//
//  ECAppLog.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 7/2009.
//  Copyright Emerald Sequoia LLC 2009. All rights reserved.
//

@interface ECAppLog : NSObject {
}

+(void)log:(NSString *)string;
+(void)newSession;
+(void)clear;
+(void)mail;
+(NSString *)logFileName;

@end
