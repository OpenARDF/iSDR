//
//  FileHandler.h
//  iSDR
//
//  Copyright (c) 2011-2026 OpenARDF. Licensed under the MIT License.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioFile.h>

#import "product.h"
#import "CAStreamBasicDescription.h"

#define AUDIOBUFFER0 0x1
#define AUDIOBUFFER1 0x2
#define MAX_AUDIOBUFFERSIZE_FRAMES 51200
#define FILLDELAY (0.01)

typedef struct {
	AudioStreamBasicDescription asbd;
#ifdef __IPHONE_8_0
	AUDIO_UNIT_SAMPLE_TYPE *data;
#else
	AudioUnitSampleType *data;
#endif
	UInt32 numFrames;
	UInt32 sampleNum;
} SoundBuffer, *SoundBufferPtr;

@interface FileStats : NSObject
@property (nonatomic, assign) float fileLengthInFrames;
@property (nonatomic, assign) float framesRead;
@property (nonatomic, assign) float frameRate;
@property (nonatomic, assign) float frameRateScaleFactor;
@property (nonatomic, assign) float filePlayTime;
@property (nonatomic, assign) float centerFrequency;
@property (nonatomic, assign) SInt16 amplitudeScaleFactor;
@property (nonatomic, assign) UInt32 channelsInFile;
@property (nonatomic, strong) NSString* fileName;
@end

@interface FileHandler : NSObject
{
	SoundBuffer*				soundBuffer0ptr;
	SoundBuffer*				soundBuffer1ptr;
	int*						bufferFlags;
	CAStreamBasicDescription	fileFormat;
	FileStats*					fileStats;

@private
	SoundBuffer					_SoundBuffer0;
	SoundBuffer					_SoundBuffer1;
	CAStreamBasicDescription	clientFormat;
	ExtAudioFileRef				_Xafref;
	NSTimer*					fillPeriodicTimer;
	NSTimer*					fillOnceTimer;
	float						timerInterval;
	BOOL						_isRunning;
	NSURL*						_currentFileURL;
}

@property (nonatomic, readonly)	SoundBuffer*				soundBuffer0ptr;
@property (nonatomic, readonly)	SoundBuffer*				soundBuffer1ptr;
@property (nonatomic, assign)	int*						bufferFlags;
@property (nonatomic, assign)	SoundBuffer					_SoundBuffer0;
@property (nonatomic, assign)	SoundBuffer					_SoundBuffer1;
@property (nonatomic, assign)	UInt32						channelsInFile;
@property (nonatomic, strong)	FileStats*					fileStats;

- (id)initFH;
- (OSStatus)loadFile:(NSURL *)sourceURL;
- (BOOL)loadBuffers;
- (void)fillBuffTimer:(TTimerCommand)command selector:(SEL)aSelector;
- (void)fillBuffOnceTimer:(TTimerCommand)command;
- (void)pauseFileReads;
- (void)resumeFileReads;
- (BOOL)isRunning;
- (void)fillFileBuffers;
- (NSURL *)getCurrentFileURL;
#ifdef SDR_DEBUG
- (void)printExtAudioFileError:(OSStatus)result;
#endif

@end
