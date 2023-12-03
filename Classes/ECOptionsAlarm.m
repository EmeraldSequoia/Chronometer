//
//  ECOptionsAlarm.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 6/26/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "ECOptionsAlarm.h"
#import "ECAudio.h"
#import "ChronometerAppDelegate.h"


@implementation ECOptionsAlarm


#pragma mark -
#pragma mark Initialization

/*
- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if ((self = [super initWithStyle:style])) {
    }
    return self;
}
*/


#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = NSLocalizedString(@"Alarm Sound", @"Alarm sound screen title");
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(doneAction:)] autorelease];
}

// when the user taps the Exit button, exit
- (IBAction) doneAction: (id) sender {
    [ChronometerAppDelegate optionDone];
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return 2;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
	case 0:
 	    return NSLocalizedString(@"For Istanbul & Thebes:", @"alarm section header");
	default:
	    assert(false);
	    return @"Huh?";
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Alarm Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Configure the cell...
    switch (indexPath.row) {
	case 0:
	    cell.textLabel.text = ECAlarmTriangle;
	    break;
	case 1:
	    cell.textLabel.text = ECAlarmChime;
	    break;
	default:
	    break;
    }
    if ([cell.textLabel.text caseInsensitiveCompare:[[NSUserDefaults standardUserDefaults] stringForKey:@"ECAlarmName"]] == NSOrderedSame) {
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
	    [[NSUserDefaults standardUserDefaults] setObject:ECAlarmTriangle forKey:@"ECAlarmName"];
	    [[NSUserDefaults standardUserDefaults] setDouble:ECAlarmTriangleRings forKey:@"ECAlarmRings"];
	    [[NSUserDefaults standardUserDefaults] setDouble:ECAlarmTriangleRepeat forKey:@"ECAlarmRepeatInterval"];
	    break;
	case 1:
	    [[NSUserDefaults standardUserDefaults] setObject:ECAlarmChime forKey:@"ECAlarmName"];
	    [[NSUserDefaults standardUserDefaults] setDouble:ECAlarmChimeRings forKey:@"ECAlarmRings"];
	    [[NSUserDefaults standardUserDefaults] setDouble:ECAlarmChimeRepeat forKey:@"ECAlarmRepeatInterval"];
	    break;
	default:
	    assert(false);
	    break;
    }
    [ECAudio ringOnce];
    [self.tableView reloadData];
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

