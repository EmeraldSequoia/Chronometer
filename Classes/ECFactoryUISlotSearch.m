//
//  ECFactoryUISlotSearch.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 1/19/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "ECFactoryUISlotSearch.h"
#undef ECTRACE
#import "ECTrace.h"
#import "ECOptions.h"
#import "ECWatchEnvironment.h"


@implementation ECFactoryUISlotSearch

- (ECFactoryUISlotSearch *)initForWatch:(ECGLWatch *)aWatch envSlot:(int)env offset:(int)offs constrained:(bool)constrainMe locDB:(ECGeoNames *)db {
    traceEnter("ECFactoryUISlotSearch::initForWatch");
    if (self = [super init]) {
	assert(db);
	assert(!constrainMe || (offs > -12 && offs < 13));
	assert(env > 0 && env <= 28);		// FIX FIX should use aWatch's properties
	myOffset = offs;
	constrained = constrainMe;
	myEnvSlot = env;
	locDB = [db retain];
	watch = [aWatch retain];
    }
    traceExit("ECFactoryUISlotSearch::initForWatch");
    return self;
}

- (void)startSearchFor:(NSString *)str {
    emptySearch = str.length == 0;
    if (constrained) {
	[locDB searchForCityNameFragment:str appropriateForNominalTZSlot:myOffset];
    } else {
	[locDB searchForCityNameFragment:str withProximity:false];
    }

}

// UISearchResultsUpdating methods      	---------------------------------------------------------

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self.tableView reloadData];
}

// when the user taps the Done button, exit
- (void)doneAction: (id)sender {
    [ChronometerAppDelegate optionDone];
}

- (void)viewDidLoad {
    traceEnter("ECFactoryUISlotSearch::viewDidLoad");
    tracePrintf1("nav controller thinks it's %s", [orientationNameForOrientation([self.navigationController interfaceOrientation]) UTF8String]);
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
    [self startSearchFor:@""];
    [self.tableView reloadData];
    self.navigationItem.titleView = [ECFactoryUI littleMapForSlot:constrained ? (myOffset<0 ? 24+myOffset : myOffset) : -myEnvSlot];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(doneAction:)] autorelease];
    traceExit ("ECFactoryUISlotSearch::viewDidLoad");
}

- (void)viewDidAppear:(BOOL)animated {
    traceEnter("ECFactoryUISlotSearch viewDidAppear");
    [super viewDidAppear:animated];
    searchController.active = YES;
    traceExit("ECFactoryUISlotSearch viewDidAppear");
}

- (void)didPresentSearchController:(UISearchController *)aSearchController {
    traceEnter("didPresentSearchController");
    assert(aSearchController == searchController);
    [searchController.searchBar becomeFirstResponder];
    traceExit("didPresentSearchController");
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    traceEnter("ECFactoryUISlotSearch::searchBarCancelButtonClicked");
    // revert to full list
    [self startSearchFor:@""];
    traceExit("ECFactoryUISlotSearch::searchBarCancelButtonClicked");
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
#define ROW_HEIGHT 50.0
#define CITY_FONT_SIZE 18
#define V_OFFSET 7
#define REGION_FONT_SIZE 14
#define INDICATOR_FONT_SIZE 16
#define LABEL_OFFSET 10
#define RIGHT_WIDTH 80
#define RIGHT_OFFSET (320-LABEL_OFFSET-RIGHT_WIDTH)
#define LABEL_WIDTH 280

- (UITableViewCell *)tripleCellForTableView:(UITableView *)tableView city:(NSString *)city region:(NSString *)region indicator:(NSString *)indicator color:(UIColor *)color {
    NSString *cellIdentifier = @"EC TripleCell 2";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell) {
	UILabel *label = [cell.contentView.subviews objectAtIndex:0];
	label.text = city;
	label.textColor = color;
	label = [cell.contentView.subviews objectAtIndex:1];
#ifndef NDEBUG
	label.text = [region stringByAppendingString:[NSString stringWithFormat:@"  (%ld)", [locDB selectedCityPopulation]]];
#else
	label.text = region;
#endif
    	label = [cell.contentView.subviews objectAtIndex:2];
	label.text = indicator;
    } else {
	cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	// city
	// Deprecated iOS 7:  CGSize size = [@"8" sizeWithFont:[UIFont boldSystemFontOfSize:CITY_FONT_SIZE] forWidth:RIGHT_WIDTH lineBreakMode:UILineBreakModeClip];  
        CGRect sizeRect = [@"8" boundingRectWithSize:CGSizeMake(RIGHT_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:CITY_FONT_SIZE]} context:nil];
        CGFloat sizeHeight = ceil(sizeRect.size.height);
	CGRect rect = CGRectMake(LABEL_OFFSET, 2, LABEL_WIDTH, sizeHeight);
	UILabel *label = [[UILabel alloc] initWithFrame:rect];
	label.font = [UIFont boldSystemFontOfSize:CITY_FONT_SIZE];
	label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
	label.backgroundColor = [UIColor clearColor];
	label.textAlignment = NSTextAlignmentLeft;
	label.adjustsFontSizeToFitWidth = true;
	label.textColor = color;
	label.text = city;
	[cell.contentView addSubview:label];
	[label release];
	// region info
	// Deprecated iOS 7:  size = [@"8" sizeWithFont:[UIFont systemFontOfSize:REGION_FONT_SIZE] forWidth:RIGHT_WIDTH lineBreakMode:UILineBreakModeClip];  
        sizeRect = [@"8" boundingRectWithSize:CGSizeMake(RIGHT_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:CITY_FONT_SIZE]} context:nil];
        sizeHeight = ceil(sizeRect.size.height);
	rect = CGRectMake(LABEL_OFFSET, (ROW_HEIGHT - sizeHeight)-V_OFFSET, LABEL_WIDTH, sizeHeight);
	label = [[UILabel alloc] initWithFrame:rect];
	label.font = [UIFont systemFontOfSize:REGION_FONT_SIZE];
	label.textColor = [UIColor secondaryLabelColor];
	label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
	label.backgroundColor = [UIColor clearColor];
	label.textAlignment = NSTextAlignmentLeft;
	label.adjustsFontSizeToFitWidth = true;
#ifndef NDEBUG
	label.text = [region stringByAppendingString:[NSString stringWithFormat:@"  (%ld)", [locDB selectedCityPopulation]]];
#else
	label.text = region;
#endif
	[cell.contentView addSubview:label];
	[label release];
	// slot inclusion indication
	// Deprecated iOS 7:  size = [@"8" sizeWithFont:[UIFont fontWithName:@"Courier" size:INDICATOR_FONT_SIZE] forWidth:RIGHT_WIDTH lineBreakMode:UILineBreakModeClip];  
        sizeRect = [@"8" boundingRectWithSize:CGSizeMake(RIGHT_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:INDICATOR_FONT_SIZE]} context:nil];
        sizeHeight = ceil(sizeRect.size.height);
	rect = CGRectMake(RIGHT_OFFSET, (ROW_HEIGHT-sizeHeight)/2, RIGHT_WIDTH, sizeHeight);
	label = [[UILabel alloc] initWithFrame:rect];
	label.font = [UIFont fontWithName:@"Courier" size:INDICATOR_FONT_SIZE];
	label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
	label.backgroundColor = [UIColor clearColor];
	label.textAlignment = NSTextAlignmentRight;
	label.text = indicator;
        label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[cell.contentView addSubview:label];
	[label release];
    }
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([locDB numMatches] == 0) {
        static NSString *NotFoundCellIdentifier = @"SearchCellNotFound";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NotFoundCellIdentifier];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:NotFoundCellIdentifier] autorelease];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.textColor = [UIColor secondaryLabelColor];
        }
        if (indexPath.row == 1) {
            cell.textLabel.text = @"No results found";
        } else {
            cell.textLabel.text = @"";
        }
        return cell;
    }

    [locDB selectNthTopCity:indexPath.row];
    
    // Set up the cell...
    NSString *indic = nil;
    if (constrained) {
	switch ([locDB selectedCityInclusionClassForSlotAtOffsetHour:myOffset]) {
	    case normalHasDST:		    // 1    fills the slot exactly						    Los Angeles
	    case halfNoDST:		    // 1    in the middle of a slot						    Mumbai
	    case oddNoDST:		    // 1    off center of slot							    Kathmandu
		indic = @" = ";
		break;
	    case normalNoDSTLeft:	    // 2    on the boundary between this slot and the next one east		    Phoenix
	    case halfHasDSTLeft:	    // 2    evenly splits the boundary between this slot and the one to the east    Adelaide
		indic = @" =>";
		break;
    	    case normalNoDSTRight:	    // 2    on the boundary between this slot and the next one west		    Phoenix
	    case halfHasDSTRight:	    // 2    evenly splits the boundary between this slot and the one to the west    Adelaide
		indic = @"<= ";
		break;
	    case oddHasDST:		    // 1    off center of a slot						    <none as of 2010>
	    case notIncluded:		    // 0    doesnt fit in this slot
	    default:
		assert(false);
		break;
	}
    } else {
	indic = @"";
    }
    UIColor *color;
    if ([watch hasCityAtLatitude:[locDB selectedCityLatitude] longitude:[locDB selectedCityLongitude]]) {
	if (fabs([locDB selectedCityLatitude]  - [watch enviroWithIndex:myEnvSlot].latitude ) < 0.01  &&
	    fabs([locDB selectedCityLongitude] - [watch enviroWithIndex:myEnvSlot].longitude) < 0.01) {
	    color = [UIColor systemBlueColor];  // It's what's already in the slot
	} else {
	    color = [UIColor systemIndigoColor];  // It's in some other slot
	}
    } else {
	color = [UIColor labelColor];  // It's in no slot
    }

    return [self tripleCellForTableView:tableView city:[locDB selectedCityName] region:[locDB selectedCityRegionName] indicator:indic color:color];
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
    ESTimeZone *estz = ESCalendar_initTimeZoneFromOlsonID([[locDB selectedCityTZName] UTF8String]);
    [[watch enviroWithIndex:myEnvSlot] setNewCity:[locDB selectedCityName]
					     zone:estz
				  latitudeDegrees:[locDB selectedCityLatitude]
				 longitudeDegrees:[locDB selectedCityLongitude]
					 override:!constrained];
    [ECFactoryUI saveDefaultsForWatch:watch
				  env:myEnvSlot
				 city:[locDB selectedCityName]
			     timeZone:estz
			     latitude:[locDB selectedCityLatitude] 
			    longitude:[locDB selectedCityLongitude]];
    ESCalendar_releaseTimeZone(estz);
    [ChronometerAppDelegate needFactoryWork];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self.navigationController popViewControllerAnimated: YES];
}

- (void)dealloc {
    [locDB release];
    [watch release];
    [searchController release];
    [super dealloc];
}


@end

