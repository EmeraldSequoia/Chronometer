//
//  ECErrorReporter.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "EBVirtualMachine.h"

@interface ECErrorReporter : NSObject<EBVirtualMachineErrorDelegate> {
}

-(void)reportError:(NSString *)errorDescription;
-(void)reportWarning:(NSString *)errorDescription;
+(ECErrorReporter *)theErrorReporter;

@end
