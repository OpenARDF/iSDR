/*

    File: rad2fft.c
Abstract: Radix 2 integer FFT
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

#import <stdlib.h>
#import <math.h>
#import <stdio.h>
#import "rad2fft.h"
#import <string.h>

#ifndef TRUE
#define TRUE true
#endif

#ifndef FALSE
#define FALSE false
#endif


#define CplxMul32Packed(x,p) { \
	int tmp = x.real; int32_t c = (int32_t)((uint32_t)(p) & UINT32_C(0xffff0000)); int32_t s = (int32_t)((uint32_t)(p) << 16); \
	x.real = (int)( ( (int64_t)tmp * (int64_t)c - (int64_t)x.imag * (int64_t)s ) >> 32 ); \
	x.imag = (int)( ( (int64_t)tmp * (int64_t)s + (int64_t)x.imag * (int64_t)c ) >> 32 ); \
} \

#define FloatCplxMul32Packed(x,p) { \
float tmp = x.real; int32_t c = (int32_t)((uint32_t)(p) & UINT32_C(0xffff0000)); int32_t s = (int32_t)((uint32_t)(p) << 16); \
x.real = ( ( tmp * (float)c - (float)x.imag * (float)s ) / powf(2.0, 32.0) ); \
x.imag = ( ( tmp * (float)s + (float)x.imag * (float)c ) / powf(2.0, 32.0) ); \
} \



// The product (a + bi) · (c + di) can be calculated in the following way.
// k1 = c · (a + b)
// k2 = a · (d − c)
// k3 = b · (c + d)
// Real part = k1 − k3
// Imaginary part = k1 + k2.
#define FloatCplxMul(x,y) { \
float k1 = y.real * (x.real + x.imag); float k2 = x.real * (y.imag - y.real); float k3 = x.imag * (y.real + y.imag); \
x.real = (k1 - k3); \
x.imag = (k1 + k2); \
} \
// x.real = (k1 - k3); // / powf(2.0, 32.0); \
// x.imag = (k1 + k2); // / powf(2.0, 32.0); \


//#define FloatCplxMul(x,y) { \
//float tmp = x.real; \
//x.real = ( ( tmp * (float)y.real - (float)x.imag * (float)y.imag ) ); \
//x.imag = ( ( tmp * (float)y.imag + (float)x.imag * (float)y.real ) ); \
//}


#define Radix2IntButterfly(x0,x1) { \
int tmp = x0.real>>1; \
x0.real = tmp + (x1.real);\
x1.real = tmp - (x1.real);\
tmp = (x0.imag>>1); \
x0.imag = tmp + (x1.imag);\
x1.imag = tmp - (x1.imag);\
} \

#define Radix2IntButterflyShift(x0,x1) { \
int tmp = x0.real>>1; \
x0.real = tmp + (x1.real>>1);\
x1.real = tmp - (x1.real>>1);\
tmp = (x0.imag>>1); \
x0.imag = tmp + (x1.imag>>1);\
x1.imag = tmp - (x1.imag>>1);\
} \

#define Radix2FloatButterfly(x0,x1) { \
float tmp = x0.real/2.0; \
x0.real = tmp + (x1.real);\
x1.real = tmp - (x1.real);\
tmp = (x0.imag)/2.0; \
x0.imag = tmp + (x1.imag);\
x1.imag = tmp - (x1.imag);\
} \

#define Radix2FloatButterflyShift(x0,x1) { \
float tmp = x0.real/2.0; \
x0.real = tmp + (x1.real/2);\
x1.real = tmp - (x1.real/2);\
tmp = (x0.imag)/2.0; \
x0.imag = tmp + (x1.imag/2);\
x1.imag = tmp - (x1.imag/2);\
} \

//#define Radix2FloatButterfly(x0,x1) { \
//float tmp = x0.real; \
//x0.real = tmp + (x1.real);\
//x1.real = tmp - (x1.real);\
//tmp = (x0.imag); \
//x0.imag = tmp + (x1.imag);\
//x1.imag = tmp - (x1.imag);\
//}

static int FloatToInt16(float x)
{
	int y;
	if(x<0.f) {
		if(x<=-32768.0f) y = -32768;
		else y = (int)(x - 0.5f);
	} else {
		if(x>=32767.0f) y = 32767;
		else y = (int)(x + 0.5f);
	}
	return y;
}


static void BitReverseReorder(Int32Cplx* ioCplxData, int N)
{
	int linearIdx, bitReversedIdx;

	for(linearIdx = 1, bitReversedIdx = 0; linearIdx < N - 1; ++linearIdx) {
		int halfSize = N;
		do {
			halfSize >>=1;
			bitReversedIdx ^= halfSize;
		} while(bitReversedIdx < halfSize);

		if(linearIdx < bitReversedIdx) {
			/* Swap linear and bit reversed indexed values */
			Int32Cplx tmp = ioCplxData[bitReversedIdx];
			ioCplxData[bitReversedIdx] = ioCplxData[linearIdx];
			ioCplxData[linearIdx] = tmp;
		}
	}
}


static void BitReverseReorderFloat(FloatCplx* ioCplxData, int N)
{
	int linearIdx, bitReversedIdx;

	for(linearIdx = 1, bitReversedIdx = 0; linearIdx < N - 1; ++linearIdx) {
		int halfSize = N;
		do {
			halfSize >>=1;
			bitReversedIdx ^= halfSize;
		} while(bitReversedIdx < halfSize);

		if(linearIdx < bitReversedIdx) {
			/* Swap linear and bit reversed indexed values */
			FloatCplx tmp = ioCplxData[bitReversedIdx];
			ioCplxData[bitReversedIdx] = ioCplxData[linearIdx];
			ioCplxData[linearIdx] = tmp;
		}
	}
}


Int32Cplx* CreateIntTwiddleFactors(int size, int doinverse)
{
	int i;
	Int32Cplx* twiddleFactors = (Int32Cplx*)malloc(sizeof(Int32Cplx)*size);
	float scaleFac = (float)(1<<15);

	if(twiddleFactors)
	{
		for(i = 0; i < size/2; ++i) {
//			int cosSin;
			float tmp;
			tmp = scaleFac*cosf(2.0*M_PI*i/size);
			twiddleFactors[i].real = FloatToInt16(tmp);
			if (doinverse) {
				tmp = scaleFac*sinf(2.0*M_PI*i/size);
			}
			else {
				tmp = -scaleFac*sinf(2.0*M_PI*i/size);
			}
//			cosSin |= FloatToInt16(tmp) & 0x0000ffff;
//			twiddleFactors[i].real = cosSin;
			twiddleFactors[i].imag = FloatToInt16(tmp);
		}
	}
	else SDR_DEBUGPRINT(("Error allocating memory for twiddle factors\n"));

		return twiddleFactors;
}


PackedInt16Cplx* CreatePackedTwiddleFactors(int size, int doinverse)
{
	int i;
	PackedInt16Cplx* twiddleFactors = (PackedInt16Cplx*)malloc(sizeof(PackedInt16Cplx)*size);
	float scaleFac = (float)(1<<15);

	if(twiddleFactors)
	{
		for(i = 0; i < size/2; ++i) {
			uint32_t cosSin;
			float tmp;
			tmp = scaleFac*cosf(2.0*M_PI*i/size);
			cosSin = (uint32_t)(uint16_t)FloatToInt16(tmp) << 16;
			if (doinverse) {
				tmp = scaleFac*sinf(2.0*M_PI*i/size);
			}
			else {
				tmp = -scaleFac*sinf(2.0*M_PI*i/size);
			}
			cosSin |= (uint32_t)(uint16_t)FloatToInt16(tmp);
			twiddleFactors[i] = cosSin;
		}
	}
	else SDR_DEBUGPRINT(("Error allocating memory for twiddle factors\n"));

	return twiddleFactors;
}


FloatCplx* CreateFloatTwiddleFactors(int size, int doinverse)
{
	int i;
	FloatCplx* twiddleFactors = (FloatCplx*)malloc(sizeof(FloatCplx)*size);
	float scaleFac = (float)1; //(1<<15);

	if(twiddleFactors) {
		for(i = 0; i < size/2; ++i) {
			float tmp = 2.0 * M_PI * i / size;
			twiddleFactors[i].real = scaleFac*cosf(tmp);
			if (doinverse) {
				twiddleFactors[i].imag = scaleFac*sinf(tmp);
			}
			else {
				twiddleFactors[i].imag = -scaleFac*sinf(tmp);
			}
		}
	}
	return twiddleFactors;
}


FloatCplx* CreateBPFKernel(int size, int FFTsize_frames, float samplefrequency, float centerFrequency, float bandwidth)
{
	// 100 'BAND-PASS WINDOWED-SINC FILTER
	// 110 'This program calculates band-pass filter kernel which has /size/ points

	if(size < 3 || FFTsize_frames < 2 || samplefrequency <= 0.0f ||
		bandwidth <= 0.0f || centerFrequency < 0.0f)
		return NULL;

	if(size > FFTsize_frames)
		size = (2 * (FFTsize_frames / 2)) - 1;

	FloatCplx* filterKernel = (FloatCplx*)malloc(sizeof(FloatCplx)*FFTsize_frames);
	float* lowerCutoff = (float*)malloc(sizeof(float)*size);  // workspace for the lower cutoff filter
	float* upperCutoff = (float*)malloc(sizeof(float)*size);  // workspace for the upper cutoff filter
	int i, M, err=FALSE;
	float FcLow, FcHigh, sum;

	if(filterKernel == NULL || lowerCutoff == NULL || upperCutoff == NULL)
	{
		free(filterKernel);
		free(lowerCutoff);
		free(upperCutoff);
		return NULL;
	}

	// Fc = center frequency expressed as a fraction of the sampling rate
	// iPhone audio sampling rate = 44100 Hz (but need to account for decimation)
	// FcL = lower-freq-limit / 44100
	// FcH = upper-freq-limit / 44100

	FcLow = (centerFrequency - (bandwidth / 2.0));

	FcHigh = (centerFrequency + (bandwidth / 2.0));

	if(FcLow < 0.0) FcLow = 0.0;

	if(FcHigh > samplefrequency/2)
	{
		SDR_DEBUGPRINT(("Error: Filter description exceeds practical limits!\n"));
		err = TRUE;
	}

	if(!(size % 2))
	{
		SDR_DEBUGPRINT(("Error: filter kernel must be odd number of points!\n"));
		err = TRUE;
	}

	if (err)
	{
		if (filterKernel)
		{
			free(filterKernel);
		}
		if (lowerCutoff)
		{
			free(lowerCutoff);
		}
		if (upperCutoff)
		{
			free(upperCutoff);
		}

		return(NULL);
	}

	FcLow /= samplefrequency;
	FcHigh /= samplefrequency;

	M = size - 1;

	// Calculate the first low-pass filter kernel via Eq.
	// 16-4, with a cutoff frequency of 0.196, store in A[]
	sum = 0.0;
	for (i=0; i <= M; i++)
	{
		if (i == M/2)
		{
			lowerCutoff[i] = 2 * M_PI * FcLow;
		}
		else
		{
			lowerCutoff[i] = sinf(2.0 * M_PI * FcLow * (float)(i - M/2)) / (float)(i - M/2);
		}

		lowerCutoff[i] *= (0.42 - 0.5 * cosf(2.0 * M_PI * (float)i / (float)M) + 0.08 * cosf(4.0 * M_PI * (float)i/(float)M));
		sum += lowerCutoff[i];
	}

	// Normalize the first low-pass filter kernel for unity gain at DC

	for (i=0; i <= M; i++)
	{
		if(sum != 0) lowerCutoff[i] /= sum;
	}

	// Calculate the second low-pass filter kernel via Eq. 16-4, with a cutoff frequency of 0.204, store in B[]
	// and normalize the second low-pass filter kernel for unity gain at DC

	sum = 0.0;
	for(i=0; i <= M; i++)
	{
		if (i == M/2)
		{
			upperCutoff[i] = 2 * M_PI * FcHigh;
		}
		else
		{
			upperCutoff[i] = sinf(2.0 * M_PI * FcHigh * (float)(i - M/2)) / (float)(i - M/2);
		}

		upperCutoff[i] *= (0.42 - 0.5 * cosf(2.0 * M_PI * (float)i / (float)M) + 0.08 * cosf(4.0 * M_PI * (float)i/(float)M));
		sum += upperCutoff[i];
	}

	// Change the low-pass filter kernel into a
	// high-pass filter kernel using spectral inversion
	for (i=0; i <= M; i++)
	{
		if(sum != 0) upperCutoff[i] /= sum;
		upperCutoff[i] = - upperCutoff[i];
	}

//	upperCutoff[M/2] += 1.0; // is this needed? It appears to work without it.

	// Add the low-pass filter kernel in A[ ], to the
	// high-pass filter kernel in B[ ], to form a band
	// reject filter kernel, stored in H[ ] (Fig.14-8)
	// Change the band-reject filter kernel into a
	// band-pass filter kernel by using spectral inversion
	// The band-pass filter kernel now resides in H[ ]

	for(i=0; i <= M; i++)
	{
		filterKernel[i].real = -(lowerCutoff[i] + upperCutoff[i]) *  500.0;
		filterKernel[i].imag = 0;
	}

//	filterKernel[M/2].real += 1.0; // is this needed? It appears to work without it.

	//pad with zeroes
	for(i=size; i < FFTsize_frames; i++)
	{
		filterKernel[i].real = filterKernel[i].imag = 0;
	}

	if (lowerCutoff)
	{
		free(lowerCutoff);
	}

	if (upperCutoff)
	{
		free(upperCutoff);
	}

	return(filterKernel);
}


void DisposeFilterKernel(FloatCplx* filterKernel)
{
	if(filterKernel)
	{
		free(filterKernel);
	}
}


void DisposeIntTwiddleFactors(Int32Cplx* twiddleFactors)
{
	if(twiddleFactors)
	{
		free(twiddleFactors);
	}
}


void DisposePackedTwiddleFactors(PackedInt16Cplx* twiddleFactors)
{
	if(twiddleFactors)
	{
		free(twiddleFactors);
	}
}


void DisposeFloatTwiddleFactors(FloatCplx* twiddleFactors)
{
	if(twiddleFactors)
	{
		free(twiddleFactors);
	}
}


void Radix2IntCplxFFT(Int32Cplx* ioCplxData, int size, const PackedInt16Cplx* twiddleFactors, int twiddleFactorsStrides)
//void Radix2IntCplxFFT(Int32Cplx* ioCplxData, int size, const Int32Cplx* twiddleFactors, int twiddleFactorsStrides)
{
	int span, twiddle, strides;

	/* Reorder input data in bit-reversed order */
	BitReverseReorder(ioCplxData, size);

	span = 1;
	//	twiddle = 1;
	strides = twiddleFactorsStrides*size / 2;

	do {
		register Int32Cplx x0, x1;
		int idx = 0;

		do {
			/* Multiply-less butterfly */
			x1 = ioCplxData[idx+span];
			x0 = ioCplxData[idx];
			Radix2IntButterflyShift(x0, x1); // major time hogg
//#define Radix2IntButterflyShift(x0,x1)
//			{
//				int tmp = x0.real>>1;
//				x0.real = tmp + (x1.real>>1);
//				x1.real = tmp - (x1.real>>1);
//				tmp = (x0.imag>>1);
//				x0.imag = tmp + (x1.imag>>1);
//				x1.imag = tmp - (x1.imag>>1);
//			}

			ioCplxData[idx] = x0;
			ioCplxData[idx+span] = x1;
			idx += span << 1;
		} while(idx < size);

		twiddle = 1;

		while(twiddle < span) {
			PackedInt16Cplx packedTwiddleFactor = twiddleFactors[strides*twiddle];
//			Int32Cplx TwiddleFactor = twiddleFactors[strides*twiddle];
			idx = twiddle;
//			int64_t tmp;
//			int64_t c;
//			int64_t s;

			//Need to align loop using -falign-loops=16
			do {
				x1 = ioCplxData[idx+span];
				x0 = ioCplxData[idx];
//-falign-loops=16
				CplxMul32Packed(x1, packedTwiddleFactor); // major time hogg
//#define CplxMul32Packed(x,p)
//				{
//					tmp = x1.real;
//					c = TwiddleFactor.real;
//					s = TwiddleFactor.imag;
//					x1.real = (int)( ( tmp * c - (int64_t)x1.imag * s ) >> 16 );
//					x1.imag = (int)( ( tmp * s + (int64_t)x1.imag * c ) >> 16 );
//				}

				Radix2IntButterfly(x0, x1); // major time hogg
//#define Radix2IntButterfly(x0,x1)
//				{
//					tmp = x0.real>>1;
//					x0.real = tmp + (x1.real);
//					x1.real = tmp - (x1.real);
//					tmp = (x0.imag>>1);
//					x0.imag = tmp + (x1.imag);
//					x1.imag = tmp - (x1.imag);
//				}



				ioCplxData[idx] = x0;
				ioCplxData[idx+span] = x1;
				idx += span << 1;
			} while(idx < size);
			++twiddle;
		}
		span <<= 1;
		strides >>= 1;
	} while(span < size);
}


void Radix2FloatCplxFFT(FloatCplx* ioCplxData, int size, const PackedInt16Cplx* twiddleFactors, int twiddleFactorsStrides)
//void Radix2FloatCplxFFT(FloatCplx* ioCplxData, int size, const Int32Cplx* twiddleFactors, int twiddleFactorsStrides)
{
	int span, twiddle, strides;

	/* Reorder input data in bit reversed order */
	BitReverseReorderFloat(ioCplxData, size);

	span = 1;
	strides = twiddleFactorsStrides*size / 2;

	do {
		FloatCplx x0, x1;
		int idx = 0;

		do {
			/* Multiply-less butterfly */
			x1 = ioCplxData[idx+span];
			x0 = ioCplxData[idx];
			Radix2FloatButterflyShift(x0, x1);
			ioCplxData[idx] = x0;
			ioCplxData[idx+span] = x1;
			idx += span << 1;
		} while(idx < size);

		twiddle = 1;

		while(twiddle < span) {
			PackedInt16Cplx packedTwiddleFactor = twiddleFactors[strides*twiddle];
//			register Int32Cplx TwiddleFactor = twiddleFactors[strides*twiddle];
			idx = twiddle;

			do {
				x1 = ioCplxData[idx+span];
				x0 = ioCplxData[idx];
				FloatCplxMul32Packed(x1, packedTwiddleFactor);
				Radix2FloatButterfly(x0, x1);
//				FloatCplxMul32Packed(x1, TwiddleFactor);
//				{
//					float tmp = x1.real;
//					float c = TwiddleFactor.real;
//					float s = TwiddleFactor.imag;
//					x1.real = ( ( tmp * TwiddleFactor.real - (float)x1.imag * TwiddleFactor.imag ) / 65536. );
//					x1.imag = ( ( tmp * TwiddleFactor.imag + (float)x1.imag * TwiddleFactor.real ) / 65536. );
//				}


				ioCplxData[idx] = x0;
				ioCplxData[idx+span] = x1;
				idx += span << 1;
			} while(idx < size);

			++twiddle;
		}

		span <<= 1;
		strides >>= 1;
	}
	while(span < size);
}
