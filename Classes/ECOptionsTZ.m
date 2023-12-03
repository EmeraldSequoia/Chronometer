//
//  ECOptionsTZ.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 10/7/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import "ECOptionsTZ.h"
#import "ECOptionsLoc.h"
#import "Constants.h"
#import "ECOptions.h"
#undef ECTRACE
#import "ECTrace.h"
#import "ECErrorReporter.h"
#import "ECWatchTime.h"
#import "TSTime.h"

@implementation ECOptionsTZ


- (UITableViewController *)initWith:(int)n timeZones:(NSString **)zones {
    if (self = [super initWithStyle:UITableViewStylePlain] ) {
	timeZoneList = zones;
	numZones = n;
    }
    return self;
}

- (void)viewDidLoad {
    traceEnter("ECOptionsTZ::viewDidLoad");
    [super viewDidLoad];
    //self.navigationItem.title = @"TimeZone";
    //self.navigationItem.rightBarButtonItem  = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStyleBordered target:self action:@selector(cancelAction:)];
    traceExit("ECOptionsTZ::viewDidLoad");
}

-(void)cancelAction:(id)sender {
    tracePrintf("popping ECOptionsTZ controller (cancel)");
    [self.navigationController popViewControllerAnimated: YES];
}

// tableView delegate methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return numZones;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {    
    traceEnter("ECOptionsTZ::cellForRowAtIndexPath");
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ECTZCell"];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ECTZCell"] autorelease];
    }

    if (ESCalendar_validOlsonID([timeZoneList[indexPath.row] UTF8String])) {
        ESTimeZone *estz = ESCalendar_initTimeZoneFromOlsonID([timeZoneList[indexPath.row] UTF8String]);
        cell.textLabel.text = [NSString stringWithCString:ESCalendar_timeZoneName(estz) encoding:NSUTF8StringEncoding];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:[UIFont labelFontSize]];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.text = [ECOptions formatInfoForTZ:estz type:3];
        if ([timeZoneList[indexPath.row] compare:[ECOptions currentTZName]] == NSOrderedSame) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        if (ESCalendar_tzOffsetForTimeInterval(estz, [TSTime currentTime]) == [ECOptions currentTZOffset]) {
            cell.textLabel.textColor = [UIColor systemBlueColor];
        } else {
            cell.textLabel.textColor = [UIColor labelColor];
        }
    } else {
        cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"(%@)", @"format for invalid tiemzone"),  timeZoneList[indexPath.row]];
        cell.textLabel.font = [UIFont italicSystemFontOfSize:[UIFont labelFontSize]];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.text = NSLocalizedString(@"unusable", @"invalid timezone note");
    }
    tracePrintf1 ("%s", [cell.textLabel.text UTF8String]);
    traceExit ("ECOptionsTZ::cellForRowAtIndexPath");
    
    return cell;
}

// user picked one of the zones; set the timezone and exit
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (ESCalendar_validOlsonID([timeZoneList[indexPath.row] UTF8String])) {
        [ECOptions setTimeZoneWithName:timeZoneList[indexPath.row] updateWatches:true];
        tracePrintf("popping ECOptionsTZ controller (pick)");
        [self.navigationController popViewControllerAnimated: YES];
    } else {
        tracePrintf("invalid tz");
        [[ECErrorReporter theErrorReporter] reportWarning:[NSString stringWithFormat:NSLocalizedString(@"%@\nis not recognized by this version of iOS",@"format for invalid timezone"),
                                                                    timeZoneList[indexPath.row]]];
    }
}

- (void)dealloc {
    traceEnter("ECOptionsTZ::dealloc");
    //[self.navigationItem.rightBarButtonItem release];
    //self.navigationItem.rightBarButtonItem = nil;
    [super dealloc];
    traceExit("ECOptionsTZ::dealloc");
}

@end

