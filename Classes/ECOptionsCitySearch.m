//
//  ECOptionsCitySearch.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 10/13/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import "ECOptionsCitySearch.h"
#import "Constants.h"
#import "ECLocationManager.h"
#undef ECTRACE
#import "ECTrace.h"

@implementation ECOptionsCitySearch

- (ECOptionsCitySearch *)initWithParent:(ECOptionsLoc *)aParent locDB:(ECGeoNames *)aLocDB placeholderText:(NSString *)aPlaceholderText {
    traceEnter("ECOptionsCitySearch::init");
    if (self = [super init]) {
	parent = [aParent retain];
        locDB = [aLocDB retain];
        placeholderText = [aPlaceholderText retain];
    }
    traceExit("ECOptionsCitySearch::init");
    return self;
}

- (void)dealloc {
    traceEnter("ECOptionsCitySearch::dealloc");
    [parent release];
    [locDB release];
    [placeholderText release];
    [searchController release];
    [super dealloc];
    traceExit("ECOptionsCitySearch::dealloc");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [locDB searchForCityNameFragment:@"" withProximity:true];
    searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.searchResultsUpdater = self;
    searchController.hidesNavigationBarDuringPresentation = NO;
    searchController.obscuresBackgroundDuringPresentation = NO;
    searchController.searchBar.delegate = self;
    searchController.searchBar.placeholder = placeholderText;
    searchController.delegate = self;
    self.tableView.tableHeaderView = searchController.searchBar;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.definesPresentationContext = YES;
    searching = false;
}

- (void)viewDidAppear:(BOOL)animated {
    traceEnter("ECOptionsCitySearch viewDidAppear");
    [super viewDidAppear:animated];
    searchController.active = YES;
    traceExit("ECOptionsCitySearch viewDidAppear");
}

- (void)didPresentSearchController:(UISearchController *)aSearchController {
    traceEnter("didPresentSearchController");
    assert(aSearchController == searchController);
    [searchController.searchBar becomeFirstResponder];
    traceExit("didPresentSearchController");
}

// UISearchResultsUpdating methods      	---------------------------------------------------------

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self.tableView reloadData];
}

// UISearchBarDelegate methods			---------------------------------------------------------

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    searching = true;
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    searching = false;
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    return YES;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    traceEnter("textDidChange");
    // start (or restart) a search for the given city name fragment
    [locDB searchForCityNameFragment:searchText withProximity:true];
    traceExit ("textDidChange");
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    traceEnter("searchBarCancelButtonClicked");
    [self.navigationController popViewControllerAnimated:true];
    traceExit("searchBarCancelButtonClicked");
}

// UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    assert(section == 0);
    int numMatches = [locDB numMatches];
    if (numMatches == 0) {
        return 2;  // A blank line and "No results found"
    }
    return numMatches;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"SearchCell";
    static NSString *NotFoundCellIdentifier = @"SearchCellNotFound";
    
    bool tableIsEmpty = [locDB numMatches] == 0;
    NSString *cellIdentifier = tableIsEmpty ? NotFoundCellIdentifier : CellIdentifier;

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        if (tableIsEmpty) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:NotFoundCellIdentifier] autorelease];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.textColor = [UIColor darkGrayColor];
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
    cell.detailTextLabel.text = [locDB selectedCityRegionName];
    return cell;
}

// UITableViewDelegate methogs

- (NSIndexPath *)tableView:(UITableView *)tableView 
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([locDB numMatches] == 0) {
        return nil;
    }
    return indexPath;
}

// user picked one
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    traceEnter("ECOptionsCitySearch:didSelectRowAtIndexPath");
    if ([locDB numMatches] == 0) {
        return;
    }
    [locDB selectNthTopCity:indexPath.row];
    [parent useSelectedCity];
    [self.navigationController popViewControllerAnimated:true];
    traceExit("ECOptionsCitySearch:didSelectRowAtIndexPath");
}

@end

