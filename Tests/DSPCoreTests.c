/*
 Copyright (c) 2026 OpenARDF. Licensed under the MIT License.
*/

/*
 * Characterization tests for iSDR's platform-neutral FFT implementation.
 *
 * The small reference DFT is intentionally independent of the production
 * radix-2 implementation. It is an oracle for behavior, not a second DSP path
 * used by the application.
 */

#include "rad2fft.h"
#include "AudioBufferUtilities.h"

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static int failures = 0;

#define EXPECT_TRUE(condition) do { \
	if (!(condition)) { \
		fprintf(stderr, "%s:%d: expected %s\n", __FILE__, __LINE__, #condition); \
		failures++; \
	} \
} while (0)

static void expect_near(float actual, float expected, float tolerance, const char *label)
{
	if (!isfinite(actual) || fabsf(actual - expected) > tolerance)
	{
		fprintf(stderr, "%s: expected %.7f, got %.7f (tolerance %.7f)\n",
				label, expected, actual, tolerance);
		failures++;
	}
}

static void reference_dft(const FloatCplx *input, FloatCplx *output, int size, int inverse)
{
	const double direction = inverse ? 1.0 : -1.0;

	for (int bin = 0; bin < size; bin++)
	{
		double real = 0.0;
		double imag = 0.0;

		for (int sample = 0; sample < size; sample++)
		{
			const double angle = direction * 2.0 * M_PI * (double)bin * (double)sample / (double)size;
			const double cosine = cos(angle);
			const double sine = sin(angle);
			real += (double)input[sample].real * cosine - (double)input[sample].imag * sine;
			imag += (double)input[sample].real * sine + (double)input[sample].imag * cosine;
		}

		// The production FFT scales every butterfly, so its transform is normalized by N.
		output[bin].real = (float)(real / (double)size);
		output[bin].imag = (float)(imag / (double)size);
	}
}

static void test_float_fft_matches_reference(void)
{
	enum { size = 8 };
	const FloatCplx input[size] = {
		{ 1.0f, 0.0f }, { 0.5f, -0.25f }, { -0.75f, 0.5f }, { 0.0f, 1.0f },
		{ 0.25f, -0.5f }, { -1.0f, 0.0f }, { 0.125f, 0.75f }, { 0.5f, 0.25f }
	};
	FloatCplx actual[size];
	FloatCplx expected[size];
	PackedInt16Cplx *twiddles = CreatePackedTwiddleFactors(size, FALSE);

	EXPECT_TRUE(twiddles != NULL);
	if (twiddles == NULL)
		return;

	for (int i = 0; i < size; i++)
		actual[i] = input[i];

	reference_dft(input, expected, size, FALSE);
	Radix2FloatCplxFFT(actual, size, twiddles, 1);

	for (int i = 0; i < size; i++)
	{
		char label[64];
		snprintf(label, sizeof(label), "float FFT bin %d real", i);
		expect_near(actual[i].real, expected[i].real, 0.0001f, label);
		snprintf(label, sizeof(label), "float FFT bin %d imaginary", i);
		expect_near(actual[i].imag, expected[i].imag, 0.0001f, label);
	}

	DisposePackedTwiddleFactors(twiddles);
}

static void test_integer_fft_impulse_is_flat(void)
{
	enum { size = 8 };
	Int32Cplx data[size] = { 0 };
	PackedInt16Cplx *twiddles = CreatePackedTwiddleFactors(size, FALSE);

	EXPECT_TRUE(twiddles != NULL);
	if (twiddles == NULL)
		return;

	data[0].real = size * 1024;
	Radix2IntCplxFFT(data, size, twiddles, 1);

	for (int i = 0; i < size; i++)
	{
		EXPECT_TRUE(data[i].real == 1024);
		EXPECT_TRUE(data[i].imag == 0);
	}

	DisposePackedTwiddleFactors(twiddles);
}

static void test_bandpass_kernel_contract(void)
{
	enum { kernel_size = 5, fft_size = 16 };
	FloatCplx *kernel = CreateBPFKernel(kernel_size, fft_size, 44100.0f, 1400.0f, 2600.0f);

	EXPECT_TRUE(kernel != NULL);
	if (kernel != NULL)
	{
		for (int i = 0; i < kernel_size; i++)
		{
			EXPECT_TRUE(isfinite(kernel[i].real));
			EXPECT_TRUE(kernel[i].imag == 0.0f);
		}
		for (int i = kernel_size; i < fft_size; i++)
		{
			EXPECT_TRUE(kernel[i].real == 0.0f);
			EXPECT_TRUE(kernel[i].imag == 0.0f);
		}
		DisposeFilterKernel(kernel);
	}

	EXPECT_TRUE(CreateBPFKernel(4, fft_size, 44100.0f, 1400.0f, 2600.0f) == NULL);
	EXPECT_TRUE(CreateBPFKernel(kernel_size, fft_size, 44100.0f, 22000.0f, 1000.0f) == NULL);
}

static void test_circular_copy_wraps_without_overrun(void)
{
	int32_t ring[8] = { 0 };
	const int32_t source[4] = { 10, 11, 12, 13 };
	int32_t destination[4] = { 0 };

	EXPECT_TRUE(ISDRCopyFramesIntoRing(ring, 8, 6, source, 4));
	EXPECT_TRUE(ring[6] == 10 && ring[7] == 11 && ring[0] == 12 && ring[1] == 13);
	EXPECT_TRUE(ISDRCopyFramesFromRing(ring, 8, 6, destination, 4));
	for (int i = 0; i < 4; i++)
		EXPECT_TRUE(destination[i] == source[i]);

	EXPECT_TRUE(!ISDRCopyFramesIntoRing(ring, 8, 8, source, 4));
	EXPECT_TRUE(!ISDRCopyFramesFromRing(ring, 8, 0, destination, 9));
}

static void test_file_cursor_crosses_buffer_boundary(void)
{
	const int32_t first[] = { 1, 101, 2, 102, 3, 103 };
	const int32_t second[] = { 4, 104, 5, 105, 6, 106, 7, 107 };
	const int32_t *buffers[2] = { first, second };
	const size_t frameCounts[2] = { 3, 4 };
	ISDRStereoFileCursor cursor = { 0, { 2, 0 } };
	int32_t left[4] = { 0 };
	int32_t right[4] = { 0 };
	uint32_t exhaustedMask = 0;

	const size_t copied = ISDRCopyStereoFileFrames(buffers, frameCounts, &cursor,
													left, right, 4, &exhaustedMask);
	EXPECT_TRUE(copied == 4);
	EXPECT_TRUE(left[0] == 3 && left[1] == 4 && left[2] == 5 && left[3] == 6);
	EXPECT_TRUE(right[0] == 103 && right[1] == 104 && right[2] == 105 && right[3] == 106);
	EXPECT_TRUE(exhaustedMask == UINT32_C(1));
	EXPECT_TRUE(cursor.activeBuffer == 1);
	EXPECT_TRUE(cursor.framePositions[0] == 0 && cursor.framePositions[1] == 3);
}

int main(void)
{
	test_float_fft_matches_reference();
	test_integer_fft_impulse_is_flat();
	test_bandpass_kernel_contract();
	test_circular_copy_wraps_without_overrun();
	test_file_cursor_crosses_buffer_boundary();

	if (failures != 0)
	{
		fprintf(stderr, "%d DSP core assertion(s) failed.\n", failures);
		return EXIT_FAILURE;
	}

	puts("DSP core tests passed (FFT, BPF, circular buffer, file cursor).\n");
	return EXIT_SUCCESS;
}
