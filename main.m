//
//  main.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/16/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Classes/ChronometerAppDelegate.h"

int main(int argc, char *argv[])
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    [ChronometerAppDelegate startOfMain];
    int retVal;
    @try {
	retVal = UIApplicationMain(argc, argv, nil, @"ChronometerAppDelegate");
    }
    @catch(NSException *exception) {
	NSString *name = [exception name];
	NSString *reason = [exception reason];
	// NSDictionary *dictionary = [exception userInfo];
// You can stop in the debugger at the throw by adding a symbolic breakpoint on objc_exception_throw
	printf("Uncaught exception with name %s and reason:\n%s\n",
	       [name UTF8String],
	       [reason UTF8String]);
	retVal = 1;
    }
    @finally {
    }
    [pool release];
    return retVal;
}
