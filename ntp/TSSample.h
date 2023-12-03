//
//  TSSample.h
//  TimeSync
//
//  Created by Bill Arnett on 8/11/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface TSSample : NSObject {
    NSTimeInterval myTransmitTime;	// when I transmitted the request
    NSTimeInterval myReceiveTime;	// when I received the response
    double rtt;			// roundtrip time for this sample
    double clockSkew;		// realTime == localTime + skew (seconds)
}

@property (readwrite) NSTimeInterval myTransmitTime;
@property (readwrite) NSTimeInterval myReceiveTime;
@property (readonly, nonatomic) double roundTripTime;		// round-trip time (seconds)
@property (readwrite, nonatomic) double clockSkew;		// how much our clock is off (according to this one sample)

@end
