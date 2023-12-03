//
//  ECOptionsBigmap.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 10/8/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "ECOptionsLoc.h"

@class ECLocationPin;

@interface ECOptionsBigmap : UIViewController<MKMapViewDelegate> {
    ECOptionsLoc	*parent;
    UIView		*titleView;
    UIImageView         *xhairView;
    UISegmentedControl	*mapSat;
    MKMapView           *mapView;
    bool		settable;
    bool                centerSetDone;
    ECLocationPin       *pin;
}

-(ECOptionsBigmap *)initWithParent:(ECOptionsLoc *)parent settable:(bool)settable;

@end
