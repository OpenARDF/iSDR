/*
 Third-party provenance: portions of this file are derived from Apple's
 multichannel mixer sample code.

 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*
 File: MultichannelMixerController.h
 Abstract: The Controller Class for the AUGraph.
 Version: 1.0.2

 This software is provided by OpenARDF on an "AS IS" basis.
 OPENARDF MAKES NO WARRANTIES, EXPRESS OR IMPLIED,
 INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE
 SOFTWARE OR ITS USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL OPENARDF BE LIABLE FOR ANY SPECIAL,
 INDIRECT, INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE,
 REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE OPENARDF SOFTWARE,
 HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF OPENARDF HAS BEEN
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

 Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.

 */
#ifndef __MULTICHANNELMIXERCONTROLLER_H__
#define __MULTICHANNELMIXERCONTROLLER_H__


//#ifdef __cplusplus
//extern "C" {
//#endif


#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioFile.h>

#import "product.h"
#import "CAStreamBasicDescription.h"
#import "FFTBufferManager.h"
#import "dspThread.h"
#import "AULevelMeter.h"
#import "FileHandler.h"
#import "AudioBufferUtilities.h"

const Float64 kGraphSampleRate = 44100.0;

typedef enum iSDRAudioReady {
	AudioError,
	AudioNotReady,
	AudioReady
} iSDRAudioStatus;


typedef enum iSDRAudioState {
	AudioNotBusy = 0,
	AudioBusy = 1,
	AudioReadState
} iSDRAudioState;


typedef enum iSDRAudioMode {
	AudioModeUnknown,
	AudioModeDemonstration,
	AudioModeMonaural,
	AudioModeStereo
} iSDRAudioMode;


@protocol MultichannelMixerControllerDelegate
@required
- (void)reconfigureDisplaySetup:(UInt32)reason;
@optional
- (void)showMPVolumeView;
@end

@interface MultichannelMixerController : NSObject
{
	AUGraph						mAudioGraph;
	AudioUnit					mMixerUnit;
	iSDRAudioStatus				audioStatus;
	iSDRAudioMode				mAudioMode;
	BOOL						mLiveAudioAllowed;
	BOOL						mAutoconfigEnabled;
	BOOL						mAudioBlocked;
	BOOL						mAudioFlowTurnedOn;
	__unsafe_unretained AULevelMeter*	mcMixerUser;
	AudioFileID					mAudioFile;
	CAStreamBasicDescription	mStreamDesc;

	CAStreamBasicDescription	mClientFormat;
	CAStreamBasicDescription	mOutputFormat;


	__unsafe_unretained id		vController;

	AudioUnit					mRemoteIOUnit;

	UInt32						mCurrentHardwareInputNumberChannels;

	SoundBuffer*				mSoundBuffer0;
	SoundBuffer*				mSoundBuffer1;
	UInt32						mActiveFileBufferIndex;
	int							mEmptyBuffers;
	ExtAudioFileRef				mXafref;
	FileHandler*				fileHandler;

//	NSArray*					soundBufferArray;

	FFTBufferManager*			fftBufferManager;
	dspThread*					audioDSPThread;
#ifndef DISABLE_HPF
	DCRejectionFilter*			dcFilter;
#endif
	CAStreamBasicDescription	thruFormat;

	BOOL						mute;
	BOOL						noisefilter;

	AURenderCallbackStruct		rcbs;
	AURenderCallback			mRenderCallback;
	Float64						hwSampleRate;
	UInt32						sampleRateBandwidth;

	BOOL						sendRawPCM;
	id							receiverPCM;

	UInt16						morseKey;

@private
	id <MultichannelMixerControllerDelegate> delegate;
	BOOL						morseRunning;
	NSURL*						mActiveFileURL;

#ifdef SDR_DEBUG
	UInt32						_maxSamplesPerRender;
	UInt32						_minSamplesPerRender;
#endif

	SystemSoundID				buttonPressSound;
	SystemSoundID				errorSound;
	SystemSoundID				successSound;
}

@property (assign) id <MultichannelMixerControllerDelegate>	delegate;
@property (nonatomic, assign)	UInt16						morseKey;
@property (nonatomic, assign)	AULevelMeter*				mcMixerUser;
@property (nonatomic, retain)	FileHandler*				fileHandler;

@property (nonatomic, readonly) iSDRAudioMode				mAudioMode;
@property (nonatomic, readonly) iSDRAudioStatus				audioStatus;
@property (nonatomic, assign)	SoundBuffer*				mSoundBuffer0;
@property (nonatomic, assign)	SoundBuffer*				mSoundBuffer1;
@property (nonatomic, assign)	int							mEmptyBuffers;
@property (nonatomic, assign)	ExtAudioFileRef				mXafref;
//@property (nonatomic, retain)	NSArray*					soundBufferArray;

@property (nonatomic, readonly) UInt32						mCurrentHardwareInputNumberChannels;

@property (nonatomic, assign)	FFTBufferManager*			fftBufferManager;
@property (nonatomic, assign)	AudioUnit					mRemoteIOUnit;
@property (nonatomic, assign)	AudioUnit					mMixerUnit;
@property (nonatomic, assign)	dspThread*					audioDSPThread;
@property (nonatomic, assign)	BOOL						mLiveAudioAllowed;
@property (nonatomic, assign)	BOOL						mAutoconfigEnabled;
@property (nonatomic, assign)	BOOL						mAudioBlocked;
@property (nonatomic, assign)	BOOL						mAudioFlowTurnedOn;
@property (nonatomic, assign)	AudioFileID					mAudioFile;
@property (nonatomic, assign)   CAStreamBasicDescription	mStreamDesc;

#ifndef DISABLE_HPF
@property (nonatomic, assign)	DCRejectionFilter*			dcFilter;
#endif

@property (nonatomic, readonly) UInt32						sampleRateBandwidth;

@property (nonatomic, assign)	BOOL						mute;
@property (nonatomic, assign)	BOOL						noisefilter;
@property (nonatomic, assign)	id							vController;

- (id)initMMC;
- (BOOL)setupRIOGraph:(UInt32)CurrentHardwareInputNumberChannels;
- (OSStatus)setupAudioSession;
- (BOOL)setupAUGraph;
- (OSStatus)loadFile:(NSURL *)sourceURL setupIfNeeded:(BOOL)doSetup;
- (NSURL *)getCurrentFileURL;
- (FileStats*)getFileStats;

#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
- (OSStatus)setupAudioSession_old;
#endif

- (void)enableInput:(UInt32)inputNum isOn:(AudioUnitParameterValue)isONValue;

- (void)startAUGraph:(BOOL)overRide;
- (void)stopAUGraph:(BOOL)overRide;
- (float)getAvgPower;
- (BOOL)audioBusy:(iSDRAudioState)setting;

- (void)disableAllAudio;
- (void)reenableAudio;

- (BOOL)shutDownAudio;
- (bool)shutDownAudio_old;
- (void)adjustAudioRouting:(UInt32)reason;
//- (iSDRAudioMode)getAudioSupport;
- (void)killAllAudio;

- (void)playErrorSound;
- (void)playSuccessSound;
- (void)playKeypressSound;

#ifdef SDR_DEBUG
- (void)printAudioSetupResults:(iSDRAudioStatus)status numChans:(UInt32)CurrentHardwareInputNumberChannels;
- (char*)getDebugMessage;
- (void)printFileError:(OSStatus)result;
- (void)printExtAudioFileError:(OSStatus)result;
#endif

- (Float32)getAUGraphCPULoad;

@end


//#ifdef __cplusplus
//}
//#endif

#endif
