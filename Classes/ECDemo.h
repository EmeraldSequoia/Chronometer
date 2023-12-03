//
//  ECDemo.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 6/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#include "EBVirtualMachine.h"

@class ECDemoPhase, ECWatchTime;

@interface ECDemo : NSObject {
    NSMutableArray	  *phases;
    EBVMInstructionStream *firstAct, *lastAct;
    EBVirtualMachine	  *vm;
    NSTimer               *endTimer;
    ECWatchTime           *watchTime;
}

@property (nonatomic, assign) EBVMInstructionStream *firstAct, *lastAct;

-(id)initWithVM:(EBVirtualMachine *)vm;
-(void)addPhase:(ECDemoPhase *)phase;
-(void)runOnWatchTime:(ECWatchTime *)watchTime;
-(void)cancel;
-(bool)running;

@end

@interface ECDemoPhase : NSObject {
    NSDate         *startTime;
    NSTimeInterval duration;
    double         speed;
    NSTimer        *timer;
    NSString       *newWatchName;
}

@property(readonly, nonatomic) NSDate *startTime;
@property(readonly, nonatomic) NSTimeInterval duration;
@property(readonly, nonatomic) double speed;

-(id)initWithStartTime:(NSDate *)startTime
	 newWatchNamed:(NSString *)newWatchName
	      duration:(NSTimeInterval)duration
		 speed:(double)speed;

@end
