//
//  ECGLAtlasLayout.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 8/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "ECGLAtlasLayout.h"
#import "ECGLTexture.h"
#import "ECWatchArchive.h"
#import "ECErrorReporter.h"
#import "ECGlobals.h"
#import "Constants.h"

#define LocalPadding (1)

@implementation ECGLAtlasLayout

typedef struct BlockPoint {
    int x;
    int y;
} BlockPoint;

static BlockPoint
BlockPointMake(int x, int y) {
    BlockPoint bp;
    bp.x = x;
    bp.y = y;
    return bp;
}

typedef struct BlockSize {
    int width;
    int height;
} BlockSize;

static BlockSize
BlockSizeMake(int width, int height) {
    BlockSize bs;
    bs.width = width;
    bs.height = height;
    return bs;
}

typedef struct BlockRect {
    BlockPoint origin;
    BlockSize size;
} BlockRect;

static BlockRect
BlockRectMake(int x, int y, int width, int height) {
    BlockRect br;
    br.origin.x = x;
    br.origin.y = y;
    br.size.width = width;
    br.size.height = height;
    return br;
}

typedef struct TextureData {
    int        mask;  // day, night, back
    BlockSize  size;
    BlockPoint frontPlacedLocation;
    BlockPoint backPlacedLocation;
    BlockPoint nightPlacedLocation;
    bool       isPlaced;
    UIImage    *image;
    NSString   *relativePath;
} TextureData;

static int maxTexture(int zoomPower) {
    switch(zoomPower) {
      case 2:
        return 4096;
      case 1:
        return 2048;
      default:
        return 1024;
    }
}

static int
roundUpToPowerOfTwo(int num,
		    int zoomPower,
                    int deviceWidth) {
    if (deviceWidth == 0) {
        assert(num <= maxTexture(zoomPower) && num > 0);
    }
    if (num > 2048) {
	return 4096;
    }
    if (num > 1024) {
	return 2048;
    }
    if (num > 512) {
	return 1024;
    }
    if (num > 256) {
	return 512;
    }
    if (num > 128) {
	return 256;
    }
    if (num > 64) {
	return 128;
    }
    if (num > 32) {
	return 64;
    }
    if (num > 16) {
	return 32;
    }
    if (num > 8) {
	return 16;
    }
    if (num > 4) {
	return 8;
    }
    if (num > 2) {
	return 4;
    }
    if (num > 1) {
	return 2;
    }
    assert(num == 1);
    return 1;
}

struct LayoutHints {
    const char *watchName;
    int hint[5][ECNumWatchDrawModes];
} layoutHints[] = {
    {
	"default",
	{
//           F     N     B	
	    { 128,  128,  128, }, // Z -2
	    { 256,  256,  256, }, // Z -1
	    { 512,  512,  512, }, // Z  0
	    { 1024, 1024, 1024,}, // Z  1
	    { 2048, 2048, 2048,}, // Z  2
	},
    },
    {
	"Alexandria",
	{
//           F     N     B	
	    { 256,  256,  256, }, // Z -2
	    { 512,  512,  512, }, // Z -1
	    { 1024, 1024, 1024,}, // Z  0
	    { 2048, 2048, 2048,}, // Z  1
	    { 4096, 4096, 4096,}, // Z  2
	},
    },
    {
	"Atlantis",
	{
	    { 256,  256,  256, },
	    { 512,  512,  512, },
	    { 1024, 1024, 1024,},
	    { 2048, 2048, 2048,}, // Z  1
	    { 4096, 4096, 4096,}, // Z  2
	},
    },
    {
	"Terra",
	{
	    { 128,  128,  128, },
	    { 256,  256,  256, },
	    { 1024,  512,  512, },
	    { 2048, 1024, 1024,}, // Z  1
	    { 4096, 4096, 4096,}, // Z  2
	},
    },
    {
	"Background",
	{
	    { 256,  256,  256, },
	    { 512,  512,  512, },
	    { 1024, 1024, 1024,},
	    { 2048, 2048, 2048,}, // Z  1
	    { 4096, 4096, 4096,}, // Z  2
	},
    },
    {
	"Babylon",
	{
	    { 256,  256,  256, },
	    { 512,  512,  512, },
	    { 1024, 1024, 1024,},
	    { 2048, 2048, 2048,}, // Z  1
	    { 4096, 4096, 4096,}, // Z  2
	},
    },
    {
	"Chandra",
	{
	    { 256,  128,  128, },
	    { 512,  512,  256, },
	    { 1024, 1024, 512, },
	    { 2048, 2048, 1024,}, // Z  1
	    { 4096, 4096, 2048,}, // Z  2
	},
    },
    {
	"Firenze",
	{
	    { 128,  128,  256, },
	    { 256,  256,  512, },
	    { 512,  512,  512, },
	    { 1024, 1024, 1024,}, // Z  1
	    { 2048, 2048, 2048,}, // Z  2
	},
    },
    {
	"Geneva",
	{
	    { 128,  128,  256, },
	    { 256,  256,  512, },
	    { 512,  512,  1024,},
	    { 1024, 1024, 2048,}, // Z  1
	    { 2048, 2048, 4096,}, // Z  2
	},
    },
    {
	"Istanbul",
	{
	    { 128,  256,  256, },
	    { 512,  512,  512, },
	    { 1024, 1024, 1024,},
	    { 2048, 2048, 2048,}, // Z  1
	    { 4096, 4096, 4096,}, // Z  2
	},
    },
    {
	"London",
	{
	    { 256,  256,  256, },
	    { 512,  512,  512, },
	    { 1024, 1024, 1024,},
	    { 2048, 2048, 2048,}, // Z  1
	    { 4096, 4096, 4096,}, // Z  2
	},
    },
    {
	"Mauna Kea",
	{
	    { 256,  256,  256, },
	    { 512,  512,  512, },
	    { 1024, 1024, 1024,},
	    { 2048, 2048, 2048,}, // Z  1
	    { 4096, 4096, 4096,}, // Z  2
	},
    },
    {
	"McAlester",
	{
	    { 256,  256,  256, },
	    { 512,  512,  512, },
	    { 1024, 1024, 1024,},
	    { 2048, 2048, 2048,}, // Z  1
	    { 4096, 4096, 4096,}, // Z  2
	},
    },
    {
	"Olympia",
	{
	    { 128,  128,  128, },
	    { 256,  256,  512, },
	    { 512,  512,  512, },
	    { 1024, 1024, 2048,}, // Z  1
	    { 2048, 2048, 4096,}, // Z  2
	},
    },
    {
	"Paris",
	{
	    { 256,  256,  256, },
	    { 512,  512,  512, },
	    { 1024, 1024, 1024,},
	    { 2048, 2048, 2048,}, // Z  1
	    { 4096, 4096, 4096,}, // Z  2
	},
    },
    {
	"Terra",
	{
	    { 128,  128,  256, },
	    { 256,  256,  512, },
	    { 512,  512,  1024, },
	    { 1024, 1024, 2048,}, // Z  1
	    { 2048, 2048, 4096,}, // Z  2
	},
    },
    {
	"Tombstone",
	{
	    { 256,  256,  256, },
	    { 512,  512,  512, },
	    { 1024, 1024, 1024,},
	    { 2048, 2048, 2048,}, // Z  1
	    { 4096, 4096, 4096,}, // Z  2
	},
    },
};
static const int numLayoutHintWatches = sizeof(layoutHints) / sizeof(struct LayoutHints);
static int findLayoutHint(NSString        *watchName,
			  int             zoomIndex,
			  ECWatchModeEnum watchMode) {
#ifdef EC_CWH_ANDROID
    static NSMutableSet *messageEmitted = nil;
    if (!messageEmitted) {
        messageEmitted = [[NSMutableSet alloc] init];
    }
#ifdef ATLAS_DEBUG
    bool emitMessage = ![messageEmitted containsObject:watchName];
#else
    bool emitMessage = FALSE;
#endif
    [messageEmitted addObject:watchName];
    if ([watchName hasSuffix:@" I"]) {
        if (emitMessage) printf("CWHA mapping '%s", [watchName UTF8String]);
        watchName = [watchName substringToIndex:[watchName length] - 2];
        if (emitMessage) printf("' to '%s'\n", [watchName UTF8String]);
    } else if ([watchName hasSuffix:@" II"]) {
        if (emitMessage) printf("CWHA mapping '%s", [watchName UTF8String]);
        watchName = [watchName substringToIndex:[watchName length] - 3];
        watchMode = ECbackMode;
        if (emitMessage) printf("' to '%s' and mode back\n", [watchName UTF8String]);
    }
#endif
    for (int i = 0; i < numLayoutHintWatches; i++) {
	if ([watchName caseInsensitiveCompare:[NSString stringWithUTF8String:layoutHints[i].watchName]] == NSOrderedSame) {
	    return layoutHints[i].hint[zoomIndex][watchMode];
	}
    }
    return layoutHints[0].hint[zoomIndex][watchMode];
}

#if EC_HENRY_ANDROID
struct DeviceWidthLayoutHints {
    const char *watchName;
    int hint[numAndroidWatchOutputWidths][ECNumWatchDrawModes];
} deviceWidthLayoutHints[] = {

    {
        "Alexandria I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Alexandria I-south",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Atlantis I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Atlantis II",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Babylon I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Babylon I-monday",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Babylon I-saturday",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Cairo I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Chandra I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Selene I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Firenze I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Padua I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Geneva I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Basel I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Haleakala I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Hana I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Hernandez I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Kyoto I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Kyoto II",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Mauna Kea I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Mauna Loa I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "McAlester I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Miami I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Venezia I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Milano I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Olympia I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Paris I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Paris I-black",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Terra I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Gaia I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Uraniborg I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Uraniborg II",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Vienna I",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Vienna I-midnight",
        {
            // F     N     B
            { 1024, 1024, 1024, }, // 480
        }
    },
    {
        "Demo Control",
        {
            // F     N     B
            { 128,  128, 128, }, // 480
        }
    },
};

static const int numDeviceWidthLayoutHintWatches = sizeof(deviceWidthLayoutHints) / sizeof(struct DeviceWidthLayoutHints);
static int findDeviceWidthLayoutHint(NSString        *watchName,
                                     int             deviceWidth,
                                     ECWatchModeEnum watchMode) {
    int deviceWidthIndex = -1;
    for (int widthIndex = 0; widthIndex < numAndroidWatchOutputWidths; widthIndex++) {
        if (androidWatchOutputWidths[widthIndex] == deviceWidth) {
            deviceWidthIndex = widthIndex;
        }
    }
    if (deviceWidthIndex >= 0) {
        for (int i = 0; i < numDeviceWidthLayoutHintWatches; i++) {
            if ([watchName caseInsensitiveCompare:[NSString stringWithUTF8String:deviceWidthLayoutHints[i].watchName]] == NSOrderedSame) {
                return deviceWidthLayoutHints[i].hint[deviceWidthIndex][watchMode];
            }
        }
    }
    assert(false);
    return 0;
}
#else
static int findDeviceWidthLayoutHint(NSString        *watchName,
                                     int             deviceWidth,
                                     ECWatchModeEnum watchMode) {
    assert(false);  // Not in HenryForAndroid
    return 0;
}
#endif


static int recurseLevel = 0;

// return width actually used
// NOTE NOTE NOTE:  Up is really down.  That is, when I wrote this code, I assumed that 0 was the top of the image as with UIImage.
// But this code uses CGImages, for which 0 is at the bottom.  So instead of starting at the top of the area and working down (with increasing y),
// we're really starting at the bottom and working up (with increasing y).  It all works out.
static int
useAvailableSpace(BlockRect space,
		  NSArray   *sortedTextures,
		  int       mode,
		  int       zoomPower,
                  int       deviceWidth,
		  int       freeWidthRightEdge,
		  int       *alreadyPlaced) {

#undef ATLAS_DEBUG
#ifdef ATLAS_DEBUG
    for (int i = 0; i < recurseLevel; i++) printf("  ");
    printf("useAvailableSpace %4d %4d %4d %4d (already placed %d out of %lu)\n",
           space.origin.x, space.origin.y, space.size.width, space.size.height,
           *alreadyPlaced, (unsigned long)[sortedTextures count]);
    fflush(stdout);
#endif
    recurseLevel++;
    if (recurseLevel > 50) {
	recurseLevel--;
	printf("Infinite recursion in useAvailableSpace\n");
	fflush(stdout);
	assert(false);
	return 0;
    }
    int elementIndex = 0;
    int numElements = [sortedTextures count];

    // Find the first element (if any) whose height will fit in the available height
    int elementHeight = 0;
    while (elementIndex < numElements) {
	TextureData *element = (TextureData *)[[sortedTextures objectAtIndex:elementIndex] bytes];
	if (element->isPlaced) {
	    elementIndex++;
	    continue;
	}
	if (element->size.height <= space.size.height) {
	    elementHeight = element->size.height;
	    break;
	}
	elementIndex++;
    }
    if (elementIndex == numElements) {
	recurseLevel--;
#ifdef ATLAS_DEBUG
	// Didn't find one
	for (int i = 0; i < recurseLevel; i++) printf("  ");
	printf("End (without elements) useAvailableSpace\n");
	fflush(stdout);
#endif
	return 0;
    }
    assert(elementIndex < numElements);
    // element here points to an element that will fit in the available height; 
    // place all elements of that height that will fit in the available width
    int rowRight = space.origin.x + space.size.width;
    int cellLeft = space.origin.x;
#ifdef ATLAS_DEBUG
    TextureData *element = (TextureData *)[[sortedTextures objectAtIndex:elementIndex] bytes];
    printf("valid elementIndex %d, elementHeight %d, elementWidth %d, cellLeft %d, rowRight %d\n",
            elementIndex, elementHeight, element->size.width, cellLeft, rowRight);
#endif
    bool didACell = false;
    while (elementIndex < numElements) {
	TextureData *element = (TextureData *)[[sortedTextures objectAtIndex:elementIndex] bytes];
	if (element->isPlaced) {
	    elementIndex++;
	    continue;
	}
	if (element->size.height != elementHeight) {
	    break;
	}
	if (cellLeft + element->size.width <= rowRight) {
	    switch (mode) {
	      case frontMask:
		element->frontPlacedLocation.x = cellLeft + LocalPadding;
		element->frontPlacedLocation.y = space.origin.y + LocalPadding;
		break;
	      case backMask:
		element->backPlacedLocation.x = cellLeft + LocalPadding;
		element->backPlacedLocation.y = space.origin.y + LocalPadding;
		break;
	      case nightMask:
		element->nightPlacedLocation.x = cellLeft + LocalPadding;
		element->nightPlacedLocation.y = space.origin.y + LocalPadding;
		break;
	      default:
		assert(false);
	    }
	    element->isPlaced = true;
#ifdef ATLAS_DEBUG
            NSString *debugPath = element->relativePath;
            if ([debugPath length] > 20) {
                debugPath = [@".." stringByAppendingString:[debugPath substringFromIndex:[debugPath length] - 20]];
            }
            for (int i = 0; i < recurseLevel; i++) printf("  ");
            printf("%4d %4d %4d %4d Placed %s\n", cellLeft, space.origin.y,
                   element->size.width, element->size.height,
                   [debugPath UTF8String]);
            fflush(stdout);
#endif
	    cellLeft += element->size.width;
	    didACell = true;
	    (*alreadyPlaced)++;
	}
	elementIndex++;
    }
    // Here we've placed all elements of the first height in a row.  There remain two rectangles from the original space:
    // 1) the space to the right of this row, with the same height, up to the edge of the available space.
    //    This rectangle can be divided into:
    //    a) The space for which there is already somebody above (freeWidthRightEdge)
    //    b) The space for which there is not already somebody above (freeWidthRightEdge => availableWidth)
    // 2) the space below this row, all the way across the available space.
    // We should first take 1a), because it costs nothing and will otherwise be lost
    // Then we take 2) because again it costs nothing until 2) extends outward to the right
    
    // First 1a):
    int widthUsed = cellLeft - space.origin.x;
    assert (cellLeft <= rowRight);
    if (didACell && *alreadyPlaced < numElements && cellLeft < freeWidthRightEdge) {
	widthUsed += useAvailableSpace(BlockRectMake(cellLeft, space.origin.y, freeWidthRightEdge - cellLeft, elementHeight), sortedTextures, mode, zoomPower, deviceWidth, freeWidthRightEdge, alreadyPlaced);
    }
    // Then 2):
    int widthUsedBelow = 0;
    if (*alreadyPlaced < numElements && elementHeight < space.size.height) {
	int rowWidth = useAvailableSpace(BlockRectMake(space.origin.x, space.origin.y + elementHeight, space.size.width, space.size.height - elementHeight), sortedTextures, mode, zoomPower, deviceWidth, roundUpToPowerOfTwo(cellLeft, zoomPower, deviceWidth), alreadyPlaced);
	widthUsedBelow = rowWidth;
    }
    // Recurse on available space to the right (rectangle 1):
    assert (cellLeft <= rowRight);
    if (widthUsed > 0 || widthUsedBelow > 0) { // Don't bother recurse if we're just going to try again with the same rectangle
	if (*alreadyPlaced < numElements && cellLeft < rowRight) {
	    int blockLeft = cellLeft < freeWidthRightEdge ? freeWidthRightEdge : cellLeft;
	    widthUsed += useAvailableSpace(BlockRectMake(blockLeft, space.origin.y, rowRight - blockLeft, elementHeight), sortedTextures, mode, zoomPower, deviceWidth, freeWidthRightEdge, alreadyPlaced);
	}
	if (widthUsedBelow > widthUsed) {
	    widthUsed = widthUsedBelow;
	}
    }
    recurseLevel--;
#ifdef ATLAS_DEBUG
    for (int i = 0; i < recurseLevel; i++) printf("  ");
    printf("End useAvailableSpace using width %d\n", widthUsed);
#endif
    return widthUsed;
}

static NSInteger
textureBlockSorter(id   id2,
		   id   id1,
		   void *context) {
    TextureData *textureData1 = (TextureData *)[id1 bytes];
    TextureData *textureData2 = (TextureData *)[id2 bytes];
    if (textureData1->size.height < textureData2->size.height) {
	return NSOrderedAscending;
    } else if (textureData1->size.height > textureData2->size.height) {
	return NSOrderedDescending;
    } else if (textureData1->size.width < textureData2->size.width) {
	return NSOrderedAscending;
    } else if (textureData1->size.width > textureData2->size.width) {
	return NSOrderedDescending;
    } else {
	return NSOrderedSame;
    }
}

static void
writeMergedAtlas(NSArray    *textures,
		 NSString   *mergedAtlasName,
		 int        mode,
		 int        zoomPower,
                 int        deviceWidth,
		 NSString   *archiveDirectory,
		 int        width,
		 int        height,
		 int        *writtenWidth,
		 int        *writtenHeight) {
    //printf("\nmergedAtlas %s will contain:\n", [mergedAtlasName UTF8String]);
    int imageWidth = roundUpToPowerOfTwo(width, zoomPower, deviceWidth);
    int imageHeight = roundUpToPowerOfTwo(height, zoomPower, deviceWidth);
    *writtenWidth = imageWidth;
    *writtenHeight = imageHeight;
    size_t bitsPerComponent = 8;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    assert(colorSpace);
    CGContextRef context = CGBitmapContextCreate(NULL, imageWidth, imageHeight, bitsPerComponent, 0,
						 colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);
    assert(context);
    UIGraphicsPushContext(context);
    
    for (NSData *textureId in textures) {
	TextureData *textureData = (TextureData *)[textureId bytes];
	BlockPoint *placedLocation = NULL;
	switch (mode) {
	  case frontMask:
	    placedLocation = &textureData->frontPlacedLocation;
	    break;
	  case backMask:
	    placedLocation = &textureData->backPlacedLocation;
	    break;
	  case nightMask:
	    placedLocation = &textureData->nightPlacedLocation;
	    break;
	  default:
	    assert(false);
	    placedLocation = &textureData->nightPlacedLocation;		//  shut up warning
	}
//	printf("  %4d %4d %4d %4d %s\n",
//	       placedLocation->x, placedLocation->y,
//	       textureData->size.width, textureData->size.height,
//	       [textureData->relativePath UTF8String]);
	assert(textureData->isPlaced);
	CGContextDrawImage(context,
			   CGRectMake(placedLocation->x,
				      placedLocation->y,
				      textureData->size.width - (2 * LocalPadding),
				      textureData->size.height - (2 * LocalPadding)),
			   [textureData->image CGImage]);
    }
    UIGraphicsPopContext();
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    assert(cgImage);
    UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
    assert(uiImage);
    NSData *imageData = UIImagePNGRepresentation(uiImage);
    assert(imageData);
    NSError *error;
    NSString *path = [archiveDirectory stringByAppendingPathComponent:mergedAtlasName];
    if (![imageData writeToFile:path options:NSAtomicWrite error:&error]) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Couldn't write PNG file to %@: %@", path, [error localizedDescription]]];
    }
    assert(colorSpace == CGBitmapContextGetColorSpace(context));
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
}

static void
placeTextureArray(NSArray    *textures,
		  int        mode,
		  int        zoomPower,
                  int        deviceWidth,
		  NSString   *mergedAtlasName,
		  NSString   *archiveDirectory,
		  int        capXRange,
		  int        *writtenWidth,
		  int        *writtenHeight) {
    // Sort by height, then width
    NSMutableArray *sortedTextures = [[NSMutableArray alloc] initWithCapacity:[textures count]];
    [sortedTextures setArray:textures];
    [sortedTextures sortUsingFunction:textureBlockSorter context:NULL];

    // unplace any textures that were placed on a previous side (e.g., front when we're now doing back)
    for (NSData *textureId in textures) {
	TextureData *textureData = (TextureData *)[textureId bytes];
	textureData->isPlaced = false;
    }

    int rowTop = 0;
    int maxWidthUsedAbove = 0;
#ifdef ATLAS_DEBUG
    printf("\n\n\n MODE %d %d\n", mode, deviceWidth);
#endif
    while (1) {
	assert([sortedTextures count] > 0);
	// Get height of first element
	TextureData *firstElement = (TextureData *)[[sortedTextures objectAtIndex:0] bytes];
	assert(!firstElement->isPlaced);
	int rowHeight = firstElement->size.height;
        if (deviceWidth == 0) {
            assert(rowTop + rowHeight <= maxTexture(zoomPower)); // FIX FIX FIX, but for now:  We can only handle one texture per side
        }
	int alreadyPlaced = 0;
	int width = useAvailableSpace(BlockRectMake(0, rowTop, capXRange, rowHeight), sortedTextures, mode, zoomPower, deviceWidth, maxWidthUsedAbove, &alreadyPlaced);
	assert(width > 0);
	if (width > maxWidthUsedAbove) {
	    maxWidthUsedAbove = roundUpToPowerOfTwo(width, zoomPower, deviceWidth);  // It's "used" in the sense that the archive will be that big anyway
	}
	rowTop += rowHeight;
	NSMutableArray *unplacedTextures = [[NSMutableArray alloc] initWithCapacity:[sortedTextures count]];
	bool foundUnplaced = false;
	for (NSData *textureId in sortedTextures) {
	    TextureData *textureData = (TextureData *)[textureId bytes];
	    if (!textureData->isPlaced) {
		[unplacedTextures addObject:textureId];
		foundUnplaced = true;
	    }
	}
	if (foundUnplaced) {
	    [sortedTextures release];
	    sortedTextures = unplacedTextures;
	} else {
	    [unplacedTextures release];
	    break;
	}
    }
    [sortedTextures release];
    writeMergedAtlas(textures, mergedAtlasName, mode, zoomPower, deviceWidth, archiveDirectory, maxWidthUsedAbove, rowTop, writtenWidth, writtenHeight);
}

// Should be a mirror of ECGLWatch::initFromArchiveAtPath: withName:
+ (void)mergeWatchAtlasesFromArchive:(NSString *)fromArchivePath
			   toArchive:(NSString *)toArchivePath
		 usingVirtualMachine:(EBVirtualMachine *)vm
			   watchName:(NSString *)watchName
		  inArchiveDirectory:(NSString *)archiveDirectory
		usingPngsInDirectory:(NSString *)partPngDirectory
		   isBackgroundWatch:(bool)isBackgroundWatch
                      forDeviceWidth:(int)deviceWidth
                   deviceWidthSuffix:(NSString *)deviceWidthSuffix
	     expectingFrontAtlasSize:(CGSize)expectedFrontAtlasSize
	      expectingBackAtlasSize:(CGSize)expectedBackAtlasSize
	     expectingNightAtlasSize:(CGSize)expectedNightAtlasSize {
    ECWatchArchive *watchArchive = [[ECWatchArchive alloc] initForReadingFromPath:fromArchivePath];
    if (!watchArchive) {
	return;
    }
    [watchArchive readInteger]; // faceWidth
    [watchArchive readInteger]; // numEnvironments
    [watchArchive readInteger]; // maxSeparateLoc
    [watchArchive readDouble];  // landscapeZoomFactor
    [watchArchive readInteger]; // beatsPerSecond
    [watchArchive readInteger]; // statusBarLoc
    int numTextures = [watchArchive readInteger];
    NSMutableArray *texturesByZoom[ECNumVisualZoomFactors];
    int i;
    for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	texturesByZoom[j] = [[NSMutableArray alloc] initWithCapacity:numTextures];
    }
    for (i = 0; i < numTextures; i++) {
	NSString *texturePathBase = [watchArchive readString];
	NSString *texturePathRoot = [texturePathBase stringByDeletingPathExtension];
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    [watchArchive readInteger];  // texture width; ignore
	    [watchArchive readInteger];  // texture height; ignore
	    NSString *texturePath;
            if (deviceWidth != 0) {
                // When deviceWidth != 0, it means we have a hardware watch device, and we only use one zoom factor.
                // By convention, we use the z=0 (zoom=1.0) zoom index.
                if (j != ECZoom0Index) continue;
                texturePath = texturePathRoot;  // The path written in the archive contains the width suffix already.
            } else {
                if (isBackgroundWatch && j < ECZoom0Index) continue;
                texturePath = [texturePathRoot stringByAppendingFormat:@"-Z%d.png", j + ECZoomMinPower2];
            }
	    UIImage *textureImage = [[UIImage alloc] initWithContentsOfFile:texturePath];
            if (!textureImage) {
                printf("No texture image at derived location:\n%s\n", [texturePath UTF8String]);
                assert(textureImage);
            }
	    TextureData textureBytes;
	    textureBytes.mask = 0;
	    CGSize cgSize = [textureImage size];
	    textureBytes.size.width = round(cgSize.width) + 2 * LocalPadding;
	    textureBytes.size.height = round(cgSize.height) + 2 * LocalPadding;
	    //	assert(textureBytes.size.width == textureWidth);
	    //	assert(textureBytes.size.height == textureHeight);
	    assert(textureBytes.size.width <= maxTexture(j+ECZoomMinPower2) && textureBytes.size.height <= maxTexture(j+ECZoomMinPower2));
	    textureBytes.image = textureImage;
	    textureBytes.relativePath = [texturePath retain];  // not really a relative path but it doesn't matter here
	    textureBytes.isPlaced = false;
	    NSData *textureData = [NSData dataWithBytes:&textureBytes length:sizeof(TextureData)];
	    [texturesByZoom[j] addObject:textureData];
	}
    }
    [watchArchive readInteger];  // numVariables
    int numInits = [watchArchive readInteger];
    for (i = 0; i < numInits; i++) {
	[watchArchive readInstructionStreamForVirtualMachine:vm];
    }
    int numParts = [watchArchive readInteger];
    for (i = 0; i < numParts; i++) {
	int frontTextureSlot;
	int backTextureSlot;
	int nightTextureSlot;
	CGRect boundsOnScreen;
	CGPoint anchorOnScreen;
	double updateInterval;
	double updateIntervalOffset;
	ECWatchTimerSlot updateTimer;
	int modeMask;
	int handKind;
	bool flipOnBack;
	bool flipX;
	bool flipY;
	bool centerPixelOnly;
	ECDragType dragType;
	ECDragAnimationType dragAnimationType;
	double animSpeed;
	int grabPrio;
	int envSlot;
	ECPartSpecialness specialness;
	unsigned int specialParameter;
	bool norotate;
	bool cornerRelative;
	ECAnimationDirection animDir;
	EBVMInstructionStream *angleInstructionStream;
	EBVMInstructionStream *xOffsetInstructionStream;
	EBVMInstructionStream *yOffsetInstructionStream;
	double offsetRadius;
	EBVMInstructionStream *offsetAngleInstructionStream;
	EBVMInstructionStream *actionInstructionStream;
	bool immediate, expanded;
	ECPartRepeatStrategy repeatStrategy;
	int masterIndex;
	ECButtonEnabledControl enabledControl;
	[watchArchive readWatchPartDataWithFrontTextureSlot:&frontTextureSlot
					    backTextureSlot:&backTextureSlot
					   nightTextureSlot:&nightTextureSlot
					     boundsOnScreen:&boundsOnScreen
					     anchorOnScreen:&anchorOnScreen
					     updateInterval:&updateInterval
				       updateIntervalOffset:&updateIntervalOffset
						updateTimer:&updateTimer
						   modeMask:&modeMask
						   handKind:&handKind
						   dragType:&dragType
					  dragAnimationType:&dragAnimationType
						  animSpeed:&animSpeed
						    animDir:&animDir
						   grabPrio:&grabPrio
						    envSlot:&envSlot
						specialness:&specialness
					   specialParameter:&specialParameter
						   norotate:&norotate
					     cornerRelative:&cornerRelative
						 flipOnBack:&flipOnBack
						      flipX:&flipX
						      flipY:&flipY
					    centerPixelOnly:&centerPixelOnly
					usingVirtualMachine:vm
				     angleInstructionStream:&angleInstructionStream
				   xOffsetInstructionStream:&xOffsetInstructionStream
				   yOffsetInstructionStream:&yOffsetInstructionStream
					       offsetRadius:&offsetRadius
			       offsetAngleInstructionStream:&offsetAngleInstructionStream
				    actionInstructionStream:&actionInstructionStream
					     repeatStrategy:&repeatStrategy
						  immediate:&immediate
						   expanded:&expanded
						masterIndex:&masterIndex
					     enabledControl:&enabledControl];
	// This method is used on raw image data, which has the same texture slot for all modes:
	assert(frontTextureSlot == backTextureSlot);
	assert(frontTextureSlot == nightTextureSlot);
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    if (isBackgroundWatch && j < ECZoom0Index) continue;
            if (deviceWidth != 0 && j != ECZoom0Index) continue;
	    TextureData *textureData = (TextureData *)[[texturesByZoom[j] objectAtIndex:frontTextureSlot] bytes];
	    textureData->mask |= modeMask;
	}
    }
    // Skip noview parts, don't need them here, and single-part archives have no spare-part section
    [watchArchive finishReading];
    [watchArchive release];
    watchArchive = nil;

    int frontWidth[ECNumVisualZoomFactors];
    int frontHeight[ECNumVisualZoomFactors];
    int backWidth[ECNumVisualZoomFactors];
    int backHeight[ECNumVisualZoomFactors];
    int nightWidth[ECNumVisualZoomFactors];
    int nightHeight[ECNumVisualZoomFactors];

    NSMutableArray *spareParts[ECNumVisualZoomFactors];

    // Do all of the placements
    for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	spareParts[j] = [NSMutableArray arrayWithCapacity:10];
        NSString *suffixForZoomOrWidth;
	int z2 = j + ECZoomMinPower2;
        if (deviceWidth != 0) {
            // When deviceWidth != 0, it means we have a hardware watch device, and we only use one zoom factor.
            // By convention, we use the z=0 (zoom=1.0) zoom index.
            if (j != ECZoom0Index) continue;
            assert(z2 == 0);
            suffixForZoomOrWidth = [NSString stringWithFormat:@"W%d", deviceWidth];
        } else {
            if (isBackgroundWatch && j < ECZoom0Index) continue;
            suffixForZoomOrWidth = [NSString stringWithFormat:@"Z%d", z2];
        }
	

	int numFrontTextures = 0;
	int numNightTextures = 0;
	int numBackTextures = 0;
	for (NSData *textureId in texturesByZoom[j]) {
	    TextureData *textureData = (TextureData *)[textureId bytes];
	    if (isBackgroundWatch || (textureData->mask & frontMask)) {
		numFrontTextures++;
	    }
	    if (!isBackgroundWatch) {
		if (textureData->mask & nightMask) {
		    numNightTextures++;
		}
		if (textureData->mask & backMask) {
		    numBackTextures++;
		}
	    }
	}

	// Collect front, night, back (and should have night-back)
	NSMutableArray *frontArray = [NSMutableArray arrayWithCapacity:numFrontTextures];
	NSMutableArray *nightArray = [NSMutableArray arrayWithCapacity:numNightTextures];
	NSMutableArray *backArray = [NSMutableArray arrayWithCapacity:numBackTextures];
    
	for (NSData *textureId in texturesByZoom[j]) {
	    TextureData *textureData = (TextureData *)[textureId bytes];
	    if (isBackgroundWatch || (textureData->mask & frontMask)) {
		[frontArray addObject:textureId];
		if (textureData->mask & spareMask) {
		    [spareParts[j] addObject:textureId];
		}
	    }
	    if (!isBackgroundWatch) {
		if (textureData->mask & nightMask) {
		    [nightArray addObject:textureId];
		}
		if (textureData->mask & backMask) {
		    [backArray addObject:textureId];
		}
	    }
	}
	
        int capX;
        if (deviceWidth != 0) {
            capX = findDeviceWidthLayoutHint(watchName, deviceWidth, ECfrontMode);
        } else {
            capX = findLayoutHint(watchName, j, ECfrontMode);
        }
	placeTextureArray(frontArray, frontMask, z2, deviceWidth,
			  [NSString stringWithFormat:@"front-atlas-%@.png", suffixForZoomOrWidth],
			  archiveDirectory, capX, &frontWidth[j], &frontHeight[j]);
        if (deviceWidth == 0) {
	    if (z2 == 0 && frontWidth[j] != expectedFrontAtlasSize.width) {
	        [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Front atlas width (%d) for watch %@ doesn't match expected width %g",
	    							      frontWidth[j], watchName, (double)expectedFrontAtlasSize.width]];
	    }
	    if (z2 == 0 && frontHeight[j] != expectedFrontAtlasSize.height) {
	        [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Front atlas height (%d) for watch %@ doesn't match expected height %g",
	    							      frontHeight[j], watchName, (double)expectedFrontAtlasSize.height]];
	    }
        }
	if (!isBackgroundWatch) {
            if (deviceWidth != 0) {
                capX = findDeviceWidthLayoutHint(watchName, deviceWidth, ECbackMode);
            } else {
                capX = findLayoutHint(watchName, j, ECbackMode);
            }
	    placeTextureArray(backArray, backMask, z2, deviceWidth,
			      [NSString stringWithFormat:@"back-atlas-%@.png", suffixForZoomOrWidth],
			      archiveDirectory, capX, &backWidth[j], &backHeight[j]);
            if (deviceWidth == 0) {
                if (z2 == 0 && backWidth[j] != expectedBackAtlasSize.width) {
                    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Back atlas width (%d) for watch %@ doesn't match expected width %g",
                                                                              backWidth[j], watchName, (double)expectedBackAtlasSize.width]];
                }
                if (z2 == 0 && backHeight[j] != expectedBackAtlasSize.height) {
                    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Back atlas height (%d) for watch %@ doesn't match expected height %g",
                                                                              backHeight[j], watchName, (double)expectedBackAtlasSize.height]];
                }
            }
            if (deviceWidth != 0) {
                capX = findDeviceWidthLayoutHint(watchName, deviceWidth, ECnightMode);
            } else {
                capX = findLayoutHint(watchName, j, ECnightMode);
            }
	    placeTextureArray(nightArray, nightMask, z2, deviceWidth,
			      [NSString stringWithFormat:@"night-atlas-%@.png", suffixForZoomOrWidth],
			      archiveDirectory, capX, &nightWidth[j], &nightHeight[j]);
            if (deviceWidth == 0) {
                if (z2 == 0 && nightWidth[j] != expectedNightAtlasSize.width) {
                    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Night atlas width (%d) for watch %@ doesn't match expected width %g",
                                                                              nightWidth[j], watchName, (double)expectedNightAtlasSize.width]];
                }
                if (z2 == 0 && nightHeight[j] != expectedNightAtlasSize.height) {
                    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Night atlas height (%d) for watch %@ doesn't match expected height %g",
                                                                              nightHeight[j], watchName, (double)expectedNightAtlasSize.height]];
                }
            }
	}
    }

    // OK, everybody is placed: Now start over, reading and writing simultaneously
    ECWatchArchive *fromWatchArchive = [[ECWatchArchive alloc] initForReadingFromPath:fromArchivePath];
    if (!fromWatchArchive) {
	return;
    }
    ECWatchArchive *toWatchArchive = [[ECWatchArchive alloc] initForWritingIntoPath:toArchivePath];
    if (!toWatchArchive) {
	return;
    }
    [toWatchArchive writeInteger:[fromWatchArchive readInteger]];  // faceWidth
    [toWatchArchive writeInteger:[fromWatchArchive readInteger]];  // numEnvironments
    [toWatchArchive writeInteger:[fromWatchArchive readInteger]];  // maxSeparateLoc
    [toWatchArchive writeDouble:[fromWatchArchive readDouble]];    // landscapeZoomFactor
    [toWatchArchive writeInteger:[fromWatchArchive readInteger]];  // beatsPerSecond
    [toWatchArchive writeInteger:[fromWatchArchive readInteger]];  // statusBarLocation
    
    // Don't write original textures
    numTextures = [fromWatchArchive readInteger];
    for (i = 0; i < numTextures; i++) {
	[fromWatchArchive readString];
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    [fromWatchArchive readInteger];
	    [fromWatchArchive readInteger];
	}
    }

    // We have our own textures (that's the whole point)
    if (isBackgroundWatch) {
	[toWatchArchive writeInteger:1];  // front
    } else {
	[toWatchArchive writeInteger:3];  // front, night, back
    }
    if (deviceWidth == 0) {
        [toWatchArchive writeString:[NSString stringWithFormat:@"%@/%@", watchName, @"front-atlas.png"]];
    } else {
        [toWatchArchive writeString:[NSString stringWithFormat:@"%@/%@", watchName, [NSString stringWithFormat:@"front-atlas-W%d.png", deviceWidth]]];
    }
    for (int j = 0; j < ECNumVisualZoomFactors; j++) {
        if (deviceWidth != 0) {
            if (j != ECZoom0Index) {
                [toWatchArchive writeInteger:0];
                [toWatchArchive writeInteger:0];
            } else {
                [toWatchArchive writeInteger:frontWidth[j]];
                [toWatchArchive writeInteger:frontHeight[j]];
            }
        } else {
            if (isBackgroundWatch && j < ECZoom0Index) {
                [toWatchArchive writeInteger:0];
                [toWatchArchive writeInteger:0];
            } else {
                [toWatchArchive writeInteger:frontWidth[j]];
                [toWatchArchive writeInteger:frontHeight[j]];
            }
        }
    }
    ECWatchArchive *frontVertexArchivesByZoom[ECNumVisualZoomFactors];
    ECWatchArchive *backVertexArchivesByZoom[ECNumVisualZoomFactors];
    ECWatchArchive *nightVertexArchivesByZoom[ECNumVisualZoomFactors];
    int numFrontParts = 0;
    int numBackParts = 0;
    int numNightParts = 0;
    NSString *backPath[ECNumVisualZoomFactors];
    NSString *nightPath[ECNumVisualZoomFactors];
    for (int j = 0; j < ECNumVisualZoomFactors; j++) {
        NSString *suffixForZoomOrWidth;
	int z2 = j + ECZoomMinPower2;
        if (deviceWidth != 0) {
            if (j != ECZoom0Index) continue;
            assert(z2 == 0);
            suffixForZoomOrWidth = [NSString stringWithFormat:@"W%d", deviceWidth];
        } else {
            if (isBackgroundWatch && j < ECZoom0Index) continue;
            suffixForZoomOrWidth = [NSString stringWithFormat:@"Z%d", z2];
        }
	NSString *path = [NSString stringWithFormat:@"%@/front-atlas-%@.dat", archiveDirectory, suffixForZoomOrWidth];
	frontVertexArchivesByZoom[j] = [[ECWatchArchive alloc] initForWritingIntoPath:path];
	[frontVertexArchivesByZoom[j] writeInteger:0];  // Write a zero as a placeholder; we'll come back to write correct count later
	backPath[j] = [NSString stringWithFormat:@"%@/back-atlas-%@.dat", archiveDirectory, suffixForZoomOrWidth];
	backVertexArchivesByZoom[j] = [[ECWatchArchive alloc] initForWritingIntoPath:backPath[j]];
	[backVertexArchivesByZoom[j] writeInteger:0];  // Write a zero as a placeholder; we'll come back to write correct count later
	nightPath[j] = [NSString stringWithFormat:@"%@/night-atlas-%@.dat", archiveDirectory, suffixForZoomOrWidth];
	nightVertexArchivesByZoom[j] = [[ECWatchArchive alloc] initForWritingIntoPath:nightPath[j]];
	[nightVertexArchivesByZoom[j] writeInteger:0];  // Write a zero as a placeholder; we'll come back to write correct count later
    }
    if (!isBackgroundWatch) {
        NSString *possiblyWidthSuffix = @"";
        if (deviceWidth != 0) {
            possiblyWidthSuffix = [NSString stringWithFormat:@"-W%d", deviceWidth];
        }
	[toWatchArchive writeString:[NSString stringWithFormat:@"%@/%@%@.png", watchName, @"back-atlas", possiblyWidthSuffix]];
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
            if (deviceWidth != 0 && j != ECZoom0Index) {
                [toWatchArchive writeInteger:0];
                [toWatchArchive writeInteger:0];
            } else {
                [toWatchArchive writeInteger:backWidth[j]];
                [toWatchArchive writeInteger:backHeight[j]];
            }
	}
	[toWatchArchive writeString:[NSString stringWithFormat:@"%@/%@%@.png", watchName, @"night-atlas", possiblyWidthSuffix]];
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
            if (deviceWidth != 0 && j != ECZoom0Index) {
                [toWatchArchive writeInteger:0];
                [toWatchArchive writeInteger:0];
            } else {
                [toWatchArchive writeInteger:nightWidth[j]];
                [toWatchArchive writeInteger:nightHeight[j]];
            }
	}
    }

    [toWatchArchive writeInteger:[fromWatchArchive readInteger]]; // numVariables, just used to initialize vm in watch ctlr
    [toWatchArchive writeInteger:[fromWatchArchive readInteger]]; // numInits
    for (i = 0; i < numInits; i++) {
	[toWatchArchive writeInstructionStream:[fromWatchArchive readInstructionStreamForVirtualMachine:vm] usingVirtualMachine:vm];
    }
    [toWatchArchive writeInteger:[fromWatchArchive readInteger]]; // numParts
    for (i = 0; i < numParts; i++) {
	int frontTextureSlot;
	int backTextureSlot;
	int nightTextureSlot;
	CGRect boundsOnScreen;
	CGPoint anchorOnScreen;
	double updateInterval;
	double updateIntervalOffset;
	ECWatchTimerSlot updateTimer;
	int modeMask;
	int handKind;
	ECDragType dragType;
	ECDragAnimationType dragAnimationType;
	double animSpeed;
	int grabPrio;
	int envSlot;
	ECPartSpecialness specialness;
	unsigned int specialParameter;
	bool norotate;
	bool cornerRelative;
	ECAnimationDirection animDir;
	bool flipOnBack;
	bool flipX;
	bool flipY;
	bool centerPixelOnly;
	EBVMInstructionStream *angleInstructionStream;
	EBVMInstructionStream *xOffsetInstructionStream;
	EBVMInstructionStream *yOffsetInstructionStream;
	double offsetRadius;
	EBVMInstructionStream *offsetAngleInstructionStream;
	EBVMInstructionStream *actionInstructionStream;
	bool immediate, expanded;
	ECPartRepeatStrategy repeatStrategy;
	int masterIndex;
	ECButtonEnabledControl enabledControl;
	[fromWatchArchive readWatchPartDataWithFrontTextureSlot:&frontTextureSlot
						backTextureSlot:&backTextureSlot
					       nightTextureSlot:&nightTextureSlot
						 boundsOnScreen:&boundsOnScreen
						 anchorOnScreen:&anchorOnScreen
						 updateInterval:&updateInterval
					   updateIntervalOffset:&updateIntervalOffset
						    updateTimer:&updateTimer
						       modeMask:&modeMask
						       handKind:&handKind
						       dragType:&dragType
					      dragAnimationType:&dragAnimationType
						      animSpeed:&animSpeed
							animDir:&animDir
						       grabPrio:&grabPrio
							envSlot:&envSlot
						    specialness:&specialness
					       specialParameter:&specialParameter
						       norotate:&norotate
						 cornerRelative:&cornerRelative
						     flipOnBack:&flipOnBack
							  flipX:&flipX
							  flipY:&flipY
						centerPixelOnly:&centerPixelOnly
					    usingVirtualMachine:vm
					 angleInstructionStream:&angleInstructionStream
				       xOffsetInstructionStream:&xOffsetInstructionStream
				       yOffsetInstructionStream:&yOffsetInstructionStream
						   offsetRadius:&offsetRadius
				   offsetAngleInstructionStream:&offsetAngleInstructionStream
					actionInstructionStream:&actionInstructionStream
						 repeatStrategy:&repeatStrategy
						      immediate:&immediate
						       expanded:&expanded
						    masterIndex:&masterIndex
						 enabledControl:&enabledControl];
	assert(frontTextureSlot == backTextureSlot);  // paranoia
	assert(frontTextureSlot == nightTextureSlot);
	// Write to vertex sidecar files here for each atlas
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    if (isBackgroundWatch && j < ECZoom0Index) continue;
            if (deviceWidth != 0 && j != ECZoom0Index) continue;
	    TextureData *textureData = (TextureData *)[[texturesByZoom[j] objectAtIndex:frontTextureSlot] bytes];
	    assert(textureData->mask == modeMask);
	    if (textureData->mask & frontMask) {
		assert(textureData->frontPlacedLocation.x >= 0);
		assert(textureData->frontPlacedLocation.y >= 0);
	    } else if (!isBackgroundWatch) {
		textureData->frontPlacedLocation.x = 0;
		textureData->frontPlacedLocation.y = 0;
	    }
	    if (!isBackgroundWatch) {
		if (textureData->mask & backMask) {
		    assert(textureData->backPlacedLocation.x >= 0);
		    assert(textureData->backPlacedLocation.y >= 0);
		} else {
		    textureData->backPlacedLocation.x = 0;
		    textureData->backPlacedLocation.y = 0;
		}
		if (textureData->mask & nightMask) {
		    assert(textureData->nightPlacedLocation.x >= 0);
		    assert(textureData->nightPlacedLocation.y >= 0);
		} else {
		    textureData->nightPlacedLocation.x = 0;
		    textureData->nightPlacedLocation.y = 0;
		}
	    }
//	    CGRect frontNewTextureBounds = CGRectMake(textureData->frontPlacedLocation.x / (double)frontWidth[j], (frontHeight[j] - textureData->size.height - textureData->frontPlacedLocation.y) / (double)frontHeight[j],
//						      textureData->size.width / (double)frontWidth[j], textureData->size.height / (double)frontHeight[j]);
	    CGRect frontNewTextureBounds = CGRectMake((textureData->frontPlacedLocation.x) / (double)frontWidth[j], (frontHeight[j] - textureData->frontPlacedLocation.y - textureData->size.height + 2 * LocalPadding) / (double)frontHeight[j],
						      (textureData->size.width - 2 * LocalPadding) / (double)frontWidth[j], (textureData->size.height - 2 * LocalPadding) / (double)frontHeight[j]);
	    CGRect backNewTextureBounds;
	    CGRect nightNewTextureBounds;
	    if (isBackgroundWatch) {
		backNewTextureBounds = frontNewTextureBounds;
		nightNewTextureBounds = frontNewTextureBounds;
	    } else {
		backNewTextureBounds = CGRectMake(textureData->backPlacedLocation.x / (double)backWidth[j], (backHeight[j] - textureData->backPlacedLocation.y - textureData->size.height + 2 * LocalPadding) / (double)backHeight[j],
						  (textureData->size.width - 2 * LocalPadding) / (double)backWidth[j], (textureData->size.height - 2 * LocalPadding) / (double)backHeight[j]);
		nightNewTextureBounds = CGRectMake(textureData->nightPlacedLocation.x / (double)nightWidth[j], (nightHeight[j] - textureData->nightPlacedLocation.y - textureData->size.height + 2 * LocalPadding) / (double)nightHeight[j],
						   (textureData->size.width - 2 * LocalPadding) / (double)nightWidth[j], (textureData->size.height - 2 * LocalPadding) / (double)nightHeight[j]);
	    }
	    if (textureData->mask & frontMask) {
		if (centerPixelOnly) {
		    [frontVertexArchivesByZoom[j] writeRect:CGRectMake(CGRectGetMidX(frontNewTextureBounds), CGRectGetMidY(frontNewTextureBounds), 0, 0)];
		} else {
		    [frontVertexArchivesByZoom[j] writeRect:frontNewTextureBounds];
		}
		[frontVertexArchivesByZoom[j] writeInteger:(flipX + (flipY<<1))];
		if (j == ECZoom0Index && j != ECZoomIndexForPower2(1)) {
		    numFrontParts++;
		}
	    }
	    if (textureData->mask & backMask) {
		if (centerPixelOnly) {
		    [backVertexArchivesByZoom[j] writeRect:CGRectMake(CGRectGetMidX(backNewTextureBounds), CGRectGetMidY(backNewTextureBounds), 0, 0)];
		} else {
		    [backVertexArchivesByZoom[j] writeRect:backNewTextureBounds];
		}
		[backVertexArchivesByZoom[j] writeInteger:(flipX + (flipY<<1))];
		if (j == ECZoom0Index && j != ECZoomIndexForPower2(1)) {
		    numBackParts++;
		}
	    }
	    if (textureData->mask & nightMask) {
		if (centerPixelOnly) {
		    [nightVertexArchivesByZoom[j] writeRect:CGRectMake(CGRectGetMidX(nightNewTextureBounds), CGRectGetMidY(nightNewTextureBounds), 0, 0)];
		} else {
		    [nightVertexArchivesByZoom[j] writeRect:nightNewTextureBounds];
		}
		[nightVertexArchivesByZoom[j] writeInteger:(flipX + (flipY<<1))];
		if (j == ECZoom0Index && j != ECZoomIndexForPower2(1)) {
		    numNightParts++;
		}
	    }
	}

	// printf("atlas layout writing part fpl x=%d, y=%d, frontWidth[j] = %d,\n");
	[toWatchArchive writeWatchPartDataWithFrontTextureSlot:0
					       backTextureSlot:(isBackgroundWatch ? 0 : 1)
					      nightTextureSlot:(isBackgroundWatch ? 0 : 2)
						boundsOnScreen:boundsOnScreen
						anchorOnScreen:anchorOnScreen
						updateInterval:updateInterval
					  updateIntervalOffset:updateIntervalOffset
						   updateTimer:updateTimer
						      modeMask:modeMask
						      handKind:handKind
						      dragType:dragType
					     dragAnimationType:dragAnimationType
						     animSpeed:animSpeed
						       animDir:animDir
						      grabPrio:grabPrio
						       envSlot:envSlot
						   specialness:specialness
					      specialParameter:specialParameter
						      norotate:norotate
						cornerRelative:cornerRelative
						    flipOnBack:flipOnBack
							 flipX:flipX
							 flipY:flipY
					       centerPixelOnly:centerPixelOnly
					   usingVirtualMachine:vm
					angleInstructionStream:angleInstructionStream
				      xOffsetInstructionStream:xOffsetInstructionStream
				      yOffsetInstructionStream:yOffsetInstructionStream
						  offsetRadius:offsetRadius
				  offsetAngleInstructionStream:offsetAngleInstructionStream
				       actionInstructionStream:actionInstructionStream
						repeatStrategy:repeatStrategy
						     immediate:immediate
						      expanded:expanded
						   masterIndex:masterIndex
						enabledControl:enabledControl];
    }
    int numNoViewParts = [fromWatchArchive readInteger];
    [toWatchArchive writeInteger:numNoViewParts];
    for (i = 0; i < numNoViewParts; i++) {
	[toWatchArchive writeRect:[fromWatchArchive readRect]];        // boundsOnScreen
	[toWatchArchive writeInteger:[fromWatchArchive readInteger]]; // enabledControl
	[toWatchArchive writeInteger:[fromWatchArchive readInteger]]; // modeMask
	[toWatchArchive writeInstructionStream:[fromWatchArchive readInstructionStreamForVirtualMachine:vm] usingVirtualMachine:vm];  // actionInstructionStream
	[toWatchArchive writeInteger:[fromWatchArchive readInteger]]; // repeatStrategy
	[toWatchArchive writeInteger:[fromWatchArchive readInteger]]; // immediate
	[toWatchArchive writeInteger:[fromWatchArchive readInteger]]; // expanded
	[toWatchArchive writeInteger:[fromWatchArchive readInteger]]; // grabPrio
	[toWatchArchive writeInteger:[fromWatchArchive readInteger]]; // envSlot
	[toWatchArchive writeInteger:[fromWatchArchive readInteger]]; // flipXOnBack
	[toWatchArchive writeInteger:[fromWatchArchive readInteger]]; // cornerRelative
    }
    int numSpareParts = [spareParts[ECZoom0Index] count];
    [toWatchArchive writeInteger:numSpareParts];
    for (i = 0; i < numSpareParts; i++) {
	TextureData *textureData = (TextureData *)[[spareParts[ECZoom0Index] objectAtIndex:i] bytes];
	[toWatchArchive writeString:[[[textureData->relativePath lastPathComponent] stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"-Z0" withString:@""]];
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    if (isBackgroundWatch && j < ECZoom0Index || deviceWidth != 0 && j != ECZoom0Index) {
		[toWatchArchive writeRect:CGRectMake(0, 0, 0, 0)];
	    } else {
		textureData = (TextureData *)[[spareParts[j] objectAtIndex:i] bytes];
		[toWatchArchive writeRect:CGRectMake(textureData->frontPlacedLocation.x, textureData->frontPlacedLocation.y, textureData->size.width, textureData->size.height)];
	    }
	}
    }
    [fromWatchArchive finishReading];
    [fromWatchArchive release];
    [toWatchArchive finishWriting];
    [toWatchArchive release];
    for (int j = 0; j < ECNumVisualZoomFactors; j++) {
        if (deviceWidth != 0) {
// STOP HERE STOPPED HERE
            if (j != ECZoom0Index) continue;
        } else {
            if (isBackgroundWatch && j < ECZoom0Index) continue;
        }
	[backVertexArchivesByZoom[j] seekToStart];
	[backVertexArchivesByZoom[j] writeInteger:numBackParts];
	[backVertexArchivesByZoom[j] finishWriting];
	[backVertexArchivesByZoom[j] release];
	[nightVertexArchivesByZoom[j] seekToStart];
	[nightVertexArchivesByZoom[j] writeInteger:numNightParts];
	[nightVertexArchivesByZoom[j] finishWriting];
	[nightVertexArchivesByZoom[j] release];
	if (isBackgroundWatch) {
	    // Hack central: The front atlas is all there is, and
	    // there are three display lists (front, night, back)
	    // attached to it, so we need to have all the vertices
	    // (for all modes) in the associated vertex archive file.
	    // So we read the night and back archives from where we
	    // just wrote them, and append to the front archive.
	    // The order is front,night,back because that's the canonical
	    // ordering we'll use when constructing the display lists
	    [frontVertexArchivesByZoom[j] logName:@"Append night"];
	    ECWatchArchive *sourceArchive = [[ECWatchArchive alloc] initForReadingFromPath:nightPath[j]];
	    int numSourceParts = [sourceArchive readInteger];
	    assert(numSourceParts == numNightParts);
	    for (int k = 0; k < numSourceParts; k++) {
		[frontVertexArchivesByZoom[j] writeRect:[sourceArchive readRect]];
		[frontVertexArchivesByZoom[j] writeInteger:[sourceArchive readInteger]];
	    }
	    [sourceArchive finishReading];
	    [sourceArchive release];

	    [frontVertexArchivesByZoom[j] logName:@"Append back"];
	    sourceArchive = [[ECWatchArchive alloc] initForReadingFromPath:backPath[j]];
	    numSourceParts = [sourceArchive readInteger];
	    assert(numSourceParts == numBackParts);
	    for (int k = 0; k < numSourceParts; k++) {
		[frontVertexArchivesByZoom[j] writeRect:[sourceArchive readRect]];
		[frontVertexArchivesByZoom[j] writeInteger:[sourceArchive readInteger]];
	    }
	    [sourceArchive finishReading];
	    [sourceArchive release];

	    [frontVertexArchivesByZoom[j] seekToStart];
	    [frontVertexArchivesByZoom[j] writeInteger:(numFrontParts + numNightParts + numBackParts)];
	    [frontVertexArchivesByZoom[j] finishWriting];
	    [frontVertexArchivesByZoom[j] release];
	} else {
	    [frontVertexArchivesByZoom[j] seekToStart];
	    [frontVertexArchivesByZoom[j] writeInteger:numFrontParts];
	    [frontVertexArchivesByZoom[j] finishWriting];
	    [frontVertexArchivesByZoom[j] release];
	}
    }
}

@end
