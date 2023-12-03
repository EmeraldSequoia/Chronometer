//
//  ECTopLevelViewController.h
//
//  Created by Steve Pucci 04 Apr 2011
//  Copyright Emerald Sequoia LLC 2011. All rights reserved.
//
#ifndef _ECTOPLEVELVIEWCONTROLLER_H_
#define _ECTOPLEVELVIEWCONTROLLER_H_

/*! Controller for window, created primarily so window elements can autorotate */
@interface ECTopLevelViewController : UIViewController {
    BOOL statusBarHidden;
}

- (void)setStatusBarHidden:(BOOL)hidden;

@end

#endif  // _ECTOPLEVELVIEWCONTROLLER_H_
