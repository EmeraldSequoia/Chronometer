//
//  ECDemo.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 6/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "ECQView.h"
#import "ECDemo.h"
#import "ECWatchTime.h"
#import "ECErrorReporter.h"
#import "ECWatchController.h"
#import "ChronometerAppDelegate.h"

@class EBVirtualMachine;

@implementation ECDemoPhase

@synthesize startTime, duration, speed;

-(id)initWithStartTime:(NSDate *)aStartTime
	 newWatchNamed:(NSString *)aNewWatchName
	      duration:(NSTimeInterval)aDuration
		 speed:(double)aSpeed {
    [super init];
#if 0
    if (aNewWatchName) {
	if ([ChronometerAppDelegate controllerForWatchNamed:newWatchName] == nil) {
	    [[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"No watch named %@ in demo", newWatchName]];
	    newWatchName = nil;
	} else {
	    newWatchName = [aNewWatchName retain];
	}
    } else {
	newWatchName = nil;
    }
    startTime = [aStartTime retain];
    duration = aDuration;
    speed = aSpeed;
    timer = nil;
#endif
    return self;
}

-(void)dealloc {
    [startTime release];
    [newWatchName release];
    [timer invalidate];
    [super dealloc];
}

-(void)fireImmediatelyForWatchTime:(ECWatchTime *)watchTime {
#if 0
    if (newWatchName) {
	ECWatchController *newWatchController = [ChronometerAppDelegate controllerForWatchNamed:newWatchName];
	if (newWatchController) {
	    [watchTime resetToLocal];
	    watchTime = [newWatchController mainTime];
	    [ChronometerAppDelegate switchToWatchNamed:newWatchName];
	}
    }
    [watchTime setCurrentDate:startTime withWarp:speed];
#endif
}

-(void)timerFire:(NSTimer *)theTimer {
    timer = nil;
    [self fireImmediatelyForWatchTime:(ECWatchTime *)[theTimer userInfo]];
}

-(void)setupTimerForWatchTime:(ECWatchTime *)watchTime toFireAt:(NSTimeInterval)interval {
    timer = [NSTimer timerWithTimeInterval:interval
				    target:self
				  selector:@selector(timerFire:)
				  userInfo:watchTime
				   repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

-(void)cancelTimer {
    [timer invalidate];
    timer = nil;
}

@end

@implementation ECDemo

@synthesize firstAct, lastAct;

-(id)initWithVM:(EBVirtualMachine *)aVM {
    if (self = [super init]) {
	vm = aVM;
	endTimer = nil;
	watchTime = nil;
	phases = [[NSMutableArray alloc] initWithCapacity:10];
    }
    return self;
}

-(void)dealloc {
    [self cancel];
    [phases removeAllObjects];
    [phases release];
    [firstAct release];
    [lastAct release];
    [endTimer invalidate];
    [super dealloc];
}

-(void)addPhase:(ECDemoPhase *)phase {
    [phases addObject:phase];
    [phase release];  // the array will have retained it
}

-(void)endActionForWatchTime:(ECWatchTime *)aWatchTime {
    endTimer = nil;
    [aWatchTime resetToLocal];
    if (lastAct) {
	[vm evaluateInstructionStream:lastAct errorReporter:[ECErrorReporter theErrorReporter]];
    }
    watchTime = nil;
}

-(void)demoDoneTimerFire:(NSTimer *)theTimer {
    [self endActionForWatchTime:[theTimer userInfo]];
}

-(void)runOnWatchTime:(ECWatchTime *)aWatchTime {
    watchTime = aWatchTime;
    if (firstAct) {
	[vm evaluateInstructionStream:firstAct errorReporter:[ECErrorReporter theErrorReporter]];
    }

    NSTimeInterval accumulatedTime = 0;
    for (ECDemoPhase *phase in phases) {
	if (accumulatedTime == 0) {
	    [phase fireImmediatelyForWatchTime:watchTime];
	} else {
	    [phase setupTimerForWatchTime:watchTime
				 toFireAt:accumulatedTime];
	}
	accumulatedTime += [phase duration];
    }
    endTimer = [NSTimer timerWithTimeInterval:accumulatedTime
				       target:self
				     selector:@selector(demoDoneTimerFire:)
				     userInfo:watchTime
				      repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:endTimer forMode:NSDefaultRunLoopMode];
}

-(void)cancel {
    if (endTimer) {
	[endTimer invalidate];
	endTimer = nil;
	for (ECDemoPhase *phase in phases) {
	    [phase cancelTimer];
	}
	[self endActionForWatchTime:watchTime];
    }
}

-(bool)running {
    return (endTimer != nil);
}

@end

