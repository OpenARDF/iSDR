/*
 Third-party provenance: portions of this file are derived from Apple's
 SpeakHere audio-meter sample code.

 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

 File: MeterTable.cpp
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

#include "MeterTable.h"

inline double DbToAmp(double inDb)
{
	return pow(10., 0.05 * inDb);
}

MeterTable::MeterTable(float inMinDecibels, size_t inTableSize, float inRoot)
	: mMinDecibels(inMinDecibels),
	mDecibelResolution(mMinDecibels / (inTableSize - 1)),
	mScaleFactor(1. / mDecibelResolution)
{
	if (inMinDecibels >= 0.)
	{
		printf("MeterTable inMinDecibels must be negative");
		return;
	}

	mTable = (float*)malloc(inTableSize*sizeof(float));

	double minAmp = DbToAmp(inMinDecibels);
	double ampRange = 1. - minAmp;
	double invAmpRange = 1. / ampRange;

	double rroot = 1. / inRoot;
	for (size_t i = 0; i < inTableSize; ++i) {
		double decibels = i * mDecibelResolution;
		double amp = DbToAmp(decibels);
		double adjAmp = (amp - minAmp) * invAmpRange;
		mTable[i] = pow(adjAmp, rroot);
	}
}

MeterTable::~MeterTable()
{
	free(mTable);
}
