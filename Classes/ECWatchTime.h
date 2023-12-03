//
//  ECWatchTime.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

typedef enum ECWatchTimeCycle {
    ECWatchCycleReverseFF6,
    ECWatchCycleFirst = ECWatchCycleReverseFF6,
    ECWatchCycleReverseFF5,
    ECWatchCycleReverseFF4,
    ECWatchCycleReverseFF3,
    ECWatchCycleReverseFF2,
    ECWatchCycleReverseFF1,
    ECWatchCycleReverse,
    ECWatchCycleReverseSlow1,
    ECWatchCycleSlow1,
    ECWatchCycleNormal,
    ECWatchCycleFF1,
    ECWatchCycleFF2,
    ECWatchCycleFF3,
    ECWatchCycleFF4,
    ECWatchCycleFF5,
    ECWatchCycleFF6,
    ECWatchCycleLastForward = ECWatchCycleFF6,
    ECWatchCyclePaused,
    ECWatchCycleOther,
    ECWatchCycleLast = ECWatchCycleOther,
    ECNumWatchCycles,
} ECWatchTimeCycle;

@class ECWatchEnvironment;

@interface ECWatchTime : NSObject {
@private
    // In a plot of our time (y) vs actual time (x), our time is y = mx + b

    // The factor by which we are running faster (or slower) than actual time (m)
    double  warp;

    // What our time would read when the actual NTP time (as we know it) was zero, extrapolated backwards (b)
    double  ourTimeAtNTPZero;

    // Internal use only:
    double       warpBeforeFreeze;
    ECWatchTimeCycle cycle;
    bool         useSmoothTime;
    int          latched;
    NSTimeInterval latchNTPTime;
}

@property (nonatomic) double warp;
@property (nonatomic, readonly) double ourTimeAtIPhoneZero, ourTimeAtNTPZero;
@property (nonatomic, readonly) bool frozen, isCorrect, lastMotionWasInReverse;

// Convention:  names which end with "Number" (e.g., dayNumber) are integer values,
//                 with specific definitions described below
//              names which end with "Value" (e.g., dayValue), are continuous double
//                 values, which are typically equal to the Number value immediately after
//                 the Number value changes.  That is, the Value value is always >= the Number value.

// Standard initializer
-(id)init;

// Initializer to represent an event time on a watch
-(id)initWithFrozenDate:(NSDate *)date;
-(id)initWithFrozenDateInterval:(NSTimeInterval)dateInterval;
-(bool)checkAndConstrainAbsoluteTime;

// When updating, we can presume all uses of watchTime can legitimately use the same currentTime,
// so latch it when starting the update for a watch and unlatch it when done
-(void)latchTimeForBeatsPerSecond:(int)beatsPerSecond;
-(void)unlatchTime;

// *****************
// Methods useful for watch hands and moving dials:
// *****************

// 12:35:45.9 => 45
-(int)secondNumberUsingEnv:(ECWatchEnvironment *)env;

// 12:35:45.9 => 45.9
-(double)secondValueUsingEnv:(ECWatchEnvironment *)env;

// 12:35:45 => 35
-(int)minuteNumberUsingEnv:(ECWatchEnvironment *)env;

// 12:35:45 => 35.75
-(double)minuteValueUsingEnv:(ECWatchEnvironment *)env;

// 13:45:00 => 1
-(int)hour12NumberUsingEnv:(ECWatchEnvironment *)env;

// 13:45:00 => 1.75
-(double)hour12ValueUsingEnv:(ECWatchEnvironment *)env;

// 13:45:00 => 13
-(int)hour24NumberUsingEnv:(ECWatchEnvironment *)env;

// 13:45:00 => 13.75
-(double)hour24ValueUsingEnv:(ECWatchEnvironment *)env;

// March 1 => 0  (n.b, not 1; useful for angles and for arrays of images, and consistent with double form below)
-(int)dayNumberUsingEnv:(ECWatchEnvironment *)env;

// March 1 at 6pm  =>  0.75;  useful for continuous hands displaying day
-(double)dayValueUsingEnv:(ECWatchEnvironment *)env;

// March 1 => 2  (n.b., not 3)
-(int)monthNumberUsingEnv:(ECWatchEnvironment *)env;

// March 1 at noon  =>  12 / (31 * 24);  useful for continuous hands displaying month
-(double)monthValueUsingEnv:(ECWatchEnvironment *)env;

// March 1 1999 => 1999
-(int)yearNumberUsingEnv:(ECWatchEnvironment *)env;

// BCE => 0; CE => 1
-(int)eraNumberUsingEnv:(ECWatchEnvironment *)env;

// Sunday => 0
-(int)weekdayNumberUsingEnv:(ECWatchEnvironment *)env;

// Tuesday at 6pm => 2.75
-(double)weekdayValueUsingEnv:(ECWatchEnvironment *)env;

// This function incorporates the value of ECCalendarWeekdayStart
-(int)weekdayNumberAsCalendarColumnUsingEnv:(ECWatchEnvironment *)env;

// Leap year: fraction of 366 days since Jan 1
// Non-leap year: fraction of 366 days since Jan 1 through Feb 28, then that plus 24hrs starting Mar 1
// Result is indicator value on 366-year dial
-(double)year366IndicatorFractionUsingEnv:(ECWatchEnvironment *)env;

// Jan 1 => 0    
-(int)dayOfYearNumberUsingEnv:(ECWatchEnvironment *)env;

// First week => 0    
-(int)weekOfYearNumberUsingEnv:(ECWatchEnvironment *)env
                    useISO8601:(bool)useISO8601   // use only when weekStartDay == 1 (Monday)
                  weekStartDay:(int)weekStartDay;  // weekStartDay == 0 means weeks start on Sunday

// daylight => 1; standard => 0
-(bool)isDSTUsingEnv:(ECWatchEnvironment *)env;

// leapYear
-(bool)leapYearUsingEnv:(ECWatchEnvironment *)env;

// The date for the next DST change in this watch
-(NSTimeInterval)nextDSTChangeUsingEnv:(ECWatchEnvironment *)env;

// The date for the prev DST change in this watch
-(NSTimeInterval)prevDSTChangePrecisely:(bool)precise usingEnv:(ECWatchEnvironment *)env;

-(int)secondsSinceMidnightNumberUsingEnv:(ECWatchEnvironment *)env;
-(double)secondsSinceMidnightValueUsingEnv:(ECWatchEnvironment *)env;

// *****************
// Stopwatch methods:  The y for a stopwatch watch is zero at reset
// *****************

// Set value to 0
-(void)stopwatchReset;

// Initialize and set value according to recorded defaults
-(void)stopwatchInitStoppedReading:(double)interval;
-(void)stopwatchInitRunningFromZeroTime:(double)zeroTime;

// Copy lap time
-(void)copyLapTimeFromOtherTimer:(ECWatchTime *)otherTimer;

// Clone time
-(void)makeTimeIdenticalToOtherTimer:(ECWatchTime *)otherTimer;

// Check for clone
-(bool)isIdenticalTo:(ECWatchTime *)otherTimer;

// 00:04:03.9 => 3
-(int)stopwatchSecondNumber;

// 00:04:03.9 => 3.9
-(double)stopwatchSecondValue;

// 01:04:45 => 4
-(int)stopwatchMinuteNumber;

// 01:04:45 => 4.75
-(double)stopwatchMinuteValue;

// 5d 01:30:00 => 1
-(int)stopwatchHour12Number;

// 5d 01:30:00 => 1.5
-(double)stopwatchHour12Value;

// 5d 01:30:00 => 1
-(int)stopwatchHour24Number;

// 5d 01:30:00 => 1.5
-(double)stopwatchHour24Value;

// 5d 18:00:00 => 5
-(int)stopwatchDayNumber;

// 5d 18:00:00 => 5.75
-(double)stopwatchDayValue;

// *****************
// Alarm methods
// *****************

// Clone time + interval
-(void)makeTimeIdenticalToOtherTimer:(ECWatchTime *)otherTimer plusDelta:(NSTimeInterval)delta;

-(double)offsetFromOtherTimer:(ECWatchTime *)otherTimer;

// *****************
// Get methods for internal use
// *****************

// return the current (warped) time
-(double)currentTime;

// return the current time ignoring any latch (useful for things like finding the next DST transition in the midst of a time motion)
-(double)currentTimeIgnoringLatch;

// return the current (warped) time
-(NSDate *)currentDate;

// Return the iPhone time corresponding to the given watch time
-(double)convertFromWatchToIPhone:(double)t;

// Return the watch time corresponding to the given iPhone time
-(double)convertFromIPhoneToWatch:(double)t;

// warp == 0
-(bool)isStopped;

// warp < 0
-(bool)runningBackward;

// LT - GMT in seconds
-(NSTimeInterval)tzOffsetUsingEnv:(ECWatchEnvironment *)env;

// 1d 4:00:00 (localized (not yet))
-(NSString *)representationOfDeltaOffsetUsingEnv:(ECWatchEnvironment *)env;

// 1 day/s
-(NSString *)representationOfWarp;

// Number of days between two times (if this is Wed and other's Thu, answer is -1)
-(int)numberOfDaysOffsetFrom:(ECWatchTime *)other usingEnv:(ECWatchEnvironment *)env;;
-(int)numberOfDaysOffsetFrom:(ECWatchTime *)other usingEnv1:(ECWatchEnvironment *)env1 env2:(ECWatchEnvironment *)env2;

// *****************
// Set methods
// *****************

// "Smooth time" clients don't care about absolute time, just about having a smooth time reference from app startup
-(void)setUseSmoothTime:(bool)useSmoothTime;

// Set the time/date directly
-(void)setCurrentDate:(NSDate *)date;
-(void)setCurrentDate:(NSDate *)date withWarp:(double)warp;

// Set the time to the given one, but freeze it there
-(void)setToFrozenDate:(NSDate *)date;
-(void)setToFrozenDateInterval:(NSTimeInterval)date;

// save/restore current state to userDefaults
- (void)saveStateForWatch:(NSString *)nam;
- (void)restoreStateForWatch:(NSString *)nam;

// Freeze at current time; does nothing if already frozen
-(void)stop;

// Unfreeze; does nothing if not frozen
-(void)start;

// Freeze or unfreeze
-(void)toggleStop;

// Reverse direction
-(void)reverse;

// Like toggleStop, but if stopping then round value to nearest rounding value if stopping
// (useful for stopwatches, so the restart time is exactly where it purports to be)
-(void)toggleStopWithRounding:(double)rounding;

// Reset to following actual iPhone time (subject to calendar installed)
-(void)resetToLocal;

// Change warp speed, recalculating internal data as necessary
-(void)setWarp:(double)newWarp;

// If pause, then resume from current position at normal speed (warp == 1); if not paused, then pause
-(void)pausePlay;

// Cycle through speeds
-(void)cycleFastForward;

// Cycle through speeds
-(void)cycleRewind;

// Advance to next point (context sensitive)
-(void)advanceToNextUsingEnv:(ECWatchEnvironment *)env;

// Advance to previous point (context sensitive)
-(void)advanceToPreviousUsingEnv:(ECWatchEnvironment *)env;

// Specific advance next/prev methods
-(void)advanceToNextInterval:(NSTimeInterval)interval usingEnv:(ECWatchEnvironment *)env;
-(void)advanceToPrevInterval:(NSTimeInterval)interval usingEnv:(ECWatchEnvironment *)env;
-(void)advanceToNextMonthUsingEnv:(ECWatchEnvironment *)env;
-(void)advanceToPrevMonthUsingEnv:(ECWatchEnvironment *)env;
-(void)advanceToNextYearUsingEnv:(ECWatchEnvironment *)env;
-(void)advanceToPrevYearUsingEnv:(ECWatchEnvironment *)env;

// Advance by exactly this amount
-(void)advanceBySeconds:(double)numSeconds fromTime:(NSTimeInterval)startTime;
-(void)advanceBySeconds:(double)numSeconds;
-(void)advanceByDays:(int)numDays fromTime:(NSTimeInterval)startTime usingEnv:(ECWatchEnvironment *)env; // works on DST days
-(void)advanceByDays:(int)numDays usingEnv:(ECWatchEnvironment *)env; // works on DST days
-(void)advanceOneDayUsingEnv:(ECWatchEnvironment *)env;
-(void)advanceByMonths:(int)numMonths fromTime:(NSTimeInterval)startTime usingEnv:(ECWatchEnvironment *)env;  // keeping day the same, unless there's no such day, in which case go to last day of month
-(void)advanceByMonths:(int)numMonths usingEnv:(ECWatchEnvironment *)env;  // keeping day the same, unless there's no such day, in which case go to last day of month
-(void)advanceOneMonthUsingEnv:(ECWatchEnvironment *)env;
-(void)advanceByYears:(int)numYears fromTime:(NSTimeInterval)startTime usingEnv:(ECWatchEnvironment *)env;   // keeping month and day the same, unless it was Feb 29, in which case move back to Feb 28
-(void)advanceByYears:(int)numYears usingEnv:(ECWatchEnvironment *)env;   // keeping month and day the same, unless it was Feb 29, in which case move back to Feb 28
-(void)advanceOneYearUsingEnv:(ECWatchEnvironment *)env;
-(void)retardOneDayUsingEnv:(ECWatchEnvironment *)env; // works on DST days
-(void)retardOneMonthUsingEnv:(ECWatchEnvironment *)env;
-(void)retardOneYearUsingEnv:(ECWatchEnvironment *)env;
-(void)advanceToQuarterHourUsingEnv:(ECWatchEnvironment *)env;
-(void)retreatToQuarterHourUsingEnv:(ECWatchEnvironment *)env;

// *****************
// Debug methods
// *****************
// Note: The following routine adds one to the returned month and day, for readability
-(NSString *)dumpAllUsingEnv:(ECWatchEnvironment *)env;

@end
