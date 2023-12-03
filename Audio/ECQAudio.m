
//  ECQAudio.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 2/2009.
//  Copyright Emerald Sequoia LLC 2009. All rights reserved.
//

// Interface for an audio queue to play one sound at a time

#import "ECQAudio.h"

@interface ECQAudio (ECQAudioPrivate)

-(void)releaseFileAndHibernate;

@end

@implementation ECQAudio

static NSLock *stateLock = nil;

-(id)init {
    [super init];
    playerState = NULL;
    if (!stateLock) {
	stateLock = [[NSLock alloc] init];
    }
    return self;
}

-(void)dealloc {
    if (playerState) {
	free(playerState);
    }
    [super dealloc];
}

-(void)makePlayerState {
    assert(!playerState);
    playerState = (ECQAudioPlayerState *)malloc(sizeof(ECQAudioPlayerState));
    playerState->mAudioFile = NULL;
    playerState->mQueue = NULL;
    playerState->mIsRunning = false;
    playerState->started = false;
    playerState->restart = false;
    playerState->hibernateWhenFinished = false;
}

-(void)freePlayerState {
    assert(playerState);
    free(playerState);
    playerState = NULL;
}

static void DeriveBufferSize(const AudioStreamBasicDescription *ASBDesc,
			     UInt32                            maxPacketSize,
			     Float64                           seconds,
			     UInt32                            *outBufferSize,
			     UInt32                            *outNumPacketsToRead) {
    static const int maxBufferSize = 0x50000;   // 327,680
    static const int minBufferSize = 0x4000;    //  16,384
 
    if (ASBDesc->mFramesPerPacket != 0) {
        Float64 numPacketsForTime =
            ASBDesc->mSampleRate / ASBDesc->mFramesPerPacket * seconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    } else {
        *outBufferSize =
            maxBufferSize > maxPacketSize
	    ? maxBufferSize
	    : maxPacketSize;
    }
 
    if (*outBufferSize > maxBufferSize &&
        *outBufferSize > maxPacketSize) {
        *outBufferSize = maxBufferSize;
    } else {
        if (*outBufferSize < minBufferSize) {
            *outBufferSize = minBufferSize;
	}
    }
    *outNumPacketsToRead = *outBufferSize / maxPacketSize;
}

-(void)handleOutputBuffer:(AudioQueueBufferRef)inBuffer forQueue:(AudioQueueRef)inAQ {
//    printf("handleOutputBuffer, thread 0x%08x\n", (unsigned int)[NSThread currentThread]);
    [stateLock lock];
    if (!playerState) {
	[stateLock unlock];
	return;
    }
    if (playerState->restart) {
	printf("hOB restarting A\n");
	playerState->mCurrentPacket = 0;
	playerState->restart = false;
    }
    [stateLock unlock];
    UInt32 numBytesReadFromFile;
    UInt32 numPackets = playerState->mNumPacketsToRead;
    OSStatus status = AudioFileReadPackets(playerState->mAudioFile,
					   false,  // don't cache
					   &numBytesReadFromFile,
					   playerState->mPacketDescs, 
					   playerState->mCurrentPacket,
					   &numPackets,
					   inBuffer->mAudioData);
    if (status != 0) {
#ifndef NDEBUG
	printf("AudioFileReadPackets error: %d\n", (int)status);
#endif
	return;
    }
    if (numPackets > 0) {
        inBuffer->mAudioDataByteSize = numBytesReadFromFile;
	AudioQueueEnqueueBuffer(playerState->mQueue,
				inBuffer,
				(playerState->mPacketDescs ? numPackets : 0),
				playerState->mPacketDescs);
	if (status != 0) {
#ifndef NDEBUG
	    printf("AudioQueueEnqueueBuffer error: %d\n", (int)status);
#endif
	    return;
	}
	[stateLock lock];
	if (playerState->restart) {
	    printf("hOB restarting B\n");
	    playerState->mCurrentPacket = 0;
	    playerState->restart = false;
	} else {
	    playerState->mCurrentPacket += numPackets;
	}
	[stateLock unlock];
    } else {
	[stateLock lock];
	if (playerState->restart) {
	    printf("hOB restarting C\n");
	    playerState->mCurrentPacket = 0;
	    playerState->restart = false;
	} else {
	    playerState->started = false;
	    status = AudioQueueStop(playerState->mQueue,	false); // not immediate
	    if (status != 0) {
#ifndef NDEBUG
		printf("AudioQueueStop error: %d\n", (int)status);
#endif
	    }
	}
	[stateLock unlock];
    }
}

-(void)changedProperty:(AudioQueuePropertyID)property forQueue:(AudioQueueRef)queue {
//    printf("changedProperty, thread 0x%08x\n", (unsigned int)[NSThread currentThread]);
    assert(property == kAudioQueueProperty_IsRunning);
    UInt32 qIsRunning;
    UInt32 qIsRunningSize = sizeof(qIsRunning);
    OSStatus status = AudioQueueGetProperty(queue, property, &qIsRunning, &qIsRunningSize);
    if (status != 0) {
#ifndef NDEBUG
	printf("AudioQueueGetProperty error: %d\n", (int)status);
#endif
    }
    [stateLock lock];
    playerState->mIsRunning = (qIsRunning != 0);
#ifndef NDEBUG
    printf("Audio queue %s\n", playerState->mIsRunning ? "STARTED" : "STOPPED");
#endif
    if (!playerState->mIsRunning && playerState->hibernateWhenFinished) {
	[self releaseFileAndHibernate];
    }
    [stateLock unlock];
}

static void handleOutputBuffer (void                *aqData,
				AudioQueueRef       inAQ,
				AudioQueueBufferRef inBuffer) {
    ECQAudio *qaudio = (ECQAudio *)aqData;
    [qaudio handleOutputBuffer:inBuffer forQueue:inAQ];
}

static void propertyListener(void                 *inUserData,
			     AudioQueueRef        inAQ,
			     AudioQueuePropertyID propertyID) {
    ECQAudio *qaudio = (ECQAudio *)inUserData;
    [qaudio changedProperty:propertyID forQueue:inAQ];
}

-(bool)setupForURL:(CFURLRef)audioFileURL {
//    printf("setupForURL, thread 0x%08x\n", (unsigned int)[NSThread currentThread]);
#ifndef NDEBUG
    static const int bufSize = 2048;
    UInt8 filename[bufSize];
    CFURLGetFileSystemRepresentation(audioFileURL, true, filename, bufSize);
#endif
    [stateLock lock];
    if (!playerState) {
	[self makePlayerState];
    }
    [stateLock unlock];
    OSStatus status = AudioFileOpenURL(audioFileURL,
				       kAudioFileReadPermission,
				       0,
				       &playerState->mAudioFile);
    if (status != 0) {
#ifndef NDEBUG
	printf("AudioFileOpenURL error for file %s: %d\n", filename, (int)status);
#endif
	return false;
    }

    // Get the file's data format
    UInt32 dataFormatSize = sizeof(playerState->mDataFormat);
    status = AudioFileGetProperty(playerState->mAudioFile,
				  kAudioFilePropertyDataFormat,
				  &dataFormatSize,
				  &playerState->mDataFormat);
    if (status != 0) {
#ifndef NDEBUG
	printf("AudioFileGetProperty(1) error for file %s: %d\n", filename, (int)status);
#endif
	AudioFileClose(playerState->mAudioFile);
	playerState->mAudioFile = NULL;
	return false;
    }

    UInt32 maxPacketSize;
    UInt32 propertySize = sizeof(maxPacketSize);
    status = AudioFileGetProperty (playerState->mAudioFile,
				   kAudioFilePropertyPacketSizeUpperBound,
				   &propertySize,
				   &maxPacketSize);
    if (status != 0) {
#ifndef NDEBUG
	printf("AudioFileGetProperty(2) error for file %s: %d\n", filename, (int)status);
#endif
	AudioFileClose(playerState->mAudioFile);
	playerState->mAudioFile = NULL;
	return false;
    }

 
    DeriveBufferSize(&playerState->mDataFormat,
		     maxPacketSize,
		     0.1,  // seconds
		     &playerState->bufferByteSize,
		     &playerState->mNumPacketsToRead);

    bool isFormatVBR = playerState->mDataFormat.mBytesPerPacket == 0 ||
	               playerState->mDataFormat.mFramesPerPacket == 0;
 
    if (isFormatVBR) {
	playerState->mPacketDescs = (AudioStreamPacketDescription *)malloc (playerState->mNumPacketsToRead * sizeof(AudioStreamPacketDescription));
    } else {
	playerState->mPacketDescs = NULL;
    }

    // Create a playback queue
    status = AudioQueueNewOutput(&playerState->mDataFormat,
				 handleOutputBuffer,
				 self,
				 NULL, // use queue's internal thread's run loop
				 kCFRunLoopCommonModes,
				 0,    // reserved, must be 0
				 &playerState->mQueue);
    if (status != 0) {
#ifndef NDEBUG
	printf("AudioQueueNewOutput error for file %s: %d\n", filename, (int)status);
#endif
	AudioFileClose(playerState->mAudioFile);
	playerState->mAudioFile = NULL;
	if (playerState->mPacketDescs) {
	    free(playerState->mPacketDescs);
	    playerState->mPacketDescs = NULL;
	}
	return false;
    }

    // Some files (e.g., MPEG 4 AAC) require a "magic cookie", "to contain audio metadata"
    UInt32 cookieSize = sizeof (UInt32);
    status = AudioFileGetPropertyInfo(playerState->mAudioFile,
				      kAudioFilePropertyMagicCookieData,
				      &cookieSize,
				      NULL);
 
    if (status == 0 && cookieSize) {
	char* magicCookie = (char *)malloc(cookieSize);
 
	status = AudioFileGetProperty(playerState->mAudioFile,
				      kAudioFilePropertyMagicCookieData,
				      &cookieSize,
				      magicCookie);
	if (status == 0) {
#ifndef NDEBUG
	    printf("AudioFileGetProperty(3) error for file %s: %d\n", filename, (int)status);
#endif
	    [self releaseFileAndHibernate];
	    return false;
	}
	status = AudioQueueSetProperty(playerState->mQueue,
				       kAudioQueueProperty_MagicCookie,
				       magicCookie,
				       cookieSize);
	free(magicCookie);
	if (status == 0) {
#ifndef NDEBUG
	    printf("AudioQueueSetProperty error for file %s: %d\n", filename, (int)status);
	    [self releaseFileAndHibernate];
#endif
	}
    }

    playerState->mCurrentPacket = 0;
 
    for (int i = 0; i < kECNAudioBuffers; ++i) {
	status = AudioQueueAllocateBuffer(playerState->mQueue, playerState->bufferByteSize, &playerState->mBuffers[i]);
	if (status != 0) {
#ifndef NDEBUG
	    printf("AudioFileGetProperty(3) error for file %s: %d\n", filename, (int)status);
#endif
	    [self releaseFileAndHibernate];
	    return false;
	}
	[self handleOutputBuffer:playerState->mBuffers[i] forQueue:playerState->mQueue];
    }
    UInt32 numberOfFramesPrepared;
    status = AudioQueuePrime(playerState->mQueue, 0, &numberOfFramesPrepared);
    if (status != 0) {
#ifndef NDEBUG
	printf("AudioQueuePrime error for file %s: %d\n", filename, (int)status);
#endif
    }
    printf("primed %d frames\n", (int)numberOfFramesPrepared);

    Float32 gain = 1.0;    // Full gain; maybe should try to use a setting?
    status = AudioQueueSetParameter(playerState->mQueue, kAudioQueueParam_Volume, gain);
    if (status != 0) {
#ifndef NDEBUG
	printf("AudioQueueSetParameter error for file %s: %d\n", filename, (int)status);
#endif
	[self releaseFileAndHibernate];
	return false;
    }

    status = AudioQueueAddPropertyListener(playerState->mQueue, kAudioQueueProperty_IsRunning, propertyListener, self);
    if (status != 0) {
#ifndef NDEBUG
	printf("AudioQueueAddPropertyListener error for file %s: %d\n", filename, (int)status);
#endif
	[self releaseFileAndHibernate];
	return false;
    }
    return true;
}


-(void)releaseFileAndHibernate {
    AudioFileClose(playerState->mAudioFile);
    playerState->mAudioFile = NULL;
    if (playerState->mPacketDescs) {
	free(playerState->mPacketDescs);
	playerState->mPacketDescs = NULL;
    }
    AudioQueueDispose(playerState->mQueue, true/*immediate*/);
    playerState->mQueue = NULL;
    [self freePlayerState];
}

-(void)playSound {
    [stateLock lock];
    if (playerState && playerState->mAudioFile && playerState->mQueue) {
	if (playerState->started) {
	    // Queue is still running
	    playerState->restart = true;
	    printf("playSound setting restart\n");
	    [stateLock unlock];
	    return;
	}
	playerState->started = true;
	[stateLock unlock];
	OSStatus status = AudioQueueStart(playerState->mQueue, NULL/*immediately*/);
#ifndef NDEBUG
	if (status != 0) {
	    printf("AudioQueueStart error: %d\n", (int)status);
	}
#endif
#ifndef NDEBUG
    } else {
	[stateLock unlock];
	printf("Trying to play a sound with no audio file set up\n");
#endif
    }
}

-(void)setupForFile:(NSString *)filename {
    // Open the file
    CFURLRef audioFileURL = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault,
								    (UInt8 *)[filename UTF8String],
								    [filename length],
								    false);
    [self setupForURL:audioFileURL];
    CFRelease(audioFileURL);
}

-(void)setupForResourceNamed:(CFStringRef)resourceName withType:(CFStringRef)resourceType {
    CFURLRef audioFileURL = CFBundleCopyResourceURL(CFBundleGetMainBundle(), resourceName, resourceType, NULL);
    [self setupForURL:audioFileURL];
    CFRelease(audioFileURL);
}

-(void)hibernateWhenFinished {
    [stateLock lock];
    if (playerState) {
	if (playerState->mIsRunning) {
	    playerState->hibernateWhenFinished = true;
	} else {
	    [self releaseFileAndHibernate];
	}
    }
    [stateLock unlock];
}

@end
