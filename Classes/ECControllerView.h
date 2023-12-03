//
//  ECControllerView.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 5/22/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ECControllerView : UIView {
    UITouch *firstTouch;
    CGPoint firstTouchPoint;
    NSTimeInterval firstTouchTimestamp;
    NSTimeInterval lastTouchTimestamp;
}

@end
