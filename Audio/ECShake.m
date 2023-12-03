//
//  ECShake.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 2/5/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import "ECShake.h"

#define kFilteringFactor 0.1
#define kShakeThreshold 1.5

static ECShake *shaker = nil;
static CMMotionManager *motionMgr = nil;

@implementation ECShake

@synthesize cbObj, sel;

+ (void)initialize {
    assert(!shaker);
    shaker = [[ECShake alloc] init];
    motionMgr = [[CMMotionManager alloc] init];
}

- (ECShake *)init {
    if (self=[super init]) {
	accelX = accelY = accelZ = 0;
	cbObj = nil;
	sel = nil;
    }
    return self;
}

+ (void)setupShakeCallBack:(id)obj selector:(SEL)sel {
    assert(shaker);
    assert(shaker.cbObj == nil);	// one at a time
    shaker.cbObj = obj;
    shaker.sel = sel;
    
     // Configure and start the accelerometer
    assert(motionMgr);
    motionMgr.accelerometerUpdateInterval = (1.0 / 100);
    [motionMgr startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
        if (error) {
            NSLog(@"Accelerometer update error: %@", [error localizedDescription]);
            return;
        }
        [shaker didAccelerateWithData:accelerometerData];
    }];
}

+ (void)cancelCallBack {
    [shaker shutdown];
    shaker.cbObj = nil;
    shaker.sel = nil;
}

// Delegate method, called when the device accelerates.
- (void)didAccelerateWithData:(CMAccelerometerData *)accelerationData {
    double length, x, y, z;
    CMAcceleration acceleration = accelerationData.acceleration;
    
#if 0
    //Use a basic high-pass filter to remove the influence of the gravity
    accelX = acceleration.x * kFilteringFactor + accelX * (1.0 - kFilteringFactor);
    accelY = acceleration.y * kFilteringFactor + accelY * (1.0 - kFilteringFactor);
    accelZ = acceleration.z * kFilteringFactor + accelZ * (1.0 - kFilteringFactor);
    // Compute values for the three axes of the acceleromater
    x = acceleration.x - accelX;
    y = acceleration.y - accelY;
    z = acceleration.z - accelZ;
    //Compute the intensity of the current acceleration 
    length = sqrt(x * x + y * y + z * z);
#else
    x = acceleration.x;
    y = acceleration.y;
    z = acceleration.z;
    
    length = sqrt(x * x + y * y + z * z) - 1.0;
#endif

    // If above the threshold then perform the call back
    if (length >= kShakeThreshold) {
	//printf("shaken!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
	[cbObj performSelectorOnMainThread:sel withObject:nil waitUntilDone:YES];
    }
}

- (void)shutdown {
    [motionMgr stopAccelerometerUpdates];
}

@end
