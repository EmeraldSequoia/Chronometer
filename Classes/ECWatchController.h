//
//  ECWatchController.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/15/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ECWatch.h"

@class ECPartController, ECWatch;

@interface ECWatchController : NSObject {
    ECWatch *watch;			// the model we're controlling
    bool audibleTicks;			// make annoying ticking sounds
    bool audibleSWTicks;		// play stopwatch ticks
    bool audibleChimes;			// play tunes
    bool reallyLoaded;                  // we've actually read and used the xml file
    NSMutableArray *subControllers;	// that do the real work
    int faceWidth;  // Dimension in xml that represents the width of the face itself (used for watch devices)
    int statusBarLocation;              // Android status bar location
    CGSize expectedFrontAtlasSize;
    CGSize expectedBackAtlasSize;
    CGSize expectedNightAtlasSize;
    NSString *name;
}

@property (retain, nonatomic) ECWatch *watch;
@property (readonly, nonatomic) NSString *name;
@property (nonatomic) bool reallyLoaded;
@property (readonly) bool audibleTicks, audibleChimes, audibleSWTicks;
@property (nonatomic) int faceWidth, statusBarLocation;

//// initialization
- (ECWatchController *)initWithName:(NSString *)aName;
- (int)addSubController: (ECPartController *)sub;
- (void)setExpectedFrontAtlasSize:(CGSize)expectedFrontAtlasSize
		    backAtlasSize:(CGSize)expectedBackAtlasSize
		   nightAtlasSize:(CGSize)expectedNightAtlasSize;

//// public utility methods
- (void)archiveAll;

@end
