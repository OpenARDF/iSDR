/*
 Third-party provenance: portions of this file are derived from Apple's
 aurioTouch/aurioTouch2 sample code.

 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

 File: FFTBufferManager.cpp
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

#import "FFTBufferManager.h"
#import "AudioBufferUtilities.h"
#import "dspThread.h"
//#import "CAXException.h"
#import <UIKit/UIDevice.h>
//#import <AvailabilityInternal.h>


#ifdef SDR_DEBUG
static UInt32 missedFrames1=0;
static UInt32 missedFrames2=0;
static UInt32 maxInputFrames=0;
static UInt32 minInputFrames=4096;
#endif


FFTBufferManager::FFTBufferManager(UInt32 inBufferSegments, UInt32 inDSPStepSize_frames, int inAudioChannels) :
//mTailAudioInputCircularBufferIndex(0),
mHeadAudioInputCircularBufferIndex_frame(0),
mTailAudioOutputCircularBufferIndex_frame(0),
//mTailAudioInputCircularBufferIndex_frame(0),
mHasNewSpectrumData(false),
mCenterFrequency(0.5),
mCenterFrequencyOffsetHz(0.),
mCenterFrequencyOffsetRatio(0.),
mSSBFiltering(false),
mInputAudioChannels(inAudioChannels),
mCopyRawPCM(true),
mBufferActive(true),
mDSPBufferReady(false),
mSpectrumAnalysis(NULL),
mSpectrumSnapshot(NULL),
mSpectrumSnapshotSize(0),
mNumberBufferSegments(inBufferSegments),
mAudioBufferSize_chunks(inBufferSegments),
mAudioBufferSize_bytes(inBufferSegments * inDSPStepSize_frames * AUDIO_FRAME_SIZE_BYTES),
mAudioBufferSize_frames(mAudioBufferSize_bytes/AUDIO_FRAME_SIZE_BYTES),
mDSPrunLoop(NULL),
mDSPrunLoopSource(NULL),
mInputAudioChunkCount(0),
mInputAudioFrameCount(0),
mOutputAudioFrameCount(0),
mProcessedAudioChunkCount(0),
mProcessedAudioFrameCount(0),
mFramesSinceTrigger(0),
mValid(false)
{
	mInAudioBuffer[0] = (int32_t*)calloc(mAudioBufferSize_frames, sizeof(int32_t));
	mInAudioBuffer[1] = (int32_t*)calloc(mAudioBufferSize_frames, sizeof(int32_t));
	mOutAudioBuffer[0] = (int32_t*)calloc(mAudioBufferSize_frames, sizeof(int32_t));
	mOutAudioBuffer[1] = (int32_t*)calloc(mAudioBufferSize_frames, sizeof(int32_t));
	mSpectrumAnalysis = SpectrumAnalysisCreate(DSP_CHUNKSIZE_FRAMES, mInputAudioChannels.load(std::memory_order_relaxed));
	// Reserve the maximum stereo spectrum so a later mono/stereo route change
	// cannot enlarge the producer buffer beyond the UI snapshot allocation.
	mSpectrumSnapshotSize = mSpectrumAnalysis == NULL ? 0 : 2 * DSP_CHUNKSIZE_FRAMES;
	mSpectrumSnapshot = (int32_t*)calloc(mSpectrumSnapshotSize, sizeof(int32_t));
	mOscilloBuff.mNumberChannels = 1;
	mOscilloBuff.mData = calloc(1, MAX_DATA_PER_RENDER_BYTES);
	mOscilloBuff.mDataByteSize = 0;
	mValid = inBufferSegments > 0 && inDSPStepSize_frames > 0 &&
		mInAudioBuffer[0] != NULL && mInAudioBuffer[1] != NULL &&
		mOutAudioBuffer[0] != NULL && mOutAudioBuffer[1] != NULL &&
		mSpectrumAnalysis != NULL && mSpectrumSnapshot != NULL &&
		mOscilloBuff.mData != NULL;
}

FFTBufferManager::~FFTBufferManager()
{
	if(mInAudioBuffer[0]) free(mInAudioBuffer[0]);
	if(mInAudioBuffer[1]) free(mInAudioBuffer[1]);
	if(mOutAudioBuffer[0]) free(mOutAudioBuffer[0]);
	if(mOutAudioBuffer[1]) free(mOutAudioBuffer[1]);
	if(mOscilloBuff.mData) free(mOscilloBuff.mData);
	if(mSpectrumSnapshot) free(mSpectrumSnapshot);
	if(mSpectrumAnalysis) SpectrumAnalysisDestroy(mSpectrumAnalysis);
	mDSPrunLoop = NULL;
	mDSPrunLoopSource = NULL;
}

bool FFTBufferManager::isValid() const
{
	return mValid;
}


void FFTBufferManager::RegisterSource(CFRunLoopRef loop, CFRunLoopSourceRef source)
{
	mDSPrunLoop = loop;
	mDSPrunLoopSource = source;
}

void FFTBufferManager::UnRegisterSource()
{
	mDSPrunLoop = NULL;
	mDSPrunLoopSource = NULL;
}


/*
 This method puts audio data into a circular buffer, then wakes up the DSP thread whenever
 there is sufficient data for it to process.
 */
void FFTBufferManager::GrabAudioData(AudioBufferList *inBL)
{
	if(!mValid || inBL == NULL || inBL->mNumberBuffers == 0 || inBL->mNumberBuffers > 2)
		return;

	const UInt32 bytesToCopy = inBL->mBuffers[0].mDataByteSize;
	if(bytesToCopy == 0 || (bytesToCopy % AUDIO_FRAME_SIZE_BYTES) != 0)
		return;
	const UInt32 framesToCopy = bytesToCopy / AUDIO_FRAME_SIZE_BYTES;
	if(framesToCopy > mAudioBufferSize_frames || bytesToCopy > MAX_DATA_PER_RENDER_BYTES)
		return;

	for(UInt32 bufferNumber = 0; bufferNumber < inBL->mNumberBuffers; bufferNumber++)
	{
		if(inBL->mBuffers[bufferNumber].mData == NULL ||
			inBL->mBuffers[bufferNumber].mDataByteSize < bytesToCopy)
			return;
	}

#ifdef SDR_DEBUG
	if(framesToCopy > maxInputFrames)
	{
		maxInputFrames=framesToCopy;
	}

	if(framesToCopy < minInputFrames)
	{
		minInputFrames = framesToCopy;
	}
#endif

	const UInt64 inputFrames = mInputAudioFrameCount.load(std::memory_order_acquire);
	const UInt64 processedFrames = mProcessedAudioFrameCount.load(std::memory_order_acquire);
	if(inputFrames >= processedFrames &&
		inputFrames - processedFrames + framesToCopy <= mAudioBufferSize_frames)
	{
		///////////////////////////////////////////////////////
		// Put raw audio data into the input circular buffer //
		///////////////////////////////////////////////////////

		// Capture raw audio data from active channels into the next buffer
		const int32_t inputHead = mHeadAudioInputCircularBufferIndex_frame.load(std::memory_order_acquire);
		for(UInt32 buffnum=0; buffnum < inBL->mNumberBuffers; buffnum++)
		{
			ISDRCopyFramesIntoRing(mInAudioBuffer[buffnum], mAudioBufferSize_frames,
				inputHead,
				(const int32_t *)inBL->mBuffers[buffnum].mData, framesToCopy);
		}

		mInputAudioFrameCount.fetch_add(framesToCopy, std::memory_order_release);

		mHeadAudioInputCircularBufferIndex_frame.store(
			(inputHead + framesToCopy) % mAudioBufferSize_frames, std::memory_order_release);

		// Use DSP chunk size to determine when to wake up DSP thread
		UInt32 priorRemainder = mFramesSinceTrigger.load(std::memory_order_acquire);
		UInt32 accumulatedFrames;
		UInt32 newRemainder;
		do
		{
			accumulatedFrames = priorRemainder + framesToCopy;
			newRemainder = accumulatedFrames % DSP_CHUNKSIZE_FRAMES;
		}
		while(!mFramesSinceTrigger.compare_exchange_weak(priorRemainder, newRemainder,
			std::memory_order_acq_rel, std::memory_order_acquire));
		const UInt32 completedChunks = accumulatedFrames / DSP_CHUNKSIZE_FRAMES;
		if(completedChunks > 0)
			mInputAudioChunkCount.fetch_add(completedChunks, std::memory_order_release);
		fireCommandsOnRunLoop(mDSPrunLoop, mDSPrunLoopSource);

		///////////////////////////////////////////////////////////////////
		// Read processed audio data out from the output circular buffer //
		///////////////////////////////////////////////////////////////////
		const UInt64 currentProcessedFrames = mProcessedAudioFrameCount.load(std::memory_order_acquire);
		const UInt64 currentOutputFrames = mOutputAudioFrameCount.load(std::memory_order_acquire);
		const UInt64 availableOutputFrames = currentProcessedFrames >= currentOutputFrames ?
			currentProcessedFrames - currentOutputFrames : 0;
		if(availableOutputFrames >= framesToCopy)
		{
			// write processed audio back into audio stream
			mOutputAudioFrameCount.fetch_add(framesToCopy, std::memory_order_release);
			const int32_t outputTail = mTailAudioOutputCircularBufferIndex_frame.load(std::memory_order_acquire);

			for(UInt32 buffnum=0; buffnum < inBL->mNumberBuffers; buffnum++)
			{
				ISDRCopyFramesFromRing(mOutAudioBuffer[buffnum], mAudioBufferSize_frames,
					outputTail,
					(int32_t *)inBL->mBuffers[buffnum].mData, framesToCopy);

				// copy pointer PCM data for o-scope display
				if(mCopyRawPCM.load(std::memory_order_acquire))
				{
//					mOscilloBuff.mBuffers[0].mData = inBL->mBuffers[buffnum].mData;
					memcpy(mOscilloBuff.mData, inBL->mBuffers[buffnum].mData, bytesToCopy);
					mOscilloBuff.mDataByteSize = bytesToCopy;
					// Publish completion only after the snapshot and size are stable.
					mCopyRawPCM.store(false, std::memory_order_release);
				}
			}

			mTailAudioOutputCircularBufferIndex_frame.store(
				(outputTail + framesToCopy) % mAudioBufferSize_frames, std::memory_order_release);
		}
		else
		{
#ifdef SDR_DEBUG
			static uint16_t i=0;
			missedFrames1++;
#endif


			// Never replay stale ring contents when the DSP worker has underrun.
			for(UInt32 buffnum=0; buffnum < inBL->mNumberBuffers; buffnum++)
				memset(inBL->mBuffers[buffnum].mData, 0, bytesToCopy);

			SDR_DEBUGPRINT(("%d!\n", i++));
		}

	}
#ifdef SDR_DEBUG
	else
	{
		missedFrames2++;
		SDR_DEBUGPRINT(("%u\n", (unsigned int)missedFrames2));
		AudioBufferFlush();
	}
#endif

}


void FFTBufferManager::fireCommandsOnRunLoop(CFRunLoopRef loop, CFRunLoopSourceRef source)
{
	if(mDSPBufferReady.load(std::memory_order_acquire) && loop != NULL && source != NULL)
	{
		CFRunLoopSourceSignal(source);
		CFRunLoopWakeUp(loop);
	}
}


AudioBuffer* FFTBufferManager::getOscilloBuff()
{
	return &mOscilloBuff;
}


void FFTBufferManager::setCopyRawPCM(BOOL value)
{
	mCopyRawPCM.store(value, std::memory_order_release);
}


BOOL FFTBufferManager::getCopyRawPCM()
{
	return mCopyRawPCM.load(std::memory_order_acquire);
}


void FFTBufferManager::setBufferActive(BOOL value)
{
	mBufferActive.store(value, std::memory_order_release);
}


BOOL FFTBufferManager::getBufferActive()
{
	return mBufferActive.load(std::memory_order_acquire);
}

// Caller needs to take care to ensure that setCenterFrequency is called immediately following
// any changes to the center frequency offset.
void FFTBufferManager::setCenterFrequencyOffsetHz(float hertz, float samplerate, BOOL ssb)
{
	mCenterFrequencyOffsetHz.store(hertz, std::memory_order_release);
	mCenterFrequencyOffsetRatio.store(hertz / samplerate, std::memory_order_release);
	mSSBFiltering.store(ssb, std::memory_order_release);
}


float FFTBufferManager::getCenterFrequencyOffsetHz()
{
	return mCenterFrequencyOffsetHz.load(std::memory_order_acquire);
}


float FFTBufferManager::getCenterFrequencyOffset()
{
	return mCenterFrequencyOffsetRatio.load(std::memory_order_acquire);
}


void FFTBufferManager::setCenterFrequency(float fraction)
{
	float result = CLAMP(0., fraction + mCenterFrequencyOffsetRatio.load(std::memory_order_acquire), 1.0);
	mCenterFrequency.store(result, std::memory_order_release);
}


float FFTBufferManager::getCenterFrequency()
{
	float result = CLAMP(0., mCenterFrequency.load(std::memory_order_acquire) -
		mCenterFrequencyOffsetRatio.load(std::memory_order_acquire), 1.0);
	return result;
}


//void FFTBufferManager::setBPF(float centerfrequency, float bandwidth)
//{
//	ConfigureBPF(mSpectrumAnalysis, centerfrequency, bandwidth);
//}


void FFTBufferManager::setBPF(float bandwidthHz)
{
	if(mSSBFiltering.load(std::memory_order_acquire)) // SSB
	{
		ConfigureBPF(mSpectrumAnalysis, bandwidthHz/2., bandwidthHz);
	}
	else if(mCenterFrequencyOffsetHz.load(std::memory_order_acquire) < 0.) // CW
	{
		ConfigureBPF(mSpectrumAnalysis, -mCenterFrequencyOffsetHz.load(std::memory_order_acquire), bandwidthHz);
	}
	else // AM, FM, Binaural
	{
		ConfigureBPF(mSpectrumAnalysis, 0., bandwidthHz);
	}
}


void FFTBufferManager::setOperatingMode(iSDROperatingMode mode)
{
	setSidebandMode(mSpectrumAnalysis, mode);
}


void FFTBufferManager::setIQLogicState(BOOL reversed)
{
	ReverseIQ(mSpectrumAnalysis, reversed);
}


void FFTBufferManager::setNumAudioChannels(int audiochannels)
{
	mInputAudioChannels.store(audiochannels, std::memory_order_release);
	setNumberOfAudioChannels(mSpectrumAnalysis, audiochannels);
}


void FFTBufferManager::setSpectrumMagnitudeShift(int spectrumMagnitudeShift)
{
	setSpectrumMagShift(mSpectrumAnalysis, spectrumMagnitudeShift);
}


void FFTBufferManager::setSignalScaleFactor(float signalScaling)
{
	setSignalScaling(mSpectrumAnalysis, signalScaling);
}


void FFTBufferManager::setDSPBufferReady(BOOL setting)
{
	mDSPBufferReady.store(setting, std::memory_order_release);
}


BOOL FFTBufferManager::getDSPBufferReady()
{
	return mDSPBufferReady.load(std::memory_order_acquire);
}



void FFTBufferManager::AudioBufferFlush()
{
	mInputAudioChunkCount.store(0, std::memory_order_release);
	mInputAudioFrameCount.store(0, std::memory_order_release);
	mOutputAudioFrameCount.store(0, std::memory_order_release);
	mProcessedAudioChunkCount.store(0, std::memory_order_release);
	mProcessedAudioFrameCount.store(0, std::memory_order_release);
	mFramesSinceTrigger.store(0, std::memory_order_release);
#ifdef SDR_DEBUG
	missedFrames1 = 0;
	missedFrames2=0;
	maxInputFrames=0;
	minInputFrames=4096;
#endif

	// Reset ownership counters without touching storage concurrently used by the
	// realtime callback. Underruns are explicitly silenced before stale data can play.
	mHeadAudioInputCircularBufferIndex_frame.store(0, std::memory_order_release);
	mTailAudioOutputCircularBufferIndex_frame.store(0, std::memory_order_release);
//	mTailAudioInputCircularBufferIndex = 0;
	// mTailAudioInputCircularBufferIndex_frame = 0;
//	mAudioOutputCircularBufferUsed_frames = 0;
	mHasNewSpectrumData.store(false, std::memory_order_release);

}

#ifdef SDR_DEBUG
char* FFTBufferManager::getDebugMessage()
{
	static char debugMessage[256];

	sprintf(debugMessage, "Input chunks=%llu frames= %llu\nProc'd chunks=%llu frames=%llu\nOutput frames=%llu\nMissed frames1=%u\nMissed frames2=%u\nmaxframes=%u\nminframes=%u",
			mInputAudioChunkCount.load(std::memory_order_acquire),
			mInputAudioFrameCount.load(std::memory_order_acquire),
			mProcessedAudioChunkCount.load(std::memory_order_acquire),
			mProcessedAudioFrameCount.load(std::memory_order_acquire),
			mOutputAudioFrameCount.load(std::memory_order_acquire),
			(unsigned int)missedFrames1,
			(unsigned int)missedFrames2,
			(unsigned int)maxInputFrames,
			(unsigned int)minInputFrames
			);

	return(debugMessage);
}
#endif

/* This method allows the AppDelegate to request calculations of spectrum power levels */
Boolean	FFTBufferManager::ComputeFFT(int32_t** SpectrumDataptr, int32_t* SpectrumDataSize)
{
	if(SpectrumDataptr == NULL || SpectrumDataSize == NULL || !mValid)
		return FALSE;

	if(mHasNewSpectrumData.load(std::memory_order_acquire))
	{
		const int32_t currentSpectrumSize = GetSpectrumBufferSize(mSpectrumAnalysis);
		if(currentSpectrumSize <= 0 || (UInt32)currentSpectrumSize > mSpectrumSnapshotSize)
			return FALSE;
		// Keep the producer blocked from replacing the magnitude data until the
		// UI owns a stable snapshot, then release it to compute the next frame.
		memcpy(mSpectrumSnapshot, GetSpectrumBuffer(mSpectrumAnalysis),
			(size_t)currentSpectrumSize * sizeof(int32_t));
		*SpectrumDataptr = mSpectrumSnapshot;
		*SpectrumDataSize = currentSpectrumSize;
		mHasNewSpectrumData.store(false, std::memory_order_release);
		return TRUE;
	}

	return FALSE;
}


/* This method runs the dsp audio processing chain on any buffered data sitting in the circular buffer.
 Results are placed back in the buffer at the same spot from which the raw audio was read. FFT magnitude
 results get calculated (if requested) and are placed into a separate buffer that can be read by
 any external object by calling ComputeFFT.
 */
Boolean FFTBufferManager::ProcessAudio()
{
	// Check to see if there is a full chunk of data waiting for processing
	const UInt64 inputChunks = mInputAudioChunkCount.load(std::memory_order_acquire);
	const UInt64 processedChunks = mProcessedAudioChunkCount.load(std::memory_order_acquire);
	if(inputChunks > processedChunks)
	{
		//////////////////////////////////////////////////////////////////////
		// Read audio data from input circular buffer into DSP processing   //
		// which places the processed audio into the output circular buffer //
		//////////////////////////////////////////////////////////////////////

		const UInt64 processedFrames = mProcessedAudioFrameCount.load(std::memory_order_acquire);
		const int32_t tailFrame = (int32_t)(processedFrames % mAudioBufferSize_frames);
		if((UInt32)tailFrame + DSP_CHUNKSIZE_FRAMES > mAudioBufferSize_frames)
			return FALSE;

		const bool spectrumPending = mHasNewSpectrumData.load(std::memory_order_acquire);
		SpectrumAnalysisProcess(mSpectrumAnalysis,
			mInAudioBuffer[0]+tailFrame, mInAudioBuffer[1]+tailFrame,
			mOutAudioBuffer[0]+tailFrame, mOutAudioBuffer[1]+tailFrame,
			mCenterFrequency.load(std::memory_order_acquire), !spectrumPending);
		if(!spectrumPending && mBufferActive.load(std::memory_order_acquire))
			mHasNewSpectrumData.store(true, std::memory_order_release);

		mProcessedAudioChunkCount.fetch_add(1, std::memory_order_release);
		mProcessedAudioFrameCount.fetch_add(SEGMENT_STEPSIZE_FRAMES, std::memory_order_release);

#ifdef SDR_DEBUG
		if(mProcessedAudioFrameCount.load(std::memory_order_acquire) >
			mInputAudioFrameCount.load(std::memory_order_acquire))
		{
			SDR_DEBUGPRINT(("Processed frame count is out of sync!\n"));
		}
#endif

//		mTailAudioInputCircularBufferIndex = (mTailAudioInputCircularBufferIndex + 1) % mNumberBufferSegments;

		return(mInputAudioChunkCount.load(std::memory_order_acquire) >
			mProcessedAudioChunkCount.load(std::memory_order_acquire));
	}

	return(FALSE);
}
