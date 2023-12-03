//
//  ECOptionsData.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 2/11/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ECHelpController;

@interface ECOptionsData : UITableViewController {
    int			category;
    NSTimer		*dataRefreshTimer;
    ECHelpController	*parent;
    bool		nearPresent;
}

- (ECOptionsData *)initForCategory:(int)n parent:(ECHelpController *)parent;

@end
