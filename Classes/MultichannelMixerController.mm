/*
 Third-party provenance: portions of this file are derived from Apple's
 multichannel mixer sample code.

 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*
 File: MultichannelMixerController.mm
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
#import "MultichannelMixerController.h"
#import "EAGLViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/NSThread.h>
#import "iSDR_helper.h"
#include <atomic>
#include <new>

@interface MultichannelMixerController ()

- (void)handleAudioInterruption:(NSNotification *)notification;
- (void)registerForAudioSessionNotifications:(AVAudioSession *)session;
- (BOOL)ensureDSPResourcesForChannels:(int)channels;

@end

@implementation MultichannelMixerController
{
	BOOL	systemSoundMutingState;
}

@synthesize mAudioMode;
@synthesize audioStatus;
@synthesize fftBufferManager;
@synthesize mRemoteIOUnit;
@synthesize mMixerUnit;
@synthesize audioDSPThread;
@synthesize mute;
@synthesize noisefilter;
@synthesize sampleRateBandwidth;
@synthesize mSoundBuffer0, mSoundBuffer1; //, soundBufferArray;
@synthesize vController;
@synthesize mLiveAudioAllowed;
@synthesize mAutoconfigEnabled;
#ifndef DISABLE_HPF
@synthesize dcFilter;
#endif
@synthesize mAudioFile;
@synthesize mStreamDesc;
@synthesize mXafref;
@synthesize fileHandler;
@synthesize mCurrentHardwareInputNumberChannels;

EAGLViewController* vc;

#pragma mark- AUComponentDescription

// a simple wrapper for AudioComponentDescription
class AUComponentDescription : public AudioComponentDescription
{
public:
	AUComponentDescription()
	{
		componentType = 0;
		componentSubType = 0;
		componentManufacturer = 0;
		componentFlags = 0;
		componentFlagsMask = 0;
	};


	AUComponentDescription(OSType inType,
                           OSType inSubType,
                           OSType inManufacturer = 0,
                           unsigned long inFlags = 0,
                           unsigned long inFlagsMask = 0 )
	{
		componentType = inType;
		componentSubType = inSubType;
		componentManufacturer = inManufacturer;
		componentFlags = (UInt32)inFlags;
		componentFlagsMask = (UInt32)inFlagsMask;
	};

	AUComponentDescription(const AudioComponentDescription &inDescription)
    {
		*(AudioComponentDescription*)this = inDescription;
	};
};


#pragma mark -Audio Session Property Listener

#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
void audioPropListener_old(void *					inClientData,
					   AudioSessionPropertyID	inID,
					   UInt32					inDataSize,
					   const void *				inData)
{
	MultichannelMixerController *THIS = (__bridge MultichannelMixerController *)inClientData;

	if(inID == kAudioSessionProperty_AudioRouteChange)
	{
		/* TODO: when an external microphone gets removed, audioInterruptionListener gets called,
		 and it shuts off audio flow. That happens whether or not live audio is actually being used.
		 That is, audioInterruptionListener gets called when the microphone "disappears" even when
		 iSDR is in demoModeOnly. But audioInterruptionListener never gets called again in that case.
		 So audio is never restarted. We need to test for that condition, and restart audio here
		 if it is appropriate.

		 One way to do this might be to check whether a speaker is present and if we are in
		 demoMode. When those conditions are met, then audio can get restarted here. */

		try
		{
			CFDictionaryRef	routeChangeDictionary = (CFDictionaryRef)inData;

			UInt32 routeChangeReason;
			CFNumberRef routeChangeReasonRef = (CFNumberRef)CFDictionaryGetValue(routeChangeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_Reason));
			CFNumberGetValue(routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason);
			SDR_DEBUGPRINT(("Audio Route Change, Reason: %d\n", (int)routeChangeReason));

			if(THIS->mAutoconfigEnabled)
			{
				/*
				 enum {
				 kAudioSessionRouteChangeReason_Unknown                    = 0,
				 kAudioSessionRouteChangeReason_NewDeviceAvailable         = 1,  x
				 kAudioSessionRouteChangeReason_OldDeviceUnavailable       = 2,  x
				 kAudioSessionRouteChangeReason_CategoryChange             = 3,
				 kAudioSessionRouteChangeReason_Override                   = 4,
				 // this enum has no constant with a value of 5
				 kAudioSessionRouteChangeReason_WakeFromSleep              = 6,
				 kAudioSessionRouteChangeReason_NoSuitableRouteForCategory = 7   x
				 };
				 */

				SDR_DEBUGPRINT(("Changing route...\n"));

				switch(routeChangeReason)
				{
					case kAudioSessionRouteChangeReason_NoSuitableRouteForCategory:
						SDR_DEBUGPRINT(("kAudioSessionRouteChangeReason_NoSuitableRouteForCategory\n"));
						[THIS adjustAudioRouting_old:kAudioSessionRouteChangeReason_NoSuitableRouteForCategory];
						break;

					case kAudioSessionRouteChangeReason_NewDeviceAvailable:
						SDR_DEBUGPRINT(("kAudioSessionRouteChangeReason_NewDeviceAvailable\n"));
						[THIS adjustAudioRouting_old:kAudioSessionRouteChangeReason_NewDeviceAvailable];
						break;

					case kAudioSessionRouteChangeReason_OldDeviceUnavailable:
						SDR_DEBUGPRINT(("kAudioSessionRouteChangeReason_OldDeviceUnavailable!\n"));
						[THIS adjustAudioRouting_old:kAudioSessionRouteChangeReason_OldDeviceUnavailable];
						break;

					case kAudioSessionRouteChangeReason_WakeFromSleep:
						SDR_DEBUGPRINT(("kAudioSessionRouteChangeReason_WakeFromSleep!\n"));
						[THIS adjustAudioRouting_old:kAudioSessionRouteChangeReason_WakeFromSleep];
						break;

					case kAudioSessionRouteChangeReason_Override:
						SDR_DEBUGPRINT(("kAudioSessionRouteChangeReason_Override!\n"));
						[THIS adjustAudioRouting_old:kAudioSessionRouteChangeReason_Override];
						break;

					case kAudioSessionRouteChangeReason_CategoryChange:
						SDR_DEBUGPRINT(("kAudioSessionRouteChangeReason_CategoryChange!\n"));
						[THIS adjustAudioRouting_old:kAudioSessionRouteChangeReason_CategoryChange];
						break;

					case kAudioSessionRouteChangeReason_Unknown:
						SDR_DEBUGPRINT(("kAudioSessionRouteChangeReason_Unknown!\n"));
						[THIS adjustAudioRouting_old:kAudioSessionRouteChangeReason_Unknown];
						break;

					default:
						SDR_DEBUGPRINT(("Route change reason cannot be handled: %ld\n",routeChangeReason));
						break;
				}
			}
			else
			{
				SDR_DEBUGPRINT(("Cannot reconfigure audio route: mAutoconfigEnabled not enabled!\n"));
			}


		} catch (CAXException e) {
			char buf[256];
			fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		}
	}
	else if (inID == kAudioSessionProperty_AudioInputAvailable)
	{
		if(THIS->mAudioMode != AudioModeDemonstration)
		{
			SDR_DEBUGPRINT(("Audio lost while streaming! Take action?\n"));
		}
	}
}
#endif


#pragma mark -Audio Session Interruption Listener

static NSString* audioSessionCategory = nil;

void audioInterruptionListener(void *inClientData, UInt32 inInterruption)
{
	//	static BOOL holdMuteState=YES;

	SDR_DEBUGPRINT(("Session interrupted! --- %s ---\n", inInterruption == kAudioSessionBeginInterruption ? "Begin Interruption" : "End Interruption"));

	MultichannelMixerController *THIS = (__bridge MultichannelMixerController *)inClientData;

	//	SDR_DEBUGPRINT(("Audio interrupt: %ld\n",inInterruption));

	if(inInterruption == kAudioSessionEndInterruption)
	{
		SDR_DEBUGPRINT(("Audio interrupt ended.\n"));

		// make sure we are again the active session

		[[AVAudioSession sharedInstance] setActive:YES error:nil]; // shut down the audio session if it is active

		// restart  audio
		SDR_DEBUGPRINT(("Unblocking audio.\n"));
		[THIS startAUGraph:TRUE];
	}

	if(inInterruption == kAudioSessionBeginInterruption)
	{
		if((THIS->mAudioMode == AudioModeDemonstration) && (THIS->audioStatus == AudioReady))
		{
			SDR_DEBUGPRINT(("Audio interrupted: Taking no action.\n"));
		}
		else
		{
			SDR_DEBUGPRINT(("Audio interrupted: Blocking audio.\n"));
			[THIS stopAUGraph:TRUE];
		}
	}
}

#pragma mark -Audio Session Property Listener

- (void)registerForAudioSessionNotifications:(AVAudioSession *)session
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

	// Audio setup can run repeatedly as routes change. Replacing both observers
	// prevents a single system event from being delivered more than once.
	[notificationCenter removeObserver:self
							 name:AVAudioSessionRouteChangeNotification
						   object:session];
	[notificationCenter removeObserver:self
							 name:AVAudioSessionInterruptionNotification
						   object:session];
	[notificationCenter addObserver:self
						 selector:@selector(handleRouteChange:)
							 name:AVAudioSessionRouteChangeNotification
						   object:session];
	[notificationCenter addObserver:self
						 selector:@selector(handleAudioInterruption:)
							 name:AVAudioSessionInterruptionNotification
						   object:session];
}

- (void)handleAudioInterruption:(NSNotification *)notification
{
	NSNumber *typeValue = notification.userInfo[AVAudioSessionInterruptionTypeKey];
	if(typeValue == nil)
	{
		return;
	}

	AVAudioSessionInterruptionType interruptionType = (AVAudioSessionInterruptionType)typeValue.unsignedIntegerValue;
	if(interruptionType == AVAudioSessionInterruptionTypeBegan)
	{
		// Preserve whether audio had been flowing so startAUGraph: can restore
		// exactly that state when iOS permits the session to resume.
		if((mAudioMode != AudioModeDemonstration) || (audioStatus != AudioReady))
		{
			[self stopAUGraph:TRUE];
		}
		return;
	}

	AVAudioSessionInterruptionOptions options =
		(AVAudioSessionInterruptionOptions)[notification.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
	if((options & AVAudioSessionInterruptionOptionShouldResume) == 0)
	{
		return;
	}

	NSError *activationError = nil;
	if(![[AVAudioSession sharedInstance] setActive:YES error:&activationError])
	{
		NSLog(@"Unable to reactivate the audio session after interruption: %@", activationError.localizedDescription);
		return;
	}

	[self startAUGraph:TRUE];
}


- (void)handleRouteChange:(NSNotification *)notification
{
    UInt8 reasonValue = [[notification.userInfo valueForKey: AVAudioSessionRouteChangeReasonKey] intValue];

#ifdef SDR_DEBUG
	AVAudioSessionRouteDescription* previousRoute = [notification.userInfo valueForKey: AVAudioSessionRouteChangePreviousRouteKey];
	NSString* name = notification.name;
	SDR_DEBUGPRINT(("\n\n********************************************************************************************************\n"));
	SDR_DEBUGPRINT(("handleRouteChange name = %s; \nreasonValue: %ud; \npreviousRoute: %s\n\n", [name UTF8String], reasonValue, [previousRoute.description UTF8String]));
	//	id object = notification.object;
#endif

	AVAudioSession* session = [AVAudioSession sharedInstance];

	if(self.mAutoconfigEnabled)
	{
		switch(reasonValue)
		{
			case AVAudioSessionRouteChangeReasonUnknown:
			{
				SDR_DEBUGPRINT(("AVAudioSessionRouteChangeReasonUnknown!\n"));
				[self adjustAudioRouting:kAudioSessionRouteChangeReason_Unknown];
			}
				break;

			case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
			{
				SDR_DEBUGPRINT(("AVAudioSessionRouteChangeReasonNewDeviceAvailable\n"));
				[self adjustAudioRouting:kAudioSessionRouteChangeReason_NewDeviceAvailable];
			}
				break;


			case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
			{
				SDR_DEBUGPRINT(("AVAudioSessionRouteChangeReasonOldDeviceUnavailable!\n"));
				[self adjustAudioRouting:kAudioSessionRouteChangeReason_OldDeviceUnavailable];
			}
				break;


			case AVAudioSessionRouteChangeReasonCategoryChange:
			{
				if([session.category isEqualToString:audioSessionCategory])
				{
					SDR_DEBUGPRINT(("Audio session category is unchanged: ignoring notification. (%s)\n", [session.category UTF8String]));
				}
				else
				{
					SDR_DEBUGPRINT(("AVAudioSessionRouteChangeReasonCategoryChange! New category: %s\n", [session.category UTF8String]));
					[self adjustAudioRouting:kAudioSessionRouteChangeReason_CategoryChange];
					audioSessionCategory = session.category;
				}
			}
				break;


			case AVAudioSessionRouteChangeReasonOverride:
			{
				SDR_DEBUGPRINT(("AVAudioSessionRouteChangeReasonOverride! Ignoring notification.\n"));
				//				[self adjustAudioRouting:kAudioSessionRouteChangeReason_Override];
			}
				break;


			case AVAudioSessionRouteChangeReasonWakeFromSleep:
			{
				SDR_DEBUGPRINT(("AVAudioSessionRouteChangeReasonWakeFromSleep! Ignoring notification\n"));
				//				[self adjustAudioRouting:kAudioSessionRouteChangeReason_WakeFromSleep];
			}
				break;


			case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
			{
				SDR_DEBUGPRINT(("AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory\n"));
				[self adjustAudioRouting:kAudioSessionRouteChangeReason_NoSuitableRouteForCategory];
			}
				break;


			case AVAudioSessionRouteChangeReasonRouteConfigurationChange:
			{
				SDR_DEBUGPRINT(("AVAudioSessionRouteChangeReasonRouteConfigurationChange! Ignoring notification\n"));
				//				[self adjustAudioRouting:kAudioSessionRouteChangeReason_NewDeviceAvailable];
			}
				break;


			default:
			{
				SDR_DEBUGPRINT(("Unrecognized Configuration Change! Ignoring notification\n"));
			}
				break;
		}
	}
	else
	{
		SDR_DEBUGPRINT(("Cannot reconfigure audio route: mAutoconfigEnabled not enabled!\n"));
	}

	SDR_DEBUGPRINT(("********************************************************************************************************\n\n"));
}


#pragma mark -RIO Render Callback

static OSStatus	renderInput(
							void						*inRefCon,
							AudioUnitRenderActionFlags 	*ioActionFlags,
							const AudioTimeStamp 		*inTimeStamp,
							UInt32 						inBusNumber,
							UInt32 						inNumberFrames,
							AudioBufferList 			*ioData)
{
	MultichannelMixerController *THIS = (__bridge MultichannelMixerController *)inRefCon;

	//	[THIS audioBusy:AudioBusy];

#ifdef SDR_DEBUG_C
	if(THIS->_maxSamplesPerRender < inNumberFrames) THIS->_maxSamplesPerRender = inNumberFrames;
	if(THIS->_minSamplesPerRender > inNumberFrames) THIS->_minSamplesPerRender = inNumberFrames;

	static BOOL do_once=TRUE;

	if(do_once)
	{
		do_once = FALSE;
		SDR_DEBUGPRINT(("Render Thread Priority = %1.2lf\n", [NSThread threadPriority]));
	}
#endif

	if(THIS->mRemoteIOUnit != NULL) // live audio
	{
		static OSStatus err;

		err = AudioUnitRender(THIS->mRemoteIOUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
		if(err)
		{
			SDR_DEBUGPRINT(("renderInput error: %d %08X %4.4s\n", (int)err, (int)err, (char*)&err));
			//			[THIS audioBusy:AudioNotBusy];
			return err;
		}
	}

//#ifdef DO_NOT_USE

	else if(THIS->mute == NO) // audio from file
	{
		if(ioData->mNumberBuffers < 2 || THIS->mSoundBuffer0 == NULL || THIS->mSoundBuffer1 == NULL)
		{
			SilenceData(ioData);
		}
		else
		{
			const int emptyBuffers = __atomic_load_n(&THIS->mEmptyBuffers, __ATOMIC_ACQUIRE);
			const int32_t *buffers[2] = {
				(const int32_t *)THIS->mSoundBuffer0->data,
				(const int32_t *)THIS->mSoundBuffer1->data
			};
			const size_t frameCounts[2] = {
				(emptyBuffers & AUDIOBUFFER0) == 0 ? THIS->mSoundBuffer0->numFrames : 0,
				(emptyBuffers & AUDIOBUFFER1) == 0 ? THIS->mSoundBuffer1->numFrames : 0
			};
			ISDRStereoFileCursor cursor = {
				THIS->mActiveFileBufferIndex,
				{ THIS->mSoundBuffer0->sampleNum, THIS->mSoundBuffer1->sampleNum }
			};
			uint32_t exhaustedMask = 0;
			int32_t *outA = (int32_t *)ioData->mBuffers[0].mData;
			int32_t *outB = (int32_t *)ioData->mBuffers[1].mData;
			const size_t copiedFrames = ISDRCopyStereoFileFrames(buffers, frameCounts, &cursor,
															 outA, outB, inNumberFrames, &exhaustedMask);

			THIS->mActiveFileBufferIndex = (UInt32)cursor.activeBuffer;
			THIS->mSoundBuffer0->sampleNum = (UInt32)cursor.framePositions[0];
			THIS->mSoundBuffer1->sampleNum = (UInt32)cursor.framePositions[1];
			if(exhaustedMask != 0)
				__atomic_fetch_or(&THIS->mEmptyBuffers, (int)exhaustedMask, __ATOMIC_RELEASE);

			// If both file buffers are empty, silence only the unfilled suffix.
			if(copiedFrames < inNumberFrames)
			{
				memset(outA + copiedFrames, 0, (inNumberFrames - copiedFrames) * sizeof(int32_t));
				memset(outB + copiedFrames, 0, (inNumberFrames - copiedFrames) * sizeof(int32_t));
			}
		}
	}

//#endif // DO_NOT_USE

	if(THIS->fftBufferManager == NULL) return noErr;

	if(THIS->mute == YES)
	{
		SilenceData(ioData);
	}
	else
	{
		THIS->fftBufferManager->GrabAudioData(ioData);
	}

	//	[THIS audioBusy:AudioNotBusy];

	return noErr;
}


#pragma mark- MultichannelMixerController

@synthesize	morseKey;
@synthesize mcMixerUser;
@synthesize mAudioBlocked, mAudioFlowTurnedOn;
@synthesize mEmptyBuffers; //, mEmptyBuffersPtr;

- (id)initMMC
{
	SDR_DEBUGPRINT(("Initializing MMC...\n"));
	if(self = [super init])
	{
		self.mRemoteIOUnit = NULL;
		self.fftBufferManager = nil;
		self.audioDSPThread = nil;

		mEmptyBuffers = AUDIOBUFFER0 | AUDIOBUFFER1; // start out with all buffers flagged as empty
		mActiveFileBufferIndex = 0;

		self.mcMixerUser = nil;
		mAudioBlocked = FALSE;
		mAudioGraph = nil;
		mLiveAudioAllowed = FALSE;
		morseKey = 0;
		morseRunning = FALSE;
		mute = TRUE;

		FileHandler* fh = [[FileHandler alloc] initFH];
		self.fileHandler = fh;
		[fh release];

		mSoundBuffer0 = fileHandler.soundBuffer0ptr;
		mSoundBuffer1 = fileHandler.soundBuffer1ptr;
		fileHandler.bufferFlags = &mEmptyBuffers;
		mActiveFileURL = nil;
	}

	return self;
}


- (BOOL)ensureDSPResourcesForChannels:(int)channels
{
	if(fftBufferManager == nil)
	{
		fftBufferManager = new (std::nothrow) FFTBufferManager(
			NUMBER_OF_BUFFER_SEGMENTS, SEGMENT_STEPSIZE_FRAMES, channels);
		if(fftBufferManager == nil || !fftBufferManager->isValid())
		{
			delete fftBufferManager;
			fftBufferManager = nil;
			return NO;
		}
	}

	if(audioDSPThread == nil)
	{
		audioDSPThread = new (std::nothrow) dspThread();
		if(audioDSPThread == nil || audioDSPThread->LaunchDSPThread(fftBufferManager) != 0)
		{
			delete audioDSPThread;
			audioDSPThread = nil;
			delete fftBufferManager;
			fftBufferManager = nil;
			return NO;
		}
	}

	audioDSPThread->dspEnable();
	return YES;
}


- (void)dealloc
{
	mute = TRUE; // avoid crashes at shutdown caused by accesses to deallocated buffers

	// Stop render callbacks before releasing any state they can access.
	if(mAudioGraph)
	{
		AUGraphStop(mAudioGraph);
		DisposeAUGraph(mAudioGraph);
		mAudioGraph = nil;
		mMixerUnit = nil;
		self.mRemoteIOUnit = NULL;
	}

	if(audioDSPThread)
	{
		SDR_DEBUGPRINT(("DL thread 0\n"));
		audioDSPThread->dspDisable();
		audioDSPThread->killThread(); // instruct the thread to terminate itself

		delete audioDSPThread;
		audioDSPThread = nil;
	}

	if(fftBufferManager)
	{
		SDR_DEBUGPRINT(("DL fftbuff 0\n"));
		delete fftBufferManager;
		fftBufferManager = nil;
	}

	if(mcMixerUser)
	{
		[mcMixerUser setAu:nil];
		mcMixerUser = nil;
	}
	self.fileHandler = nil;

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}


- (BOOL)setupRIOGraph:(UInt32)CurrentHardwareInputNumberChannels
{
	UInt32 size;
	OSStatus result = noErr;
    AUNode ioNode;
	AUNode mixerNode;
    CAStreamBasicDescription streamDesc;

	/*
	 SDR_DEBUGPRINT(("Checking for loudspeaker...\n"));
	 AVAudioSession* session = [AVAudioSession sharedInstance];
	 NSError* error;
	 BOOL success = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
	 error:&error];
	 if(!success)
	 {
	 SDR_DEBUGPRINT(("Override Default To Speaker: AudioUnitSetProperty result: %d\n", (int)result));
	 return(1);
	 }
	 */

	SDR_DEBUGPRINT(("setupRIOgraph\n"));

	mRenderCallback = renderInput;

    if(mAudioGraph)
	{
		SDR_DEBUGPRINT(("Disposing AU Graph 2.\n"));
		DisposeAUGraph(mAudioGraph);
		mAudioGraph = nil;
		mMixerUnit = nil;
		self.mRemoteIOUnit = NULL;
	}

	if(mRemoteIOUnit != NULL)
	{
		AudioComponentInstanceDispose(mRemoteIOUnit);
		self.mRemoteIOUnit = NULL; // disposal frees rIOUnit, so just set pointer to nil
	}

	if(mMixerUnit != nil)
	{
		if(mcMixerUser) [mcMixerUser setAu:nil];
		mcMixerUser = nil;
		AudioComponentInstanceDispose(mMixerUnit);
		mMixerUnit = nil;
	}

    // create a new AUGraph
	result = NewAUGraph(&mAudioGraph);
    if(result) { SDR_DEBUGPRINT(("NewAUGraph result: %d\n", (int)result)); return(1); }

    // create two AudioComponentDescriptions for the AUs we want in the graph
    // output unit
	AUComponentDescription rio_desc(kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple, 0, 0);

    // mixer unit
	AUComponentDescription mixer_desc(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer, kAudioUnitManufacturer_Apple, 0, 0);

    // create a node in the graph that is an AudioUnit, using the supplied AudioComponentDescription to find and open that unit
	result = AUGraphAddNode(mAudioGraph, &rio_desc, &ioNode);
	if(result) { SDR_DEBUGPRINT(("AUGraphNewNode 1 result: %d\n", (int)result)); return(1); }

	result = AUGraphAddNode(mAudioGraph, &mixer_desc, &mixerNode );
	if(result) { SDR_DEBUGPRINT(("AUGraphNewNode 2 result: %d\n", (int)result)); return(1); }

	// connect the mixer node's bus 0 output to the output rio node's out-bus input
	result = AUGraphConnectNodeInput(mAudioGraph, mixerNode, 0, ioNode, 0);
	if(result) { SDR_DEBUGPRINT(("AUGraphConnectNodeInput result: %d\n", (int)result)); return(1); }

    // open the graph AudioUnits - audio units are opened here, but not initialized (no resource allocation occurs)
	result = AUGraphOpen(mAudioGraph);
	if(result) { SDR_DEBUGPRINT(("AUGraphOpen result: %d\n", (int)result)); return(1); }

	result = AUGraphNodeInfo(mAudioGraph, mixerNode, NULL, &mMixerUnit);
    if(result) { SDR_DEBUGPRINT(("AUGraphNodeInfo result: %d\n", (int)result)); return(1); }

	result = AUGraphNodeInfo(mAudioGraph, ioNode, NULL, &mRemoteIOUnit);
    if(result) { SDR_DEBUGPRINT(("AUGraphNodeInfo result: %d\n", (int)result)); return(1); }

	//=========================================================
	// set mixer unit bus count

	UInt32 numbuses = 1;
	size = sizeof(numbuses);
	result = AudioUnitSetProperty(mMixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, size);
	if (result) { SDR_DEBUGPRINT(("Element Count: AudioUnitSetProperty result: %d\n", (int)result)); return(1); }

	//=========================================================
	// enable mixer metering mode

	UInt32 meteringMode = 1;
	result = AudioUnitSetProperty(mMixerUnit, kAudioUnitProperty_MeteringMode, kAudioUnitScope_Input, 0, &meteringMode, sizeof(meteringMode) );
	if(result)
	{
		SDR_DEBUGPRINT(("Metering: AudioUnitSetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1);
	}
	else
	{
		SDR_DEBUGPRINT(("Metering mode enabled!\n"));
	}

	//=========================================================
	// set mixer volume to max
	result = AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1.0, 0);
	if(result) { SDR_DEBUGPRINT(("AudioUnitSetParameter kMultiChannelMixerParam_Volume Input result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	result = AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, 1.0, 0);
	if(result) { SDR_DEBUGPRINT(("AudioUnitSetParameter kMultiChannelMixerParam_Volume Output result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	//==============================================================
	// set stream format to what we want

	size = sizeof(streamDesc);
	result = AudioUnitGetProperty(mRemoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &streamDesc, &size);
	if(result) { SDR_DEBUGPRINT(("AudioUnitGetProperty4 result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	streamDesc.ChangeNumberChannels(CurrentHardwareInputNumberChannels, FALSE);
	streamDesc.mSampleRate = kGraphSampleRate;
	streamDesc.SetAUCanonical(CurrentHardwareInputNumberChannels, FALSE);

	result = AudioUnitSetProperty(mRemoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &streamDesc, size);
	if(result) { SDR_DEBUGPRINT(("Stream Format RIO4: AudioUnitSetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	result = AudioUnitSetProperty(mRemoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamDesc, size);
	if(result) { SDR_DEBUGPRINT(("Stream Format RIO3: AudioUnitSetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }


	result = AudioUnitSetProperty(mMixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamDesc, size);
	if(result) { SDR_DEBUGPRINT(("Stream Format RIO2: AudioUnitSetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	//	size = sizeof(streamDesc);
	//	result = AudioUnitGetProperty(mMixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &streamDesc, &size);
	//	if(result) { SDR_DEBUGPRINT(("AudioUnitGetProperty5 result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	streamDesc.ChangeNumberChannels(2, FALSE); // for compatibility with older iOS, always set to 2 channels
	streamDesc.SetAUCanonical(2, FALSE);  // for compatibility with older iOS, always set to 2 channels
	//	streamDesc.mSampleRate = kGraphSampleRate;

	result = AudioUnitSetProperty(mMixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &streamDesc, size);
	if(result)
	{
		SDR_DEBUGPRINT(("\nStream Format RIO1: AudioUnitSetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
		return(1);
	}


	//==============================================================
    // set the unit to handle 4096 samples per slice since we want to keep rendering during screen lock
    UInt32 maxFPS = 4096;
    result = AudioUnitSetProperty(mMixerUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
								  &maxFPS, sizeof(maxFPS));
	if(result)
	{
		SDR_DEBUGPRINT(("\nFrames per slice MCM: AudioUnitSetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
		return(1);
	}

    // set the mixer unit to handle 4096 samples per slice since we want to keep rendering during screen lock
    result = AudioUnitSetProperty(mRemoteIOUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
								  &maxFPS, sizeof(maxFPS));
	if(result)
	{
		SDR_DEBUGPRINT(("\nFrames per slice RIO: AudioUnitSetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
		return(1);
	}

	//=============================================================
	// Set up render callback on mixer needing more data
	rcbs.inputProc = mRenderCallback;
	rcbs.inputProcRefCon = (void *)self;

	result = AUGraphSetNodeInputCallback(mAudioGraph, mixerNode, 0, &rcbs);
	if(result) { SDR_DEBUGPRINT(("AUGraphSetNodeInputCallback result: %d\n", (int)result)); return(1); }

	//=========================================================
	// enable remote io unit microphone and speaker connections
	UInt32 one = 1;
	size = sizeof(one);
	result = AudioUnitSetProperty(mRemoteIOUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, size);
	if(result) { SDR_DEBUGPRINT(("Couldn't enable input on the remote I/O unit  result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	result = AudioUnitSetProperty(mRemoteIOUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &one, size);
	if(result) { SDR_DEBUGPRINT(("Couldn't enable output on the remote I/O unit result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	// now that we've set everything up we can initialize the graph, this will also validate the connections
	result = AUGraphInitialize(mAudioGraph);
    if(result) { SDR_DEBUGPRINT(("RIOGraphInitialize result: %d\n", (int)result)); return(1); }

	return(0);
}


- (BOOL)setupAUGraph
{
	OSStatus result=0;

	/*
	 SDR_DEBUGPRINT(("Checking for loudspeaker...\n"));
	 AVAudioSession* session = [AVAudioSession sharedInstance];
	 NSError* error;
	 BOOL success = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
	 error:&error];
	 if(!success)
	 {
	 SDR_DEBUGPRINT(("Override Default To Speaker: AudioUnitSetProperty result: %d\n", (int)result));
	 return(1);
	 }
	 */

	SDR_DEBUGPRINT(("setupAUGraph\n"));

	if(mAudioGraph)
	{
		SDR_DEBUGPRINT(("Existing AUGraph found. Closing it down...\n"));
		result = AUGraphClose(mAudioGraph);
		if(result)
		{
			SDR_DEBUGPRINT(("Error closing AUGraph %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			return(1);
		}

		SDR_DEBUGPRINT(("Disposing AU Graph 3.\n"));
		result = DisposeAUGraph(mAudioGraph);
		if(result)
		{
			SDR_DEBUGPRINT(("Error disposing AUGraph %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			return(1);
		}

		mAudioGraph = nil;
		mMixerUnit = nil;
		self.mRemoteIOUnit = NULL;
	}

	if(mRemoteIOUnit != NULL)
	{
		AudioComponentInstanceDispose(mRemoteIOUnit);
		self.mRemoteIOUnit = NULL; // disposal frees rIOUnit, so just set pointer to nil
	}

	if(mMixerUnit != nil)
	{
		if(mcMixerUser) [mcMixerUser setAu:nil];
		mcMixerUser = nil;
		AudioComponentInstanceDispose(mMixerUnit);
		mMixerUnit = nil;
	}

	// clear the mSoundBuffer struct
	//	memset(&mSoundBuffer0, 0, sizeof(mSoundBuffer0));
	//	memset(&mSoundBuffer1, 0, sizeof(mSoundBuffer1));

	mAudioMode = AudioModeDemonstration;

	mRenderCallback = renderInput;

	if(mActiveFileURL == nil)
	{
		NSURL* fileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:DEFAULT_AUDIO_FILE_NAME ofType:nil]];

		if([self loadFile:fileURL setupIfNeeded:FALSE])
		{
			SDR_DEBUGPRINT(("Could not load default audio file!\n"));
			return(1);
		}
	}
	else
	{
		mCurrentHardwareInputNumberChannels	= fileHandler.channelsInFile;
	}

	// load up the audio data
	//    if([fileHandler loadFile:mActiveFileURL])
	//	{
	//		SDR_DEBUGPRINT(("Could not load default audio file!\n"));
	//		return(1);
	//	}

	AUNode outputNode;
	AUNode mixerNode;
	CAStreamBasicDescription streamDesc;

	// create a new AUGraph
	result = NewAUGraph(&mAudioGraph);
	if(result) { SDR_DEBUGPRINT(("NewAUGraph result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	// create two AudioComponentDescriptions for the AUs we want in the graph

	// output unit
	AUComponentDescription rio_desc(kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple);
	//	AUComponentDescription rio_desc(kAudioUnitType_Output, kAudioUnitSubType_GenericOutput, kAudioUnitManufacturer_Apple);

	// mixer unit
	AUComponentDescription mixer_desc(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer, kAudioUnitManufacturer_Apple);
	// AUComponentDescription mixer_desc(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter, kAudioUnitManufacturer_Apple);

	// create a node in the graph that is an AudioUnit, using the supplied AudioComponentDescription to find and open that unit
	result = AUGraphAddNode(mAudioGraph, &rio_desc, &outputNode);
	if(result) { SDR_DEBUGPRINT(("AUGraphNewNode 1 result %d %4.4s\n", (int)result, (char*)&result)); return(1); }

	result = AUGraphAddNode(mAudioGraph, &mixer_desc, &mixerNode );
	if(result) { SDR_DEBUGPRINT(("AUGraphNewNode 2 result %d %4.4s\n", (int)result, (char*)&result)); return(1); }

	// connect a node's output to a node's input
	result = AUGraphConnectNodeInput(mAudioGraph, mixerNode, 0, outputNode, 0);
	if(result) { SDR_DEBUGPRINT(("AUGraphConnectNodeInput result %d %4.4s\n", (int)result, (char*)&result)); return(1); }

	// open the graph AudioUnits are open but not initialized (no resource allocation occurs here)
	result = AUGraphOpen(mAudioGraph);
	if(result) { SDR_DEBUGPRINT(("AUGraphOpen result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	result = AUGraphNodeInfo(mAudioGraph, mixerNode, NULL, &mMixerUnit);
	if(result) { SDR_DEBUGPRINT(("AUGraphNodeInfo result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	UInt32 numbuses = 1;
	UInt32 size = sizeof(numbuses);

	// set bus count
	result = AudioUnitSetProperty(mMixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, sizeof(UInt32));
	if (result) { SDR_DEBUGPRINT(("Element Count: AudioUnitSetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	UInt32 meteringMode = 1;
	result = AudioUnitSetProperty(mMixerUnit, kAudioUnitProperty_MeteringMode, kAudioUnitScope_Input, 0, &meteringMode, sizeof(meteringMode) );
	if(result)
	{
		SDR_DEBUGPRINT(("Metering: AudioUnitSetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1);
	}
	else
	{
		SDR_DEBUGPRINT(("Metering mode enabled!\n"));
	}

	// setup render callback struct
	rcbs.inputProc = mRenderCallback;
	rcbs.inputProcRefCon = (void *)self;

	// Set a callback for the specified node's specified input
	result = AUGraphSetNodeInputCallback(mAudioGraph, mixerNode, 0, &rcbs);
	if(result) { SDR_DEBUGPRINT(("AUGraphSetNodeInputCallback result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	// set input stream format to what we want
	size = sizeof(streamDesc);
	result = AudioUnitGetProperty(mMixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamDesc, &size);
	if(result) { SDR_DEBUGPRINT(("AudioUnitGetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

//	streamDesc.ChangeNumberChannels(2, FALSE);
//	streamDesc.mSampleRate = kGraphSampleRate;

	streamDesc.SetAUCanonical(2, false);
	streamDesc.mSampleRate = kGraphSampleRate;



	printf("Input stream format:\n");
	streamDesc.Print();


	result = AudioUnitSetProperty(mMixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamDesc, sizeof(streamDesc));
	if(result) { SDR_DEBUGPRINT(("Stream Format AU1: AudioUnitSetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	// set output stream format to what we want
	result = AudioUnitGetProperty(mMixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &streamDesc, &size);
	if(result) { SDR_DEBUGPRINT(("AudioUnitGetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

//	streamDesc.ChangeNumberChannels(2, FALSE);
//	streamDesc.mSampleRate = kGraphSampleRate;

	streamDesc.SetAUCanonical(2, false);
	streamDesc.mSampleRate = kGraphSampleRate;

	printf("Output stream format:\n");
	streamDesc.Print();

	result = AudioUnitSetProperty(mMixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &streamDesc, sizeof(streamDesc));
	if(result) { SDR_DEBUGPRINT(("Stream Format AU2: AudioUnitSetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	// now that we've set everything up we can initialize the graph, this will also validate the connections
	result = AUGraphInitialize(mAudioGraph);
	if(result) { SDR_DEBUGPRINT(("AUGraphInitialize result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(1); }

	return(0);
}

- (Float32)getAUGraphCPULoad
{
	Float32 load;
	//	AUGraphGetCPULoad(mAudioGraph, &load);
	AUGraphGetMaxCPULoad(mAudioGraph, &load);
	////	 [NSThread setThreadPriority:1.0];
	return load;
}


- (OSStatus)loadFile:(NSURL *)sourceURL setupIfNeeded:(BOOL)doSetup
{
	if(fileHandler == nil) return (OSStatus)1;
	if(sourceURL == nil) return (OSStatus)2;

	int holdNumberOfChannels = fileHandler.channelsInFile;

	if(mActiveFileURL != nil)
	{
		NSString* fileURLString = [sourceURL path];
		NSString* activeFileURLString = [mActiveFileURL path];

		if([activeFileURLString caseInsensitiveCompare:fileURLString] == 0)
		{
			SDR_DEBUGPRINT(("Active URL = %s\n", [activeFileURLString UTF8String]));
			SDR_DEBUGPRINT(("Selected file already loaded!\n"));
			return noErr;
		}
		else
		{
			SDR_DEBUGPRINT(("Active URL = %s\n", [activeFileURLString UTF8String]));
		}
	}

	OSStatus result = [fileHandler loadFile:sourceURL];

	if(result == noErr)
	{
		mActiveFileBufferIndex = 0;
		mActiveFileURL = sourceURL;

		if(mAudioMode != AudioModeDemonstration) return noErr;

		if(fileHandler.channelsInFile == 1)
		{
			SDR_DEBUGPRINT(("Monaural file found!\n"));
			if(mCurrentHardwareInputNumberChannels != 1)
			{
				mCurrentHardwareInputNumberChannels = 1;

				SDR_DEBUGPRINT(("Setting up for monaural...\n"));
				if(doSetup)
				{
					[self shutDownAudio];

					if([self setupAudioSession]) // re-initialize the audio session
					{
						[delegate reconfigureDisplaySetup:fatalAudioErrorDeviceLost];
					}
					else
					{
						[delegate reconfigureDisplaySetup:reInitializeAudioSettings];
					}
				}
			}
		}
		else if(fileHandler.channelsInFile == 2)
		{
			SDR_DEBUGPRINT(("Stereo file found!\n"));
			if(mCurrentHardwareInputNumberChannels != 2)
			{
				mCurrentHardwareInputNumberChannels = 2;

				SDR_DEBUGPRINT(("Setting up for stereo...\n"));
				if(doSetup)
				{
					[self shutDownAudio];

					if([self setupAudioSession]) // re-initialize the audio session
					{
						[delegate reconfigureDisplaySetup:fatalAudioErrorDeviceLost];
					}
					else
					{
						[delegate reconfigureDisplaySetup:reInitializeAudioSettings];
					}
				}
			}
		}
		else
		{
			mCurrentHardwareInputNumberChannels = holdNumberOfChannels;
			SDR_DEBUGPRINT(("Unsupported number of channels in file!\n"));
			return (OSStatus)3;
		}
	}
	else
	{
		mActiveFileURL = nil;
	}


	return result;
}


- (NSURL *)getCurrentFileURL
{
	return [fileHandler getCurrentFileURL];
}


- (FileStats*)getFileStats
{
	//	SDR_DEBUGPRINT(("!!(MCMixCtrlr) fileName: %s\n", [stats.fileName UTF8String]));
	return fileHandler.fileStats;
}


#pragma mark-

// enable or disables a specific bus
- (void)enableInput:(UInt32)inputNum isOn:(AudioUnitParameterValue)isONValue
{
    SDR_DEBUGPRINT(("BUS %d isON %f\n", (uint)inputNum, isONValue));

	//   OSStatus result = AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, inputNum, isONValue, 0);
	//   if (result) { SDR_DEBUGPRINT(("AudioUnitSetParameter kMultiChannelMixerParam_Enable result %d %08X %4.4s\n", result, result, (char*)&result)); return; }

}


//
- (float)getAvgPower
{
	if(mMixerUnit != nil)
	{
		OSStatus result;
		//  float avgPower1;
		//	float avgPower2;
		//	float avgPower3;
		//	float avgPower4;
		float powerMeasurement;
		UInt32 size;

		/*
		 kMultiChannelMixerParam_PreAveragePower   = 1000,
		 kMultiChannelMixerParam_PrePeakHoldLevel  = 2000,
		 kMultiChannelMixerParam_PostAveragePower  = 3000,
		 kMultiChannelMixerParam_PostPeakHoldLevel = 4000

		 */

		UInt32 meteringMode;
		size = sizeof(meteringMode);
		result = AudioUnitGetProperty(mMixerUnit, kAudioUnitProperty_MeteringMode, kAudioUnitScope_Input, 0, &meteringMode, &size );

		if(result)
		{
			SDR_DEBUGPRINT(("Metering mode: AudioUnitGetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); return(0);
		}
		else
		{
			result = AudioUnitGetParameter(mMixerUnit, kMultiChannelMixerParam_PreAveragePower, kAudioUnitScope_Input, 0, &powerMeasurement);
			if(result)
			{
				SDR_DEBUGPRINT(("AvgPower1: AudioUnitGetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			}
#if 0

			else
				printf("preAvgPwr = %f  ", powerMeasurement);

			result = AudioUnitGetParameter(mMixerUnit, kMultiChannelMixerParam_PrePeakHoldLevel, kAudioUnitScope_Input, 0, &powerMeasurement);
			if(result)
			{
				SDR_DEBUGPRINT(("AvgPower1: AudioUnitGetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			}
			else
				printf("prePeakHoldLevel = %f  ", powerMeasurement);

			result = AudioUnitGetParameter(mMixerUnit, kMultiChannelMixerParam_PostAveragePower, kAudioUnitScope_Input, 0, &powerMeasurement);
			if(result)
			{ SDR_DEBUGPRINT(("AvgPower1: AudioUnitGetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); }
			else
				printf("postAvgPwr = %f  ", powerMeasurement);

			result = AudioUnitGetParameter(mMixerUnit, kMultiChannelMixerParam_PostPeakHoldLevel, kAudioUnitScope_Input, 0, &powerMeasurement);
			if(result)
			{ SDR_DEBUGPRINT(("AvgPower1: AudioUnitGetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); }
			else
				printf("postPeakHoldLevel = %f\n", powerMeasurement);
#endif
		}

		return(powerMeasurement);
	}

	return(0);
}

// starts render
- (void)startAUGraph:(BOOL)overRide
{
	// Don't start audio flow if it is currently blocked
	if(!overRide && mAudioBlocked)
	{
		SDR_DEBUGPRINT(("startAUGraph: Audio currently blocked.\n"));
		mAudioFlowTurnedOn = TRUE;
		return;
	}

	if(overRide)
	{
		mAudioBlocked = FALSE;
		if(!mAudioFlowTurnedOn)
		{
			return;
		}
	}
	else
	{
		mAudioFlowTurnedOn = TRUE;
	}


    SDR_DEBUGPRINT(("startAUGraph: "));

	[fileHandler resumeFileReads];

	audioDSPThread->dspEnable();
	SDR_DEBUGPRINT(("Restarting thread\n"));


	if(mAudioGraph != nil)
	{
		OSStatus result;
		Boolean isRunning = FALSE;

		result = AUGraphIsRunning(mAudioGraph, &isRunning);
		if(result)
		{
			SDR_DEBUGPRINT(("AUGraphIsRunning result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			return;
		}

		if(!isRunning)
		{
			SDR_DEBUGPRINT(("starting graph\n"));
			result = AUGraphStart(mAudioGraph);

			if(result) // try one more time to initialize mAudioGraph before giving up
			{
				result = AUGraphInitialize(mAudioGraph);
				if(result) { SDR_DEBUGPRINT(("AUGraphInitialize result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); }

				if(result)
				{
					SDR_DEBUGPRINT(("AUGraphStart result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
					return;
				}
				else
				{
					result = AUGraphStart(mAudioGraph);

					if(result)
					{
						SDR_DEBUGPRINT(("AUGraphStart result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
						return;
					}
				}

			}
		}
		else
		{
			SDR_DEBUGPRINT(("graph is already started!\n"));
		}
	}
#ifdef SDR_DEBUG
	else
	{
		SDR_DEBUGPRINT(("Error: No audio graph to start!\n"));
	}
#endif
}


- (void)disableAllAudio
{
	audioDSPThread->dspDisable();
	mute = TRUE;
}

- (void)reenableAudio
{
	fftBufferManager->AudioBufferFlush();
	mute = FALSE;
	audioDSPThread->dspEnable();
}


// stops render
- (void)stopAUGraph:(BOOL)overRide
{
	// Don't bother stopping audio flow if it is currently blocked
	if(!overRide && mAudioBlocked)
	{
		SDR_DEBUGPRINT(("stopAUGraph: Audio stopped already by blocking.\n"));
		mAudioFlowTurnedOn = FALSE;
		return;
	}

	if(overRide) mAudioBlocked = TRUE;

	SDR_DEBUGPRINT(("stopAUGraph: "));

	if(mAudioGraph != nil)
	{
		Boolean isRunning = FALSE;

		OSStatus result = AUGraphIsRunning(mAudioGraph, &isRunning);
		if(result)
		{
			SDR_DEBUGPRINT(("AUGraphIsRunning result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			return;
		}

		if(isRunning)
		{
			SDR_DEBUGPRINT(("stopping graph\n"));

			result = AUGraphStop(mAudioGraph);

			if(result)
			{
				SDR_DEBUGPRINT(("AUGraphStop result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
				return;
			}
			else
			{
				SDR_DEBUGPRINT(("mAudioGraph has been stopped!\n"));
			}
		}
		else
		{
			SDR_DEBUGPRINT(("mAudioGraph is already stopped!\n"));
		}

		[fileHandler pauseFileReads];
	}
#ifdef SDR_DEBUG
	else
	{
		SDR_DEBUGPRINT(("mAudioGraph is nil!\n"));
	}
#endif
}

/*********************************************
 Media Services Availability
 On iOS, the system provides audio and other multimedia functionality through a shared server process. Under certain circumstances, the system may terminate and restart this process. Your app should be prepared to respond to these events by reinitializing any audio objects (such as players, recorders, converters, or audio queues) in use and reapplying preferred audio session settings.

 To respond to a media server restart, subscribe to the AVAudioSessionMediaServicesWereResetNotification.
 **********************************************/

- (OSStatus)setupAudioSession
{
	static UInt32 HoldCurrentHardwareInputNumberChannels = 1;
	BOOL useDemoMode = FALSE;
	OSStatus result=0;
	BOOL validchannelcount = FALSE;
	audioStatus	= AudioNotReady;

	// Get the app's audioSession singleton object
	AVAudioSession* session = [AVAudioSession sharedInstance];

	//error handling
	NSError* audioSessionError = nil;

	SDR_DEBUGPRINT(("Setting session not active!\n"));
	[session setActive:NO error:&audioSessionError]; // shut down the audio session if it is active

	/*****************************************************************************************
	 * Select Audiosession Category                                                          *
	 *****************************************************************************************/

	if(mLiveAudioAllowed)
	{
		BOOL success = [session.category isEqualToString:AVAudioSessionCategoryPlayAndRecord];

//		if(![session.category isEqualToString:AVAudioSessionCategoryMultiRoute])
		if(![session.category isEqualToString:AVAudioSessionCategoryPlayAndRecord])
		{
			SDR_DEBUGPRINT(("Setting session category: AVAudioSessionCategoryPlayAndRecord.\n"));

			//set the audioSession category.
			//Needs to be Record or PlayAndRecord to use audioRouteOverride: AVAudioSessionCategoryPlayAndRecord
			//success = [session setCategory:AVAudioSessionCategoryMultiRoute error:&audioSessionError];
			//success = [session setCategory:AVAudioSessionCategoryMultiRoute withOptions:(AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionDefaultToSpeaker) error:&audioSessionError];
			success = [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:(AVAudioSessionCategoryOptionAllowBluetoothHFP | AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers) error:&audioSessionError];

			if(audioSessionError)
			{
				NSLog(@"AVAudioSession error setting category: %ld, %@",(long)audioSessionError.code, audioSessionError.localizedDescription);
				//				audioStatus = AudioError;
				//				result = kAudioSessionInitializationError;
				//				return result;
			}
		}

		if(!success)
		{
			if(![session.category isEqualToString:AVAudioSessionCategoryMultiRoute])
			{
				SDR_DEBUGPRINT(("Setting session category: isEqualToString:AVAudioSessionCategoryMultiRoute.\n"));

				//set the audioSession category.
				//Needs to be Record or PlayAndRecord to use audioRouteOverride:
				//[session setCategory:AVAudioSessionCategoryPlayAndRecord error:&audioSessionError];
				[session setCategory:AVAudioSessionCategoryMultiRoute withOptions:(AVAudioSessionCategoryOptionAllowBluetoothHFP | AVAudioSessionCategoryOptionDefaultToSpeaker) error:&audioSessionError];

				if(audioSessionError)
				{
					NSLog(@"AVAudioSession error setting category: %ld, %@",(long)audioSessionError.code, audioSessionError.localizedDescription);
					audioStatus = AudioError;
					result = kAudioSessionInitializationError;
					return result;
				}
			}
		}
	}
	else
	{
		if(![session.category isEqualToString:AVAudioSessionCategoryPlayback])
		{
			SDR_DEBUGPRINT(("Setting session category: AVAudioSessionCategoryPlayback.\n"));

			//set the audioSession category.
			[session setCategory:AVAudioSessionCategoryPlayback error:&audioSessionError];

			if(audioSessionError)
			{
				NSLog(@"AVAudioSession error setting category: %ld, %@",(long)audioSessionError.code, audioSessionError.localizedDescription);
				audioStatus = AudioError;
				result = kAudioSessionInitializationError;
				return result;
			}
		}
	}

	/*****************************************************************************************
	 * Set Audiosession Mode                                                                 *
	 *****************************************************************************************/

	/*
	// Don't unnecessarily set the session mode
	if(![session.mode isEqualToString:AVAudioSessionModeMeasurement])
	{
		SDR_DEBUGPRINT(("Setting session mode.\n"));

		[session setMode:AVAudioSessionModeMeasurement error:&audioSessionError]; // minimal processing
		//[session setMode:AVAudioSessionModeDefault error:&audioSessionError]; // testing

		if(audioSessionError)
		{
			NSLog(@"AVAudioSession error overrideOutputAudioPort: %ld, %@",(long)audioSessionError.code, audioSessionError.localizedDescription);
			audioStatus = AudioError;
			result = kAudioServicesNoHardwareError; // ?? not sure if this is a reasonable value
			return result;
		}
	}
	 */

	/*****************************************************************************************
	 * Set Audiosession Override                                                             *
	 *****************************************************************************************/

	/*
	//set the audioSession override
	[session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&audioSessionError];
	if(audioSessionError)
	{
		NSLog(@"AVAudioSession error overrideOutputAudioPort:%@",error);
		audioStatus = AudioError;
		result = kAudioServicesNoHardwareError; // ?? not sure if this is a reasonable value
		return result;
	}
	*/

	/*****************************************************************************************
	 * Set Audiosession Samplerate                                                           *
	 *****************************************************************************************/

	if(session.sampleRate != 44100.0)
	{
		SDR_DEBUGPRINT(("Setting session sample rate.\n"));

		hwSampleRate = 44100.0;
		[session setPreferredSampleRate:hwSampleRate error:&audioSessionError];
		if(audioSessionError)
		{
			NSLog(@"AVAudioSession error setting sample rate: %ld, %@",(long)audioSessionError.code, audioSessionError.localizedDescription);
			audioStatus = AudioError;
			result = kAudioServicesNoHardwareError; // ?? not sure if this is a reasonable value
			return result;
		}
	}

	/*****************************************************************************************
	 * Set Audiosession Buffer Duration                                                      *
	 *****************************************************************************************/

	NSTimeInterval bufferDuration = .005;
	if(fabs(session.preferredIOBufferDuration - bufferDuration) > 0.00001)
	{
		SDR_DEBUGPRINT(("Setting session buffer duration. Preferred: %0.5lf Actual: %0.5lf\n", session.preferredIOBufferDuration, session.IOBufferDuration));

		[session setPreferredIOBufferDuration:bufferDuration error:&audioSessionError];

		if(audioSessionError)
		{
			NSLog(@"AVAudioSession error setting buffer size: %ld, %@",(long)audioSessionError.code, audioSessionError.localizedDescription);
			audioStatus = AudioError;
			result = kAudioServicesNoHardwareError; // ?? not sure if this is a reasonable value
			return result;
		}
	}

	/*****************************************************************************************
	 * Activate the Audio Session                                                            *
	 *****************************************************************************************/

	//activate the audio session
	SDR_DEBUGPRINT(("Setting session active!\n"));
	[session setActive:YES error:&audioSessionError];
	SDR_DEBUGPRINT(("Checking session buffer duration. Preferred: %0.5lf Actual: %0.5lf\n", session.preferredIOBufferDuration, session.IOBufferDuration));

	if(audioSessionError)
	{
		NSLog(@"AVAudioSession error activating audio session: %ld, %@",(long)audioSessionError.code, audioSessionError.localizedDescription);
		audioStatus = AudioError;
		result = kAudioSessionInitializationError;
		return result;
	}

	/*****************************************************************************************
	 * Read the Audio Session settings                                                       *
	 *****************************************************************************************/

	// Read actual values
	hwSampleRate = session.sampleRate;

#ifdef SDR_DEBUG
	AVAudioSessionRouteDescription* rd = [session currentRoute];

	if(rd)
	{
		SDR_DEBUGPRINT(("\n***********************************************************\n"));
		SDR_DEBUGPRINT(("* Current Route:\n"));

		for(AVAudioSessionPortDescription* avaspd in rd.inputs)
		{
			SDR_DEBUGPRINT(("* \n* Input: %s - %s\n", [avaspd.portName UTF8String], [avaspd.portType UTF8String]));

			for(AVAudioSessionChannelDescription* avascd in avaspd.channels)
			{
				SDR_DEBUGPRINT(("*   Ch: %s\n", [avascd.channelName UTF8String]));
			}
		}

		for(AVAudioSessionPortDescription* avaspd in rd.outputs)
		{
			SDR_DEBUGPRINT(("* \n* Output: %s - %s\n", [avaspd.portName UTF8String], [avaspd.portType UTF8String]));

			for(AVAudioSessionChannelDescription* avascd in avaspd.channels)
			{
				SDR_DEBUGPRINT(("*   Ch: %s\n", [avascd.channelName UTF8String]));
			}
		}
	}

	SDR_DEBUGPRINT(("***********************************************************\n\n"));
#endif // SDR_DEBUG

	/*****************************************************************************************
	 * Select input port                                                                     *
	 *****************************************************************************************/
#ifdef SDR_DEBUG
	NSInteger count = 0;

	if([session respondsToSelector:@selector(availableInputs)])
	{
		NSArray* availableInputPorts = [session availableInputs];

		// Look at the available input ports that were returned and decide which one to use - preference goes to any USB or external ports.

		SDR_DEBUGPRINT(("\n***********************************************************\n"));
		SDR_DEBUGPRINT(("* Category: %s\n", [session.category UTF8String]));
		SDR_DEBUGPRINT(("***********************************************************\n"));
		SDR_DEBUGPRINT(("* Available Input Ports:\n"));

		for(AVAudioSessionPortDescription* avaspd in availableInputPorts)
		{
			count++;
			SDR_DEBUGPRINT(("* \n* Input %ld: %s\n", (long)count, [avaspd.portName UTF8String]));

			for(AVAudioSessionChannelDescription* avascd in avaspd.channels)
			{
				SDR_DEBUGPRINT(("*   Ch %lu: %s - ", (unsigned long)avascd.channelNumber, [avascd.channelName UTF8String]));

				if([avaspd.portType isEqualToString:AVAudioSessionPortLineOut])
				{
					SDR_DEBUGPRINT(("port = Line Out\n"));
				}
				else if([avaspd.portType isEqualToString:AVAudioSessionPortHeadphones])
				{
					SDR_DEBUGPRINT(("port = Headphones\n"));
				}
				else if([avaspd.portType isEqualToString:AVAudioSessionPortBluetoothA2DP])
				{
					SDR_DEBUGPRINT(("port = Bluetooth A2DP\n"));
				}
				else if([avaspd.portType isEqualToString:AVAudioSessionPortBuiltInReceiver])
				{
					SDR_DEBUGPRINT(("port = Built-in Receiver\n"));
				}
				else if([avaspd.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker])
				{
					SDR_DEBUGPRINT(("port = Built-in Speaker\n"));
				}
				else if([avaspd.portType isEqualToString:AVAudioSessionPortHDMI])
				{
					SDR_DEBUGPRINT(("port = HDMI\n"));
				}
				else if([avaspd.portType isEqualToString:AVAudioSessionPortAirPlay])
				{
					SDR_DEBUGPRINT(("port = Air Play\n"));
				}
				else if([avaspd.portType isEqualToString:AVAudioSessionPortBluetoothLE])
				{
					SDR_DEBUGPRINT(("port = Bluetooth LE\n"));
				}
				else
				{
					SDR_DEBUGPRINT(("port = Unknown!\n"));
				}
			}

			// Here we might be able to select the preferred output port
		}
	}

	SDR_DEBUGPRINT(("***********************************************************\n"));
	SDR_DEBUGPRINT(("* Available Output Ports:\n"));

	count = 0;
	for(AVAudioSessionPortDescription* avaspd in session.outputDataSources)
	{
		count++;
		SDR_DEBUGPRINT(("* \n* Output %ld: %s\n", (long)count, [avaspd.portName UTF8String]));

		for(AVAudioSessionChannelDescription* avascd in avaspd.channels)
		{
			SDR_DEBUGPRINT(("*   Ch %lu: %s - ", (unsigned long)avascd.channelNumber, [avascd.channelName UTF8String]));

			if([avaspd.portType isEqualToString:AVAudioSessionPortLineOut])
			{
				SDR_DEBUGPRINT(("port = Line Out\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortHeadphones])
			{
				SDR_DEBUGPRINT(("port = Headphones\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortBluetoothA2DP])
			{
				SDR_DEBUGPRINT(("port = Bluetooth A2DP\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortBuiltInReceiver])
			{
				SDR_DEBUGPRINT(("port = Built-in Receiver\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker])
			{
				SDR_DEBUGPRINT(("port = Built-in Speaker\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortHDMI])
			{
				SDR_DEBUGPRINT(("port = HDMI\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortAirPlay])
			{
				SDR_DEBUGPRINT(("port = Air Play\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortBluetoothLE])
			{
				SDR_DEBUGPRINT(("port = Bluetooth LE\n"));
			}
			else
			{
				SDR_DEBUGPRINT(("port = Unknown!\n"));
			}
		}

		// Here we might be able to select the preferred output port
	}

	SDR_DEBUGPRINT(("***********************************************************\n\n"));


	AVAudioSessionRouteDescription* avasrd = [session currentRoute];

	SDR_DEBUGPRINT(("\n***********************************************************\n"));
	SDR_DEBUGPRINT(("* New Route:\n"));

	count = 0;
	for(AVAudioSessionPortDescription* avaspd in avasrd.inputs)
	{
		count++;
		SDR_DEBUGPRINT(("* \n* Input %ld: %s\n", (long)count, [avaspd.portName UTF8String]));

		for(AVAudioSessionChannelDescription* avascd in avaspd.channels)
		{
			SDR_DEBUGPRINT(("*   Ch %lu: %s - ", (unsigned long)avascd.channelNumber, [avascd.channelName UTF8String]));

			if([avaspd.portType isEqualToString:AVAudioSessionPortLineOut])
			{
				SDR_DEBUGPRINT(("port = Line Out\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortHeadphones])
			{
				SDR_DEBUGPRINT(("port = Headphones\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortBluetoothA2DP])
			{
				SDR_DEBUGPRINT(("port = Bluetooth A2DP\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortBuiltInReceiver])
			{
				SDR_DEBUGPRINT(("port = Built-in Receiver\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker])
			{
				SDR_DEBUGPRINT(("port = Built-in Speaker\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortHDMI])
			{
				SDR_DEBUGPRINT(("port = HDMI\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortAirPlay])
			{
				SDR_DEBUGPRINT(("port = Air Play\n"));
			}
			else
			{
				if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0"))
				{
					if([avaspd.portType isEqualToString:AVAudioSessionPortBluetoothLE])
					{
						SDR_DEBUGPRINT(("port = Bluetooth LE\n"));
					}
					else
					{
						SDR_DEBUGPRINT(("port = Unknown!\n"));
					}
				}
				else
				{
					SDR_DEBUGPRINT(("port = Unknown!\n"));
				}
			}
		}

		// Here we might be able to select the preferred output port
	}

	SDR_DEBUGPRINT(("***********************************************************\n\n"));


	count = 0;
	for(AVAudioSessionPortDescription* avaspd in avasrd.outputs)
	{
		count++;
		SDR_DEBUGPRINT(("* \n* Output %ld: %s\n", (long)count, [avaspd.portName UTF8String]));

		for(AVAudioSessionChannelDescription* avascd in avaspd.channels)
		{
			SDR_DEBUGPRINT(("*   Ch %lu: %s - ", (unsigned long)avascd.channelNumber, [avascd.channelName UTF8String]));

			if([avaspd.portType isEqualToString:AVAudioSessionPortLineOut])
			{
				SDR_DEBUGPRINT(("port = Line Out\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortHeadphones])
			{
				SDR_DEBUGPRINT(("port = Headphones\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortBluetoothA2DP])
			{
				SDR_DEBUGPRINT(("port = Bluetooth A2DP\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortBuiltInReceiver])
			{
				SDR_DEBUGPRINT(("port = Built-in Receiver\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker])
			{
				SDR_DEBUGPRINT(("port = Built-in Speaker\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortHDMI])
			{
				SDR_DEBUGPRINT(("port = HDMI\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortAirPlay])
			{
				SDR_DEBUGPRINT(("port = Air Play\n"));
			}
			else if([avaspd.portType isEqualToString:AVAudioSessionPortBluetoothLE])
			{
				SDR_DEBUGPRINT(("port = Bluetooth LE\n"));
			}
			else
			{
				SDR_DEBUGPRINT(("port = Unknown!\n"));
			}
		}
	}
#endif // SDR_DEBUG

	[self registerForAudioSessionNotifications:session];

	SDR_DEBUGPRINT(("audioSession active\n"));
	audioSessionCategory = session.category; // record current setting
	mCurrentHardwareInputNumberChannels = (UInt32)session.inputNumberOfChannels;

	if(mLiveAudioAllowed)
	{
		if(mCurrentHardwareInputNumberChannels == 1)
		{
			validchannelcount = TRUE;
			sampleRateBandwidth = (UInt32)(hwSampleRate / 2.0);
			mAudioMode = AudioModeMonaural;
			SDR_DEBUGPRINT(("Only one input channel found: narrow SDR only: BW = %0.1u\n", (unsigned int)sampleRateBandwidth));
		}
		else if(mCurrentHardwareInputNumberChannels == 2)
		{
			validchannelcount = TRUE;
			sampleRateBandwidth = (UInt32)hwSampleRate;
			mAudioMode = AudioModeStereo;
			SDR_DEBUGPRINT(("Success: Two audio input channels found: BW = %0.1u\n", (unsigned int)sampleRateBandwidth));
		}
	}
	else
	{
		//if(mCurrentHardwareInputNumberChannels == 0)
		//{
			if(audioSessionCategory == AVAudioSessionCategoryPlayback)
			{
				mCurrentHardwareInputNumberChannels = 2; // assume stereo files
				useDemoMode = TRUE; // only valid option under these circumstances
				validchannelcount = TRUE;
				sampleRateBandwidth = (UInt32)hwSampleRate;
				mAudioMode = AudioModeStereo;
				SDR_DEBUGPRINT(("Success: Two audio input channels found: BW = %0.1u\n", (unsigned int)sampleRateBandwidth));
			}
		//}
	}

	///////////////////////////////////////////////////////////////
	// At this point the audio session has been set up successfully
	///////////////////////////////////////////////////////////////
	try
	{
		if(!useDemoMode)
		{
			if(validchannelcount)
			{
				// Changing the number of audio channels requires restarting the FFT objects, so kill them
				if(mCurrentHardwareInputNumberChannels != HoldCurrentHardwareInputNumberChannels)
				{
					HoldCurrentHardwareInputNumberChannels = mCurrentHardwareInputNumberChannels;

					if(fftBufferManager != nil)
					{
						fftBufferManager->setNumAudioChannels(mCurrentHardwareInputNumberChannels);
					}
				}

				// Set up remote i/o unit for receiving input from mic port
				if(![self setupRIOGraph:mCurrentHardwareInputNumberChannels])
				{
					int maxFPS;
					UInt32 size = sizeof(maxFPS);
					XThrowIfError(AudioUnitGetProperty(mRemoteIOUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, &size), "couldn't get the remote I/O unit's max frames per slice");
					SDR_DEBUGPRINT(("Maximum frames per slice: %d\n", maxFPS));

					switch(maxFPS)
					{
						case 1024:
						case 2048:
						case 4096:
						case 8192:

							SDR_DEBUGPRINT(("MMC starting fft path 1\n"));
							if(![self ensureDSPResourcesForChannels:(int)mCurrentHardwareInputNumberChannels])
							{
								SDR_DEBUGPRINT(("Unable to create DSP resources\n"));
								audioStatus = AudioError;
								return 1;
							}

							useDemoMode = FALSE;
							// start flow of live audio
							result = AUGraphStart(mAudioGraph);
							break;

						default:
							SDR_DEBUGPRINT(("Error: unsupported max FPS\n"));
							//				assert("Error: unsupported max FPS\n";
							break;
					}
				}
				else
				{
					SDR_DEBUGPRINT(("Error: could not create streaming augraph %d\n", (int)mCurrentHardwareInputNumberChannels));
					useDemoMode = TRUE; //Use demo mode since live audio cannot be supported

				}
			}
			else
			{
				SDR_DEBUGPRINT(("Unsupported number of input channels: %d\n", (int)mCurrentHardwareInputNumberChannels));
				useDemoMode = TRUE; //Use demo mode since live audio cannot be supported
			}
		}

		if(useDemoMode) // only TRUE if invalid channel count was read above
		{
			if(mAudioGraph)
			{
				SDR_DEBUGPRINT(("Existing AUGraph found.\n"));
				OSStatus result = AUGraphClose(mAudioGraph);
				if(result)
				{
					SDR_DEBUGPRINT(("Error closing AUGraph %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
				}

				SDR_DEBUGPRINT(("Disposing AU Graph 5.\n"));
				result = DisposeAUGraph(mAudioGraph);
				if(result)
				{
					SDR_DEBUGPRINT(("Error disposing AUGraph %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
				}

				mAudioGraph = nil;
//				mMixerUnit = nil;
//				mRemoteIOUnit = NULL;
			}

			if(mRemoteIOUnit != NULL)
			{
				AudioComponentInstanceDispose(mRemoteIOUnit);
				mRemoteIOUnit = NULL; // disposal frees rIOUnit, so just set pointer to nil
			}

			if(mMixerUnit != nil)
			{
				if(mcMixerUser) [mcMixerUser setAu:nil];
				mcMixerUser = nil;
				AudioComponentInstanceDispose(mMixerUnit);
				mMixerUnit = nil;
			}

			if(audioDSPThread != nil)
			{
				SDR_DEBUGPRINT(("disable thread 1\n"));
				audioDSPThread->dspDisable();
			}


#ifndef DISABLE_HPF
			if (dcFilter) delete[] dcFilter;
#endif
		}

		if(useDemoMode == TRUE)
		{
			//			mCurrentHardwareInputNumberChannels = 2; // assume stereo audio files
			if([self setupAUGraph])
			{
				SDR_DEBUGPRINT(("Error setting up AU graph for recorded audio!\n"));
				audioStatus = AudioError;
				return result;
			}
			else
			{
				result = AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1.0, 0);
				if(result) { SDR_DEBUGPRINT(("AudioUnitSetParameter kMultiChannelMixerParam_Volume Input result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); }
				result = AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, 1.0, 0);
				if(result) { SDR_DEBUGPRINT(("AudioUnitSetParameter kMultiChannelMixerParam_Volume Output result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); }

			}


			// Changing the number of audio channels requires restarting the FFT objects, so kill them
			if(mCurrentHardwareInputNumberChannels != HoldCurrentHardwareInputNumberChannels)
			{
				HoldCurrentHardwareInputNumberChannels = mCurrentHardwareInputNumberChannels;

				if(fftBufferManager != nil)
				{
					fftBufferManager->setNumAudioChannels(mCurrentHardwareInputNumberChannels);
				}
			}

			// Set up audio graph for playing audio loop from file
			mAudioMode = AudioModeDemonstration;

			sampleRateBandwidth = (mCurrentHardwareInputNumberChannels * kGraphSampleRate) / 2;

			if(mLiveAudioAllowed)
			{
				SDR_DEBUGPRINT(("Audio input unavailable: using demo mode\n"));
			}
			else
			{
				SDR_DEBUGPRINT(("Demo mode only setting in effect: using demo mode\n"));
			}

			SDR_DEBUGPRINT(("MMC starting fft path 2\n"));
			if(![self ensureDSPResourcesForChannels:(int)mCurrentHardwareInputNumberChannels])
			{
				SDR_DEBUGPRINT(("Unable to create DSP resources\n"));
				audioStatus = AudioError;
				return 1;
			}
		}
	}
	catch (...)
	{
		fprintf(stderr, "Error setting up audio in setupAudioSession\n");
		audioStatus	= AudioError;
#ifndef DISABLE_HPF
		if (dcFilter) delete[] dcFilter;
#endif
	}

	if(audioStatus == AudioNotReady)
	{
		audioStatus	= AudioReady;
	}

#ifdef SDR_DEBUG
	[self printAudioSetupResults:audioStatus numChans:mCurrentHardwareInputNumberChannels];
#endif

	return(result);
}




#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
- (OSStatus)setupAudioSession_old
{
	static UInt32 HoldCurrentHardwareInputNumberChannels = 0;
	BOOL useDemoMode = TRUE;
	UInt32 AudioInputAvailable;
	OSStatus result=0;

	audioStatus	= AudioNotReady;

	try
	{
		// Initialize and configure the audio session

		result = AudioSessionInitialize(NULL, NULL, audioInterruptionListener, self);

		if(result == kAudioSessionAlreadyInitialized)
		{
			SDR_DEBUGPRINT(("Setting up audio session again.\n"));

			//			result = AudioSessionSetActive(TRUE);
			//			if(result)
			//			{
			//				SDR_DEBUGPRINT(("AudioSessionSetActive result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			//				audioStatus = AudioError;
			//				return result;
			//			}

		}
		else if(result == kAudioSessionInitializationError)
		{
			SDR_DEBUGPRINT(("Fatal error: couldn't set audio session active!\n"));
			audioStatus = AudioError;
			return result;
		}
		else
		{
			if(result)
			{
				SDR_DEBUGPRINT(("Error initializing AudioSession (continuing anyway): result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
				return result;
			}

			//			result = AudioSessionSetActive(TRUE);

			//			if(result)
			//			{
			//				SDR_DEBUGPRINT(("Couldn't set audio session active.\n"));
			//				return result;
			//			}
		}

		XThrowIfError(AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioPropListener_old, self), "couldn't set property listener");

		Float32 preferredBufferSize = .005;
		XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(preferredBufferSize), &preferredBufferSize), "couldn't set i/o buffer duration");

		UInt32 size = sizeof(hwSampleRate);
		XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &hwSampleRate), "couldn't get hw sample rate");
		SDR_DEBUGPRINT(("Hardware sample rate: %5.0f\n", hwSampleRate));

		// TODO: How to make it recognize a connected Bluetooth headset?


		/*
		 kAudioSessionProperty_AudioInputAvailable                   = 'aiav',   // UInt32           (get only/property listener)
		 */
		size = sizeof(AudioInputAvailable);
		XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, &size, &AudioInputAvailable), "couldn't get AudioInputAvailable");
		SDR_DEBUGPRINT(("Audio input available: %s\n", ((int)AudioInputAvailable == 1) ? "Yes":"No"));

		if(AudioInputAvailable == 1)
		{
			UInt32 audioCategory;
			UInt32 size = sizeof(audioCategory);
			AudioSessionGetProperty(kAudioSessionProperty_AudioCategory, &size, &audioCategory);

			if(audioCategory != kAudioSessionCategory_PlayAndRecord)
			{
				audioCategory = kAudioSessionCategory_PlayAndRecord;
				XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory), "couldn't set audio category");
			}
		}
		else
		{
			UInt32 audioCategory = kAudioSessionCategory_MediaPlayback;
			XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory), "couldn't set audio category");

		}

		result = AudioSessionSetActive(TRUE);
		if(result)
		{
			SDR_DEBUGPRINT(("AudioSessionSetActive result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			//				audioStatus = AudioError;
			//				return result;
		}


		if((AudioInputAvailable == 1) && mLiveAudioAllowed)
		{
			bool validchannelcount = FALSE;

			/*
			 kAudioSessionProperty_CurrentHardwareInputNumberChannels    = 'chic',   // UInt32           (get only)
			 */
			size = sizeof(mCurrentHardwareInputNumberChannels);
			XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels, &size, &mCurrentHardwareInputNumberChannels), "couldn't get CurrentHardwareInputNumberChannels");
			SDR_DEBUGPRINT(("Number of audio input channels found: %d\n", (int)mCurrentHardwareInputNumberChannels));

			if(mCurrentHardwareInputNumberChannels == 1)
			{
				validchannelcount = TRUE;
				SDR_DEBUGPRINT(("Only one input channel found: narrow SDR only\n"));
				sampleRateBandwidth = (UInt32)(hwSampleRate / 2.0);
				mAudioMode = AudioModeMonaural;
			}
			else if(mCurrentHardwareInputNumberChannels == 2)
			{
				validchannelcount = TRUE;
				SDR_DEBUGPRINT(("Success: Two audio input channels found!\n"));
				sampleRateBandwidth = (UInt32)hwSampleRate;
				mAudioMode = AudioModeStereo;
			}

			if(validchannelcount)
			{
				// Changing the number of audio channels requires restarting the FFT objects, so kill them
				if(mCurrentHardwareInputNumberChannels != HoldCurrentHardwareInputNumberChannels)
				{
					HoldCurrentHardwareInputNumberChannels = mCurrentHardwareInputNumberChannels;

					if(fftBufferManager != nil)
					{
						fftBufferManager->setNumAudioChannels(mCurrentHardwareInputNumberChannels);
					}
				}

				// Set up remote i/o unit for receiving input from mic port
				if(![self setupRIOGraph:mCurrentHardwareInputNumberChannels])
				{
					int maxFPS;
					UInt32 size = sizeof(maxFPS);
					XThrowIfError(AudioUnitGetProperty(mRemoteIOUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, &size), "couldn't get the remote I/O unit's max frames per slice");
					SDR_DEBUGPRINT(("Maximum frames per slice: %d\n", maxFPS));

					switch(maxFPS)
					{
						case 1024:
						case 2048:
						case 4096:
						case 8192:

							SDR_DEBUGPRINT(("MMC starting fft path 1\n"));
							if(![self ensureDSPResourcesForChannels:(int)mCurrentHardwareInputNumberChannels])
							{
								SDR_DEBUGPRINT(("Unable to create DSP resources\n"));
								audioStatus = AudioError;
								return 1;
							}

							useDemoMode = FALSE;
							// start flow of live audio
							result = AUGraphStart(mAudioGraph);
							break;

						default:
							SDR_DEBUGPRINT(("Error: unsupported max FPS\n"));
							//				assert("Error: unsupported max FPS\n";
							break;
					}
				}
				else
				{
					SDR_DEBUGPRINT(("Error: could not create streaming augraph %d\n", (int)mCurrentHardwareInputNumberChannels));
					useDemoMode = TRUE; //Use demo mode since live audio cannot be supported

				}
			}
			else
			{
				SDR_DEBUGPRINT(("Unsupported number of input channels: %d\n", (int)mCurrentHardwareInputNumberChannels));
				useDemoMode = TRUE; //Use demo mode since live audio cannot be supported
			}

			if(useDemoMode == TRUE) // only happens if invalid channel count was read above
			{
				if(mAudioGraph)
				{
					SDR_DEBUGPRINT(("Existing AUGraph found.\n"));
					OSStatus result = AUGraphClose(mAudioGraph);
					if(result)
					{
						SDR_DEBUGPRINT(("Error closing AUGraph %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
					}

					SDR_DEBUGPRINT(("Disposing AU Graph 5.\n"));
					result = DisposeAUGraph(mAudioGraph);
					if(result)
					{
						SDR_DEBUGPRINT(("Error disposing AUGraph %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
					}

					mAudioGraph = nil;
					mMixerUnit = nil;
					mRemoteIOUnit = NULL;
				}

				if(mRemoteIOUnit != NULL)
				{
					AudioComponentInstanceDispose(mRemoteIOUnit);
					mRemoteIOUnit = NULL; // disposal frees rIOUnit, so just set pointer to nil
				}

				if(mMixerUnit != nil)
				{
					if(mcMixerUser) [mcMixerUser setAu:nil];
					mcMixerUser = nil;
					AudioComponentInstanceDispose(mMixerUnit);
					mMixerUnit = nil;
				}

				if(audioDSPThread != nil)
				{
					SDR_DEBUGPRINT(("disable thread 1\n"));
					audioDSPThread->dspDisable();
				}


#ifndef DISABLE_HPF
				if (dcFilter) delete[] dcFilter;
#endif
			}
		}


		if(useDemoMode == TRUE)
		{
			//			mCurrentHardwareInputNumberChannels = 2; // assume stereo audio files
			if([self setupAUGraph])
			{
				SDR_DEBUGPRINT(("Error setting up AU graph for recorded audio!\n"));
				audioStatus = AudioError;
				return result;
			}
			else
			{
				result = AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1.0, 0);
				if(result) { SDR_DEBUGPRINT(("AudioUnitSetParameter kMultiChannelMixerParam_Volume Input result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); }
				result = AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, 1.0, 0);
				if(result) { SDR_DEBUGPRINT(("AudioUnitSetParameter kMultiChannelMixerParam_Volume Output result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); }

			}


			// Changing the number of audio channels requires restarting the FFT objects, so kill them
			if(mCurrentHardwareInputNumberChannels != HoldCurrentHardwareInputNumberChannels)
			{
				HoldCurrentHardwareInputNumberChannels = mCurrentHardwareInputNumberChannels;

				if(fftBufferManager != nil)
				{
					fftBufferManager->setNumAudioChannels(mCurrentHardwareInputNumberChannels);
				}
			}

			// Set up audio graph for playing audio loop from file
			mAudioMode = AudioModeDemonstration;

			sampleRateBandwidth = (mCurrentHardwareInputNumberChannels * kGraphSampleRate) / 2;

			if(mLiveAudioAllowed)
			{
				SDR_DEBUGPRINT(("Audio input unavailable: using demo mode\n"));
			}
			else
			{
				SDR_DEBUGPRINT(("Demo mode only setting in effect: using demo mode\n"));
			}

			SDR_DEBUGPRINT(("MMC starting fft path 2\n"));
			if(![self ensureDSPResourcesForChannels:(int)mCurrentHardwareInputNumberChannels])
			{
				SDR_DEBUGPRINT(("Unable to create DSP resources\n"));
				audioStatus = AudioError;
				return 1;
			}
		}
	}
	catch (...)
	{
		fprintf(stderr, "Error setting up audio in setupAudioSession\n");
		audioStatus	= AudioError;
#ifndef DISABLE_HPF
		if (dcFilter) delete[] dcFilter;
#endif
	}

	if(audioStatus == AudioNotReady)
	{
		audioStatus	= AudioReady;
	}

#ifdef SDR_DEBUG
	[self printAudioSetupResults:audioStatus numChans:mCurrentHardwareInputNumberChannels];
#endif

	return(result);
}
#endif



#ifdef SDR_DEBUG
- (void)printAudioSetupResults:(iSDRAudioStatus)status numChans:(UInt32)CurrentHardwareInputNumberChannels
{
	AVAudioSession* session = [AVAudioSession sharedInstance];

	if(session)
	{
		SDR_DEBUGPRINT(("\n===================================="));
		SDR_DEBUGPRINT(("\nAudio setup results:\n"));

		SDR_DEBUGPRINT(("  Category: %s\n", [session.category UTF8String]));

		if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
		{
			if([session.currentRoute.inputs count] > 0)
			{
				for(AVAudioSessionPortDescription* avaspd in session.currentRoute.inputs)
				{
					SDR_DEBUGPRINT(("  Input:  %s - %s\n", [avaspd.portName UTF8String], [avaspd.portType UTF8String]));
				}
			}
			else
			{
				SDR_DEBUGPRINT(("  Input:  category does not support\n"));
			}

			if([session.currentRoute.outputs count] > 0)
			{
				for(AVAudioSessionPortDescription* avaspd in session.currentRoute.outputs)
				{
					SDR_DEBUGPRINT(("  Output: %s - %s\n", [avaspd.portName UTF8String], [avaspd.portType UTF8String]));
				}
			}
			else
			{
				SDR_DEBUGPRINT(("  Output: category does not support\n"));
			}
		}

		switch(status)
		{
			case AudioError:
				SDR_DEBUGPRINT(("  audioStatus:              AudioError\n"));
				break;

			case AudioReady:
				SDR_DEBUGPRINT(("  audioStatus:              AudioReady\n"));
				break;

			case AudioNotReady:
				SDR_DEBUGPRINT(("  audioStatus:              AudioNotReady\n"));
				break;

			default:
				SDR_DEBUGPRINT(("  audioStatus:              Unknown Error!\n"));
				break;
		}

		SDR_DEBUGPRINT(("  sampleRateBandwidth:      %u\n", (unsigned int)sampleRateBandwidth));
		SDR_DEBUGPRINT(("  Number of audio channels: %u\n", (unsigned int)CurrentHardwareInputNumberChannels));

		if(mAudioMode == AudioModeDemonstration)
		{
			SDR_DEBUGPRINT(("  audioMode:           AudioModeDemonstration\n"));
		}
		else
		{
			SDR_DEBUGPRINT(("  audioMode:           %s\n", (mAudioMode == AudioModeMonaural) ? "Mono Mic":"Stereo Mic"));
		}

		SDR_DEBUGPRINT(("  Remote i/o unit:     %s\n", (mRemoteIOUnit != NULL) ? "exists":"NULL"));
		SDR_DEBUGPRINT(("  MCMixer unit:        %s\n", (mMixerUnit != nil) ? "exists":"nil"));
		SDR_DEBUGPRINT(("  Audio graph:         %s\n", (mAudioGraph != nil) ? "exists":"nil"));
		SDR_DEBUGPRINT(("  Thread:              %s\n", (audioDSPThread != nil) ? "exists":"nil"));
		SDR_DEBUGPRINT(("  FFTBuffer:           %s\n", (fftBufferManager != nil) ? "exists":"nil"));
		SDR_DEBUGPRINT(("====================================\n\n"));
	}

	return;
}
#endif


- (BOOL)shutDownAudio
{
	BOOL success = TRUE;

	if(mcMixerUser) [mcMixerUser setAu:nil];
	mcMixerUser = nil;

	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:AVAudioSessionRouteChangeNotification
												  object:[AVAudioSession sharedInstance]];
	[self stopAUGraph:FALSE];

	if(audioDSPThread)
	{
		SDR_DEBUGPRINT(("pausing thread 2\n"));
		audioDSPThread->dspDisable();
	}
	else
	{
		success = FALSE;
	}

    if(mAudioGraph)
	{
		SDR_DEBUGPRINT(("shutDownAudio: Existing AUGraph found.\n"));
		OSStatus result = AUGraphClose(mAudioGraph);
		if(result)
		{
			SDR_DEBUGPRINT(("Error closing AUGraph %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			success = FALSE;
		}

		SDR_DEBUGPRINT(("Disposing AU Graph 4.\n"));
		result = DisposeAUGraph(mAudioGraph);
		if(result)
		{
			SDR_DEBUGPRINT(("Error disposing AUGraph %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			success = FALSE;
		}

		mAudioGraph = nil;
		mMixerUnit = nil;
		mRemoteIOUnit = NULL;
	}

	if(mRemoteIOUnit != NULL)
	{
		SDR_DEBUGPRINT(("Deleting RIO Unit.\n"));
		AudioComponentInstanceDispose(mRemoteIOUnit);
		mRemoteIOUnit = NULL; // disposal frees rIOUnit, so just set pointer to nil
	}

	if(mMixerUnit != nil)
	{
		SDR_DEBUGPRINT(("Deleting Mixer Unit.\n"));
		AudioComponentInstanceDispose(mMixerUnit);
		mMixerUnit = nil;
	}

#ifndef DISABLE_HPF
	if (dcFilter) delete[] dcFilter;
#endif

	SDR_DEBUGPRINT(("Audio shutdown complete.\n"));
	return success;
}



- (bool)shutDownAudio_old
{
	bool success = TRUE;

	if(mcMixerUser) [mcMixerUser setAu:nil];
	mcMixerUser = nil;

	[self stopAUGraph:FALSE];

	if(audioDSPThread)
	{
		SDR_DEBUGPRINT(("pausing thread 2\n"));
		audioDSPThread->dspDisable();
	}
	else
	{
		success = FALSE;
	}

    if(mAudioGraph)
	{
		SDR_DEBUGPRINT(("shutDownAudio: Existing AUGraph found.\n"));
		OSStatus result = AUGraphClose(mAudioGraph);
		if(result)
		{
			SDR_DEBUGPRINT(("Error closing AUGraph %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			success = FALSE;
		}

		SDR_DEBUGPRINT(("Disposing AU Graph 4.\n"));
		result = DisposeAUGraph(mAudioGraph);
		if(result)
		{
			SDR_DEBUGPRINT(("Error disposing AUGraph %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			success = FALSE;
		}

		mAudioGraph = nil;
		mMixerUnit = nil;
		mRemoteIOUnit = NULL;
	}

	if(mRemoteIOUnit != NULL)
	{
		SDR_DEBUGPRINT(("Deleting RIO Unit.\n"));
		AudioComponentInstanceDispose(mRemoteIOUnit);
		mRemoteIOUnit = NULL; // disposal frees rIOUnit, so just set pointer to nil
	}

	if(mMixerUnit != nil)
	{
		SDR_DEBUGPRINT(("Deleting Mixer Unit.\n"));
		AudioComponentInstanceDispose(mMixerUnit);
		mMixerUnit = nil;
	}

#ifndef DISABLE_HPF
	if (dcFilter) delete[] dcFilter;
#endif

	SDR_DEBUGPRINT(("Audio shutdown complete.\n"));
	return success;
}


// Attempts to reconfigure Audio Graph and Audio Units without recreating anything
- (BOOL)reconfigureAudioGuts_old
{
	UInt32 holdHardwareInputNumberChannels = mCurrentHardwareInputNumberChannels;
	BOOL useDemoMode = TRUE;
	OSStatus result=0;

	try
	{
#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_6_0)
		// Get the app's audioSession singleton object
		AVAudioSession* session = [AVAudioSession sharedInstance];

		//error handling
		NSError* audioSessionError = nil;

		SDR_DEBUGPRINT(("Setting session not active!\n"));
		[session setActive:NO error:&audioSessionError]; // shut down the audio session if it is active

		/*****************************************************************************************
		 * Select Audiosession Category                                                          *
		 *****************************************************************************************/

		if(mLiveAudioAllowed)
		{
			BOOL success = [session.category isEqualToString:AVAudioSessionCategoryPlayAndRecord];

			//		if(![session.category isEqualToString:AVAudioSessionCategoryMultiRoute])
			if(![session.category isEqualToString:AVAudioSessionCategoryPlayAndRecord])
			{
				SDR_DEBUGPRINT(("Setting session category: AVAudioSessionCategoryPlayAndRecord.\n"));

				//set the audioSession category.
				//Needs to be Record or PlayAndRecord to use audioRouteOverride: AVAudioSessionCategoryPlayAndRecord
				//success = [session setCategory:AVAudioSessionCategoryMultiRoute error:&audioSessionError];
				//success = [session setCategory:AVAudioSessionCategoryMultiRoute withOptions:(AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionDefaultToSpeaker) error:&audioSessionError];
				success = [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:(AVAudioSessionCategoryOptionAllowBluetoothHFP | AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers) error:&audioSessionError];

				if(audioSessionError)
				{
					NSLog(@"AVAudioSession error setting category: %ld, %@",(long)audioSessionError.code, audioSessionError.localizedDescription);
					//				audioStatus = AudioError;
					//				result = kAudioSessionInitializationError;
					//				return result;
				}
			}

			if(!success)
			{
				if(![session.category isEqualToString:AVAudioSessionCategoryMultiRoute])
				{
					SDR_DEBUGPRINT(("Setting session category: isEqualToString:AVAudioSessionCategoryMultiRoute.\n"));

					//set the audioSession category.
					//Needs to be Record or PlayAndRecord to use audioRouteOverride:
					//[session setCategory:AVAudioSessionCategoryPlayAndRecord error:&audioSessionError];
					[session setCategory:AVAudioSessionCategoryMultiRoute withOptions:(AVAudioSessionCategoryOptionAllowBluetoothHFP | AVAudioSessionCategoryOptionDefaultToSpeaker) error:&audioSessionError];

					if(audioSessionError)
					{
						NSLog(@"AVAudioSession error setting category: %ld, %@",(long)audioSessionError.code, audioSessionError.localizedDescription);
						audioStatus = AudioError;
						result = kAudioSessionInitializationError;
						return result;
					}
				}
			}
		}
		else
		{
			if(![session.category isEqualToString:AVAudioSessionCategoryPlayback])
			{
				SDR_DEBUGPRINT(("Setting session category: AVAudioSessionCategoryPlayback.\n"));

				//set the audioSession category.
				[session setCategory:AVAudioSessionCategoryPlayback error:&audioSessionError];

				if(audioSessionError)
				{
					NSLog(@"AVAudioSession error setting category: %ld, %@",(long)audioSessionError.code, audioSessionError.localizedDescription);
					audioStatus = AudioError;
					result = kAudioSessionInitializationError;
					return result;
				}
			}
		}

		/*****************************************************************************************
		 * Activate the Audio Session                                                            *
		 *****************************************************************************************/

		//activate the audio session
		SDR_DEBUGPRINT(("Setting session active!\n"));
		[session setActive:YES error:&audioSessionError];
		SDR_DEBUGPRINT(("Checking session buffer duration. Preferred: %0.5lf Actual: %0.5lf\n", session.preferredIOBufferDuration, session.IOBufferDuration));

		if(audioSessionError)
		{
			NSLog(@"AVAudioSession error activating audio session: %ld, %@",(long)audioSessionError.code, audioSessionError.localizedDescription);
			audioStatus = AudioError;
			result = kAudioSessionInitializationError;
			return result;
		}

		/*****************************************************************************************
		 * Read the Audio Session settings                                                       *
		 *****************************************************************************************/

		// Read actual values
		hwSampleRate = session.sampleRate;

		[self registerForAudioSessionNotifications:session];

		SDR_DEBUGPRINT(("audioSession active\n"));
		audioSessionCategory = session.category; // record current setting
		mCurrentHardwareInputNumberChannels = (UInt32)session.inputNumberOfChannels;
#else
		/*
		 kAudioSessionProperty_AudioInputAvailable                   = 'aiav',   // UInt32           (get only/property listener)
		 */
		UInt32 audioInputAvailable;
		UInt32 size = sizeof(audioInputAvailable);
		XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, &size, &audioInputAvailable), "couldn't get AudioInputAvailable");
		SDR_DEBUGPRINT(("Audio input available: %s\n", ((int)audioInputAvailable == 1) ? "Yes":"No"));

		if(audioInputAvailable == 1)
		{
			UInt32 audioCategory;
			UInt32 size = sizeof(audioCategory);
			AudioSessionGetProperty(kAudioSessionProperty_AudioCategory, &size, &audioCategory);

			if(audioCategory != kAudioSessionCategory_PlayAndRecord)
			{
				audioCategory = kAudioSessionCategory_PlayAndRecord;
				XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory), "couldn't set audio category");
			}
		}
		else
		{
			UInt32 audioCategory = kAudioSessionCategory_MediaPlayback;
			XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory), "couldn't set audio category");

		}

		result = AudioSessionSetActive(TRUE);
		if(result)
		{
			SDR_DEBUGPRINT(("AudioSessionSetActive result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			//				audioStatus = AudioError;
			//				return result;
		}

		if((audioInputAvailable == 1) && mLiveAudioAllowed)
		{
			useDemoMode = FALSE;

			/*
			 kAudioSessionProperty_CurrentHardwareInputNumberChannels    = 'chic',   // UInt32           (get only)
			 */
			size = sizeof(mCurrentHardwareInputNumberChannels);
			XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels, &size, &mCurrentHardwareInputNumberChannels), "couldn't get CurrentHardwareInputNumberChannels");
			SDR_DEBUGPRINT(("Number of audio input channels found: %d\n", (int)mCurrentHardwareInputNumberChannels));
		}
#endif

		if(!useDemoMode)
		{
			BOOL validchannelcount = FALSE;

			if(mCurrentHardwareInputNumberChannels == 1)
			{
				validchannelcount = TRUE;
				SDR_DEBUGPRINT(("Only one input channel found: narrow SDR only\n"));
				sampleRateBandwidth = (UInt32)(hwSampleRate / 2.0);
				mAudioMode = AudioModeMonaural;
			}
			else if(mCurrentHardwareInputNumberChannels == 2)
			{
				validchannelcount = TRUE;
				SDR_DEBUGPRINT(("Success: Two audio input channels found!\n"));
				sampleRateBandwidth = (UInt32)hwSampleRate;
				mAudioMode = AudioModeStereo;
			}

			if(validchannelcount)
			{
				// Changing the number of audio channels requires restarting the FFT objects, so kill them
				if(mCurrentHardwareInputNumberChannels != holdHardwareInputNumberChannels)
				{
					holdHardwareInputNumberChannels = mCurrentHardwareInputNumberChannels;

					if(fftBufferManager != nil)
					{
						fftBufferManager->setNumAudioChannels(mCurrentHardwareInputNumberChannels);
					}
				}

				// Set up remote i/o unit for receiving input from mic port
				if(![self setupRIOGraph:mCurrentHardwareInputNumberChannels])
				{
					int maxFPS;
					UInt32 size = sizeof(maxFPS);
					XThrowIfError(AudioUnitGetProperty(mRemoteIOUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, &size), "couldn't get the remote I/O unit's max frames per slice");
					SDR_DEBUGPRINT(("Maximum frames per slice: %d\n", maxFPS));

					switch(maxFPS)
					{
						case 1024:
						case 2048:
						case 4096:
						case 8192:

							SDR_DEBUGPRINT(("MMC starting fft path 1\n"));
							if(![self ensureDSPResourcesForChannels:(int)mCurrentHardwareInputNumberChannels])
							{
								SDR_DEBUGPRINT(("Unable to create DSP resources\n"));
								audioStatus = AudioError;
								return 1;
							}

							useDemoMode = FALSE;
							// start flow of live audio
							result = AUGraphStart(mAudioGraph);
							break;

						default:
							SDR_DEBUGPRINT(("Error: unsupported max FPS\n"));
							//				assert("Error: unsupported max FPS\n";
							break;
					}
				}
				else
				{
					SDR_DEBUGPRINT(("Error: could not create streaming augraph %d\n", (int)mCurrentHardwareInputNumberChannels));
					useDemoMode = TRUE; //Use demo mode since live audio cannot be supported

				}
			}
			else
			{
				SDR_DEBUGPRINT(("Unsupported number of input channels: %d\n", (int)mCurrentHardwareInputNumberChannels));
				useDemoMode = TRUE; //Use demo mode since live audio cannot be supported
			}

			if(useDemoMode == TRUE) // only happens if invalid channel count was read above
			{
				if(mAudioGraph)
				{
					SDR_DEBUGPRINT(("Existing AUGraph found.\n"));
					OSStatus result = AUGraphClose(mAudioGraph);
					if(result)
					{
						SDR_DEBUGPRINT(("Error closing AUGraph %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
					}

					SDR_DEBUGPRINT(("Disposing AU Graph 5.\n"));
					result = DisposeAUGraph(mAudioGraph);
					if(result)
					{
						SDR_DEBUGPRINT(("Error disposing AUGraph %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
					}

					mAudioGraph = nil;
					mMixerUnit = nil;
					mRemoteIOUnit = NULL;
				}

				if(mRemoteIOUnit != NULL)
				{
					AudioComponentInstanceDispose(mRemoteIOUnit);
					mRemoteIOUnit = NULL; // disposal frees rIOUnit, so just set pointer to nil
				}

				if(mMixerUnit != nil)
				{
					if(mcMixerUser) [mcMixerUser setAu:nil];
					mcMixerUser = nil;
					AudioComponentInstanceDispose(mMixerUnit);
					mMixerUnit = nil;
				}

				if(audioDSPThread != nil)
				{
					SDR_DEBUGPRINT(("disable thread 1\n"));
					audioDSPThread->dspDisable();
				}

#ifndef DISABLE_HPF
				if (dcFilter) delete[] dcFilter;
#endif
			}
		}

		if(useDemoMode == TRUE)
		{
			//			mCurrentHardwareInputNumberChannels = 2; // assume stereo audio files
			if([self setupAUGraph])
			{
				SDR_DEBUGPRINT(("Error setting up AU graph for recorded audio!\n"));
				audioStatus = AudioError;
				return result;
			}
			else
			{
				result = AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1.0, 0);
				if(result) { SDR_DEBUGPRINT(("AudioUnitSetParameter kMultiChannelMixerParam_Volume Input result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); }
				result = AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, 1.0, 0);
				if(result) { SDR_DEBUGPRINT(("AudioUnitSetParameter kMultiChannelMixerParam_Volume Output result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); }

			}


			// Changing the number of audio channels requires restarting the FFT objects, so kill them
			if(mCurrentHardwareInputNumberChannels != holdHardwareInputNumberChannels)
			{
				if(fftBufferManager != nil)
				{
					fftBufferManager->setNumAudioChannels(mCurrentHardwareInputNumberChannels);
				}
			}

			// Set up audio graph for playing audio loop from file
			mAudioMode = AudioModeDemonstration;

			sampleRateBandwidth = (mCurrentHardwareInputNumberChannels * kGraphSampleRate) / 2;

			if(mLiveAudioAllowed)
			{
				SDR_DEBUGPRINT(("Audio input unavailable: using demo mode\n"));
			}
			else
			{
				SDR_DEBUGPRINT(("Demo mode only setting in effect: using demo mode\n"));
			}

			SDR_DEBUGPRINT(("MMC starting fft path 2\n"));
			if(![self ensureDSPResourcesForChannels:(int)mCurrentHardwareInputNumberChannels])
			{
				SDR_DEBUGPRINT(("Unable to create DSP resources\n"));
				audioStatus = AudioError;
				return 1;
			}
		}
	}
	catch (...)
	{
		fprintf(stderr, "Error setting up audio in setupAudioSession\n");
		audioStatus	= AudioError;
#ifndef DISABLE_HPF
		if (dcFilter) delete[] dcFilter;
#endif
	}

	if(audioStatus == AudioNotReady)
	{
		audioStatus	= AudioReady;
	}

#ifdef SDR_DEBUG
	[self printAudioSetupResults:audioStatus numChans:mCurrentHardwareInputNumberChannels];
#endif

	return(result);
}


- (void)adjustAudioRouting:(UInt32)reason
{
	[(id)delegate performSelectorOnMainThread:@selector(showMPVolumeView) withObject:nil waitUntilDone:NO];

	if(mLiveAudioAllowed)
		SDR_DEBUGPRINT(("adjustAudioRouting: live audio allowed\n"));
	else
		SDR_DEBUGPRINT(("adjustAudioRouting: demo mode only\n"));

	switch(reason)
	{
			//			kAudioSessionRouteChangeReason_Unknown                    = 0,
			//			kAudioSessionRouteChangeReason_NewDeviceAvailable         = 1,
			//			kAudioSessionRouteChangeReason_OldDeviceUnavailable       = 2,
			//			kAudioSessionRouteChangeReason_CategoryChange             = 3,
			//			kAudioSessionRouteChangeReason_Override                   = 4,
			// this enum has no constant with a value of 5
			//			kAudioSessionRouteChangeReason_WakeFromSleep              = 6,
			//			kAudioSessionRouteChangeReason_NoSuitableRouteForCategory = 7

		case kAudioSessionRouteChangeReason_NoSuitableRouteForCategory:
		case kAudioSessionRouteChangeReason_NewDeviceAvailable:
		case kAudioSessionRouteChangeReason_OldDeviceUnavailable:
		{
			if(SYSTEM_VERSION_LESS_THAN(@"6.0"))
			{
				NSLog(@"Error: adjustAudioRouting called for wrong OS version!");
				return;
			}

			AVAudioSession* session = [AVAudioSession sharedInstance];
			if(mCurrentHardwareInputNumberChannels == session.inputNumberOfChannels)
			{
				// Let the hardware handle the change
				return;
			}

			id user = self.mcMixerUser;
			[self.mcMixerUser setAu:nil];
			self.mcMixerUser = nil;

			[self reconfigureAudioGuts_old]; // attempt to reconfigure with minimal recreation of objects

			self.mcMixerUser = user;
			[self.mcMixerUser setAu:self.mMixerUnit];
			[delegate reconfigureDisplaySetup:reInitializeAudioSettings];
			AUGraphStart(mAudioGraph);
		}
			break;

			// Headphone was removed from iPhone (headphone with or without mic)
		case kAudioSessionRouteChangeReason_CategoryChange:
		{
			/*
			 NSString *const AVAudioSessionCategoryAmbient;
			 NSString *const AVAudioSessionCategorySoloAmbient;
			 NSString *const AVAudioSessionCategoryPlayback;
			 NSString *const AVAudioSessionCategoryRecord;
			 NSString *const AVAudioSessionCategoryPlayAndRecord;
			 NSString *const AVAudioSessionCategoryAudioProcessing;
			 NSString *const AVAudioSessionCategoryMultiRoute;
			 */

			AVAudioSession *session = [AVAudioSession sharedInstance];

			//error handling
			NSError* audioSessionError = nil;

			[session setActive:NO error:&audioSessionError]; // shut down the audio session if it is active
			NSString* audioSessionCategory = session.category;
			[session setActive:YES error:&audioSessionError]; // enable the audio session if it is shut down

			if([audioSessionCategory isEqualToString:AVAudioSessionCategoryAmbient])
			{
				/*  Use this category for background sounds such as rain, car engine noise, etc.
				 Mixes with other music. */
				SDR_DEBUGPRINT(("Audio session category: AVAudioSessionCategoryAmbient\n"));
			}
			else if([audioSessionCategory isEqualToString:AVAudioSessionCategorySoloAmbient])
			{
				/*  Use this category for background sounds.  Other music will stop playing. */
				SDR_DEBUGPRINT(("Audio session category: AVAudioSessionCategorySoloAmbient\n"));
			}
			else if([audioSessionCategory isEqualToString:AVAudioSessionCategoryPlayback])
			{
				/* Use this category for music tracks.*/
				SDR_DEBUGPRINT(("Audio session category: AVAudioSessionCategoryPlayback\n"));
			}
			else if([audioSessionCategory isEqualToString:AVAudioSessionCategoryRecord])
			{
				/*  Use this category when recording audio. */
				SDR_DEBUGPRINT(("Audio session category: AVAudioSessionCategoryRecord\n"));
			}
			else if([audioSessionCategory isEqualToString:AVAudioSessionCategoryPlayAndRecord])
			{
				/*  Use this category when recording and playing back audio. */
				SDR_DEBUGPRINT(("Audio session category: AVAudioSessionCategoryPlayAndRecord\n"));
			}
			else if([audioSessionCategory isEqualToString:AVAudioSessionCategoryMultiRoute])
			{
				/*  Use this category to customize the usage of available audio accessories and built-in audio hardware.
				 For example, this category provides an application with the ability to use an available USB output
				 and headphone output simultaneously for separate, distinct streams of audio data. Use of
				 this category by an application requires a more detailed knowledge of, and interaction with,
				 the capabilities of the available audio routes.  May be used for input, output, or both.
				 Note that not all output types and output combinations are eligible for multi-route.  Input is limited
				 to the last-in input port. Eligible inputs consist of the following:
				 AVAudioSessionPortUSBAudio, AVAudioSessionPortHeadsetMic, and AVAudioSessionPortBuiltInMic.
				 Eligible outputs consist of the following:
				 AVAudioSessionPortUSBAudio, AVAudioSessionPortLineOut, AVAudioSessionPortHeadphones, AVAudioSessionPortHDMI,
				 and AVAudioSessionPortBuiltInSpeaker.
				 Note that AVAudioSessionPortBuiltInSpeaker is only allowed to be used when there are no other eligible
				 outputs connected.  */
				SDR_DEBUGPRINT(("Audio session category: AVAudioSessionCategoryMultiRoute\n"));
			}
			else
			{
				/* Undefined category! */
				NSLog(@"Error: unknown audio category");
			}

			SDR_DEBUGPRINT(("Leaving audio route unchanged...\n"));
		}
			break;


		case kAudioSessionRouteChangeReason_Override:
		{
			SDR_DEBUGPRINT(("Override: ignoring.\n"));
		}
			break;

		case kAudioSessionRouteChangeReason_WakeFromSleep:
		{
			SDR_DEBUGPRINT(("Wake From Sleep: ignoring.\n"));
		}
			break;

		case kAudioSessionRouteChangeReason_Unknown:
		default:
		{
			if(SYSTEM_VERSION_LESS_THAN(@"6.0"))
			{
				NSLog(@"Error: adjustAudioRouting called for wrong OS version!");
				return;
			}

			AVAudioSession* session = [AVAudioSession sharedInstance];
			if(mCurrentHardwareInputNumberChannels == session.inputNumberOfChannels)
			{
				// Hope that the hardware will handle the change
				return;
			}

			id user = self.mcMixerUser;
			[self.mcMixerUser setAu:nil];
			self.mcMixerUser = nil;

			[self reconfigureAudioGuts_old]; // attempt to reconfigure with minimal recreation of objects

			self.mcMixerUser = user;
			[self.mcMixerUser setAu:self.mMixerUnit];
			[delegate reconfigureDisplaySetup:reInitializeAudioSettings];
			AUGraphStart(mAudioGraph);
		}
			break;
	}

	return;
}


#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
- (NSInteger)getNumberOfInputChannels_old
{
	NSInteger returnValue = 0;

	UInt32 AudioInputAvailable;
	OSStatus result=0;

	try
	{
		/*
		 kAudioSessionProperty_AudioInputAvailable                   = 'aiav',   // UInt32           (get only/property listener)
		 */
		UInt32 size = sizeof(AudioInputAvailable);
		XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, &size, &AudioInputAvailable), "couldn't get AudioInputAvailable");
		SDR_DEBUGPRINT(("Audio input available: %s\n", ((int)AudioInputAvailable == 1) ? "Yes":"No"));

		if(AudioInputAvailable == 1)
		{
			UInt32 audioCategory;
			UInt32 size = sizeof(audioCategory);
			AudioSessionGetProperty(kAudioSessionProperty_AudioCategory, &size, &audioCategory);

			if(audioCategory != kAudioSessionCategory_PlayAndRecord)
			{
				audioCategory = kAudioSessionCategory_PlayAndRecord;
				XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory), "couldn't set audio category");
			}
		}
		else
		{
			UInt32 audioCategory = kAudioSessionCategory_MediaPlayback;
			XThrowIfError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory), "couldn't set audio category");

		}

		result = AudioSessionSetActive(TRUE);
		if(result)
		{
			SDR_DEBUGPRINT(("AudioSessionSetActive result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			//				audioStatus = AudioError;
			//				return result;
		}


		if((AudioInputAvailable == 1) && mLiveAudioAllowed)
		{
			/*
			 kAudioSessionProperty_CurrentHardwareInputNumberChannels    = 'chic',   // UInt32           (get only)
			 */
			UInt32 numChans;
			size = sizeof(numChans);
			XThrowIfError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels, &size, &numChans), "couldn't get CurrentHardwareInputNumberChannels");
			SDR_DEBUGPRINT(("Number of audio input channels found: %d\n", (int)numChans));

			returnValue = (NSInteger)numChans;
		}
	}
	catch (...)
	{
		fprintf(stderr, "Error reading number of input channels\n");
		audioStatus	= AudioError;
#ifndef DISABLE_HPF
		if (dcFilter) delete[] dcFilter;
#endif
	}

	return returnValue;
}

- (void)adjustAudioRouting_old:(UInt32)reason
{
	if(mLiveAudioAllowed)
		SDR_DEBUGPRINT(("adjustAudioRouting: live audio allowed\n"));
	else
		SDR_DEBUGPRINT(("adjustAudioRouting: demo mode only\n"));

	switch(reason)
	{
			//			kAudioSessionRouteChangeReason_Unknown                    = 0,
			//			kAudioSessionRouteChangeReason_NewDeviceAvailable         = 1,
			//			kAudioSessionRouteChangeReason_OldDeviceUnavailable       = 2,
			//			kAudioSessionRouteChangeReason_CategoryChange             = 3,
			//			kAudioSessionRouteChangeReason_Override                   = 4,
			// this enum has no constant with a value of 5
			//			kAudioSessionRouteChangeReason_WakeFromSleep              = 6,
			//			kAudioSessionRouteChangeReason_NoSuitableRouteForCategory = 7

		case kAudioSessionRouteChangeReason_Unknown:
		{
			NSInteger channels = [self getNumberOfInputChannels_old];

			if(channels == mCurrentHardwareInputNumberChannels)
			{
				return; // let hardware handle rerouting
			}

			id user = self.mcMixerUser;
			[self.mcMixerUser setAu:nil];
			self.mcMixerUser = nil;

			[self reconfigureAudioGuts_old]; // attempt to reconfigure with minimal recreation of objects

			self.mcMixerUser = user;
			[self.mcMixerUser setAu:self.mMixerUnit];
			[delegate reconfigureDisplaySetup:reInitializeAudioSettings];
			AUGraphStart(mAudioGraph);
			}
			break;

		// These are the most common reasons: a headphone or microphone device has been attached or removed.
		case kAudioSessionRouteChangeReason_NoSuitableRouteForCategory:
			SDR_DEBUGPRINT(("Microphone removed from iPod? \n"));
		case kAudioSessionRouteChangeReason_NewDeviceAvailable:
		case kAudioSessionRouteChangeReason_OldDeviceUnavailable:
		{
			NSInteger channels = [self getNumberOfInputChannels_old];

			if(channels == mCurrentHardwareInputNumberChannels)
			{
				return; // let hardware handle rerouting
			}

			id user = self.mcMixerUser;
			[self.mcMixerUser setAu:nil];
			self.mcMixerUser = nil;

			[self reconfigureAudioGuts_old]; // attempt to reconfigure with minimal recreation of objects

			self.mcMixerUser = user;
			[self.mcMixerUser setAu:self.mMixerUnit];
					[delegate reconfigureDisplaySetup:reInitializeAudioSettings];
			AUGraphStart(mAudioGraph);
		}
			break;

		// Headphone was removed from iPhone (headphone with or without mic)
		case kAudioSessionRouteChangeReason_CategoryChange:
		{
			UInt32 audioCategory;
			UInt32 size = sizeof(audioCategory);
			AudioSessionGetProperty(kAudioSessionProperty_AudioCategory, &size, &audioCategory);
			SDR_DEBUGPRINT(("Category change: %lu\n", audioCategory));

			switch(audioCategory)
			{
				case kAudioSessionCategory_UserInterfaceSoundEffects:
					SDR_DEBUGPRINT(("uifx: User Interface Sound Effects\n"));
					break;

				case kAudioSessionCategory_AmbientSound:
					SDR_DEBUGPRINT(("ambi: Ambient Sound\n"));
					break;

				case kAudioSessionCategory_SoloAmbientSound:
					SDR_DEBUGPRINT(("solo: Solo Ambient Sound\n"));
					break;

				case kAudioSessionCategory_MediaPlayback:
					SDR_DEBUGPRINT(("medi: Media Playback\n"));
					break;

				case kAudioSessionCategory_LiveAudio:
					SDR_DEBUGPRINT(("live: Live Audio\n"));
					break;

				case kAudioSessionCategory_RecordAudio:
					SDR_DEBUGPRINT(("reca: Record Audio\n"));
					break;

				case kAudioSessionCategory_PlayAndRecord:
					SDR_DEBUGPRINT(("Mono mic removed from iPhone in demo-only mode?\n"));
					SDR_DEBUGPRINT(("plar: Play and Record\n"));
					break;

				case kAudioSessionCategory_AudioProcessing:
					SDR_DEBUGPRINT(("proc: Audio Processing\n"));
					break;

			}

			SDR_DEBUGPRINT(("Leaving audio route unchanged...\n"));
		}
			break;

		default:
		{
			NSInteger channels = [self getNumberOfInputChannels_old];

			if(channels == mCurrentHardwareInputNumberChannels)
			{
				return; // hope that hardware handles rerouting
			}

			id user = self.mcMixerUser;
			[self.mcMixerUser setAu:nil];
			self.mcMixerUser = nil;

			[self reconfigureAudioGuts_old]; // attempt to reconfigure with minimal recreation of objects

			self.mcMixerUser = user;
			[self.mcMixerUser setAu:self.mMixerUnit];
			[delegate reconfigureDisplaySetup:reInitializeAudioSettings];
			AUGraphStart(mAudioGraph);
		}
			break;
	}

	return;
}


- (void)killAllAudio_old
{
	AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_AudioRouteChange, audioPropListener_old, self);
	AudioSessionSetActive(FALSE);
	AudioSessionInitialize(NULL, NULL, NULL, self);
	//	[self shutDownAudio];
}
#endif


- (void)killAllAudio
{
	AVAudioSession* session = [AVAudioSession sharedInstance];
	[self stopAUGraph:FALSE];
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:AVAudioSessionRouteChangeNotification
												  object:[AVAudioSession sharedInstance]];
	[session setActive:NO error:nil]; // shut down the audio session if it is active

	// Prevent strange active microphone behavior when shutting down
	if(![session.category isEqualToString:AVAudioSessionCategoryPlayback])
	{
		SDR_DEBUGPRINT(("Setting session category: AVAudioSessionCategoryPlayback.\n"));

		//set the audioSession category.
		[session setCategory:AVAudioSessionCategoryPlayback error:nil];
	}
}


- (BOOL)audioBusy:(iSDRAudioState)setting
{
	static BOOL busy = AudioNotBusy;
	static UInt16 count = 0;
	static std::atomic_flag stateUpdateInProgress = ATOMIC_FLAG_INIT;

	if(setting == AudioReadState) return busy;

	// Preserve the original non-blocking semantics: a concurrent state update is skipped.
	if(!stateUpdateInProgress.test_and_set(std::memory_order_acquire))
	{
		if(setting == AudioBusy)
		{
			count++;
		}
		else
		{
			if(count) count--;
		}

		busy = (count!=0);
		stateUpdateInProgress.clear(std::memory_order_release);
	}

	return busy;

}


- (void)playSuccessSound
{
	if(successSound == 0)
	{
		CFURLRef url = NULL;

		try
		{
			url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFStringRef([[NSBundle mainBundle] pathForResource:@"success" ofType:@"caf"]), kCFURLPOSIXPathStyle, FALSE);
			XThrowIfError(AudioServicesCreateSystemSoundID(url, &successSound), "couldn't create button tap alert sound");
			CFRelease(url);
		}
		catch (CAXException &e)
		{
			CFRelease(url);
			char buf[256];
			fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		}
		catch (...)
		{
			CFRelease(url);
			fprintf(stderr, "An unknown error occurred in playSuccessSound\n");
		}

		if(successSound)
		{
			// This callback will handle setting things back to normal after the sound plays
			AudioServicesAddSystemSoundCompletion(successSound, NULL, NULL, restoreAudioAfterSystemSound, (void*)self);
		}
	}

	if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
	{
		if(![[[AVAudioSession sharedInstance] category] isEqualToString:AVAudioSessionCategoryPlayback])
		{
			if(mAudioGraph)
			{
				Boolean isRunning;
				AUGraphIsRunning(mAudioGraph, &isRunning);

				if(isRunning)
				{
					//				AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 0.0, 0);
					AUGraphStop(mAudioGraph); // seems to be necessary for system sound to play in this audio session category
					fftBufferManager->setBufferActive(FALSE); // throw away spectrum data until the system sound has played
				}
			}
		}
	}
	else
	{
		systemSoundMutingState = self.mute;
		self.mute = TRUE;
		[self stopAUGraph:FALSE];
	}

	AudioServicesPlaySystemSound(successSound);
}

- (void)playErrorSound
{
	if(errorSound == 0)
	{
		CFURLRef url = NULL;

		try
		{
			url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFStringRef([[NSBundle mainBundle] pathForResource:@"oops" ofType:@"caf"]), kCFURLPOSIXPathStyle, FALSE);
			XThrowIfError(AudioServicesCreateSystemSoundID(url, &errorSound), "couldn't create button tap alert sound");
			CFRelease(url);
		}
		catch (CAXException &e)
		{
			CFRelease(url);
			char buf[256];
			fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		}
		catch (...)
		{
			CFRelease(url);
			fprintf(stderr, "An unknown error occurred in playErrorSound\n");
		}

		if(errorSound)
		{
			// This callback will handle setting things back to normal after the sound plays
			AudioServicesAddSystemSoundCompletion(errorSound, NULL, NULL, restoreAudioAfterSystemSound, (void*)self);
		}
	}

	if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
	{
		if(![[[AVAudioSession sharedInstance] category] isEqualToString:AVAudioSessionCategoryPlayback])
		{
			if(mAudioGraph)
			{
				Boolean isRunning;
				AUGraphIsRunning(mAudioGraph, &isRunning);

				if(isRunning)
				{
					//				AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 0.0, 0);
					AUGraphStop(mAudioGraph); // seems to be necessary for system sound to play in this audio session category
					fftBufferManager->setBufferActive(FALSE); // throw away spectrum data until the system sound has played
				}
			}
		}
	}
	else
	{
		systemSoundMutingState = self.mute;
		self.mute = TRUE;
		[self stopAUGraph:FALSE];
	}

	AudioServicesPlaySystemSound(errorSound);
}

- (void)playKeypressSound
{
	if(buttonPressSound == 0)
	{
		CFURLRef url = NULL;

		try
		{
			url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFStringRef([[NSBundle mainBundle] pathForResource:@"button_press" ofType:@"caf"]), kCFURLPOSIXPathStyle, FALSE);
			XThrowIfError(AudioServicesCreateSystemSoundID(url, &buttonPressSound), "couldn't create button tap alert sound");
			CFRelease(url);
		}
		catch (CAXException &e)
		{
			CFRelease(url);
			char buf[256];
			fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		}
		catch (...)
		{
			CFRelease(url);
			fprintf(stderr, "An unknown error occurred in playKeypressSound\n");
		}

		if(buttonPressSound)
		{
			// This callback will handle setting things back to normal after the sound plays
			AudioServicesAddSystemSoundCompletion(buttonPressSound, NULL, NULL, restoreAudioAfterSystemSound, (void*)self);
		}
	}

	if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
	{
		if(![[[AVAudioSession sharedInstance] category] isEqualToString:AVAudioSessionCategoryPlayback])
		{
			if(mAudioGraph)
			{
				Boolean isRunning;
				AUGraphIsRunning(mAudioGraph, &isRunning);

				if(isRunning)
				{
					//				AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 0.0, 0);
					AUGraphStop(mAudioGraph); // seems to be necessary for system sound to play in this audio session category
					fftBufferManager->setBufferActive(FALSE); // throw away spectrum data until the system sound has played
				}
			}
		}
	}
	else
	{
		systemSoundMutingState = self.mute;
		self.mute = TRUE;
		[self stopAUGraph:FALSE];
	}

	AudioServicesPlaySystemSound(buttonPressSound);
}

void restoreAudioAfterSystemSound(SystemSoundID  ssID, void *clientData)
{
	[(__bridge id)clientData restoreAudio];
}

- (void)restoreAudio
{
	if(!fftBufferManager->getBufferActive())
	{
		AUGraphStart(mAudioGraph);
		fftBufferManager->setBufferActive(TRUE);
//		AudioUnitSetParameter(mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 1.0, 0);
	}

	if(SYSTEM_VERSION_LESS_THAN(@"6.0"))
	{
		if(systemSoundMutingState)
		{
			self.mute = TRUE;
			[self stopAUGraph:FALSE];
		}
		else
		{
			self.mute = FALSE;
			[self startAUGraph:systemSoundMutingState];
		}
	}
}

#ifdef SDR_DEBUG
- (char*)getDebugMessage
{
	static char debugMessage[256];

	sprintf(debugMessage, "Audio Samples: HW Sample Rate: %4.0f SRBW: %u\n Samples per render: max=%u min=%u\n",
			hwSampleRate,
			(unsigned int)sampleRateBandwidth,
			(unsigned int)_maxSamplesPerRender,
			(unsigned int)_minSamplesPerRender
			);

	return(debugMessage);
}
#endif

#ifdef SDR_DEBUG
- (void)printFileError:(OSStatus)result
{
	switch(result)
	{
		case kAudioFileUnspecifiedError:
			SDR_DEBUGPRINT(("File error: wht?: An unspecified error has occurred.\n"));
			break;

		case kAudioFileUnsupportedFileTypeError:
			SDR_DEBUGPRINT(("File error: typ?: The file type is not supported.\n"));
			break;

		case kAudioFileUnsupportedDataFormatError:
			SDR_DEBUGPRINT(("File error: fmt?: The data format is not supported by this file type.\n"));
			break;

		case kAudioFileUnsupportedPropertyError:
			SDR_DEBUGPRINT(("File error: pty?: The property is not supported.\n"));
			break;

		case kAudioFileBadPropertySizeError:
			SDR_DEBUGPRINT(("File error: !siz: The size of the property data was not correct.\n"));
			break;

		case kAudioFilePermissionsError:
			SDR_DEBUGPRINT(("File error: prm?: The operation violated the file permissions. For example, an attempt was made to write to a file opened with the kAudioFileReadPermission constant.\n"));
			break;

		case kAudioFileNotOptimizedError:
			SDR_DEBUGPRINT(("File error: optm: The chunks following the audio data chunk are preventing the extension of the audio data chunk. To write more data, you must optimize the file.\n"));
			break;

		case kAudioFileInvalidChunkError:
			SDR_DEBUGPRINT(("File error: chk?: Either the chunk does not exist in the file or it is not supported by the file.\n"));
			break;

		case kAudioFileDoesNotAllow64BitDataSizeError:
			SDR_DEBUGPRINT(("File error: off?: The file offset was too large for the file type. The AIFF and WAVE file format types have 32-bit file size limits.\n"));
			break;

		case kAudioFileInvalidPacketOffsetError:
			SDR_DEBUGPRINT(("File error: pck?: A packet offset was past the end of the file, or not at the end of the file when a VBR format was written, or a corrupt packet size was read when the packet table was built.\n"));
			break;

		case kAudioFileInvalidFileError:
			SDR_DEBUGPRINT(("File error: dta?: The file is malformed, or otherwise not a valid instance of an audio file of its type.\n"));
			break;

		case kAudioFileOperationNotSupportedError:
			SDR_DEBUGPRINT(("File error: pck?: A packet offset was past the end of the file, or not at the end of the file when a VBR format was written, or a corrupt packet size was read when the packet table was built.\n"));
			break;

			// general file error codes
		case kAudioFileNotOpenError:
			SDR_DEBUGPRINT(("File error: File not open!\n"));
			break;

		case kAudioFileEndOfFileError:
			SDR_DEBUGPRINT(("File error: End of File!\n"));
			break;

		case kAudioFilePositionError:
			SDR_DEBUGPRINT(("File error: File position error!\n"));
			break;

		case kAudioFileFileNotFoundError:
			SDR_DEBUGPRINT(("File error: File not found!\n"));
			break;

		default:
			SDR_DEBUGPRINT(("File error: Unknown error occurred! %d\n", (int)result));
			break;
	}

	return;
}


- (void)printExtAudioFileError:(OSStatus)result
{
	switch(result)
	{
		case kExtAudioFileError_CodecUnavailableInputConsumed:
			SDR_DEBUGPRINT(("Ext file error: The ExtAudioFileWrite function was interrupted and the last buffer that you provided was successfully written to disk.\n"));
			break;

		case kExtAudioFileError_CodecUnavailableInputNotConsumed:
			SDR_DEBUGPRINT(("Ext file error: The ExtAudioFileWrite function was interrupted and the last buffer that you provided was not successfully written to disk.\n"));
			break;

		case kExtAudioFileError_InvalidProperty:
			SDR_DEBUGPRINT(("Ext file error: Invalid property!\n"));
			break;

		case kExtAudioFileError_InvalidPropertySize:
			SDR_DEBUGPRINT(("Ext file error: Invalid property size!\n"));
			break;

		case kExtAudioFileError_NonPCMClientFormat:
			SDR_DEBUGPRINT(("Ext file error: Non-PCM client format!\n"));
			break;

		case kExtAudioFileError_InvalidChannelMap:
			SDR_DEBUGPRINT(("Ext file error: The number of channels does not match the specified format.\n"));
			break;

		case kExtAudioFileError_InvalidOperationOrder:
			SDR_DEBUGPRINT(("Ext file error: Invalid operation order!\n"));
			break;

		case kExtAudioFileError_InvalidDataFormat:
			SDR_DEBUGPRINT(("Ext file error: Invalid data format!\n"));
			break;

		case kExtAudioFileError_MaxPacketSizeUnknown:
			SDR_DEBUGPRINT(("Ext file error: Max packet size unknown!\n"));
			break;

		case kExtAudioFileError_InvalidSeek:
			SDR_DEBUGPRINT(("Ext file error: An attempt to write, or an offset, is out of bounds.\n"));
			break;

		case kExtAudioFileError_AsyncWriteTooLarge:
			SDR_DEBUGPRINT(("Ext file error: Async write too large!\n"));
			break;

		case kExtAudioFileError_AsyncWriteBufferOverflow:
			SDR_DEBUGPRINT(("Ext file error: Async write buffer overflow!\n"));
			break;

			// general file error codes
		case kAudioFileNotOpenError:
			SDR_DEBUGPRINT(("Ext file error: File not open!\n"));
			break;

		case kAudioFileEndOfFileError:
			SDR_DEBUGPRINT(("Ext file error: End of File!\n"));
			break;

		case kAudioFilePositionError:
			SDR_DEBUGPRINT(("Ext file error: File position error!\n"));
			break;

		case kAudioFileFileNotFoundError:
			SDR_DEBUGPRINT(("Ext file error: File not found!\n"));
			break;

		default:
			SDR_DEBUGPRINT(("Ext file error: Unknown error occurred! %d\n", (int)result));
			break;
	}

	return;
}
#endif


- (id <MultichannelMixerControllerDelegate>)delegate { return delegate; }

- (void)setDelegate:(id <MultichannelMixerControllerDelegate>)v
{
	delegate = v;
}



@end
