//
//  GlyphDrawing.mm
//
//  Created by Jens Egeblad on 11/16/09.
//
//  [stevep: retrieved from blog entry at // http://mexircus.com/blog//blog4.php/2009/11/17/cgfontgetglyphsforunichars-fixes on 3/2/2010]
//
//  Purpose: Reimplement CGFontGetGlyphsForUnichars(CGFontRef, unichar[], CGGlyph[], size_t)
//
//  The function that does that: 
//     size_t CMFontGetGlyphsForUnichars(CGFontRef cgFont, const UniChar buffer[], CGGlyph glyphs[], size_t numGlyphs)
//
//     (returns number of glyps put in glyphs)
//
//  Why?: We are not allowed to use it on the iPhone. Apple rejects apps with it.
//
//  Why do we need it?:
//        1. UIString drawing is not thread safe
//        2. PDF drawing doesn't embeded fonts, and is therefore impossible with UIString drawing
// 
//  Another work-around for UIString drawing: Make sure it always occurs in main-thread with e.g. performSelector
// 
//  How does it work?:
//        Fetch cmap (character map) table of font
//        Find the right segment (We only look for platform 0 and 3 and format 4 and 12)
//          Pick a platform+format for all subsequent lookups.
//          Cache selection
// 
//        For each unichar look for character in selected cmap segment (either format 4 or 12)
// 
//  How well does it work?:
//        This files contains testing code. All 65536 unichars are tested with our function
//        and Apples.  Testing generally gives perfect results for all
//        current fonts except:
//         + AppleGothic where there are about 300 character mismatches from char 55424 and up
//         + STHeitiTC-Light and STHeitiTC-Medium  which has one character mismatch
//
//  Why those anomalies?: I don't know... 
//
//  Possible improvements:
//     + cache better: 
//          We cache the fonttables and never release them. Consider release strateies
///    + Search faster: 
//          It may be possible to do binary searching in the tables if they are sorted
//          which I don't know if they are
//     + Add more formats: Only format 4 and 12 supported. That handles all present iPhone fonts.
//     + Fix current minor issues.
//     
// 
//  This code was mainly based on:
//       http://github.com/jamesjhu/CMGlyphDrawing
// 
//  Other reading:
//      Apple document on truetype format:  http://developer.apple.com/textfonts/TTRefMan/RM06/Chap6cmap.html
//      Another code: http://code.google.com/p/cocos2d-iphone/source/browse/trunk/external/FontLabel/FontLabelStringDrawing.m?spec=svn1358&r=1358

#import <Foundation/Foundation.h>

// ===========================================================================
//
// Helper functions for indexing into CFDataRef
//

UInt16 getUInt16WithByteIndex(CFDataRef data, CFIndex index) {
    UInt16 value = 0;
    CFDataGetBytes(data, CFRangeMake(index, 2), (UInt8 *)&value);
    return CFSwapInt16BigToHost(value);
}

UInt32 getUInt32WithByteIndex(CFDataRef data, CFIndex index) {
    UInt32 value = 0;
    CFDataGetBytes(data, CFRangeMake(index, 4), (UInt8 *)&value);
    return CFSwapInt32BigToHost(value);
}

UInt16 getUInt16(CFDataRef data, CFIndex index) {
    UInt16 value = 0;
    CFDataGetBytes(data, CFRangeMake(index * 2, 2), (UInt8 *)&value);
    return CFSwapInt16BigToHost(value);
}

// UNICODE helpers

#define kUnicodeHighSurrogateStart 0xD800
#define kUnicodeHighSurrogateEnd 0xDBFF
#define kUnicodeLowSurrogateStart 0xDC00
#define kUnicodeLowSurrogateEnd 0xDFFF

inline bool unicharIsHighSurrogate(UniChar c) { return c >= kUnicodeHighSurrogateStart && c <= kUnicodeHighSurrogateEnd; }
inline bool unicharIsLowSurrogate(UniChar c) {return c >= kUnicodeLowSurrogateStart && c <= kUnicodeLowSurrogateEnd; }
inline UInt32 convertSurrogatePairToUTF32(UniChar high, UniChar low) { return (UInt32)((high - 0xD800) * 0x400 + (low - 0xDC00) + 0x10000); }


// ===========================================================================
//
// CMap -- struct + functions.
// A cmap is a part of each truetype font that contains the 
// TADAA!!: character map. (which is what we want)
//

/** 
	Only save a ref to the cmap fonttable and the segment offset
	of segment with the relevant platform
	When we build a cmap we decide which segment to use.
 */
struct CMap {
	CFDataRef fontTable;
	UInt32 segmentOffset;
	int format; // 4 or 12 only support right now.
};

// Create a cmap struction (retains font table)
CMap * CMapCreate(CFDataRef fontTable, UInt32 segmentOffset, int format) 
{
	CMap * cmap = (CMap *)calloc(1, sizeof(CMap));
	cmap->segmentOffset = segmentOffset;
	CFRetain(fontTable);
	cmap->fontTable	 = fontTable;
	cmap->format = format;
	return cmap;
}

// Delete cmap struction (relases the font table)
void CMapRelease(CMap * cmap) 
{
	// Release CFData references
	CFRelease(cmap->fontTable);
	// Release struct
	free(cmap);
}

/** CMap cache -- We have a global cache of all the fonts we have encountered so far.
    The cache specifically caches the plaform decision we've made in the form of the segment offset.
*/
static CFMutableDictionaryRef cmapCache = NULL; 

// Decide the contents of the cmap (platform + format)
CMap * CMGetCMapForFont(CGFontRef cgFont) 
{
	// Create dictionary to cache cmaps
	if (cmapCache == NULL) {
		CFDictionaryValueCallBacks nonRetainingDictionaryValueCallbacks = kCFTypeDictionaryValueCallBacks;
		nonRetainingDictionaryValueCallbacks.retain = NULL;
		nonRetainingDictionaryValueCallbacks.release = NULL;
		cmapCache = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &nonRetainingDictionaryValueCallbacks);
	}
	
	// extract font name to insert the font into the cache.
	CFStringRef fontName = CGFontCopyFullName(cgFont);
	// Check dictionary to see if a cmap exists for given font name
	CMap * cmap = (CMap *)CFDictionaryGetValue(cmapCache, fontName);
	if (cmap != NULL) {
		CFRelease(fontName);
		return cmap;
	}
	
	CFDataRef fontTable = CGFontCopyTableForTag(cgFont, 'cmap');
	if (fontTable != NULL) {
		UInt16 version = 0;
		UInt16 subtableCount = 0;
		
		version = getUInt16WithByteIndex(fontTable, 0);
		subtableCount = getUInt16WithByteIndex(fontTable, 2);
		
		UInt32 segmentOffset = 0;
		UInt16 bestPlatformID = 0;
		// each platform is given a priority - Lower is better

		// We prefer platform 0
		struct PlatformPriority {
			int plat;
			int prio;
		};
		PlatformPriority const platforms[] = {
			{0, 0}, // best
			{3, 1}, // second best
		};
		// anything else is ignored 
		// -- The iPhone fonts typically also have platform 1, but we ignore them for now
		int bestPriority = 2000000000; // Smaller is better so start with big...
		
		// Iterate through all subtables to find the best platform
		for (UInt16 subtableIndex = 0; subtableIndex < subtableCount; ++subtableIndex) {
			UInt16 platformID = getUInt16WithByteIndex(fontTable, subtableIndex * 8 + 4);

			// look for this platformID in our list. Are we interested in it at all?
			for (int p = 0; p < sizeof(platforms)/sizeof(PlatformPriority); ++p) {
				if (platformID == platforms[p].plat && bestPriority > platforms[p].prio) {
					segmentOffset = getUInt32WithByteIndex(fontTable, subtableIndex * 8 + 8);;
					bestPriority = platforms[p].prio;
					bestPlatformID = platformID;
				}
			}
		}
		
		// Only support Unicode... (platform 0 and 3) and format 4 and 12
		if (bestPlatformID == 0 || bestPlatformID == 3) {
			UInt16 format = getUInt16WithByteIndex(fontTable, segmentOffset);
			if (format == 4 || format == 12) {
				cmap = CMapCreate(fontTable, segmentOffset, format);
				
				// Assign cmap to font name and cache it in the dictionary
				CFDictionaryAddValue(cmapCache, fontName, cmap);
				CFRelease(fontName);
				CFRelease(fontTable);
				return cmap;
			}
		}
		
		// not supported -- Just leave
		CFRelease(fontTable);
	}

	CFRelease(fontName);	
    return NULL;
}


size_t
CMap4GetGlyphIndicesForUnichar(CMap * cmap, UniChar const * s, CGGlyph * result, size_t count) 
{
	// Unlike other implementations, I don't cache all this stuff. It is relatively easy
	// to extract, and we use plenty of memory on the iPhone as it is.
	UInt32 segmentOffset = 	cmap->segmentOffset;
	UInt16 segCountX2 =  getUInt16WithByteIndex(cmap->fontTable, segmentOffset + 6);
	UInt16 segCount = segCountX2 / 2;
	
	unsigned char * ptr = (unsigned char*)CFDataGetBytePtr(cmap->fontTable);
	unsigned int endCodeOffset = segmentOffset + 14;
	UInt16 * endCode  =  (UInt16*)&ptr[endCodeOffset];
	unsigned int startCodeOffset = endCodeOffset + 2 + segCountX2;
	UInt16 * startCode =  (UInt16*)&ptr[startCodeOffset];
	unsigned int idDeltaCodeOffset = startCodeOffset + segCountX2;
	UInt16 * idDelta   =  (UInt16*)&ptr[idDeltaCodeOffset];;
	unsigned int idRangeOffsetOffset = idDeltaCodeOffset + segCountX2;
	UInt16 * idRangeOffset = (UInt16*)&ptr[idRangeOffsetOffset];
	unsigned int glyphIndexArrayOffset = idRangeOffsetOffset + segCountX2;
	UInt16 * glyphIndexArray = (UInt16*)&ptr[glyphIndexArrayOffset];
	
	
	for (size_t j = 0; j < count; ++j) { 
		UniChar c = s[j];
		bool found = false;
		for (int i = 0; i < segCount; i++) {
			// Find first endcode greater or equal to the char code
			UInt16 end = CFSwapInt16BigToHost(endCode[i]);
			UInt16 start = CFSwapInt16BigToHost(startCode[i]);
			if (end >= c && start <= c) {
				UInt16 delta = CFSwapInt16BigToHost(idDelta[i]);
				UInt16 rangeOffset = CFSwapInt16BigToHost(idRangeOffset[i]);
				if(rangeOffset == 0) {
					result[j] = delta + c;
					found = true;
					break;
				} else {
					result[j] = CFSwapInt16BigToHost(glyphIndexArray[(rangeOffset >> 1) + (c - start) - (segCount - i)]);
					found = true;
					break;
				}
			}
		}
		if (!found) {
			// failed. Set the glyph to zero.
			result[j] = 0;
		}
	}
	return count;
}

size_t
CMap12GetGlyphIndicesForUnichar(CMap * cmap, UniChar const * s, CGGlyph * result, size_t count) 
{
	UInt32 nGroups = getUInt32WithByteIndex(cmap->fontTable, cmap->segmentOffset + 12);
	size_t glyphOutputCount = 0;
	for (size_t j = 0; j < count; ++j) {
		// Format of groups are:
		// UInt32 startCode
		// UInt32 endCode
		// startGlyph
		bool found = false;
		
		// figure out what the 32-bit version of this is:
		UniChar c = s[j];
		UInt32 c32 = c;
		if (unicharIsHighSurrogate(c)) {
			if (j+1 < count) { 
				unichar cc = s[j+1];
				if (unicharIsLowSurrogate(cc)) {
					c32 = convertSurrogatePairToUTF32(c, cc);
					j++;
				}
			}
		}
		int offset = cmap->segmentOffset + 16;
		for (UInt32 g = 0; g < nGroups; ++g) {
			UInt32 start  = getUInt32WithByteIndex(cmap->fontTable, offset);
			UInt32 end  = getUInt32WithByteIndex(cmap->fontTable, offset + 4);

			if (c32 <= end && c32 >= start) {
				UInt32 startGlyph  = getUInt32WithByteIndex(cmap->fontTable, offset + 8);
				result[glyphOutputCount++] = startGlyph + c32 - start;
				found = true;
				break;
			}
			offset += 12;
		}
		if (!found) {
			// add blank
			result[glyphOutputCount++] = 0;
		}
	}
	
	return glyphOutputCount;
}


// ===========================================================================
//
// Main functions:



// The lock will keep the cache thread safe. You'll need some place to set 
// it up though

static NSLock * lock = 0;

// Call this before anything
void setupGlyphsLock()
{
	if (!lock) {
		[[NSLock alloc] init];
	}
}


extern "C" size_t
CMFontGetGlyphsForUnichars(CGFontRef cgFont, const UniChar buffer[], CGGlyph glyphs[], size_t numGlyphs)
{
	size_t res = 0;;
	// only act on the lock if we have one
	if (lock) { [lock lock]; }
	CMap * cmap = CMGetCMapForFont(cgFont);
	if (cmap->format == 4) {
		res = CMap4GetGlyphIndicesForUnichar(cmap, buffer, glyphs, numGlyphs);
	} else if(cmap->format == 12) {
		res = CMap12GetGlyphIndicesForUnichar(cmap, buffer, glyphs, numGlyphs);
	} else {
		// just fill in blanks
		for (int i = 0; i < numGlyphs; ++i) {
			glyphs[i] = 0;
		}
		res = numGlyphs;
	}
	// again, unlock if we use a lock
	if (lock) { [lock unlock]; }
	return res;
}




// =============================================================================
//
// testing code -- Tabulate fonts will run through all fonts and compare with 
// CGFontGetGlyphsForUnichars
//

//#define TESTING
#ifdef TESTING

extern "C" bool CGFontGetGlyphsForUnichars(CGFontRef, unichar[], CGGlyph[], size_t);

void 
verifyFont(CGFontRef font)
{
	for (size_t j = 0; j < 256; ++j) {
		UniChar s[256];
		for (size_t i = 0; i < 256; ++i) {
			s[i] = j*256 + i;
		}
		CGGlyph ours[256];
		CGGlyph theirs[256];
		CGFontGetGlyphsForUnichars(font, s, theirs, 256);
		CMFontGetGlyphsForUnichars(font, s, ours, 256);
		for (size_t i = 0; i < 256; ++i) {
			if (ours[i] != theirs[i]) {
				printf("char: %i doesn't match. I get: %i I want: %i\n", j*256+i, ours[i], theirs[i]);
			}
		}
	}
}

struct MyFontInfo  {
	NSString * name;
	NSString * regularName;
	NSString * boldName;
	NSString * italicName;
	NSString * boldItalicName;
};

static MyFontInfo fontTable[] = {

{@"Georgia",						@"Georgia",				@"Georgia-Bold",		@"Georgia-Italic",			@"Georgia-BoldItalic"},
{@"Helvetica",						@"Helvetica",			@"Helvetica-Bold",		@"Helvetica-Oblique",		@"Helvetica-BoldOblique"},

{@"DB LCD Temp",					@"DBLCDTempBlack",		0,						0,							0},
{@"Marker Felt",					@"MarkerFelt-Thin",		0,						0,							0},
{@"Zapfino",						@"Zapfino",				0,						0,							0},

{@"Arial",							@"ArialMT",				@"Arial-BoldMT",		@"Arial-ItalicMT",			@"Arial-BoldItalicMT"},
{@"Times New Roman",				@"TimesNewRomanPSMT",	@"TimesNewRomanPS-BoldMT", @"TimesNewRomanPS-ItalicMT", @"TimesNewRomanPS-BoldItalicMT"},

{@"American Typewriter",			@"AmericanTypewriter",	@"AmericanTypewriter-Bold",	0,						0},
{@"Courier",						@"Courier",				@"Courier-Bold",		@"Courier-Oblique",			@"Courier-BoldOblique"},
{@"Verdana",						@"Verdana",				@"Verdana-Bold",		@"Verdana-Italic",			@"Verdana-BoldItalic"},

{@"Arial Rounded MT Bold",			@"ArialRoundedMTBold",	0,						0,							0},
{@"Arial Unicode MS",				@"ArialUnicodeMS",	0,						0,							0},
{@"AppleGothic",					@"AppleGothic",			0,						0,							0},
{@"Courier New",					@"CourierNewPSMT",		@"CourierNewPS-BoldMT",	@"CourierNewPS-ItalicMT",	@"CourierNewPS-BoldItalicMT"},
{@"Helvetica Neue",					@"HelveticaNeue",		@"HelveticaNeue-Bold",	0,							0},
{@"Hiragino Kaku Gothic ProN W3",	@"HiraKakuProN-W3",		0,						0,							0},
{@"Hiragino Kaku Gothic ProN W6",	@"HiraKakuProN-W6",		0,						0,							0},
{@"STHeiti TC",						@"STHeitiTC-Light",		@"STHeitiTC-Medium",	0,							0},
{@"Trebuchet MS",					@"TrebuchetMS",			@"TrebuchetMS-Bold",	@"TrebuchetMS-Italic",		@"Trebuchet-BoldItalic"}
};


void
tabulate(NSString * fontName)
{
	if (!fontName) { return; }
	CGFontRef cgfont = CGFontCreateWithFontName ((CFStringRef)fontName);
	if (!cgfont) {
		printf("!!!=========================================!!!\n");
		printf("Could not create font: %s\n", [fontName UTF8String]);
		printf("!!!=========================================!!!\n");
		return;
	}
	printf("===============================================================\n");
	printf("Font: %s\n", [fontName UTF8String]);
	CMGetCMapForFont(cgfont);
	verifyFont(cgfont);
	CGFontRelease(cgfont);
}

void
tabulateFonts()
{
	for (int i = 0; i < sizeof(fontTable)/sizeof(MyFontInfo); ++i) {
		tabulate(fontTable[i].regularName);
		tabulate(fontTable[i].boldName);
		tabulate(fontTable[i].italicName);
		tabulate(fontTable[i].boldItalicName);
	}
}


#endif
