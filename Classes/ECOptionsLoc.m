//
//  ECOptionsLoc.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 9/7/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import "Contacts/CNLabeledValue.h"

#import "Constants.h"
#undef ECTRACE
#import "ECErrorReporter.h"
#import "ECTrace.h"
#import "ECOptionsLoc.h"
#import "ECOptionsCitySearch.h"
#import "ECOptions.h"
#import "ECLocationManager.h"
#import "ChronometerAppDelegate.h"
#import "ECErrorReporter.h"
#import "ECOptionsTZRoot.h"
#import "ECOptionsBigmap.h"
#import "ECOptionsRecents.h"
#import "ECGlobals.h"

static bool inBigMap = false;

@implementation ECLocationPin

@synthesize coordinate, title, subtitle;

-(void)dealloc {
    [title release];
    [subtitle release];
    [super dealloc];
}

@end

#define MAINFRAME_UNINIT (-5000)
#define LATLONGMOTION 42
#define MKMAXLAT 83		// MKMapKit does weird things pole-ward of 83
#define SCALE_BAR_LEFT 72   // Left side of scale bar in superview coords

#define FT_PER_KM (1000 * 100 / (2.54 * 12))

@implementation ECOptionsLoc

@synthesize mapView,pin,useDeviceLocationSwitch;
#ifdef BIGMAPLABELS
@synthesize label1, label2, label3;
#endif

- (ECOptionsLoc *)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil locDB:(ECGeoNames *)db {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
	assert(db);
	locDB = [db retain];
    }
    return self;
}

// utilities			---------------------------------------------------------


// Copied from eslocation/ESLocation.cpp to avoid include nightmare including <string> in that file's .hpp
// Haversine
static double 
kmBetweenLatLong(double latitude1Radians,
                 double longitude1Radians,
                 double latitude2Radians,
                 double longitude2Radians) {
    double earthRadius = 6371; // km
    double deltaLat = latitude2Radians - latitude1Radians;
    double deltaLong = longitude2Radians - longitude1Radians;

    double sinDLatOver2 = sin(deltaLat/2);
    double sinDLongOver2 = sin(deltaLong/2);
    double a = sinDLatOver2*sinDLatOver2 + sinDLongOver2*sinDLongOver2 * cos(latitude1Radians)*cos(latitude2Radians);
    double c = 2 * atan2(sqrt(a), sqrt(1-a));
    return earthRadius * c;
}

// distance between two locations (kilometers)
+ (double)distanceFrom:(CLLocationCoordinate2D)from to:(CLLocationCoordinate2D)to {
    return kmBetweenLatLong(from.latitude * M_PI / 180, from.longitude * M_PI / 180,
                            to.latitude * M_PI / 180, to.longitude * M_PI / 180);
}

static double greatCircleCourse(double latitude1,
                                double longitude1,
                                double latitude2,
                                double longitude2) {
    return atan2(sin(longitude1 - longitude2) * cos(latitude2),
                 cos(latitude1)*sin(latitude2)-sin(latitude1)*cos(latitude2)*cos(longitude1-longitude2));
}

static NSString *courseAbbrev(double fromLatitudeDegrees,
                              double fromLongitudeDegrees,
                              double toLatitudeDegrees,
                              double toLongitudeDegrees) {
    double courseInRadians = greatCircleCourse(fromLatitudeDegrees * M_PI / 180,
                                               fromLongitudeDegrees * M_PI / 180,
                                               toLatitudeDegrees * M_PI / 180,
                                               toLongitudeDegrees * M_PI / 180);
    int sector = (int)round(courseInRadians / (M_PI / 8));
    if (sector < 0) {
        sector += 16;
    }
    switch (sector) {
      case 0:
        return @"N";
      case 1:
        return @"NNW";
      case 2:
        return @"NW";
      case 3:
        return @"WNW";
      case 4:
        return @"W";
      case 5:
        return @"WSW";
      case 6:
        return @"SW";
      case 7:
        return @"SSW";
      case 8:
        return @"S";
      case 9:
        return @"SSE";
      case 10:
        return @"SE";
      case 11:
        return @"ESE";
      case 12:
        return @"E";
      case 13:
        return @"ENE";
      case 14:
        return @"NE";
      case 15:
        return @"NNE";
      default:
        printf("Unknown sector %d from %f\n", sector, courseInRadians);
        return @"?";
    }
}

+ (NSString *)headingFrom:(CLLocationCoordinate2D)from to:(CLLocationCoordinate2D)to {
    return courseAbbrev(from.latitude, from.longitude, to.latitude, to.longitude);
}

- (NSString *)proximityQualifiedName:(CLLocationCoordinate2D)from {
    CLLocationCoordinate2D cityLoc = {[locDB selectedCityLatitude],[locDB selectedCityLongitude]};
    double delta = [ECOptionsLoc distanceFrom:from to:cityLoc];
    if (sqrt([locDB selectedCityPopulation])/5 > delta) {
	return [NSString stringWithFormat:@"%@", [locDB selectedCityName]];
    } else {
	NSString *units;
	if ([[ECLocationManager theLocationManager] SIUnits]) {
	    units = NSLocalizedString(@"km","kilometers abbreviation for proximity qualified names");
	} else {
	    units = NSLocalizedString(@"mi","miles abbreviation for proximity qualified names");
	    delta = delta*.62;
	}
	NSString *heading = [ECOptionsLoc headingFrom:cityLoc to:from];
	return [NSString stringWithFormat:NSLocalizedString(@"%3.0f %@ %@ of %@", @"format for proximity qualified names, eg: '123 km NW of Paris'"), delta, units, heading, [locDB selectedCityName]];
    }
}

- (void)setTargetLabels {
    traceEnter("setTargetLabels");

    latitudeLabel.text =   targetLatitude.text = [NSString stringWithFormat:@"%6.3f", center.latitude];
    longitudeLabel.text = targetLongitude.text = [NSString stringWithFormat:@"%6.3f", center.longitude];

    assert(locDB);
    [locDB findClosestCityToLatitudeDegrees:center.latitude longitudeDegrees:center.longitude];
    NSString *city = [locDB selectedCityName];
    NSString *region = [locDB selectedCityRegionName];
    
    assert(city);
    if (city) {
	cityNameLabel.text = [self proximityQualifiedName:center];
        cityNameTextField.text = cityNameLabel.text;
	regionInfoLabel.text = region;
	[ECOptions setCurrentCity:cityNameLabel.text region:region];

	// update the pin
	pin.title = cityNameLabel.text;
	pin.subtitle = regionInfoLabel.text;
    }
    
    traceExit("setTargetLabels");
}

#ifdef BIGMAPLABELS
// for the bigmap view:
- (void)updateLabels {
    MKCoordinateRegion region = mapView.region;
    [locDB findBestMatchCityToLatitudeDegrees:region.center.latitude longitudeDegrees:region.center.longitude];
    label1.text = [NSString stringWithFormat:@"%@, %@", [self proximityQualifiedName:region.center], [locDB selectedCityRegionName]];
    label2.text = [NSString stringWithFormat:@"(%6.3f, %6.3f)", region.center.latitude, region.center.longitude];
    label3.text = [locDB selectedCityTZName];
}
#endif

static double makeBarLengthEvenUnit(double barLen, double pixelsPerDistanceUnit) {
    int roundedLen = pow(10,trunc(log10(barLen)));  // meters or miles/feet
    if (roundedLen < 1) {
        roundedLen = 1;
    }
    int roundedLenPixels = roundedLen * pixelsPerDistanceUnit;
    if (roundedLenPixels < 20) {
	roundedLen = roundedLen * 5;
    }
    return roundedLen;
}

// when the map changes, adjust the scale bar and its label
- (void)adjustScaleBar {
    traceEnter("adjustScaleBar");
    bool siUnits = [[ECLocationManager theLocationManager] SIUnits];

    double verticalSpan   = mapView.region.span.latitudeDelta;  // in degrees
    double lowerLatitude = mapView.region.center.latitude - verticalSpan / 2;  // Approximate
    if (lowerLatitude < -89) {
        lowerLatitude = -89;
    }
    double upperLatitude = mapView.region.center.latitude + verticalSpan / 2;  // Approximate
    if (upperLatitude > 89) {
        upperLatitude = 89;
    }

    double horizontalSpan = mapView.region.span.longitudeDelta;  // in degrees
    double lowerLongitude = mapView.region.center.longitude - horizontalSpan / 2;  // Approximate
    if (lowerLongitude < -180) {
        lowerLongitude += 360;
    }
    double upperLongitude = mapView.region.center.longitude + horizontalSpan / 2;  // Approximate
    if (upperLongitude > 180) {
        upperLongitude += 360;
    }
    
    double diagonalDistanceKm = kmBetweenLatLong(lowerLatitude * M_PI / 180, lowerLongitude * M_PI / 180, 
                                                 upperLatitude * M_PI / 180, upperLongitude * M_PI / 180);
    double vpixels = mapView.frame.size.height;
    double hpixels = mapView.frame.size.width;
    double diagonalDistancePixels = sqrt(vpixels*vpixels + hpixels*hpixels);

    double pixelsPerKm = diagonalDistanceKm == 0 ? 0 : (diagonalDistancePixels / diagonalDistanceKm);

    NSString *unitName = @"";
    double barLengthInDistanceUnits = 0;
    double barLengthActualPixels = 0;

    double barLengthTargetPixels = hpixels / 4;

    if (siUnits) {
        double pixelsPerM = pixelsPerKm / 1000;
        double barLengthM = makeBarLengthEvenUnit(barLengthTargetPixels / pixelsPerM, pixelsPerM);
        if (barLengthM >= 1000) {
            double barLengthKm = makeBarLengthEvenUnit(barLengthTargetPixels / pixelsPerKm, pixelsPerKm);
            barLengthInDistanceUnits = barLengthKm;
            barLengthActualPixels = barLengthKm * pixelsPerKm;
            unitName = @"km";
        } else {
            barLengthInDistanceUnits = barLengthM;
            barLengthActualPixels = barLengthM * pixelsPerM;
            unitName = @"m";
        }
    } else {
        double pixelsPerFt = pixelsPerKm / FT_PER_KM;
        double barLengthFt = makeBarLengthEvenUnit(barLengthTargetPixels / pixelsPerFt, pixelsPerFt);
        if (barLengthFt > 5280) {
            double pixelsPerMi = pixelsPerFt * 5280;
            double barLengthMi = makeBarLengthEvenUnit(barLengthTargetPixels / pixelsPerMi, pixelsPerMi);
            barLengthInDistanceUnits = barLengthMi;
            barLengthActualPixels = barLengthMi * pixelsPerMi;
            unitName = @"mi";
        } else {
            barLengthInDistanceUnits = barLengthFt;
            barLengthActualPixels = barLengthFt * pixelsPerFt;
            unitName = @"ft";
        }
    }

    scaleLabel.text = [NSString stringWithFormat:@"%d %s", (int)round(barLengthInDistanceUnits), [unitName UTF8String]];
    CGPoint scaleBarCenter = scaleBar.center;
    CGFloat scaleBarLeftEdge = SCALE_BAR_LEFT;
    scaleBar.transform = CGAffineTransformScale(CGAffineTransformIdentity, barLengthActualPixels/100, 1);
    scaleBar.center = CGPointMake(scaleBarLeftEdge + scaleBar.frame.size.width/2, scaleBarCenter.y);
    traceExit("adjustScaleBar");
}

- (void)restoreSmallMap {
    traceEnter("restoreSmallMap");
    if (fabs(center.latitude) < MKMAXLAT) {
	[self.view addSubview:mapView];
        [self.view bringSubviewToFront:oneTouch];
        mapView.userInteractionEnabled = false;
        mapView.layer.opacity = 0;
	tracePrintf2("recentering map: from lat=%10.7f, long=%10.7f", mapView.centerCoordinate.latitude, mapView.centerCoordinate.longitude);
	tracePrintf3("          %5.0f km to lat=%10.7f, long=%10.7f",[ECOptionsLoc distanceFrom:center to:mapView.centerCoordinate], center.latitude, center.longitude);
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
	[UIView setAnimationDuration:.5];
        [mapView setRegion:MKCoordinateRegionMake(center, MKCoordinateSpanMake(2,2)) animated:YES];
        //mapView.centerCoordinate = center;	    // this innocent looking line causes big trouble near longitude 180
        mapInitialized = true;
	mapView.layer.opacity = 1;
	scaleBar.layer.opacity = 1;
        tapmapLabel.text = NSLocalizedString(@"Tap the map to\nset the location.", @"small map usage hint");
	scaleLabel.layer.opacity = 1;
	oneTouch.enabled = true;
	scaleUnitsButton.enabled = true;
	[self adjustScaleBar];
	[UIView commitAnimations];
    } else {
	// too far pole-ward, leave the map hidden and hide the scale bar, too
	tracePrintf2("too far pole-ward: lat=%g, long=%g", center.latitude, center.longitude);
	mapView.layer.opacity = 0;
	scaleBar.layer.opacity = 0;
	if (center.latitude > 0) {
	    tapmapLabel.text = NSLocalizedString(@"No map display north of 83 degrees.", "map too far north");
	} else {
	    tapmapLabel.text = NSLocalizedString(@"No map display south of -83 degrees.", "map too far south");
	}
	scaleLabel.layer.opacity = 0;
	oneTouch.enabled = false;
	scaleUnitsButton.enabled = false;
    }
    traceExit ("restoreSmallMap");
}

- (void)updateToCoordinate:(CLLocationCoordinate2D)newPosition horizontalError:(double)horizontalError {
    traceEnter("updateToCoordinate");

    double dist = [ECOptionsLoc distanceFrom:newPosition to:center];
    center = newPosition;
    pin.coordinate = center;
    if (dist > 0.1 || needLoc) {	    // 100 meters is unlikely to change cities
        tracePrintf2("lat=%10.7f, long=%10.7f", newPosition.latitude, newPosition.longitude);
	[self setTargetLabels];
	needLoc = false;
	// set the timezone if in auto mode or at least remember it for later
	ESTimeZone *estz = ESCalendar_initTimeZoneFromOlsonID([[locDB selectedCityTZName] UTF8String]);
	[ECOptions setTimezone:estz andCenter:center];
	ESCalendar_releaseTimeZone(estz);
    } else {
	// tracePrintf1("labels OK (%s)", [cityNameLabel.text UTF8String]);
    }

    tzNameLabel.text = [ECOptions currentTZName];
    tzInfoLabel.text = [ECOptions currentTZInfo];
    tzSourceLabel.text = [ECOptions currentTZSource];
    
    if ([ECOptionsLoc distanceFrom:center to:mapView.centerCoordinate] > 2) {	    // 1 pixel is about 2 km
	[self restoreSmallMap];
    } else {
	// tracePrintf("map OK");
    }

    ECLocationManager *locMan = [ECLocationManager theLocationManager];
    CLLocationCoordinate2D oldECPosition;
    oldECPosition.latitude =  [locMan lastLatitudeDegrees];
    oldECPosition.longitude = [locMan lastLongitudeDegrees];
    dist = [ECOptionsLoc distanceFrom:oldECPosition to:newPosition];
    if (dist > 0.1) {	    // 100 meters is more than accurate enough for EC
	[locMan setOverrideLocationToLatitudeDegrees: center.latitude
				    longitudeDegrees:center.longitude
				      altitudeMeters:[locMan lastAltitudeMeters]
					      horizontalError:horizontalError];
    } else {
	// tracePrintf("ECLoc OK");
    }

    traceExit("updateToCoordinate");
}

// 
- (void)useSelectedCity {
    traceEnter("useSelectedCity");
    cityNameLabel.text = [self proximityQualifiedName:center];
    cityNameTextField.text = cityNameLabel.text;
    regionInfoLabel.text = [locDB selectedCityRegionName];
    [ECOptions setCurrentCity:cityNameLabel.text region:regionInfoLabel.text];
    CLLocationCoordinate2D newPos = {[locDB selectedCityLatitude], [locDB selectedCityLongitude]};
    assert (!useDeviceLocationSwitch.on);
    [self updateToCoordinate:newPos horizontalError:ECDefaultHorizontalError];
    traceExit ("useSelectedCity");
}

- (void)timeUpdater: (NSTimer *)t  {
    timeLabel.text = [ECOptions formatTime];
}

- (void)delayedTermination: (NSTimer *)t  {
    traceEnter("delayedTermination");
    [self release];
    traceExit("delayedTermination");
}

- (void)clearTimerAndObserver {
    traceEnter("clearTimerAndObserver");
    [ECLocationManager theLocationManager].delegate = nil;
    [[ECLocationManager theLocationManager] cancelLocationUpdates];
    [timeTimer invalidate];
    timeTimer = nil;
    traceExit("clearTimerAndObserver");
}

- (void)setTimerAndObserver: (id)obj  {
    traceEnter("setTimerAndObserver");
    if (obj) {
	[ECLocationManager theLocationManager].delegate = (ECLocationManagerDelegate *)self;
	if (useDeviceLocationSwitch.on) {
	    tracePrintf("starting ECLocationMgr");
	    [[ECLocationManager theLocationManager] requestLocationUpdates];
	}
	timeTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:obj selector:@selector(timeUpdater:) userInfo:nil repeats:true];
    } else {
	[self clearTimerAndObserver];
//	[self retain];
//	[NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(delayedTermination:) userInfo:nil repeats:false];
    }
    traceExit ("setTimerAndObserver");
}

- (void)issueAlert:(NSString *)title message:(NSString *)msg {
    [[ECErrorReporter theErrorReporter] reportError:msg];
}

- (void)notFoundError:(NSString *)missing {
    [self issueAlert:NSLocalizedString(@"Error",@"error alert title") message:[NSString stringWithFormat:NSLocalizedString(@"Emerald Chronometer cannot find\n'%@'\nin its internal database.", @"error alert format"), missing]];
}

// initialization			---------------------------------------------------------
- (void)viewDidLoad {
    traceEnter("viewDidLoad");
    inSomeLatLongField = false;
    mainFrameOriginY = MAINFRAME_UNINIT;
    [super viewDidLoad];

    mapView.delegate = self;		    // needed for the pin
    mapInitialized = false;
    targetLatitude.delegate = self;
    targetLongitude.delegate = self;
    
    self.navigationItem.title = NSLocalizedString(@"Location", @"Location label");
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(doneAction:)] autorelease];

    center.latitude =  [[ECLocationManager theLocationManager]lastLatitudeDegrees];
    center.longitude = [[ECLocationManager theLocationManager]lastLongitudeDegrees];

    cityNameTextField.delegate = self;

    cityNameLabel.text = nil;
    cityNameTextField.text = nil;
    regionInfoLabel.text = nil;

    mapView.layer.opacity = 0;

    pin = [[ECLocationPin alloc] init];

    useDeviceLocationSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseLocationServices"];
    
    unfinished = true;
    traceExit("viewDidLoad");
}

- (void) viewDidLayoutSubviews {
    traceEnter("viewDidLayoutSubviews");
    if (!firstLayoutSubviewsDone) {
        tracePrintf4("viewDidLayoutSubviews map frame is %.1f %.1f %.1f %.1f\n", 
                     mapView.frame.origin.x,
                     mapView.frame.origin.y,
                     mapView.frame.size.width,
                     mapView.frame.size.height);
        tracePrintf4("viewDidLayoutSubviews searchbar holder frame is %.1f %.1f %.1f %.1f\n", 
                     cityNameSearchBarHolder.frame.origin.x,
                     cityNameSearchBarHolder.frame.origin.y,
                     cityNameSearchBarHolder.frame.size.width,
                     cityNameSearchBarHolder.frame.size.height);
        regionInfoFrame = regionInfoLabel.frame;
        cityNameLabelCenter = cityNameLabel.center;
        [self autoLocAction:nil];
        firstLayoutSubviewsDone = true;
    }
    traceExit("viewDidLayoutSubviews");
}

// 
- (void) finishECLocInitialization {
    traceEnter("finishECLocInitialization");

    [self setTargetLabels];
    pin.coordinate = center;
    ESTimeZone *estz = ESCalendar_initTimeZoneFromOlsonID([[locDB selectedCityTZName] UTF8String]);
    [ECOptions setTimezone:estz andCenter:center];
    ESCalendar_releaseTimeZone(estz);
    
    tzNameLabel.text = [ECOptions currentTZName];
    tzSourceLabel.text = [ECOptions currentTZSource];
    tzInfoLabel.text = [ECOptions currentTZInfo];
    timeLabel.text = [ECOptions formatTime];

    unfinished = false;
    traceExit("finishECLocInitialization");
}

- (void)viewWillAppear:(BOOL)animated {
    traceEnter("viewWillAppear");
    kbdLockout = true;
    [self setTimerAndObserver:self];
    [super viewWillAppear:animated];
    traceExit("viewWillAppear");
}

- (void)viewDidAppear:(BOOL)animated {
    traceEnter("viewDidAppear");
    if (unfinished) {
	[self finishECLocInitialization];
    }
    if (!searchEditing) {
	[self restoreSmallMap];
    }
    if (!useDeviceLocationSwitch.on) {
	[mapView addAnnotation:pin];
    }
    mapView.showsUserLocation = useDeviceLocationSwitch.on;
    kbdLockout = false;
    inBigMap = false;
    [super viewDidAppear:animated];
    traceExit("viewDidAppear");
}

- (void)viewWillDisappear:(BOOL)animated {
    traceEnter("viewWillDisappear");
    [self setTimerAndObserver:nil];
    if (!useDeviceLocationSwitch.on) {
	[mapView removeAnnotation:pin];
    }
    mapView.showsUserLocation = false;
    // save the last place before exiting
    [ECOptionsRecents push:cityNameLabel.text region:regionInfoLabel.text position:center];
    [super viewWillDisappear:animated];
    traceExit("viewWillDisappear");
}


// ECLocationManager "delegate"			---------------------------------------------------------

- (void)follower {
    traceEnter("follower");
    if (useDeviceLocationSwitch.on) {
	CLLocationCoordinate2D newPosition;
	newPosition.latitude =  [[ECLocationManager theLocationManager]lastLatitudeDegrees];
	newPosition.longitude = [[ECLocationManager theLocationManager]lastLongitudeDegrees];
	[self updateToCoordinate:newPosition horizontalError:0];
    } else {
	tracePrintf("manual loc only");
    }
    [spinner stopAnimating];
    oneTouch.enabled = true;
    cityNameLabel.layer.opacity = useDeviceLocationSwitch.on;
    regionInfoLabel.layer.opacity = 1;
    latitudeLabel.layer.opacity  = 1;
    longitudeLabel.layer.opacity = 1;
    traceExit("follower");
}


// button action methods			---------------------------------------------------------

// when the user taps the Done button, exit
- (IBAction) doneAction: (id) sender {
    [ChronometerAppDelegate optionDone];
}

// when the user taps Set (on iPad or in bigmap view), move the pin
- (IBAction) setAction: (id) sender {
    traceEnter("setAction");
    //set the labels et al based on the center of the mapView (in both map sizes)
    assert (!useDeviceLocationSwitch.on);
    [self updateToCoordinate:mapView.centerCoordinate horizontalError:0];
    traceExit("setAction");
}

// when the user flips the "Use Device Location" switch; also called at startup from ViewDidLoad with sender==nil
- (IBAction) autoLocAction: (id) sender {
    traceEnter("autoLocAction");

    if (useDeviceLocationSwitch.on) {
	tracePrintf("starting ECLocationMgr");
	[[ECLocationManager theLocationManager] requestLocationUpdates];
	[spinner startAnimating];
    } else {
	tracePrintf("disabling ECLocationMgr");
	// put ECLocationManager into manual mode (but for now at the current position)
	[[ECLocationManager theLocationManager] setOverrideLocationToLatitudeDegrees:center.latitude
								    longitudeDegrees:center.longitude
								      altitudeMeters:[[ECLocationManager theLocationManager] lastAltitudeMeters]
								     horizontalError:sender==nil ? ECDefaultHorizontalError : 0];
	[[ECLocationManager theLocationManager] stopUpdating];
	[spinner stopAnimating];
    }

    // adjust widgets to different positions and/or visibilities
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    [UIView setAnimationDuration:.5];
    CGRect tmp = regionInfoFrame;
    if (useDeviceLocationSwitch.on) {
        tmp.origin.y -= 12;
        // CGPoint pnt = cityNameLabel.center;
        // pnt.x = 160;
        // cityNameLabel.center = pnt;
        cityNameLabel.center = cityNameLabelCenter;
    } else {
        tmp.origin.y -= 3;
        cityNameLabel.center = cityNameLabelCenter;
    }
    regionInfoLabel.frame = tmp;
    regionInfoLabel.textAlignment = useDeviceLocationSwitch.on ? NSTextAlignmentCenter : NSTextAlignmentLeft;
    cityNameLabel.textAlignment = useDeviceLocationSwitch.on ? NSTextAlignmentCenter : NSTextAlignmentLeft;
    cityNameLabel.font = [cityNameLabel.font fontWithSize:useDeviceLocationSwitch.on ? 24 : 16];
    cityNameLabel.hidden = !useDeviceLocationSwitch.on;
    cityNameLabel.layer.opacity = useDeviceLocationSwitch.on;		// will be re-enabled when the ECLocationManager update finishes (follower)
    cityNameTextField.hidden = useDeviceLocationSwitch.on;
    regionInfoLabel.layer.opacity = 1;
    recentsButton.layer.opacity = !useDeviceLocationSwitch.on;
    setButton.layer.opacity = !useDeviceLocationSwitch.on;
    tapmapLabel.layer.opacity = !useDeviceLocationSwitch.on;
    targetLatitude.layer.opacity  = !useDeviceLocationSwitch.on;
    targetLongitude.layer.opacity  = !useDeviceLocationSwitch.on;
    targetLatitudeLabel.layer.opacity  = !useDeviceLocationSwitch.on;
    targetLongitudeLabel.layer.opacity  = !useDeviceLocationSwitch.on;
    latitudeLabel.layer.opacity  = 0;
    longitudeLabel.layer.opacity = 0;
    latitudeLabelLabel.layer.opacity  = useDeviceLocationSwitch.on;
    longitudeLabelLabel.layer.opacity = useDeviceLocationSwitch.on;
    oneTouch.enabled = !useDeviceLocationSwitch.on;		
    // show the GPS location in auto mode; the pin in manual
    mapView.showsUserLocation = useDeviceLocationSwitch.on;
    if (useDeviceLocationSwitch.on) {
	[mapView removeAnnotation:pin];
    } else {
	[mapView addAnnotation:pin];
    }
    [UIView commitAnimations];
    
    [ECOptions setAutoLoc:useDeviceLocationSwitch.on];
    if (sender) {	// don't do this in initialization
	[ECOptions setCurrentCityUnknown];	// noop if in manual loc mode
	needLoc = true;
    }

    tzSourceLabel.text = [ECOptions currentTZSource];
    if (useDeviceLocationSwitch.on && [[NSUserDefaults standardUserDefaults] boolForKey:@"ECAutoTZ"]) {
	tzNameLabel.text = nil;
	tzInfoLabel.text = nil;
	timeLabel.text = nil;
    } else {
	tzNameLabel.text = [ECOptions currentTZName];
	tzInfoLabel.text = [ECOptions currentTZInfo];
	timeLabel.text = [ECOptions formatTime];
    }
    
    traceExit("autoLocAction");
}

// when the user taps the invisible button on top of the small map, make the map cover the whole screen
- (IBAction) bigmapAction: (id) sender {
    traceEnter("bigmapAction");
    inBigMap = true;
    UIViewController *vc = [[[ECOptionsBigmap alloc] initWithParent:self settable:!useDeviceLocationSwitch.on] autorelease];
    [self.navigationController pushViewController:vc animated:YES];
#ifdef BIGMAPLABELS
    [self updateLabels];
#endif
    traceExit ("bigmapAction");
}

// change map type to "Classic"
- (IBAction) mapAction: (id) sender {
    traceEnter("mapAction");
    mapView.mapType = MKMapTypeStandard;
    mapButton.enabled = NO;
    satButton.enabled = YES;
    traceExit ("mapAction");
}

// change map type to Satellite
- (IBAction) satAction: (id) sender {
    traceEnter("satAction");
    mapView.mapType = MKMapTypeSatellite;
    satButton.enabled = NO;
    mapButton.enabled = YES;
    traceExit ("satAction");
}

// when the user taps the recents button, display the list of recent locations
- (IBAction) recentsAction: (id) sender {
    traceEnter("recentsAction");
    UIViewController *vc = [[[ECOptionsRecents alloc] initWithParent:self] autorelease];
    vc.navigationItem.title = NSLocalizedString(@"Recents", @"recent locations list screen title");
    [self.navigationController pushViewController:vc animated:YES];
    traceExit ("recentsAction");
}

// when the user taps the units label on the scale bar, toggle between SI units and American units
- (IBAction) unitsAction: (id) sender {
#undef ADJUSTABLE_SCALE
#ifdef ADJUSTABLE_SCALE
    [ECLocationManager theLocationManager].SIUnits = ![ECLocationManager theLocationManager].SIUnits;
    [self adjustScaleBar];
#endif
}

// UITextFieldDelegate methods (*mostly* for lat/long entry)	---------------------------------------------------------

- (void)delayedStartCityNameSearch:(NSTimer *)timer {
    traceEnter("delayedStartCityNameSearch");
    UIViewController *vc = [[[ECOptionsCitySearch alloc] initWithParent:self locDB:locDB placeholderText:cityNameLabel.text] autorelease];
    vc.navigationItem.title = NSLocalizedString(@"City Search", @"city search screen title");
    [self.navigationController pushViewController:vc animated:YES];
    traceExit("delayedStartCityNameSearch");
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    traceEnter("textFieldShouldBeginEditing");
    if (textField == cityNameTextField) {
        [NSTimer scheduledTimerWithTimeInterval:0.001 target:self selector:@selector(delayedStartCityNameSearch:) userInfo:nil repeats:NO];
        traceExit("textFieldShouldBeginEditing city name");
        return false;
    }
    traceExit("textFieldShouldBeginEditing");
    return !kbdLockout;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    traceEnter("textFieldDidBeginEditing");
    if (textField == cityNameTextField) {
        assert(false);
        traceExit("textFieldDidBeginEditing city name");
        return;
    }

    inSomeLatLongField = true;
    traceExit("textFieldDidBeginEditing");
}

- (void)delayedViewReturnPosition:(NSTimer *)timer {
    if (inSomeLatLongField) {
	return;
    }
    CLLocationCoordinate2D newPos;
    double lat = [targetLatitude.text floatValue];
    lat = fmin(90, fmax(-90, lat));
    newPos.latitude = lat;
    double lng = [targetLongitude.text floatValue];
    lng = fmin(180, fmax(-180, lng));
    newPos.longitude = lng;
    assert (!useDeviceLocationSwitch.on);
    [self updateToCoordinate:newPos horizontalError:0];
    [self restoreSmallMap];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    traceEnter("textFieldDidEndEditing");
    inSomeLatLongField = false;
    [NSTimer scheduledTimerWithTimeInterval:0.001 target:self selector:@selector(delayedViewReturnPosition:) userInfo:nil repeats:NO];
    traceExit("textFieldDidEndEditing");
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    traceEnter("textFieldShouldReturn");
    [textField resignFirstResponder];
    traceExit ("textFieldShouldReturn");
    return YES;
}


// MKMapViewDelegate methods			---------------------------------------------------------

// the user scrolled or zoomed the map (in either map view)
- (void)mapView:(MKMapView *)mapVw regionDidChangeAnimated:(BOOL)animated {
    traceEnter("regionDidChangeAnimated");
    assert(mapVw == mapView);
#ifdef BIGMAPLABELS
    if (label1) {
	[self updateLabels];
    }
#endif
    [self adjustScaleBar];
    traceExit("regionDidChangeAnimated");
}

- (void)mapViewDidFailLoadingMap:(MKMapView *)mapView withError:(NSError *)error {
    tracePrintf("mapViewDidFailLoadingMap---------------------------------------------");
    // inform user? try again? for now just...
    [ChronometerAppDelegate setNetworkActivityIndicator:false];
}

- (void)mapViewWillStartLoadingMap:(MKMapView *)mapView {
    //traceEnter("mapViewWillStartLoadingMap");
    [ChronometerAppDelegate setNetworkActivityIndicator:TRUE];
    //traceExit("mapViewWillStartLoadingMap");
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView {
    //traceEnter("mapViewDidFinishLoadingMap");
    [ChronometerAppDelegate setNetworkActivityIndicator:false];
    //traceExit("mapViewDidFinishLoadingMap");
}

- (MKAnnotationView *)mapView:(MKMapView *)mapVw viewForAnnotation:(id <MKAnnotation>)annotation {
    //traceEnter("viewForAnnotation");
    MKAnnotationView *pinView = nil;
    assert(mapVw == mapView);
    if (annotation == pin) {
	pinView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"ECPin"];
	if (!pinView) {
	    pinView = [[[MKPinAnnotationView alloc] initWithAnnotation:pin reuseIdentifier:@"ECPin"] autorelease];
	    ((MKPinAnnotationView*)pinView).pinTintColor = MKPinAnnotationView.purplePinColor;
	}
    } else {
	// return nil to use the default for the user's location (or anything else that sneaks in)
    }
    //traceExit("viewForAnnotation");
    return pinView;
}

// cleanup  			---------------------------------------------------------

- (void)dealloc {
    traceEnter("ECOptionsLoc::dealloc");

    [self clearTimerAndObserver];


    self.navigationItem.rightBarButtonItem = nil;

    [backer release];    backer = nil;
    [tzbacker release];  tzbacker = nil;
    [useDeviceLocationSwitch release]; useDeviceLocationSwitch = nil;
    [spinner release]; spinner = nil;
    [switchLabel release]; switchLabel = nil;
    [tzlabel release]; tzlabel = nil;
    [cityNameLabel release]; cityNameLabel = nil;
    [regionInfoLabel release]; regionInfoLabel = nil;
    [recentsButton release]; recentsButton = nil;
    [setButton release]; setButton = nil;
    [targetLatitude release]; targetLatitude = nil;
    [targetLongitude release]; targetLongitude = nil;
    [targetLatitudeLabel release]; targetLatitudeLabel = nil;
    [targetLongitudeLabel release]; targetLongitudeLabel = nil;
    [latitudeLabel release]; latitudeLabel = nil;
    [longitudeLabel release]; longitudeLabel = nil;
    [latitudeLabelLabel release]; latitudeLabelLabel = nil;
    [longitudeLabelLabel release]; longitudeLabelLabel = nil;
    [scaleBar release]; scaleBar = nil;
    [scaleUnitsButton release]; scaleUnitsButton = nil;
    [tapmapLabel release]; tapmapLabel = nil;
    [scaleLabel release]; scaleLabel = nil;
    [tzNameLabel release]; tzNameLabel = nil;
    [tzSourceLabel release]; tzSourceLabel = nil;
    [tzInfoLabel release]; tzInfoLabel = nil;
    [timeLabel release]; timeLabel = nil;
    [oneTouch release]; oneTouch = nil;
#ifdef BIGMAPLABELS
    [label1 release]; label1 = nil;
    [label2 release]; label2 = nil;
    [label3 release]; label3 = nil;
#endif
#if 0
    if (finder) {
	assert(false);
	finder.delegate = nil;
	[finder cancel];
	[finder release];
    }
#endif
    if (locDB) {
	[locDB release];
    }

    [pin			release];

    [super dealloc];
    traceExit("ECOptionsLoc::dealloc");
}

@end
