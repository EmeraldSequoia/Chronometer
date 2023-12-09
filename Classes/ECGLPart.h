//
//  ECGLPart.h
//  Emerald Chronometer
//
//  Created by Steve Pucci in August 2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "Constants.h"
#import "ECGLDisplayList.h"

@class ECWatchArchive, EBVMInstructionStream, EBVirtualMachine, ECGLTextureAtlas, ECGLDisplayList, ECWatchTimeTrigger, ECGLWatch, ECWatchEnvironment;

typedef struct ECGLPartTextureData {
    int              textureAtlasSlotIndex;  // 4 bytes
    ECGLDisplayList  *displayList;      // 4 bytes
    int              displayListIndex;  // 4 bytes
} ECGLPartTextureData; // 12 bytes

typedef struct ECGLAnimatingValue {
    EBVMInstructionStream *instructionStream;
    double                targetValue;
    double                currentValue;
    NSTimeInterval        lastAnimationTime;
    NSTimeInterval        animationStopTime;
    bool                  animating;
} ECGLAnimatingValue; // 44 bytes

@class ECGLPart;  // Opaque forward decl

// ECGLPartBase is used both by view parts (ECGLPart) and noview parts, which just use the base class
@interface ECGLPartBase : NSObject { // 4 bytes from NSObject overhead
@protected
    CGRect boundsOnScreen;         	       // 16 bytes
    unsigned int repeatStrategy:2;             // 4 bytes; this bitfield really ECPartRepeatStrategy, 0-3
    unsigned int modeMask:6;          	            // 0-32
    unsigned enabledControl:8;                      // 150-153
    int handGrabPriority:3;                         // -4: grabbed last; 3: grabbed first
    unsigned int immediate:1;			    // boolean
    unsigned int expanded:1;			    // boolean
    unsigned int envSlot:5;                         // really ECWatchEnvSlot, 0-31
    unsigned int flipXOnBack:1;
    unsigned int cornerRelative:1;                  // boolean
    EBVirtualMachine *vm;          	       // 4 bytes
    ECGLWatch *watch;                          // 4 bytes
#ifdef HIRES_DUMP
    NSString *debugName;
#endif
    EBVMInstructionStream *actionInstructionStream; // 4 bytes
    NSTimeInterval nextUpdateTime;             // 8 bytes, in absolute actual wall-clock time (not the time displayed on the watch)
}   // 44 bytes total

- (id)init;
- (id)initWithBoundsOnScreen:(CGRect)boundsOnScreen
		    modeMask:(int)modeMask
	      enabledControl:(ECButtonEnabledControl)enabledControl
	      repeatStrategy:(ECPartRepeatStrategy)repeatStrategy
		   immediate:(bool)immediate
		    expanded:(bool)expanded
                    grabPrio:(int)grabPrio
		     envSlot:(int)envSlot
                 flipXOnBack:(bool)flipXOnBack
              cornerRelative:(bool)cornerRelative
			  vm:(EBVirtualMachine *)vm
		       watch:(ECGLWatch *)watch
     actionInstructionStream:(EBVMInstructionStream *)actionInstructionStream;
- (bool)activeInModeNum:(ECWatchModeEnum)modeNum;
- (bool)enclosesPoint:(CGPoint)point forModeNum:(ECWatchModeEnum)modeNum;
- (bool)enclosesPointExpanded:(CGPoint)point forModeNum:(ECWatchModeEnum)modeNum;
- (double)distanceFromBorderToPoint:(CGPoint)point forModeNum:(ECWatchModeEnum)modeNum;
- (void)act;
- (void)actNumberOfTimes:(int)numberOfTimes;
- (bool)drags;
- (ECGLPart *)asDraggableFullPart;
- (int)grabPriority;
- (int)envSlot;

@property (nonatomic, readonly) bool immediate, expanded;
@property (nonatomic, readonly) ECPartRepeatStrategy repeatStrategy;
@property (nonatomic, readonly) ECButtonEnabledControl enabledControl;
@property (nonatomic, readonly) CGRect boundsOnScreen;
@property (readonly, nonatomic) int envSlot;
@property (readonly, nonatomic) ECGLWatch *watch;
#ifdef HIRES_DUMP
-(void)drawHiresImage:(CGImageRef)cgImage intoContext:(CGContextRef)context;
@property (nonatomic, retain) NSString *debugName;
#endif

@end

@interface ECGLPart : ECGLPartBase {  // 44 bytes from ECGLPartBase
@private
    ECGLPartTextureData textureDataByMode[ECNumWatchDrawModes];  // 12 * ECNumWatchDrawModes (3) = 36 bytes
    CGPoint anchorOnScreen;        	  // 8 bytes
    double updateInterval;         	  // 8 bytes
    double updateIntervalOffset;   	  // 8 bytes
    double animSpeed;                     // 8 bytes
    unsigned int handKind:8;  // up to 255      	  // 4 bytes
    unsigned int updateTimer:2;  // really ECWatchTimerSlot, 0-3
    unsigned int animationDir:3; // really ECAnimationDirection, 0-6
    unsigned int partSpecialness:2;      // really ECPartSpecialness, 0-3
    unsigned int specialParameter:4;     // varies by special part, 0-15
    unsigned int dragType:2;               // really ECDragType, 0-2
    unsigned int dragAnimationType:3;      // really ECDragAnimationType, 0-3
    unsigned int flipX:1;
    unsigned int flipY:1;
    unsigned int animating:1;
    unsigned int isSlave:1;
    unsigned int norotate:1;                        // boolean
    ECGLPart *nextSlave; // aka firstSlaveOfMaster // 4 bytes
    
    // Main hand angle:
    ECGLAnimatingValue angle;             // 28 bytes

    // Dynamic offset of anchor from anchorOnScreen, if any
    ECGLAnimatingValue xOffset;           // 28 bytes: offset of anchor, if any
    ECGLAnimatingValue yOffset;           // 28 bytes: offset of anchor, if any

    // A different way of specifying the offset of the anchor from anchorOnScreen
    double offsetRadius;                  // 8 bytes
    ECGLAnimatingValue offsetAngle;       // 28 bytes

}
// 236 bytes, plus 96 bytes per part in the display list and texture atlas (4 bytes per coord, 2 coords per vertex, 3 vertices per triangle, 2 triangles per rectangle, 2 rectangles (texture & shape) per part
//            plus 4 bytes in the watch's array of parts, plus 4 bytes per side implemented (front/back/night), 3 = 16 bytes
//   = 348 bytes per part

@property (readonly, nonatomic) bool isSlave;
@property (readonly, nonatomic) unsigned int handKind;

- (id)initFromArchive:(ECWatchArchive *)watchArchive usingVirtualMachine:(EBVirtualMachine *)vm intoWatch:(ECGLWatch *)watch;
- (void)setupForDisplayList:(ECGLDisplayList *)displayList
		    atIndex:(int)displayListIndex
		 forModeNum:(ECWatchModeEnum)modeNum;
- (NSTimeInterval)prepareForDrawForModeNum:(ECWatchModeEnum)modeNum
				    atTime:(NSTimeInterval)currentTime
                          snappedWatchTime:(NSTimeInterval)snappedWatchTime
			     forcingUpdate:(bool)forceUpdate
			    allowAnimation:(bool)allowAnimation
		      draggingPartDragType:(ECDragType)draggingPartDragType;
- (int )partTextureAtlasSlotIndexForModeNum:(ECWatchModeEnum)modeNum;
- (void)drawSpecialPartIntoContext:(CGContextRef)context forDisplayList:(ECGLDisplayList *)displayList withinAtlasWithBounds:(CGRect)atlasSize textureVertices:(ECDLCoordType *)textureVertices zoomPower:(int)zoomPower;
- (void)dragStartAtPoint:(CGPoint)firstTouchPoint;
- (void)dragFrom:(CGPoint)firstTouchPoint to:(CGPoint)currentPoint;
- (void)dragComplete;
- (void)resetPart;
- (int)modeMask;
- (void)updateDisplayListsAtTime:(NSTimeInterval)atTime
		      forModeNum:(ECWatchModeEnum)modeNum
	     evaluateExpressions:(bool)evaluateExpressions
			 animate:(bool)animate
		     masterAngle:(double)masterAngle
	       masterOffsetAngle:(double)masterOffsetAngle
	    draggingPartDragType:(ECDragType)draggingPartDragType;

- (void)print;

@end
