//
//  ECDynamicUpdate.h
//  Emerald Chronometer
//
//  Created by Steve Pucci Aug 2008
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

@class ECWatchTimeTrigger;
@class ECWatchEnvironment;
@class ECWatchTime;

@interface ECDynamicUpdate : NSObject {
}

// Note: This method returns the iPhone time (not the ECWatchTime time nor the NTP time)
// at which a part in the given watch, in the given environment, should be next updated,
// given the part's declared interval and intervalOffset.
+ (NSTimeInterval)getNextUpdateTimeForInterval:(double)interval
				     andOffset:(double)intervalOffset
				    startingAt:(NSTimeInterval)startTime
				forEnvironment:(ECWatchEnvironment *)environment
				     watchTime:(ECWatchTime *)watchTime;

@end

