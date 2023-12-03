//
//  ECWatch.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/18/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ECWatch.h"
#import "ECWatchPart.h"
#import "EBVirtualMachine.h"
#import "ECWatchEnvironment.h"
#import "ECAstronomy.h"
#import "ECWatchTime.h"
#import "ECGLWatch.h"
#import "ECGlobals.h"

@implementation ECWatch

@synthesize name, vm, mode, definedModes, inits, center, numEnvironments, maxSeparateLoc, landscapeZoomFactor, beatsPerSecond;

+ (NSString *)defaultModeName {
    return @"front";
}

- (ECWatch *)initWithName:(NSString *)aName VMOwner:(id)VMOwner {
    if (self = [super init]) {
	parts = [[NSMutableArray alloc] initWithCapacity:ECDefaultNumParts];
	chimes = [[NSMutableArray alloc] initWithCapacity:ECDefaultNumChimes];
	buttons = [[NSMutableArray alloc] initWithCapacity:ECDefaultNumButtons];
	inits = [[NSMutableArray alloc] initWithCapacity:5];
	name = [aName retain];
	vm = [[EBVirtualMachine alloc] initWithOwner:VMOwner name:aName];
	ECImportVariables(vm);
	numEnvironments = 0;
    }
    return self;
}

- (ECWatch *)init {
    assert(false);
    self = [super init];
    return self;
}

- (void)setCenterX:(CGFloat)x y:(CGFloat)y {
    center.x = x;
    center.y = y;
}

- (void)addPart: (ECWatchPart *)part {
    [parts addObject:part];
    definedModes |= part.modeMask;
}

- (void)addChime: (ECWatchPart *)chime {
    [chimes addObject:chime];
}

- (void)addButton: (ECWatchButton *)butt {
    [buttons addObject:butt];
}

- (void)addInit: (EBVMInstructionStream *)init {
    [inits addObject:init];
}

- (void)setMode:(ECWatchModeMask)newMode {
    assert(newMode == frontMask || newMode == nightMask || newMode == backMask);
    if (mode != 0) {
	assert(newMode & definedModes);
    }
    mode = newMode;
}

- (void)dealloc {
    // hack:  need to release the contents of the collections?
    [name release];
    [vm release];
    [parts removeAllObjects];
    [chimes removeAllObjects];
    [buttons removeAllObjects];
    [parts release];
    [chimes release];
    [buttons release];
    [inits release];
    [super dealloc];
}

- (const char *)description {
    return [[NSString stringWithFormat:@"Watch: %@", name] UTF8String];
}

@end
