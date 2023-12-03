#ifndef NDEBUG
//
//  ECDebugController.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 3/6/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ECGeoNames;

@interface ECMapGeneratorController : UIViewController {
    UIView		    *mapView;
    UIView		    *titleView;
    UISegmentedControl	    *opType;
    ECGeoNames		    *locDB;
    UIActivityIndicatorView *spinner;
}

- (ECMapGeneratorController *)initWithDB:(ECGeoNames *)db;

@end

#endif
