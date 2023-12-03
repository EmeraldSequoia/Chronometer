//
//  ECFactoryUI.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 1/18/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#undef ECTRACE
#import "ECTrace.h"
#import "ECErrorReporter.h"
#import "ECFactoryUI.h"
#import "ECFactoryUISlotSearch.h"
#import "ECFactoryUIGlobalSearch.h"
#import "ECGeoNames.h"
#import "ECOptions.h"
#import "ECWatchEnvironment.h"
#import "ECGLWatch.h"
#import "ECGlobals.h"

#define UTCSectorNumber 11
#define UTCSectorOffsetVal (UTCSectorNumber - 0.5)
#define ringSectorToEnvSlot(i) (i+firstEnvSlot)
#define subdialToEnvSlot(i)    (i+firstEnvSlot)
#define envSlotToOffset(i)     (i-firstEnvSlot-UTCSectorNumber)
#define offsetToEnvSlot(i)     (i+firstEnvSlot+UTCSectorNumber)
#define ringSectorToOffset(i)  (i-UTCSectorNumber)

typedef struct ringDefault {
    const char 		    	  *cityName;
    const char              	  *OlsonID;
    double			  lat;
    double			  lng;
} ringDefault;

static const ringDefault ringDefaults[29] = {                            // envSlot    subdial             position on Terra back
    {"",              "",                         0,          0      },  //    0
    {"San Francisco", "America/Los_Angeles",     37.77493, -122.41942},	 //    1          0                left (big)
    {"Denver",        "America/Denver",          39.73915, -104.98470},	 //    2          1                top
    {"Chicago",       "America/Chicago",         41.85003,  -87.65005},	 //    3          2                right
    {"New York",      "America/New_York",        40.71427,  -74.00597},	 //    4          3                bottom
									 //           ringSector offset    other cities                                   half hour zones
    {"Pago Pago",     "Pacific/Pago_Pago",      -14.27806, -170.70250},	 //    5          0       -11   X: Apia (Samoa)
    {"Honolulu",      "Pacific/Honolulu",        21.30694, -157.85834},	 //    6          1       -10   W: Papeete
    {"Anchorage",     "America/Juneau",          61.21806, -149.90028},	 //    7          2       -9    V: Juneau
    {"Los Angeles",   "America/Los_Angeles",     34.05223, -118.24368},	 //    8          3       -8    U: Vancouver
    {"Denver",        "America/Denver",          39.73915, -104.98470},	 //    9          4       -7    T: Ciudad Juarez, Phoenix, Calgary, Albuquerque
    {"Chicago",       "America/Chicago",         41.85003,  -87.65005},	 //   10          5       -6    S: Mexico City, Houston, Winnepeg
    {"New York",      "America/New_York",        40.71427,  -74.00597},	 //   11          6       -5    R: Lima, Bogota, Toronto, Montreal		-4:30: Caracas
    {"Santiago",      "America/Santiago",       -33.42628,  -70.56655},	 //   12          7       -4    Q: Halifax, San Juan (Puerto Rico)		-3:30: St. John's (Newfoundland)
    {"Rio de Janeiro","America/Sao_Paulo",      -22.90278,  -43.20750},	 //   13          8       -3    P: Buenos Aires, Sao Paulo
    {"Grytviken",     "Atlantic/South_Georgia", -54.27667,  -36.51167},	 //   14          9       -2    O: (South Georgia)
    {"Dakar",	      "Africa/Dakar",		 14.74208,  -17.43978},	 //   15         10       -1    N: 1:00: Praia (Cape Verde), (Azores)
    {"London",        "Europe/London",           51.50842,   -0.12553},	 //   16         11        0    Z: Casablanca, Lisbon, Reykjavik, Accra (Ghana)
    {"Paris",         "Europe/Paris",            48.85341,    2.34880},	 //   17         12       +1    A: Lagos, Rome, Algiers, Kinshasa, Berlin
    {"Cairo",         "Africa/Cairo",            30.05000,   31.25000},	 //   18         13       +2    B: Istanbul, Cape Town, Jerusalem, Kiev, Kaliningrad
    {"Moscow",        "Europe/Moscow",           55.75222,   37.61555},	 //   19         14       +3    C: Baghdad, Nairobi, Mecca			+3:30: Tehran
    {"Dubai",         "Asia/Dubai",              25.25222,   55.28000},	 //   20         15       +4    D: Samara, Baku, Mauritius
    {"Delhi",	      "Asia/Kolkata",            28.66667,   77.21666},	 //   21         16       +5    E: 5:30: India, Colombo				+5:00: Lahore, Yekaterinburg, Tashkent, Maldives	+5:45: Kathmandu
    {"Dhaka",         "Asia/Dhaka",              23.72305,   90.40861},	 //   22         17       +6    F: Omsk, Novosibirsk, Almaty (Kazakhstan)	+6:30: Rangoon
    {"Bangkok",       "Asia/Bangkok",            13.75000,  100.51667},	 //   23         18       +7    G: Jakarta, Krasnoyarsk
    {"Hong Kong",     "Asia/Hong_Kong",          22.28401,  114.15007},	 //   24         19       +8    H: Shanghai, Beijing, Irkutsk, Singapore, Perth
    {"Tokyo",         "Asia/Tokyo",              35.68953,  139.69168},	 //   25         20       +9    I: Seoul, Yakutsk				+9:30: Darwin, Adelaide
    {"Sydney",        "Australia/Sydney",       -33.86785,  151.20732},	 //   26         21      +10    K: Melbourne, Brisbane, Vladivostok
    {"Nouméa",        "Pacific/Noumea",         -22.26667,  166.45000},	 //   27         22      +11    L: Magadan (Russia)
    {"Auckland",      "Pacific/Auckland",       -36.86666,  174.76666},	 //   28         23      +12    M: Kamchatka,  Suva (Fiji)
};									 


@implementation ECFactoryUI

- (ECFactoryUI *)initForWatch:(ECGLWatch *)aWatch withFirstEnvSlot:(int)envSlot numSlots:(int)numSlots constrainToZones:(bool)constrainToZone locDB:(ECGeoNames *)db {
    if (self = [super initWithStyle:UITableViewStyleGrouped]) {
	assert(db);
	nSlots = numSlots;
	constrainToZones = constrainToZone;
	firstEnvSlot = envSlot;
	watch = [aWatch retain];
	locDB = [db retain];
    }
    return self;
}

+ (void)ensureTZValidityForWatch:(ECGLWatch *)watch env:(int)i{
    int firstEnvSlot = 5;  // Note: NOT unused; is used in macros
    // check that this timezone is still OK for this slot; it may not be if this is the first run on a new version of iPhoneOS and the Olson database has been updated
    NSString *tzName = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"%@-timeZone-%d", watch.name, i]];
    if (tzName == nil) {
#ifdef NDEBUG
	return;	    // check the defaults only in DEBUG builds
#endif
	tzName = [NSString stringWithUTF8String:ringDefaults[i].OlsonID];
    }
    NSString *tzVersion = [NSString stringWithCString:ESCalendar_version() encoding:NSUTF8StringEncoding];
    if ([tzVersion compare:[[NSUserDefaults standardUserDefaults] stringForKey:@"testedTzVersion"]] == NSOrderedSame) {
	return;
    }
    ESTimeZone *estz = ESCalendar_initTimeZoneFromOlsonID([tzName UTF8String]);
    if (![ECGeoNames validTZ:estz forSlot:envSlotToOffset(i)]) {
	NSString *cityName = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"%@-cityName-%d", watch.name, i]];
	tzName = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"%@-timeZone-%d", watch.name, i]];
	NSString *errorDescription = [NSString stringWithFormat:@"%@ in timezone %@ is no longer a valid choice for slot %d. Reverting to default (%s).", cityName, tzName, envSlotToOffset(i), ringDefaults[i].cityName];
        [[ECErrorReporter theErrorReporter] reportWarning:errorDescription];
	// revert to defaults
	[self saveDefaultsForWatch:watch env:i city:nil timeZone:nil latitude:0 longitude:0];
    }
    ESCalendar_releaseTimeZone(estz);
    [[NSUserDefaults standardUserDefaults] setObject:tzVersion forKey:@"testedTzVersion"];
}

+ (NSString *)timeZoneNameForWatch:(ECGLWatch *)watch env:(int)i {
    NSString *tzName = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"%@-timeZone-%d", watch.name, i]];
    if (tzName == nil) {
	tzName = [NSString stringWithUTF8String:ringDefaults[i].OlsonID];
    }
    assert(tzName);
    return tzName;
}

+ (NSString *)cityNameForWatch:(ECGLWatch *)watch env:(int)i {
    NSString *cityName = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"%@-cityName-%d", watch.name, i]];
    if (cityName == nil) {
	cityName = [NSString stringWithUTF8String:ringDefaults[i].cityName];
    }
    return cityName;
}

+ (double)latitudeForWatch:(ECGLWatch *)watch env:(int)i {
    double lat;
    NSString *cityName = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"%@-cityName-%d", watch.name, i]];
    if (cityName == nil) {
	lat = ringDefaults[i].lat;
    } else {
	lat = [[NSUserDefaults standardUserDefaults] doubleForKey:[NSString stringWithFormat:@"%@-latitude-%d", watch.name, i]];
    }
    return lat;
}

+ (double)longitudeForWatch:(ECGLWatch *)watch env:(int)i {
    double lng;
    NSString *cityName = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"%@-cityName-%d", watch.name, i]];
    if (cityName == nil) {
	lng = ringDefaults[i].lng;
    } else {
	lng = [[NSUserDefaults standardUserDefaults] doubleForKey:[NSString stringWithFormat:@"%@-longitude-%d", watch.name, i]];
    }
    return lng;
}

+ (void)saveDefaultsForWatch:(ECGLWatch *)watch env:(int)i city:(NSString *)city timeZone:(ESTimeZone *)tz latitude:(double)lat longitude:(double) lng {
    [[NSUserDefaults standardUserDefaults] setObject:city      forKey:[NSString stringWithFormat:@"%@-cityName-%d",  watch.name, i]];
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithCString:ESCalendar_timeZoneName(tz) encoding:NSUTF8StringEncoding] forKey:[NSString stringWithFormat:@"%@-timeZone-%d",  watch.name, i]];
    [[NSUserDefaults standardUserDefaults] setDouble:lat       forKey:[NSString stringWithFormat:@"%@-latitude-%d",  watch.name, i]];
    [[NSUserDefaults standardUserDefaults] setDouble:lng       forKey:[NSString stringWithFormat:@"%@-longitude-%d", watch.name, i]];
}

+ (double)UTCSectorOffset {
    return UTCSectorOffsetVal;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (constrainToZones) {
	self.navigationItem.title = NSLocalizedString(@"World-time Ring", @"Factory top level label for front");
	self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"World-time",@"Factory back button title for worldtime") style:UIBarButtonItemStylePlain target:nil action:nil] autorelease];
    } else {
    	self.navigationItem.title = NSLocalizedString(@"Sub-dials", @"Factory top level label for back");
	self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Sub-dials",@"Factory top level label for back") style:UIBarButtonItemStylePlain target:nil action:nil] autorelease];
    }
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(doneAction:)] autorelease];
}

- (void)viewWillAppear:(BOOL)animated {
    traceEnter("ECFactoryUI::viewWillAppear");
    tracePrintf1("nav controller thinks it's %s", [orientationNameForOrientation([self.navigationController interfaceOrientation]) UTF8String]);
    [self.tableView reloadData];
    [super viewWillAppear:animated];
    tracePrintf1("nav controller thinks it's %s", [orientationNameForOrientation([self.navigationController interfaceOrientation]) UTF8String]);
    traceExit("ECFactoryUI::viewWillAppear");
}

// when the user taps the Done button, exit
- (void)doneAction: (id)sender {
    [ChronometerAppDelegate optionDone];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return constrainToZones ? 2 : 1;
}

#define SEARCHSECTION 0
#define SLOTSSECTION  1

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (constrainToZones && section == SEARCHSECTION) ? 1 : nSlots;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (constrainToZones) {
	switch (section) {
	    case SEARCHSECTION:
		return NSLocalizedString(@"Choose a city (and its slot):", @"search section header");
	    case SLOTSSECTION:
		return NSLocalizedString(@"Or, choose a city for each slot:", @"front side slot section header");
	    default:
		assert(false);
		return @"Huh?";
	}
    } else {
	assert(section == 0);
	return NSLocalizedString(@"Choose a city for each subdial:", @"back side selection header");
    }
}

+ (UIImageView *)littleMapForSlot:(int)slot {
    UIImage *img;
    if (slot>=24) {
	img = [UIImage imageNamed:@"world90.png"];
    } else if (slot < 0 ) {
	img = [UIImage imageNamed:[NSString stringWithFormat:@"slot%d.png", abs(slot)-1]];
    } else {
	img = [UIImage imageNamed:[NSString stringWithFormat:@"slotMap%02d.png", slot]];
    }
    assert(img);
    return [[[UIImageView alloc] initWithImage:img] autorelease];
}

// Customize the appearance of table view cells.
#define ROW_HEIGHT 50.0
#define MAIN_FONT_SIZE 18
#define CITY_FONT_SIZE 16
#define V_OFFSET 7
#define REGION_FONT_SIZE 10
#define LABEL_OFFSET 10
#define RIGHT_OFFSET 100
#define ACC_WIDTH 15
#define LABEL_WIDTH 175
#define TLABEL_WIDTH 100
#define RIGHT_WIDTH 170
#define SWITCH_OFFSET (LABEL_OFFSET+LABEL_WIDTH+10)

+ (UITableViewCell *)tripleCell:(int)slot top:(NSString *)top bottom:(NSString *)bottom rightColor:(UIColor *)rightColor disclosure:(bool)disclosure replaceNotMap:(bool)replaceNotMap {
    UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:(replaceNotMap ? @"nopeReplace" : @"nope")] autorelease];
    cell.accessoryType = disclosure ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    if (replaceNotMap) {
        // "Replace" label
        cell.textLabel.text = @"Replace";
    } else {
        //slot "label" image
        UIImageView *lilMap = [ECFactoryUI littleMapForSlot:slot];
        lilMap.autoresizingMask = UIViewAutoresizingNone;
        [cell.contentView addSubview:lilMap];
    }
    // city
    // Deprecated iOS 7:  CGSize size = [@"8" sizeWithFont:[UIFont systemFontOfSize:CITY_FONT_SIZE] forWidth:RIGHT_WIDTH lineBreakMode:UILineBreakModeClip];  
    CGRect sizeRect = [@"8" boundingRectWithSize:CGSizeMake(RIGHT_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:CITY_FONT_SIZE]} context:nil];
    CGFloat sizeHeight = ceil(sizeRect.size.height);
    CGRect rect = CGRectMake(RIGHT_OFFSET, V_OFFSET, RIGHT_WIDTH, sizeHeight);
    UILabel *label = [[UILabel alloc] initWithFrame:rect];
    label.font = [UIFont systemFontOfSize:CITY_FONT_SIZE];
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    label.textColor = rightColor;
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentRight;
    label.adjustsFontSizeToFitWidth = true;
    label.text = top;
    if (isIpad()) {
        label.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    }
    [cell.contentView addSubview:label];
    [label release];
    // TZ info
    // Deprecated iOS 7:  size = [@"8" sizeWithFont:[UIFont systemFontOfSize:REGION_FONT_SIZE] forWidth:RIGHT_WIDTH lineBreakMode:UILineBreakModeClip];  
    sizeRect = [@"8" boundingRectWithSize:CGSizeMake(RIGHT_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:REGION_FONT_SIZE]} context:nil];
    sizeHeight = ceil(sizeRect.size.height);
    rect = CGRectMake(RIGHT_OFFSET, (ROW_HEIGHT - sizeHeight)-V_OFFSET, RIGHT_WIDTH, sizeHeight);
    label = [[UILabel alloc] initWithFrame:rect];
    label.font = [UIFont systemFontOfSize:REGION_FONT_SIZE];
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentRight;
    label.adjustsFontSizeToFitWidth = true;
    label.text = bottom;
    if (isIpad()) {
        label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    }
    [cell.contentView addSubview:label];
    [label release];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    NSString *cellIdentifier;
    int envSlot;

    if (constrainToZones) {
	switch (indexPath.section) {
	    case SLOTSSECTION:
		envSlot = ringSectorToEnvSlot(indexPath.row);
		ECWatchEnvironment *env = [watch enviroWithIndex:envSlot];
		cell = [ECFactoryUI tripleCell:(indexPath.row+13) % 24
					   top:env.cityName
					bottom:[ECOptions formatInfoForTZ:env.estz type:2]
				    rightColor:[UIColor systemBlueColor]
				    disclosure:true
                                 replaceNotMap:false];
		break;
	    case SEARCHSECTION:
		cellIdentifier = @"FactoryCell";
		cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (cell == nil) {
		    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier] autorelease];
		}
		cell.textLabel.font = [UIFont boldSystemFontOfSize:MAIN_FONT_SIZE];
		cell.textLabel.text = @"Search";	// @"-11:+13";
		cell.detailTextLabel.text = nil;
		cell.textLabel.textColor = [UIColor labelColor];
		break;
	    default:
		assert(false);
	}
    } else {
	cellIdentifier = @"FactoryCell";
	cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
	    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
	}
	envSlot = subdialToEnvSlot(indexPath.row);
	cell.textLabel.text = [watch enviroWithIndex:envSlot].cityName;
	cell.textLabel.textAlignment = NSTextAlignmentRight;
	cell.imageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"slot%ld.png", (long)indexPath.row]];
	cell.textLabel.textColor = [UIColor systemBlueColor];
    }
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    traceEnter("ECFactoryUI::didSelectRowAtIndexPath");
    tracePrintf1("nav controller thinks it's %s", [orientationNameForOrientation([self.navigationController interfaceOrientation]) UTF8String]);
    UITableViewController *vc;

    if (constrainToZones && indexPath.section == SEARCHSECTION) {
	vc = [[[ECFactoryUIGlobalSearch alloc] initForWatch:watch withFirstEnvSlotOffset:envSlotToOffset(0) locDB:locDB] autorelease];
    } else {
	if (constrainToZones) {
	    vc = [[[ECFactoryUISlotSearch alloc] initForWatch:watch
						      envSlot:ringSectorToEnvSlot(indexPath.row)
						       offset:ringSectorToOffset(indexPath.row) 
						  constrained:true
							locDB:locDB] autorelease];
	} else {
	    vc = [[[ECFactoryUISlotSearch alloc] initForWatch:watch
						      envSlot:subdialToEnvSlot(indexPath.row)
						       offset:-99
						  constrained:false
							locDB:locDB] autorelease];
	}
    }
    [self.navigationController pushViewController:vc animated:true];
    traceExit("ECFactoryUI::didSelectRowAtIndexPath");
}

- (void)dealloc {
    [locDB release];
    [watch release];
    [super dealloc];
}


@end

