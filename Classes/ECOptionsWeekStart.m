//
//  ECOptionsWeekStart.m
//  Chronometer
//
//  Created by William Arnett on 1/10/2012.
//  Copyright (c) 2012 Emerald Sequoia LLC. All rights reserved.
//

#import "ECGlobals.h"
#import "ECOptionsWeekStart.h"
#import "ChronometerAppDelegate.h"
#import "ECGLWatch.h"

@implementation ECOptionsWeekStart

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = NSLocalizedString(@"Starting Weekday", @"Weekday Start screen title");
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(doneAction:)] autorelease];
}

// when the user taps the Exit button, exit
- (IBAction) doneAction: (id) sender {
    [ChronometerAppDelegate optionDone];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return 3;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
	case 0:
 	    return NSLocalizedString(@"Start weeks on:", @"calendar weekday start section header");
	default:
	    assert(false);
	    return @"Huh?";
    }
}


- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
	case 0:
 	    return NSLocalizedString(@"Specifies which day of the week will appear in the first column of Babylon's calendar", @"calendar weekday start section footer");
	default:
	    assert(false);
	    return @"Huh?";
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"WDS Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Configure the cell...
    int check;
    switch (indexPath.row) {
	case 0:
	    cell.textLabel.text = NSLocalizedString(@"Sunday", @"Sunday");
	    check = 0;
	    break;
	case 1:
	    cell.textLabel.text = NSLocalizedString(@"Monday", @"Monday");
	    check = 1;
	    break;
	case 2:
	    cell.textLabel.text = NSLocalizedString(@"Saturday", @"Saturday");
	    check = 6;
	    break;
	default:
	    assert(false);
            check = 0;  // Silence overzealous compiler
	    break;
    }
    if (ECCalendarWeekdayStart == check) {
	cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
	cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
	case 0:
	    ECCalendarWeekdayStart = 0;	    // Sunday
	    break;
	case 1:
	    ECCalendarWeekdayStart = 1;	    // Monday
	    break;
	case 2:
	    ECCalendarWeekdayStart = 6;	    // Saturday
	    break;
	default:
	    assert(false);
	    break;
    }
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:ECCalendarWeekdayStart] forKey:@"ECCalendarWeekdayStart"];
    [self.tableView reloadData];
    assert([NSThread isMainThread]);
    ECGLWatch *theBabylonWatch = [ChronometerAppDelegate availableWatchWithName:@"Babylon"];
    assert(theBabylonWatch);
    [theBabylonWatch updateAllPartsForModeNum:ECfrontMode animating:false];
    //[ChronometerAppDelegate forceUpdateAllowingAnimation:false dragType:ECDragNotDragging];
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)dealloc {
    [super dealloc];
}

@end
