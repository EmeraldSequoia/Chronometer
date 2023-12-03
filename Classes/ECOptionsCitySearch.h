//
//  ECOptionsCitySearch.h
//  Chronometer
//
//  Created by Steve Pucci on 11/15/2018.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//
//  based on
//
//  Created by Bill Arnett on 10/13/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ECOptionsLoc.h"

@interface ECOptionsCitySearch : UITableViewController<UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate> {
    ECOptionsLoc            *parent;
    bool                    searching;
    UISearchController      *searchController;
    ECGeoNames              *locDB;
    NSString                *placeholderText;
}
    
- (ECOptionsCitySearch *)initWithParent:(ECOptionsLoc *)parent locDB:(ECGeoNames *)locDB placeholderText:(NSString *)placeholderText;

@end
