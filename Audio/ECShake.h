//
//  ECShake.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 2/5/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>


@interface ECShake : NSObject {
    id	    cbObj;	    // object to notify
    SEL	    sel;	    // selector to call
    
    double  accelX, accelY, accelZ;
}

@property (readwrite, retain) id cbObj;
@property (readwrite) SEL sel;

+ (void)setupShakeCallBack:(id)obj selector:(SEL)sel;
+ (void)cancelCallBack;

- (void)didAccelerateWithData:(CMAccelerometerData *)acceleration;
- (void)shutdown;

@end
