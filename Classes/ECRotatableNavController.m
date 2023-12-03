//
//  ECRotatableNavController.m
//
//  Created by Steve Pucci 06 Apr 2011
//  Copyright Emerald Sequoia LLC 2011. All rights reserved.
//

#import "ECRotatableNavController.h"
#import "ECGlobals.h"
#import "ChronometerAppDelegate.h"

@implementation ECRotatableNavController

- (UIInterfaceOrientationMask)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController {
    return isIpad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *view = self.view;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    CGRect bounds = view.frame;
    CGSize appSize = [ChronometerAppDelegate applicationSize];
    CGFloat appWidth = appSize.width;
    if (bounds.size.width != appWidth) {
        bounds.size.width = appWidth;
        bounds.size.height = appSize.height;
        bounds.origin.x = 0;
        view.frame = bounds;
    }
    //printf("nav controller's bounds now %g x %g\n", view.frame.size.width, view.frame.size.height);
}


@end
