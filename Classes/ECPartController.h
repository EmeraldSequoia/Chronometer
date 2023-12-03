//
//  ECPartController.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/23/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ECWatch.h"
#import "ECWatchController.h"

@class ECWatchPart, ECQView, ECVisualController, ECWatchArchive, EBVirtualMachine;


@interface ECPartController : NSObject {
    ECWatchPart *model;
    ECWatchController *watchController;
    ECQView *ecView;
@protected
    int xrayLevel;
    int grabPrio;
    int envSlot;
    int specialness;
    bool cornerRelative;
    unsigned int specialParameter;
    CGRect boundsOnScreen;  // used only for non-image parts like no-view buttons
}

@property (readonly, nonatomic) ECQView *ecView;
@property (readonly, nonatomic) ECWatchController *watchController;
@property (readonly, nonatomic) ECWatchPart *model;
@property (readonly, nonatomic) int envSlot;
@property (readonly, nonatomic) int specialness;
@property (readonly, nonatomic) bool cornerRelative;

- (ECPartController *)initWithModel:(ECWatchPart *)model
			     master:(ECWatchController *)theBoss
			   grabPrio:(int)grabPrio
			    envSlot:(int)envSlot
                     cornerRelative:(bool)cornerRelative
			specialness:(int)specialness
		   specialParameter:(unsigned int)specialParameter;
- (bool)isVisual;
- (ECPartRepeatStrategy)repeatStrategy;
- (bool)immediate;
- (bool)expanded;
- (bool)flipOnBack;
- (bool)cornerRelative;
- (ECButtonEnabledControl)enabledControl;
- (void)print;
- (void)willTerminate;
- (void)lastMinuteViewPrep;
- (int)grabPrio;
- (void)archivePartToImagePath:(NSString *)imagePath
	usingTextureSlotNumber:(int)textureSlot
	       needToSaveImage:(bool)needToSaveImage
		   masterIndex:(int)masterIndex
	     usingWatchArchive:(ECWatchArchive *)watchArchive
	   usingVirtualMachine:(EBVirtualMachine *)vm;
@end


@interface ECVisualController : ECPartController {
@private
    bool opaquePart;
@protected
}

- (ECVisualController *)initWithModel:(ECWatchPart *)model
                                 view:(ECQView *)view
                               master:(ECWatchController *)theBoss
                               opaque:(bool)opaque
                             grabPrio:(int)grabPrio
                              envSlot:(int)envSlot
                          specialness:(int)specialness
                     specialParameter:(unsigned int)specialParameter
                       cornerRelative:(bool)cornerRelative;

@end


@interface ECHandController : ECVisualController {
}

- (ECHandController *)initWithModel:(ECWatchPart *)model
			       view:(ECQView *)view
			     master:(ECWatchController *)theBoss
			     opaque:(bool)opaque
			   grabPrio:(int)grabPrio
			    envSlot:(int)envSlot
			specialness:(int)specialness
		   specialParameter:(unsigned int)specialParameter
                     cornerRelative:(bool)cornerRelative;
@end


@interface ECAnimationController : ECVisualController {
}

@end


@interface ECBlinkerController : ECVisualController {
}

@end

@interface ECTickController : ECPartController {
}

- (void)audibilize;

@end


@interface ECTuneController : ECPartController {
@private
    NSInvocationOperation *tuneOp;
}

- (void)audibilize;

@end


@interface ECButtonController : ECVisualController {
@private
    double xOffset, yOffset, width, height, xScale, yScale;		// position / scale of this button
    double xMotion, yMotion, rotation;					// how much it moves when pressed
    double opacity;
    ECButtonEnabledControl enableControl;
    bool immediate, expanded;
    ECPartRepeatStrategy repeatStrategy;
    UIImage *image;							// may be nil
    UIImage *image2x;							// may be nil
    UIImage *image4x;							// may be nil
    NSTimer *repeater;							// for the repeating action
    bool flipOnBack;
}

- (ECButtonController *)initWithModel:(ECWatchButton *)part
			       master:(ECWatchController *)container
				image:(UIImage *)image
			      image2x:(UIImage *)image2x
			      image4x:(UIImage *)image4x
			      opacity:(double)op
				    x:(double)x
				    y:(double)y
				width:(double)w
			       height:(double)h
		       enabledControl:(ECButtonEnabledControl)enableControl
		       repeatStrategy:(ECPartRepeatStrategy)repeatStrategy
			    immediate:(bool)immediate
			     expanded:(bool)expanded
			   flipOnBack:(bool)flipOnBack
			       xScale:(double)xScale
			       yScale:(double)yScale
			    animSpeed:(double)animSpeed
			     grabPrio:(int)grabPrio
			      envSlot:(int)envSlot
			  specialness:(int)specialness
		     specialParameter:(unsigned int)specialParameter
		       cornerRelative:(bool)cornerRelative
			     rotation:(double)rot
			      xMotion:(double)xm
			      yMotion:(double)ym;

@end
