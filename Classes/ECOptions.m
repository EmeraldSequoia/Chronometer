//
//  ECOptions.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/29/2009.
//  Copyright Emerald Sequoia LLC 2009. All rights reserved.
//

#import "Constants.h"
#import "ECGlobals.h"
#undef ECTRACE
#import "ECTrace.h"
#import "ECOptions.h"
#import "ECOptionsDim.h"
#import "ECOptionsLoc.h"
#import "ECTS.h"
#import "ECGeoNames.h"
#import "ECWatchTime.h"
#import "ECGLWatch.h"
#import "ECGLTexture.h"
#import "ECWatchEnvironment.h"
#import "ECLocationManager.h"
#import "ECOptionsTZRoot.h"
#import "ChronometerAppDelegate.h"
#import "ECGLWatchLoader.h"
#import "ECAppLog.h"
#import "ECFactoryUI.h"
#import "ECMapGeneratorController.h"
#import "TSTime.h"
#include "ESCalendar.h"
#import "ECOptionsAlarm.h"
#import "ECOptionsWeekStart.h"

@implementation ECOptions

static CLLocationCoordinate2D center;
static ESTimeZone *currentTZ = nil;		    // the one now in use by the rest of EC
static ESTimeZone *tzOfCenter = nil;		    // the one that would be if autoTZ was ON
static NSString *currentCity = nil;
static NSString *currentRegion = nil;
static ECOptions *myself = nil;
static bool cityUnknown = true;

+ (void)initialize {
    bool oldVal = [[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseLocationServices"];
    [ECAppLog log:[NSString stringWithFormat:@"UseLocationServices %@", oldVal ? @"ON" : @"OFF"]];
    [ECAppLog log:[NSString stringWithFormat:@"AutoTZ %@", [[NSUserDefaults standardUserDefaults] boolForKey:@"ECAutoTZ"] ? @"ON" : @"OFF"]];
    if (oldVal) {
	[self setCurrentCityUnknown];
    } else {
	[ECOptions setCurrentCity:[[NSUserDefaults standardUserDefaults] stringForKey:@"ECCurrentCity"]
			   region:[[NSUserDefaults standardUserDefaults] stringForKey:@"ECCurrentRegion"]];
    }
}

+ (void)setCurrentCity:(NSString *)city region:(NSString *)region {
    traceEnter("setCurrentCity");
    tracePrintf2("%s, %s",[city UTF8String], [region UTF8String]);
    [currentCity release];
    currentCity = [city retain];
    [currentRegion release];
    currentRegion = [region retain];
    [[NSUserDefaults standardUserDefaults] setObject:currentCity forKey:@"ECCurrentCity"];
    [[NSUserDefaults standardUserDefaults] setObject:currentRegion forKey:@"ECCurrentRegion"];
    cityUnknown = false;
    traceExit("setCurrentCity");
}

+ (void)setCurrentCityUnknown {
    [ECOptions setCurrentCityUnknownIfAuto:@"<unknown>" region:@"working..."];
}

- (void)ensureDB {
    traceEnter("ensureDB");
    if (!needRelease) {
	[ChronometerAppDelegate reserveBytesOfMemory:2500000];
	//[ECGLWatchLoader pauseBGWhenDone];
	needRelease = true;
	tracePrintf("set needRelease");
    }
    if (locDB == nil) {
	locDB = [[ECGeoNames alloc] init];
    }
    traceExit("ensureDB");
}

- (void)locateMyself {
    if (cityUnknown) {
	[self ensureDB];
	[locDB findClosestCityToLatitudeDegrees:[[ECLocationManager theLocationManager]lastLatitudeDegrees] longitudeDegrees:[[ECLocationManager theLocationManager]lastLongitudeDegrees]];
	NSString *city = [locDB selectedCityName];
	NSString *region = [locDB selectedCityRegionName];
	[ECOptions setCurrentCity:city region:region];
    }
}

+ (void)setCurrentCityUnknownIfAuto:(NSString *)city region:(NSString *)region {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseLocationServices"]) {
	[self setCurrentCity:city region:region];
	cityUnknown = true;
	[myself.tableView reloadData];
    }
}

// utilities

+ (NSString *)formatTZOffset:(float)off {	    // examples: "-4" or "+5:30"
    return [NSString stringWithCString:ESCalendar_formatTZOffset(off) encoding:NSUTF8StringEncoding];
}

+ (double)minOffsetForTZ:(ESTimeZone *)tz {
    NSTimeInterval now = [TSTime currentTime];
    double offsetNow = ESCalendar_tzOffsetForTimeInterval(tz, now)/3600.0;
    NSTimeInterval nextDSTTransition = ESCalendar_nextDSTChangeAfterTimeInterval(tz, now);
    if (nextDSTTransition) {
	double offsetThen = ESCalendar_tzOffsetForTimeInterval(tz, nextDSTTransition + 1)/3600.0;
	return fmin(offsetNow, offsetThen);
    } else {
	return offsetNow;
    }
}

// typ == 1: "CHAST = UTC+12:45"  or  "CHADT = UTC+13:45 (Daylight)"
// typ == 2: "CHAST = UTC+12:45 : CHADT = UTC+13:45"
// typ == 3: "CHAST = UTC+12:45; (CHADT = UTC+13:45 on Nov 22, 2009)"
// typ == 4: "-10: -9" or "-10:-10"
// typ == 5: "CHAST"
+ (NSString *)formatInfoForTZ:(ESTimeZone *)estz type:(int)typ {	    
    return [NSString stringWithCString:ESCalendar_formatInfoForTZ(estz, typ) encoding:NSUTF8StringEncoding];
}

+ (NSString *)formatTime {
    return [NSString stringWithCString:ESCalendar_formatTime() encoding:NSUTF8StringEncoding];
}

+ (NSString *)currentTZName {
    return [NSString stringWithCString:ESCalendar_timeZoneName(currentTZ) encoding:NSUTF8StringEncoding];
}

+ (ESTimeZone *)currentTimeZone {
    return currentTZ;
}

+ (NSString *)currentTZInfo {
    return [self formatInfoForTZ:currentTZ type:3];
}

+ (NSInteger)currentTZOffset {
    return ESCalendar_tzOffsetForTimeInterval(currentTZ, [TSTime currentTime]);
}

+ (NSString *)currentShortTZInfo {
    return [self formatInfoForTZ:currentTZ type:1];
}

+ (NSString *)currentCity {
    return currentCity;
}

+ (NSString *)currentRegion {
    return currentRegion;
}

+ (NSString *)currentCityRegion {
    return [NSString stringWithFormat:NSLocalizedString(@"%@, %@", "city, region"), currentCity, currentRegion];
}

+ (NSString *)currentTZSourceInfoGuts:(NSString *)loc {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ECAutoTZ"]) {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseLocationServices"]) {
	    return [NSString stringWithFormat:NSLocalizedString(@"(auto from %@)",@"automatic timezone source"), [[UIDevice currentDevice] localizedModel]];
	} else {
	    return [NSString stringWithFormat:NSLocalizedString(@"(auto from %@)",@"automatic timezone source"), loc];
	}
	
    } else {
	return NSLocalizedString(@"(manual)",@"manual timezone setting indication");
    }
}

+ (NSString *)currentTZSource {
    return [ECOptions currentTZSourceInfoGuts:@"location"];
}

static ESTimeZone *lastWarnedTZ = nil;
static float lastWarnedLong = -200;

+ (void)checkSanityForTimezone:(ESTimeZone *)estz position:(CLLocationCoordinate2D)pos {
    if (pos.latitude == 0 && pos.longitude == 0) {
	//tracePrintf("checkSanityForTimezone: nowhere");
	return;
    }
    NSTimeInterval now = [TSTime currentTime];
    float tzCenter = (ESCalendar_tzOffsetForTimeInterval(estz, now)/3600 - ESCalendar_isDSTAtTimeInterval(estz, now)) * 15;
    if (fabs([TSTime dateRSkew]) > TOOBIGSKEW || fabs(pos.longitude - lastWarnedLong) < 0.01 && estz == lastWarnedTZ) {
	//tracePrintf("checkSanityForTimezone: same bad place as previously");
	return;
    }
    float delta = fabs(pos.longitude - tzCenter);
    if (delta > 180) {
	delta = 360 - delta;
    }
    if (delta > 25) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Warning", @"Warning")
                                                                       message:[NSString stringWithFormat:NSLocalizedString(@"%@\ncentered at %d %s\n\nmay be inappropriate for\n\n%@\n%@\n%@\n(± %.0f meters)",@"format for timezone/longitude mismatch"),
								      [self formatInfoForTZ:estz type:1],
								      (int)fabsf(tzCenter), tzCenter == 0 ? " " : tzCenter < 0 ? "W" : "E",
								      currentCity, currentRegion,
								      [ECLocationManager positionStringForLatitude:pos.latitude longitude:pos.longitude],
								      [[ECLocationManager theLocationManager] lastHorizontalErrorMeters]]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* okButton = [UIAlertAction
                                      actionWithTitle:@"OK"
                                                style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction * action) {
            }];
        [alert addAction:okButton];
        UIViewController *iOSWantsAViewControllerToDoThisSoHereIsOne = [[UIViewController alloc] init];
        [iOSWantsAViewControllerToDoThisSoHereIsOne presentViewController:alert animated:YES completion:nil];
        [iOSWantsAViewControllerToDoThisSoHereIsOne release];
        
	//tracePrintf("checkSanityForTimezone: gave warning");
	lastWarnedLong = pos.longitude;
	lastWarnedTZ = estz;
    } else {
	//tracePrintf("checkSanityForTimezone: OK");
	lastWarnedLong = -200;
	lastWarnedTZ = NULL;
    }
}

+ (NSString *)currentTZSourceInfo {
    return [ECOptions currentTZSourceInfoGuts:[ECOptions currentCityRegion]];
}

// get the saved timezone or use default
// ESCalendar has no autorelease semantics; returned timezone is retained, so release if you're not going to use it.
+ (ESTimeZone *)defaultTZ {
    NSString *tzName = nil;
    if (!([[NSUserDefaults standardUserDefaults] boolForKey:@"ECAutoTZ"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseLocationServices"])) {
	tzName = [[NSUserDefaults standardUserDefaults] stringForKey:@"ECTimeZone"];
    }
    if (tzName == nil) {
	return ESCalendar_retainTimeZone(ESCalendar_localTimeZone());
    } else {
	return ESCalendar_initTimeZoneFromOlsonID([tzName UTF8String]);
    }
}

// Semantics: if tz non-nil, has been pre-retained (because ESTimeZone has no auto-release)
+ (void)setTimeZone:(ESTimeZone *)tz updateWatches:(bool)updateWatches {
    traceEnter("setTimeZone");
    if (tz) {
        tracePrintf1("       tz=%s",ESCalendar_timeZoneName(tz));
	[self checkSanityForTimezone:tz position:center];
    } else {		// nil means we're now in autoTZ mode
        tracePrintf("       tz=nil");
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseLocationServices"]) {
	    tz = ESCalendar_retainTimeZone(ESCalendar_localTimeZone());
	} else {
	    if (tzOfCenter) {
		tz = ESCalendar_retainTimeZone(tzOfCenter);
	    } else {
		tz = [self defaultTZ];
	    }
	}
    }
    if (currentTZ != tz) {
	ESCalendar_releaseTimeZone(currentTZ);
	currentTZ = ESCalendar_retainTimeZone(tz);
	tracePrintf1("currentTZ=%s", ESCalendar_timeZoneName(tz));
	if (updateWatches) {
	    [ChronometerAppDelegate setTimeZone:tz];
	}
	[[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithCString:ESCalendar_timeZoneName(tz) encoding:NSUTF8StringEncoding] forKey:@"ECTimeZone"];
    } else {
	ESCalendar_releaseTimeZone(tz);  // Didn't need it, so release it
    }
    traceExit("setTimeZone");
}

+ (void)setTimeZoneWithName:(NSString *)tzName updateWatches:(bool)updateWatches {
    [self setTimeZone:ESCalendar_initTimeZoneFromOlsonID([tzName UTF8String]) updateWatches:updateWatches];
}

+ (void)autoTZUpdate {	    // for CAD::applicationSignificantTimeChange
    traceEnter("autoTZUpdate");
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ECAutoTZ"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseLocationServices"]) {
	center.latitude =  [[ECLocationManager theLocationManager]lastLatitudeDegrees];	    // avoid bogus warning
	center.longitude = [[ECLocationManager theLocationManager]lastLongitudeDegrees];
	[ECOptions setTimeZone:ESCalendar_localTimeZone() updateWatches:true];
    }
    traceExit("autoTZUpdate");
}

+ (void)setTimezone:(ESTimeZone *)tz andCenter:(CLLocationCoordinate2D)newCenter {
    traceEnter("setTZandCenter");
    center = newCenter;
    ESCalendar_releaseTimeZone(tzOfCenter);
    tzOfCenter = ESCalendar_retainTimeZone(tz);
    tracePrintf1("tz for center=%s", ESCalendar_timeZoneName(tz));
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ECAutoTZ"]) {
	[ECOptions setTimeZone:NULL updateWatches:true];
    } else {
	[self checkSanityForTimezone:currentTZ position:center];
    }

    traceExit("setTZandCenter");
}

+ (void)setAutoLoc:(bool)newVal {
    bool oldVal = [[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseLocationServices"];
    if (oldVal != newVal) {
	[[NSUserDefaults standardUserDefaults] setBool:newVal forKey:@"ECUseLocationServices"];
	[ECAppLog log:[NSString stringWithFormat:@"UseLocationServices %@", newVal ? @"ON" : @"OFF"]];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ECAutoTZ"]) {
	    [ECOptions setTimeZone:NULL  updateWatches:true];	    // NULL means "auto"
	}
    }
}

+ (void)setAutoTZ:(bool)newVal {
    if (newVal) {
	[ECOptions setTimeZone:nil updateWatches:true];	    // nil means "auto"
    }
    [[NSUserDefaults standardUserDefaults] setBool:newVal forKey:@"ECAutoTZ"];
    [ECAppLog log:[NSString stringWithFormat:@"AutoTZ %@", newVal ? @"ON" : @"OFF"]];
}

+ (void)restoreTZ {
    [self setTimeZone:[self defaultTZ] updateWatches:true];
}

+ (bool)purpleZone {
    NSTimeInterval now = [TSTime currentTime];
    return ESCalendar_tzOffsetForTimeInterval(ESCalendar_localTimeZone(), now)
	!= ESCalendar_tzOffsetForTimeInterval(currentTZ, now);
}

// action methods

- (void)quitMe:(id)sender {
    [ChronometerAppDelegate optionDone];
}

- (void)helpOpt:(id)sender {
    [ChronometerAppDelegate optionToHelp:@"Settings"];
}

- (void)NTPAction:(UISwitch*)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"ECUseNTP"];
    if (sender.on) {
	[ECTS reSync];
    } else {
	[ECTS stopNTP];
    }
}

- (void)DALAction:(UISwitch*)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"ECDisableAutoLock"];
    [ChronometerAppDelegate setDALForBatteryState];
}

- (void)DALAction2:(UISwitch*)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"ECDisableAutoLockUnplugged"];
    [ChronometerAppDelegate setDALForBatteryState];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //[ChronometerAppDelegate cancelMainThreadRedrawUpdate];
    ESCalendar_localTimeZoneChanged();  // May be unnecessary

    self.title = NSLocalizedString(@"Settings",@"Main settings screen title");
    UINavigationItem *navItem = self.navigationItem;
    navItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(quitMe:)] autorelease];
    //navItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(quitMe:)] autorelease];
    //navItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"backWatch2.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(quitMe:)] autorelease];
}

- (void)viewDidAppear:(BOOL)animated {
    [self.tableView reloadData];
    myself = self;
    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
   myself = nil;
}

// Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return ECSingleWatchProduct ? 2 : 3;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
	case 0:		    // time & location
	    return 3;
	case 1:		    // DAL
	    return 2;
	case 2:		    // watch options
	    return 3;
#ifndef NDEBUG
	case 3:		    // testing
	    return 1;
#endif
	default:
	    assert(false);
	    return 0;
    }
}

// Customize the appearance of table view cells.
#define ROW_HEIGHT 50.0
#define MAIN_FONT_SIZE 16
#define CITY_FONT_SIZE 16
#define V_OFFSET 7
#define REGION_FONT_SIZE 11
#define LABEL_OFFSET 10
#define RIGHT_OFFSET 100
#define ACC_WIDTH 15
#define LABEL_WIDTH 175
#define TLABEL_WIDTH 75
#define RIGHT_WIDTH 170
#define SWITCH_OFFSET (LABEL_OFFSET+LABEL_WIDTH+10)
#define STD_TABLE_WIDTH 320

- (UITableViewCell *)tripleCell:(NSString *)constant tableWidth:(CGFloat)tableWidth top:(NSString *)top bottom:(NSString *)bottom rightColor:(UIColor *)rightColor {
    UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ECTripleCell"] autorelease];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    // constant label
    // Deprecated iOS 7:  CGSize size = [@"8" sizeWithFont:[UIFont boldSystemFontOfSize:MAIN_FONT_SIZE] forWidth:TLABEL_WIDTH lineBreakMode:UILineBreakModeClip];  
    CGRect sizeRect = [@"8" boundingRectWithSize:CGSizeMake(TLABEL_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:MAIN_FONT_SIZE]} context:nil];
    CGFloat sizeHeight = ceil(sizeRect.size.height);
    CGRect rect = CGRectMake(LABEL_OFFSET, (ROW_HEIGHT - sizeHeight) / 2.0, TLABEL_WIDTH, sizeHeight);
    UILabel *label = [[UILabel alloc] initWithFrame:rect];
    label.font = [UIFont boldSystemFontOfSize:MAIN_FONT_SIZE];
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    label.highlightedTextColor = [UIColor whiteColor];
    label.text = constant;
    label.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    [cell.contentView addSubview:label];
    [label release];
    // city or Olson Id
    // Deprecated iOS 7:  size = [@"8" sizeWithFont:[UIFont systemFontOfSize:CITY_FONT_SIZE] forWidth:RIGHT_WIDTH lineBreakMode:UILineBreakModeClip];  
    sizeRect = [@"8" boundingRectWithSize:CGSizeMake(RIGHT_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:CITY_FONT_SIZE]} context:nil];
    sizeHeight = ceil(sizeRect.size.height);
    rect = CGRectMake(RIGHT_OFFSET + tableWidth - STD_TABLE_WIDTH, V_OFFSET, RIGHT_WIDTH, sizeHeight);
    label = [[UILabel alloc] initWithFrame:rect];
    label.font = [UIFont systemFontOfSize:CITY_FONT_SIZE];
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    label.highlightedTextColor = [UIColor whiteColor];
    label.textColor = rightColor;
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentRight;
    label.text = top;
    [cell.contentView addSubview:label];
    [label release];
    // region or TZ info
    // Deprecated iOS 7:  size = [@"8" sizeWithFont:[UIFont systemFontOfSize:REGION_FONT_SIZE] forWidth:RIGHT_WIDTH lineBreakMode:UILineBreakModeClip];  
    sizeRect = [@"8" boundingRectWithSize:CGSizeMake(RIGHT_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:REGION_FONT_SIZE]} context:nil];
    sizeHeight = ceil(sizeRect.size.height);
    rect = CGRectMake(RIGHT_OFFSET + tableWidth - STD_TABLE_WIDTH, (ROW_HEIGHT - sizeHeight)-V_OFFSET, RIGHT_WIDTH, sizeHeight);
    label = [[UILabel alloc] initWithFrame:rect];
    label.font = [UIFont systemFontOfSize:REGION_FONT_SIZE];
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    label.highlightedTextColor = [UIColor whiteColor];
    label.textColor = rightColor;
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentRight;
    label.text = bottom;
    [cell.contentView addSubview:label];
    [label release];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    UIFont *font = [UIFont boldSystemFontOfSize:MAIN_FONT_SIZE];
    UISwitch *switchCtl = nil;
    UILabel *label = nil;
    CGRect sizeRect;  
    CGRect rect;
    CGFloat sizeHeight;
    CGFloat tableWidth = tableView.bounds.size.width;

    switch (indexPath.section) {
	case 0:		    // Location & Time
	    switch (indexPath.row) {
		case 0:		// location
		    [self locateMyself];
		    cell = [self tripleCell:NSLocalizedString(@"Location", @"Location label")
                                 tableWidth:tableWidth
					top:currentCity
				     bottom:currentRegion
				 rightColor:[[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseLocationServices"] ? [UIColor systemBlueColor] : [UIColor systemPurpleColor]];
		    break;
		case 1:		// timezone
		    cell = [self tripleCell:NSLocalizedString(@"Timezone", @"Timezone option label")
                                 tableWidth:tableWidth
					top:[ECOptions currentTZName] 
				     bottom:[ECOptions currentShortTZInfo] 
				 rightColor:[[NSUserDefaults standardUserDefaults] boolForKey:@"ECAutoTZ"] ? [UIColor systemBlueColor] : [UIColor systemPurpleColor]];
		    break;
		case 2:		// NTP
		    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ECSwitchCell"] autorelease];
		    cell.selectionStyle = UITableViewCellSelectionStyleNone;
		    // label
		    // Deprecated iOS 7:  size = [@"8" sizeWithFont:font forWidth:LABEL_WIDTH lineBreakMode:UILineBreakModeClip];  
                    sizeRect = [@"8" boundingRectWithSize:CGSizeMake(LABEL_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:font} context:nil];
                    sizeHeight = ceil(sizeRect.size.height);
		    rect = CGRectMake(LABEL_OFFSET, (ROW_HEIGHT - sizeHeight) / 2.0, LABEL_WIDTH, sizeHeight);
		    label = [[UILabel alloc] initWithFrame:rect];
		    label.font = font;
		    label.adjustsFontSizeToFitWidth = YES;
		    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
		    [cell.contentView addSubview:label];
                    label.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
		    label.highlightedTextColor = [UIColor whiteColor];
		    label.text = NSLocalizedString(@"Use NTP", @"NTP option item label");
		    [label release];
		    // switch
		    rect = CGRectMake(SWITCH_OFFSET, (ROW_HEIGHT-kSwitchButtonHeight)/2.0, kSwitchButtonWidth, kSwitchButtonHeight);
		    switchCtl = [[UISwitch alloc] initWithFrame:rect];
		    [switchCtl addTarget:self action:@selector(NTPAction:) forControlEvents:UIControlEventValueChanged];
		    switchCtl.backgroundColor = [UIColor clearColor];
		    switchCtl.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"ECUseNTP"];
                    switchCtl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		    [cell.contentView addSubview:switchCtl];
		    [switchCtl release];
		    break;
		default:
		    assert(false);
		    cell = nil;
	    }
	    break;
	case 1:		// Disable Auto-lock
	    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ECSwitchCell"] autorelease];
	    cell.selectionStyle = UITableViewCellSelectionStyleNone;
	    switch (indexPath.row) {
		case 0:
		    // label
                    // Deprecated iOS 7:  size = [@"8" sizeWithFont:font forWidth:LABEL_WIDTH lineBreakMode:UILineBreakModeClip];  
                    sizeRect = [@"8" boundingRectWithSize:CGSizeMake(LABEL_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:font} context:nil];
                    sizeHeight = ceil(sizeRect.size.height);
		    rect = CGRectMake(LABEL_OFFSET, (ROW_HEIGHT - sizeHeight) / 2.0, LABEL_WIDTH, sizeHeight);
		    label = [[UILabel alloc] initWithFrame:rect];
		    label.font = font;
		    label.adjustsFontSizeToFitWidth = YES;
		    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
		    [cell.contentView addSubview:label];
		    label.highlightedTextColor = [UIColor whiteColor];
                    label.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
		    label.text = NSLocalizedString(@"... when Plugged In", @"Disable auto-lock when on charger option label");
		    [label release];
		    // switch
		    rect = CGRectMake(SWITCH_OFFSET, (ROW_HEIGHT-kSwitchButtonHeight)/2.0, kSwitchButtonWidth, kSwitchButtonHeight);
		    switchCtl = [[UISwitch alloc] initWithFrame:rect];
		    [switchCtl addTarget:self action:@selector(DALAction:) forControlEvents:UIControlEventValueChanged];
		    switchCtl.backgroundColor = [UIColor clearColor];
		    switchCtl.on =[[NSUserDefaults standardUserDefaults] boolForKey:@"ECDisableAutoLock"];
                    switchCtl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		    [cell.contentView addSubview:switchCtl];
		    [switchCtl release];
		    break;
		case 1:
		    // label
		    // Deprecated iOS 7:  size = [@"8" sizeWithFont:font forWidth:LABEL_WIDTH lineBreakMode:UILineBreakModeClip];  
                    sizeRect = [@"8" boundingRectWithSize:CGSizeMake(LABEL_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:font} context:nil];
                    sizeHeight = ceil(sizeRect.size.height);
		    rect = CGRectMake(LABEL_OFFSET, (ROW_HEIGHT - sizeHeight) / 2.0, LABEL_WIDTH, sizeHeight);
		    label = [[UILabel alloc] initWithFrame:rect];
		    label.font = font;
		    label.adjustsFontSizeToFitWidth = YES;
		    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
		    [cell.contentView addSubview:label];
		    label.highlightedTextColor = [UIColor whiteColor];
                    label.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
		    label.text = NSLocalizedString(@"... when on Battery", @"disable auto-lock when unplugged option label");
		    [label release];
		    // switch
		    rect = CGRectMake(SWITCH_OFFSET, (ROW_HEIGHT-kSwitchButtonHeight)/2.0, kSwitchButtonWidth, kSwitchButtonHeight);
		    switchCtl = [[UISwitch alloc] initWithFrame:rect];
		    [switchCtl addTarget:self action:@selector(DALAction2:) forControlEvents:UIControlEventValueChanged];
                    switchCtl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		    switchCtl.backgroundColor = [UIColor clearColor];
		    switchCtl.on =[[NSUserDefaults standardUserDefaults] boolForKey:@"ECDisableAutoLockUnplugged"];
		    [cell.contentView addSubview:switchCtl];
		    [switchCtl release];
		    break;
		default:
		    assert(false);
	    }
	    break;
	case 2:		    // Watch options
	    if (!ECSingleWatchProduct) {
		switch (indexPath.row) {
		    case 0:
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
			cell.textLabel.text = NSLocalizedString(@"Terra World-time Ring", @"Terra front city ring options label");
			break;
		    case 1:
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
			cell.textLabel.text = NSLocalizedString(@"Terra Back Subdials", @"Terra back subdials options label");
			break;
		    case 2:
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil] autorelease];
			cell.textLabel.text = NSLocalizedString(@"Babylon Week Start", @"Babylon first day of week label");
			switch (ECCalendarWeekdayStart) {
			    case 0:
				cell.detailTextLabel.text = @"Sunday";
				break;
			    case 1:
				cell.detailTextLabel.text = @"Monday";
				break;
			    case 6:
				cell.detailTextLabel.text = @"Saturday";
				break;
			    default:
				assert(false);
				break;
			}
			break;
		    case 3:
			assert(false);
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil] autorelease];
			cell.textLabel.text = NSLocalizedString(@"Alarm Watches Sound", @"Alarm options label");
			cell.detailTextLabel.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"ECAlarmName"];
			break;
		    default:
			assert(false);
			cell = nil;
		}
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	    } else {
		assert(false);
	    }
	    break;
	default:
	    assert(false);
	    cell = nil;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIViewController *vc = nil;
    switch (indexPath.section) {
	case 0:	    // location
	    switch (indexPath.row) {
		case 0:		// set location
		    [self ensureDB];
		    vc = [[ECOptionsLoc alloc] initWithNibName:@"ECOptionsLoc" bundle:nil locDB:locDB];
		    [self.navigationController pushViewController:vc animated:true];
		    [vc release];
		    break;
		case 1:		// set timezone
		    vc = [[[ECOptionsTZRoot alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
		    [self.navigationController pushViewController:vc animated:true];
                    tracePrintf("pushed ECOptionsTZRoot controller");
		    if (center.latitude == 0 && center.longitude == 0) {
			// so the warnings will work if we haven't yet run ECOptionsLoc
			center.latitude =  [[ECLocationManager theLocationManager]lastLatitudeDegrees];
			center.longitude = [[ECLocationManager theLocationManager]lastLongitudeDegrees];
		    }
		    break;
		case 2:		// NTP
		    break;
		default:
		    assert(false);
	    }
	    break;
	case 1:	    // DAL
	    break;
	case 2:	    // per-watch options
	    if (indexPath.row == 0 || indexPath.row == 1) {
		ECGLWatch *watch = [ChronometerAppDelegate availableWatchWithName:@"Terra"];
		[ChronometerAppDelegate waitForWatchToLoad:watch];
		int firstEnvSlot;
		int numSlots;
		bool constrainToZones;
		if (indexPath.row == 0) {
		    firstEnvSlot = 5;  // Really ought to get this from the watch
		    numSlots = 24;  // Really ought to get this from the watch
		    constrainToZones = true;  // Really ought to get this from the watch
		} else {
		    firstEnvSlot = 1;  // Really ought to get this from the watch
		    numSlots = 4;  // Really ought to get this from the watch
		    constrainToZones = false;  // Really ought to get this from the watch
		}
		[self ensureDB];
		vc = [[[ECFactoryUI alloc] initForWatch:watch withFirstEnvSlot:firstEnvSlot numSlots:numSlots constrainToZones:constrainToZones locDB:locDB] autorelease];
		[self.navigationController pushViewController:vc animated:true];
	    } else if (indexPath.row == 2) {
		vc = [[[ECOptionsWeekStart alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
		[self.navigationController pushViewController:vc animated:true];
	    } else if (indexPath.row == 3) {
		assert(false);
		vc = [[[ECOptionsAlarm alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
		[self.navigationController pushViewController:vc animated:true];
	    } else {
		assert(false);
	    }
	    break;
#ifndef NDEBUG
	case 3:
	    [self ensureDB];
	    [self.navigationController pushViewController:[[[ECMapGeneratorController alloc] initWithDB:locDB] autorelease] animated:true];
	    break;
#endif
	default:
	    assert(false);
    }
}

/*
- (void)viewWillAppear:(BOOL)animated {
    [self.tableView reloadData];	    // only neede for Units
    [super viewWillAppear:animated];
}
*/

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
	default:
	    assert(false);
	    break;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    assert([indexPath indexAtPosition:0] <= 4);
    assert([indexPath length] == 2);
    return ROW_HEIGHT;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
	case 0:
	    return NSLocalizedString(@"Location & Time", @"time & position options section header");
	case 1:
	    return NSLocalizedString(@"Disable Auto-Lock", @"disable auto lock section header");
	case 2:
	    return NSLocalizedString(@"Watch-specific Settings", @"settings that apply to only one watch");
#ifndef NDEBUG
	case 3:
	    return NSLocalizedString(@"\n\nDEBUG ONLY", @"debug section header");
#endif
	default:
	    assert(false);
	    return @"Huh?";
    }
}

- (void)dealloc {
    traceEnter("ECOptions::dealloc");
    //[ChronometerAppDelegate resumeMainThreadRedrawUpdate];
    [locDB release];
    if (needRelease) {
	tracePrintf("needRelease was true");
	[ChronometerAppDelegate releaseReservedMemory];
	[ECGLWatchLoader resumeBG];
    }
    [super dealloc];
    traceExit ("ECOptions::dealloc");
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return isIpad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

@end
