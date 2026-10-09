/*
 *  product.h
 *  iSDR
 *

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

 *
 */

#ifndef __PRODUCT_H__
#define __PRODUCT_H__

#import "MacTypes.h"
#if !defined(__COREAUDIO_USE_FLAT_INCLUDES__)
#include <CoreAudio/CoreAudioTypes.h>
#include <CoreFoundation/CoreFoundation.h>
#else
#include "CoreAudioTypes.h"
#include "CoreFoundation.h"
#endif

/*
 *  System Versioning Preprocessor Macros
 */

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

#ifndef BOOL
/// Type to represent a boolean value.
#if !defined(OBJC_HIDE_64) && TARGET_OS_IPHONE && __LP64__
typedef bool BOOL;
#else
typedef signed char BOOL;
// BOOL is explicitly signed so @encode(BOOL) == "c" rather than "C"
// even if -funsigned-char is used.
#endif
#endif

///////////////////////////////////////////////////////////////////////////////////////////
// Debug and Beta Flags
// Define "ISDR_BETA_BUILD" to enable an expiration date
//#define ISDR_BETA_BUILD TRUE

#ifdef ISDR_BETA_BUILD
// Date format: "yyyy-MM-ddTHH:mm:ssZ"
#define EXPIRATION_DATE (@"2016-01-01T00:00:00Z")
#endif

///////////////////////////////////////////////////////////////////////////////////////////
// Debug and Beta Flags
// Define "SDR_DEBUG" to enable all non-Wi-Fi debug prints
// #define SDR_DEBUG

#ifndef   SDR_DEBUG
#define   SDR_DEBUGPRINT(arg)
#else
#define   SDR_DEBUGPRINT(arg)     (printf arg)
#endif

///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
// Define "WIFI_DEBUG" to enable all Wi-Fi debug prints
//#define WIFI_DEBUG

#ifndef   WIFI_DEBUG
#define   WIFI_DEBUGPRINT(arg)
#else
//#define TEST_WITHOUT_PIGLET
#define   WIFI_DEBUGPRINT(arg)     (printf arg)
#endif

#define DEFAULT_IP_ADDRESS (@"10.1.1.1")
#define UP TRUE
#define DOWN FALSE
#define MINIMUM_SETTABLE_RADIO_FREQUENCY_KHZ (50.)
#define MAXIMUM_SETTABLE_RADIO_FREQUENCY_KHZ (1500000.)
#define FREQUENCY_STEP_SIZE_KHZ (2.)
#define MINIMUM_WIFI_MESSAGE_INTERVAL_S (0.1)

#define MIN_PORT_VALUE (0)
#define MAX_PORT_VALUE (65535)
#define DEFAULT_COMMAND_PORT (7373)
#define DEFAULT_DATA_PORT (7374)

#define PROGRAMMATIC_DISMISS_BUTTON 100

///////////////////////////////////////////////////////////////////////////////////////////
// In-App Store
// Place with your product ids and related text here
//
#define STORE_ITEMS (@[@"ISDR_INAPP_WIFI"])
#define STORE_ITEM_NAMES (@[@"Wi-Fi Radio Control Option"])
#define STORE_ITEM_IMAGES ([NSArray arrayWithObjects:[UIImage imageNamed:@"wifi connected.png"], nil])
//
#define STORE_ITEM0_SUPPORT_WEBSITE (@"http://wifi.digitalconfections.com")
#define STORE_ITEM0_DESCRIPTIVE_TEXT ([NSString stringWithFormat:@"Provides %@ the ability to connect with a Wi-Fi radio control interface to wirelessly control the frequency setting of a compatible radio. NOTICE: Additional hardware is required. See support web site before purchasing.\nDetails: l^%@^l.", appName, STORE_ITEM0_SUPPORT_WEBSITE])
#define STORE_ITEMS_DESCRIPTIVE_TEXT (@[STORE_ITEM0_DESCRIPTIVE_TEXT])
//
// Set USE_MINIMAL_PURCHASE_RETENTION to TRUE if you want removing the app to also reset purchase flags
#define USE_MINIMAL_PURCHASE_RETENTION TRUE
//
///////////////////////////////////////////////////////////////////////////////////////////

#define	  DEFAULT_AUDIO_FILE_NAME (@"sample40m.caf")
//#define	  DEFAULT_AUDIO_FILE_EXTENSION (@"caf")

//#define RETINA_DISPLAY_GL_SUPPORT
//#define ENABLE_VIDEO_OUT
//#define printA(S) {}

// Audio file definitions for demo mode
#define MAXBUFS 1
#define NUMFILES 1

#ifndef CLAMP
#define CLAMP(min,x,max) (x < min ? min : (x > max ? max : x))
#endif

#ifndef MIN
#define MIN(a,b)      ((a<b) ? a : b)
#endif

#ifndef MAX
#define MAX(a,b)      ((a>b) ? a : b)
#endif

////////////////////////////////////////////
/* FOOBAR - changes for iOS 8 audio havoc */
typedef SInt32 AUDIO_UNIT_SAMPLE_TYPE;
typedef SInt16 AUDIO_SAMPLE_TYPE;
#define    AUDIO_FORMAT_FLAGS_CANONICAL (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked)
/* FOOBAR - changes for iOS 8 audio havoc */
////////////////////////////////////////////


// Product configuration settings
#define DISABLE_HPF

// Hardware information
//#define IPOD_DISPLAY_PORTRAIT_HEIGHT	((size_t)480)
//#define IPOD_DISPLAY_PORTRAIT_WIDTH		((size_t)320)
//#define IPOD_DISPLAY_LANDSCAPE_HEIGHT	((size_t)320)
//#define IPOD_DISPLAY_LANDSCAPE_WIDTH	((size_t)480)
#define IPOD_STATUSBAR_HEIGHT			((size_t)0)
//#define IPOD_SIGNAL_GRID_HEIGHT			((size_t)140)
//#define IPOD_SIGNAL_GRID_WIDTH			((size_t)480)

#define IPOD_RETINA_SIGNAL_GRID_HEIGHT			((size_t)140)
#define IPOD_RETINA_SIGNAL_GRID_WIDTH			((size_t)480)

//#define IPAD_DISPLAY_PORTRAIT_HEIGHT	((size_t)1024)
//#define IPAD_DISPLAY_PORTRAIT_WIDTH		((size_t)768)
//#define IPAD_DISPLAY_LANDSCAPE_HEIGHT	((size_t)768)
//#define IPAD_DISPLAY_LANDSCAPE_WIDTH	((size_t)1024)
#define IPAD_STATUSBAR_HEIGHT			((size_t)20)
//#define IPAD_SIGNAL_GRID_HEIGHT			((size_t)492)
//#define IPAD_SIGNAL_GRID_WIDTH			((size_t)1024)

//#define IPAD_RETINA_DISPLAY_PORTRAIT_HEIGHT		((size_t)2048)
//#define IPAD_RETINA_DISPLAY_PORTRAIT_WIDTH		((size_t)1536)
//#define IPAD_RETINA_DISPLAY_LANDSCAPE_HEIGHT	((size_t)1536)
//#define IPAD_RETINA_DISPLAY_LANDSCAPE_WIDTH		((size_t)2048)
//#define IPAD_RETINA_STATUSBAR_HEIGHT			((size_t)40)
//#define IPAD_RETINA_SIGNAL_GRID_HEIGHT			((size_t)984)
//#define IPAD_RETINA_SIGNAL_GRID_WIDTH			((size_t)2048)

#define IPAD_POPOVER_MENU_WIDTH			((size_t)520)
#define IPAD_POPOVER_MENU_HEIGHT		((size_t)390)
#define IPAD_POPOVER_HEIGHT				(IPAD_POPOVER_MENU_HEIGHT)
#define IPAD_POPOVER_MENU_WIDTH_FOR_FREQUENCY_ENTRY			((size_t)520)
#define IPAD_POPOVER_MENU_HEIGHT_FOR_FREQUENCY_ENTRY		((size_t)150)
#define IPAD_POPOVER_MENU_HEIGHT_FOR_ABOUT_PAGE ((size_t)560)
#define IPAD_POPOVER_MENU_WIDTH_FOR_ABOUT_PAGE ((size_t)750)

#define FILE_INFO_BANNER_HEIGHT			((size_t)15)

#define AUDIO_FRAME_SIZE_BYTES (sizeof(int32_t))
#define MAX_DATA_PER_RENDER_BYTES (288*AUDIO_FRAME_SIZE_BYTES)

#define AUDIO_SAMPLE_RATE (44100.)
#define MAX_AUDIO_AMPLITUDE (4000000)
#define MIN_AUDIO_AMPLITUDE (MAX_AUDIO_AMPLITUDE/8)
#define MID_AUDIO_AMPLITUDE ((MAX_AUDIO_AMPLITUDE + MIN_AUDIO_AMPLITUDE) >> 1)
#define INITIAL_SCALE_FACTOR (0.5)

// The number of FFT_SIZE regions that the circular buffer can hold
// Caution: To avoid poor audio, the buffer size needs to align to an integral number of
//          frames-to-render calls. For iPhone and iPod touch the frames are 256 per render
//          call. For iPad with USB microphone it is 288 frames per render call.
#define NUMBER_OF_BUFFER_SEGMENTS		9

// The number of buffered bytes that get sent to DSP processing at a time (must be a power of two)
#define DSP_CHUNKSIZE_FRAMES	1024
#define DSP_CHUNKSIZE_BYTES		((int32_t)(DSP_CHUNKSIZE_FRAMES * AUDIO_FRAME_SIZE_BYTES))
// Sets the window overlap. Should generally be 75%, 50%, 25% or 0% of DSP_CHUNKSIZE_FRAMES
#define SEGMENT_STEPSIZE_FRAMES	1024
#define SEGMENT_STEPSIZE_BYTES	((int32_t)(SEGMENT_STEPSIZE_FRAMES * AUDIO_FRAME_SIZE_BYTES))
//#define	SEGMENT_OVERLAP_FRAMES	(DSP_CHUNKSIZE_FRAMES - SEGMENT_STEPSIZE_FRAMES)
//#define SEGMENT_OVERLAP_BYTES	((int32_t)(SEGMENT_OVERLAP_FRAMES * AUDIO_FRAME_SIZE_BYTES))

#define NUMBER_OF_S_METER_LIGHT_SEGMENTS 13


// for general screen placement in table views
#define kLeftMargin				20.0
#define kTopMargin				20.0
#define kRightMargin			20.0
#define kTweenMargin			10.0
#define kTextFieldWidth			260.0
#define kTextFieldHeight		30.0

#define TUNEBARTOP_IPAD			105 // top row of rainbow tune bar in pixels
#define TUNEBARTOP				83  // top row of rainbow tune bar in pixels

#define max(a,b) ((a) > (b) ? (a) : (b))
#define min(a,b) ((a) > (b) ? (b) : (a))

typedef enum lockStates
{
	UNLOCKED = 0,
	LOCKED = 1
} LockState;

//typedef enum
//{
//	UnknownModel,
//	iPhone3GS,
//	iPhone4,
//	iPhone4s,
//	iPhone5,
//	iPhone5s,
//	iPhone6,
//	iPhone6plus,
//	iPodTouch3,
//	iPodTouch4,
//	iPodTouch5,
//	iPad1,
//	iPad2,
//	iPad3,
//	iPadMini,
//	numberOfModels
//} AppleModel;

typedef double frequencyType;

typedef	enum iSDROperatingMode
{
	USB_mode,
	LSB_mode,
	CW_mode,
	AM_mode,
	NFM_mode,
	Binaural_mode
} iSDROperatingMode;

typedef struct settings *DefaultSettings;

typedef enum AGCSetting
{
	AGC_OFF,
	AGC_SLOW,
	AGC_FAST
} AGCSetting;

typedef enum gridType
{
	Linear,
	SemiLog
} GridType;

//typedef enum hardwarePlatforms
//{
//	IPod_Hardware,
//	IPad_Hardware
//} HardwarePlatformType;


typedef enum displayHardware
{
	iPad_Display,
	Retina_Display,
	NonRetina_Display
} DisplayHardwareType;

typedef enum displayOrientation
{
	Portrait,
	PortraitButtonTop,
	Landscape,
	LandscapeButtonLeft,
	AutoRotate
} DisplayOrientation;

typedef struct settings
{
	DisplayOrientation			displayOrientation;

	int						hardwarePlatform;
	int						displayHardware;
    frequencyType			centerFrequency;
	BOOL					demoModeOnly;
	BOOL					reverseIQ;
	iSDROperatingMode		operatingMode;
	frequencyType			bpfBandwidth;
	frequencyType			rxOffset;
	AGCSetting				agcSetting;
	float					gridBrightness;
	BOOL					simpleTouchMode;
	GridType				gridType;
	float					signalScaleFactor;
	BOOL					soundEffectsEnabled;
	BOOL					playWhileMinimized;
	BOOL					hasShownIntroductionText;
	BOOL					wifiFunctionalityEnabled;
	BOOL					wifiFunctionalityPurchased;
///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
	BOOL					hasSuccessfullyConnectedViaWifi;
	BOOL					reversePlusMinus;
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////
} DefaultSettingsType;

typedef enum TTimerCommand {
	CancelTimer,
	StartTimer,
	FireTimer
} TTimerCommand;

#define MIN_CENTER_FREQUENCY ((frequencyType)-100.0)
#define MAX_CENTER_FREQUENCY ((frequencyType)450000.0)
#define MIN_RX_OFFSET ((frequencyType)500.0)
#define MAX_RX_OFFSET ((frequencyType)1000.0)
#define DEFAULT_CENTER_FREQUENCY ((frequencyType)7200.0)
#define MIN_BPF_BANDWIDTH ((frequencyType)100.0)
#define MAX_BPF_BANDWIDTH ((frequencyType)6000.0)
#define DEFAULT_BPF_BANDWIDTH ((frequencyType)3000.0)
#define DEFAULT_RX_OFFSET ((frequencyType)0.0)
#define DEFAULT_OPERATING_MODE (LSB_mode)
#define DEFAULT_DEMOMODE_ONLY (YES)
#define DEFAULT_REVERSE_IQ (NO)
#define DEFAULT_AGC_SETTING (AGC_SLOW)
//#define CW_OFFSET ((frequencyType)750.0)


#define PI ((double)3.14159265)


#endif
