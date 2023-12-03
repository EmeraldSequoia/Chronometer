//
//  ECFactoryUI.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 1/18/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Constants.h"
#import "ECGLWatch.h"

// ECFactoryUI is the UI for the factory top level (it has no NIB)
//    it also provides the default values for the ring slots and subdials

#define DEFAULT_ENVSLOT 16		// London

@class ECGeoNames;

@interface ECFactoryUI : UITableViewController {
    int		nSlots;			// number of slots to configure
    bool	constrainToZones;	// false -> allow any city in any slot; true -> allow only cities from a single zone
    int		firstEnvSlot;           // The envSlot index of the first slot in the ring
    ECGLWatch	*watch;                 // The watch this applies to
    ECGeoNames	*locDB;			//
}

- (ECFactoryUI *)initForWatch:(ECGLWatch *)watch withFirstEnvSlot:(int)envSlot numSlots:(int)numSlots constrainToZones:(bool)constrainToZones locDB:(ECGeoNames *)db;
+ (NSString *)timeZoneNameForWatch:(ECGLWatch *)watch env:(int)i;
+ (NSString *)cityNameForWatch:(ECGLWatch *)watch env:(int)i;
+ (double)latitudeForWatch:(ECGLWatch *)watch env:(int)i;
+ (double)longitudeForWatch:(ECGLWatch *)watch env:(int)i;
+ (void)saveDefaultsForWatch:(ECGLWatch *)watch env:(int)i city:(NSString *)city timeZone:(ESTimeZone *)tz latitude:(double)lat longitude:(double) lng;
+ (double)UTCSectorOffset;
+ (UIImageView *)littleMapForSlot:(int)slot;
+ (UITableViewCell *)tripleCell:(int)slot top:(NSString *)top bottom:(NSString *)bottom rightColor:(UIColor *)rightColor disclosure:(bool)disclosure replaceNotMap:(bool)replaceNotMap;
+ (void)ensureTZValidityForWatch:(ECGLWatch *)watch env:(int)i;

@end
