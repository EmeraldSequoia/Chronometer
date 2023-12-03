//
//  ECDynamicUpdate.h
//  Emerald Chronometer
//
//  Created by Steve Pucci Aug 2008
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ECDynamicUpdate.h"
#import "ECWatchTime.h"
#import "ECWatchEnvironment.h"
#import "ECLocationManager.h"
#import "ECAstronomy.h"
#import "ECTS.h"
#import "ChronometerAppDelegate.h"
#import "Constants.h"

@implementation ECDynamicUpdate

static NSTimeInterval calculateNextSunriseForEnvironment(ECWatchEnvironment *watchEnvironment) {
    return [[watchEnvironment astronomyManager] nextSunrise];
}

static NSTimeInterval calculateNextSunsetForEnvironment(ECWatchEnvironment *watchEnvironment) {
    return [[watchEnvironment astronomyManager] nextSunset];
}

static NSTimeInterval calculateNextMoonriseForEnvironment(ECWatchEnvironment *watchEnvironment) {
    return [[watchEnvironment astronomyManager] nextMoonrise];
}

static NSTimeInterval calculateNextMoonsetForEnvironment(ECWatchEnvironment *watchEnvironment) {
    return [[watchEnvironment astronomyManager] nextMoonset];
}

static NSTimeInterval calculateNextSunriseOrSunsetForEnvironment(ECWatchEnvironment *watchEnvironment) {
    NSTimeInterval sunrise = [[watchEnvironment astronomyManager] nextSunrise];
    NSTimeInterval sunset  = [[watchEnvironment astronomyManager] nextSunset];
    if ([watchEnvironment runningBackward]) {
	return sunrise > sunset ? sunrise : sunset;
    } else {
	return sunrise < sunset ? sunrise : sunset;
    }
}

static NSTimeInterval calculateNextMoonriseOrMoonsetForEnvironment(ECWatchEnvironment *watchEnvironment) {
    NSTimeInterval moonrise = [[watchEnvironment astronomyManager] nextMoonrise];
    NSTimeInterval moonset  = [[watchEnvironment astronomyManager] nextMoonset];
    if ([watchEnvironment runningBackward]) {
	return moonrise > moonset ? moonrise : moonset;
    } else {
	return moonrise < moonset ? moonrise : moonset;
    }
}

static NSTimeInterval calculateNextSunriseOrMidnightForEnvironment(ECWatchEnvironment *watchEnvironment) {
    return [[watchEnvironment astronomyManager] nextSunriseOrMidnight];
}

static NSTimeInterval calculateNextSunsetOrMidnightForEnvironment(ECWatchEnvironment *watchEnvironment) {
    return [[watchEnvironment astronomyManager] nextSunsetOrMidnight];
}

static NSTimeInterval calculateNextMoonriseOrMidnightForEnvironment(ECWatchEnvironment *watchEnvironment) {
    return [[watchEnvironment astronomyManager] nextMoonriseOrMidnight];
}

static NSTimeInterval calculateNextMoonsetOrMidnightForEnvironment(ECWatchEnvironment *watchEnvironment) {
    return [[watchEnvironment astronomyManager] nextMoonsetOrMidnight];
}

static NSTimeInterval calculateNextTimeSyncIndicatorMotion(ECWatchEnvironment *watchEnvironment) {
    if ([ECTS active]) {
	return [[watchEnvironment watchTime] currentTime] + ECStatusIndicatorBlinkRate;
    } else {
	return ECFarInTheFuture;
    }
}

static NSTimeInterval calculateNextLocSyncIndicatorMotion(ECWatchEnvironment *watchEnvironment) {
    if ([[watchEnvironment locationManager] active]) {
	return [[watchEnvironment watchTime] currentTime] + ECStatusIndicatorBlinkRate;
    } else {
	return ECFarInTheFuture;
    }
}

static NSTimeInterval calculateNextDSTChangeForEnvironment(ECWatchEnvironment *watchEnvironment) {
    ECWatchTime *watchTime = [watchEnvironment watchTime];
    NSTimeInterval returnTime;
    if ([watchTime runningBackward]) {
	returnTime = [watchTime prevDSTChangePrecisely:false usingEnv:watchEnvironment];
	if (!returnTime) { // no DST
	    returnTime = ECFarInThePast;
	}
    } else {
	returnTime = [watchTime nextDSTChangeUsingEnv:watchEnvironment];
	if (!returnTime) {  // no DST
	    returnTime = ECFarInTheFuture;
	}
    }
    return returnTime;
}

typedef NSTimeInterval (*ECDynamicUpdaterFn)(ECWatchEnvironment *);

+ (ECDynamicUpdaterFn)getUpdateCalculatorForInterval:(double)negativeUpdateInterval {
    ECDynamicUpdateSpecifier spec = (ECDynamicUpdateSpecifier)lrint(negativeUpdateInterval);
    switch(spec) {
      case ECDynamicUpdateNextSunrise:
	return calculateNextSunriseForEnvironment;
      case ECDynamicUpdateNextSunset:
	return calculateNextSunsetForEnvironment;
      case ECDynamicUpdateNextMoonrise:
	return calculateNextMoonriseForEnvironment;
      case ECDynamicUpdateNextMoonset:
	return calculateNextMoonsetForEnvironment;
      case ECDynamicUpdateNextSunriseOrSunset:
	return calculateNextSunriseOrSunsetForEnvironment;
      case ECDynamicUpdateNextMoonriseOrMoonset:
	return calculateNextMoonriseOrMoonsetForEnvironment;
      case ECDynamicUpdateNextSunriseOrMidnight:
	return calculateNextSunriseOrMidnightForEnvironment;
      case ECDynamicUpdateNextSunsetOrMidnight:
	return calculateNextSunsetOrMidnightForEnvironment;
      case ECDynamicUpdateNextMoonriseOrMidnight:
	return calculateNextMoonriseOrMidnightForEnvironment;
      case ECDynamicUpdateNextMoonsetOrMidnight:
	return calculateNextMoonsetOrMidnightForEnvironment;
      case ECDynamicUpdateNextDSTChange:	// == ECDynamicUpdateNextEnvChange
	return calculateNextDSTChangeForEnvironment;
      case ECDynamicUpdateLocSyncIndicator:
	return calculateNextLocSyncIndicatorMotion;
      case ECDynamicUpdateTimeSyncIndicator:
	return calculateNextTimeSyncIndicatorMotion;
      default:
	return NULL;
    }
}

static NSTimeInterval onEvenTime(double t, double interval, double offset) {
    NSTimeInterval nt = (((floor(t / interval)) * interval) + offset);
    if (nt <= t) {
	nt += interval;
    }
    return nt;
}

static NSTimeInterval onEvenTimeBack(double t, double interval, double offset) {
    NSTimeInterval nt = (((floor(t / interval)) * interval) + offset);
    if (nt >= t) {
	nt -= interval;
    }
    return nt;
}

// Note: This method returns the iPhone time (not the ECWatchTime time nor the NTP time)
// at which a part in the given watch, in the given environment, should be next updated,
// given the part's declared interval and intervalOffset.
+ (NSTimeInterval)getNextUpdateTimeForInterval:(double)interval
				     andOffset:(double)intervalOffset
				    startingAt:(NSTimeInterval)startTime
				forEnvironment:(ECWatchEnvironment *)environment
				     watchTime:(ECWatchTime *)watchTime {
    if (interval == 0) {
	return ECFarInTheFuture;
    }
    double warp = [watchTime warp];  // Note: the watchTime passed in may not be [environment watchTime] if it's a stopwatch time
    if (warp == 0) {
	return ECFarInTheFuture;  // watch is stopped; no need to update
    }

    double requestedUpdateTime = ECFarInTheFuture;
    if (interval < 0) {
	assert(watchTime == [environment watchTime]);  // If this assert ever legitimately triggers, then we need to pass in watchTime to the update calculators
	ECDynamicUpdaterFn nextUpdateCalculator = [self getUpdateCalculatorForInterval:interval];
	if (nextUpdateCalculator) {
	    requestedUpdateTime = [watchTime convertFromWatchToIPhone:(*nextUpdateCalculator)(environment)];
	    //printf("update at %s for interval %g, offset %g: %s\n",
	    //   [[[NSDate dateWithTimeIntervalSinceReferenceDate:startTime] description] UTF8String],
	    //   interval, intervalOffset,
	    //   [[[NSDate dateWithTimeIntervalSinceReferenceDate:requestedUpdateTime] description] UTF8String]);
	} else {
	    assert(false);	    // should be prevented by ECWatchDefinitionManager checking
	}
    } else {
	double actualFiringInterval;
	double actualFiringOffset;
	if (warp > 0) {
	    actualFiringInterval = ceil(interval / warp / kECTimerResolutionInSeconds) * kECTimerResolutionInSeconds;
	    double roundedRequestedInterval = actualFiringInterval * warp;
	    double q1 = (intervalOffset - [watchTime ourTimeAtIPhoneZero] - [watchTime tzOffsetUsingEnv:environment])/roundedRequestedInterval;
	    double q2 = (q1 - floor(q1)) * roundedRequestedInterval;
	    actualFiringOffset = q2 / warp;
	} else { // negative warp
	    actualFiringInterval = ceil(interval / (-warp) / kECTimerResolutionInSeconds) * kECTimerResolutionInSeconds;
	    double roundedRequestedInterval = actualFiringInterval * (-warp);
	    double q1 = ([watchTime ourTimeAtIPhoneZero] + [watchTime tzOffsetUsingEnv:environment] - intervalOffset)/roundedRequestedInterval;
	    double q2 = (q1 - floor(q1)) * roundedRequestedInterval;
	    actualFiringOffset = q2 / (-warp);
	}
        NSTimeInterval snappedIPhoneTime = [watchTime convertFromWatchToIPhone:[watchTime currentTime]];
	requestedUpdateTime = (warp > 0 ? &onEvenTime : &onEvenTimeBack)(snappedIPhoneTime, actualFiringInterval, actualFiringOffset);
	//printf("update at %s for interval %g, offset %g, actualInterval %g, actualOffset %g: %s\n",
	//      [[[NSDate dateWithTimeIntervalSinceReferenceDate:startTime] description] UTF8String],
	//     interval, intervalOffset, actualFiringInterval, actualFiringOffset,
	//     [[[NSDate dateWithTimeIntervalSinceReferenceDate:requestedUpdateTime] description] UTF8String]);
    }
    return requestedUpdateTime;
}

@end
