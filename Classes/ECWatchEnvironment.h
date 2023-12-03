//
//  ECWatchEnvironment.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

@class ECWatchTime;
@class ECLocationManager;
@class ECAstronomyManager;
@class ECGLWatch;

#include "ESCalendar.h"  // For opaque ESTimeZone

// *****************************************************************
// ECWatchEnvironment
//
// The watch environment contains several components, which are interdependent.
//
// The time zone is set by clients of the environment and depends on none of
// the other elements.  If unset, a default time zone object is created which
// matches that of the iPhone.
//
// The location manager is set by clients of the environment and depends on none of
// the other elements.  If unset, a single location manager shared by all such
// environments is used to report the iPhone's true location.

// The calendar is created from the time zone's current offset from GMT, and is
// recreated at DST changes, when the time zone is changed by clients, or when
// explicitly overridden by clients.
//
// The watch time is created from the calendar, and is reset when the calendar
// changes.  Resetting involves de-activating and re-activating all triggers on
// the watch time.
//
// The astronomy object depends on all four of the other elements, but has no
// cached data and doesn't need to explicitly recalculate when the elements change.
// If a VM op, for example, uses the astronomy data, it will get fresh data on a
// major change because the ECWatchTime will fire all of its triggers.  Most watch
// environment objects will not have an astronomy object.
//
// On significant time changes, there is an explicit ordering of who gets notified
// and what happens.  That ordering is controlled by the environment (this class)
// because it controls the inter-relationships among its members.  In particular,
//   The calendar is reset first to the current time zone, if necessary
//   The watch time is told to reactivate everything
//   The astronomy manager is not notified directly but will get called as dependent
//     timers fire.
// *****************************************************************

@interface ECWatchEnvironment : NSObject {
@public
    ESTimeZone         *estz;
    ECLocationManager  *locationManager;
    ECAstronomyManager *astronomyManager;
    NSString	       *cityName;
    double		latitude, longitude;

    ECWatchTime        *watchTime;   // shared among all envs for this watch; points to [watch mainTime]

    // caches for watch time it is applied to
    NSTimeInterval prevTimeForTZ, resultForTZ;	    // a really really simple cache for tzOffset
    double cacheMidnightBase, cacheDSTEvent, cacheDSTDelta;        // a kind of simple cache for midnightForDateInterval

    // Internal data
@private
    bool               observingIPhoneTime;
    bool               timeZoneIsDefault;
    ECGLWatch          *watch;
}

@property(nonatomic, readonly) ECLocationManager *locationManager;
@property(nonatomic, readonly) ECAstronomyManager *astronomyManager;
@property(nonatomic, readonly) ECWatchTime *watchTime;
@property(nonatomic, readonly) ESTimeZone *estz;
@property(nonatomic, retain) NSString *cityName;
@property(nonatomic, readonly) bool runningBackward;
@property(nonatomic, assign) double latitude, longitude;

-(id)initWithTimeZoneNamed:(NSString *)timeZoneName city:(NSString *)city forWatch:(ECGLWatch *)watch usingLocAstroFrom:(ECWatchEnvironment *)clonee locationManager:(ECLocationManager *)locationManager observingIPhoneTime:(bool)observingIPhoneTime;

-(void)setTimeZone:(ESTimeZone *)estz;
-(void)setLocationManager:(ECLocationManager *)locationManager skipObservers:(bool)skipObservers;  // Use only to override the iPhone's calculated location; nil for default (iPhone) location
-(void)clearCache;
#ifdef SHAREDCLOCK
+(bool)globalTimes;
+(void)setGlobalTimes:(bool)newVal;
#endif    
-(NSString *)timeZoneName;
+(void)lockForBGTZAccess;
+(void)unlockForBGTZAccess;
-(void)dealloc;
-(void)setNewCity:(NSString *)cityName zone:(ESTimeZone *)tz latitudeDegrees:(double)lat longitudeDegrees:(double)lng override:(bool)override;

@end
