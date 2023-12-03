//
//  ECOptionsRecents.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 10/13/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import "ECOptionsRecents.h"
#import "Constants.h"
#import "ECLocationManager.h"
#undef ECTRACE
#import "ECTrace.h"

static NSMutableArray *recentStack;		    // stack of up to ECMaxRecents objects of type ECOptionsRecentItem
static NSMutableArray *recentStackString;	    // persistent string form of above


@implementation ECOptionsRecentItem

@synthesize name, region, position, ambiguous;

- (ECOptionsRecentItem *)initWithName:(NSString *)nam region:(NSString *)regio position:(CLLocationCoordinate2D)pos {
    if (self = [super init]) {
	name = [nam retain];
	region = [regio retain];
	position = pos;
	ambiguous = false;
    }
    return self;
}

- (void)dealloc {
    [name release];
    [super dealloc];
}
@end


@implementation ECOptionsRecents

+ (void)initialize {
    traceEnter("ECOptionsRecents:initialize");
    recentStackString = [[NSMutableArray alloc] initWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"ECRecentStack"]];
    recentStack = [[NSMutableArray alloc] initWithCapacity:ECMaxRecents];
    for (NSString *str in recentStackString) {
	NSArray *decomp = [str componentsSeparatedByString:@" + "];
	assert([decomp count] == 4);
	NSString *nam = [decomp objectAtIndex:0];
	NSString *regio = [decomp objectAtIndex:1];
	CLLocationCoordinate2D pos;
	pos.latitude = [[decomp objectAtIndex:2] floatValue];
	pos.longitude = [[decomp objectAtIndex:3] floatValue];
	ECOptionsRecentItem *item = [[[ECOptionsRecentItem alloc] initWithName:nam region:regio position:pos] autorelease];
	[recentStack insertObject:item atIndex:[recentStack count]];
        tracePrintf1("Found recent: %s", [nam UTF8String]);
    }
    traceExit("ECOptionsRecents:initialize");
}

- (ECOptionsRecents *)initWithParent:(ECOptionsLoc *)ancestor {
    if (self = [super init]) {
	parent = ancestor;
    }
    return self;
}

+ (void)push:(NSString *)name region:(NSString *)regio position:(CLLocationCoordinate2D)pos {
    traceEnter("ECOptionsRecents:push");
    assert(recentStack);
    if ([recentStack count] >= ECMaxRecents) {
	[recentStack removeObjectAtIndex:ECMaxRecents-1];
    	[recentStackString removeObjectAtIndex:ECMaxRecents-1];
    }
    ECOptionsRecentItem *newItem = [[[ECOptionsRecentItem alloc] initWithName:name region:regio position:pos] autorelease];
    
    // remove any other entry duplicate entry
    for (int i=0; i<[recentStack count]; i++) {
	ECOptionsRecentItem *oldItem = [recentStack objectAtIndex:i];
	if (fabs(oldItem.position.latitude - newItem.position.latitude) < 0.0005 && fabs(oldItem.position.longitude - newItem.position.longitude) < 0.0005) {
	    [recentStack removeObjectAtIndex:i];
	    [recentStackString removeObjectAtIndex:i];
	} else if ([newItem.name compare:oldItem.name] == NSOrderedSame && [newItem.region compare:oldItem.region] == NSOrderedSame) {
	    newItem.ambiguous = oldItem.ambiguous = true;
	}
    }
    
    // convert it into a string and save the whole stack
    NSString *newString = [NSString stringWithFormat:@"%@ + %@ + %8.5f + %8.5f", newItem.name, newItem.region, newItem.position.latitude, newItem.position.longitude];
    [recentStackString insertObject:newString atIndex:0];
    [[NSUserDefaults standardUserDefaults] setObject:recentStackString forKey:@"ECRecentStack"];
    [recentStack insertObject:newItem atIndex:0];
    traceExit("ECOptionsRecents:push");
}

// when the user taps the Edit button...
- (void) editAction: (id) sender {
    UINavigationItem *navItem = self.navigationItem;
    [navItem setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneAction:)] autorelease] animated:YES];
    navItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Clear", @"recents list clear button title") style:UIBarButtonItemStylePlain target:self action:@selector(clearAction:)] autorelease];
    [self setEditing:YES animated:YES];
}

// when the user taps the Done button (Edit mode) ...
- (void) doneAction: (id) sender {
    self.navigationItem.leftBarButtonItem = self.navigationItem.backBarButtonItem;
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editAction:)] autorelease];
    [self setEditing:NO animated:YES];
}

// when the user taps the clear button (Edit mode) ...
- (void) clearAction: (id) sender {
    [recentStack removeAllObjects];
    [recentStackString removeAllObjects];
    [self.tableView reloadData];
    [[NSUserDefaults standardUserDefaults] setObject:recentStackString forKey:@"ECRecentStack"];
}

// tableview delegate methods:

- (void)viewDidLoad {
    [super viewDidLoad];
    //self.navigationItem.rightBarButtonItem  = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Clear", @"recents list clear button title") style:UIBarButtonItemStyleBordered target:self action:@selector(clearAction:)] autorelease];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editAction:)] autorelease];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [recentStack count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(recentStack);
    assert(indexPath.row < ECMaxRecents);
    ECOptionsRecentItem *item = [recentStack objectAtIndex:indexPath.row];

    static NSString *CellIdentifier = @"RecentCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    
    cell.textLabel.text = item.name;
    if (item.ambiguous) {
	cell.detailTextLabel.text = [ECLocationManager positionStringForLatitude:item.position.latitude longitude:item.position.longitude];
    } else {
	cell.detailTextLabel.text = item.region;
    }
    cell.showsReorderControl = YES;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

// user deleted one
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    traceEnter("ECOptionsRecents:commitEditingStyle");
    assert(editingStyle == UITableViewCellEditingStyleDelete);

    // clear the ambiguous flag if there's exactly one like this one
    ECOptionsRecentItem *thisItem = [recentStack objectAtIndex:indexPath.row];
    if (thisItem.ambiguous) {
	ECOptionsRecentItem *dupItem = nil;
	for (int i=0; i<[recentStack count]; i++) {
	    if (i != indexPath.row) {
		ECOptionsRecentItem *otherItem = [recentStack objectAtIndex:i];
		if ([thisItem.name compare:otherItem.name] == NSOrderedSame && [thisItem.region compare:otherItem.region] == NSOrderedSame) {
		    if (dupItem) {
			dupItem = nil;	// more than one, do nothing
			break;		// no need to check further
		    } else {
			assert(otherItem.ambiguous);
			dupItem = otherItem;
		    }
		}
	    }
	}
	if (dupItem) {
	    dupItem.ambiguous = false;
	    [tableView reloadData];
	}
    }

    // update the stack and save it
    [recentStack removeObjectAtIndex:indexPath.row];
    [recentStackString removeObjectAtIndex:indexPath.row];
    [[NSUserDefaults standardUserDefaults] setObject:recentStackString forKey:@"ECRecentStack"];

    // remove from the tableView
    NSArray *ary = [[[NSArray alloc] initWithObjects:indexPath,nil] autorelease];
    [tableView deleteRowsAtIndexPaths:ary withRowAnimation:UITableViewRowAnimationFade];
    
    traceExit ("ECOptionsRecents:commitEditingStyle");
}

// user moved one
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    traceEnter("ECOptionsRecents:moveRowAtIndexPath");
    int fromIndex = fromIndexPath.row;
    int toIndex = toIndexPath.row;
    
    if (fromIndex == toIndex) {
	// noop
    } else {
	ECOptionsRecentItem *item = [[[recentStack objectAtIndex:fromIndex] retain] autorelease];
	NSString *itemStr = [[[recentStackString objectAtIndex:fromIndex] retain] autorelease];
	[recentStack removeObjectAtIndex:fromIndex];
	[recentStackString removeObjectAtIndex:fromIndex];
	[recentStack insertObject:item atIndex:toIndex];
	[recentStackString insertObject:itemStr atIndex:toIndex];

	[[NSUserDefaults standardUserDefaults] setObject:recentStackString forKey:@"ECRecentStack"];
    }
    traceExit ("ECOptionsRecents:moveRowAtIndexPath");
}

// user picked one
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    traceEnter("ECOptionsRecents:didSelectRowAtIndexPath");
    assert(recentStack);
    assert(indexPath.row < ECMaxRecents);
    ECOptionsRecentItem *item = [recentStack objectAtIndex:indexPath.row];
    [parent updateToCoordinate:item.position horizontalError:ECDefaultHorizontalError];
    [self.navigationController popViewControllerAnimated:true];
    traceExit("ECOptionsRecents:didSelectRowAtIndexPath");
}

@end

