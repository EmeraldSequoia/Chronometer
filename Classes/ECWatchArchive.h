//
//  ECWatchArchive.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 8/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#include <stdio.h>
#import "Constants.h"

@class EBVMInstructionStream, EBVirtualMachine;

@interface ECWatchArchive : NSObject {
    FILE *fp;
    NSString *path;

#undef EC_ARCHIVE_LOG
#ifdef EC_ARCHIVE_LOG
    FILE *debug_log;
#endif
}

@property (readonly, nonatomic) NSString *path;

- (id)initForWritingIntoPath:(NSString *)path;
- (void)writeInteger:(int)value;
- (void)writeDouble:(double)value;
- (void)writeRect:(CGRect)value;
- (void)writePoint:(CGPoint)value;
- (void)writeInstructionStream:(EBVMInstructionStream *)value usingVirtualMachine:(EBVirtualMachine *)vm;
- (void)writeString:(NSString *)string;
- (void)writeWatchPartDataWithFrontTextureSlot:(int)frontTextureSlot
			       backTextureSlot:(int)backTextureSlot
			      nightTextureSlot:(int)nightTextureSlot
				boundsOnScreen:(CGRect)boundsOnScreen
				anchorOnScreen:(CGPoint)anchorOnScreen
				updateInterval:(double)updateInterval
			  updateIntervalOffset:(double)updateIntervalOffset
				   updateTimer:(ECWatchTimerSlot)updateTimer
				      modeMask:(int)modeMask
				      handKind:(int)handKind
				      dragType:(ECDragType)dragType
			     dragAnimationType:(ECDragAnimationType)dragAnimationType
				     animSpeed:(double)animSpeed
				       animDir:(ECAnimationDirection)animDir
				      grabPrio:(int)grabPrio
				       envSlot:(int)envSlot
				   specialness:(ECPartSpecialness)specialness
			      specialParameter:(unsigned int)specialParameter
    				      norotate:(bool)norotate
				cornerRelative:(bool)cornerRelative
				    flipOnBack:(bool)flipOnBack
					 flipX:(bool)flipX
					 flipY:(bool)flipY
			       centerPixelOnly:(bool)centerPixelOnly
			   usingVirtualMachine:(EBVirtualMachine *)vm
			angleInstructionStream:(EBVMInstructionStream *)angleInstructionStream
		      xOffsetInstructionStream:(EBVMInstructionStream *)xOffsetInstructionStream
		      yOffsetInstructionStream:(EBVMInstructionStream *)yOffsetInstructionStream
				  offsetRadius:(double)offsetRadius
		  offsetAngleInstructionStream:(EBVMInstructionStream *)offsetAngleInstructionStream
		       actionInstructionStream:(EBVMInstructionStream *)actionInstructionStream
				repeatStrategy:(ECPartRepeatStrategy)repeatStrategy
				     immediate:(bool)immediate
				      expanded:(bool)expanded
				   masterIndex:(int)masterIndex
				enabledControl:(ECButtonEnabledControl)enabledControl;

- (void)logName:(NSString *)name;
- (void)seekToStart;
- (void)finishWriting;

- (id)initForReadingFromPath:(NSString *)path;
- (int)readInteger;
- (double)readDouble;
- (CGRect)readRect;
- (CGPoint)readPoint;
- (void)readDataInto:(void *)dataLocation numberOfBytes:(int)numberOfBytes;
- (EBVMInstructionStream *)readInstructionStreamForVirtualMachine:(EBVirtualMachine *)virtualMachine;
- (NSString *)readString;
- (void)readWatchPartDataWithFrontTextureSlot:(int*)frontTextureSlot
			      backTextureSlot:(int*)backTextureSlot
			     nightTextureSlot:(int*)nightTextureSlot
			       boundsOnScreen:(CGRect*)boundsOnScreen
			       anchorOnScreen:(CGPoint*)anchorOnScreen
			       updateInterval:(double*)updateInterval
			 updateIntervalOffset:(double*)updateIntervalOffset
				  updateTimer:(ECWatchTimerSlot*)updateTimer
				     modeMask:(int*)modeMask
				     handKind:(int*)handKind
				     dragType:(ECDragType*)dragType
			    dragAnimationType:(ECDragAnimationType*)dragAnimationType
				    animSpeed:(double*)animSpeed
				      animDir:(ECAnimationDirection*)animDir
				     grabPrio:(int*)grabPrio
				      envSlot:(int*)envSlot
				  specialness:(ECPartSpecialness*)specialness
			     specialParameter:(unsigned int *)specialParameter
				     norotate:(bool*)norotate
			       cornerRelative:(bool*)cornerRelative
				   flipOnBack:(bool*)flipOnBack
					flipX:(bool*)flipX
					flipY:(bool*)flipY
			      centerPixelOnly:(bool*)centerPixelOnly
			  usingVirtualMachine:(EBVirtualMachine *)vm
		       angleInstructionStream:(EBVMInstructionStream **)angleInstructionStream
		     xOffsetInstructionStream:(EBVMInstructionStream **)xOffsetInstructionStream
		     yOffsetInstructionStream:(EBVMInstructionStream **)yOffsetInstructionStream
				 offsetRadius:(double *)offsetRadius
		 offsetAngleInstructionStream:(EBVMInstructionStream **)offsetAngleInstructionStream
		      actionInstructionStream:(EBVMInstructionStream **)actionInstructionStream
			       repeatStrategy:(ECPartRepeatStrategy *)repeatStrategy
				    immediate:(bool *)immediate
				     expanded:(bool *)expanded
				  masterIndex:(int *)masterIndex
			       enabledControl:(ECButtonEnabledControl *)enabledControl;
- (void)finishReading;

@end
