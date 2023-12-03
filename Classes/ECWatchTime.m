//
//  ECWatchTime.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "ECWatchTime.h"
#import "ECGlobals.h"
#import "ChronometerAppDelegate.h"  // For forceUpdateInMainThread
#import "ECErrorReporter.h"
#import "ECAstronomy.h"  // for secondsFromGMTForDate
#undef ECTRACE
#import "ECTrace.h"
#import "ECAppLog.h"
#import "ECWatchEnvironment.h"
#import "TSTime.h"
#include "ESCalendar.h"

#define kECWatchTimeAdvanceGap (2.0)  // Number of seconds prior to the advance "next" target that we stop

static double *warpValuesForCycle = NULL;
static ECWatchTimeCycle *nextCycleForFF = NULL;
static ECWatchTimeCycle *nextCycleForRewind = NULL;

static void
initializeWarpValues() {
    if (!warpValuesForCycle) {
	warpValuesForCycle = (double *)malloc(sizeof(double) * ECNumWatchCycles);
	nextCycleForFF = (ECWatchTimeCycle *)malloc(sizeof(ECWatchTimeCycle) * ECNumWatchCycles);
	nextCycleForRewind = (ECWatchTimeCycle *)malloc(sizeof(ECWatchTimeCycle) * ECNumWatchCycles);
    }
    
    // The value to use for warp when cycling to this state
    warpValuesForCycle[ECWatchCycleReverseFF6]   = - 5 * 24 * 3600;
    warpValuesForCycle[ECWatchCycleReverseFF5] 	 = - 24 * 3600;
    warpValuesForCycle[ECWatchCycleReverseFF4] 	 = -  5 * 3600;
    warpValuesForCycle[ECWatchCycleReverseFF3] 	 = - 3600;
    warpValuesForCycle[ECWatchCycleReverseFF2] 	 = - 60;
    warpValuesForCycle[ECWatchCycleReverseFF1] 	 = - 5;
    warpValuesForCycle[ECWatchCycleReverse]      = - 1;
    warpValuesForCycle[ECWatchCycleReverseSlow1] = - .25;
    warpValuesForCycle[ECWatchCycleSlow1]        =   .25;
    warpValuesForCycle[ECWatchCycleNormal]       =   1;
    warpValuesForCycle[ECWatchCycleFF1]       =   5;
    warpValuesForCycle[ECWatchCycleFF2]       =   60;
    warpValuesForCycle[ECWatchCycleFF3]       =   3600;
    warpValuesForCycle[ECWatchCycleFF4]       =   5 * 3600;
    warpValuesForCycle[ECWatchCycleFF5]       =  24 * 3600;
    warpValuesForCycle[ECWatchCycleFF6]       =   5 * 24 * 3600;
    warpValuesForCycle[ECWatchCyclePaused]    =   0;
    warpValuesForCycle[ECWatchCycleOther]     =   1;  // Should never be used

    nextCycleForFF[ECWatchCycleReverseFF6]   = ECWatchCycleReverseFF5;
    nextCycleForFF[ECWatchCycleReverseFF5]   = ECWatchCycleReverseFF4;
    nextCycleForFF[ECWatchCycleReverseFF4]   = ECWatchCycleReverseFF3;
    nextCycleForFF[ECWatchCycleReverseFF3]   = ECWatchCycleReverseFF2;
    nextCycleForFF[ECWatchCycleReverseFF2]   = ECWatchCycleReverseFF1;
    nextCycleForFF[ECWatchCycleReverseFF1]   = ECWatchCycleReverse;
    nextCycleForFF[ECWatchCycleReverse]      = ECWatchCycleReverseSlow1;
    nextCycleForFF[ECWatchCycleReverseSlow1] = ECWatchCycleSlow1;
    nextCycleForFF[ECWatchCycleSlow1]        = ECWatchCycleNormal;
    nextCycleForFF[ECWatchCycleNormal]       = ECWatchCycleFF1;
    nextCycleForFF[ECWatchCycleFF1]          = ECWatchCycleFF2;
    nextCycleForFF[ECWatchCycleFF2]          = ECWatchCycleFF3;
    nextCycleForFF[ECWatchCycleFF3]          = ECWatchCycleFF4;
    nextCycleForFF[ECWatchCycleFF4]          = ECWatchCycleFF5;
    nextCycleForFF[ECWatchCycleFF5]          = ECWatchCycleFF6;
    nextCycleForFF[ECWatchCycleFF6]          = ECWatchCycleNormal;  // cycle around, but only positive speeds
    nextCycleForFF[ECWatchCyclePaused]       = ECWatchCycleNormal;
    nextCycleForFF[ECWatchCycleOther]        = ECWatchCycleNormal;

    nextCycleForRewind[ECWatchCycleReverseFF6]   = ECWatchCycleReverse;  // cycle around, but only negative or slow speeds
    nextCycleForRewind[ECWatchCycleReverseFF5]   = ECWatchCycleReverseFF6;
    nextCycleForRewind[ECWatchCycleReverseFF4]   = ECWatchCycleReverseFF5;
    nextCycleForRewind[ECWatchCycleReverseFF3]   = ECWatchCycleReverseFF4;
    nextCycleForRewind[ECWatchCycleReverseFF2]   = ECWatchCycleReverseFF3;
    nextCycleForRewind[ECWatchCycleReverseFF1]   = ECWatchCycleReverseFF2;
    nextCycleForRewind[ECWatchCycleReverse]      = ECWatchCycleReverseFF1;
    nextCycleForRewind[ECWatchCycleReverseSlow1] = ECWatchCycleReverse;
    nextCycleForRewind[ECWatchCycleSlow1]        = ECWatchCycleReverseSlow1;
    nextCycleForRewind[ECWatchCycleNormal]       = ECWatchCycleSlow1;
    nextCycleForRewind[ECWatchCycleFF1]          = ECWatchCycleNormal;
    nextCycleForRewind[ECWatchCycleFF2]          = ECWatchCycleFF1;
    nextCycleForRewind[ECWatchCycleFF3]          = ECWatchCycleFF2;
    nextCycleForRewind[ECWatchCycleFF4]          = ECWatchCycleFF3;
    nextCycleForRewind[ECWatchCycleFF5]          = ECWatchCycleFF4;
    nextCycleForRewind[ECWatchCycleFF6]          = ECWatchCycleFF5;
    nextCycleForRewind[ECWatchCyclePaused]       = ECWatchCycleReverseSlow1;
    nextCycleForRewind[ECWatchCycleOther]        = ECWatchCycleReverse;
}

@implementation ECWatchTime

@synthesize warp, ourTimeAtNTPZero;

#define calcEffectiveSkew(useSmoothTime) (useSmoothTime ? [TSTime dateROffset] : [TSTime skew])
#define calcOurTimeAtIPhoneZero(useSmoothTime) (ourTimeAtNTPZero + calcEffectiveSkew(useSmoothTime))

+(NSTimeInterval)correctedTime
{
    return [TSTime currentTime];
}

-(double)ourTimeAtIPhoneZero {
    if (warp) {
	return calcOurTimeAtIPhoneZero(useSmoothTime);
    } else {
	return ourTimeAtNTPZero;
    }
}

-(void)commonInit {
    if (!warpValuesForCycle) {
	initializeWarpValues();
    }
    warpBeforeFreeze = 0.0;
    useSmoothTime = false;
    latched = 0;
}

-(id)init
{
    [super init];
    warp = 1.0;
    ourTimeAtNTPZero = 0;
    cycle = ECWatchCycleNormal;
    [self commonInit];
    return self;
}

-(id)initWithFrozenDate:(NSDate *)date {
    [super init];
    warp = 0.0;
    cycle = ECWatchCyclePaused;
    ourTimeAtNTPZero = [date timeIntervalSinceReferenceDate];
    [self commonInit];
    return self;
}

-(id)initWithFrozenDateInterval:(NSTimeInterval)dateInterval {
    [super init];
    warp = 0.0;
    cycle = ECWatchCyclePaused;
    ourTimeAtNTPZero = dateInterval;
    [self commonInit];
    return self;
}

- (void)saveStateForWatch:(NSString *)nam {
#ifdef SAVEWATCHTIME
    // note that we save "warp-1" and add 1 back in in restoreStateForWatch so that
    //  when it's restored the very first time the uninitialized value of zero becomes 1 which is what we want
    [[NSUserDefaults standardUserDefaults] setDouble:warp-1 forKey:[nam stringByAppendingString:@"-warp"]];
    [[NSUserDefaults standardUserDefaults] setDouble:warpBeforeFreeze-1 forKey:[nam stringByAppendingString:@"-warpBeforeFreeze"]];
    [[NSUserDefaults standardUserDefaults] setDouble:ourTimeAtNTPZero forKey:[nam stringByAppendingString:@"-timeZero"]];
#endif
}

- (void)restoreStateForWatch:(NSString *)nam {
#ifdef SAVEWATCHTIME
    warp = [[NSUserDefaults standardUserDefaults] doubleForKey:[nam stringByAppendingString:@"-warp"]] + 1;
    warpBeforeFreeze = [[NSUserDefaults standardUserDefaults] doubleForKey:[nam stringByAppendingString:@"-warpBeforeFreeze"]] + 1;
    ourTimeAtNTPZero = [[NSUserDefaults standardUserDefaults] doubleForKey:[nam stringByAppendingString:@"-timeZero"]];
#else
#endif
}

-(void) dealloc
{
    [super dealloc];
}

static double lastMaxRangeMessageTime = 0;
static double lastMinRangeMessageTime = 0;

-(void)possiblyPutUpMessageBoxAboutMaxRange {
    double now = [NSDate timeIntervalSinceReferenceDate];
    if (now - lastMinRangeMessageTime > ECLastAstroDateWarningInterval) {
	NSString *minMessageText = NSLocalizedString(@"The earliest time supported is", @"Astronomy date range checking");
	[[ECErrorReporter theErrorReporter] reportError:[minMessageText stringByAppendingString:@"\n4000 Jan 1 BCE 00:00:00 UT"]];
	lastMinRangeMessageTime = now;
    }
}

-(void)possiblyPutUpMessageBoxAboutMinRange {
    double now = [NSDate timeIntervalSinceReferenceDate];
    if (now - lastMaxRangeMessageTime > ECLastAstroDateWarningInterval) {
	NSString *maxMessageText = NSLocalizedString(@"The latest time supported is", @"Astronomy date range checking");
	[[ECErrorReporter theErrorReporter] reportError:[maxMessageText stringByAppendingString:@"\n2800 Dec 31 23:59:59 UT"]];
	lastMaxRangeMessageTime = now;
    }
}

-(bool)checkAndConstrainAbsoluteTime {
    if ([self currentTime] <= ECMinimumSupportedAstroDate) {
	//[self possiblyPutUpMessageBoxAboutMaxRange];
	if (warp != 0) {
	    [self stop];
	} else {
	    ourTimeAtNTPZero = ECMinimumSupportedAstroDate;
	}
	return true;
    } 
    if ([self currentTime] >= ECMaximumSupportedAstroDate) {
	//[self possiblyPutUpMessageBoxAboutMinRange];
	if (warp != 0) {
	    [self stop];
	} else {
	    ourTimeAtNTPZero = ECMaximumSupportedAstroDate;
	}
	return true;
    }
    return false;
}

-(void)latchTimeForBeatsPerSecond:(int)beatsPerSecond {
    assert(latched >= 0);
    if (!latched) {
        if (beatsPerSecond > 0) {
            latchNTPTime = rint([self currentTime] * beatsPerSecond) / beatsPerSecond;
        } else {
            latchNTPTime = [self currentTime];
        }
    }
    latched++;
}

-(void)unlatchTime {
    assert(latched > 0);
    latched--;
}

// *****************
// Internal methods:
// *****************

-(double)currentTimeIgnoringLatch {
    if (warp) { // If running, incorporate skew; else not; that way skew can change without affecting stopped clocks (and stopwatches)
	// This is just y = mx + b
	return warp * [NSDate timeIntervalSinceReferenceDate] + calcOurTimeAtIPhoneZero(useSmoothTime);
    } else {
	return ourTimeAtNTPZero;  // ourTimeAtAnyTimeWhatsoever
    }
}

-(double)currentTime
{
    // For demo screen captures.  Note that this won't work properly for Miami, Mauna Kea
#undef DEMO_CAPTURE
#ifdef DEMO_CAPTURE
    ESDateComponents fakeDateComponents;
    fakeDateComponents.era = 1;
    fakeDateComponents.year = 2010;
    fakeDateComponents.month = 11;
    fakeDateComponents.day = 27;
    fakeDateComponents.hour = 6;
    fakeDateComponents.minute = 10;
    fakeDateComponents.seconds = 30.0;
    NSTimeInterval fakeTimeInterval = ESCalendar_timeIntervalFromUTCDateComponents(
        &fakeDateComponents);
    return fakeTimeInterval;
#endif

    if (latched) {
	return latchNTPTime;
    }
    if (warp) { // If running, incorporate skew; else not; that way skew can change without affecting stopped clocks (and stopwatches)
	// This is just y = mx + b
	return warp * [NSDate timeIntervalSinceReferenceDate] + calcOurTimeAtIPhoneZero(useSmoothTime);
    } else {
	return ourTimeAtNTPZero;  // ourTimeAtAnyTimeWhatsoever
    }
}

-(NSDate *)currentDate {
    return [NSDate dateWithTimeIntervalSinceReferenceDate:[self currentTime]];
}

// Return the watch time corresponding to the given iPhone time
-(double)convertFromIPhoneToWatch:(double)t {
    if (warp) {  // only include skew when watch is running
	return warp * t + calcOurTimeAtIPhoneZero(useSmoothTime);
    } else {
	return ourTimeAtNTPZero;  // ourTimeAtAnyTimeWhatsoever
    }
}

// Return the iPhone time corresponding to the given watch time
-(double)convertFromWatchToIPhone:(double)t
{
    // This is just the inverse of the above x = (y-b)/m
    if (warp == 0) {
	return 0;  // no possible answer unless ourTimeAtNTPZero == t in which case every answer is correct
    } else {
	return (t - calcOurTimeAtIPhoneZero(useSmoothTime)) / warp;
    }
}

#if 0  //BOGUS
// Return how far the indicated time is from now
-(double)offsetFromNow {
    assert(warp == 0 || warp == 1);
    if (warp) {
	//     warp * date + calcOurTimeAtIPhoneZero(useSmoothTime) - [TSTime currentTime]
	// ==  warp * date + ourTimeAtNTPZero + calcEffectiveSkew(useSmoothTime) - (date + dateSkew)
	// ==  date + ourTimeAtNTPZero + (useSmoothTime ? dateROffset : dateSkew) - (date + dateSkew)
	// ==  ourTimeAtNTPZero + useSmoothTime ? dateROffset - dateSkew : 0;
	return useSmoothTime ? ourTimeAtNTPZero + [TSTime dateROffset] - [TSTime dateSkew] : ourTimeAtNTPZero;
    } else {
	// Nothing for it, we need current time.  Might as well just do it directly
	return [self currentTime] - [TSTime currentDateRTime];
    }
}
#endif

-(bool)isStopped {
    return (warp == 0);
}

-(bool)runningBackward {
    return (warp < 0);
}

#define ECMidnightCacheSpan    (30 * 24 * 3600)  // 30 days total span
#define ECMidnightCachePreload (15 * 24 * 3600)  // starting 15 days back

-(double) midnightForDateInterval:(double)dateInterval usingEnv:(ECWatchEnvironment *)env {
    if (dateInterval <= env->cacheMidnightBase || dateInterval >= env->cacheMidnightBase + ECMidnightCacheSpan) {
	ESTimeZone *estz = env.estz;
	//printf("\n missed cache for %s\n with base %s\n and extent %s\n",
	//       [[[NSDate dateWithTimeIntervalSinceReferenceDate:dateInterval] description] UTF8String],
	//       [[[NSDate dateWithTimeIntervalSinceReferenceDate:env->cacheMidnightBase] description] UTF8String],
	//       [[[NSDate dateWithTimeIntervalSinceReferenceDate:(env->cacheMidnightBase + ECMidnightCacheSpan)] description] UTF8String]);
	double firstDay = dateInterval - ECMidnightCachePreload;
	ESDateComponents cs;
	ESCalendar_localDateComponentsFromTimeInterval(firstDay, estz, &cs);
	cs.hour = 0;
	cs.minute = 0;
	cs.seconds = 1;  // 1 second past midnight
	NSTimeInterval firstMidnight = ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
	env->cacheMidnightBase = firstMidnight - 1;
	NSTimeInterval nextTZChange = ESCalendar_nextDSTChangeAfterTimeInterval(estz, firstMidnight);
	if (nextTZChange) {
	    env->cacheDSTEvent = nextTZChange;
	    if (env->cacheDSTEvent <= env->cacheMidnightBase + ECMidnightCacheSpan) {
		NSTimeInterval postTransitionTimeInterval = env->cacheDSTEvent + 1;
		NSTimeInterval preTransitionTimeInterval = env->cacheDSTEvent - 1;
		ESCalendar_localDateComponentsFromTimeInterval(postTransitionTimeInterval, estz, &cs);
		double postTransitionTime = cs.hour * 3600 + cs.minute * 60 + cs.seconds;
		ESCalendar_localDateComponentsFromTimeInterval(preTransitionTimeInterval, estz, &cs);
		double preTransitionTime = cs.hour * 3600 + cs.minute * 60 + cs.seconds;
		if (fabs(postTransitionTime - preTransitionTime) > 3600 * 12) {  // Must be different days
		    if (postTransitionTime > preTransitionTime) {
			postTransitionTime -= 3600 * 24;
		    } else {
			preTransitionTime -= 3600 * 24;
		    }
		}
		env->cacheDSTDelta = postTransitionTime - preTransitionTime - 2;
	    } else {
		// env->cacheDSTEvent = ECFarInTheFuture;  // Don't throw this info away -- we need  for -[ECWatchTime nextDSTChangeUsingEnv:]
		env->cacheDSTDelta = 0;  // But we don't need the delta in that method
	    }
	} else {
	    env->cacheDSTEvent = ECFarInTheFuture;
	    env->cacheDSTDelta = 0;
	}
	//printf("Caching midnight span\n from %s\n to %s\n",
	//       [[[NSDate dateWithTimeIntervalSinceReferenceDate:env->cacheMidnightBase] description] UTF8String],
	//       [[[NSDate dateWithTimeIntervalSinceReferenceDate:(env->cacheMidnightBase + ECMidnightCacheSpan)] description] UTF8String]);
	//if (env->cacheDSTEvent > env->cacheMidnightBase + ECMidnightCacheSpan) {
	//    printf(" and no cached DST event\n");
	//} else {
	//    printf(" DST delta=%.0f seconds, one second after %s\n", env->cacheDSTDelta, [[[NSDate dateWithTimeIntervalSinceReferenceDate:(env->cacheDSTEvent-1)] description] UTF8String]);
	//}
    }
    double midnightBase = (dateInterval < env->cacheDSTEvent) ? env->cacheMidnightBase : env->cacheMidnightBase - env->cacheDSTDelta;
    double timeSinceMidnight = EC_fmod(dateInterval - midnightBase, 24 * 3600);
    return dateInterval - timeSinceMidnight;
}

-(int)secondsSinceMidnightNumberUsingEnv:(ECWatchEnvironment *)env {
    double now = floor([self currentTime]);
    double midnight = [self midnightForDateInterval:now usingEnv:env];
    return (int)(now - midnight);
}

-(double)secondsSinceMidnightValueUsingEnv:(ECWatchEnvironment *)env {
    double now = [self currentTime];
    double midnight = [self midnightForDateInterval:now usingEnv:env];
    return now - midnight;
}

// *****************
// Methods useful for watch hands and moving dials:
// *****************

// 12:35:45.9 => 45
-(int)secondNumberUsingEnv:(ECWatchEnvironment *)env {
    return [self secondsSinceMidnightNumberUsingEnv:env] % 60;
}

// 12:35:45.9 => 45.9
-(double)secondValueUsingEnv:(ECWatchEnvironment *)env {
    return EC_fmod([self secondsSinceMidnightValueUsingEnv:env], 60);
}

// 12:35:45 => 35
-(int)minuteNumberUsingEnv:(ECWatchEnvironment *)env {
    return ([self secondsSinceMidnightNumberUsingEnv:env] / 60) % 60;
}

// 12:35:45 => 35.75
-(double)minuteValueUsingEnv:(ECWatchEnvironment *)env {
    return EC_fmod([self secondsSinceMidnightValueUsingEnv:env] / 60, 60);
}

// 13:45:00 => 1
-(int)hour12NumberUsingEnv:(ECWatchEnvironment *)env {
    return ([self secondsSinceMidnightNumberUsingEnv:env] / 3600) % 12;
}

// 13:45:00 => 1.75
-(double)hour12ValueUsingEnv:(ECWatchEnvironment *)env {
    return EC_fmod([self secondsSinceMidnightValueUsingEnv:env] / 3600, 12);
}

// 13:45:00 => 13
-(int)hour24NumberUsingEnv:(ECWatchEnvironment *)env {
    return ([self secondsSinceMidnightNumberUsingEnv:env] / 3600) % 24;
}

// 13:45:00 => 13.75
-(double)hour24ValueUsingEnv:(ECWatchEnvironment *)env {
    return EC_fmod([self secondsSinceMidnightValueUsingEnv:env] / 3600, 24);
}

// March 1 => 0  (n.b, not 1; useful for angles and for arrays of images, and consistent with double form below)
-(int)dayNumberUsingEnv:(ECWatchEnvironment *)env {
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval([self currentTime], env.estz, &cs);
    return cs.day - 1;
}
    
// March 1 at 6pm  =>  0.75;  useful for continuous hands displaying day
-(double)dayValueUsingEnv:(ECWatchEnvironment *)env {
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval([self currentTime], env.estz, &cs);
    return cs.day - 1.0 + cs.hour / 24.0 + cs.minute / (60.0 * 24.0) + cs.seconds / (3600.0 * 24.0);
} 

// March 1 => 2  (n.b., not 3)
-(int)monthNumberUsingEnv:(ECWatchEnvironment *)env {
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval([self currentTime], env.estz, &cs);
    return cs.month - 1;
}

static int
calcDaysInMonth(int        nsMonthNumber,
		int        year,
		int        era,
		ESTimeZone *estz)
{
    switch(nsMonthNumber) {
      case 1:
	return 31;
      case 2:
        {
	    // look up March 1 of this year and subtract Feb 1, divide by 3600 * 24 => num days
	    ESDateComponents cs;
	    cs.day = 1;
	    cs.month = 2;
	    cs.year = year;
	    cs.era = era;
	    cs.hour = 0;
	    cs.minute = 0;
	    cs.seconds = 0;
	    NSTimeInterval feb1 = ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
	    cs.month = 3;
	    NSTimeInterval mar1 = ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
	    return rint((mar1 - feb1) / (3600.0 * 24.0));
        }
      case 3:
	return 31;
      case 4:
	return 30;
      case 5:
	return 31;
      case 6:
	return 30;
      case 7:
	return 30;
      case 8:
	return 31;
      case 9:
	return 30;
      case 10:
	return 31;
      case 11:
	return 30;
      case 12:
	return 31;
      default:
	return 0;
    }
}

// March 1 at noon  =>  12 / (31 * 24); useful for continuous hands displaying month
-(double)monthValueUsingEnv:(ECWatchEnvironment *)env {
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval([self currentTime], env.estz, &cs);
    return (cs.month - 1.0) + (cs.day - 1.0 + cs.hour / 24.0 + cs.minute / (60.0 * 24.0) + cs.seconds / (3600.0 * 24.0))/calcDaysInMonth(cs.month, cs.year, cs.era, env.estz);
}

// March 1 1999 => 1999
-(int)yearNumberUsingEnv:(ECWatchEnvironment *)env {
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval([self currentTime], env.estz, &cs);
    return cs.year;
}

// BCE => 0; CE => 1
-(int)eraNumberUsingEnv:(ECWatchEnvironment *)env {
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval([self currentTime], env.estz, &cs);
    return cs.era;
}

// daylight => 1; standard => 0
-(bool)isDSTUsingEnv:(ECWatchEnvironment *)env {
    double t = [self currentTime];
    if (warp > 0) {
	t += 1.0;  // Apple doesn't seem to know that 02:00:00.4 is after the transition
    } else if (warp < 0) {
	t -= 1.0;  // And when we go backwards, we want a time that's before the transition
    }
    //printf("DSTNumber: Checking DSTForDate "); printADateWithTimeZone(t, env.estz);
    //printf(", getting '%s'\n", [[calendar timeZone] isDaylightSavingTimeForDate:[NSDate dateWithTimeIntervalSinceReferenceDate:t]] ? "yes" : "no");
    return ESCalendar_isDSTAtTimeInterval(env.estz, t);
}

extern void printADate(NSTimeInterval dt);

-(NSTimeInterval)nextDSTChangeUsingEnv:(ECWatchEnvironment *)env {
    NSTimeInterval now = [self currentTimeIgnoringLatch];
    [self midnightForDateInterval:now usingEnv:env];  // force cache load
    if (now > env->cacheMidnightBase && now < env->cacheDSTEvent) {
	return env->cacheDSTEvent;
    }
    // Should never get here...
    //printf("Cache miss for nextDST, now = "); printADate(now); printf(", midnightBase = "); printADate(env->cacheMidnightBase); printf(", dst event = "); printADate(env->cacheDSTEvent); printf("\n");
    NSTimeInterval nextChange = ESCalendar_nextDSTChangeAfterTimeInterval(env.estz, now);
    //printf("Calculating next DST change for %s => %s\n",
    //	   [[now description] UTF8String],
    //	   [[date description] UTF8String]);
    return nextChange;
}

-(NSTimeInterval)prevDSTChangePrecisely:(bool)precise usingEnv:(ECWatchEnvironment *)env {
    ESTimeZone *estz = env.estz;

    NSTimeInterval now = [self currentTimeIgnoringLatch];

    // Let's try back one year first (remember, there should be two every year)
    NSTimeInterval oneYearPrior = now - 365 * 24 * 3600;
    NSTimeInterval startInterval = oneYearPrior;
    NSTimeInterval nextShift = ESCalendar_nextDSTChangeAfterTimeInterval(estz, startInterval);
    if (nextShift) {
	if (nextShift < now) {
	    // If not, then our one and only known transition is after where we are and we know nothing
	    NSTimeInterval bestShiftSoFar = nextShift; // startDate >= nextShift > now
	    while (1) {
		//printf("%s is before %s?\n",
		//	   [[nextShift description] UTF8String],
		//	   [[now description] UTF8String]);
		startInterval = nextShift + 7200;  // move past ambiguity
		nextShift = ESCalendar_nextDSTChangeAfterTimeInterval(estz, startInterval);
		if (!nextShift || nextShift >= now) {
		    return bestShiftSoFar;
		}
		// OK, nextShift passes, so move on up and iterate
		bestShiftSoFar = nextShift;
	    }
	    //printf("One-year: Calculating prev DST change for %s => %s\n",
	    //       [[now description] UTF8String],
	    //       [[startDate description] UTF8String]);
	    return 0;
	}
    }
    if (!precise) {
	return 0;
    }
    assert(false);  // Nothing should need precise prevDST; if it does, this should be rewritten 'cause it's too darned slow
    // Nothing back a year.  Let's try going back 10, 100, 1000, 10000 years just in case
    int i;
    for (i = 10; i <= 10000; i *= 10) {
	NSTimeInterval prior = now - i * 365.0 * 24 * 3600;
	nextShift = ESCalendar_nextDSTChangeAfterTimeInterval(estz, prior);
	if (nextShift) {  // found one in prior eras.  The following loop might take a while...
	    // Put some code here kinda like the code above
	}
    }
    //printf("No prev DST change for %s\n",
    //	   [[now description] UTF8String]);
    return 0;  // must be no DST in this time zone
}

// 2000 => 1, 2001 => 0
-(bool)leapYearUsingEnv:(ECWatchEnvironment *)env {
    return (ESCalendar_daysInYear(env->estz, [self currentTime]) > 365.5);
}

// Tuesday => 2
-(int)weekdayNumberUsingEnv:(ECWatchEnvironment *)env {
    NSTimeInterval now = [self currentTime];
    NSTimeInterval localNow = now + ESCalendar_tzOffsetForTimeInterval(env->estz, now);
    double localNowDays = localNow / (24 * 3600);
    double weekday = EC_fmod(localNowDays + 1, 7);
    //printf("weekdayNumber is %d (%.4f)\n", (int)floor(weekday), weekday);
    return (int)floor(weekday);
}

// Tuesday at 6pm => 2.75
-(double)weekdayValueUsingEnv:(ECWatchEnvironment *)env {
    NSTimeInterval now = [self currentTime];
    NSTimeInterval localNow = now + ESCalendar_tzOffsetForTimeInterval(env->estz, now);
    double localNowDays = localNow / (24 * 3600);
    double weekday = EC_fmod(localNowDays + 1, 7);
    return weekday;
}

// This function incorporates the value of ECCalendarWeekdayStart
-(int)weekdayNumberAsCalendarColumnUsingEnv:(ECWatchEnvironment *)env {
    NSTimeInterval now = [self currentTime];
    NSTimeInterval localNow = now + ESCalendar_tzOffsetForTimeInterval(env->estz, now);
    double localNowDays = localNow / (24 * 3600);
    double weekday = EC_fmod(localNowDays + 1, 7);
    int weekdayNumber = (int)floor(weekday);
    //printf("weekdayNumber is %d (%.4f)\n", weekdayNumber, weekday);
    return (7 + weekdayNumber - ECCalendarWeekdayStart) % 7;
}

// Leap year: fraction of 366 days since Jan 1
// Non-leap year: fraction of 366 days since Jan 1 through Feb 28, then that plus 24hrs starting Mar 1
// Result is indicator value on 366-year dial
-(double)year366IndicatorFractionUsingEnv:(ECWatchEnvironment *)env {
    const int secondsIn366Year = 366 * 24 * 3600;  // 31,622,400
    double ct = [self currentTime];
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(ct, env->estz, &cs);
    //printf("Date %s %04d-%02d\n",
    //cs.era ? " CE" : "BCE",
    //cs.year, cs.month);
    int month = cs.month;
    cs.month = 1;
    int day = cs.day;
    cs.day = 1;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval firstOfThisYearInterval = ESCalendar_timeIntervalFromLocalDateComponents(env->estz, &cs);
    bool isLeapYear = (ESCalendar_daysInYear(env->estz, ct) > 365.5);
    bool isGregorianTransitionYear = (cs.year == 1582 && cs.era == 1);
    //printf("...daysInYear %d, isLeapYear %s\n", daysInYear(calendar, ct), isLeapYear ? "TRUE" : "FALSE");
    if (!isLeapYear && month > 2) {
	ct += 24 * 3600;  // We skip over Feb 28 in non-leap years
	if (isGregorianTransitionYear) {
	    if (month > 10 || month == 10 && day > 4) {
		ct += 10 * 24*3600;
	    }
	}
    }
    return (ct - firstOfThisYearInterval) / secondsIn366Year;
}

// Jan 1 => 0    
-(int)dayOfYearNumberUsingEnv:(ECWatchEnvironment *)env {
    double midnight = [self midnightForDateInterval:([self currentTime] + 2) usingEnv:env];  // Make sure we're in the same day, but just barely,
                                                                                             // so we get the right date and we can round to ignore DST effects
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(midnight, env->estz, &cs);
    //printf("Date %s %04d-%02d\n",
    //cs.era ? " CE" : "BCE",
    //cs.year, cs.month);
    cs.month = 1;
    cs.day = 1;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval firstOfThisYearInterval = ESCalendar_timeIntervalFromLocalDateComponents(env->estz, &cs);
    return (int)rint((midnight - firstOfThisYearInterval) / (24 * 3600));
}

// First week => 0    
-(int)weekOfYearNumberUsingEnv:(ECWatchEnvironment *)env
                    useISO8601:(bool)useISO8601   // use only when weekStartDay == 1 (Monday)
                  weekStartDay:(int)weekStartDay {  // weekStartDay == 0 means weeks start on Sunday
    assert(!useISO8601 || weekStartDay == 1);
    double midnight = [self midnightForDateInterval:([self currentTime] + 2) usingEnv:env];  // Make sure we're in the same day, but just barely,
                                                                                             // so we get the right date and we can round to ignore DST effects
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(midnight, env->estz, &cs);
    //printf("Date %s %04d-%02d\n",
    //cs.era ? " CE" : "BCE",
    //cs.year, cs.month);

    if (useISO8601 && cs.month == 12 && cs.day >= 29) {  // End of December
        int weekday = ESCalendar_localWeekdayFromTimeInterval(midnight, env->estz);
        int weekdayOfDec31 = (weekday + (31 - cs.day)) % 7;
        if (weekdayOfDec31 <= 3 && weekdayOfDec31 >= 1 &&
            weekdayOfDec31 + cs.day >= 32) {   // weekdayOfDec31 == 3 && cs.day >= 29 ||
                                               // weekdayOfDec31 == 2 && cs.day >= 30 ||
                                               // weekdayOfDec31 == 1 && cs.day >= 31
            return 0;  // we're part of next year, and we're the first week
        }
    }

    cs.month = 1;
    cs.day = 1;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval firstOfThisYearInterval = ESCalendar_timeIntervalFromLocalDateComponents(env->estz, &cs);

    while (1) {
        int weekdayOfJan1 = ESCalendar_localWeekdayFromTimeInterval(firstOfThisYearInterval, env->estz);

        // Now get "effective" first day of year, which is the first day of the first week as defined by algorithm
        int deltaFromFirstDayToFirstWeek;  // positive means first day is behind first week (normally false, so normally negative)
        if (useISO8601) {
            if (weekdayOfJan1 == 0 || weekdayOfJan1 >= 5) {  // First day of year belongs to previous year's last week; move forward
                // 5 => 3, 6 => 2, 0 => 1
                deltaFromFirstDayToFirstWeek = (8 - weekdayOfJan1) % 7;
            } else {  // First day of year belongs to this year's first week; move backward
                // 1 => 0, 2 => -1, 3 => -2, 4 => -3
                deltaFromFirstDayToFirstWeek = (1 - weekdayOfJan1);
            }
        } else {
            // weekStartDay == 0: 0 => 0, 1 => -1, 2 => -2, ... 6 => -6
            // weekStartDay == 6: 6 => 0, 0 => -1, 1 => -2, ... 5 => -6
            // weekStartDay == 5: 5 => 0, 6 => -1, 0 => -2, ... 4 => -6
            deltaFromFirstDayToFirstWeek = - ((weekdayOfJan1 + 7 - weekStartDay) % 7);
        }

        firstOfThisYearInterval += (deltaFromFirstDayToFirstWeek * 24 * 3600);

        if (midnight >= firstOfThisYearInterval) {
            break;
        }

        // If we're here, then this day logically belongs to the previous year

        if (cs.era > 0) {
            if (cs.year == 1) {
                cs.era = 0;
            } else {
                cs.year--;
            }
        } else {
            cs.year++;
        }
        firstOfThisYearInterval = ESCalendar_timeIntervalFromLocalDateComponents(env->estz, &cs);
        assert(midnight >= firstOfThisYearInterval);
    } 

    int logicalDayOfYear = (int)rint((midnight - firstOfThisYearInterval) / (24 * 3600));  // relative to first week start day
    return logicalDayOfYear / 7;
}

// *****************
// Stopwatch methods:  The y for a stopwatch watch is zero at reset
// *****************

// 00:04:03.9 => 3
-(int)stopwatchSecondNumber
{
    return (int)(llrint(floor([self currentTime])) % 60);
}

// 00:04:03.9 => 3.9
-(double)stopwatchSecondValue
{
    return EC_fmod([self currentTime], 60);
}

// 01:04:45 => 4
-(int)stopwatchMinuteNumber
{
    return (int)((llrint(floor([self currentTime])) / 60) % 60);
}

// 01:04:45 => 4.75
-(double)stopwatchMinuteValue
{
    return EC_fmod([self currentTime] / 60, 60);
}

// 5d 01:30:00 => 1
-(int)stopwatchHour24Number
{
    return (int)((llrint(floor([self currentTime])) / 3600) % 24);
}

// 5d 01:30:00 => 1.5
-(double)stopwatchHour24Value
{
    return EC_fmod([self currentTime] / 3600, 24);
}

// 5d 01:30:00 => 1
-(int)stopwatchHour12Number
{
    return (int)((llrint(floor([self currentTime])) / 3600) % 12);
}

// 5d 01:30:00 => 1.5
-(double)stopwatchHour12Value
{
    return EC_fmod([self currentTime] / 3600, 12);
}

// 5d 18:00:00 => 5
-(int)stopwatchDayNumber
{
    return (int)(llrint(floor([self currentTime])) / (3600 * 24));
}

// 5d 18:00:00 => 5.75
-(double)stopwatchDayValue
{
    return [self currentTime] / (3600 * 24);
}

// *****************
// Alarm methods
// *****************

// *****************
// Set methods
// *****************

static ECWatchTimeCycle
cycleFromWarp(double warp) {
    if (warp == 0) {
	return ECWatchCyclePaused;
    }
    ECWatchTimeCycle cycle;
    for (cycle = ECWatchCycleFirst; cycle <= ECWatchCycleLastForward; cycle++) {
	if (warpValuesForCycle[cycle] > warp) {
	    if (cycle < ECWatchCycleFirst) {
		if (warpValuesForCycle[cycle] - warp > warp - warpValuesForCycle[cycle - 1] ) {
		    return cycle - 1;
		} else {
		    return cycle;
		}
	    }
	}
    }
    return ECWatchCycleOther;
}

// Freeze at current time; does nothing if already frozen
// Skew is removed from ourTimeAtNTPZero when stopping so we don't have to recalculate stopped watches when skew changes
-(void)stop
{
    if (warp != 0.0) {
	// m = 0 => b = y;
	ourTimeAtNTPZero = [self currentTime];
	warpBeforeFreeze = warp;
	warp = 0.0;
	cycle = ECWatchCyclePaused;
    }
}

// Unfreeze; does nothing if not frozen
// Skew is inserted back into ourTimeAtNTPZero when restarting so we don't have to modify stopped watches when skew changes
-(void)start
{
    if (warp == 0.0) {
	// b = y - mx;
	if (warpBeforeFreeze == 0) {
	    warpBeforeFreeze = 1.0;
	}
	ourTimeAtNTPZero = ourTimeAtNTPZero - ([NSDate timeIntervalSinceReferenceDate] * warpBeforeFreeze + calcEffectiveSkew(useSmoothTime));
	warp = warpBeforeFreeze;
	cycle = cycleFromWarp(warp);
    }
}

// Freeze or unfreeze
-(void)toggleStop
{
    if (warp == 0.0) {
	[self start];
    } else {
	[self stop];
    }
}

// Reverse direction
-(void)reverse
{
    warp = -warp;
    warpBeforeFreeze = -warpBeforeFreeze;
}

// Do this once for a given watchTime if it wants to use smooth time (i.e., is relative not absolute)
// BEFORE it does anything at all
-(void)setUseSmoothTime:(bool)newUseSmoothTime {
    useSmoothTime = newUseSmoothTime;
}

// Like toggleStop, but if stopping then round value to nearest rounding value
// (useful for stopwatches, so the restart time is exactly where it purports to be)
-(void)toggleStopWithRounding:(double)rounding {
    if (warp == 0.0) {
	[self start];
    } else {
	[self stop];
//	ourTimeAtNTPZero = round(ourTimeAtNTPZero / rounding) * rounding;
	// Well actually, it looks better if it truncates instead of rounding
	ourTimeAtNTPZero = floor(ourTimeAtNTPZero / rounding) * rounding;
    }
}

// Initialize and set value according to recorded defaults
-(void)stopwatchInitStoppedReading:(double)interval {
    assert(useSmoothTime);
    warp = 0.0;
    cycle = ECWatchCyclePaused;
    ourTimeAtNTPZero = interval;
}

// Initialize and set value according to recorded defaults
-(void)stopwatchInitRunningFromZeroTime:(double)zeroRTime {
    assert(useSmoothTime);
    warp = 1.0;
    cycle = ECWatchCycleNormal;
    ourTimeAtNTPZero = -zeroRTime;
}

-(void)stopwatchReset
{
    assert(useSmoothTime);
    if (warp) {
	ourTimeAtNTPZero = -calcEffectiveSkew(useSmoothTime) - warp * [NSDate timeIntervalSinceReferenceDate];
    } else {
	ourTimeAtNTPZero = 0;
    }
}

// Copy lap time
-(void)copyLapTimeFromOtherTimer:(ECWatchTime *)otherTimer
{
    assert(useSmoothTime);
    assert(otherTimer->useSmoothTime);
    ourTimeAtNTPZero = [otherTimer currentTime];
    warp = 0.0;
    cycle = ECWatchCyclePaused;
}

-(void)makeTimeIdenticalToOtherTimer:(ECWatchTime *)otherTimer
{
    assert(useSmoothTime == otherTimer->useSmoothTime);
    ourTimeAtNTPZero = otherTimer->ourTimeAtNTPZero;
    warp = otherTimer->warp;
    cycle = otherTimer->cycle;
}

// Clone time + interval
-(void)makeTimeIdenticalToOtherTimer:(ECWatchTime *)otherTimer plusDelta:(NSTimeInterval)delta {
    assert(useSmoothTime);
    assert(!otherTimer->useSmoothTime);
    //ourTimeAtNTPZero = [TSTime rDateForNTPTime:otherTimer->ourTimeAtNTPZero] + delta;
    ourTimeAtNTPZero = otherTimer->ourTimeAtNTPZero + delta;
    //printf("raw delta = %.2f\n", ourTimeAtNTPZero - otherTimer->ourTimeAtNTPZero);
    //printf("delta = %.2f => ourTimeAtNTPZero %.2f\n", delta, ourTimeAtNTPZero);
    //printf("...checking, my time - other timer = %.2f, dateROffset = %.2f, dateRSkew = %.2f, dateSkew = %.2f, ntp conversion delta is %.2f\n",
    //       [TSTime ntpTimeForRDate:[self currentTime]] - [otherTimer currentTime], [TSTime dateROffset], [TSTime dateRSkew], [TSTime dateSkew], [TSTime ntpTimeForRDate:[self currentTime]] - [self currentTime]);
    //[TSTime reportAllSkewsAndOffset:"setting timer"];
    warp = otherTimer->warp;
    cycle = otherTimer->cycle;
}

-(double)offsetFromOtherTimer:(ECWatchTime *)otherTimer {
    assert(!otherTimer->useSmoothTime);
    if (warp == otherTimer->warp) {
	return ourTimeAtNTPZero - otherTimer->ourTimeAtNTPZero;
    } else if (useSmoothTime) {
	//[TSTime reportAllSkewsAndOffset:"reporting offset"];
	return [TSTime ntpTimeForRDate:[self currentTime]] - [otherTimer currentTime];
    } else {
	return [self currentTime] - [otherTimer currentTime];
    }
}

// Check for clone
-(bool)isIdenticalTo:(ECWatchTime *)otherTimer
{
    assert(useSmoothTime == otherTimer->useSmoothTime);
    return ourTimeAtNTPZero == otherTimer->ourTimeAtNTPZero
	&& warp == otherTimer->warp;
}

// reset to a saved time
-(void)setCurrentDate:(NSDate *)date {
    ourTimeAtNTPZero = [date timeIntervalSinceReferenceDate] - ([NSDate timeIntervalSinceReferenceDate] + calcEffectiveSkew(useSmoothTime));
    warp = 1.0;
    cycle = ECWatchCycleNormal;
}

-(void)setCurrentDate:(NSDate *)date withWarp:(double)aWarp {
    // target = ynew
    // target = mnew * x + bnew + skew
    // target - (mnew * x) = bnew

    if (aWarp) {
	ourTimeAtNTPZero = [date timeIntervalSinceReferenceDate] - (aWarp * [NSDate timeIntervalSinceReferenceDate] + calcEffectiveSkew(useSmoothTime));
    } else {
	ourTimeAtNTPZero = [date timeIntervalSinceReferenceDate];
    }
    warp = aWarp;
    cycle = cycleFromWarp(warp);
}

-(void)setToFrozenDate:(NSDate *)date {
    warp = 0.0;
    cycle = ECWatchCyclePaused;
    ourTimeAtNTPZero = [date timeIntervalSinceReferenceDate];
    [self checkAndConstrainAbsoluteTime];
}

-(void)setToFrozenDateInterval:(NSTimeInterval)date {
    warp = 0.0;
    cycle = ECWatchCyclePaused;
    ourTimeAtNTPZero = date;
    [self checkAndConstrainAbsoluteTime];
}

// Reset to following actual iPhone time (subject to calendar installed)
-(void)resetToLocal {
    ourTimeAtNTPZero = 0;
    warp = 1.0;
    cycle = ECWatchCycleNormal;
}

-(bool)frozen
{
    return (warp == 0.0);
}

-(bool)isCorrect
{
    return (warp == 1.0 && ourTimeAtNTPZero == 0);
}

-(bool)lastMotionWasInReverse {
    return warp < 0 || (warp == 0 && warpBeforeFreeze < 0);
}

// Change warp speed, recalculating internal data as necessary
-(void)setWarp:(double)newWarp
{
    if (newWarp == 0) {
	[self stop];
    } else {
	if (warp == 0) {  // need to re-incorporate skew
	    ourTimeAtNTPZero = ourTimeAtNTPZero - ([NSDate timeIntervalSinceReferenceDate] * newWarp + calcEffectiveSkew(useSmoothTime));
	} else {
	    // yold = ynew
	    // mold * x + bold + skew = mnew * x + bnew + skew
	    // (mold - mnew) * x = bnew - bold
	    // bnew = bold + (mold - mnew) * x
	    ourTimeAtNTPZero += (warp - newWarp) * [NSDate timeIntervalSinceReferenceDate];
	}
	warp = newWarp;
	cycle = cycleFromWarp(warp);
    }
}

-(NSTimeInterval)tzOffsetUsingEnv:(ECWatchEnvironment *)env {
    double now = [self currentTime];
    if (env->prevTimeForTZ == now) {
	//printf("returning previous tzOffset at date ");
	//printADateWithTimeZone(now, env->estz);
	//printf("\n");
    } else {
	env->prevTimeForTZ = now;
	env->resultForTZ = ESCalendar_tzOffsetForTimeInterval(env->estz, now);
	// [[env->calendar timeZone] secondsFromGMTForDate:[self currentDate]];  Apple bug here 1918,1919,>=2038
    }
    return env->resultForTZ;
}

-(int)numberOfDaysOffsetFrom:(ECWatchTime *)other usingEnv1:(ECWatchEnvironment *)env1 env2:(ECWatchEnvironment *)env2 {
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval([self currentTime], env1->estz, &cs);
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval myMidnight = ESCalendar_timeIntervalFromLocalDateComponents(env1->estz, &cs);
    ESCalendar_localDateComponentsFromTimeInterval([other currentTime], env2->estz, &cs);
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval otherMidnight = ESCalendar_timeIntervalFromLocalDateComponents(env2->estz, &cs);
    NSTimeInterval deltaSeconds = myMidnight - otherMidnight;
    return rint(deltaSeconds/(24 * 3600));
}

// Number of days between two times (if this is Wed and other's Thu, answer is -1)
-(int)numberOfDaysOffsetFrom:(ECWatchTime *)other usingEnv:(ECWatchEnvironment *)env {
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval([self currentTime], env->estz, &cs);
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval myMidnight = ESCalendar_timeIntervalFromLocalDateComponents(env->estz, &cs);
    ESCalendar_localDateComponentsFromTimeInterval([other currentTime], env->estz, &cs);
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval otherMidnight = ESCalendar_timeIntervalFromLocalDateComponents(env->estz, &cs);
    NSTimeInterval deltaSeconds = myMidnight - otherMidnight;
    return rint(deltaSeconds/(24 * 3600));
}

// 1d 4:00:00 (localized (not yet))
-(NSString *)representationOfDeltaOffsetUsingEnv:(ECWatchEnvironment *)env {
    double delta;
    if (warp) {
//    delta = currentDate - actualDate
//    delta = [self currentTime] - ([NSDate timeIntervalSinceReferenceDate] + skew);
//    delta = (warp * [NSDate timeIntervalSinceReferenceDate] + ourTimeAtNTPZero + skew) - ([NSDate timeIntervalSinceReferenceDate] + skew);
//    delta = warp * [NSDate timeIntervalSinceReferenceDate] + ourTimeAtNTPZero - [NSDate timeIntervalSinceReferenceDate];
	delta = (warp - 1) * [NSDate timeIntervalSinceReferenceDate] + ourTimeAtNTPZero;
    } else {
//    delta = currentDate - actualDate
//    delta = [self currentTime] - ([NSDate timeIntervalSinceReferenceDate] + skew);
//    delta = ourTimeAtNTPZero - ([NSDate timeIntervalSinceReferenceDate] + skew);
	delta = ourTimeAtNTPZero - [NSDate timeIntervalSinceReferenceDate] - calcEffectiveSkew(useSmoothTime);
    }
    
    char *sign;
    NSTimeInterval now = [self currentTime];
    NSTimeInterval time1;
    NSTimeInterval time2;
    if (delta > 0) {
	sign = "+";
	time1 = now - delta;
	time2 = now;
    } else {
	sign = "-";
	time1 = now;
	time2 = now - delta;
	delta = -delta;  // futureproof -- in case we specify fractional seconds at some point
	delta = delta;   // for now, shut up the warning
    }
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromDeltaTimeInterval(env->estz, time1, time2, &cs);

    if (cs.year != 0) {
	return [NSString stringWithFormat:@"%s%dy %dd %02d:%02d:%02d", sign, cs.year, cs.day, cs.hour, cs.minute, (int)floor(cs.seconds)];
    } else if (cs.day != 0) {
	return [NSString stringWithFormat:@"%s%dd %02d:%02d:%02d", sign, cs.day, cs.hour, cs.minute, (int)floor(cs.seconds)];
    } else {
	return [NSString stringWithFormat:@"%s%02d:%02d:%02d", sign, cs.hour, cs.minute, (int)floor(cs.seconds)];
    }
}

// 1 day/s (localized (not yet))
-(NSString *)representationOfWarp {
    if (warp == 0) {
	return @"Stopped";
    } else if (warp < 0) {
	if (warp > -60) {
	    return [NSString stringWithFormat:@"%gx", warp];
	} else if (warp > -3600) {
	    return [NSString stringWithFormat:@"%g min/sec", warp/60];
	} else if (warp > -24 * 3600) {
	    return [NSString stringWithFormat:@"%g hr/sec", warp/3600];
	} else {
	    double rate = warp/(3600*24);
	    char *plural = ((fabs(rate) - 1) < 0.001) ? "" : "s";
	    return [NSString stringWithFormat:@"%g day%s/sec", rate, plural];
	}
    } else {
	if (warp < 60) {
	    return [NSString stringWithFormat:@"%gx", warp];
	} else if (warp < 3600) {
	    return [NSString stringWithFormat:@"%g min/sec", warp/60];
	} else if (warp < 24 * 3600) {
	    return [NSString stringWithFormat:@"%g hr/sec", warp/3600];
	} else {
	    double rate = warp/(3600*24);
	    char *plural = ((fabs(rate) - 1) < 0.001) ? "" : "s";
	    return [NSString stringWithFormat:@"%g day%s/sec", rate, plural];
	}
    }
}

// If pause, then resume from current position at normal speed (warp == 1); if not paused, then pause
-(void)pausePlay {
    if (warp == 0) {
	[self setWarp:1];
	cycle = ECWatchCycleNormal;
    } else {
	[self stop];
	cycle = ECWatchCyclePaused;
    }
}

// Cycle through speeds
-(void)cycleFastForward {
    if (cycle >= ECWatchCycleFirst && cycle <= ECWatchCycleLast) {
	ECWatchTimeCycle newCycle = nextCycleForFF[cycle];
	[self setWarp:warpValuesForCycle[newCycle]];
	cycle = newCycle;
    } else {
	[self setWarp:1];
	cycle = ECWatchCycleNormal;
    }
}

// Cycle through speeds
-(void)cycleRewind {
    if (cycle >= ECWatchCycleFirst && cycle <= ECWatchCycleLast) {
	ECWatchTimeCycle newCycle = nextCycleForRewind[cycle];
	[self setWarp:warpValuesForCycle[newCycle]];
	cycle = newCycle;
    } else {
	[self setWarp:1];
	cycle = ECWatchCycleNormal;
    }
}

static NSTimeInterval onEvenTime(double t, double interval) {
    NSTimeInterval nt = floor(t / interval) * interval;
    if (nt < t) {
	nt += interval;
    }
    return nt;
}

static NSTimeInterval onEvenTimeBack(double t, double interval) {
    NSTimeInterval nt = ceil(t / interval) * interval;
    if (nt > t) {
	nt -= interval;
    }
    return nt;
}

// Amount to move forward or backwards before calculating the next place to stop
-(NSTimeInterval)gapJumpBeforeInterval {
    if (warp >= 0) {
	// Stopping just before midnight, so jump past
	return   kECWatchTimeAdvanceGap + 1;
    } else {
	// Stopping just after midnight, so jump back
	return - kECWatchTimeAdvanceGap - 1;
    }
}

-(NSTimeInterval)offsetAfterJump {
    if (warp >= 0) {
	return - kECWatchTimeAdvanceGap;
    } else {
	return kECWatchTimeAdvanceGap;
    }
}

-(NSTimeInterval)preAdvanceForNextAtTime:(NSTimeInterval)currentLocal andInterval:(NSTimeInterval)interval {
    if (warp >= 0) {
	return currentLocal + kECWatchTimeAdvanceGap + 1;
    } else {
	return currentLocal + (interval/2);
    }
}

-(NSTimeInterval)preAdvanceForPrevAtTime:(NSTimeInterval)currentLocal andInterval:(NSTimeInterval)interval {
    if (warp >= 0) {
	return currentLocal - (interval/2);
    } else {
	return currentLocal - kECWatchTimeAdvanceGap - 1;
    }
}

-(void)advanceToNextInterval:(NSTimeInterval)interval usingEnv:(ECWatchEnvironment *)env {
    NSTimeInterval tzOff = [self tzOffsetUsingEnv:env];
    NSTimeInterval currentTimeGMT = [self currentTime];
    NSTimeInterval currentTimeLocal = currentTimeGMT + tzOff;
    NSTimeInterval newTimeLocal = onEvenTime([self preAdvanceForNextAtTime:currentTimeLocal andInterval:interval], interval);
    newTimeLocal += [self offsetAfterJump];
    ourTimeAtNTPZero += (newTimeLocal - currentTimeLocal);
    [self checkAndConstrainAbsoluteTime];
}

-(void)advanceToPrevInterval:(NSTimeInterval)interval usingEnv:(ECWatchEnvironment *)env {
    NSTimeInterval tzOff = [self tzOffsetUsingEnv:env];
    NSTimeInterval currentTimeGMT = [self currentTime];
    NSTimeInterval currentTimeLocal = currentTimeGMT + tzOff;
    NSTimeInterval newTimeLocal = onEvenTimeBack([self preAdvanceForPrevAtTime:currentTimeLocal andInterval:interval], interval);
    newTimeLocal += [self offsetAfterJump];
    ourTimeAtNTPZero += (newTimeLocal - currentTimeLocal);
    [self checkAndConstrainAbsoluteTime];
}

-(void)advanceToNextMonthUsingEnv:(ECWatchEnvironment *)env {
    NSTimeInterval currentTime = [self currentTime];
    NSTimeInterval preTime = [self preAdvanceForNextAtTime:currentTime andInterval:(3600 * 24 * 15)];
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(preTime, env->estz, &cs);
    // Find the first of this month
    cs.day = 1;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval firstOfThisMonth = ESCalendar_timeIntervalFromLocalDateComponents(env->estz, &cs);
    // Add one month
    NSTimeInterval firstOfNextMonth = ESCalendar_addMonthsToTimeInterval(firstOfThisMonth, env->estz, 1);
    ourTimeAtNTPZero += (firstOfNextMonth - currentTime + [self offsetAfterJump]);
    [self checkAndConstrainAbsoluteTime];
}

-(void)advanceToPrevMonthUsingEnv:(ECWatchEnvironment *)env {
    NSTimeInterval currentTime = [self currentTime];
    NSTimeInterval preTime = [self preAdvanceForPrevAtTime:currentTime andInterval:(3600 * 24 * 15)];
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(preTime, env->estz, &cs);
    // Find the first of this month
    cs.day = 1;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval firstOfThisMonth = ESCalendar_timeIntervalFromLocalDateComponents(env->estz, &cs);
    ourTimeAtNTPZero += (firstOfThisMonth - currentTime + [self offsetAfterJump]);
    [self checkAndConstrainAbsoluteTime];
}

-(void)advanceToNextYearUsingEnv:(ECWatchEnvironment *)env {
    NSTimeInterval currentTime = [self currentTime];
    NSTimeInterval preTime = [self preAdvanceForNextAtTime:currentTime andInterval:(3600 * 24 * 15)];
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(preTime, env->estz, &cs);
    // Find the first of this year
    cs.day = 1;
    cs.month = 1;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval firstOfThisYear = ESCalendar_timeIntervalFromLocalDateComponents(env->estz, &cs);
    // Add one year
    NSTimeInterval firstOfNextYear = ESCalendar_addYearsToTimeInterval(firstOfThisYear, env->estz, 1);
    ourTimeAtNTPZero += (firstOfNextYear - currentTime + [self offsetAfterJump]);
    [self checkAndConstrainAbsoluteTime];
}

-(void)advanceToPrevYearUsingEnv:(ECWatchEnvironment *)env {
    NSTimeInterval currentTime = [self currentTime];
    NSTimeInterval preTime = [self preAdvanceForNextAtTime:currentTime andInterval:(3600 * 24 * 15)];
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(preTime, env->estz, &cs);
    // Find the first of this year
    cs.day = 1;
    cs.month = 1;
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval firstOfThisYear = ESCalendar_timeIntervalFromLocalDateComponents(env->estz, &cs);
    ourTimeAtNTPZero += (firstOfThisYear - currentTime + [self offsetAfterJump]);
    [self checkAndConstrainAbsoluteTime];
}

// Advance to next point (context sensitive)
-(void)advanceToNextUsingEnv:(ECWatchEnvironment *)env {
    switch (cycle) {
      case ECWatchCycleFF6: // 5x24x3600x
      case ECWatchCycleReverseFF6:
	[self advanceToNextYearUsingEnv:env];
	break;

      case ECWatchCycleFF5: // 24x3600x
      case ECWatchCycleReverseFF5:
	[self advanceToNextMonthUsingEnv:env];
	break;

      case ECWatchCycleFF2: // 60x
      case ECWatchCycleReverseFF2:
	[self advanceToNextInterval:3600 usingEnv:env];
	break;

      case ECWatchCycleFF1: // 5x
      case ECWatchCycleReverseFF1:
	[self advanceToNextInterval:60 usingEnv:env];
	break;

      case ECWatchCycleSlow1: // 0.1
	[self advanceToNextInterval:1 usingEnv:env];
	break;

      case ECWatchCycleReverseSlow1:
	break;
	[self advanceToNextInterval:1 usingEnv:env];
	break;

      default:
      case ECWatchCycleOther:
      case ECWatchCycleNormal:
      case ECWatchCyclePaused:
      case ECWatchCycleReverse:
      case ECWatchCycleFF3: // 3600x
      case ECWatchCycleReverseFF3:
      case ECWatchCycleFF4: // 5x3600x
      case ECWatchCycleReverseFF4:
	[self advanceToNextInterval:(24 * 3600) usingEnv:env];
	break;
    }
}

// Advance to prev point (context sensitive)
-(void)advanceToPreviousUsingEnv:(ECWatchEnvironment *)env {
    switch (cycle) {
      case ECWatchCycleFF6: // 5x24x3600x
      case ECWatchCycleReverseFF6:
	[self advanceToPrevYearUsingEnv:env];
	break;

      case ECWatchCycleFF5: // 24x3600x
      case ECWatchCycleReverseFF5:
	[self advanceToPrevMonthUsingEnv:env];
	break;

      case ECWatchCycleFF2: // 60x
      case ECWatchCycleReverseFF2:
	[self advanceToPrevInterval:3600 usingEnv:env];
	break;

      case ECWatchCycleFF1: // 5x
      case ECWatchCycleReverseFF1:
	[self advanceToPrevInterval:60 usingEnv:env];
	break;

      case ECWatchCycleSlow1: // 0.1
	[self advanceToPrevInterval:1 usingEnv:env];
	break;

      case ECWatchCycleReverseSlow1:
	break;
	[self advanceToPrevInterval:1 usingEnv:env];
	break;

      default:
      case ECWatchCycleOther:
      case ECWatchCycleNormal:
      case ECWatchCyclePaused:
      case ECWatchCycleReverse:
      case ECWatchCycleFF3: // 3600x
      case ECWatchCycleReverseFF3:
      case ECWatchCycleFF4: // 5x3600x
      case ECWatchCycleReverseFF4:
	[self advanceToPrevInterval:(24 * 3600) usingEnv:env];
	break;
    }
}

-(void)advanceBySeconds:(double)numSeconds fromTime:(NSTimeInterval)startTime {
    if (!isnan(startTime)) {
	double timeSinceStartDate = [self currentTime] - startTime;
	ourTimeAtNTPZero += (numSeconds - timeSinceStartDate);
    } else {
	ourTimeAtNTPZero += numSeconds;
    }
    [self checkAndConstrainAbsoluteTime];
}

-(void)advanceByDays:(int)intDays fromTime:(NSTimeInterval)startTime usingEnv:(ECWatchEnvironment *)env { // works on DST days
    //printf("advanceByDays %d using timezone %s\n", intDays, [[[env timeZone] description] UTF8String]);
    if (isnan(startTime)) {
	startTime = [self currentTime];
    }
    NSTimeInterval sameTimeNextDay = ESCalendar_addDaysToTimeInterval(startTime, env->estz, intDays);
    [self advanceBySeconds:(sameTimeNextDay - startTime) fromTime:startTime];
}

-(void)advanceOneDayUsingEnv:(ECWatchEnvironment *)env { // works on DST days
    [self advanceByDays:1 fromTime:[self currentTime] usingEnv:env];
}

-(void)advanceByMonths:(int)intMonths fromTime:(NSTimeInterval)startTime usingEnv:(ECWatchEnvironment *)env {  // keeping day the same, unless there's no such day, in which case go to last day of month
    if (isnan(startTime)) {
	startTime = [self currentTime];
    }
    NSTimeInterval sameTimeNextMonth = ESCalendar_addMonthsToTimeInterval(startTime, env->estz, intMonths);
    [self advanceBySeconds:(sameTimeNextMonth - startTime) fromTime:startTime];
}

-(void)advanceOneMonthUsingEnv:(ECWatchEnvironment *)env {  // keeping day the same, unless there's no such day, in which case go to last day of month
    [self advanceByMonths:1 fromTime:[self currentTime] usingEnv:env];
}

-(void)advanceByYears:(int)numYears fromTime:(NSTimeInterval)startTime usingEnv:(ECWatchEnvironment *)env {   // keeping month and day the same, unless it was Feb 29, in which case move back to Feb 28
    if (isnan(startTime)) {
	startTime = [self currentTime];
    }
    NSTimeInterval sameTimeNextYear = ESCalendar_addYearsToTimeInterval(startTime, env->estz, numYears);
    [self advanceBySeconds:(sameTimeNextYear - startTime) fromTime:startTime];
}

-(void)advanceOneYearUsingEnv:(ECWatchEnvironment *)env {   // keeping month and day the same, unless it was Feb 29, in which case move back to Feb 28
    [self advanceByYears:1 fromTime:[self currentTime] usingEnv:env];
}

-(void)retardOneDayUsingEnv:(ECWatchEnvironment *)env { // works on DST days
    [self advanceByDays:-1 fromTime:[self currentTime] usingEnv:env];
}

-(void)retardOneMonthUsingEnv:(ECWatchEnvironment *)env {
    [self advanceByMonths:-1 fromTime:[self currentTime] usingEnv:env];
}

-(void)retardOneYearUsingEnv:(ECWatchEnvironment *)env {
    [self advanceByYears:-1 fromTime:[self currentTime] usingEnv:env];
}

-(void)advanceByYears:(int)numYears usingEnv:(ECWatchEnvironment *)env {
    [self advanceByYears:numYears fromTime:nan("") usingEnv:env];
}

-(void)advanceByMonths:(int)numMonths usingEnv:(ECWatchEnvironment *)env {
    [self advanceByMonths:numMonths fromTime:nan("") usingEnv:env];
}

-(void)advanceByDays:(int)numDays usingEnv:(ECWatchEnvironment *)env {
    [self advanceByDays:numDays fromTime:nan("") usingEnv:env];
}

-(void)advanceBySeconds:(double)numSeconds {
    [self advanceBySeconds:numSeconds fromTime:nan("")];
}

-(void)advanceToQuarterHourUsingEnv:(ECWatchEnvironment *)env {
    double ct = [self currentTime];
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(ct, env->estz, &cs);
    double secondsSinceHour = cs.minute * 60 + cs.seconds;
    if (secondsSinceHour < 15*60) {
	[self advanceBySeconds:(15*60 - secondsSinceHour) fromTime:nan("")];
    } else if (secondsSinceHour < 30*60) {
	[self advanceBySeconds:(30*60 - secondsSinceHour) fromTime:nan("")];
    } else if (secondsSinceHour < 45*60) {
	[self advanceBySeconds:(45*60 - secondsSinceHour) fromTime:nan("")];
    } else {
	[self advanceBySeconds:(60*60 - secondsSinceHour) fromTime:nan("")];
    }
}

-(void)retreatToQuarterHourUsingEnv:(ECWatchEnvironment *)env {
    double ct = [self currentTime];
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(ct, env->estz, &cs);
    double fudge = 0.01;
    double secondsSinceHour = cs.minute * 60 + cs.seconds - fudge;
    if (secondsSinceHour < 0) {
	secondsSinceHour += 60*60;
    }
    if (secondsSinceHour < 15*60) {
	[self advanceBySeconds:(-fudge - secondsSinceHour) fromTime:nan("")];
    } else if (secondsSinceHour < 30*60) {
	[self advanceBySeconds:(-fudge + 15*60 - secondsSinceHour) fromTime:nan("")];
    } else if (secondsSinceHour < 45*60) {
	[self advanceBySeconds:(-fudge + 30*60 - secondsSinceHour) fromTime:nan("")];
    } else {
	[self advanceBySeconds:(-fudge + 45*60 - secondsSinceHour) fromTime:nan("")];
    }
}

// *****************
// Debug methods
// *****************

// Note: The following routine adds one to the returned month and day, for readability
-(NSString *)dumpAllUsingEnv:(ECWatchEnvironment *)env {
    // Temporarily stop the watch so the values are consistent, then restore when we're done
    double oldWarp = warp;
    double oldTimeAtNTPZero = ourTimeAtNTPZero;
    ourTimeAtNTPZero = [self currentTime];
    warp = 0.0;
    const char *days[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
    NSString *returnString = [NSString stringWithFormat:@"Watch time Numbers:\n  %d/%02d/%02d %02d:%02d:%02d %s\nWatch time Values:\n   year: %5d\n  month: %10.4f\n    day: %10.4f\n hour24: %10.4f\n hour12: %10.4f\n minute: %10.4f\n second: %10.4f\nWeekday: %10.4f\n",
			       [self yearNumberUsingEnv:env],
			       [self monthNumberUsingEnv:env] + 1,
			       [self dayNumberUsingEnv:env] + 1,
			       [self hour24NumberUsingEnv:env],
			       [self minuteNumberUsingEnv:env],
			       [self secondNumberUsingEnv:env],
			       days[[self weekdayNumberUsingEnv:env]],
			       [self yearNumberUsingEnv:env],
			       [self monthValueUsingEnv:env] + 1.0,
			       [self dayValueUsingEnv:env] + 1.0,
			       [self hour24ValueUsingEnv:env],
			       [self hour12ValueUsingEnv:env],
			       [self minuteValueUsingEnv:env],
			       [self secondValueUsingEnv:env],
			       [self weekdayValueUsingEnv:env]
			      ];
    warp = oldWarp;
    ourTimeAtNTPZero = oldTimeAtNTPZero;
    return returnString;
}

@end

