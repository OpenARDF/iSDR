/*
 Third-party provenance: portions of this file are derived from Apple's
 Core Audio Utility Classes sample code.

 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

    File: CAMath.h
Abstract: Helper class for various math functions
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

#ifndef __CAMath_h__
#define __CAMath_h__

#if !defined(__COREAUDIO_USE_FLAT_INCLUDES__)
	#include <CoreAudio/CoreAudioTypes.h>
#else
	#include <CoreAudioTypes.h>
#endif

inline bool fiszero(Float64 f) { return (f == 0.); }
inline bool fiszero(Float32 f) { return (f == 0.f); }

inline bool fnonzero(Float64 f) { return !fiszero(f); }
inline bool fnonzero(Float32 f) { return !fiszero(f); }

inline bool fequal(const Float64 &a, const Float64 &b) { return a == b; }
inline bool fequal(const Float32 &a, const Float32 &b) { return a == b; }

inline bool fnotequal(const Float64 &a, const Float64 &b) { return !fequal(a, b); }
inline bool fnotequal(const Float32 &a, const Float32 &b) { return !fequal(a, b); }

#endif // __CAMath_h__
