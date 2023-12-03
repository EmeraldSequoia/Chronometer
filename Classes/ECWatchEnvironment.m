//
//  ECWatchEnvironment.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "Constants.h"
#import "ECWatchEnvironment.h"
#import "ECLocationManager.h"
#import "ECAstronomy.h"
#import "ECGLWatch.h"
#import "ChronometerAppDelegate.h"
#include "ESCalendar.h"

static NSLock *TZLock = nil;
static bool   haveTZLock = false;

@implementation ECWatchEnvironment

@synthesize watchTime, cityName, latitude, longitude;

+(ESTimeZone *)timeZoneWhenNoneSpecified {
    // [NS-TimeZone resetSystemTimeZone];  // FIX: This can apparently make systemTimeZone slow (kernel call?)
    return ESCalendar_localTimeZone();
}

-(id)initWithTimeZoneNamed:(NSString *)timeZoneName
		      city:(NSString *)city
		  forWatch:(ECGLWatch *)aWatch
	 usingLocAstroFrom:(ECWatchEnvironment *)clonee
	   locationManager:(ECLocationManager *)aLocationManager
       observingIPhoneTime:(bool)anObservingIPhoneTime {
    [super init];
    if (!TZLock) {
	TZLock = [[NSLock alloc] init];
    }
    cityName = [city retain];
    assert(timeZoneName);
    estz = ESCalendar_initTimeZoneFromOlsonID([timeZoneName UTF8String]);
    observingIPhoneTime = anObservingIPhoneTime;
    watch = aWatch;
    watchTime = [aWatch mainTime];
    if (clonee) {
	locationManager = [[clonee locationManager] retain];
	astronomyManager = [[clonee astronomyManager] retain];
    } else {
	if (aLocationManager) {
	    locationManager = [aLocationManager retain];
	} else {
	    locationManager = nil;
	}
	astronomyManager = nil;
    }
    prevTimeForTZ = 0;
    cacheMidnightBase = ECFarInThePast;
    if (observingIPhoneTime) {
	[[self locationManager] addLocationChangeObserver:self
				  locationChangedSelector:@selector(locationChanged)
				locationFixFailedSelector:@selector(locationFixFailed)];
	[ChronometerAppDelegate addObserver:self significantTimeChangeSelector:@selector(significantTimeChange:)];
    }
    return self;
}

-(id)init {
    assert(false);
    return nil;
}

-(void)dealloc {
    if (observingIPhoneTime) {
	[[self locationManager] removeLocationChangeObserver:self];
	[ChronometerAppDelegate removeObserver:self];
    }
    [astronomyManager release];
    [locationManager release];
    ESCalendar_releaseTimeZone(estz);
    [cityName release];
    [super dealloc];
}

-(void)clearCache {
    assert([NSThread isMainThread]); // else our bool haveTZLock is unreliable
    bool wasLocked = haveTZLock;
    if (!wasLocked) {
	[TZLock lock];
	haveTZLock = true;
    }
    prevTimeForTZ = 0;
    cacheMidnightBase = ECFarInThePast;
    if (!wasLocked) {
	[TZLock unlock];
	haveTZLock = false;
    }
}

-(void)handleNewTimeZone {
    assert([NSThread isMainThread]); // else our bool haveTZLock is unreliable
    bool wasLocked = haveTZLock;
    if (!wasLocked) {
	[TZLock lock];
	haveTZLock = true;
    }
    [self clearCache];
    if (!wasLocked) {
	[TZLock unlock];
	haveTZLock = false;
    }
}

-(void)setTimeZone:(ESTimeZone *)newTimeZone {  // Note: NOT for DST changes; a single time zone can handle DST and not DST
    assert([NSThread isMainThread]); // else our bool haveTZLock is unreliable
    bool wasLocked = haveTZLock;
    if (!wasLocked) {
	[TZLock lock];
	haveTZLock = true;
    }
    ESCalendar_releaseTimeZone(estz);
    if (newTimeZone) {
	estz = ESCalendar_retainTimeZone(newTimeZone);
	timeZoneIsDefault = false;
    } else {
	assert(observingIPhoneTime);
	estz = ESCalendar_retainTimeZone([ECWatchEnvironment timeZoneWhenNoneSpecified]);
	timeZoneIsDefault = true;
    }
    [self handleNewTimeZone];
    if (!wasLocked) {
	[TZLock unlock];
	haveTZLock = false;
    }
}

-(void)setNewCity:(NSString *)city zone:(ESTimeZone *)tz latitudeDegrees:(double)lat longitudeDegrees:(double)lng override:(bool)override {
    if (override) {
	[locationManager setOverrideLocationToLatitudeDegrees:lat longitudeDegrees:lng altitudeMeters:[locationManager lastAltitudeMeters]];    // noop if no locationManger exists
    }
    self.cityName = [city retain];
    [self setTimeZone:tz];
    latitude = lat;
    longitude = lng;
}

-(void)significantTimeChange:(id)ignored {
    // Assume the worst:  TZ changed
    assert([NSThread isMainThread]); // else our bool haveTZLock is unreliable
    bool wasLocked = haveTZLock;
    if (!wasLocked) {
	[TZLock lock];
	haveTZLock = true;
    }
    if (timeZoneIsDefault) {
	ESCalendar_releaseTimeZone(estz);
	assert(observingIPhoneTime);
	estz = ESCalendar_retainTimeZone([ECWatchEnvironment timeZoneWhenNoneSpecified]);
    }
    // New tz, or time zone might have changed to/from DST, means calendar might also change
    [self handleNewTimeZone];
    if (!wasLocked) {
	[TZLock unlock];
	haveTZLock = false;
    }
}

-(void)setLocationManager:(ECLocationManager *)locMgr skipObservers:(bool)skipObservers {  // Use only to override the iPhone's calculated location
    [locationManager release];
    locationManager = [locMgr retain];
    if (!skipObservers) {
	[self significantTimeChange:nil];
    }
}

-(void)locationChanged {
    // Update our internal data
    assert([NSThread isMainThread]);
    [self significantTimeChange:nil];
}

-(void)locationFixFailed {
    // Do nothing?
}

-(ESTimeZone *)estz {
    return estz;
}

-(NSString *)timeZoneName {
    return [NSString stringWithCString:ESCalendar_timeZoneName(estz) encoding:NSUTF8StringEncoding];
}

-(ECLocationManager *)locationManager {
    if (locationManager) {
	return locationManager;
    } else {
	return [ECLocationManager theLocationManager];
    }
}

-(ECAstronomyManager *)astronomyManager {
    if (!astronomyManager) {
	astronomyManager = [[ECAstronomyManager alloc] initFromEnvironment:self watchTime:watchTime];
    }
    return astronomyManager;
}

-(bool)runningBackward {
    return [watch runningBackward];
}

+(void)lockForBGTZAccess {
    assert(![NSThread isMainThread]);  // Otherwise we have serious issues with recursive locks
    [TZLock lock];
}

+(void)unlockForBGTZAccess {
    assert(![NSThread isMainThread]);  // Otherwise we have serious issues with recursive locks
    [TZLock unlock];
}

#ifdef SHAREDCLOCK
+(bool)globalTimes {
    return globalTimes;
}

+(void)setGlobalTimes:(bool)newVal {
    globalTimes = newVal;
    [ChronometerAppDelegate forceUpdateInMainThread];
    [[NSUserDefaults standardUserDefaults] setBool:globalTimes forKey:@"ECUseSharedClock"];
}
#endif

@end
