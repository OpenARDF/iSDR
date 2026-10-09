/*
 Copyright (c) 2026 OpenARDF. Licensed under the MIT License.
*/

/*
 * Sanitizer-backed characterization tests for iSDR's production analysis path.
 */

#include "SpectrumAnalysis.h"

#include <climits>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

static int failures = 0;

#define EXPECT_TRUE(condition) do { \
	if (!(condition)) { \
		std::fprintf(stderr, "%s:%d: expected %s\n", __FILE__, __LINE__, #condition); \
		failures++; \
	} \
} while (0)

static void exercise_mode(int channels, iSDROperatingMode mode, bool extremeInput)
{
	H_SPECTRUM_ANALYSIS analysis = SpectrumAnalysisCreate(DSP_CHUNKSIZE_FRAMES, channels);
	EXPECT_TRUE(analysis != nullptr);
	if (analysis == nullptr)
		return;

	int32_t inputI[DSP_CHUNKSIZE_FRAMES] = { 0 };
	int32_t inputQ[DSP_CHUNKSIZE_FRAMES] = { 0 };
	int32_t outputI[DSP_CHUNKSIZE_FRAMES] = { 0 };
	int32_t outputQ[DSP_CHUNKSIZE_FRAMES] = { 0 };

	if (extremeInput)
	{
		for (int i = 0; i < DSP_CHUNKSIZE_FRAMES; i++)
		{
			inputI[i] = (i & 1) == 0 ? INT32_MAX : INT32_MIN;
			inputQ[i] = (i & 1) == 0 ? INT32_MIN : INT32_MAX;
		}
	}

	setSidebandMode(analysis, mode);
	SpectrumAnalysisProcess(analysis, inputI, inputQ, outputI, outputQ, 0.5f, TRUE);
	EXPECT_TRUE(GetSpectrumBuffer(analysis) != nullptr);
	EXPECT_TRUE(GetSpectrumBufferSize(analysis) == (channels == 2 ? 2048 : 1024));

	// A second pass exercises overlap-add state and the zero-vector NFM denominator.
	SpectrumAnalysisProcess(analysis, inputI, inputQ, outputI, outputQ, 0.5f, TRUE);
	SpectrumAnalysisDestroy(analysis);
}

int main()
{
	EXPECT_TRUE(SpectrumAnalysisCreate(1000, 2) == nullptr);
	EXPECT_TRUE(SpectrumAnalysisCreate(DSP_CHUNKSIZE_FRAMES, 0) == nullptr);
	EXPECT_TRUE(SpectrumAnalysisCreate(DSP_CHUNKSIZE_FRAMES, 3) == nullptr);

	for (int channels = 1; channels <= 2; channels++)
	{
		exercise_mode(channels, USB_mode, false);
		exercise_mode(channels, AM_mode, true);
		exercise_mode(channels, NFM_mode, false);
	}

	if (failures != 0)
	{
		std::fprintf(stderr, "%d spectrum assertion(s) failed.\n", failures);
		return EXIT_FAILURE;
	}

	std::puts("Spectrum analysis tests passed (mono/stereo, USB/AM/NFM, extreme input).");
	return EXIT_SUCCESS;
}
