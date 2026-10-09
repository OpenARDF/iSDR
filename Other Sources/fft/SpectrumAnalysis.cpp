/*

    File: SpectrumAnalysis.cpp
Abstract: Simple spectral analysis tool
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
#import <stdio.h>
#import <string.h>
#import <math.h>
#import "rad2fft.h"
#import "SpectrumAnalysis.h"
#import <sys/types.h>
#include <stdint.h>
#include <mutex>
#include <new>

/*
 * Convert from Cartesian to polar coordinates. Write results into outBuffer.
 */
void MagSpectrumCplx32(H_SPECTRUM_ANALYSIS p);
//void MagSpectrumCplx32(Int32Cplx* inBuffer, int32_t* outMag, int size, int audiochannels, int spectrumMagnitudeShift);
//void PhaseSpectrumCplx32(Int32Cplx* inBuffer, int32_t* outPhase, int size);

#define Scale(e) powf(2.0,e)

#define kLog2TableLog2Size 8
#define kLog2TableSize (1<<kLog2TableLog2Size)

//#define CplxMul32Cplx(x,p) { \
//int tmp = x.real; \
//x.real = (int)( (int64_t)tmp * (int64_t)p.real - (int64_t)x.imag * (int64_t)p.imag ); \
//x.imag = (int)( (int64_t)tmp * (int64_t)p.imag + (int64_t)x.imag * (int64_t)p.real ); \
//} \

// x is a Int32Cplx and p is a FloatCplx
#define CplxMul32FloatCplx(x,p) { \
float tmp = (float)x.real; \
x.real = (int)( tmp * p.real - (float)x.imag * p.imag ); \
x.imag = (int)( tmp * p.imag + (float)x.imag * p.real ); \
} \

// scaling constant for the log2 to 10*log10 conversion (equals 3.0103, stored as Q2.13)
static const int16_t kLog2ToLog10ScaleFactor = (int16_t)((float)(1<<13)*10.0f*logf(2.0f)/logf(10.0f) + 0.5f);
//static const int32_t kAdjust0dBLevel = (-32) << 26; //0x80000000
static const int32_t kAdjust0dBLevel = INT32_MIN; // 0x80000000

static inline int32_t SaturatingInt64(int64_t value)
{
	if(value > INT32_MAX) return INT32_MAX;
	if(value < INT32_MIN) return INT32_MIN;
	return (int32_t)value;
}

static inline int32_t SaturatingScale(int64_t value, unsigned int shift)
{
	return SaturatingInt64(value * ((int64_t)1 << shift));
}

static inline int32_t SaturatingDouble(double value)
{
	if(!isfinite(value)) return 0;
	if(value > (double)INT32_MAX) return INT32_MAX;
	if(value < (double)INT32_MIN) return INT32_MIN;
	return (int32_t)value;
}

static inline int32_t MagnitudeSample(double i, double q)
{
	return SaturatingDouble(hypot(i, q));
}

static inline int32_t DemodulatedSample(double iz1, double iz0, double iz_1,
	double qz1, double qz0, double qz_1)
{
	const double denominator = hypot(iz1, qz1);
	if(denominator <= 1.0)
		return 0;
	return SaturatingDouble((((qz1 - qz_1) * iz0) - ((iz1 - iz_1) * qz0)) /
		denominator);
}


static const int kLog2Table[kLog2TableSize] =
{
	0x00000000, 0x00000000, 0x04000000, 0x06570068, 0x08000000, 0x0949a780, 0x0a570070, 0x0b3abb40,
	0x0c000000, 0x0cae00d0, 0x0d49a780, 0x0dd67540, 0x0e570070, 0x0ecd4010, 0x0f3abb40, 0x0fa0a7f0,
	0x10000000, 0x10598fe0, 0x10ae00e0, 0x10fde0c0, 0x1149a780, 0x1191bba0, 0x11d67540, 0x121820a0,
	0x12570060, 0x12934f00, 0x12cd4020, 0x13050140, 0x133abb40, 0x136e92a0, 0x13a0a7e0, 0x13d118e0,
	0x14000000, 0x142d75a0, 0x14598fe0, 0x148462c0, 0x14ae00e0, 0x14d67b00, 0x14fde0c0, 0x15244080,
	0x1549a780, 0x156e2220, 0x1591bba0, 0x15b47ec0, 0x15d67540, 0x15f7a860, 0x161820a0, 0x1637e620,
	0x16570060, 0x16757680, 0x16934f00, 0x16b09040, 0x16cd4020, 0x16e96400, 0x17050140, 0x17201cc0,
	0x173abb40, 0x1754e120, 0x176e92a0, 0x1787d3a0, 0x17a0a7e0, 0x17b91340, 0x17d118e0, 0x17e8bc20,
	0x18000000, 0x1816e7a0, 0x182d75a0, 0x1843ace0, 0x18598fe0, 0x186f2100, 0x188462c0, 0x18995740,
	0x18ae00e0, 0x18c26160, 0x18d67b00, 0x18ea4f80, 0x18fde0c0, 0x19113080, 0x19244080, 0x19371240,
	0x1949a780, 0x195c01a0, 0x196e2220, 0x19800a60, 0x1991bba0, 0x19a33760, 0x19b47ec0, 0x19c59300,
	0x19d67540, 0x19e726a0, 0x19f7a860, 0x1a07fb60, 0x1a1820a0, 0x1a281940, 0x1a37e620, 0x1a478840,
	0x1a570060, 0x1a664f80, 0x1a757680, 0x1a847600, 0x1a934f00, 0x1aa20240, 0x1ab09040, 0x1abefa00,
	0x1acd4020, 0x1adb6320, 0x1ae96400, 0x1af74320, 0x1b050140, 0x1b129ee0, 0x1b201cc0, 0x1b2d7b60,
	0x1b3abb40, 0x1b47dd00, 0x1b54e120, 0x1b61c820, 0x1b6e92a0, 0x1b7b40e0, 0x1b87d3a0, 0x1b944b20,
	0x1ba0a7e0, 0x1bacea80, 0x1bb91340, 0x1bc52280, 0x1bd118e0, 0x1bdcf680, 0x1be8bc20, 0x1bf469c0,
	0x1c000000, 0x1c0b7f20, 0x1c16e7a0, 0x1c2239a0, 0x1c2d75a0, 0x1c389c00, 0x1c43ace0, 0x1c4ea8c0,
	0x1c598fe0, 0x1c646280, 0x1c6f2100, 0x1c79cbc0, 0x1c8462c0, 0x1c8ee680, 0x1c995740, 0x1ca3b540,
	0x1cae00e0, 0x1cb83a20, 0x1cc26160, 0x1ccc76e0, 0x1cd67b00, 0x1ce06dc0, 0x1cea4f80, 0x1cf42060,
	0x1cfde0c0, 0x1d0790a0, 0x1d113080, 0x1d1ac060, 0x1d244080, 0x1d2db100, 0x1d371240, 0x1d406460,
	0x1d49a780, 0x1d52dbe0, 0x1d5c01a0, 0x1d651900, 0x1d6e2220, 0x1d771d20, 0x1d800a60, 0x1d88e9c0,
	0x1d91bba0, 0x1d9a8020, 0x1da33760, 0x1dabe180, 0x1db47ec0, 0x1dbd0f20, 0x1dc59300, 0x1dce0a40,
	0x1dd67540, 0x1dded400, 0x1de726a0, 0x1def6d60, 0x1df7a860, 0x1dffd7a0, 0x1e07fb60, 0x1e1013a0,
	0x1e1820a0, 0x1e202280, 0x1e281940, 0x1e300520, 0x1e37e620, 0x1e3fbc80, 0x1e478840, 0x1e4f4980,
	0x1e570060, 0x1e5ead00, 0x1e664f80, 0x1e6de800, 0x1e757680, 0x1e7cfb20, 0x1e847600, 0x1e8be760,
	0x1e934f00, 0x1e9aad40, 0x1ea20240, 0x1ea94de0, 0x1eb09040, 0x1eb7c9a0, 0x1ebefa00, 0x1ec62180,
	0x1ecd4020, 0x1ed45600, 0x1edb6320, 0x1ee267e0, 0x1ee96400, 0x1ef057c0, 0x1ef74320, 0x1efe2640,
	0x1f050140, 0x1f0bd420, 0x1f129ee0, 0x1f1961c0, 0x1f201cc0, 0x1f26cfe0, 0x1f2d7b60, 0x1f341f20,
	0x1f3abb40, 0x1f414fe0, 0x1f47dd00, 0x1f4e62c0, 0x1f54e120, 0x1f5b5840, 0x1f61c820, 0x1f6830e0,
	0x1f6e92a0, 0x1f74ed40, 0x1f7b40e0, 0x1f818da0, 0x1f87d3a0, 0x1f8e12c0, 0x1f944b20, 0x1f9a7ce0,
	0x1fa0a7e0, 0x1fa6cc80, 0x1facea80, 0x1fb30200, 0x1fb91340, 0x1fbf1e00, 0x1fc52280, 0x1fcb20c0,
	0x1fd118e0, 0x1fd70ac0, 0x1fdcf680, 0x1fe2dc60, 0x1fe8bc20, 0x1fee95e0, 0x1ff469c0, 0x1ffa37c0
};

inline int log2Int(uint x)
{
	int y; //=0;
	if(x < kLog2TableSize)
	{
		y = kLog2Table[x];
	}
	else // if(x < 160000* kLog2TableSize)
	{
		// Built-in Function: int __builtin_clz (unsigned int x)
		// Returns the number of leading 0-bits in x, starting at the most significant bit position. If x is 0, the result is undefined.
		int shiftArg = __builtin_clz(x);
		shiftArg = (32 - kLog2TableLog2Size) - shiftArg;
		y = (shiftArg<<26) + kLog2Table[x>>shiftArg];
	}

	return y;
}


#if defined __arm__
inline int mul32_16b(int32_t x, int32_t y) { int32_t z; asm volatile("smulwb %0, %1, %2" : "=r"(z) : "r"(x), "r"(y)); return z; }
inline int mul32_16t(int32_t x, int32_t y) { int32_t z; asm volatile("smulwt %0, %1, %2" : "=r"(z) : "r"(x), "r"(y)); return z; }
inline int32_t SquareMag(int32_t re, int32_t im)
{
	register int32_t z;
	asm volatile("smultt %0, %1, %2" : "=r"(z) : "r"(re), "r"(re));
	asm volatile("smlatt %0, %1, %2, %3" : "=r"(z) : "r"(im), "r"(im), "0"(z));
	return z;
}
#else
#define mul32_16b(a,b) ((int32_t)(((int64_t)(a) * (int64_t)((b) & 0x0000ffff))>>16))
#define mul32_16t(a,b) ((int32_t)(((int64_t)(a) * (int64_t)(((b) & 0xffff0000)>>16))>>16))
inline int32_t SquareMag(int32_t re, int32_t im)
{
	const int64_t scaledRe = re >> 16;
	const int64_t scaledIm = im >> 16;
	return SaturatingInt64(scaledRe * scaledRe + scaledIm * scaledIm);
}
#endif

struct SPECTRUM_ANALYSIS
{
	std::mutex			stateMutex;
	int32_t				chunk_size_frames;
	int32_t				FFT_size_frames;
	int32_t				window_step_size_frames;
	int32_t				FFT_zero_padding_bytes;
	int16_t*			weightingWindow;
	Int32Cplx*			fftBuffer;
	Int32Cplx*			audiohold;
	Int32Cplx*			scratchPad; // temporary storage for calculations
	int32_t*			SprectrumData;
	PackedInt16Cplx*	twiddleFactors;
	PackedInt16Cplx*	invtwiddleFactors; // TODO: this simple iFFT wastes space - fix later
	FloatCplx*			BPFKernelTable;
	BOOL				bpfEnabled;
	int					audiochannels;
	BOOL				reverseIQ;
	float				BPFcenterfrequency;
	float				BPFbandwidth;
	int					BPFkernelsize;
	int					samplerate;
	iSDROperatingMode	sidebandMode;
	int					spectrumMagnitudeShift;
	float				signalScaleFactor;
	double				demodIZ1, demodIZ0, demodIZ_1;
	double				demodQZ1, demodQZ0, demodQZ_1;
};


H_SPECTRUM_ANALYSIS SpectrumAnalysisCreate(int32_t chunksize, int audiochannels)
{
	if(audiochannels != 1 && audiochannels != 2)
		return NULL;

	H_SPECTRUM_ANALYSIS p = new (std::nothrow) SPECTRUM_ANALYSIS();

	if(p)
	{
		p->chunk_size_frames = chunksize; // this is how many raw audio frames are sent in each call
		p->spectrumMagnitudeShift = 1;
		p->signalScaleFactor = 0.;

		switch (chunksize)
		{
			case 4096:
			case 2048:
			case 1024:
			case 512:
			case 256:
			case 128:
			case 64:
				p->window_step_size_frames = DSP_CHUNKSIZE_FRAMES;
				p->FFT_size_frames = 2*DSP_CHUNKSIZE_FRAMES;
//				p->FFT_size_frames = 2048;
				p->FFT_zero_padding_bytes = AUDIO_FRAME_SIZE_BYTES*(p->FFT_size_frames - p->window_step_size_frames);
				break;
			default:
				SDR_DEBUGPRINT(("Error: Unsupported audio data chunk size!\n"));
				delete p;
				return(NULL);
				break;
		}

		p->weightingWindow = (int16_t*)malloc(sizeof(int16_t)*p->FFT_size_frames);
		p->fftBuffer = (Int32Cplx*)calloc(p->FFT_size_frames, sizeof(Int32Cplx));
		p->audiohold = (Int32Cplx*)calloc(p->FFT_size_frames, sizeof(Int32Cplx));
		p->scratchPad = (Int32Cplx*)malloc(sizeof(Int32Cplx)*p->FFT_size_frames);
		p->SprectrumData = (int32_t *)malloc(sizeof(int32_t)*p->FFT_size_frames);

		p->twiddleFactors = CreatePackedTwiddleFactors(p->FFT_size_frames, FALSE);
		p->invtwiddleFactors = CreatePackedTwiddleFactors(p->FFT_size_frames, TRUE);
		if(p->weightingWindow == NULL || p->fftBuffer == NULL || p->audiohold == NULL ||
			p->scratchPad == NULL || p->SprectrumData == NULL ||
			p->twiddleFactors == NULL || p->invtwiddleFactors == NULL)
		{
			SpectrumAnalysisDestroy(p);
			return NULL;
		}

		for(int i = 0; i < p->window_step_size_frames/2; ++i)
		{
			/* Hamming window */
			float w = 0.53836-0.46164*cosf(2.0*M_PI*i/(float)(p->window_step_size_frames-1));
			p->weightingWindow[i] = (int16_t)(powf(2.0, 15.0)*w);
			p->weightingWindow[p->window_step_size_frames-i-1] = p->weightingWindow[i];
		}

		// create BPF and convert it to frequency domain
		/* int size, int pad2length, float samplefrequency, float centerFrequency, float bandwidth */
//		p->BPFKernelTable = CreateBPFKernel(1025, p->FFT_size_frames, 44100.0, 1400.0, 2600.0);
//		Radix2FloatCplxFFT(p->BPFKernelTable, p->FFT_size_frames, p->twiddleFactors, 1);
//		p->BPFcenterfrequency = 1400.0;
//		p->BPFbandwidth = 2600.0;
//		p->BPFkernelsize = 1025;
//		p->samplerate = 44100.0;
		// TODO: it shouldn't be necessary to create the BPF yet. Wait until Rx is initialized
		if(!CreateBPF(p, 44100.0, 1025, 1400.0, 2600.0))
		{
			SpectrumAnalysisDestroy(p);
			return NULL;
		}

		p->bpfEnabled = FALSE;
		p->audiochannels = audiochannels;
		p->reverseIQ = FALSE;
		p->sidebandMode = USB_mode;
	}
	return p;
}

void SpectrumAnalysisDestroy(H_SPECTRUM_ANALYSIS p)
{
	if(p)
	{
		if(p->weightingWindow) free(p->weightingWindow);
		if(p->fftBuffer) free(p->fftBuffer);
		if(p->SprectrumData) free(p->SprectrumData);
		if(p->audiohold) free(p->audiohold);
		if(p->scratchPad) free(p->scratchPad);

		DisposePackedTwiddleFactors(p->twiddleFactors);
		DisposePackedTwiddleFactors(p->invtwiddleFactors);
		DisposeFilterKernel(p->BPFKernelTable);
		delete p;
	}
}


void ConfigureBPF(H_SPECTRUM_ANALYSIS p, float BPFcenterFrequency, float BPFbandwidth)
{
	if(p)
	{
		if(BPFbandwidth > 0.0)
		{
			float samplerate;
			int kernelSize;
			{
				std::lock_guard<std::mutex> lock(p->stateMutex);
				samplerate = p->samplerate;
				kernelSize = p->BPFkernelsize;
			}
			const BOOL created = CreateBPF(p, samplerate, kernelSize,
				BPFcenterFrequency, BPFbandwidth);
			std::lock_guard<std::mutex> lock(p->stateMutex);
			p->bpfEnabled = created;
		}
		else
		{
			std::lock_guard<std::mutex> lock(p->stateMutex);
			p->bpfEnabled = FALSE;
		}
	}
}


BOOL CreateBPF(H_SPECTRUM_ANALYSIS p, float samplerate, int BPFkernelsize, float BPFcenterFrequency, float BPFbandwidth)
{
	if(p == NULL)
		return FALSE;

	FloatCplx *newKernel = CreateBPFKernel(BPFkernelsize, p->FFT_size_frames,
		samplerate, BPFcenterFrequency, BPFbandwidth);
	if(newKernel == NULL)
		return FALSE;

	Radix2FloatCplxFFT(newKernel, p->FFT_size_frames, p->twiddleFactors, 1);
	std::lock_guard<std::mutex> lock(p->stateMutex);
	DisposeFilterKernel(p->BPFKernelTable);
	p->BPFKernelTable = newKernel;
	p->BPFcenterfrequency = BPFcenterFrequency;
	p->BPFbandwidth = BPFbandwidth;
	p->BPFkernelsize = BPFkernelsize;
	p->samplerate = samplerate;
	return TRUE;
}

void SpectrumAnalysisProcess(H_SPECTRUM_ANALYSIS p, int32_t* inTimeSigRe, int32_t* inTimeSigIm, int32_t* OutTimeSigRe, int32_t* OutTimeSigIm, float centerFrequency, BOOL domag)
{
	if(p)
	{
		std::lock_guard<std::mutex> lock(p->stateMutex);
		int gainval = 8, postGainval = 10;

#ifdef DO_WEIGHTING_WINDOW
		for(int i = 0; i < p->window_step_size_frames; i += 2)
		{
			int32_t dualCoef = *((int32_t*)(p->weightingWindow + i));
			p->fftBuffer[i].real   = SaturatingScale(mul32_16b(SaturatingScale(inTimeSigRe[i], 7), dualCoef), 1);
			p->fftBuffer[i].imag   = SaturatingScale(mul32_16b(SaturatingScale(inTimeSigIm[i], 7), dualCoef), 1);
			p->fftBuffer[i+1].real = SaturatingScale(mul32_16t(SaturatingScale(inTimeSigRe[i+1], 7), dualCoef), 1);
			p->fftBuffer[i+1].imag = SaturatingScale(mul32_16t(SaturatingScale(inTimeSigIm[i+1], 7), dualCoef), 1);
		}
#else
		if(p->audiochannels == 2)
		{
			if(p->reverseIQ)
			{
				for(int i = 0; i < p->window_step_size_frames; i++)
				{
					p->fftBuffer[i].real   = SaturatingScale(inTimeSigIm[i], gainval);
					p->fftBuffer[i].imag   = SaturatingScale(inTimeSigRe[i], gainval);
				}
			}
			else
			{
				for(int i = 0; i < p->window_step_size_frames; i++)
				{
					p->fftBuffer[i].real   = SaturatingScale(inTimeSigRe[i], gainval);
					p->fftBuffer[i].imag   = SaturatingScale(inTimeSigIm[i], gainval);
				}
			}
		}
		else if(p->audiochannels == 1)
		{
			for(int i = 0; i < p->window_step_size_frames; i++)
			{
				p->fftBuffer[i].real   = SaturatingScale(inTimeSigRe[i], gainval);
				p->fftBuffer[i].imag   = 0;
			}
		}

#endif

		// Pad with zeroes
		if(p->FFT_zero_padding_bytes)
		{
			memset(&p->fftBuffer[p->window_step_size_frames], 0, p->FFT_zero_padding_bytes);
		}

		// FFT
		Radix2IntCplxFFT(p->fftBuffer, p->FFT_size_frames, p->twiddleFactors, 1);

		//calculate magnitude spectrum for display
		if(domag) MagSpectrumCplx32(p); // ->fftBuffer, p->SprectrumData, p->FFT_size_frames, p->audiochannels, p->spectrumMagnitudeShift);
		// if(dophase) (p->fftBuffer, p->outSpectrumIm, p->FFT_size_frames);


#ifndef	DISABLE_SPECTRUM_SHIFT
		//shift spectrum of interest to DC
		ShiftSpectrum(p, centerFrequency);
#endif //DISABLE_SPECTRUM_SHIFT

#ifndef DISABLE_BPF
		// Multiply here by frequency domain filter kernel table
		if(p->bpfEnabled)
		{
			for(int i=0; i<p->FFT_size_frames; i++)
			{
				CplxMul32FloatCplx(p->fftBuffer[i],p->BPFKernelTable[i]);
			}
		}
#endif //DISABLE_BPF


		// iFFT
		Radix2IntCplxFFT(p->fftBuffer, p->FFT_size_frames, p->invtwiddleFactors, 1);

		int stepsize = p->window_step_size_frames;
		if(p->FFT_zero_padding_bytes)
		{
			if(p->audiochannels == 2)
			{
				if(p->sidebandMode == AM_mode)
				{
					double ii, qq;

					for(int i=0; i < stepsize; i++)
					{
						ii = SaturatingScale((int64_t)p->fftBuffer[i].real + p->audiohold[i].real, gainval);
						qq = SaturatingScale((int64_t)p->fftBuffer[i].imag + p->audiohold[i].imag, gainval);

						*(OutTimeSigRe + i)	= MagnitudeSample(ii, qq);
						*(OutTimeSigIm + i)	= *(OutTimeSigRe + i);
						p->audiohold[i] = p->fftBuffer[i+stepsize];
					}
				}
				else if(p->sidebandMode == NFM_mode)
				{
					for(int i=0; i < stepsize; i++)
					{
						p->demodIZ_1 = p->demodIZ0;
						p->demodIZ0 = p->demodIZ1;
						p->demodIZ1 = SaturatingScale((int64_t)p->fftBuffer[i].real + p->audiohold[i].real, gainval);

						p->demodQZ_1 = p->demodQZ0;
						p->demodQZ0 = p->demodQZ1;
						p->demodQZ1 = SaturatingScale((int64_t)p->fftBuffer[i].imag + p->audiohold[i].imag, gainval);

						*(OutTimeSigIm + i)	= *(OutTimeSigRe + i) = DemodulatedSample(
							p->demodIZ1, p->demodIZ0, p->demodIZ_1,
							p->demodQZ1, p->demodQZ0, p->demodQZ_1);

						p->audiohold[i] = p->fftBuffer[i+stepsize];
					}
				}
				else
				{
					for(int i=0; i < stepsize; i++)
					{
						*(OutTimeSigRe + i)	= SaturatingScale((int64_t)p->fftBuffer[i].real + p->audiohold[i].real, postGainval);
						*(OutTimeSigIm + i)	= SaturatingScale((int64_t)p->fftBuffer[i].imag + p->audiohold[i].imag, postGainval);
						p->audiohold[i] = p->fftBuffer[i+stepsize];
					}
				}

			}
			else
			{
				if(p->sidebandMode == AM_mode)
				{
					for(int i=0; i < stepsize; i++)
					{
						*(OutTimeSigRe + i)	= *(OutTimeSigIm + i) = MagnitudeSample(
							SaturatingScale((int64_t)p->fftBuffer[i].real + p->audiohold[i].real, gainval), 0.0);
						p->audiohold[i] = p->fftBuffer[i+stepsize];
					}
				}
				else if(p->sidebandMode == NFM_mode)
				{
					for(int i=0; i < stepsize; i++)
					{
						p->demodIZ_1 = p->demodIZ0;
						p->demodIZ0 = p->demodIZ1;
						p->demodIZ1 = SaturatingScale((int64_t)p->fftBuffer[i].real + p->audiohold[i].real, gainval);

						p->demodQZ_1 = p->demodQZ0;
						p->demodQZ0 = p->demodQZ1;
						p->demodQZ1 = SaturatingScale((int64_t)p->fftBuffer[i].imag + p->audiohold[i].imag, gainval);

						*(OutTimeSigIm + i)	= *(OutTimeSigRe + i) = DemodulatedSample(
							p->demodIZ1, p->demodIZ0, p->demodIZ_1,
							p->demodQZ1, p->demodQZ0, p->demodQZ_1);

						p->audiohold[i] = p->fftBuffer[i+stepsize];
					}
				}
				else
				{
					for(int i=0; i < stepsize; i++)
					{
						*(OutTimeSigRe + i)	= *(OutTimeSigIm + i) = SaturatingScale(
							(int64_t)p->fftBuffer[i].real + p->audiohold[i].real, postGainval);
						p->audiohold[i] = p->fftBuffer[i+stepsize];
					}
				}
			}
		}
		else
		{
			if(p->audiochannels == 2)
			{
				if(p->sidebandMode == AM_mode)
				{
					double ii, qq;

					for(int i=0; i < stepsize; i++)
					{
						ii = SaturatingScale(p->fftBuffer[i].real, gainval);
						qq = SaturatingScale(p->fftBuffer[i].imag, gainval);

						*(OutTimeSigRe + i)	= MagnitudeSample(ii, qq);
						*(OutTimeSigIm + i)	= *(OutTimeSigRe + i);
					}
				}
				else if(p->sidebandMode == NFM_mode)
				{
					for(int i=0; i < stepsize; i++)
					{
						p->demodIZ_1 = p->demodIZ0;
						p->demodIZ0 = p->demodIZ1;
						p->demodIZ1 = SaturatingScale(p->fftBuffer[i].real, gainval);

						p->demodQZ_1 = p->demodQZ0;
						p->demodQZ0 = p->demodQZ1;
						p->demodQZ1 = SaturatingScale(p->fftBuffer[i].imag, gainval);

						*(OutTimeSigIm + i)	= *(OutTimeSigRe + i) = DemodulatedSample(
							p->demodIZ1, p->demodIZ0, p->demodIZ_1,
							p->demodQZ1, p->demodQZ0, p->demodQZ_1);
					}
				}
				else
				{
					for(int i=0; i < stepsize; i++)
					{
						*(OutTimeSigRe + i)	= SaturatingScale(p->fftBuffer[i].real, postGainval);
						*(OutTimeSigIm + i)	= SaturatingScale(p->fftBuffer[i].imag, postGainval);
					}
				}
			}
			else
			{
				if(p->sidebandMode == AM_mode)
				{
					for(int i=0; i < stepsize; i++)
					{
						*(OutTimeSigRe + i)	= *(OutTimeSigIm + i) = MagnitudeSample(
							SaturatingScale(p->fftBuffer[i].real, gainval), 0.0);
					}
				}
				else if(p->sidebandMode == NFM_mode)
				{
					for(int i=0; i < stepsize; i++)
					{
						p->demodIZ_1 = p->demodIZ0;
						p->demodIZ0 = p->demodIZ1;
						p->demodIZ1 = SaturatingScale(p->fftBuffer[i].real, gainval);

						p->demodQZ_1 = p->demodQZ0;
						p->demodQZ0 = p->demodQZ1;
						p->demodQZ1 = SaturatingScale(p->fftBuffer[i].imag, gainval);

						*(OutTimeSigIm + i)	= *(OutTimeSigRe + i) = DemodulatedSample(
							p->demodIZ1, p->demodIZ0, p->demodIZ_1,
							p->demodQZ1, p->demodQZ0, p->demodQZ_1);

						p->audiohold[i] = p->fftBuffer[i+stepsize];
					}
				}
				else
				{
					for(int i=0; i < stepsize; i++)
					{
						*(OutTimeSigRe + i)	= *(OutTimeSigIm + i) = SaturatingScale(
							p->fftBuffer[i].real, postGainval);
					}
				}
			}
		}

	}
}


int32_t* GetSpectrumBuffer(H_SPECTRUM_ANALYSIS p)
{
	return(p->SprectrumData);
}


int32_t GetSpectrumBufferSize(H_SPECTRUM_ANALYSIS p)
{
	std::lock_guard<std::mutex> lock(p->stateMutex);
	if(p->audiochannels == 2)
		return(p->FFT_size_frames);
	else
		return(p->FFT_size_frames / 2);
}


void BPFonoff(H_SPECTRUM_ANALYSIS p, BOOL command)
{
	std::lock_guard<std::mutex> lock(p->stateMutex);
	p->bpfEnabled = command;
}


void ReverseIQ(H_SPECTRUM_ANALYSIS p, BOOL command)
{
	std::lock_guard<std::mutex> lock(p->stateMutex);
	p->reverseIQ = command;
}


void setSidebandMode(H_SPECTRUM_ANALYSIS p, iSDROperatingMode mode)
{
	std::lock_guard<std::mutex> lock(p->stateMutex);
	p->sidebandMode = mode;
}


void setNumberOfAudioChannels(H_SPECTRUM_ANALYSIS p, int audiochannels)
{
	if(audiochannels != 1 && audiochannels != 2)
		return;
	std::lock_guard<std::mutex> lock(p->stateMutex);
	p->audiochannels = audiochannels;
}


void setSpectrumMagShift(H_SPECTRUM_ANALYSIS p, int spectrumMagnitudeShift)
{
	std::lock_guard<std::mutex> lock(p->stateMutex);
	p->spectrumMagnitudeShift = spectrumMagnitudeShift;
}


void setSignalScaling(H_SPECTRUM_ANALYSIS p, float signalScaling)
{
	std::lock_guard<std::mutex> lock(p->stateMutex);
	p->signalScaleFactor = signalScaling;
}


void MagSpectrumCplx32(H_SPECTRUM_ANALYSIS p)
{
	int32_t hold;
	Int32Cplx* inBuffer = p->fftBuffer;
	int32_t* outMag = p->SprectrumData;
	int size = p->FFT_size_frames;
	int audiochannels = p->audiochannels;
	int spectrumMagnitudeShift = p->spectrumMagnitudeShift;
	float scaling = 1. + 24.*p->signalScaleFactor;
	int32_t holdLast = 0;
	int32_t temp;

	if(audiochannels == 2)
	{
		//copy negative frequencies to the left
		for(int j=0, i=size/2; i<size; j++,i++)
		{
			outMag[j] = kAdjust0dBLevel;
			if(((hold = scaling*SquareMag(inBuffer[i].real, inBuffer[i].imag))))
			{
				temp = SaturatingScale(hold, spectrumMagnitudeShift);
				outMag[j] = SaturatingInt64((int64_t)outMag[j] +
					log2Int((uint)SaturatingInt64((int64_t)temp + holdLast)));
				holdLast = temp;
//				outMag[j] += log2Int(hold<<spectrumMagnitudeShift);
			}

			outMag[j] = SaturatingScale(mul32_16b(outMag[j], kLog2ToLog10ScaleFactor), 1);
		}

		holdLast = 0;
		//copy positive frequencies to the right
		for(int j=size/2, i=0; i<size/2; j++,i++)
		{
			outMag[j] = kAdjust0dBLevel;
			if((hold = scaling*SquareMag(inBuffer[i].real, inBuffer[i].imag)))
			{
				temp = SaturatingScale(hold, spectrumMagnitudeShift);
				outMag[j] = SaturatingInt64((int64_t)outMag[j] +
					log2Int((uint)SaturatingInt64((int64_t)temp + holdLast)));
				holdLast = temp;
//				outMag[j] += log2Int(hold<<spectrumMagnitudeShift);
			}

			outMag[j] = SaturatingScale(mul32_16b(outMag[j], kLog2ToLog10ScaleFactor), 1);
		}
	}
	else
	{
		if(p->reverseIQ)
		{
			//copy negative frequencies to the left
			for(int j=0, i=size/2; i<size; j++,i++)
			{
				outMag[j] = kAdjust0dBLevel;
				if((hold = scaling*SquareMag(inBuffer[i].real, inBuffer[i].imag)))
				{
					temp = SaturatingScale(hold, spectrumMagnitudeShift);
					outMag[j] = SaturatingInt64((int64_t)outMag[j] +
						log2Int((uint)SaturatingInt64((int64_t)temp + holdLast)));
					holdLast = temp;
//					outMag[j] += log2Int(hold<<spectrumMagnitudeShift);
				}

				outMag[j] = SaturatingScale(mul32_16b(outMag[j], kLog2ToLog10ScaleFactor), 1);
			}
		}
		else
		{
			//copy positive frequencies to the left
			for(int j=0, i=0; i<size/2; j++,i++)
			{
				outMag[j] = kAdjust0dBLevel;
				if ((hold = scaling*SquareMag(inBuffer[i].real, inBuffer[i].imag)))
				{
					temp = SaturatingScale(hold, spectrumMagnitudeShift);
					outMag[j] = SaturatingInt64((int64_t)outMag[j] +
						log2Int((uint)SaturatingInt64((int64_t)temp + holdLast)));
					holdLast = temp;
//					outMag[j] += log2Int(hold<<spectrumMagnitudeShift);
				}

				outMag[j] = SaturatingScale(mul32_16b(outMag[j], kLog2ToLog10ScaleFactor), 1);
			}

		}
	}

	return;
}

#ifdef DONOTINCLUDE
void PhaseSpectrumCplx32(Int32Cplx* inBuffer, int32_t* outPhase, int size)
{
	float hold;

	//copy negative frequencies to the left
	for (int j=0, i=size/2; i<size; j++,i++) {
		hold = 1000 * atan2f(inBuffer[i].imag, inBuffer[i].real );
		outPhase[j] = (int32_t)hold;
	}

	//copy positive frequencies to the right
	for (int j=size/2, i=0; i<size/2; j++,i++) {
		hold = 1000 * atan2f( inBuffer[i].imag, inBuffer[i].real );
		outPhase[j] = (int32_t)hold;
	}

	return;
}
#endif

/*
 * Shift is provided in fraction of total bandwidth [0 : 1];
 */
void ShiftSpectrum(H_SPECTRUM_ANALYSIS p, float shift) // Int32Cplx* ioCplxData, int size, modulationFormat sideband, float bandwidth, float shift )
{
	int binshift;
	int bins;

	if(p->audiochannels == 2)
	{
		if(shift > 0.5)
			shift -= 0.5;
		else
			shift += 0.5;
	}
	else
	{
		shift /= 2.;
		if(p->reverseIQ) shift += 0.5;
	}

	bins = p->FFT_size_frames;
	binshift = (shift * bins);

	if(binshift == 0) return; // no need to shift
	if(p->FFT_zero_padding_bytes && (binshift % 2)) binshift--; // padding introduces artifacts in odd bins, so avoid them

	switch (p->sidebandMode)
	{
		case USB_mode:
		case CW_mode:
		{
			int i,j,halfbins=bins/2;
			for(j=binshift,i=0; i<halfbins; j++,i++)
			{
				if(j>bins-1) j=0;
				*(p->scratchPad+i) = *(p->fftBuffer+j); // shift buffer data into storage
			}

			memcpy(p->fftBuffer, p->scratchPad, sizeof(Int32Cplx)*halfbins);

			memset(p->fftBuffer+i, 0, sizeof(Int32Cplx)*halfbins );
		}
			break;

		case LSB_mode:
		{
			int i,j,halfbins=bins/2;
			for(j=binshift-1,i=bins-1; i>=halfbins; j--,i--)
			{
				if(j<0) j = bins-1;
				*(p->scratchPad+i) = *(p->fftBuffer+j); // shift buffer data into storage
			}

			memcpy(p->fftBuffer+halfbins, p->scratchPad+halfbins, sizeof(Int32Cplx)*halfbins);

			memset(p->fftBuffer, 0, sizeof(Int32Cplx)*halfbins );
		}
			break;

//		case AM_mode:
//		case NFM_mode:
		default:
		{
			int i,j;
			for(j=binshift,i=0; i<bins; j++,i++)
			{
				if(j==bins) j=0;

				*(p->scratchPad+i) = *(p->fftBuffer+j); // shift buffer data into storage
			}
			memcpy(p->fftBuffer, p->scratchPad, sizeof(Int32Cplx)*bins);

		}
			break;
	}

	return;
}
