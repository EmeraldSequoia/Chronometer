//
//  ECIdleTimeQueue.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 6/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

@interface ECIdleTimeWorkUnit : NSObject {
@public
    double priority;  // Don't make a property out of this -- it needs to have fast access for sorting.
}

// Subclasses should reimplement this, returning whether they should be re-inserted into the queue, possibly
// at a different priority.
-(bool)run;

@end

// =====================================

@interface ECIdleTimeQueue : NSObject {
    NSMutableArray *units;
    CFRunLoopObserverRef observerRef;
}

-(id)init;

-(void)addWorkUnit:(ECIdleTimeWorkUnit *)workUnit;
-(void)removeWorkUnit:(ECIdleTimeWorkUnit *)workUnit;

+(ECIdleTimeQueue *)defaultQueue;

@end
