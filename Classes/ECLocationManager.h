//
//  ECLocationManager.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "Constants.h"

@interface ECLocationManagerDelegate : NSObject {
}
-(void)follower;
@end

@interface ECLocationManager : NSObject <CLLocationManagerDelegate> {
    CLLocationManager   *locationManager;
    CLLocationDegrees   lastLongitudeDegrees;
    CLLocationDegrees   lastLatitudeDegrees;
#ifdef ECHEADING
    double		lastDirection;		    // in radians
#endif
    double              lastAltitudeMeters;
    double              lastHorizontalErrorMeters;
    double              lastVerticalErrorMeters;
    NSTimeInterval      lastFix;
    NSTimeInterval      requestTime;
    NSTimer             *autoCheckTimer;
    NSTimer             *requestTimer;
    bool                locationOverridden;
    bool		SIUnits;		    // normally true; false in the good old USA (used only for altitude)
    bool		active;			    // true if CLLocationManager is continuously updating
    bool		haveFirstUpdate;	    // we have received the first update
    bool		suspended;		    // true if we were active but suspended now and should reactivate later
    bool		autoCheck;		    // true only during initialization and the subsequent auto-checks
    bool		doJustOne;		    // need just one new fix
    bool		userRequested;		    // running this time in response to a user request
    bool		canceled;		    // user canceled while active
    bool                refreshing;                 // auto check
    bool                settingEnabled;             // true if our Settings defaults say to use location services
    bool		timedOut;		    // true if we didn't receive a fix in time
    int			count;			    // number of location updates received
    NSMutableDictionary *observers;
    ECLocationManagerDelegate *delegate;
}

@property (readonly, nonatomic) CLLocationDegrees lastLongitudeDegrees;
@property (readonly, nonatomic) CLLocationDegrees lastLatitudeDegrees;
@property (readonly, nonatomic) double lastAltitudeMeters, lastAltitudeLocalUnits;
@property (readonly, nonatomic) double lastLongitudeRadians;
@property (readonly, nonatomic) double lastLatitudeRadians;
@property (readonly, nonatomic) double lastHorizontalErrorMeters;
@property (readonly, nonatomic) double lastVerticalErrorMeters;
#ifdef ECHEADING
@property (readonly, nonatomic) double lastDirection;	// radians
#endif
@property (readonly, nonatomic) bool locationOverridden;
@property (readonly, nonatomic) NSTimeInterval lastFix;
@property (readonly, nonatomic) bool valid, active, settingEnabled;
@property (readwrite,nonatomic) bool SIUnits;
@property (readonly, nonatomic) int count;
@property (assign, readwrite, nonatomic) ECLocationManagerDelegate *delegate;

// Housekeeping
- (id)initGlobalManager;
- (id)initWithOverrideLatitudeDegrees:(double)latitudeDegrees longitudeDegrees:(double)longitudeDegrees;
- (void)dealloc;
- (void)notifyAllLocationChangeObservers:(bool)noError;
- (void)saveLocation;
- (void)reloadLocation;
- (void)setDelegate:(ECLocationManagerDelegate *)obj;
+ (NSString *)positionStringForLatitude:(double)lat longitude:(double)lng;
- (NSString *)positionString;
- (NSString *)positionString2;
- (NSString *)latitudeString;
- (NSString *)longitudeString;
- (NSString *)latitudeString2;
- (NSString *)longitudeString2;
- (NSString *)statusText;
- (ECLocState)indicatorState;
- (NSTimeInterval)nextFix;

// Request to be notified when any new location information comes in
- (void)addLocationChangeObserver:(id)observer
	 locationChangedSelector:(SEL)locationChangedSelector
       locationFixFailedSelector:(SEL)locationFixFailedSelector;

- (void)removeLocationChangeObserver:(id)observer;

// Request a new location fix (won't happen right away)
- (void)startIfNecessary;
- (void)stopUpdatingIfDone;
- (void)requestOneLocationFix;
- (void)requestLocationUpdates;
- (void)cancelLocationUpdates;
- (void)cancelLocationRequest;
- (void)stopUpdating;
- (void)disable;
- (void)suspend;
- (void)resume;
- (void)useBestAccuracy:(bool)best;
- (bool)accuracyIsGood;

// Set an override location, for debug or (possibly) from user input
- (void)setOverrideLocationToLatitudeRadians:(double)latitude
			    longitudeRadians:(double)longitude
			      altitudeMeters:(double)altitude
			       skipObservers:(bool)skipObservers;
- (void)setOverrideLocationToLatitudeRadians:(double)latitude
			    longitudeRadians:(double)longitude
			      altitudeMeters:(double)altitude;
- (void)setOverrideLocationToLatitudeDegrees:(double)latitude
			    longitudeDegrees:(double)longitude
			      altitudeMeters:(double)altitude
			       skipObservers:(bool)skipObservers
			     horizontalError:(double)horizontalError;
- (void)setOverrideLocationToLatitudeDegrees:(double)latitude
			    longitudeDegrees:(double)longitude
			      altitudeMeters:(double)altitude
			     horizontalError:(double)horizontalError;
- (void)setOverrideLocationToLatitudeDegrees:(double)latitude
			    longitudeDegrees:(double)longitude
			      altitudeMeters:(double)altitude;

// Get (or create and get) the singleton object
+ (ECLocationManager *)theLocationManager;

@end
