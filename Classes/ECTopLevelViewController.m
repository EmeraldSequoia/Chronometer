//
//  ECTopLevelViewController.m
//
//  Created by Steve Pucci 04 Apr 2011
//  Copyright Emerald Sequoia LLC 2011. All rights reserved.
//

#import "ECTopLevelViewController.h"
#import "ECGLViewController.h"
#import "ECGlobals.h"
#import "ECTopLevelView.h"
#import "ChronometerAppDelegate.h"

@implementation ECTopLevelViewController

- (id)init {
    [super init];
    // Deprecated in iOS7 as no-op:  self.wantsFullScreenLayout = YES;  // overlap with status bar
    return self;
}

- (void)setStatusBarHidden:(BOOL)hidden {
    statusBarHidden = hidden;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (BOOL)prefersStatusBarHidden {
    printf("prefersStatusBarHidden called\n");
    return statusBarHidden;
}

- (void)loadView {
    CGSize sz = [UIScreen mainScreen].bounds.size;;
    self.view = [[ECTopLevelView alloc] initWithFrame:CGRectMake(0, 0, sz.width, sz.height)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    //printf("top viewWillAppear\n");
//    UIInterfaceOrientation interfaceOrientation = [self interfaceOrientation];
//    [ChronometerAppDelegate willAnimateRotationToOrientation:interfaceOrientation duration:0];
//    [ChronometerAppDelegate willRotateToOrientation:interfaceOrientation duration:0];
//    [ChronometerAppDelegate didRotateFromOrientation:interfaceOrientation];  // this isn't right; we should be supplying the "from" orientation
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    //printf("top viewDidAppear\n");
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // printf("supportedInterfaceOrientations on top level view controller\n");
    return isIpad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

// Note steve 2020/01/20: willAnimateRotationToOrientation was deprecated in iOS 9,
// and the documentation for the deprecated method says to use viewWillTransitionToSize
// instead.
//
// Transition coordinators are a completely different way of handling animation, where
// instead of an animation interval (or end time), the animation coordinator handles the
// curve of motion and calls back to each animating controller callback block with the
// current progress.  Also, and most significantly, an animation can be "cancelled" by
// the user, apparently at any time, and it is the responsibility of each callback
// block to be able to restore the state to its original pre-transition state.
//
// Cancelling would be difficult for us to do, since our animating of watches in the context
// of a device rotation does not remember the previous state.  And of course our motion
// animation in OpenGL coordinates uses a different strategy altogether.
//
// If Apple ever changes this from a deprecation to "you can't do this any more" we can
// rewrite it, but in the mean time, just leaving as is.
//
// Documentation for willAnimateRotationToInterfaceOrientation:duration: follows:
// This method is called from within the animation block that is used to rotate the
// view. You can override this method and use it to configure additional animations that
// should occur during the view rotation. For example, you could use it to adjust the zoom
// level of your content, change the scroller position, or modify other animatable
// properties of your view.
// By the time this method is called, the interfaceOrientation property is already set to
// the new orientation. Thus, you can perform any additional layout required by your views
// in this method.

// Documentation for viewWillTransitionToSize:withTransitionCoordinator:

// UIKit calls this method before changing the size of a presented view controller’s
// view. You can override this method in your own objects and use it to perform additional
// tasks related to the size change. For example, a container view controller might use
// this method to override the traits of its embedded child view controllers. Use the
// provided coordinator object to animate any changes you make.  If you override this
// method in your custom view controllers, always call super at some point in your
// implementation so that UIKit can forward the size change message appropriately. View
// controllers forward the size change message to their views and child view
// controllers. Presentation controllers forward the size change to their presented view
// controller.
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)newInterfaceOrientation  // See block above about deprecation.
					 duration:(NSTimeInterval)duration {
    [ChronometerAppDelegate willAnimateRotationToOrientation:newInterfaceOrientation duration:duration];
    [super willAnimateRotationToInterfaceOrientation:newInterfaceOrientation duration:duration];
    printf("top willAnimateRotationToInterfaceOrientation\n");
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation  // See block above about deprecation.
				duration:(NSTimeInterval)duration {
    [ChronometerAppDelegate willRotateToOrientation:toInterfaceOrientation duration:duration];
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
//    printf("top willRotateToInterfaceOrientation\n");
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {  // See block above about deprecation.
//    [ChronometerAppDelegate didRotateFromOrientation:fromInterfaceOrientation];
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    printf("top didRotateToInterfaceOrientation\n");
}

- (void)viewWillLayoutSubviews {
    [ChronometerAppDelegate willLayoutSubviews];
    // printf("top will layout subviews\n");
}

- (void)didReceiveMemoryWarning {
    // Do nothing!  Don't call super here! (see assert in viewDidUnload)
}

@end
