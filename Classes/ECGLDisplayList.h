//
//  ECGLDisplayList.h
//  Emerald Chronometer
//
//  Created by Steven Pucci July 2008
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#import "Constants.h"

@class ECGLTextureAtlas;
@class ECGLPart;

typedef GLfloat ECDLCoordType;

@interface ECGLDisplayList : NSObject {
@private
#ifndef NDEBUG
    bool             *shapeCoordInitialized;
#endif

    int              textureDLOffsets[ECNumVisualZoomFactors];  // point within the corresponding atlas at which our texture coordinates start
    NSMutableSet     *specialParts;
@protected
    ECDLCoordType    *shapeVertices;
    ECGLTextureAtlas *textureAtlases[ECNumVisualZoomFactors];
    int     	     triangleCount;
}

#ifndef NDEBUG
-(int)textureDLOffsetForZoom:(int)z2;
#endif

// Construct and destroy
-(id) initForNumParts:(int)numParts
       textureAtlases:(ECGLTextureAtlas **)textureAtlases;
-(id) initForNumParts:(int)numParts
   textureAtlasesFrom:(ECGLDisplayList *)otherDisplayList;
-(void) dealloc;

// Set up DL data
-(void) setPartShapeCoords:(CGPoint *)quadVertices
	      forPartIndex:(int)partIndex;
-(void) setPartShapeRect:(CGRect)rect
	    forPartIndex:(int)partIndex;

// Draw
-(void) drawForZoomPower2:(int)zoomPower2;  // 0 == normal, -1 == half size, -2 == quarter size
-(void) drawForZoomPower2:(int)zoomPower2 altZoomPower2:(int)altZoomPower2;

// Utility
-(int) partCount;
-(bool) loadedForZoomPower2:(int)zoomPower2;
-(void) registerSpecialPart:(ECGLPart *)part;
-(void) unregisterSpecialPart:(ECGLPart *)part;
-(void) drawSpecialPartsForTextureAtlas:(ECGLTextureAtlas *)textureAtlas intoContext:(CGContextRef)context atlasSize:(CGRect)atlasSize;
-(void) addWatchesForSpecialPartsToSet:(NSMutableSet *)specialWatches;

// Debug
#ifndef NDEBUG
-(void) print;
-(void) checkInitialized;
#endif

@end

@interface ECGLDisplayListWithTextureVertices : ECGLDisplayList {
@private
    ECDLCoordType    *textureVertices[ECNumVisualZoomFactors];
}

-(void) drawRangeForZoomPower2:(int)z2 from:(int)indexOfFirstShape to:(int)indexOfLastShape;

// Declare the following so we can assert if someone tries it on us
-(void) drawSpecialPartsForTextureAtlas:(ECGLTextureAtlas *)textureAtlas intoContext:(CGContextRef)context atlasSize:(CGRect)atlasSize;

-(void) setPartTextureBounds:(CGRect)textureBounds
		forPartIndex:(int)partIndex
		       flipX:(bool)flipX
		       flipY:(bool)flipY
		 pixelCoords:(bool)pixelCoords
		  zoomPower2:(int)zoomPower2;

@end
