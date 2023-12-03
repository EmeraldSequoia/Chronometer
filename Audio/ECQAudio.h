//
//  ECQAudio.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 2/2009.
//  Copyright Emerald Sequoia LLC 2009. All rights reserved.
//

// Interface for an audio queue to play one sound at a time

#import <AudioToolbox/AudioToolbox.h>

#define kECNAudioBuffers 3

typedef struct ECQAudioPlayerState {
    AudioStreamBasicDescription   mDataFormat;
    AudioQueueRef                 mQueue;
    AudioQueueBufferRef           mBuffers[kECNAudioBuffers];
    AudioFileID                   mAudioFile;
    UInt32                        bufferByteSize;
    SInt64                        mCurrentPacket;
    UInt32                        mNumPacketsToRead;
    AudioStreamPacketDescription  *mPacketDescs;
    bool                          mIsRunning;
    bool                          started;
    bool                          hibernateWhenFinished;
    bool                          restart;
} ECQAudioPlayerState;

@interface ECQAudio : NSObject {
    ECQAudioPlayerState *playerState;
}

-(id)init;

-(bool)setupForURL:(CFURLRef)url;
-(void)setupForFile:(NSString *)filename;
-(void)setupForResourceNamed:(CFStringRef)resourceName withType:(CFStringRef)resourceType;
-(void)playSound;  
-(void)hibernateWhenFinished;

@end
