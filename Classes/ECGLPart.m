//
//  ECGLPart.m
//  Emerald Chronometer
//
//  Created by Steve Pucci in August 2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ECGLPart.h"
#import "ECWatchArchive.h"
#import "EBVirtualMachine.h"
#import "ECGLDisplayList.h"
#import "ECGLTexture.h"
#import "ECDynamicUpdate.h"
#import "ECGLWatch.h"
#import "ECWatchTime.h"
#import "ECLocationManager.h"
#import "ECWatchEnvironment.h"
#import "ECAstronomy.h"
#import "ChronometerAppDelegate.h"
#import "ECErrorReporter.h"
#import "ECGlobals.h"
#import "Constants.h"
#import "ECFactoryUI.h"
#import "ECMapProjection.h"
#import "TSTime.h"

#import "Glyph.h"

#import <CoreText/CoreText.h>

#include <unistd.h>  // For usleep

@implementation ECGLPartBase

@synthesize boundsOnScreen, watch;
#ifdef HIRES_DUMP
@synthesize debugName;
#endif

- (id)init {
    [super init];
    return self;
}

- (id)initWithBoundsOnScreen:(CGRect)aBoundsOnScreen
		    modeMask:(int)aModeMask
	      enabledControl:(ECButtonEnabledControl)anEnabledControl
	      repeatStrategy:(ECPartRepeatStrategy)aRepeatStrategy
		   immediate:(bool)aImmediate
		    expanded:(bool)aExpanded
                    grabPrio:(int)grabPri
		     envSlot:(int)anEnvSlot
                 flipXOnBack:(bool)aFlipXOnBack
              cornerRelative:(bool)aCornerRelative
			  vm:(EBVirtualMachine *)aVM
		       watch:(ECGLWatch *)aWatch
     actionInstructionStream:(EBVMInstructionStream *)anActionInstructionStream {
    [super init];
    boundsOnScreen = aBoundsOnScreen;
    modeMask = aModeMask;
    enabledControl = anEnabledControl;
    vm = aVM;
    assert(anEnvSlot >= 0 && anEnvSlot <= ECEnvUB);
    envSlot = anEnvSlot;
    watch = aWatch;
    repeatStrategy = aRepeatStrategy;
    immediate = aImmediate;
    expanded = aExpanded;
    flipXOnBack = aFlipXOnBack;
    cornerRelative = aCornerRelative;
    assert(grabPri >= ECGrabPrioLB && grabPri <= ECGrabPrioUB);
    handGrabPriority = grabPri;
    actionInstructionStream = [anActionInstructionStream retain];
    nextUpdateTime = ECFarInThePast;
    return self;
}

- (bool)repeats {
    return repeatStrategy != 0;
}

- (ECPartRepeatStrategy)repeatStrategy {
    return repeatStrategy;
}

- (bool)immediate {
    return immediate != 0;
}

- (bool)expanded {
    return expanded != 0;
}

- (int)envSlot {
    return (int)envSlot;
}

- (ECButtonEnabledControl)enabledControl {
    return (ECButtonEnabledControl)enabledControl;
}

- (bool)activeInModeNum:(ECWatchModeEnum)modeNum {
    ECWatchModeMask mask = 1 << modeNum;
    return
	(modeMask & mask) &&
	(actionInstructionStream != NULL) &&
	(enabledControl == ECButtonEnabledAlways || [watch manualSet] || ([watch alarmManualSet] && enabledControl == ECButtonEnabledAlarmStemOutOnly) || (enabledControl == ECButtonEnabledWrongTimeOnly && ![watch mainTime].isCorrect));
}

- (bool)enclosesPointExpanded:(CGPoint)point forModeNum:(ECWatchModeEnum)modeNum {
    return false;
}

- (bool)enclosesPoint:(CGPoint)point forModeNum:(ECWatchModeEnum)modeNum {
    CGPoint origin = boundsOnScreen.origin;
    if (cornerRelative) {
        assert([watch isBackground]);
	[ChronometerAppDelegate translateCornerRelativeOrigin:&origin];
    }
    CGRect expandedBounds;
    if (boundsOnScreen.size.width < ECMinimumInputViewSize) {
	expandedBounds.origin.x = origin.x - (ECMinimumInputViewSize - boundsOnScreen.size.width)/2;
	expandedBounds.size.width = ECMinimumInputViewSize;
    } else {
	expandedBounds.origin.x = origin.x;
	expandedBounds.size.width = boundsOnScreen.size.width;
    }
    if (boundsOnScreen.size.height < ECMinimumInputViewSize) {
	expandedBounds.origin.y = origin.y - (ECMinimumInputViewSize - boundsOnScreen.size.height)/2;
	expandedBounds.size.height = ECMinimumInputViewSize;
    } else {
	expandedBounds.origin.y = origin.y;
	expandedBounds.size.height = boundsOnScreen.size.height;
    }
    return CGRectContainsPoint(expandedBounds, point);
}

// Higher positive numbers mean more enclosed
- (double)distanceFromBorderToPoint:(CGPoint)point forModeNum:(ECWatchModeEnum)modeNum {
    assert([self enclosesPoint:point forModeNum:modeNum]);
    CGPoint origin = boundsOnScreen.origin;
    if (cornerRelative) {
        assert([watch isBackground]);
	[ChronometerAppDelegate translateCornerRelativeOrigin:&origin];
    }
    if (boundsOnScreen.size.width > 100 && boundsOnScreen.size.height > 100) {
	// Chandra hack:  If the button is that big, it should always lose when overlapping another part, so return zero
	return 0.01;
    }
    CGFloat xlo, ylo, xhi, yhi;
    if (boundsOnScreen.size.width < ECMinimumInputViewSize) {
	xlo = origin.x - (ECMinimumInputViewSize - boundsOnScreen.size.width)/2;
	xhi = xlo + ECMinimumInputViewSize;
    } else {
	xlo = origin.x;
	xhi = xlo + boundsOnScreen.size.width;
    }
    if (boundsOnScreen.size.height < ECMinimumInputViewSize) {
	ylo = origin.y - (ECMinimumInputViewSize - boundsOnScreen.size.height)/2;
	yhi = ylo + ECMinimumInputViewSize;
    } else {
	ylo = origin.y;
	yhi = ylo + boundsOnScreen.size.height;
    }
    CGFloat closestDist;
    CGFloat dist = point.x - xlo;
    assert(dist >= 0);
    closestDist = dist;
    dist = xhi - point.x;
    assert(dist >= 0);
    if (dist < closestDist) {
	closestDist = dist;
    }
    dist = point.y - ylo;
    assert(dist >= 0);
    if (dist < closestDist) {
	closestDist = dist;
    }
    dist = yhi - point.y;
    assert(dist >= 0);
    if (dist < closestDist) {
	closestDist = dist;
    }
    return closestDist;
}

- (void)actNumberOfTimes:(int)numberOfTimes doRepaint:(bool)doRepaint {
    if (actionInstructionStream) {
	[ChronometerAppDelegate setPartBeingEvaluated:self];
	ECGLWatch *watchToUse = watch;
	if ([watch isBackground]) {
	    watchToUse = [ChronometerAppDelegate currentWatch];
	}
	int counter = 0;
	while (counter++ < 30 && ![watchToUse loaded]) {
	    usleep(100000);
	}
	ECAstronomyManager *astroMgr = [watchToUse astroWithIndex:(int)envSlot];
	[[watchToUse mainTime] latchTimeForBeatsPerSecond:[watch beatsPerSecond]];
	[astroMgr setupLocalEnvironmentForThreadFromActionButton:true];
	for (int i = 0; i < numberOfTimes; i++) {
	    [vm evaluateInstructionStream:actionInstructionStream errorReporter:ECtheErrorReporter];
	}
	[astroMgr cleanupLocalEnvironmentForThreadFromActionButton:true];
	[[watchToUse mainTime] unlatchTime];
	[ChronometerAppDelegate setPartBeingEvaluated:nil];
	if (doRepaint) {
	    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:ECDragNotDragging];
	}
    }
}

- (void)actNumberOfTimes:(int)numberOfTimes {
    [self actNumberOfTimes:numberOfTimes doRepaint:true];
}

- (void)act {
    [self actNumberOfTimes:1 doRepaint:true];
}

- (bool) drags {
    return false;
}

- (ECGLPart *)asDraggableFullPart {
    assert([self drags]);  // must be derived class
    assert([self isKindOfClass:[ECGLPart class]]);
    return (ECGLPart *)self;
}

- (int)grabPriority {
    return handGrabPriority;
}

- (double)currentAngle {
    return 0;
}

- (double)currentOffsetAngle {
    return 0;
}

- (double)offRadius {
    return 0;
}

- (CGPoint)currentOffset {
    return CGPointMake(0, 0);
}

- (CGPoint)currentAnchor {
    return CGPointMake(0, 0);
}

#ifdef HIRES_DUMP  // DOESN'T WORK ON WHEELS OR HANDS WITH OFFSET ANGLES, NOR ON TERMINATORS
-(void)drawHiresImage:(CGImageRef)cgImage intoContext:(CGContextRef)context {
    CGSize appSize = [ChronometerAppDelegate applicationSize];
    CGContextSaveGState(context);
    CGPoint anch = [self currentAnchor];
    CGRect bounds = [self boundsOnScreen];
    CGPoint lowerLeft = bounds.origin;
    bounds.origin.x = 0;
    bounds.origin.y = 0;
    CGPoint offset = [self currentOffset];
    double offsetAngle = [self currentOffsetAngle];
    double oRad = [self offRadius];
    offset.x -= oRad * cos(M_PI / 2 - offsetAngle);
    offset.y -= oRad * sin(M_PI / 2 - offsetAngle);
    CGContextScaleCTM(context, HIRES_DUMP, HIRES_DUMP);
    CGContextTranslateCTM(context, anch.x + appSize.width/2, anch.y + appSize.height/2);
    CGContextTranslateCTM(context, -offset.x, -offset.y);
    CGContextRotateCTM(context, -offsetAngle);
    CGContextRotateCTM(context, -[self currentAngle]);
    CGContextTranslateCTM(context, - anch.x + lowerLeft.x, - anch.y + lowerLeft.y );
    CGContextDrawImage(context, bounds, cgImage);
    CGContextRestoreGState(context);
}
#endif

@end

@interface ECGLPart (ECGLPartPrivate)

-(void)addingAnimationForValue;
-(void)removingAnimationForValue;

@end

@implementation ECGLPart

@synthesize handKind;

//#ifndef NDEBUG
void
printADateWithTimeZoneAbbrev(NSTimeInterval dt,
			     ESTimeZone     *estz,
			     const char     *tzAbbrev) {
    double fractionalSeconds = dt - floor(dt);
    int microseconds = round(fractionalSeconds * 1000000);
    ESDateComponents ltcs;
    ESCalendar_localDateComponentsFromTimeInterval(dt, estz, &ltcs);
    printf("%d %04d/%02d/%02d %02d:%02d:%02d.%06d%s",
	   ltcs.era, ltcs.year, ltcs.month, ltcs.day, ltcs.hour, ltcs.minute, (int)floor(ltcs.seconds), microseconds, tzAbbrev);
}
void
printADate(NSTimeInterval dt) {
    printADateWithTimeZoneAbbrev(dt, ESCalendar_localTimeZone(), " LT");
}

void
printADateWithTimeZone(NSTimeInterval dt,
		       ESTimeZone     *estz) {
    printADateWithTimeZoneAbbrev(dt, estz, "");
}

void
printDate(const char *description) {
    NSTimeInterval dt = [TSTime currentTime];
    double fractionalSeconds = dt - floor(dt);
    int microseconds = round(fractionalSeconds * 1000000);
    ESDateComponents ltcs;
    ESCalendar_localDateComponentsFromTimeInterval(dt, ESCalendar_localTimeZone(), &ltcs);
    printf("%d %04d/%02d/%02d %02d:%02d:%02d.%06d LT %s",
	   ltcs.era, ltcs.year, ltcs.month, ltcs.day, ltcs.hour, ltcs.minute, (int)floor(ltcs.seconds), microseconds, description);
}
//#endif

static NSString *formatAngleValue(ECGLAnimatingValue *val,
				  EBVirtualMachine   *vm) {
    double dcurrent = val->currentValue;
    double dtarget = val->targetValue;
    double deval = vm && val->instructionStream ? [vm evaluateInstructionStream:val->instructionStream errorReporter:ECtheErrorReporter] : 0.0;
    return [NSString stringWithFormat:@"%g=>%g[%g] degrees, %g=>%g[%g]/60, %g=>%g[%g]/12 %sanimating",
		     dcurrent * 180 / M_PI, dtarget * 180 / M_PI, deval * 180 / M_PI,
		     dcurrent * 30 / M_PI, dtarget * 30 / M_PI, deval * 30 / M_PI,
		     dcurrent * 6 / M_PI, dtarget * 6 / M_PI, deval * 6 / M_PI,
		     (val->animating ? "" : "NOT ")];
}

static NSString *formatLinearValue(ECGLAnimatingValue *val,
				   EBVirtualMachine   *vm) {
    double dcurrent = val->currentValue;
    double dtarget = val->targetValue;
    double deval = val->instructionStream ? [vm evaluateInstructionStream:val->instructionStream errorReporter:ECtheErrorReporter] : 0.0;
    return [NSString stringWithFormat:@"%g=>%g[%g] %sanimating", dcurrent, dtarget, deval, (val->animating ? "" : "NOT ")];

}

static double
getAnimatedValue(ECGLAnimatingValue *value,
		 bool               isAngle,
		 ECGLPart           *forPart,
		 NSTimeInterval     atTime)  // actual time, not time of watch
{
    if (!value->instructionStream) {
	return 0;
    }
    if (value->animating) {
	if (atTime >= value->animationStopTime) {
	    value->animating = false;
	    [forPart removingAnimationForValue];
	    if (isAngle) {
		value->currentValue = EC_fmod(value->targetValue, 2 * M_PI);
	    } else {
		value->currentValue = value->targetValue;
	    }
	} else {
	    double fractionComplete = (atTime - value->lastAnimationTime) / (value->animationStopTime - value->lastAnimationTime);
	    value->currentValue += (value->targetValue - value->currentValue) * fractionComplete;
	    value->lastAnimationTime = atTime;
	}
    }
    return value->currentValue;
}

#ifndef NDEBUG
static void assertValNotNan(double             val,
			    EBVirtualMachine   *vm,
			    ECGLAnimatingValue *value) {
    if (isnan(val)) {
	printf("\n\n *** BAD (nan) VALUE RETURNED FROM FOLLOWING INSTRUCTION STREAM *** \n");
	[value->instructionStream printToOutputFile:stdout withIndentLevel:1 fromVirtualMachine:vm];
	assert(!isnan(val)); // equivalent to assert(false), but more useful in the printout
    }
}
#else
#define assertValNotNan(a, b, c)
#endif

static double
updateAndReturnValue(ECGLAnimatingValue   *value,
		     double               animateSpeed,  // amount to move, per second
		     ECAnimationDirection animationDir,
		     bool                 isAngle,       // meaning delta is mod 2pi
		     ECGLPart             *forPart,
		     NSTimeInterval       atTime,  // actual time, not time of watch
		     EBVirtualMachine     *vm,
		     ECDragType           draggingPartDragType) {
    if (!value->instructionStream) {
	return 0;
    }
    double newValue = [vm evaluateInstructionStream:value->instructionStream errorReporter:ECtheErrorReporter];
    if (isAngle) {
	newValue = EC_fmod(newValue, 2 * M_PI);
    }
    if (!animateSpeed) {
	value->currentValue = newValue;
	value->animating = false;
	assertValNotNan(newValue, vm, value);
	return newValue;
    }
    if (value->currentValue == newValue) {
	value->animating = false;
	assertValNotNan(newValue, vm, value);
	return newValue;
    }
    value->targetValue = newValue;
    if (isAngle) {
	if (animationDir == ECAnimationDirLogicalForward) {
	    animationDir = [[vm owner] runningBackward] ? ECAnimationDirAlwaysCCW : ECAnimationDirAlwaysCW;
	} else if (animationDir == ECAnimationDirLogicalBackward) {
	    animationDir = [[vm owner] runningBackward] ? ECAnimationDirAlwaysCW : ECAnimationDirAlwaysCCW;
	}
	// At this point, the possible values are AlwaysCW, AlwaysCCW, Closest, Furthest
	switch (animationDir) {
	  case ECAnimationDirAlwaysCW:
	    if (newValue > value->currentValue) {  // Correct direction
		if (newValue - value->currentValue > 2 * M_PI) {
		    value->currentValue += 2 * M_PI;  // Make the current value match the cycle that we're trying to get to
		}
	    } else {  // going backwards, need to move logically backwards so we can animate forwards
		value->currentValue -= 2 * M_PI;
	    }
	    break;
	  case ECAnimationDirAlwaysCCW:
	    if (newValue < value->currentValue) {  // Correct direction
		if (value->currentValue - newValue > 2 * M_PI) {
		    value->currentValue -= 2 * M_PI;  // Make the current value match the cycle that we're trying to get to
		}
	    } else {  // going fowards, need to move logically forward so we can animate backwards
		value->currentValue += 2 * M_PI;
	    }
	    break;
	  case ECAnimationDirClosest:
	    if (newValue > value->currentValue) {
		if (newValue - value->currentValue > M_PI) {
		    value->currentValue += 2 * M_PI;  // Make the current value match the cycle that we're trying to get to
		}
	    } else {
		if (value->currentValue - newValue > M_PI) {
		    value->currentValue -= 2 * M_PI;  // Make the current value match the cycle that we're trying to get to
		}
	    }
	    break;
	  case ECAnimationDirFurthest:
	    if (newValue > value->currentValue) {
		if (newValue - value->currentValue < M_PI) {
		    value->currentValue -= 2 * M_PI;  // Make the current value match the cycle that we're trying to get to
		}
	    } else {
		if (value->currentValue - newValue < M_PI) {
		    value->currentValue += 2 * M_PI;  // Make the current value match the cycle that we're trying to get to
		}
	    }
	    break;
	  default:
	    assert(false);
	}
	// if (forPart->animateDuringDrag) printf("updateAndReturnValue: %s\n", [formatAngleValue(value, vm) UTF8String]);
    } else {
	// if (forPart->animateDuringDrag) printf("updateAndReturnValue: %s\n", [formatLinearValue(value, vm) UTF8String]);
    }
    double deltaTime = fabs(value->targetValue - value->currentValue) / animateSpeed;
    if (draggingPartDragType == ECDragHack1 && (forPart->dragAnimationType == ECDragAnimationHack1 || forPart->dragAnimationType == ECDragAnimationHack2)) {
	if ([ChronometerAppDelegate isFirstGenerationHardware]) {
	    deltaTime /= 2;
	} else {
	    deltaTime /= 4;
	}
    }
    if (deltaTime < kECGLFrameRate) {
	value->animating = false;
	value->currentValue = value->targetValue;
	assertValNotNan(value->currentValue, vm, value);
	return value->currentValue;
    }
    [forPart addingAnimationForValue];
    if (value->animating) {
	// If we're already animating, we don't reset the stop time.  That will guarantee we get back to where we're supposed
	// to be at the original animation stop time.  It might do weird things to the speed, though.
	double val = getAnimatedValue(value, isAngle, forPart, atTime);
	assertValNotNan(val, vm, value);
	return val;
    } else {
	value->lastAnimationTime = atTime;
	value->animating = true;
	value->animationStopTime = atTime + deltaTime;
	double animationOverrideInterval = [ChronometerAppDelegate animationOverrideInterval];
	if (animationOverrideInterval) {
	    value->animationStopTime = atTime + animationOverrideInterval;
	}
    }
    assertValNotNan(value->currentValue, vm, value);
    return value->currentValue;
}

static double
getAngle(ECGLAnimatingValue   *value,
	 ECGLPart             *forPart,
	 NSTimeInterval       atTime,
	 bool                 evaluateExpressions,
	 double               animationSpeed,
	 ECAnimationDirection animationDir,
	 EBVirtualMachine     *vm,
	 ECDragType           draggingPartDragType) {
    if (evaluateExpressions) {
	return updateAndReturnValue(value, animationSpeed, animationDir, true/*isAngle*/, forPart, atTime, vm, draggingPartDragType);
    } else {
	return getAnimatedValue(value, true/*isAngle*/, forPart, atTime);
    }
}

static double
getLinear(ECGLAnimatingValue *value,
	  ECGLPart           *forPart,
	  NSTimeInterval     atTime,
	  bool               evaluateExpressions,
	  double             animationSpeed,
	  EBVirtualMachine   *vm,
	  ECDragType         draggingPartDragType) {
    if (evaluateExpressions) {
	return updateAndReturnValue(value, animationSpeed, ECAnimationDirClosest, false/* !isAngle*/, forPart, atTime, vm, draggingPartDragType);
    } else {
	return getAnimatedValue(value, false/* !isAngle*/, forPart, atTime);
    }
}

- (id)initFromArchive:(ECWatchArchive *)watchArchive
  usingVirtualMachine:(EBVirtualMachine *)aVm
	    intoWatch:(ECGLWatch *)aWatch {
    [super init];
    watch = aWatch;
    vm = aVm;
    animating = 0;
    int frontTextureSlot;
    int backTextureSlot;
    int nightTextureSlot;
    int hKind;
    int mMask;
    bool imm, expd;
    ECPartRepeatStrategy rpts;
    ECWatchTimerSlot updTimer;
    bool flipXOnBackB;
    bool flipXB;
    bool flipYB;
    bool centerPixelOnly;
    ECDragType dragT;
    ECDragAnimationType dragAnimationT;
    ECAnimationDirection animD;
    int grabPri;
    int envSlt;
    bool norot;
    bool cornerRel;
    ECButtonEnabledControl enabledCtl;
    int masterIndex;
    ECPartSpecialness specialness;
    unsigned int specialParam;
    [watchArchive readWatchPartDataWithFrontTextureSlot:&frontTextureSlot
					backTextureSlot:&backTextureSlot
				       nightTextureSlot:&nightTextureSlot
					 boundsOnScreen:&boundsOnScreen
					 anchorOnScreen:&anchorOnScreen
					 updateInterval:&updateInterval
				   updateIntervalOffset:&updateIntervalOffset
					    updateTimer:&updTimer
					       modeMask:&mMask
					       handKind:&hKind
					       dragType:&dragT
				      dragAnimationType:&dragAnimationT
					      animSpeed:&animSpeed
						animDir:&animD
					       grabPrio:&grabPri
						envSlot:&envSlt
					    specialness:&specialness
				       specialParameter:&specialParam
					       norotate:&norot
					 cornerRelative:&cornerRel
					     flipOnBack:&flipXOnBackB
						  flipX:&flipXB
						  flipY:&flipYB
					centerPixelOnly:&centerPixelOnly
				    usingVirtualMachine:aVm
				 angleInstructionStream:&angle.instructionStream
			       xOffsetInstructionStream:&xOffset.instructionStream
			       yOffsetInstructionStream:&yOffset.instructionStream
					   offsetRadius:&offsetRadius
			   offsetAngleInstructionStream:&offsetAngle.instructionStream
				actionInstructionStream:&actionInstructionStream
					 repeatStrategy:&rpts
					      immediate:&imm
					       expanded:&expd
					    masterIndex:&masterIndex
					 enabledControl:&enabledCtl];
    assert(ECHandKindUB < 255);
    handKind = (int)hKind;
    updateTimer = (int)updTimer;
    flipXOnBack = (int)flipXOnBackB;
    flipX = (int)flipXB;
    flipY = (int)flipYB;
    dragType = (unsigned int)dragT;
    dragAnimationType = (unsigned int)dragAnimationT;
    animationDir = (int)animD;
    assert(grabPri >= ECGrabPrioLB && grabPri <= ECGrabPrioUB);
    handGrabPriority = grabPri;
    assert(envSlt >= 0 && envSlt <= ECEnvUB);
    envSlot = envSlt;
    partSpecialness = (unsigned int)specialness;
    specialParameter = specialParam;
    norotate = norot;
    cornerRelative = cornerRel;
    assert(enabledCtl >= 0 && enabledCtl < 256);
    enabledControl = (unsigned int)enabledCtl;
    assert(rpts >= ECPartRepeatStrategyLB && rpts <= ECPartRepeatStrategyUB);
    repeatStrategy = (unsigned int)rpts;
    immediate = imm;
    expanded = expd;
    assert(mMask >= 0 && mMask < 64);
    modeMask = mMask;
    textureDataByMode[ECfrontMode].textureAtlasSlotIndex = frontTextureSlot;
    textureDataByMode[ECbackMode].textureAtlasSlotIndex = backTextureSlot;
    textureDataByMode[ECnightMode].textureAtlasSlotIndex = nightTextureSlot;
    [angle.instructionStream retain];
    [xOffset.instructionStream retain];
    [yOffset.instructionStream retain];
    [offsetAngle.instructionStream retain];
    [actionInstructionStream retain];
    for (int i = 0; i < ECNumWatchDrawModes; i++) {
	textureDataByMode[i].displayList = nil;
	textureDataByMode[i].displayListIndex = -1;
    }
    if (masterIndex >= 0) {
	assert(masterIndex < watch.partBases.count);
	ECGLPart *master = [watch.partBases objectAtIndex:masterIndex];
        assert([master isKindOfClass:[ECGLPart class]]);  // The array has ECGLPartBases in it but master shouldn't be one
	assert(master->modeMask == self->modeMask);
	assert(!master->isSlave);
	self->nextSlave = master->nextSlave;
	master->nextSlave = self;
	isSlave = 1;
    } else {
	isSlave = 0;
	self->nextSlave = nil;
    }
    return self;
}

- (void)dealloc {
    [angle.instructionStream release];
    [xOffset.instructionStream release];
    [yOffset.instructionStream release];
    [offsetAngle.instructionStream release];
    [super dealloc];
}

- (bool)isSlave {
    return (isSlave != 0);
}

- (double)currentAngle {
    return angle.currentValue;
}

- (CGPoint)currentAnchor {
    return anchorOnScreen;
}

- (double)currentOffsetAngle {
    return offsetAngle.currentValue;
}

- (CGPoint)currentOffset {
    return CGPointMake(xOffset.currentValue, yOffset.currentValue);
}

- (double)offRadius {
    return offsetRadius;
}

- (bool)activeInModeNum:(ECWatchModeEnum)modeNum {
    bool manualSet = [watch manualSet];
    bool alarmManualSet = [watch alarmManualSet];
    ECWatchModeMask mask = 1 << modeNum;
    return
	(modeMask & mask) &&
	(actionInstructionStream != NULL || (manualSet && handKind != ECNotTimerZeroKind  && (handKind < ECHandKindFirstAlarm || handKind > ECHandKindLastAlarm)) || (alarmManualSet && handKind >= ECHandKindFirstAlarm && handKind <= ECHandKindLastAlarm)) &&
	(enabledControl == ECButtonEnabledAlways || manualSet || (alarmManualSet && (enabledControl == ECButtonEnabledAlarmStemOutOnly || handKind >= ECHandKindFirstAlarm && handKind <= ECHandKindLastAlarm)) || (enabledControl == ECButtonEnabledWrongTimeOnly && ![watch mainTime].isCorrect));
}

- (void)resetPart {
    nextUpdateTime = ECFarInThePast;
}

- (bool) drags {
    return handKind != ECNotTimerZeroKind;
}

- (int)modeMask {
    return (int)modeMask;
}

- (void)moveLocationForDeltaAngle:(double)deltaAngle fromOriginalLatitude:(double)originalLatitude originalLongitude:(double)originalLongitude {
    switch (handKind) {
      case ECLatitudeMinuteOnesHandKind:
	{
	    ECLocationManager *locationManager = [[watch enviroWithIndex:0] locationManager];
	    if ([locationManager valid]) {
		double lat = originalLatitude;
		double sign = lat > 0 ? 1 : -1;
		// 2pi angle == 10/60 of 1/360 of 2pi
		lat += sign * deltaAngle / (6 * 360);
		if (lat > M_PI/2) {
		    lat = M_PI/2;
		} else if (lat < 0) {
		    lat = 0;
		}
		[locationManager setOverrideLocationToLatitudeRadians:lat longitudeRadians:originalLongitude altitudeMeters:0];
	    }
	}
	break;
      case ECLatitudeMinuteTensHandKind:
	{
	    ECLocationManager *locationManager = [[watch enviroWithIndex:0] locationManager];
	    if ([locationManager valid]) {
		double lat = originalLatitude;
		double sign = lat > 0 ? 1 : -1;
		// 2pi angle == 1/360 of 2pi
		lat += sign * deltaAngle / 360;
		if (lat > M_PI/2) {
		    lat = M_PI/2;
		} else if (lat < 0) {
		    lat = 0;
		}
		[locationManager setOverrideLocationToLatitudeRadians:lat longitudeRadians:originalLongitude altitudeMeters:0];
	    }
	}
	break;
      case ECLatitudeOnesHandKind:
	{
	    ECLocationManager *locationManager = [[watch enviroWithIndex:0] locationManager];
	    if ([locationManager valid]) {
		double lat = originalLatitude;
		double sign = lat > 0 ? 1 : -1;
		// 2pi angle == 1/36 of 2pi
		lat += sign * deltaAngle / 36;
		if (lat > M_PI/2) {
		    lat = M_PI/2;
		} else if (lat < 0) {
		    lat = 0;
		}
		[locationManager setOverrideLocationToLatitudeRadians:lat longitudeRadians:originalLongitude altitudeMeters:0];
	    }
	}
	break;
      case ECLatitudeTensHandKind:
	{
	    ECLocationManager *locationManager = [[watch enviroWithIndex:0] locationManager];
	    if ([locationManager valid]) {
		double lat = originalLatitude;
		double sign = lat > 0 ? 1 : -1;
		// 2pi angle == 1/3.6 of 2pi
		lat += sign * deltaAngle / 3.6;
		if (lat > M_PI/2) {
		    lat = M_PI/2;
		} else if (lat < 0) {
		    lat = 0;
		}
		[locationManager setOverrideLocationToLatitudeRadians:lat longitudeRadians:originalLongitude altitudeMeters:0];
	    }
	}
	break;
      case ECLongitudeMinuteOnesHandKind:
	{
	    ECLocationManager *locationManager = [[watch enviroWithIndex:0] locationManager];
	    if ([locationManager valid]) {
		double longit = originalLongitude;
		double sign = longit > 0 ? 1 : -1;
		// 2pi angle == 10/60 of 1/360 of 2pi
		longit += sign * deltaAngle / (6 * 360);
		if (longit > M_PI) {
		    longit = M_PI;
		} else if (longit < 0) {
		    longit = 0;
		}
		[locationManager setOverrideLocationToLatitudeRadians:originalLatitude longitudeRadians:longit altitudeMeters:0];
	    }
	}
	break;
      case ECLongitudeMinuteTensHandKind:
	{
	    ECLocationManager *locationManager = [[watch enviroWithIndex:0] locationManager];
	    if ([locationManager valid]) {
		double longit = originalLongitude;
		double sign = longit > 0 ? 1 : -1;
		// 2pi angle == 1/360 of 2pi
		longit += sign * deltaAngle / 360;
		if (longit > M_PI) {
		    longit = M_PI;
		} else if (longit < 0) {
		    longit = 0;
		}
		[locationManager setOverrideLocationToLatitudeRadians:originalLatitude longitudeRadians:longit altitudeMeters:0];
	    }
	}
	break;
      case ECLongitudeOnesHandKind:
	{
	    ECLocationManager *locationManager = [[watch enviroWithIndex:0] locationManager];
	    if ([locationManager valid]) {
		double longit = originalLongitude;
		double sign = longit > 0 ? 1 : -1;
		// 2pi angle == 10/360 of 2pi
		longit += sign * deltaAngle / 36;
		if (longit > M_PI) {
		    longit = M_PI;
		} else if (longit < 0) {
		    longit = 0;
		}
		[locationManager setOverrideLocationToLatitudeRadians:originalLatitude longitudeRadians:longit altitudeMeters:0];
	    }
	}
	break;
      case ECLongitudeTensHandKind:
	{
	    ECLocationManager *locationManager = [[watch enviroWithIndex:0] locationManager];
	    if ([locationManager valid]) {
		double longit = originalLongitude;
		double sign = longit > 0 ? 1 : -1;
		// 2pi angle == 100/360 of 2pi
		longit += sign * deltaAngle / 3.6;
		if (longit > M_PI) {
		    longit = M_PI;
		} else if (longit < 0) {
		    longit = 0;
		}
		[locationManager setOverrideLocationToLatitudeRadians:originalLatitude longitudeRadians:longit altitudeMeters:0];
	    }
	}
	break;
      case ECLongitudeHundredsHandKind:
	{
	    ECLocationManager *locationManager = [[watch enviroWithIndex:0] locationManager];
	    if ([locationManager valid]) {
		double longit = originalLongitude;
		double sign = longit > 0 ? 1 : -1;
		// 2pi angle == 1000/360 of 2pi
		longit += sign * deltaAngle / .36;
		if (longit > M_PI) {
		    longit = M_PI;
		} else if (longit < 0) {
		    longit = 0;
		}
		[locationManager setOverrideLocationToLatitudeRadians:originalLatitude longitudeRadians:longit altitudeMeters:0];
	    }
	}
	break;
      case ECLatitudeSignHandKind:
	{
	    ECLocationManager *locationManager = [[watch enviroWithIndex:0] locationManager];
	    if ([locationManager valid]) {
		double lat = originalLatitude;
		if (lat > 0) {
		    if (deltaAngle < -M_PI/8) {
			lat = -lat;
		    }
		} else {
		    if (deltaAngle > M_PI/8) {
			lat = -lat;
		    }
		}
		[locationManager setOverrideLocationToLatitudeRadians:lat longitudeRadians:originalLongitude altitudeMeters:0];
	    }
	}
	break;
      case ECLongitudeSignHandKind:
	{
	    ECLocationManager *locationManager = [[watch enviroWithIndex:0] locationManager];
	    if ([locationManager valid]) {
		double longit = originalLongitude;
		if (longit > 0) {
		    if (deltaAngle < -M_PI/8) {
			longit = -longit;
		    }
		} else {
		    if (deltaAngle > M_PI/8) {
			longit = -longit;
		    }
		}
		[locationManager setOverrideLocationToLatitudeRadians:originalLatitude longitudeRadians:longit altitudeMeters:0];
	    }
	}
	break;
    }
}

- (void)moveTimerZeroForDeltaAngle:(double)deltaAngle from:(NSTimeInterval)startTime {
    ECWatchTime *watchTime = [watch mainTime];
    ECWatchEnvironment *env = [watch mainEnv];
    switch (handKind) {
      case ECSecondHandKind:
        [watchTime advanceBySeconds:                   (deltaAngle * 60 / (2*M_PI)) fromTime:startTime];
	break;
      case ECMinuteHandKind:
        [watchTime advanceBySeconds:            60.0 * (deltaAngle * 60 / (2*M_PI)) fromTime:startTime];
	break;
      case ECHour12HandKind:
        [watchTime advanceBySeconds:     60.0 * 60.0 * (deltaAngle * 12 / (2*M_PI)) fromTime:startTime];
	break;
      case ECReverseHour24Kind:
	[watchTime advanceBySeconds:    -60.0 * 60.0 * (deltaAngle * 24 / (2*M_PI)) fromTime:startTime];
	break;
      case ECHour24HandKind:
	[watchTime advanceBySeconds:     60.0 * 60.0 * (deltaAngle * 24 / (2*M_PI)) fromTime:startTime];
	break;
      case ECHour24MoonHandKind:
	[watchTime advanceBySeconds: 60.0 * 60.0 * 24 * deltaAngle * 29.5306 / (29.5306 - 1) / (2*M_PI) fromTime:startTime];
	break;
      case ECDayHandKind:
        [watchTime advanceByDays:	     (int)round(deltaAngle * 31 / (2*M_PI)) fromTime:startTime usingEnv:env];
	break;
      case ECMoonDayHandKind:
        [watchTime advanceBySeconds:      (deltaAngle * 29.5306 * 86400 / (2*M_PI)) fromTime:startTime];
	break;
      case ECSunRAHandKind:
        [watchTime advanceBySeconds:   (deltaAngle * 365.242191 * 86400 / (2*M_PI)) fromTime:startTime];
	break;
      case ECReverseSunRAHandKind:
	[watchTime advanceBySeconds:  -(deltaAngle * 365.242191 * 86400 / (2*M_PI)) fromTime:startTime];
	break;
      case ECMoonRAHandKind:
        [watchTime advanceBySeconds:           deltaAngle/(2*M_PI) * 27.322 * 86400 fromTime:startTime];
        break;
      case ECReverseMoonRAHandKind:
	[watchTime advanceBySeconds:          -deltaAngle/(2*M_PI) * 27.322 * 86400 fromTime:startTime];
	break;
      case ECWkDayHandKind:
	[watchTime advanceByDays:            (int)round(deltaAngle *  7 / (2*M_PI)) fromTime:startTime usingEnv:env];
	break;
      case ECMonthHandKind:
	[watchTime advanceByMonths:          (int)round(deltaAngle * 12 / (2*M_PI)) fromTime:startTime usingEnv:env];
	break;
      case ECYear1HandKind:
	[watchTime advanceByYears:           (int)round(deltaAngle * 10 / (2*M_PI)) fromTime:startTime usingEnv:env];
	break;
      case ECMercuryYearHandKind:
	[watchTime advanceBySeconds:   (-deltaAngle *      87.97 * 86400 / (2*M_PI)) fromTime:startTime];
	break;
      case ECVenusYearHandKind:
	[watchTime advanceBySeconds:   (-deltaAngle *     224.70 * 86400 / (2*M_PI)) fromTime:startTime];
	break;
      case ECEarthYearHandKind:
	[watchTime advanceBySeconds:   (-deltaAngle *     365.26 * 86400 / (2*M_PI)) fromTime:startTime];
	break;
      case ECMarsYearHandKind:
	[watchTime advanceBySeconds:   (-deltaAngle *     686.98 * 86400 / (2*M_PI)) fromTime:startTime];
	break;
      case ECJupiterYearHandKind:
	[watchTime advanceBySeconds:   (-deltaAngle *    4332.71 * 86400 / (2*M_PI)) fromTime:startTime];
	break;
      case ECSaturnYearHandKind:
	[watchTime advanceBySeconds:   (-deltaAngle *   10759.50 * 86400 / (2*M_PI)) fromTime:startTime];
	break;
      case ECYear10HandKind:
	[watchTime advanceByYears:     (int)round(10 * (deltaAngle * 10 / (2*M_PI))) fromTime:startTime usingEnv:env];
	break;
      case ECYear100HandKind:
	[watchTime advanceByYears:    (int)round(100 * (deltaAngle * 10 / (2*M_PI))) fromTime:startTime usingEnv:env];
	break;
      case ECYear1000HandKind:
	[watchTime advanceByYears:   (int)round(1000 * (deltaAngle * 10 / (2*M_PI))) fromTime:startTime usingEnv:env];
	break;
      case ECGreatYearHandKind:
	[watchTime advanceByYears:     (int)round(25772 * (deltaAngle   / (2*M_PI))) fromTime:startTime usingEnv:env];
	break;
      case ECNodalHandKind:
	[watchTime advanceByDays:     (int)round(-(deltaAngle *  6793.5 / (2*M_PI))) fromTime:startTime usingEnv:env];
	break;
      default:
        assert(false);
    }
}

- (void)moveAlarmTimeForDeltaAngle:(double)deltaAngle from:(double)startOffset {
    int numUnits;
    switch (handKind) {
      case ECIntervalSecondHandKind:
	[watch setIntervalOffset:floor(EC_fmod(startOffset +               deltaAngle * 60 / (2*M_PI), ECIntervalAlarmWrap))];
	break;
      case ECIntervalMinuteHandKind:
	numUnits = (int) round(deltaAngle * 60 / (2 * M_PI));
	[watch setIntervalOffset:floor(EC_fmod(startOffset +        60.0 * numUnits, ECIntervalAlarmWrap))];
	break;
      case ECIntervalHour12HandKind:
	numUnits = (int) round(deltaAngle * 12 / (2 * M_PI));
	[watch setIntervalOffset:floor(EC_fmod(startOffset + 60.0 * 60.0 * numUnits, ECIntervalAlarmWrap))];
	break;
      case ECIntervalHour24HandKind:
	numUnits = (int) round(deltaAngle * 24 / (2 * M_PI));
	[watch setIntervalOffset:floor(EC_fmod(startOffset + 60.0 * 60.0 * numUnits, ECIntervalAlarmWrap))];
	break;
      case ECTargetMinuteHandKind:
	numUnits = (int) round(deltaAngle * 60 / (2 * M_PI));
	[watch setTargetOffset:floor(EC_fmod(startOffset +        60.0 * numUnits, ECTargetAlarmWrap) / 60) * 60];
	break;
      case ECTargetHour12HandKind:
	numUnits = (int) round(deltaAngle * 12 / (2 * M_PI));
	[watch setTargetOffset:floor(EC_fmod(startOffset + 60.0 * 60.0 * numUnits, ECTargetAlarmWrap) / 60) * 60];
	break;
      case ECTargetHour12HandKindB:
	numUnits = (int) round(deltaAngle * 144 / (2 * M_PI));
	[watch setTargetOffset:floor(EC_fmod(startOffset +  5.0 * 60.0 * numUnits, ECTargetAlarmWrap) / 300) * 300];
	break;
      case ECTargetHour24HandKind:
	numUnits = (int) round(deltaAngle * 24 / (2 * M_PI));
	[watch setTargetOffset:floor(EC_fmod(startOffset + 60.0 * 60.0 * numUnits, ECTargetAlarmWrap) / 60) * 60];
	break;
      default:
        assert(false);
    }
}

static int worldtimeRingShifts = 0;  // How many times we have, to this point, simulated advancing the ring 15 degrees

- (void)moveWorldtimeRingForDeltaAngle:(double)currentDeltaAngle from:(double)originalOffset {
    int shiftsRequiredForCurrentPosition = (int) round(currentDeltaAngle * 12 / M_PI);
    while (shiftsRequiredForCurrentPosition < 0) {
	shiftsRequiredForCurrentPosition += 24;
    }
    shiftsRequiredForCurrentPosition %= 24;
    int newShiftsRequired = shiftsRequiredForCurrentPosition - worldtimeRingShifts;
    while (newShiftsRequired < 0) {
	newShiftsRequired += 24;
    }
    newShiftsRequired %= 24;
    worldtimeRingShifts = (shiftsRequiredForCurrentPosition % 24);
    if (newShiftsRequired > 0) {
	[self actNumberOfTimes:newShiftsRequired doRepaint:false];
    }
}

static double angleRepresentedByPoint(CGPoint touchPoint, CGPoint anchorPoint) {
    double dx = touchPoint.x - anchorPoint.x;
    double dy = touchPoint.y - anchorPoint.y;
    return atan2(dy, dx);
}

static double originalLatitude;
static double originalLongitude;
static double originalOffset = 0;
static NSDate *originalTime = nil;
static double lastPointAngle = 0;     // ditto.
static double currentDeltaAngle = 0;  // ditto.  The difference between currentPointAngle and firstPointAngle says how much the hand should move.
                               // note that this is cumulative, meaning if you go all the way around it remembers.  This is the raw requested
                               // angle, before snapping to any "legal positions".
static NSTimeInterval lastTimestamp;

- (void)dragStartAtPoint:(CGPoint)firstTouchPoint {
    assert(handKind != ECNotTimerZeroKind);
    double watchZoom = [watch zoom];
    firstTouchPoint.x /= watchZoom;
    firstTouchPoint.y /= watchZoom;
    lastPointAngle = - angleRepresentedByPoint(firstTouchPoint, anchorOnScreen);
    currentDeltaAngle = 0;
    assert(!originalTime);
    originalTime = [[[watch mainTime] currentDate] retain];
    lastTimestamp = [NSDate timeIntervalSinceReferenceDate];
    if (handKind >= ECHandKindFirstLatLong && handKind <= ECHandKindLastLatLong) {
	ECLocationManager *locationManager = [[watch enviroWithIndex:0] locationManager];
	originalLatitude = [locationManager lastLatitudeRadians];
	originalLongitude = [locationManager lastLongitudeRadians];
    } else if (handKind >= ECHandKindFirstIntervalAlarm && handKind <= ECHandKindLastIntervalAlarm) {
	originalOffset = [watch currentOffset];
	printf("Original offset is %.2f\n", originalOffset);
    } else if (handKind >= ECHandKindFirstTargetAlarm && handKind <= ECHandKindLastTargetAlarm) {
	originalOffset = [watch specifiedOffset];
    } else if (handKind == ECWorldtimeRingHandKind) {
	worldtimeRingShifts = 0;
    }
}

//void EC_printAngle(double     angle,
//		   const char *description);

- (void)dragFrom:(CGPoint)firstTouchPoint to:(CGPoint)currentPoint {
    assert(originalTime);
    assert(handKind != ECNotTimerZeroKind);
    NSTimeInterval thisTimestamp = [NSDate timeIntervalSinceReferenceDate];
    if (thisTimestamp - lastTimestamp < kECDragRepeatInterval) {
	return;
    }
    double watchZoom = [watch zoom];
    firstTouchPoint.x /= watchZoom;
    firstTouchPoint.y /= watchZoom;
    currentPoint.x /= watchZoom;
    currentPoint.y /= watchZoom;

    lastTimestamp = thisTimestamp;
    double thisPointAngle = - angleRepresentedByPoint(currentPoint, anchorOnScreen);  // change sign: convert from trig angle to clock angle
    double deltaAngle = thisPointAngle - lastPointAngle;
    if (deltaAngle < (- M_PI)) {
	deltaAngle += (2 * M_PI);
    } else if (deltaAngle > M_PI) {
	deltaAngle -= (2 * M_PI);
    }
    currentDeltaAngle += deltaAngle;
    //EC_printAngle(currentDeltaAngle, "currentDeltaAngle");
    lastPointAngle = thisPointAngle;
    if (handKind >= ECHandKindFirstLatLong && handKind <= ECHandKindLastLatLong) {
	[self moveLocationForDeltaAngle:currentDeltaAngle fromOriginalLatitude:originalLatitude originalLongitude:originalLongitude];
    } else if (handKind >= ECHandKindFirstAlarm && handKind <= ECHandKindLastAlarm) {
	[self moveAlarmTimeForDeltaAngle:currentDeltaAngle from:originalOffset];
    } else if (handKind == ECWorldtimeRingHandKind) {
	[self moveWorldtimeRingForDeltaAngle:currentDeltaAngle from:originalOffset];
    } else {
	assert(originalTime);
	[self moveTimerZeroForDeltaAngle:currentDeltaAngle from:[originalTime timeIntervalSinceReferenceDate]];
    }
    //printf("\ndragFrom calling forceUpdate with dragType %d\n", dragType);
    [ChronometerAppDelegate forceUpdateAllowingAnimation:true dragType:dragType];  // but animate only those parts which should animate during drag of this drag type
    //printf("dragFrom done calling forceUpdate with dragType %d\n\n", dragType);
//    printf("drag redraw complete in %.4f seconds\n", [NSDate timeIntervalSinceReferenceDate] - thisTimestamp);
}

- (void)dragComplete {
    [originalTime release];
    originalTime = nil;
}

- (void)transformPointWithinView:(CGPoint *)pointWithinView forModeNum:(int)modeNum {
    ECWatchModeMask mask = (1 << modeNum);
    if (flipXOnBack && (mask & backOrBackNightMask)) {
	pointWithinView->x = - pointWithinView->x;
    }
    if (offsetAngle.instructionStream || xOffset.instructionStream || yOffset.instructionStream) {
	// remove offset from point (ignores masterOffsetAngle for now):
	double xoff = offsetRadius * cos(M_PI / 2 - offsetAngle.currentValue);
	double yoff = offsetRadius * sin(M_PI / 2 - offsetAngle.currentValue);
	xoff += xOffset.currentValue;
	yoff += yOffset.currentValue;
	pointWithinView->x -= xoff;
	pointWithinView->y -= yoff;
    }
    // Skip hands for now
    if (angle.instructionStream) {
	// unrotate point back into original coordinate system
	// convert to angle, radius
	double dx = pointWithinView->x - anchorOnScreen.x;
	double dy = pointWithinView->y - anchorOnScreen.y;
	double pointAngle = atan2(dy, dx);
	double unrotatedAngle = pointAngle + angle.currentValue;  // UNrotating means negative angle, except hand angles go the other way from trig angles so we add
	double radius = sqrt(dx * dx + dy * dy);
	pointWithinView->x = anchorOnScreen.x + radius * cos(unrotatedAngle);
	pointWithinView->y = anchorOnScreen.y + radius * sin(unrotatedAngle);
    }
}

- (bool)enclosesPointGuts:(CGPoint)point forModeNum:(int)modeNum expand:(bool)expand {
    CGPoint pointWithinView = point;
    [self transformPointWithinView:&pointWithinView forModeNum:modeNum];
    CGPoint origin = boundsOnScreen.origin;
    if (cornerRelative) {
        assert([watch isBackground]);
	[ChronometerAppDelegate translateCornerRelativeOrigin:&origin];
    }
    CGRect expandedBounds;
    if (boundsOnScreen.size.width < ECMinimumInputViewSize) {
	expandedBounds.origin.x = origin.x - (ECMinimumInputViewSize - boundsOnScreen.size.width)/2;
	expandedBounds.size.width = ECMinimumInputViewSize;
    } else {
	expandedBounds.origin.x = origin.x;
	expandedBounds.size.width = boundsOnScreen.size.width;
    }
    if (boundsOnScreen.size.height < ECMinimumInputViewSize) {
	expandedBounds.origin.y = origin.y - (ECMinimumInputViewSize - boundsOnScreen.size.height)/2;
	expandedBounds.size.height = ECMinimumInputViewSize;
    } else {
	expandedBounds.origin.y = origin.y;
	expandedBounds.size.height = boundsOnScreen.size.height;
    }
    if (xOffset.instructionStream) {
	expandedBounds.origin.x += [vm evaluateInstructionStream:xOffset.instructionStream errorReporter:ECtheErrorReporter];
    }
    if (yOffset.instructionStream) {
	expandedBounds.origin.y += [vm evaluateInstructionStream:yOffset.instructionStream errorReporter:ECtheErrorReporter];
    }
    if (expand) {
	expandedBounds.origin.x = 0;
	expandedBounds.size.width = [UIScreen mainScreen].bounds.size.width/2;
	expandedBounds.origin.y = origin.y - ([UIScreen mainScreen].bounds.size.height/2 - boundsOnScreen.size.height)/2;
	expandedBounds.size.height = [UIScreen mainScreen].bounds.size.height/2;

    }
    //printf("...checking point against bounds (%.1f, %.1f, %.1f, %.1f)\n",
    //       expandedBounds.origin.x,
    //       expandedBounds.origin.y,
    //       expandedBounds.origin.x + expandedBounds.size.width,
    //       expandedBounds.origin.y + expandedBounds.size.height);
    return CGRectContainsPoint(expandedBounds, pointWithinView);
}

- (bool)enclosesPoint:(CGPoint)point forModeNum:(ECWatchModeEnum)modeNum {
    return [self enclosesPointGuts:point forModeNum:modeNum expand:false];
}

- (bool)enclosesPointExpanded:(CGPoint)point forModeNum:(ECWatchModeEnum)modeNum {
    return [self enclosesPointGuts:point forModeNum:modeNum expand:true];
}

// Higher positive numbers mean more enclosed
- (double)distanceFromBorderToPoint:(CGPoint)point forModeNum:(ECWatchModeEnum)modeNum {
    assert([self enclosesPoint:point forModeNum:modeNum]);
    if (boundsOnScreen.size.width > 100 && boundsOnScreen.size.height > 100) {
	// Chandra hack:  If the button is that big, it should always lose when overlapping another part, so return zero
	return 0.01;
    }
    CGPoint origin = boundsOnScreen.origin;
    if (cornerRelative) {
        assert([watch isBackground]);
	[ChronometerAppDelegate translateCornerRelativeOrigin:&origin];
    }
    CGPoint pointWithinView = point;
    [self transformPointWithinView:&pointWithinView forModeNum:modeNum];
    CGFloat xlo, ylo, xhi, yhi;
    if (boundsOnScreen.size.width < ECMinimumInputViewSize) {
	xlo = origin.x - (ECMinimumInputViewSize - boundsOnScreen.size.width)/2;
	xhi = xlo + ECMinimumInputViewSize;
    } else {
	xlo = origin.x;
	xhi = xlo + boundsOnScreen.size.width;
    }
    if (boundsOnScreen.size.height < ECMinimumInputViewSize) {
	ylo = origin.y - (ECMinimumInputViewSize - boundsOnScreen.size.height)/2;
	yhi = ylo + ECMinimumInputViewSize;
    } else {
	ylo = origin.y;
	yhi = ylo + boundsOnScreen.size.height;
    }
    if (xOffset.instructionStream) {
	double offset = [vm evaluateInstructionStream:xOffset.instructionStream errorReporter:ECtheErrorReporter];
	xlo += offset;
	xhi += offset;
    }
    if (yOffset.instructionStream) {
	double offset = [vm evaluateInstructionStream:yOffset.instructionStream errorReporter:ECtheErrorReporter];
	ylo += offset;
	yhi += offset;
    }
    CGFloat closestDist;
    CGFloat dist = pointWithinView.x - xlo;
    assert(dist >= 0);
    closestDist = dist;
    dist = xhi - pointWithinView.x;
    assert(dist >= 0);
    if (dist < closestDist) {
	closestDist = dist;
    }
    dist = pointWithinView.y - ylo;
    assert(dist >= 0);
    if (dist < closestDist) {
	closestDist = dist;
    }
    dist = yhi - pointWithinView.y;
    assert(dist >= 0);
    if (dist < closestDist) {
	closestDist = dist;
    }
    return closestDist;
}

- (int)partTextureAtlasSlotIndexForModeNum:(ECWatchModeEnum)modeNum {
    assert(modeNum >= 0);
    assert(modeNum < ECNumWatchDrawModes);
    return textureDataByMode[modeNum].textureAtlasSlotIndex;
}

- (void)setupForDisplayList:(ECGLDisplayList *)dl
		    atIndex:(int)dlIndex
		 forModeNum:(ECWatchModeEnum)modeNum {
    assert(dl);
    assert(dlIndex >= 0);
    assert(dlIndex < [dl partCount]);
    assert((modeMask & (1 << modeNum)) != 0);
    assert(modeNum >= 0);
    assert(modeNum < ECNumWatchDrawModes);
    ECGLPartTextureData *partData = &textureDataByMode[modeNum];
    assert(!partData->displayList);
    assert(partData->displayListIndex == -1);  // don't call twice
    partData->displayList = dl;
    partData->displayListIndex = dlIndex;
    if (partSpecialness != ECPartNotSpecial) {
	[dl registerSpecialPart:self];
    }
}

static void calculateCorner(CGFloat cornerX,
			    CGFloat cornerY,
			    CGFloat anchorX,
			    CGFloat anchorY,
			    CGFloat theta,
			    CGFloat *rotX,
			    CGFloat *rotY) {
    CGFloat dx = cornerX - anchorX;
    CGFloat dy = cornerY - anchorY;
    CGFloat radius = sqrt (dx * dx + dy * dy);
    CGFloat phi = atan2f(dy, dx);
    CGFloat newPhi = phi - theta;
    *rotX = anchorX + radius * cosf(newPhi);
    *rotY = anchorY + radius * sinf(newPhi);
}

static void untranslateQuad(CGPoint                *quadVertices,
			    UIInterfaceOrientation currentOrientation) {
    if (currentOrientation == UIInterfaceOrientationPortrait ||
        currentOrientation == UIInterfaceOrientationPortraitUpsideDown) {
	return;
    }
    CGFloat temp;
    int i;
    switch(currentOrientation) {
      case UIInterfaceOrientationPortrait:
      case UIInterfaceOrientationPortraitUpsideDown:
      case UIInterfaceOrientationUnknown:
	assert(false);
	break;
      case UIInterfaceOrientationLandscapeLeft:  // ccw, home button at right
	for (i = 0; i < 4; i++) {
	    temp = quadVertices[i].x;
	    quadVertices[i].x = -quadVertices[i].y;
	    quadVertices[i].y = temp;
	}
	break;
      case UIInterfaceOrientationLandscapeRight:  // cw, home button at left
	for (i = 0; i < 4; i++) {
	    temp = quadVertices[i].x;
	    quadVertices[i].x = quadVertices[i].y;
	    quadVertices[i].y = -temp;
	}
	break;
    }
}

static void fullScreen(CGPoint *quadVertices) {
    // Presumes the part is in the atlas in portrait form.  Therefore:
    // Portrait (unchanged): UL, UR, LL, LR
    // Landscape:            UR, LR, UL, LL
    //printf("Before fullScreen: quads are\n");
    //printf("  %5g %5g\n", quadVertices[0].x, quadVertices[0].y);
    //printf("  %5g %5g\n", quadVertices[1].x, quadVertices[1].y);
    //printf("  %5g %5g\n", quadVertices[2].x, quadVertices[2].y);
    //printf("  %5g %5g\n", quadVertices[3].x, quadVertices[3].y);
    CGSize screenSize = [ChronometerAppDelegate applicationSize];
    //int screenScaleZoomTweakFactor = isIpad() ? 2.0 : 1.0;  // Extra tweak beyond screenSize
    int screenScaleZoomTweakFactor = 1.0;
    CGFloat halfWidth = screenSize.width / 2 / screenScaleZoomTweakFactor + 2;
    CGFloat halfHeight = screenSize.height / 2 / screenScaleZoomTweakFactor + 2;
    if (halfWidth > halfHeight) {
        quadVertices[0].x = halfHeight;
        quadVertices[0].y = halfWidth;
        quadVertices[1].x = halfHeight;
        quadVertices[1].y = -halfWidth;
        quadVertices[2].x = -halfHeight;
        quadVertices[2].y = halfWidth;
        quadVertices[3].x = -halfHeight;
        quadVertices[3].y = -halfWidth;
    } else {
        quadVertices[0].x = -halfWidth;
        quadVertices[0].y = halfHeight;
        quadVertices[1].x = halfWidth;
        quadVertices[1].y = halfHeight;
        quadVertices[2].x = -halfWidth;
        quadVertices[2].y = -halfHeight;
        quadVertices[3].x = halfWidth;
        quadVertices[3].y = -halfHeight;
    }
    //printf("After fullScreen: quads are\n");
    //printf("  %5g %5g\n", quadVertices[0].x, quadVertices[0].y);
    //printf("  %5g %5g\n", quadVertices[1].x, quadVertices[1].y);
    //printf("  %5g %5g\n", quadVertices[2].x, quadVertices[2].y);
    //printf("  %5g %5g\n", quadVertices[3].x, quadVertices[3].y);
}

// Only required when data changes
- (void)updateDisplayListsAtTime:(NSTimeInterval)atTime
		      forModeNum:(ECWatchModeEnum)modeNum
	     evaluateExpressions:(bool)evaluateExpressions
			 animate:(bool)animate
		     masterAngle:(double)masterAngle
	       masterOffsetAngle:(double)masterOffsetAngle
	    draggingPartDragType:(ECDragType)draggingPartDragType {
    assert(modeNum >= 0);
    assert(modeNum < ECNumWatchDrawModes);
    ECWatchModeMask mask = (1 << modeNum);
    assert(mask & modeMask);
    
    [ChronometerAppDelegate setPartBeingEvaluated:self];
    if (evaluateExpressions) {
	animating = 0;  // we'll turn it back on as we encounter them when setting the angles
    }

    double angleAnimationSpeed;
    double linearAnimationSpeed;
    if (animate && animSpeed) {
        if (animSpeed < 0) {
            angleAnimationSpeed  = kECGLAngleAnimationSpeed  * (-animSpeed);
            linearAnimationSpeed = 0;
        } else {
            angleAnimationSpeed  = kECGLAngleAnimationSpeed  * animSpeed;
            linearAnimationSpeed = kECGLLinearAnimationSpeed * animSpeed;
        }
    } else {
	angleAnimationSpeed = 0;
	linearAnimationSpeed = 0;
    }

    // Offsets for entire view, as with epicycle views or sliding buttons:
    double xOffsetTotal = 0;
    double yOffsetTotal = 0;
    double offsetAngleValue = masterOffsetAngle;
    if (offsetAngle.instructionStream) {
	offsetAngleValue += getAngle(&offsetAngle, self, atTime, evaluateExpressions, angleAnimationSpeed, animationDir, vm, draggingPartDragType);
	xOffsetTotal = offsetRadius * cos(M_PI / 2 - offsetAngleValue);
	yOffsetTotal = offsetRadius * sin(M_PI / 2 - offsetAngleValue);
    }
    double xOffsetValue = getLinear(&xOffset, self, atTime, evaluateExpressions, linearAnimationSpeed, vm, draggingPartDragType);
    xOffsetTotal += xOffsetValue;
    double yOffsetValue = getLinear(&yOffset, self, atTime, evaluateExpressions, linearAnimationSpeed, vm, draggingPartDragType);
    yOffsetTotal += yOffsetValue;
    double angleValue = masterAngle + offsetAngleValue + getAngle(&angle, self, atTime, evaluateExpressions, angleAnimationSpeed, animationDir, vm, draggingPartDragType);

    CGPoint origin = boundsOnScreen.origin;
    CGPoint anchor = anchorOnScreen;
    if (cornerRelative) {
        assert([watch isBackground]);  // Scaling is special for background watch so this won't work for other watches
	[ChronometerAppDelegate translateCornerRelativeOrigin:&origin];
	[ChronometerAppDelegate translateCornerRelativeOrigin:&anchor];
    }

    // UL, UR, LL, LR
    CGPoint quadVertices[4];
    calculateCorner(origin.x,
		    origin.y + boundsOnScreen.size.height,
		    anchor.x, anchor.y, (CGFloat)angleValue, &quadVertices[0].x, &quadVertices[0].y); // UL
    calculateCorner(origin.x + boundsOnScreen.size.width,
		    origin.y + boundsOnScreen.size.height,
		    anchor.x, anchor.y, (CGFloat)angleValue, &quadVertices[1].x, &quadVertices[1].y); // UR
    calculateCorner(origin.x,
		    origin.y,
		    anchor.x, anchor.y, (CGFloat)angleValue, &quadVertices[2].x, &quadVertices[2].y); // LL
    calculateCorner(origin.x + boundsOnScreen.size.width,
		    origin.y,
		    anchor.x, anchor.y, (CGFloat)angleValue, &quadVertices[3].x, &quadVertices[3].y); // LR
    for (int i = 0; i < 4; i++) {
	quadVertices[i].x += xOffsetTotal;
	quadVertices[i].y += yOffsetTotal;
    }

    if (flipXOnBack && (mask & backOrBackNightMask)) {
	for (int i = 0; i < 4; i++) {
	    quadVertices[i].x = -quadVertices[i].x;
	}
    }
    if (norotate) {
	//untranslateQuad(quadVertices, [ChronometerAppDelegate currentOrientation]);
        fullScreen(quadVertices);
    }
    ECGLPartTextureData *textureData = &textureDataByMode[modeNum];
    assert(textureData->displayListIndex >= 0);
    [textureData->displayList setPartShapeCoords:quadVertices forPartIndex:textureData->displayListIndex];
    [ChronometerAppDelegate setPartBeingEvaluated:nil];
    if (!isSlave && nextSlave) {  // Must be a master
	for (ECGLPart *slave = nextSlave; slave; slave = slave->nextSlave) {
	    [slave updateDisplayListsAtTime:atTime forModeNum:modeNum evaluateExpressions:evaluateExpressions animate:animate masterAngle:(angleValue - offsetAngleValue) masterOffsetAngle:offsetAngleValue draggingPartDragType:draggingPartDragType];
	}
    }
}

-(ECGLPartTextureData *) findPartTextureDataForDisplayList:(ECGLDisplayList *)displayList {
    for (int j = 0; j < ECNumWatchDrawModes; j++) {
	if (displayList == textureDataByMode[j].displayList) {
	    return &textureDataByMode[j];
	}
    }
    return (ECGLPartTextureData *)-1;
}

static void setupTextTransform(CGContextRef context,
			       CGRect       rect) {
    CGAffineTransform transform;  // without transforming, text shows up mirrored about the center of the rect
    // x' = ax + cy + tx
    // y' = bx + dy + ty
    transform.a = 1;
    transform.b = 0;
    transform.c = 0;
    transform.d = -1;
    transform.tx = 0;
    transform.ty = 2 * CGRectGetMidY(rect);
    CGContextConcatCTM(context, transform);
}

extern void EC_printAngle(double     angle,
			  const char *description);

static double drawCircularText(CGContextRef      context,
			       NSString          *str,
			       double            centerAngle,
			       double            radius,
			       double            leftAngularLimit,  /* wrt the center */
			       double            rightAngularLimit, /* wrt the center */
			       ECDialOrientation orientation,
			       CGFontRef         cgfont,    // cgfont presumed already set into context (at correct size) to avoid doing it for every call
			       double            pixelSpacing,
			       double            unitsPerPixel) {
    
    CGContextSaveGState(context);  // To restore rotation transform on exit

    int strLength = [str length];  // Does this do the right thing with composed characters?  The docs say no, but I'm not sure if we have any...
    // printf("Draw circular text %s size %d\n", [str UTF8String], strLength);
    if (strLength < 1) {
	return 0;
    }
    unichar *buffer     = (unichar *)malloc(strLength * sizeof(unichar));
    CGGlyph *glyphs     = (CGGlyph *)malloc(strLength * sizeof(CGGlyph));
    int *glyphAdvances  = (int *)    malloc(strLength * sizeof(int));
    [str getCharacters:buffer];
    CMFontGetGlyphsForUnichars(cgfont, buffer, glyphs, strLength);
    CGFontGetGlyphAdvances(cgfont, glyphs, strLength, glyphAdvances);

    bool drawUpsideDown = (orientation == ECDialOrientationDemiRadial && centerAngle > M_PI/2 && centerAngle < 3*M_PI/2);

    // compute total angular length in text units
    int lenInTextUnits = 0;
    double spacing = pixelSpacing * unitsPerPixel;
    for (int i = 0; i < strLength; i++) {
	lenInTextUnits += glyphAdvances[i];
	if (i != 0) {
	    lenInTextUnits += spacing;
	}
    }
    double angularLen = lenInTextUnits / (radius * unitsPerPixel);  // convert to pixels and then to radians
    double totalAngularLimit = 2 * fmin(leftAngularLimit, rightAngularLimit);  // We can do better than this, but to start...
    double angularSpacing = spacing / (radius * unitsPerPixel);
    bool removeCharacters = false;
    int lastLeftCharIncluded = 0;
    int firstRightCharIncluded = 0;
    int dotsLenInTextUnits = 0;
#define DOTS_MAXLEN 4
    CGGlyph dotGlyphs[DOTS_MAXLEN];
    int dotGlyphAdvances[DOTS_MAXLEN];
    CGPoint dotGlyphPositions[DOTS_MAXLEN];
    // but we need to add ".."
    const NSString *dots = @"..";  // Change following line too if this changes
    int numDots = 2;  // change previous line too if this changes
    if (angularLen > totalAngularLimit) {  // Text is too big to fit
	//printf("\nFor text %s, FAILS:\n", [str UTF8String], angularLen < totalAngularLimit ? "PASSES" : "FAILS");
	//EC_printAngle(angularLen, "angularLen");
	//EC_printAngle(totalAngularLimit, "totalAngularLimit");
	// Try without spacing
	double angularLenWithoutSpacing = angularLen - (strLength - 1) * angularSpacing;
	if (angularLenWithoutSpacing <= totalAngularLimit) {
	    // OK without spacing, just skip spacing
	    angularLen = angularLenWithoutSpacing;
	    angularSpacing = 0;
	    //printf("...but fixed it by removing kern spacing\n");
	} else {
	    // spacing isn't enough; remove some characters too
	    angularLen = angularLenWithoutSpacing;
	    angularSpacing = 0;


	    assert(numDots <= DOTS_MAXLEN);  // We won't want more than 4 dots certainly
	    unichar dotsBuf[DOTS_MAXLEN];
	    [dots getCharacters:dotsBuf];
	    CMFontGetGlyphsForUnichars(cgfont, dotsBuf, dotGlyphs, numDots);
	    CGFontGetGlyphAdvances(cgfont, dotGlyphs, numDots, dotGlyphAdvances);
	    double dotPixelSpacing = 0;
	    double dotSpacing = dotPixelSpacing * unitsPerPixel;
	    for (int i = 0; i < numDots; i++) {
		dotsLenInTextUnits += dotGlyphAdvances[i];
		if (i != 0) {
		    dotsLenInTextUnits += dotSpacing;
		}
	    }
	    double dotsAngularLen = dotsLenInTextUnits / (radius * unitsPerPixel);
	    angularLen += dotsAngularLen;
	    int center = strLength / 2;
	    lastLeftCharIncluded = center;
	    firstRightCharIncluded = center + 1;
	    removeCharacters = true;
	    while (angularLen > totalAngularLimit) {
		angularLen -= glyphAdvances[lastLeftCharIncluded] / (radius * unitsPerPixel);
		lastLeftCharIncluded--;
		assert(lastLeftCharIncluded >= 0);
		if (angularLen <= totalAngularLimit) {
		    break;
		}
		angularLen -= glyphAdvances[firstRightCharIncluded] / (radius * unitsPerPixel);
		firstRightCharIncluded++;
		assert(firstRightCharIncluded < strLength - 1);
	    }
	    // printf("...but removing kern spacing wasn't enough; lastLeft=%d, firstRight=%d of %d chars\n", lastLeftCharIncluded, firstRightCharIncluded, strLength);
	}
    }
    double priorRotationComponent;
    if (drawUpsideDown) {
	priorRotationComponent = -angularLen/2 - centerAngle + M_PI;
    } else {
	priorRotationComponent = angularLen/2 - centerAngle;
    }
    CGRect fontBbox = CGFontGetFontBBox(cgfont);
    double fontHeight = fontBbox.size.height / unitsPerPixel;
    for (int i = 0; i < strLength; i++) {
	double glyphWidth = glyphAdvances[i] / unitsPerPixel;
	double angularHalfLen = glyphWidth / (2 * radius);
        CGPoint point;
	if (drawUpsideDown) {
	    CGContextRotateCTM(context, priorRotationComponent + angularHalfLen);
	    // Deprecated: CGContextShowGlyphsAtPoint(context, -glyphWidth/2, -radius + fontHeight/2, &glyphs[i], 1);
            point.x = -glyphWidth/2;
            point.y = -radius + fontHeight/2;
            CGContextShowGlyphsAtPositions(context, &glyphs[i], &point, 1);
	    priorRotationComponent = angularHalfLen + angularSpacing;
	} else {
	    CGContextRotateCTM(context, priorRotationComponent - angularHalfLen);
	    // Deprecated: CGContextShowGlyphsAtPoint(context, -glyphWidth/2, radius - fontHeight, &glyphs[i], 1);
            point.x = -glyphWidth/2;
            point.y = radius - fontHeight;
            CGContextShowGlyphsAtPositions(context, &glyphs[i], &point, 1);
	    priorRotationComponent = -angularHalfLen - angularSpacing;
	}
	if (removeCharacters) {
	    if (i == lastLeftCharIncluded) {
		// draw dots;
		glyphWidth = dotsLenInTextUnits / unitsPerPixel;
		angularHalfLen = glyphWidth / (2 * radius);
		if (drawUpsideDown) {
		    CGContextRotateCTM(context, priorRotationComponent + angularHalfLen);
		    // Deprecated: CGContextShowGlyphsAtPoint(context, -glyphWidth/2, -radius + fontHeight/2, dotGlyphs, numDots);
                    double x = -glyphWidth/2;
                    double y = -radius + fontHeight/2;
                    for (int dotI = 0; dotI < numDots; dotI++) {
                        dotGlyphPositions[dotI].x = x;
                        dotGlyphPositions[dotI].y = y;
                        double dotGlyphWidth = dotGlyphAdvances[dotI] / unitsPerPixel;
                        x += dotGlyphWidth;
                    }
                    CGContextShowGlyphsAtPositions(context, dotGlyphs, dotGlyphPositions, numDots);
		    priorRotationComponent = angularHalfLen + angularSpacing;
		} else {
		    CGContextRotateCTM(context, priorRotationComponent - angularHalfLen);
		    // Deprecated: CGContextShowGlyphsAtPoint(context, -glyphWidth/2, radius - fontHeight, dotGlyphs, numDots);
                    double x = -glyphWidth/2;
                    double y = radius - fontHeight;
                    for (int dotI = 0; dotI < numDots; dotI++) {
                        dotGlyphPositions[dotI].x = x;
                        dotGlyphPositions[dotI].y = y;
                        double dotGlyphWidth = dotGlyphAdvances[dotI] / unitsPerPixel;
                        x += dotGlyphWidth;
                    }
                    CGContextShowGlyphsAtPositions(context, dotGlyphs, dotGlyphPositions, numDots);
		    priorRotationComponent = -angularHalfLen - angularSpacing;
		}
		i = firstRightCharIncluded - 1; // The -1 is because we're about to do i++ in the loop
	    }
	}
    }

    free(glyphAdvances);
    free(glyphs);
    free(buffer);
    CGContextRestoreGState(context);
    return angularLen;
}

static void drawRingTextAndPossiblyChannelForSlot(CGContextRef context,
						  ECGLWatch    *watch,
						  int          sector,
						  int          envSlot,
						  double       textRadius,
						  double       channelRadius,
						  CGFontRef    cgfont,
						  double       unitsPerPixel) {
    ECWatchEnvironment *env = [watch enviroWithIndex:envSlot];
    ESTimeZone *estz = env.estz;
    NSString *cityName = env.cityName;
    NSTimeInterval now = [TSTime currentTime];
    NSTimeInterval nextDST = ESCalendar_nextDSTChangeAfterTimeInterval(estz, now);
    bool drawChannel = (nextDST != 0);
    CGContextSetBlendMode(context, kCGBlendModeClear);
    double leftAngularLimit = M_PI / 12;  // Could do better by an analysis of what's to our left and right
    double rightAngularLimit = M_PI / 12;
    drawCircularText(context, cityName, sector * M_PI / 12, textRadius, leftAngularLimit, rightAngularLimit, ECDialOrientationRadial, cgfont, 0.5/*pixelSpacing*/, unitsPerPixel);
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    if (drawChannel) {
	int currentOffset = ESCalendar_tzOffsetForTimeInterval(estz, now);
	int nextOffset = ESCalendar_tzOffsetForTimeInterval(estz, nextDST + 2);
	double lowOffsetHours;
	double highOffsetHours;
	if (currentOffset > nextOffset) {
	    lowOffsetHours = nextOffset / 3600.0;
	    highOffsetHours = currentOffset / 3600.0;
	} else {
	    lowOffsetHours = currentOffset / 3600.0;
	    highOffsetHours = nextOffset / 3600.0;
	}
	//printf("Creating ring slot %d (env slot %d) (tz %.2f to %.2f) with city name %s\n", sector, envSlot, lowOffsetHours, highOffsetHours, [cityName UTF8String]);
	CGContextAddArc(context, 0, 0, channelRadius, (-4.5 - highOffsetHours) * M_PI / 12, (-4.5 - lowOffsetHours) * M_PI / 12, 0);
	CGContextDrawPath(context, kCGPathStroke);
    } else {
	CGFloat dashLengths[2] = {2, 3};
	int numDashLengths = sizeof(dashLengths) / sizeof(dashLengths[0]);
	CGContextSetLineDash(context, 0, dashLengths, numDashLengths);
	CGContextSetAlpha(context, 0.5);
	CGContextAddArc(context, 0, 0, channelRadius, (5.5 - sector) * M_PI / 12, (6.5 - sector) * M_PI / 12, 0);
	CGContextDrawPath(context, kCGPathStroke);
	CGContextSetLineDash(context, 0, NULL, 0);
    }
}
				     
static void drawUprightText(CGContextRef context,
			    NSString     *str,
			    CGPoint      center, 
			    CGFontRef    cgfont,
			    double       pixelSpacing,
			    double       unitsPerPixel) {
    int strLength = [str length];  // Does this do the right thing with composed characters?  The docs say no, but I'm not sure if we have any...
    if (strLength < 1) {
	return;
    }
    unichar *buffer     = (unichar *)malloc(strLength * sizeof(unichar));
    CGGlyph *glyphs     = (CGGlyph *)malloc(strLength * sizeof(CGGlyph));
    int *glyphAdvances  = (int *)    malloc(strLength * sizeof(int));
    CGRect *glyphBBoxes = (CGRect *) malloc(strLength * sizeof(CGRect));
    CGPoint *glyphPositions = (CGPoint *)malloc(strLength * sizeof(CGPoint));
    [str getCharacters:buffer];
    CMFontGetGlyphsForUnichars(cgfont, buffer, glyphs, strLength);
    CGFontGetGlyphAdvances(cgfont, glyphs, strLength, glyphAdvances);
    CGFontGetGlyphBBoxes(cgfont, glyphs, strLength, glyphBBoxes);

    int lengthInTextUnits = 0;
    CGFloat maxHeightInTextUnits = 0;
    for (int i = 0; i < strLength; i++) {
	lengthInTextUnits += glyphAdvances[i];
	CGFloat height = glyphBBoxes[i].size.height;
	if (height > maxHeightInTextUnits) {
	    maxHeightInTextUnits = height;
	}
    }
    double length = lengthInTextUnits / unitsPerPixel;  // convert to pixels
    double height = maxHeightInTextUnits / unitsPerPixel;
    double left = center.x - length/2;
    double bottom = center.y - height/2;
    double x = left;
    double y = bottom;
    for (int i = 0; i < strLength; i++) {
        glyphPositions[i].x = x;
        glyphPositions[i].y = y;
        x += glyphAdvances[i] / unitsPerPixel;
    }
    //CGContextStrokeRect(context, CGRectMake(left, bottom, length, height));
    // Deprecated: CGContextShowGlyphsAtPoint(context, left, bottom, glyphs, strLength);
    CGContextShowGlyphsAtPositions(context, glyphs, glyphPositions, strLength);

    free(glyphPositions);
    free(glyphBBoxes);
    free(glyphAdvances);
    free(glyphs);
    free(buffer);
}

- (void)drawSpecialPartIntoContext:(CGContextRef)context
		    forDisplayList:(ECGLDisplayList *)displayList
	     withinAtlasWithBounds:(CGRect)atlasSize
		   textureVertices:(ECDLCoordType *)textureVertices
			 zoomPower:(int)zoomPower {
    assert(![NSThread isMainThread]);
    ECGLPartTextureData *partTextureData = [self findPartTextureDataForDisplayList:displayList];
    ECDLCoordType *textureVertexPtr = &textureVertices[12 * partTextureData->displayListIndex];
    ECDLCoordType left   = textureVertexPtr[0] * atlasSize.size.width;
    ECDLCoordType bottom = atlasSize.size.height - textureVertexPtr[1] * atlasSize.size.height;
    ECDLCoordType right  = textureVertexPtr[2] * atlasSize.size.width;
    ECDLCoordType top    = atlasSize.size.height - textureVertexPtr[5] * atlasSize.size.height;  // Note: NOT [3]; these are triangles
    //CGContextStrokeRect(context, CGRectMake(left, bottom, right-left, top-bottom));
    double zoomFactor = zoomPower < 0 ? 1.0 / (1 << (-zoomPower)) : 1 << zoomPower;
    CGContextSaveGState(context);
    switch(partSpecialness) {
      case ECPartNotSpecial:
	assert(false);
	break;
      case ECPartSpecialWorldtimeRing:
	{
	    // printf("Drawing worldtime ring, zoomPower %d, zoomFactor %g\n", zoomPower, zoomFactor);

	    // Set up the font once for the entire part
	    CGFontRef cgfont = CGFontCreateWithFontName ((CFStringRef)@"Arial");
	    double nominalFontSize = 10;
	    int unitsPerEm = CGFontGetUnitsPerEm(cgfont);
	    double pixelsPerEm = nominalFontSize * zoomFactor;  // aka actual font size
	    double unitsPerPixel = unitsPerEm / pixelsPerEm;
	    CGContextSetFont(context, cgfont);
	    CGContextSetFontSize(context, pixelsPerEm);
	    CGContextSetStrokeColorWithColor(context, [[UIColor blackColor] CGColor]);

	    double cityRad2 = 142.5 * zoomFactor;
	    double cityRad1 = 129 * zoomFactor;
	    double channelRad1 = 111.5 * zoomFactor;
	    double channelRad2 = 126 * zoomFactor;
	    if (zoomPower != 0) {
		CGContextSetLineWidth(context, zoomFactor);
	    }
	    CGContextTranslateCTM(context, (right + left)/2, (top + bottom)/2);
	    for (int i = 0; i < 24; i += 2) {
		drawRingTextAndPossiblyChannelForSlot(context, watch, i, i + envSlot, cityRad1, channelRad1, cgfont, unitsPerPixel);
	    }
	    for (int i = 1; i < 24; i += 2) {
		drawRingTextAndPossiblyChannelForSlot(context, watch, i, i + envSlot, cityRad2, channelRad2, cgfont, unitsPerPixel);
	    }
	    CGFontRelease(cgfont);
	}
	break;
      case ECPartSpecialSubdial:
	{
	    CGFontRef cgfont = CGFontCreateWithFontName ((CFStringRef)@"Verdana");
	    double nominalFontSize = 12;
	    int unitsPerEm = CGFontGetUnitsPerEm(cgfont);
	    double pixelsPerEm = nominalFontSize * zoomFactor;  // aka actual font size
	    double unitsPerPixel = unitsPerEm / pixelsPerEm;
	    CGContextSetFont(context, cgfont);
	    CGContextSetFontSize(context, pixelsPerEm);
	    CGContextSetStrokeColorWithColor(context, [[UIColor blackColor] CGColor]);

	    CGFloat nominalBoundsWidth = (right-left) / zoomFactor;
	    //printf("Drawing subdial ring %d, envSlot %d, zoomPower %d, zoomFactor %g, nominalBoundsWidth %g\n", specialParameter, envSlot, zoomPower, zoomFactor, nominalBoundsWidth);
	    double textRadius;
	    double numberRadius;
	    double numberFontSize;
	    if (nominalBoundsWidth > 133) {  // Must be big subdial
		textRadius = 84 * zoomFactor;  // 58+3+12+7.5 = 80.5
		numberRadius = 72 * zoomFactor;
		numberFontSize = 9 * zoomFactor;
	    } else {  // must be small subdial
		textRadius = 58 * zoomFactor;  // 32 + 3 + 12 + 7.5 = 54.5
		numberRadius = 46 * zoomFactor;
		numberFontSize = 8 * zoomFactor;
	    }
	    CGContextTranslateCTM(context, (right + left)/2, (top + bottom)/2);
	    ECWatchEnvironment *env = [watch enviroWithIndex:envSlot];
	    NSString *cityName = env.cityName;
	    double leftAngularLimit = M_PI / 2;  // We can do better than this, but just to start...
	    double rightAngularLimit = M_PI / 2;
	    double totalTextAngle = drawCircularText(context, cityName, M_PI, textRadius, leftAngularLimit, rightAngularLimit, ECDialOrientationDemiRadial, cgfont, 1.0/*pixelSpacing*/, unitsPerPixel);
	    totalTextAngle += 10 / textRadius;
	    CGFontRelease(cgfont);

	    cgfont = CGFontCreateWithFontName ((CFStringRef)@"Arial");
	    CGContextSetFont(context, cgfont);
	    pixelsPerEm = numberFontSize;
	    unitsPerPixel = unitsPerEm / pixelsPerEm;
	    CGContextSetFontSize(context, pixelsPerEm);

	    for (int i = 1; i < 24; i ++) {
		switch (specialParameter) {
		  case 0:
		    if (i == 15 || i == 16) {
			continue;
		    }
		    break;
		  case 1:
		    break;
		  case 2:
		    if (i >= 9 && i <= 11) {
			continue;
		    }
		    break;
		  case 3:
		    if (i >= 8 && i <= 10 || i >= 13 && i <= 15) {
			continue;
		    }
		    break;
		  default:
		    assert(false);
		    break;
		}
		double pointAngle = M_PI * (18 - i) / 12;
		double angularDistanceFromBottom = M_PI * (i < 12 ? i : (24 - i)) / 12;
		if (angularDistanceFromBottom <= totalTextAngle/2) {
		    continue;
		}
		CGFloat x = numberRadius * cos(pointAngle);
		CGFloat y = numberRadius * sin(pointAngle);
		CGFloat width = 0.5;
		CGFloat halfWidth = width / 2;
		if (i % 2) {
		    CGContextSetAlpha(context, 0.5);
		    CGContextFillEllipseInRect(context, CGRectMake(x-halfWidth, y-halfWidth, width, width));
		    CGContextStrokeEllipseInRect(context, CGRectMake(x-halfWidth, y-halfWidth, width, width));
		    CGContextSetAlpha(context, 1);
		} else {
		    drawUprightText(context, [NSString stringWithFormat:@"%d", i], CGPointMake(x, y), cgfont, 0.5/*pixelSpacing*/, unitsPerPixel);
		}
	    }
	    CGFontRelease(cgfont);
	}
	break;
      case ECPartSpecialDotsMap:
	{
#define MAP_WIDTH_DEGREES  360.0
#define MAP_HEIGHT_DEGREES 180.0
	    CGContextTranslateCTM(context, (right + left)/2, (top + bottom)/2);
	    CGFloat mapWidthPixels = (right - left);
	    CGFloat mapHeightPixels = (top - bottom);
	    CGFloat xscale = mapWidthPixels / MAP_WIDTH_DEGREES;
	    CGFloat yscale = mapHeightPixels / MAP_HEIGHT_DEGREES;
	    double dotRadius = 1.5 * zoomFactor / xscale;
	    CGContextScaleCTM(context, xscale, -yscale);	// now (x,y) is scaled to maps's (longitude,latitude)
	    CGContextSetFillColorWithColor(context, [[UIColor blueColor] CGColor]);
	    for (int i = watch.maxSeparateLoc + 1; i < watch.numEnvironments; i++) {
		ECWatchEnvironment *env = [watch enviroWithIndex:i];
		double x, y;
		forwardRobinson(env.latitude, env.longitude, &x, &y);
		CGContextAddArc(context, x, y, dotRadius, 0, M_PI*2, 1);
		CGContextFillPath(context);
	    }
	}
	break;
      default:
	assert(false);
	break;
    }
    CGContextRestoreGState(context);
}

-(void)addingAnimationForValue {
    // This one's easy
    animating = 1;
}

-(void)removingAnimationForValue {
    // Maybe some other value is still animating
    animating = angle.animating || xOffset.animating || yOffset.animating || offsetAngle.animating;
}

static bool
animateThisPartWhenDraggingPartWithType(ECDragAnimationType thisPartDragAnimationType,
					ECDragType          draggingPartDragType) {
    if (draggingPartDragType == ECDragNotDragging) {
	return true;
    }
    switch(thisPartDragAnimationType) {
      case ECDragAnimationNever:
	return false;
      case ECDragAnimationAlways:
	return true;
      case ECDragAnimationHack1:
	return true;
      case ECDragAnimationHack2:
	return draggingPartDragType == ECDragHack1;
    }
    assert(false);
    return false;
}

// Note 2011-08-13 Steve: There are two "atTime"s of interest here.  For the purpose of evaluating
// part instructions, we need to use the watch time, which has been latched to the appropriate multiple
// of the beat frequency.  For the purposes of animation, though, we want to use the unlatched time as
// we don't want the animation to jump at the beat frequency.  Further, we want to use a common time for
// all watches that are being animated, particularly in the grid-mode zoom handled outside of this method.
// The "currentTime" passed in here is that common time (in NTP terms), the time reference for all watches
// and parts being updated.  The latched beat-snapped time is available in [watch currentTime].
// Calculating the next update is a bit tricky.  We want to calculate the absolute time of the next update
// based on the snapped beat time (there's no point in redoing that snapped time, for example, even if we
// haven't actually gotten to that true time yet; go on to the next time).  But we want to subtract that
// desired time from the currentTime, not the current snapped time.

// This returns the amount of time before the next requested update, relative to the (iPhone time) atTime passed in.
- (NSTimeInterval)prepareForDrawForModeNum:(ECWatchModeEnum)modeNum
				    atTime:(NSTimeInterval)currentTime
                          snappedWatchTime:(NSTimeInterval)snappedWatchTime
			     forcingUpdate:(bool)forceUpdate
			    allowAnimation:(bool)allowAnimation
		      draggingPartDragType:(ECDragType)draggingPartDragType {
    if (isSlave) {
	return ECFarInTheFuture;   // slave parts never need to update
    }
    bool allowAnimationForThisPart = allowAnimation && animateThisPartWhenDraggingPartWithType(dragAnimationType, draggingPartDragType);
    //printf("prepareForDrawForModeNum dragAnimationType %d draggingPartDragType %d allowAnimation %s\n", dragAnimationType, draggingPartDragType, allowAnimationForThisPart ? "true" : "false");
    if (currentTime > nextUpdateTime || forceUpdate) {
	[self updateDisplayListsAtTime:currentTime forModeNum:modeNum evaluateExpressions:true animate:allowAnimationForThisPart masterAngle:0 masterOffsetAngle:0 draggingPartDragType:draggingPartDragType];
        // nextUpdateTime is an iPhone time
	nextUpdateTime = [ECDynamicUpdate getNextUpdateTimeForInterval:updateInterval
							     andOffset:updateIntervalOffset
                                                            startingAt:currentTime
							forEnvironment:[watch enviroWithIndex:envSlot]
							     watchTime:[watch timerWithIndex:updateTimer]];
#if 0
        if ([[watch name] compare:@"Terra"] == NSOrderedSame) {
            printf("Part next update time:");
            printADate(currentTime);
            printf(" (currentTime), ");
            printADate(snappedWatchTime);
            printf(" (snappedWatchTime),  => ");
            printADate(nextUpdateTime);
            printf(" via updateInterval %.4f and offset %.4f\n", updateInterval, updateIntervalOffset);
            fflush(stdout);
        }
#endif
    } else if (animating) {
	// update without evaluation
	[self updateDisplayListsAtTime:currentTime forModeNum:modeNum evaluateExpressions:false animate:allowAnimationForThisPart masterAngle:0 masterOffsetAngle:0 draggingPartDragType:draggingPartDragType];
#if 0
	printf("Animation Part next update time:");
	printADate(currentTime);
	printf(" => ");
	printADate(nextUpdateTime);
	printf("\n");
        fflush(stdout);
#endif
    }
    if (animating) {
	return -1;
    }
    return nextUpdateTime - currentTime;
}

- (void)print {
    printf("\n\n  *** PART ***\n");
    for (int i = 0; i < ECNumWatchDrawModes; i++) {
	printf("%s texture atlas at slot index %d: ", ECmodeNames[i], textureDataByMode[i].textureAtlasSlotIndex);
    }
    printf("  boundsOnScreen x=%g y=%g w=%g h=%g\n", boundsOnScreen.origin.x, boundsOnScreen.origin.y, boundsOnScreen.size.width, boundsOnScreen.size.height);
    printf("  anchorOnScreen x=%g y=%g\n", anchorOnScreen.x, anchorOnScreen.y);
    printf("  updateInterval %g\n", updateInterval);
    printf("  updateIntervalOffset %g\n", updateIntervalOffset);
    printf("  nextUpdateTime %s\n", [[[NSDate dateWithTimeIntervalSinceReferenceDate:nextUpdateTime] description] UTF8String]);
    printf("  animating %s\n", animating ? "true" : "false");
    printf("  actionInstructionStream:\n");
    [actionInstructionStream printToOutputFile:stdout withIndentLevel:2 fromVirtualMachine:vm];
    printf("  modeMask 0x%08x\n", modeMask);
    printf("  handKind %d\n", handKind);
    printf("  angleInstructionStream (%s):\n", [formatAngleValue(&angle, vm) UTF8String]);
    [angle.instructionStream printToOutputFile:stdout withIndentLevel:2 fromVirtualMachine:vm];
    printf("  xOffsetInstructionStream (%s):\n", [formatLinearValue(&xOffset, vm) UTF8String]);
    [xOffset.instructionStream printToOutputFile:stdout withIndentLevel:2 fromVirtualMachine:vm];
    printf("  yOffsetInstructionStream (%s):\n", [formatLinearValue(&yOffset, vm) UTF8String]);
    [yOffset.instructionStream printToOutputFile:stdout withIndentLevel:2 fromVirtualMachine:vm];
    printf("  offsetRadius %g:\n", offsetRadius);
    printf("  offsetAngleInstructionStream (%s):\n", [formatAngleValue(&offsetAngle, vm) UTF8String]);
    [offsetAngle.instructionStream printToOutputFile:stdout withIndentLevel:2 fromVirtualMachine:vm];
}

@end
