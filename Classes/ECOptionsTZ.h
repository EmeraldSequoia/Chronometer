//
//  ECOptionsTZ.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 10/7/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ECOptionsLoc.h"

@interface ECOptionsTZ : UITableViewController {
    NSString	**timeZoneList;
    int		numZones;
}

- (UITableViewController *)initWith:(int)n timeZones:(NSString **)zones;

@end
