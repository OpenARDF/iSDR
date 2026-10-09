/*
 Third-party provenance: portions of this file are derived from Apple's
 aurioTouch/aurioTouch2 sample code.

 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


//
//  EAGLViewController.h
//  iSDR
//
//  This software is provided by OpenARDF on an "AS IS" basis.
//  OPENARDF MAKES NO WARRANTIES, EXPRESS OR IMPLIED,
//  INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
//  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE
//  SOFTWARE OR ITS USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
//
//  IN NO EVENT SHALL OPENARDF BE LIABLE FOR ANY SPECIAL,
//  INDIRECT, INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
//  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
//  PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE,
//  REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE OPENARDF SOFTWARE,
//  HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
//  STRICT LIABILITY OR OTHERWISE, EVEN IF OPENARDF HAS BEEN
//  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.
//

#ifndef __EAGLVIEWCONTROLLER_H__
#define __EAGLVIEWCONTROLLER_H__

//#ifdef __cplusplus
//extern "C" {
//#endif

#import <UIKit/UIKit.h>
#import <AvailabilityInternal.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <libkern/OSAtomic.h>
#import <CoreFoundation/CFURL.h>

#import "product.h"
#import "PreferencesViewController.h"
#import "EAGLView.h"
#import "iSDRAppDelegate.h"
#import "MultichannelMixerController.h"

#import "AULevelMeter.h"
#import "DITableViewController.h"

#import "BigSwitch.h"
#import "LockButton.h"
#import "WifiButton.h"

///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
#import "PlusMinusButton.h"
//#import "StoreViewController.h"

typedef enum windowBehaviorModes
{
	WindowMuted, // "switch off"
	SignalWindowLockMode,
	FrequencyWindowLockMode
} WindowBehavior;

#import "WifiInterface.h"
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////

#define SPECTRUM_BAR_WIDTH 35

typedef enum buttonState
{
	buttonsUnknown,
	buttonsTurnOn, // unhide, unlock, and draw all buttons
	buttonsHide,   // hide (undraw) bottons that lie on top of tune bar
	buttonsLock,   // draw only the lock button and a gray tune bar
	buttonsRedraw, // redraw the buttons without changing states
	buttonsRedrawWithCenterFrequency, // same as buttonsRedraw except that the center frequency text replaces the on/off switch
	buttonsAllOff  // erase all button and tune bar overlays
}buttonState;

typedef enum displayConfigurationAction
{
	reInitializeAudioSettings,
	fatalAudioErrorDeviceLost,
	fatalAudioErrorUnknownCause
}displayConfigurationAction;

typedef enum stepMode
{
	modulationSetting,
	bandwidthSetting
} StepMode;

typedef struct SpectrumLinkedTexture
{
	GLuint							texName;
	struct SpectrumLinkedTexture	*nextTex;
} SpectrumLinkedTexture;

inline double linearInterp(double valA, double valB, double fract)
{
	return valA + ((valB - valA) * fract);
}

///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
typedef enum alertCatagories
{
	FatalError,
	BetaPeriodExpired,
	IPAddressError,
	WifiConnectionFailedError,
	WifiNotReadyAlert,
	EnableWifiOnAppPrompt,
	EnableWifiOnDevicePrompt,
	CancelWifiSearchPrompt,
	DisableWifiPrompt,
	WifiConnectedToOtherDeviceWarning,
	PortValuesChanged,
	OldIOSVersion,
	ConnectionLostReconnectPrompt,
	EnterTCPCommandPortPrompt
} AlertCategory;

typedef enum ipValidationResults
{
	AddressIsOK,
	BetterCandidateFound,
	CandidateDiffersFromConnected,
	CandidateIsConnected,
	NoGoodCandidateFound
} IpCheckResult;
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////

@class OverlayView;

@interface EAGLViewController : UIViewController <EAGLViewDelegate, UIApplicationDelegate, PreferencesViewControllerDelegate, MultichannelMixerControllerDelegate, DITableViewControllerDelegate, UIPopoverPresentationControllerDelegate, WifiInterfaceListener, WifiCenterFrequencyListener, WifiStateListener, BigSwitchDelegate, PlusMinusButtonDelegate, WifiButtonDelegate, LockButtonDelegate, UITextFieldDelegate, WifiRadioInfoListener>
{
	EAGLView*					eaglView;
	DefaultSettingsType			defaultsWorkingCopy;
	UINavigationController*		navigationController;
	MultichannelMixerController*	mixerController;
	iSDRAppDelegate*			__weak appDelegate;

///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
	WifiInterface*				wifi;
	NSMutableString*			activeIPAddress; // selected IP address for testing and connecting
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////

	AULevelMeter*				rssiMeter;
	CGRect						meterRect;

	CGRect						topLeftRect;
	CGRect						topRightRect;

	OverlayView*				frequencyOverlayLandscape;

	UIImageView*				doubleArrowOverlayLandscape;

	UIImageView*				cursorLandscapeOverlayOS;
	UIImageView*				cursorLandscapeOverlayWF;
	UIImageView*				tuneBarLandscapeOverlayWF;
	UIImageView*				tuneBarLandscapeOverlayGrayWF;
	UIImageView*				tuneBarLandscapeOverlayOS;
	UIImageView*				tuneBarLandscapeOverlayGrayOS;
	UIImageView*				meterNumberingOverlay;
	UIImageView*				agcOffOverlayLandscape;
	UIImageView*				agcSlowOverlayLandscape;
	UIImageView*				agcFastOverlayLandscape;
	UIImageView*				semiLogGridOverlay;
	UIImageView*				linearGridOverlay;
	UIImageView*				signalScopeGridOverlay;

	///////////////////////////////////////////////////////////////////////////////////////////
	// Wifi support changes
    PlusMinusButton*			plusButton;  // increment center frequency
    PlusMinusButton*			minusButton; // decrement center frequency
	WifiButton*					wifiButton;  // control wifi behavior
	UILabel*					centerFrequencyText;
	UILabel*					ipAddressText;
	WindowBehavior				windowBehavior; // How center frequency UI should behave
	UILabel*					frequencyTextLandscape;
	// Wifi support changes
	///////////////////////////////////////////////////////////////////////////////////////////

	SInt32*						fftData;
	NSUInteger					fftLength;
	BOOL						hasNewFFTData;

	BOOL						initted_oscilloscope, initted_spectrum;
	BOOL						displayInitialized;
	UInt32*						texBitBuffer;
	UInt32						texBitBufferSize;
	CGRect						spectrumRect;

	UIButton*					infoButton;
	BigSwitch*					switchCtl;
	LockButton*					lockButton;

	NSTimer*					countdownTimer;

	CGRect						gridRectangle;

	UInt16						displayPortraitHeight;
	UInt16						displayPortraitWidth;
	UInt16						displayLandscapeHeight;
	UInt16						displayLandscapeWidth;
	UInt16						displayStatusBarHeight;

	UInt16						gridHeight;
	UInt16						gridWidth;
	UInt16						oscopeMaxSignalHeight;
	UInt16						oscopeSignalOffset;
	UInt16						fftSignalOffset;

	UInt16						tunebarTopRow;
	UInt16						tunebarHeight;

	UInt16						gridBottomRow;
	UInt16						meterTopRow;

	UInt16						tunebarWaterfallColumn;
	UInt16						tunebarVertHeightOffset;
	UInt16						waterfallStepSize;
	UInt16						oscopeCursorVerticalRow;
	UInt16						waterfallCursorHorizontalCenterColumn;

	iSDRDisplayMode				displayMode;

	BOOL						noisefilter;
	BOOL						buttonsAreOn;
	BOOL						screenIsLocked;

	CGRect						tuneBarWFRectangle;
	CGRect						tuneBarOSRectangle;
	CGRect						gridRectangleWF;

	CGRect						cursorRectangleOS;
	UInt16						cursorWidthOS;
	UInt16						cursorHeightOS;

	SInt16						cursorHeightOStweak;
	SInt16						cursorRowOStweak;
	SInt16						signalTraceOStweak;

	CGRect						cursorRectangleWF;
	UInt16						cursorWidthWF;
	UInt16						cursorHeightWF;

	CGRect						freqOverlayRectangle;

	UILabel*					fileInfoTextLandscape;

	float						sampleRateBandwidthHz;
	float						sampleRateBandwidthKHz;

	SpectrumLinkedTexture*		firstTex;
	SpectrumLinkedTexture*		lastTex;

	CGFloat						lastPinchDist;
	NSTimeInterval				viewRefreshRate;

	UIEvent*					twoTouchFrequencyEvent;
	UIEvent*					slideFrequencyEvent;
	UIEvent*					simpleTouchFrequencyEvent;
	CGFloat						slideFrequencyStartLoc;
	frequencyType				preTouchFrequencySetting;
	frequencyType				preFirstTapFrequencySetting;
	UITouch*					__weak slidingTouch;
	UITouch*					__weak baseTouch;
	NSInteger					cursorTapCount;
	BOOL						touchWithoutFrequencyOverlay;
	BOOL						secondTapWithoutFrequencyOverlay;

	AURenderCallbackStruct		inputProc;

	int32_t*					l_SprectrumData;
	int32_t						l_SprectrumDataSize;

	GLfloat*					oscilLine;
	BOOL						resetOscilLine;
	BOOL						savedAnimationState;

	CFStringRef					audioFilePath;

	PreferencesViewController*	prefViewController;

	CGFloat						_freqOverlayFrameCenterRow;
	CGFloat						_frequencyOverlayWidth;
	CGFloat						_frequencyOverlayHeight;
	CGFloat						_frequencyOverlayBorderOffset;

	BOOL						runningInBackground;

	UIPopoverPresentationController*    iSDRpopoverController;
	BOOL						_popoverActive;

	BOOL						hideStatusBar;
}

@property (nonatomic, strong)	EAGLView*				eaglView;
@property (nonatomic, weak)	iSDRAppDelegate*		appDelegate;

	///////////////////////////////////////////////////////////////////////////////////////////
	// Wifi support changes
@property (nonatomic, strong)	PlusMinusButton*		plusButton;
@property (nonatomic, strong)	PlusMinusButton*		minusButton;
@property (nonatomic, strong)	WifiButton*				wifiButton;
@property (nonatomic, strong)	UILabel*				centerFrequencyText;
@property (nonatomic, strong)	UILabel*				ipAddressText;
@property (nonatomic, strong)	NSMutableString*		activeIPAddress; // selected IP address for testing and connecting
@property (nonatomic, readwrite) WindowBehavior			windowBehavior;
	// Wifi support changes
	///////////////////////////////////////////////////////////////////////////////////////////

@property (nonatomic, strong)	AULevelMeter*			rssiMeter;

@property (nonatomic, weak)	UITouch*				baseTouch;
@property (nonatomic, weak)	UITouch*				slidingTouch;

@property (nonatomic, strong)	UIImageView*			cursorLandscapeOverlayOS;
@property (nonatomic, strong)	UIImageView*			cursorLandscapeOverlayWF;
@property (nonatomic, strong)	UIImageView*			tuneBarLandscapeOverlayWF;
@property (nonatomic, strong)	UIImageView*			tuneBarLandscapeOverlayGrayWF;
@property (nonatomic, strong)	UIImageView*			tuneBarLandscapeOverlayOS;
@property (nonatomic, strong)	UIImageView*			tuneBarLandscapeOverlayGrayOS;
@property (nonatomic, strong)	UIImageView*			meterNumberingOverlay;
@property (nonatomic, strong)	UIImageView*			agcOffOverlayLandscape;
@property (nonatomic, strong)	UIImageView*			agcSlowOverlayLandscape;
@property (nonatomic, strong)	UIImageView*			agcFastOverlayLandscape;
@property (nonatomic, strong)	UIImageView*			semiLogGridOverlay;
@property (nonatomic, strong)	UIImageView*			linearGridOverlay;
@property (nonatomic, strong)	UIImageView*			signalScopeGridOverlay;


@property (nonatomic, strong)	PreferencesViewController*	prefViewController;
@property (nonatomic) BOOL		hideStatusBar;

@property (nonatomic, strong)	UIButton*				infoButton;
@property (nonatomic, strong)	BigSwitch*				switchCtl;
@property (nonatomic, strong)	LockButton*				lockButton;

@property (nonatomic, strong)	UIPopoverPresentationController*    iSDRpopoverController;

@property (nonatomic, strong)	IBOutlet UINavigationController* navigationController;

@property (strong)				MultichannelMixerController*	mixerController;

@property (assign)				iSDRDisplayMode			displayMode;
@property (nonatomic, assign)	NSTimeInterval			viewRefreshRate;

@property (nonatomic, assign)	CGRect					tuneBarWFRectangle;
@property (nonatomic, assign)	CGRect					tuneBarOSRectangle;
@property (nonatomic, assign)	CGRect					gridRectangleWF;
@property (nonatomic, assign)	CGRect					gridRectangle;

@property (nonatomic, assign)	CGRect					cursorRectangleWF;
@property (nonatomic, assign)	UInt16					cursorWidthWF;
@property (nonatomic, assign)	UInt16					cursorHeightWF;
@property (nonatomic, assign)	CGRect					cursorRectangleOS;
@property (nonatomic, assign)	UInt16					cursorWidthOS;
@property (nonatomic, assign)	UInt16					cursorHeightOS;
@property (nonatomic, assign)	CGRect					freqOverlayRectangle;

@property (nonatomic, assign)	BOOL					buttonsAreOn;
@property (nonatomic, assign)	BOOL					noisefilter;
@property (nonatomic, assign)	AURenderCallbackStruct	inputProc;
@property (nonatomic, assign)	float					sampleRateBandwidthHz;
@property (nonatomic, assign)	float					sampleRateBandwidthKHz;

@property (nonatomic, assign)	BOOL					savedAnimationState;
@property (nonatomic, assign)	BOOL					runningInBackground;

- (void)drawView;
- (void)drawViewWithAnimation;
- (void)setUpForDisplayMode:(iSDRDisplayMode)mode;
- (void)setupViewForOscilloscope;
- (BOOL)drawEnabled;
- (void)setFFTData:(int32_t *)FFTDATA length:(NSUInteger)LENGTH;
- (void)drawWaterfallSpectrum:(BOOL)drawData;
- (void)drawOscilloscope:(BOOL)drawLines;
- (void)readRawPCMOscope;
- (void)flipAction:(id)sender;
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0)
- (UIInterfaceOrientation)getInterfaceOrientation;
#endif
- (void)drawButtons:(buttonState)state;
- (void)getSavedSettings;
- (void)drawBandwidthOverlay:(UITouch*)touchLocation edgeReached:(BOOL)drawToEdge doErase:(BOOL)erase useFrequency:(frequencyType)freqToUse;
- (GLfloat)getHorizontalLocation:(UITouch*)touchLocation;
- (GLfloat)getVerticalLocation:(UITouch*)touchLocation;
- (void)drawFrequencyOverlay;
- (void)createBandwidthOverlays:(iSDROperatingMode)operatingMode;
- (void)initializeRadioSettings;
- (void)popFatalErrorMessage:(UInt32)reason;
- (void)setupDrawBuffers;
- (void)prepareForBackground;
- (void)returnFromBackground;
- (void)hideButtonCountdown:(TTimerCommand)command selector:(SEL)aSelector;
- (void)hideButtons;
- (void)turnOnButtons;
- (void)hideFreqOverlay;
- (void)reconfigureDisplaySetup:(UInt32)reason;
- (void)PrintDiagnostics:(iSDRAudioStatus)status inputAvail:(UInt32)audioInputAvailable numChans:(UInt32)CurrentHardwareInputNumberChannels sampleRate:(UInt32)sampleRateBandwidth maxfps:(UInt32)fps;
- (void)createButtons:(BOOL)initialize;
- (void)stepModeSetting:(stepMode)stepType;
- (NSString*) getFreqModeText;
#ifdef SDR_DEBUG
//- (void)PrintMessage:(char*)msg;
#endif
- (void)setupViewForSpectrum;
- (void)clearTextures;
- (void)refreshDisplay;

- (iSDROperatingMode)setNextOperatingMode:(iSDROperatingMode)currentMode;

- (void)createSemiLogGridOverlay:(BOOL)useSmallText;
- (void)createLinearGridOverlay;
- (void)createSignalScopeGridOverlay:(BOOL)useSmallText;

#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
- (void)createSemiLogGridOverlay_old:(BOOL)useSmallText;
- (void)createLinearGridOverlay_old;
- (void)createSignalScopeGridOverlay_old:(BOOL)useSmallText;
#endif

//PreferencesViewControllerDelegate
- (void)preferencesFinished;
- (void)applyRadioSettings:(BOOL)forceApply;
- (void)flushAudio;
- (void)renewDefaults;

//DITableViewController delegate
- (OSStatus)setFile:(NSURL *)fileURL;
- (NSURL *)getCurrentFileURL;
- (NSString*) getFileInfoText;
- (BOOL) getFilePlayActive;
- (void) setFilePlayActive:(BOOL)useFileAudio;

///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
+ (NSString*)frequencyString:(frequencyType)frequency;
- (frequencyType)stepCenterFrequency:(BOOL)direction;
- (void)alertUserOfPortChanges:(NSString*)dataPort commandPort:(NSString*)commandPort;
- (void)configureForWifi;
- (BOOL)establishWifiConnection;
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////

@end


@interface OverlayView : UIImageView
{
	BOOL doNotTimeout;
	BOOL isVisible;
}

@property (nonatomic) BOOL doNotTimeout;
@property (nonatomic) BOOL isVisible;


@end

//#ifdef __cplusplus
//	}
//#endif

#endif
