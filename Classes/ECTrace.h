/*
 *  ECTrace.h
 *  Chronometer
 *
 *  Created by Bill Arnett on 9/29/2009.
 *  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
 *
 */

#import "ChronometerAppDelegate.h"

#ifdef ECTRACE
extern NSString *traceTabs(void);
extern void traceEnter(const char *msg);
extern void traceExit(const char *msg);
#define tracePrintf(a)      {[ChronometerAppDelegate noteTimeAtPhaseWithString:[traceTabs() stringByAppendingString:@a]];}
#define tracePrintf1(a,b)   {[ChronometerAppDelegate noteTimeAtPhaseWithString:[traceTabs() stringByAppendingString:[NSString stringWithFormat:@a,b]]];}
#define tracePrintf2(a,b,c) {[ChronometerAppDelegate noteTimeAtPhaseWithString:[traceTabs() stringByAppendingString:[NSString stringWithFormat:@a,b,c]]];}
#define tracePrintf3(a,b,c,d) {[ChronometerAppDelegate noteTimeAtPhaseWithString:[traceTabs() stringByAppendingString:[NSString stringWithFormat:@a,b,c,d]]];}
#define tracePrintf4(a,b,c,d,e) {[ChronometerAppDelegate noteTimeAtPhaseWithString:[traceTabs() stringByAppendingString:[NSString stringWithFormat:@a,b,c,d,e]]];}
#else
#define traceTab() {;}
#define traceEnter(x) {;}
#define traceExit(x) {;}
#define tracePrintf(a) {;}
#define tracePrintf1(a,b) {;}
#define tracePrintf2(a,b,c) {;}
#define tracePrintf3(a,b,c,d) {;}
#define tracePrintf4(a,b,c,d,e) {;}
#endif
