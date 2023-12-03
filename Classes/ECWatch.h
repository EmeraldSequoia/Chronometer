//
//  ECWatch.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/18/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "Constants.h"
#import <UIKit/UIKit.h>

@class EBVirtualMachine, ECWatchPart, ECWatchButton, EBVMInstructionStream;


@interface ECWatch : NSObject {
    NSString *name;				// identifies this watch externally
    ECWatchModeMask mode;				// which mode we're currently in
    ECWatchModeMask definedModes;			// modes defined for this watch
    NSMutableArray *parts;			// {ECWatchVisualItem *} bands, cases, dials, and hands of all sorts
    NSMutableArray *chimes;			// {ECWatchAudioItem *} bells and whistles
    NSMutableArray *buttons;			// {ECWatchItem *} no audio/visuals just actions
    EBVirtualMachine *vm;			// shared by all the parts of this watch
    NSMutableArray *inits;                      // For Henry: an array (in order) of all the inits encountered in the xml file
    CGPoint center;                             // offset of logical center of watch when rotating view
    int numEnvironments;                        // number of environments (location managers, astro managers) in this watch
    int maxSeparateLoc;                         // maximum slot number which has a separate (unique) location and astro manager; others share slot 0's
    int beatsPerSecond;                         // times on this watch will be rounded to the nearest 1/beatsPerSecond second to model a physical watch with that frequency
    double landscapeZoomFactor;                 // In single-watch (nongrid) view, amount by which we scale this watch relative to other watches
}

@property (nonatomic, retain) NSString *name;
@property (readonly, nonatomic, retain) EBVirtualMachine *vm;
@property (nonatomic) ECWatchModeMask mode;
@property (readonly, nonatomic) ECWatchModeMask definedModes;
@property (nonatomic) CGPoint center;
@property (readonly, nonatomic) NSArray *inits;
@property (nonatomic) int numEnvironments, maxSeparateLoc, beatsPerSecond;
@property (nonatomic) double landscapeZoomFactor;

+ (NSString *)defaultModeName;

- (ECWatch *)initWithName:(NSString *)name VMOwner:(id)VMOwner;
- (void)addPart:(ECWatchPart *)part;
- (void)addChime:(ECWatchPart *)chime;
- (void)addButton:(ECWatchButton *)item;
- (void)addInit:(EBVMInstructionStream *)init;
- (void)setCenterX:(CGFloat)x y:(CGFloat)y;

- (const char *)description;
@end
