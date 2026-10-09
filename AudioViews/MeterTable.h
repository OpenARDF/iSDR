/*
 Third-party provenance: portions of this file are derived from Apple's
 SpeakHere audio-meter sample code.

 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

 File: MeterTable.h
 Abstract: Class for handling conversion from linear scale to dB
 Version: 2.0

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

#include <stdlib.h>
#include <stdio.h>
#include <math.h>

class MeterTable
{
public:
// MeterTable constructor arguments:
// inNumUISteps - the number of steps in the UI element that will be drawn.
//					This could be a height in pixels or number of bars in an LED style display.
// inTableSize - The size of the table. The table needs to be large enough that there are no large gaps in the response.
// inMinDecibels - the decibel value of the minimum displayed amplitude.
// inRoot - this controls the curvature of the response. 2.0 is square root, 3.0 is cube root. But inRoot doesn't have to be integer valued, it could be 1.8 or 2.5, etc.

MeterTable(float inMinDecibels = -80., size_t inTableSize = 400, float inRoot = 2.0);
~MeterTable();

	float ValueAt(float inDecibels)
	{
		if(mTable)
		{
			if (inDecibels < mMinDecibels) return  0.;
			if (inDecibels >= 0.) return 1.;
			int index = (int)(inDecibels * mScaleFactor);
			return mTable[index];
		}

		return 0.;
	}
private:
	float	mMinDecibels;
	float	mDecibelResolution;
	float	mScaleFactor;
	float	*mTable;
};
