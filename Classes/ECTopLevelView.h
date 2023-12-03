//
//  ECTopLevelView.h
//
//  Created by Steve Pucci 11 Apr 2011
//  Copyright Emerald Sequoia LLC 2011. All rights reserved.
//

#ifndef _ECTOPLEVELVIEW_H_
#define _ECTOPLEVELVIEW_H_

@class ECGLView;

/*! Container view for everything except the OpenGL view */
@interface ECTopLevelView : UIView {
    ECGLView            *glView;
}

@property (retain, nonatomic) ECGLView *glView;;

@end

#endif  // _ECTOPLEVELVIEW_H_
