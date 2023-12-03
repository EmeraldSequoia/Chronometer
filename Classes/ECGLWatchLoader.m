//
//  ECGLWatchLoader
//  Emerald Chronometer
//
//  Created by Steven Pucci October 2008
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ECGLWatchLoader.h"
#import "ChronometerAppDelegate.h"
#import "ECWatchEnvironment.h"

#include <stdatomic.h>  // For atomic_thread_fence()

@implementation ECGLWatchLoader

static NSThread *thread = nil;
static bool stopThread = false;
static NSLock *requestLock = nil;  // I think we could do this with atomic operations instead of a lock but a lock is safer
static bool requestMade = false;
static bool willLookForRequest = false;
static bool paused = false;
static bool pauseWhenDone = false;

+ (void)timerFire:(NSTimer*)theTimer {
    assert(false);  // should have been invalidated when the run loop, with a smaller timeout, timed out
}

+ (void)threadBody:(id)arg {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    assert(![NSThread isMainThread]);
    assert([NSThread currentThread] == thread);

    [NSThread setThreadPriority:0.1];  // priorities range from 0.0 to 1.0, where 1 is highest

    // start run loop
    NSRunLoop *threadRunLoop = [NSRunLoop currentRunLoop];  // first time called in a thread creates it if necessary

    NSTimeInterval runLoopLifetime = 3600*24*30*12;  // that's a lot of seconds

    // Need to add something to the run loop or it will exit immediately
    [threadRunLoop addTimer:[NSTimer scheduledTimerWithTimeInterval:(runLoopLifetime * 2)
							     target:self
							   selector:@selector(timerFire:)
							   userInfo:nil
							    repeats:NO]
		    forMode:NSDefaultRunLoopMode];

    stopThread = false;

    do {
	[threadRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceReferenceDate:[NSDate timeIntervalSinceReferenceDate] + runLoopLifetime]];
    } while (!stopThread);

    assert(false);

    [pool release];
}

+ (void)checkForWorkInThread {
    assert(![NSThread isMainThread]);
    assert([NSThread currentThread] == thread);
    [requestLock lock];
    requestMade = false;
    willLookForRequest = true;
    [requestLock unlock];
    while (1) {
	[requestLock lock];
	if (paused) {
	    requestMade = false;
	    willLookForRequest = false;
	    [requestLock unlock];
	    break;
	}
	[requestLock unlock];
	[ECWatchEnvironment lockForBGTZAccess];
	if ([ChronometerAppDelegate doOneBackgroundLoad]) {
	    [ECWatchEnvironment unlockForBGTZAccess];
	} else {  // Don't think there's anything to do
	    [ECWatchEnvironment unlockForBGTZAccess];
	    [requestLock lock];
	    if (!requestMade) {
		willLookForRequest = false;
		[requestLock unlock];
		if (pauseWhenDone) {
		    paused = true;
		}
		break;
	    }
	    requestMade = false;
	    [requestLock unlock];
	}
    }
    // [ChronometerAppDelegate printMemoryUsage:@"------------ end of checkForWorkInThread"];
}

// Expected to be called in main thread only
+ (void)init {
    assert([NSThread isMainThread]);
    assert(!thread);
    thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadBody:) object:nil];
    [thread start];
    requestLock = [[NSLock alloc] init];
}

// Expected to be called in main thread only
+ (void)checkForWork {
    assert([NSThread isMainThread]);
    assert(thread);
    [requestLock lock];
    if (willLookForRequest) {
	requestMade = true;
	[requestLock unlock];
	return;
    } else {
	[requestLock unlock];
	[self performSelector:@selector(checkForWorkInThread) onThread:thread withObject:nil waitUntilDone:NO];
    }
}

+ (void)waitUntilPaused {
    assert(paused);
}

+ (void)pauseBG {
    assert([NSThread isMainThread]);
    assert(thread);
    paused = true;
    atomic_thread_fence(memory_order_seq_cst);
    [self performSelector:@selector(waitUntilPaused) onThread:thread withObject:nil waitUntilDone:YES];
}

+ (void)pauseBGWhenDone {
    assert([NSThread isMainThread]);
    assert(thread);
    pauseWhenDone = true;
    atomic_thread_fence(memory_order_seq_cst);
}

+ (void)resumeBG {
    assert([NSThread isMainThread]);
    assert(thread);
    paused = false;
    pauseWhenDone = false;
    atomic_thread_fence(memory_order_seq_cst);
    [self checkForWork];
}

@end
