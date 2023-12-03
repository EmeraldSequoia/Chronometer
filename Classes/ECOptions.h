//
//  ECOptions.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/29/2009.
//  Copyright Emerald Sequoia LLC 2009. All rights reserved.
//

#import "ECLocationManager.h"

#include "ESCalendar.h"  // for opaque ESTimeZone

@class ECGeoNames;

@interface ECOptions : UITableViewController <UITableViewDataSource, UITableViewDelegate> {
    ECGeoNames	*locDB;
    bool	needRelease;	    // we reserved some RAM and stopped the BG loader
}

+ (NSString *)formatInfoForTZ:(ESTimeZone *)estz type:(int)typ;
+ (NSString *)formatTZOffset:(float)off;
+ (double)minOffsetForTZ:(ESTimeZone *)tz;
+ (NSString *)formatTime;
+ (NSString *)currentTZName;
+ (NSInteger)currentTZOffset;
+ (NSString *)currentTZSource;
+ (NSString *)currentTZSourceInfo;
+ (NSString *)currentTZInfo;
+ (NSString *)currentShortTZInfo;
+ (NSString *)currentCity;
+ (NSString *)currentRegion;
+ (NSString *)currentCityRegion;
+ (ESTimeZone *)currentTimeZone;
+ (void)restoreTZ;
+ (void)setTimeZoneWithName:(NSString *)tzName updateWatches:(bool)updateWatches;		    // pass nil for autoTZ
+ (void)autoTZUpdate;
+ (void)setTimezone:(ESTimeZone *)tz andCenter:(CLLocationCoordinate2D)center;
+ (void)setCurrentCity:(NSString *)city region:(NSString *)region;
+ (void)setCurrentCityUnknownIfAuto:(NSString *)city region:(NSString *)region;
+ (void)setCurrentCityUnknown;
+ (void)setAutoLoc:(bool)newVal;
+ (void)setAutoTZ:(bool)newVal;
+ (bool)purpleZone;			    // true if we're not in the local timezone
- (void)locateMyself;

@end
