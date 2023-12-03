//
//  ECTS.h
//  Chronometer
//
//  Created by Bill Arnett on 11/11/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#if 1  // Emerald Chronometer
#import "Constants.h"
#else
typedef enum ECTSState {
    ECTSGood = 0,
    ECTSWorkingGood = 1,
    ECTSWorkingUncertain = 2,
    ECTSUncertain = 3,
    ECTSOFF = 4,
    ECTSFailed = 5,
    ECTSCanceled = 6
} ECTSState;
#endif

struct _CountryFarmDescriptor;

@class TSNTPConnection;

#define ECNTPInterval	    86400	// seconds between ntp syncs
#define ECNTPPollInterval   0.25	// seconds between data requests
#define ECHostTimeOut	    4.0		// how long to wait before trying another host
#define ECHostInitialTime   3.0		// how long to wait the first time
#define defaultAccuracy	    0.333	// std deviation must be less than this to be "good"; should be greater than .287 or one second precision sources will never satisfy
#define minRTT		    0.005	// roundtrip times less than this (m ms) are probably wrong
#define maxRTT		    4		// upper bound (4 whole seconds)
#define sortaGoodRTT	    0.500	// good enough to give to watchTime the very first time
#define goodRTT		    0.100	// good enough to give to watchTime
#define reallyGoodRTT	    0.050	// good enough to quit asking for more
#define sigmaSpread	    3		// discard a sample if it's skew is not within this many std deviations of mean
#define sigmaHuge	    9.999	// for bad samples
#define maxSkew		    1e11	// if our clock is off by more than this (3000 years) something's wrong
#define samplesLB	    4		// less than this many is "too few"
#define samplesUB	    5		// stop after this many good samples
#define tooBad		    4		// if this many bad samples, stop polling

@interface ECTS : NSObject {
    TSNTPConnection *connection;
    NSTimer	    *timer;		// for next poll
    double	    pollInterval;	// how often to poll
    int		    countGood;		// number of good samples received in total from this server
    int		    countBad;		// number of bad samples in a row
    double	    sigmaSkew;		// standard deviation of skews
    double	    meanSkew;		// average skew
    double	    sumSkews;		// sum of all skew values
    double	    sumSkews2;		// sum of squares of all skew values
    double	    meanRTT;		// average roundtrip time
    double	    skewLB;		// max of skew lower bounds
    double	    skewUB;		// min of skew upper bounds
    int		    hostNum;		// ntp pool host number
    const struct _CountryFarmDescriptor *countryFarmDescriptor;  // data for country
    NSTimer	    *hostTimer;
    NSTimer	    *sampleTimer;
    bool	    enabled;		// true if we're at least trying
    bool	    goodSync;		// our time is now synched with the atomic clocks
    bool	    canceled;		// last sync attempt was canceled; nothing pending
    bool	    failed;		// last sync attempt failed; will retry later
    bool	    userRequested;	// now running because the user asked for it
}

@property (readonly, nonatomic) TSNTPConnection *connection;
@property (readwrite, nonatomic) bool goodSync;
@property (readwrite, nonatomic) bool canceled, userRequested, enabled;
@property (readwrite, nonatomic) int countGood;
@property (readonly, nonatomic) double skewLB, skewUB, sigmaSkew;

+ (void)startNTP;
+ (void)reSync;
+ (void)stopNTP;
- (void)stopReSync;
- (void)syncAfter:(double)delay;
- (void)nextHost:(id)data;
+ (bool)synched;
+ (bool)running;
+ (bool)active;
+ (NSString *)timeServer;
+ (NSString *)timeServerIP;
+ (NSString *)statusText;
+ (ECTSState)indicatorState;
+ (double)skewUB;
+ (double)skewLB;
+ (double)sigma;

@end
