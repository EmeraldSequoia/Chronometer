//
//  ECWatchDefinitionManager
//  Emerald Chronometer
//
//  Created by Steve Pucci on 4/27/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ECWatchDefinitionManager.h"
#import	"ChronometerAppDelegate.h"
#import "ECErrorReporter.h"
#import "ECWatchController.h"
#import "ECPartController.h"
#import "ECWatch.h"
#import "ECQView.h"
#import "ECWatchPart.h"
#import "EBVirtualMachine.h"
#import "ECDemo.h"
#import "ECGlobals.h"

#import <Foundation/Foundation.h>

@implementation ECWatchDefinitionManager

// Forward declarations

static double xm, ym, rm;
#if 0 // #ifdef EC_IPAD
static double scaler = 768.0/320.0;
#else
static double scaler = 1;
#endif
static NSMutableDictionary *imageCache;
static NSMutableDictionary *uniqueChecker;
static bool capturingDemo = false;

+(void)initialize {
    xm = [UIScreen mainScreen].bounds.size.width * 10;	    // really should be this divided by 2 but we sometimes want to draw parts somewhat off screen
    ym = [UIScreen mainScreen].bounds.size.height * 10;
    rm = floor(sqrt(xm*xm + ym*ym) * 2);
    imageCache = [[NSMutableDictionary alloc]initWithCapacity:70];
    uniqueChecker = [[NSMutableDictionary alloc]initWithCapacity:200];
}
    
-(ECWatchDefinitionManager *)init {
	[super init];
    builtinWatchDirectoryName = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Watches"];
    [builtinWatchDirectoryName retain];
    winBin = [[NSMutableArray alloc]initWithCapacity:4];
    watchController = nil;
    return self;
}

-(void)dealloc {
    [builtinWatchDirectoryName release];
    [winBin release];
    [super dealloc];
}

-(NSString *)watchDefinitionPathForName:(NSString *)name
{
    NSString *builtinName = [builtinWatchDirectoryName stringByAppendingPathComponent:name];
    BOOL isDirectory;
    if ([[NSFileManager defaultManager] fileExistsAtPath:builtinName isDirectory:&isDirectory]) {
	if (!isDirectory) {
	    [errorDelegate reportError:[NSString stringWithFormat:@"Watch definition bundle %@ is not a directory", builtinName]];
	    return nil;
	}
	return builtinName;
    }
    [errorDelegate reportError:[NSString stringWithFormat:@"Can't find watch definition bundle for watch '%@'", name]];
    return nil;
}

static NSString *watchToLoad = nil;

static CGSize expectedFrontAtlasSize;
static CGSize expectedBackAtlasSize;
static CGSize expectedNightAtlasSize;

-(ECWatchController *)loadWatchWithName:(NSString *)name intoController:(ECWatchController *)aWatchController errorReporter:(id)errorReporter{
    //[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"%@ watch load start", name] UTF8String]];
    errorDelegate = errorReporter;
    watchController = aWatchController;
    watchController.reallyLoaded = true;
    NSString *watchDirectory = [builtinWatchDirectoryName stringByAppendingPathComponent:name];  // HACK FOR NOW, SINCE ALL WATCHES ARE BUILTIN: FIX

    NSString *watchDescriptorFile = [watchDirectory stringByAppendingPathComponent:[name stringByAppendingString:@".xml"]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:watchDescriptorFile]) {
	printf("watchDescriptorFile %s\n", [watchDescriptorFile UTF8String]);
	[errorDelegate reportError:[NSString stringWithFormat:@"Watch definition bundle %@ doesn't contain %@.xml", watchDirectory, name]];
	return watchController;
    }
    
    currentWatchName = name;
    currentWatchBundleDirectory = watchDirectory;

    [uniqueChecker removeAllObjects];		    // start clean

    vm = [[watchController watch] vm];
    assert(vm != nil);

    expectedFrontAtlasSize
	= expectedBackAtlasSize
	= expectedNightAtlasSize
	= CGSizeMake(-1, -1);

    // Open the file, and read it
    NSURL *url = [NSURL fileURLWithPath:watchDescriptorFile isDirectory:NO];

    NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:url];
    [parser setDelegate:self];
    [parser setShouldProcessNamespaces:NO];
    [parser setShouldReportNamespacePrefixes:NO];
    [parser setShouldResolveExternalEntities:NO];
    
    @try {
	[parser parse];
    }
    @catch(NSException *exception) {
	[errorDelegate reportError:[NSString stringWithFormat:@"Parse error encounted in definition for watch %@: %@", name, [exception reason]]];
	[parser release];
	currentWatchBundleDirectory = nil;
	currentWatchName = nil;
	vm = nil;
	return nil;
    }
    @finally {
    }
    [parser release];
    currentWatchName = nil;
    currentWatchBundleDirectory = nil;

    if (expectedFrontAtlasSize.width < 0) {
	[errorDelegate reportError:[NSString stringWithFormat:@"Didn't find element 'atlas' in watch %@", name]];
	vm = nil;
	return nil;
    }
    [watchController setExpectedFrontAtlasSize:expectedFrontAtlasSize
				 backAtlasSize:expectedBackAtlasSize
				nightAtlasSize:expectedNightAtlasSize];

    ECWatchController *returnValue = watchController;
    watchController = nil;
    errorDelegate = nil;
    vm = nil;
    //[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"%@ watch load end", name] UTF8String]];
    return returnValue;
}

-(ECWatchController *)loadWatchAtPath:(NSString *)watchDirectory withName:(NSString *)name
{
    if ( [name compare:@"partsBin"] == NSOrderedSame) {
	return nil;
    }

    // Construct the ECWatchController
    watchController = [[ECWatchController alloc] initWithName:name];
    [watchController autorelease];
    if (watchToLoad && [name compare:watchToLoad] != NSOrderedSame) {
	ECWatchController *returnValue = watchController;
	watchController = nil;
	[ChronometerAppDelegate noteTimeAtPhase:[[NSString stringWithFormat:@"%@ watch load deferred", name] UTF8String]];
	return returnValue;
    }

#undef DEBUG_LOAD
#ifdef DEBUG_LOAD
    printf("\nLoading watch %s\n", [name UTF8String]);
#endif

    return [self loadWatchWithName:name intoController:watchController errorReporter:errorDelegate];
}

NSString *hackWatch = nil;

-(void)loadAllWatchesInDirectory:(NSString *)directory
{
    //printf("Loading all watches in directory %s\n", [directory UTF8String]);
    //fflush(stdout);
    NSArray *watchNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL];
    for (NSString *watchName in watchNames) {
	if (hackWatch && ([watchName compare:hackWatch] != NSOrderedSame)) {
	    continue;
	}
	// try to load it
	ECWatchController *watchCon = [self loadWatchAtPath:[directory stringByAppendingPathComponent:watchName] withName:watchName];
	if (watchCon == nil) {
	    // do nothing; loadWatchAtPath reported the error
	} else {
	    // add it to the list of watches
	    if ([ChronometerAppDelegate addWatch:watchCon]) {
		// OK
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Duplicate watch name '%@'", watchName]];	    
	    }
	}
    }
}

-(void)loadAllWatchesWithErrorReporter:(id)errorReporter
{
    errorDelegate = errorReporter;
    [self loadAllWatchesInDirectory:builtinWatchDirectoryName];
// nothing here yet so don't bother    [self loadAllWatchesInDirectory:customWatchDirectoryName];
    errorDelegate = nil;
}

-(void)loadAllWatchesWithErrorReporter:(id)errorReporter butJustReallyLoad:(NSString *)watchName
{
    watchToLoad = [watchName retain];
    errorDelegate = errorReporter;
    [self loadAllWatchesInDirectory:builtinWatchDirectoryName];
// nothing here yet so don't bother    [self loadAllWatchesInDirectory:customWatchDirectoryName];
    errorDelegate = nil;
    [watchToLoad release];
    watchToLoad = nil;
}

-(void)loadAllWatchesWithErrorReporter:(id)errorReporter butJustHackIn:(NSString *)watchName
{
    hackWatch = [watchName retain];
    errorDelegate = errorReporter;
    [self loadAllWatchesInDirectory:builtinWatchDirectoryName];
// nothing here yet so don't bother    [self loadAllWatchesInDirectory:customWatchDirectoryName];
    errorDelegate = nil;
    [hackWatch release];
    hackWatch = nil;
}

-(ECWatchController *)loadWatchWithName:(NSString *)name errorReporter:(id)delegate
{
    //printf("Loading watch named %s\n", [name UTF8String]);
    //fflush(stdout);

    errorDelegate = delegate;

    // Find the file
    NSString *watchDirectory = [self watchDefinitionPathForName:name];
    if (!watchDirectory) {
	errorDelegate = nil;
	return nil;
    }
    ECWatchController *returnController = [self loadWatchAtPath:watchDirectory withName:name];
    errorDelegate = nil;
    return returnController;
}

- (void)parserDidStartDocument:(NSXMLParser *)parser
{
    //printf("Saw XML start document\n");
}

- (void)parserDidEndDocument:(NSXMLParser *)parser
{
    //printf("Saw XML end document\n");
}

static int uniquer = 1000;
- (NSString *)verifyName:(NSString *)aName hint:(NSString*)hint{
    if (aName == nil) {
	[errorDelegate reportError:[NSString stringWithFormat:@"No 'name' attribute for a %@ part\nin %@", hint, currentWatchName]];
    }
    if ([uniqueChecker objectForKey:aName]) {
	[errorDelegate reportError:[NSString stringWithFormat:@"Duplicate name '%@' for parts\nin %@", aName, currentWatchName]];
	aName = [NSString stringWithFormat:@"%@%d", aName, uniquer++];
    }
    [uniqueChecker setObject:self forKey:aName];
    return aName;
}

- (NSString *)verifyRefName:(NSString *)aName hint:(NSString*)hint{
    if (aName != nil) {
	if ([uniqueChecker objectForKey:aName] == nil) {
	    [errorDelegate reportError:[NSString stringWithFormat:@"Bad refName '%@' for a %@ part\nin %@", aName, hint, currentWatchName]];
	    aName = [NSString stringWithFormat:@"%@%d", aName, uniquer++];
	}
    }
    return aName;
}

- (NSString *)verifyAttr:(NSDictionary *)attributeDict key:(NSString *)key for:(NSString *)partName {
    NSString *val = [attributeDict objectForKey:key];
    if (val == nil) {
	if (partName) {
	    if ([partName caseInsensitiveCompare:@"optional"] == NSOrderedSame) {
		// expr will be "0"
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"No '%@' attribute\nfor %@:%@", key, currentWatchName, partName]];
	    }
	} else {
	    [errorDelegate reportError:[NSString stringWithFormat:@"No '%@' attribute\nfor %@:%@", key, currentWatchName, @"init"]];  // hack
	}
	val = @"0";
    }
    return val;
}

- (NSString *)verifyAttr:(NSDictionary *)attributeDict key:(NSString *)key for:(NSString *)partName optional:(bool)opt {
    NSString *val = [attributeDict objectForKey:key];
    if (val == nil && opt) {
	return nil;
    }
    return [self verifyAttr:attributeDict key:key for:partName];
}

//static int cacheHits = 0, cacheMisses = 0;
- (UIImage *)verifyImageFile:(NSString *)srcImage for:(NSString *)partName optional:(bool)opt image2x:(UIImage **)image2x image4x:(UIImage **)image4x {
    if (srcImage == nil) {
	if (partName == nil || opt) {
	    return nil;
	} else {
	    [errorDelegate reportError:[NSString stringWithFormat:@"No 'src' attribute\nfor %@:%@", currentWatchName, partName]];
	}
    }
    UIImage *anImage;
    NSString *srcImagePath = [currentWatchBundleDirectory stringByAppendingPathComponent:srcImage];
    anImage = [imageCache objectForKey:srcImagePath];
    if (anImage == nil) {
	anImage = [UIImage imageWithContentsOfFile:srcImagePath];
	if (anImage == nil) {
	    if (opt) {
		return nil;
	    }
	    [errorDelegate reportError:[NSString stringWithFormat:@"Image %@ failed to load\nfor %@:%@", srcImagePath, currentWatchName, partName]];
	    assert(false);
	} else {
	    [imageCache setObject:anImage forKey:srcImagePath];
//	    printf("cache miss %d\t%s\n", cacheMisses++, [srcImage UTF8String]);
	}
    } else {
//	printf("cache hit %d\t%s\n",cacheHits++, [srcImage UTF8String]);
    }
    NSString *srcImage2x = [srcImage stringByReplacingOccurrencesOfString:@".png" withString:@"-2x.png"];
    NSString *srcImagePath2x = [currentWatchBundleDirectory stringByAppendingPathComponent:srcImage2x];
    *image2x = [imageCache objectForKey:srcImagePath2x];
    if (*image2x == nil) {
	*image2x = [UIImage imageWithContentsOfFile:srcImagePath2x];
	if (*image2x == nil) {
	    // Consider warning here:  All images should have AT2x versions...
	    //[errorDelegate reportError:[NSString stringWithFormat:@"Image %@ failed to load\nfor %@:%@", srcImagePath, currentWatchName, partName]];
	    //assert(false);
	    // or not; Bill thinks some images (eg. bands) are OK at low res even on high res devices
	} else {
	    [imageCache setObject:*image2x forKey:srcImagePath2x];
//	    printf("cache miss %d\t%s\n", cacheMisses++, [srcImage UTF8String]);
	}
    } else {
//	printf("cache hit %d\t%s\n",cacheHits++, [srcImage UTF8String]);
    }
    NSString *srcImage4x = [srcImage stringByReplacingOccurrencesOfString:@".png" withString:@"-4x.png"];
    NSString *srcImagePath4x = [currentWatchBundleDirectory stringByAppendingPathComponent:srcImage4x];
    *image4x = [imageCache objectForKey:srcImagePath4x];
    if (*image4x == nil) {
	*image4x = [UIImage imageWithContentsOfFile:srcImagePath4x];
	if (*image4x == nil) {
	    // Consider warning here:  All images should have AT4x versions...
	    //[errorDelegate reportError:[NSString stringWithFormat:@"Image %@ failed to load\nfor %@:%@", srcImagePath, currentWatchName, partName]];
	    //assert(false);
	    // or not; Bill thinks some images (eg. bands) are OK at low res even on high res devices
	} else {
	    [imageCache setObject:*image4x forKey:srcImagePath4x];
//	    printf("cache miss %d\t%s\n", cacheMisses++, [srcImage UTF8String]);
	}
    } else {
//	printf("cache hit %d\t%s\n",cacheHits++, [srcImage UTF8String]);
    }
#ifndef NDEBUG
    assert(anImage.scale == 1);  // Otherwise we're getting the high-definition version unintentionally (Henry must run on iPhone 3 simulator)
#endif
    return anImage;
}

- (NSArray *)verifyImageDir:(NSString *)directoryName for:(NSString *)partName {
    if (directoryName == nil) {
	[errorDelegate reportError:[NSString stringWithFormat:@"No 'dir' attribute\nfor %@:%@", currentWatchName, partName]];
    }
    NSString *directoryPath = [currentWatchBundleDirectory stringByAppendingPathComponent:directoryName];
    NSMutableArray *frames = [NSMutableArray arrayWithCapacity:10];
    NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:NULL];
    for (NSString *imageFileName in fileNames) {
	NSString *imagePath = [directoryPath stringByAppendingPathComponent:imageFileName];
	UIImage *anImage = [UIImage imageWithContentsOfFile:imagePath];
	if (anImage == nil) {
	    [errorDelegate reportError:[NSString stringWithFormat:@"Image %@ failed to load\nfor %@:%@", imageFileName, currentWatchName, partName]];
	}	
	[frames addObject:anImage];
    }
    if ([frames count] == 0) {
	[errorDelegate reportError:[NSString stringWithFormat:@"No files found in %@\nfor %@:%@", directoryName, currentWatchName, partName]];
    }
    return frames;
}

- (UIFont *)verifyFont:(NSString *)fontName size:(double)fontSize for:(NSString *)partName {
    if (fontName == nil) {
	[errorDelegate reportError:[NSString stringWithFormat:@"No 'fontName' attribute\nfor %@:%@", currentWatchName, partName]];
    }
    UIFont *font = [UIFont fontWithName:fontName size:fontSize];
    if (font == nil) {
	[errorDelegate reportError:[NSString stringWithFormat:@"Font '%@ %g' failed to load\nfor %@:%@", fontName, fontSize, currentWatchName, partName]];
	font = [UIFont fontWithName:@"Arial" size:12];
    }
    return font;
}

- (UIFont *)verifyFont:(NSString *)fontName size:(double)fontSize for:(NSString *)partName optional:(bool)opt {
    if (opt && fontName == nil) {
	return nil;
    } else {
	return [self verifyFont:fontName size:fontSize for:partName];
    }
}

- (UIColor *)colorCheck:(NSDictionary *)attributeDict  df:(UIColor*)df name:(NSString *)name attr:(NSString *)attr {
    NSString *stringValue = [attributeDict objectForKey:attr];
    if (stringValue != nil) {
	if ([stringValue caseInsensitiveCompare:@"black"] == NSOrderedSame) return [UIColor blackColor];
	if ([stringValue caseInsensitiveCompare:@"white"] == NSOrderedSame) return [UIColor whiteColor];
	if ([stringValue caseInsensitiveCompare:@"red"] == NSOrderedSame) return [UIColor redColor];
	EBVMInstructionStream *instructionStream = [vm compileInstructionStreamFromCExpression:stringValue errorReporter:[ECErrorReporter theErrorReporter]];
	unsigned int val = (unsigned int)[vm evaluateInstructionStream:instructionStream errorReporter:[ECErrorReporter theErrorReporter]];
        switch (val) {
	    case ECblack:	return [UIColor blackColor];
	    case ECblue:	return [UIColor blueColor];
	    case ECgreen:	return [UIColor greenColor];
	    case ECcyan:	return [UIColor cyanColor];
	    case ECred:		return [UIColor redColor];
	    case ECyellow:	return [UIColor yellowColor];
	    case ECmagenta:	return [UIColor magentaColor];
	    case ECwhite:	return [UIColor whiteColor];
	    case ECbrown:	return [UIColor brownColor];
	    case ECdarkGray:	return [UIColor darkGrayColor];
	    case EClightGray:	return [UIColor lightGrayColor];
            case ECclear:	return [UIColor clearColor];
            case ECnfgclr:      return [UIColor colorWithRed:0xb0/255.0 green:0xff/255.0 blue:0xf8/255.0 alpha:1.0];  // 0xffb0fff8
	    default:
	    {
		// val is an int of the form AARRGGBB where AA etc are hex digits
		double alpha = ((val & 0xff000000) >> 24) / 255.0;
		double red   = ((val & 0x00ff0000) >> 16) / 255.0;
		double green = ((val & 0x0000ff00) >>  8) / 255.0;
		double blue  = ((val & 0x000000ff)      ) / 255.0;
		return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
	    }
	}
    }
    return df;
}

- (ECTimeBaseKind)timeBaseCheck:(NSDictionary *)attributeDict df:(ECTimeBaseKind)df name:(NSString *)name attr:(NSString *)attr {
    NSString *stringValue = [attributeDict objectForKey:attr];
    if (stringValue != nil) {
        if ([stringValue caseInsensitiveCompare:@"LT"] == NSOrderedSame) return ECTimeBaseKindLT;
        if ([stringValue caseInsensitiveCompare:@"UT"] == NSOrderedSame) return ECTimeBaseKindUT;
        if ([stringValue caseInsensitiveCompare:@"LST"] == NSOrderedSame) return ECTimeBaseKindLST;
        [errorDelegate reportError:[NSString stringWithFormat:@"Invalid timeBase for %@:%@ -- '%@'", name, attr, stringValue]];
    }
    return df;
}

- (ECHoleType)holeCheck:(NSDictionary *)attributeDict df:(ECHoleType)df attr:(NSString *)attr {
    NSString *stringValue = [attributeDict objectForKey:attr];
    if (stringValue != nil) {
	EBVMInstructionStream *instructionStream = [vm compileInstructionStreamFromCExpression:stringValue errorReporter:[ECErrorReporter theErrorReporter]];
	int val = (int)[vm evaluateInstructionStream:instructionStream errorReporter:[ECErrorReporter theErrorReporter]];
	switch (val) {
	    case ECHoleWind:
	    case ECHolePort:
		return val;
	    default:
		[errorDelegate reportError:[NSString stringWithFormat:@"Invalid type for window:%@", attr]];
	}
    }
    return df;
}

- (ECDialOrientation)qDialTypeCheck:(NSDictionary *)attributeDict  df:(ECDialOrientation)df name:(NSString *)name attr:(NSString *)attr {
    NSString *stringValue = [attributeDict objectForKey:attr];
    if (stringValue != nil) {
	if ([stringValue caseInsensitiveCompare:@"upright"] == NSOrderedSame) return ECDialOrientationUpright;
	if ([stringValue caseInsensitiveCompare:@"demi"] == NSOrderedSame) return ECDialOrientationDemiRadial;
	if ([stringValue caseInsensitiveCompare:@"rotated"] == NSOrderedSame) return ECDialOrientationRotatedRadial;
	if ([stringValue caseInsensitiveCompare:@"radial"] == NSOrderedSame) return ECDialOrientationRadial;
	if ([stringValue caseInsensitiveCompare:@"tachy"] == NSOrderedSame) return ECDialOrientationTachy;
	if ([stringValue caseInsensitiveCompare:@"year"] == NSOrderedSame) return ECDialOrientationYear;
	EBVMInstructionStream *instructionStream = [vm compileInstructionStreamFromCExpression:stringValue errorReporter:[ECErrorReporter theErrorReporter]];
	int val = (int)[vm evaluateInstructionStream:instructionStream errorReporter:[ECErrorReporter theErrorReporter]];
	switch (val) {
	    case ECDialOrientationUpright:
	    case ECDialOrientationDemiRadial:
	    case ECDialOrientationRotatedRadial:
	    case ECDialOrientationRadial:
	    case ECDialOrientationYear:
		return val;
	    default:
		[errorDelegate reportError:[NSString stringWithFormat:@"Invalid type for %@:%@", name, attr]];
	}
    }
    return df;
}

- (ECQHandType)qHandTypeCheck:(NSDictionary *)attributeDict  df:(ECQHandType)df name:(NSString *)name attr:(NSString *)attr {
    NSString *stringValue = [attributeDict objectForKey:attr];
    if (stringValue != nil) {
	EBVMInstructionStream *instructionStream = [vm compileInstructionStreamFromCExpression:stringValue errorReporter:[ECErrorReporter theErrorReporter]];
	int val = (int)[vm evaluateInstructionStream:instructionStream errorReporter:[ECErrorReporter theErrorReporter]];
	switch (val) {
	    case ECQHandRect:
	    case ECQHandTri:
	    case ECQHandQuad:
	    case ECQHandCube:
	    case ECQHandRise:
	    case ECQHandSet:
	    case ECQHandSun:
	    case ECQHandSun2:
	    case ECQHandSpoke:
	    case ECQHandWire:
	    case ECQHandGear:
	    case ECQHandBreguet:
		return val;
	    default:
		[errorDelegate reportError:[NSString stringWithFormat:@"Invalid type for %@:%@", name, attr]];
	}
    }
    return df;
}

- (ECWheelOrientation)qWheelTypeCheck:(NSDictionary *)attributeDict  df:(ECWheelOrientation)df name:(NSString *)name attr:(NSString *)attr {
    NSString *stringValue = [attributeDict objectForKey:attr];
    if (stringValue != nil) {
	EBVMInstructionStream *instructionStream = [vm compileInstructionStreamFromCExpression:stringValue errorReporter:[ECErrorReporter theErrorReporter]];
	int val = (int)[vm evaluateInstructionStream:instructionStream errorReporter:[ECErrorReporter theErrorReporter]];
	switch (val) {
	    case ECWheelOrientationTwelve:
	    case ECWheelOrientationThree:
	    case ECWheelOrientationSix:
	    case ECWheelOrientationNine:
	    case ECWheelOrientationStraight:
		return val;
	    default:
		[errorDelegate reportError:[NSString stringWithFormat:@"Invalid orientation for %@:%@", name, attr]];
	}
    }
    return df;
}

- (double)boundsCheckOpt:(NSDictionary *)attributeDict lb:(double)lb ub:(double)ub df:(double)df name:(NSString *)name attr:(NSString *)attr optional:(bool)optional {
    NSString *stringValue = [attributeDict objectForKey:attr];
    if (stringValue == nil) {
	if (!optional) {
	    [errorDelegate reportError:[NSString stringWithFormat:@"Attribute '%@' required (in range [%g:%g])\nfor %@:%@", attr, lb, ub, currentWatchName, name]];
	}
	return df;
    }
    EBVMInstructionStream *instructionStream = [vm compileInstructionStreamFromCExpression:stringValue errorReporter:[ECErrorReporter theErrorReporter]];
    double val = [vm evaluateInstructionStream:instructionStream errorReporter:[ECErrorReporter theErrorReporter]];
    if (val >= lb && val <= ub) {
	return val;
    } else {
	if ([attr compare:@"update" options:NSLiteralSearch] == NSOrderedSame) {
	    if (val >= ECDynamicLB && val <= ECDynamicUB) {
		return val;
	    } else {
		return fmin(val,ub);		// long updates can screw up on DST transition day
	    }
	} else if ([attr compare:@"planetNumber" options:NSLiteralSearch] == NSOrderedSame && val == ECPlanetMidnightSun) {
	    return val;
	} else {
	    [errorDelegate reportError:[NSString stringWithFormat:@"Value '%g' out of range [%g:%g]\nfor %@:%@:%@", val, lb, ub, currentWatchName, name, attr]];
	    return df;
	}
    }
}

- (double)boundsCheck:(NSDictionary *)attributeDict lb:(double)lb ub:(double)ub df:(double)df name:(NSString *)name attr:(NSString *)attr {
    return [self boundsCheckOpt:attributeDict lb:lb ub:ub df:df name:name attr:attr optional:false];
}

- (void)noWindows:(NSString *)name {
    if ([winBin count] != 0) {
	[errorDelegate reportError:[NSString stringWithFormat:@"window elements not valid here %@:%@", currentWatchName, name]];
	[winBin removeAllObjects];
    }
}

- (void)applyWindows:(id)view {
    for (ECHoleHolder *win in winBin) {
	[view clearHere:win];
	[win release];
    }
    [winBin removeAllObjects];
}

- (void)parserDidInitStart:(NSDictionary *)attributeDict {
    NSString *expr = [self verifyAttr:attributeDict key:@"expr" for:nil];
    if (expr) {
	EBVMInstructionStream *initInstructionStream = [vm compileInstructionStreamFromCExpression:expr errorReporter:[ECErrorReporter theErrorReporter]];
	[vm evaluateInstructionStream:initInstructionStream errorReporter:[ECErrorReporter theErrorReporter]];
	[[watchController watch] addInit:initInstructionStream];
    }
    [self noWindows:@"init"];
}

static ECQStaticView *theBase = nil;
static ECWatchModeMask baseMask;

- (bool)onBase:(NSString *)element {
    if (theBase) {
	[errorDelegate reportError:[NSString stringWithFormat:@"element '%@' not allowed in a static for %@", element, currentWatchName]];	    
	return true;
    }
    return false;
}

- (void)parserDidStaticStart:(NSDictionary *)attributeDict {
    //   <base name='face' modes='front' n='42'> ... </base>
    
    if ([self onBase:@"static"])
	return;
    
    NSString *nam =[self verifyName:[attributeDict objectForKey:@"name"] hint:@"static"];
    if (nam) {
	// check for garbage attributes
	for (NSString *key in attributeDict) {
	    if ([key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"n" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
	// create the (degenerate) object
	baseMask = [self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true];
	ECWatchPart *part = [[ECWatchPart alloc] initWithName:nam
							  for:[watchController watch]
						     modeMask:baseMask
					       updateInterval:0
					 updateIntervalOffset:0
						  updateTimer:ECMainTimer
						   masterPart:nil];
	// verify modes match
	
	if (part) {
	    // create view object
	    ECQStaticView *view = (ECQStaticView *)[[ECQStaticView alloc]initForPieces:[self boundsCheckOpt:attributeDict lb:1 ub:255 df:10 name:nam attr:@"n" optional:true]];
	    if (view) {
		// apply windows
		[self applyWindows:view];
		
		// create controller
		ECPartController *ctlr = [[ECVisualController alloc] initWithModel:part
									      view:view
									    master:watchController
									    opaque:false
									  grabPrio:ECGrabPrioDefault
									   envSlot:0  // No GL part, so no need for env slot
								       specialness:ECPartNotSpecial
								  specialParameter:0
                                                                    cornerRelative:false];
		if (ctlr) {
		    [[watchController watch] addPart:part];
		    [ctlr release];
		}
#ifdef FIXFIXFIX
		[view release];
#endif
		// save to use with subsequent pieces
		theBase = view;
	    }
	    [part release];
	}
    }
}

- (void)parserDidStaticEnd {
    [self applyWindows:theBase];
    [theBase finishInit];
    theBase = nil;
}

- (void)parserDidQDialStart:(NSDictionary *)attributeDict {
    //   <QDial	name='dial-u' x='0' y='0' modes='front' radius='132' orientation='upright' tick='tick300' marks='center' markWidth='.5' fontSize='24' fontName='Times New Roman' strokeColor='0xff010101' bgColor='clear' text='12,3,6,9'/>
    
    NSString *nam =[self verifyName:[attributeDict objectForKey:@"name"] hint:@"QDial"];
    if (nam) {
	// check for garbage attributes
	for (NSString *key in attributeDict) {
	    if ([key compare:@"orientation" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"demiTweak" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"bgColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"strokeColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fillColor1" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fillColor2" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"radius" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"radius2" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"clipRadius" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontName" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontSize" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"text" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"tick" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"nMarks" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"mSize" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"angle" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"kind" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"update" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"updateOffset" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"special" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"z" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"thick" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"angle0" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"angle1" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"angle2" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"marks" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"markWidth" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];
		return;
	    }
	}
	
	double fontSize = [self boundsCheckOpt:attributeDict lb:kECminFontSize ub:kECmaxFontSize df:kECdefaultFontSize name:nam attr:@"fontSize" optional:true] * scaler;
	if (theBase) {
	    // create a piece, not a full-fledged part
	    ECQDialView *piece = [[ECQDialView alloc]initWithOrientation:[self qDialTypeCheck:attributeDict df:ECDialOrientationUpright name:nam attr:@"orientation"]
					   xCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
					   yCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler
							  reverseNumbers:false
								  radius:[self boundsCheckOpt:attributeDict lb:kECminRadius ub:rm df:kECdefaultRadius name:nam attr:@"radius" optional:true] * scaler
								 radius2:[self boundsCheckOpt:attributeDict lb:kECminRadius ub:rm df:0 name:nam attr:@"radius2"  optional:true] * scaler
							      clipRadius:[self boundsCheckOpt:attributeDict lb:-rm ub:rm df:rm name:nam attr:@"clipRadius"  optional:true] * scaler
							       demiTweak:[self boundsCheckOpt:attributeDict lb:-fontSize ub:fontSize df:0 name:nam attr:@"demiTweak"  optional:true]
								    text:[self verifyAttr:attributeDict key:@"text" for:nam optional:true]
								    font:[self verifyFont:[attributeDict objectForKey:@"fontName"] size:fontSize for:nam optional:true]
								    tick:[self boundsCheckOpt:attributeDict lb:ECDialTickLB ub:ECDialTickUB df:kECdefaultTickType name:nam attr:@"tick"  optional:true]
								  nMarks:[self boundsCheckOpt:attributeDict lb:0 ub:rm df:0 name:nam attr:@"nMarks" optional:true]
								   mSize:[self boundsCheckOpt:attributeDict lb:0 ub:rm df:0 name:nam attr:@"mSize" optional:true] * scaler
								  angle0:[self boundsCheckOpt:attributeDict lb:0 ub:2*M_PI df:0 name:nam attr:@"angle0" optional:true]
								  angle1:[self boundsCheckOpt:attributeDict lb:0 ub:2*M_PI df:0 name:nam attr:@"angle1" optional:true]
								  angle2:[self boundsCheckOpt:attributeDict lb:0 ub:2*M_PI df:2*M_PI name:nam attr:@"angle2" optional:true]
								   marks:[self boundsCheckOpt:attributeDict lb:ECDiskMarksMaskLB ub:ECDiskMarksMaskUB df:0 name:nam attr:@"marks" optional:true]
							       markWidth:[self boundsCheckOpt:attributeDict lb:0 ub:rm df:1 name:nam attr:@"markWidth" optional:true] * scaler
							      fillColor1:[self colorCheck:attributeDict df:kECdefaultDialColor name:nam attr:@"fillColor1"]
							      fillColor2:[self colorCheck:attributeDict df:kECdefaultDialColor name:nam attr:@"fillColor2"]
							     strokeColor:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"strokeColor"]
								 bgColor:[self colorCheck:attributeDict df:kECdefaultDialColor name:nam attr:@"bgColor"] ]; 
	    [self applyWindows:piece];
	    if ([self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true] != baseMask) {
		[errorDelegate reportError:[NSString stringWithFormat:@"mismatched modes ignored for %@:%@", currentWatchName, nam]];
	    }

	    // attach it to the current base
	    [theBase addPiece:piece];
	    [piece release];
	} else {
	    // create a full standalone part
	    ECWatchModeMask mask = [self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true];
	    // grab the hand angle expression
	    NSString *expr = [self verifyAttr:attributeDict key:@"angle" for:nam];
	    ECWatchHand *part = [[ECWatchHand alloc] initWithName:nam
							 forWatch:[watchController watch]
							 modeMask:mask
							     kind:[self boundsCheckOpt:attributeDict lb:ECHandKindLB ub:ECHandKindUB df:ECNotTimerZeroKind name:nam attr:@"kind" optional:true]
						   updateInterval:[self boundsCheck:attributeDict lb:kECminUpdate ub:kECmaxUpdate df:1 name:nam attr:@"update"]
					     updateIntervalOffset:[self boundsCheckOpt:attributeDict lb:-kECmaxUpdate ub:kECmaxUpdate df:0 name:nam attr:@"updateOffset" optional:true]
						      updateTimer:ECMainTimer
						       masterPart:nil    // FOR NOW
						      angleStream:[[[watchController watch] vm] compileInstructionStreamFromCExpression:expr errorReporter:[ECErrorReporter theErrorReporter]]
						     actionStream:nil
								z:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:0 name:nam attr:@"z" optional:true]
							thickness:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:3 name:nam attr:@"thick" optional:true]
						    xOffsetStream:nil
						    yOffsetStream:nil
						     offsetRadius:0
						offsetAngleStream:nil];
	    if (part) {
		// create view object
		ECQDialView *view = [[ECQDialView alloc]initWithOrientation:[self qDialTypeCheck:attributeDict df:ECDialOrientationUpright name:nam attr:@"orientation"]
					   xCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
					   yCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler
							     reverseNumbers:false
								     radius:[self boundsCheck:attributeDict lb:kECminRadius ub:rm df:kECdefaultRadius name:nam attr:@"radius"] * scaler
								    radius2:[self boundsCheckOpt:attributeDict lb:kECminRadius ub:rm df:0 name:nam attr:@"radius2"  optional:true] * scaler
								 clipRadius:[self boundsCheckOpt:attributeDict lb:-rm ub:rm df:rm name:nam attr:@"clipRadius"  optional:true] * scaler
								  demiTweak:[self boundsCheckOpt:attributeDict lb:-fontSize ub:fontSize df:0 name:nam attr:@"demiTweak"  optional:true]
								       text:[self verifyAttr:attributeDict key:@"text" for:nam optional:true]
								       font:[self verifyFont:[attributeDict objectForKey:@"fontName"] size:fontSize for:nam optional:true]
								       tick:[self boundsCheckOpt:attributeDict lb:ECDialTickLB ub:ECDialTickUB df:kECdefaultTickType name:nam attr:@"tick"  optional:true]
								     nMarks:[self boundsCheckOpt:attributeDict lb:0 ub:rm df:0 name:nam attr:@"nMarks" optional:true]
								      mSize:[self boundsCheckOpt:attributeDict lb:0 ub:rm df:0 name:nam attr:@"mSize" optional:true] * scaler
								     angle0:[self boundsCheckOpt:attributeDict lb:0 ub:2*M_PI df:0 name:nam attr:@"angle0" optional:true]
								     angle1:[self boundsCheckOpt:attributeDict lb:0 ub:2*M_PI df:0 name:nam attr:@"angle1" optional:true]
								     angle2:[self boundsCheckOpt:attributeDict lb:0 ub:2*M_PI df:2*M_PI name:nam attr:@"angle2" optional:true]
								      marks:[self boundsCheckOpt:attributeDict lb:ECDiskMarksMaskLB ub:ECDiskMarksMaskUB df:0 name:nam attr:@"marks" optional:true]
								  markWidth:[self boundsCheckOpt:attributeDict lb:0 ub:rm df:1 name:nam attr:@"markWidth" optional:true] * scaler
								 fillColor1:[self colorCheck:attributeDict df:kECdefaultDialColor name:nam attr:@"fillColor1"]
								 fillColor2:[self colorCheck:attributeDict df:kECdefaultDialColor name:nam attr:@"fillColor2"]
								strokeColor:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"strokeColor"]
								    bgColor:[self colorCheck:attributeDict df:kECdefaultDialColor name:nam attr:@"bgColor"] ];
		if (view) {	
		    // apply windows
		    [self applyWindows:view];
		    
		    // create controller
		    ECPartController *ctlr = [[ECVisualController alloc] initWithModel:part
										  view:view
										master:watchController
										opaque:false
									      grabPrio:ECGrabPrioDefault
									       envSlot:0
									   specialness:[self boundsCheckOpt:attributeDict lb:ECPartSpecialLB ub:ECPartSpecialUB df:ECPartNotSpecial name:nam attr:@"special" optional:true]
								      specialParameter:0
                                                                        cornerRelative:false];
		    if (ctlr) {
			[[watchController watch] addPart:part];
			[ctlr release];
		    }
		    [view release];
		}
		[part release];
	    }
	}
    }
}

- (void)parserDidQWheelStart:(NSDictionary *)attributeDict {
    // <Qwheel name='Qwkdays' x='40' y='-14' kind='minuteKind' modes='front' update='1 * hours()' updateOffset='0' angle='weekdayNumberAngle()' radius='50' radius2='30' tradius='48' orientation='three' marks='inner' markWidth='.125' fontSize='16' fontName='Arial' text='SUN,MON,TUE,WED,THU,FRI,SAT' opaque='0' animate='1' strokeColor='black' bgColor='white' />
    
    if ([self onBase:@"QWheel"])
	return;
    
    NSString *nam;
    nam = [self verifyRefName:[attributeDict objectForKey:@"refName"] hint:@"QWheel"];
    if (nam == nil) {
	nam = [self verifyName:[attributeDict objectForKey:@"name"] hint:@"Qwheel"];
    }
    if (nam) {
	// check for garbage attributes
	for (NSString *key in attributeDict) {
	    if ([key compare:@"orientation" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"angle" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"update" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"updateOffset" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"strokeColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"bgColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"radius" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"radius2" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"tradius" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"radius3" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"tradius3" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontName" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontSize" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontSize3" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"text" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"text3" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animate" options:NSLiteralSearch] == NSOrderedSame||
		[key compare:@"tick" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"nMarks" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"mSize" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"angle2" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"angle1" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"marks" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"markWidth" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"envSlot" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"special" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"dragType" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"dragAnimationType" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animSpeed" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"z" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"thick" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"kind" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"refName" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
	// grab the hand angle expression
	NSString *expr = [self verifyAttr:attributeDict key:@"angle" for:nam];
	if (expr == nil) {
	    return;
	}
	
	// create the object
	double fontSize = [self boundsCheckOpt:attributeDict lb:kECminFontSize ub:kECmaxFontSize df:kECdefaultFontSize name:nam attr:@"fontSize" optional:true] * scaler;
	double fontSize3 = [self boundsCheckOpt:attributeDict lb:kECminFontSize ub:kECmaxFontSize df:fontSize name:nam attr:@"fontSize3" optional:true] * scaler;
	ECWatchHand *part  =  [[ECWatchHand alloc] initWithName:nam
						       forWatch:[watchController watch]
						       modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
							   kind:[self boundsCheckOpt:attributeDict lb:ECHandKindLB ub:ECHandKindUB df:ECNotTimerZeroKind name:nam attr:@"kind" optional:true]
						 updateInterval:[self boundsCheck:attributeDict lb:kECminUpdate ub:kECmaxUpdate df:1 name:nam attr:@"update"]
					   updateIntervalOffset:[self boundsCheckOpt:attributeDict lb:-kECmaxUpdate ub:kECmaxUpdate df:0 name:nam attr:@"updateOffset" optional:true]
						    updateTimer:ECMainTimer
						     masterPart:nil   // FOR NOW
						    angleStream:[[[watchController watch] vm] compileInstructionStreamFromCExpression:expr errorReporter:[ECErrorReporter theErrorReporter]]
						   actionStream:nil
							      z:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:0 name:nam attr:@"z" optional:true]
						      thickness:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:3 name:nam attr:@"thick" optional:true]
						  xOffsetStream:nil
						  yOffsetStream:nil
						   offsetRadius:0
					      offsetAngleStream:nil];
	if (part) {
	    // create view object
	    ECQWheelView *view = [[ECQWheelView alloc]initWithOrientation:[self qWheelTypeCheck:attributeDict df:ECWheelOrientationThree name:nam attr:@"orientation"]
					    xCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
					    yCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler
								   radius:[self boundsCheck:attributeDict lb:kECminRadius ub:rm df:kECdefaultRadius name:nam attr:@"radius"] * scaler
								  radius2:[self boundsCheckOpt:attributeDict lb:kECminRadius ub:rm df:0 name:nam attr:@"radius2" optional:true] * scaler
								  tradius:[self boundsCheckOpt:attributeDict lb:kECminRadius ub:rm df:0 name:nam attr:@"tradius" optional:true] * scaler
								  radius3:[self boundsCheckOpt:attributeDict lb:kECminRadius ub:rm df:0 name:nam attr:@"radius3" optional:true] * scaler
								  tradius3:[self boundsCheckOpt:attributeDict lb:kECminRadius ub:rm df:0 name:nam attr:@"tradius3" optional:true] * scaler
								     text:[self verifyAttr:attributeDict key:@"text" for:nam]
								    text3:[attributeDict objectForKey:@"text3"]
								     font:[self verifyFont:[attributeDict objectForKey:@"fontName"] size:fontSize for:nam]
								    font3:[self verifyFont:[attributeDict objectForKey:@"fontName"] size:fontSize3 for:nam]
								     tick:[self boundsCheckOpt:attributeDict lb:ECDialTickLB ub:ECDialTickUB df:ECDialTickNone name:nam attr:@"tick"  optional:true]
								   nMarks:[self boundsCheckOpt:attributeDict lb:0 ub:360 df:0 name:nam attr:@"nMarks" optional:true]
								    mSize:[self boundsCheckOpt:attributeDict lb:0 ub:480 df:0 name:nam attr:@"mSize" optional:true] * scaler
								   angle1:[self boundsCheckOpt:attributeDict lb:0 ub:2*M_PI df:0 name:nam attr:@"angle1" optional:true]
								   angle2:[self boundsCheckOpt:attributeDict lb:0 ub:2*M_PI df:2*M_PI name:nam attr:@"angle2" optional:true]
								    marks:[self boundsCheckOpt:attributeDict lb:ECDiskMarksMaskLB ub:ECDiskMarksMaskUB df:0 name:nam attr:@"marks" optional:true]
								markWidth:[self boundsCheckOpt:attributeDict lb:0 ub:rm df:1 name:nam attr:@"markWidth" optional:true] * scaler
								 dragType:[self boundsCheckOpt:attributeDict lb:ECDragLB ub:ECDragUB df:ECDragNormal name:nam attr:@"dragType" optional:true]
							dragAnimationType:[self boundsCheckOpt:attributeDict lb:ECDragAnimationLB ub:ECDragAnimationUB df:ECDragAnimationNever name:nam attr:@"dragAnimationType" optional:true]
								animSpeed:[self boundsCheckOpt:attributeDict lb:0 ub:100 df:1 name:nam attr:@"animSpeed" optional:true]
							      strokeColor:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"strokeColor"]
	    							  bgColor:[self colorCheck:attributeDict df:kECdefaultDialColor name:nam attr:@"bgColor"] ];
	    if (view) {	
		// apply windows
		[self applyWindows:view];
		
		// create controller
	        int envSlot = [self boundsCheckOpt:attributeDict lb:0 ub:ECEnvUB df:0 name:nam attr:@"envSlot" optional:true];
		ECPartController *ctlr = [[ECHandController alloc] initWithModel:part view:view master:watchController
									  opaque:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"opaque" optional:true]
									grabPrio:ECGrabPrioDefault
									 envSlot:envSlot
								     specialness:[self boundsCheckOpt:attributeDict lb:ECPartSpecialLB ub:ECPartSpecialUB df:ECPartNotSpecial name:nam attr:@"special" optional:true]
								specialParameter:0
                                                                  cornerRelative:false];
		if (ctlr) {
		    [[watchController watch] addPart:part];
		    [ctlr release];
		}
		[view release];
	    }
	    [part release];
	}
    }
}

- (void)parserDidSWheelStart:(NSDictionary *)attributeDict {
    // <Swheel name='Qwkdays' x='40' y='-14' kind='minuteKind' modes='front' update='1 * hours()' updateOffset='0' angle='weekdayNumberAngle()' radius='50' radius2='30' tradius='48' orientation='three' marks='inner' markWidth='.125' fontSize='16' fontName='Arial' text='SUN,MON,TUE,WED,THU,FRI,SAT' opaque='0' animate='1' strokeColor='black' bgColor='white' />
    // makes a wheel suitable for use behind an aperture by constructing several Qhands with type "spoke"
    if ([self onBase:@"SWheel"])
	return;
    
    NSString *nam;
    nam = [self verifyRefName:[attributeDict objectForKey:@"refName"] hint:@"SWheel"];
    if (nam == nil) {
	nam = [self verifyName:[attributeDict objectForKey:@"name"] hint:@"SWheel"];
    }
    if (nam) {
	// check for garbage attributes
	[self noWindows:nam];
	for (NSString *key in attributeDict) {
	    if ([key compare:@"orientation" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"angle" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"update" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"updateOffset" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"updateTimer" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"strokeColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"bgColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"calendarWeekendColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"radius" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"envSlot" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"fontName" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontSize" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"text" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animate" options:NSLiteralSearch] == NSOrderedSame||
		[key compare:@"dragType" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"dragAnimationType" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animSpeed" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"angle2" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"angle1" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animDir" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"calendar" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"calendarStartDay" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"z" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"kind" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"refName" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
	// grab the various attributes
	ECWatchModeMask modeMask = [self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true];
	ECHandKind kind = [self boundsCheckOpt:attributeDict lb:ECHandKindLB ub:ECHandKindUB df:ECNotTimerZeroKind name:nam attr:@"kind" optional:true];
	double updateInterval = [self boundsCheck:attributeDict lb:kECminUpdate ub:kECmaxUpdate df:1 name:nam attr:@"update"];
	double updateIntervalOffset = [self boundsCheckOpt:attributeDict lb:-kECmaxUpdate ub:kECmaxUpdate df:0 name:nam attr:@"updateOffset" optional:true];
	ECWatchTimerSlot updateTimer = [self boundsCheckOpt:attributeDict lb:ECTimerLB ub:ECTimerUB df:ECMainTimer name:nam attr:@"updateTimer" optional:true];
	ECWheelOrientation orientation = [self qWheelTypeCheck:attributeDict df:ECWheelOrientationThree name:nam attr:@"orientation"];
	double x = [self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler;
	double y = [self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler;
	double radius = [self boundsCheck:attributeDict lb:kECminRadius ub:rm df:kECdefaultRadius name:nam attr:@"radius"] * scaler;		    // top of text in orientationTwelve
	double angle1 = [self boundsCheckOpt:attributeDict lb:0 ub:2*M_PI df:0 name:nam attr:@"angle1" optional:true];
	double angle2 = [self boundsCheckOpt:attributeDict lb:0 ub:2*M_PI df:2*M_PI name:nam attr:@"angle2" optional:true];
	ECCalendarWheelType calendarWheelType = [self boundsCheckOpt:attributeDict lb:ECNotCalendarWheel ub:ECCalendarWheelOct1582 df:ECNotCalendarWheel
                                                                name:nam attr:@"calendar" optional:true];
        bool isCalendarWheel = (calendarWheelType != ECNotCalendarWheel);
        int calendarStartDay = [self boundsCheckOpt:attributeDict lb:0 ub:6 df:0
                                               name:nam attr:@"calendarStartDay" optional:(calendarWheelType == ECNotCalendarWheel)];
        if (isCalendarWheel) {
            radius -= ECCalendarWheelSpokeExtension;  // HACK HACK HACK
        }
	NSString *text = [self verifyAttr:attributeDict key:@"text" for:nam optional:isCalendarWheel];
	ECDragAnimationType dragAnimationType = [self boundsCheckOpt:attributeDict lb:ECDragAnimationLB ub:ECDragAnimationUB df:ECDragAnimationAlways name:nam attr:@"dragAnimationType" optional:true];	    
	ECDragType dragType = [self boundsCheckOpt:attributeDict lb:ECDragLB ub:ECDragUB df:ECDragNormal name:nam attr:@"dragType" optional:true];
	double animSpeed = [self boundsCheckOpt:attributeDict lb:0 ub:100 df:1 name:nam attr:@"animSpeed" optional:true];
	ECAnimationDirection animDir = [self boundsCheckOpt:attributeDict lb:ECAnimationDirLB ub:ECAnimationDirUB df:ECAnimationDirClosest name:nam attr:@"animDir" optional:true];
	UIColor *strokeColor = [self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"strokeColor"];
	UIColor *bgColor = [self colorCheck:attributeDict df:kECdefaultDialColor name:nam attr:@"bgColor"];
        UIColor *calendarWeekendColor = nil;
        NSString *calWEColorSpec = [self verifyAttr:attributeDict key:@"calendarWeekendColor" for:nam optional:!isCalendarWheel];
        if (calWEColorSpec) {
            calendarWeekendColor = [self colorCheck:attributeDict df:[UIColor colorWithRed:0 green:0 blue:1 alpha:1] name:nam attr:@"calendarWeekendColor"];
        }
	double fontSize = [self boundsCheckOpt:attributeDict lb:kECminFontSize ub:kECmaxFontSize df:kECdefaultFontSize name:nam attr:@"fontSize" optional:true] * scaler;
	NSString *fontName = [attributeDict objectForKey:@"fontName"];
	UIFont *font = [self verifyFont:fontName size:fontSize for:nam];
        assert(font);
	bool opaque = [self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"opaque" optional:true];
	NSString *expr = [self verifyAttr:attributeDict key:@"angle" for:nam];
	if (expr == nil || (text == nil && !isCalendarWheel)) {
	    return;
	}

        EBVMInstructionStream *xOffsetStream = nil;
        EBVMInstructionStream *yOffsetStream = nil;

	// split up the text into the labels for each "spoke"
	NSArray *labels;
        double maxW = 0, maxH = 0;
        if (isCalendarWheel) {
            animSpeed = -animSpeed;  // Hack meaning don't animate linear motion
            NSMutableArray *mLabels = [NSMutableArray arrayWithCapacity:4];
            NSString *exprY = [NSString stringWithFormat:@"calendarWeekdayStart() == %d ? 0 : -100", calendarStartDay];
            yOffsetStream = [[[watchController watch] vm] compileInstructionStreamFromCExpression:exprY errorReporter:[ECErrorReporter theErrorReporter]];
            if (calendarWheelType == ECCalendarWheelOct1582) {
                [mLabels addObject:[NSString stringWithFormat:@"%%%%Calendar%%%%%d", calendarStartDay + 9]];  // Hack meaning October 1582, week starts on Sunday
                [mLabels addObject:@"%%Calendar%%8"];  // Hack meaning blank
                [mLabels addObject:@"%%Calendar%%8"];  // Hack meaning blank
                [mLabels addObject:@"%%Calendar%%8"];  // Hack meaning blank
                //[mLabels addObject:@"%%Calendar%%9"];  // Hack meaning October 1582, week starts on Sunday
                //[mLabels addObject:@"%%Calendar%%10"];  // Hack meaning October 1582, week starts on Monday
                //[mLabels addObject:@"%%Calendar%%15"];  // Hack meaning October 1582, week starts on Saturday
            } else if (calendarWheelType == ECCalendarWheel012B) {
                for (int d = 0; d < 3; d++) {
                    NSString *lab = [NSString stringWithFormat:@"%%%%Calendar%%%%%d", d];
                    //printf("Adding label %s to array\n", [lab UTF8String]);
                    [mLabels addObject:lab];
                }
                [mLabels addObject:@"%%Calendar%%8"];  // Hack meaning blank
            } else {
                assert(calendarWheelType == ECCalendarWheel3456);
                for (int d = 3; d < 7; d++) {
                    NSString *lab = [NSString stringWithFormat:@"%%%%Calendar%%%%%d", d];
                    //printf("Adding label %s to array\n", [lab UTF8String]);
                    [mLabels addObject:lab];
                }
            }
            labels = mLabels;
        } else {
            labels = [text componentsSeparatedByString:@","];
            // compute the maximum sizes
            for (NSString *lab in labels) {
                // Deprecated iOS 7:  CGSize labSize = [lab sizeWithFont: font];
                CGSize labSize = [lab sizeWithAttributes:@{NSFontAttributeName:font}];
                maxW = fmax(maxW, labSize.width);
                maxH = fmax(maxH, labSize.height);
            }
        }
        int n = [labels count];
        assert (n > 0);

	// angle expressions are the same for all spokes
	NSString *angleExpr = nil;
	switch (orientation) {
	    case ECWheelOrientationTwelve:	angleExpr=@" 0";    break;
	    case ECWheelOrientationThree:	angleExpr=@"-pi/2"; break;
	    case ECWheelOrientationSix:		angleExpr=@"-pi";   break;
	    case ECWheelOrientationNine:	angleExpr=@" pi/2"; break;
	    default:					    assert(false);
	}

	// create the Qhands
	int i;
	//printf("\nSWheel:\n");
	ECWatchHand *masterPart = nil;
	for (i=0; i<n; i++) {
	    // fix up the angle expr
	    NSString *offsetAngleExpr;
	    EBVMInstructionStream *angleStream;
	    if (i == 0) {
		if (angle1 != 0) {
		    offsetAngleExpr = [NSString stringWithFormat:@"(%@) - (%@) - %.9f", expr, angleExpr, angle1];
		} else {
		    offsetAngleExpr = [NSString stringWithFormat:@"(%@) - (%@)", expr, angleExpr];
		}
		angleStream = [[[watchController watch] vm] compileInstructionStreamFromCExpression:angleExpr errorReporter:[ECErrorReporter theErrorReporter]];
	    } else {
                if (isCalendarWheel) {
                    offsetAngleExpr = [NSString stringWithFormat:@"calendarWeekdayStart() == %d ? %.9f : 0", calendarStartDay, -i * (angle2-angle1) / n];
                } else {
                    offsetAngleExpr = [NSString stringWithFormat:@"%.9f", -i * (angle2-angle1) / n];
                }
		angleStream = nil;
	    }
	    //printf("%d : %s\n", i, [offsetAngleExpr UTF8String]);

	    // adjust the radius
	    double thisRad = 0;
	    switch (orientation) {
		case ECWheelOrientationTwelve:	thisRad = radius - maxH/2; break;
		case ECWheelOrientationThree:	thisRad = radius - maxW/2;  break;
		case ECWheelOrientationSix:	thisRad = radius - maxH/2; break;
		case ECWheelOrientationNine:	thisRad = radius - maxW/2;  break;
		default:					    assert(false);
	    }

            double z;
            NSString *partName;

            NSString *thisLabel = [labels objectAtIndex:i];
            if ([thisLabel compare:@"%%Calendar%%8"] == NSOrderedSame) {
                partName = [NSString stringWithFormat:@"BlankCalendarSWheelSlot-%x", (unsigned int)modeMask];
                z = 0;
            } else {
                partName = [nam stringByAppendingFormat:@"-%d", i];
                z = [self boundsCheckOpt:attributeDict lb:0 ub:10 df:0 name:nam attr:@"z" optional:true];
            }

	    // create the object
	    ECWatchHand *part  =  [[ECWatchHand alloc] initWithName:partName
							   forWatch:[watchController watch]
							   modeMask:modeMask
							       kind:kind
						     updateInterval:updateInterval
					       updateIntervalOffset:updateIntervalOffset
							updateTimer:updateTimer
							 masterPart:masterPart
							angleStream:angleStream
						       actionStream:nil
								  z:z
							  thickness:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:3 name:nam attr:@"thick" optional:true]
						      xOffsetStream:xOffsetStream
						      yOffsetStream:yOffsetStream
						       offsetRadius:thisRad
						  offsetAngleStream:[[[watchController watch] vm] compileInstructionStreamFromCExpression:offsetAngleExpr errorReporter:[ECErrorReporter theErrorReporter]]];
	    if (i == 0) {
		masterPart = part;
	    }
	    if (part) {
		// create view object
		ECQHandView *view = [[ECQHandView alloc]initWithType:ECQHandSpoke
				       xAnchorOffsetFromScreenCenter:x
				       yAnchorOffsetFromScreenCenter:y
							       width:kECdefaultHandWidth
							      oWidth:kECdefaultHandWidth
							      length:kECdefaultHandLength
							     length2:0
								text:[labels objectAtIndex:i]
								font:font
                                                   calendarWheelType:calendarWheelType
                                                    calendarStartDay:calendarStartDay
							     oLength:0
								tail:0
							       oTail:0
							     oCenter:0
							       nRays:0
							   animSpeed:animSpeed
							     animDir:animDir
							    dragType:dragType
						   dragAnimationType:dragAnimationType
							     oRadius:0
							    oRadiusX:0
							   lineWidth:0.25 * scaler
							  oLineWidth:0
							      scolor:strokeColor
							      fcolor:strokeColor
							     oscolor:calendarWeekendColor
							     ofcolor:bgColor
                                                          tLineWidth:0
							     tscolor:calendarWeekendColor
							     tfcolor:bgColor
							     blender:nil
							   blender2x:nil
                                                           blender4x:nil];
		if (view) {
		    // create controller
		    int envSlot = [self boundsCheckOpt:attributeDict lb:0 ub:ECEnvUB df:0 name:nam attr:@"envSlot" optional:true];
		    ECPartController *ctlr = [[ECHandController alloc] initWithModel:part view:view master:watchController
									      opaque:opaque
									    grabPrio:ECGrabPrioDefault
									     envSlot:envSlot
									 specialness:[self boundsCheckOpt:attributeDict lb:ECPartSpecialLB ub:ECPartSpecialUB df:ECPartNotSpecial name:nam attr:@"special" optional:true]
								    specialParameter:0
                                                                      cornerRelative:false];
		    if (ctlr) {
			[[watchController watch] addPart:part];
			[ctlr release];
		    }
		    [view release];
		}
		if (i != 0) {	    // don't release the masterPart
		    [part release];
		}
	    }
	}
	[masterPart release];
    }
}

- (void)parserDidTWheelStart:(NSDictionary *)attributeDict {
    // <Swheel name='Qwkdays' x='40' y='-14' kind='minuteKind' modes='front' update='1 * hours()' updateOffset='0' angle='weekdayNumberAngle()' radius='50' radius2='30' tradius='48' orientation='three' marks='inner' markWidth='.125' fontSize='16' fontName='Arial' text='SUN,MON,TUE,WED,THU,FRI,SAT' opaque='0' animate='1' strokeColor='black' bgColor='white' />
    // makes a wheel suitable for use behind an aperture by constructing several Qhands with type "spoke"
    if ([self onBase:@"TWheel"])
	return;
    
    NSString *nam;
    nam = [self verifyRefName:[attributeDict objectForKey:@"refName"] hint:@"TWheel"];
    if (nam == nil) {
	nam = [self verifyName:[attributeDict objectForKey:@"name"] hint:@"TWheel"];
    }
    if (nam) {
	// check for garbage attributes
	[self noWindows:nam];
	for (NSString *key in attributeDict) {
	    if ([key compare:@"orientation" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"angle" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"update" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"updateOffset" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"updateTimer" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"strokeColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"bgColor2" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"bgColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"radius" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontName" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontSize" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"text" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animate" options:NSLiteralSearch] == NSOrderedSame||
		[key compare:@"dragType" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"dragAnimationType" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animSpeed" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"angle2" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"angle1" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"envSlot" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"special" options:NSLiteralSearch] == NSOrderedSame ||
//		[key compare:@"animDir" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"ticks" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"tickWidth" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"borderWidth" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"kind" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"refName" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"action" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"halfAndHalf" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
	// grab the various attributes
	ECWatchModeMask modeMask = [self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true];
	ECHandKind kind = [self boundsCheckOpt:attributeDict lb:ECHandKindLB ub:ECHandKindUB df:ECNotTimerZeroKind name:nam attr:@"kind" optional:true];
	double updateInterval = [self boundsCheck:attributeDict lb:kECminUpdate ub:kECmaxUpdate df:1 name:nam attr:@"update"];
	double updateIntervalOffset = [self boundsCheckOpt:attributeDict lb:-kECmaxUpdate ub:kECmaxUpdate df:0 name:nam attr:@"updateOffset" optional:true];
	ECWatchTimerSlot updateTimer = [self boundsCheckOpt:attributeDict lb:ECTimerLB ub:ECTimerUB df:ECMainTimer name:nam attr:@"updateTimer" optional:true];
	ECWheelOrientation orientation = [self qWheelTypeCheck:attributeDict df:ECWheelOrientationThree name:nam attr:@"orientation"];
	double x = [self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler;
	double y = [self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler;
	double thickness = [self boundsCheckOpt:attributeDict lb:0 ub:10 df:3 name:nam attr:@"thick" optional:true];
	double tickWidth = [self boundsCheckOpt:attributeDict lb:0 ub:10 df:0 name:nam attr:@"tickWidth" optional:true];
	double borderWidth = [self boundsCheckOpt:attributeDict lb:0 ub:10 df:0 name:nam attr:@"borderWidth" optional:true];
	double ticks = [self boundsCheckOpt:attributeDict lb:0 ub:100 df:0 name:nam attr:@"ticks" optional:true];
	double radius = [self boundsCheck:attributeDict lb:kECminRadius ub:rm df:kECdefaultRadius name:nam attr:@"radius"] * scaler;		    // top of text in orientationTwelve
	double angle1 = [self boundsCheckOpt:attributeDict lb:0 ub:2*M_PI df:0 name:nam attr:@"angle1" optional:true];
	double angle2 = [self boundsCheckOpt:attributeDict lb:0 ub:2*M_PI df:2*M_PI name:nam attr:@"angle2" optional:true];
	NSString *text = [self verifyAttr:attributeDict key:@"text" for:nam];
	ECDragAnimationType dragAnimationType = [self boundsCheckOpt:attributeDict lb:ECDragAnimationLB ub:ECDragAnimationUB df:ECDragAnimationAlways name:nam attr:@"dragAnimationType" optional:true];	    
	ECDragType dragType = [self boundsCheckOpt:attributeDict lb:ECDragLB ub:ECDragUB df:ECDragNormal name:nam attr:@"dragType" optional:true];
	double animSpeed = [self boundsCheckOpt:attributeDict lb:0 ub:100 df:1 name:nam attr:@"animSpeed" optional:true];
//	ECAnimationDirection animDir = [self boundsCheckOpt:attributeDict lb:ECAnimationDirLB ub:ECAnimationDirUB df:ECAnimationDirClosest name:nam attr:@"animDir" optional:true];
	UIColor *strokeColor = [self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"strokeColor"];
	UIColor *bgColor = [self colorCheck:attributeDict df:[UIColor clearColor]  name:nam attr:@"bgColor"];
	UIColor *bgColor2 = [self colorCheck:attributeDict df:bgColor name:nam attr:@"bgColor2"];
	double fontSize = [self boundsCheckOpt:attributeDict lb:kECminFontSize ub:kECmaxFontSize df:kECdefaultFontSize name:nam attr:@"fontSize" optional:true] * scaler;
	NSString *fontName = [attributeDict objectForKey:@"fontName"];
	UIFont *font = [self verifyFont:fontName size:fontSize for:nam];
	bool opaque = [self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"opaque" optional:true];
	bool halfAndHalf = [self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"halfAndHalf" optional:true];
	NSString *expr = [self verifyAttr:attributeDict key:@"angle" for:nam];
	if (expr == nil || text == nil) {
	    return;
	}

	// split up the text into the labels for each "spoke"
	NSArray *labels = [text componentsSeparatedByString:@","];
	int n = [labels count];
	assert (n > 0);
	// compute the maximum sizes
	double maxW = 0, maxH = 0;
	for (NSString *lab in labels) {
	    // Deprecated iOS 7:  CGSize labSize = [lab sizeWithFont: font];
            CGSize labSize = [lab sizeWithAttributes:@{NSFontAttributeName:font}];
	    maxW = fmax(maxW, labSize.width);
	    maxH = fmax(maxH, labSize.height);
	}

	// adjust the radii
	double inRad, outRad;
	switch (orientation) {
	    case ECWheelOrientationThree:
	    case ECWheelOrientationNine:    outRad = radius;	inRad = radius - maxW;  break;
	    case ECWheelOrientationSix:
	    case ECWheelOrientationTwelve:  outRad = radius;	inRad = radius - maxH;	break;
	    default:			    assert(false);   outRad = 0; inRad = 0;
	}
	    
	// angle expressions are the same for all spokes
	NSString *angleExpr = nil;
	switch (orientation) {
	    case ECWheelOrientationTwelve:	angleExpr=@" 0";    break;
	    case ECWheelOrientationThree:	angleExpr=@"-pi/2"; break;
	    case ECWheelOrientationSix:		angleExpr=@"-pi";   break;
	    case ECWheelOrientationNine:	angleExpr=@" pi/2"; break;
	    default:					    assert(false);
	}
	
	NSString *expr3 = [self verifyAttr:attributeDict key:@"action" for:nam optional:true];
	EBVMInstructionStream *s3 = nil;
	if (expr3 != nil) {
	    s3 = [[[watchController watch] vm] compileInstructionStreamFromCExpression:expr3 errorReporter:[ECErrorReporter theErrorReporter]];
	}
	
	// create the Qhands
	int i;
	//printf("\nTWheel:\n");
	ECWatchHand *masterPart = nil;
	for (i=0; i<n; i++) {
	    // fix up the angle expr
	    NSString *offsetAngleExpr;
	    EBVMInstructionStream *angleStream;
	    if (i == 0) {
		if (angle1 != 0) {
		    offsetAngleExpr = [NSString stringWithFormat:@"(%@) - (%@) - %.9f", expr, angleExpr, angle1];
		} else {
		    offsetAngleExpr = [NSString stringWithFormat:@"(%@) - (%@)", expr, angleExpr];
		}
	    } else {
		offsetAngleExpr = [NSString stringWithFormat:@"%.9f", -i * (angle2-angle1) / n];
		angleStream = nil;
	    }
	    //printf("%d : %s\n", i, [offsetAngleExpr UTF8String]);

	    // create the object
	    ECWatchHand *part  =  [[ECWatchHand alloc] initWithName:[nam stringByAppendingFormat:@"-%d", i]
							   forWatch:[watchController watch]
							   modeMask:modeMask
							       kind:kind
						     updateInterval:updateInterval
					       updateIntervalOffset:updateIntervalOffset
							updateTimer:updateTimer
							 masterPart:masterPart
							angleStream:[[[watchController watch] vm] compileInstructionStreamFromCExpression:offsetAngleExpr errorReporter:[ECErrorReporter theErrorReporter]]
						       actionStream:s3
								  z:0
							  thickness:thickness
						      xOffsetStream:nil
						      yOffsetStream:nil
						       offsetRadius:0
						  offsetAngleStream:nil];
	    if (i == 0) {
		masterPart = part;
	    }
	    if (part) {
		// create view object
		ECQWedgeHandView *view = [[ECQWedgeHandView alloc]initWithOuterRadius:outRad
							xAnchorOffsetFromScreenCenter:x
							yAnchorOffsetFromScreenCenter:y
									  innerRadius:inRad
									    angleSpan:2*M_PI/n
									    animSpeed:animSpeed
									     dragType:dragType
								    dragAnimationType:dragAnimationType
									       scolor:strokeColor
									       fcolor:(halfAndHalf && (i < n/4 || i >= 3*n/4)) ? bgColor  : bgColor2
									      fcolor2:(halfAndHalf && (i < n/4 || i >= 3*n/4)) ? bgColor2 : bgColor
										 font:font
										 text:[labels objectAtIndex:i]
									  orientation:orientation
										ticks:ticks
									    tickWidth:tickWidth
									  borderWidth:borderWidth
									  halfAndHalf:halfAndHalf && (i == n/4 || i == 3*n/4)];
		if (view) {
		    // create controller
		    int envSlot = [self boundsCheckOpt:attributeDict lb:0 ub:ECEnvUB df:0 name:nam attr:@"envSlot" optional:true];
		    ECPartController *ctlr = [[ECHandController alloc] initWithModel:part view:view master:watchController
									      opaque:opaque
									    grabPrio:ECGrabPrioDefault
									     envSlot:envSlot
									 specialness:[self boundsCheckOpt:attributeDict lb:ECPartSpecialLB ub:ECPartSpecialUB df:ECPartNotSpecial name:nam attr:@"special" optional:true]
								    specialParameter:0
                                                                      cornerRelative:false];
		    if (ctlr) {
			[[watchController watch] addPart:part];
			[ctlr release];
		    }
		    [view release];
		}
		if (i != 0) {	    // don't release the masterPart
		    [part release];
		}
	    }
	}
	[masterPart release];
    }
}

- (void)parserDidQtextStart:(NSDictionary *)attributeDict {
    // <Qtext	name='set' x=' 15' y='-72' fontSize='8'	fontName='Arial' modes='front' text='Coucher' strokeColor='blue'/>

    NSString *nam =[self verifyName:[attributeDict objectForKey:@"name"] hint:@"Qtext"];
    if (nam) {
	// check for garbage attributes
	[self noWindows:nam];
	for (NSString *key in attributeDict) {
	    if ([key compare:@"text" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"cropBottom" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"cropTop" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"radius" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"startAngle" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"orientation" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontName" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontSize" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"strokeColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}

	if (theBase) {
	    // create a piece, not a full-fledged part
	    double fontSize = [self boundsCheckOpt:attributeDict lb:kECminFontSize ub:kECmaxFontSize df:kECdefaultFontSize name:nam attr:@"fontSize" optional:true] * scaler;
	    ECQTextView *piece = [[ECQTextView alloc]initCenteredWithText:[self verifyAttr:attributeDict key:@"text" for:nam] 
					    xCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
					    yCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler
							       cropBottom:[self boundsCheckOpt:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"cropBottom" optional:true] * scaler
								  cropTop:[self boundsCheckOpt:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"cropTop" optional:true] * scaler
								   radius:[self boundsCheckOpt:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"radius" optional:true] * scaler
								    angle:[self boundsCheckOpt:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"startAngle" optional:true]
                                                                animSpeed:1.0
							      orientation:[self qDialTypeCheck:attributeDict df:ECDialOrientationRadial name:nam attr:@"orientation"]
								     font:[self verifyFont:[attributeDict objectForKey:@"fontName"] size:fontSize for:nam]
								    color:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"strokeColor"] ]; 
	    if ([self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true] != baseMask) {
		[errorDelegate reportError:[NSString stringWithFormat:@"mismatched modes ignored for %@:%@", currentWatchName, nam]];
	    }
	    
	    // attach it to the current base
	    [theBase addPiece:piece];
	    [piece release];
	} else {
	    // create a full standalone part
	    ECWatchPart *part = [[ECWatchPart alloc] initWithName:nam
							  for:[watchController watch]
						     modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
					       updateInterval:0
					 updateIntervalOffset:0
						  updateTimer:ECMainTimer
					           masterPart:nil];
	    if (part) {
		// create view object
		double fontSize = [self boundsCheckOpt:attributeDict lb:kECminFontSize ub:kECmaxFontSize df:kECdefaultFontSize name:nam attr:@"fontSize" optional:true];
		ECQView *view = [[ECQTextView alloc]initCenteredWithText:[self verifyAttr:attributeDict key:@"text" for:nam] 
					   xCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
					   yCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler
							      cropBottom:[self boundsCheckOpt:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"cropBottom" optional:true] * scaler
								 cropTop:[self boundsCheckOpt:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"cropTop" optional:true] * scaler
								  radius:[self boundsCheckOpt:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"radius" optional:true] * scaler
								   angle:[self boundsCheckOpt:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"startAngle" optional:true]
                                                               animSpeed:1.0
							     orientation:[self qDialTypeCheck:attributeDict df:ECDialOrientationRadial name:nam attr:@"orientation"]
								    font:[self verifyFont:[attributeDict objectForKey:@"fontName"] size:fontSize for:nam]
								   color:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"strokeColor"] ];
		if (view) {
		    // create controller
		    ECPartController *ctlr = [[ECVisualController alloc] initWithModel:part
										  view:view
										master:watchController
										opaque:false
									      grabPrio:ECGrabPrioDefault
									       envSlot:0
									   specialness:[self boundsCheckOpt:attributeDict lb:ECPartSpecialLB ub:ECPartSpecialUB df:ECPartNotSpecial name:nam attr:@"special" optional:true]
								      specialParameter:0
                                                                        cornerRelative:false];
		    if (ctlr) {
			[[watchController watch] addPart:part];
			[ctlr release];
		    }
		    [view release];
		}
		[part release];
	    }
	}
    }
}

- (void)parserDidQHandStart:(NSDictionary *)attributeDict {
    // <Qhand name='qhr' x=' 0' y=' 0' kind='minuteKind' modes='all' type='tri' length=' 80' length2='0' width='5' tail='20' update='60' angle='hour12ValueAngle()' strokeColor='black' fillColor='clear' opaque='0' animate='1'/>
    
    if ([self onBase:@"QHand"])
	return;
    
    NSString *nam;
    nam = [self verifyRefName:[attributeDict objectForKey:@"refName"] hint:@"Qhand"];
    if (nam == nil) {
	nam = [self verifyName:[attributeDict objectForKey:@"name"] hint:@"Qhand"];
    }
    if (nam) {
	// check for garbage attributes
//	[self noWindows:nam];
	for (NSString *key in attributeDict) {
	    if ([key compare:@"type" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"angle" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"update" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"updateOffset" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"updateTimer" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"strokeColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fillColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"length" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"length2" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"text" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontName" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontSize" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"oLength" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"oWidth" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"oCenter" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"oTail" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"lineWidth" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"nRays" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"oRadius" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"oRadiusX" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"oLineWidth" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"oStrokeColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"oFillColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"tLineWidth" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"tStrokeColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"tFillColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"opaque" options:NSLiteralSearch] == NSOrderedSame||
		[key compare:@"animate" options:NSLiteralSearch] == NSOrderedSame||
		[key compare:@"dragType" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"dragAnimationType" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"tail" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"width" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"xMotion" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"yMotion" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"z" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"thick" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"kind" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animSpeed" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animDir" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"grabPrio" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"envSlot" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"special" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"input" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"offsetAngle" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"offsetRadius" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"tipRadius" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"rimOuterRadius" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"rimInnerRadius" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"hubRadius" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"leafRadius" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"nTeeth" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"nLeaves" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"nSpokes" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"overlay" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"refName" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
	// grab the hand angle expressions
	NSString *expr = [self verifyAttr:attributeDict key:@"angle" for:nam];
	if (expr == nil) {
	    return;
	}
	NSString *expr2 = [self verifyAttr:attributeDict key:@"offsetAngle" for:nam optional:true];
	EBVMInstructionStream *s2 = nil;
	if (expr2 != nil) {
	    s2 = [[[watchController watch] vm] compileInstructionStreamFromCExpression:expr2 errorReporter:[ECErrorReporter theErrorReporter]];
	}
        EBVMInstructionStream *xOffsetStream = nil;
        NSString *exprX = [self verifyAttr:attributeDict key:@"xMotion" for:nam optional:true];
        if (exprX != nil) {
            xOffsetStream = [[[watchController watch] vm] compileInstructionStreamFromCExpression:exprX errorReporter:[ECErrorReporter theErrorReporter]];
        }
        EBVMInstructionStream *yOffsetStream = nil;
        NSString *exprY = [self verifyAttr:attributeDict key:@"yMotion" for:nam optional:true];
        if (exprY != nil) {
            yOffsetStream = [[[watchController watch] vm] compileInstructionStreamFromCExpression:exprY errorReporter:[ECErrorReporter theErrorReporter]];
        }
	
	// create the object
	ECWatchHand *part  =  [[ECWatchHand alloc] initWithName:nam
						       forWatch:[watchController watch]
						       modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
							   kind:[self boundsCheckOpt:attributeDict lb:ECHandKindLB ub:ECHandKindUB df:ECNotTimerZeroKind name:nam attr:@"kind" optional:true]
						 updateInterval:[self boundsCheck:attributeDict lb:-kECminUpdate ub:kECmaxUpdate df:1 name:nam attr:@"update"]
					   updateIntervalOffset:[self boundsCheckOpt:attributeDict lb:-kECmaxUpdate ub:kECmaxUpdate df:0 name:nam attr:@"updateOffset" optional:true]
						    updateTimer:[self boundsCheckOpt:attributeDict lb:ECTimerLB ub:ECTimerUB df:ECMainTimer name:nam attr:@"updateTimer" optional:true]
						     masterPart:nil  // FOR NOW
						    angleStream:[[[watchController watch] vm] compileInstructionStreamFromCExpression:expr errorReporter:[ECErrorReporter theErrorReporter]]
						   actionStream:nil
							      z:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:0 name:nam attr:@"z" optional:true]
						      thickness:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:3 name:nam attr:@"thick" optional:true]
						  xOffsetStream:xOffsetStream
						  yOffsetStream:yOffsetStream
						   offsetRadius:[self boundsCheckOpt:attributeDict lb:-rm ub:rm df:0 name:nam attr:@"offsetRadius" optional:true] * scaler
					      offsetAngleStream:s2];
	if (part) {
	    // create view object
	    double fontSize = [self boundsCheckOpt:attributeDict lb:kECminFontSize ub:kECmaxFontSize df:kECdefaultFontSize name:nam attr:@"fontSize" optional:true] * scaler;
	    double typ = [self qHandTypeCheck:attributeDict df:ECQHandTri name:nam attr:@"type"];
	    ECQHandView *view;
	    UIImage *image2x=nil;
	    UIImage *image4x=nil;
	    UIImage *image = [self verifyImageFile:[attributeDict objectForKey:@"overlay"] for:nam optional:true image2x:&image2x image4x:&image4x];
            double oLineWidth = [self boundsCheckOpt:attributeDict lb:0 ub:20 df:0 name:nam attr:@"oLineWidth" optional:true] * scaler;
            UIColor *osColor = [self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"oStrokeColor"];
            UIColor *ofColor = [self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"oFillColor"];
            double tLineWidth = [self boundsCheckOpt:attributeDict lb:0 ub:20 df:oLineWidth/scaler name:nam attr:@"tLineWidth" optional:true] * scaler;
            UIColor *tsColor = [self colorCheck:attributeDict df:osColor name:nam attr:@"tStrokeColor"];
            UIColor *tfColor = [self colorCheck:attributeDict df:ofColor name:nam attr:@"tFillColor"];
	    if (typ == ECQHandGear) {
		double rad = [self boundsCheck:attributeDict lb:kECminHandLength ub:rm df:kECdefaultHandLength name:nam attr:@"tipRadius"];
		view = [[ECQHandView alloc]initWithType:typ
				       xAnchorOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
				       yAnchorOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler
							       width:rad * scaler
							      oWidth:[self boundsCheckOpt:attributeDict lb:kECminHandLength ub:rm df:rad*.9 name:nam attr:@"rimOuterRadius" optional:true] * scaler
							      length:[self boundsCheckOpt:attributeDict lb:0 ub:rad df:rad*.8 name:nam attr:@"rimInnerRadius" optional:true] * scaler
							     length2:[self boundsCheckOpt:attributeDict lb:0 ub:rad df:rad*.20 name:nam attr:@"hubRadius" optional:true] * scaler
								text:nil
								font:nil
                                                   calendarWheelType:ECNotCalendarWheel
                                                    calendarStartDay:0
							     oLength:[self boundsCheckOpt:attributeDict lb:0 ub:rad  df:rad*.15 name:nam attr:@"leafRadius" optional:true] * scaler
								tail:[self boundsCheck:attributeDict lb:0 ub:500 df:100 name:nam attr:@"nTeeth"]
							       oTail:[self boundsCheck:attributeDict lb:0 ub:50 df:10 name:nam attr:@"nLeaves"]
							     oCenter:[self boundsCheckOpt:attributeDict lb:0 ub:16 df:3 name:nam attr:@"nSpokes" optional:true]
							       nRays:0
							   animSpeed:[self boundsCheckOpt:attributeDict lb:0 ub:100 df:1 name:nam attr:@"animSpeed" optional:true]
							     animDir:[self boundsCheckOpt:attributeDict lb:ECAnimationDirLB ub:ECAnimationDirUB df:ECAnimationDirClosest name:nam attr:@"animDir" optional:true]
				                            dragType:[self boundsCheckOpt:attributeDict lb:ECDragLB ub:ECDragUB df:ECDragNormal name:nam attr:@"dragType" optional:true]
				          	   dragAnimationType:[self boundsCheckOpt:attributeDict lb:ECDragAnimationLB ub:ECDragAnimationUB df:ECDragAnimationNever name:nam attr:@"dragAnimationType" optional:true]
							     oRadius:0
							    oRadiusX:0
							   lineWidth:[self boundsCheckOpt:attributeDict lb:0 ub:20 df:0 name:nam attr:@"lineWidth" optional:true] * scaler
							  oLineWidth:oLineWidth
							      scolor:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"strokeColor"]
							      fcolor:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"fillColor"]
							     oscolor:osColor
							     ofcolor:ofColor
                                                          tLineWidth:tLineWidth
							     tscolor:tsColor
							     tfcolor:tfColor
							     blender:image
							   blender2x:image2x
                                                           blender4x:image4x];
		
	    } else {
		double len = [self boundsCheckOpt:attributeDict lb:kECminHandLength ub:rm df:kECdefaultHandLength name:nam attr:@"length" optional:true];
		view = [[ECQHandView alloc]initWithType:typ
				       xAnchorOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
				       yAnchorOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler
							       width:[self boundsCheckOpt:attributeDict lb:kECminHandWidth ub:kECmaxHandWidth df:kECdefaultHandWidth name:nam attr:@"width" optional:true] * scaler
							      oWidth:[self boundsCheckOpt:attributeDict lb:-kECmaxHandWidth ub:kECmaxHandWidth df:kECdefaultHandWidth name:nam attr:@"oWidth" optional:true] * scaler
							      length:len * scaler
							     length2:[self boundsCheckOpt:attributeDict lb:-len ub:len df:0 name:nam attr:@"length2" optional:true] * scaler
								text:[attributeDict objectForKey:@"text"]
								font:[self verifyFont:[attributeDict objectForKey:@"fontName"] size:fontSize for:nam optional:true]
                                                   calendarWheelType:ECNotCalendarWheel
                                                    calendarStartDay:0
							     oLength:[self boundsCheckOpt:attributeDict lb:0 ub:rm  df:0 name:nam attr:@"oLength" optional:true] * scaler
								tail:[self boundsCheckOpt:attributeDict lb:-rm ub:rm df:ceil(len/10) name:nam attr:@"tail" optional:true] * scaler
							       oTail:[self boundsCheckOpt:attributeDict lb:-rm ub:rm df:0 name:nam attr:@"oTail" optional:true] * scaler
							     oCenter:[self boundsCheckOpt:attributeDict lb:-rm ub:rm df:0 name:nam attr:@"oCenter" optional:true] * scaler
							       nRays:[self boundsCheckOpt:attributeDict lb:0 ub:360 df:0 name:nam attr:@"nRays" optional:true]
							   animSpeed:[self boundsCheckOpt:attributeDict lb:0 ub:100 df:1 name:nam attr:@"animSpeed" optional:true]
							     animDir:[self boundsCheckOpt:attributeDict lb:ECAnimationDirLB ub:ECAnimationDirUB df:ECAnimationDirClosest name:nam attr:@"animDir" optional:true]
							    dragType:[self boundsCheckOpt:attributeDict lb:ECDragLB ub:ECDragUB df:ECDragNormal name:nam attr:@"dragType" optional:true]
				                   dragAnimationType:[self boundsCheckOpt:attributeDict lb:ECDragAnimationLB ub:ECDragAnimationUB df:ECDragAnimationNever name:nam attr:@"dragAnimationType" optional:true]	    
							     oRadius:[self boundsCheckOpt:attributeDict lb:0 ub:rm df:0 name:nam attr:@"oRadius" optional:true] * scaler
							    oRadiusX:[self boundsCheckOpt:attributeDict lb:0 ub:rm df:0 name:nam attr:@"oRadiusX" optional:true] * scaler
							   lineWidth:[self boundsCheckOpt:attributeDict lb:0 ub:20 df:0 name:nam attr:@"lineWidth" optional:true] * scaler
							  oLineWidth:oLineWidth
							      scolor:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"strokeColor"]
							      fcolor:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"fillColor"]
							     oscolor:osColor
							     ofcolor:ofColor
                                                          tLineWidth:tLineWidth
							     tscolor:tsColor
							     tfcolor:tfColor
							     blender:image
							   blender2x:image2x
                                                           blender4x:image4x];
	    }
	    if (view) {
		[self applyWindows:view];

		// create controller
		ECPartController *ctlr = [[ECHandController alloc] initWithModel:part view:view master:watchController
									  opaque:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"opaque"  optional:true]
									grabPrio:[self boundsCheckOpt:attributeDict lb:ECGrabPrioLB ub:ECGrabPrioUB df:ECGrabPrioDefault name:nam attr:@"grabPrio" optional:true]
									 envSlot:[self boundsCheckOpt:attributeDict lb:0 ub:ECEnvUB df:0 name:nam attr:@"envSlot" optional:true]
								     specialness:[self boundsCheckOpt:attributeDict lb:ECPartSpecialLB ub:ECPartSpecialUB df:ECPartNotSpecial name:nam attr:@"special" optional:true]
								specialParameter:0
                                                                  cornerRelative:false];
		if (ctlr) {
		    [[watchController watch] addPart:part];
		    [ctlr release];
		}
		[view release];
	    }
	    [part release];
	}
    }
}

- (void)parserDidQWedgeStart:(NSDictionary *)attributeDict {
    // <Qwedge name='qhr' x=' 0' y=' 0' modes='all' outerRadius='50' innerRadius='25' angleSpan='pi/12'  update='60' angle='hour12ValueAngle()' strokeColor='black' fillColor='clear' opaque='0' animate='1'/>
    
    if ([self onBase:@"QWedge"])
	return;
    
    NSString *nam = [self verifyRefName:[attributeDict objectForKey:@"refName"] hint:@"Qwedge"];
    if (nam == nil) {
	nam = [self verifyName:[attributeDict objectForKey:@"name"] hint:@"Qwedge"];
    }
    if (nam) {
	// check for garbage attributes
	[self noWindows:nam];
	for (NSString *key in attributeDict) {
	    if ([key compare:@"angle" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"update" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"updateOffset" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"strokeColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fillColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"innerRadius" options:NSLiteralSearch] == NSOrderedSame||
		[key compare:@"outerRadius" options:NSLiteralSearch] == NSOrderedSame||
		[key compare:@"angleSpan" options:NSLiteralSearch] == NSOrderedSame||
		[key compare:@"offsetAngle" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"offsetRadius" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"opaque" options:NSLiteralSearch] == NSOrderedSame||
		[key compare:@"animate" options:NSLiteralSearch] == NSOrderedSame||
		[key compare:@"dragType" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"dragAnimationType" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animSpeed" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"envSlot" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"special" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"borderWidth" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"z" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"thick" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"kind" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"input" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"refName" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
	// grab the hand angle expression
	NSString *expr = [self verifyAttr:attributeDict key:@"angle" for:nam];
	if (expr == nil) {
	    return;
	}
	
	NSString *expr2 = [self verifyAttr:attributeDict key:@"offsetAngle" for:nam optional:true];
	EBVMInstructionStream *s2 = nil;
	if (expr2 != nil) {
	    s2 = [[[watchController watch] vm] compileInstructionStreamFromCExpression:expr2 errorReporter:[ECErrorReporter theErrorReporter]];
	}
	// create the object
	ECWatchHand *part  =  [[ECWatchHand alloc] initWithName:nam
						       forWatch:[watchController watch]
						       modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
							   kind:[self boundsCheckOpt:attributeDict lb:ECHandKindLB ub:ECHandKindUB df:ECNotTimerZeroKind name:nam attr:@"kind" optional:true]
						 updateInterval:[self boundsCheck:attributeDict lb:-kECminUpdate ub:kECmaxUpdate df:1 name:nam attr:@"update"]
					   updateIntervalOffset:[self boundsCheckOpt:attributeDict lb:-kECmaxUpdate ub:kECmaxUpdate df:0 name:nam attr:@"updateOffset" optional:true]
						    updateTimer:ECMainTimer
						     masterPart:nil // FOR NOW
						    angleStream:[[[watchController watch] vm] compileInstructionStreamFromCExpression:expr errorReporter:[ECErrorReporter theErrorReporter]]
						   actionStream:nil
							      z:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:0 name:nam attr:@"z" optional:true]
						      thickness:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:3 name:nam attr:@"thick" optional:true]
						  xOffsetStream:nil
						  yOffsetStream:nil
						   offsetRadius:[self boundsCheckOpt:attributeDict lb:-rm ub:rm df:0 name:nam attr:@"offsetRadius" optional:true] * scaler
					      offsetAngleStream:s2];
	if (part) {
	    // create view object
	    UIColor *fcolor = [self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"fillColor"];
	    double borderWidth = [self boundsCheckOpt:attributeDict lb:0 ub:10 df:((fcolor == [UIColor clearColor] ? ECHandLineWidthOutline : ECHandLineWidthFill)) name:nam attr:@"borderWidth" optional:true] * scaler;
	    ECQWedgeHandView *view = [[ECQWedgeHandView alloc]initWithOuterRadius:[self boundsCheck:attributeDict lb:0 ub:ym*2 df:0 name:nam attr:@"outerRadius"] * scaler
						    xAnchorOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
						    yAnchorOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler
								      innerRadius:[self boundsCheckOpt:attributeDict lb:0 ub:ym*2 df:0 name:nam attr:@"innerRadius" optional:true] * scaler
									angleSpan:[self boundsCheck:attributeDict lb:0.001 ub:2*M_PI df:0 name:nam attr:@"angleSpan"]
									animSpeed:[self boundsCheckOpt:attributeDict lb:0 ub:100 df:1 name:nam attr:@"animSpeed" optional:true]
									 dragType:[self boundsCheckOpt:attributeDict lb:ECDragLB ub:ECDragUB df:ECDragNormal name:nam attr:@"dragType" optional:true]
								dragAnimationType:[self boundsCheckOpt:attributeDict lb:ECDragAnimationLB ub:ECDragAnimationUB df:ECDragAnimationNever name:nam attr:@"dragAnimationType" optional:true]
									   scolor:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"strokeColor"]
									   fcolor:fcolor
									  fcolor2:nil
									     font:nil
									     text:nil
								      orientation:ECWheelOrientationTwelve
									    ticks:0
									tickWidth:0
								      borderWidth:borderWidth
								      halfAndHalf:false];
	    if (view) {
		// create controller
		ECPartController *ctlr = [[ECHandController alloc] initWithModel:part view:view master:watchController
									  opaque:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"opaque"  optional:true]
									grabPrio:ECGrabPrioDefault
									 envSlot:[self boundsCheckOpt:attributeDict lb:0 ub:ECEnvUB df:0 name:nam attr:@"envSlot" optional:true]
								     specialness:[self boundsCheckOpt:attributeDict lb:ECPartSpecialLB ub:ECPartSpecialUB df:ECPartNotSpecial name:nam attr:@"special" optional:true]
								specialParameter:0
                                                                  cornerRelative:false];
		if (ctlr) {
		    [[watchController watch] addPart:part];
		    [ctlr release];
		}
		[view release];
	    }
	    [part release];
	}
    }
}

// A day/night ring is a bunch of wedges...
- (void)parserDidDayNightRingStart:(NSDictionary *)attributeDict {
    if ([self onBase:@"dayNight"])
	return;
    
    NSString *nam =[self verifyName:[attributeDict objectForKey:@"name"] hint:@"dayNight"];
    if (nam) {
	// check for garbage attributes
	[self noWindows:nam];
	for (NSString *key in attributeDict) {
	    if ([key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"x" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"z" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"thick" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"numWedges" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"planetNumber" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"masterOffset" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"outerRadius" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"innerRadius" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"update" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"strokeColor" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"fillColor" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"input" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"timeBase" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"envSlot" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"updateOffset" options:NSLiteralSearch] == NSOrderedSame ) {
				    // ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
	int envSlot = [self boundsCheckOpt:attributeDict lb:0 ub:ECEnvUB df:0 name:nam attr:@"envSlot" optional:true];
	int numWedges = [self boundsCheck:attributeDict lb:2 ub:96 df:24 name:nam attr:@"numWedges"];
	NSString *masterOffsetAngleExpr = [self verifyAttr:attributeDict key:@"masterOffset" for:nam optional:true];
	int planetNumber = [self boundsCheck:attributeDict lb:0 ub:ECLastLegalPlanet df:24 name:nam attr:@"planetNumber"];
	double outerRadius = [self boundsCheck:attributeDict lb:0 ub:ym*2 df:0 name:nam attr:@"outerRadius"] * scaler;
	double innerRadius = [self boundsCheck:attributeDict lb:0 ub:ym*2 df:0 name:nam attr:@"innerRadius"] * scaler;
	double modes = [self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true];
	double kind = [self boundsCheckOpt:attributeDict lb:ECHandKindLB ub:ECHandKindUB df:ECNotTimerZeroKind name:nam attr:@"kind" optional:true];
	double updateInterval = [self boundsCheck:attributeDict lb:-kECminUpdate ub:kECmaxUpdate df:1 name:nam attr:@"update"];
	double updateIntervalOffset = [self boundsCheckOpt:attributeDict lb:-kECmaxUpdate ub:kECmaxUpdate df:0 name:nam attr:@"updateOffset" optional:true];
	double x = [self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler;
	double y = [self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler;
	UIColor *strokeColor = [self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"strokeColor"];
	UIColor *fillColor = [self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"fillColor"];
        ECTimeBaseKind timeBaseKind = [self timeBaseCheck:attributeDict df:ECTimeBaseKindLT name:nam attr:@"timeBase"];
        
	//double acceptsInput = [self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"input" optional:true];
	double opaque = [self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"opaque"  optional:true];
	ECWatch *watch = [watchController watch];
	EBVirtualMachine *aVm = [watch vm];
	for (int i = 0; i < numWedges; i++) {
	    // create the object
	    NSString *expr;
	    if (envSlot == 0) {
		expr = masterOffsetAngleExpr
		    ? [NSString stringWithFormat:@"(%@) + dayNightLeafAngle(%d, %d, %d, %d)", masterOffsetAngleExpr, planetNumber, i, numWedges, timeBaseKind]
		    : [NSString stringWithFormat:@"dayNightLeafAngle(%d, %d, %d, %d)", planetNumber, i, numWedges, timeBaseKind];
	    } else {
		expr = masterOffsetAngleExpr
		    ? [NSString stringWithFormat:@"(%@) + dayNightLeafAngleN(%d, %d, %d, %d, %d)", masterOffsetAngleExpr, planetNumber, i, numWedges, timeBaseKind, envSlot]
		    : [NSString stringWithFormat:@"dayNightLeafAngleN(%d, %d, %d, %d, %d)", planetNumber, i, numWedges, timeBaseKind, envSlot];
	    }
	    //printf("D/N wedge %2d of %2d: %s\n", i, numWedges, [expr UTF8String]);
	    ECWatchHand *part  =  [[ECWatchHand alloc] initWithName:/*[NSString stringWithFormat:@"%@-%d", nam, i]*/ [NSString stringWithFormat:@"%@-wedge", nam]
							   forWatch:watch
							   modeMask:modes
							       kind:kind
						     updateInterval:updateInterval
					       updateIntervalOffset:updateIntervalOffset
							updateTimer:ECMainTimer
							 masterPart:nil   // FOR NOW
							angleStream:[aVm compileInstructionStreamFromCExpression:expr errorReporter:[ECErrorReporter theErrorReporter]]
						       actionStream:nil
								  z:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:0 name:nam attr:@"z" optional:true]
							  thickness:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:3 name:nam attr:@"thick" optional:true]
						      xOffsetStream:nil
						      yOffsetStream:nil
						       offsetRadius:0
						  offsetAngleStream:nil];
	    if (part) {
		// create view object
		ECQWedgeHandView *view = [[ECQWedgeHandView alloc]initWithOuterRadius:outerRadius
							xAnchorOffsetFromScreenCenter:x
							yAnchorOffsetFromScreenCenter:y
									  innerRadius:innerRadius
									    angleSpan:(2 * M_PI + .2)/ numWedges
									    animSpeed:1
									     dragType:ECDragNormal
								    dragAnimationType:ECDragAnimationNever  // [stevep 3/10/10: This seems wrong to me; but it reproduces the prior behavior of discrete:false]
									       scolor:strokeColor
									       fcolor:fillColor
									      fcolor2:nil
										 font:nil
										 text:nil
									  orientation:ECWheelOrientationTwelve
										ticks:0
									    tickWidth:0
									  borderWidth:(fillColor == [UIColor clearColor] ? ECHandLineWidthOutline : ECHandLineWidthFill) * scaler
									  halfAndHalf:false];
		if (view) {
		    // create controller
		    ECPartController *ctlr = [[ECHandController alloc] initWithModel:part view:view master:watchController
									      opaque:opaque
									    grabPrio:ECGrabPrioDefault
									     envSlot:envSlot
									 specialness:ECPartNotSpecial
								    specialParameter:0
                                                                      cornerRelative:false];
		    if (ctlr) {
			[[watchController watch] addPart:part];
			[ctlr release];
		    }
		    [view release];
		}
		[part release];
	    }
	}
    }
}

- (void)parserDidImageStart:(NSDictionary *)attributeDict {
    //   <Image  name='face' x='0' y='10' modes='front' scale='1' src='eb-face.png' opaque='1'/>
    
    NSString *nam;
    nam = [self verifyRefName:[attributeDict objectForKey:@"refName"] hint:@"Image"];
    if (nam == nil) {
	nam = [self verifyName:[attributeDict objectForKey:@"name"] hint:@"Image"];
    }
#undef BANDLESS
#ifdef BANDLESS
    if ([nam hasPrefix:@"band"]) {
	nam=nil;	// ignore bands!
    }
#endif
    if (nam) {
	// check for garbage attributes
	for (NSString *key in attributeDict) {
	    if ([key compare:@"src" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"scale" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"radius2" options:NSLiteralSearch] == NSOrderedSame||
		[key compare:@"opaque" options:NSLiteralSearch] == NSOrderedSame||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"grabPrio" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"envSlot" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"special" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"alpha" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"norotate" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"input" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"refName" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
	if (theBase) {
	    // create a piece, not a full-fledged part
	    UIImage *image2x;
	    UIImage *image4x=nil;
	    UIImage *image = [self verifyImageFile:[attributeDict objectForKey:@"src"] for:nam optional:false image2x:&image2x image4x:&image4x];
	    ECImageView *piece = [[ECImageView alloc]initCenteredWithImage:image
								   image2x:image2x
								   image4x:image4x
					     xCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
					     yCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler
								   radius2:[self boundsCheckOpt:attributeDict lb:kECminRadius ub:rm df:0 name:nam attr:@"radius2" optional:true] * scaler
								 animSpeed:1.0
								   animDir:ECAnimationDirClosest
								  dragType:ECDragNormal
							 dragAnimationType:ECDragAnimationNever
								     alpha:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:1 name:nam attr:@"alpha" optional:true]
								    xScale:[self boundsCheckOpt:attributeDict lb:-kECmaxScale ub:kECmaxScale df:kECdefaultScale name:nam attr:@"scale" optional:true]
								    yScale:[self boundsCheckOpt:attributeDict lb:-kECmaxScale ub:kECmaxScale df:kECdefaultScale name:nam attr:@"scale" optional:true]
								  norotate:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"norotate" optional:true]];
	    if ([self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true] != baseMask) {
		[errorDelegate reportError:[NSString stringWithFormat:@"mismatched modes ignored for %@:%@", currentWatchName, nam]];
	    }
	    [self applyWindows:piece];
	    
	    // attach it to the current base
	    [theBase addPiece:piece];
	    [piece release];
	} else {
	    // create a full standalone part
	    ECWatchPart *part = [[ECWatchPart alloc] initWithName:nam
							      for:[watchController watch]
							 modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
						   updateInterval:0
					     updateIntervalOffset:0
						      updateTimer:ECMainTimer
						       masterPart:nil];
	    if (part) {
		// create view object
		UIImage *image2x;
                UIImage *image4x=nil;
		UIImage *image = [self verifyImageFile:[attributeDict objectForKey:@"src"] for:nam optional:false image2x:&image2x image4x:&image4x];
		ECImageView *view = [[ECImageView alloc]initCenteredWithImage:image
								      image2x:image2x
								      image4x:image4x
						xCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
						yCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler
								      radius2:[self boundsCheckOpt:attributeDict lb:kECminRadius ub:rm df:0 name:nam attr:@"radius2" optional:true] * scaler
								    animSpeed:1.0
								      animDir:ECAnimationDirClosest
								     dragType:ECDragNormal
							    dragAnimationType:ECDragAnimationNever
									alpha:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:1 name:nam attr:@"alpha" optional:true]
								       xScale:[self boundsCheckOpt:attributeDict lb:-kECmaxScale ub:kECmaxScale df:kECdefaultScale name:nam attr:@"scale" optional:true]
								       yScale:[self boundsCheckOpt:attributeDict lb:-kECmaxScale ub:kECmaxScale df:kECdefaultScale name:nam attr:@"scale" optional:true]
								     norotate:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"norotate" optional:true]];
		if (view) {
		    // apply windows
		    [self applyWindows:view];
		    
		    // create controller
		    ECPartController *ctlr = [[ECVisualController alloc] initWithModel:part view:view master:watchController
										opaque:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"opaque"  optional:true]
									      grabPrio:[self boundsCheckOpt:attributeDict lb:ECGrabPrioLB ub:ECGrabPrioUB df:ECGrabPrioDefault name:nam attr:@"grabPrio" optional:true]
									       envSlot:[self boundsCheckOpt:attributeDict lb:0 ub:ECEnvUB df:0 name:nam attr:@"envSlot" optional:true]
									   specialness:[self boundsCheckOpt:attributeDict lb:ECPartSpecialLB ub:ECPartSpecialUB df:ECPartNotSpecial name:nam attr:@"special" optional:true]
								      specialParameter:0
                                                                        cornerRelative:false];
		    if (ctlr) {
			[[watchController watch] addPart:part];
			[ctlr release];
		    }
		    [view release];
		}
		[part release];
	    }
	}
    }
}

- (void)parserDidTerminatorStart:(NSDictionary *)attributeDict {
    //   <terminator  name='term' x='0' y='10' modes='front' update='1 * days()' updateOffset='0' angle='lunarPhase()'/>
    
    if ([self onBase:@"terminator"])
	return;
    
    NSString *nam =[self verifyName:[attributeDict objectForKey:@"name"] hint:@"terminator"];
    if (nam) {
	// check for garbage attributes
	for (NSString *key in attributeDict) {
	    if ([key compare:@"phaseAngle" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"rotation" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"update" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"updateOffset" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"envSlot" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"radius" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"leavesPerQuadrant" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"leafAnchorRadius" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"leafBorderColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"leafFillColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"incremental" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
	// grab the phase angle expression
	NSString *phaseExpression = [self verifyAttr:attributeDict key:@"phaseAngle" for:nam];
	if (phaseExpression == nil) {
	    return;
	}
	// grab the rotation expression, if present
	NSString *rotationExpression = [attributeDict objectForKey:@"rotation"];
	
	[ECTerminatorLeaf createTerminatorLeavesForRadius:[self boundsCheck:attributeDict lb:1 ub:xm df:0 name:nam attr:@"radius"]  * scaler
					 terminatorCenter:CGPointMake([self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler,
								      [self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"y"] * scaler)
					      incremental:([self boundsCheckOpt:attributeDict lb:0 ub:1 df:1 name:nam attr:@"incremental" optional:true] ? true : false)
						 modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
				       forWatchController:watchController
						 partName:nam
					   updateInterval:[self boundsCheck:attributeDict lb:kECminUpdate ub:kECmaxUpdate df:1 name:nam attr:@"update"]
				     updateIntervalOffset:[self boundsCheckOpt:attributeDict lb:-kECmaxUpdate ub:kECmaxUpdate df:0 name:nam attr:@"updateOffset" optional:true]
						  envSlot:[self boundsCheckOpt:attributeDict lb:0 ub:ECEnvUB df:0 name:nam attr:@"envSlot" optional:true]
					  phaseExpression:phaseExpression
			     terminatorRotationExpression:rotationExpression
			terminatorCenterXOffsetExpression:nil
			terminatorCenterYOffsetExpression:nil
					leavesPerQuadrant:[self boundsCheck:attributeDict lb:1 ub:ECMaxLeaves df:0 name:nam attr:@"leavesPerQuadrant"]
				     leafAnchorEdgeRadius:[self boundsCheck:attributeDict lb:0 ub:xm df:0 name:nam attr:@"leafAnchorRadius"] * scaler
					  leafBorderColor:[self colorCheck:attributeDict df:[UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1] name:nam attr:@"leafBorderColor"]
					    leafFillColor:[self colorCheck:attributeDict df:[UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1] name:nam attr:@"leafFillColor"] ];
    }
}

- (void)parserDidCalendarHeaderStart:(NSDictionary *)attributeDict {
    //   <CalendarHeader name='cal header' x='xCal' y='yCal' modes='front' bodyFontSize='calendarFontSize' bodyFontName='Arial' fontSize='calendarFontSize' fontName='Arial' weekdayStart='0' />

    NSString *nam =[self verifyName:[attributeDict objectForKey:@"name"] hint:@"CalendarHeader"];
    if (nam) {
	// check for garbage attributes
	for (NSString *key in attributeDict) {
	    if ([key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"parkX" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"parkY" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontSize" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"fontName" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"bodyFontSize" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"bodyFontName" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"weekdayStart" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"weekdayColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"weekendColor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
        double bodyFontSize = [self boundsCheckOpt:attributeDict lb:kECminFontSize ub:kECmaxFontSize df:kECdefaultFontSize name:nam attr:@"bodyFontSize" optional:false];
	UIFont *bodyFont = [self verifyFont:[attributeDict objectForKey:@"bodyFontName"] size:bodyFontSize for:nam optional:false];

        double headerFontSize = [self boundsCheckOpt:attributeDict lb:kECminFontSize ub:kECmaxFontSize df:kECdefaultFontSize name:nam attr:@"fontSize" optional:false];
	UIFont *headerFont = [self verifyFont:[attributeDict objectForKey:@"fontName"] size:headerFontSize for:nam optional:false];

        CGSize overallSize;
        CGSize cellSize;
        CGSize spacing;
        ESCalculateCalendarWidth(bodyFont, &overallSize, &cellSize, &spacing);

        CGFloat masterX = [self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] - overallSize.width / 2;
        CGFloat masterY = [self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"y"];

        CGFloat parkX = [self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"parkX"];
        CGFloat parkY = [self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"parkY"];

        static char *labelsByWeekday[7] = {"Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"};

        int weekdayStart = (int)rint([self boundsCheck:attributeDict lb:0 ub:6 df:0 name:nam attr:@"weekdayStart"]);

        // Create 7 labels
        for (int col = 0; col < 7; col++) {
            int wkday = (col + weekdayStart) % 7;
            char *labelText = labelsByWeekday[wkday];
            bool isWeekend = (wkday == 0 || wkday == 6);

            CGFloat x = masterX + cellSize.width/2 + col * (cellSize.width + spacing.width);
            CGFloat y = masterY + cellSize.height/2 + spacing.height;
            if (theBase) {
                ECQTextView *piece = [[ECQTextView alloc]initCenteredWithText:[NSString stringWithUTF8String:labelText]
                                                xCenterOffsetFromScreenCenter:x
                                                yCenterOffsetFromScreenCenter:y
                                                                   cropBottom:0
                                                                      cropTop:0
                                                                       radius:0
                                                                        angle:0
                                                                    animSpeed:0
                                                                  orientation:ECDialOrientationRadial
                                                                         font:headerFont
                                                                        color:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:isWeekend?@"weekendColor":@"weekdayColor"] ]; 
                if ([self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true] != baseMask) {
                    [errorDelegate reportError:[NSString stringWithFormat:@"mismatched modes ignored for %@:%@", currentWatchName, nam]];
                }
                
                // attach it to the current base
                [theBase addPiece:piece];
                [piece release];
            } else {
                // create a full standalone part
                NSString *exprX = [NSString stringWithFormat:@"calendarWeekdayStart() == %d ? 0 : %.2f", weekdayStart, parkX - x];
                EBVMInstructionStream *xOffsetStream = [[[watchController watch] vm] compileInstructionStreamFromCExpression:exprX errorReporter:[ECErrorReporter theErrorReporter]];
                NSString *exprY = [NSString stringWithFormat:@"calendarWeekdayStart() == %d ? 0 : %.2f", weekdayStart, parkY - y];
                EBVMInstructionStream *yOffsetStream = [[[watchController watch] vm] compileInstructionStreamFromCExpression:exprY errorReporter:[ECErrorReporter theErrorReporter]];
                
                ECWatchHand *part  =  [[ECWatchHand alloc] initWithName:[nam stringByAppendingFormat:@"-%d", col]
                                                               forWatch:[watchController watch]
                                                               modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
                                                                   kind:ECNotTimerZeroKind
                                                         updateInterval:1e6
                                                   updateIntervalOffset:0
                                                            updateTimer:ECMainTimer
                                                             masterPart:nil
                                                            angleStream:nil
                                                           actionStream:nil
                                                                      z:0
                                                              thickness:3
                                                          xOffsetStream:xOffsetStream
                                                          yOffsetStream:yOffsetStream
                                                           offsetRadius:0
                                                      offsetAngleStream:nil];
                if (part) {
                    // create view object
                    ECQView *view = [[ECQTextView alloc]initCenteredWithText:[NSString stringWithUTF8String:labelText]
                                               xCenterOffsetFromScreenCenter:x
                                               yCenterOffsetFromScreenCenter:y
                                                                  cropBottom:0
                                                                     cropTop:0
                                                                      radius:0
                                                                       angle:0
                                                                   animSpeed:0
                                                                 orientation:ECDialOrientationRadial
                                                                        font:headerFont
                                                                       color:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:isWeekend?@"weekendColor":@"weekdayColor"] ]; 
                    if (view) {
                        // create controller
                        ECPartController *ctlr = [[ECVisualController alloc] initWithModel:part
                                                                                      view:view
                                                                                    master:watchController
                                                                                    opaque:false
                                                                                  grabPrio:ECGrabPrioDefault
                                                                                   envSlot:0
                                                                               specialness:ECPartNotSpecial // Though, hmm, we probably want to actually do something here for different weekday starts...
                                                                          specialParameter:0
                                                                            cornerRelative:false];
                        if (ctlr) {
                            [[watchController watch] addPart:part];
                            [ctlr release];
                        }
                        [view release];
                    }
                    [part release];
                }
            }
        }
    }
}

- (void)parserDidCalendarRowCoverStart:(NSDictionary *)attributeDict {
    // <CalendarRowCover  name='cal week5 right cover' x='xCal' y='yCal' modes='front' coverType='row5Right' fontName='Arial' fontSize='calendarFontSize' fontColor='0xff808080' update='3600'       animSpeed='calendarAnimationSpeed' />

    if ([self onBase:@"CalendarRowCover"])
	return;
    
    NSString *nam =[self verifyName:[attributeDict objectForKey:@"name"] hint:@"CalendarRowCover"];
    if (nam) {
	// check for garbage attributes
	for (NSString *key in attributeDict) {
	    if ([key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"z" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"fontSize" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"fontName" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"bgColor" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"fontColor" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"calendarRadius" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"coverType" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"update" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"updateOffset" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animSpeed" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"z" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"thick" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
        double fontSize = [self boundsCheckOpt:attributeDict lb:kECminFontSize ub:kECmaxFontSize df:kECdefaultFontSize name:nam attr:@"fontSize" optional:false];
	UIFont *font = [self verifyFont:[attributeDict objectForKey:@"fontName"] size:fontSize for:nam optional:false];

        CGSize overallSize;
        CGSize cellSize;
        CGSize spacing;
        ESCalculateCalendarWidth(font, &overallSize, &cellSize, &spacing);

        CGFloat x = [self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"];
        CGFloat y = [self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"y"];

        CGFloat calendarRadius = [self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"calendarRadius"];

        ECCalendarRowCoverType coverType = [self boundsCheck:attributeDict lb:ECCalendarRowCoverMin ub:ECCalendarRowCoverMax df:0 name:nam attr:@"coverType"];
        bool isUnderlay = (coverType == ECCalendarCoverRow1Left || coverType == ECCalendarCoverRow1Right);

        NSString *exprX = [NSString stringWithFormat:@"%s(%d, %.4f, %.4f, %.4f)",
                                    isUnderlay ? "calendarRowUnderlayOffsetForType" : "calendarRowCoverOffsetForType",
                                    (int)coverType,
                                    overallSize.width, cellSize.width, spacing.width];
        //printf("calendar row cover exprX='%s'\n", [exprX UTF8String]);
        EBVMInstructionStream *xOffsetStream = [[[watchController watch] vm] compileInstructionStreamFromCExpression:exprX errorReporter:[ECErrorReporter theErrorReporter]];

	ECWatchHand *part  =  [[ECWatchHand alloc] initWithName:nam
						       forWatch:[watchController watch]
						       modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
							   kind:ECNotTimerZeroKind
						 updateInterval:[self boundsCheck:attributeDict lb:-kECminUpdate ub:kECmaxUpdate df:1 name:nam attr:@"update"]
					   updateIntervalOffset:[self boundsCheckOpt:attributeDict lb:-kECmaxUpdate ub:kECmaxUpdate df:0 name:nam attr:@"updateOffset" optional:true]
						    updateTimer:ECMainTimer
						     masterPart:nil
						    angleStream:nil
						   actionStream:nil
							      z:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:0 name:nam attr:@"z" optional:true]
						      thickness:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:3 name:nam attr:@"thick" optional:true]
						  xOffsetStream:xOffsetStream
						  yOffsetStream:nil
						   offsetRadius:0
					      offsetAngleStream:nil];
        CGFloat rowY;
        switch(coverType) {
          case ECCalendarCoverRow56Right:
          case ECCalendarCoverRow6Left:
            rowY = y + calendarRadius - 5 * (cellSize.height + spacing.height) - cellSize.height/2;
            break;
          case ECCalendarCoverRow1Left:
          case ECCalendarCoverRow1Right:
            rowY = y + calendarRadius - cellSize.height/2 - 1;
            break;
          default:
            [[ECErrorReporter theErrorReporter]
                        reportError:[NSString stringWithFormat:@"Calendar row cover type %d unexpected in watch %@", coverType, nam]];
            return;
        }
        if (part) {
            // create view object
            ECQView *view = [[ECQCalendarRowCoverView alloc] initWithRowCoverType:coverType
                                                                        calendarX:x
                                                                             rowY:rowY
                                                                             font:font
                                                                          bgColor:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"bgColor"]
                                                                        fontColor:[self colorCheck:attributeDict df:kECdefaultHandColor name:nam attr:@"fontColor"]];
            if (view) {
                // create controller
                ECPartController *ctlr = [[ECVisualController alloc] initWithModel:part
                                                                              view:view
                                                                            master:watchController
                                                                            opaque:false
                                                                          grabPrio:ECGrabPrioDefault
                                                                           envSlot:0
                                                                       specialness:ECPartNotSpecial
                                                                  specialParameter:0
                                                                    cornerRelative:false];
                if (ctlr) {
                    [[watchController watch] addPart:part];
                    [ctlr release];
                }
                [view release];
            }
            [part release];
        }
    }
}

- (void)parserDidHandStart:(NSDictionary *)attributeDict {    
    // < hand name='hour' x='0' y='10' xAnchor='5' yAnchor='0' kind='minuteKind' modes='front | back' src='howard-hour.png' update='1 * minutes()' animate='1' kind='hour12kind'	angle='hour12ValueAngle()' scale='1' updateOffset='.5' opaque='0'/>

    if ([self onBase:@"hand"])
	return;
    
    NSString *nam;
    nam = [self verifyRefName:[attributeDict objectForKey:@"refName"] hint:@"Image"];
    if (nam == nil) {
	nam = [self verifyName:[attributeDict objectForKey:@"name"] hint:@"Image"];
    }
    if (nam) {
	// check for garbage attributes
	for (NSString *key in attributeDict) {
	    if ([key compare:@"src" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"angle" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"offsetAngle" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"offsetRadius" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"update" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"updateOffset" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"opaque" options:NSLiteralSearch] == NSOrderedSame||
		[key compare:@"scale" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"z" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"thick" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"xAnchor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"yAnchor" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animate" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animSpeed" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animDir" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"dragType" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"dragAnimationType" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"alpha" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"grabPrio" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"envSlot" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"special" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"specialParam" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"input" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"kind" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"action" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"cornerRelative" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"refName" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
	if (([attributeDict objectForKey:@"xAnchor"] != 0) !=
	    ([attributeDict objectForKey:@"yAnchor"] != 0)) {
	    [errorDelegate reportError:[NSString stringWithFormat:@"%@:%@ supplied xAnchor or yAnchor but not both", currentWatchName, nam]];
	    return;
	}
	// grab the hand angle expressions
	NSString *expr = [self verifyAttr:attributeDict key:@"angle" for:nam];
	if (expr == nil) {
	    return;
	}
	NSString *expr2 = [self verifyAttr:attributeDict key:@"offsetAngle" for:nam optional:true];
	EBVMInstructionStream *s2 = nil;
	if (expr2 != nil) {
	    s2 = [[[watchController watch] vm] compileInstructionStreamFromCExpression:expr2 errorReporter:[ECErrorReporter theErrorReporter]];
	}

	NSString *expr3 = [self verifyAttr:attributeDict key:@"action" for:nam optional:true];
	EBVMInstructionStream *s3 = nil;
	if (expr3 != nil) {
	    s3 = [[[watchController watch] vm] compileInstructionStreamFromCExpression:expr3 errorReporter:[ECErrorReporter theErrorReporter]];
	}
	
	// create the object
	ECWatchHand *part = [[ECWatchHand alloc] initWithName:nam
						     forWatch:[watchController watch]
						     modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
						         kind:[self boundsCheckOpt:attributeDict lb:ECHandKindLB ub:ECHandKindUB df:ECNotTimerZeroKind name:nam attr:@"kind" optional:true]
					       updateInterval:[self boundsCheck:attributeDict lb:kECminUpdate ub:kECmaxUpdate df:1 name:nam attr:@"update"]
					 updateIntervalOffset:[self boundsCheckOpt:attributeDict lb:-kECmaxUpdate ub:kECmaxUpdate df:0 name:nam attr:@"updateOffset" optional:true]
						  updateTimer:ECMainTimer
						   masterPart:nil // FOR NOW
						  angleStream:[[[watchController watch] vm] compileInstructionStreamFromCExpression:expr errorReporter:[ECErrorReporter theErrorReporter]]
						 actionStream:s3
							    z:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:0 name:nam attr:@"z" optional:true]
						    thickness:[self boundsCheckOpt:attributeDict lb:0 ub:10 df:3 name:nam attr:@"thick" optional:true]
						xOffsetStream:nil
						yOffsetStream:nil
						 offsetRadius:[self boundsCheckOpt:attributeDict lb:0 ub:rm df:0 name:nam attr:@"offsetRadius" optional:true] * scaler
					    offsetAngleStream:s2];
	if (part) {
	    // create view object
	    ECImageView *view;
	    UIImage *image2x;
	    UIImage *image4x=nil;
	    UIImage *image = [self verifyImageFile:[attributeDict objectForKey:@"src"] for:nam optional:false image2x:&image2x image4x:&image4x];
	    if ([attributeDict objectForKey:@"xAnchor"]) {
		view = [[ECImageView alloc]initWithImage:image
						 image2x:image2x
						 image4x:image4x
			   xAnchorOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
			   yAnchorOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler
				      xAnchorInViewSpace:[self boundsCheck:attributeDict lb:-xm*2 ub:xm*2 df:0 name:nam attr:@"xAnchor"] * scaler
				      yAnchorInViewSpace:[self boundsCheck:attributeDict lb:-ym*2 ub:ym*2 df:0 name:nam attr:@"yAnchor"] * scaler
						  xScale:[self boundsCheckOpt:attributeDict lb:kECminScale ub:kECmaxScale df:kECdefaultScale name:nam attr:@"scale" optional:true]
						  yScale:[self boundsCheckOpt:attributeDict lb:kECminScale ub:kECmaxScale df:kECdefaultScale name:nam attr:@"scale" optional:true]
					       animSpeed:[self boundsCheckOpt:attributeDict lb:0 ub:100 df:1 name:nam attr:@"animSpeed" optional:true]
						 animDir:[self boundsCheckOpt:attributeDict lb:ECAnimationDirLB ub:ECAnimationDirUB df:ECAnimationDirClosest name:nam attr:@"animDir" optional:true]
						dragType:[self boundsCheckOpt:attributeDict lb:ECDragLB ub:ECDragUB df:ECDragNormal name:nam attr:@"dragType" optional:true]
				       dragAnimationType:[self boundsCheckOpt:attributeDict lb:ECDragAnimationLB ub:ECDragAnimationUB df:ECDragAnimationNever name:nam attr:@"dragAnimationType" optional:true]];
	    } else {
		view = [[ECImageView alloc]initCenteredWithImage:image
							 image2x:image2x
							 image4x:image4x
				   xCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
				   yCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler
							 radius2:0
						       animSpeed:[self boundsCheckOpt:attributeDict lb:0 ub:100 df:1 name:nam attr:@"animSpeed" optional:true]
							 animDir:[self boundsCheckOpt:attributeDict lb:ECAnimationDirLB ub:ECAnimationDirUB df:ECAnimationDirClosest name:nam attr:@"animDir" optional:true]
							dragType:[self boundsCheckOpt:attributeDict lb:ECDragLB ub:ECDragUB df:ECDragNormal name:nam attr:@"dragType" optional:true]
					       dragAnimationType:[self boundsCheckOpt:attributeDict lb:ECDragAnimationLB ub:ECDragAnimationUB df:ECDragAnimationNever name:nam attr:@"dragAnimationType" optional:true]
							   alpha:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:1 name:nam attr:@"alpha" optional:true]
							  xScale:[self boundsCheckOpt:attributeDict lb:kECminScale ub:kECmaxScale df:kECdefaultScale name:nam attr:@"scale" optional:true]
							  yScale:[self boundsCheckOpt:attributeDict lb:kECminScale ub:kECmaxScale df:kECdefaultScale name:nam attr:@"scale" optional:true]
							norotate:false];
	    }
	    if (view) {
		[self applyWindows:view];

		// create controller
		ECPartController *ctlr = [[ECHandController alloc] initWithModel:part view:view master:watchController
									  opaque:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"opaque" optional:true]
									grabPrio:[self boundsCheckOpt:attributeDict lb:ECGrabPrioLB ub:ECGrabPrioUB df:ECGrabPrioDefault name:nam attr:@"grabPrio" optional:true]
									 envSlot:[self boundsCheckOpt:attributeDict lb:0 ub:ECEnvUB df:0 name:nam attr:@"envSlot" optional:true]
								     specialness:[self boundsCheckOpt:attributeDict lb:ECPartSpecialLB ub:ECPartSpecialUB df:ECPartNotSpecial name:nam attr:@"special" optional:true]
								specialParameter:[self boundsCheckOpt:attributeDict lb:ECPartSpecialParamLB ub:ECPartSpecialParamUB df:0 name:nam attr:@"specialParam" optional:true]
                                                                  cornerRelative:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"cornerRelative" optional:true]];
		    if (ctlr) {
		    [[watchController watch] addPart:part];
		    [ctlr release];
		}
		[view release];
	    }
	    [part release];
	}
    }
}

- (void)parserDidBlinkerStart:(NSDictionary *)attributeDict {
    //   <blinker name='cuckoo' x=' 0' y='-65' modes='front' src='../../Icon.png' update='1 * minutes()' duration='2*seconds()' scale='0.33'/>
    
    if ([self onBase:@"blinker"])
	return;
    
    NSString *nam =[self verifyName:[attributeDict objectForKey:@"name"] hint:@"blinker"];
    if (nam) {
	// check for garbage attributes
	[self noWindows:nam];
	for (NSString *key in attributeDict) {
	    if ([key compare:@"src" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"duration" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"update" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"updateOffset" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"scale" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"envSlot" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}

	// grab the duration expression
	NSString *expr = [self verifyAttr:attributeDict key:@"duration" for:nam];
	if (expr == nil) {
	    return;
	}

	// create the object
	ECWatchBlinker *part = [[ECWatchBlinker alloc] initWithName:nam
								for:[watchController watch]
							   modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
						     updateInterval:[self boundsCheck:attributeDict lb:kECminUpdate ub:kECmaxUpdate df:1 name:nam attr:@"update"]
					       updateIntervalOffset:[self boundsCheckOpt:attributeDict lb:-kECmaxUpdate ub:kECmaxUpdate df:0 name:nam attr:@"updateOffset" optional:true]
							   duration:[[[watchController watch] vm] compileInstructionStreamFromCExpression:expr errorReporter:[ECErrorReporter theErrorReporter]] ];
	if (part) {
	    // create view object
	    UIImage *image2x;
	    UIImage *image4x=nil;
	    UIImage *image = [self verifyImageFile:[attributeDict objectForKey:@"src"] for:nam optional:false image2x:&image2x image4x:&image4x];
	    ECImageView *view = [[ECImageView alloc]initCenteredWithImage:image
								  image2x:image2x
								  image4x:image4x
					    xCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
					    yCenterOffsetFromScreenCenter:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler
								  radius2:0
								animSpeed:1.0
								  animDir:ECAnimationDirClosest
								 dragType:ECDragNormal
							dragAnimationType:ECDragAnimationAlways
								    alpha:1
								   xScale:[self boundsCheckOpt:attributeDict lb:kECminScale ub:kECmaxScale df:kECdefaultScale name:nam attr:@"scale" optional:true]
								   yScale:[self boundsCheckOpt:attributeDict lb:kECminScale ub:kECmaxScale df:kECdefaultScale name:nam attr:@"scale" optional:true]
								 norotate:false];
	    if (view) {
		// create controller
	        int envSlot = [self boundsCheckOpt:attributeDict lb:0 ub:ECEnvUB df:0 name:nam attr:@"envSlot" optional:true];
		ECPartController *ctlr = [[ECBlinkerController alloc] initWithModel:part view:view master:watchController opaque:false grabPrio:ECGrabPrioDefault envSlot:envSlot specialness:ECPartNotSpecial
								   specialParameter:0
                                                                     cornerRelative:false];
		if (ctlr) {
		    [[watchController watch] addPart:part];
		    [ctlr release];
		}
		[view release];
	    }
	    [part release];
	}
    }
}

- (void)parserDidWindowStart:(NSDictionary *)attributeDict {
    // <window name='ignored' type='porthole' x='0' y='0' w='10' h='15' startAngle='0' endAngle='pi' border='1' strokeColor='red' />  // defines the clear area; the border will surround it; applies to the next element to be parsed

    // check for garbage attributes
    for (NSString *key in attributeDict) {
	if ([key compare:@"w" options:NSLiteralSearch] == NSOrderedSame ||
	    [key compare:@"h" options:NSLiteralSearch] == NSOrderedSame ||
	    [key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"type" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"name" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"startAngle" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"endAngle" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"border" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"strokeColor" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"shadowOpacity" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"shadowSigma" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"shadowOffset" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"y" options:NSLiteralSearch] == NSOrderedSame ) {
	    // ok
	} else {
	    [errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:window", key, currentWatchName]];	    
	    return;
	}
    }

    // create a holder for this
    double x = [self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:@"window" attr:@"x"] * scaler;
    double y = [self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:@"window" attr:@"y"] * scaler;
    double w = [self boundsCheck:attributeDict lb:0 ub:xm*2 df:0 name:@"window" attr:@"w"] * scaler;
    double h = [self boundsCheck:attributeDict lb:0 ub:ym*2 df:0 name:@"window" attr:@"h"] * scaler;
    ECHoleHolder *win = [[ECHoleHolder alloc]initWithType:[self holeCheck:attributeDict df:ECHoleWind attr:@"type"]
							x:x
							y:y
							w:w
							h:h
					       startAngle:[self boundsCheckOpt:attributeDict lb:-2*M_PI ub:2*M_PI df:0 name:@"window" attr:@"startAngle" optional:true]
						 endAngle:[self boundsCheckOpt:attributeDict lb:-2*M_PI ub:2*M_PI df:2*M_PI name:@"window" attr:@"endAngle" optional:true]
					      borderWidth:[self boundsCheckOpt:attributeDict lb:0 ub:100  df:2 name:@"window" attr:@"border" optional:true] * scaler
					      strokeColor:[self colorCheck:attributeDict df:kECdefaultHandColor name:@"window" attr:@"strokeColor"] ];
    if (win.type == ECHolePort) {
	if (win.rect.size.width != win.rect.size.height) {
	    [errorDelegate reportError:[NSString stringWithFormat:@"width != height for %@:porthole", currentWatchName]];	    	    
	}
    }
    // save it to apply to the next applicable element
    [winBin addObject:win];
    [win release];

    // Add any shadow to the watch controller
    double shadowOpacity = [self boundsCheckOpt:attributeDict lb:0 ub:1.0 df:0 name:@"window" attr:@"shadowOpacity" optional:true];
    if (shadowOpacity != 0) {
	double shadowSigma = [self boundsCheck:attributeDict lb:0 ub:10 df:0 name:@"window specifying shadowOpacity" attr:@"shadowSigma"];
	double shadowOffset = [self boundsCheck:attributeDict lb:-10 ub:10 df:0 name:@"window specifying shadowOpacity" attr:@"shadowOffset"];
	// Make a shadow image with these parameters, unless one exists already
	NSString *shadowImageDir = [ECTempPngDirectory stringByAppendingPathComponent:@"window-shadows"];
	NSString *shadowImagePath = [NSString stringWithFormat:@"%@/window-shadow-%.1f-%.1f-%.4f-%.4f-%.4f.png", shadowImageDir, w, h, shadowOpacity, shadowSigma, shadowOffset];
	if (![[NSFileManager defaultManager] fileExistsAtPath:shadowImagePath]) {  // If we've created one using these paramters, it will be identical
	    NSString *script = [@"$scripts" stringByAppendingPathComponent:@"makeOneWindowShadow.pl"];
	    NSString *command = [NSString stringWithFormat:@"\"%@\" \"%@\" %.1f %.1f %.4f %.4f %.4f", script, shadowImagePath, w, h, shadowOpacity, shadowSigma, shadowOffset];
	    //printf("%s\n", [command UTF8String]);
	    // Doesn't work with XCode 5/iOS 7 simulator:  system([command UTF8String]);
            sendCommandToCommandServer([command UTF8String]);
	}
	// Make a part using the shadow image
	NSString *nam = [self verifyName:[attributeDict objectForKey:@"name"] hint:@"window"];
	ECWatchPart *part = [[ECWatchPart alloc] initWithName:nam
							  for:[watchController watch]
						     modeMask:[self boundsCheck:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes"]
					       updateInterval:0
					 updateIntervalOffset:0
						  updateTimer:ECMainTimer
						   masterPart:nil];
	if (part) {
	    // create view object
	    UIImage *anImage = [imageCache objectForKey:shadowImagePath];
	    if (anImage == nil) {
		anImage = [UIImage imageWithContentsOfFile:shadowImagePath];
	    }
	    ECImageView *view = [[ECImageView alloc]initCenteredWithImage:anImage
								  image2x:nil  // Let shadows be low resolution
								  image4x:nil  // Let shadows be low resolution
					    xCenterOffsetFromScreenCenter:(x + w/2)
					    yCenterOffsetFromScreenCenter:(y + h/2)
								  radius2:0
								animSpeed:1.0
								  animDir:ECAnimationDirClosest
								 dragType:ECDragNormal
							dragAnimationType:ECDragAnimationNever
								    alpha:1
								   xScale:1
								   yScale:1
								 norotate:false];
	    if (view) {
		// create controller
		ECPartController *ctlr = [[ECVisualController alloc] initWithModel:part view:view master:watchController
									    opaque:0
									  grabPrio:0
									   envSlot:0
								       specialness:ECPartNotSpecial
								  specialParameter:0
                                                                    cornerRelative:false];
		if (ctlr) {
		    [[watchController watch] addPart:part];
		    [ctlr release];
		}
		[view release];
	    }
	    [part release];
	}
    }
}

- (void)parserDidQRectStart:(NSDictionary *)attributeDict {
    // make a solid color rectangle suitbable for an aperture's background

    NSString *nam = [self verifyName:[attributeDict objectForKey:@"name"] hint:@"QRect"];

    // check for garbage attributes
    for (NSString *key in attributeDict) {
	if ([key compare:@"w" options:NSLiteralSearch] == NSOrderedSame ||
	    [key compare:@"h" options:NSLiteralSearch] == NSOrderedSame ||
	    [key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"panes" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"name" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"bgColor" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"envSlot" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"special" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"x" options:NSLiteralSearch] == NSOrderedSame	||
	    [key compare:@"y" options:NSLiteralSearch] == NSOrderedSame ) {
	    // ok
	} else {
	    [errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
	    return;
	}
    }
    
    double x = [self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler;
    double y = [self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler;
    double w = [self boundsCheck:attributeDict lb:0 ub:xm*2 df:0 name:nam attr:@"w"] * scaler;
    double h = [self boundsCheck:attributeDict lb:0 ub:ym*2 df:0 name:nam attr:@"h"] * scaler;
    double panes = [self boundsCheckOpt:attributeDict lb:-10 ub:10 df:1 name:nam attr:@"panes" optional:true];
    UIColor *bgColor = [self colorCheck:attributeDict df:kECdefaultDialColor name:@"window" attr:@"bgColor"];

    if (bgColor == [UIColor clearColor]) {
	// doesn't make sense, ie don't do it
    } else if (theBase) {
        // Just make a piece, not a real part
        ECImageView *view = [[ECImageView alloc]initCenteredBlankWidth:w
                                                                height:h
                                                                 color:bgColor
                                         xCenterOffsetFromScreenCenter:x+w/2
                                         yCenterOffsetFromScreenCenter:y+h/2
                                                                 panes:panes
                                                             animSpeed:1.0
                                                              dragType:ECDragNormal
                                                     dragAnimationType:ECDragAnimationNever
                                                                 alpha:1
                                                                xScale:kECdefaultScale
                                                                yScale:kECdefaultScale];
        [theBase addPiece:view];
        [view release];
    } else {
	ECWatchPart *part = [[ECWatchPart alloc] initWithName:nam
							  for:[watchController watch]
						     modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
					       updateInterval:0
					 updateIntervalOffset:0
						  updateTimer:ECMainTimer
						   masterPart:nil];
	if (part) {	    
	    // create view object
	    ECImageView *view = [[ECImageView alloc]initCenteredBlankWidth:w
								    height:h
								     color:bgColor
					     xCenterOffsetFromScreenCenter:x+w/2
					     yCenterOffsetFromScreenCenter:y+h/2
								     panes:panes
								 animSpeed:1.0
								  dragType:ECDragNormal
							 dragAnimationType:ECDragAnimationNever
								     alpha:1
								    xScale:kECdefaultScale
								    yScale:kECdefaultScale];
	    if (view) {
		// create controller
		ECPartController *ctlr = [[ECVisualController alloc] initWithModel:part view:view master:watchController
									    opaque:1
									  grabPrio:ECGrabPrioDefault
									   envSlot:[self boundsCheckOpt:attributeDict lb:0 ub:ECEnvUB df:0 name:nam attr:@"envSlot" optional:true]
								       specialness:[self boundsCheckOpt:attributeDict lb:ECPartSpecialLB ub:ECPartSpecialUB df:ECPartNotSpecial name:nam attr:@"special" optional:true]
								  specialParameter:0
                                                                    cornerRelative:false];
		if (ctlr) {
		    [[watchController watch] addPart:part];
		    [ctlr release];
		}
		[view release];
	    }
	    [part release];
	}
    }
}

- (void)parserDidTickStart:(NSDictionary *)attributeDict {
    // <tick name='tock' modes='all' src='Snap.caf' interval='0.50' level='1.0'/>    // level is NYI

    if ([self onBase:@"tick"])
	return;
    
    NSString *nam =[self verifyName:[attributeDict objectForKey:@"name"] hint:@"tick"];
    if (nam) {
	// check for garbage attributes
	[self noWindows:nam];
	for (NSString *key in attributeDict) {
	    if ([key compare:@"src" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"interval" options:NSLiteralSearch] == NSOrderedSame ||
//		[key compare:@"level" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}

	// create the object
	ECWatchTick *ticker = [[ECWatchTick alloc] initWithName:nam
							    for:[watchController watch]
						       modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
						 updateInterval:[self boundsCheck:attributeDict lb:-kECmaxUpdate ub:kECmaxUpdate df:1 name:nam attr:@"interval"]
					   updateIntervalOffset:0
						      soundFile:[self verifyAttr:attributeDict key:@"src" for:nam] ];            //hack:  should verify validity

	// create the controller	
	if (ticker) {
	    [[watchController watch] addChime:ticker];
	    [[[ECTickController alloc] initWithModel:ticker master:watchController grabPrio:ECGrabPrioDefault envSlot:0 cornerRelative:false specialness:ECPartNotSpecial
				    specialParameter:0] release];
	    [ticker release];
	}
    }
}

- (void)parserDidCenterStart:(NSDictionary *)attributeDict {
    // <center x='0' y='-45'/>

    for (NSString *key in attributeDict) {
	if ([key compare:@"x" options:NSLiteralSearch] == NSOrderedSame ||
	    [key compare:@"y" options:NSLiteralSearch] == NSOrderedSame) {
		// ok
	} else {
	    [errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@", key, currentWatchName]];	    
	    return;
	}
    }

    [[watchController watch] setCenterX:[self boundsCheck:attributeDict lb:-320 ub:320 df:0 name:@"center" attr:@"x"] * scaler
				      y:[self boundsCheck:attributeDict lb:-320 ub:320 df:0 name:@"center" attr:@"y"] * scaler];
}

- (void)parserDidAtlasStart:(NSDictionary *)attributeDict {
    // check for garbage attributes
    for (NSString *key in attributeDict) {
	if ([key compare:@"frontWidth" options:NSLiteralSearch] == NSOrderedSame ||
	    [key compare:@"frontHeight" options:NSLiteralSearch] == NSOrderedSame ||
	    [key compare:@"backWidth" options:NSLiteralSearch] == NSOrderedSame ||
	    [key compare:@"backHeight" options:NSLiteralSearch] == NSOrderedSame ||
	    [key compare:@"nightWidth" options:NSLiteralSearch] == NSOrderedSame ||
	    [key compare:@"nightHeight" options:NSLiteralSearch] == NSOrderedSame ) {
	} else {
	    [errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@", key, currentWatchName]];	    
	    return;
	}
    }

    expectedFrontAtlasSize.width =  [self boundsCheck:attributeDict lb:0 ub:2048 df:2049 name:@"atlas" attr:@"frontWidth"];
    expectedFrontAtlasSize.height = [self boundsCheck:attributeDict lb:0 ub:2048 df:2049 name:@"atlas" attr:@"frontHeight"];
    expectedBackAtlasSize.width =  [self boundsCheck:attributeDict lb:0 ub:2048 df:2049 name:@"atlas" attr:@"backWidth"];
    expectedBackAtlasSize.height = [self boundsCheck:attributeDict lb:0 ub:2048 df:2049 name:@"atlas" attr:@"backHeight"];
    expectedNightAtlasSize.width =  [self boundsCheck:attributeDict lb:0 ub:2048 df:2049 name:@"atlas" attr:@"nightWidth"];
    expectedNightAtlasSize.height = [self boundsCheck:attributeDict lb:0 ub:2048 df:2049 name:@"atlas" attr:@"nightHeight"];
}

- (void)parserDidDemoStart:(NSDictionary *)attributeDict {
    NSString *nam =[self verifyName:[attributeDict objectForKey:@"name"] hint:@"demo"];
    if ([self onBase:@"demo"])
	return;
    
    if (nam) {
	// check for garbage attributes
	[self noWindows:nam];
	for (NSString *key in attributeDict) {
	    if ([key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"firstAct" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"lastAct" options:NSLiteralSearch] == NSOrderedSame ) {
				    // ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}

	capturingDemo = true;
#ifdef FIXFIXFIX
	ECDemo *demo = [[ECDemo alloc] initWithVM:[[watchController watch]vm]];
	[watchController addDemo:demo];

	NSString *expr = [self verifyAttr:attributeDict key:@"firstAct" for:nam];
	if (expr != nil) {
	    demo.firstAct = [vm compileInstructionStreamFromCExpression:expr errorReporter:[ECErrorReporter theErrorReporter]];
	}
	expr = [self verifyAttr:attributeDict key:@"lastAct" for:@"optional"];
	if (expr != nil) {
	    demo.lastAct = [vm compileInstructionStreamFromCExpression:expr errorReporter:[ECErrorReporter theErrorReporter]];
	}
#endif
    }
}

- (void)parserDidDemoPhaseStart:(NSDictionary *)attributeDict {
    if ([self onBase:@"demoPhase"])
	return;

    NSString *nam =[self verifyName:[attributeDict objectForKey:@"name"] hint:@"demoPhase"];    
    if (nam) {
	// check for garbage attributes
	[self noWindows:nam];
	for (NSString *key in attributeDict) {
	    if ([key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"newWatch" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"startTime" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"duration" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"speed" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
	if (!capturingDemo) {
	    [errorDelegate reportError:[NSString stringWithFormat:@"demoPhase element needs to be nested inside a demo element"]];
	    return;
	}
	NSString *startTimeExpr = [self verifyAttr:attributeDict key:@"startTime" for:nam];
	if (startTimeExpr == nil) {
	    return;
	}
#ifdef FIXFIXFIX
	EBVMInstructionStream *instructionStream = [vm compileInstructionStreamFromCExpression:startTimeExpr errorReporter:[ECErrorReporter theErrorReporter]];
	NSDate *startTime = [NSDate dateWithTimeIntervalSinceReferenceDate:[vm evaluateInstructionStream:instructionStream errorReporter:[ECErrorReporter theErrorReporter]]];
	NSString *durationExpr = [self verifyAttr:attributeDict key:@"duration" for:nam];
	if (durationExpr == nil) {
	    return;
	}
	instructionStream = [vm compileInstructionStreamFromCExpression:durationExpr
							  errorReporter:[ECErrorReporter theErrorReporter]];
	double duration = [vm evaluateInstructionStream:instructionStream
					  errorReporter:[ECErrorReporter theErrorReporter]];
	[[watchController demo] addPhase:[[ECDemoPhase alloc]
					     initWithStartTime:startTime
						 newWatchNamed:[attributeDict objectForKey:@"newWatch"]
						      duration:duration
							 speed:[self boundsCheckOpt:attributeDict lb:-1e11 ub:1e11 df:1 name:nam attr:@"speed" optional:true]]];
#endif
    }
}

- (void)parserDidChimeStart:(NSDictionary *)attributeDict {
    // <chime name='quarter' modes='all' tune='agfc' interval='1 * hours()' offset='15 * minutes()' pause='0.5 * seconds()'/>

    if ([self onBase:@"chime"])
	return;
    
    NSString *nam =[self verifyName:[attributeDict objectForKey:@"name"] hint:@"chime"];
    if (nam) {
	// check for garbage attributes
	[self noWindows:nam];
	for (NSString *key in attributeDict) {
	    if ([key compare:@"tune" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"interval" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"offset" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"pause" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}

	// grab the pause expression
	NSString *expr = [self verifyAttr:attributeDict key:@"pause" for:nam];
	if (expr == nil) {
	    return;
	}

	// create the object
	ECWatchTune *part = [[ECWatchTune alloc] initWithName:nam
							  for:[watchController watch]
						     modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
					       updateInterval:[self boundsCheck:attributeDict lb:kECminUpdate ub:kECmaxUpdate df:1 name:nam attr:@"interval"]
					 updateIntervalOffset:[self boundsCheckOpt:attributeDict lb:-kECmaxUpdate ub:kECmaxUpdate df:0 name:nam attr:@"offset" optional:true]
							pause:[[[watchController watch] vm] compileInstructionStreamFromCExpression:expr errorReporter:[ECErrorReporter theErrorReporter]]
							 tune:[self verifyAttr:attributeDict key:@"tune" for:nam] ];
	
	// create the controller	
	if (part) {
	    [[watchController watch] addChime:part];
	    [[[ECTuneController alloc] initWithModel:part master:watchController grabPrio:ECGrabPrioDefault envSlot:0 cornerRelative:false specialness:ECPartNotSpecial
				    specialParameter:0] release];		    
	    [part release];
	}
    }
}

- (void)parserDidButtonStart:(NSDictionary *)attributeDict {
    // <button	name='Lap / Reset' x='130' y=' 86' modes='front' action='stopwatchReset()' w='10' h='40' src='stem.png' xMotion='10' yMotion='0' scale='1' motion='manualSet()?1:0' />
    
    if ([self onBase:@"button"])
	return;
    
    NSString *nam =[self verifyName:[attributeDict objectForKey:@"name"] hint:@"button"];
    if (nam) {
	// check for garbage attributes
//	[self noWindows:nam];	    // windows are ignored, ie. passed on to the next part
	for (NSString *key in attributeDict) {
	    if ([key compare:@"action" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"motion" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"x" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"y" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"w" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"h" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"scale" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"xMotion" options:NSLiteralSearch] == NSOrderedSame ||
		[key compare:@"yMotion" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"animSpeed" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"rotation" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"opacity" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"modes" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"src" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"grabPrio" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"cornerRelative" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"repeatStrategy" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"immediate" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"expanded" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"flipOnBack" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"enabled" options:NSLiteralSearch] == NSOrderedSame	||
		[key compare:@"name" options:NSLiteralSearch] == NSOrderedSame ) {
		// ok
	    } else {
		[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized attribute '%@' for %@:%@", key, currentWatchName, nam]];	    
		return;
	    }
	}
	
	// grab the action and motion expressions
	NSString *actionExpr = [self verifyAttr:attributeDict key:@"action" for:@"optional"];
	if (actionExpr == nil) {
	    return;
	}
	NSString *motionExpr = [self verifyAttr:attributeDict key:@"motion" for:@"optional"];
	if (motionExpr == nil) {
	    return;
	}
	NSString *xMotion = [self verifyAttr:attributeDict key:@"xMotion" for:@"optional"];
	NSString *yMotion = [self verifyAttr:attributeDict key:@"yMotion" for:@"optional"];
	EBVMInstructionStream *xOffsetStream =
	    xMotion
	    ? [[[watchController watch] vm] compileInstructionStreamFromCExpression:[NSString stringWithFormat:@"(%@) * (%@) *%f", motionExpr, xMotion, scaler] errorReporter:[ECErrorReporter theErrorReporter]]
	    : nil;
	EBVMInstructionStream *yOffsetStream =
	    yMotion
	    ? [[[watchController watch] vm] compileInstructionStreamFromCExpression:[NSString stringWithFormat:@"(%@) * (%@) *%f", motionExpr, yMotion, scaler] errorReporter:[ECErrorReporter theErrorReporter]]
	    : nil;

	// create the object
	ECWatchButton *part = [[ECWatchButton alloc] initWithName:nam
							 forWatch:[watchController watch]
							 modeMask:[self boundsCheckOpt:attributeDict lb:ECmaskLB ub:ECmaskUB df:frontMask name:nam attr:@"modes" optional:true]
							   action:[[[watchController watch] vm] compileInstructionStreamFromCExpression:actionExpr errorReporter:[ECErrorReporter theErrorReporter]] 
						   updateInterval:ECDynamicUpdateNextEnvChange
					     updateIntervalOffset:0
						       masterPart:nil
						      angleStream:nil
						    xOffsetStream:xOffsetStream
						    yOffsetStream:yOffsetStream
						offsetAngleStream:nil];
	
	// create the controller (which, in this case, creates its own view)
	if (part) {
	    UIImage *image2x = nil;
	    UIImage *image4x=nil;
	    UIImage *img = [self verifyImageFile:[attributeDict objectForKey:@"src"] for:nil optional:false image2x:&image2x image4x:&image4x];
	    double w = 0, h = 0;
	    if (img) {
		if ([attributeDict objectForKey:@"w"] != nil || [attributeDict objectForKey:@"h"] != nil) {
		    [errorDelegate reportError:[NSString stringWithFormat:@"w and h not allowed with src for %@:%@", currentWatchName, nam]];	    
		}
	    } else {
		w = [self boundsCheck:attributeDict lb:0 ub:xm*2 df:0 name:nam attr:@"w"] * scaler;
		h = [self boundsCheck:attributeDict lb:0 ub:ym*2 df:0 name:nam attr:@"h"] * scaler;
	    }
	    [[watchController watch] addButton:part];
	    [[[ECButtonController alloc] initWithModel:part
						master:watchController
						 image:img
					       image2x:image2x
					       image4x:image4x
					       opacity:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:1 name:nam attr:@"opacity" optional:true]
						     x:[self boundsCheck:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"x"] * scaler
						     y:[self boundsCheck:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"y"] * scaler    
						 width:w
						height:h
					enabledControl:[self boundsCheckOpt:attributeDict lb:ECButtonEnabledControlLB ub:ECButtonEnabledControlUB df:ECButtonEnabledStemOutOnly name:nam attr:@"enabled" optional:true]
					repeatStrategy:[self boundsCheckOpt:attributeDict lb:ECPartRepeatStrategyLB ub:ECPartRepeatStrategyUB df:ECPartRepeatsAndAcceleratesOnce name:nam attr:@"repeatStrategy" optional:true]
					     immediate:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"immediate" optional:true]
					      expanded:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"expanded" optional:true]
					    flipOnBack:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:1 name:nam attr:@"flipOnBack" optional:true]
						xScale:[self boundsCheckOpt:attributeDict lb:kECminScale ub:kECmaxScale df:kECdefaultScale name:nam attr:@"scale" optional:true]
						yScale:[self boundsCheckOpt:attributeDict lb:kECminScale ub:kECmaxScale df:kECdefaultScale name:nam attr:@"scale" optional:true]
					     animSpeed:[self boundsCheckOpt:attributeDict lb:0 ub:100 df:1 name:nam attr:@"animSpeed" optional:true]
					      grabPrio:[self boundsCheckOpt:attributeDict lb:ECGrabPrioLB ub:ECGrabPrioUB df:ECGrabPrioDefault name:nam attr:@"grabPrio" optional:true]
					       envSlot:[self boundsCheckOpt:attributeDict lb:0 ub:ECEnvUB df:0 name:nam attr:@"envSlot" optional:true]
					   specialness:[self boundsCheckOpt:attributeDict lb:ECPartSpecialLB ub:ECPartSpecialUB df:ECPartNotSpecial name:nam attr:@"special" optional:true]
				      specialParameter:0
					cornerRelative:[self boundsCheckOpt:attributeDict lb:0 ub:1 df:0 name:nam attr:@"cornerRelative" optional:true]
					      rotation:[self boundsCheckOpt:attributeDict lb:-2*M_PI ub:2*M_PI df:0 name:nam attr:@"rotation" optional:true]
					       xMotion:[self boundsCheckOpt:attributeDict lb:-xm ub:xm df:0 name:nam attr:@"xMotion" optional:true] * scaler
					       yMotion:[self boundsCheckOpt:attributeDict lb:-ym ub:ym df:0 name:nam attr:@"yMotion" optional:true] * scaler] release];		    
	    [part release];
	}
    }
}

static int debugIndentationLevel = 0;

#if EC_HENRY_ANDROID
- (ECAndroidStatusBarLocation)getStatusBarLocation:(NSDictionary *)attributeDict {
    NSString *attr = @"statusBarLoc";
    NSString *stringValue = [attributeDict objectForKey:attr];
    if (stringValue == nil) {
        [errorDelegate reportError:[NSString stringWithFormat:@"Attribute '%@' required for %@", attr, currentWatchName]];
        return ECAndroidStatusBarUnknown;
    } else {
        if ([stringValue compare:@"top" options:(NSCaseInsensitiveSearch)] == NSOrderedSame) {
            return ECAndroidStatusBarTop;
        } else if ([stringValue compare:@"center" options:(NSCaseInsensitiveSearch)] == NSOrderedSame) {
            return ECAndroidStatusBarCenter;
        } else if ([stringValue compare:@"bottom" options:(NSCaseInsensitiveSearch)] == NSOrderedSame) {
            return ECAndroidStatusBarBottom;
        } else {
            [errorDelegate reportError:[NSString stringWithFormat:@"Attribute '%@' has unrecogized value '%@' for %@", attr, stringValue, currentWatchName]];
            return ECAndroidStatusBarUnknown;
        }
    }
}
#endif

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {

#ifdef DEBUG_LOAD
    int i;
    for (i = 0; i < debugIndentationLevel; i++) {
	printf("   ");
    }
    debugIndentationLevel++;
    NSString *name = [attributeDict objectForKey:@"name"];
    printf("Start element %s [%s]\n", [elementName UTF8String], name ? [name UTF8String] : "");
#endif

    NSString *aName = [attributeDict objectForKey:@"name"];
    // This would be faster with a dictionary lookup of selectors, or just by constructing a selector from the element name:
    if ([elementName caseInsensitiveCompare:@"watch"] == NSOrderedSame) {
	// <watch name='Howard' background='img.png' >
	NSString *wName = [[watchController watch] name];
	if ([wName            compare:aName options:(NSCaseInsensitiveSearch)] != NSOrderedSame ||
	    [currentWatchName compare:aName options:(NSCaseInsensitiveSearch)] != NSOrderedSame ||
	    [currentWatchName compare:wName options:(NSCaseInsensitiveSearch)] != NSOrderedSame) {
	    [errorDelegate reportError:[NSString stringWithFormat:@"Name mismatch for watch\n%@ != %@ != %@", currentWatchName, aName, wName]];
	    return;
	}
#ifdef EC_HENRY_ANDROID
        int faceWidth = [self boundsCheckOpt:attributeDict lb:1 ub:320 df:0 name:aName attr:@"faceWidth" optional:false];
        [watchController setFaceWidth:faceWidth];
        int statusBarLocation = [self getStatusBarLocation:attributeDict];
        [watchController setStatusBarLocation:statusBarLocation];
#endif
	int numEnvironments = [self boundsCheckOpt:attributeDict lb:1 ub:(ECEnvUB+1) df:1 name:aName attr:@"numEnvironments" optional:true];
	[[watchController watch] setNumEnvironments:numEnvironments];
	int beatsPerSecond = [self boundsCheckOpt:attributeDict lb:0 ub:20 df:0 name:aName attr:@"beatsPerSecond" optional:true];
	[[watchController watch] setBeatsPerSecond:beatsPerSecond];
        if ([attributeDict objectForKey:@"beatsPerSecond"] == nil && [aName compare:@"Background"] != NSOrderedSame) {
            printf("Warning: watch %s has no beatsPerSecond attribute\n", [aName UTF8String]);
        }
	int maxSeparateLoc = [self boundsCheckOpt:attributeDict lb:0 ub:ECEnvUB df:0 name:aName attr:@"maxSeparateLoc" optional:true];
	[[watchController watch] setMaxSeparateLoc:maxSeparateLoc];
	double landscapeZoomFactor = [self boundsCheckOpt:attributeDict lb:0.5 ub:2.0 df:1.0 name:aName attr:@"landscapeZoomFactor" optional:true];
	[[watchController watch] setLandscapeZoomFactor:landscapeZoomFactor];
	UIImage *bgImg2x;
	UIImage *bgImg4x;
	UIImage *bgImg = [self verifyImageFile:[attributeDict objectForKey:@"background"] for:nil optional:false image2x:&bgImg2x image4x:&bgImg4x];
	if (bgImg != nil) {
	    [errorDelegate reportError:[NSString stringWithFormat:@"background attribute on watch %@ is obsolete", aName]];
	    return;
	}
    } else if ([elementName caseInsensitiveCompare:@"QDial"] == NSOrderedSame) {
	[self parserDidQDialStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"Qtext"] == NSOrderedSame) {
	[self parserDidQtextStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"QHand"] == NSOrderedSame) {
	[self parserDidQHandStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"QWedge"] == NSOrderedSame) {
	[self parserDidQWedgeStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"QRect"] == NSOrderedSame) {
	[self parserDidQRectStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"Image"] == NSOrderedSame) {
	[self parserDidImageStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"terminator"] == NSOrderedSame) {
	[self parserDidTerminatorStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"CalendarHeader"] == NSOrderedSame) {
	[self parserDidCalendarHeaderStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"CalendarRowCover"] == NSOrderedSame) {
	[self parserDidCalendarRowCoverStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"init"] == NSOrderedSame) {
	[self parserDidInitStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"hand"] == NSOrderedSame) {
	[self parserDidHandStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"blinker"] == NSOrderedSame) {
	[self parserDidBlinkerStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"QWheel"] == NSOrderedSame) {
	[self parserDidQWheelStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"SWheel"] == NSOrderedSame) {
	[self parserDidSWheelStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"TWheel"] == NSOrderedSame) {
	[self parserDidTWheelStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"window"] == NSOrderedSame) {
	[self parserDidWindowStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"tick"] == NSOrderedSame) {
	[self parserDidTickStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"demo"] == NSOrderedSame) {
	[self parserDidDemoStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"demoPhase"] == NSOrderedSame) {
	[self parserDidDemoPhaseStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"QdayNightRing"] == NSOrderedSame) {
	[self parserDidDayNightRingStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"chime"] == NSOrderedSame) {
	[self parserDidChimeStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"button"] == NSOrderedSame) {
	[self parserDidButtonStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"center"] == NSOrderedSame) {
	[self parserDidCenterStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"static"] == NSOrderedSame) {
	[self parserDidStaticStart:attributeDict];
    } else if ([elementName caseInsensitiveCompare:@"atlas"] == NSOrderedSame) {
	[self parserDidAtlasStart:attributeDict];
    } else {
	[errorDelegate reportError:[NSString stringWithFormat:@"Unrecognized element %@ in description for watch\n%@", elementName, currentWatchName]];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{            
    if ([elementName caseInsensitiveCompare:@"demo"] == NSOrderedSame) {
	capturingDemo = false;
    } else if ([elementName caseInsensitiveCompare:@"static"] == NSOrderedSame) {
	[self parserDidStaticEnd];
    } else {
	// ignore
    }
    debugIndentationLevel--;
#ifdef DEBUG_LOAD
    int i;
    for (i = 0; i < debugIndentationLevel; i++) {
	printf("   ");
    }
    printf("End   element %s\n", [elementName UTF8String]);
#endif
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    [errorDelegate reportError:[parseError localizedDescription]];
    //printf("Saw error %s\n", [[parseError localizedDescription] UTF8String]);
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{        
    NSScanner *scanner = [NSScanner scannerWithString:string];
    [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
    if (![scanner isAtEnd]) {
	[errorDelegate reportError:[NSString stringWithFormat:@"Saw non-whitespace characters in watch %@ not in element definition: %@", currentWatchName, string]];
    }
}

@end
