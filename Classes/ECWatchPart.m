//
//  ECWatchPart.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/17/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import "ECWatch.h"
#import "ECWatchPart.h"
#import "EBVirtualMachine.h"
#import "ECErrorReporter.h"


@implementation ECWatchPart			    //////////////////////////////////////////////////////////

@synthesize updateInterval, updateIntervalOffset, updateTimer, watch, name, modeMask, masterPart, partIndex;

- (ECWatchPart *)initWithName:(NSString *)nam for:(ECWatch *)container modeMask:(ECWatchModeMask)modes updateInterval:(double)interval updateIntervalOffset:(double)off updateTimer:(ECWatchTimerSlot)updTimer masterPart:(ECWatchPart *)aMasterPart {
    assert(nam);
    assert(container);
    
    if (self = [super init]) {
	name = [nam retain];
	watch = container;	// no retain!
	modeMask = modes;
	updateInterval = interval;
	updateIntervalOffset = off;
	updateTimer = updTimer;
	masterPart = aMasterPart;
	partIndex = -1;
    }
    return self;
}

- (void)setModeMask:(ECWatchModeMask)newMode {
    assert(0 <= newMode && newMode <= (allModes | stopMask));
    modeMask = newMode;
}

- (void)dealloc {
    [name release];
    [super dealloc];
}

- (ECHandKind)handKind {
    return ECNotTimerZeroKind;
}

- (EBVMInstructionStream *)angleInstructionStream {
    return nil;
}

- (EBVMInstructionStream *)xOffsetInstructionStream {
    return nil;
}

- (EBVMInstructionStream *)yOffsetInstructionStream {
    return nil;
}

- (double)offsetRadius {
    return 0;
}

- (double)z {
    return 0;
}

- (double)thickness {
    return 3;
}

- (EBVMInstructionStream *)offsetAngleInstructionStream {
    return nil;
}

- (EBVMInstructionStream *)actionInstructionStream {
    return nil;
}

@end


@implementation ECWatchHand				    /////////////////////////////////////////////////////////

@synthesize handKind, angleInstructionStream, xOffsetInstructionStream, yOffsetInstructionStream, offsetRadius, offsetAngleInstructionStream, z, thickness;

- (ECWatchHand *)initWithName:(NSString *)nam
		     forWatch:(ECWatch *)container
		     modeMask:(ECWatchModeMask)modes
			 kind:(ECHandKind)kind
	       updateInterval:(double)interval
	 updateIntervalOffset:(double)off
		  updateTimer:(ECWatchTimerSlot)updTimer
		   masterPart:(ECWatchPart *)aMasterPart
		  angleStream:(EBVMInstructionStream *)angleStream
		 actionStream:(EBVMInstructionStream *)actionStream
			    z:(double)aZ
		    thickness:(double)aThickness
		xOffsetStream:(EBVMInstructionStream *)xOffsetStream
		yOffsetStream:(EBVMInstructionStream *)yOffsetStream
		 offsetRadius:(double)anOffsetRadius
	    offsetAngleStream:(EBVMInstructionStream *)offsetAngleStream {
    if (self = (id)[super initWithName:(NSString *)nam
				   for:(ECWatch *)container
			      modeMask:(ECWatchModeMask)modes
			updateInterval:(double)interval
		  updateIntervalOffset:(double)off
			   updateTimer:updTimer
			    masterPart:aMasterPart]) {
	angleInstructionStream = [angleStream retain];
	actionInstructionStream = [actionStream retain];
	xOffsetInstructionStream = [xOffsetStream retain];
	yOffsetInstructionStream = [yOffsetStream retain];
	offsetRadius = anOffsetRadius;
	offsetAngleInstructionStream = [offsetAngleStream retain];
	handKind = kind;
	z = aZ;
	thickness = aThickness;
    }
    return self;
}

- (double)angle {		    // return the current angle of this hand using our virtual machine program
    assert([watch vm]);
    if (angleInstructionStream != nil) {
	return [[watch vm] evaluateInstructionStream:angleInstructionStream errorReporter:[ECErrorReporter theErrorReporter]];
    }
    return random();
}

- (EBVMInstructionStream *)actionInstructionStream {
    return actionInstructionStream;
}

- (void)dealloc {
    [angleInstructionStream release];
    [xOffsetInstructionStream release];
    [yOffsetInstructionStream release];
    [offsetAngleInstructionStream release];
    [actionInstructionStream release];
    [super dealloc];
}

@end


@implementation ECWatchBlinker                              //////////////////////////////////////////////////////////

- (ECWatchBlinker *)initWithName:(NSString *)nam for:(ECWatch *)container modeMask:(ECWatchModeMask)modes updateInterval:(double)interval updateIntervalOffset:(double)off duration:(EBVMInstructionStream *)stream {
    if (!stream) {
	return nil;
    }
    if (self = (id)[super initWithName:(NSString *)nam
				   for:(ECWatch *)container
			      modeMask:(ECWatchModeMask)modes
			updateInterval:(double)interval
		  updateIntervalOffset:(double)off
			   updateTimer:ECMainTimer
			    masterPart:nil]) {
	computeDuration = [stream retain];
    }
    return self;    
}

- (double)duration  {		    // return the time this item should be visible using our virtual machine program
    if (computeDuration != nil) {
	assert([watch vm]);
	return [[watch vm] evaluateInstructionStream:computeDuration errorReporter:[ECErrorReporter theErrorReporter]];
    }
    return 2;
}

- (void)dealloc {
    [computeDuration release];
    [super dealloc];
}

@end


@implementation ECWatchTick				    //////////////////////////////////////////////////////////

@synthesize soundFile;

- (ECWatchTick *)initWithName:(NSString *)aName for:(ECWatch *)container modeMask:(ECWatchModeMask)mod updateInterval:(double)interval updateIntervalOffset:(double)off soundFile:(NSString*)aSoundFile {
    if (self = (id)[super initWithName:(NSString *)aName
				   for:(ECWatch *)container
			      modeMask:(ECWatchModeMask)mod
			updateInterval:(double)interval
		  updateIntervalOffset:(double)off
			   updateTimer:ECMainTimer
			    masterPart:nil]) {
	soundFile = [aSoundFile retain];
    }
    return self;
}

- (void)dealloc {
    [soundFile release];
    [super dealloc];
}

@end


@implementation ECWatchTune				    //////////////////////////////////////////////////////////

@synthesize tones;

- (ECWatchTune *)initWithName:(NSString *)aName for:(ECWatch *)container modeMask:(ECWatchModeMask)mod updateInterval:(double)interval updateIntervalOffset:(double)off
			pause:(EBVMInstructionStream *)stream tune:(NSString *)notes {
    if (!stream) {
	return nil;
    }
    if (self = (id)[super initWithName:(NSString *)aName
				   for:(ECWatch *)container
			      modeMask:(ECWatchModeMask)mod
			updateInterval:(double)interval
		  updateIntervalOffset:(double)off
			   updateTimer:ECMainTimer
			    masterPart:nil]) {
	computeDelay = [stream retain];
	tones = [notes retain];
    }
    return self;    
}
    
- (double)delay {		    // return the time to delay between tones using our virtual machine program
    if (computeDelay != nil) {
	assert([watch vm]);
	return [[watch vm] evaluateInstructionStream:computeDelay errorReporter:[ECErrorReporter theErrorReporter]];
    }
    return 0.5;
}

- (void)dealloc {
    [computeDelay release];
    [tones release];
    [super dealloc];
}

@end


@implementation ECWatchButton			    //////////////////////////////////////////////////////////

- (ECWatchButton *)initWithName:(NSString *)aName
		       forWatch:(ECWatch *)container
		       modeMask:(ECWatchModeMask)mod
			 action:(EBVMInstructionStream *)actionStream
		 updateInterval:(double)interval
	   updateIntervalOffset:(double)intervalOffset
		     masterPart:(ECWatchPart *)aMasterPart
		    angleStream:(EBVMInstructionStream *)angleStream
		  xOffsetStream:(EBVMInstructionStream *)xOffsetStream
		  yOffsetStream:(EBVMInstructionStream *)yOffsetStream
	      offsetAngleStream:(EBVMInstructionStream *)offsetAngleStream {
    if (self = (id)[super initWithName:(NSString *)aName
			      forWatch:(ECWatch *)container
			      modeMask:(ECWatchModeMask)mod
				  kind:ECNotTimerZeroKind
			updateInterval:interval
		  updateIntervalOffset:intervalOffset
			   updateTimer:ECMainTimer
			    masterPart:aMasterPart
			   angleStream:angleStream
			  actionStream:actionStream
				     z:0
			     thickness:3
			 xOffsetStream:xOffsetStream
			 yOffsetStream:yOffsetStream
			  offsetRadius:0
		     offsetAngleStream:offsetAngleStream]) {
    }
    return self;    
}


- (void)dealloc {
    [super dealloc];
}

@end
