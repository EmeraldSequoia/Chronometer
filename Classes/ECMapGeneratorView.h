#ifndef NDEBUG
//
//  ECDebugView.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 3/7/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ECGeoNames.h"

@interface ECMapGeneratorView : UIView {
    CGImageRef		mapImageRef;
    CGRect		mapRect;
    double		mapWidthPixels,	mapHeightPixels;	// of the map image
    double		myWidth, myHeight;			// of the drawing frame
    ECGeoNames		*locDB;
    NSString		*inputFileName;
    NSString		*outputFileName;
    int			slot;
    int			opType;
}

- (ECMapGeneratorView *)initWithFrame:(CGRect)rect type:(int)typ forSlot:(int)slot inputFile:(NSString *)inf outputFile:(NSString *)outf locDB:(ECGeoNames *)theLocDB;

@end

#endif
