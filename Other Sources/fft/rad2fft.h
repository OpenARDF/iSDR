/*

    File: rad2fft.h
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

#ifndef __RAD2_FFT_H__
#define __RAD2_FFT_H__

#ifdef __cplusplus
extern "C" {
#endif

#import <stdlib.h>
#import <stdio.h>
#import <string.h>
#import <math.h>
#import <stdbool.h>
#import <stdbool.h>
#import "SpectrumAnalysis.h"
#import <sys/types.h>
#import "product.h"

typedef enum modulationFormat {
	CW,
	USB,
	LSB,
	WFM,
	NFM
} modulationFormat;


/*
 * Struct for holding a 32 bit integer complex numbers
 */
struct Int32Cplx
{
	int real;
	int imag;
};
typedef struct Int32Cplx Int32Cplx;


/*
 * Struct for holding float complex numbers
 */
struct FloatCplx
{
	float real;
	float imag;
};
typedef struct FloatCplx FloatCplx;


/*
 * Packed complex type. The upper 16 bits correspond to the real part,
 * the lower 16 bit to imaginary part
 */
// This value is a bit container, not a signed arithmetic value. Keeping it
// unsigned makes the shifts used to pack and unpack Q15 components defined.
typedef uint32_t PackedInt16Cplx;


/*
 * Create a lookup table with "size" twiddle factors for the FFT.
 */
PackedInt16Cplx* CreatePackedTwiddleFactors(int size, int doinverse);
Int32Cplx* CreateIntTwiddleFactors(int size, int doinverse);
FloatCplx* CreateFloatTwiddleFactors(int size, int doinverse);


/*
 * Create a complex array of frequency domain FIR filter kernel
 */
FloatCplx* CreateBPFKernel(int size, int pad2length, float samplefrequency, float centerFrequency, float bandwidth);


/*
 * Dispose of the filter kernel table
 */
void DisposeFilterKernel(FloatCplx* filterKernel);


/*
 * Dispose the twiddle factor table
 */
void DisposePackedTwiddleFactors(PackedInt16Cplx* cosSinTable);

/*
 * Dispose the twiddle factor table
 */
void DisposeIntTwiddleFactors(Int32Cplx* cosSinTable);


/*
 * Inplace complex radix 2 FFT. The complex data vector must have the specified size and must be a power of 2.
 */
void Radix2IntCplxFFT(Int32Cplx* ioCplxData, int size, const PackedInt16Cplx* twiddleFactors, int twiddleFactorsStrides);
//	void Radix2IntCplxFFT(Int32Cplx* ioCplxData, int size, const Int32Cplx* twiddleFactors, int twiddleFactorsStrides);


/*
 * Inplace complex radix 2 FFT. The complex data vector must have the specified size and must be a power of 2.
 */
	void Radix2FloatCplxFFT(FloatCplx* ioCplxData, int size, const PackedInt16Cplx* twiddleFactors, int twiddleFactorsStrides);
//	void Radix2FloatCplxFFT(FloatCplx* ioCplxData, int size, const Int32Cplx* twiddleFactors, int twiddleFactorsStrides);


#ifdef __cplusplus
	}
#endif

#endif
