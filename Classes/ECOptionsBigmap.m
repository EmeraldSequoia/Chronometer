//
//  ECOptionsBigmap.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 10/8/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import "ECOptionsLoc.h"
#import "ECOptionsBigmap.h"
#import "ECLocationManager.h"
#import "ChronometerAppDelegate.h"
#undef ECTRACE
#import "ECTrace.h"

@implementation ECOptionsBigmap

static bool needsHint = false;

static CGRect parentFrame;

+ (void)initialize {
    needsHint = [ChronometerAppDelegate firstRun];
}

- (ECOptionsBigmap *)initWithParent:(ECOptionsLoc *)obj settable:(bool)s {
    if (self=[super init]) {
	parent = obj;
        parentFrame = parent.view.frame;
	settable = s;
    }
    return self;
}

- (void)viewDidLoad {
    traceEnter("ECOptionsBigmap::viewDidLoad");
    [super viewDidLoad];
    titleView = [[UIView alloc] initWithFrame:CGRectMake(120, 50, 140, 30)];
    mapSat = [[UISegmentedControl alloc] initWithFrame:CGRectMake(0, 0, 140, 30)];
    mapSat.tintColor = [UIColor darkGrayColor];
    [mapSat insertSegmentWithTitle:NSLocalizedString(@"Map", @"map type label") atIndex:0 animated:false];
    [mapSat insertSegmentWithTitle:NSLocalizedString(@"Hybrid", @"map type label") atIndex:1 animated:false];
    [mapSat insertSegmentWithTitle:NSLocalizedString(@"Sat", @"map type label") atIndex:2 animated:false];
    MKMapType state = 0;
    mapView = [[MKMapView alloc] init];
    mapView.mapType = [[NSUserDefaults standardUserDefaults] integerForKey:@"ECMapType"];
    mapView.region = parent.mapView.region;
    mapView.delegate = self;  // For pin
    pin = [[ECLocationPin alloc] init];
    pin.coordinate = parent.pin.coordinate;
    // printf("map view region: center: %.2f %.2f, span %.2f %.2f\n",
    //        mapView.region.center.latitude, mapView.region.center.longitude,
    //        mapView.region.span.latitudeDelta, mapView.region.span.longitudeDelta);
    switch ([[NSUserDefaults standardUserDefaults] integerForKey:@"ECMapType"]) {
	case MKMapTypeStandard:
	    state = 0;
	    break;
	case MKMapTypeHybrid:
	    state = 1;
	    break;
	case MKMapTypeSatellite:
	    state = 2;
	    break;
	default:
	    assert(false);
	    break;
    }
    mapSat.selectedSegmentIndex = state;
    [mapSat addTarget:self action:@selector(mapSatAction:) forControlEvents:UIControlEventAllEvents];
    [titleView addSubview:mapSat];
    self.navigationItem.titleView = titleView;
    if (settable) {
	self.navigationItem.rightBarButtonItem  = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Set", @"set button on big map") style:UIBarButtonItemStylePlain target:self action:@selector(setAction:)];
    }
    [self.view addSubview:mapView];
    if (settable) {
        NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"xHairs.png"];
        UIImage *img = [[UIImage alloc] initWithContentsOfFile:path];
        xhairView = [[UIImageView alloc] initWithImage:img];
        [self.view addSubview:xhairView];
        [img release];
    }
#ifdef BIGMAPLABELS
    if (parent.label1 == nil) {
	parent.label1 = [[UILabel alloc] initWithFrame:CGRectMake(0, parentFrame.size.height - 64, parentFrame.size.width, 15)];  // (0, 381, 320, 15)
	parent.label1.textAlignment = NSTextAlignmentCenter;
	parent.label1.font = [UIFont systemFontOfSize:14];
	parent.label1.textColor = [UIColor	whiteColor];
	parent.label1.backgroundColor = [UIColor blackColor];
        CGFloat y2 = parentFrame.size.height - 49;
	parent.label2 = [[UILabel alloc] initWithFrame:CGRectMake(0, y2, parentFrame.size.width / 2, 20)];  // (0, 396, 160, 20)];
	parent.label2.textAlignment = NSTextAlignmentLeft;
	parent.label2.font = [UIFont systemFontOfSize:12];
	parent.label2.textColor = [UIColor	whiteColor];
	parent.label2.backgroundColor = [UIColor blackColor];
	parent.label3 = [[UILabel alloc] initWithFrame:CGRectMake(parentFrame.size.width / 2, y2, parentFrame.size.width / 2, 20)];  // 160, 396, 160, 20)];
	parent.label3.textAlignment = NSTextAlignmentRight;
	parent.label3.font = [UIFont systemFontOfSize:12];
	parent.label3.textColor = [UIColor	whiteColor];
	parent.label3.backgroundColor = [UIColor blackColor];
    }
    [self.view addSubview:parent.label1];
    [self.view addSubview:parent.label2];
    [self.view addSubview:parent.label3];
#endif
    traceExit("ECOptionsBigmap::viewDidLoad");
}

// when the user taps Set (on iPad or in bigmap view), move the pin
- (IBAction) setAction: (id) sender {
    traceEnter("setAction");
    //set the labels et al based on the center of the mapView (in both map sizes)
    assert (!parent.useDeviceLocationSwitch.on);
    [parent updateToCoordinate:mapView.centerCoordinate horizontalError:0];
    pin.coordinate = mapView.centerCoordinate;
    traceExit("setAction");
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

// when the user taps the Map / Sat segmentedControl, switch the map type
- (IBAction) mapSatAction: (UISegmentedControl *) sender {
    traceEnter("mapSatAction");
    MKMapType state = 0;
    switch (sender.selectedSegmentIndex) {
	case 0:
	    state = MKMapTypeStandard;
	    break;
	case 1:
	    state = MKMapTypeHybrid;
	    break;
	case 2:
	    state = MKMapTypeSatellite;
	    break;
	default:
	    assert(false);
	    break;
    }
    mapView.mapType = state;
    [[NSUserDefaults standardUserDefaults] setInteger:state forKey:@"ECMapType"];
    traceExit ("mapSatAction");
}

- (void)viewWillAppear:(BOOL)animated {
    traceEnter("ECOptionsBigmap::viewWillAppear");

    CGRect fullScreen = CGRectMake(parentFrame.origin.x, 0 /*parentFrame.origin.y */, parentFrame.size.width, parentFrame.size.height - 64);  // CGRectMake(0, 0, 320, 416);
    mapView.frame = fullScreen;
    xhairView.frame = fullScreen;

    if (!parent.useDeviceLocationSwitch.on) {
	[mapView addAnnotation:pin];
    }
    mapView.showsUserLocation = parent.useDeviceLocationSwitch.on;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseLocationServices"]) {
	tracePrintf("starting ECLocationMgr");
	[ECLocationManager theLocationManager].delegate = (ECLocationManagerDelegate *)self;
	[[ECLocationManager theLocationManager] requestLocationUpdates];
    }
    mapView.userInteractionEnabled = true;
    [super viewWillAppear:animated];
    traceExit("ECOptionsBigmap::viewWillAppear");
}

- (void)viewWillDisappear:(BOOL)animated {
    traceEnter("ECOptionsBigmap::viewWillDisappear");
    [mapView removeAnnotation:pin];
    mapView.showsUserLocation = false;
    mapView.mapType = MKMapTypeStandard;
    [ECLocationManager theLocationManager].delegate = nil;
    traceExit("ECOptionsBigmap::viewWillDisappear");
}

- (void)follower {
    traceEnter("bigmap::follower");
    if (!centerSetDone) {
        CLLocationCoordinate2D newPosition;
        newPosition.latitude =  [[ECLocationManager theLocationManager]lastLatitudeDegrees];
        newPosition.longitude = [[ECLocationManager theLocationManager]lastLongitudeDegrees];
        [parent.mapView setCenterCoordinate:newPosition animated:YES];
        centerSetDone = true;
    }
    traceExit("bigmap::follower");
}

- (void)dealloc {
    traceEnter("ECOptionsBigmap::dealloc");

    if (settable) {
	[self.navigationItem.rightBarButtonItem release];
	self.navigationItem.rightBarButtonItem = nil;
    }
    [titleView release];
    [xhairView release];
    [mapSat release];
    [mapView release];
    
    [super dealloc];
    traceExit("ECOptionsBigmap::dealloc");
}

@end
