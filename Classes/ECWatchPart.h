//
//  ECWatchPart.h
//  Emerald Chronometer
//
//  Created by Bill Arnett on 4/17/2008.
//  Copyright 2008 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ECWatch.h"
#import "Constants.h"

@class EBVMInstructionStream;


@interface ECWatchPart : NSObject {			//////////////////////////////////////////////////////////
    NSString *name;					// mostly for debugging
    ECWatch *watch;					// the watch that this is a part of
    ECWatchModeMask modeMask;				// which modes this is part of (1=front, 2=night, 4=back)
    NSTimeInterval updateInterval;			// how often to do our action (in seconds)
    NSTimeInterval updateIntervalOffset;		// offset (in seconds) from even number of updateIntervals to start our action
    ECWatchPart *masterPart;                            // for parts which slave off a master angle
    ECWatchTimerSlot updateTimer;                       // which watch-time do we offset the update from (main, stopwatch, etc)
    int partIndex;                                      // temporary storage of part index when writing watch archive
}

@property (readonly, retain, nonatomic) NSString *name;
@property (readonly, nonatomic) NSTimeInterval updateInterval, updateIntervalOffset;
@property (readonly, nonatomic) ECWatch *watch;
@property (readonly, nonatomic) ECWatchModeMask modeMask;
@property (readonly, nonatomic) ECWatchTimerSlot updateTimer;
@property (readonly, nonatomic) ECWatchPart *masterPart;
@property (readonly, nonatomic) double z, thickness;
@property (nonatomic) int partIndex;

- (ECWatchPart *)initWithName:(NSString *)nam
			  for:(ECWatch *)container
		     modeMask:(ECWatchModeMask)modes
	       updateInterval:(double)interval
	 updateIntervalOffset:(double)off
	     	  updateTimer:(ECWatchTimerSlot)updateTimer
		   masterPart:(ECWatchPart *)masterPart;
- (ECHandKind)handKind;
- (EBVMInstructionStream *)angleInstructionStream;
- (EBVMInstructionStream *)xOffsetInstructionStream;
- (EBVMInstructionStream *)yOffsetInstructionStream;
- (double)offsetRadius;
- (EBVMInstructionStream *)offsetAngleInstructionStream;
- (EBVMInstructionStream *)actionInstructionStream;

@end


@interface ECWatchHand : ECWatchPart {			//////////////////////////////////////////////////////////
@private
    EBVMInstructionStream *angleInstructionStream;		// return the current angle of the hand (radians clockwise from 12 oclock)
    EBVMInstructionStream *xOffsetInstructionStream;
    EBVMInstructionStream *yOffsetInstructionStream;
    ECHandKind handKind;
    double offsetRadius;
    double z;
    double thickness;
    EBVMInstructionStream *offsetAngleInstructionStream;
    EBVMInstructionStream *actionInstructionStream;			// do something
}

@property (readonly, nonatomic) EBVMInstructionStream *angleInstructionStream;
@property (readonly, nonatomic) EBVMInstructionStream *xOffsetInstructionStream;
@property (readonly, nonatomic) EBVMInstructionStream *yOffsetInstructionStream;
@property (readonly, nonatomic) double angle;		// runs the instructionstream and returns the result
@property (readonly, nonatomic) double offsetRadius;
@property (readonly, nonatomic) EBVMInstructionStream *offsetAngleInstructionStream;
@property (readonly, nonatomic) ECHandKind handKind;
@property (readonly, nonatomic) double z, thickness;

- (ECWatchHand *)initWithName:(NSString *)nam
		     forWatch:(ECWatch *)container
		     modeMask:(ECWatchModeMask)modes
			 kind:(ECHandKind)kind
	       updateInterval:(double)interval
	 updateIntervalOffset:(double)off
		  updateTimer:(ECWatchTimerSlot)updateTimer
		   masterPart:(ECWatchPart *)masterPart
		  angleStream:(EBVMInstructionStream *)angleStream
		 actionStream:(EBVMInstructionStream *)actionStream
			    z:(double)z
		    thickness:(double)thickness
		xOffsetStream:(EBVMInstructionStream *)xOffsetStream
		yOffsetStream:(EBVMInstructionStream *)yOffsetStream
		 offsetRadius:(double)offsetRadius
	    offsetAngleStream:(EBVMInstructionStream *)offsetAngleStream;
@end


@interface ECWatchBlinker : ECWatchPart {		//////////////////////////////////////////////////////////
@private
    EBVMInstructionStream *computeDuration;		// return the number of seconds that this item should be visible this time
}

@property (readonly,nonatomic) double duration;		// runs the instructionstream and returns the result

- (ECWatchBlinker *)initWithName:(NSString *)nam
			     for:(ECWatch *)container
			modeMask:(ECWatchModeMask)modes
		  updateInterval:(double)interval
	    updateIntervalOffset:(double)off
			duration:(EBVMInstructionStream *)stream;

@end


@interface ECWatchTick : ECWatchPart {		//////////////////////////////////////////////////////////
@private
    NSString *soundFile;				// name of the sound file to play
}

@property (readonly, nonatomic) NSString *soundFile;

- (ECWatchTick *)initWithName:(NSString *)aName
			  for:(ECWatch *)container
		     modeMask:(ECWatchModeMask)mod
	       updateInterval:(double)interval
	 updateIntervalOffset:(double)off
		    soundFile:(NSString*)aSoundFile;

@end


@interface ECWatchTune : ECWatchPart {		//////////////////////////////////////////////////////////
@private
    NSString *tones;					// sequence of tones to play
    EBVMInstructionStream *computeDelay;		// computes how long to delay between tones of the tune (in seconds)
}

- (ECWatchTune *)initWithName:(NSString *)aName
			  for:(ECWatch *)container
		     modeMask:(ECWatchModeMask)mod
	       updateInterval:(double)interval
	 updateIntervalOffset:(double)off
			pause:(EBVMInstructionStream *)stream
			 tune:(NSString *)notes;

@property (readonly,nonatomic) NSString *tones;
@property (readonly,nonatomic) double delay;		// runs the instructionstream and returns the result

@end


@interface ECWatchButton : ECWatchHand {		//////////////////////////////////////////////////////////
}

- (ECWatchButton *)initWithName:(NSString *)aName
		       forWatch:(ECWatch *)container
		       modeMask:(ECWatchModeMask)mod
			 action:(EBVMInstructionStream *)stream
		 updateInterval:(double)interval
	   updateIntervalOffset:(double)intervalOffset
		     masterPart:(ECWatchPart *)masterPart
		    angleStream:(EBVMInstructionStream *)angleStream
		  xOffsetStream:(EBVMInstructionStream *)xOffsetStream
		  yOffsetStream:(EBVMInstructionStream *)yOffsetStream
	      offsetAngleStream:(EBVMInstructionStream *)offsetAngleStream;

@end
