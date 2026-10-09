/*

    File: SpectrumAnalysis.h
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

#if !defined __SPECTRUM_ANALYSIS_H__
#define __SPECTRUM_ANALYSIS_H__

#import <sys/types.h>
#import <stdbool.h>

#import "product.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Forward declarations
 */
struct SPECTRUM_ANALYSIS;
typedef struct SPECTRUM_ANALYSIS* H_SPECTRUM_ANALYSIS;



/*
 * Create a SpectrumAnalysis object. The block size argument must be a power of 2
 */
H_SPECTRUM_ANALYSIS SpectrumAnalysisCreate(int32_t chunksize, int audiochannels);


/*
 * Dispose SpectrumAnalysis object
 */
void SpectrumAnalysisDestroy(H_SPECTRUM_ANALYSIS p);

/*
 * Allows an external object to get a pointer to the array holding mag spectrum results
 */
int32_t* GetSpectrumBuffer(H_SPECTRUM_ANALYSIS p);

/*
 * Allows an external object to get the size of the mag spectrum result array
 */
int32_t GetSpectrumBufferSize(H_SPECTRUM_ANALYSIS p);

/*
 * Shift the spectrum bins of an Int32Cplx spectrum table
 */
	void ShiftSpectrum(H_SPECTRUM_ANALYSIS p, float shift);

/*
 * Setter for enabling/disabling the band pass filter
 */
	void BPFonoff(H_SPECTRUM_ANALYSIS p, BOOL command);


/*
 * Setter for reversing Inverse and Quadrature line logic
 */
	void ReverseIQ(H_SPECTRUM_ANALYSIS p, BOOL command);


/*
 * Setter for setting sideband operating mode
 */
	void setSidebandMode(H_SPECTRUM_ANALYSIS p, iSDROperatingMode mode);


/*
 * Setter for setting sideband operating mode
 */
	void setNumberOfAudioChannels(H_SPECTRUM_ANALYSIS p, int audiochannels);


/*
 * Setter for magnitude shift to boost FFT magnitude display
 */
	void setSpectrumMagShift(H_SPECTRUM_ANALYSIS p, int spectrumMagnitudeShift);


/*
 * Setter for scaling of FFT magnitude display
 */
	void setSignalScaling(H_SPECTRUM_ANALYSIS p, float signalScaling);


/*
 * Calculates new BPF settings
 */
	void ConfigureBPF(H_SPECTRUM_ANALYSIS p, float BPFcenterFrequency, float BPFbandwidth);

/*
 * Creates new bandpass frequency-domain filter
 */
	BOOL CreateBPF(H_SPECTRUM_ANALYSIS p, float samplerate, int BPFkernelsize, float BPFcenterFrequency, float BPFbandwidth);

/*
 *
 * Inputs:
 *		p:				an opaque SpectrumAnalysis object handle
 *		inTimeSig:		pointer to a time signal of the same length as specified in SpectrumAnalysisCreate()
 *		outMagSpectrum:	pointer to a magnitude spectrum. Its length must at least be size/2
 *		in_dB:			flag indicating wether the magnitude spectrum should be calculated in dB
 *
 * Discussion:
 *
 * the real valued time signal is first weighted with a Hamming window of the same size and then transformed
 * in the frequency domain. The squared magnitudes of the resulting complex spectrum are copied into the
 * outMagSpectrum vector and then converted to dB if so requested. Since the input signal is real, the magnitude
 * spectrum is only half the size (note that the Nyquist term is discarded) as the input signal.
 *
 * Value ranges:
 *
 * the input signal is expected to be in a Q7.24 format in the range [-1, 1) which means that the integer parts should be zero
 * the ouput magnitude spectrum is in Q7.24 format with a range of [-128, 0) when calculated in dB.
 */
void SpectrumAnalysisProcess(H_SPECTRUM_ANALYSIS p, int32_t* inTimeSigRe, int32_t* inTimeSigIm, int32_t* OutTimeSigRe, int32_t* OutTimeSigIm, float centerFrequency, BOOL domag);

#ifdef __cplusplus
}
#endif

#endif
