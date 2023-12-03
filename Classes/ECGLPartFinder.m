//
//  ECGLPartFinder.m.
//  Emerald Chronometer
//
//  Created by Steve Pucci in August 2008
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "ChronometerAppDelegate.h"
#import "ECGLPartFinder.h"
#import "ECGLWatch.h"
#import "ECGLPart.h"

@implementation ECGLPartFinder

- (ECGLPartBase *)findClosestActivePartInWatch:(ECGLWatch *)watch
                                         andBG:(ECGLWatch *)bgWatch
                                       toPoint:(CGPoint)point {
    // Algorithm:
    // Collect all parts for which the bounds, possibly expanded to the minimum size, enclose the given point
    //   If there is only one such part, return it
    //   Otherwise see how far we are from the border.  The one furthest from the border wins
    // If no parts completely enclose the point, return nil
    ECWatchModeEnum modeNum = [watch currentModeNum];
    NSMutableSet *enclosingParts = [NSMutableSet setWithCapacity:5];
    int highestPrioritySeen = ECGrabPrioLB;
    CGPoint watchPoint = point;
    double iPhoneScaleFactor = [ChronometerAppDelegate iPhoneScaleFactor];
    double watchZoom = [watch zoom];
    watchZoom *= iPhoneScaleFactor;
    watchPoint.x /= watchZoom;
    watchPoint.y /= watchZoom;
    for (ECGLPartBase *part in [watch partBases]) {
	if ([part activeInModeNum:modeNum] && [part enclosesPoint:watchPoint forModeNum:modeNum]) {
	    [enclosingParts addObject:part];
	    int grabPriority = [part grabPriority];
	    if (grabPriority > highestPrioritySeen) {
		highestPrioritySeen = grabPriority;
	    }
	}
    }
    double bgZoom = [bgWatch zoom];
    bgZoom *= iPhoneScaleFactor;
    point.x /= bgZoom;
    point.y /= bgZoom;
    // printf("Start bg part search bgZoom %.2f point %.1f, %.1f\n", bgZoom, point.x, point.y);
    for (ECGLPartBase *part in [bgWatch partBases]) {
	if ([part activeInModeNum:modeNum]) {
            if ([part enclosesPoint:point forModeNum:modeNum]) {
                [enclosingParts addObject:part];
                int grabPriority = [part grabPriority];
                if (grabPriority > highestPrioritySeen) {
                    highestPrioritySeen = grabPriority;
                }
            }
        }
    }
    // printf("End of bg search\n");
    int enclosingPartCount = [enclosingParts count];
    if (enclosingPartCount == 0) {
	return nil;
    }
    if (enclosingPartCount == 1) {
	return [enclosingParts anyObject];
    }
    ECGLPartBase *partFurthestFromBorder = nil;
    double distanceFurthestFromBorder = -1; // all parts should be positive since all are enclosed
    for (ECGLPartBase *part in enclosingParts) {
	if ([part grabPriority] == highestPrioritySeen) {
	    double dist = [part distanceFromBorderToPoint:([part watch] == bgWatch ? point : watchPoint) forModeNum:modeNum];
	    if (dist > distanceFurthestFromBorder) {
		distanceFurthestFromBorder = dist;
		partFurthestFromBorder = part;
	    }
	}
    }
    assert(partFurthestFromBorder);
    return partFurthestFromBorder;
}

@end
