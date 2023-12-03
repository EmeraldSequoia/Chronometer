//
//  TSSample.m
//  TimeSync
//
//  Created by Bill Arnett on 8/11/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "TSConnection.h"
#import "TSSample.h"


@implementation TSSample

@synthesize myTransmitTime, myReceiveTime, clockSkew;

- (TSSample *)init {
    if (self = [super init]) {
	rtt = 0;
	clockSkew = 0;
	myTransmitTime = 0;
	myReceiveTime = 0;
    }
    return self;
}

- (double)roundTripTime {
    if (rtt == 0) {
	if (myReceiveTime && myTransmitTime) {
	    rtt = myReceiveTime - myTransmitTime;
	} // no data yet
    }
    return rtt;
}

- (void)dealloc {
    [super dealloc];
}

@end
