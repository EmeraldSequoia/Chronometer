//
//  ECFactoryUIGlobalSearch.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 2/2/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "ECFactoryUIGlobalSearch.h"
#import "ChronometerAppDelegate.h"
#import "ECFactoryUISlotResolver.h"
#import "ECFactoryUI.h"
#import "ECTrace.h"
#import "ECOptions.h"


@implementation ECFactoryUIGlobalSearch


- (ECFactoryUIGlobalSearch *)initWithStyle:(UITableViewStyle)style {
    if (self = [super initWithStyle:style]) {
    }
    return self;
}

- (ECFactoryUIGlobalSearch *)initForWatch:(ECGLWatch *)aWatch withFirstEnvSlotOffset:(int)aFirstEnvSlotOffset locDB:(ECGeoNames *)db {
    if (self = [super init]) {
	assert(db);
	firstEnvSlotOffset = aFirstEnvSlotOffset;
	watch = [aWatch retain];
	locDB = [db retain];
    }
    return self;
}

- (void)startSearchFor:(NSString *)str {
    [locDB searchForCityNameFragment:str withProximity:false];
}

// when the user taps the Done button, exit
- (void)doneAction: (id)sender {
    [ChronometerAppDelegate optionDone];
}

- (void)viewDidLoad {
    self.tableView.scrollEnabled = YES;
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(doneAction:)] autorelease];
    self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Search",@"Slot picker back button title") style:UIBarButtonItemStylePlain target:nil action:nil] autorelease];
    self.navigationItem.titleView = [ECFactoryUI littleMapForSlot:24];

    searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.searchResultsUpdater = self;
    searchController.hidesNavigationBarDuringPresentation = NO;
    searchController.obscuresBackgroundDuringPresentation = NO;
    searchController.searchBar.delegate = self;
    searchController.delegate = self;
    self.tableView.tableHeaderView = searchController.searchBar;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.definesPresentationContext = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    searchController.active = YES;
}

- (void)didPresentSearchController:(UISearchController *)aSearchController {
    traceEnter("didPresentSearchController");
    assert(aSearchController == searchController);
    [searchController.searchBar becomeFirstResponder];
    traceExit("didPresentSearchController");
}

- (void)viewWillAppear:(BOOL)animated {
    [self startSearchFor:@""];
//    [self.searchDisplayController setActive:false animated:YES];  // This doesn't work in iOS 7 when *returning* to this controller via navigation pop; do it in viewDidAppear instead
    [self.tableView reloadData];
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    //traceEnter("ECFactorySecondFloor::searchBarCancelButtonClicked");
    // revert to full list
    [self startSearchFor:@""];
    //traceExit("ECFactorySecondFloor::searchBarCancelButtonClicked");
}


- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchString {
    traceEnter("textDidChange");
    // start (or restart) a search for the given city name fragment

    if (searchString.length > 0) {
	[self startSearchFor:searchString];
    } else {
	[self startSearchFor:@""];
    }
    
    traceExit ("textDidChange");
}

// UISearchResultsUpdating methods      	---------------------------------------------------------

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self.tableView reloadData];
}

// UITableView Delegate Methods 			---------------------------------------------------------


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    int numMatches = [locDB numMatches];
    if (numMatches == 0) {
        return 2;  // A blank line and "No results found"
    }
    return numMatches;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"FactorySecondFloorCell";
    static NSString *NotFoundCellIdentifier = @"SearchCellNotFound";
    
    bool tableIsEmpty = [locDB numMatches] == 0;
    NSString *cellIdentifier = tableIsEmpty ? NotFoundCellIdentifier : CellIdentifier;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        if (tableIsEmpty) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:NotFoundCellIdentifier] autorelease];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.textColor = [UIColor secondaryLabelColor];
        } else {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
        }
    }
    
    // Set up the cell...
    if (tableIsEmpty) {
        if (indexPath.row == 1) {
            cell.textLabel.text = @"No results found";
        } else {
            cell.textLabel.text = @"";
        }
        return cell;
    }
    [locDB selectNthTopCity:indexPath.row];
    cell.textLabel.text = [locDB selectedCityName];
    if ([watch hasCityAtLatitude:[locDB selectedCityLatitude] longitude:[locDB selectedCityLongitude]]) {
	cell.textLabel.textColor = [UIColor systemIndigoColor];	 // it's somewhere on the watch but not here
    } else {
	cell.textLabel.textColor = [UIColor labelColor];
    }
#ifndef NDEBUG
    cell.detailTextLabel.text = [[locDB selectedCityRegionName] stringByAppendingString:[NSString stringWithFormat:@"  (%ld)", [locDB selectedCityPopulation]]];
#else
    cell.detailTextLabel.text = [locDB selectedCityRegionName];
#endif
    
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView 
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([locDB numMatches] == 0) {
        return nil;
    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([locDB numMatches] == 0) {
        return;
    }
    [locDB selectNthTopCity:indexPath.row];
    UITableViewController *vc = [[[ECFactoryUISlotResolver alloc] initForWatch:watch
								      withCity:[locDB selectedCityName]
								      zoneName:[locDB selectedCityTZName]
								      latitude:[locDB selectedCityLatitude]
								     longitude:[locDB selectedCityLongitude]
							    firstEnvSlotOffset:firstEnvSlotOffset
								    geoNamesDB:locDB] autorelease];
    vc.navigationItem.title = [locDB selectedCityName];
    [self.navigationController pushViewController:vc animated:true];
}

- (void)dealloc {
    [locDB release];
    [watch release];
    [super dealloc];
}


@end

