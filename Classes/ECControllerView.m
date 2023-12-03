//
//  ECControllerView.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 5/22/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ECControllerView.h"
#import "Constants.h"
#import "ChronometerAppDelegate.h"
#import "ECGlobals.h"


@implementation ECControllerView

- (void) print {
    if ([self isHidden]) {
	printf("    hidden\t");
    } else {
	printf("    visible\t");
    }
}

// This function translates from a coordinate in the view, which comes in from Cocoa as a Y-down
// coordinate in a view which contains offset regions, into a coordinate in the app's frame, which
// is Y-up and centered in the center of the safe portion of that view.
static void translatePointIntoWindow(CGPoint *point) 
{
    CGRect lowerLeftAppBounds = [ChronometerAppDelegate applicationBoundsPoints];
    // printf("lower left application bounds %.1f %.1f %.1f %.1f\n",
    //        lowerLeftAppBounds.origin.x, lowerLeftAppBounds.origin.y, lowerLeftAppBounds.size.width, lowerLeftAppBounds.size.height);
    CGSize viewSize = [ChronometerAppDelegate applicationViewSizePoints];
    // The first step is converting the Y-up app bounds above, whose origin is at the lower left,
    // into a rectangle with the Y-down origin at the top left, to match the incoming point.
    CGRect appBounds = CGRectMake(lowerLeftAppBounds.origin.x,
                                  viewSize.height - (lowerLeftAppBounds.origin.y + lowerLeftAppBounds.size.height),
                                  lowerLeftAppBounds.size.width,
                                  lowerLeftAppBounds.size.height);
    // printf("           application bounds %.1f %.1f %.1f %.1f\n",
    //        appBounds.origin.x, appBounds.origin.y, appBounds.size.width, appBounds.size.height);
    // Now we find the center of that Y-down rectangle of safe area:
    CGPoint center = CGPointMake(appBounds.origin.x + (appBounds.size.width / 2.0),
                                 appBounds.origin.y + (appBounds.size.height / 2.0));
    // printf("center %.1f %.1f\n", center.x, center.y);
    // Finally we convert the incoming Y-down point into a Y-up point relative to that center.
    point->x -= center.x;
    point->y = center.y - point->y;
}

// Handles the start of a touch
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches) {
	firstTouch = touch;
	firstTouchPoint = [touch locationInView:self];
	firstTouchTimestamp = lastTouchTimestamp = [touch timestamp];
    }
    translatePointIntoWindow(&firstTouchPoint);
    [ChronometerAppDelegate touchBeganAtPoint:firstTouchPoint];
}

// Handles the continuation of a touch.
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{  
    UITouch *activeTouch = nil;
    for (UITouch *touch in touches){
	if (touch == firstTouch) {
	    activeTouch = touch;
	}
    }
    if (!activeTouch) {
//	printf("No active touch, resetting firstTouch\n");
	firstTouch = [touches anyObject];
	firstTouchPoint = [firstTouch locationInView:self];
        translatePointIntoWindow(&firstTouchPoint);
	firstTouchTimestamp = lastTouchTimestamp = [firstTouch timestamp];
	return;  // Nothing to do yet
    }
    // printf("touchesMoved %g to %g\n", firstTouchPoint.x, [activeTouch locationInView:self].x);
    lastTouchTimestamp = [activeTouch timestamp];
    CGPoint thisTouchPoint = [activeTouch locationInView:self];
    translatePointIntoWindow(&thisTouchPoint);
    [ChronometerAppDelegate touchMovedFromFirstTouch:firstTouchPoint to:thisTouchPoint];
}

- (bool)touchesMeanSwipe:(NSSet *)touches activeTouch:(UITouch **)activeTouchReturn press:(bool *)pressReturn hold:(bool *)holdReturn {
    UITouch *activeTouch = nil;
    for (UITouch *touch in touches){
	if (touch == firstTouch) {
	    activeTouch = touch;
	}
    }
    if (!activeTouch) {
	*activeTouchReturn = [touches anyObject];
	*pressReturn = false;
	*holdReturn = false;
	return false;
    }
    *activeTouchReturn = activeTouch;
    CGPoint thisTouchPoint = [activeTouch locationInView:self];
    translatePointIntoWindow(&thisTouchPoint);
    double firstDx = fabs(firstTouchPoint.x - thisTouchPoint.x);
    double minSwipeX = isIpad() ? ECMinSwipeXIPad : ECMinSwipeX;
    if (firstDx > minSwipeX) {
	*pressReturn = false;
	*holdReturn = false;
	//printf("Swipe because of distance\n");
	return true;
    }
    double timeSinceFirstTouch = activeTouch.timestamp - firstTouchTimestamp;
    double firstSpeed = firstDx / timeSinceFirstTouch;
    if (firstDx > ECMaxPressX && firstSpeed > ECMinSwipeXFirstSpeed) {
	*pressReturn = false;
	*holdReturn = false;
	//printf("Swipe because of speed\n");
	return true;
    }
    if (firstDx > ECMaxPressX) {
	*pressReturn = false;
	*holdReturn = false;
	//printf("No swipe, no press, no hold (firstDX too large at %.2f)\n", firstDx);
    } else if (timeSinceFirstTouch > ECMinHold) {
	*pressReturn = false;
	*holdReturn = true;
    } else {
	*pressReturn = true;
	*holdReturn = false;
    }
    return false;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{  
    UITouch *touch;
    bool press;
    bool hold;
    if ([self touchesMeanSwipe:touches activeTouch:&touch press:&press hold:&hold]) {
	CGPoint thisTouchPoint = [touch locationInView:self];
        translatePointIntoWindow(&thisTouchPoint);
	if (firstTouchPoint.x < thisTouchPoint.x) {
	    [ChronometerAppDelegate touchEndedPossiblySwipingLeft:false right:true press:press hold:hold at:thisTouchPoint count:0];
	} else {
	    [ChronometerAppDelegate touchEndedPossiblySwipingLeft:true right:false press:press hold:hold at:thisTouchPoint count:0];
	}
    } else {
	CGPoint thisTouchPoint = [touch locationInView:self];
        // printf("touchesEnded found pre-translation point %.1f, %.1f\n", thisTouchPoint.x, thisTouchPoint.y);
        translatePointIntoWindow(&thisTouchPoint);
        // printf("touchesEnded found      translated point %.1f, %.1f\n", thisTouchPoint.x, thisTouchPoint.y);
	[ChronometerAppDelegate touchEndedPossiblySwipingLeft:false right:false press:press hold:hold at:thisTouchPoint count:[touch tapCount]];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
//    printf("touchesCancelled\n");
    [ChronometerAppDelegate touchEndedPossiblySwipingLeft:false right:false press:false hold:false at:CGPointMake(-10000,-10000) count:0];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    printf("ECControllerView (n.b.: NOT controller) got a shouldAutorotate message???\n");
    return (interfaceOrientation == UIInterfaceOrientationPortrait) || isIpad();
}

- (void)dealloc {
    [super dealloc];
}


@end
