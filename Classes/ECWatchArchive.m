//
//  ECWatchArchive.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 8/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "ECErrorReporter.h"
#import "ECWatchArchive.h"

@implementation ECWatchArchive

@synthesize path;

- (id)initForWritingIntoPath:(NSString *)p {
    [super init];
#ifndef NDEBUG
    path = [p retain];
#endif
    fp = fopen([p UTF8String], "w");
    if (!fp) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error creating archive %@: %s", p, strerror(errno)]];
    }
#ifdef EC_ARCHIVE_LOG
    debug_log = fopen([[p stringByAppendingString:@".log"] UTF8String], "w");
    if (!debug_log) {
	printf("Couldn't open log file %s\n", [[p stringByAppendingString:@".log"] UTF8String]);
	assert(false);
    }
#endif
    return self;
}

- (void)dealloc {
#ifndef NDEBUG
//     [path release];  // Don't do this until all clients are changed to handle us releasing the string out from under them
#endif
    [super dealloc];
}

- (void)writeInteger:(int)value {
#ifdef EC_ARCHIVE_LOG
    fprintf(debug_log, "Integer: %d\n", value);
#endif
    size_t objectsWritten = fwrite(&value, sizeof(int), 1, fp);
    if (objectsWritten != 1) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error writing int to archive: %s", strerror(errno)]];
    }
}

- (void)writeDouble:(double)value {
#ifdef EC_ARCHIVE_LOG
    fprintf(debug_log, "Double: %.15f\n", value);
#endif
    size_t objectsWritten = fwrite(&value, sizeof(double), 1, fp);
    if (objectsWritten != 1) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error writing double to archive: %s", strerror(errno)]];
    }
}

#if __LP64__
struct CGSize32 {
    float width;
    float height;
};
struct CGPoint32 {
    float x;
    float y;
};
struct CGRect32 {
    struct CGPoint32 origin;
    struct CGSize32 size;
};
#endif

- (void)writeRect:(CGRect)value {
#ifdef EC_ARCHIVE_LOG
    fprintf(debug_log, "Rect: (%.15f, %.15f, %.15f, %.15f)\n", value.origin.x, value.origin.y, value.size.width, value.size.height);
#endif
#if __LP64__
    struct CGRect32 value32;
    value32.origin.x = value.origin.x;
    value32.origin.y = value.origin.y;
    value32.size.width = value.size.width;
    value32.size.height = value.size.height;
    size_t objectsWritten = fwrite(&value32, sizeof(struct CGRect32), 1, fp);
#else
    size_t objectsWritten = fwrite(&value, sizeof(CGRect), 1, fp);
#endif
    if (objectsWritten != 1) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error writing rect to archive: %s", strerror(errno)]];
    }
}

- (void)writeSize:(CGSize)value {
#ifdef EC_ARCHIVE_LOG
    fprintf(debug_log, "Size: (%.15f, %.15f)\n", value.width, value.height);
#endif
#if __LP64__
    struct CGSize32 value32;
    value32.width = value.width;
    value32.height = value.height;
    size_t objectsWritten = fwrite(&value32, sizeof(struct CGSize32), 1, fp);
#else
    size_t objectsWritten = fwrite(&value, sizeof(CGSize), 1, fp);
#endif
    if (objectsWritten != 1) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error writing size to archive: %s", strerror(errno)]];
    }
}

- (void)writePoint:(CGPoint)value {
#ifdef EC_ARCHIVE_LOG
    fprintf(debug_log, "Point: (%.15f, %.15f)\n", value.x, value.y);
#endif
#if __LP64__
    struct CGPoint32 value32;
    value32.x = value.x;
    value32.y = value.y;
    size_t objectsWritten = fwrite(&value32, sizeof(struct CGPoint32), 1, fp);
#else
    size_t objectsWritten = fwrite(&value, sizeof(CGPoint), 1, fp);
#endif
    if (objectsWritten != 1) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error writing rect to archive: %s", strerror(errno)]];
    }
}

- (void)writeInstructionStream:(EBVMInstructionStream *)value usingVirtualMachine:(EBVirtualMachine *)vm {
#ifdef EC_ARCHIVE_LOG
    fprintf(debug_log, "Instruction Stream:\n");
    [value printToOutputFile:debug_log withIndentLevel:1 fromVirtualMachine:vm];
#endif
#ifndef ESVM_BRIDGE
    if (!vm->errorDelegate) {
	vm->errorDelegate = [ECErrorReporter theErrorReporter];
    }
#endif
    if (value) {
	[value writeInstructionStreamToFile:fp forVirtualMachine:vm];
    } else {
	[self writeInteger:0];
    }

}

- (void)writeString:(NSString *)string {
    if (string) {
	int length = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	[self writeInteger:length];
#ifdef EC_ARCHIVE_LOG
	fprintf(debug_log, "String: '%s'\n", [string UTF8String]);
#endif
	if (length) {
	    size_t objectsWritten = fwrite([string UTF8String], length, 1, fp);
	    if (objectsWritten != 1) {
		[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error writing string to archive: %s", strerror(errno)]];
	    }
	}
    } else {
#ifdef EC_ARCHIVE_LOG
	fprintf(debug_log, "String: NULL\n");
#endif
	[self writeInteger:0];
    }
}

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
				enabledControl:(ECButtonEnabledControl)enabledControl {
    [self writeInteger:frontTextureSlot];
    [self writeInteger:backTextureSlot];
    [self writeInteger:nightTextureSlot];
    [self writeRect:boundsOnScreen];
    [self writePoint:anchorOnScreen];
    [self writeDouble:updateInterval];
    [self writeDouble:updateIntervalOffset];
    [self writeInteger:(int)updateTimer];
    [self writeInteger:modeMask];
    [self writeInteger:handKind];
    [self writeInteger:(int)dragType];
    [self writeInteger:(int)dragAnimationType];
    [self writeDouble:animSpeed];
    [self writeInteger:(int)animDir];
    [self writeInteger:grabPrio];
    [self writeInteger:envSlot];
    [self writeInteger:(int)specialness];
    [self writeInteger:(int)specialParameter];
    [self writeInteger:norotate];
    [self writeInteger:cornerRelative];
    [self writeInteger:(flipOnBack ? 1 : 0)];
    [self writeInteger:(flipX ? 1 : 0)];
    [self writeInteger:(flipY ? 1 : 0)];
    [self writeInteger:(centerPixelOnly ? 1 : 0)];
    [self writeInstructionStream:angleInstructionStream usingVirtualMachine:vm];
    [self writeInstructionStream:xOffsetInstructionStream usingVirtualMachine:vm];
    [self writeInstructionStream:yOffsetInstructionStream usingVirtualMachine:vm];
    [self writeDouble:offsetRadius];
    [self writeInstructionStream:offsetAngleInstructionStream usingVirtualMachine:vm];
    [self writeInstructionStream:actionInstructionStream usingVirtualMachine:vm];
    [self writeInteger:repeatStrategy];
    [self writeInteger:(immediate ? 1 : 0)];
    [self writeInteger:(expanded ? 1 : 0)];
    [self writeInteger:masterIndex];
    [self writeInteger:(int)enabledControl];
}

- (void)logName:(NSString *)name {
#ifdef EC_ARCHIVE_LOG
    fprintf(debug_log, "**** Part %s\n", [name UTF8String]);
#endif
}

- (void)seekToStart {
#ifdef EC_ARCHIVE_LOG
    fprintf(debug_log, "Seek to start\n");
#endif
    fflush(fp);
    int st = fseek(fp, 0, SEEK_SET);
    if (st != 0) {
#ifndef NDEBUG
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error seeking to start %s: %s", [path UTF8String], strerror(errno)]];
#else
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error seeking to start: %s", strerror(errno)]];
#endif
    }
}

- (void)finishWriting {
    int status = fclose(fp);
    if (status != 0) {
#ifndef NDEBUG
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error closing archive %s: %s", [path UTF8String], strerror(errno)]];
#else
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error closing archive: %s", strerror(errno)]];
#endif
    }
#ifdef EC_ARCHIVE_LOG
    fclose(debug_log);
#endif
#ifndef NDEBUG
    [path release];
#endif
}

- (id)initForReadingFromPath:(NSString *)p {
    [super init];
#ifndef NDEBUG
    path = [p retain];
#endif
    fp = fopen([p UTF8String], "r");
    if (!fp) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error opening archive %@: %s", p, strerror(errno)]];
    }
    // printf("Archive opened path %s\n", [path UTF8String]);
    return self;
}

- (void)reportReadErrorForType:(const char *)dataType {
#ifndef NDEBUG
    if (feof(fp)) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"End of file trying to read %s from archive %@", dataType, path]];
    } else {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error reading %s from archive %@: %s", dataType, path, strerror(errno)]];
    }
#else
    if (feof(fp)) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"End of file trying to read %s from archive", dataType]];
    } else {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error reading %s from archive: %s", dataType, strerror(errno)]];
    }
#endif
}

- (int)readInteger {
    int value;
    size_t objectsRead = fread(&value, sizeof(int), 1, fp);
    if (objectsRead != 1) {
	[self reportReadErrorForType:"int"];
    }
    // printf("Archive returning integer %d\n", value);
    return value;
}

- (double)readDouble {
    double value;
    size_t objectsRead = fread(&value, sizeof(double), 1, fp);
    if (objectsRead != 1) {
	[self reportReadErrorForType:"double"];
    }
    // printf("Archive returning double %.4f\n", value);
    return value;
}

- (CGRect)readRect {
    CGRect value;
#if __LP64__
    struct CGRect32 value32;
    size_t objectsRead = fread(&value32, sizeof(struct CGRect32), 1, fp);
    value.origin.x = value32.origin.x;
    value.origin.y = value32.origin.y;
    value.size.width = value32.size.width;
    value.size.height = value32.size.height;
#else
    size_t objectsRead = fread(&value, sizeof(CGRect), 1, fp);
#endif
    if (objectsRead != 1) {
	[self reportReadErrorForType:"rect"];
    }
    return value;
}

- (CGSize)readSize {
    CGSize value;
#if __LP64__
    struct CGSize32 value32;
    size_t objectsRead = fread(&value32, sizeof(struct CGSize32), 1, fp);
    value.width = value32.width;
    value.height = value32.height;
#else
    size_t objectsRead = fread(&value, sizeof(CGSize), 1, fp);
#endif
    if (objectsRead != 1) {
	[self reportReadErrorForType:"size"];
    }
    return value;
}

- (CGPoint)readPoint {
    CGPoint value;
#if __LP64__
    struct CGPoint32 value32;
    size_t objectsRead = fread(&value32, sizeof(struct CGPoint32), 1, fp);
    value.x = value32.x;
    value.y = value32.y;
#else
    size_t objectsRead = fread(&value, sizeof(CGPoint), 1, fp);
#endif
    if (objectsRead != 1) {
	[self reportReadErrorForType:"point"];
    }
    return value;
}

- (EBVMInstructionStream *)readInstructionStreamForVirtualMachine:(EBVirtualMachine *)virtualMachine {
#ifndef ESVM_BRIDGE
    if (!virtualMachine->errorDelegate) {
	virtualMachine->errorDelegate = [ECErrorReporter theErrorReporter];
    }
#endif
    int streamLength;
    size_t objectsRead = fread(&streamLength, sizeof(int), 1, fp);
    if (objectsRead != 1) {
	[self reportReadErrorForType:"instruction stream length"];
	return nil;
    }
    if (streamLength == 0) {
	return nil;
    }
    EBVMInstructionStream *stream = [[[EBVMInstructionStream alloc] initFromFilePointer:fp withStreamLength:streamLength forVirtualMachine:virtualMachine pathForDebugMsgs:path] autorelease];
    // printf("Archive returning instruction stream:\n");
    // [stream printToOutputFile:stdout withIndentLevel:1 fromVirtualMachine:virtualMachine];
    return stream;
}

- (NSString *)readString {
    int stringLength;
    size_t objectsRead = fread(&stringLength, sizeof(int), 1, fp);
    if (objectsRead != 1) {
	[self reportReadErrorForType:"string length"];
	return nil;
    }
    if (stringLength == 0) {
	return nil;
    }
#define BUFSIZE (1024)
    char buf[BUFSIZE + 1];
    char *bufptr = buf;
    if (stringLength > BUFSIZE) {
	bufptr = (char *)malloc(stringLength + 1);
    }
    objectsRead = fread(bufptr, stringLength, 1, fp);
    if (objectsRead != 1) {
	[self reportReadErrorForType:"string"];
	return nil;
    }
    bufptr[stringLength] = '\0';
    // printf("Archive read string characters as '%s'\n", bufptr);
    NSString *string = [NSString stringWithUTF8String:bufptr];
    if (bufptr != buf) {
	free(bufptr);
    }
    if ((int)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding] != stringLength) {
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"String length (%lu) didn't match expected length (%d)", (unsigned long)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], stringLength]];
    }
    return string;
}

- (void)readDataInto:(void *)dataLocation numberOfBytes:(int)numberOfBytes {
    size_t objectsRead = fread(dataLocation, numberOfBytes, 1, fp);
    if (objectsRead != 1) {
	[self reportReadErrorForType:"raw data"];
    }
}

- (void)readWatchPartDataWithFrontTextureSlot:(int*)frontTextureSlot
			      backTextureSlot:(int*)backTextureSlot
			     nightTextureSlot:(int*)nightTextureSlot
			       boundsOnScreen:(CGRect*)boundsOnScreen
			       anchorOnScreen:(CGPoint*)anchorOnScreen
			       updateInterval:(double*)updateInterval
			 updateIntervalOffset:(double*)updateIntervalOffset
				  updateTimer:(ECWatchTimerSlot *)updateTimer
				     modeMask:(int*)modeMask
				     handKind:(int*)handKind
				     dragType:(ECDragType*)dragType
			    dragAnimationType:(ECDragAnimationType*)dragAnimationType
				    animSpeed:(double*)animSpeed
				      animDir:(ECAnimationDirection*)animDir
				     grabPrio:(int*)grabPrio
				      envSlot:(int*)envSlot
				  specialness:(ECPartSpecialness*)specialness
			     specialParameter:(unsigned int*)specialParameter
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
			       enabledControl:(ECButtonEnabledControl *)enabledControl {
    *frontTextureSlot = [self readInteger];
    *backTextureSlot = [self readInteger];
    *nightTextureSlot = [self readInteger];
    *boundsOnScreen = [self readRect];
    *anchorOnScreen = [self readPoint];
    *updateInterval = [self readDouble];
    *updateIntervalOffset = [self readDouble];
    *updateTimer = (ECWatchTimerSlot)[self readInteger];
    *modeMask = [self readInteger];
    *handKind = [self readInteger];
    *dragType = (ECDragType)[self readInteger];
    *dragAnimationType = (ECDragAnimationType)[self readInteger];
    *animSpeed = [self readDouble];
    *animDir = (ECAnimationDirection)[self readInteger];
    *grabPrio = [self readInteger];
    *envSlot = [self readInteger];
    *specialness = (ECPartSpecialness)[self readInteger];
    *specialParameter = (unsigned int)[self readInteger];
    *norotate = [self readInteger];
    *cornerRelative = [self readInteger];
    *flipOnBack = [self readInteger] ? true : false;
    *flipX = [self readInteger] ? true : false;
    *flipY = [self readInteger] ? true : false;
    *centerPixelOnly = [self readInteger] ? true : false;
    *angleInstructionStream = [self readInstructionStreamForVirtualMachine:vm];
    *xOffsetInstructionStream = [self readInstructionStreamForVirtualMachine:vm];
    *yOffsetInstructionStream = [self readInstructionStreamForVirtualMachine:vm];
    *offsetRadius = [self readDouble];
    *offsetAngleInstructionStream = [self readInstructionStreamForVirtualMachine:vm];
    *actionInstructionStream = [self readInstructionStreamForVirtualMachine:vm];
    *repeatStrategy = [self readInteger];
    *immediate = [self readInteger] ? true : false;
    *expanded = [self readInteger] ? true : false;
    *masterIndex = [self readInteger];
    *enabledControl = (ECButtonEnabledControl)[self readInteger];
}

- (void)finishReading {
    int status = fclose(fp);
    if (status != 0) {
#ifndef NDEBUG
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error closing archive %s: %s", [path UTF8String], strerror(errno)]];
#else
	[[ECErrorReporter theErrorReporter] reportError:[NSString stringWithFormat:@"Error closing archive: %s", strerror(errno)]];
#endif
    }
#ifndef NDEBUG
    [path release];
#endif
}


@end
