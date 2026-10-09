/*
 Third-party provenance: portions of this file are derived from Apple's
 aurioTouch/aurioTouch2 sample code.

 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

    File: iSDR_helper.h
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

#if !defined(__rio_helper_h__)
#define __rio_helper_h__

#include "CAStreamBasicDescription.h"
#import "FFTBufferManager.h"

int SetupRemoteIO (AudioUnit& inRemoteIOUnit, AURenderCallbackStruct inRenderProcm, CAStreamBasicDescription& outFormat);
void SilenceData(AudioBufferList *inData);

class DCRejectionFilter
{
public:
	DCRejectionFilter(Float32 poleDist = DCRejectionFilter::kDefaultPoleDist);

	void InplaceFilter(SInt32* ioData, UInt32 numFrames);
	void Reset();

protected:

	// Coefficients
	SInt16 mA1;
	SInt16 mGain;

	// State variables
	SInt32 mY1;
	SInt32 mX1;

	static const Float32 kDefaultPoleDist;
};

#endif
