//
//  ECIdleTimeQueue.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 6/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "ECIdleTimeQueue.h"

extern void
printDate(const char *description);

@implementation ECIdleTimeWorkUnit

// Subclasses need to reimplement this: true means re-insert in queue, possibly at different priority
-(bool)run {
    assert(false);
    return false;
}

@end

@interface ECIdleTimeTestWorkUnit : ECIdleTimeWorkUnit {
}

-(bool)run;

@end

@implementation ECIdleTimeTestWorkUnit

-(bool)run {
    printf("Test work unit\n");
    return false;
}

@end

@implementation ECIdleTimeQueue

-(void)addWorkUnit:(ECIdleTimeWorkUnit *)workUnit {
    int firstUnitGreaterOrEqual = 0;
    for (ECIdleTimeWorkUnit *u in units) {
	if (workUnit->priority >= u->priority) {
	    break;
	}
	firstUnitGreaterOrEqual++;
    }
    [units insertObject:workUnit atIndex:firstUnitGreaterOrEqual];
}

-(void)removeWorkUnit:(ECIdleTimeWorkUnit *)workUnit {
    [units removeObject:workUnit];
}

-(void)dummyTrigger:(NSTimer *)theTimer {
    // Do nothing; the aim of this trigger is to force the idle observer callback to be called again
    // printDate("DummyTimer fire");
}

-(void)runLoopObserverCallback {
    // If anything in the queue
    if ([units count]) {
	// last item in array is the one we want (avoids moving the entire array on each removal)
	ECIdleTimeWorkUnit *lastUnit = [[units lastObject] retain];
	[units removeLastObject];
	if ([lastUnit run]) {
	    [self addWorkUnit:lastUnit];
	}
	if ([units count]) {
	    // printDate("IdleTimeQueue Scheduling a dummy timer because of pending unit\n");
	    [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(dummyTrigger:) userInfo:nil repeats:NO];
	}
	[lastUnit release];
    }
}

static void runLoopObserverCallback(CFRunLoopObserverRef observer,
				    CFRunLoopActivity    activity,
				    void                 *info) {
    // printDate("runLoopObserverCallback");
    [(ECIdleTimeQueue *)info runLoopObserverCallback];
}

-(id)init {
    [super init];
    units = [[NSMutableArray alloc] initWithCapacity:50];
    CFRunLoopObserverContext observerContext;
    observerContext.version = 0;
    observerContext.info = self;
    observerContext.retain = NULL;
    observerContext.release = NULL;
    observerContext.copyDescription = NULL;
    observerRef = CFRunLoopObserverCreate(kCFAllocatorDefault,
					  kCFRunLoopBeforeWaiting,
					  YES/*repeats*/,
					  0/*order*/,
					  runLoopObserverCallback,
					  &observerContext);
    CFRunLoopAddObserver([[NSRunLoop currentRunLoop] getCFRunLoop], observerRef, /*kCFRunLoopCommonModes*/ kCFRunLoopDefaultMode);
    return self;
}

-(void)dealloc {
    [units removeAllObjects];
    [units release];
    CFRunLoopRemoveObserver([[NSRunLoop currentRunLoop] getCFRunLoop], observerRef, /*kCFRunLoopCommonModes*/ kCFRunLoopDefaultMode);
    [super dealloc];
}

static ECIdleTimeQueue *defaultQueue = NULL;

+(ECIdleTimeQueue *)defaultQueue {
    if (!defaultQueue) {
	defaultQueue = [[ECIdleTimeQueue alloc] init];
    }
    return defaultQueue;
}

@end
