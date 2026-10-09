/*
 Third-party provenance: portions of this file are derived from Apple's
 Core Audio Utility Classes sample code.

 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

    File: CAXException.h
Abstract: Helper class for excpetion handling
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


#ifndef __CAXException_h__
#define __CAXException_h__

#if !defined(__COREAUDIO_USE_FLAT_INCLUDES__)
	#include <CoreFoundation/CoreFoundation.h>
#else
	#include <ConditionalMacros.h>
	#include <CoreFoundation.h>
#endif
#include "CADebugMacros.h"
#include <ctype.h>
#include <stdio.h>
#include <string.h>

class CAX4CCString {
public:
	CAX4CCString(OSStatus error) {
		// see if it appears to be a 4-char-code
		char *str = mStr;
		*(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
		if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
			str[0] = str[5] = '\'';
			str[6] = '\0';
		} else if (error > -200000 && error < 200000) {
			// no, format it as an integer
			snprintf(str, sizeof(mStr), "%d", (int)error);
		} else {
			snprintf(str, sizeof(mStr), "0x%x", (int)error);
		}
	}
	const char *get() const { return mStr; }
	operator const char *() const { return mStr; }
private:
	char mStr[16];
};

// An extended exception class that includes the name of the failed operation
class CAXException {
public:
	CAXException(const char *operation, OSStatus err) :
		mError(err)
		{
			if (operation == NULL)
				mOperation[0] = '\0';
			else if (strlen(operation) >= sizeof(mOperation)) {
				memcpy(mOperation, operation, sizeof(mOperation) - 1);
				mOperation[sizeof(mOperation) - 1] = '\0';
			} else
				strcpy(mOperation, operation);
		}

	char *FormatError(char *str) const
	{
		return FormatError(str, mError);
	}

	char				mOperation[256];
	const OSStatus		mError;

	// -------------------------------------------------

	typedef void (*WarningHandler)(const char *msg, OSStatus err);

	static char *FormatError(char *str, OSStatus error)
	{
		strcpy(str, CAX4CCString(error));
		return str;
	}

	static void Warning(const char *s, OSStatus error)
	{
		if (sWarningHandler)
			(*sWarningHandler)(s, error);
	}

	static void SetWarningHandler(WarningHandler f) { sWarningHandler = f; }
private:
	static WarningHandler	sWarningHandler;
};

#if	DEBUG || CoreAudio_Debug
	#define XThrowIfError(error, operation) \
		do {																	\
			OSStatus __err = error;												\
			if (__err) {															\
				DebugMessageN2("about to throw %s: %s", CAX4CCString(error).get(), operation);\
				STOP;															\
				throw CAXException(operation, __err);		\
			}																	\
		} while (0)

	#define XThrowIf(condition, error, operation) \
		do {																	\
			if (condition) {													\
				OSStatus __err = error;											\
				DebugMessageN2("about to throw %s: %s", CAX4CCString(error).get(), operation);\
				STOP;															\
				throw CAXException(operation, __err);		\
			}																	\
		} while (0)

	#define XRequireNoError(error, label) \
		do { \
			OSStatus __err = error; \
			if (__err) { \
				DebugMessageN2("about to throw %s: %s", CAX4CCString(error).get(), #error);\
				STOP;															\
				goto label; \
			} \
		} while (0)

	#define XAssert(assertion) \
		do { \
			if (!(assertion)) { \
				DebugMessageN1("error: failed assertion: %s", #assertion);\
				STOP;															\
			} \
		} while (0)

	#define XAssertNoError(error) \
		do { \
			OSStatus __err = error; \
			if (__err) { \
				DebugMessageN2("error %s: %s", CAX4CCString(error).get(), #error);\
				STOP;															\
			} \
		} while (0)

#else
	#define XThrowIfError(error, operation) \
		do {																	\
			OSStatus __err = error;												\
			if (__err) {															\
				throw CAXException(operation, __err);		\
			}																	\
		} while (0)

	#define XThrowIf(condition, error, operation) \
		do {																	\
			if (condition) {													\
				OSStatus __err = error;											\
				throw CAXException(operation, __err);		\
			}																	\
		} while (0)

	#define XRequireNoError(error, label) \
		do {																	\
			OSStatus __err = error;												\
			if (__err) {															\
				goto label;		\
			}																	\
		} while (0)

	#define XAssert(assertion) \
		do {																	\
		} while (0)

	#define XAssertNoError(error) \
		do {																	\
			/*OSStatus __err =*/ error;												\
		} while (0)
#endif

#define XThrow(error, operation) XThrowIf(TRUE, error, operation)
#define XThrowIfErr(error) XThrowIfError(error, #error)

#endif // __CAXException_h__
