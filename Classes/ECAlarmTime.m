//
//  ECAlarmTime.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 1/2009.
//  Copyright Emerald Sequoia LLC 2009. All rights reserved.
//

#import "ECAlarmTime.h"
#import "ECWatchTime.h"
#import "ECWatchEnvironment.h"
#import "ECGlobals.h"
#import "ECAppLog.h"
#import "ESCalendar.h"
#import "ChronometerAppDelegate.h"
#import "TSTime.h"
#import "UserNotifications/UserNotifications.h"

#ifndef NDEBUG
extern void printADate(NSTimeInterval dt);
#endif

@interface ECAlarmTime (ECAlarmTimePrivate)

- (void)recalculateAlarm;
- (void)addToSet;
- (void)removeFromSet;
- (void)removeExistingLocalNotificationsForThisWatch;

@end

static NSMutableSet *alarmTimes = nil;
static NSLock *alarmTimesSetLock = nil;

@implementation ECAlarmTime

@synthesize specifiedMode, specifiedOffset;

- (id)initWithFireReceiver:(id)receiver fireSelector:(SEL)aFireSelector fireUserInfo:(id)aFireUserInfo currentWatchTime:(ECWatchTime *)aWatchTime env:(ECWatchEnvironment *)anEnv {
    [super init];
    fireReceiver = receiver;
    fireSelector = aFireSelector;
    fireUserInfo = aFireUserInfo;
    currentWatchTime = aWatchTime;
    env = anEnv;
    specifiedMode = ECAlarmTimeTarget;
    specifiedOffset = 0;  // midnight
    osTimer = nil;
    alarmWatchTime = [[ECWatchTime alloc] init];
    [self addToSet];
    localNotificationIdentifier = nil;
    [self removeExistingLocalNotificationsForThisWatch];
    [self recalculateAlarm];
    [TSTime registerMediaTimeResetCallbackForObserver:self callback:@selector(mediaTimeReset) callbackInMainThreadOnly:YES];
    return self;
}

- (void)dealloc {
    [osTimer invalidate];
    [alarmWatchTime release];
    [self removeFromSet];
    [super dealloc];
}

- (NSString *)displayName { // Fake out compiler
    assert(false);
    return @"";
}

- (bool)timerIsStopped {
    assert(specifiedMode == ECAlarmTimeInterval);
    if (alarmWatchTime) {
	return [alarmWatchTime isStopped];
    }
    return false;
}

- (NSTimeInterval)currentAlarmTime {    // In NTP time base
    if (alarmWatchTime) {
	if (specifiedMode == ECAlarmTimeInterval) {
	    NSTimeInterval rTime = [alarmWatchTime currentTime];
	    return [TSTime ntpTimeForRDate:rTime];
	} else {
	    return [alarmWatchTime currentTime];
	}
    }
    return 0;
}

// Return the one and only local notification identifer for this watch.  This identifier is reused indefinitely, which allows
// us to more easily maintain one and only one local notification (at most) per watch.
- (NSString *)localNotificationIdentifer {
    return [fireReceiver displayName];
}

// N.B.: The notifications are *not* removed upon completion of this method, but are delayed by two asynchronous thread calls
// (the completion handler for getting the pending notifications, and a second async call from that handler to actually remove
// the notifications.  There's a potential *third* delay for executing *this* method on the main thread, if the caller is not
// the main thread.
- (void)removeExistingLocalNotificationsForThisWatch {
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(removeExistingLocalNotificationsForThisWatch) withObject:nil waitUntilDone:NO];
        return;
    }
    NSString *watchName = [fireReceiver displayName];

    UNUserNotificationCenter *notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
    NSMutableArray<NSString *>* identifiersToRemove = [[NSMutableArray alloc] init];
    // printf("Scheduling new-style removal for %s\n", [watchName UTF8String]);
    [notificationCenter getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
            // printf("Executing new-style removal for %s\n", [watchName UTF8String]);
            //bool foundOne = false;
            for (UNNotificationRequest *request in requests) {
                NSDictionary *userInfo = request.content.userInfo;
                NSString *notificationWatchName = [userInfo objectForKey:@"watch"];
                if (!notificationWatchName) {
                    printf("Found local notification through new API with no watch name, removing\n");
                    [identifiersToRemove addObject:request.identifier];
                } else if ([watchName compare:notificationWatchName] == NSOrderedSame) {
                    //foundOne = true;
                    // printf("Found existing local notification through new API for watch %s, removing\n", [watchName UTF8String]);
                    [identifiersToRemove addObject:request.identifier];
                }
            }
            //if (!foundOne) {
            //    printf("No existing local notification for watch %s\n", [watchName UTF8String]);
            //}
            // Note: the following method executes asynchronously and is not complete even after the completion of this
            // callback.
            [notificationCenter removePendingNotificationRequestsWithIdentifiers:identifiersToRemove];
        }];
}

- (void)addToSet {
    if (!alarmTimes) {
	assert(alarmTimesSetLock == nil);
	alarmTimesSetLock = [[NSLock alloc] init];
	[alarmTimesSetLock lock];
	alarmTimes = [[NSMutableSet alloc] initWithCapacity:2];
    } else {
	[alarmTimesSetLock lock];
    }
    [alarmTimes addObject:self];
    [alarmTimesSetLock unlock];
    [TSTime addTimeAdjustmentObserver:self];
}

- (void)removeFromSet {
    assert(alarmTimes);
    assert(alarmTimesSetLock);
    [TSTime removeTimeAdjustmentObserver:self];
    [alarmTimesSetLock lock];
    [alarmTimes removeObject:self];
    [alarmTimesSetLock unlock];
}

- (void)recalculateTargetTime {
    assert(specifiedMode == ECAlarmTimeTarget);
    // Break out offset from midnight into HH, MM, SS, sssss
    assert(specifiedOffset >= 0);
    assert(specifiedOffset <= 3600 * 24);
    unsigned int integerOffset = (unsigned int) floor(specifiedOffset);
    double fractionalSeconds = specifiedOffset - integerOffset;
    unsigned int alarmSeconds = integerOffset % 60;
    unsigned int alarmMinutes = integerOffset / 60;
    unsigned int alarmHours = alarmMinutes / 60;
    alarmMinutes = alarmMinutes % 60;
    assert(alarmHours >= 0 && alarmHours <= 23);
    assert(alarmMinutes >= 0 && alarmMinutes <= 59);
    assert(alarmSeconds >= 0 && alarmSeconds <= 59);

    // Find alarm time today.  See if we passed it yet.
    ESTimeZone *estz = [env estz];
    NSTimeInterval now = [currentWatchTime currentTime];
    ESDateComponents csNow;
    ESCalendar_localDateComponentsFromTimeInterval(now, estz, &csNow);
    csNow.hour = alarmHours;
    csNow.minute = alarmMinutes;
    csNow.seconds = alarmSeconds + fractionalSeconds;
    NSTimeInterval alarmInterval = ESCalendar_timeIntervalFromLocalDateComponents(estz, &csNow);

    // Are we passed today's alarm time?
    if (now > alarmInterval) {
	// Find tomorrow at this time:
	NSTimeInterval alarmTomorrow = ESCalendar_addDaysToTimeInterval(alarmInterval, estz, 1);
	alarmInterval = alarmTomorrow;
    }
    [alarmWatchTime setToFrozenDateInterval:(alarmInterval + fractionalSeconds)];
#ifndef NDEBUG
//    printf("Setting alarmWatchTime to frozen interval "); printADate(alarmInterval + fractionalSeconds); printf("\n");
#endif
    [self recalculateAlarm];
}

- (void)recalculateIntervalTime {
    assert(specifiedMode == ECAlarmTimeInterval);
    //printf("Requesting interval offset of %.2f\n", specifiedOffset);
    [alarmWatchTime makeTimeIdenticalToOtherTimer:currentWatchTime plusDelta:specifiedOffset];
    [alarmWatchTime start];
#ifndef NDEBUG
//    printf("Setting alarmWatchTime to moving interval "); printADate([alarmWatchTime currentTime]); printf("\n");
#endif
    [self recalculateAlarm];
}

- (void)recalculateTime {
    if (specifiedMode == ECAlarmTimeTarget) {
	// Recalculate for tomorrow
	[self recalculateTargetTime];
    } else {
	// Reset to original specified interval
	[self recalculateIntervalTime];
    }
}

+ (ECWatchTime *)defaultAlarmTimeForTime:(ECWatchTime *)currentTime usingEnv:(ECWatchEnvironment *)env {
    ESTimeZone *estz = [env estz];

    // Find tomorrow at this time:
    NSTimeInterval now = [currentTime currentTime];
    NSTimeInterval tomorrowAtThisTime = ESCalendar_addDaysToTimeInterval(now, estz, 1);
    ESDateComponents cs;
    ESCalendar_localDateComponentsFromTimeInterval(tomorrowAtThisTime, estz, &cs);
    cs.hour = 0;
    cs.minute = 0;
    cs.seconds = 0;
    NSTimeInterval targetTime = ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
    return [[[ECWatchTime alloc] initWithFrozenDateInterval:targetTime] autorelease];
}

- (void)specifyTargetAlarmAt:(double)logicalSecondsFromLocalMidnight {
    specifiedMode = ECAlarmTimeTarget;
    [alarmWatchTime setUseSmoothTime:false];
    specifiedOffset = logicalSecondsFromLocalMidnight;
    if (specifiedOffset < 0 || specifiedOffset >= 3600 * 24) {
	specifiedOffset = 0;
    }
    [self recalculateTargetTime];
}

- (void)specifyIntervalAlarmAt:(double)intervalSeconds {
    specifiedMode = ECAlarmTimeInterval;
    [alarmWatchTime setUseSmoothTime:true];
    specifiedOffset = intervalSeconds;
    [self recalculateIntervalTime];
}

- (double)effectiveOffset {
    double offset = EC_fmod([alarmWatchTime offsetFromOtherTimer:currentWatchTime], ECIntervalAlarmWrap);
    return offset;
}

- (void)setSpecifiedModeToTarget {
    if (specifiedMode != ECAlarmTimeTarget) {
	assert(specifiedMode == ECAlarmTimeInterval);
	specifiedMode = ECAlarmTimeTarget;
	[alarmWatchTime stop];
	[alarmWatchTime setUseSmoothTime:false];
	specifiedOffset = [alarmWatchTime hour24ValueUsingEnv:env];
	[self recalculateTargetTime];
    }
}
- (void)setSpecifiedModeToInterval {
    if (specifiedMode != ECAlarmTimeInterval) {
	assert(specifiedMode == ECAlarmTimeTarget);
	specifiedMode = ECAlarmTimeInterval;
	[alarmWatchTime setUseSmoothTime:true];
	[alarmWatchTime start];
	specifiedOffset = EC_fmod([alarmWatchTime currentTime] - [currentWatchTime currentTime], 24 * 3600);
	[self recalculateIntervalTime];
    }
}

- (void)startTimer {
    assert(specifiedMode == ECAlarmTimeInterval);  // there's not really any reason we couldn't do this, but it doesn't seem to make sense...
    //[alarmWatchTime setUseSmoothTime:true];  // This is bogus where it sits, because it will change the displayed interval before starting the timer, and smooth time doesn't apply to stopped ECWatchTimes anyway
    [alarmWatchTime stop];  // when the target time is fixed, the derived interval will count down...
    [self recalculateAlarm];
}

- (void)stopTimer {
    assert(specifiedMode == ECAlarmTimeInterval);  // there's not really any reason we couldn't do this, but it doesn't seem to make sense...
    [alarmWatchTime start];  // when the target time is moving, the derived interval will stay fixed...
    //[alarmWatchTime setUseSmoothTime:false];  // Bogus where it sits (see above)
    [self recalculateAlarm];
}

- (void)stopTimerIfInterval {
    if (specifiedMode == ECAlarmTimeInterval) {
	[alarmWatchTime start];  // when the target time is moving, the derived interval will stay fixed...
	[self recalculateAlarm];
    }
}

- (void)toggleTimer {
    if ([alarmWatchTime isStopped]) {
	[self stopTimer];
    } else {
	[self startTimer];
    }
}

- (bool)setToFire {
    if (specifiedMode == ECAlarmTimeInterval) {
	return [alarmWatchTime isStopped];
    }
    return true;	    // target alarms are always running
}

- (bool)defaultsStartTimerWithTargetTime:(double)targetTime {
    if ([currentWatchTime currentTime] >= targetTime) {
	//printf("defaultsStartTimerWithTargetTime says alarm time for %s passed\n", [[fireReceiver name] UTF8String]);
	//printf("... currentAlarmTime is "); printADate([self currentAlarmTime]); printf(", targetTime is "); printADate(targetTime); printf("\n");
	[self recalculateIntervalTime];
	return true;
    } else {
	[alarmWatchTime setToFrozenDateInterval:[TSTime rDateForNTPTime:targetTime]];
	[self recalculateAlarm];
	return false;
    }
}

- (void)defaultsSetCurrentInterval:(double)timerOffset {
    assert(specifiedMode == ECAlarmTimeInterval);
    [alarmWatchTime makeTimeIdenticalToOtherTimer:currentWatchTime plusDelta:timerOffset];
    [self recalculateAlarm];
}

- (void)timerFire:(NSTimer *)theTimer {
#ifndef NDEBUG
    [ECAppLog log:[NSString stringWithFormat:@"timerFire"]];
#endif
    [self recalculateTime];
    [fireReceiver performSelector:fireSelector withObject:fireUserInfo];
}

// Several cases here.  But note that the indicated time of alarmWatchTime will never change.  The question is whether we have passed that indicated time.
// The main thing we need to do is just invalidate and recalculate the alarm based on the new position.  That is always the right thing to do.
// In addition, if we "missed" an alarm because we just moved past the target time in recalculating, then we also need to fire it.
- (void)notifyTimeAdjustment {
    [ECAppLog log:[NSString stringWithFormat:@"notifyTimeAdjustment"]];
    if (osTimer) {
	assert([alarmWatchTime isStopped]);
	if ([self currentAlarmTime] < [currentWatchTime currentTime]) {  // The indicated time is now past the target time
	    [osTimer invalidate];
	    osTimer = nil;
            // LocalNotifications are always removed in [self recalculateAlarm], *always* called indirectly by [self recalculateTime]
#ifndef NDEBUG
	    printf("Firing timer because time skewed past target\n");
#endif
	    [self timerFire:nil];  // calls [self recalculateTime]
	} else {
            //printf("Not past, recalculate\n");
	    [self recalculateAlarm];
	}
    }
}

- (void)mediaTimeReset {
    // Strictly speaking, we don't care about media time.  BUT:  When media time has been reset, it *can* mean our timers are screwed up.
    // This is intended to fix a problem discovered in May 2012 where, when returning from the background with NTP disabled, nobody was
    // informing us that the NSTimer was potentially going to be delayed because of the time spent in the background.
    [ECAppLog log:[NSString stringWithFormat:@"-[ECAlarmTime mediaTimeReset]"]];
    [self notifyTimeAdjustment];
}

- (bool)alarmEnabled { // Fake out compiler
    assert(false);
    return false;
}

-(void)replaceLocalNotificationGlue:(NSDictionary *)paramDict {
    [self replaceLocalNotificationWithContent:paramDict[@"content"] trigger:paramDict[@"trigger"]];
}

// Note [steve 2019/12/23]: UNNotificationRequest now takes care of this replicated notification issue, by using the identifier to
// make sure there's only one copy of the notification with the same identifier.  We still make sure we execute on the main thread
// to avoid race issues with our *own* logic.
-(void) replaceLocalNotificationWithContent:(UNNotificationContent *)content trigger:(UNNotificationTrigger *)trigger {
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(replaceLocalNotificationGlue:) 
                               withObject:[[NSDictionary alloc] 
                                              initWithObjectsAndKeys:content, @"content", trigger, @"trigger", nil] 
                            waitUntilDone:NO];
        return;
    }
    UNUserNotificationCenter *notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
    if (content) {
        assert(trigger);
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[self localNotificationIdentifer]
                                                                              content:content
                                                                              trigger:trigger];
        [notificationCenter addNotificationRequest:request withCompletionHandler:^(NSError *error) {
                if (error) {
                    printf("Error adding notification request:\n%s\n", [error.localizedDescription UTF8String]);
                }
            }];
    } else {
        assert(!trigger);
        [notificationCenter removePendingNotificationRequestsWithIdentifiers:@[[self localNotificationIdentifer]]];
    }
}

- (void)recalculateAlarm {
    if (osTimer) {
	[osTimer invalidate];
	osTimer = nil;
    }
    UNMutableNotificationContent *newLocalNotificationContent = nil;
    UNNotificationTrigger *newLocalNotificationTrigger = nil;
    // If we ever allow warps other than 1.0 and 0.0, then the following code will need to change...
    if ([alarmWatchTime isStopped]) {  // If the alarm time is stopped, then we need to set the osTimer; otherwise there's nothing to do...
	NSTimeInterval watchTimeTimeOfAlarm = [self currentAlarmTime];  // NTP
	NSTimeInterval iPhoneTimeOfAlarm = watchTimeTimeOfAlarm - [TSTime skew];
	NSTimeInterval deltaT = iPhoneTimeOfAlarm - [NSDate timeIntervalSinceReferenceDate];
#ifndef NDEBUG
	//printf("\niPhoneTimeOfAlarm: "); printADate(iPhoneTimeOfAlarm); printf(" alarm at "); printADate([self currentAlarmTime]);
	//double now = [NSDate timeIntervalSinceReferenceDate];
	//printf("\niPhoneTime:        "); printADate(now); printf("   now is "); printADate(now + [TSTime skew]);
	//printf("\ndeltaT: %.1f\n", deltaT);
#endif
	if (deltaT > 0) {
	    osTimer = [NSTimer scheduledTimerWithTimeInterval:deltaT
						       target:self
						     selector:@selector(timerFire:)
						     userInfo:nil
						      repeats:NO];
            //printf("Setting osTimer alarmEnabled %s\n", [fireReceiver alarmEnabled] ? "YES" : "NO");
	    if ([fireReceiver alarmEnabled]) {  // Don't set local notify if alarm is disabled in ECGLWatch
		NSTimeInterval fireDateInterval = iPhoneTimeOfAlarm;
		if (specifiedMode == ECAlarmTimeTarget) {
                    ESDateComponents esDateComponents;
                    ESCalendar_localDateComponentsFromTimeInterval(fireDateInterval, env.estz, &esDateComponents);
#ifdef ESCALENDAR_NS
                    NSDateComponents *nsDateComponents = [[[NSDateComponents alloc] init] autorelease];
                    nsDateComponents.timeZone = ESCalendar_nsTimeZone(env.estz);
                    nsDateComponents.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
                    nsDateComponents.hour = esDateComponents.hour;
                    nsDateComponents.minute = esDateComponents.minute;
                    nsDateComponents.second = (int)floor(esDateComponents.seconds);
                    nsDateComponents.nanosecond = (int)floor((esDateComponents.seconds - nsDateComponents.second) * 1000000000);
                    newLocalNotificationTrigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:nsDateComponents 
                                                                                                           repeats:YES];
#else
# error Need NSCalendar for new implementation of ECAlarmTime
#endif
		} else {
                    newLocalNotificationTrigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:deltaT repeats:NO];
		}
                newLocalNotificationContent = [[[UNMutableNotificationContent alloc] init] autorelease];
                newLocalNotificationContent.body = [NSString stringWithFormat:@"The alarm on %@ has gone off!", 
                                                             [fireReceiver displayName]];
		NSString *displayName = [fireReceiver displayName];
		newLocalNotificationContent.userInfo = [NSDictionary dictionaryWithObject:displayName forKey:@"watch"];
		newLocalNotificationContent.sound = [UNNotificationSound soundNamed:@"Triangle20.wav"];
	    }
	}
    }
    [self replaceLocalNotificationWithContent:newLocalNotificationContent trigger:newLocalNotificationTrigger];
}

- (void)handleTZChange {
    if (specifiedMode == ECAlarmTimeTarget) {
	[self recalculateTargetTime];
    }
    [env clearCache];
}

- (void)advanceAlarmHour {
    if (specifiedMode != ECAlarmTimeTarget) {
	[self setSpecifiedModeToTarget];
    }
    specifiedOffset = floor(specifiedOffset / 60) * 60;
    specifiedOffset += 3600;
    if (specifiedOffset >= 24 * 3600) {
	specifiedOffset -= (24 * 3600);
    }
    [self recalculateTargetTime];
}

- (void)advanceAlarmMinute {
    if (specifiedMode != ECAlarmTimeTarget) {
	[self setSpecifiedModeToTarget];
    }
    specifiedOffset = floor(specifiedOffset / 60) * 60;
    specifiedOffset += 60;
    if (specifiedOffset >= 24 * 3600) {
	specifiedOffset -= (24 * 3600);
    }
    [self recalculateTargetTime];
}

- (void)toggleAlarmAMPM {
    if (specifiedMode != ECAlarmTimeTarget) {
	[self setSpecifiedModeToTarget];
    }
    specifiedOffset = floor(specifiedOffset / 60) * 60;
    specifiedOffset += (12 * 3600);
    if (specifiedOffset >= 24 * 3600) {
	specifiedOffset -= (24 * 3600);
    }
    [self recalculateTargetTime];
}

- (void)advanceIntervalHour {
    if (specifiedMode != ECAlarmTimeInterval) {
	[self setSpecifiedModeToInterval];
    }
    specifiedOffset = floor(specifiedOffset);
    specifiedOffset += 3600;
    if (specifiedOffset >= 24 * 3600) {
	specifiedOffset -= (24 * 3600);
    }
    [self recalculateIntervalTime];
}

- (void)advanceIntervalMinute {
    if (specifiedMode != ECAlarmTimeInterval) {
	[self setSpecifiedModeToInterval];
    }
    specifiedOffset = floor(specifiedOffset);
    specifiedOffset += 60;
    if (specifiedOffset >= 24 * 3600) {
	specifiedOffset -= (24 * 3600);
    }
    [self recalculateIntervalTime];
}

- (void)advanceIntervalSecond {
    if (specifiedMode != ECAlarmTimeInterval) {
	[self setSpecifiedModeToInterval];
    }
    specifiedOffset = floor(specifiedOffset);
    specifiedOffset += 1;
    if (specifiedOffset >= 24 * 3600) {
	specifiedOffset -= (24 * 3600);
    }
    [self recalculateIntervalTime];
}


@end
