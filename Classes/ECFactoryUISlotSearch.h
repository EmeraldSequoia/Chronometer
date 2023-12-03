//
//  ECFactoryUISlotSearch.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 1/19/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ECFactoryUI.h"
#import "ECGeoNames.h"


// ECFactoryUISlotSearch is the UI for both front (constrained) and back (unconstrained) city searching

@interface ECFactoryUISlotSearch : UITableViewController  <UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate> {
    int		    myEnvSlot;
    ECGeoNames	    *locDB;
    bool	    emptySearch;
    bool	    constrained;	    // ie Terra back side
    int		    myOffset;
    ECGLWatch	    *watch;
    UISearchController *searchController;
}

- (ECFactoryUISlotSearch *)initForWatch:(ECGLWatch *)aWatch envSlot:(int)env offset:(int)offs constrained:(bool)constrainMe locDB:(ECGeoNames *)db;

@end
