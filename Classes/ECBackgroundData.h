//
//  ECBackgroundData.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/13/2010 from ECOptionsData
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ECHelpController;

@interface ECBackgroundData : UITableViewController  <UITableViewDataSource, UITableViewDelegate> {
    int			category;
}

- (ECBackgroundData *)initForCategory:(int)n;
+ (void)refresh;

@end
