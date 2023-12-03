//
//  ECOptionsData.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 2/11/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "ECOptionsData.h"
#import "Constants.h"
#import "ChronometerAppDelegate.h"
#import "ECLocationManager.h"
#import "ECTS.h"
#import "ECOptions.h"
#import "ECGLWatch.h"
#import "ECWatchTime.h"
#import "ECAstronomy.h"
#import "ECLocationManager.h"
#import "ECWatchEnvironment.h"
#import "ECHelpController.h"
#import "ECGlobals.h"

#define ROW_HEIGHT 30.0
#define HEADER_HEIGHT 35.0
#define HEADERFOOTER_FONT_SIZE 16
#define DATUM_FONT_SIZE 14
#define VALUE_FONT_SIZE 14

@implementation ECOptionsData

- (ECOptionsData *)initForCategory:(int)n  parent:(ECHelpController *)myParent{
    if (self = [super initWithStyle:UITableViewStyleGrouped]) {
	category = n;
	parent = myParent;
	if (category != 2) {
	    dataRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refresh:) userInfo:nil repeats:true];
	}
    }
    return self;
}

- (void)quitMe:(id)sender {
    [parent helpless:self];
}

- (void)refresh:(id)sender {
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (category != 2 && category != 100) {
	self.tableView.rowHeight = ROW_HEIGHT;
    }
    switch (category) {
	case 0:		// time
	    self.navigationItem.title = NSLocalizedString(@"Time", @"Time label");
	    break;
	case 1:		// location
	    self.navigationItem.title = NSLocalizedString(@"Location", @"Location label");
	    break;
	case 2:		// astro top level
	    self.navigationItem.title = NSLocalizedString(@"Astro Data", @"astro data label");
	    break;
	case 10:	// Sun
	    self.navigationItem.title = NSLocalizedString(@"Sun", @"Sun data label");
	    break;
	case 11:	// Moon
	    self.navigationItem.title = NSLocalizedString(@"Moon", @"Moon data label");
	    break;
	case 14:	// Earth
	    self.navigationItem.title = NSLocalizedString(@"Earth", @"Earth data label");
	    break;
	case 12:	// Mercury
	    self.navigationItem.title = NSLocalizedString(@"Mercury", @"Mercury data label");
	    break;
	case 13:	// Venus
	    self.navigationItem.title = NSLocalizedString(@"Venus", @"Venus data label");
	    break;
	case 15:	// Mars
	    self.navigationItem.title = NSLocalizedString(@"Mars", @"Mars data label");
	    break;
	case 16:	// Jupiter
	    self.navigationItem.title = NSLocalizedString(@"Jupiter", @"Jupiter data label");
	    break;
	case 17:	// Saturn
	    self.navigationItem.title = NSLocalizedString(@"Saturn", @"Saturn data label");
	    break;
        case 100:       // Top level
	    self.navigationItem.title = NSLocalizedString(@"Status Data", @"Status top-level data label");
	    break;
	default:
	    assert(false);
    }
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(quitMe:)] autorelease];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return ((category == 0 || category == 1) ? 2 : 1);
}


- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return HEADER_HEIGHT;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    UILabel *label = nil;
    if ((category <= 1 && section == 1) || category >= 10) {
	CGRect rect = CGRectMake(0, HEADER_HEIGHT, 320, HEADER_HEIGHT);
	label = [[[UILabel alloc] initWithFrame:rect] autorelease];
	label.font = [UIFont boldSystemFontOfSize:HEADERFOOTER_FONT_SIZE];
	label.textAlignment = UITextAlignmentCenter;
	label.backgroundColor = [UIColor clearColor];
	label.adjustsFontSizeToFitWidth = YES;
	label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
	label.text = @"\n❖";
    }
    return label;
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return HEADER_HEIGHT;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UILabel *label = nil;
    if ((category <= 1 && section == 0) || category >= 10) {
	CGRect rect = CGRectMake(0, HEADER_HEIGHT, 320, HEADER_HEIGHT);
	label = [[[UILabel alloc] initWithFrame:rect] autorelease];
	label.textAlignment = UITextAlignmentCenter;
	label.backgroundColor = [UIColor clearColor];
	ECGLWatch *watch = [ChronometerAppDelegate currentWatch];
	if (category == 0) {
	    label.text = [watch displayName];
	    label.font = [UIFont boldSystemFontOfSize:HEADERFOOTER_FONT_SIZE];
	} else {
	    label.font = [UIFont boldSystemFontOfSize:HEADERFOOTER_FONT_SIZE-2];
	    label.adjustsFontSizeToFitWidth = YES;
	    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
	    ECWatchTime *watchTime = [watch mainTime];    
	    ECWatchEnvironment *watchEnv = [watch mainEnv];
	    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	    [dateFormatter setDateFormat:@"yyyy MMM dd"];
	    [dateFormatter setTimeZone:[ECOptions currentTimeZone]];
	    label.text = [[dateFormatter stringFromDate:
					     [NSDate dateWithTimeIntervalSinceReferenceDate:
							 [watchTime currentTime]]]
			     stringByAppendingString:
				 [NSString stringWithFormat:@"  %02d:%02d:%02d %@",
					   [watchTime hour24NumberUsingEnv:watchEnv],
					   [watchTime minuteNumberUsingEnv:watchEnv],
					   [watchTime secondNumberUsingEnv:watchEnv],
					   [ECOptions formatInfoForTZ:[watchEnv timeZone] type:5]]];
	}
    }
    return label;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    assert(section == 0 || ((category <= 1) && section == 1));
    switch (category) {
	case 0:		// time
	    return section == 1 ? 1 : [[[ChronometerAppDelegate currentWatch] mainTime] isCorrect] ? 12 : 13;
	    break;
	case 1:		// location
	    return section == 1 ? 1 : 5;
	    break;
	case 2:		// astro top level
	    return 8;
	    break;
	case 10:	// Sun
	    return 13;
	    break;
	case 11:	// Moon
	    return 21;
	    break;
	case 14:	// Earth
	    return 8;
	    break;
	case 12:	// Mercury
	case 13:	// Venus
	case 15:	// Mars
	case 16:	// Jupiter
	case 17:	// Saturn
	    return 18;
	    break;
        case 100:       // top-level
            return 3;
	    break;
	default:
	    assert(false);
	    return 0;
    }
}

- (NSString *)formatTime:(ECWatchTime *)tim forWatch:(ECGLWatch*)watch {
    ECWatchEnvironment *watchEnv = [watch mainEnv];
    return [NSString stringWithFormat:@"%02d:%02d", [tim hour24NumberUsingEnv:watchEnv], (int)round([tim minuteValueUsingEnv:watchEnv])];
}

// Notes:  In the following two methods (formatRA and formatAngle), we have the following conventions:
//   - no suffix  (e.g., "minutes") are precise representations (i.e., not integral) of the corresponding component
//   - suffix "R" (e.g., "minutesR") means the component rounded to the closest value, for use when it is the last component output as an integer
//   - suffix "T" (e.g., "minutesT") means the component truncated (floor), for use when another component follows it
//   - suffix "R10" (e.g., "minutesR10") means the component, multiplied by 10, rounded to the nearest integer, for use (when divided by 10) in %.1f
//   - suffix "R100" (e.g., "minutesR100") means the component, multiplied by 100, rounded to the nearest integer, for use (when divided by 100) in %.2f
//   - suffix "F" (e.g., "minutesF") means the fractional part of the component, for use in determining the following component(s)
//  Note further that because of what happens when a component nears 1.0 (e.g., 59.9 seconds for a %.0f display), sometimes we need to reset that component
//    to zero and bump up the previous component (possibly propagating all the way back to the top), but this cannot be done until the precision of the
//    final (smallest) component is determined, which may vary depending on what case we're in.
- (NSString *)formatRA:(double)radians {
    assert(radians >= 0);
    ECLocationManager *lm = [ECLocationManager theLocationManager];
    double hours = radians * 12 / M_PI;
    int hoursT = (int)floor(hours);
    double hoursF = hours - hoursT;
    double minutes = hoursF * 60;
    int minutesT = (int)floor(minutes);    // integer part of minutes
    double minutesF = minutes - minutesT;  // fraction part of minutes
    double seconds = minutesF * 60;
    int secondsR = (int)rint(seconds);
    int minutesR = (int)rint(minutes);
    switch (category) {
	case 11:		// Moon
	    if (nearPresent && [lm accuracyIsGood]) {
		if (secondsR == 60) {
		    secondsR = 0;
		    if (++minutesT == 60) {
			minutesT = 0;
			if (++hoursT == 24) {
			    hoursT = 0;
			}
		    }
		}
		return [NSString stringWithFormat:@"%dh %02dm %02ds", hoursT, minutesT, secondsR];
	    } else {
		return [NSString stringWithFormat:@"%2.1fh", hours];
	    }
	case 10:		// Sun
	case 14:		// Earth
	case 12:		// Mercury
	case 13:		// Venus
	case 15:		// Mars
	case 16:		// Jupiter
	case 17:		// Saturn
	    if (nearPresent && [lm accuracyIsGood]) {
		if (secondsR == 60) {
		    secondsR = 0;
		    if (++minutesT == 60) {
			minutesT = 0;
			if (++hoursT == 24) {
			    hoursT = 0;
			}
		    }
		}
		return [NSString stringWithFormat:@"%dh %02dm %02ds", hoursT, minutesT, secondsR];
	    } else {
		if (minutesR == 60) {
		    minutesR = 0;
		    if (++hoursT == 24) {
			hoursT = 0;
		    }
		}
		return [NSString stringWithFormat:@"%dh %02dm", hoursT, minutesR];
	    }
	default:
	    assert(false);
	    return 0;
    }
}

- (NSString *)formatAngle:(double)radians {
    ECLocationManager *lm = [ECLocationManager theLocationManager];
    double degrees = radians * 180 / M_PI;
    int degreesT = (int)floor(fabs(degrees));   // integer part of degrees
    if (degrees < 0) {
	degreesT = -degreesT;
    }
    double degreesF = fabs(degrees - degreesT);  // fraction part of degrees
    double minutes = degreesF * 60;
    //int minutesI = (int)floor(minutes);   // integer part of minutes
    //double minutesF = minutes - minutesI; // fraction part of minutes
    //double seconds = minutesF * 60;
    int degreesR = (int)rint(degrees);
    int minutesR = (int)rint(minutes);
    // [stevep 4/11/10 This switch statement could be replaced with a single if-then-else but I'm leaving it
    //   as a switch in case we want to do something more sophisticated in the future]
    switch (category) {
	case 11:		// Moon
	    if (nearPresent && [lm accuracyIsGood]) {
		if (minutesR == 60) {
		    minutesR = 0;
		    if (++degreesT == 360) {
			degreesT = 0;
		    }
		}
		return [NSString stringWithFormat:@"%d° %d'", degreesT, minutesR];
	    } else {
		return [NSString stringWithFormat:@"%d°", degreesR];
	    }
	case 10:		// Sun
	case 14:		// Earth
	case 12:		// Mercury
	case 13:		// Venus
	case 15:		// Mars
	case 16:		// Jupiter
	case 17:		// Saturn
	    if (minutesR == 60) {
	        minutesR = 0;
	        if (++degreesT == 360) {
	    	  degreesT = 0;
	        }
	    }
	    return [NSString stringWithFormat:@"%d° %d'", degreesT, minutesR];
	default:
	    assert(false);
	    return 0;
    }
}

+ (NSString *)formatTimeHHMMSS:(NSTimeInterval)tm {
    double hours = EC_fmod(tm / 3600, 24);
    int hoursT = (int)floor(hours);
    double hoursF = hours - hoursT;
    double minutes = hoursF * 60;
    int minutesT = (int)floor(minutes);    // integer part of minutes
    double minutesF = minutes - minutesT;  // fraction part of minutes
    double seconds = minutesF * 60;
    int secondsR = (int)rint(seconds);
    if (secondsR == 60) {
	secondsR = 0;
	if (++minutesT == 60) {
	    minutesT = 0;
	    if (++hoursT == 24) {
		hoursT = 0;
	    }
	}
    }
    return [NSString stringWithFormat:@"%02d:%02d:%02d", hoursT, minutesT, secondsR];
}

+ (NSString *)formatTimeHHMM:(NSTimeInterval)tm {
    double hours = EC_fmod(tm / 3600, 24);
    int hoursT = (int)floor(hours);
    double hoursF = hours - hoursT;
    double minutes = hoursF * 60;
    int minutesR = (int)rint(minutes);
    if (minutesR == 60) {
	minutesR = 0;
	if (++hoursT == 24) {
	    hoursT = 0;
	}
    }
    return [NSString stringWithFormat:@"%02d:%02d", hoursT, minutesR];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier;
    CellIdentifier = category == 2 ? @"ECPlanetCell" : category == 100 ? @"ECDataTopLevel" : @"ECDataCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:(category ==2 || category == 100) ? UITableViewCellStyleDefault: UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
    }
    if (category != 100) {
	cell.textLabel.font = [UIFont boldSystemFontOfSize:DATUM_FONT_SIZE];
	cell.detailTextLabel.font = [UIFont fontWithName:@"Courier-Bold" size:VALUE_FONT_SIZE];
	cell.textLabel.adjustsFontSizeToFitWidth = YES;
	cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
	cell.textLabel.backgroundColor = [UIColor clearColor];
	cell.detailTextLabel.backgroundColor = [UIColor clearColor];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    if ((indexPath.row % 2) == 1 && category != 2 && category != 100) {
	cell.contentView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:.05];
    } else {
	cell.contentView.backgroundColor = nil;
    }


    ECGLWatch *watch = [ChronometerAppDelegate currentWatch];
    ECWatchEnvironment *watchEnv = [watch mainEnv];
    ECWatchTime *watchTime = [watch mainTime];
    ECAstronomyManager *watchAstro = [watch mainAstro];
    ECLocationManager *lm = [ECLocationManager theLocationManager];

    NSNumberFormatter *nf = [[[NSNumberFormatter alloc] init] autorelease];
    [nf setUsesGroupingSeparator:YES];
    [nf setNumberStyle:NSNumberFormatterDecimalStyle];
    [nf setPositiveFormat:@"#,##0"];
    
    nearPresent = [watchTime yearNumberUsingEnv:watchEnv] > 1900 &&
		  [watchTime yearNumberUsingEnv:watchEnv] < 2100;
    
    switch (category) {
	case 0:		// time
	    if (indexPath.section == 1) {
		cell.textLabel.text = @"Refresh NTP Sync";
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		break;
	    }
	    switch (indexPath.row) {
		case 0:
		    cell.textLabel.text = @"Local Time";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%02d:%02d:%02d %@", [watchTime hour24NumberUsingEnv:watchEnv], [watchTime minuteNumberUsingEnv:watchEnv], [watchTime secondNumberUsingEnv:watchEnv], [[watchEnv timeZone] abbreviationForDate:[watchTime currentDate]]];
		    break;
		case 1:
		    cell.textLabel.text = @"Date";
		    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		    [dateFormatter setDateFormat:@"EEE yyyy MMM dd G"];
		    [dateFormatter setTimeZone:[ECOptions currentTimeZone]];
		    cell.detailTextLabel.text = [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:[watchTime currentTime]]];
		    [dateFormatter release];
		    break;
		case 2:
		    cell.textLabel.text = @"Timezone";
		    cell.detailTextLabel.text = [[watchEnv timeZone] name];
		    break;
		case 3:
		    cell.textLabel.text = @"Current UTC offset";
		    cell.detailTextLabel.text = [ECOptions formatTZOffset:[watchTime tzOffsetUsingEnv:watchEnv]/3600.0];
		    break;
		case 4:
		    cell.textLabel.text = @"UTC";
		    double off = [watchTime tzOffsetUsingEnv:watchEnv];	// seconds
		    double hr  = EC_fmod([watchTime hour24NumberUsingEnv:watchEnv] - floor(off/3600), 24);
		    if (hr<0) {
			hr += 24;
		    }
		    double min = EC_fmod([watchTime minuteNumberUsingEnv:watchEnv] - EC_fmod(off/60,60) , 60);
		    if (min<0) {
			min += 60;
		    }
		    double sec = [watchTime secondNumberUsingEnv:watchEnv];
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%02d:%02d:%02d", (int)hr, (int)min, (int)sec];
		    break;
		case 5:
		    cell.textLabel.text = @"Julian Date";
		    extern double julianDateForDate(NSTimeInterval x);
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.5f", julianDateForDate([watchTime currentTime])];
		    break;
		case 6:
		    cell.textLabel.text = @"Solar Time";
		    [watchAstro setupLocalEnvironmentForThreadFromActionButton:false];
		    double tm = [[watch mainTime] currentTime] + [[ECLocationManager theLocationManager] lastLongitudeDegrees]/15*3600 + [watchAstro EOT]*12*3600/M_PI;
		    if ([lm accuracyIsGood]) {
			cell.detailTextLabel.text = [ECOptionsData formatTimeHHMMSS:tm];
		    } else {
			cell.detailTextLabel.text = [ECOptionsData formatTimeHHMM:tm];
		    }
		    [watchAstro cleanupLocalEnvironmentForThreadFromActionButton:false];
		    break;
		case 7:
		    cell.textLabel.text = @"Sidereal Time";
		    [watchAstro setupLocalEnvironmentForThreadFromActionButton:false];
		    double tim = [watchAstro localSiderealTime];
		    if ([lm accuracyIsGood]) {
			cell.detailTextLabel.text = [ECOptionsData formatTimeHHMMSS:tim];
		    } else {
			cell.detailTextLabel.text = [ECOptionsData formatTimeHHMM:tim];
		    }
		    [watchAstro cleanupLocalEnvironmentForThreadFromActionButton:false];
		    break;
		case 8:
		    cell.textLabel.text = @"Day Length";
		    [watchAstro setupLocalEnvironmentForThreadFromActionButton:false];
		    if ([watchAstro planetriseForDayValid:ECPlanetSun] && [watchAstro planetsetForDayValid:ECPlanetSun]) {
			double len = [[watchAstro watchTimeWithPlanetsetForDay:ECPlanetSun] currentTime] - [[watchAstro watchTimeWithPlanetriseForDay:ECPlanetSun] currentTime];
			if (len < 0) {
			    len += 24*3600;	    // for cases when sunrise is later than sunset
			}
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%2dh %02dm", (int)floor(len/3600), (int)EC_fmod(len/60, 60)];
		    } else {
			cell.detailTextLabel.text = @" -";
		    }
		    [watchAstro cleanupLocalEnvironmentForThreadFromActionButton:false];
		    break;
		case 9:
		    cell.textLabel.text = @"NTP Status";
		    cell.detailTextLabel.text = [[ECTS statusText] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
		    break;
		case 10:
		    if ([ECWatchTime rawSkew] < 0) {
			cell.textLabel.text = [[[UIDevice currentDevice] localizedModel] stringByAppendingString:@" ahead of NTP by"];
		    } else {
			cell.textLabel.text = [[[UIDevice currentDevice] localizedModel] stringByAppendingString:@" behind NTP by"];
		    }
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%7.2f sec", fabs([ECWatchTime rawSkew])];
		    break;
	        case 11:
		    cell.textLabel.text = @"NTP Accuracy Range";
		    {
			double skewLB = [ECTS skewLB];
			double skewUB = [ECTS skewUB];
			double skew = [ECWatchTime rawSkew];
			NSString *skewLBStr = skewLB > -1e9 ? [NSString stringWithFormat:@"%.2f", skewLB - skew] : @"?";
			NSString *skewUBStr = skewUB <  1e9 ? [NSString stringWithFormat:@"%.2f", skewUB - skew] : @"?";
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ : %@", skewLBStr, skewUBStr];
		    }
		    break;
		case 12:	// must be last
		    assert(![watchTime isCorrect]);
		    cell.textLabel.text = @"Off by";
		    cell.detailTextLabel.text = [watchTime representationOfDeltaOffsetUsingEnv:watchEnv];
		    break;
		default:
		    assert(false);
		    break;
	    }
	    break;
	case 1:		// location
	    if (indexPath.section == 1) {
		if (lm.active) {
		    cell.textLabel.text = @"Cancel Location Sync";
		} else {
		    cell.textLabel.text = @"Refresh Location Sync";
		}
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		break;
	    }
	    switch (indexPath.row) {
		case 0:
		    cell.textLabel.text = @"Latitude";
		    cell.detailTextLabel.text = [lm latitudeString2];
		    break;
		case 1:
		    cell.textLabel.text = @"Longitude";
		    cell.detailTextLabel.text = [lm longitudeString2];
		    break;
		case 2:
		    cell.textLabel.text = @"Horizontal Error";
		    if (lm.locationOverridden) {
			cell.detailTextLabel.text = @"-";
		    } else {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"±%.0f m", [lm lastHorizontalErrorMeters]];
		    }
		    break;
		case 3:
		    cell.textLabel.text = @"Status";
		    cell.detailTextLabel.text = [[lm statusText] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
		    break;
		case 4:
		    cell.textLabel.text = @"Last Sync";
		    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
		    [dateFormatter setDateFormat:@"MMM dd HH:mm:ss"];
		    [dateFormatter setTimeZone:[ECOptions currentTimeZone]];
		    cell.detailTextLabel.text = [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:[lm lastFix]]];
		    break;
		default:
		    assert(false);
		    break;
	    }
	    break;
	case 2:	    // astro
	    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	    cell.detailTextLabel.text = nil;
	    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	    switch (indexPath.row) {
		case 0:	cell.textLabel.text = @"Sun";	    cell.imageView.image = [UIImage imageNamed:@"sun.png"];	break;
		case 1:	cell.textLabel.text = @"Moon";	    cell.imageView.image = [UIImage imageNamed:@"moon2.png"];	break;
		case 2:	cell.textLabel.text = @"Mercury";   cell.imageView.image = [UIImage imageNamed:@"mercury.png"];	break;
		case 3:	cell.textLabel.text = @"Venus";	    cell.imageView.image = [UIImage imageNamed:@"venus2.png"];	break;
		case 4:	cell.textLabel.text = @"Earth";	    cell.imageView.image = [UIImage imageNamed:@"earth.png"];	break;
		case 5:	cell.textLabel.text = @"Mars";	    cell.imageView.image = [UIImage imageNamed:@"mars.png"];	break;
		case 6:	cell.textLabel.text = @"Jupiter";   cell.imageView.image = [UIImage imageNamed:@"jupiter.png"];	break;
		case 7:	cell.textLabel.text = @"Saturn";    cell.imageView.image = [UIImage imageNamed:@"saturn.png"];	break;
		default:
		    assert(false);
		    break;
	    }
	    break;
	case 10:		// Sun
	    [watchAstro setupLocalEnvironmentForThreadFromActionButton:false];
	    switch (indexPath.row) {
		case 0:
		    cell.textLabel.text = @"Rise";
		    if ([watchAstro planetriseForDayValid:category-10]) {
			cell.detailTextLabel.text = [self formatTime:[watchAstro watchTimeWithPlanetriseForDay:category-10] forWatch:watch];
		    } else {
			cell.detailTextLabel.text = @" -";
		    }
		    break;
		case 1:
		    cell.textLabel.text = @"Transit";
		    if ([watchAstro planettransitForDayValid:category-10]) {
			cell.detailTextLabel.text = [self formatTime:[watchAstro watchTimeWithPlanettransitForDay:category-10] forWatch:watch];
		    } else {
			cell.detailTextLabel.text = @" -";
		    }
		    break;
		case 2:
		    cell.textLabel.text = @"Set";
		    if ([watchAstro planetsetForDayValid:category-10]) {
			cell.detailTextLabel.text = [self formatTime:[watchAstro watchTimeWithPlanetsetForDay:category-10] forWatch:watch];
		    } else {
			cell.detailTextLabel.text = @" -";
		    }
		    break;
		case 3:
		    cell.textLabel.text = @"Altitude";
		    cell.detailTextLabel.text = [self formatAngle:[watchAstro planetAltitude:category-10]];
		    break;
		case 4:
		    cell.textLabel.text = @"Azimuth";
		    double az = [watchAstro planetAzimuth:category-10];
		    if (az < 0) {
			az += M_PI*2;
		    }
		    cell.detailTextLabel.text = [self formatAngle:az];
		    break;
		case 5:
		    cell.textLabel.text = @"Zodiac";
		    cell.detailTextLabel.text = [ECAstronomyManager zodiacConstellationOf:[watchAstro planetEclipticLongitude:category-10]];
		    break;
		case 6:
		    cell.textLabel.text = @"Right Ascension";
		    cell.detailTextLabel.text = [self formatRA:[watchAstro planetRA:category-10 correctForParallax:true]];
		    break;
		case 7:
		    cell.textLabel.text = @"Declination";
		    cell.detailTextLabel.text = [self formatAngle:[watchAstro planetDecl:category-10 correctForParallax:true]];
		    break;
		case 8:
		    cell.textLabel.text = @"Ecliptic Longitude";
		    cell.detailTextLabel.text = [self formatAngle:[watchAstro planetEclipticLongitude:category-10]];
		    break;
		case 9:
		    cell.textLabel.text = @"Distance from Earth";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.3f AU", [watchAstro planetHeliocentricRadius:ECPlanetEarth]];
		    break;
		case 10:
		    cell.textLabel.text = @"Apparent Diameter";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f°", [watchAstro planetApparentDiameter:category-10]*180/M_PI];
		    break;
		case 11:
		    cell.textLabel.text = @"Radius";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ km", [nf stringFromNumber:[NSNumber numberWithDouble:[watchAstro planetRadius:category-10]]]];
		    break;
		case 12:
		    cell.textLabel.text = @"Mass";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%6.4e kg", [watchAstro planetMass:category-10]];
		    break;
		default:
		    assert(false);
		    break;
	    }
	    [watchAstro cleanupLocalEnvironmentForThreadFromActionButton:false];
	    break;
	case 11:		// Moon
	    [watchAstro setupLocalEnvironmentForThreadFromActionButton:false];
	    cell.indentationLevel = 0;
	    switch (indexPath.row) {
		case 0:
		    cell.textLabel.text = @"Rise";
		    if ([watchAstro planetriseForDayValid:category-10]) {
			cell.detailTextLabel.text = [self formatTime:[watchAstro watchTimeWithPlanetriseForDay:category-10] forWatch:watch];
		    } else {
			cell.detailTextLabel.text = @" -";
		    }
		    break;
		case 1:
		    cell.textLabel.text = @"Transit";
		    if ([watchAstro planettransitForDayValid:category-10]) {
			cell.detailTextLabel.text = [self formatTime:[watchAstro watchTimeWithPlanettransitForDay:category-10] forWatch:watch];
		    } else {
			cell.detailTextLabel.text = @" -";
		    }
		    break;
		case 2:
		    cell.textLabel.text = @"Set";
		    if ([watchAstro planetsetForDayValid:category-10]) {
			cell.detailTextLabel.text = [self formatTime:[watchAstro watchTimeWithPlanetsetForDay:category-10] forWatch:watch];
		    } else {
			cell.detailTextLabel.text = @" -";
		    }
		    break;
		case 3:
		    cell.textLabel.text = @"Phase";
		    cell.detailTextLabel.text = [watchAstro moonPhaseString];
		    break;
		case 4:
		    ;// stupid compiler
		    double deltaN = [[watchAstro watchTimeWithClosestNewMoon] currentTime] - [watchTime currentTime];
		    double delta1 = [[watchAstro watchTimeWithClosestFirstQuarter] currentTime] - [watchTime currentTime];
		    double deltaF = [[watchAstro watchTimeWithClosestFullMoon] currentTime] - [watchTime currentTime];
		    double delta3 = [[watchAstro watchTimeWithClosestThirdQuarter] currentTime] - [watchTime currentTime];
		    double delta = fmin(fmin(fabs(deltaN), fabs(delta1)), fmin(fabs(deltaF), fabs(delta3)));
		    if (delta == fabs(deltaN) && delta > 1) {
			cell.textLabel.text = [NSString stringWithFormat:@"Time %@ New Moon", deltaN > 0 ? @"Until" : @"Since"];
			delta = fabs(deltaN);
		    } else if ((delta == fabs(delta1) && delta > 1) || delta == fabs(deltaN)) {
			cell.textLabel.text = [NSString stringWithFormat:@"Time %@ 1st Quarter", delta1 > 0 ? @"Until" : @"Since"];
			delta = fabs(delta1);
		    } else if ((delta == fabs(deltaF) && delta > 1) || delta == fabs(delta1)) {
			cell.textLabel.text = [NSString stringWithFormat:@"Time %@ Full Moon", deltaF > 0 ? @"Until" : @"Since"];
			delta = fabs(deltaF);
		    } else if ((delta == fabs(delta3) && delta > 1) || delta == fabs(deltaF)) {
			cell.textLabel.text = [NSString stringWithFormat:@"Time %@ 3rd Quarter", delta3 > 0 ? @"Until" : @"Since"];
			delta = fabs(delta3);
		    }
		    if (delta < 3600) {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f minutes", delta/60];
		    } else if (delta < 86400) {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f hours", delta/3600];
		    } else {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f days", delta/86400];
		    }
		    cell.indentationLevel = 1;
		    break;
		case 5:
		    cell.textLabel.text = @"Age";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f days", [watchAstro realMoonAgeAngle]];
		    cell.indentationLevel = 1;
		    break;
		case 6:
		    cell.textLabel.text = @"Terminator Seleno. Longitude";
		    double termAngle = [watchAstro moonAgeAngle]*180/M_PI;
		    if (termAngle > 180) {
			termAngle -= 180;
		    }
		    double sl;
		    if (termAngle < 90) {
			sl = 90 - termAngle;
		    } else {
			sl = termAngle - 90;
		    }

		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f %@", sl, sl > 89.5 ? @"" : termAngle < 90 ? @"E" : @"W"];
		    cell.indentationLevel = 1;
		    break;
		case 7:
		    cell.textLabel.text = @"Altitude";
		    cell.detailTextLabel.text = [self formatAngle:[watchAstro planetAltitude:category-10]];
		    break;
		case 8:
		    cell.textLabel.text = @"Azimuth";
		    double az = [watchAstro planetAzimuth:category-10];
		    if (az < 0) {
			az += M_PI*2;
		    }
		    cell.detailTextLabel.text = [self formatAngle:az];
		    break;
		case 9:
		    cell.textLabel.text = @"Zodiac";
		    cell.detailTextLabel.text = [ECAstronomyManager zodiacConstellationOf:[watchAstro planetEclipticLongitude:category-10]];
		    break;
		case 10:
		    cell.textLabel.text = @"Right Ascension";
		    cell.detailTextLabel.text = [self formatRA:[watchAstro planetRA:category-10 correctForParallax:true]];
		    break;
		case 11:
		    cell.textLabel.text = @"Declination";
		    cell.detailTextLabel.text = [self formatAngle:[watchAstro planetDecl:category-10 correctForParallax:true]];
		    break;
		case 12:
		    cell.textLabel.text = @"Ecliptic Latitude";
		    cell.detailTextLabel.text = [self formatAngle:[watchAstro planetEclipticLatitude:category-10]];
		    break;
		case 13:
		    cell.textLabel.text = @"Ecliptic Longitude";
		    cell.detailTextLabel.text = [self formatAngle:[watchAstro planetEclipticLongitude:category-10]];
		    break;
		case 14:
		    cell.textLabel.text = @"Distance from Earth";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f Earth radii", [watchAstro planetGeocentricDistance:category-10]*kECAUInKilometers/[watchAstro planetRadius:ECPlanetEarth]];
		    break;
		case 15:
		    cell.textLabel.text = @"Ascending Node RA";
		    cell.detailTextLabel.text = [self formatRA:[watchAstro moonAscendingNodeRA]];
		    break;
		case 16:
		    cell.textLabel.text = @"Apparent Diameter";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f°", [watchAstro planetApparentDiameter:category-10]*180/M_PI];
		    break;
		case 17:
		    cell.textLabel.text = @"Radius";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ km", [nf stringFromNumber:[NSNumber numberWithDouble:[watchAstro planetRadius:category-10]]]];
		    break;
		case 18:
		    cell.textLabel.text = @"Mass";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%6.4e kg", [watchAstro planetMass:category-10]];
		    break;
		case 19:
		    cell.textLabel.text = @"Mean Sidereal Orbit Period";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f days", [watchAstro planetOribitalPeriod:category-10] * 365.256366];
		    break;
		case 20:
		    cell.textLabel.text = @"Mean Synodic Orbit Period";
		    cell.detailTextLabel.text =  @"29.5 days";
		    break;
		default:
		    assert(false);
		    break;
	    }
	    [watchAstro cleanupLocalEnvironmentForThreadFromActionButton:false];
	    break;
	    case 14:		// Earth
		[watchAstro setupLocalEnvironmentForThreadFromActionButton:false];
		switch (indexPath.row) {
		    case 0:
			cell.textLabel.text = @"Greenwich Mean Sidereal Time";
			double tim = [watchAstro localSiderealTime] - [[ECLocationManager theLocationManager] lastLongitudeDegrees]/15*3600 ;
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%02d:%02d:%02d", (int)EC_fmod(tim/3600, 24), (int)EC_fmod(tim/60,60), (int)EC_fmod(tim,60)];
			break;
		    case 1:
			cell.textLabel.text = @"Equation of Time";
			double eotseconds = [watchAstro EOT] * 12 * 3600 / M_PI;
			double mn = copysign(floor(fabs(eotseconds) / 60), eotseconds);
			double sc = EC_fmod(fabs(eotseconds), 60);
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%+2dm %02ds", (int)mn, (int)sc];
			break;
		    case 2:
			cell.textLabel.text = @"Heliocentric Longitude";
			cell.detailTextLabel.text = [self formatAngle:[watchAstro planetHeliocentricLongitude:category-10]];
			break;
		    case 3:
			cell.textLabel.text = @"Distance from Sun";
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%.3f AU", [watchAstro planetHeliocentricRadius:category-10]];
			break;
		    case 4:
			cell.textLabel.text = @"Precession";
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%8.4f°", [watchAstro precession]*180/M_PI];
			break;
			break;
		    case 5:
			cell.textLabel.text = @"Radius";
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ km", [nf stringFromNumber:[NSNumber numberWithDouble:[watchAstro planetRadius:category-10]]]];
			break;
		    case 6:
			cell.textLabel.text = @"Mass";
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%6.4e kg", [watchAstro planetMass:category-10]];
			break;
		    case 7:
			cell.textLabel.text = @"Sidereal Orbit Period";
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%6g days", [watchAstro planetOribitalPeriod:category-10] * 365.256366];
			break;
		    default:
			assert(false);
		}
	    [watchAstro cleanupLocalEnvironmentForThreadFromActionButton:false];
	    break;
	case 12:		// Mercury
	case 13:		// Venus
	case 15:		// Mars
	case 16:		// Jupiter
	case 17:		// Saturn
	    [watchAstro setupLocalEnvironmentForThreadFromActionButton:false];
	    switch (indexPath.row) {
		case 0:
		    cell.textLabel.text = @"Rise";
		    if ([watchAstro planetriseForDayValid:category-10]) {
			cell.detailTextLabel.text = [self formatTime:[watchAstro watchTimeWithPlanetriseForDay:category-10] forWatch:watch];
		    } else {
			cell.detailTextLabel.text = @" -";
		    }
		    break;
		case 1:
		    cell.textLabel.text = @"Transit";
		    if ([watchAstro planettransitForDayValid:category-10]) {
			cell.detailTextLabel.text = [self formatTime:[watchAstro watchTimeWithPlanettransitForDay:category-10] forWatch:watch];
		    } else {
			cell.detailTextLabel.text = @" -";
		    }
		    break;
		case 2:
		    cell.textLabel.text = @"Set";
		    if ([watchAstro planetsetForDayValid:category-10]) {
			cell.detailTextLabel.text = [self formatTime:[watchAstro watchTimeWithPlanetsetForDay:category-10] forWatch:watch];
		    } else {
			cell.detailTextLabel.text = @" -";
		    }
		    break;
		case 3:
		    cell.textLabel.text = @"Altitude";
		    cell.detailTextLabel.text = [self formatAngle:[watchAstro planetAltitude:category-10]];
		    break;
		case 4:
		    cell.textLabel.text = @"Azimuth";
		    double az = [watchAstro planetAzimuth:category-10];
		    if (az < 0) {
			az += 2*M_PI;
		    }
		    cell.detailTextLabel.text = [self formatAngle:az];
		    break;
		case 5:
		    cell.textLabel.text = @"Zodiac";
		    cell.detailTextLabel.text = [ECAstronomyManager zodiacConstellationOf:[watchAstro planetEclipticLongitude:category-10]];
		    break;
		case 6:
		    cell.textLabel.text = @"Right Ascension";
		    cell.detailTextLabel.text = [self formatRA:[watchAstro planetRA:category-10 correctForParallax:true]];
		    break;
		case 7:
		    cell.textLabel.text = @"Declination";
		    cell.detailTextLabel.text = [self formatAngle:[watchAstro planetDecl:category-10 correctForParallax:true]];
		    break;
		case 8:
		    cell.textLabel.text = @"Ecliptic Latitude";
		    cell.detailTextLabel.text = [self formatAngle:[watchAstro planetEclipticLatitude:category-10]];
		    break;
		case 9:
		    cell.textLabel.text = @"Ecliptic Longitude";
		    cell.detailTextLabel.text = [self formatAngle:[watchAstro planetEclipticLongitude:category-10]];
		    break;
		case 10:
		    cell.textLabel.text = @"Heliocentric Latitude";
		    cell.detailTextLabel.text = [self formatAngle:[watchAstro planetHeliocentricLatitude:category-10]];
		    break;
		case 11:
		    cell.textLabel.text = @"Heliocentric Longitude";
		    cell.detailTextLabel.text = [self formatAngle:[watchAstro planetHeliocentricLongitude:category-10]];
		    break;
		case 12:
		    cell.textLabel.text = @"Distance from Sun";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.3f AU", [watchAstro planetHeliocentricRadius:category-10]];
		    break;
		case 13:
		    cell.textLabel.text = @"Distance from Earth";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.3f AU", [watchAstro planetGeocentricDistance:category-10]];
		    break;
		case 14:
		    cell.textLabel.text = @"Apparent Diameter";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%4.1f arcsec", [watchAstro planetApparentDiameter:category-10]*180/M_PI*3600];
		    break;
		case 15:
		    cell.textLabel.text = @"Radius";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ km", [nf stringFromNumber:[NSNumber numberWithDouble:[watchAstro planetRadius:category-10]]]];
		    break;
		case 16:
		    cell.textLabel.text = @"Mass";
		    cell.detailTextLabel.text = [NSString stringWithFormat:@"%6.4e kg", [watchAstro planetMass:category-10]];
		    break;
		case 17:
		    cell.textLabel.text = @"Sidereal Orbit Period";
		    double per = [watchAstro planetOribitalPeriod:category-10];
		    if (per > 1) {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%4g years", per];
		    } else {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%4g days",  per * 365.256366];
		    }
		    break;
		default:
		    assert(false);
		    break;
	    }
	    [watchAstro cleanupLocalEnvironmentForThreadFromActionButton:false];
	    break;
        case 100:
	    switch (indexPath.row) {
		case 0:
		    cell.textLabel.text = NSLocalizedString(@"Time", @"Time label");
		    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		    break;
		case 1:
		    cell.textLabel.text = NSLocalizedString(@"Location", @"Location label");
		    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		    break;
		case 2:
		    cell.textLabel.text = NSLocalizedString(@"Astronomical", @"astro data display item label");
		    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		    break;
		default:
		    assert(false);
		    break;
	    }
	    break;
	default:
	    assert(false);
	    break;
    }
	
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (category) {
	case 0:
	    [ECTS reSync];
	    break;
	case 1:
	    if ([ECLocationManager theLocationManager].active) {
		[[ECLocationManager theLocationManager] cancelLocationRequest];
	    } else {
		[[ECLocationManager theLocationManager] requestOneLocationFix];		// does not update userDefaults and hence ECOptionsLoc's switch
	    }
	    break;
	case 2:
	  {
	    ECOptionsData *vc = [[ECOptionsData alloc] initForCategory:indexPath.row+10 parent:parent];
	    [self.navigationController pushViewController:vc animated:true];
	    [vc release];
	    break;
	  }
        case 100:
	    switch (indexPath.row) {
		case 0:
		case 1:
		case 2:
		  {
		      ECOptionsData *vc = [[ECOptionsData alloc] initForCategory:indexPath.row parent:parent];
		      [self.navigationController pushViewController:vc animated:true];
		      [vc release];
		  }
		  break;
	        default:
		  assert(false);
		  break;
	    }	    
	    break;
	default:
	    // do nothing
	    break;
    }
}


- (void)dealloc {
    [super dealloc];
    [dataRefreshTimer invalidate];
    [dataRefreshTimer release];
}


@end

