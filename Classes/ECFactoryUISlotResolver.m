//
//  ECFactoryUISlotResolver.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 2/2/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "ECFactoryUISlotResolver.h"
#import "ECFactoryUI.h"
#import "ECGeoNames.h"
#import "ECOptions.h"
#import "ChronometerAppDelegate.h"
#import "ECWatchEnvironment.h"


@implementation ECFactoryUISlotResolver

#define offsetToEnvSlot2(offset) (offset - firstEnvSlotOffset)

-(ECFactoryUISlotResolver *)initForWatch:(ECGLWatch *)aWatch withCity:(NSString *)city zoneName:(NSString *)tzName latitude:(double)aLat longitude:(double)aLong firstEnvSlotOffset:(int)aFirstEnvSlotOffset geoNamesDB:(ECGeoNames *)db {
    if (self = [super initWithNibName:@"ECFactoryThirdFloor" bundle:nil]) {
	assert(db);
	myCity = [city retain];
	myTZ = ESCalendar_initTimeZoneFromOlsonID([tzName UTF8String]);
	myLat = aLat;
	myLong = aLong;
	locDB = [db retain];
	offsetA = offsetB = -99;
	firstEnvSlotOffset = aFirstEnvSlotOffset;
	watch = [aWatch retain];
    }
    return self;
}

- (void)viewDidLoad {
    nSlots = 0;
    // figure out potential slots for this city
    for (int offset=-11; offset<=12; offset++) {
	if ([locDB selectedCityValidForSlotAtOffsetHour:offset]) {
	    if (offsetA == -99) {
		offsetA = offset;
		nSlots++;
	    } else if (offsetB == -99) {
		offsetB = offset;
		nSlots++;
	    } else {
		assert(false);	    // found more than two slots for this city???
	    }
	}
    }
    if (nSlots == 1) {
	self.navigationItem.title = @"1 matching slot";
    } else if (nSlots == 2) {
	self.navigationItem.title = @"2 matching slots";
    } else {
	assert(false);
    }
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel",@"Resolver cancel button title") style:UIBarButtonItemStylePlain target:self action:@selector(cancelButton:)] autorelease];
    [self.tableView reloadData];
}

- (void)cancelButton:(id)foo {
    [self.navigationController popToRootViewControllerAnimated: YES];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    assert(section == 0);
    return nSlots;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    assert(section == 0);
    return [NSString stringWithFormat:@"Choose a city to replace with\n   %@:", myCity];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    assert(section == 0);
    return [NSString stringWithFormat:NSLocalizedString(@"\nSelecting %@ city will replace that city with\n%@\n%@", @"footer format for slot picker"), nSlots==1 ? @"the" : @"a", myCity, [ECOptions formatInfoForTZ:myTZ type:2]];
}

#define MAIN_FONT_SIZE 18
// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(indexPath.section == 0);
    assert(indexPath.row < nSlots);
    static NSString *CellIdentifier = @"ECFactoryThirdFloorCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
	int offset = indexPath.row == 0 ? offsetA : offsetB;
   	cell = [ECFactoryUI tripleCell:offset < 0 ? offset+24: offset	    // inverse of zone<13 ? zone : zone-24
				   top:[watch enviroWithIndex:offsetToEnvSlot2(offset)].cityName
				bottom:[ECOptions formatInfoForTZ:[watch enviroWithIndex:offsetToEnvSlot2(offset)].estz type:2]
			    rightColor:[UIColor systemBlueColor]
			    disclosure:false
                         replaceNotMap:true];
    }
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(indexPath.row == 0 || indexPath.row == 1);
    int offset = (indexPath.row == 0 ? offsetA : offsetB);
    [watch enviroWithIndex:offsetToEnvSlot2(offset)].cityName = myCity;
    [[watch enviroWithIndex:offsetToEnvSlot2(offset)] setTimeZone:myTZ];
    [watch enviroWithIndex:offsetToEnvSlot2(offset)].latitude = myLat;
    [watch enviroWithIndex:offsetToEnvSlot2(offset)].longitude= myLong;
    [ECFactoryUI saveDefaultsForWatch:watch env:offsetToEnvSlot2(offset) city:myCity timeZone:myTZ latitude:[locDB selectedCityLatitude] longitude:[locDB selectedCityLongitude]];
    [ChronometerAppDelegate needFactoryWork];
    [self.navigationController popViewControllerAnimated: YES];
}

- (void)dealloc {
    [myCity release];
    ESCalendar_releaseTimeZone(myTZ);
    [locDB release];
    [watch release];
    [super dealloc];
}


@end

