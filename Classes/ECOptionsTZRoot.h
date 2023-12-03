//
//  ECOptionsTZRoot.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 10/7/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Constants.h"

#define NUMCONTINENTS 14
#define NUMOTHERS 108

@interface ECOptionsTZRoot : UITableViewController {
    bool	    autoMode;
}

#ifndef NDEBUG
+ (NSString **)otherTZs;
#endif

@end
