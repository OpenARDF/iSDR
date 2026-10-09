/*
 Third-party provenance: portions of this file are derived from Apple's
 aurioTouch/aurioTouch2 sample code.

 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

    File: iSDR_helper.cpp
Abstract: Helper class for manipulating the remote i/o audio unit
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

#import "product.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <stdio.h>

#import "CAXException.h"
#include "CAStreamBasicDescription.h"
#import "iSDR_helper.h"

int SetupRemoteIO (AudioUnit& inRemoteIOUnit, AURenderCallbackStruct inRenderProc, CAStreamBasicDescription& outFormat)
{
	try {
		// Open the output unit
		AudioComponentDescription desc;
		desc.componentType = kAudioUnitType_Output;
		desc.componentSubType = kAudioUnitSubType_RemoteIO;
		desc.componentManufacturer = kAudioUnitManufacturer_Apple;
		desc.componentFlags = 0;
		desc.componentFlagsMask = 0;

		AudioComponent comp = AudioComponentFindNext(NULL, &desc);

		XThrowIfError(AudioComponentInstanceNew(comp, &inRemoteIOUnit), "couldn't open the remote I/O unit");

		UInt32 one = 1;
		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one)), "couldn't enable input on the remote I/O unit");

		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &inRenderProc, sizeof(inRenderProc)), "couldn't set remote i/o render callback");

        // set our required format - Canonical AU format: LPCM non-interleaved 8.24 fixed point
        outFormat.SetAUCanonical(2, FALSE);
		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &outFormat, sizeof(outFormat)), "couldn't set the remote I/O unit's output client format");
		XThrowIfError(AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &outFormat, sizeof(outFormat)), "couldn't set the remote I/O unit's input client format");

		XThrowIfError(AudioUnitInitialize(inRemoteIOUnit), "couldn't initialize the remote I/O unit");
	}
	catch (...)
	{
		fprintf(stderr, "Error setting up remoteIO\n");
		return 1;
	}

	return 0;
}


void SilenceData(AudioBufferList *inData)
{
	for (UInt32 i=0; i < inData->mNumberBuffers; i++)
	{
		memset(inData->mBuffers[i].mData, 0, inData->mBuffers[i].mDataByteSize);
	}
}


inline SInt32 smul32by16(SInt32 i32, SInt16 i16)
{
#if defined __arm__
	register SInt32 r;
	asm volatile("smulwb %0, %1, %2" : "=r"(r) : "r"(i32), "r"(i16));
	return r;
#else
	return (SInt32)(((SInt64)i32 * (SInt64)i16) >> 16);
#endif
}

inline SInt32 smulAdd32by16(SInt32 i32, SInt16 i16, SInt32 acc)
{
#if defined __arm__
	register SInt32 r;
	asm volatile("smlawb %0, %1, %2, %3" : "=r"(r) : "r"(i32), "r"(i16), "r"(acc));
	return r;
#else
	return ((SInt32)(((SInt64)i32 * (SInt64)i16) >> 16) + acc);
#endif
}

const Float32 DCRejectionFilter::kDefaultPoleDist = 0.975f;

DCRejectionFilter::DCRejectionFilter(Float32 poleDist)
{
	mA1 = (SInt16)((float)(1<<15)*poleDist);
	mGain = (mA1 >> 1) + (1<<14); // Normalization factor: (r+1)/2 = r/2 + 0.5
	Reset();
}

void DCRejectionFilter::Reset()
{
	mY1 = mX1 = 0;
}

/*
 Butterworth 1st order HPF? Approximate cut-off 180Hz?
 Filtered audio data gets written directly to the output buffer
 */
void DCRejectionFilter::InplaceFilter(SInt32* ioData, UInt32 numFrames)
{
	SInt32 y1 = mY1, x1 = mX1;
	for (UInt32 i=0; i < numFrames; i++)
	{
		SInt32 x0, y0;
		x0 = ioData[i];
		y0 = smul32by16(y1, mA1);
		y1 = smulAdd32by16(x0 - x1, mGain, y0) << 1;
		ioData[i] = y1;
		x1 = x0;
	}
	mY1 = y1;
	mX1 = x1;
}
