//
//  ECGLDisplayList.m
//  Emerald Chronometer
//
//  Created by Steven Pucci July 2008
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ECGLDisplayList.h"
#import "ECGLTexture.h"
#import "ECGLPart.h"

@implementation ECGLDisplayList

// Construct and destroy
-(id) initForNumParts:(int)numParts
       textureAtlases:(ECGLTextureAtlas **)aTextureAtlases
       reserveOffsets:(bool)reserveOffsets {
    [super init];
    int arraySizeInBytes = 3 * 2 * 2 * numParts * sizeof(ECDLCoordType);
    shapeVertices = (ECDLCoordType *)malloc(arraySizeInBytes);
    specialParts = nil;
    int i;
    for (i = 0; i < ECNumVisualZoomFactors; i++) {
	textureAtlases[i] = aTextureAtlases[i];
	// The offsets (for ease of use when passing to OpenGL during draw) are in number of vertex coordinates
	if (reserveOffsets) {
	    textureDLOffsets[i] = [textureAtlases[i] reserveBytesAndReturnOffset:arraySizeInBytes] / sizeof(ECDLCoordType);
	} else {
	    textureDLOffsets[i] = -1;
	}
    }
    triangleCount = 2 * numParts;
#ifndef NDEBUG
    shapeCoordInitialized = (bool *)malloc(numParts * sizeof(bool));
    for (i = 0; i < numParts; i++) {
	shapeCoordInitialized[i] = false;
    }
#endif
    return self;
}

-(id) initForNumParts:(int)numParts
       textureAtlases:(ECGLTextureAtlas **)aTextureAtlases {
    return [self initForNumParts:numParts textureAtlases:aTextureAtlases reserveOffsets:true];
}

-(id) initForNumParts:(int)numParts
   textureAtlasesFrom:(ECGLDisplayList *)otherDisplayList {
    return [self initForNumParts:numParts textureAtlases:otherDisplayList->textureAtlases];
}

-(void) dealloc {
    free(shapeVertices);
    assert(!specialParts);
    [specialParts release];
    [super dealloc];
}

#ifndef NDEBUG
-(int)textureDLOffsetForZoom:(int)z2 {
    int indx = ECZoomIndexForPower2(z2);
    return textureDLOffsets[indx];
}
#endif

-(void) setPartShapeCoords:(CGPoint *)quadVertices
	      forPartIndex:(int)partIndex {
    assert(triangleCount >= 0);  // sanity
    assert(triangleCount < 10000);  // sanity
    assert(triangleCount >= (partIndex + 1) * 2);
    assert(partIndex >= 0);
#ifndef NDEBUG
    shapeCoordInitialized[partIndex] = true;
#endif
    ECDLCoordType *shapeVertexPtr =   &(shapeVertices  [12 * partIndex]);
    for (int i = 0; i < 3; i++) {
	*shapeVertexPtr++ = quadVertices[i].x;
	*shapeVertexPtr++ = quadVertices[i].y;
    }
    for (int i = 1; i < 4; i++) {
	*shapeVertexPtr++ = quadVertices[i].x;
	*shapeVertexPtr++ = quadVertices[i].y;
    }
}

-(void) setPartShapeRect:(CGRect)rect
	    forPartIndex:(int)partIndex {
        // UL, UR, LL, LR
    CGPoint quadVertices[4];
    quadVertices[0].x = rect.origin.x;                     quadVertices[0].y = rect.origin.y + rect.size.height;
    quadVertices[1].x = rect.origin.x + rect.size.width;   quadVertices[1].y = rect.origin.y + rect.size.height;
    quadVertices[2] = rect.origin;
    quadVertices[3].x = rect.origin.x + rect.size.width;   quadVertices[3].y = rect.origin.y;
    [self setPartShapeCoords:quadVertices forPartIndex:partIndex];
}

#ifndef NDEBUG
-(void) checkInitialized {
    int numParts = [self partCount];
    for (int i = 0; i < numParts; i++) {
	assert(shapeCoordInitialized[i]);
    }
}
#endif

-(void) drawForZoomPower2:(int)zoomPower2 altZoomPower2:(int)altZoomPower2 textureVertices:(ECDLCoordType *)textureVertices offsetInRects:(int)offsetInRects lengthInRects:(int)lengthInRects {
    int atlasIndex = ECZoomIndexForPower2(zoomPower2);
    assert(atlasIndex >= 0);
    assert(atlasIndex < ECNumVisualZoomFactors);
    ECGLTextureAtlas *textureAtlas = textureAtlases[atlasIndex];
    if ([textureAtlas textureLoadedSize] == 0 && zoomPower2 != altZoomPower2) {
	atlasIndex = ECZoomIndexForPower2(altZoomPower2);
	textureAtlas = textureAtlases[atlasIndex];
    }
    assert([textureAtlas textureLoadedSize] > 0);
    if (!textureVertices) {
	assert(textureDLOffsets[atlasIndex] >= 0);
	textureVertices = [textureAtlas textureVertices] + textureDLOffsets[atlasIndex];
    }
    int triCount = lengthInRects ? lengthInRects * 2 : triangleCount;
#ifndef NDEBUG
    //printf("Drawing from atlas: "); [textureAtlas printFull];
    // [self print];
    int numParts = [self partCount];
    for (int i = 0; i < numParts; i++) {
	assert(shapeCoordInitialized[i]);
    }
    ECDLCoordType *shapeVertexPtr = shapeVertices + offsetInRects*2*2*3;
    ECDLCoordType *textureVertexPtr = textureVertices + offsetInRects*2*2*3;
    for (int i = 0; i < triCount; i++) {
	for (int j = 0; j < 6; j++) {
	    ECDLCoordType coord = *shapeVertexPtr++;
	    assert(!isnan(coord));
	    assert(coord >= -10000 && coord <= 10000);
	    coord = *textureVertexPtr++;
	    if (coord < 0 || coord > 1024) {
		printf("Triangle %d coord %d bad at %g:\n", i, j, coord);
		[textureAtlas printFull];
	    }
	    assert(coord >= 0 && coord <= 1024);
	    assert(!isnan(coord));
	}
    }
    //[self print];
#endif
    [textureAtlas attachTexture];  // if necessary, else is nop
    glBindTexture(GL_TEXTURE_2D, [textureAtlas textureID]);
#ifndef NDEBUG
    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
	printf("OpenGL error %d\n", err);
        assert(false);
    }
#endif
    glVertexPointer(2, GL_FLOAT, 0, shapeVertices + offsetInRects*2*2*3);
#ifndef NDEBUG
    err = glGetError();
    if (err != GL_NO_ERROR) {
	printf("OpenGL error %d\n", err);
        assert(false);
    }
#endif
    glEnableClientState(GL_VERTEX_ARRAY);
#ifndef NDEBUG
    err = glGetError();
    if (err != GL_NO_ERROR) {
	printf("OpenGL error %d\n", err);
        assert(false);
    }
#endif
    glTexCoordPointer(2, GL_FLOAT, 0, textureVertices + offsetInRects*2*2*3);
#ifndef NDEBUG
    err = glGetError();
    if (err != GL_NO_ERROR) {
	printf("OpenGL error %d\n", err);
        assert(false);
    }
#endif
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
#ifndef NDEBUG
    err = glGetError();
    if (err != GL_NO_ERROR) {
	printf("OpenGL error %d\n", err);
        assert(false);
    }
#endif
#undef ONE_AT_A_TIME
#ifdef ONE_AT_A_TIME
    for (int i = 0; i < triCount; i++) {
	glDrawArrays(GL_TRIANGLES, i * 3, 3);
    }
#else
    glDrawArrays(GL_TRIANGLES, 0, triCount * 3);
#endif
#ifndef NDEBUG
    err = glGetError();
    if (err != GL_NO_ERROR) {
	printf("OpenGL error %d\n", err);
        assert(false);
    }
#endif
}

-(void) drawForZoomPower2:(int)zoomPower2 altZoomPower2:(int)altZoomPower2 {  // 0 == normal, -1 == half size, -2 == quarter size
    [self drawForZoomPower2:zoomPower2 altZoomPower2:altZoomPower2 textureVertices:NULL offsetInRects:0 lengthInRects:0];  // NULL meaning use the ones in the atlas
}

-(void) drawForZoomPower2:(int)zoomPower2 {  // 0 == normal, -1 == half size, -2 == quarter size
    [self drawForZoomPower2:zoomPower2 altZoomPower2:zoomPower2 textureVertices:NULL offsetInRects:0 lengthInRects:0];  // NULL meaning use the ones in the atlas
}

-(int) partCount {
    assert(triangleCount > 0);
    assert((triangleCount % 2) == 0);
    return triangleCount / 2;
}

-(bool) loadedForZoomPower2:(int)zoomPower2 {
    int atlasIndex = ECZoomIndexForPower2(zoomPower2);
    assert(atlasIndex >= 0);
    assert(atlasIndex < ECNumVisualZoomFactors);
    ECGLTextureAtlas *textureAtlas = textureAtlases[atlasIndex];
    return [textureAtlas textureLoadedSize] > 0;
}

-(void) registerSpecialPart:(ECGLPart *)part {
    if (!specialParts) {
	specialParts = [[NSMutableSet alloc] initWithCapacity:5];
    }
    [specialParts addObject:part];
    for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	ECGLTextureAtlas *textureAtlas = textureAtlases[j];
	[textureAtlas registerSpecialDisplayList:self];
    }    
}

-(void) unregisterSpecialPart:(ECGLPart *)part {
    assert(specialParts);
    assert([specialParts containsObject:part]);
    [specialParts removeObject:part];
    if ([specialParts count] == 0) {
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    ECGLTextureAtlas *textureAtlas = textureAtlases[j];
	    [textureAtlas unregisterSpecialDisplayList:self];
	}
	[specialParts release];
	specialParts = nil;
    }
}

-(int) findAtlas:(ECGLTextureAtlas *)atlas {
    for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	if (atlas == textureAtlases[j]) {
	    return j;
	}
    }
    return -1;
}

-(void) drawSpecialPartsForTextureAtlas:(ECGLTextureAtlas *)textureAtlas intoContext:(CGContextRef)context atlasSize:(CGRect)atlasSize {
//    assert([NSThread isMainThread]);
    int atlasIndex = [self findAtlas:textureAtlas];
    int zoomPower = atlasIndex + ECZoomMinPower2;
    assert(atlasIndex >= 0);
    if (atlasIndex >= 0) {
	assert(textureDLOffsets[atlasIndex] >= 0);
	ECDLCoordType *textureVertices = [textureAtlas textureVertices] + textureDLOffsets[atlasIndex];
	for (ECGLPart *part in specialParts) {
	    [part drawSpecialPartIntoContext:context forDisplayList:self withinAtlasWithBounds:atlasSize textureVertices:textureVertices zoomPower:zoomPower];
	}
    }
}

-(void) addWatchesForSpecialPartsToSet:(NSMutableSet *)specialWatches {
    for (ECGLPart *part in specialParts) {
	[specialWatches addObject:[part watch]];
    }
}

#ifndef NDEBUG
-(void) print {
    int atlasIndex0 = ECZoom0Index;
    assert(atlasIndex0 >= 0);
    assert(atlasIndex0 < ECNumVisualZoomFactors);
    ECGLTextureAtlas *textureAtlas0 = textureAtlases[atlasIndex0];
    printf("Display list with %d triangles (%.1f shapes) from %s\n", triangleCount, triangleCount / 2.0, [[textureAtlas0 path] UTF8String]);
    for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	ECGLTextureAtlas *textureAtlas = textureAtlases[j];
	if (textureAtlas) {
	    printf("......size at z %2d: %ld\n", j + ECZoomMinPower2, [textureAtlas textureLoadedSize]);
	} else {
	    printf("......size at z %2d: uninitialized\n", j + ECZoomMinPower2);
	}
    }
    for (int i = 0; i < triangleCount; i++) {
	printf("...triangle %d:\n", i);
	printf("  vertex (%10.2f, %10.2f),",
	       shapeVertices  [6 * i    ], shapeVertices  [6 * i + 1]);
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    ECGLTextureAtlas *textureAtlas = textureAtlases[j];
	    ECDLCoordType *textureVertices = [textureAtlas textureVertices];
	    if (textureAtlas && textureVertices) {
		printf(" z%2d texture (%10.4f, %10.4f)",
		       j + ECZoomMinPower2,
		       textureVertices[6 * i    ], textureVertices[6 * i + 1]);
	    } else {
		printf(" z%2d texture (%10.4s  %10.4s)",
		       j + ECZoomMinPower2,
		       "uninit", "uninit");
	    }
	}
	printf("\n");
	printf("  vertex (%10.2f, %10.2f),",
	       shapeVertices  [6 * i + 2], shapeVertices  [6 * i + 3]);
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    ECGLTextureAtlas *textureAtlas = textureAtlases[j];
	    ECDLCoordType *textureVertices = [textureAtlas textureVertices];
	    if (textureAtlas && textureVertices) {
		printf(" z%2d texture (%10.4f, %10.4f)",
		       j + ECZoomMinPower2,
		       textureVertices[6 * i + 2], textureVertices[6 * i + 3]);
	    } else {
		printf(" z%2d texture (%10.4s  %10.4s)",
		       j + ECZoomMinPower2,
		       "uninit", "uninit");
	    }
	}
	printf("\n");
	printf("  vertex (%10.2f, %10.2f),",
	       shapeVertices  [6 * i + 4], shapeVertices  [6 * i + 5]);
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    ECGLTextureAtlas *textureAtlas = textureAtlases[j];
	    ECDLCoordType *textureVertices = [textureAtlas textureVertices];
	    if (textureAtlas && textureVertices) {
		printf(" z%2d texture (%10.4f, %10.4f)",
		       j + ECZoomMinPower2,
		       textureVertices[6 * i + 4], textureVertices[6 * i + 5]);
	    } else {
		printf(" z%2d texture (%10.4s  %10.4s)",
		       j + ECZoomMinPower2,
		       "uninit", "uninit");
	    }
	}
	printf("\n");
    }
    fflush(stdout);
}
#endif

@end

@implementation ECGLDisplayListWithTextureVertices

-(id) initForNumParts:(int)numParts
       textureAtlases:(ECGLTextureAtlas **)aTextureAtlases {
    [super initForNumParts:numParts
	    textureAtlases:aTextureAtlases
	    reserveOffsets:false];
    for (int i = 0; i < ECNumVisualZoomFactors; i++) {
	textureVertices[i] = NULL;
    }
    return self;
}

-(id) initForNumParts:(int)numParts
   textureAtlasesFrom:(ECGLDisplayList *)otherDisplayList {
    return [self initForNumParts:numParts textureAtlases:otherDisplayList->textureAtlases];
}

-(void) dealloc {
    for (int i = 0; i < ECNumVisualZoomFactors; i++) {
	if (textureVertices[i]) {
	    free(textureVertices[i]);
	}
    }
    [super dealloc];
}

// Override base class
-(void) drawForZoomPower2:(int)zoomPower2 {  // 0 == normal, -1 == half size, -2 == quarter size
    assert(textureVertices[ECZoomIndexForPower2(zoomPower2)]);
    [self drawForZoomPower2:zoomPower2 altZoomPower2:zoomPower2 textureVertices:textureVertices[ECZoomIndexForPower2(zoomPower2)] offsetInRects:0 lengthInRects:0];
}

-(void) drawRangeForZoomPower2:(int)zoomPower2 from:(int)indexOfFirstShape to:(int)indexOfLastShape {
    assert(textureVertices[ECZoomIndexForPower2(zoomPower2)]);
    [self drawForZoomPower2:zoomPower2 altZoomPower2:zoomPower2 textureVertices:textureVertices[ECZoomIndexForPower2(zoomPower2)] offsetInRects:indexOfFirstShape lengthInRects:(indexOfLastShape - indexOfFirstShape + 1)];
}

-(void) drawSpecialPartsForTextureAtlas:(ECGLTextureAtlas *)textureAtlas intoContext:(CGContextRef)context atlasSize:(CGRect)atlasSize {
    assert(false);  // Can't do that on this kind of display list
}

-(void) setPartTextureBounds:(CGRect)textureBounds
		forPartIndex:(int)partIndex
		       flipX:(bool)flipX
		       flipY:(bool)flipY
		 pixelCoords:(bool)pixelCoords
		  zoomPower2:(int)zoomPower2 {
    assert(triangleCount >= 0);  // sanity
    assert(triangleCount < 10000);  // sanity
    assert(triangleCount >= (partIndex + 1) * 2);
    assert(textureBounds.size.width >= 0);
    assert(textureBounds.size.height >= 0);
    assert(textureBounds.origin.x >= 0);
    assert(textureBounds.origin.y >= 0);
    assert(textureBounds.origin.x <= 4096);
    assert(textureBounds.origin.y <= 4096);
    int atlasIndex = ECZoomIndexForPower2(zoomPower2);
    assert(atlasIndex >= 0);
    assert(atlasIndex < ECNumVisualZoomFactors);
    ECGLTextureAtlas *textureAtlas = textureAtlases[atlasIndex];
    assert(textureAtlas);
    int atlasWidth = [textureAtlas width];
    int atlasHeight = [textureAtlas height];
    assert((int)textureBounds.origin.x <= atlasWidth);
    assert((int)textureBounds.origin.y <= atlasHeight);
    assert((int)textureBounds.size.width <= atlasWidth);
    assert((int)textureBounds.size.height <= atlasHeight);
    if (pixelCoords) {
	textureBounds.origin.x = textureBounds.origin.x / atlasWidth;
	textureBounds.origin.y = (atlasHeight - textureBounds.size.height - textureBounds.origin.y) / atlasHeight;
	textureBounds.size.width /= atlasWidth;
	textureBounds.size.height /= atlasHeight;
    }

    if (!textureVertices[ECZoomIndexForPower2(zoomPower2)]) {
	int arraySizeInBytes = 3 * 2 * 2 * [self partCount] * sizeof(ECDLCoordType);
	textureVertices[ECZoomIndexForPower2(zoomPower2)] = (ECDLCoordType *)malloc(arraySizeInBytes);
    }
    ECDLCoordType *textureVertexPtr = &(textureVertices[ECZoomIndexForPower2(zoomPower2)][12 * partIndex]);

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
    *textureVertexPtr   = bottom;
}

#ifndef NDEBUG
-(void) print {
    int atlasIndex0 = ECZoom0Index;
    assert(atlasIndex0 >= 0);
    assert(atlasIndex0 < ECNumVisualZoomFactors);
    ECGLTextureAtlas *textureAtlas0 = textureAtlases[atlasIndex0];
    printf("Display list with %d triangles (%.1f shapes) from %s\n", triangleCount, triangleCount / 2.0, [[textureAtlas0 path] UTF8String]);
    for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	ECGLTextureAtlas *textureAtlas = textureAtlases[j];
	if (textureAtlas) {
	    printf("......size at z %2d: %ld\n", j + ECZoomMinPower2, [textureAtlas textureLoadedSize]);
	} else {
	    printf("......size at z %2d: uninitialized\n", j + ECZoomMinPower2);
	}
    }
    for (int i = 0; i < triangleCount; i++) {
	printf("...triangle %d:\n", i);
	printf("  vertex (%10.2f, %10.2f)",
	       shapeVertices  [6 * i    ], shapeVertices  [6 * i + 1]);
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    ECGLTextureAtlas *textureAtlas = textureAtlases[j];
	    ECDLCoordType *textureVerts = textureVertices[j];
	    if (textureAtlas && textureVerts) {
		printf(", z%2d texture (%10.4f, %10.4f)",
		       j + ECZoomMinPower2,
		       textureVerts[6 * i    ], textureVerts[6 * i + 1]);
	    } else {
		printf(", z%2d texture (%10.4s  %10.4s)",
		       j + ECZoomMinPower2,
		       "uninit", "uninit");
	    }
	}
	printf("\n");
	printf("  vertex (%10.2f, %10.2f)",
	       shapeVertices  [6 * i + 2], shapeVertices  [6 * i + 3]);
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    ECGLTextureAtlas *textureAtlas = textureAtlases[j];
	    ECDLCoordType *textureVerts = textureVertices[j];
	    if (textureAtlas && textureVerts) {
		printf(", z%2d texture (%10.4f, %10.4f)",
		       j + ECZoomMinPower2,
		       textureVerts[6 * i + 2], textureVerts[6 * i + 3]);
	    } else {
		printf(", z%2d texture (%10.4s  %10.4s)",
		       j + ECZoomMinPower2,
		       "uninit", "uninit");
	    }
	}
	printf("\n");
	printf("  vertex (%10.2f, %10.2f)",
	       shapeVertices  [6 * i + 4], shapeVertices  [6 * i + 5]);
	for (int j = 0; j < ECNumVisualZoomFactors; j++) {
	    ECGLTextureAtlas *textureAtlas = textureAtlases[j];
	    ECDLCoordType *textureVerts = textureVertices[j];
	    if (textureAtlas && textureVerts) {
		printf(", z%2d texture (%10.4f, %10.4f)",
		       j + ECZoomMinPower2,
		       textureVerts[6 * i + 4], textureVerts[6 * i + 5]);
	    } else {
		printf(", z%2d texture (%10.4s  %10.4s)",
		       j + ECZoomMinPower2,
		       "uninit", "uninit");
	    }
	}
	printf("\n");
    }
    fflush(stdout);
}
#endif

@end
