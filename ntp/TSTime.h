//
//  TSTime.h
//  timestamp
//
//  Created by Steve Pucci on 5/2/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TSTimeAdjustmentObserver<NSObject>
- (void)notifyTimeAdjustment;
@end

@interface TSTime : NSObject {
}

// Public methods for clients
+ (NSTimeInterval)currentTime;       // For clients who want the time as accurately as possible
+ (NSTimeInterval)currentDateRTime;  // For clients who just want a consistent time base from app startup
+ (NSTimeInterval)skew;  // for currentTime, delta of NTP - [NSDate]
+ (NSTimeInterval)dateROffset; // for currentDateRTime, delta of RTime - [NSDate]
+ (NSTimeInterval)dateSkew;
+ (NSTimeInterval)dateRSkew;
+ (NSTimeInterval)ntpTimeForRDate:(NSTimeInterval)rDateTime;
+ (NSTimeInterval)rDateForNTPTime:(NSTimeInterval)ntpTime;
+ (float)currentTimeError;
+ (void)noteTimeAtPhase:(const char *)phaseName;
+ (void)noteTimeAtPhaseWithString:(NSString *)phaseName;
+ (void)printTimes:(NSString *)who;
+ (NSTimeInterval)dateForMediaTime:(NSTimeInterval)mediaTime;
+ (NSTimeInterval)mediaTimeForDate:(NSTimeInterval)dateTime;
+ (NSTimeInterval)timeUntilNextFractionalSecond:(double)fractionalSecond;
+ (void)resync;

// Debug
#ifndef NDEBUG
+ (void)reportAllSkewsAndOffset:(const char *)description;
#endif

// Public registration method to be informed when the sync changes
+ (void)addTimeAdjustmentObserver:(id<TSTimeAdjustmentObserver>)observer;  // for EC backward compatibility
+ (void)removeTimeAdjustmentObserver:(id)observer;
+ (void)registerSyncValueChangeCallbackForObserver:(id)observer callback:(SEL)callback callbackInMainThreadOnly:(bool)callbackInMainThreadOnly;
+ (void)registerSyncStatusChangeCallbackForObserver:(id)observer callback:(SEL)callback callbackInMainThreadOnly:(bool)callbackInMainThreadOnly;
+ (void)registerMediaTimeResetCallbackForObserver:(id)observer callback:(SEL)callback callbackInMainThreadOnly:(bool)callbackInMainThreadOnly;

// Methods to be called by app delegate
+ (void)startOfMainWithSignature:(const char*)fourByteAppSig;
+ (void)applicationSignificantTimeChange;
+ (void)goingToSleep;
+ (void)wakingUp;
+ (void)aboutToTerminate;

// Methods called by ntp internals
+ (void)gettimeofdayR:(struct timeval *)tv;
+ (void)setRSkew:(NSTimeInterval)newRSkew;
+ (void)notifySyncStatusChanged;

@end
