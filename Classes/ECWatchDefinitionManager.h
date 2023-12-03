//
//  ECWatchDefinitionManager
//  Emerald Chronometer
//
//  Created by Steve Pucci on 4/27/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

// Opaque declaration
@class ECWatchController;
@class EBVirtualMachine;

#import "ECLocationManager.h"

@interface ECWatchDefinitionManager : ECLocationManagerDelegate
#if __IPHONE_4_0
 <NSXMLParserDelegate> 
#endif
{
    id       	      errorDelegate;
    NSString 	      *builtinWatchDirectoryName;
    NSString          *currentWatchName;
    NSString          *currentWatchBundleDirectory;
    ECWatchController *watchController;
    EBVirtualMachine  *vm;
    NSMutableArray    *winBin;
}

-(ECWatchController *)loadWatchWithName:(NSString *)name errorReporter:(id)errorReporter;
-(ECWatchController *)loadWatchWithName:(NSString *)name intoController:(ECWatchController *)watchController errorReporter:(id)errorReporter;
-(void)loadAllWatchesWithErrorReporter:(id)errorReporter;
-(void)loadAllWatchesWithErrorReporter:(id)errorReporter butJustReallyLoad:(NSString *)watchName;
-(void)loadAllWatchesWithErrorReporter:(id)errorReporter butJustHackIn:(NSString *)watchName;
@end
