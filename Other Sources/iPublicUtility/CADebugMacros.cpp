/*
 Third-party provenance: portions of this file are derived from Apple's
 Core Audio Utility Classes sample code.

 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

    File: CADebugMacros.cpp
Abstract: Helper class for printing debug messages
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

 Copyright (c) 2011 Charles Scharlau - NZ0I. Licensed under the MIT License.


*/

#include "CADebugMacros.h"
#include <stdio.h>
#include <stdarg.h>
#if TARGET_API_MAC_OSX
	#include <syslog.h>
#endif

#if DEBUG
#include <stdio.h>

void	DebugPrint(const char *fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	vprintf(fmt, args);
	va_end(args);
}
#endif // DEBUG

#if TARGET_API_MAC_OSX
void	LogError(const char *fmt, ...)
{
	va_list args;
	va_start(args, fmt);
#if DEBUG
	vprintf(fmt, args);
#endif
	vsyslog(LOG_ERR, fmt, args);
	va_end(args);
}

void	LogWarning(const char *fmt, ...)
{
	va_list args;
	va_start(args, fmt);
#if DEBUG
	vprintf(fmt, args);
#endif
	vsyslog(LOG_WARNING, fmt, args);
	va_end(args);
}
#endif
