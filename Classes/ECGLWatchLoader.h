//
//  ECGLWatchLoader
//  Emerald Chronometer
//
//  Created by Steven Pucci October 2008
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

@interface ECGLWatchLoader : NSObject {
}

+ (void)init;
+ (void)checkForWork;
+ (void)pauseBG;
+ (void)pauseBGWhenDone;
+ (void)resumeBG;

@end
