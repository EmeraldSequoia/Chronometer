//
//  ECOptionsRecents.h
//  Chronometer
//
//  Created by Bill Arnett on 10/13/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ECOptionsLoc.h"

@interface ECOptionsRecentItem : NSObject {
    CLLocationCoordinate2D  position;
    NSString		    *name;
    NSString		    *region;
    bool		    ambiguous;		// looks the same as some other entry
}

@property (readonly, nonatomic) NSString *name, *region;
@property (nonatomic) bool ambiguous;
@property (readonly, nonatomic) CLLocationCoordinate2D position;

- (ECOptionsRecentItem *)initWithName:(NSString *)name region:(NSString *)regio position:(CLLocationCoordinate2D)pos;

@end

@interface ECOptionsRecents : UITableViewController {
    ECOptionsLoc *parent;
}
    
+ (void)push:(NSString *)name region:(NSString *)regio position:(CLLocationCoordinate2D)pos;
- (ECOptionsRecents *)initWithParent:(ECOptionsLoc *)parent;

@end
