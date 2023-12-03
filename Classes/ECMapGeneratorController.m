#ifndef NDEBUG
//
//  ECDebugController.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 3/6/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "ECMapGeneratorController.h"
#import "ECMapGeneratorView.h"
#import "Constants.h"

@implementation ECMapGeneratorController

- (ECMapGeneratorController *)initWithDB:(ECGeoNames *)db {
    if (self = [super init]) {
	assert(db);
	locDB = [db retain];
    }
    return self;
};

- (void)loadView {
    CGRect myRect = [[UIScreen mainScreen] bounds];
    // create empty background
    UIView *contentView = [[UIView alloc] initWithFrame:myRect];
    contentView.opaque = YES;
//    contentView.autoresizesSubviews = YES;
//    contentView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    self.view = contentView;
    [contentView release];
    self.view.backgroundColor = [UIColor colorWithRed:0.85 green:0.95 blue:1.0 alpha:1.0];
    mapView = [[[UILabel alloc] initWithFrame:CGRectMake(10, 50, 300, 300)] autorelease];
    ((UILabel *)mapView).numberOfLines = 10;
    ((UILabel *)mapView).text = @"Push the Face button to generate a new version of Terra's front decoration.\n\nPush the Maps button to generate the little maps for the FactoryUI.\n\nPush the Show button to display a timezone map of all cities.";
    mapView.backgroundColor = [UIColor colorWithRed:0.85 green:0.95 blue:1.0 alpha:1.0];
    [self.view addSubview:mapView];
    [mapView setNeedsDisplay];
    spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.center = CGPointMake(160, 200);
    spinner.hidesWhenStopped = true;
}

static int doOneCounter = 0;
static NSTimer *doOneTimer = nil;

- (void)doOne:(id)foo {
    assert(doOneCounter <= 23);
    int x = floor(doOneCounter / 8) * 90;
    int y = (doOneCounter % 8) * 46;
    CGRect myRect = CGRectMake(x+(320-90*3)/2, y+(420-46*8)/2, 90, 46);	    //[[UIScreen mainScreen] applicationFrame];
    mapView = [[[ECMapGeneratorView alloc] initWithFrame:myRect type:2 forSlot:doOneCounter inputFile:@"world90.png" outputFile:[NSString stringWithFormat:@"/slotMap%02d.png", doOneCounter] locDB:locDB] autorelease];
    [self.view addSubview:mapView];

    doOneCounter++;
    if (doOneCounter == 24) {
	[doOneTimer invalidate];
	doOneTimer = nil;
    }
}

- (void)doCase0 {
    mapView = [[[ECMapGeneratorView alloc] initWithFrame:CGRectMake(0, (460-162-kToolbarHeight)/2, 320, 162) type:0 forSlot:0 inputFile:@"world320.png" outputFile:nil locDB:locDB] autorelease];
    [self.view addSubview:mapView];
    [spinner stopAnimating];
}

- (void)opAction:(id)foo {
    for (UIView *v in self.view.subviews) {
	[v removeFromSuperview];
    }
    switch (opType.selectedSegmentIndex) {
	case 0:
	    self.view.backgroundColor = [UIColor colorWithRed:0.85 green:0.95 blue:1.0 alpha:1.0];
	    [self.view addSubview:spinner];
	    [spinner startAnimating];
	    [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(doCase0) userInfo:nil repeats:NO];
	    break;
	case 1:
	    self.view.backgroundColor = [UIColor whiteColor];
	    mapView = [[[ECMapGeneratorView alloc] initWithFrame:CGRectMake((320-180)/2, (460-91-kToolbarHeight)/2, 180, 91) type:1 forSlot:0 inputFile:@"world180.png" outputFile:@"/world180RobBWCities24.png" locDB:locDB] autorelease];
	    [self.view addSubview:mapView];
	    break;
	case 2:
	    self.view.backgroundColor = [UIColor whiteColor];
	    doOneCounter = 0;
	    doOneTimer = [NSTimer scheduledTimerWithTimeInterval:0.001 target:self selector:@selector(doOne:) userInfo:nil repeats:YES];
	    break;
	default:
	    assert(false);
	    break;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    titleView = [[UIView alloc] initWithFrame:CGRectMake(120, 50, 140, 30)];
    opType = [[UISegmentedControl alloc] initWithFrame:CGRectMake(0, 0, 140, 30)];
    // Deprecated iOS 7 as no-op:  opType.segmentedControlStyle = UISegmentedControlStyleBar;
    opType.tintColor = [UIColor darkGrayColor];
    [opType insertSegmentWithTitle:NSLocalizedString(@"Show", @"just display all cites") atIndex:0 animated:false];
    [opType insertSegmentWithTitle:NSLocalizedString(@"Face", @"do the front face") atIndex:1 animated:false];
    [opType insertSegmentWithTitle:NSLocalizedString(@"Maps", @"do the little maps") atIndex:2 animated:false];
    [opType addTarget:self action:@selector(opAction:) forControlEvents:UIControlEventAllEvents];
    [titleView addSubview:opType];
    self.navigationItem.titleView = titleView;
}

- (void)dealloc {
    [doOneTimer invalidate];
    [locDB release];
    [spinner release];
    [super dealloc];
}


@end

#endif
