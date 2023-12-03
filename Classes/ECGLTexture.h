//
//  ECGLTexture.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 8/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import <OpenGLES/ES1/gl.h>

#import "ECGLDisplayList.h"

// A texture atlas represents an image and the locations of the parts within that image
// The idea (new to post-2.1, July 2009) is that this atlas will store an array of all
// texture coordinates for parts stored within it, organized by display list.  That is,
// Each display list's coordinates will be in a group within the master array, and the
// display list will tell OpenGL to draw directly out of that spot in the array; the display
// list will know what offset its section is within the atlas because at the time the
// display list is created, the current offset in the atlas is recorded in the DL.
// The big advantage of this approach is that the DL can store multiple atlases for multiple
// zoom factors, but avoid paying any storage at all (save one pointer) for zoom factors
// that are not currently in use.  The texture coordinates for different zooms are necessarily
// different (because the spacing between parts must be proportionally larger for smaller
// atlas sizes), and this approach lets us postpone reading in the texture coordinates (and
// keeping storage for them) until the atlas itself is read for the given zoom.
@interface ECGLTextureAtlas : NSObject {
    int      numRequiredWatchModes;
    NSString *path;
    NSString *cachePath;
    int      width;
    int      height;
    GLuint   textureID;
    GLubyte  *textureData;
    volatile size_t   textureLoadedSize;
    NSLock   *loadLock;
    bool     attached;
    bool     markForUnattach;
    ECDLCoordType    *textureVertices;
    int      vertexReservedSize;
    NSMutableSet *specialDisplayLists;
}

@property (readonly, nonatomic) ECDLCoordType *textureVertices;
@property (readonly, nonatomic) GLuint textureID;
@property (readonly, nonatomic) int numRequiredWatchModes;
@property (readonly, nonatomic) int width, height;
@property (readonly, nonatomic) CGSize size;  // convenience method
@property (readonly, nonatomic) NSString *path;
@property (readonly, nonatomic) volatile size_t textureLoadedSize;

+ (void)handleMemoryWarning;
+ (ECGLTextureAtlas *)atlasForRelativePath:(NSString *)relativePath
				    create:(bool)create
				     width:(int)width
				    height:(int)height
				zoomPower2:(int)z2;
+ (size_t)totalLoadedSize;
+ (NSString *)fullPathForRelativePath:(NSString *)relativePath;
+ (void)setRedOverlay:(double)n;
+ (double)redOverlay;

- (int)reserveBytesAndReturnOffset:(int)sizeToReserve;

- (void)registerSpecialDisplayList:(ECGLDisplayList *)displayList;
- (void)unregisterSpecialDisplayList:(ECGLDisplayList *)displayList;
+ (void)invalidateSpecialParts;

- (void)watchPartModeRequiresLoad;
- (size_t)bytesNeededForLoad;
- (size_t)watchPartModeReleasesLoadNeedingUnattach:(bool *)needUnattach;
- (void)unattachIfMarked;
- (void)forceUnloadOrUnattach;

+ (bool)writeOnePngTestOnly:(bool)testOnly;

- (void)attachTexture;

- (void)print;
- (void)printFull;
- (void)reportMemoryUsage:(size_t *)attachedSize pendingSize:(size_t *)pendingSize loaded:(bool *)isLoaded attached:(bool *)isAttached;
+ (void)reportMemoryUsage:(size_t *)attachedSize pendingSize:(size_t *)pendingSize numLoaded:(int *)numLoaded numAttached:(int *)numAttached numTotal:(int *)numTotal;
+ (void)reportAllAttachedOrLoadedTextures;

@end
