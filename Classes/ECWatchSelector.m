//
//  ECWatchSelector.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 11/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.

#import "ECWatchSelector.h"
#import "ChronometerAppDelegate.h"
#import "ECGLWatch.h"
#import "ECGlobals.h"

static bool globalEditingFlag = false;

@interface ECWatchSelectorCell : UITableViewCell {
    int rowIndex;
    ECWatchSelector *parent;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;

@property (nonatomic) int rowIndex;
@property (assign, nonatomic) ECWatchSelector *parent;

@end

@implementation ECWatchSelectorCell

@synthesize rowIndex, parent;

#define CHECK_TAG      1
#define WATCH_ICON_TAG 2
#define WATCH_NAME_TAG 3
#define HELPWORD_TAG   4

#define CHECK_COLUMN_OFFSET (ECisPre30 ? 15.0 : -5.0)
#define CHECK_OFFSCREEN_X (ECisPre30 ? -30.0 : -300.0)
#define HELPWORD_OFFSCREEN_X 1000
#define HELPWORD_COLUMN_WIDTH 85

#define CELL_WIDTH 320.0
#define ROW_HEIGHT 50.0
#define MAIN_FONT_SIZE 20.0

#define CHECK_COLUMN_WIDTH 30.0
#define CHECK_IMAGE_WIDTH 30.0
#define CHECK_IMAGE_HEIGHT 30.0
	
#define WATCH_ICON_PADDING 8.0
#define WATCH_ICON_COLUMN_OFFSET (CHECK_COLUMN_OFFSET + CHECK_COLUMN_WIDTH + WATCH_ICON_PADDING)
#define WATCH_ICON_COLUMN_WIDTH 40.0
#define WATCH_ICON_IMAGE_WIDTH 40.0
#define WATCH_ICON_IMAGE_HEIGHT 40.0
	
#define WATCH_NAME_ICON_PADDING 8.0
#define WATCH_NAME_COLUMN_OFFSET (WATCH_ICON_COLUMN_OFFSET + WATCH_ICON_COLUMN_WIDTH + WATCH_NAME_ICON_PADDING)
#define WATCH_NAME_COLUMN_WIDTH (CELL_WIDTH - HELPWORD_COLUMN_WIDTH - WATCH_NAME_COLUMN_OFFSET)

#define HELPWORD_ICON_PADDING 8.0
#define HELPWORD_ICON_PADDING_IPAD 200
#define HELPWORD_COLUMN_OFFSET (WATCH_ICON_COLUMN_OFFSET + WATCH_ICON_COLUMN_WIDTH + WATCH_NAME_COLUMN_WIDTH + (isIpad() ? HELPWORD_ICON_PADDING_IPAD : HELPWORD_ICON_PADDING))
#define HELPWORD_RIGHT_PADDING 8.0

#define MAIN_FONT_SIZE 20.0
#define CHECK_FONT_SIZE 20.0
#define HELPWORD_FONT_SIZE 12.0
	

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (globalEditingFlag) {
	bool isActive;
	[ChronometerAppDelegate availableWatchForIndex:rowIndex isActive:&isActive];
	UILabel *checkView = (UILabel *)[self viewWithTag:CHECK_TAG];
	CGRect checkFrame = checkView.frame;
	if (isActive) {   // now active, turn it off
	    if ([ChronometerAppDelegate watchCount] == 1) {
		return;
	    }
	    assert([ChronometerAppDelegate watchCount] > 1);
	    checkFrame.origin.x = CHECK_OFFSCREEN_X;
	} else {  // now inactive, turn it on
	    checkFrame.origin.x = CHECK_COLUMN_OFFSET;
	}
	checkView.frame = checkFrame;
	[ChronometerAppDelegate setWatchActive:!isActive forAvailableIndex:rowIndex alreadyLocked:false];
	parent.navigationItem.leftBarButtonItem.title = [ChronometerAppDelegate watchCount] > 1 ? NSLocalizedString(@"One",@"One") : NSLocalizedString(@"All",@"All");
    } else {
	[super touchesBegan:touches withEvent:event];
    }
}

@end

@implementation ECWatchSelector

-(id) init {
//    [super initWithStyle:UITableViewStylePlain];
    [super initWithStyle:UITableViewStyleGrouped];
    
    return self;
}

- (void)cancelMe:(id)sender {
    [ChronometerAppDelegate selectorCancel];
}

- (void)editDone:(id)sender {
    if (editingOnly) {
	editingOnly = false;
	[ChronometerAppDelegate selectorCancel];
	return;
    }
    self.title = NSLocalizedString(@"Switch to Watch",@"Watch switcher title");
    UINavigationItem *navItem = self.navigationItem;
    [navItem setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(cancelMe:)] autorelease] animated:YES];
    [navItem setLeftBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editMe:)] autorelease] animated:YES];
    [self setEditing:NO animated:YES];
}

- (void)allAction:(id)sender {
    assert(globalEditingFlag);
    bool turnOn = [ChronometerAppDelegate watchCount] == 1;	// only one on -> turn them all ON; more than one on -> turn them all OFF except the currentWatch
    [ChronometerAppDelegate setActiveForAllAvailableWatches:turnOn];
    self.navigationItem.leftBarButtonItem.title = turnOn ? NSLocalizedString(@"One",@"One") : NSLocalizedString(@"All",@"All");
    [[self tableView] reloadData];
}

- (void)editMe:(id)sender {
    self.title = NSLocalizedString(@"Available Watches",@"Watch editor title");
    UINavigationItem *navItem = self.navigationItem;
    [navItem setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(editDone:)] autorelease] animated:YES];
    navItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"One",@"One") style:UIBarButtonItemStylePlain target:self action:@selector(allAction:)] autorelease];
    if ([ChronometerAppDelegate watchCount] == 1) {
	navItem.leftBarButtonItem.title =  NSLocalizedString(@"All",@"All");
    }
    [self setEditing:YES animated:YES];
}

- (void)loadView {
    [super loadView];
    UINavigationItem *navItem = self.navigationItem;
    if (editingOnly) {
	self.title = NSLocalizedString(@"Available Watches",@"Watch editor title");
	navItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"One" style:UIBarButtonItemStylePlain target:self action:@selector(allAction:)] autorelease];
	navItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(editDone:)] autorelease];
	if ([ChronometerAppDelegate watchCount] == 1) {
	    navItem.leftBarButtonItem.title =  NSLocalizedString(@"All",@"All");
	}
	[self setEditing:YES animated:NO];
    } else {
	globalEditingFlag = false;
	self.title = NSLocalizedString(@"Switch to Watch",@"Watch switcher title");
	navItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Exit",@"Exit button title") style:UIBarButtonItemStylePlain target:self action:@selector(cancelMe:)] autorelease];
	navItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editMe:)] autorelease];
    }
}

- (void)setEditingOnly:(bool)eo {
    editingOnly = eo;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // show the current watch
    NSIndexPath *scrollIndexPath;
    scrollIndexPath = [NSIndexPath indexPathForRow:[ChronometerAppDelegate currentWatchNumber] inSection:0];
    [[self tableView] scrollToRowAtIndexPath:scrollIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

-(NSInteger) tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    assert(section == 0);
    if (self.editing) {
	return [ChronometerAppDelegate availableWatchCount];
    } else {
	return [ChronometerAppDelegate watchCount];
    }
}

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(void)  tableView:(UITableView *)tableView
moveRowAtIndexPath:(NSIndexPath *)fromIndexPath
       toIndexPath:(NSIndexPath *)toIndexPath {
    assert([fromIndexPath indexAtPosition:0] == 0);
    assert([fromIndexPath length] == 2);
    assert([toIndexPath indexAtPosition:0] == 0);
    assert([toIndexPath length] == 2);
    int fromIndex = (int) [fromIndexPath indexAtPosition:1];
    int toIndex = (int) [toIndexPath indexAtPosition:1];
    if (fromIndex == toIndex) {
	return;
    }
    
    // Now change all of the stored tags...
    // from:  += delta
    ECWatchSelectorCell *cell = (ECWatchSelectorCell *)[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:fromIndex inSection:0]];
    cell.rowIndex = toIndex;
    int indx;
    if (fromIndex < toIndex) {
	// from < cell < to: --
	for (indx = fromIndex + 1; indx <= toIndex; indx++) {
	    cell = (ECWatchSelectorCell *)[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indx inSection:0]];
	    cell.rowIndex = indx - 1;
	}
    } else {
	// from < cell < to: ++
	for (indx = fromIndex - 1; indx >= toIndex; indx--) {
	    cell = (ECWatchSelectorCell *)[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indx inSection:0]];
	    cell.rowIndex = indx + 1;
	}
    }

    [ChronometerAppDelegate moveWatchAtAvailableIndex:(int)fromIndex toIndex:(int)toIndex];
}

static UIImage *imageForWatch(ECGLWatch *watch) {
    NSString *imagePath = [@"chooser" stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", watch.name]];
    // printf("imageNamed %s\n", [imagePath UTF8String]);
    return [UIImage imageNamed:imagePath];
}

-(void) configureCell:(ECWatchSelectorCell *)cell atRow:(int)row editing:(bool)isEditing indexIsFromAvailable:(bool)indexIsFromAvailable animated:(bool)animated {
    bool isActive;
    int availableIndex;
    ECGLWatch *watch = indexIsFromAvailable ? [ChronometerAppDelegate availableWatchForIndex:row isActive:&isActive] : [ChronometerAppDelegate activeWatchForIndex:row availableIndex:&availableIndex];
#if 0
    printf("configureCell at row %d, %s %s, => %s\n",
	   row, isEditing ? " isEditing" : "!isEditing",
	   indexIsFromAvailable ? " indexIsFromAvailable" : "!indexIsFromAvailable",
	   [[watch name] UTF8String]);
#endif
    cell.rowIndex = indexIsFromAvailable ? row : availableIndex;

    // watch name
    UILabel *label = (UILabel *)[cell viewWithTag:WATCH_NAME_TAG];
    label.text = [watch displayName];
    if (watch == [ChronometerAppDelegate currentWatch] && !editingOnly) {
	label.textColor = [UIColor blueColor];
    } else {
	label.textColor = [UIColor labelColor];
    }

    // watch icon
    UIImageView *imageView = (UIImageView *)[cell viewWithTag:WATCH_ICON_TAG];
    imageView.image = imageForWatch(watch);

    UILabel *nameView = (UILabel *)[cell viewWithTag:WATCH_NAME_TAG];
    nameView.text = [watch displayName];
    UILabel *checkView = (UILabel *)[cell viewWithTag:CHECK_TAG];
    CGRect checkFrame = checkView.frame;
    
    UILabel *helpwordView = (UILabel *)[cell viewWithTag:HELPWORD_TAG];
    helpwordView.text = [watch helpword];
    CGRect helpwordFrame = helpwordView.frame;
    if (animated) {
	[UIView beginAnimations:nil context:nil];
    }
    if (isEditing) {
	// Later, when we have naming or time zones for specific watches:
//	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	cell.accessoryType = UITableViewCellAccessoryNone;
	if (indexIsFromAvailable) {
	    if (isActive) {
		checkFrame.origin.x = CHECK_COLUMN_OFFSET;
	    } else {
		checkFrame.origin.x = CHECK_OFFSCREEN_X;
	    }
	} else {
	    assert(false);
	}
	helpwordFrame.origin.x = HELPWORD_OFFSCREEN_X;
    } else {
	cell.accessoryType = UITableViewCellAccessoryNone;
	checkFrame.origin.x = CHECK_OFFSCREEN_X;
	helpwordFrame.origin.x = HELPWORD_COLUMN_OFFSET;
    }
    checkView.frame = checkFrame;
    helpwordView.frame = helpwordFrame;

    if (animated) {
	[UIView commitAnimations];
    }
}

-(ECWatchSelectorCell *)tableViewCellWithReuseIdentifier:(NSString *)identifier {

    // Create an instance of UITableViewCell and add tagged subviews
    ECWatchSelectorCell *cell = [[[ECWatchSelectorCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier] autorelease];
    cell.parent = self;
    //cell.selectionStyle = UITableViewCellSelectionStyleNone;		// prevents accidental selection when double clicking too slowly but also disables highlighting

    // Create elements for the subviews:
    UIView *contentView = cell.contentView;

    // Leftmost: check view
    UIFont *font = [UIFont boldSystemFontOfSize:CHECK_FONT_SIZE];
    // Deprecated iOS 7:  CGSize size = [@"√" sizeWithFont:font forWidth:CHECK_COLUMN_WIDTH lineBreakMode:NSLineBreakByClipping];
    CGRect sizeRect = [@"√" boundingRectWithSize:CGSizeMake(CHECK_COLUMN_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:font} context:nil];
    CGFloat sizeHeight = ceil(sizeRect.size.height);
    CGRect rect = CGRectMake(CHECK_OFFSCREEN_X, (ROW_HEIGHT - sizeHeight) / 2.0, CHECK_IMAGE_WIDTH, sizeHeight);
    
    UILabel *label = [[UILabel alloc] initWithFrame:rect];
    label.tag = CHECK_TAG;
    label.font = font;
    label.text = @"√";
    label.adjustsFontSizeToFitWidth = YES;
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    [cell.contentView addSubview:label];
    label.highlightedTextColor = [UIColor whiteColor];
    [label release];

    // Next: watch icon
    rect = CGRectMake(WATCH_ICON_COLUMN_OFFSET, (ROW_HEIGHT - WATCH_ICON_IMAGE_HEIGHT) / 2.0, WATCH_ICON_IMAGE_WIDTH, WATCH_ICON_IMAGE_HEIGHT);
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:rect];
    imageView.tag = WATCH_ICON_TAG;
    [contentView addSubview:imageView];
    [imageView release];

    font = [UIFont boldSystemFontOfSize:MAIN_FONT_SIZE];
    // Deprecated iOS 7:  size = [@"Fy" sizeWithFont:font forWidth:WATCH_NAME_COLUMN_WIDTH lineBreakMode:UILineBreakModeClip];  
    sizeRect = [@"Fy" boundingRectWithSize:CGSizeMake(CHECK_COLUMN_WIDTH, ROW_HEIGHT) options:0 attributes:@{NSFontAttributeName:font} context:nil];
    sizeHeight = ceil(sizeRect.size.height);

    // Next: watch name
    rect = CGRectMake(WATCH_NAME_COLUMN_OFFSET, (ROW_HEIGHT - sizeHeight) / 2.0, WATCH_NAME_COLUMN_WIDTH, sizeHeight);
    label = [[UILabel alloc] initWithFrame:rect];
    label.tag = WATCH_NAME_TAG;
    label.font = font;
    
    label.adjustsFontSizeToFitWidth = YES;
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    [cell.contentView addSubview:label];
    label.highlightedTextColor = [UIColor whiteColor];
    [label release];
	
    // Next: helpword
    font = [UIFont boldSystemFontOfSize:HELPWORD_FONT_SIZE];
    rect = CGRectMake(HELPWORD_COLUMN_OFFSET, (ROW_HEIGHT - sizeHeight) / 2.0, HELPWORD_COLUMN_WIDTH - HELPWORD_RIGHT_PADDING, sizeHeight);
    label = [[UILabel alloc] initWithFrame:rect];
    label.tag = HELPWORD_TAG;
    label.font = font;
//    label.textAlignment = UITextAlignmentRight;
    
    label.adjustsFontSizeToFitWidth = YES;
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    [cell.contentView addSubview:label];
    label.highlightedTextColor = [UIColor whiteColor];
    [label release];
	
    return cell;
}

-(UITableViewCell *)tableView:(UITableView *)tableView
	cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    assert([indexPath indexAtPosition:0] == 0);
    assert([indexPath length] == 2);
    NSUInteger indx = [indexPath indexAtPosition:1];
    bool isEditing = self.editing;

    NSString *reuseIdentifier = @"WatchCell";
    ECWatchSelectorCell *cell = (ECWatchSelectorCell *)[tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
	cell = [self tableViewCellWithReuseIdentifier:reuseIdentifier];
    }
    [self configureCell:cell atRow:indx editing:isEditing indexIsFromAvailable:isEditing animated:false];
    return cell;
}

// Set the editing state of the view controller. We pass this down to the table view and also modify the content
// of the table to insert a placeholder row for adding content when in editing mode.
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    globalEditingFlag = editing;
    // Calculate the index paths for all of the placeholder rows based on the number of items in each section.
    NSArray *indexPaths = [ChronometerAppDelegate indexPathsForInactiveWatches];
    UITableView *tableView = [self tableView];
    if (animated) {
	[tableView beginUpdates];
	[tableView setEditing:editing animated:animated];
	if (editing) {
	    // Show the inactive rows
	    [tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
#ifndef NDEBUG
            for (NSIndexPath *indexPath in indexPaths) {
		assert([indexPath indexAtPosition:0] == 0);
		assert([indexPath length] == 2);
	    }
#endif
	} else {
	    // Hide the inactive rows.
	    [tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
#ifndef NDEBUG
            for (NSIndexPath *indexPath in indexPaths) {
		assert([indexPath indexAtPosition:0] == 0);
		assert([indexPath length] == 2);
	    }
#endif
	}
	for (ECWatchSelectorCell *cell in [tableView visibleCells]) {
	    [self configureCell:cell atRow:cell.rowIndex editing:editing indexIsFromAvailable:true animated:animated];
	}
	[tableView endUpdates];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    assert([indexPath indexAtPosition:0] == 0);
    assert([indexPath length] == 2);
    if (! self.editing) {
	NSUInteger indx = [indexPath indexAtPosition:1];
	[ChronometerAppDelegate selectorChoose:indx];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
	   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) {  // OS2.0 bug?
	return UITableViewCellEditingStyleNone;
    }
    assert([indexPath indexAtPosition:0] == 0);
#ifndef NDEBUG
    if ([indexPath length] != 2) {
	printf("editingStyle got path length %lu\n", (unsigned long)[indexPath length]);
    }
    assert([indexPath length] == 2);
#endif
    return UITableViewCellEditingStyleNone;
}

- (CGFloat)   tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    assert([indexPath indexAtPosition:0] == 0);
    assert([indexPath length] == 2);
    return ROW_HEIGHT;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return isIpad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}


@end
