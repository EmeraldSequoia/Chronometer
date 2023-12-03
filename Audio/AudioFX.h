/*


*/

#import <Foundation/Foundation.h>

//CLASSES:

@class AudioFX;

//PROTOCOLS:

@protocol AudioFXDelegate <NSObject>
- (void) audioFXDidComplete:(AudioFX*)audioFX;
@end

//CLASS INTERFACES:

/*
This class wraps the AudioServices APIs from CoreAudio to allow playback of small sound files with no panning or volume controls.
Use this class to play casual sounds during user interface interaction (keyboard like, lock/unlock...).
Make sure the sound files are small and uncompressed or IMA.
When you have lots of small sounds and don't really care about the latency response when playing them, it's recommended to create and destroy AudioFX instances on demand instead of allocating them all upfront - or use the +playAtPath: method.
*/
@interface AudioFX : NSObject
{
@private
	UInt32					_soundID;
	NSInteger				_tag;
	id<AudioFXDelegate>		_delegate;
	bool					_hasCallback;
}
#if TARGET_OS_IPHONE
+ (void) vibrate; //iPhone only
#endif

+ (bool) playAtPath:(NSString*)path; //One-shot sound playback

- (id) initWithPath:(NSString*)path; //If the path is not absolute, it is assumed to be relative to the main bundle's resources

@property NSInteger tag;

@property(assign) id<AudioFXDelegate> delegate;

- (void) play;
@end
