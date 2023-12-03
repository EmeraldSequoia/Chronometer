//
//  ECFactoryUIGlobalSearch.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 2/2/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ECGeoNames.h"
#import "ECGLWatch.h"


// ECFactoryUIGlobalSearch handles front side unconstrained global search

@interface ECFactoryUIGlobalSearch : UITableViewController  <UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate> {
    ECGeoNames	    *locDB;
    int             firstEnvSlotOffset;
    ECGLWatch	    *watch;
    UISearchController *searchController;
}

- (ECFactoryUIGlobalSearch *)initForWatch:(ECGLWatch *)aWatch withFirstEnvSlotOffset:(int)aFirstEnvSlotOffset locDB:(ECGeoNames *)db;

@end
