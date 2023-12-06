//
//  ECGLTexture.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 8/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "Constants.h"
#import "ECGLTexture.h"
#import "ECErrorReporter.h"
#import "ECGlobals.h"
#import "ChronometerAppDelegate.h"
#import "ECWatchArchive.h"
#import "ECGLWatchLoader.h"
#import "ECAppLog.h"
#import "ECGLWatch.h"

#include <sys/stat.h>
#include <sys/time.h>

#include <stdatomic.h>  // For atomic_thread_fence()

@interface ECPNGQueueEntry : NSObject {
@public
    UIImage *image;
    NSString *cachePath;
    struct timeval times[2];
}

@end

@implementation ECPNGQueueEntry
@end

@interface ECGLTextureAtlas (ECGLTextureAtlasPrivate)

- (void)drawSpecialPartsIntoContext:(CGContextRef)context withInputStatBuf:(struct stat *)inputStatbuf;

@end

@implementation ECGLTextureAtlas;

@synthesize numRequiredWatchModes, textureID, path, width, height, textureVertices;

static NSMutableDictionary *atlasesByRelativePath = nil;
static size_t totalLoadedSize = 0;

+ (NSString *)fullPathForRelativePath:(NSString *)relativePath {
    NSString *path = [NSString stringWithFormat:@"%@/%@", ECbundleArchiveDirectory, relativePath];
    if (![ECfileManager fileExistsAtPath:path]) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Can't find archive for path %@", relativePath]];
	return nil;
    }
    return path;
}

- (id)initWithRelativePath:(NSString *)relativePath width:(int)aWidth height:(int)aHeight {
    [super init];
    loadLock = [[NSLock alloc] init];
    textureLoadedSize = 0;
    textureData = NULL;
    textureVertices = NULL;
    vertexReservedSize = 0;
    width = aWidth;
    height = aHeight;
    attached = false;
    markForUnattach = false;
    path = [[ECGLTextureAtlas fullPathForRelativePath:relativePath] retain];
    cachePath = nil;  // for now; if necessary we'll change this if and when there are special parts and we subsequently load
    specialDisplayLists = nil;
    assert(atlasesByRelativePath);  // clients shouldn't call this init method
    assert([atlasesByRelativePath objectForKey:relativePath] == nil);
    [atlasesByRelativePath setObject:self forKey:relativePath];
    return self;
}

static NSMutableSet *specialTextures = nil;

- (void)dealloc {
    assert(false);  // Should never delete texture aliases -- just unload them if you need memory
    assert(specialDisplayLists == nil);
    assert(![specialTextures containsObject:self]);
    [path release];
    [loadLock release];
    if (textureVertices) {
	free(textureVertices);
    }
    [super dealloc];
}

- (int)reserveBytesAndReturnOffset:(int)sizeToReserve {
    int offset = vertexReservedSize;
    vertexReservedSize += sizeToReserve;
    return offset;
}

- (size_t) textureLoadedSize {
    return textureLoadedSize;
}

+ (void)initStatics {
    atlasesByRelativePath = [[NSMutableDictionary alloc] initWithCapacity:15];
}

+ (ECGLTextureAtlas *)atlasForRelativePath:(NSString *)relativePath
				    create:(bool)create
				     width:(int)width
				    height:(int)height
				zoomPower2:(int)z2 {
    if (!atlasesByRelativePath) {
	[ECGLTextureAtlas initStatics];
    }
    assert([[relativePath pathExtension] caseInsensitiveCompare:@"png"] == NSOrderedSame);
    NSString *relPath = [NSString stringWithFormat:@"%@-Z%d.png", [relativePath stringByDeletingPathExtension], z2];
    ECGLTextureAtlas *atlas = [atlasesByRelativePath objectForKey:relPath];
    if (atlas || !create) {
	return atlas;
    }
    atlas = [[ECGLTextureAtlas alloc] initWithRelativePath:relPath width:width height:height];
    return atlas;
}

+ (size_t)totalLoadedSize {
    return totalLoadedSize;
}

static bool qualifyTextureDimension(size_t dimension) {
    switch (dimension) {
      case 4096:
      case 2048:
      case 1024:
      case 512:
      case 256:
      case 128:
      case 64:
      case 32:
      case 16:
      case 8:
      case 4:
      case 2:
      case 1:
	return true;
      default:
	return false;
    }
}

- (void)loadTextureCoordinates {
    if (!textureVertices) {
	NSString *vertexFilePath = [path stringByReplacingOccurrencesOfString:@".png" withString:@".dat"];
	ECWatchArchive *vertexArchive = [[ECWatchArchive alloc] initForReadingFromPath:vertexFilePath];
	int numParts = [vertexArchive readInteger];
	textureVertices = (ECDLCoordType *)malloc(numParts * 2 * 2 * 3 * sizeof(ECDLCoordType));
	ECDLCoordType *textureVertexPtr = textureVertices;
	for (int i = 0; i < numParts; i++) {
	    CGRect textureBounds = [vertexArchive readRect];
	    int flipper = [vertexArchive readInteger];
	    bool flipX = (flipper & 0x1);
	    bool flipY = (flipper & 0x2) != 0;

	    // Note:  These vertices are flipped from what I expected.  Oh well, it works...
	    ECDLCoordType left, right, top, bottom;
	    if (flipX) {
		right = textureBounds.origin.x;
		left = textureBounds.origin.x + textureBounds.size.width;
	    } else {
		left = textureBounds.origin.x;
		right = textureBounds.origin.x + textureBounds.size.width;
	    }
	    if (flipY) {
		bottom = textureBounds.origin.y;
		top = textureBounds.origin.y + textureBounds.size.height;
	    } else {
		top = textureBounds.origin.y;
		bottom = textureBounds.origin.y + textureBounds.size.height;
	    }

	    // triangle 1
	    *textureVertexPtr++ = left;
	    *textureVertexPtr++ = top;
	    *textureVertexPtr++ = right;
	    *textureVertexPtr++ = top;
	    *textureVertexPtr++ = left;
	    *textureVertexPtr++ = bottom;
	    // triangle 2
	    *textureVertexPtr++ = right;
	    *textureVertexPtr++ = top;
	    *textureVertexPtr++ = left;
	    *textureVertexPtr++ = bottom;
	    *textureVertexPtr++ = right;
	    *textureVertexPtr++ = bottom;
	}
	[vertexArchive finishReading];
	[vertexArchive release];
    }
}

// redOverlay
static double redOverlayValue = 0;

+ (double)redOverlay {
    return redOverlayValue;
}

+ (void)setRedOverlay:(double)n {
	assert(0 <= n && n <= 1);
    redOverlayValue = n;
}

- (void)calculateCachePath {
    assert(!cachePath);
    cachePath = [[path stringByReplacingOccurrencesOfString:ECbundleArchiveDirectory withString:ECcacheArchiveDirectory] retain];
}

// Texture states:
// 1.  Not loaded, unattached (starting state)
// 2.  Loaded, unattached (1 => loadTexture => 2, 2 => unLoadTexture => 1)
// 3.  Loaded, attached (2 => attachTexture => 3)
// 4.  Loaded, attached, markForUnattach (3 => unLoadTexture => 4, 4 => loadTexture => 3)
// textureLoadedSize reflects need to load or unload, not actual attach/unattach state
- (void)loadTexture {
    [loadLock lock];
    assert(numRequiredWatchModes == 1);
    assert(textureLoadedSize == 0);
    bool needToRedrawSpecials = false;
    NSString *pathToLoad = path;
    struct stat inputStatbuf;  // Yes, I know this is uninitialized.  I know what I'm doing.
    if (specialDisplayLists) {
	stat([path UTF8String], &inputStatbuf);  // Record inputStatbuf time; we'll need it no matter what we do if there are special parts
        bool firstTime = (cachePath == nil);
	if (!cachePath) {  // If we haven't set up the name and created the directory
	    [self calculateCachePath];
	    assert(cachePath);
	    NSString *cachePathParent = [cachePath stringByDeletingLastPathComponent];
	    //printf("cachePath = %s\ncachePathParent = %s\n", [cachePath UTF8String], [cachePathParent UTF8String]);
	    if (![ECfileManager fileExistsAtPath:cachePathParent]) {
		NSError *error;
		if(![ECfileManager createDirectoryAtPath:cachePathParent withIntermediateDirectories:YES attributes:nil error:&error]) {
		    [[ECErrorReporter theErrorReporter]
			reportError:[NSString stringWithFormat:@"Couldn't create special part archive directory %@: %@",
					      cachePathParent,
					      [error localizedDescription]]];
		}
                ESSetFileNotBackedUp([cachePathParent UTF8String]);
	    }
	}
//	printf("Loading texture with special parts %s\n", [cachePath UTF8String]);
	struct stat statbuf;
	int st = stat([cachePath UTF8String], &statbuf);
	if (st != 0) {  // file doesn't exist, or trouble reading it
//	    printf("...cache missing, need to recreate\n");
	    needToRedrawSpecials = true;
	    pathToLoad = path;
	} else { // the cached file does exist, check its timestamp against the timestamp of the input archive
	    double cacheModDate =      statbuf.st_mtimespec.tv_sec +      statbuf.st_mtimespec.tv_nsec / 1000000000.0;
	    double inputModDate = inputStatbuf.st_mtimespec.tv_sec + inputStatbuf.st_mtimespec.tv_nsec / 1000000000.0;
	    if (fabs(cacheModDate - inputModDate) > 0.000002) {  // precision of stat is higher than precision to which we can set modtime with utimes()
//		printf("...cache exists but out of date, need to recreate (cache %.10f - input %.10f = %.10f)\n",
//		       cacheModDate, inputModDate, cacheModDate - inputModDate);
		needToRedrawSpecials = true;
		pathToLoad = path;
	    } else {
//		printf("...cache exists, up to date, using it\n");
                if (firstTime) {
                    ESSetFileNotBackedUp([cachePath UTF8String]);  // yust in case
                }
		needToRedrawSpecials = false;
		pathToLoad = cachePath;
	    }
	}
    }
#if 0
    NSArray *pathComp = [pathToLoad pathComponents];
    int numComp = [pathComp count];
    NSString *description = [NSString stringWithFormat:@"%s/%s %s texture",
			      [[pathComp objectAtIndex:(numComp - 2)] UTF8String],
			      [[pathComp objectAtIndex:(numComp - 1)] UTF8String],
			      attached ? "reattach" : "load"];
    [ChronometerAppDelegate noteTimeAtPhase:[description UTF8String]];
#endif
#ifdef MEMORY_TRACK_TEXTURE
    NSArray *pathComp = [pathToLoad pathComponents];
    int numComp = [pathComp count];
    NSString *description = [NSString stringWithFormat:@"%s %s/%s %s texture",
			      ([NSThread isMainThread] ? "FG" : "BG"),
			      [[pathComp objectAtIndex:(numComp - 2)] UTF8String],
			      [[pathComp objectAtIndex:(numComp - 1)] UTF8String],
			      attached ? "reattach" : "load"];
    [ChronometerAppDelegate noteTextureMemoryBeforeOperation:description];
#endif
    size_t loadedSize = width * height * 4;
    if (attached) {
	assert(markForUnattach);
	markForUnattach = false;
    } else {
	[self loadTextureCoordinates];  // This is a no-op if this isn't the first load ever
	// [ChronometerAppDelegate noteTimeAtPhase:"load texture start"];
	CGImageRef cgImage = [UIImage imageWithContentsOfFile:pathToLoad].CGImage;
	// [ChronometerAppDelegate noteTimeAtPhase:"done with cgImage create"];
#ifndef NDEBUG
	size_t imWidth = CGImageGetWidth(cgImage);
	size_t imHeight = CGImageGetHeight(cgImage);
	assert(imWidth == (size_t)width);
	assert(imHeight == (size_t)height);
	//printf("Loaded image at path %s, %dx%d\n", [pathToLoad UTF8String], (int)imWidth, (int)imHeight);
#endif
#ifdef EC_HENRY
	if (!qualifyTextureDimension(width)) {
	    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Texture width %d not a power of two <= max supported at %@", width, pathToLoad]];
	    [loadLock unlock];
	    return;
	}
	if (!qualifyTextureDimension(height)) {
	    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Texture height %d not a power of two <= max supported at %@", height, pathToLoad]];
	    [loadLock unlock];
	    return;
	}
#endif
	assert(!textureData);
	textureData = (GLubyte *) calloc(1, loadedSize);  // clear memory to avoid simulator bug
	CGContextRef bitmapContext = CGBitmapContextCreate(textureData, width, height, 8, width * 4, CGImageGetColorSpace(cgImage), kCGImageAlphaPremultipliedLast);
	assert(bitmapContext != NULL);
	// [ChronometerAppDelegate noteTimeAtPhase:"done with cg context create"];
	CGRect sz = CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height);
	if (redOverlayValue > 0) {
	    CGContextSetFillColorWithColor(bitmapContext, [[UIColor colorWithRed:redOverlayValue green:0 blue:0 alpha:1] CGColor]);
	    CGContextFillRect(bitmapContext, sz);
	    // Here we have a solid pure red in the context bitmap
	    // Apply the image transparency to it
	    CGContextSetBlendMode(bitmapContext, kCGBlendModeDestinationIn);
	    CGContextDrawImage(bitmapContext, sz, cgImage);
	    // Now the bitmap should have the transparency of the image but nothing else
	    // Now apply the luminosity of the image to it
	    CGContextSetBlendMode(bitmapContext, kCGBlendModeLuminosity);
	}
	CGContextDrawImage(bitmapContext, sz, cgImage);
	if (specialDisplayLists && needToRedrawSpecials) {
	    [self drawSpecialPartsIntoContext:bitmapContext withInputStatBuf:&inputStatbuf];
	}
	// [ChronometerAppDelegate noteTimeAtPhase:"done with cg context draw"];
	CGContextRelease(bitmapContext);
    }
    textureLoadedSize = loadedSize;
    totalLoadedSize += textureLoadedSize;
#ifdef MEMORY_TRACK_TEXTURE
    [ChronometerAppDelegate printTextureMemoryBeforeAfterOperation:description];
#endif
    [loadLock unlock];
}

- (void)attachTexture {
    assert([NSThread isMainThread]);
    [loadLock lock];
    if (attached) {
	assert(!textureData);
	[loadLock unlock];
	return;
    }
#ifdef MEMORY_TRACK_TEXTURE
    NSArray *pathComp = [path pathComponents];
    int numComp = [pathComp count];
    NSString *description = [NSString stringWithFormat:@"%s/%s attach texture",
			      [[pathComp objectAtIndex:(numComp - 2)] UTF8String],
			      [[pathComp objectAtIndex:(numComp - 1)] UTF8String]];
    [ChronometerAppDelegate noteTextureMemoryBeforeOperation:description];
#endif
//    [ChronometerAppDelegate reduceLoadedTexturesEnoughToAttach:textureLoadedSize];
    assert(textureData);
    assert(textureLoadedSize > 0);
    //[ChronometerAppDelegate noteTimeAtPhase:"attachTexture"];
    //do {
        glGenTextures(1, &textureID);
    //} while (textureID <= 20);  // Avoid using low ids to avoid conflicting with broken MKMapView widget
#ifndef NDEBUG
    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
	printf("OpenGL error %d\n", err);
        assert(false);
    }
#endif
    //printf("textureID is %u\n", textureID);
    //[ChronometerAppDelegate noteTimeAtPhase:"done with glGenTextures"];
    glBindTexture(GL_TEXTURE_2D, textureID);
#ifndef NDEBUG
    err = glGetError();
    if (err != GL_NO_ERROR) {
	printf("OpenGL error %d\n", err);
        assert(false);
    }
#endif
    //[ChronometerAppDelegate noteTimeAtPhase:"done with glBindTexture"];
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, textureData);
#ifndef NDEBUG
    err = glGetError();
    if (err != GL_NO_ERROR) {
	printf("OpenGL error %d\n", err);
        assert(false);
    }
#endif
    //[ChronometerAppDelegate noteTimeAtPhase:"done with glTexImage2D"];
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
#ifndef NDEBUG
    err = glGetError();
    if (err != GL_NO_ERROR) {
	printf("OpenGL error %d\n", err);
        assert(false);
    }
#endif
    //[ChronometerAppDelegate noteTimeAtPhase:"done with glTexParameteri"];
    free(textureData);
    textureData = NULL;
    markForUnattach = false;
    attached = true;
#ifdef MEMORY_TRACK_TEXTURE
    [ChronometerAppDelegate printTextureMemoryBeforeAfterOperation:description];
#endif
    [loadLock unlock];
}

- (void)unattachIfMarked {
    assert([NSThread isMainThread]);
    if (attached && markForUnattach) {  // first check, for performance we don't lock
	[loadLock lock];
	if (attached && markForUnattach) {  // now make sure
#ifdef MEMORY_TRACK_TEXTURE
	    NSArray *pathComponents = [path pathComponents];
	    int numComponents = [pathComponents count];
	    NSString *description = [NSString stringWithFormat:@"%s/%s unattach texture",
					      [[pathComponents objectAtIndex:(numComponents - 2)] UTF8String],
					      [[pathComponents objectAtIndex:(numComponents - 1)] UTF8String]];
	    [ChronometerAppDelegate noteTextureMemoryBeforeOperation:description];
#endif
	    assert(attached);
	    assert(!textureData);
	    glDeleteTextures(1, &textureID);
	    textureID = -1;
	    attached = false;
	    markForUnattach = false;
#ifdef MEMORY_TRACK_TEXTURE
	    [ChronometerAppDelegate printTextureMemoryBeforeAfterOperation:description];
#endif
	}
	[loadLock unlock];
    }
}

// return true if we need to unattach
- (bool)unloadTexture {
    [loadLock lock];
    assert(numRequiredWatchModes == 0);
    assert(textureLoadedSize > 0);
    assert(![NSThread isMainThread] || [ChronometerAppDelegate inBackground]);
#ifdef MEMORY_TRACK_TEXTURE
    NSArray *pathComponents = [path pathComponents];
    int numComponents = [pathComponents count];
    NSString *description = [NSString stringWithFormat:@"%s/%s texture unattach/unload",
				      [[pathComponents objectAtIndex:(numComponents - 2)] UTF8String],
				      [[pathComponents objectAtIndex:(numComponents - 1)] UTF8String]];
    [ChronometerAppDelegate noteTextureMemoryBeforeOperation:description];
#endif
    bool returnValue;
    if (attached) {
	markForUnattach = true;
	assert(!textureData);  // This triggered
	returnValue = true;
    } else {
	assert(textureData);
	free(textureData);
	textureData = NULL;
	returnValue = false;
    }
    totalLoadedSize -= textureLoadedSize;
    textureLoadedSize = 0;
#ifdef MEMORY_TRACK_TEXTURE
    description = [NSString stringWithFormat:@"%s/%s %s texture",
			    [[pathComponents objectAtIndex:(numComponents - 2)] UTF8String],
			    [[pathComponents objectAtIndex:(numComponents - 1)] UTF8String],
			    attached ? "mark for unattach" : "unload"];
    [ChronometerAppDelegate printTextureMemoryBeforeAfterOperation:description];
#endif
    [loadLock unlock];
    return returnValue;
}

-(void)forceUnloadOrUnattachWithLoadLockLocked:(bool)loadLockedOnEntry { // Used for red mode, and for special part reload
    assert([NSThread isMainThread]);
    if (!loadLockedOnEntry) {
	[loadLock lock];
    }
    if (textureLoadedSize == 0) {
	if (!loadLockedOnEntry) {
	    [loadLock unlock];
	}
	return;
    }
#ifdef MEMORY_TRACK_TEXTURE
    NSArray *pathComponents = [path pathComponents];
    int numComponents = [pathComponents count];
    NSString *description = [NSString stringWithFormat:@"%s/%s force unattach/unload texture",
				      [[pathComponents objectAtIndex:(numComponents - 2)] UTF8String],
				      [[pathComponents objectAtIndex:(numComponents - 1)] UTF8String]];
    [ChronometerAppDelegate noteTextureMemoryBeforeOperation:description];
#endif
    if (attached) {
	assert(attached);
	assert(!textureData);
	glDeleteTextures(1, &textureID);
	textureID = -1;
	attached = false;
	markForUnattach = false;
    } else {
	assert(textureLoadedSize > 0);
	assert(textureData);
	free(textureData);
	textureData = NULL;
    }
    numRequiredWatchModes = 0;
    totalLoadedSize -= textureLoadedSize;
    textureLoadedSize = 0;
#ifdef MEMORY_TRACK_TEXTURE
    [ChronometerAppDelegate printTextureMemoryBeforeAfterOperation:description];
#endif
    if (!loadLockedOnEntry) {
	[loadLock unlock];
    }
}

-(void)forceUnloadOrUnattach { // Used when switching to or from red mode
    [self forceUnloadOrUnattachWithLoadLockLocked:false];
}

- (size_t)bytesNeededForLoad {
    assert(numRequiredWatchModes >= 0);
    if (numRequiredWatchModes == 0 && textureLoadedSize == 0) {
	return width * height * 4;
    }
    return 0;
}


// watchPartModeRequiresLoad is used when a watch's mode's texture is bg loaded
- (void)watchPartModeRequiresLoad {
    assert(numRequiredWatchModes >= 0);
    if (numRequiredWatchModes++ == 0 && textureLoadedSize == 0) {
	[self loadTexture];
    }
}

// watchPartModeReleasesLoad is used when a memory limit is reached and we ...
- (size_t)watchPartModeReleasesLoadNeedingUnattach:(bool *)needUnattach {
    assert(numRequiredWatchModes > 0);
    if (--numRequiredWatchModes == 0) {
	*needUnattach = [self unloadTexture];
	return width * height * 4;
    }
    return 0;
}

- (void)registerSpecialDisplayList:(ECGLDisplayList *)displayList {
    if (!specialTextures) {
	specialTextures = [[NSMutableSet alloc] initWithCapacity:6];
    }
    [specialTextures addObject:self];
    if (!specialDisplayLists) {
	specialDisplayLists = [[NSMutableSet alloc] initWithCapacity:5];
    }
    [specialDisplayLists addObject:displayList];
}

- (void)unregisterSpecialDisplayList:(ECGLDisplayList *)displayList {
    assert(specialDisplayLists);
    assert([specialDisplayLists containsObject:displayList]);
    [specialDisplayLists removeObject:displayList];
    if ([specialDisplayLists count] == 0) {
	[specialDisplayLists release];
	specialDisplayLists = nil;
	assert(specialTextures);
	assert([specialTextures containsObject:self]);
	[specialTextures removeObject:self];
	if ([specialTextures count] == 0) {
	    [specialTextures release];
	    specialTextures = 0;
	}
    }
}

static NSMutableArray *pngWritingQueue = nil;
static NSLock *pngWritingQueueLock = nil;

- (void)drawSpecialPartsIntoContext:(CGContextRef)context withInputStatBuf:(struct stat *)inputStatbuf{
    assert(![NSThread isMainThread]);

    // Now tell each part (via the display lists) to draw into the proper location of the texture
    for (ECGLDisplayList *displayList in specialDisplayLists) {
	[displayList drawSpecialPartsForTextureAtlas:self intoContext:context atlasSize:CGRectMake(0, 0, width, height)];
    }

    // dump context into cache file
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    assert(cgImage);
    UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
    assert(uiImage);

    if (!pngWritingQueue) {
	pngWritingQueueLock = [[NSLock alloc] init];
	atomic_thread_fence(memory_order_seq_cst);  // Make sure the lock gets created and seen before the queue
	pngWritingQueue = [[NSMutableArray alloc] initWithCapacity:6];  // Each side of Terra with three zoom levels each
    }
    [pngWritingQueueLock lock];
    ECPNGQueueEntry *queueEntry = [[[ECPNGQueueEntry alloc] init] autorelease];
    queueEntry->image = [uiImage retain];
    queueEntry->cachePath = [cachePath retain];
    queueEntry->times[0].tv_sec  = queueEntry->times[1].tv_sec  = inputStatbuf->st_mtimespec.tv_sec;
    queueEntry->times[0].tv_usec = queueEntry->times[1].tv_usec = inputStatbuf->st_mtimespec.tv_nsec / 10;
    
    [pngWritingQueue insertObject:queueEntry atIndex:0];
    [pngWritingQueueLock unlock];

}

// Return true iff did something
+ (bool)writeOnePngTestOnly:(bool)testOnly {
    if (pngWritingQueue) {
	assert(pngWritingQueueLock);
	[pngWritingQueueLock lock];
	if ([pngWritingQueue count] == 0) {
	    [pngWritingQueueLock unlock];
	    return false;
	}
	if (testOnly) {
	    [pngWritingQueueLock unlock];
	    return true;
	}
	ECPNGQueueEntry *queueEntry = [[pngWritingQueue lastObject] retain];
	[pngWritingQueue removeLastObject];
	UIImage *uiImage = queueEntry->image;
	NSString *cachePath = queueEntry->cachePath;
	[pngWritingQueueLock unlock];

	NSData *imageData = UIImagePNGRepresentation(uiImage);
	assert(imageData);
	NSError *error;
	if (![imageData writeToFile:cachePath options:NSAtomicWrite error:&error]) {
	    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Couldn't write PNG file to %@: %@", cachePath, [error localizedDescription]]];
	}
        ESSetFileNotBackedUp([cachePath UTF8String]);
//	printf("Writing png for %s\n", [cachePath UTF8String]);
	// Now record the modtime of the input file as the modtime of the output file; if the input ever changes we'll kill the output and redo it
	// struct timeval times[2];
	// [0] is access
	// [1] is mod time
	int st = utimes([cachePath UTF8String], queueEntry->times);
	if (st != 0) {
	    perror("Can't change the mod time of the cachePath file\n");
	}

	CGImageRelease([uiImage CGImage]);
	[uiImage release];
	[cachePath release];
	[queueEntry release];
	[ECAppLog log:[NSString stringWithFormat:@"Created special part atlas"]];
	return true;
    } else {
	return false;
    }
}

- (void)invalidateSpecialPartsAddingSpecialWatchesToSet:(NSMutableSet *)specialWatches {
    assert([NSThread isMainThread]);
    assert(specialDisplayLists);  // else we shouldn't be registered
    for (ECGLDisplayList *displayList in specialDisplayLists) {
	[displayList addWatchesForSpecialPartsToSet:specialWatches];
    }    
    [loadLock lock];
    if (!cachePath) {  // If we haven't set up the name and created the directory
	[self calculateCachePath];
    }
    assert(cachePath);
    if ([ECfileManager fileExistsAtPath:cachePath]) {  // The directory exists, but there's no cached file
	NSError *error;
//	printf("removing cached texture with special parts %s\n", [cachePath UTF8String]);
	if (![ECfileManager removeItemAtPath:cachePath error:&error]) {
	    [[ECErrorReporter theErrorReporter]
		reportError:[NSString stringWithFormat:@"Couldn't clear cached atlas at %@: %@", cachePath, [error localizedDescription]]];
	}
    }
    [loadLock unlock];
}

+ (void)invalidateSpecialParts {
    assert([NSThread isMainThread]);
    NSMutableSet *specialWatches = [[NSMutableSet alloc] initWithCapacity:1];
    for (ECGLTextureAtlas *textureAtlas in specialTextures) {
	[textureAtlas invalidateSpecialPartsAddingSpecialWatchesToSet:specialWatches];
    }
    for (ECGLWatch *watch in specialWatches) {
	[watch unloadAllTextures];
    }
    [specialWatches release];
    [ECGLWatchLoader checkForWork];
}

- (CGSize)size {
    return CGSizeMake(width, height);
}

- (void)print {
    printf("%9ld bytes loaded for image %s\n", textureLoadedSize, [path UTF8String]);
}

- (void)printFull {
    printf("Texture atlas %s\n", [path UTF8String]);
    if (textureVertices) {
	printf("...vertexReservedSize %d (%.2f parts)\n",
	       vertexReservedSize, (vertexReservedSize / ( 2.0 * 2 * 3 * sizeof(ECDLCoordType))));
    }
}

- (void)handleMemoryWarning {
    assert(numRequiredWatchModes >= 0);
    if (numRequiredWatchModes == 0 && textureLoadedSize > 0) {
	[self unloadTexture];
    }
}

+ (void)handleMemoryWarning {
    for (NSString *relativePath in atlasesByRelativePath) {
	ECGLTextureAtlas *atlas = [atlasesByRelativePath objectForKey:relativePath];
	assert(atlas);
	[atlas handleMemoryWarning];
    }
}

- (void)reportMemoryUsage:(size_t *)attachedSize pendingSize:(size_t *)pendingSize loaded:(bool *)isLoaded attached:(bool *)isAttached {
    *isAttached = attached;
    *isLoaded = (textureLoadedSize > 0);
    if (attached) {
	*pendingSize = 0;
	*attachedSize = textureLoadedSize;
    } else {
	*pendingSize = textureLoadedSize;
	*attachedSize = 0;
    }
}

+ (void)reportMemoryUsage:(size_t *)totAttachedSize pendingSize:(size_t *)totPendingSize numLoaded:(int *)numLoaded numAttached:(int *)numAttached numTotal:(int *)numTotal {
    *totAttachedSize = 0;
    *totPendingSize = 0;
    *numLoaded = 0;
    *numAttached = 0;
    *numTotal = 0;
    for (NSString *relativePath in atlasesByRelativePath) {
	ECGLTextureAtlas *atlas = [atlasesByRelativePath objectForKey:relativePath];
	assert(atlas);
	(*numTotal)++;
	size_t attachedSize;
	size_t pendingSize;
	bool isLoaded;
	bool isAttached;
	[atlas reportMemoryUsage:&attachedSize pendingSize:&pendingSize loaded:&isLoaded attached:&isAttached];
	if (isAttached) {
	    (*numAttached)++;
	}
	if (isLoaded) {
	    (*numLoaded)++;
	}
	*totAttachedSize += attachedSize;
	*totPendingSize += pendingSize;
    }
}

+ (void)reportAllAttachedOrLoadedTextures {
    for (NSString *relativePath in atlasesByRelativePath) {
	ECGLTextureAtlas *atlas = [atlasesByRelativePath objectForKey:relativePath];
	assert(atlas);
	size_t attachedSize;
	size_t pendingSize;
	bool isLoaded;
	bool isAttached;
	[atlas reportMemoryUsage:&attachedSize pendingSize:&pendingSize loaded:&isLoaded attached:&isAttached];
        if (isAttached || isLoaded) {
            printf("%s%s %s\n",
                   isAttached ? " ATTACHED" : "",
                   isLoaded ? " LOADED" : "",
                   [relativePath UTF8String]);
        }
    }
}

@end
