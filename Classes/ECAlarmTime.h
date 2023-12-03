//
//  ECAlarmTime.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 1/2009.
//  Copyright Emerald Sequoia LLC 2009. All rights reserved.
//

@class ECWatchTime;
@class ECWatchEnvironment;

#import "Constants.h"
#import "TSTime.h"

// *****************
// Alarm methods.  There are two flavors (see ECAlarmTimeMode):
// Interval mode specifes an arbitrary time between the current watch time of
// the watches' primary watch (that will be the receiver of these methods).
// Target mode specifies the time from local midnight on a 24-hour day, in *logical*
// seconds.  That means even on DST change days, a target of 6am is still represented
// as 6 * 60 * 60.  It is up to the methods below to change the logical seconds into
// an actual time.
// *****************

@interface ECAlarmTime : NSObject<TSTimeAdjustmentObserver> {
    // constant specified data
    ECWatchTime     *currentWatchTime;  // definition of "current time"
    ECWatchEnvironment *env;   // how to interpret currentWatchTime
    id              fireReceiver;
    SEL             fireSelector;
    id              fireUserInfo;

    // dynamic specified data
    ECAlarmTimeMode specifiedMode;   // ECAlarmTimeTarget, ECAlarmTimeInterval
    double          specifiedOffset; // If target: logical seconds from local midnight; if interval: original specified interval

    // derived data
    ECWatchTime     *alarmWatchTime;
    NSTimer         *osTimer;
    NSString        *localNotificationIdentifier;
}

@property(nonatomic, readonly) ECAlarmTimeMode specifiedMode;
@property(nonatomic, readonly) double specifiedOffset, effectiveOffset;
//@property(nonatomic, readonly) ECWatchTime *alarmWatchTime;

- (id)initWithFireReceiver:(id)receiver fireSelector:(SEL)fireSelector fireUserInfo:(id)fireUserInfo currentWatchTime:(ECWatchTime *)watchTime env:(ECWatchEnvironment *)env;
- (void)dealloc;

- (void)specifyTargetAlarmAt:(double)logicalSecondsFromLocalMidnight;
- (void)specifyIntervalAlarmAt:(double)intervalSeconds;

// Initialization from defaults methods
- (bool)defaultsStartTimerWithTargetTime:(double)targetTime;
- (void)defaultsSetCurrentInterval:(double)timerOffset;

- (void)startTimer;
- (void)stopTimer;
- (void)stopTimerIfInterval;
- (void)toggleTimer;
- (bool)setToFire;

- (bool)timerIsStopped;
- (NSTimeInterval)currentAlarmTime;    // In NTP time base

- (void)advanceAlarmHour;
- (void)advanceAlarmMinute;
- (void)toggleAlarmAMPM;

- (void)advanceIntervalHour;
- (void)advanceIntervalMinute;
- (void)advanceIntervalSecond;

- (void)recalculateAlarm;
- (void)recalculateIntervalTime;

- (void)setSpecifiedModeToTarget;
- (void)setSpecifiedModeToInterval;

- (void)handleTZChange;

+ (ECWatchTime *)defaultAlarmTimeForTime:(ECWatchTime *)currentTime usingEnv:(ECWatchEnvironment *)env;

@end
