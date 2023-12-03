//
//  TSTime.m
//  timestamp
//
//  Created by Steve Pucci on 5/2/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "TSTime.h"
#import "TSConnection.h"
#import "ECTS.h"
#import "ECErrorReporter.h"
#if 0  // Emerald Timestamp
#import "TSRootViewController.h"
#import "TSEventViewController.h"
#endif

#include <stdatomic.h> // for atomic_thread_fence()
#include <sys/time.h>  // for struct timeval

#undef TS_TEST  // Turn this on for fake ntp synchronization all over the place

//////////////////////////////////////////////////////////

@interface TSTimeObserver : NSObject {
@public
    id   observer;
    SEL  callback;
    bool mainThreadOnly;
}

- (id)initWithObserver:(id)observer callback:(SEL)callback callbackInMainThreadOnly:(bool)callbackInMainThreadOnly;

@end

@implementation TSTimeObserver

- (id)initWithObserver:(id)anObserver callback:(SEL)aCallback callbackInMainThreadOnly:(bool)callbackInMainThreadOnly {
    [super init];
    observer = [anObserver retain];
    callback = aCallback;
    mainThreadOnly = callbackInMainThreadOnly;
    return self;
}

- (void)dealloc {
    [observer release];
    [super dealloc];
}

@end

//////////////////////////////////////////////////////////

static float currentTimeError = 1E9;  // not very accurate


static double startOfMainTime;
static double lastTimeNoted = -1;

static double dateSkew = 0;
static double dateRSkew = 0;
static double dateROffset = 0;
static double mediaSkew = 0;
static double mediaROffset = 0;
static double mediaOffset = 0;

@implementation TSTime

#undef TS_PRINT_HEARTBEAT
#ifdef TS_PRINT_HEARTBEAT
+ (void)TSPrintHeartbeatTimerFire:(id)timer {
    [TSTime reportAllSkewsAndOffset:"heartbeat"];
}
#endif

// Preload any values for which the default value when missing isn't what we want
+ (void)registerDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *defaultsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								 [NSNumber numberWithBool:YES],	    @"ECUseNTP",
								 [NSNumber numberWithDouble:0],	    @"date-skew",
							         nil];
    
    [defaults registerDefaults:defaultsDict];
}

+ (void)saveDateSkewToDefaults {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:dateSkew] forKey:@"date-skew"];
}

// Load current values from "disk"
+ (void)loadDefaults {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults boolForKey:@"ECUseNTP"]) {
	dateSkew = [userDefaults doubleForKey:@"date-skew"];
	//printf("Loading dateSkew %.4f from defaults\n", dateSkew);
    } else {
	dateSkew = 0;
    }
}

NSMutableArray *valueChangeObservers = nil;
NSMutableArray *statusChangeObservers = nil;
NSMutableArray *mediaTimeResetObservers = nil;

+ (void)registerSyncValueChangeCallbackForObserver:(id)observer callback:(SEL)callback callbackInMainThreadOnly:(bool)callbackInMainThreadOnly {
    if (!valueChangeObservers) {
	valueChangeObservers = [[NSMutableArray alloc] initWithCapacity:1];
    }
    [valueChangeObservers addObject:[[[TSTimeObserver alloc] initWithObserver:observer callback:callback callbackInMainThreadOnly:callbackInMainThreadOnly] autorelease]];
}

+ (void)addTimeAdjustmentObserver:(id<TSTimeAdjustmentObserver>)observer {
    [self registerSyncValueChangeCallbackForObserver:observer callback:@selector(notifyTimeAdjustment) callbackInMainThreadOnly:true];
}

+ (void)removeTimeAdjustmentObserver:(id)observer {
    TSTimeObserver *removeMe = nil;
    for (TSTimeObserver *to in valueChangeObservers) {
	if (to->observer == observer) {
	    removeMe = to;
	    break;
	}
    }
    if (removeMe) {
	[valueChangeObservers removeObject:removeMe];
    }
}

+ (void)registerSyncStatusChangeCallbackForObserver:(id)observer callback:(SEL)callback callbackInMainThreadOnly:(bool)callbackInMainThreadOnly {
    if (!statusChangeObservers) {
	statusChangeObservers = [[NSMutableArray alloc] initWithCapacity:1];
    }
    [statusChangeObservers addObject:[[[TSTimeObserver alloc] initWithObserver:observer callback:callback callbackInMainThreadOnly:callbackInMainThreadOnly] autorelease]];
}

+ (void)registerMediaTimeResetCallbackForObserver:(id)observer callback:(SEL)callback callbackInMainThreadOnly:(bool)callbackInMainThreadOnly {
    if (!mediaTimeResetObservers) {
	mediaTimeResetObservers = [[NSMutableArray alloc] initWithCapacity:1];
    }
    [mediaTimeResetObservers addObject:[[[TSTimeObserver alloc] initWithObserver:observer callback:callback callbackInMainThreadOnly:callbackInMainThreadOnly] autorelease]];
}

// Gee, iOS. I guess this was too hard for you after 10 years.  Let those developers do some work for a change.
+ (void)setNetworkActivityOn {
    assert([NSThread isMainThread]);
    // [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;  // Deprecated in iOS 13
}
+ (void)setNetworkActivityOff {
    assert([NSThread isMainThread]);
    // [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;   // Deprecated in iOS 13
}

+ (void)notifySyncStatusChanged {
    if ([ECTS active]) {
        if ([NSThread isMainThread]) {
            // [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;  // Deprecated in iOS 13
        } else {
            [self performSelectorOnMainThread:@selector(setNetworkActivityOn) withObject:nil waitUntilDone:NO];
        }
    } else {
        if ([NSThread isMainThread]) {
            // [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;  // Deprecated in iOS 13
        } else {
            [self performSelectorOnMainThread:@selector(setNetworkActivityOff) withObject:nil waitUntilDone:NO];
        }
    }
    for (TSTimeObserver *to in statusChangeObservers) {
	if (to->mainThreadOnly) {
	    [to->observer performSelectorOnMainThread:to->callback withObject:nil waitUntilDone:NO];
	} else {
	    [to->observer performSelector:to->callback];
	}
    }
}

static bool skewWarned = false;

+ (void)notifySyncValueChanged {
    for (TSTimeObserver *to in valueChangeObservers) {
	if (to->mainThreadOnly) {
	    [to->observer performSelectorOnMainThread:to->callback withObject:nil waitUntilDone:NO];
	} else {
	    [to->observer performSelector:to->callback];
	}
    }
    if (fabs(dateSkew) > TOOBIGSKEW) {
	if (!skewWarned) {
#ifdef TS_PRINT_HEARTBEAT
	    [TSTime reportAllSkewsAndOffset:"too big skew"];
#endif
	    NSString *warning = [NSString stringWithFormat:NSLocalizedString(@"Your clock differs from NTP time by %.0f seconds.\nPlease check that your Date & Time and Timezone settings are correct.",@"Large NTP skew warning message"), dateSkew];
#if TARGET_IPHONE_SIMULATOR
	    warning = [warning stringByAppendingString:@"\n\nSimulator Detected\n\nIf your Mac has slept since the app has started,\nthis is normal behavior.\nRestart the app to correct the displayed time."];
#endif
	    [[ECErrorReporter theErrorReporter] reportWarning:warning];
	    skewWarned = true;
	}
    } else {
	skewWarned = false;
    }
}

+ (void)notifyMediaTimeReset {
    for (TSTimeObserver *to in mediaTimeResetObservers) {
	if (to->mainThreadOnly) {
	    [to->observer performSelectorOnMainThread:to->callback withObject:nil waitUntilDone:NO];
	} else {
	    [to->observer performSelector:to->callback];
	}
    }
}

static NSLock *printfLock = nil;

// If asleep, use NSDate and dateSkew; if not asleep, use CACurrentMediaTime and mediaSkew
static bool asleep = false;
static bool awakenedFirstTime = false;

/*
NOTE 2021/11/04: USES OF CACurrentMediaTime IN EC HAVE BEEN REMOVED IN FAVOR OF NSDATE, BECAUSE IN NEW VERSIONS OF IOS
  WITH REAL NTP BUILT-IN, NSDATE HAS A VERY CLOSE TO ZERO SKEW RATE, AND WE SAW IN ETS THAT USE OF CACurrentMediaTime
  CAUSED AN UNKNOWN PROBLEM DURING STARTUP WHERE A SYNC WASN'T DONE PROPERLY.  THUS THE FOLLOWING DENSE DESCRIPTION IS
  OBSOLETE; ALL TIMES ARE NOW == "NSDate time".

Time bases:

There are four time bases of interest:
  T1) "NTP time", abbreviated "ntp", which is UT1 to our best approximation.
      In this product we express it in NSTimeInterval units (seconds since 1/1/2001)
  T2) "NSDate time", abbreviated "dateTime", which is the value returned by [NSDate timeIntervalSinceReferenceDate]
      This value can change on an iPhone when the iPhone gets a new time reference from the cell tower it is talking to.  This change is accompanied by
      a call to applicationSignificantTimeChange.
  T3) "media time", which is the time returned by CACurrentMediaTime()
      This value remains constant (subject to the accuracy of the internal device clock) while the app session runs and while the device is not "locked" (asleep).
      When the device is locked the value is not useful.
  T4) "NSDate reference time", abbreviated "dateRTime", which, like media time, remains constant for the app session, and which we
      attempt to maintain even across sleep/wake boundaries.  It moves in lock step with media time while
      the device is awake, and then in lock step with date time
      while the device is asleep.  The absolute value is arbitrarily chosen to be the date time base at app
      session startup; thus until the first aSTC event comes in, it should return the same thing as date time
      (though with a small measurement error due to the delta between the sampling of the two input time bases).  See below.
  T5) "gettimeofday time", the time returned by gettimeofday().  This isn't really a time base like the others so much as
      a way of representing a particular time base.  The kernel function gettimeofday() uses the same time base as "dateTime" (T2), but
      in this app we replace that kernel call with a method using a more uniform time base (see below) based on dateRTime (T4).

dateRTime (T4) is used internally as the ntp-*un*corrected time base, to which the ntp correction is applied.  The ntp code
uses this time base when calculating its offsets, and reports back the skew with respect to this time base.
This time base is chosen because it has the best uniformity we can come up with, perfect while the device is awake
and as good as we know how when it goes to sleep.  This it is ideally suited for capturing reference times before and
after an ntp sample is obtained from a remote machine.

In practice, however, we use the simplest calculation for each request, which involves a simple addition of one skew term.

In this program we define the following key values, where "skews" are deltas from ntp, and "offsets" are internal timebase offsets
  (1) mediaOffset = dateTime - mediaTime;
       (a) =>   dateTime = mediaTime + mediaOffset
       This value changes when dateTime's time base changes and when mediaTime comes back from being asleep

  (2) mediaROffset = dateRTime - mediaTime;
       (a) =>   dateRTime = mediaTime + mediaROffset
       This value stays the same when dateTime's time base changes, because dateRTime's time base does not change

  (3) mediaSkew === NTP - mediaTime
       (a) =>   NTP = mediaTime + mediaSkew   (when mediaTime is valid)

  (4) dateRSkew === NTP - dateRTime
       This value is what is actually reported by the ntp code as the "skew".  It is *not* the dateSkew used in EC 3.1.

  (5) dateROffset === dateRTime - dateTime
       (a) =>   dateRTime = dateTime + dateROffset
       (b)                = mediaTime + mediaOffset + dateROffset  // from (1)(a)
       (c) =>   mediaROffset = mediaOffset + dateROffset   // from (2)(a)
       (d) =>   dateROffset = mediaROffset - mediaOffset
       (d) =>   dateRSkew = mediaTime + mediaSkew - dateRTime
       (e) =>             = mediaTime + mediaSkew - (dateTime + dateROffset)
       (f) =>             = -dateTime + mediaTime + mediaSkew - dateROffset
       (g) ->             = -(dateTime - mediaTime) + mediaSkew - dateROffset
       (h) ->             = -mediaOffset + mediaSkew - dateROffset
       (i) ->             = mediaSkew - (mediaOffset + dateROffset)
       (j) =>             = mediaSkew - mediaROffset
       (k) =>   mediaSkew = dateRSkew + mediaROffset
       This value starts out at zero when the app starts and changes when the iPhone time changes due to cell towers.

  (6) dateSkew === NTP - dateTime
       (a) dateSkew = dateRTime + dateRSkew - dateTime   // from (2)
       (b)           = dateTime + dateROffset + dateRSkew - dateTime  // from (3)
                     = dateROffset + dateRSkew
       (c) =>   NTP = dateTime + dateSkew
       (d)          = dateTime + dateROffset + dateRSkew  (when mediaTime is unreliable)
       (e) (with (3)) => mediaSkew = dateTime + dateSkew - mediaTime
       (f)                         = mediaOffset + dateSkew
       (g)               dateSkew = mediaSkew - mediaOffset

All of these skew values are kept up to date as the program progresses.

 */

static bool closeEnough(double p1, double p2) {
    return fabs(p1 - p2) < .000001;
}

extern void printDate(const char *description);
extern void printADate(NSTimeInterval dt);

#ifndef NDEBUG
+(void)reportAllSkewsAndOffset:(const char *)description {
    static double lastMediaSkew = 0;
    static double lastDateSkew = 0;
    static double lastDateRSkew = 0;
    static double lastMediaOffset = 0;
    static double lastMediaROffset = 0;
    static double lastDateROffset = 0;
    static bool firstTime = true;
    static int printCount = 0;
    static int headerFrequency = 20;

    static NSLock *lock = nil;
    if (!lock) {
	lock = [[NSLock alloc] init];
    }
    [lock lock];

    if ((printCount++ % headerFrequency) == 0) {
	printf("%16s %16s %16s %16s %16s %16s %22s %34s %34s %24s\n",
	       "mediaSkew", "dateSkew", "dateRSkew", "mediaOffset", "mediaROffset", "dateROffset",
	       "dateTime", "dateRTime", "ntp time",
	       "description");
    }
    printf("%15.4f%s %15.4f%s %15.4f%s %15.4f%s %15.4f%s %16.5f%s ",
	   mediaSkew, firstTime || closeEnough(mediaSkew, lastMediaSkew) ? " " : "*",
	   dateSkew, firstTime || closeEnough(dateSkew, lastDateSkew) ? " " : "*",
	   dateRSkew, firstTime || closeEnough(dateRSkew, lastDateRSkew) ? " " : "*",
	   mediaOffset, firstTime || closeEnough(mediaOffset, lastMediaOffset) ? " " : "*",
	   mediaROffset, firstTime || closeEnough(mediaROffset, lastMediaROffset) ? " " : "*",
	   dateROffset, firstTime || closeEnough(dateROffset, lastDateROffset) ? " " : "*");
    printf("[");
    NSTimeInterval nsdate = [NSDate timeIntervalSinceReferenceDate];
    printADate(nsdate);
    printf("] [");
    NSTimeInterval curR = [TSTime currentDateRTime];
    printADate(curR);
    printf("] [");
    NSTimeInterval curT = [TSTime currentTime];
    printADate(curT);
    printf ("] %s\n", description);
    printf("%76s %24.5f  %25.5f %34.5f %34.5f\n", " ", curR - nsdate, nsdate, curR, curT);
    firstTime = false;
    lastMediaSkew = mediaSkew;
    lastDateSkew = dateSkew;
    lastDateRSkew = dateRSkew;
    lastMediaOffset = mediaOffset;
    lastMediaROffset = mediaROffset;
    lastDateROffset = dateROffset;
    [lock unlock];
}
#endif

+(NSTimeInterval)skew {
    return dateSkew;
}

+(NSTimeInterval)dateROffset {
    return dateROffset;
}

+ (NSTimeInterval)ntpTimeForRDate:(NSTimeInterval)rDateTime {
    return rDateTime + dateRSkew;
}

+ (NSTimeInterval)rDateForNTPTime:(NSTimeInterval)ntpTime {
    return ntpTime - dateRSkew;
}

+ (NSTimeInterval)dateSkew {
    return dateSkew;
}

+ (NSTimeInterval)dateRSkew {
    return dateRSkew;
}

// Following method called when mediaTime base is unknown, i.e. at startup and after waking.  Best we have is dateSkew, either from before sleep or from defaults
static void setupSkewsFromDateSkewOnly(NSTimeInterval dateTime,
				       NSTimeInterval mediaTime) {
    // dateSkew is presumed valid input
    mediaOffset = dateTime - mediaTime;  // From eq (1)
    mediaROffset = mediaOffset;                 // Because dateRTime and dateTime start out the same
    mediaSkew = mediaOffset + dateSkew;  // From eq (3)(f)
    dateROffset = 0;  // By definition, dateRTime and dateTime start out the same
    dateRSkew = dateSkew;  // Because dateRTime and dateTime are the same
    // At this moment, our best guess is that NTP = startOfMainTime + dateSkew, so use that to calculate mediaSkew
    // No need to save defaults, dateSkew didn't change
    [TSTime notifyMediaTimeReset];
}

+ (void)resyncTimerFire:(id)timer {
    [ECTS reSync];
}

#ifdef TS_TEST
+ (void)TSTestTimerFire:(id)timer {
    u_int32_t random_int = arc4random();
    double newSync = (double)random_int / ((double)(unsigned int)0xffffffff) * 30;
    [self setRSkew:newSync];
}

+ (void)startTSTest {
    [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(TSTestTimerFire:) userInfo:nil repeats:YES];
}
#endif

+ (void)startOfMainWithSignature:(const char *)fourByteAppSig {
    startOfMainTime = [NSDate timeIntervalSinceReferenceDate];
    // CFTimeInterval mediaTime = CACurrentMediaTime();  // Do this immediately after getting the dateTime
    NSTimeInterval mediaTime = startOfMainTime;
    [TSConnection setAppSignature:fourByteAppSig];
    [self registerDefaults];
    [self loadDefaults];
    // dateSkew = <from loadDefaults>
    setupSkewsFromDateSkewOnly(startOfMainTime, mediaTime);
    // After this, until the NTP fix comes in, NTP = mediaTime + mediaSkew;
    //[self reportAllSkewsAndOffset:"startOfMain"];
#ifdef TS_TEST
    [self startTSTest];
#else
    [ECTS startNTP];  // Does so only based on defaults value ECUseNTP
#endif
    [NSTimer scheduledTimerWithTimeInterval:3600 target:self selector:@selector(resyncTimerFire:) userInfo:nil repeats:YES];
#ifdef TS_PRINT_HEARTBEAT
    [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(TSPrintHeartbeatTimerFire:) userInfo:nil repeats:YES];
#endif
}
   
static void setupSkewsFromMediaSkewOnly() {
    NSTimeInterval dateTime = [NSDate timeIntervalSinceReferenceDate];
    // CFTimeInterval mediaTime = CACurrentMediaTime();
    NSTimeInterval mediaTime = dateTime;
    // mediaSkew is unchanged, by definition
    // mediaROffset is unchanged, by definition
    mediaOffset = dateTime - mediaTime;   // eq (1)
    dateSkew = mediaSkew - mediaOffset;   // eq (3)(f) inverted
    dateROffset = mediaROffset - mediaOffset;  // eq (5)(d)
    dateRSkew = mediaSkew - mediaROffset;   // eq (5)(j)
    [TSTime saveDateSkewToDefaults];
}

+ (void)goingToSleep {
    // When asleep, mediaTime is invalid, and thus mediaSkew is useless.  But since we've been keeping all values up to date,
    // there's nothing to do here except set the "asleep" flag and set the currentTimeError high.
    assert([NSThread isMainThread]);
    [TSTime notifyMediaTimeReset];
    assert(!asleep);
    currentTimeError = 1e9;
    // But, in case we have a delayed aSTC coming, we pretend we got one here; it's really no damage
    setupSkewsFromMediaSkewOnly();
    //[self reportAllSkewsAndOffset:"goingToSleep"];
    atomic_thread_fence(memory_order_seq_cst);  // Make sure the value gets set before the state change
    asleep = true;
    [ECTS stopNTP];
}

+ (void)wakingUp {
    assert([NSThread isMainThread]);
    if (awakenedFirstTime) {
	assert(asleep);
    } else {
	awakenedFirstTime = true;
	return;
    }
    assert(currentTimeError == 1e9);  // cause we set it to that when sleeping and it should never be reset during sleep
    // dateSkew is our only primary input
    NSTimeInterval dateTime = [NSDate timeIntervalSinceReferenceDate];
    // CFTimeInterval mediaTime = CACurrentMediaTime();
    NSTimeInterval mediaTime = dateTime;
    setupSkewsFromDateSkewOnly(dateTime, mediaTime);
    atomic_thread_fence(memory_order_seq_cst);  // Make sure the value gets set before the state change
    asleep = false;
    //[self reportAllSkewsAndOffset:"wakingUp"];
    [ECTS reSync];
}

+ (void)resync {
    [ECTS reSync];
}

// This should have no effect on the media time or media skew, but it might result in a new dateSkew which should be recorded in the defaults
+ (void)applicationSignificantTimeChange {
    assert([NSThread isMainThread]);
    if (asleep) {
	;  // We're already in dateSkew mode; we can't learn anything from the time change since we have no heartbeat code
    } else {  // not asleep; just update dateSkew and save it
	setupSkewsFromMediaSkewOnly();
	//[self reportAllSkewsAndOffset:"aSTC"];
    }
}

+ (void)setRSkew:(NSTimeInterval)rskew {
    if (asleep) {
	// Can't really use this here...
    } else {
	double skewLB = [ECTS skewLB];
	double skewUB = [ECTS skewUB];
	double skewAverage = (skewUB - skewLB) / 2;  // The skew we use is always in the middle of the range anyway, so this loses no information
	if (skewAverage < 1e9) {
	    //[self reportAllSkewsAndOffset:"setRSkew start"];
	    // mediaOffset is unchanged
	    // mediaROffset is unchanged
	    // dateROffset is unchanged
	    dateRSkew = rskew;
	    mediaSkew = dateRSkew + mediaROffset;
	    dateSkew = mediaSkew - mediaOffset;
	    [self saveDateSkewToDefaults];
	    currentTimeError = skewAverage;
	    //printf("Got new skew %.3f [%.3f => %.3f] ±%.3fs\n", dateRSkew, skewLB, skewUB, skewAverage);
	    //[self reportAllSkewsAndOffset:"setRSkew notify start"];
	    [self notifySyncValueChanged];
	    //[self reportAllSkewsAndOffset:"setRSkew end"];
	}
    }
}

static NSTimeInterval fetchCurrentTime() {
    // No lock here for performance.  The only non-atomic piece is whether we use date or media time, and both should always be "correct" as far as we can tell anyway
    if (asleep) {
	NSTimeInterval dateTime = [NSDate timeIntervalSinceReferenceDate];
	return dateTime + dateSkew;  // eq (6)(c)
    } else {
	// NSTimeInterval mediaTime = CACurrentMediaTime();
	NSTimeInterval mediaTime = [NSDate timeIntervalSinceReferenceDate];
	return mediaTime + mediaSkew;  // eq (3)(a)
    }
}

static NSTimeInterval fetchCurrentDateRTime() {
    if (asleep) {
	NSTimeInterval dateTime = [NSDate timeIntervalSinceReferenceDate];
	return dateTime + dateROffset;  // eq (5)(a)
    } else {
	// NSTimeInterval mediaTime = CACurrentMediaTime();
	NSTimeInterval mediaTime = [NSDate timeIntervalSinceReferenceDate];
	return mediaTime + mediaROffset;   // eq (2)(a)
    }
}

+(NSTimeInterval)currentTime {
    return fetchCurrentTime();
}

+(float)currentTimeError {
    return currentTimeError;
}

+ (NSTimeInterval)currentDateRTime {
    return fetchCurrentDateRTime();
}

+ (NSTimeInterval)dateForMediaTime:(NSTimeInterval)aMediaTime {
    return aMediaTime + mediaSkew;
}

+ (NSTimeInterval)mediaTimeForDate:(NSTimeInterval)aDateTime {
    return aDateTime - mediaSkew;
}

static double
TS_fmod(double arg1,
	double arg2)
{
    return (arg1 - floor(arg1/arg2)*arg2);
}

+ (NSTimeInterval)timeUntilNextFractionalSecond:(double)fractionalSecond {
    NSTimeInterval now = fetchCurrentTime();
    NSTimeInterval timeSinceLastFractionalSecond = TS_fmod(now, fractionalSecond);
    return fractionalSecond - timeSinceLastFractionalSecond;
}

+ (void)aboutToTerminate {
    // Nothing to do; the dateSkew should already be in the defaults
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+(void)printTimes:(NSString *)who {
    double now = [NSDate timeIntervalSinceReferenceDate];
    printf("<< ");
    printADate(now);
    printf("(iPhone) %+7.3f == ", dateSkew);
    printADate(now+dateSkew);
    printf("  >>        %s\n", [who UTF8String]);
}

+ (void)noteTimeAtPhase:(const char *)phaseName {
    if (!printfLock) {
	printfLock = [[NSLock alloc] init];
    }
    [printfLock lock];
    double t = [NSDate timeIntervalSinceReferenceDate];
    if (lastTimeNoted < 0) {
	printf("Phase time Cumulative  Description\n");
	printf("%10.4f %10.4f: ", 0.0, t - startOfMainTime);
    } else {
	printf("%10.4f %10.4f: ", t - lastTimeNoted, t - startOfMainTime);
    }
    [self printTimes:[NSString stringWithCString:phaseName encoding:NSASCIIStringEncoding]];
    lastTimeNoted = t;
    [printfLock unlock];
}

+ (void)noteTimeAtPhaseWithString:(NSString *)phaseName {
    [self noteTimeAtPhase:[phaseName UTF8String]];
}

+ (void)setSkewFromNTP:(NSTimeInterval)newSkew {
}

#define TS_VALUE_OF_NSTIME_AT_1970 -978307200.00   // obtained by asking for NSDate at 1/1/70 midnight UTC, verified to be 31 365-day years and 8 leap days exactly

+ (void)gettimeofdayR:(struct timeval *)tv {
    NSTimeInterval rTime = fetchCurrentDateRTime();
    double timeSince1970 = rTime - TS_VALUE_OF_NSTIME_AT_1970;
    long intSeconds = (long)timeSince1970;
    tv->tv_sec = intSeconds;
    double fraction = timeSince1970 - intSeconds;
    tv->tv_usec = (int)(fraction * 1e6);
    //printf("gettimeofdayR converted %.6f into %d and %d\n", timeSince1970, (int)intSeconds, (int)tv->tv_usec);
}

@end
