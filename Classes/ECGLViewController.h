//
//  ECGLViewController.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 11/2009
//  Copyright Emerald Sequoia LLC 2009. All rights reserved.
//

@class ECGLView;

@interface ECGLViewController : UIViewController {
    UIView *window;
    UIInterfaceOrientation currentOrientation;  // Because willAnimateRotationToInterfaceOrientation doesn't know old orientation
}

-(id)initForWindow:(UIView *)window;

-(ECGLView *)glView;

@end
