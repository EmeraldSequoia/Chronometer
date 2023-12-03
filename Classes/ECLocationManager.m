//
//  ECLocationManager.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "Constants.h"
#undef ECTRACE
#import "ECTrace.h"
#import "ECOptions.h"
#import "ECLocationManager.h"
#import "ECAddressKey.h"
#import "ECErrorReporter.h"
#import "ChronometerAppDelegate.h"
#import "ECBackgroundData.h"

static ECLocationManager *theLocationManager = nil;

// This is really a protocol.
@implementation ECLocationManagerDelegate
-(void) follower {}
@end

@interface ECLocationManagerObserverDescriptor : NSObject {
    id   observer;
    SEL  locationChangedSelector;
    SEL  locationFixFailedSelector;
}

@property (nonatomic, retain) id observer;
@property (nonatomic) SEL locationChangedSelector;
@property (nonatomic) SEL locationFixFailedSelector;

@end

@implementation ECLocationManagerObserverDescriptor

@synthesize observer;
@synthesize locationChangedSelector;
@synthesize locationFixFailedSelector;

@end

@interface ECLocationManager (ECLocationManagerPrivate)

- (void)notifyAllLocationChangeObservers;

@end

@implementation ECLocationManager

@synthesize SIUnits, active, settingEnabled, count, lastLongitudeDegrees, lastLatitudeDegrees, lastAltitudeMeters, lastHorizontalErrorMeters, lastVerticalErrorMeters, lastFix;
@synthesize delegate;
#ifdef ECHEADING
@synthesize lastDirection;
#endif

- (void)setDelegate:(ECLocationManagerDelegate *)obj {
    assert(delegate == nil || obj == nil);
    delegate = obj;
}
static bool warned = false;

- (bool)validLatitude:(double)latitude longitude:(double)longitude {
    if (!warned) {
	if (fabs(latitude) > M_PI/2 || fabs(longitude) > M_PI) {
	    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Your location (%g,%g) appears to be invalid.  Turn on Location Services or use Settings to enter a valid one.", latitude*180/M_PI, longitude*180/M_PI]];
	    warned = true;
	    return false;
	}
    }
    return true;
}

- (void)autoTimeLimit: (NSTimer *)t {
    if (autoCheck) {
	if (userRequested) {
	    tracePrintf("Not stopping: userRequested true");
	} else {
	    tracePrintf("Stopping because autoCheck timed out");
	    [self stopUpdating];
	    timedOut = true;
	}
    } else {
	tracePrintf("Not stopping; autoCheck false");
    }

}

- (void)requestTimeLimit: (NSTimer *)t {
    traceEnter("requestTimeLimit");
    if (doJustOne) {
	tracePrintf("Stopping because request timed out");
	[self stopUpdating];
	timedOut = true;
    } else {
	tracePrintf("Not stopping: doJustOne false");
    }
    requestTimer = nil;
    traceExit("requestTimeLimit");
}

- (NSTimeInterval)nextFix {
    return [[autoCheckTimer fireDate] timeIntervalSinceReferenceDate];
}

- (void)autoCheck: (NSTimer *)t {
    traceEnter ("autoCheck");
    assert(t == autoCheckTimer);
    autoCheckTimer = nil;
    // if you change these constants:  assert(ECLocationAutoCheckTimeout < ECLocationFixLifetime+10);
    if (!active && [CLLocationManager locationServicesEnabled] && [[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseLocationServices"]) {
	tracePrintf("starting CLLocationManager");
	[locationManager startUpdatingLocation];
#ifdef ECHEADING
	[locationManager startUpdatingHeading];
#endif
	//[ChronometerAppDelegate noteTimeAtPhase:"LM active"];
	active = true;
	autoCheck = true;
	doJustOne = false;
	userRequested = false;
	refreshing = true;
	canceled = false;

	// Give up after a while
	timedOut = false;
	[NSTimer scheduledTimerWithTimeInterval:ECLocationAutoCheckTimeout target:self selector:@selector(autoTimeLimit:) userInfo:nil repeats:false];

	// notify our observers
	[self notifyAllLocationChangeObservers:true];
    }
    traceExit("autoCheck");
}

- (void)submitAutoCheckTimerForFix {
    if (autoCheckTimer) {
	[autoCheckTimer invalidate];
    }
    NSTimeInterval expiryTime = lastFix + ECLocationFixLifetime;
    NSTimeInterval timeRemaining = expiryTime - [NSDate timeIntervalSinceReferenceDate];
    if (timeRemaining < 0) {
	timeRemaining = ECLocationFixLifetime;
    }
    timeRemaining -= ECLocationAutoCheckTimeout;  // give us time to actually get another fix before we expire
    if (timeRemaining < 0) {
	timeRemaining = 2;  // 2-second delay between auto-submits while in the region where it's not quite expired but it's still not valid
    }
    tracePrintf1("submitAutoCheckTimerForFix for %.2f seconds", timeRemaining);
    timedOut = false;
    autoCheckTimer = [NSTimer scheduledTimerWithTimeInterval:timeRemaining target:self selector:@selector(autoCheck:) userInfo:nil repeats:NO];
}

- (void)startIfNecessary {
    traceEnter ("startIfNecessary");
    if (settingEnabled) {
	tracePrintf("nothing to do");
    } else {
	tracePrintf("starting CLLocationManager");
	[locationManager startUpdatingLocation];
#ifdef ECHEADING
	[locationManager startUpdatingHeading];
#endif
	//[ChronometerAppDelegate noteTimeAtPhase:"LM active"];
	settingEnabled = true;
	active = true;
	suspended = false;
	doJustOne = false;
	userRequested = false;
	autoCheck = true;
	refreshing = false;
	haveFirstUpdate = false;
	
	// Give up after a while
	timedOut = false;
	[NSTimer scheduledTimerWithTimeInterval:ECLocationAutoCheckTimeout target:self selector:@selector(autoTimeLimit:) userInfo:nil repeats:false];
	
	[self submitAutoCheckTimerForFix];
    }
    traceExit("startIfNecessary");
}

- (ECLocationManager *)initGlobalManager {
    traceEnter ("initGlobalManager");
    if (self = [super init]) {
        tracePrintf("super init ok");
        theLocationManager = self;
	observers = [[NSMutableDictionary alloc] initWithCapacity:2];
	// get value from last run or user input
	lastFix = 0;
	haveFirstUpdate = false;
	lastHorizontalErrorMeters = -1;	    // invalid
	requestTimer = autoCheckTimer = nil;
	[self reloadLocation];

	// create the CLLocationManager (even if we don't need it initially)
	locationManager = [[CLLocationManager alloc] init];
        if ([locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
            [locationManager requestWhenInUseAuthorization];
        }
	locationManager.delegate = self;
        locationManager.desiredAccuracy = kCLLocationAccuracyBest;
	locationManager.distanceFilter  = kCLDistanceFilterNone;
#ifdef ECHEADING
	locationManager.headingFilter = 1;	    // degrees
#endif

	// start the real updates (unless specifically disabled)
	settingEnabled = false;
	NSString *useLS = [[NSUserDefaults standardUserDefaults] stringForKey:@"ECUseLocationServices"];
	bool val = [[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseLocationServices"];
	if ([CLLocationManager locationServicesEnabled] && (useLS == nil || [useLS caseInsensitiveCompare:@"use"] == NSOrderedSame || val)) {
	    [self startIfNecessary];	// and it will be this time
	}
    }
    traceExit("initGlobalManager");
    return self;
}

- (id)initWithOverrideLatitudeDegrees:(double)latitudeDegrees longitudeDegrees:(double)longitudeDegrees {
    [super init];
    observers = nil;
    lastFix = 0;
    haveFirstUpdate = false;
    lastHorizontalErrorMeters = -1;	    // invalid
    requestTimer = autoCheckTimer = nil;
    locationManager = nil;
    settingEnabled = false;
    [self setOverrideLocationToLatitudeDegrees:latitudeDegrees longitudeDegrees:longitudeDegrees altitudeMeters:0 skipObservers:true horizontalError:ECDefaultHorizontalError];
    return self;
}

- (id)init {
    [super init];
    assert(false);
    return self;
}

- (void)dealloc {
    [locationManager release];
    [observers release];
    [super dealloc];
}

-(double)lastLongitudeRadians {
    return lastLongitudeDegrees * M_PI / 180;
}

- (double)lastLatitudeRadians {
    return lastLatitudeDegrees * M_PI / 180;
}

- (CLLocationDistance)lastAltitudeLocalUnits {
    return lastAltitudeMeters * (SIUnits ? 1 : 3.2808399);
}

- (void)setSIUnits:(bool)newVal {
    SIUnits = newVal;
    [self notifyAllLocationChangeObservers:true];    
    [self saveLocation];
}

- (bool)locationOverridden {
    return locationOverridden;
}

- (bool)accuracyIsGood {
    return (locationOverridden || (lastHorizontalErrorMeters > 0 && lastHorizontalErrorMeters < ECDefaultHorizontalError));
}

- (bool)valid {
    if (lastHorizontalErrorMeters < 0) {
	return false;
    }
    double longitude = [self lastLongitudeRadians];
    double latitude = [self lastLatitudeRadians];
    bool v = fabs(latitude)  > 0.0000001 || 
	     fabs(longitude) > 0.0000001 ||
	(latitude == 0 && longitude == 0);
    return v;
}

- (void)reloadLocation {
    if (self == theLocationManager) {
	SIUnits =  [[NSUserDefaults standardUserDefaults] boolForKey:@"ECSIUnits"];
	NSString *latitude =  [[NSUserDefaults standardUserDefaults] stringForKey:@"ECLastLatitude"];
	NSString *longitude = [[NSUserDefaults standardUserDefaults] stringForKey:@"ECLastLongitude"];
	NSString *altitude =  [[NSUserDefaults standardUserDefaults] stringForKey:@"ECLastAlt"];
	[self setOverrideLocationToLatitudeDegrees:[latitude doubleValue]
				  longitudeDegrees: [longitude doubleValue]
				    altitudeMeters:[altitude doubleValue]
					    horizontalError:ECDefaultHorizontalError];
    }
}

- (void)saveLocation {
    if (self == theLocationManager) {
	NSString *latitude =  [NSString stringWithFormat:@"%.5f", [self lastLatitudeDegrees]];
	NSString *longitude = [NSString stringWithFormat:@"%.5f", [self lastLongitudeDegrees]];
	NSString *altitude =  [NSString stringWithFormat:@"%.5f", [self lastAltitudeMeters]];
	[[NSUserDefaults standardUserDefaults] setObject:latitude forKey:@"ECLastLatitude"];
	[[NSUserDefaults standardUserDefaults] setObject:longitude forKey:@"ECLastLongitude"];
	[[NSUserDefaults standardUserDefaults] setObject:altitude forKey:@"ECLastAlt"];
	[[NSUserDefaults standardUserDefaults] setBool:SIUnits forKey:@"ECSIUnits"];
    }
}

- (void)locationManager:(CLLocationManager *)manager
didUpdateToMostRecentLocation:(CLLocation *)newLocation {
    assert([NSThread isMainThread]);
    traceEnter("didUpdateToLocation");
    if (newLocation.horizontalAccuracy >= 0) {
	double prevLongitudeDegrees = lastLongitudeDegrees;
	double prevLatitudeDegrees = lastLatitudeDegrees;
	++count;
	// Update our internal data with the latest value
	lastLongitudeDegrees = newLocation.coordinate.longitude;
	lastLatitudeDegrees = newLocation.coordinate.latitude;
	lastHorizontalErrorMeters = newLocation.horizontalAccuracy;
	lastAltitudeMeters = newLocation.altitude;
	lastVerticalErrorMeters = newLocation.verticalAccuracy;
	lastFix = [newLocation.timestamp timeIntervalSinceReferenceDate];
	locationOverridden = false;
	tracePrintf3("lat=%.8f, long=%.8f; %.6f secs ago", lastLatitudeDegrees, lastLongitudeDegrees, [NSDate timeIntervalSinceReferenceDate] - lastFix);
	
	if (userRequested) {
#if 0
	    [ChronometerAppDelegate showECStatusMessage:[self positionString]];
#endif
	    [ChronometerAppDelegate showECLocationStatus];
	}
	[ChronometerAppDelegate forceUpdateInMainThread];	    // make sure status indicator is updated in all cases
	
#if 0
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	[ChronometerAppDelegate noteTimeAtPhaseWithString:[NSString stringWithFormat:@"loc event, autoCheck %s, doJustOne %s, lastFix %.2f secs ago, requestTime %.2f secs ago",
								    autoCheck ? "true" : "false",
								    doJustOne ? "true" : "false",
								    now - lastFix,
								    now - requestTime]];
#endif
	// stop trying (and save some energy) if this just the first time; a rough position good enough for ECAstronomy
	[self stopUpdatingIfDone];	
	[self saveLocation];
#ifndef NDEBUG
	//printf("didUpdateToLocation: (%9.7f,%10.7f) ±%g,%g\n", lastLatitudeDegrees, lastLongitudeDegrees, lastHorizontalErrorMeters, lastVerticalErrorMeters);
#endif
	// notify our "delegate", too
	if (delegate) {
	    [delegate performSelector:@selector(follower)];
	} else {
	    if (!haveFirstUpdate || fabs(lastLatitudeDegrees-prevLatitudeDegrees)+fabs(prevLongitudeDegrees-lastLongitudeDegrees) > 0.01) {	    // if we've moved more than about a kilometer
		[ECOptions setCurrentCityUnknownIfAuto:[NSString stringWithFormat:@"%@ location", [[UIDevice currentDevice] localizedModel]]	    // then the last city name is uncertain
						region:[self positionString2]];
	    }
	}
	haveFirstUpdate = true;
    } else {
	// it's not valid
    }
    traceExit ("didUpdateToLocation");
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations {
    [self locationManager:manager didUpdateToMostRecentLocation:[locations lastObject]];
}

#ifdef ECHEADING
- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    lastDirection = newHeading.trueHeading * M_PI/180;		// radians
    [ChronometerAppDelegate forceUpdateInMainThread];
}
#endif

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    traceEnter("locationManager::didFailWithError");
    // Do nothing to our internal data -- our last known location is better than nothing.

    // But notify our observers in case someone wants to put up a message
    [self notifyAllLocationChangeObservers:false];
    // notify delegate?

    if (error.code == kCLErrorDenied) {
	tracePrintf("Stopping because we got an error");
	[self stopUpdating];
    } else if (error.code == kCLErrorLocationUnknown) {
	tracePrintf("unable to get a location fix");
    } else {
        tracePrintf1("code=%ld", (long)error.code);
    }
    traceExit ("locationManager::didFailWithError");
}

- (void)addLocationChangeObserver:(id)observer
	 locationChangedSelector:(SEL)locationChangedSelector
       locationFixFailedSelector:(SEL)locationFixFailedSelector {
    //printf("Adding location change observer %s\n", [NSThread isMainThread] ? "in main thread" : "in sub thread");
    assert([NSThread isMainThread]);  // otherwise we'll have conflicts with the observers hash
    [observer retain];
    ECLocationManagerObserverDescriptor *descriptor = [[ECLocationManagerObserverDescriptor alloc] init];
    descriptor.observer = observer;
    descriptor.locationChangedSelector = locationChangedSelector;
    descriptor.locationFixFailedSelector = locationFixFailedSelector;
    [observers setObject:descriptor forKey:[ECAddressKey keyForAddress:observer]];
    [descriptor release];
}

- (void)removeLocationChangeObserver:(id)observer {
    [observers removeObjectForKey:[ECAddressKey keyForAddress:observer]];
    [observer release];
}

- (void)notifyAllLocationChangeObservers:(bool)noError {
    for (ECAddressKey *addressKey in observers) {
	ECLocationManagerObserverDescriptor *descriptor = [observers objectForKey:addressKey];
	if (noError) {
	    [descriptor.observer performSelector:descriptor.locationChangedSelector];
	} else {
	    [descriptor.observer performSelector:descriptor.locationFixFailedSelector];
	}
    }
    [ECBackgroundData refresh];
}

- (void)requestLocationUpdates {
    traceEnter ("requestLocationUpdates");
    if ([CLLocationManager locationServicesEnabled]) {
	tracePrintf("starting CLLocationManager");
	[locationManager startUpdatingLocation];
#ifdef ECHEADING
	[locationManager startUpdatingHeading];
#endif
	//[ChronometerAppDelegate noteTimeAtPhase:"LM active"];
	active = true;
	userRequested = true;
	canceled = false;
	autoCheck = false;
	doJustOne = false;
	requestTime = [NSDate timeIntervalSinceReferenceDate];
	// notify our observers
	[self notifyAllLocationChangeObservers:true];
    }
    [ChronometerAppDelegate showECLocationStatus];
    traceExit("requestLocationUpdates");
}

- (void)requestOneLocationFix {
    traceEnter ("requestOneLocationFix");
    if ([CLLocationManager locationServicesEnabled]) {
	tracePrintf("starting CLLocationManager");
	[locationManager startUpdatingLocation];
#ifdef ECHEADING
	[locationManager startUpdatingHeading];
#endif
	//[ChronometerAppDelegate noteTimeAtPhase:"LM active"];
	active = true;
	canceled = false;
	userRequested = true;
	doJustOne = true;
	requestTime = [NSDate timeIntervalSinceReferenceDate];
	autoCheck = false;
	// notify our observers
	[self notifyAllLocationChangeObservers:true];
	
	// Give up after a while
	if (requestTimer != nil) {
	    [requestTimer invalidate];
	}
	timedOut = false;
	requestTimer = [NSTimer scheduledTimerWithTimeInterval:ECLocationRequestCheckTimeout target:self selector:@selector(requestTimeLimit:) userInfo:nil repeats:false];
    }
    [ChronometerAppDelegate showECLocationStatus];
    traceExit("requestOneLocationFix");
}

- (void)cancelLocationUpdates {
    traceEnter ("cancelLocationUpdates");
    if (active && !doJustOne) {
	tracePrintf("turning off autocheck and turning on doJustOne");
	doJustOne = true;
	autoCheck = false;
    }
    if (active) {
	[self stopUpdatingIfDone];
    }
    if (active) {
	tracePrintf("scheduling another requestTimeLimit");
	// maybe get another location update but give up after a short while
	if (requestTimer != nil) {
	    [requestTimer invalidate];
	}
	timedOut = false;
	requestTimer = [NSTimer scheduledTimerWithTimeInterval:ECLocationRequestCheckTimeout target:self selector:@selector(requestTimeLimit:) userInfo:nil repeats:false];
    }
    traceExit("cancelLocationUpdates");
}

- (void)cancelLocationRequest {
    canceled = true;
    //printf("stopping because we were canceled\n");
    [self stopUpdating];
}

- (NSString *)statusText {
    if (active) {
	if (refreshing) {
	    return NSLocalizedString(@"Location\nrefreshing...", @"Location services active");
	} else if (doJustOne) {
	    return NSLocalizedString(@"Location\nfinding...", @"Location services temporarily active");
	} else {
	    return NSLocalizedString(@"Location\nupdating...", @"Location services continuous updating");
	}
    } else if (![CLLocationManager locationServicesEnabled]) {
	return NSLocalizedString(@"Location\nServices OFF", @"Location Services OFF");
    } else if (locationOverridden && !timedOut) {
	return NSLocalizedString(@"Location\nmanual", @"Location Services OFF, manual setting only");
//    } else if (canceled) {
//	return NSLocalizedString(@"Location\nfix canceled", @"Location\nfix canceled");
    } else if ([self valid] && !timedOut) {
	if ([NSDate timeIntervalSinceReferenceDate] - lastFix < ECLocationFixLifetime) {
	    return NSLocalizedString(@"Location\nestablished", @"good Location data acquired");		// [NSString stringWithFormat:@"Location fix ±%d m", (int)lastHorizontalErrorMeters];
	} else {
	    return NSLocalizedString(@"Location\nout of date", @"Location date out of date");		// [NSString stringWithFormat:@"Location fix ±%d m", (int)lastHorizontalErrorMeters];
	}
    } else {
	return NSLocalizedString(@"Location\nuncertain", @"no good location data");
    }
}

- (ECLocState)indicatorState {
    if (active && userRequested) {
	return [NSDate timeIntervalSinceReferenceDate] - lastFix < ECLocationFixLifetime ? ECLocWorkingGood : ECLocWorkingUncertain;
    }
    if (locationOverridden) {
	return ECLocManual;
//    } else if (canceled) {
//	return ECLocCanceled;
    } else if ([self valid] && [NSDate timeIntervalSinceReferenceDate] - lastFix < ECLocationFixLifetime) {
	return active ? ECLocWorkingGood : ECLocGood;
    } else {
	return active ? ECLocWorkingUncertain : ECLocUncertain;
    }
}

- (NSString *)positionString {
    return [NSString stringWithFormat:@"%@ ±%d m", [self positionString2], (int)lastHorizontalErrorMeters];
}

+ (NSString *)positionStringForLatitude:(double)lat longitude:(double)lng {
    int latd = floor(fabs(lat));
    int latm = floor((fabs(lat) - latd)*60);
    double lats = (fabs(lat) - latd - latm/60.0)*3600;
    NSString *ns = lat >= 0 ? @"N" : @"S";
    int longd = floor(fabs(lng));
    int longm = floor((fabs(lng) - longd)*60);
    double longs = (fabs(lng) - longd - longm/60.0)*3600;
    NSString *ew = lng >= 0 ? @"E" : @"W";
    return [NSString stringWithFormat:@"%d° %d' %2.0f\" %@, %d° %d' %3.1f\" %@", latd, latm, lats, ns, longd, longm, longs, ew];
}

- (NSString *)positionString2 {
    return [ECLocationManager positionStringForLatitude:lastLatitudeDegrees longitude:lastLongitudeDegrees];
}

- (NSString *)latitudeString {
    int latd = floor(fabs(lastLatitudeDegrees));
    int latm = floor((fabs(lastLatitudeDegrees) - latd)*60);
    double lats = (fabs(lastLatitudeDegrees) - latd - latm/60.0)*3600;
    NSString *ns = lastLatitudeDegrees >= 0 ? @"N" : @"S";
    return [NSString stringWithFormat:@"%d&deg; %d&prime; %2.0f&Prime; %@", latd, latm, lats, ns];
}

- (NSString *)longitudeString {
    int longd = floor(fabs(lastLongitudeDegrees));
    int longm = floor((fabs(lastLongitudeDegrees) - longd)*60);
    double longs = (fabs(lastLongitudeDegrees) - longd - longm/60.0)*3600;
    NSString *ew = lastLongitudeDegrees >= 0 ? @"E" : @"W";
    return [NSString stringWithFormat:@"%d&deg; %d&prime; %2.0f&Prime; %@", longd, longm, longs, ew]; 
}

- (NSString *)latitudeString2 {
    int latd = floor(fabs(lastLatitudeDegrees));
    int latm = floor((fabs(lastLatitudeDegrees) - latd)*60);
    double lats = (fabs(lastLatitudeDegrees) - latd - latm/60.0)*3600;
    NSString *ns = lastLatitudeDegrees >= 0 ? @"N" : @"S";
    return [NSString stringWithFormat:@"%d° %d' %2.0f\" %@", latd, latm, lats, ns];
}

- (NSString *)longitudeString2 {
    int longd = floor(fabs(lastLongitudeDegrees));
    int longm = floor((fabs(lastLongitudeDegrees) - longd)*60);
    double longs = (fabs(lastLongitudeDegrees) - longd - longm/60.0)*3600;
    NSString *ew = lastLongitudeDegrees >= 0 ? @"E" : @"W";
    return [NSString stringWithFormat:@"%d° %d' %2.0f\" %@", longd, longm, longs, ew]; 
}

- (void)stopUpdatingIfDone {
    traceEnter("stopUpdatingIfDone");
    double age = [NSDate timeIntervalSinceReferenceDate] - lastFix;
    tracePrintf4("autocheck=%d, doJustOne=%d, lastHorizontalErrorMeters=%g, age=%g", autoCheck, doJustOne, lastHorizontalErrorMeters, age);
    if ((autoCheck &&
	 lastHorizontalErrorMeters <= ECInitialAccuracy &&
	 age < (ECLocationFixLifetime - ECLocationAutoCheckTimeout - 10)) ||  // The -10 is to account for a fix that came in just after we turned off services (we see 5-second delays there)
	(doJustOne &&
	 lastHorizontalErrorMeters <= ECRequestAccuracy &&
	 lastFix > requestTime)) {
	tracePrintf("We're done :-)");
	[self stopUpdating];    // also notifies observers
    } else if (!active) {
	tracePrintf("Not stopping because we're already stopped");
    } else {
	tracePrintf("Not stopping because we think we're not done");
	// ...and notify anyone who's observing us
	[self notifyAllLocationChangeObservers:true];
    }
    traceExit ("stopUpdatingIfDone");
}

- (void)disableGuts {
    traceEnter ("disableGuts");
    tracePrintf("stopping CLLocationManager");
    [locationManager stopUpdatingLocation];
    //[ChronometerAppDelegate noteTimeAtPhase:"LM off"];
    active = false;
    autoCheck = false;
    refreshing = false;
    haveFirstUpdate = false;
    requestTime = 0;
    //count = 0;
    if (![self validLatitude:[self lastLatitudeRadians] longitude:[self lastLongitudeRadians]]) {
	lastHorizontalErrorMeters = -1;
    }
    
    // notify our observers
    [self notifyAllLocationChangeObservers:true];
    if (userRequested) {
	[ChronometerAppDelegate showECLocationStatus];
    }
    [ChronometerAppDelegate forceUpdateInMainThread];  // to update location indicator
    userRequested = false;

    if (autoCheckTimer) {
	[autoCheckTimer invalidate];
	autoCheckTimer = nil;
    }
    if (requestTimer) {
	[requestTimer invalidate];
	requestTimer = nil;
    }
    traceExit("disableGuts");
}

- (void)disable {
    [self disableGuts];
    settingEnabled = false;
}

- (void)stopUpdating {
    [self disableGuts];
    // Next auto check
    [self submitAutoCheckTimerForFix];
}

- (void)suspend {
    traceEnter("suspend");
    if (active && !autoCheck) {
	suspended = true;
	[self stopUpdating];
    }
    traceExit("suspend");
}

- (void)resume {
    traceEnter("resume");
    if (suspended) {
	suspended = false;
	[self requestLocationUpdates];
    } else {
	if (settingEnabled) {
	    if (autoCheckTimer) {
		[autoCheckTimer invalidate];
		autoCheckTimer = nil;
	    }
	    [self autoCheck:nil];
	}
    }
    traceExit("resume");
}

- (void)useBestAccuracy:(bool)best {
    locationManager.desiredAccuracy = best ? kCLLocationAccuracyBest : ECRequestAccuracy;
}

// Set an override location, for debug or (possibly) from user input
- (void)setOverrideLocationToLatitudeDegrees:(double)latitude
			   longitudeDegrees:(double)longitude
			     altitudeMeters:(double)altitude
			       skipObservers:(bool)skipObservers
			     horizontalError:(double)horizontalError {
    traceEnter ("setOverrideLocation");
    
    // printf("Setting override location for location manager 0x%08x to %.2f %.2f\n", (unsigned int)self, latitude, longitude);

    if (![self validLatitude:latitude * M_PI/180 longitude:longitude * M_PI/180]) {
	lastLongitudeDegrees = 0;
	lastLatitudeDegrees = -90;
	lastAltitudeMeters = 0;
	lastHorizontalErrorMeters = -1;
	lastVerticalErrorMeters = -1;
    } else {
	lastLongitudeDegrees = longitude;
	lastLatitudeDegrees = latitude;
	lastAltitudeMeters = altitude;
	lastHorizontalErrorMeters = horizontalError ? 101 : 0;
	lastVerticalErrorMeters = 0;
    }
    lastFix = [NSDate timeIntervalSinceReferenceDate];
    locationOverridden = true;
#ifndef NDEBUG
    //printf("overriding location to (%g,%g)\n", latitude, longitude);
#endif
    
    // notify our observers
    if (!skipObservers) {
	[self notifyAllLocationChangeObservers:true];
    }

    [self saveLocation];
    traceExit("setOverrideLocation");
}

- (void)setOverrideLocationToLatitudeDegrees:(double)latitude
			    longitudeDegrees:(double)longitude
			      altitudeMeters:(double)altitude {
    [self setOverrideLocationToLatitudeDegrees:latitude longitudeDegrees:longitude altitudeMeters:altitude skipObservers:false horizontalError:0];
}

- (void)setOverrideLocationToLatitudeDegrees:(double)latitude
			    longitudeDegrees:(double)longitude
			      altitudeMeters:(double)altitude
			     horizontalError:(double)horizontalError {
    [self setOverrideLocationToLatitudeDegrees:latitude longitudeDegrees:longitude altitudeMeters:altitude skipObservers:false horizontalError:horizontalError];
}

- (void)setOverrideLocationToLatitudeRadians:(double)latitude
			    longitudeRadians:(double)longitude
			      altitudeMeters:(double)altitude {
    [self setOverrideLocationToLatitudeDegrees:latitude * 180 / M_PI longitudeDegrees:longitude * 180 / M_PI altitudeMeters:altitude skipObservers:false horizontalError:0];
}

- (void)setOverrideLocationToLatitudeRadians:(double)latitude
			    longitudeRadians:(double)longitude
			      altitudeMeters:(double)altitude
			       skipObservers:(bool)skipObservers {
    [self setOverrideLocationToLatitudeDegrees:latitude * 180 / M_PI longitudeDegrees:longitude * 180 / M_PI altitudeMeters:altitude skipObservers:skipObservers horizontalError:0];
}

+ (ECLocationManager *)theLocationManager {
    if (!theLocationManager) {
	theLocationManager = [[ECLocationManager alloc] initGlobalManager];
    }
    return theLocationManager;
}

@end
