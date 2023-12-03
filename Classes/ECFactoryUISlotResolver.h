//
//  ECFactoryUISlotResolver.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 2/2/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ECFactoryUI.h"
#import "ECGeoNames.h"


// ECFactoryUISlotResolver handles the final part of ECFactoryGlobalSearch's job: picking which slot to put the chosen city into

@interface ECFactoryUISlotResolver : UITableViewController {
    NSString	    *myCity;
    ESTimeZone	    *myTZ;
    ECGeoNames	    *locDB;
    double	    myLat, myLong;
    int		    nSlots;
    int		    offsetA;
    int		    offsetB;
    int             firstEnvSlotOffset;
    ECGLWatch	    *watch;
}

-(ECFactoryUISlotResolver *)initForWatch:(ECGLWatch *)aWatch withCity:(NSString *)city zoneName:(NSString *)tzName latitude:(double)aLat longitude:(double)aLong firstEnvSlotOffset:(int)aFirstEnvSlotOffset geoNamesDB:(ECGeoNames *)db;

@end
