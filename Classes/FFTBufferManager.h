/*
 Third-party provenance: portions of this file are derived from Apple's
 aurioTouch/aurioTouch2 sample code.

 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

 File: FFTBufferManager.h
 Abstract: This class manages buffering and computation for FFT analysis on input audio data. The methods provided are used to grab the audio, buffer it, and perform the FFT when sufficient data is available
 Version: 1.11

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

#ifndef __FFTBUFFERMANAGER_H__
#define __FFTBUFFERMANAGER_H__

#include <AudioToolbox/AudioToolbox.h>
#include <stdbool.h>
#include <CoreFoundation/CFRunLoop.h>

#include <atomic>

#include "SpectrumAnalysis.h"
#include "product.h"

class FFTBufferManager
{
public:
	FFTBufferManager(UInt32 inCircularBufferSize_frames, UInt32 inDSPStepSize_frames, int inAudioChannels);
	~FFTBufferManager();

	void				GrabAudioData(AudioBufferList *inBL);
	//	void				GrabFileData(AudioQueueBufferRef inBR);

	Boolean				ComputeFFT(int32_t** SpectrumDataptr, int32_t* SpectrumDataSize);
	Boolean				ProcessAudio();
	void				RegisterSource(CFRunLoopRef loop, CFRunLoopSourceRef source);
	void				UnRegisterSource();
	void				AudioBufferFlush();
	bool				isValid() const;
	void				setCenterFrequency(float fraction);
	float				getCenterFrequency();
	void				setCenterFrequencyOffsetHz(float hertz, float samplerate, BOOL ssb);
	float				getCenterFrequencyOffsetHz();
	float				getCenterFrequencyOffset();
//	void				setBPF(float centerfrequency, float bandwidth);
	void				setBPF(float bandwidth);
	void				setOperatingMode(iSDROperatingMode mode);
	void				setIQLogicState(BOOL reversed);
	void				setSpectrumMagnitudeShift(int spectrumMagnitudeShift);
	void				setSignalScaleFactor(float signalScaling);
	void				setNumAudioChannels(int audiochannels);
	AudioBuffer*		getOscilloBuff();
	void				setCopyRawPCM(BOOL value);
	BOOL				getCopyRawPCM();
	void				setBufferActive(BOOL value);
	BOOL				getBufferActive();
	BOOL				getDSPBufferReady();
	void				setDSPBufferReady(BOOL value);
#ifdef SDR_DEBUG
	char*				getDebugMessage();
#endif

private:
	void				fireCommandsOnRunLoop(CFRunLoopRef loop, CFRunLoopSourceRef source);

	std::atomic<int32_t>	mHeadAudioInputCircularBufferIndex_frame; // audio input gets written here

	std::atomic<int32_t>	mTailAudioOutputCircularBufferIndex_frame; // buffered DSP processed audio ready for the speaker gets read here

	std::atomic<bool>	mHasNewSpectrumData;
	std::atomic<float>	mCenterFrequency;
	std::atomic<float>	mCenterFrequencyOffsetHz; // an offset value for applying CW rx offset
	std::atomic<float>	mCenterFrequencyOffsetRatio; // an offset value for applying CW rx offset
	std::atomic<bool>	mSSBFiltering;
	std::atomic<int>	mInputAudioChannels;
	std::atomic<bool>	mCopyRawPCM;
	AudioBuffer			mOscilloBuff;
	std::atomic<bool>	mDSPBufferReady;
	std::atomic<bool>	mBufferActive;

	H_SPECTRUM_ANALYSIS mSpectrumAnalysis;

	int32_t*			mInAudioBuffer[2];
	int32_t*			mOutAudioBuffer[2];
	int32_t*			mSpectrumSnapshot;
	UInt32				mSpectrumSnapshotSize;
	UInt32				mNumberBufferSegments;
	UInt32				mAudioBufferSize_chunks;
	UInt32				mAudioBufferSize_bytes;
	UInt32				mAudioBufferSize_frames;
	//	int32_t				mAudioBufferCurrentIndex_frames;
	CFRunLoopRef			mDSPrunLoop;
	CFRunLoopSourceRef	mDSPrunLoopSource;
	std::atomic<UInt64>	mInputAudioChunkCount;
	std::atomic<UInt64>	mInputAudioFrameCount;
	std::atomic<UInt64>	mOutputAudioFrameCount;
	std::atomic<UInt64>	mProcessedAudioChunkCount;
	std::atomic<UInt64>	mProcessedAudioFrameCount;
	std::atomic<UInt32>	mFramesSinceTrigger;
	bool				mValid;
};


#endif
