//
//  ECAudio.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 1/24/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ECAudio : NSObject {
    
}

+ (void)ringOnce;
+ (void)startRinging;
+ (void)startSilentRinging;
+ (bool)stopRinging;
+ (void)stopRingingNow;
+ (void)ringAling;
+ (void)repeatRing:(void*)ignoreMe;
+ (void)repeatSilentRing:(void*)ignoreMe;
+ (void)cleanUp:(NSTimer*) ignoreMe;
+ (double)ringCount;
+ (bool)ringing;
+ (void)setup;
+ (void)setupSilentSounds;
+ (void)cancelSilentSounds;


@end
