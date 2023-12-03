//
//  ECBackgroundData.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/13/2010 from ECOptionsData
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "ECBackgroundData.h"
#import "Constants.h"
#import "ChronometerAppDelegate.h"
#import "ECLocationManager.h"
#import "ECTS.h"
#import "ECOptions.h"
#import "ECGLWatch.h"
#import "ECWatchTime.h"
#import "ECLocationManager.h"
#import "ECWatchEnvironment.h"
#import "TSTime.h"
#import "ECGlobals.h"

#define ROW_HEIGHT 30.0
#define HEADER_HEIGHT 35.0
#define HEADERFOOTER_FONT_SIZE 16
#define DATUM_FONT_SIZE 14
#define VALUE_FONT_SIZE 14

static ECBackgroundData *theBackgroundDataObject = nil;

@implementation ECBackgroundData

- (ECBackgroundData *)initForCategory:(int)n {
    assert(theBackgroundDataObject == nil);
    if (self = [super initWithStyle:UITableViewStyleGrouped]) {
	category = n;
    }
    theBackgroundDataObject = self;
    return self;
}

+ (void)refreshGuts {
    if (theBackgroundDataObject) {
	[theBackgroundDataObject.tableView reloadData];
    }
}

+ (void)refresh {
    [self performSelectorOnMainThread:@selector(refreshGuts) withObject:nil waitUntilDone:false];
}

- (void)quitMe:(id)sender {
    assert(theBackgroundDataObject);
    [ChronometerAppDelegate dataDone];
}

- (void)dealloc {
    assert(theBackgroundDataObject != nil);
    theBackgroundDataObject = nil;
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = ROW_HEIGHT;
    switch (category) {
	case 0:		// time
	    self.navigationItem.title = NSLocalizedString(@"Time", @"Time label");
	    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(quitMe:)] autorelease];
	    break;
	case 1:		// location
	    self.navigationItem.title = NSLocalizedString(@"Location", @"Location label");
	    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(quitMe:)] autorelease];
	    break;
	default:
	    assert(false);
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
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
	label.textAlignment = NSTextAlignmentCenter;
	label.backgroundColor = [UIColor clearColor];
	label.adjustsFontSizeToFitWidth = YES;
	label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
	label.text = @"\n❖";
    }
    return label;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (category) {
	case 0:		// time
	    return 5;
	    break;
	case 1:		// location
	    return 5;
	    break;
	default:
	    assert(false);
	    return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"ECDataCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
    }
    cell.textLabel.font = [UIFont boldSystemFontOfSize:DATUM_FONT_SIZE];
    cell.detailTextLabel.font = [UIFont fontWithName:@"Courier-Bold" size:VALUE_FONT_SIZE];
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (indexPath.row % 2 == 1) {
	cell.contentView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:.05];
    } else {
	cell.contentView.backgroundColor = [UIColor clearColor];
    }

    ECGLWatch *watch = [ChronometerAppDelegate currentWatch];
    ECWatchEnvironment *watchEnv = [watch mainEnv];
    ECWatchTime *watchTime = [watch mainTime];
    ECLocationManager *lm = [ECLocationManager theLocationManager];
    
    switch (category) {
	case 0:		// time
	    switch (indexPath.row) {
		case 0:
		    cell.textLabel.text = @"NTP Status";
		    cell.detailTextLabel.text = [[ECTS statusText] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
		    break;
		case 1:
		  {
		    NSString *model = [[[UIDevice currentDevice] localizedModel] stringByReplacingOccurrencesOfString:@"iPhone Simulator" withString:@"Simulator"];
		    if ([TSTime skew] == 0) {
			cell.textLabel.text = [model stringByAppendingString:@" offset"];
			cell.detailTextLabel.text = @"unknown";
		    } else {
			if ([TSTime skew] < 0) {
			    cell.textLabel.text = [model stringByAppendingString:@" ahead of NTP by"];
			} else {
			    cell.textLabel.text = [model stringByAppendingString:@" behind NTP by"];
			}
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%7.2f sec", fabs([TSTime skew])];
			if (fabs([TSTime skew]) > 86400) {
			    cell.detailTextLabel.textColor = [UIColor systemRedColor];
			}
		    }
		    break;
		  }
	        case 2:
		    cell.textLabel.text = @"NTP Sync Accuracy";
		    double skewLB = [ECTS skewLB];
		    double skewUB = [ECTS skewUB];
		    double skewAverage = (skewUB - skewLB) / 2;  // The skew we use is always in the middle of the range anyway, so this loses no information
		    if (skewAverage >= 1e9 || [TSTime skew] == 0) {
			cell.detailTextLabel.text = @"-";
		    } else {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"±%.2f sec", skewAverage];
		    }
		    break;
		case 3:
		    cell.textLabel.text = @"Timezone";
		    cell.detailTextLabel.text = [watchEnv timeZoneName];
		    break;
		case 4:
		    cell.textLabel.text = @"Current UTC offset";
		    cell.detailTextLabel.text = [ECOptions formatTZOffset:[watchTime tzOffsetUsingEnv:watchEnv]/3600.0];
		    break;
		default:
		    assert(false);
		    break;
	    }
	    break;
	case 1:		// location
	    switch (indexPath.row) {
		case 0:
		    cell.textLabel.text = @"Status";
		    cell.detailTextLabel.text = [[lm statusText] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
		    break;
		case 1:
		    cell.textLabel.text = @"Latitude";
		    cell.detailTextLabel.text = [lm latitudeString2];
		    break;
		case 2:
		    cell.textLabel.text = @"Longitude";
		    cell.detailTextLabel.text = [lm longitudeString2];
		    break;
		case 3:
		    cell.textLabel.text = @"Horizontal Error";
		    if (lm.locationOverridden || [lm lastHorizontalErrorMeters] < 0) {
			cell.detailTextLabel.text = @"-";
		    } else {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"±%.0f m", [lm lastHorizontalErrorMeters]];
		    }
		    break;
		case 4:
		    cell.textLabel.text = @"Last Sync";
		    cell.detailTextLabel.text = [NSString stringWithCString:ESCalendar_formatTimeInterval([lm lastFix], [ECOptions currentTimeZone], "MMM dd HH:mm:ss") encoding:NSUTF8StringEncoding];
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

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return (isIpad()) ? 40 : 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (isIpad()) {
        UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(0, 20, 320, 20)] autorelease];
        label.font = [UIFont boldSystemFontOfSize:16];
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor secondaryLabelColor];
        label.text = category == 0 ? @"Time Info" : @"Location Info";
        label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        return label;
    } else {
        return nil;
    }
}

@end

