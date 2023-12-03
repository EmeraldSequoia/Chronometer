//
//  ECGLViewController.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 11/2009
//  Copyright Emerald Sequoia LLC 2009. All rights reserved.
//

#import "ECGLViewController.h"
#import "ChronometerAppDelegate.h"
#import "ECGLView.h"
#import "ECGlobals.h"
#import "ECGLWatch.h"

@implementation ECGLViewController

-(id)initForWindow:(UIView *)win {
    [super init];
    window = win;
    // Deprecated iOS 8:  currentOrientation = self.interfaceOrientation;
    // Deprecated iOS 7:  self.wantsFullScreenLayout = YES;  // overlap with status bar
    return self;
}

-(void)loadView {
    ECGLView *glView = [[ECGLView alloc] init];
    self.view = glView;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return isIpad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

// Subclasses may override this method to perform additional actions immediately prior to
// the rotation. For example, you might use this method to disable view interactions, stop
// media playback, or temporarily turn off expensive drawing or live updates. You might
// also use it to swap the current view for one that reflects the new interface
// orientation. When this method is called, the interfaceOrientation property still
// contains the view’s original orientation.
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation  // See block in ECTopLevelViewController about deprecation.
				duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    printf("GL willRotate\n");
    currentOrientation = toInterfaceOrientation;  // Cause, despite the documentation, we're not rotated in didRotate
    [ChronometerAppDelegate willRotateToOrientation:toInterfaceOrientation duration:duration];
}

// This method is called from within the animation block that is used to rotate the
// view. You can override this method and use it to configure additional animations that
// should occur during the view rotation. For example, you could use it to adjust the zoom
// level of your content, change the scroller position, or modify other animatable
// properties of your view.
// By the time this method is called, the interfaceOrientation property is already set to
// the new orientation. Thus, you can perform any additional layout required by your views
// in this method.
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)newInterfaceOrientation  // See block in ECTopLevelViewController about deprecation.
					 duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:newInterfaceOrientation duration:duration];
    printf("GL willAnimateRotation\n");
    [ChronometerAppDelegate willAnimateRotationToOrientation:newInterfaceOrientation duration:duration];
}

// Subclasses may override this method to perform additional actions immediately after the
// rotation. For example, you might use this method to reenable view interactions, start
// media playback again, or turn on expensive drawing or live updates. By the time this
// method is called, the interfaceOrientation property is already set to the new
// orientation.
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {  // See block in ECTopLevelViewController about deprecation.
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    printf("GL didRotate\n");
    [ChronometerAppDelegate didRotateFromOrientation:fromInterfaceOrientation];
}

- (NSUInteger)supportedInterfaceOrientations:(UIWindow *)window {
    printf("supportedInterfaceOrientations on GL view controller\n");
    return isIpad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (void)viewWillLayoutSubviews {
    // printf("gl view will layout subviews\n");
    [[self glView] orientationChange];
}

-(ECGLView *)glView {
    return (ECGLView *)self.view;
}

-(void)dealloc {
    [super dealloc];
}

@end
