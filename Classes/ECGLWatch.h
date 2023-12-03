//
//  ECGLWatch.h
//  Emerald Chronometer
//
//  Created by Steve Pucci in Aug 2008
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#include "Constants.h"
#include "ESCalendar.h"
#include "TSTime.h"

@class EBVirtualMachine, ECWatchTime, ECWatchEnvironment, ECAstronomyManager, ECGLDisplayList, ECAlarmTime, ECGLTextureAtlas, ECGLDisplayListWithTextureVertices;

@interface ECGLWatch : NSObject<TSTimeAdjustmentObserver> {
@private
    NSMutableArray   *partGroupsByTextureMode[ECNumWatchDrawModes];
    NSMutableArray   *partBases;
    NSMutableDictionary **spareParts;
    NSMutableArray   *displayListsByMode[ECNumWatchDrawModes];
    ECGLDisplayListWithTextureVertices *loadingDisplayListsByMode[ECNumWatchDrawModes];
    ECGLTextureAtlas **textures;
    int              numTextures;
    EBVirtualMachine *vm;
    NSString         *name;
    NSString         *displayName;
    ECWatchEnvironment **environments;
    int              numEnvironments;  // Number of environment slots
    int              maxSeparateLoc;   // Highest env slot with a separate location manager; rest share mainEnv's location manager, but can have a separate timezone
    double           landscapeZoomFactor; // In single-watch (nongrid) view, amount by which we scale this watch relative to other watches
    ECWatchTime      **timers;
    ECWatchTime      *mainTime;   // Cache main time here to avoid asking env about it
    ECAstronomyManager *mainAstro; // Ditto for astro mgr
    ECWatchEnvironment *mainEnv;   // Ditto for env as a whole
    int              lastMainTimeEnv;  // The slot most recently used to set the calendar & timezone for mainTime
    ECWatchModeMask  definedModes;
    ECWatchModeEnum  currentModeNum;
    int              textureLoadRequiredMasksByZoom[ECNumVisualZoomFactors];
    int              activeIndex;     // if not active, is the active index after this one
    int              availableIndex;  
    int              canonicalIndex;
    NSTimeInterval   beatsPerSecond;

    CGPoint          drawCenter;
    double           zoom;
    CGPoint          targetDrawCenter;
    double           targetZoom;
    CGPoint          anchor;         // the point which doesn't change during this animation
    NSTimeInterval   lastPositionZoomAnimationTime;
    NSTimeInterval   animationPositionZoomStopTime;
    CGPoint          startDrawCenter;
    double           startZoom;
    NSTimeInterval   animationPositionZoomStartTime;

    bool             animatingPositionZoom;

    NSTimeInterval   lastFlipAnimationTime;
    NSTimeInterval   animationFlipStopTime;
    ECAlarmTime      *alarmTime; // Do we need more than one of these for multiple alarms?
    bool             hasStopwatch;
    bool             alarmEnabled;  // Do we need more than one of these for multiple alarms?
    bool             active;
    bool             animatingFlip; // front to back or vice versa
    bool             visible;
    bool             isBackground;
    bool             loaded;
    int		     topSector;
    bool dragging;	     // true while a hand is being dragged
    bool alarmManualSet;     // is the alarm stem pulled out enabling manual setting of the alarm hands
}

@property (readonly, nonatomic, retain) EBVirtualMachine *vm;
@property(nonatomic) bool visible, active, alarmEnabled, alarmManualSet;
@property(nonatomic) int activeIndex, availableIndex, canonicalIndex, topSector;
@property(nonatomic) double zoom, landscapeZoomFactor;
@property(nonatomic) NSTimeInterval beatsPerSecond;
@property(nonatomic, readonly) bool manualSet;
@property(nonatomic, readonly) bool isBackground;
@property(nonatomic, readonly) bool loaded;
@property(nonatomic, readonly) ECWatchModeEnum currentModeNum;
@property(nonatomic, readonly) ECWatchModeMask definedModes;
@property (readonly, nonatomic) bool runningBackward, dragging, flipping;
@property (readonly, nonatomic) NSString *name, *helpword;
@property (nonatomic, retain) NSString *displayName;
@property (nonatomic, readonly) CGPoint drawCenter;
@property (nonatomic, readonly) ECWatchTime *mainTime;
@property (nonatomic, readonly) ECAstronomyManager *mainAstro;
@property (nonatomic, readonly) ECWatchEnvironment *mainEnv;
@property (nonatomic, readonly) int numEnvironments, maxSeparateLoc;

+ (ECGLWatch *)globalWatch;
- (id)initWithName:(NSString *)name;
- (void)loadFromArchive;
- (void)setCurrentModeNum:(ECWatchModeEnum)mode zoomPower2:(int)z2 allowAnimation:(bool)allowAnimation;
- (ECWatchModeEnum)finalCurrentModeNum;
- (void)setPosition:(CGPoint)pos
               zoom:(float)newZoom 
 animationStartTime:(NSTimeInterval)animationStartTime
  animationInterval:(NSTimeInterval)animationInterval;
+ (NSTimeInterval)updateDeviceRotationForTime:(NSTimeInterval)currentTime;
- (NSTimeInterval)updatePositionZoomForTime:(NSTimeInterval)currentTime;
- (NSTimeInterval)drawForCurrentModeAtTime:(NSTimeInterval)redrawTime
				zoomPower2:(int)z2
				gridPower2:(int)gridZ2
				 zoomingIn:(bool)zoomingIn
			    asCurrentWatch:(bool)asCurrentWatch
			     forcingUpdate:(bool)forceUpdate
			     allowAnimation:(bool)allowAnimation
				  dragType:(ECDragType)dragType;
- (NSTimeInterval)drawForModeNum:(ECWatchModeEnum)mode
		   andZoomPower2:(int)z2
		      gridPower2:(int)gridZ2
			  atTime:(NSTimeInterval)redrawTime
		       zoomingIn:(bool)zoomingIn
		  asCurrentWatch:(bool)asCurrentWatch
		   forcingUpdate:(bool)forceUpdate
		  allowAnimation:(bool)allowAnimation
			dragType:(ECDragType)dragType;
- (NSTimeInterval)prepareAllPartsForDrawForModeNum:(ECWatchModeEnum)modeNum
					    atTime:(NSTimeInterval)currentTime
				     forcingUpdate:(bool)forceUpdate
				    allowAnimation:(bool)allowAnimation
					  dragType:(ECDragType)dragType;
- (NSTimeInterval)nextDSTTransition;
- (void)print;
- (void)printDisplayListForModeNum:(ECWatchModeEnum)mode;
- (void)printDisplayListForCurrentMode;
- (int)numPartBases;  // debug
- (void)displayListMemoryUsage:(size_t *)displayListSize numDisplayLists:(int *)numDisplayLists numDisplayListParts:(int *)numDisplayListParts;
- (void)unloadAllTextures;
- (ECWatchTime *)alarmTimer;     // either owned by watch, or autorelease object not owned by watch
- (ECWatchTime *)intervalTimer;  // autorelease object not owned by watch
- (ECWatchTime *)timerWithIndex:(unsigned int)timerNumber;
- (ECWatchEnvironment *)enviroWithIndex:(unsigned int)timerNumber;
- (ECAstronomyManager *)astroWithIndex:(unsigned int)timerNumber;
- (void)updateAllPartsForModeNum:(ECWatchModeEnum)modeNum animating:(bool)animate;  // Useful only for background watch (I think)
- (void)updateAllPartsForCurrentModeAnimating:(bool)animate;
- (bool)loadArchiveIfRequiredTestOnly:(bool)testOnly;
- (bool)loadTextureIfRequiredForModeNum:(ECWatchModeEnum)modeNum zoomPower2:(int)z2 testOnly:(bool)testOnly needsBytes:(size_t *)needsBytes;
- (size_t)markTextureUnloadedForModeNum:(ECWatchModeEnum)modeNum zoomPower2:(int)z2 needUnattach:(bool *)needUnattach;
- (void)doPendingUnattaches;
- (void)setInactive;
- (int)isActive;
- (bool)alarming;
- (ECAlarmTimeMode)alarmMode;
- (NSArray *)partBases;
- (int)nextActiveIndexIncludingThisOne;
- (void)setTimeZone:(ESTimeZone *)estz;
- (void)rotateRing:(int)delta;
- (bool)hasCityAtLatitude:(double)lat longitude:(double)lng;
+ (void)setRotation:(CGFloat)rotationDegrees animationStartTime:(NSTimeInterval)animationStartTime animationInterval:(NSTimeInterval)animationInterval;

//// input event callback methods
- (void)handleTouchMoveWithDeltaX:(CGFloat)dx forAdjacentIndex:(int)adjacentIndex;
- (void)handle2DTouchMoveTo:(CGPoint)pt;
- (void)handleTouchReleaseWithoutSwipeForAdjacentIndex:(int)adjacentIndex;
- (void)handleTouchReleaseWithoutSwipeToDrawCenter:(CGPoint)drawCenter animationStartTime:(NSTimeInterval)animationStartTime;
- (void)snapToPosition:(int)newPosition atZoom:(double)atZoom;
- (void)scrollIntoPosition:(int)newPosition atZoom:(double)newZoom animationStartTime:(NSTimeInterval)animationStartTime animationInterval:(NSTimeInterval)animationInterval;
- (void)scrollToDrawCenter:(CGPoint)drawCenter animationStartTime:(NSTimeInterval)animationStartTime atZoom:(double)aZoom animationInterval:(NSTimeInterval)animationInterval;

//// button op methods
- (void)stemIn;
- (void)stemOut;
- (void)alarmStemIn;
- (void)alarmStemOut;
- (void)setRunningBackward:(bool)runningBackward;  // set by watch's mechanical switch
- (void)resetTime;
- (double)alarmCount;
- (void)enableAlarm;
- (void)disableAlarm;
- (bool)stopAlarmRinging;
- (void)startIntervalTimer;
- (void)stopIntervalTimer;
- (void)toggleIntervalTimer;
- (void)advanceAlarmHour;
- (void)advanceAlarmMinute;
- (void)toggleAlarmAMPM;
- (void)advanceIntervalHour;
- (void)advanceIntervalMinute;
- (void)advanceIntervalSecond;
- (void)setAlarmToTarget;
- (void)setAlarmToInterval;
- (void)stopwatchStartStopWithRounding:(double)rounding;
- (void)stopwatchReset;
- (void)stopwatchRattrapanteWithRounding:(double)rounding;
- (void)updateDefaultsForCurrentStopwatchState;

-(double)currentMainTime;
-(double)getValueFromMainTime:(SEL)watchTimeSelector;
-(int)getIntValueFromMainTime:(SEL)watchTimeSelector;
-(bool)getBoolValueFromMainTime:(SEL)watchTimeSelector;
-(double)getValueFromAlarmTime:(SEL)watchTimeSelector;
-(int)getIntValueFromAlarmTime:(SEL)watchTimeSelector;
-(double)getValueFromTimeForEnv:(int)envNumber watchTimeSelector:(SEL)watchTimeSelector;
-(int)getIntValueFromTimeForEnv:(int)envNumber watchTimeSelector:(SEL)watchTimeSelector;
-(bool)getBoolValueFromTimeForEnv:(int)envNumber watchTimeSelector:(SEL)watchTimeSelector;
-(double)getValueFromMainAstroWatchTime:(SEL)astroSelector watchTimeSelector:(SEL)watchTimeSelector;
-(int)getIntValueFromMainAstroWatchTime:(SEL)astroSelector watchTimeSelector:(SEL)watchTimeSelector;
-(double)getValueFromMainAstroWatchTime:(SEL)astroSelector planetNumber:(int)planetNumber watchTimeSelector:(SEL)watchTimeSelector;
-(int)getIntValueFromMainAstroWatchTime:(SEL)astroSelector planetNumber:(int)planetNumber watchTimeSelector:(SEL)watchTimeSelector;
-(int)getDayOffsetValueFromMainAstroWatchTime:(SEL)astroSelector;  // return number of days from main watchTime to given astro watch time
-(double)getValueFromAstroWatchTimeForEnv:(int)envNumber astroSelector:(SEL)astroSelector watchTimeSelector:(SEL)watchTimeSelector;
-(int)getIntValueFromAstroWatchTimeForEnv:(int)envNumber astroSelector:(SEL)astroSelector watchTimeSelector:(SEL)watchTimeSelector;
-(int)getDayOffsetValueFromAstroWatchTimeForEnv:(int)envNumber astroSelector:(SEL)astroSelector;  // return number of days from main watchTime to given astro watch time
-(int)offsetDaysFromMainForEnv:(int)envNumber;
-(int)offsetDaysFrom:(int)envNumber forEnv:(int)envNumber;
-(void)advanceMainTimeUsingEnvSelector:(SEL)watchTimeSelector;
-(void)advanceMainTimeUsingEnvSelector:(SEL)watchTimeSelector withIntParameter:(int)parameter;
-(void)advanceMainTimeUsingSelector:(SEL)watchTimeSelector withDoubleParameter:(double)parameter;
-(void)advanceTimeForEnvUsingEnvSelector:(SEL)watchTimeSelector forEnv:(int)envNumber;
-(void)setMainTimeToFrozenDateInterval:(NSTimeInterval)dateInterval;
-(ESTimeZone *)estzForEnv:(int)envNumber;
-(ESTimeZone *)mainEstz;
-(double)rotationForCalendarWheel012BDesignedForWeekdayStart:(int)wheelWeekdayStart;
-(double)rotationForCalendarWheel3456DesignedForWeekdayStart:(int)wheelWeekdayStart;
-(double)rotationForCalendarWheelOct1582DesignedForWeekdayStart:(int)wheelWeekdayStart;
-(int)calendarColumn;
-(int)calendarRow;
-(double)calendarRowCoverOffsetForType:(ECCalendarRowCoverType)coverType overallWidth:(CGFloat)overallWidth cellWidth:(CGFloat)cellWidth spacingWidth:(CGFloat)spacingWidth;
-(double)calendarRowUnderlayOffsetForType:(ECCalendarRowCoverType)coverType overallWidth:(CGFloat)overallWidth cellWidth:(CGFloat)cellWidth spacingWidth:(CGFloat)spacingWidth;
-(int)mainTimeWeekOfYearNumber;
-(int)weekOfYearNumberForEnv:(int)envNumber;

- (ECWatchTime *)stopwatchTimer;
- (ECWatchTime *)stopwatchLapTimer;
- (ECWatchTime *)stopwatchDisplayTimer;

//// Alarm hand drag methods
- (void)setTargetOffset:(double)newOffset;
- (void)setIntervalOffset:(double)newOffset;
- (double)currentOffset;
- (double)specifiedOffset;
- (void)alarmReset;

//// debug
#ifndef NDEBUG
- (void)checkDisplayListsForMode:(ECWatchModeEnum)modeNum;
- (void)dumpVariableValues;
#endif

@end
