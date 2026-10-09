/*
 Third-party provenance: portions of this file are derived from Apple's
 aurioTouch/aurioTouch2 sample code.

 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


//
//  EAGLViewController.mm
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

#import "EAGLViewController.h"
#import "MultichannelMixerController.h"
#import "CAXException.h"
#import "PreferencesViewController.h"
#import <UIKit/UIDevice.h>
#import <AvailabilityInternal.h>
#import <UIKit/UIPopoverController.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CoreText/CoreText.h>
#include <atomic>

// This determines how slowly the oscilloscope lines fade away from the display.
// Larger numbers = slower fade (and more strain on the graphics processing)

#define kMaxNumDrawBuffers 4
#define kDefaultDrawSamples 256

#define kWaveformDrawSamples 2048
#define kWaveformDrawBuffers 1

#define kFFTDrawSamples 512
#define kFFTDrawBuffers 2

#define kFrequencyOverlayWidth_iPad 300
#define kFrequencyOverlayBorderOffset_iPad 300
#define kFrequencyOverlayWidth_iPod 200
#define kFrequencyOverlayBorderOffset_iPod 200

static SInt8 *drawBuffers[kMaxNumDrawBuffers];
static BOOL	drawBuffersInitialized = FALSE;
static SInt8 numDrawBuffers = kMaxNumDrawBuffers;

static int drawBufferIdx = 0;
static int drawBufferLen = kDefaultDrawSamples;
static DefaultSettingsType holdDefaults; // temporary storage area used for comparison to see if values changed

static const char* USB_mode_text = "USB";
static const char* LSB_mode_text = "LSB";
static const char* CW_mode_text = "CW";
static const char* AM_mode_text = "AM";
static const char* NFM_mode_text = "FM";
static const char* Binaural_mode_text = "Binaural";
static const char* modeText[] = {USB_mode_text, LSB_mode_text, CW_mode_text, AM_mode_text, NFM_mode_text, Binaural_mode_text};

@interface EAGLViewController (PrivateMethods)
- (void)sendRadio_AI2;
- (void)sendRadio_AI;
- (void)hideMPVolumeView;
@end

@implementation EAGLViewController
{
	FFTBufferManager*			fftBufferManager;

	UIAlertController*			wifiStateTranstionAlert;
	UIAlertController*			wifiDisabledOnDeviceAlert;
	UIAlertController*			wifiEnterNewIPAddress;
	UIAlertController*			wifiConnectionLostAlert;
	WifiState					holdWifiState;

	float						frequencyAtStartOfSlideEvent;
	float						totalSlideSinceStartOfSlideEvent;
	float						kHertzPerScreenElement;

	NSTimeInterval				autoInfoConfirmationTime;
	double						receiverFrequencyOffsetHz;
	NSMutableString*			receiverModeText;
	NSMutableString*			receiverModelText;
	double						iqOffsetFudgeFactorKHz;
	frequencyType				iqOffsetFudgeFactorNormalized;
	MPVolumeView*				systemVolumeView;
}


// value, a, b, g, r
static const GLfloat colorLevels[] = {
	0.0,   1.0,  0.0,   0.0,   0.0,  // black
	0.1,   1.0,  0.3,   0.0,   0.0,  //
	0.2,   1.0,  0.5,   0.0,   0.0,  //
	0.3,   1.0,  0.7,   0.3,   0.0,  //
	0.4,   1.0,  0.0,   0.5,   0.0,  //
	0.5,   1.0,  0.0,   0.7,   0.0,  //
	0.6,   1.0,  0.0,   1.0,   0.0,  //
	0.7,   1.0,  0.3,   1.0,   0.3,  //
	0.8,   1.0,  0.5,   0.8,   0.5,  //
	0.9,   1.0,  0.9,   0.9,   0.9,  //
	1.0,   1.0,  1.0,   1.0,   1.0,  // white
};

@synthesize eaglView;
@synthesize rssiMeter;
@synthesize hideStatusBar;

@synthesize displayMode;
@synthesize buttonsAreOn;
@synthesize noisefilter;
@synthesize inputProc;
@synthesize sampleRateBandwidthHz, sampleRateBandwidthKHz;
@synthesize mixerController;

@synthesize infoButton;
@synthesize switchCtl;
@synthesize lockButton;

@synthesize baseTouch, slidingTouch;


///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
@synthesize plusButton, minusButton, wifiButton;
@synthesize centerFrequencyText;
@synthesize ipAddressText;
@synthesize windowBehavior;
@synthesize activeIPAddress;
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////

@synthesize iSDRpopoverController;

@synthesize prefViewController;
@synthesize	navigationController;
@synthesize viewRefreshRate;
@synthesize savedAnimationState;
@synthesize runningInBackground;

@synthesize tuneBarWFRectangle, tuneBarOSRectangle;
@synthesize	gridRectangleWF, gridRectangle;
@synthesize cursorRectangleWF, cursorHeightWF, cursorWidthWF;
@synthesize cursorRectangleOS, cursorHeightOS, cursorWidthOS;
@synthesize freqOverlayRectangle;

@synthesize cursorLandscapeOverlayOS;
@synthesize cursorLandscapeOverlayWF;
@synthesize tuneBarLandscapeOverlayWF;
@synthesize tuneBarLandscapeOverlayGrayWF;
@synthesize tuneBarLandscapeOverlayOS;
@synthesize tuneBarLandscapeOverlayGrayOS;
@synthesize meterNumberingOverlay;
@synthesize agcOffOverlayLandscape;
@synthesize agcSlowOverlayLandscape;
@synthesize agcFastOverlayLandscape;
@synthesize semiLogGridOverlay;
@synthesize linearGridOverlay;
@synthesize signalScopeGridOverlay;

@synthesize appDelegate;

#pragma mark-
CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180.0;};

CGPathRef CreateRoundedRectPath(CGRect RECT, CGFloat cornerRadius)
{
	CGMutablePathRef		path;
	path = CGPathCreateMutable();

	double		maxRad = MAX(CGRectGetHeight(RECT) / 2., CGRectGetWidth(RECT) / 2.);

	if (cornerRadius > maxRad) cornerRadius = maxRad;

	CGPoint		bl, tl, tr, br;

	bl = tl = tr = br = RECT.origin;
	tl.y += RECT.size.height;
	tr.y += RECT.size.height;
	tr.x += RECT.size.width;
	br.x += RECT.size.width;

	CGPathMoveToPoint(path, NULL, bl.x + cornerRadius, bl.y);
	CGPathAddArcToPoint(path, NULL, bl.x, bl.y, bl.x, bl.y + cornerRadius, cornerRadius);
	CGPathAddLineToPoint(path, NULL, tl.x, tl.y - cornerRadius);
	CGPathAddArcToPoint(path, NULL, tl.x, tl.y, tl.x + cornerRadius, tl.y, cornerRadius);
	CGPathAddLineToPoint(path, NULL, tr.x - cornerRadius, tr.y);
	CGPathAddArcToPoint(path, NULL, tr.x, tr.y, tr.x, tr.y - cornerRadius, cornerRadius);
	CGPathAddLineToPoint(path, NULL, br.x, br.y + cornerRadius);
	CGPathAddArcToPoint(path, NULL, br.x, br.y, br.x - cornerRadius, br.y, cornerRadius);

	CGPathCloseSubpath(path);

	CGPathRef				ret;
	ret = CGPathCreateCopy(path);
	CGPathRelease(path);
	return ret;
}


CGPathRef createSharpRectPath(CGRect RECT)
{
	CGMutablePathRef		path;
	path = CGPathCreateMutable();

	CGPoint		bl, tl, tr, br;

	bl = tl = tr = br = RECT.origin;
	tl.y += RECT.size.height;
	tr.y += RECT.size.height;
	tr.x += RECT.size.width;
	br.x += RECT.size.width;

	CGPathMoveToPoint(path, NULL, bl.x, bl.y);
	CGPathAddLineToPoint(path, NULL, tl.x, tl.y);
	CGPathAddLineToPoint(path, NULL, tr.x, tr.y);
	CGPathAddLineToPoint(path, NULL, br.x, br.y);

	CGPathCloseSubpath(path);

	CGPathRef				ret;
	ret = CGPathCreateCopy(path);
	CGPathRelease(path);
	return ret;
}


/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
 - (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
 if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
 // Custom initialization
 }
 return self;
 }
 */

#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0)
- (UIInterfaceOrientation)getInterfaceOrientation
{
	return self.interfaceOrientation;
}
#endif


// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
	[super loadView];

	static BOOL success = FALSE;

	if(!success)
	{
		CGImageRef img;

		if(appDelegate == nil)
		{
			appDelegate = (iSDRAppDelegate *)[[UIApplication sharedApplication] delegate];
		}

		runningInBackground = FALSE;
		displayInitialized = FALSE;

		SDR_DEBUGPRINT(("\n\nRetrieving default settings\n\n"));
		[self getSavedSettings];

		///////////////////////////////////////////////////////////////////////////////////////////
		// Wifi support changes
		// Instantiate and configure the wifi interface singleton
		wifi = [WifiInterface sharedInstance]; // always returns the unique instance - creating it if necessary
		[wifi startWifiInterface]; // start the singleton running its own run loop
		wifi.frequencyShift = 0.;
        wifi.commandPort = appDelegate.commandPort;
        wifi.dataPort = appDelegate.dataPort;

		wifiStateTranstionAlert = nil;
		wifiDisabledOnDeviceAlert = nil;
		wifiEnterNewIPAddress = nil;
		wifiConnectionLostAlert = nil;

		self.activeIPAddress = [NSMutableString new];
		holdWifiState = Disconnected;
		// Don't attempt to use the wifiInterface immediately - it likely to take a little while before the
		// run loop has an opportunity to start up
		// Wifi support changes
		///////////////////////////////////////////////////////////////////////////////////////////

#define FREQUENCY_OVERLAY_HEIGHT_IPOD (50.)
#define FREQUENCY_OVERLAY_HEIGHT_IPAD (75.)

#define FREQUENCY_OVERLAY_WIDTH_IPOD (234.)
#define FREQUENCY_OVERLAY_WIDTH_IPAD (234.)

		if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
		{
			SDR_DEBUGPRINT(("iPad! loadView\n"));

			if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0"))
			{
				[self setNeedsStatusBarAppearanceUpdate];
			}

			_frequencyOverlayHeight = FREQUENCY_OVERLAY_HEIGHT_IPAD;
			_frequencyOverlayWidth = FREQUENCY_OVERLAY_WIDTH_IPAD;

			/////////////////////////////////////////
			// Handle Screen Layout
			/////////////////////////////////////////
			CGFloat width, height;

			width = appDelegate.hardware.portraitWidth;
			height = appDelegate.hardware.portraitHeight;

			displayStatusBarHeight = IPAD_STATUSBAR_HEIGHT;

			displayPortraitHeight = height-IPAD_STATUSBAR_HEIGHT;
			displayPortraitWidth = width;
			displayLandscapeHeight = width-IPAD_STATUSBAR_HEIGHT;
			displayLandscapeWidth = height;

			tunebarHeight = 104.;
			tunebarTopRow = displayLandscapeHeight - tunebarHeight;

			UIImage* tuneBar;
			UIEdgeInsets capInsets = UIEdgeInsetsMake(0., 0., 0., 0.);
			CGSize newSize;

			////////////////////////////////////////////////////
			// Resize rainbow tune bar to fit screen
            tuneBar = [[UIImage imageNamed:@"tuneBarHoriz_iPad.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
            newSize = CGSizeMake(displayLandscapeWidth, tunebarHeight);
            tuneBar = [self imageResize:tuneBar andResizeTo:newSize];

			self.tuneBarLandscapeOverlayOS = [[UIImageView alloc] initWithImage:tuneBar];

			tuneBarLandscapeOverlayOS.center = CGPointMake(displayLandscapeWidth/2, displayPortraitWidth-tunebarHeight/2);
			tuneBarOSRectangle = CGRectMake(0., displayLandscapeHeight-tunebarHeight, displayLandscapeWidth, tunebarHeight);
			//
			////////////////////////////////////////////////////

			////////////////////////////////////////////////////
			// Resize gray tune bar to fit screen
            tuneBar = [[UIImage imageNamed:@"tuneBarGrayHoriz_iPad.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
            newSize = CGSizeMake(displayLandscapeWidth, tunebarHeight);
            tuneBar = [self imageResize:tuneBar andResizeTo:newSize];

			self.tuneBarLandscapeOverlayGrayOS = [[UIImageView alloc] initWithImage:tuneBar];

			tuneBarLandscapeOverlayGrayOS.center = tuneBarLandscapeOverlayOS.center;
			//
			////////////////////////////////////////////////////

			doubleArrowOverlayLandscape = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"double_arrow.png"]];
			doubleArrowOverlayLandscape.center = CGPointMake(displayLandscapeWidth/2, displayPortraitWidth-tunebarHeight/2);

			CGFloat meterHeight = 50.; // = displayLandscapeHeight/15.;
			CGFloat meterVerticalCenter = displayLandscapeHeight - (tunebarHeight + meterHeight/2.); // 220.;


			CGRect frame = CGRectMake(0, meterVerticalCenter, displayLandscapeWidth, meterHeight);

			AULevelMeter* aulm = [[AULevelMeter alloc] initWithFrame:frame orient:HorizontalLeftToRight dBWidth:120.];
			self.rssiMeter = aulm;

			meterRect = CGRectMake(0, meterVerticalCenter, displayLandscapeWidth, displayLandscapeHeight/8.);
			UIColor *bgColor = [[UIColor alloc] initWithRed:.39 green:.44 blue:.57 alpha:.5];
			UIColor *bdrColor = [[UIColor alloc] initWithRed:.39 green:.44 blue:.57 alpha:.5];
			[rssiMeter setBackgroundColor:bgColor];
			[rssiMeter setBorderColor:bdrColor];
			rssiMeter.agc = defaultsWorkingCopy.agcSetting;


			CGFloat meterNumberingHeight = 28.;
			capInsets = UIEdgeInsetsMake(1., 1., 1., 1.);

			////////////////////////////////////////////////////
			// Resize meter numbering to fit screen
            tuneBar = [[UIImage imageNamed:@"meterNumberingiPad.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
            newSize = CGSizeMake(displayLandscapeWidth, meterNumberingHeight);
            tuneBar = [self imageResize:tuneBar andResizeTo:newSize];

			self.meterNumberingOverlay = [[UIImageView alloc] initWithImage:tuneBar];
			//
			////////////////////////////////////////////////////

			CGFloat meterNumberingVerticalCenter = meterVerticalCenter + meterHeight/2.;

			meterNumberingOverlay.center = CGPointMake(displayLandscapeWidth/2, meterNumberingVerticalCenter);

			// Maximize the grid size to allow just enough room for the frequency text box to fit
			gridHeight = displayLandscapeHeight - tunebarHeight - meterHeight - _frequencyOverlayHeight - FILE_INFO_BANNER_HEIGHT;

			meterTopRow = displayPortraitWidth - (tunebarHeight + meterHeight);
			gridBottomRow = gridHeight + FILE_INFO_BANNER_HEIGHT + IPAD_STATUSBAR_HEIGHT;

			cursorHeightOStweak = -2; // slight adjustment needed keep cursor inside grid area
			signalTraceOStweak = 0;  // slight adjustment needed to FFT signal trace translation for unknown reasons
			cursorRowOStweak = 0;
			UInt16 signalFFTOStweak = -5;   // slight adjustment needed to fft signal trace translation for unknown reasons

			// AGC settings images
			img = [UIImage imageNamed:@"offAGC_iPad.png"].CGImage;

			UIImageView* iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"offAGC_iPad.png"]];
			self.agcOffOverlayLandscape = iv;

			agcOffOverlayLandscape.center = CGPointMake(displayLandscapeWidth-CGImageGetWidth(img)/2, meterNumberingVerticalCenter);

			iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"slowAGC_iPad.png"]];
			self.agcSlowOverlayLandscape = iv;

			agcSlowOverlayLandscape.center = CGPointMake(displayLandscapeWidth-CGImageGetWidth(img)/2, meterNumberingVerticalCenter);

			iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"fastAGC_iPad.png"]];
			self.agcFastOverlayLandscape = iv;

			agcFastOverlayLandscape.center = CGPointMake(displayLandscapeWidth-CGImageGetWidth(img)/2, meterNumberingVerticalCenter);

			// Settings for oscilloscope grid
			//img = [UIImage imageNamed:@"grid.png"].CGImage;

			gridWidth = displayLandscapeWidth;
			gridRectangle = CGRectMake(0., 0., gridWidth, gridHeight);

			SDR_DEBUGPRINT(("iPhone grid: gridHeight=%d gridWidth=%d", gridHeight, gridWidth));

			oscopeMaxSignalHeight = gridHeight / 2.2; // keep oscope signal inside of grid area
			oscopeSignalOffset = displayLandscapeHeight - ((gridHeight / 2) + FILE_INFO_BANNER_HEIGHT) + signalTraceOStweak; // center oscope signal vertically on grid area
			fftSignalOffset = displayLandscapeHeight - (gridHeight + FILE_INFO_BANNER_HEIGHT) + signalFFTOStweak;

//			img = [UIImage imageNamed:@"tuneBarVert_iPad.png"].CGImage;
//			tunebarWaterfallColumn = CGImageGetWidth(img); // use the overlay graphic width to determine tunebar width

			tunebarVertHeightOffset = IPAD_STATUSBAR_HEIGHT; // For rainbow tunebar in waterfall mode - must avoid the status bar if there is one
			waterfallStepSize = 2;
			viewRefreshRate = 0.1;
			oscopeCursorVerticalRow = (gridHeight / 2) + FILE_INFO_BANNER_HEIGHT + cursorRowOStweak;

			// avoid compile dead code warning
			if(tunebarVertHeightOffset > 0)
			{
				oscopeCursorVerticalRow += tunebarVertHeightOffset;
			}


			//*** Tune Bar Creation ***//

            ////////////////////////////////////////////////////
            // Resize vertical rainbow tune bar to fit screen

            tuneBar = [[UIImage imageNamed:@"tuneBarVert_iPad.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
            newSize = CGSizeMake(tunebarHeight, displayLandscapeHeight);
            tuneBar = [self imageResize:tuneBar andResizeTo:newSize];

            iv = [[UIImageView alloc] initWithImage:tuneBar];
            tunebarWaterfallColumn = tunebarHeight;
            waterfallCursorHorizontalCenterColumn = (displayLandscapeWidth/2)+tunebarHeight;

			// Create the image view to hold the background rect which we just drew
//			iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tuneBarVert_iPad.png"]];
			self.tuneBarLandscapeOverlayWF = iv;

			// avoid compile dead code warning
			if(tunebarVertHeightOffset > 0)
			{
				tuneBarLandscapeOverlayWF.center = CGPointMake(tunebarWaterfallColumn/2, displayLandscapeHeight/2 + tunebarVertHeightOffset);
			}
			else
			{
				tuneBarLandscapeOverlayWF.center = CGPointMake(tunebarWaterfallColumn/2, displayLandscapeHeight/2);
			}

			if(tunebarVertHeightOffset > 0)
			{
				tuneBarWFRectangle = CGRectMake(0., 0., tunebarWaterfallColumn, displayLandscapeHeight-tunebarVertHeightOffset);
			}
			else
			{
				tuneBarWFRectangle = CGRectMake(0., 0., tunebarWaterfallColumn, displayLandscapeHeight);
			}

			gridRectangleWF = CGRectMake(tunebarWaterfallColumn, tunebarVertHeightOffset, displayLandscapeWidth-tunebarWaterfallColumn, displayLandscapeHeight-tunebarVertHeightOffset);

            ////////////////////////////////////////////////////
            // Resize vertical gray tune bar to fit screen

            tuneBar = [[UIImage imageNamed:@"tuneBarGrayVert_iPad.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
            newSize = CGSizeMake(tunebarHeight, displayLandscapeHeight);
            tuneBar = [self imageResize:tuneBar andResizeTo:newSize];

            iv = [[UIImageView alloc] initWithImage:tuneBar];
            self.tuneBarLandscapeOverlayGrayWF = iv;

			tuneBarLandscapeOverlayGrayWF.center = CGPointMake(tunebarWaterfallColumn/2, displayLandscapeHeight/2 + tunebarVertHeightOffset);
		}
		else
		{
			_frequencyOverlayHeight = FREQUENCY_OVERLAY_HEIGHT_IPOD;
			_frequencyOverlayWidth = FREQUENCY_OVERLAY_WIDTH_IPOD;

			/////////////////////////////////////////
			// Handle Screen Layout
			/////////////////////////////////////////
			CGFloat width, height;

			width = appDelegate.hardware.portraitWidth;
			height = appDelegate.hardware.portraitHeight;

			// Assume the device is an iPhone or iPod touch.
			displayStatusBarHeight = IPOD_STATUSBAR_HEIGHT;

			displayPortraitHeight = height-IPOD_STATUSBAR_HEIGHT;
			displayPortraitWidth = width;
			displayLandscapeHeight = width-IPOD_STATUSBAR_HEIGHT;
			displayLandscapeWidth = height;

			tunebarHeight = 82.;
			tunebarTopRow = displayLandscapeHeight - tunebarHeight;

			UIImage* tuneBar;
			UIEdgeInsets capInsets = UIEdgeInsetsMake(0., 0., 0., 0.);
			CGSize newSize;

			////////////////////////////////////////////////////
			// Resize rainbow tune bar to fit screen
			if(SYSTEM_VERSION_LESS_THAN(@"6.0"))
			{
				tuneBar = [UIImage imageNamed:@"tuneBarHoriz.png"];
			}
			else
			{
				if(appDelegate.hardware.use568displayPixelRatio)
				{
					tuneBar = [[UIImage imageNamed:@"tuneBarHoriz_568h.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
				}
				else
				{
					tuneBar = [[UIImage imageNamed:@"tuneBarHoriz.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
				}
			}

			newSize = CGSizeMake(displayLandscapeWidth, tunebarHeight);
			tuneBar = [self imageResize:tuneBar andResizeTo:newSize];
			self.tuneBarLandscapeOverlayOS = [[UIImageView alloc] initWithImage:tuneBar];

			tuneBarLandscapeOverlayOS.center = CGPointMake(displayLandscapeWidth/2, displayLandscapeHeight-tunebarHeight/2);
			tuneBarOSRectangle = CGRectMake(0., displayLandscapeHeight-tunebarHeight, displayLandscapeWidth, tunebarHeight);
			//
			////////////////////////////////////////////////////

			////////////////////////////////////////////////////
			// Resize gray tune bar to fit screen
			if(SYSTEM_VERSION_LESS_THAN(@"6.0"))
			{
				tuneBar = [UIImage imageNamed:@"tuneBarGrayHoriz.png"];
			}
			else
			{
				if(appDelegate.hardware.use568displayPixelRatio)
				{
					tuneBar = [[UIImage imageNamed:@"tuneBarGrayHoriz_568h.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
				}
				else
				{
					tuneBar = [[UIImage imageNamed:@"tuneBarGrayHoriz.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
				}
			}

			newSize = CGSizeMake(displayLandscapeWidth, tunebarHeight);
			tuneBar = [self imageResize:tuneBar andResizeTo:newSize];
			self.tuneBarLandscapeOverlayGrayOS = [[UIImageView alloc] initWithImage:tuneBar];

			tuneBarLandscapeOverlayGrayOS.center = tuneBarLandscapeOverlayOS.center;
			//
			////////////////////////////////////////////////////

			doubleArrowOverlayLandscape = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"double_arrow.png"]];
			doubleArrowOverlayLandscape.center = CGPointMake(displayLandscapeWidth/2, displayLandscapeHeight-tunebarHeight/2);

			CGFloat meterHeight = displayLandscapeHeight/15.;
			capInsets = UIEdgeInsetsMake(1., 1., 1., 1.);

			////////////////////////////////////////////////////
			// Resize meter numbering to fit screen
			if(SYSTEM_VERSION_LESS_THAN(@"6.0"))
			{
				tuneBar = [UIImage imageNamed:@"meterNumberingiPod.png"];
			}
			else
			{
				if(appDelegate.hardware.use568displayPixelRatio)
				{
					tuneBar = [[UIImage imageNamed:@"meterNumberingiPod_568h.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
				}
				else
				{
					tuneBar = [[UIImage imageNamed:@"meterNumberingiPod.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
				}
			}

			newSize = CGSizeMake(displayLandscapeWidth, meterHeight);
			tuneBar = [self imageResize:tuneBar andResizeTo:newSize];
			self.meterNumberingOverlay = [[UIImageView alloc] initWithImage:tuneBar];
			//
			////////////////////////////////////////////////////

			CGFloat meterVerticalCenter = displayLandscapeHeight - (tunebarHeight + meterHeight); // 220.;
			CGFloat meterNumberingVerticalCenter = meterVerticalCenter + meterHeight/2.; // 230.;

			meterNumberingOverlay.center = CGPointMake(displayLandscapeWidth/2, meterNumberingVerticalCenter);

			// Maximize the grid size to allow just enough room for the frequency text box to fit
			gridHeight = displayLandscapeHeight - tunebarHeight - meterHeight - _frequencyOverlayHeight - FILE_INFO_BANNER_HEIGHT;

			meterTopRow = displayLandscapeHeight - (tunebarHeight + meterHeight);
			gridBottomRow = gridHeight + FILE_INFO_BANNER_HEIGHT;



			cursorHeightOStweak = -2; // slight adjustment needed keep cursor inside grid area
			signalTraceOStweak = 0;  // slight adjustment needed to FFT signal trace translation for unknown reasons
			cursorRowOStweak = 0;
			UInt16 signalFFTOStweak = 0;   // slight adjustment needed to fft signal trace translation for unknown reasons

			// AGC settings images
			img = [UIImage imageNamed:@"offAGC.png"].CGImage;

			UIImageView* iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"offAGC.png"]];
			self.agcOffOverlayLandscape = iv;

			agcOffOverlayLandscape.center = CGPointMake(displayLandscapeWidth-CGImageGetWidth(img)/2, meterNumberingVerticalCenter);

			iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"slowAGC.png"]];
			self.agcSlowOverlayLandscape = iv;

			agcSlowOverlayLandscape.center = CGPointMake(displayLandscapeWidth-CGImageGetWidth(img)/2, meterNumberingVerticalCenter);

			iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"fastAGC.png"]];
			self.agcFastOverlayLandscape = iv;

			agcFastOverlayLandscape.center = CGPointMake(displayLandscapeWidth-CGImageGetWidth(img)/2, meterNumberingVerticalCenter);

			// Settings for oscilloscope grid
			//img = [UIImage imageNamed:@"grid.png"].CGImage;

			gridWidth = displayLandscapeWidth;
			gridRectangle = CGRectMake(0., 0., gridWidth, gridHeight);

			SDR_DEBUGPRINT(("iPhone grid: gridHeight=%d gridWidth=%d", gridHeight, gridWidth));

			oscopeMaxSignalHeight = gridHeight / 2.2; // keep oscope signal inside of grid area
			oscopeSignalOffset = displayLandscapeHeight - ((gridHeight / 2) + FILE_INFO_BANNER_HEIGHT) + signalTraceOStweak; // center oscope signal vertically on grid area
			fftSignalOffset = displayLandscapeHeight - (gridHeight + displayStatusBarHeight + FILE_INFO_BANNER_HEIGHT) + signalFFTOStweak;

			img = [UIImage imageNamed:@"tuneBarVert.png"].CGImage;
			tunebarWaterfallColumn = CGImageGetWidth(img); // use the overlay graphic width to determine tunebar width

			tunebarVertHeightOffset = IPOD_STATUSBAR_HEIGHT; // For rainbow tunebar in waterfall mode - must avoid the status bar if there is one
			waterfallStepSize = 2;
			viewRefreshRate = 0.1;
			oscopeCursorVerticalRow = (gridHeight / 2) + FILE_INFO_BANNER_HEIGHT + cursorRowOStweak;

			// avoid compile dead code warning
			if(tunebarVertHeightOffset > 0)
			{
				oscopeCursorVerticalRow += tunebarVertHeightOffset;
			}

			waterfallCursorHorizontalCenterColumn = (displayLandscapeWidth/2)+SPECTRUM_BAR_WIDTH;

			//*** Tune Bar Creation ***//
			////////////////////////////////////////////////////
			// Resize waterfall view tune bar to fit screen
			if(SYSTEM_VERSION_LESS_THAN(@"6.0"))
			{
				tuneBar = [UIImage imageNamed:@"tuneBarVert.png"];
			}
			else
			{
				tuneBar = [[UIImage imageNamed:@"tuneBarVert.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];

				newSize = CGSizeMake(tunebarWaterfallColumn, displayLandscapeHeight);
				tuneBar = [self imageResize:tuneBar andResizeTo:newSize];
			}

			self.tuneBarLandscapeOverlayWF = [[UIImageView alloc] initWithImage:tuneBar];
			//
			////////////////////////////////////////////////////

			// avoid compile dead code warning
			if(tunebarVertHeightOffset > 0)
			{
				tuneBarLandscapeOverlayWF.center = CGPointMake(tunebarWaterfallColumn/2, displayLandscapeHeight/2 + tunebarVertHeightOffset);
			}
			else
			{
				tuneBarLandscapeOverlayWF.center = CGPointMake(tunebarWaterfallColumn/2, displayLandscapeHeight/2);
			}

			if(tunebarVertHeightOffset > 0)
			{
				tuneBarWFRectangle = CGRectMake(0., 0., tunebarWaterfallColumn, displayLandscapeHeight-tunebarVertHeightOffset);
			}
			else
			{
				tuneBarWFRectangle = CGRectMake(0., 0., tunebarWaterfallColumn, displayLandscapeHeight);
			}

			gridRectangleWF = CGRectMake(tunebarWaterfallColumn, tunebarVertHeightOffset, displayLandscapeWidth-tunebarWaterfallColumn, displayLandscapeHeight-tunebarVertHeightOffset);

			////////////////////////////////////////////////////
			// Resize waterfall view tune bar to fit screen
			if(SYSTEM_VERSION_LESS_THAN(@"6.0"))
			{
				tuneBar = [UIImage imageNamed:@"tuneBarGrayVert.png"];
			}
			else
			{
				tuneBar = [[UIImage imageNamed:@"tuneBarGrayVert.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];

				newSize = CGSizeMake(tunebarWaterfallColumn, displayLandscapeHeight);
				tuneBar = [self imageResize:tuneBar andResizeTo:newSize];
			}

			self.tuneBarLandscapeOverlayGrayWF = [[UIImageView alloc] initWithImage:tuneBar];
			//
			////////////////////////////////////////////////////

			tuneBarLandscapeOverlayGrayWF.center = CGPointMake(tunebarWaterfallColumn/2, displayLandscapeHeight/2 + tunebarVertHeightOffset);

			CGRect frame = CGRectMake(0, meterVerticalCenter, displayLandscapeWidth, meterHeight);

			AULevelMeter* aulm = [[AULevelMeter alloc] initWithFrame:frame orient:HorizontalLeftToRight dBWidth:120.];
			self.rssiMeter = aulm;

			meterRect = CGRectMake(0, meterVerticalCenter, displayLandscapeWidth, displayLandscapeHeight/8.);
			UIColor *bgColor = [[UIColor alloc] initWithRed:.39 green:.44 blue:.57 alpha:.5];
			UIColor *bdrColor = [[UIColor alloc] initWithRed:.39 green:.44 blue:.57 alpha:.5];
			[rssiMeter setBackgroundColor:bgColor];
			[rssiMeter setBorderColor:bdrColor];
			rssiMeter.agc = defaultsWorkingCopy.agcSetting;
		}

		topLeftRect = CGRectMake(0, 0, 100, 100.);
		topRightRect = CGRectMake(displayLandscapeWidth-100, 0, 100, 100);

		// Set up modal view for setting user settings
		self.prefViewController = nil;

		// Initialize volatile settings
		displayMode = DisplayModeOscilloscopeFFT;
		initted_spectrum = FALSE;
		firstTex = nil;
		initted_oscilloscope = FALSE;
		buttonsAreOn = TRUE;
		l_SprectrumData = nil;
		countdownTimer = nil;

		try
		{
			MultichannelMixerController* mcmc = [[MultichannelMixerController alloc] initMMC];
			self.mixerController = mcmc;

			if(mixerController != nil)
			{
				mixerController.delegate = self;
				mixerController.mAutoconfigEnabled = FALSE;
				mixerController.mLiveAudioAllowed = !defaultsWorkingCopy.demoModeOnly;
				SDR_DEBUGPRINT(("call setupAudioSession #1\n"));

				OSStatus audioResult;
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
				if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
#endif
				{
					audioResult = [mixerController setupAudioSession];
				}
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
				else
				{
					audioResult = [mixerController setupAudioSession_old];
				}
#endif

				if(audioResult)
				{
					[self popFatalErrorMessage:audioResult];
				}

				if(mixerController.audioStatus != AudioReady)
				{
					fftBufferManager = nil;

					SDR_DEBUGPRINT(("Error starting audio path! Aborting...\n"));
					// TODO: implement a proper abort procedure
				}
				else
				{
					SDR_DEBUGPRINT(("Session setup successful!\n"));
					success = TRUE;
					fftBufferManager = mixerController.fftBufferManager;
					sampleRateBandwidthHz = (float)mixerController.sampleRateBandwidth;
					sampleRateBandwidthKHz = sampleRateBandwidthHz / 1000.;
					kHertzPerScreenElement = (self.displayMode == DisplayModeWaterfall) ? (sampleRateBandwidthKHz / displayLandscapeHeight) : (sampleRateBandwidthKHz / displayLandscapeWidth);

					SDR_DEBUGPRINT(("EAGLview rec'd sampleRateBandwidthHz = %0.0f\n", sampleRateBandwidthHz));

					if(mixerController.mAudioMode == AudioModeDemonstration)
					{
						SDR_DEBUGPRINT(("Starting recorded audio...\n"));
					}
					else
					{
						SDR_DEBUGPRINT(("Receiving live audio (4)...\n"));
					}

					// start the app with silence initially
					mixerController.vController = self;
					mixerController.mute = TRUE;
					//					[mixerController startAUGraph:FALSE]; // start audio flow

					if(rssiMeter)
					{
						mixerController.mcMixerUser = rssiMeter;
						[rssiMeter setAu:mixerController.mMixerUnit];
					}
				}
			}
		}
		catch (CAXException &e)
		{
			char buf[256];
			fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		}
		catch (...)
		{
			fprintf(stderr, "An unknown error occurred in EAGLViewController\n");
		}

		if((fftBufferManager != nil) && (sampleRateBandwidthHz != 0))
		{
			if(defaultsWorkingCopy.operatingMode == CW_mode)
			{
				fftBufferManager->setCenterFrequencyOffsetHz(-defaultsWorkingCopy.rxOffset, sampleRateBandwidthHz, FALSE);
			}

			fftBufferManager->setCenterFrequency(0.5);
			[self initializeRadioSettings];
		}
		else
		{
			SDR_DEBUGPRINT(("Audio error during initialization - retry"));
			success = FALSE;
			self.mixerController = nil;
		}

		if(success)
		{
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
			if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
#endif
			{
				[self createSemiLogGridOverlay:([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad)];
				[self createLinearGridOverlay];
				[self createSignalScopeGridOverlay:([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad)];
			}
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
			else
			{
				[self createSemiLogGridOverlay_old:([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad)];
				[self createLinearGridOverlay_old];
				[self createSignalScopeGridOverlay_old:([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad)];
			}
#endif

			UIImage* img_ui = nil;

			{
				// Draw the rounded rect for the bg path using this convenience function
				CGPathRef bgPath = CreateRoundedRectPath(CGRectMake(0, 0, _frequencyOverlayWidth, _frequencyOverlayHeight), 15.);

				CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
				// Create the bitmap context into which we will draw
				CGContextRef cxt = CGBitmapContextCreate(NULL, _frequencyOverlayWidth, _frequencyOverlayHeight, 8, 4*_frequencyOverlayWidth, cs, kCGImageAlphaPremultipliedFirst);
				CGContextSetFillColorSpace(cxt, cs);
				//		CGFloat fillClr[] = {0., 0., 0., 0.7}; // translucent black
				CGFloat fillClr[] = {0., 0., 0., 0.0}; // clear
				CGContextSetFillColor(cxt, fillClr);
				// Add the rounded rect to the context...
				CGContextAddPath(cxt, bgPath);
				// ... and fill it.
				CGContextFillPath(cxt);

				// Make a CGImage out of the context
				CGImageRef img_cg = CGBitmapContextCreateImage(cxt);
				// Make a UIImage out of the CGImage
				img_ui = [UIImage imageWithCGImage:img_cg];

				// Clean up
				CGImageRelease(img_cg);
				CGColorSpaceRelease(cs);
				CGContextRelease(cxt);
				CGPathRelease(bgPath);
			}

			if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
			{
				_freqOverlayFrameCenterRow = gridBottomRow + (_frequencyOverlayHeight / 2.);

				// Create the image view to hold the background rounded rect which we just drew
				_frequencyOverlayWidth = kFrequencyOverlayWidth_iPad;
				_frequencyOverlayBorderOffset = _frequencyOverlayWidth / 2.2;
				frequencyOverlayLandscape = [[OverlayView alloc] initWithImage:img_ui];

#ifdef SDR_DEBUG
//				frequencyOverlayLandscape.backgroundColor = [UIColor purpleColor];
#endif
				frequencyOverlayLandscape.frame = CGRectMake(0, 0, _frequencyOverlayWidth, _frequencyOverlayHeight);

				frequencyOverlayLandscape.center = CGPointMake((displayLandscapeWidth/2)-(_frequencyOverlayWidth/2), _freqOverlayFrameCenterRow);

				// Create the text view which shows the file information
				fileInfoTextLandscape = [[UILabel alloc] initWithFrame:CGRectMake(0, IPAD_STATUSBAR_HEIGHT, displayLandscapeWidth, FILE_INFO_BANNER_HEIGHT)];
				fileInfoTextLandscape.numberOfLines = 1;
				fileInfoTextLandscape.textAlignment = NSTextAlignmentCenter;
				fileInfoTextLandscape.textColor = [UIColor blackColor];
				fileInfoTextLandscape.text = [self getFileInfoText];
				fileInfoTextLandscape.font = [UIFont boldSystemFontOfSize:12.];
				fileInfoTextLandscape.backgroundColor = [UIColor whiteColor];

				// Create the text view which shows the frequency
				frequencyTextLandscape = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, _frequencyOverlayWidth, _frequencyOverlayHeight)];
				frequencyTextLandscape.numberOfLines = 2;
				frequencyTextLandscape.textAlignment = NSTextAlignmentCenter;
				frequencyTextLandscape.textColor = [UIColor whiteColor];
				frequencyTextLandscape.alpha = 1.;
				frequencyTextLandscape.shadowColor = [UIColor clearColor];
				frequencyTextLandscape.text = [self getFreqModeText];
				frequencyTextLandscape.font = [UIFont boldSystemFontOfSize:28.];
				frequencyTextLandscape.backgroundColor = [UIColor clearColor];

//#ifdef SDR_DEBUG
//				frequencyTextLandscape.backgroundColor = [UIColor orangeColor];
//#else
				frequencyTextLandscape.backgroundColor = [UIColor clearColor];
//#endif

				[frequencyOverlayLandscape addSubview:frequencyTextLandscape];

				// Text view was retained by the above line, so we can release it now
			}
			else
			{
				_freqOverlayFrameCenterRow = gridBottomRow + (_frequencyOverlayHeight / 2.);

				// Create the image view to hold the background rounded rect which we just drew
				_frequencyOverlayWidth = kFrequencyOverlayWidth_iPod;
				_frequencyOverlayBorderOffset = _frequencyOverlayWidth / 2.2;
				frequencyOverlayLandscape = [[OverlayView alloc] initWithImage:img_ui];

#ifdef SDR_DEBUG
//				frequencyOverlayLandscape.backgroundColor = [UIColor purpleColor];
#endif
				frequencyOverlayLandscape.frame = CGRectMake(0, 0, _frequencyOverlayWidth, _frequencyOverlayHeight);

				frequencyOverlayLandscape.center = CGPointMake((displayLandscapeWidth/2)-(_frequencyOverlayWidth/2), _freqOverlayFrameCenterRow);

				// Create the text view which shows the file information
				fileInfoTextLandscape = [[UILabel alloc] initWithFrame:CGRectMake(0., 0., displayLandscapeWidth, FILE_INFO_BANNER_HEIGHT)];
				fileInfoTextLandscape.numberOfLines = 1;
				fileInfoTextLandscape.textAlignment = NSTextAlignmentCenter;
				fileInfoTextLandscape.textColor = [UIColor blackColor];
				fileInfoTextLandscape.text = [self getFileInfoText];
				fileInfoTextLandscape.font = [UIFont boldSystemFontOfSize:12.];
				fileInfoTextLandscape.backgroundColor = [UIColor whiteColor];

				// Create the text view which shows the frequency
				frequencyTextLandscape = [[UILabel alloc] initWithFrame:CGRectMake(0., 0., _frequencyOverlayWidth, _frequencyOverlayHeight)];

				frequencyTextLandscape.numberOfLines = 2;
				frequencyTextLandscape.textAlignment = NSTextAlignmentCenter;
				frequencyTextLandscape.textColor = [UIColor whiteColor];
				frequencyTextLandscape.alpha = 1.;
				frequencyTextLandscape.shadowColor = [UIColor clearColor];
				frequencyTextLandscape.text = [self getFreqModeText];
				frequencyTextLandscape.font = [UIFont boldSystemFontOfSize:20.];

//#ifdef SDR_DEBUG
//				frequencyTextLandscape.backgroundColor = [UIColor orangeColor];
//#else
				frequencyTextLandscape.backgroundColor = [UIColor clearColor];
//#endif

				[frequencyOverlayLandscape addSubview:frequencyTextLandscape];
			}

			[self createButtons:TRUE];

			for(texBitBufferSize = 128; texBitBufferSize < displayLandscapeHeight; texBitBufferSize *= 2);
			numDrawBuffers = kFFTDrawBuffers;
			drawBufferLen = kFFTDrawSamples; // use appropriate number of samples for FFT display
			[self setupDrawBuffers];

			CGRect frame = CGRectMake(0, 0, displayLandscapeWidth, displayLandscapeHeight);

#if __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__ < __IPHONE_7_0
			if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0"))
#endif // __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__ < __IPHONE_7_0
			{
				self.extendedLayoutIncludesOpaqueBars = NO; // this is the default value
				self.edgesForExtendedLayout = YES; // this is the default value
			}
#if __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__ < __IPHONE_7_0
			else
			{
				self.wantsFullScreenLayout = YES;
			}
#endif // __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__ < __IPHONE_7_0

			EAGLView *view = [[EAGLView alloc] initWithFrame:frame];
			self.view = view;
			self.eaglView = view;

			self.eaglView.delegate = self;
			// Enable multi touch so we can handle multiple touches
			self.eaglView.multipleTouchEnabled = YES;
			//	self.eaglView.clearsContextBeforeDrawing = NO;
			[self.eaglView setAnimationInterval:viewRefreshRate];

			oscilLine = (GLfloat*)malloc(drawBufferLen * 2 * sizeof(GLfloat));

			if(rssiMeter) [self.view addSubview:rssiMeter];
			// Initializing waterfall textures seems to prevent GL crashes related to rssiMeter
			[self setupViewForSpectrum];
			[self clearTextures];

			SDR_DEBUGPRINT(("EAGLviewController Thread Priority = %1.2lf\n", [NSThread threadPriority]));

			[self.view addSubview:fileInfoTextLandscape];
			[self setUpForDisplayMode:displayMode];

			[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:FALSE useFrequency:-1.];
			[self drawFrequencyOverlay];
		}

		///////////////////////////////////////////////////////////////////////////////////////////
		// Wifi support changes
		// Give wifi plenty of time to set up its run loop before trying to establish a wifi connection.
		// The user is not likely to notice even if we are very generous since the splash screen will
		// be displayed for several seconds anyway.
		autoInfoConfirmationTime = 0;
		receiverFrequencyOffsetHz = 0.;
		receiverModeText = nil;
		iqOffsetFudgeFactorKHz = 0.;
		iqOffsetFudgeFactorNormalized = 0.;

		if(defaultsWorkingCopy.hasSuccessfullyConnectedViaWifi && defaultsWorkingCopy.wifiFunctionalityEnabled)
		{
			[self performSelector:@selector(establishWifiConnection) withObject:nil afterDelay:0.5];
		}
		else
		{
			// go straight to Wi-Fi Disconnected state
			[self performSelector:@selector(setupForWifiDisconnectedState) withObject:nil afterDelay:0.1];
		}
		// Wifi support changes
		///////////////////////////////////////////////////////////////////////////////////////////

		if(!defaultsWorkingCopy.hasShownIntroductionText)
		{
			if(SYSTEM_VERSION_LESS_THAN(@"6.0"))
			{
				NSString* title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"You're running iOS", nil), [[UIDevice currentDevice] systemVersion]];
				[self makeAlert:NO tag:OldIOSVersion title:title message:NSLocalizedString(@"Some app features may not function on this OS version.\nThis message will not appear again.", nil) textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
			}
		}
	}
	else
	{
		SDR_DEBUGPRINT(("Attempted to load view again: view already loaded\n"));
	}
}


- (void)showMPVolumeView
{
	if(systemVolumeView == nil)
	{
		systemVolumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(0., 0., 240., 44.)];
		systemVolumeView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
			UIViewAutoresizingFlexibleRightMargin |
			UIViewAutoresizingFlexibleTopMargin |
			UIViewAutoresizingFlexibleBottomMargin;
		[self.view addSubview:systemVolumeView];
	}

	// The retired system volume HUD had no direct replacement; briefly expose Apple's supported slider.
	systemVolumeView.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
	systemVolumeView.hidden = NO;
	systemVolumeView.alpha = 1.;
	[self.view bringSubviewToFront:systemVolumeView];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideMPVolumeView) object:nil];
	[self performSelector:@selector(hideMPVolumeView) withObject:nil afterDelay:4.];
}

- (void)hideMPVolumeView
{
	[UIView animateWithDuration:0.25 animations:^{
		self->systemVolumeView.alpha = 0.;
	} completion:^(BOOL finished) {
		self->systemVolumeView.hidden = YES;
	}];
}


- (void)refreshDisplay
{
	SDR_DEBUGPRINT(("Performing initial drawView!\n"));
	// These two lines resolve a screen corruption issue that occurs if buttons are drawn after
	// the screen rotates at start-up.
	[self.eaglView setNeedsLayout];
	[self.eaglView drawView];
}


- (void)didReceiveMemoryWarning
{
	// Releases the view if it doesn't have a superview.
	if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		SDR_DEBUGPRINT(("iPad! didReceiveMemoryWarning\n"));
		if(iSDRpopoverController != nil)
		{
			if(_popoverActive == TRUE)
			{
                [[iSDRpopoverController presentingViewController] dismissViewControllerAnimated:FALSE completion:NULL];
             }

			self.iSDRpopoverController = nil;
		}
	}

	self.prefViewController = nil;
	self.navigationController = nil;

    [super didReceiveMemoryWarning];

	// Release any cached data, images, etc that aren't in use.
}


-(UIImage *)imageResize :(UIImage*)img andResizeTo:(CGSize)newSize
{
	CGFloat scale = [[UIScreen mainScreen]scale];

	//UIGraphicsBeginImageContext(newSize);
	UIGraphicsBeginImageContextWithOptions(newSize, NO, scale);
	[img drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
	UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return newImage;
}



// Called after the view controller's view is released and set to nil.
// For example, a memory warning which causes the view to be purged. Not invoked as a result of -dealloc.
// So release any properties that are loaded in viewDidLoad or can be recreated lazily.
//- (void)viewDidUnload
//{
//	// Release any retained subviews of the main view.
//	//	[cursorPortraitOverlayWF release];
//	//	[cursorPortraitOverlayOS release];
//	//	[cursorLandscapeOverlayWF release];
//	//	[cursorLandscapeOverlayOS release];
//	if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
//	{
//		SDR_DEBUGPRINT(("iPad! viewDidUnload\n"));
//		if(iSDRpopoverController != nil)
//		{
//			if(_popoverActive == TRUE)
//			{
//				[iSDRpopoverController dismissPopoverAnimated:FALSE];
//			}
//
//			self.iSDRpopoverController = nil;
//		}
//	}
//
//	//	self.graphView = nil;
//
//	self.prefViewController = nil;
//	self.navigationController = nil;
//
//	[super viewDidUnload];
//}


- (void)configureUserInterface
{
	if(wifi)
	{
		[wifi disableWifiInterface:NO];
	}

	// Make sure buttons display
	// Make sure s-meter goes to zero

	[self drawButtons:buttonsHide];
	[self hideButtonCountdown:CancelTimer selector:@selector(hideButtons)];
	[self createButtons:TRUE];
	[self turnOnButtons];
}

- (void)createButtons:(BOOL)initialize
{
	if(initialize)
	{
		self.infoButton = nil;
		self.lockButton = nil;
		self.centerFrequencyText = nil;
		self.plusButton = nil;
		self.minusButton = nil;
		self.wifiButton = nil;
		self.ipAddressText = nil;
	}

    self.switchCtl = nil; // ensure this is always created anew

	if(infoButton == nil)
	{
		// set up info button
		// since the 'i' image is small, we make the button frame larger than the image to make it easier for the user to hit
		self.infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
		infoButton.backgroundColor = [UIColor clearColor];
		infoButton.tintColor = [UIColor whiteColor];

		float infoShiftRight = (0.85 * displayLandscapeWidth)-infoButton.frame.size.width;
		float infoShiftUp = displayLandscapeHeight+tunebarVertHeightOffset-tunebarHeight/2-infoButton.frame.size.height+3;
		SDR_DEBUGPRINT(("Landscape: i shift right=%f, i shift up=%f\n",infoShiftRight, infoShiftUp));
		float sizeIncrease = 15.0;
		infoButton.frame = CGRectMake(infoShiftRight, infoShiftUp, infoButton.frame.size.width+sizeIncrease, infoButton.frame.size.height+sizeIncrease);
		[infoButton addTarget:self action:@selector(flipAction:) forControlEvents:UIControlEventTouchUpInside];
	}

	// Make switch control
	if(switchCtl == nil)
	{
		CGRect frame = CGRectMake(displayLandscapeWidth/2.-60., displayLandscapeHeight+tunebarVertHeightOffset-tunebarHeight/2.-40., 120., 80.);

		BigSwitch* bs;

		///////////////////////////////////////////////////////////////////////////////////////////
		// Wifi support changes
		if(defaultsWorkingCopy.wifiFunctionalityEnabled)
		{
			NSArray* imageFiles = [NSArray arrayWithObjects:@"switch_off.png", @"switch_siglockmode.png", @"switch_freqlockmode.png", nil];
			bs = [[BigSwitch alloc] initWithFrame:frame images:imageFiles showIcons:TRUE positionOffset:CGPointMake(0., 15.)];
		}
		// Wifi support changes
		///////////////////////////////////////////////////////////////////////////////////////////
		else
		{
            bs = [[BigSwitch alloc] initWithFrame:frame showIcons:TRUE];
		}

		self.switchCtl = bs;

		switchCtl.delegate = self;
		[switchCtl setOn:(!mixerController.mute)];
	}

	///////////////////////////////////////////////////////////////////////////////////////////
	// Wifi support changes
	//
//	if(defaultsWorkingCopy.wifiFunctionalityEnabled)
//	{
//		self.lockButton = nil;

		if(centerFrequencyText == nil)
		{
			// Create the text view which shows the frequency
			CGRect frame = CGRectMake(displayLandscapeWidth/2.-150., displayLandscapeHeight+tunebarVertHeightOffset-tunebarHeight/2. - 65., 300, 80.);
			UILabel* label = [[UILabel alloc] initWithFrame:frame];
			label.numberOfLines = 1;
			label.textAlignment = NSTextAlignmentCenter;
			label.textColor = [UIColor blackColor];
			label.text = [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];
			label.font = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) ? [UIFont boldSystemFontOfSize:20.] : [UIFont boldSystemFontOfSize:18.];
			label.backgroundColor = [UIColor clearColor];
			self.centerFrequencyText = label;
		}

		if(plusButton == nil)
		{
			CGRect frame;
			if(defaultsWorkingCopy.reversePlusMinus)
			{
				frame = CGRectMake((0.325 * displayLandscapeWidth)-50., displayLandscapeHeight + tunebarVertHeightOffset - tunebarHeight/2.-50., 100, 100);
			}
			else
			{
				frame = CGRectMake((0.675 * displayLandscapeWidth)-50., displayLandscapeHeight + tunebarVertHeightOffset - tunebarHeight/2-50., 100., 100.);
			}

			PlusMinusButton* mb = [[PlusMinusButton alloc] initWithFrame:frame image:@"plus.png" disabledImage:@"grayplus.png"];
			self.plusButton = mb;
			plusButton.delegate = self;
			plusButton.disabled = !(wifi.state & SocketEstablished);
		}

		if(minusButton == nil)
		{
			CGRect frame;
			if(defaultsWorkingCopy.reversePlusMinus)
			{
				frame = CGRectMake((0.675 * displayLandscapeWidth)-50., displayLandscapeHeight + tunebarVertHeightOffset - tunebarHeight/2-50., 100., 100.);
			}
			else
			{
				frame = CGRectMake((0.325 * displayLandscapeWidth)-50., displayLandscapeHeight + tunebarVertHeightOffset - tunebarHeight/2.-50., 100, 100);
			}

			PlusMinusButton* mb = [[PlusMinusButton alloc] initWithFrame:frame image:@"minus.png" disabledImage:@"grayminus.png"];
			self.minusButton = mb;
			minusButton.delegate = self;
			minusButton.disabled = !(wifi.state & SocketEstablished);
		}

		if(wifiButton == nil)
		{
			CGRect frame = CGRectMake((0.15 * displayLandscapeWidth)-50., displayLandscapeHeight + tunebarVertHeightOffset - tunebarHeight/2-50., 100., 100.);
			// Add images in correct order based on WifiState: 	Disconnected, Searching, SocketEstablished,
			NSArray* arr = [NSArray arrayWithObjects:@"wifi disabled.png", @"wifi search.png", @"wifi connected.png", @"greenWiFi.png", nil];
			WifiButton* mb = [[WifiButton alloc] initWithFrame:frame images:arr];
			self.wifiButton = mb;
			wifiButton.delegate = self;
			[wifi addWifiStateListener:wifiButton];
			[wifi addWifiStateListener:self];
		}

		if(ipAddressText == nil)
		{
			// Create the text view which shows the frequency
			CGRect frame = CGRectMake((0.15 * displayLandscapeWidth)-60., displayLandscapeHeight + tunebarVertHeightOffset-25., 120., 20.);
			UILabel* label = [[UILabel alloc] initWithFrame:frame];
			label.numberOfLines = 1;
			label.textAlignment = NSTextAlignmentCenter;
			label.textColor = [UIColor blackColor];
			label.text = [self ipAddressString];
			label.font = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) ? [UIFont boldSystemFontOfSize:15.] : [UIFont boldSystemFontOfSize:10.];
			label.backgroundColor = [UIColor clearColor];
			self.ipAddressText = label;
		}
//	}
	// Wifi support changes
	///////////////////////////////////////////////////////////////////////////////////////////
//	else
//	{
//		self.minusButton = nil;
//		self.plusButton = nil;
//		self.centerFrequencyText = nil;
//		self.ipAddressText = nil;
//		self.wifiButton = nil;

		if(lockButton == nil)
		{
			CGRect frame = CGRectMake((0.15 * displayLandscapeWidth)-50., displayLandscapeHeight + tunebarVertHeightOffset - tunebarHeight/2-50., 100., 100.);
			//		NSArray* arr = [NSArray arrayWithObjects:@"wifi.png", @"connected.png", @"disabled.png", nil];
			// Add images in correct order based on WifiState: 	Searching, SocketEstablished, Disconnected
			NSArray* arr = [NSArray arrayWithObjects:@"lock_off.png", @"lock.png", nil];
			LockButton* mb = [[LockButton alloc] initWithFrame:frame images:arr];
			self.lockButton = mb;
			lockButton.delegate = self;
		}
//	}

	return;
}

- (void)switchWasTapped:(BigSwitch*)theSwitch withState:(NSInteger)onState
{
	switch((WindowBehavior)onState)
	{
		case WindowMuted:
		{
			WIFI_DEBUGPRINT(("Switch was tapped with state: Muted\n"));

			windowBehavior = SignalWindowLockMode; // Allow cursor movement without sound

			if(rssiMeter)
			{
				[rssiMeter sleep];
			}

			[self.eaglView stopAnimation];
			mixerController.mute = TRUE;
			[mixerController stopAUGraph:FALSE]; // stop audio flow
			[self.eaglView clearView:TRUE];
			defaultsWorkingCopy = appDelegate.defaults;
			centerFrequencyText.text = [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];
		}
			break;

		case FrequencyWindowLockMode:
		{
			WIFI_DEBUGPRINT(("Switch was tapped with state: FrequencyWindowLockMode\n"));

			windowBehavior = (WindowBehavior)onState;

			frequencyType freq = 0.5 - iqOffsetFudgeFactorNormalized;
			fftBufferManager->setCenterFrequency(freq);
			[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:NO useFrequency:-1.];
			[self drawFrequencyOverlay];

			if(rssiMeter)
			{
				[rssiMeter wake];
			}

			fftBufferManager->AudioBufferFlush();
			// start audio display

			mixerController.mute = FALSE;
			[mixerController startAUGraph:FALSE]; // start audio flow
			[self.eaglView startAnimation];
			mixerController.mAutoconfigEnabled = TRUE;
			centerFrequencyText.text = [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];
		}
			break;

		case SignalWindowLockMode:
		{
			WIFI_DEBUGPRINT(("Switch was tapped with state: SignalWindowLockMode\n"));

			windowBehavior = (WindowBehavior)onState;

			[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:NO useFrequency:-1.];
			[self drawFrequencyOverlay];

			if(rssiMeter)
			{
				[rssiMeter wake];
			}

			fftBufferManager->AudioBufferFlush();
			// start audio display

			mixerController.mute = FALSE;
			[mixerController startAUGraph:FALSE]; // start audio flow
			[self.eaglView startAnimation];
			mixerController.mAutoconfigEnabled = TRUE;
			centerFrequencyText.text = [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];
		}
			break;

		default:
			break;
	}

	if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];

	if(self.displayMode == DisplayModeWaterfall)
	{
		[self drawFrequencyOverlay];
		[self drawButtons:buttonsTurnOn];
		[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];
	}

	if(wifi.state & SocketEstablished)
	{
		NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
		NSTimeInterval delta = now - autoInfoConfirmationTime;
		if(delta > 30.)
		{
			[self sendRadio_AI2]; // refresh auto info setting in case it was lost
		}
	}
}

- (void)switchWasTapped:(BigSwitch *)theSwitch
{
	if(theSwitch.state) // any "on" state
	{
		SDR_DEBUGPRINT(("Switch is on: restart audio!\n"));
		if(rssiMeter)
		{
			[rssiMeter wake];
		}

		fftBufferManager->AudioBufferFlush();
		// start audio display

		mixerController.mute = FALSE;
		[mixerController startAUGraph:FALSE]; // start audio flow
		[self.eaglView startAnimation];
		mixerController.mAutoconfigEnabled = TRUE;
	}
	else
	{
#ifdef SDR_DEBUG
		//		char* msg = fftBufferManager->getDebugMessage();
		//		char* msg = [mixerController getDebugMessage];
		//		[self PrintMessage:msg];
#endif
		SDR_DEBUGPRINT(("Switch is off: shut down audio!\n"));
		if(rssiMeter)
		{
			[rssiMeter sleep];
		}

		mixerController.mute = TRUE;
		[self.eaglView clearView:TRUE];
		[mixerController stopAUGraph:FALSE]; // stop audio flow
	}

	centerFrequencyText.text = theSwitch.plainToggle ? @"": [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];

	if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];

	if(wifi.state & SocketEstablished)
	{
		NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
		NSTimeInterval delta = now - autoInfoConfirmationTime;
		if(delta > 30.)
		{
			[self sendRadio_AI2]; // refresh auto info setting in case it was lost
		}
	}
}

- (NSInteger)switchWasTapped:(BigSwitch *)theSwitch getNextState:(NSInteger)currentState
{
	SwitchState newState = (SwitchState)currentState;

	switch(newState)
	{
		case SwitchFreqLockedTuning:
		{
			if(theSwitch.plainToggle)
			{
				newState = (SwitchState)0;
				theSwitch.state = newState;
				[self switchWasTapped:theSwitch];
			}
			else
			{
				newState = SwitchOff;
				[self switchWasTapped:theSwitch withState:newState];
			}
		}
			break;

		case SwitchNormalTuning:
		{
			if(theSwitch.plainToggle)
			{
				newState = (SwitchState)0;
				theSwitch.state = newState;
				[self switchWasTapped:theSwitch];
			}
			else
			{
				newState = SwitchFreqLockedTuning;
				[self switchWasTapped:theSwitch withState:newState];
			}
		}
			break;

		case SwitchOff:
		{
			if(theSwitch.plainToggle)
			{
				newState = (SwitchState)1;
				theSwitch.state = newState;
				[self switchWasTapped:theSwitch];
			}
			else
			{
				newState = SwitchNormalTuning;
				[self switchWasTapped:theSwitch withState:newState];
			}
		}
			break;

		default:
			break;
	}

	return newState;
}


- (void)buttonWasActivated:(LockButton*)theButton withState:(NSInteger)state
{
	if(theButton == lockButton)
	{
		if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];

		if(state == LOCKED)
		{
			lockButton.state = UNLOCKED;
			[self drawButtons:buttonsTurnOn];	// also turns buttons back on

			// In waterfall display mode the buttons should turn off after a short while
			if(self.displayMode == DisplayModeWaterfall)
			{
				[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];
			}
		}
		else
		{
			lockButton.state = LOCKED;
			[self drawButtons:buttonsLock];
		}
	}
}



- (void)hideButtonCountdown:(TTimerCommand)command selector:(SEL)aSelector
{
	static SEL activeSelector=nil;

	//	SDR_DEBUGPRINT(("hideButtonCountdown\n"));

	if(aSelector == nil) aSelector = @selector(hideButtons);

	switch(command)
	{
		case CancelTimer:
			if(countdownTimer)
			{
				[countdownTimer invalidate];
				countdownTimer = nil;

				if(activeSelector == aSelector)
				{
					SDR_DEBUGPRINT(("hideButtonCountdown: Cancelled!\n"));
				}
				else
				{
					SDR_DEBUGPRINT(("hideButtonCountdown: Cancelled inactive timer!\n"));
				}

				activeSelector = nil;
			}
			break;

		case StartTimer:
			if(countdownTimer)
			{
				[countdownTimer invalidate];
			}
			activeSelector = aSelector;
			countdownTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:aSelector userInfo:nil repeats:YES];
			SDR_DEBUGPRINT(("hideButtonCountdown: Started!\n"));
			break;

		case FireTimer:
			if(countdownTimer)
			{
				[countdownTimer fire];

				if(activeSelector == aSelector)
				{
					SDR_DEBUGPRINT(("hideButtonCountdown: Fired!\n"));
				}
				else
				{
					SDR_DEBUGPRINT(("hideButtonCountdown: Fired inactive timer!\n"));
				}

				activeSelector = nil;
			}
			break;

		default:
			SDR_DEBUGPRINT(("Illegal command sent to hideButtonCountdown\n"));
			break;
	}

	return;
}

- (void)hideFreqOverlay
{
	SDR_DEBUGPRINT(("hideFreqOverlay\n"));
	if(!frequencyOverlayLandscape.doNotTimeout)
	{
		[frequencyOverlayLandscape removeFromSuperview];
		frequencyOverlayLandscape.isVisible = FALSE;
		//frequencyTextLandscape.textColor = [UIColor whiteColor];
		frequencyTextLandscape.alpha = 1.;
		frequencyTextLandscape.shadowColor = [UIColor clearColor];
	}

	[self hideButtonCountdown:CancelTimer selector:@selector(hideFreqOverlay)];
}

- (void)hideButtons
{
	SDR_DEBUGPRINT(("hideButtons\n"));
	if(lockButton && (lockButton.state == UNLOCKED))
	{
		[self drawButtons:buttonsHide];
	}

	if(!frequencyOverlayLandscape.doNotTimeout)
	{
		[frequencyOverlayLandscape removeFromSuperview];
		frequencyOverlayLandscape.isVisible = FALSE;
		//frequencyTextLandscape.textColor = [UIColor whiteColor];
		frequencyTextLandscape.alpha = 1.;
		frequencyTextLandscape.shadowColor = [UIColor clearColor];
	}

	[self hideButtonCountdown:CancelTimer selector:@selector(hideButtons)];
}

- (void)turnOnButtons
{
	SDR_DEBUGPRINT(("turnOnButtons\n"));
	twoTouchFrequencyEvent = nil;
	[self.eaglView enableLayout];
	slideFrequencyEvent = nil;
	self.baseTouch = nil;
	simpleTouchFrequencyEvent = nil;
	[self drawButtons:buttonsTurnOn];
	[self hideButtonCountdown:CancelTimer selector:@selector(turnOnButtons)];
}

- (void)drawButtons:(buttonState)state
{
	static BOOL doubleArrowOSDrawn=FALSE,
	onOffDrawn=FALSE, infoButtonDrawn=FALSE,
	tuneBarOSDrawn=FALSE, grayTuneBarOSDrawn=FALSE,
	tuneBarWFDrawn=FALSE, grayTuneBarWFDrawn=FALSE,
	meterNumbersDrawn=FALSE, offAGCDrawn=FALSE,
	slowAGCDrawn=FALSE, fastAGCDrawn=FALSE,
	fileInfoDrawn=FALSE;
	static BOOL lockDrawn=FALSE;

	///////////////////////////////////////////////////////////////////////////////////////////
	// Wifi support changes
    static BOOL plusminusButtonsDrawn = FALSE;
	static BOOL wifiStatusButtonDrawn = FALSE;
	static BOOL centerFrequencyTextDrawn = FALSE;
	// Wifi support changes
	///////////////////////////////////////////////////////////////////////////////////////////

	if(state == buttonsRedraw)
	{
		SDR_DEBUGPRINT(("drawButtons: buttonsRedraw\n"));

		if(fileInfoDrawn)
		{
			[fileInfoTextLandscape removeFromSuperview];
			fileInfoDrawn = FALSE;
		}

		if(meterNumbersDrawn)
		{
			[meterNumberingOverlay removeFromSuperview];
			meterNumbersDrawn = FALSE;
		}

		if(infoButtonDrawn)
		{
			[infoButton removeFromSuperview];
			infoButtonDrawn = FALSE;
		}

		if(onOffDrawn)
		{
			[switchCtl removeFromSuperview];
			onOffDrawn = FALSE;
		}

		if(!defaultsWorkingCopy.wifiFunctionalityEnabled)
		{
			if(lockDrawn)
			{
				lockButton.hidden = TRUE;
				lockDrawn = FALSE;
			}
		}
		else
		{
			///////////////////////////////////////////////////////////////////////////////////////////
			// Wifi support changes
			if(plusminusButtonsDrawn)
			{
				plusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
				minusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
				plusminusButtonsDrawn = FALSE;
			}

			if(centerFrequencyTextDrawn)
			{
				[centerFrequencyText removeFromSuperview];
				centerFrequencyTextDrawn = FALSE;
			}

			if(wifiStatusButtonDrawn)
			{
				[wifiButton removeFromSuperview];
				[ipAddressText removeFromSuperview];
				wifiStatusButtonDrawn = FALSE;
			}
			// Wifi support changes
			///////////////////////////////////////////////////////////////////////////////////////////
		}

		if(tuneBarWFDrawn)
		{
			[tuneBarLandscapeOverlayWF removeFromSuperview];
			tuneBarWFDrawn = FALSE;
		}

		if(grayTuneBarWFDrawn)
		{
			[tuneBarLandscapeOverlayGrayWF removeFromSuperview];
			grayTuneBarWFDrawn = FALSE;
		}

		if(doubleArrowOSDrawn)
		{
			[doubleArrowOverlayLandscape removeFromSuperview];
			doubleArrowOSDrawn = FALSE;
		}

		if(tuneBarOSDrawn)
		{
			[tuneBarLandscapeOverlayOS removeFromSuperview];
			tuneBarOSDrawn = FALSE;
		}

		if(grayTuneBarOSDrawn)
		{
			[tuneBarLandscapeOverlayGrayOS removeFromSuperview];
			grayTuneBarOSDrawn = FALSE;
		}

		if(!defaultsWorkingCopy.wifiFunctionalityEnabled)
		{
			if((lockButton.state == UNLOCKED) && (buttonsAreOn == FALSE))
			{
				state = buttonsHide;
			}

			if((lockButton.state == UNLOCKED) && (buttonsAreOn == TRUE))
			{
				state = buttonsTurnOn;
			}

			if((lockButton.state == LOCKED) && (buttonsAreOn == FALSE))
			{
				state = buttonsUnknown;
			}

			if((lockButton.state == LOCKED) && (buttonsAreOn == TRUE))
			{
				state = buttonsLock;
			}
		}
		else
		{
			if(buttonsAreOn == FALSE)
			{
				state = buttonsHide;
			}
			else
			{
				state = buttonsTurnOn;
			}
		}
	}

	switch(state)
	{
		case buttonsUnknown:
		{
			SDR_DEBUGPRINT(("drawButtons: buttonsUnknown\n"));
		}
			break;

		case buttonsTurnOn: // draw all the active buttons, with none hidden or inactive
		{
			buttonsAreOn = TRUE;

			SDR_DEBUGPRINT(("drawButtons: buttonsTurnOn\n"));

			if(defaultsWorkingCopy.wifiFunctionalityEnabled)
			{
				///////////////////////////////////////////////////////////////////////////////////////////
				// Wifi support changes
				if(wifiStatusButtonDrawn)
				{
					[wifiButton removeFromSuperview];
					[ipAddressText removeFromSuperview];
					wifiStatusButtonDrawn = FALSE;
				}
				// Wifi support changes
				///////////////////////////////////////////////////////////////////////////////////////////
			}

			if(self.displayMode == DisplayModeWaterfall)
			{
				if(fileInfoDrawn)
				{
					[fileInfoTextLandscape removeFromSuperview];
					fileInfoDrawn = FALSE;
				}

				if(offAGCDrawn)
				{
					[agcOffOverlayLandscape removeFromSuperview];
					offAGCDrawn = FALSE;
				}

				if(slowAGCDrawn)
				{
					[agcSlowOverlayLandscape removeFromSuperview];
					slowAGCDrawn = FALSE;
				}

				if(fastAGCDrawn)
				{
					[agcFastOverlayLandscape removeFromSuperview];
					fastAGCDrawn = FALSE;
				}

				if(meterNumbersDrawn)
				{
					[meterNumberingOverlay removeFromSuperview];
					meterNumbersDrawn = FALSE;
				}

				if(grayTuneBarWFDrawn)
				{
					[tuneBarLandscapeOverlayGrayWF removeFromSuperview];
					grayTuneBarWFDrawn = FALSE;
				}

                if(defaultsWorkingCopy.wifiFunctionalityEnabled)
				{
					///////////////////////////////////////////////////////////////////////////////////////////
					// Wifi support changes
					if(plusminusButtonsDrawn)
					{
						plusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
						minusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
						plusminusButtonsDrawn = FALSE;
					}
					// Wifi support changes
					///////////////////////////////////////////////////////////////////////////////////////////
				}

				[self.view addSubview:tuneBarLandscapeOverlayWF];
				tuneBarWFDrawn = TRUE;
			}
			else
			{
				if(!fileInfoDrawn) // && (mixerController.mAudioMode == AudioModeDemonstration))
				{
					[self.view addSubview:fileInfoTextLandscape];
					fileInfoDrawn = TRUE;
				}

				if(grayTuneBarWFDrawn)
				{
					[tuneBarLandscapeOverlayGrayWF removeFromSuperview];
					grayTuneBarWFDrawn = FALSE;
				}

				if(tuneBarWFDrawn)
				{
					[tuneBarLandscapeOverlayWF removeFromSuperview];
					tuneBarWFDrawn = FALSE;
				}

				if(grayTuneBarOSDrawn)
				{
					[tuneBarLandscapeOverlayGrayOS removeFromSuperview];
					grayTuneBarOSDrawn = FALSE;
				}

				if(doubleArrowOSDrawn)
				{
					[doubleArrowOverlayLandscape removeFromSuperview];
					doubleArrowOSDrawn = FALSE;
				}

				[self.view addSubview:tuneBarLandscapeOverlayOS];
				tuneBarOSDrawn = TRUE;

				if(!meterNumbersDrawn)
				{
					[self.view addSubview:meterNumberingOverlay];
					meterNumbersDrawn = TRUE;
				}

                if(defaultsWorkingCopy.wifiFunctionalityEnabled)
				{
					///////////////////////////////////////////////////////////////////////////////////////////
					// Wifi support changes
					if(wifi.state != Disconnected)
					{
						if(!plusminusButtonsDrawn)
						{
							[self.view addSubview:plusButton];
							[self.view addSubview:minusButton];

							plusButton.hidden = FALSE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
							minusButton.hidden = FALSE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
							plusminusButtonsDrawn = TRUE;
						}
					}
					else
					{
						if(plusminusButtonsDrawn)
						{
							plusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
							minusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
							plusminusButtonsDrawn = FALSE;
						}
					}
					// Wifi support changes
					///////////////////////////////////////////////////////////////////////////////////////////
				}

				switch(rssiMeter.agc)
				{
					case AGC_OFF:
					{
						if(slowAGCDrawn)
						{
							[agcSlowOverlayLandscape removeFromSuperview];
							slowAGCDrawn = FALSE;
						}

						if(fastAGCDrawn)
						{
							[agcFastOverlayLandscape removeFromSuperview];
							fastAGCDrawn = FALSE;
						}

						if(!offAGCDrawn)
						{
							[self.view addSubview:agcOffOverlayLandscape];
							offAGCDrawn = TRUE;
						}
					}
						break;

					case AGC_SLOW:
					{
						if(offAGCDrawn)
						{
							[agcOffOverlayLandscape removeFromSuperview];
							offAGCDrawn = FALSE;
						}

						if(fastAGCDrawn)
						{
							[agcFastOverlayLandscape removeFromSuperview];
							fastAGCDrawn = FALSE;
						}

						if(!slowAGCDrawn)
						{
							[self.view addSubview:agcSlowOverlayLandscape];
							slowAGCDrawn = TRUE;
						}
					}
						break;

					case AGC_FAST:
					{
						if(offAGCDrawn)
						{
							[agcOffOverlayLandscape removeFromSuperview];
							offAGCDrawn = FALSE;
						}

						if(slowAGCDrawn)
						{
							[agcSlowOverlayLandscape removeFromSuperview];
							slowAGCDrawn = FALSE;
						}

						if(!fastAGCDrawn)
						{
							[self.view addSubview:agcFastOverlayLandscape];
							fastAGCDrawn = TRUE;
						}
					}
						break;
				}
			}

			if(!infoButtonDrawn)
			{
				[self.view addSubview:infoButton];
				infoButtonDrawn = TRUE;
			}

			if(!onOffDrawn)
			{
				[self.view addSubview:switchCtl];
				onOffDrawn = TRUE;
			}

            if(!defaultsWorkingCopy.wifiFunctionalityEnabled)
			{
				// Always put the lock button on top
				lockDrawn = TRUE;
				[self.view addSubview:lockButton];
				lockButton.hidden = FALSE;
			}
			else
			{
				///////////////////////////////////////////////////////////////////////////////////////////
				// Wifi support changes
				if(!centerFrequencyTextDrawn)
				{
					centerFrequencyText.textColor = (self.displayMode == DisplayModeWaterfall) ? [UIColor whiteColor]:[UIColor blackColor];
					[self.view addSubview:centerFrequencyText];
					centerFrequencyTextDrawn = TRUE;
				}

				if(!wifiStatusButtonDrawn)
				{
					[self.view addSubview:wifiButton];
					if(wifiButton.state != Disconnected) [self.view addSubview:ipAddressText];
					wifiStatusButtonDrawn = TRUE;
				}
				// Wifi support changes
				///////////////////////////////////////////////////////////////////////////////////////////
				///////////////////////////////////////////////////////////////////////////////////////////
				// Wifi support changes
				if(wifi.state != Disconnected)
				{
					if(!plusminusButtonsDrawn)
					{
						[self.view addSubview:plusButton];
						[self.view addSubview:minusButton];

						plusButton.hidden = FALSE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
						minusButton.hidden = FALSE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
						plusminusButtonsDrawn = TRUE;
					}
				}
				else
				{
					if(plusminusButtonsDrawn)
					{
						plusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
						minusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
						plusminusButtonsDrawn = FALSE;
					}
				}
				// Wifi support changes
				///////////////////////////////////////////////////////////////////////////////////////////
			}
		}
			break;

		case buttonsHide: // hide any buttons lying on the tune bar, and draw colored tune bar with double arrow
		{
			if(lockButton) lockButton.state = UNLOCKED; // buttons should never be hidden and locked!
			buttonsAreOn = FALSE;

			SDR_DEBUGPRINT(("drawButtons: buttonsHide\n"));

			if(infoButtonDrawn)
			{
				[infoButton removeFromSuperview];
				infoButtonDrawn = FALSE;
			}

			if(onOffDrawn)
			{
				[switchCtl removeFromSuperview];
				onOffDrawn = FALSE;
			}

            if(!defaultsWorkingCopy.wifiFunctionalityEnabled)
			{
				if(lockDrawn)
				{
					lockButton.hidden = TRUE;
					lockDrawn = FALSE;
				}
			}
			else
			{
				///////////////////////////////////////////////////////////////////////////////////////////
				// Wifi support changes
				if(wifiStatusButtonDrawn)
				{
					[wifiButton removeFromSuperview];
					[ipAddressText removeFromSuperview];
					wifiStatusButtonDrawn = FALSE;
				}

				if(plusminusButtonsDrawn)
				{
					plusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
					minusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
					plusminusButtonsDrawn = FALSE;
				}

				if(centerFrequencyTextDrawn)
				{
					[centerFrequencyText removeFromSuperview];
					centerFrequencyTextDrawn = FALSE;
				}
				// Wifi support changes
				///////////////////////////////////////////////////////////////////////////////////////////
			}

			if(self.displayMode == DisplayModeWaterfall)
			{
				if(fileInfoDrawn)
				{
					[fileInfoTextLandscape removeFromSuperview];
					fileInfoDrawn = FALSE;
				}

				if(offAGCDrawn)
				{
					[agcOffOverlayLandscape removeFromSuperview];
					offAGCDrawn = FALSE;
				}

				if(slowAGCDrawn)
				{
					[agcSlowOverlayLandscape removeFromSuperview];
					slowAGCDrawn = FALSE;
				}

				if(fastAGCDrawn)
				{
					[agcFastOverlayLandscape removeFromSuperview];
					fastAGCDrawn = FALSE;
				}

				if(meterNumbersDrawn)
				{
					[meterNumberingOverlay removeFromSuperview];
					meterNumbersDrawn = FALSE;
				}

				if(grayTuneBarWFDrawn)
				{
					[tuneBarLandscapeOverlayGrayWF removeFromSuperview];
					grayTuneBarWFDrawn = FALSE;
				}

				if(!tuneBarWFDrawn)
				{
					[self.view addSubview:tuneBarLandscapeOverlayWF];
					tuneBarWFDrawn = TRUE;
				}
			}
			else
			{
				if(!fileInfoDrawn) // && (mixerController.mAudioMode == AudioModeDemonstration))
				{
					[self.view addSubview:fileInfoTextLandscape];
					fileInfoDrawn = TRUE;
				}

				if(grayTuneBarOSDrawn)
				{
					[tuneBarLandscapeOverlayGrayOS removeFromSuperview];
					grayTuneBarOSDrawn = FALSE;
				}

				if(!meterNumbersDrawn)
				{
					[self.view addSubview:meterNumberingOverlay];
					meterNumbersDrawn = TRUE;
				}

				if(!tuneBarOSDrawn)
				{
					[self.view addSubview:tuneBarLandscapeOverlayOS];
					tuneBarOSDrawn = TRUE;
				}

				if(!doubleArrowOSDrawn)
				{
					[self.view addSubview:doubleArrowOverlayLandscape];
					doubleArrowOSDrawn = TRUE;
				}
			}
		}
			break;

		case buttonsLock: // draw only the locked lock button, and gray tune bar
		{
			if(lockButton) lockButton.state = LOCKED; // lock should always show the locked image when buttons are locked
			buttonsAreOn = TRUE;

			SDR_DEBUGPRINT(("drawButtons: buttonsLock\n"));

			if(grayTuneBarWFDrawn)
			{
				[tuneBarLandscapeOverlayGrayWF removeFromSuperview];
				grayTuneBarWFDrawn = FALSE;
			}

			if(tuneBarWFDrawn)
			{
				[tuneBarLandscapeOverlayWF removeFromSuperview];
				tuneBarWFDrawn = FALSE;
			}

            if(defaultsWorkingCopy.wifiFunctionalityEnabled)
			{
				///////////////////////////////////////////////////////////////////////////////////////////
				// Wifi support changes
				if(wifiStatusButtonDrawn)
				{
					[wifiButton removeFromSuperview];
					[ipAddressText removeFromSuperview];
					wifiStatusButtonDrawn = FALSE;
				}

				if(plusminusButtonsDrawn)
				{
					plusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
					minusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
					plusminusButtonsDrawn = FALSE;
				}

				if(centerFrequencyTextDrawn)
				{
					[centerFrequencyText removeFromSuperview];
					centerFrequencyTextDrawn = FALSE;
				}
				// Wifi support changes
				///////////////////////////////////////////////////////////////////////////////////////////
			}

			if(infoButtonDrawn)
			{
				[infoButton removeFromSuperview];
				infoButtonDrawn = FALSE;
			}

			if(onOffDrawn)
			{
				[switchCtl removeFromSuperview];
				onOffDrawn = FALSE;
			}

			if(self.displayMode == DisplayModeWaterfall)
			{
				if(fileInfoDrawn)
				{
					[fileInfoTextLandscape removeFromSuperview];
					fileInfoDrawn = FALSE;
				}

				if(offAGCDrawn)
				{
					[agcOffOverlayLandscape removeFromSuperview];
					offAGCDrawn = FALSE;
				}

				if(slowAGCDrawn)
				{
					[agcSlowOverlayLandscape removeFromSuperview];
					slowAGCDrawn = FALSE;
				}

				if(fastAGCDrawn)
				{
					[agcFastOverlayLandscape removeFromSuperview];
					fastAGCDrawn = FALSE;
				}

				if(meterNumbersDrawn)
				{
					[meterNumberingOverlay removeFromSuperview];
					meterNumbersDrawn = FALSE;
				}

				if(tuneBarWFDrawn)
				{
					[tuneBarLandscapeOverlayWF removeFromSuperview];
					tuneBarWFDrawn = FALSE;
				}

				if(!grayTuneBarWFDrawn)
				{
					[self.view addSubview:tuneBarLandscapeOverlayGrayWF];
					grayTuneBarWFDrawn = TRUE;
				}
			}
			else
			{
				if(!fileInfoDrawn) // && (mixerController.mAudioMode == AudioModeDemonstration))
				{
					[self.view addSubview:fileInfoTextLandscape];
					fileInfoDrawn = TRUE;
				}

				if(!meterNumbersDrawn)
				{
					[self.view addSubview:meterNumberingOverlay];
					meterNumbersDrawn = TRUE;
				}

				if(doubleArrowOSDrawn)
				{
					[doubleArrowOverlayLandscape removeFromSuperview];
					doubleArrowOSDrawn = FALSE;
				}

				if(tuneBarOSDrawn)
				{
					[tuneBarLandscapeOverlayOS removeFromSuperview];
					tuneBarOSDrawn = FALSE;
				}

				if(!grayTuneBarOSDrawn)
				{
					[self.view addSubview:tuneBarLandscapeOverlayGrayOS];
					grayTuneBarOSDrawn = TRUE;
				}
			}

            if(!defaultsWorkingCopy.wifiFunctionalityEnabled)
			{
				// Always put the lock on top
				[self.view addSubview:lockButton];
				lockDrawn = TRUE;
				lockButton.hidden = FALSE;
			}
			else
			{
				///////////////////////////////////////////////////////////////////////////////////////////
				// Wifi support changes
				if(!wifiStatusButtonDrawn)
				{
					[self.view addSubview:wifiButton];
					if(wifiButton.state != Disconnected) [self.view addSubview:ipAddressText];
					wifiStatusButtonDrawn = TRUE;
				}
				// Wifi support changes
				///////////////////////////////////////////////////////////////////////////////////////////
			}
		}
			break;

		default: // turn off everything
		{
			SDR_DEBUGPRINT(("drawButtons: buttonsAllOff\n"));

			if(fileInfoDrawn)
			{
				[fileInfoTextLandscape removeFromSuperview];
				fileInfoDrawn = FALSE;
			}

			if(infoButtonDrawn)
			{
				[infoButton removeFromSuperview];
				infoButtonDrawn = FALSE;
			}

			if(onOffDrawn)
			{
				[switchCtl removeFromSuperview];
				onOffDrawn = FALSE;
			}

			///////////////////////////////////////////////////////////////////////////////////////////
			// Wifi support changes
            if(plusminusButtonsDrawn)
            {
				plusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
				minusButton.hidden = TRUE; // we must hide, rather than remove buttons to avoid losing touches they might be tracking
                plusminusButtonsDrawn = FALSE;
            }

			if(centerFrequencyTextDrawn)
			{
				[centerFrequencyText removeFromSuperview];
				centerFrequencyTextDrawn = FALSE;
			}

			if(wifiStatusButtonDrawn)
			{
				[wifiButton removeFromSuperview];
				[ipAddressText removeFromSuperview];
				wifiStatusButtonDrawn = FALSE;
			}
			// Wifi support changes
			///////////////////////////////////////////////////////////////////////////////////////////

			if(lockDrawn)
			{
				lockButton.hidden = TRUE;
				lockDrawn = FALSE;
			}

			if(tuneBarWFDrawn)
			{
				[tuneBarLandscapeOverlayWF removeFromSuperview];
				tuneBarWFDrawn = FALSE;
			}

			if(grayTuneBarWFDrawn)
			{
				[tuneBarLandscapeOverlayGrayWF removeFromSuperview];
				grayTuneBarWFDrawn = FALSE;
			}

			if(doubleArrowOSDrawn)
			{
				[doubleArrowOverlayLandscape removeFromSuperview];
				doubleArrowOSDrawn = FALSE;
			}

			if(tuneBarOSDrawn)
			{
				[tuneBarLandscapeOverlayOS removeFromSuperview];
				tuneBarOSDrawn = FALSE;
			}

			if(grayTuneBarOSDrawn)
			{
				[tuneBarLandscapeOverlayGrayOS removeFromSuperview];
				grayTuneBarOSDrawn = FALSE;
			}

			if(meterNumbersDrawn)
			{
				[meterNumberingOverlay removeFromSuperview];
				meterNumbersDrawn = FALSE;
			}

			if(offAGCDrawn)
			{
				[agcOffOverlayLandscape removeFromSuperview];
				offAGCDrawn = FALSE;
			}

			if(slowAGCDrawn)
			{
				[agcSlowOverlayLandscape removeFromSuperview];
				slowAGCDrawn = FALSE;
			}

			if(fastAGCDrawn)
			{
				[agcFastOverlayLandscape removeFromSuperview];
				fastAGCDrawn = FALSE;
			}
		}
			break;
	}
}


// ARC: handle last-instant cleanup tasks just prior to app shutdown - things that might otherwise have happened in dealloc
- (void)dealloc
{
	if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		SDR_DEBUGPRINT(("iPad! dealloc\n"));
		if(iSDRpopoverController != nil)
		{
			if(_popoverActive == TRUE)
			{
                [[iSDRpopoverController presentingViewController] dismissViewControllerAnimated:FALSE completion:NULL];
			}
		}
	}

	if(rssiMeter) rssiMeter.au = nil;

	free(oscilLine);
	free(fftData);
}



- (void)setFFTData:(int32_t *)FFTDATA length:(NSUInteger)LENGTH
{
	//	SDR_DEBUGPRINT(("LENGTH=%d fftLength=%d\n", LENGTH, fftLength));
	if(LENGTH != fftLength)
	{
		fftLength = LENGTH;
		fftData = (SInt32 *)(realloc(fftData, LENGTH * sizeof(SInt32)));
	}
	memmove(fftData, FFTDATA, fftLength * sizeof(SInt32));

	//	for(int i=0; i<fftLength; i++)
	//	{
	//		fftData[i] /= defaultsWorkingCopy.signalScaleFactor;
	//	}

	hasNewFFTData = drawBuffersInitialized;
}


- (void)fadeFFTData:(int32_t *)FFTDATA length:(NSUInteger)LENGTH
{
	if(LENGTH != fftLength)
	{
		fftLength = LENGTH;
		fftData = (SInt32 *)(calloc(LENGTH, sizeof(SInt32)));
	}

	memset(fftData, 0, fftLength * sizeof(SInt32));

	hasNewFFTData = drawBuffersInitialized;
}


- (void)setupViewForOscilloscope
{
	if(semiLogGridOverlay == nil)
	{
		[self createSemiLogGridOverlay:([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad)];
	}

	if(linearGridOverlay == nil)
	{
		[self createLinearGridOverlay];
	}

	if(signalScopeGridOverlay == nil)
	{
		[self createSignalScopeGridOverlay:([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad)];
	}

	[self drawButtons:buttonsRedraw];
	SDR_DEBUGPRINT(("buttonsRedraw6\n"));

	initted_oscilloscope = YES;

	SDR_DEBUGPRINT(("calling showMeter2!\n"));
	[rssiMeter showMeter:FALSE];
}


// Sets graphics textures to zero, initializing signal display lines to show zero signal.
- (void)clearTextures
{
	SDR_DEBUGPRINT(("clearTextures\n"));
	bzero(texBitBuffer, sizeof(UInt32) * texBitBufferSize);

	SpectrumLinkedTexture *curTex;

	for(curTex = firstTex; curTex; curTex = curTex->nextTex)
	{
		glBindTexture(GL_TEXTURE_2D, curTex->texName);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, texBitBufferSize, 0, GL_RGBA, GL_UNSIGNED_BYTE, texBitBuffer);
	}
}


// Allocates memory for holding spectrum graphics (FFT and waterfall)
// Should only be called once, otherwise memory leaks can result.
- (void)setupViewForSpectrum
{
	SDR_DEBUGPRINT(("setupViewForSpectrum\n"));
	glClearColor(0., 0., 0., 0.);

	spectrumRect = CGRectMake(0., 0., displayLandscapeWidth, displayLandscapeHeight-tunebarVertHeightOffset);

	// The bit buffer for the texture needs to be 512 pixels, because OpenGL textures are powers of
	// two in either dimensions. Our texture is drawing a strip of 300 vertical pixels on the screen,
	// so we need to step up to 512 (the nearest power of 2 greater than 300) for iPod/iPhone.
	texBitBuffer = (UInt32 *)(malloc(sizeof(UInt32) * texBitBufferSize));

	// Clears the view with black
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);

	NSUInteger texCount = ceil(CGRectGetWidth(spectrumRect) / (CGFloat)waterfallStepSize);
	GLuint *texNames;

	texNames = (GLuint *)(malloc(sizeof(GLuint) * texCount));
	glGenTextures((int)texCount, texNames);

	SpectrumLinkedTexture *curTex = NULL;
	firstTex = (SpectrumLinkedTexture *)(calloc(1, sizeof(SpectrumLinkedTexture)));
	firstTex->texName = texNames[0];
	curTex = firstTex;

	bzero(texBitBuffer, sizeof(UInt32) * texBitBufferSize);

	glBindTexture(GL_TEXTURE_2D, curTex->texName);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

	for(int i=1; i<texCount; i++)
	{
		curTex->nextTex = (SpectrumLinkedTexture *)(calloc(1, sizeof(SpectrumLinkedTexture)));
		curTex = curTex->nextTex;
		curTex->texName = texNames[i];

		glBindTexture(GL_TEXTURE_2D, curTex->texName);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

		if(i == texCount-1) lastTex = curTex;
	}

	// Enable use of the texture
	glEnable(GL_TEXTURE_2D);
	// Set a blending function to use
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
	// Enable blending
	glEnable(GL_BLEND);

	initted_spectrum = YES;
	//	initted_oscilloscope = NO;

	free(texNames);

	[self drawButtons:buttonsRedraw];
	SDR_DEBUGPRINT(("buttonsRedraw5\n"));
}


- (void)setupDrawBuffers
{
	static int drawBufferLen_alloced = 0;

	// The draw buffer is used to hold a copy of the most recent PCM data to be drawn
	// Typically the buffer size for FFT spectrum and waterfall will differ, and this
	// method will adjust the size appropriately.
	if(drawBufferLen != drawBufferLen_alloced)
	{
		int drawBuffer_i;

		// Allocate our draw buffer if needed
		if(drawBufferLen_alloced == 0)
			for(drawBuffer_i=0; drawBuffer_i<kMaxNumDrawBuffers; drawBuffer_i++)
				drawBuffers[drawBuffer_i] = NULL;

		// realloc drawBuffers and fill with zeros
		for(drawBuffer_i=0; drawBuffer_i<kMaxNumDrawBuffers; drawBuffer_i++)
		{
			drawBuffers[drawBuffer_i] = (SInt8 *)realloc(drawBuffers[drawBuffer_i], drawBufferLen);
			bzero(drawBuffers[drawBuffer_i], drawBufferLen);

			SDR_DEBUGPRINT(("dB[%d] size=%d\n", drawBuffer_i, drawBufferLen));
		}

		drawBufferLen_alloced = drawBufferLen;
		drawBuffersInitialized = TRUE;
		resetOscilLine = YES;
	}
}


- (void)readRawPCMOscope
{
	// SDR_DEBUGPRINT(("^\n"));
	if(fftBufferManager->getCopyRawPCM() == FALSE)
	{
		AudioBuffer* RawPCMData;
		UInt32 NumberFrames;

		RawPCMData = fftBufferManager->getOscilloBuff();
		NumberFrames = RawPCMData->mDataByteSize / sizeof(int32_t);

		// The draw buffer is used to hold a copy of the most recent PCM data to be drawn on the oscilloscope
		[self setupDrawBuffers];

		{
			SInt8 *data_ptr = (SInt8 *)(RawPCMData->mData);

			for(int i=0; i<NumberFrames; i++)
			{
				if((i+drawBufferIdx) >= drawBufferLen)
				{
					{
						// Cycle the lines in our draw buffer so that they age and fade. The oldest line is discarded.
						int drawBuffer_i;
						for (drawBuffer_i=(numDrawBuffers - 2); drawBuffer_i>=0; drawBuffer_i--)
							memmove(drawBuffers[drawBuffer_i + 1], drawBuffers[drawBuffer_i], drawBufferLen);
					}
					drawBufferIdx = -i;
				}

				drawBuffers[0][i + drawBufferIdx] = data_ptr[2];
				data_ptr += 4;
			}

			drawBufferIdx += NumberFrames;
		}

		fftBufferManager->setCopyRawPCM(TRUE);
	}
}


// Draw FFT view spectrum lines or oscilloscope waveform lines
- (void)drawOscilloscope:(BOOL)drawLines
{
	int glPushCount = 0;

	if(drawLines || !displayInitialized)
	{
		displayInitialized = TRUE;

		glClear(GL_COLOR_BUFFER_BIT);

		//	glBlendFunc(GL_SRC_ALPHA, GL_ONE);
		glBlendFunc(GL_ONE, GL_ONE);

		glEnable(GL_TEXTURE_2D);
		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);

		if(drawLines)
		{
			if(displayMode == DisplayModeOscilloscopeWaveform)
			{
				[self readRawPCMOscope];
			}
			else
			{
				if(fftBufferManager->ComputeFFT(&l_SprectrumData, &l_SprectrumDataSize))
				{
					[self setFFTData:l_SprectrumData length:l_SprectrumDataSize];
				}
				else
				{
					hasNewFFTData = NO;
				}

				if(hasNewFFTData)
				{
					int y, maxY;
					maxY = drawBufferLen;

					for (y=0; y<maxY; y++)
					{
						CGFloat yFract = (CGFloat)y / (CGFloat)(maxY - 1);
						CGFloat fftIdx = yFract * ((CGFloat)fftLength-10);

						double fftIdx_i, fftIdx_f;
						fftIdx_f = modf(fftIdx, &fftIdx_i);

						SInt8 fft_l, fft_r;
						CGFloat fft_l_fl, fft_r_fl;
						CGFloat interpVal;

						fft_l = (fftData[(int)fftIdx_i] & 0xFF000000) >> 24;
						fft_r = (fftData[(int)fftIdx_i + 1] & 0xFF000000) >> 24;
						fft_l_fl = (CGFloat)(fft_l + 80) / 64.;
						fft_r_fl = (CGFloat)(fft_r + 80) / 64.;
						interpVal = fft_l_fl * (1. - fftIdx_f) + fft_r_fl * fftIdx_f;

						interpVal = CLAMP(0., interpVal, 1.);

						drawBuffers[0][y] = (interpVal * 120);
					}

					{
						// Cycle the lines in our draw buffer so that they age and fade. The oldest line is discarded.
						int drawBuffer_i;
						for (drawBuffer_i=(numDrawBuffers - 2); drawBuffer_i>=0; drawBuffer_i--)
							memmove(drawBuffers[drawBuffer_i + 1], drawBuffers[drawBuffer_i], drawBufferLen);
					}
				}
			}

			GLfloat *oscilLine_ptr;
			GLfloat max = drawBufferLen;
			SInt8 *drawBuffer_ptr;

			[self setupDrawBuffers];

			// Alloc an array for our oscilloscope line vertices
			if(resetOscilLine)
			{
				oscilLine = (GLfloat*)realloc(oscilLine, drawBufferLen * 2 * sizeof(GLfloat));
				resetOscilLine = NO;
			}

			glPushMatrix();
			glPushCount++;

			// Translate to the left side and vertical center of the screen, and scale so that the screen coordinates
			// go from 0 to 1 along the X, and -1 to 1 along the Y
			if(self.displayMode == DisplayModeOscilloscopeFFT)
			{
				//glTranslatef(0., displayLandscapeHeight - (gridHeight + tunebarVertHeightOffset), 0.);
				glTranslatef(0., fftSignalOffset, 0.);
				glScalef(displayLandscapeWidth, gridHeight, 1.);
			}
			else
			{
				glTranslatef(0., oscopeSignalOffset, 0.);
				glScalef(displayLandscapeWidth, oscopeMaxSignalHeight, 1.);
			}

			// Set up some GL state for our oscilloscope lines
			glDisable(GL_TEXTURE_2D);
			glDisableClientState(GL_TEXTURE_COORD_ARRAY);
			glDisableClientState(GL_COLOR_ARRAY);
			glDisable(GL_LINE_SMOOTH);
			glLineWidth(2.);

			int drawBuffer_i;
			// Draw a line for each stored line in our buffer (the lines are stored and fade over time)
			for(drawBuffer_i=0; drawBuffer_i<numDrawBuffers; drawBuffer_i++)
			{
				if (!drawBuffers[drawBuffer_i]) continue;

				oscilLine_ptr = oscilLine;
				drawBuffer_ptr = drawBuffers[drawBuffer_i];

				GLfloat i;
				// Fill our vertex array with points
				for (i=0.; i<max; i=i+1.)
				{
					*oscilLine_ptr++ = i/max;
					*oscilLine_ptr++ = (Float32)(*drawBuffer_ptr++) / 128.;
				}

				// If we're drawing the newest line, draw it in solid green. Otherwise, draw it in a faded green.
				if (drawBuffer_i == 0)
					glColor4f(0., 1., 0., 1.);
				else
					glColor4f(0., 1., 0., (.24 * (1. - ((GLfloat)drawBuffer_i / (GLfloat)numDrawBuffers))));

				// Set up vertex pointer,
				glVertexPointer(2, GL_FLOAT, 0, oscilLine);

				// and draw the line.
				glDrawArrays(GL_LINE_STRIP, 0, drawBufferLen);

			}
		}

		while(glPushCount--)
		{
			glPopMatrix();
		}
	}
}


// Cycle through linked textures for waterfall
- (void)renderFFTToTex
{
	SpectrumLinkedTexture *newFirst;
	newFirst = lastTex;
	newFirst->nextTex = firstTex;
	firstTex = newFirst;

	SpectrumLinkedTexture *thisTex = firstTex;
	BOOL done=FALSE;

	do
	{
		if((thisTex->nextTex) == lastTex)
		{
			thisTex->nextTex = NULL;
			firstTex->texName = thisTex->texName;
			lastTex = thisTex;
			done = TRUE;
		}

		thisTex = thisTex->nextTex;
	}
	while(!done);

	UInt32 *texBitBuffer_ptr = texBitBuffer;

	int numLevels = sizeof(colorLevels) / sizeof(GLfloat) / 5;

	int y, maxY;
	maxY = CGRectGetHeight(spectrumRect);
	for(y=0; y<maxY; y++)
	{
		CGFloat yFract = (CGFloat)y / (CGFloat)(maxY - 1);
		CGFloat fftIdx = yFract * ((CGFloat)fftLength-10);

		double fftIdx_i, fftIdx_f;
		fftIdx_f = modf(fftIdx, &fftIdx_i);

		SInt8 fft_l, fft_r;
		CGFloat fft_l_fl, fft_r_fl;
		CGFloat interpVal;

		fft_l = (fftData[(int)fftIdx_i] & 0xFF000000) >> 24;
		fft_r = (fftData[(int)fftIdx_i + 1] & 0xFF000000) >> 24;
		fft_l_fl = (CGFloat)(fft_l + 80) / 64.;
		fft_r_fl = (CGFloat)(fft_r + 80) / 64.;
		interpVal = fft_l_fl * (1. - fftIdx_f) + fft_r_fl * fftIdx_f;

		interpVal = sqrt(CLAMP(0., interpVal, 1.));

		UInt32 newPx = 0xFF000000;

		int level_i;
		const GLfloat *thisLevel = colorLevels;
		const GLfloat *nextLevel = colorLevels + 5;
		for(level_i=0; level_i<(numLevels-1); level_i++)
		{
			if( (*thisLevel <= interpVal) && (*nextLevel >= interpVal) )
			{
				double fract = (interpVal - *thisLevel) / (*nextLevel - *thisLevel);
				newPx =
				((UInt8)(255. * linearInterp(thisLevel[1], nextLevel[1], fract)) << 24)
				|
				((UInt8)(255. * linearInterp(thisLevel[2], nextLevel[2], fract)) << 16)
				|
				((UInt8)(255. * linearInterp(thisLevel[3], nextLevel[3], fract)) << 8)
				|
				(UInt8)(255. * linearInterp(thisLevel[4], nextLevel[4], fract))
				;
				break;
			}

			thisLevel += 5;
			nextLevel += 5;
		}

		*texBitBuffer_ptr++ = newPx;
	}

	glBindTexture(GL_TEXTURE_2D, firstTex->texName);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, texBitBufferSize, 0, GL_RGBA, GL_UNSIGNED_BYTE, texBitBuffer);

	hasNewFFTData = NO;
}


- (BOOL)drawEnabled
{
	// Checking the application state eliminates a crash that can occur during Open GL rendering
	// if the app is not currently active. This crash was first seen while using iOS 7.0 and streaming
	// audio using Air Play.
	//	BOOL result = [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
	BOOL result = ![mixerController audioBusy:AudioReadState];
	return result;
}

- (void)drawViewWithAnimation
{
	fileInfoTextLandscape.text = [self getFileInfoText];

	if((displayMode == DisplayModeOscilloscopeWaveform) || (displayMode == DisplayModeOscilloscopeFFT))
	{
		if(!initted_oscilloscope)
		{
			[self setupViewForOscilloscope];
		}

		[self drawOscilloscope:TRUE];
	}
	else if(displayMode == DisplayModeWaterfall)
	{
		if(!initted_spectrum)
		{
			[self setupViewForSpectrum];
		}

		[self drawWaterfallSpectrum:TRUE];
	}

	return;
}

// Delegate function called by EAGLView.mm
- (void)drawView
{
	fileInfoTextLandscape.text = [self getFileInfoText];

	if((displayMode == DisplayModeOscilloscopeWaveform) || (displayMode == DisplayModeOscilloscopeFFT))
	{
		if(!initted_oscilloscope)
		{
			[self setupViewForOscilloscope];
		}

		[self drawOscilloscope:FALSE];
	}
	else if(displayMode == DisplayModeWaterfall)
	{
		if(!initted_spectrum)
		{
			[self setupViewForSpectrum];
		}

		[self drawWaterfallSpectrum:FALSE];
	}

	return;
}


- (void)drawWaterfallSpectrum:(BOOL)drawData
{
	if(drawData || !displayInitialized)
	{
		int glPushCount = 0;

		displayInitialized = TRUE;

		//	SDR_DEBUGPRINT(("drawWaterfallSpectrum\n"));

		// Clear the view
		glClear(GL_COLOR_BUFFER_BIT);

		if(fftBufferManager->ComputeFFT(&l_SprectrumData, &l_SprectrumDataSize))
		{
			[self setFFTData:l_SprectrumData length:l_SprectrumDataSize];
		}
		else
			hasNewFFTData = NO;

		if(hasNewFFTData) [self renderFFTToTex];

		glClear(GL_COLOR_BUFFER_BIT);

		glEnable(GL_TEXTURE);
		glEnable(GL_TEXTURE_2D);

		glPushMatrix();
		glPushCount++;

		glTranslatef(spectrumRect.origin.x + spectrumRect.size.width, spectrumRect.origin.y, 0.);

		GLfloat quadCoords[] =
		{
			0., 0.,
			(GLfloat)waterfallStepSize, 0.,
			0., (float)texBitBufferSize,
			(GLfloat)waterfallStepSize, (GLfloat)texBitBufferSize,
		};

		GLshort texCoords[] =
		{
			0, 0,
			1, 0,
			0, 1,
			1, 1,
		};

		glVertexPointer(2, GL_FLOAT, 0, quadCoords);
		glEnableClientState(GL_VERTEX_ARRAY);
		glTexCoordPointer(2, GL_SHORT, 0, texCoords);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);

		glColor4f(1., 1., 1., 1.);

		SpectrumLinkedTexture *thisTex;
		glPushMatrix();
		glPushCount++;

		for(thisTex = firstTex; thisTex; thisTex = thisTex->nextTex)
		{
			glTranslatef(-(waterfallStepSize), 0., 0.);
			glBindTexture(GL_TEXTURE_2D, thisTex->texName);
			glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		}

		while(glPushCount--)
		{
			glPopMatrix();
		}

		glFlush();
	}
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSArray *t = [[event allTouches] allObjects];
	int touchCount = (int)[[event allTouches] count];
	UITouch *touch = [touches anyObject];

	if(defaultsWorkingCopy.wifiFunctionalityEnabled || (lockButton.state == UNLOCKED)) // don't allow freq change when screen is locked
	{
		if(touchCount == 1)
		{
			SDR_DEBUGPRINT(("single touch...\n"));

			touchWithoutFrequencyOverlay = !frequencyOverlayLandscape.isVisible;
			preTouchFrequencySetting = fftBufferManager->getCenterFrequency();

			if(self.displayMode == DisplayModeOscilloscopeFFT)
			{
				if(CGRectContainsPoint(cursorRectangleOS, [touch locationInView:self.eaglView]))
				{
					cursorTapCount++;
					SDR_DEBUGPRINT(("Touched the cursor %ld times\n", (long)cursorTapCount));
				}
				else
				{
					cursorTapCount = 0;
					SDR_DEBUGPRINT(("1. Cursor touch count reset to %ld\n", (long)cursorTapCount));
				}
			}
			else if(self.displayMode == DisplayModeWaterfall)
			{
				if(CGRectContainsPoint(cursorRectangleWF, [touch locationInView:self.eaglView]))
				{
					cursorTapCount++;
					SDR_DEBUGPRINT(("Touched the cursor %ld times\n", (long)cursorTapCount));
				}
				else
				{
					cursorTapCount = 0;
					SDR_DEBUGPRINT(("2. Cursor touch count reset to %ld\n", (long)cursorTapCount));
				}
			}

			self.baseTouch = nil;

			//The first touch is considered to be the stationary finger - the next touch sets the frequency
			UITouch* firstTouch = [t objectAtIndex:0];

			if(self.displayMode == DisplayModeWaterfall)
			{
				if(CGRectContainsPoint(tuneBarWFRectangle, [touch locationInView:self.eaglView])) // tune bar touched
				{
					if(windowBehavior != FrequencyWindowLockMode) // prevent cursor movements in FreqWindowLockMode
					{
						self.baseTouch = firstTouch;
						//[self.eaglView disableLayout];
						slideFrequencyEvent = event;
						slideFrequencyStartLoc = [self getVerticalLocation:baseTouch];

						if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
						{
							[self drawFrequencyOverlay];
							[self drawButtons:buttonsTurnOn];
							[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];
						}
						else
						{
							[self drawButtons:buttonsHide];
							[self hideFreqOverlay];
						}
					}
	///////////////////////////////////////////////////////////////////////////////////////////
	// Wifi support changes
					else // if(windowBehavior == FrequencyWindowLockMode)
					{
#ifdef WIFI_DEBUG
						// Allow testing without connection
						if((wifi.state & SocketEstablished) || (wifi.state == Searching))
#else
							if(wifi.state & SocketEstablished)
#endif
							{
								self.baseTouch = firstTouch;
								//[self.eaglView disableLayout];
								slideFrequencyEvent = event;
								slideFrequencyStartLoc = [self getVerticalLocation:baseTouch];

								if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
								{
									[self drawFrequencyOverlay];
									[self drawButtons:buttonsTurnOn];
									[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];
								}
								else
								{
									[self drawButtons:buttonsHide];
									[self hideFreqOverlay];
								}
							}
					}
	// Wifi support changes
	///////////////////////////////////////////////////////////////////////////////////////////
				}
				else
				{
					if(defaultsWorkingCopy.simpleTouchMode)
					{
						if(CGRectContainsPoint(gridRectangleWF,  [touch locationInView:self.eaglView]) && // grid touched in simpleTune mode
						   !CGRectContainsPoint(freqOverlayRectangle, [touch locationInView:self.eaglView]))
						{
							if(windowBehavior != FrequencyWindowLockMode) // prevent cursor movements in FreqWindowLockMode
							{
								self.baseTouch = firstTouch;
								simpleTouchFrequencyEvent = event;
								slideFrequencyEvent = event;
								[self drawBandwidthOverlay:baseTouch edgeReached:FALSE doErase:FALSE useFrequency:-1.];
								[self drawFrequencyOverlay];

								[self drawButtons:buttonsTurnOn];
								[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];
							}
							///////////////////////////////////////////////////////////////////////////////////////////
							// Wifi support changes
							else // if(windowBehavior == FrequencyWindowLockMode)
							{
								self.baseTouch = firstTouch;
								simpleTouchFrequencyEvent = event;
								slideFrequencyEvent = event;
								slideFrequencyStartLoc = [self getHorizontalLocation:baseTouch];
								frequencyAtStartOfSlideEvent = defaultsWorkingCopy.centerFrequency;
								totalSlideSinceStartOfSlideEvent = 0.;
							}
							// Wifi support changes
							///////////////////////////////////////////////////////////////////////////////////////////
						}
					}

					[self drawFrequencyOverlay];
					[self drawButtons:buttonsTurnOn];
					[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];
				}
			}
			else
			{
				if(CGRectContainsPoint(tuneBarOSRectangle, [touch locationInView:self.eaglView])) // tune bar touched
				{
					if(windowBehavior != FrequencyWindowLockMode) // prevent cursor movements in FreqWindowLockMode
					{
						[self hideButtonCountdown:CancelTimer selector:@selector(turnOnButtons)];

						self.baseTouch = firstTouch;
						[self.eaglView disableLayout];
						slideFrequencyEvent = event;
						slideFrequencyStartLoc = [self getHorizontalLocation:baseTouch];
						[self drawButtons:buttonsHide]; // buttons didn't get turned off because lock was touched initially
					}
	///////////////////////////////////////////////////////////////////////////////////////////
	// Wifi support changes
					else // if(windowBehavior == FrequencyWindowLockMode)
					{
#ifdef WIFI_DEBUG
						// Allow testing without connection
						if((wifi.state & SocketEstablished) || (wifi.state == Searching))
#else
							if(wifi.state & SocketEstablished)
#endif
							{
								baseTouch = firstTouch;
								[self.eaglView disableLayout];
								slideFrequencyEvent = event;
								slideFrequencyStartLoc = [self getHorizontalLocation:baseTouch];
								[self drawButtons:buttonsHide]; // buttons didn't get turned off because lock was touched initially
								frequencyAtStartOfSlideEvent = defaultsWorkingCopy.centerFrequency;
								totalSlideSinceStartOfSlideEvent = 0.;
							}
					}
	// Wifi support changes
	///////////////////////////////////////////////////////////////////////////////////////////
				}
				else if((defaultsWorkingCopy.simpleTouchMode) && (self.displayMode != DisplayModeOscilloscopeWaveform))
				{
					if(CGRectContainsPoint(gridRectangle,  [touch locationInView:self.eaglView])) // grid touched in simpleTune mode
					{
						if(windowBehavior != FrequencyWindowLockMode) // prevent cursor movements in FreqWindowLockMode
						{
							self.baseTouch = firstTouch;
							simpleTouchFrequencyEvent = event;
							slideFrequencyEvent = event;
							[self drawBandwidthOverlay:baseTouch edgeReached:FALSE doErase:FALSE useFrequency:-1.];
							[self drawFrequencyOverlay];
							[self drawButtons:buttonsHide];
							[self hideButtonCountdown:CancelTimer selector:@selector(turnOnButtons)];
						}
	///////////////////////////////////////////////////////////////////////////////////////////
	// Wifi support changes
						else // if(windowBehavior == FrequencyWindowLockMode)
						{
							self.baseTouch = firstTouch;
							simpleTouchFrequencyEvent = event;
							slideFrequencyEvent = event;
							slideFrequencyStartLoc = [self getHorizontalLocation:baseTouch];
							frequencyAtStartOfSlideEvent = defaultsWorkingCopy.centerFrequency;
							totalSlideSinceStartOfSlideEvent = 0.;
						}
	// Wifi support changes
	///////////////////////////////////////////////////////////////////////////////////////////
					}
				}
			}
		}
		else if(touchCount == 2)
		{
			SDR_DEBUGPRINT(("double touch...\n"));

			//The first touch is considered to be the stationary finger - the next touch sets the frequency
			UITouch* firstTouch = [t objectAtIndex:0];
			UITouch* secondTouch = [t objectAtIndex:1];

			if(baseTouch)
			{
				if(baseTouch != firstTouch)
				{
					if(baseTouch == secondTouch)
					{
						secondTouch = firstTouch;
						//							firstTouch = baseTouch;
					}
					else
					{
						self.baseTouch = firstTouch;
					}
				}
			}
			else
			{
				self.baseTouch = firstTouch;
			}

			if(self.displayMode == DisplayModeWaterfall)
			{
				if(CGRectContainsPoint(tuneBarWFRectangle, [touch locationInView:self.eaglView])) // tune bar touched
				{
					if(windowBehavior == SignalWindowLockMode) // prevent cursor movements in FreqWindowLockMode
					{
						[self.eaglView disableLayout];
						slideFrequencyEvent = event;
						slideFrequencyStartLoc = [self getVerticalLocation:baseTouch];
						[self drawButtons:buttonsHide];

						if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
						{
							[self drawFrequencyOverlay];
						}
						else
						{
							[self hideFreqOverlay];
						}
					}
				}
				else
				{
					[self drawFrequencyOverlay];
					[self drawButtons:buttonsTurnOn];
					[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];
				}
			}
			else
			{
				if(CGRectContainsPoint(tuneBarOSRectangle, [touch locationInView:self.eaglView])) // tune bar touched
				{
					if(windowBehavior == SignalWindowLockMode) // prevent cursor movements in FreqWindowLockMode
					{
						[self.eaglView disableLayout];
						slideFrequencyEvent = event;
						slideFrequencyStartLoc = [self getHorizontalLocation:baseTouch];
					}
				}
			}

			if(windowBehavior == SignalWindowLockMode) // prevent cursor movements in FreqWindowLockMode
			{
				if(baseTouch && slideFrequencyEvent)
				{
					self.slidingTouch = secondTouch;

					[self.eaglView disableLayout];
					twoTouchFrequencyEvent = event;

					if(self.displayMode == DisplayModeWaterfall)
					{
						//					if(CGRectContainsPoint(tuneBarWFRectangle, [baseTouch locationInView:self.eaglView])) // tune bar touched
						{
							[self drawBandwidthOverlay:slidingTouch edgeReached:FALSE doErase:FALSE useFrequency:-1.];
							[self drawFrequencyOverlay];
							[self hideButtonCountdown:StartTimer selector:@selector(hideFreqOverlay)];
						}
					}
					else
					{
						//					if(CGRectContainsPoint(tuneBarOSRectangle, [baseTouch locationInView:self.eaglView])) // tune bar touched
						{
							[self drawBandwidthOverlay:slidingTouch edgeReached:FALSE doErase:FALSE useFrequency:-1.];
							[self drawFrequencyOverlay];
							[self hideButtonCountdown:StartTimer selector:@selector(turnOnButtons)];

							// Cancel timer for turning buttons back on
							//						[self hideButtonCountdown:CancelTimer selector:@selector(turnOnButtons)];
						}
					}
				}
			}
		}
		else
		{
			if(self.displayMode == DisplayModeWaterfall)
			{
				[self drawFrequencyOverlay];
				[self hideButtonCountdown:StartTimer selector:@selector(hideFreqOverlay)];
			}
		}
	}

	SDR_DEBUGPRINT(("Base touch: %s\n", (baseTouch == nil) ? "Nil":"set"));

	return;
}


- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	int touchCount = (int)[[event allTouches] count];
	SDR_DEBUGPRINT(("touchesMoved: touch = %p\n", touch));

	if(touch.tapCount > 1) // avoid strange tap-and-slide conditions
	{
		return;
	}

	if(lockButton && (lockButton.state == LOCKED)) // no slide events are allowed while screen is locked
	{
		return;
	}

	if(event == slideFrequencyEvent)
	{
		// Allow a single sliding touch in the spectrum bar to slowly tune the frequency
		if(baseTouch)
		{
			[self hideButtonCountdown:CancelTimer selector:@selector(turnOnButtons)];
			CGFloat newlocation, distance;

			if(touchCount == 1)
			{
				SDR_DEBUGPRINT(("sliding 1-touch...\n"));
				NSArray* t = [[event allTouches] allObjects];
				UITouch* firstTouch = [t objectAtIndex:0]; // ensure firstTouch is valid (twoTouchFrequencyEvent could invalidate it)

				if(simpleTouchFrequencyEvent == event)
				{
					///////////////////////////////////////////////////////////////////////////////////////////
					// Wifi support changes
					if(windowBehavior == FrequencyWindowLockMode)
					{
						if(wifi.state & SocketEstablished)
						{
							if(self.displayMode == DisplayModeWaterfall)
							{
								newlocation = [self getVerticalLocation:firstTouch];
							}
							else
							{
								newlocation = [self getHorizontalLocation:firstTouch];
							}

							distance = slideFrequencyStartLoc - newlocation;
							float delta = distance * kHertzPerScreenElement;

							frequencyType freq = frequencyAtStartOfSlideEvent + totalSlideSinceStartOfSlideEvent + delta;

							if([wifi sendCommand_FA:freq stepmode:YES] == RadioMessageSent)
							{
								totalSlideSinceStartOfSlideEvent += delta;
								SDR_DEBUGPRINT(("sliding freq = %0.2f; start = %0.0f; now = %0.0f; delta = %0.2f; sum = %0.2f\n", freq, slideFrequencyStartLoc, newlocation, delta, totalSlideSinceStartOfSlideEvent));
								slideFrequencyStartLoc = newlocation;
							}
						}
					}
					// Wifi support changes
					///////////////////////////////////////////////////////////////////////////////////////////
					else
					{
						[self drawBandwidthOverlay:baseTouch edgeReached:FALSE doErase:FALSE useFrequency:-1.];
						[self drawFrequencyOverlay];
					}
				}
				else
				{
					if(buttonsAreOn)
					{
						[self drawButtons:buttonsHide]; // buttons didn't get turned off because lock was touched initially
					}

					if(self.displayMode == DisplayModeWaterfall)
					{
						newlocation = [self getVerticalLocation:firstTouch];
					}
					else
					{
						newlocation = [self getHorizontalLocation:firstTouch];
					}


					frequencyType freq;

					if((windowBehavior == FrequencyWindowLockMode) && (wifi.state & SocketEstablished))
					{
						static frequencyType holdFreq = defaultsWorkingCopy.centerFrequency;

						distance = newlocation - slideFrequencyStartLoc;
						double delta;

						if(distance < 0.)
						{
							delta = MIN(distance/5000., -0.0001);
						}
						else
						{
							delta = MAX(distance/5000., 0.0001);
						}

						//if center locked and wifi connected then send new frequency to connected device
						freq = holdFreq + delta;

						SDR_DEBUGPRINT(("sliding freq = %0.3lf (delta=%0.6lf) (holdFreq=%0.6lf)\n", freq, delta, holdFreq));

						RadioMessageResult result = [wifi sendCommand_FA:freq stepmode:YES];

						if(result == RadioMessageSent)
						{
							holdFreq = freq;
							slideFrequencyStartLoc = newlocation;
							defaultsWorkingCopy.centerFrequency = freq;
							[self drawFrequencyOverlay];

						}
						else if (result == RadioMessageDupe)
						{
							holdFreq = freq;
							slideFrequencyStartLoc = newlocation;
						}
					}
					else
					{
						distance = newlocation - slideFrequencyStartLoc;
						slideFrequencyStartLoc = newlocation;

						freq = fftBufferManager->getCenterFrequency();

						if(holdDefaults.operatingMode == CW_mode)
						{
							freq += (float)distance/6000.0; // slowly advance the frequency
						}
						else
						{
							freq += (float)distance/3000.0; // slowly advance the frequency
						}

						freq = CLAMP(0.0, freq, 1.0);
						//		SDR_DEBUGPRINT(("distance = %f   freq = %1.4f\n", distance, freq));

						fftBufferManager->setCenterFrequency(freq);
						[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:FALSE useFrequency:-1.];


						if(self.displayMode == DisplayModeOscilloscopeWaveform)
						{
							[self drawFrequencyOverlay];
						}

						if(self.displayMode == DisplayModeOscilloscopeFFT)
						{
							if(event == slideFrequencyEvent)
							{
								[self drawFrequencyOverlay];
							}
						}

						if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
						{
							if((self.displayMode) == DisplayModeWaterfall)
							{
								[self drawFrequencyOverlay];
							}
						}
					}
				}
			}
			else if((touchCount == 2) && twoTouchFrequencyEvent)
			{
				SDR_DEBUGPRINT(("sliding 2-touch...\n"));
				if(buttonsAreOn)
				{
					[self drawButtons:buttonsHide]; // buttons didn't get turned off because lock was touched initially
				}

				if(self.displayMode == DisplayModeWaterfall)
				{
					[self drawBandwidthOverlay:slidingTouch edgeReached:FALSE doErase:FALSE useFrequency:-1.];
					[self drawFrequencyOverlay];
					[self hideButtonCountdown:StartTimer selector:@selector(hideFreqOverlay)];
				}
				else // if(self.displayMode == DisplayModeOscilloscopeFFT)
				{
					[self drawBandwidthOverlay:slidingTouch edgeReached:FALSE doErase:FALSE useFrequency:-1.];
					[self drawFrequencyOverlay];
				}

			}
		}
	}

	return;
}


- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch* receivedTouch = nil;

	if(baseTouch)
	{
		if([touches containsObject:baseTouch])
		{
			receivedTouch = baseTouch;
		}
	}

	if(receivedTouch == nil)
	{
		receivedTouch = [touches anyObject];
	}

	SDR_DEBUGPRINT(("touchesEnded: touch = %p (baseTouch = %p)\n", receivedTouch, baseTouch));

	if((event == slideFrequencyEvent) || (event == simpleTouchFrequencyEvent)) // invalidate touch location
	{
		int touchCount = (int)[[event allTouches] count];
		NSArray *t = [[event allTouches] allObjects];

		if(twoTouchFrequencyEvent)
		{
			if(touchCount == 2) // two touches were in effect when one ended
			{
				UITouch* touch0 = [t objectAtIndex:0];
				UITouch* touch1 = [t objectAtIndex:1];

#ifdef SDR_DEBUG
				switch (baseTouch.phase)
				{
					case UITouchPhaseBegan:
						SDR_DEBUGPRINT(("baseTouch began!  "));
						break;
					case UITouchPhaseMoved:
						SDR_DEBUGPRINT(("baseTouch moved!  "));
						break;
					case UITouchPhaseStationary:
						SDR_DEBUGPRINT(("baseTouch stationary!  "));
						break;
					case UITouchPhaseEnded:
						SDR_DEBUGPRINT(("baseTouch ended!  "));
						break;
					case UITouchPhaseCancelled:
						SDR_DEBUGPRINT(("baseTouch cancelled!  "));
						break;
					default:
						break;
				}

				switch (touch0.phase)
				{
					case UITouchPhaseBegan:
						SDR_DEBUGPRINT(("touch0 began!  "));
						break;
					case UITouchPhaseMoved:
						SDR_DEBUGPRINT(("touch0 moved!  "));
						break;
					case UITouchPhaseStationary:
						SDR_DEBUGPRINT(("touch0 stationary!  "));
						break;
					case UITouchPhaseEnded:
						SDR_DEBUGPRINT(("touch0 ended!  "));
						break;
					case UITouchPhaseCancelled:
						SDR_DEBUGPRINT(("touch0 cancelled!  "));
						break;
					default:
						break;
				}

				switch (touch1.phase)
				{
					case UITouchPhaseBegan:
						SDR_DEBUGPRINT(("touch1 began!\n"));
						break;
					case UITouchPhaseMoved:
						SDR_DEBUGPRINT(("touch1 moved!\n"));
						break;
					case UITouchPhaseStationary:
						SDR_DEBUGPRINT(("touch1 stationary!\n"));
						break;
					case UITouchPhaseEnded:
						SDR_DEBUGPRINT(("touch1 ended!\n"));
						break;
					case UITouchPhaseCancelled:
						SDR_DEBUGPRINT(("touch1 cancelled!\n"));
						break;
					default:
						break;
				}
#endif

				// If baseTouch has ended then set baseTouch = any touch that hasn't ended, otherwise nil
				UITouch* remainingTouch = nil;

				if(touch0.phase == UITouchPhaseEnded)
				{
					remainingTouch = touch1;
					touch0 = nil;
				}

				if(touch1.phase == UITouchPhaseEnded)
				{
					remainingTouch = touch0;
				}

				if(remainingTouch)
				{
					SDR_DEBUGPRINT(("One touch remains!\n"));
					if(self.displayMode == DisplayModeWaterfall)
					{
						slideFrequencyStartLoc = [self getVerticalLocation:baseTouch];
					}
					else
					{
						slideFrequencyStartLoc = [self getHorizontalLocation:baseTouch];
					}
				}
				else
				{
					SDR_DEBUGPRINT(("All touches ended!\n"));
					if(!buttonsAreOn) // if buttons got erased (i.e., if the lock button wasn't touched)
					{
						[self hideButtonCountdown:StartTimer selector:@selector(turnOnButtons)];
					}
				}

				twoTouchFrequencyEvent = nil;
				slideFrequencyEvent = nil;
				simpleTouchFrequencyEvent = nil;
				self.baseTouch = nil;
				self.slidingTouch = nil;
				return; // avoid taps being read when slide event is ending
			}
			else // if(touchCount != 2)
			{
				SDR_DEBUGPRINT(("All touches removed!\n"));

				if(!buttonsAreOn) // if buttons got erased (i.e., if the lock button wasn't touched)
				{
					[self hideButtonCountdown:StartTimer selector:@selector(turnOnButtons)];
				}
			}
		}
		else
		{
			[self flushAudio];

			if(!buttonsAreOn) // if buttons got erased (i.e., if the lock button wasn't touched)
			{
				if(simpleTouchFrequencyEvent != nil)
				{
					if(self.displayMode == DisplayModeWaterfall)
					{
						[self turnOnButtons];
						[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];
					}
					else
					{
						[self turnOnButtons];
					}
				}
				else
				{
					[self hideButtonCountdown:StartTimer selector:@selector(turnOnButtons)];
				}
			}
		}
	}

	switch(self.displayMode)
	{
		case DisplayModeOscilloscopeFFT:
		case DisplayModeOscilloscopeWaveform:
		{
			if(receivedTouch.tapCount == 2)
			{
				if(lockButton && (lockButton.state == LOCKED)) return; // allow no actions when screen is locked

				if(CGRectContainsPoint(tuneBarOSRectangle, [receivedTouch locationInView:self.eaglView])) // tune bar touched
				{
					if(slideFrequencyEvent || twoTouchFrequencyEvent)
					{
						// redraw buttons
						[self hideButtonCountdown:FireTimer selector:@selector(turnOnButtons)];
					}
				}

				if(CGRectContainsPoint(gridRectangle, [receivedTouch locationInView:self.eaglView])) // grid region touched
				{
					if(self.displayMode == DisplayModeOscilloscopeFFT)
					{
						if(CGRectContainsPoint(cursorRectangleOS, [receivedTouch locationInView:self.eaglView]))
						{
							if(cursorTapCount >= 2)
							{
								SDR_DEBUGPRINT(("2. Cursor was double-tapped. Count was set to %ld\n", (long)cursorTapCount));
								[self stepModeSetting:bandwidthSetting];
								cursorTapCount = 0;

								twoTouchFrequencyEvent = nil;
								slideFrequencyEvent = nil;
								simpleTouchFrequencyEvent = nil;
								self.baseTouch = nil;
								self.slidingTouch = nil;
								return;
							}
						}
					}

					if(!buttonsAreOn) // if buttons got erased
					{
						[self hideButtonCountdown:FireTimer selector:@selector(turnOnButtons)];
					}

					[self hideFreqOverlay];

					if((self.displayMode) == DisplayModeOscilloscopeWaveform)
					{
						// Switch to FFT display
						if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];

						//self.displayMode = DisplayModeOscilloscopeFFT;
						[self setUpForDisplayMode:DisplayModeOscilloscopeFFT];
						//displayInitialized = FALSE;

						[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:FALSE useFrequency:-1.];
						[self drawFrequencyOverlay];

						numDrawBuffers = kFFTDrawBuffers;
						drawBufferLen = kFFTDrawSamples;
						[self setupDrawBuffers];
					}
					else
					{
						// Switch to waterfall display
						SDR_DEBUGPRINT(("Switching to waterfall mode...\n"));
						if(rssiMeter)
						{
							SDR_DEBUGPRINT(("calling hideMeter!\n"));
							[rssiMeter hideMeter:TRUE];
						}

						if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];

						//self.displayMode = DisplayModeWaterfall;
						[self setUpForDisplayMode:DisplayModeWaterfall];
						//displayInitialized = FALSE;

						if(!initted_spectrum) [self setupViewForSpectrum];
						[self clearTextures];

						[cursorLandscapeOverlayOS removeFromSuperview];

						//[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:FALSE useFrequency:-1.];

						[self drawFrequencyOverlay];
						[self drawButtons:buttonsRedraw];
						[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];

						numDrawBuffers = kWaveformDrawBuffers;
						drawBufferLen = kWaveformDrawSamples;
						[self setupDrawBuffers];

						[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:FALSE useFrequency:preFirstTapFrequencySetting];
					}

					twoTouchFrequencyEvent = nil;
					slideFrequencyEvent = nil;
					simpleTouchFrequencyEvent = nil;
					self.baseTouch = nil;
					self.slidingTouch = nil;
					return;
				}

				if(CGRectContainsPoint(freqOverlayRectangle, [receivedTouch locationInView:self.eaglView]))
				{
					SDR_DEBUGPRINT(("Tapped the mode!!\n"));
					[self stepModeSetting:modulationSetting];
					[self drawButtons:buttonsRedraw];

					twoTouchFrequencyEvent = nil;
					slideFrequencyEvent = nil;
					simpleTouchFrequencyEvent = nil;
					self.baseTouch = nil;
					self.slidingTouch = nil;
					return;
				}

				if(CGRectContainsPoint(meterRect, [receivedTouch locationInView:self.eaglView]))
				{
					SDR_DEBUGPRINT(("Tapped the meter!!\n"));

					if(!buttonsAreOn) // if buttons got erased
					{
						[self hideButtonCountdown:FireTimer selector:@selector(turnOnButtons)];
					}

					if(rssiMeter)
					{
						switch(rssiMeter.agc)
						{
							case AGC_OFF:
								rssiMeter.agc = AGC_SLOW;
								break;
							case AGC_SLOW:
								rssiMeter.agc = AGC_FAST;
								break;
							case AGC_FAST:
								rssiMeter.agc = AGC_OFF;
								break;
						}

						[self drawButtons:buttonsRedraw];
						defaultsWorkingCopy.agcSetting =  rssiMeter.agc;
						appDelegate.defaults = defaultsWorkingCopy;

						[appDelegate writeDefaultsToFileSystem];
					}

					if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];

					twoTouchFrequencyEvent = nil;
					slideFrequencyEvent = nil;
					simpleTouchFrequencyEvent = nil;
					self.baseTouch = nil;
					self.slidingTouch = nil;
					return;
				}

				cursorTapCount = 0;
				SDR_DEBUGPRINT(("3. Cursor touch count reset to %ld\n", (long)cursorTapCount));
			}
			else if(receivedTouch.tapCount == 1)
			{
				if(windowBehavior == FrequencyWindowLockMode)
				{
					[self applyCenterFrequency:receivedTouch];
					if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
				}

				preFirstTapFrequencySetting = preTouchFrequencySetting;
			}

			if(displayMode == DisplayModeOscilloscopeFFT)
			{
				if(event == slideFrequencyEvent)
				{
					SDR_DEBUGPRINT(("Drawing last overlay!\n"));
					[self drawFrequencyOverlay];
				}
			}
		}
			break;


		case DisplayModeWaterfall:
		{
			if(receivedTouch.tapCount == 2)
			{
				[self hideButtonCountdown:FireTimer selector:@selector(hideFreqOverlay)];

				if(lockButton && (lockButton.state == LOCKED)) return; // allow no actions when screen is locked

				if(CGRectContainsPoint(freqOverlayRectangle, [receivedTouch locationInView:self.eaglView]))
				{
					if(!secondTapWithoutFrequencyOverlay)
					{
						SDR_DEBUGPRINT(("Tapped the mode!!\n"));
						[self stepModeSetting:modulationSetting];
						[self hideButtonCountdown:StartTimer selector:@selector(hideFreqOverlay)];

						frequencyOverlayLandscape.doNotTimeout = !frequencyOverlayLandscape.doNotTimeout; // undo the single-press action

						twoTouchFrequencyEvent = nil;
						slideFrequencyEvent = nil;
						simpleTouchFrequencyEvent = nil;
						self.baseTouch = nil;
						self.slidingTouch = nil;
						return;
					}
				}

				if(CGRectContainsPoint(cursorRectangleWF, [receivedTouch locationInView:self.eaglView]))
				{
					if(cursorTapCount >= 2)
					{
						SDR_DEBUGPRINT(("1. Cursor double-tapped. Count was %ld\n", (long)cursorTapCount));
						[self stepModeSetting:bandwidthSetting];
						cursorTapCount = 0;

						twoTouchFrequencyEvent = nil;
						slideFrequencyEvent = nil;
						simpleTouchFrequencyEvent = nil;
						self.baseTouch = nil;
						self.slidingTouch = nil;
						return;
					}
				}

				if(!CGRectContainsPoint(tuneBarOSRectangle, [receivedTouch locationInView:self.eaglView])) // tune bar not touched
				{
					[self.eaglView enableLayout];

					[self hideFreqOverlay];
					if(rssiMeter)
					{
						SDR_DEBUGPRINT(("calling showMeter!\n"));
						[rssiMeter showMeter:TRUE];
					}

					// Switch to o-scope display of signal
					if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
					[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:TRUE useFrequency:-1.]; // erase bandwidth cursor
					[self hideButtonCountdown:CancelTimer selector:@selector(hideButtons)];

					//self.displayMode = DisplayModeOscilloscopeWaveform;
					[self setUpForDisplayMode:DisplayModeOscilloscopeWaveform];
					//displayInitialized = FALSE;

					if(lockButton && (lockButton.state == LOCKED))
					{
						[self drawButtons:buttonsLock];
					}
					else
					{
						[self drawButtons:buttonsTurnOn];
					}

					[self drawFrequencyOverlay];

					numDrawBuffers = kWaveformDrawBuffers;
					drawBufferLen = kWaveformDrawSamples;
					[self setupDrawBuffers];

					[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:TRUE useFrequency:preFirstTapFrequencySetting];
				}

				cursorTapCount = 0;
				secondTapWithoutFrequencyOverlay = FALSE;
				SDR_DEBUGPRINT(("4. Cursor touch count reset to %ld\n", (long)cursorTapCount));
			}
			else if(receivedTouch.tapCount == 1)
			{
				if(windowBehavior == FrequencyWindowLockMode)
				{
					[self applyCenterFrequency:receivedTouch];
					if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
				}
				else
				{
					if(CGRectContainsPoint(freqOverlayRectangle, [receivedTouch locationInView:self.eaglView]))
					{
						SDR_DEBUGPRINT(("Tapped the mode!!\n"));

						if(frequencyOverlayLandscape.isVisible && !touchWithoutFrequencyOverlay)
						{
							frequencyOverlayLandscape.doNotTimeout = !frequencyOverlayLandscape.doNotTimeout;

							if(frequencyOverlayLandscape.doNotTimeout)
							{
								//frequencyTextLandscape.textColor = [UIColor redColor];
								frequencyTextLandscape.alpha = .8;
								frequencyTextLandscape.shadowColor = [UIColor blackColor];
							}
							else
							{
								//frequencyTextLandscape.textColor = [UIColor whiteColor];
								frequencyTextLandscape.alpha = 1.;
								frequencyTextLandscape.shadowColor = [UIColor clearColor];
							}

							if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
						}

						secondTapWithoutFrequencyOverlay = touchWithoutFrequencyOverlay;
					}

					preFirstTapFrequencySetting = preTouchFrequencySetting;

					[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];
				}
			}
			else if(receivedTouch.tapCount == 0)
			{
				if(event == slideFrequencyEvent)
				{
					[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:FALSE useFrequency:-1.];
					[self drawFrequencyOverlay];
					[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];
					SDR_DEBUGPRINT(("drawing last overlay12\n"));

					twoTouchFrequencyEvent = nil;
					slideFrequencyEvent = nil;
					simpleTouchFrequencyEvent = nil;
					self.baseTouch = nil;
					self.slidingTouch = nil;
					return;
				}
				else
				{
					[self drawFrequencyOverlay];
				}
			}
		}
			break;

		default:
		{
			SDR_DEBUGPRINT(("Error: Unhandled display mode!\n"));
		}
			break;
	}

	SDR_DEBUGPRINT(("Leaving touchesEnded...\n"));
	twoTouchFrequencyEvent = nil;
	slideFrequencyEvent = nil;
	simpleTouchFrequencyEvent = nil;
	self.baseTouch = nil;
	self.slidingTouch = nil;
	return;
}


- (void)setUpForDisplayMode:(iSDRDisplayMode)mode
{
	if(linearGridOverlay == nil) return;
	if(semiLogGridOverlay == nil) return;
	if(signalScopeGridOverlay == nil) return;

	static BOOL linearGridDrawn=FALSE;
	static BOOL semilogGridDrawn=FALSE;
	static BOOL signalScopeGridDrawn=FALSE;

	linearGridOverlay.alpha = defaultsWorkingCopy.gridBrightness;
	semiLogGridOverlay.alpha = defaultsWorkingCopy.gridBrightness;
	signalScopeGridOverlay.alpha = defaultsWorkingCopy.gridBrightness;

	frequencyOverlayLandscape.doNotTimeout = FALSE; // reset to FALSE when new display mode is entered

	switch(mode)
	{
		case DisplayModeWaterfall:
			if(semilogGridDrawn)
			{
				[semiLogGridOverlay removeFromSuperview];
				semilogGridDrawn = FALSE;
			}

			if(linearGridDrawn)
			{
				[linearGridOverlay removeFromSuperview];
				linearGridDrawn = FALSE;
			}

			if(signalScopeGridDrawn)
			{
				[signalScopeGridOverlay removeFromSuperview];
				signalScopeGridDrawn = FALSE;
			}

			self.displayMode = mode;
			displayInitialized = FALSE;
			break;

		case DisplayModeOscilloscopeFFT:

			if(signalScopeGridDrawn)
			{
				[signalScopeGridOverlay removeFromSuperview];
				signalScopeGridDrawn = FALSE;
			}

			if(defaultsWorkingCopy.gridType == SemiLog)
			{
				if(linearGridDrawn)
				{
					[linearGridOverlay removeFromSuperview];
					linearGridDrawn = FALSE;
				}

				[self.view insertSubview:semiLogGridOverlay aboveSubview:eaglView];
				semilogGridDrawn = TRUE;
			}
			else
			{
				if(semilogGridDrawn)
				{
					[semiLogGridOverlay removeFromSuperview];
					semilogGridDrawn = FALSE;
				}

				[self.view insertSubview:linearGridOverlay aboveSubview:eaglView];
				linearGridDrawn = TRUE;
			}

			self.displayMode = mode;
			displayInitialized = FALSE;
			break;

		case DisplayModeOscilloscopeWaveform:
			if(semilogGridDrawn)
			{
				[semiLogGridOverlay removeFromSuperview];
				semilogGridDrawn = FALSE;
			}

			if(linearGridDrawn)
			{
				[linearGridOverlay removeFromSuperview];
				linearGridDrawn = FALSE;
			}

			//[self.view insertSubview:signalScopeGridOverlay aboveSubview:eaglView];
			[self.view addSubview:signalScopeGridOverlay];
			signalScopeGridDrawn = TRUE;

			self.displayMode = mode;
			displayInitialized = FALSE;
			break;

		default:
			break;
	}
}


- (void)flipAction:(id)sender
{
	holdDefaults = defaultsWorkingCopy; // store current settings for later comparison

	if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		// prefViewController = nil;
		//navigationController = nil;
		//iSDRpopoverController = nil;

		SDR_DEBUGPRINT(("iPad! flipAction\n"));
		if(prefViewController == nil)
		{
			SDR_DEBUGPRINT(("creating prefViewController\n"));
			//			PreferencesViewController* pvc = [[PreferencesViewController alloc] initWithStyle:UITableViewStyleGrouped];
			PreferencesViewController* pvc = [[PreferencesViewController alloc]
											  initWithNibName:@"PreferencesViewController_iPad" bundle:nil];
			self.prefViewController = pvc;

			prefViewController.delegate = self;
			prefViewController.appDelegate = appDelegate;
		}

		// Display the nav controller modally
		if(navigationController == nil)
		{
			SDR_DEBUGPRINT(("creating navigationController\n"));
			UINavigationController* nc = [[UINavigationController alloc] initWithRootViewController:prefViewController];
			self.navigationController = nc;
		}


        [navigationController setModalPresentationStyle:UIModalPresentationPopover];
            [self presentViewController:navigationController
              animated:YES
            completion:nil];

        //present the popover view non-modal with a reference to the button pressed within the current view
        iSDRpopoverController = [navigationController
                                                          popoverPresentationController];
        iSDRpopoverController.sourceView = infoButton;
        iSDRpopoverController.sourceRect = infoButton.bounds;

	}
	else
	{
		[self hideButtonCountdown:FireTimer selector:@selector(hideButtons)];

		[self.eaglView stopAnimation];

		// Set up modal view for setting user settings
		if(prefViewController == nil)
		{
			//			PreferencesViewController* pvc = [[PreferencesViewController alloc] initWithStyle:UITableViewStyleGrouped];
			PreferencesViewController* pvc = [[PreferencesViewController alloc]
											  initWithNibName:@"PreferencesViewController" bundle:nil];
			self.prefViewController = pvc;

			prefViewController.delegate = self;
			prefViewController.appDelegate = appDelegate;
		}

		// Display the nav controller modally.
		if(navigationController == nil)
		{
			UINavigationController* nc = [[UINavigationController alloc] initWithRootViewController:prefViewController];
			self.navigationController = nc;
		}

		if(SYSTEM_VERSION_LESS_THAN(@"8.0"))
		{
			navigationController.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
		}
		else
		{
			navigationController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
		}

		//		[self presentModalViewController:navigationController animated:YES];
		[self presentViewController:navigationController animated:YES completion:nil];

		[cursorLandscapeOverlayOS removeFromSuperview];
		SDR_DEBUGPRINT(("flipAction done!\n"));
	}
}

- (void)playKeypressBeep
{
	if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// PreferencesViewController Delegate Methods
//
- (void)renewDefaults
{
	defaultsWorkingCopy = appDelegate.defaults; // ensure local copy agrees with any changes applied in Preferences
}

- (void)preferencesFinished
{
	defaultsWorkingCopy = appDelegate.defaults; // ensure local copy agrees with any changes applied in Preferences

	if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		SDR_DEBUGPRINT(("prefView finished (iPad)...\n"));
        [[iSDRpopoverController presentingViewController] dismissViewControllerAnimated:TRUE completion:NULL];
		_popoverActive = FALSE;
        iSDRpopoverController = nil;

		[self drawFrequencyOverlay];
		centerFrequencyText.text = switchCtl.plainToggle ? @"": [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];

		if((self.displayMode) == DisplayModeWaterfall)
		{
			[self hideButtonCountdown:StartTimer selector:@selector(hideFreqOverlay)];
		}

		if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
	}
	else
	{
		SDR_DEBUGPRINT(("prefView finished (iPhone)...\n"));
		[self applyRadioSettings:FALSE];

		if((self.displayMode) == DisplayModeWaterfall)
		{
			SDR_DEBUGPRINT(("Clearing waterfall...\n"));
			//			[self drawButtons:buttonsHide];

			if(!initted_spectrum) [self setupViewForSpectrum];
			[self clearTextures];

			[self drawFrequencyOverlay];
			centerFrequencyText.text = switchCtl.plainToggle ? @"": [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];

			[self drawButtons:buttonsTurnOn];
			[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];

			numDrawBuffers = kWaveformDrawBuffers;
			drawBufferLen = kWaveformDrawSamples;
			[self setupDrawBuffers];
		}
		else
		{
			[self drawFrequencyOverlay];
			//  [self drawButtons:buttonsTurnOn];
			//			SDR_DEBUGPRINT(("\nJust redrew buttons after flip!\n\n"));
		}

		//		[self dismissModalViewControllerAnimated:YES];
		[self dismissViewControllerAnimated:YES completion:nil];

		if(switchCtl.on == TRUE)
		{
			[self.eaglView startAnimation];
		}

		if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
	}
}


- (void)applyRadioSettings:(BOOL)forceApply
{
	BOOL holdAnimationState = self.eaglView.animationState;

	if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		SDR_DEBUGPRINT(("iPad! applyRadioSettings\n"));
		BOOL initializeRadio = FALSE;

		SDR_DEBUGPRINT(("Applying radio settings (iPad)...\n"));

		[self hideFreqOverlay];
		[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:TRUE useFrequency:-1.]; // erase bandwidth cursor
		[self drawButtons:buttonsAllOff];

		// Check to see if it is necessary to redraw the view
		[self getSavedSettings]; // refresh settings in case they changed

		if((holdDefaults.demoModeOnly != defaultsWorkingCopy.demoModeOnly) || forceApply)
		{
			SDR_DEBUGPRINT(("Demo mode change detected!\n"));

			if(rssiMeter)
			{
				[rssiMeter hideMeter:FALSE];
				if(mixerController != nil) mixerController.mcMixerUser = nil;
				[rssiMeter setAu:nil];
			}

#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
			if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
#endif
			{
				if([mixerController shutDownAudio])
				{
					try
					{
						mixerController.mLiveAudioAllowed = !defaultsWorkingCopy.demoModeOnly;
						SDR_DEBUGPRINT(("call setupAudioSession #2\n"));

						OSStatus audioResult = [mixerController setupAudioSession];

						if(audioResult)
						{
							[self popFatalErrorMessage:audioResult];
						}

						fftBufferManager = mixerController.fftBufferManager;
						sampleRateBandwidthHz = (float)mixerController.sampleRateBandwidth;
						sampleRateBandwidthKHz = sampleRateBandwidthHz / 1000.;
						kHertzPerScreenElement = (self.displayMode == DisplayModeWaterfall) ? (sampleRateBandwidthKHz / displayLandscapeHeight) : (sampleRateBandwidthKHz / displayLandscapeWidth);

						if(mixerController.mAudioMode == AudioModeDemonstration)
						{
							SDR_DEBUGPRINT(("Starting recorded audio...\n"));
						}
						else
						{
							SDR_DEBUGPRINT(("Receiving live audio (3)...\n"));
						}

						if(rssiMeter)
						{
							mixerController.mcMixerUser = rssiMeter;
							[rssiMeter setAu:mixerController.mMixerUnit];

							if(self.displayMode != DisplayModeWaterfall)
							{
								[rssiMeter showMeter:TRUE];
							}
							else
							{
								[rssiMeter hideMeter:TRUE];
							}

							[self clearTextures];
							[self setupDrawBuffers];
						}

						if(switchCtl.on) [mixerController startAUGraph:FALSE]; // start audio flow

					}
					catch (CAXException &e) {
						char buf[256];
						fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
					}
					catch (...) {
						fprintf(stderr, "An unknown error occurred in applicationDidFinishLaunching\n");
					}
				}
				else
				{
					SDR_DEBUGPRINT(("Could not shut down audio!\n"));
				}
			}
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
			else
			{
				if([mixerController shutDownAudio_old])
				{
					try
					{
						mixerController.mLiveAudioAllowed = !defaultsWorkingCopy.demoModeOnly;

						SDR_DEBUGPRINT(("call setupAudioSession #3\n"));
						OSStatus audioResult = [mixerController setupAudioSession_old];

						if(audioResult)
						{
							[self popFatalErrorMessage:audioResult];
						}

						fftBufferManager = mixerController.fftBufferManager;
						sampleRateBandwidthHz = (float)mixerController.sampleRateBandwidth;
						sampleRateBandwidthKHz = sampleRateBandwidthHz / 1000.;
						kHertzPerScreenElement = (self.displayMode == DisplayModeWaterfall) ? (sampleRateBandwidthKHz / displayLandscapeHeight) : (sampleRateBandwidthKHz / displayLandscapeWidth);

						if(mixerController.mAudioMode == AudioModeDemonstration)
						{
							SDR_DEBUGPRINT(("Starting recorded audio...\n"));
						}
						else
						{
							SDR_DEBUGPRINT(("Receiving live audio (2)...\n"));
						}

						// start the app with silence initially
						//					mixerController.mute = TRUE;
						//					fftBufferManager->AudioBufferFlush();

						if(rssiMeter)
						{
							mixerController.mcMixerUser = rssiMeter;
							[rssiMeter setAu:mixerController.mMixerUnit];

							if(self.displayMode != DisplayModeWaterfall)
							{
								[rssiMeter showMeter:TRUE];
							}
							else
							{
								[rssiMeter hideMeter:TRUE];
							}

							[self clearTextures];
							[self setupDrawBuffers];
						}

						if(switchCtl.on) [mixerController startAUGraph:FALSE]; // start audio flow
					}
					catch (CAXException &e) {
						char buf[256];
						fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
					}
					catch (...) {
						fprintf(stderr, "An unknown error occurred in applicationDidFinishLaunching\n");
					}
				}
				else
				{
					SDR_DEBUGPRINT(("Could not shut down audio!\n"));
				}
			}
#endif

			initializeRadio = TRUE;
		}

		if(initializeRadio || (holdDefaults.centerFrequency != defaultsWorkingCopy.centerFrequency) ||
		   (holdDefaults.operatingMode != defaultsWorkingCopy.operatingMode) ||
		   (holdDefaults.reverseIQ != defaultsWorkingCopy.reverseIQ) ||
		   (holdDefaults.bpfBandwidth != defaultsWorkingCopy.bpfBandwidth))
		{
			[self initializeRadioSettings];
		}

		[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:FALSE useFrequency:-1.];
		[self drawFrequencyOverlay];
		[self drawButtons:buttonsRedraw];
	}
	else
	{
		BOOL initializeRadio = FALSE;

		SDR_DEBUGPRINT(("Applying radio settings (iPhone)...\n"));

		initted_oscilloscope = FALSE;

		[self hideFreqOverlay];
		[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:TRUE useFrequency:-1.]; // erase bandwidth cursor

		// Check to see if it is necessary to redraw the view
		[self getSavedSettings]; // refresh settings in case they changed

		if((holdDefaults.demoModeOnly != defaultsWorkingCopy.demoModeOnly) || forceApply)
		{
			if(rssiMeter)
			{
				[rssiMeter hideMeter:FALSE];
				if(mixerController != nil) mixerController.mcMixerUser = nil;
				[rssiMeter setAu:nil];
			}

#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
			if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
#endif
			{
				if([mixerController shutDownAudio])
				{
					try
					{
						mixerController.mLiveAudioAllowed = !defaultsWorkingCopy.demoModeOnly;

						SDR_DEBUGPRINT(("call setupAudioSession #3\n"));
						OSStatus audioResult = [mixerController setupAudioSession];

						if(audioResult)
						{
							[self popFatalErrorMessage:audioResult];
						}

						fftBufferManager = mixerController.fftBufferManager;
						sampleRateBandwidthHz = (float)mixerController.sampleRateBandwidth;
						sampleRateBandwidthKHz = sampleRateBandwidthHz / 1000.;
						kHertzPerScreenElement = (self.displayMode == DisplayModeWaterfall) ? (sampleRateBandwidthKHz / displayLandscapeHeight) : (sampleRateBandwidthKHz / displayLandscapeWidth);

						if(mixerController.mAudioMode == AudioModeDemonstration)
						{
							SDR_DEBUGPRINT(("Starting recorded audio...\n"));
						}
						else
						{
							SDR_DEBUGPRINT(("Receiving live audio (2)...\n"));
						}

						// start the app with silence initially
						//					mixerController.mute = TRUE;
						//					fftBufferManager->AudioBufferFlush();

						if(rssiMeter)
						{
							mixerController.mcMixerUser = rssiMeter;
							[rssiMeter setAu:mixerController.mMixerUnit];

							if(self.displayMode != DisplayModeWaterfall)
							{
								[rssiMeter showMeter:TRUE];
							}
							else
							{
								[rssiMeter hideMeter:TRUE];
							}

							[self clearTextures];
							[self setupDrawBuffers];
						}

						if(switchCtl.on) [mixerController startAUGraph:FALSE]; // start audio flow
					}
					catch (CAXException &e) {
						char buf[256];
						fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
					}
					catch (...) {
						fprintf(stderr, "An unknown error occurred in applicationDidFinishLaunching\n");
					}
				}
				else
				{
					SDR_DEBUGPRINT(("Could not shut down audio!\n"));
				}
			}
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
			else
			{
				if([mixerController shutDownAudio_old])
				{
					try
					{
						mixerController.mLiveAudioAllowed = !defaultsWorkingCopy.demoModeOnly;

						SDR_DEBUGPRINT(("call setupAudioSession #3\n"));
						OSStatus audioResult = [mixerController setupAudioSession_old];

						if(audioResult)
						{
							[self popFatalErrorMessage:audioResult];
						}

						fftBufferManager = mixerController.fftBufferManager;
						sampleRateBandwidthHz = (float)mixerController.sampleRateBandwidth;
						sampleRateBandwidthKHz = sampleRateBandwidthHz / 1000.;
						kHertzPerScreenElement = (self.displayMode == DisplayModeWaterfall) ? (sampleRateBandwidthKHz / displayLandscapeHeight) : (sampleRateBandwidthKHz / displayLandscapeWidth);

						if(mixerController.mAudioMode == AudioModeDemonstration)
						{
							SDR_DEBUGPRINT(("Starting recorded audio...\n"));
						}
						else
						{
							SDR_DEBUGPRINT(("Receiving live audio (2)...\n"));
						}

						// start the app with silence initially
						//					mixerController.mute = TRUE;
						//					fftBufferManager->AudioBufferFlush();

						if(rssiMeter)
						{
							mixerController.mcMixerUser = rssiMeter;
							[rssiMeter setAu:mixerController.mMixerUnit];

							if(self.displayMode != DisplayModeWaterfall)
							{
								[rssiMeter showMeter:TRUE];
							}
							else
							{
								[rssiMeter hideMeter:TRUE];
							}

							[self clearTextures];
							[self setupDrawBuffers];
						}

						if(switchCtl.on) [mixerController startAUGraph:FALSE]; // start audio flow
					}
					catch (CAXException &e) {
						char buf[256];
						fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
					}
					catch (...) {
						fprintf(stderr, "An unknown error occurred in applicationDidFinishLaunching\n");
					}
				}
				else
				{
					SDR_DEBUGPRINT(("Could not shut down audio!\n"));
				}
			}
#endif

			initializeRadio = TRUE;
		}

		if(initializeRadio || (holdDefaults.centerFrequency != defaultsWorkingCopy.centerFrequency) ||
		   (holdDefaults.operatingMode != defaultsWorkingCopy.operatingMode) ||
		   (holdDefaults.reverseIQ != defaultsWorkingCopy.reverseIQ) ||
		   (holdDefaults.bpfBandwidth != defaultsWorkingCopy.bpfBandwidth))
		{
			SDR_DEBUGPRINT(("Initializing radio settings!\n"));
			[self initializeRadioSettings];
		}

		[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:FALSE useFrequency:-1.];
		[self drawFrequencyOverlay];
		fftBufferManager->setCopyRawPCM(TRUE); // prevents rare illegal access when enabling live audio
	}

	holdDefaults = defaultsWorkingCopy;
	fftBufferManager->AudioBufferFlush();

	if(!switchCtl.on) [mixerController stopAUGraph:FALSE]; // essential for ensuring audio remains off when modes are changed

	if(switchCtl.on && holdAnimationState)
	{
		[self.eaglView startAnimation];
	}
}
//
// PreferencesViewController Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////


- (void)initializeRadioSettings
{
	// prevent FM mode from being in effect if there is only one channel - since it won't work!
	if(( mixerController.mCurrentHardwareInputNumberChannels != 2) && (defaultsWorkingCopy.operatingMode == NFM_mode))
	{
		[self setNextOperatingMode:defaultsWorkingCopy.operatingMode];
		appDelegate.defaults = holdDefaults;
		defaultsWorkingCopy = appDelegate.defaults;
	}

	// Set default value for BPF.
	if(defaultsWorkingCopy.operatingMode == CW_mode)
	{
		fftBufferManager->setCenterFrequencyOffsetHz(-defaultsWorkingCopy.rxOffset, sampleRateBandwidthHz, FALSE);
		fftBufferManager->setBPF(defaultsWorkingCopy.bpfBandwidth);
	}
	else if((defaultsWorkingCopy.operatingMode == AM_mode) || (defaultsWorkingCopy.operatingMode == NFM_mode))
	{
		fftBufferManager->setCenterFrequencyOffsetHz(0., sampleRateBandwidthHz, FALSE);
		fftBufferManager->setBPF(defaultsWorkingCopy.bpfBandwidth);
	}
	else // SSB mode
	{
		fftBufferManager->setCenterFrequencyOffsetHz(0., sampleRateBandwidthHz, TRUE);
		fftBufferManager->setBPF(defaultsWorkingCopy.bpfBandwidth);
	}

	fftBufferManager->setOperatingMode(defaultsWorkingCopy.operatingMode);
	SDR_DEBUGPRINT(("IQ state=%s\n",(defaultsWorkingCopy.reverseIQ == TRUE) ? "True":"False"));
	fftBufferManager->setIQLogicState(defaultsWorkingCopy.reverseIQ);

	fftBufferManager->setSignalScaleFactor(defaultsWorkingCopy.signalScaleFactor);

	//Set up overlays that serve as a cursors for the current frequency setting
	[self createBandwidthOverlays:defaultsWorkingCopy.operatingMode];
}


- (void)getSavedSettings
{
	// Read default settings for device
	defaultsWorkingCopy = appDelegate.defaults;

	if(fftBufferManager)
	{
		if(defaultsWorkingCopy.operatingMode == CW_mode)
		{
			fftBufferManager->setCenterFrequencyOffsetHz(-defaultsWorkingCopy.rxOffset, sampleRateBandwidthHz, FALSE);
		}
		else
		{
			if((defaultsWorkingCopy.operatingMode == USB_mode) || (defaultsWorkingCopy.operatingMode == LSB_mode))
			{
				fftBufferManager->setCenterFrequencyOffsetHz(0., sampleRateBandwidthHz, TRUE);
			}
			else
			{
				fftBufferManager->setCenterFrequencyOffsetHz(0., sampleRateBandwidthHz, FALSE);
			}
		}
	}
}


- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}


//- (BOOL)shouldAutorotate
//{
//	return YES; //(mixerController.audioStatus != AudioNotReady);
//}

- (BOOL)shouldAutorotate
{
	// supportedInterfaceOrientations constrains rotation to the app's landscape layouts.
	return YES;
}


- (BOOL)prefersStatusBarHidden
{
	return hideStatusBar;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

// OLD STUFF FOR iOS 5.1
//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
//{
//	// Return YES for supported orientations
//	if(mixerController.audioStatus != AudioNotReady)
//	{
//		return ((interfaceOrientation == UIInterfaceOrientationLandscapeLeft) || (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
//	}
//
//	return NO;
//}

// OLD STUFF FOR iOS 5.1
//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
//{
	// Return YES for supported orientations
//	return ((interfaceOrientation == UIInterfaceOrientationLandscapeLeft) || (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
//}



//- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
//{
//	SDR_DEBUGPRINT(("* EAGLViewController: willRotate!\n"));
//	self.eaglView.userInteractionEnabled = FALSE;
//
//	[self hideButtonCountdown:FireTimer selector:nil];
//
//	[frequencyOverlayLandscape removeFromSuperview]; frequencyOverlayLandscape.isVisible = FALSE;
//	[cursorLandscapeOverlayOS removeFromSuperview];
//	[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:TRUE useFrequency:-1.]; // erase bandwidth cursor
//
//	[self drawButtons:buttonsAllOff];
//	[self.eaglView enableLayout];
//	slideFrequencyEvent = nil;
//	twoTouchFrequencyEvent = nil;
//	simpleTouchFrequencyEvent = nil;
//	self.baseTouch = nil;
//	self.slidingTouch = nil;
//
//	if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
//	{
//		SDR_DEBUGPRINT(("iPad! willRotate\n"));
//		if(_popoverActive == TRUE)
//		{
//			[self.prefViewController preferencesFinished];
//		}
//	}
//}


//- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
//{
//	SDR_DEBUGPRINT(("* EAGLViewController: didRotate!\n"));
//	//[self drawButtons:buttonsRedraw];
//	//SDR_DEBUGPRINT(("buttonsRedraw1\n"));
//	[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:FALSE useFrequency:-1.];
//
//	if(self.displayMode != DisplayModeWaterfall)
//	{
//		[self drawFrequencyOverlay];
//		[self turnOnButtons];
//		[self drawButtons:buttonsRedraw];
//	}
//	else
//	{
//		[self drawFrequencyOverlay];
//		[self hideButtons];
//	}
//
//
//	self.view.userInteractionEnabled = TRUE;
//}


- (void)drawFrequencyOverlay
{
	static std::atomic_flag drawInProgress = ATOMIC_FLAG_INIT;

	// Overlay refreshes are disposable; skip a duplicate refresh instead of blocking a render thread.
	if(!drawInProgress.test_and_set(std::memory_order_acquire))
	{
		//	SDR_DEBUGPRINT(("Printing freq overlay!\n"));

		frequencyTextLandscape.text = [self getFreqModeText];
		//frequencyTextLandscape.textColor = [UIColor whiteColor];
		frequencyTextLandscape.alpha = 1.;
		frequencyTextLandscape.shadowColor = [UIColor clearColor];

		switch(self.displayMode)
		{
			case DisplayModeOscilloscopeFFT:
			{
				CGFloat x;
				frequencyType frequency = fftBufferManager->getCenterFrequency();

				x = CLAMP(_frequencyOverlayBorderOffset, (frequency * displayLandscapeWidth), displayLandscapeWidth - _frequencyOverlayBorderOffset);
				frequencyOverlayLandscape.center = CGPointMake(x, _freqOverlayFrameCenterRow);
			}
				break;

			case DisplayModeOscilloscopeWaveform:
			{
				frequencyOverlayLandscape.center = CGPointMake(displayLandscapeWidth/2., _freqOverlayFrameCenterRow);
			}
				break;

			case DisplayModeWaterfall:
			default:
			{
				frequencyOverlayLandscape.frame = CGRectMake((displayLandscapeWidth/2)-(_frequencyOverlayWidth/2), (displayLandscapeHeight/2)-55, _frequencyOverlayWidth, _frequencyOverlayHeight);

				if(frequencyOverlayLandscape.doNotTimeout)
				{
					//frequencyTextLandscape.textColor = [UIColor redColor];
					frequencyTextLandscape.alpha = .8;
					frequencyTextLandscape.shadowColor = [UIColor blackColor];
				}
			}
				break;
		}

		freqOverlayRectangle = frequencyOverlayLandscape.frame;
		[self.view addSubview:frequencyOverlayLandscape]; frequencyOverlayLandscape.isVisible = TRUE;

		drawInProgress.clear(std::memory_order_release);
	}

	return;
}


- (void)drawBandwidthOverlay:(UITouch*)touchLocation edgeReached:(BOOL)drawToEdge doErase:(BOOL)erase useFrequency:(frequencyType)freqToUse
{
	// Prevent overlays for display modes that don't use them
	if(self.displayMode == DisplayModeOscilloscopeWaveform)
	{
		if((touchLocation == nil) && (freqToUse >= 0.) && (freqToUse <= 1.) && erase)
		{
			fftBufferManager->setCenterFrequency(freqToUse);
		}
		else
		{
			SDR_DEBUGPRINT(("Unneeded call to drawBandwidthOverlay in waveform display!\n"));
		}

		return;
	}

	static std::atomic_flag drawInProgress = ATOMIC_FLAG_INIT;

	// Overlay refreshes are disposable; skip a duplicate refresh instead of blocking a render thread.
	if(!drawInProgress.test_and_set(std::memory_order_acquire))
	{
		//SDR_DEBUGPRINT(("drawBandwidthOverlay!\n"));

		static BOOL WFdrawn=FALSE, OSdrawn=FALSE;
		frequencyType freq = 0;
		GLfloat modeOverlayOffset = 0;
		GLfloat	thisTouchLocation;

		if(WFdrawn) [cursorLandscapeOverlayWF removeFromSuperview];
		if(OSdrawn) [cursorLandscapeOverlayOS removeFromSuperview];
		WFdrawn = OSdrawn = FALSE;

		if(!erase)
		{
			if(touchLocation == nil)
			{
				if(freqToUse >= 0.)
				{
					freq = freqToUse;
					fftBufferManager->setCenterFrequency(freqToUse);
				}
				else
				{
					freq = fftBufferManager->getCenterFrequency();
				}
			}

			switch(defaultsWorkingCopy.operatingMode)
			{
				case USB_mode:
					if(self.displayMode == DisplayModeWaterfall)
					{
						modeOverlayOffset = (displayLandscapeHeight/2) * (defaultsWorkingCopy.bpfBandwidth / sampleRateBandwidthHz);
					}
					else
					{
						modeOverlayOffset = (displayLandscapeWidth/2) * (defaultsWorkingCopy.bpfBandwidth / sampleRateBandwidthHz);
					}

					break;

				case LSB_mode:
					if(self.displayMode == DisplayModeWaterfall)
					{
						modeOverlayOffset = -(displayLandscapeHeight/2) * (defaultsWorkingCopy.bpfBandwidth / sampleRateBandwidthHz);
					}
					else
					{
						modeOverlayOffset = -(displayLandscapeWidth/2) * (defaultsWorkingCopy.bpfBandwidth / sampleRateBandwidthHz);
					}
					break;

				case AM_mode:
				case NFM_mode:
				case Binaural_mode:
				default:
					break;
			}

			if(self.displayMode == DisplayModeWaterfall)
			{
				if(touchLocation != nil)
				{
					thisTouchLocation = [touchLocation locationInView:self.view].y + modeOverlayOffset;
					freq = 1.0 - ( (thisTouchLocation - tunebarVertHeightOffset) / displayLandscapeHeight );
					freq = CLAMP(0.0, freq, 1.0);
					//					SDR_DEBUGPRINT(("*3. TL=%1.4f; F=%1.4f :: ", thisTouchLocation, freq));
					fftBufferManager->setCenterFrequency(freq);
				}
				else
                {
                    thisTouchLocation = ((1.0 - freq) * displayLandscapeHeight) + tunebarVertHeightOffset;
                    //					SDR_DEBUGPRINT(("*4. TL=%1.4f; F=%1.4f :: ", thisTouchLocation, freq));
                }

				//				SDR_DEBUGPRINT(("WF: freq=%2.4f loc=%3.1f offset=%3.1f\n", freq, thisTouchLocation-modeOverlayOffset, modeOverlayOffset));
				cursorLandscapeOverlayWF.center = CGPointMake(waterfallCursorHorizontalCenterColumn, thisTouchLocation - modeOverlayOffset);
				[self.view addSubview:cursorLandscapeOverlayWF];
				cursorRectangleWF = CGRectMake(SPECTRUM_BAR_WIDTH, cursorLandscapeOverlayWF.center.y-25, cursorWidthWF, 50);
				WFdrawn = TRUE;
			}
			else if(self.displayMode == DisplayModeOscilloscopeFFT)
			{
				if(touchLocation != nil)
				{
					thisTouchLocation = [touchLocation locationInView:self.view].x - modeOverlayOffset;
					freq = thisTouchLocation / displayLandscapeWidth;
					freq = CLAMP(0.0, freq, 1.0);
					fftBufferManager->setCenterFrequency(freq);
				}
				else
				{
					if(drawToEdge)
					{
						if(freq > 0.5)
						{
							freq = 0.997;
						}
						else
						{
							freq = 0.003;
						}
					}
					else
					{
						// Prevent the bandwidth overlay from ever disappearing near the screen edges in SSB modes.
						if(defaultsWorkingCopy.operatingMode == USB_mode)
						{
							freq = CLAMP(0., freq, 0.997);
						}
						else if(defaultsWorkingCopy.operatingMode == LSB_mode)
						{
							freq = CLAMP(0.003, freq, 1.);
						}
						else
						{
							freq = CLAMP(0., freq, 1.);
						}
					}

                    thisTouchLocation = freq * displayLandscapeWidth;
				}

				//				SDR_DEBUGPRINT(("OS: Printing landscape overlays!\n"));
				cursorLandscapeOverlayOS.center = CGPointMake(thisTouchLocation+modeOverlayOffset, oscopeCursorVerticalRow);
				[self.view addSubview:cursorLandscapeOverlayOS];

				if((defaultsWorkingCopy.operatingMode == USB_mode) || (defaultsWorkingCopy.operatingMode == LSB_mode))
				{
					// allow extra margin for these overlays
					cursorRectangleOS = CGRectMake(cursorLandscapeOverlayOS.center.x - 50., 0., 100., cursorHeightOS);
				}
				else
				{
					cursorRectangleOS = CGRectMake(cursorLandscapeOverlayOS.center.x - 25., 0., 50., cursorHeightOS);
				}

				OSdrawn = TRUE;
			}
		}

		drawInProgress.clear(std::memory_order_release);
	}

	return;
}


- (GLfloat)getHorizontalLocation:(UITouch*)touchLocation
{
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0)

	if((self.interfaceOrientation == UIInterfaceOrientationPortrait) || (self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown))
	{
		return [touchLocation locationInView:self.view].y;
	}
	else if((self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft) || (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight))
	{
		return [touchLocation locationInView:self.view].x;
	}

	return 0.0;

#else

	UIInterfaceOrientation orient = self.view.window.windowScene.interfaceOrientation;

	if((orient == UIInterfaceOrientationPortrait) || (orient == UIInterfaceOrientationPortraitUpsideDown))
	{
		return [touchLocation locationInView:self.view].y;
	}
	else if((orient == UIInterfaceOrientationLandscapeLeft) || (orient == UIInterfaceOrientationLandscapeRight))
	{
		return [touchLocation locationInView:self.view].x;
	}

	return 0.0;

#endif
}

- (GLfloat)getVerticalLocation:(UITouch*)touchLocation
{
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0)

	if((self.interfaceOrientation == UIInterfaceOrientationPortrait) || (self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown))
	{
		return [touchLocation locationInView:self.view].x;
	}
	else if((self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft) || (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight))
	{
		return displayLandscapeHeight - [touchLocation locationInView:self.view].y;
	}

	return 0.0;

#else

	UIInterfaceOrientation orient = self.view.window.windowScene.interfaceOrientation;

	if((orient == UIInterfaceOrientationPortrait) || (orient == UIInterfaceOrientationPortraitUpsideDown))
	{
		return [touchLocation locationInView:self.view].x;
	}
	else if((orient == UIInterfaceOrientationLandscapeLeft) || (orient == UIInterfaceOrientationLandscapeRight))
	{
		return displayLandscapeHeight - [touchLocation locationInView:self.view].y;
	}

	return 0.0;

#endif
}


- (iSDROperatingMode)setNextOperatingMode:(iSDROperatingMode)currentMode
{
	switch(currentMode)
	{
		case LSB_mode:
			holdDefaults.operatingMode = USB_mode;
			holdDefaults.bpfBandwidth = 3000.0;
			fftBufferManager->setCenterFrequencyOffsetHz(0., sampleRateBandwidthHz, TRUE);
			if(rssiMeter)
			{
				rssiMeter.agc = defaultsWorkingCopy.agcSetting;
			}
			break;

		case USB_mode:
		{
			float frequency = fftBufferManager->getCenterFrequency();

			holdDefaults.operatingMode = CW_mode;
			holdDefaults.bpfBandwidth = 1000.0;
			holdDefaults.rxOffset = defaultsWorkingCopy.rxOffset;

			fftBufferManager->setCenterFrequencyOffsetHz(-holdDefaults.rxOffset, sampleRateBandwidthHz, FALSE);

			//			frequency = max(frequency, 0.0);
			fftBufferManager->setCenterFrequency(frequency);
			if(rssiMeter)
			{
				rssiMeter.agc = defaultsWorkingCopy.agcSetting;
			}
		}
			break;

		case CW_mode:
		{
			float frequency = fftBufferManager->getCenterFrequency();

			holdDefaults.operatingMode = AM_mode;
			holdDefaults.bpfBandwidth = 3000.0;
			fftBufferManager->setCenterFrequencyOffsetHz(0., sampleRateBandwidthHz, FALSE);
			fftBufferManager->setCenterFrequency(frequency);
			if(rssiMeter)
			{
				rssiMeter.agc = defaultsWorkingCopy.agcSetting;
			}
		}
			break;

		case AM_mode:
			if( mixerController.mCurrentHardwareInputNumberChannels == 2)
			{
				holdDefaults.operatingMode = NFM_mode;
				holdDefaults.bpfBandwidth = 8000.0;
				fftBufferManager->setCenterFrequencyOffsetHz(0., sampleRateBandwidthHz, FALSE);
				if(rssiMeter)
				{
					rssiMeter.agc = defaultsWorkingCopy.agcSetting;
				}
			}
			else
			{
				holdDefaults.operatingMode = Binaural_mode;
				holdDefaults.bpfBandwidth = 0.0;
				fftBufferManager->setCenterFrequencyOffsetHz(0., sampleRateBandwidthHz, FALSE);
				if(rssiMeter)
				{
					rssiMeter.agc = AGC_SLOW;
				}
			}
			break;

		case NFM_mode:
			holdDefaults.operatingMode = Binaural_mode;
			holdDefaults.bpfBandwidth = 0.0;
			fftBufferManager->setCenterFrequencyOffsetHz(0., sampleRateBandwidthHz, FALSE);
			if(rssiMeter)
			{
				rssiMeter.agc = AGC_SLOW;
			}
			break;

		case Binaural_mode:
			holdDefaults.operatingMode = LSB_mode;
			holdDefaults.bpfBandwidth = 3000.0;
			fftBufferManager->setCenterFrequencyOffsetHz(0., sampleRateBandwidthHz, TRUE);
			if(rssiMeter)
			{
				rssiMeter.agc = defaultsWorkingCopy.agcSetting;
			}
			break;
	}

	return holdDefaults.operatingMode;
}


- (void)stepModeSetting:(stepMode)stepType
{
	BOOL initializeRadio = FALSE;

	// Check to see if it is necessary to redraw the view
	[self getSavedSettings]; // refresh settings in case they changed

	holdDefaults = defaultsWorkingCopy;

	//stop the posix thread before proceeding to avoid crashes
	[mixerController disableAllAudio];

	if(stepType == modulationSetting)
	{
		[self setNextOperatingMode:holdDefaults.operatingMode];
		initializeRadio = TRUE;
	}
	else if(stepType == bandwidthSetting)
	{
		switch(holdDefaults.operatingMode)
		{
			case USB_mode:
			case LSB_mode:
				if(holdDefaults.bpfBandwidth == 3000.0)
				{
					holdDefaults.bpfBandwidth = 2000.0;
				}
				else
				{
					holdDefaults.bpfBandwidth = 3000.0;
				}
				initializeRadio = TRUE;
				break;

			case CW_mode:
				if(holdDefaults.bpfBandwidth == 1000.0)
				{
					holdDefaults.bpfBandwidth = 500.0;
				}
				else if(holdDefaults.bpfBandwidth == 500.0)
				{
					holdDefaults.bpfBandwidth = 250.0;
				}
				else if(holdDefaults.bpfBandwidth == 250.0)
				{
					holdDefaults.bpfBandwidth = 100.0;
				}
				else
				{
					holdDefaults.bpfBandwidth = 1000.0;
				}
				initializeRadio = TRUE;
				break;

			case AM_mode:
				if(holdDefaults.bpfBandwidth == 3000.0)
				{
					holdDefaults.bpfBandwidth = 2000.0;
				}
				else
				{
					holdDefaults.bpfBandwidth = 3000.0;
				}
				initializeRadio = TRUE;
				break;

			case NFM_mode:
				if(holdDefaults.bpfBandwidth == 8000.0)
				{
					holdDefaults.bpfBandwidth = 5600.0;
				}
				else
				{
					holdDefaults.bpfBandwidth = 8000.0;
				}
				initializeRadio = TRUE;
				break;

			case Binaural_mode:
			default:
				break;
		}
	}

	if(initializeRadio)
	{
		appDelegate.defaults = holdDefaults;
		defaultsWorkingCopy = appDelegate.defaults;

		SDR_DEBUGPRINT(("Applying radio settings...\n"));

		[frequencyOverlayLandscape removeFromSuperview];
		frequencyOverlayLandscape.isVisible = FALSE;
		frequencyOverlayLandscape.doNotTimeout = FALSE;
		//frequencyTextLandscape.textColor = [UIColor whiteColor];
		frequencyTextLandscape.alpha = 1.;
		frequencyTextLandscape.shadowColor = [UIColor clearColor];

		[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:TRUE useFrequency:-1.]; // erase bandwidth cursor

		[self initializeRadioSettings];

		[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:FALSE useFrequency:-1.];
		[self drawFrequencyOverlay];
	}

	//restart the posix thread before proceeding to avoid crashes
	[mixerController reenableAudio];
	if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];

	return;
}


- (void)createBandwidthOverlays:(iSDROperatingMode)operatingMode
{
	UIImage *img_ui = nil;
	size_t recWidth, recHeight;
	CGFloat fillClr[4], fillClrNarrow[4], fillClrNarrowWF[4];

	[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:TRUE useFrequency:-1.]; // be sure any overlays are erased before releasing

	self.cursorLandscapeOverlayWF = nil;
	self.cursorLandscapeOverlayOS = nil;

	if(operatingMode == CW_mode)
	{
		fillClr[0]=1.; fillClr[1]=.2; fillClr[2]=.0; fillClr[3]=0.2; // translucent red
		fillClrNarrow[0]=1.; fillClrNarrow[1]=0.; fillClrNarrow[2]=0.; fillClrNarrow[3]=0.5; // semi-translucent red
		fillClrNarrowWF[0]=1.; fillClrNarrowWF[1]=0.; fillClrNarrowWF[2]=0.; fillClrNarrowWF[3]=0.5; // semi-translucent red
	}
	else
	{
		fillClr[0]=1.; fillClr[1]=.2; fillClr[2]=.0; fillClr[3]=0.4; // translucent red
		fillClrNarrow[0]=1.; fillClrNarrow[1]=0.; fillClrNarrow[2]=0.; fillClrNarrow[3]=0.7; // semi-translucent red
		fillClrNarrowWF[0]=1.; fillClrNarrowWF[1]=0.; fillClrNarrowWF[2]=0.; fillClrNarrowWF[3]=0.7; // semi-translucent red
	}

	CGPathRef bgPath = nil, bgPath1 = nil, narrowPath = nil;
	CGContextRef cxt = nil;
	CGImageRef img_cg = nil;

	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

	switch(operatingMode)
	{
		case USB_mode:
			//*** Waterfall Cursor Creation ***//
			//*** Landscape ***//

			recWidth =  displayLandscapeWidth;
			//recHeight = (defaultsWorkingCopy.bpfBandwidth * displayLandscapeHeight) / sampleRateBandwidthHz;
			recHeight = (size_t)((float)(defaultsWorkingCopy.bpfBandwidth * displayLandscapeHeight)) / sampleRateBandwidthHz;

			cursorWidthWF = recWidth;
			cursorHeightWF = recHeight;

			// Draw the rect for the bg path using this convenience function
			bgPath = createSharpRectPath(CGRectMake(0, 3, recWidth, recHeight-3));
			narrowPath = createSharpRectPath(CGRectMake(0, 0, recWidth, 3));

			// Create the bitmap context into which we will draw
			cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

			if(cxt == NULL)
			{
				SDR_DEBUGPRINT(("Error: Could not create bit map context - 1\n"));
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);
			}
			else
			{
				CGContextSetFillColorSpace(cxt, cs);

				CGContextSetFillColor(cxt, fillClr);
				// Add the rect to the context...
				CGContextAddPath(cxt, bgPath);
				// ... and fill it.
				CGContextFillPath(cxt);


				CGContextSetFillColor(cxt, fillClrNarrowWF);
				CGContextAddPath(cxt, narrowPath);
				CGContextFillPath(cxt);

				// Make a CGImage out of the context
				img_cg = CGBitmapContextCreateImage(cxt);
				// Make a UIImage out of the CGImage
				img_ui = [UIImage imageWithCGImage:img_cg];

				// Clean up
				CGImageRelease(img_cg);
				CGContextRelease(cxt);
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);

				// Create the image view to hold the background rect which we just drew
				cursorLandscapeOverlayWF = [[UIImageView alloc] initWithImage:img_ui];

				UIImageView* iv = [[UIImageView alloc] initWithImage:img_ui];
				self.cursorLandscapeOverlayWF = iv;

				cursorLandscapeOverlayWF.frame = CGRectMake(0, 0, recWidth, recHeight);
			}

			//*** O-Scope Cursor Creation ***//
			//*** Landscape ***//

			//recWidth = (defaultsWorkingCopy.bpfBandwidth * displayLandscapeWidth) / sampleRateBandwidthHz;
			recWidth = (size_t)((float)(defaultsWorkingCopy.bpfBandwidth * displayLandscapeWidth)) / sampleRateBandwidthHz;
			recHeight =  gridHeight + cursorHeightOStweak; //0.4375 * displayLandscapeHeight;

			cursorWidthOS = recWidth;
			cursorHeightOS = recHeight;

			// Draw the rect for the bg path using this convenience function
			bgPath = nil; bgPath1 = nil; narrowPath = nil;
			bgPath = createSharpRectPath(CGRectMake(3, 0, recWidth-3, recHeight));
			narrowPath = createSharpRectPath(CGRectMake(0, 0, 3, recHeight));

			// Create the bitmap context into which we will draw
			cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

			if(cxt == NULL)
			{
				SDR_DEBUGPRINT(("Error: Could not create bit map context - 2\n"));
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);
			}
			else
			{
				CGContextSetFillColorSpace(cxt, cs);

				CGContextSetFillColor(cxt, fillClr);
				// Add the rect to the context...
				CGContextAddPath(cxt, bgPath);
				// ... and fill it.
				CGContextFillPath(cxt);


				CGContextSetFillColor(cxt, fillClrNarrow);
				CGContextAddPath(cxt, narrowPath);
				CGContextFillPath(cxt);

				// Make a CGImage out of the context
				img_cg = CGBitmapContextCreateImage(cxt);
				// Make a UIImage out of the CGImage
				img_ui = [UIImage imageWithCGImage:img_cg];

				// Clean up
				CGImageRelease(img_cg);
				CGContextRelease(cxt);
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);

				// Create the image view to hold the background rect which we just drew
				UIImageView* iv = [[UIImageView alloc] initWithImage:img_ui];
				self.cursorLandscapeOverlayOS = iv;

				cursorLandscapeOverlayOS.frame = CGRectMake(0, 0, recWidth, recHeight);
			}

			break;

		case LSB_mode:
			//*** Waterfall Cursor Creation ***//
			//*** Landscape ***//

			recWidth =  displayLandscapeWidth;
			SDR_DEBUGPRINT(("recWidth = %u (%u)\n", (unsigned int)recWidth, (unsigned int)displayLandscapeWidth));
			recHeight = (size_t)((float)(defaultsWorkingCopy.bpfBandwidth * displayLandscapeHeight)) / sampleRateBandwidthHz;

			cursorWidthWF = recWidth;
			cursorHeightWF = recHeight;

			// Draw the rect for the bg path using this convenience function
			bgPath = nil; bgPath1 = nil; narrowPath = nil;
			bgPath = createSharpRectPath(CGRectMake(0, 0, recWidth, recHeight-3));
			narrowPath = createSharpRectPath(CGRectMake(0, recHeight-3, recWidth, 3));

			// Create the bitmap context into which we will draw
			cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

			if(cxt == NULL)
			{
				SDR_DEBUGPRINT(("Error: Could not create bit map context - 1\n"));
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);
			}
			else
			{
				CGContextSetFillColorSpace(cxt, cs);

				CGContextSetFillColor(cxt, fillClr);
				// Add the rect to the context...
				CGContextAddPath(cxt, bgPath);
				// ... and fill it.
				CGContextFillPath(cxt);


				CGContextSetFillColor(cxt, fillClrNarrowWF);
				CGContextAddPath(cxt, narrowPath);
				CGContextFillPath(cxt);

				// Make a CGImage out of the context
				img_cg = CGBitmapContextCreateImage(cxt);
				// Make a UIImage out of the CGImage
				img_ui = [UIImage imageWithCGImage:img_cg];

				// Clean up
				CGImageRelease(img_cg);
				CGContextRelease(cxt);
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);

				// Create the image view to hold the background rect which we just drew
				UIImageView* iv = [[UIImageView alloc] initWithImage:img_ui];
				self.cursorLandscapeOverlayWF = iv;

				cursorLandscapeOverlayWF.frame = CGRectMake(0, 0, recWidth, recHeight);
			}

			//*** O-Scope Cursor Creation ***//
			//*** Landscape ***//

			//recWidth = defaultsWorkingCopy.bpfBandwidth * displayLandscapeWidth / sampleRateBandwidthHz;
			recWidth = (size_t)((float)(defaultsWorkingCopy.bpfBandwidth * displayLandscapeWidth)) / sampleRateBandwidthHz;
			recHeight = gridHeight + cursorHeightOStweak; // 0.4375 * displayLandscapeHeight;

			cursorWidthOS = recWidth;
			cursorHeightOS = recHeight;

			// Draw the rect for the bg path using this convenience function
			bgPath = nil; bgPath1 = nil; narrowPath = nil;
			bgPath = createSharpRectPath(CGRectMake(0, 0, recWidth-3, recHeight));
			narrowPath = createSharpRectPath(CGRectMake(recWidth-3, 0, 3, recHeight));

			// Create the bitmap context into which we will draw
			cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

			if(cxt == NULL)
			{
				SDR_DEBUGPRINT(("Error: Could not create bit map context - 1\n"));
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);
			}
			else
			{
				CGContextSetFillColorSpace(cxt, cs);

				CGContextSetFillColor(cxt, fillClr);
				// Add the rect to the context...
				CGContextAddPath(cxt, bgPath);
				// ... and fill it.
				CGContextFillPath(cxt);


				CGContextSetFillColor(cxt, fillClrNarrow);
				CGContextAddPath(cxt, narrowPath);
				CGContextFillPath(cxt);

				// Make a CGImage out of the context
				img_cg = CGBitmapContextCreateImage(cxt);
				// Make a UIImage out of the CGImage
				img_ui = [UIImage imageWithCGImage:img_cg];

				// Clean up
				CGImageRelease(img_cg);
				CGContextRelease(cxt);
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);

				// Create the image view to hold the background rect which we just drew
				UIImageView* iv = [[UIImageView alloc] initWithImage:img_ui];
				self.cursorLandscapeOverlayOS = iv;

				cursorLandscapeOverlayOS.frame = CGRectMake(0, 0, recWidth, recHeight);

			}
			break;

		case CW_mode:
			//*** Waterfall Cursor Creation ***//
			//*** Landscape ***//

		{
			recWidth =  displayLandscapeWidth;
			//recHeight = max(3.0, defaultsWorkingCopy.bpfBandwidth * displayLandscapeHeight / sampleRateBandwidthHz);
			recHeight = MAX(3., (size_t)((float)(defaultsWorkingCopy.bpfBandwidth * displayLandscapeHeight)) / sampleRateBandwidthHz);

			cursorWidthWF = recWidth;
			cursorHeightWF = recHeight;

			// Draw the rect for the bg path using this convenience function
			bgPath = nil; bgPath1 = nil; narrowPath = nil;
			bgPath = createSharpRectPath(CGRectMake(0, 0, recWidth, recHeight/2-1));
			narrowPath = createSharpRectPath(CGRectMake(0, recHeight/2-1, recWidth, 3));
			bgPath1 = createSharpRectPath(CGRectMake(0, recHeight/2+2, recWidth, recHeight/2-1));
		}

			// Create the bitmap context into which we will draw
			cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

			if(cxt == NULL)
			{
				SDR_DEBUGPRINT(("Error: Could not create bit map context - 1\n"));
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);
				if(bgPath1) CGPathRelease(bgPath1);
			}
			else
			{
				CGContextSetFillColorSpace(cxt, cs);

				if((bgPath != NULL) && (bgPath1 != NULL))
				{
					CGContextSetFillColor(cxt, fillClr);
					// Add the rect to the context...
					CGContextAddPath(cxt, bgPath);
					// ... and fill it.
					CGContextFillPath(cxt);

					CGContextAddPath(cxt, bgPath1);
					CGContextFillPath(cxt);
				}

				CGContextSetFillColor(cxt, fillClrNarrowWF);
				CGContextAddPath(cxt, narrowPath);
				CGContextFillPath(cxt);

				// Make a CGImage out of the context
				img_cg = CGBitmapContextCreateImage(cxt);
				// Make a UIImage out of the CGImage
				img_ui = [UIImage imageWithCGImage:img_cg];

				// Clean up
				CGImageRelease(img_cg);
				CGContextRelease(cxt);
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);
				if(bgPath1) CGPathRelease(bgPath1);

				// Create the image view to hold the background rect which we just drew
				UIImageView* iv = [[UIImageView alloc] initWithImage:img_ui];
				self.cursorLandscapeOverlayWF = iv;

				cursorLandscapeOverlayWF.frame = CGRectMake(0, 0, recWidth, recHeight);
			}


			//*** O-Scope Cursor Creation ***//
			//*** Landscape ***//

		{
			//recWidth = max(3.0, defaultsWorkingCopy.bpfBandwidth * displayLandscapeWidth / sampleRateBandwidthHz);
			recWidth = MAX(3.0, (size_t)((float)(defaultsWorkingCopy.bpfBandwidth * displayLandscapeWidth)) / sampleRateBandwidthHz);
			recHeight = gridHeight + cursorHeightOStweak; // 0.4375 * displayLandscapeHeight;

			cursorWidthOS = recWidth;
			cursorHeightOS = recHeight;

			// Draw the rect for the bg path using this convenience function
			bgPath = nil; bgPath1 = nil; narrowPath = nil;
			bgPath = createSharpRectPath(CGRectMake(0, 0, recWidth, recHeight));
			narrowPath = createSharpRectPath(CGRectMake(recWidth/2-1, 0, 3, recHeight));
		}


			// Create the bitmap context into which we will draw
			cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

			if(cxt == NULL)
			{
				SDR_DEBUGPRINT(("Error: Could not create bit map context - 1\n"));
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);
			}
			else
			{
				CGContextSetFillColorSpace(cxt, cs);

				if(bgPath != NULL)
				{
					CGContextSetFillColor(cxt, fillClr);
					// Add the rect to the context...
					CGContextAddPath(cxt, bgPath);
					// ... and fill it.
					CGContextFillPath(cxt);
				}

				CGContextSetFillColor(cxt, fillClrNarrow);
				CGContextAddPath(cxt, narrowPath);
				CGContextFillPath(cxt);

				// Make a CGImage out of the context
				img_cg = CGBitmapContextCreateImage(cxt);
				// Make a UIImage out of the CGImage
				img_ui = [UIImage imageWithCGImage:img_cg];

				// Clean up
				CGImageRelease(img_cg);
				CGContextRelease(cxt);
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);

				// Create the image view to hold the background rect which we just drew
				UIImageView* iv = [[UIImageView alloc] initWithImage:img_ui];
				self.cursorLandscapeOverlayOS = iv;

				cursorLandscapeOverlayOS.frame = CGRectMake(0, 0, recWidth, recHeight);
			}
			break;

		default:
			//*** Waterfall Cursor Creation ***//
			//*** Landscape ***//

			if(defaultsWorkingCopy.bpfBandwidth == 0.0)
			{
				recWidth =  displayLandscapeWidth;
				recHeight = 50;

				cursorWidthWF = recWidth;
				cursorHeightWF = recHeight;

				// Draw the rect for the bg path using this convenience function
				bgPath = nil; bgPath1 = nil; narrowPath = nil;
				narrowPath = createSharpRectPath(CGRectMake(0, recHeight/2-2, recWidth, 3));
			}
			else
			{
				recWidth =  displayLandscapeWidth;
				//recHeight = 2*defaultsWorkingCopy.bpfBandwidth * displayLandscapeHeight / sampleRateBandwidthHz;
				recHeight = (size_t)(2.*(float)(defaultsWorkingCopy.bpfBandwidth * displayLandscapeHeight)) / sampleRateBandwidthHz;

				cursorWidthWF = recWidth;
				cursorHeightWF = recHeight;

				// Draw the rect for the bg path using this convenience function
				bgPath = nil; bgPath1 = nil; narrowPath = nil;
				bgPath = createSharpRectPath(CGRectMake(0, 0, recWidth, recHeight/2-1));
				narrowPath = createSharpRectPath(CGRectMake(0, recHeight/2-1, recWidth, 3));
				bgPath1 = createSharpRectPath(CGRectMake(0, recHeight/2+1, recWidth, recHeight/2-1));
			}

			// Create the bitmap context into which we will draw
			cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

			if(cxt == NULL)
			{
				SDR_DEBUGPRINT(("Error: Could not create bit map context - 1\n"));
				// Clean up
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);
				if(bgPath1) CGPathRelease(bgPath1);
			}
			else
			{
				CGContextSetFillColorSpace(cxt, cs);

				if((bgPath != NULL) && (bgPath1 != NULL))
				{
					CGContextSetFillColor(cxt, fillClr);
					// Add the rect to the context...
					CGContextAddPath(cxt, bgPath);
					// ... and fill it.
					CGContextFillPath(cxt);

					CGContextAddPath(cxt, bgPath1);
					CGContextFillPath(cxt);
				}

				CGContextSetFillColor(cxt, fillClrNarrowWF);
				CGContextAddPath(cxt, narrowPath);
				CGContextFillPath(cxt);

				// Make a CGImage out of the context
				img_cg = CGBitmapContextCreateImage(cxt);
				// Make a UIImage out of the CGImage
				img_ui = [UIImage imageWithCGImage:img_cg];

				// Clean up
				CGImageRelease(img_cg);
				CGContextRelease(cxt);
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);
				if(bgPath1) CGPathRelease(bgPath1);

				// Create the image view to hold the background rect which we just drew
				UIImageView* iv = [[UIImageView alloc] initWithImage:img_ui];
				self.cursorLandscapeOverlayWF = iv;

				cursorLandscapeOverlayWF.frame = CGRectMake(0, 0, recWidth, recHeight);
			}


			//*** O-Scope Cursor Creation ***//
			//*** Landscape ***//

			if(defaultsWorkingCopy.bpfBandwidth == 0.0)
			{
				recWidth = 50;
				recHeight = gridHeight + cursorHeightOStweak; // 0.4375 * displayLandscapeHeight;

				cursorWidthOS = recWidth;
				cursorHeightOS = recHeight;

				// Draw the rect for the bg path using this convenience function
				bgPath = nil; bgPath1 = nil; narrowPath = nil;
				narrowPath = createSharpRectPath(CGRectMake(recWidth/2-2, 0, 3, recHeight));
			}
			else
			{
				//recWidth = 2*defaultsWorkingCopy.bpfBandwidth * displayLandscapeWidth / sampleRateBandwidthHz;
				recWidth = (float)(2.*defaultsWorkingCopy.bpfBandwidth * displayLandscapeWidth) / sampleRateBandwidthHz;
				recHeight = gridHeight + cursorHeightOStweak; // 0.4375 * displayLandscapeHeight;

				cursorWidthOS = recWidth;
				cursorHeightOS = recHeight;

				// Draw the rect for the bg path using this convenience function
				bgPath = createSharpRectPath(CGRectMake(0, 0, recWidth, recHeight));
				narrowPath = createSharpRectPath(CGRectMake(recWidth/2-2, 0, 3, recHeight));
			}


			// Create the bitmap context into which we will draw
			cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

			if(cxt == NULL)
			{
				SDR_DEBUGPRINT(("Error: Could not create bit map context - 1\n"));
				// Clean up
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);
			}
			else
			{
				CGContextSetFillColorSpace(cxt, cs);

				if(bgPath != NULL)
				{
					CGContextSetFillColor(cxt, fillClr);
					// Add the rect to the context...
					CGContextAddPath(cxt, bgPath);
					// ... and fill it.
					CGContextFillPath(cxt);
				}

				CGContextSetFillColor(cxt, fillClrNarrow);
				CGContextAddPath(cxt, narrowPath);
				CGContextFillPath(cxt);

				// Make a CGImage out of the context
				img_cg = CGBitmapContextCreateImage(cxt);
				// Make a UIImage out of the CGImage
				img_ui = [UIImage imageWithCGImage:img_cg];

				// Clean up
				CGImageRelease(img_cg);
				CGContextRelease(cxt);
				if(bgPath) CGPathRelease(bgPath);
				if(narrowPath) CGPathRelease(narrowPath);

				// Create the image view to hold the background rect which we just drew
				UIImageView* iv = [[UIImageView alloc] initWithImage:img_ui];
				self.cursorLandscapeOverlayOS = iv;

				cursorLandscapeOverlayOS.frame = CGRectMake(0, 0, recWidth, recHeight);
			}
			break;
	}

	CGColorSpaceRelease(cs);
}


- (NSString*)getFreqModeText
{
	if(fftBufferManager == nil) return nil;

	NSString* text;
	frequencyType frequency;

	if(mixerController.mAudioMode == AudioModeDemonstration)
	{
		FileStats *info = [mixerController getFileStats];
		if(info.centerFrequency >= 0.)
		{
			frequency = info.centerFrequency;
		}
		else
		{
			frequency = defaultsWorkingCopy.centerFrequency;
		}
	}
	else
	{
		frequency = (defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz);
	}

	frequency += ((fftBufferManager->getCenterFrequency() - .5) * sampleRateBandwidthKHz); // CW offset is taken into account by getCenterFrequency()

	NSString* freqString = [EAGLViewController frequencyString:frequency];

	switch(defaultsWorkingCopy.operatingMode)
	{
			// Don't include bandwidth setting
		case Binaural_mode:
			text = [NSString stringWithFormat:@"%@%s", freqString, modeText[defaultsWorkingCopy.operatingMode]];
			break;

			// Double the bandwidth setting for these modes
		case AM_mode:
		case NFM_mode:
			text = [NSString stringWithFormat:@"%@%s (%3.0f Hz)", freqString, modeText[defaultsWorkingCopy.operatingMode], 2*defaultsWorkingCopy.bpfBandwidth];

			break;

			// Print bandwidth setting normally for these modes
		default:
			text = [NSString stringWithFormat:@"%@%s (%3.0f Hz)", freqString, modeText[defaultsWorkingCopy.operatingMode], defaultsWorkingCopy.bpfBandwidth];
			break;

	}

	return text;
}


- (NSString*)getFileInfoText
{
	NSString* theText = nil;

	if(mixerController.mAudioMode == AudioModeDemonstration)
	{
		static UInt32 holdSeconds = UINT32_MAX;
		FileStats *info = [mixerController getFileStats];
		UInt32 seconds = (0.5 + (info.framesRead / info.frameRate));

		if(seconds == holdSeconds) return nil;

		//		SDR_DEBUGPRINT(("**fileName: %s\n", [info.fileName UTF8String]));

		theText = [NSString stringWithFormat:@"File: %@  Time:%3us / %3us", info.fileName, (unsigned int)seconds, (unsigned int)(info.filePlayTime)];
	}
	else
	{
#ifdef ISDR_BETA_BUILD
		//		SDR_DEBUGPRINT(("Fc = %4.1f  BW = %4lu\n", defaultsWorkingCopy.centerFrequency, sampleRateBandwidthHz));
		if(receiverModelText)
		{
			if(receiverModeText)
			{
				theText = [NSString stringWithFormat:@"%@ %@:%@ (offset:%0.0lf Hz)  -  λ = %2.0fm  -  %2.1f kHz Spectrum", receiverModelText, NSLocalizedString(@"Mode", nil), receiverModeText, receiverFrequencyOffsetHz, 300000./defaultsWorkingCopy.centerFrequency, sampleRateBandwidthKHz];
			}
			else
			{
				theText = [NSString stringWithFormat:@"%@ (offset:%0.0lf Hz)  -  λ = %2.0fm  -  %2.1f kHz Spectrum", receiverModelText, receiverFrequencyOffsetHz, 300000./defaultsWorkingCopy.centerFrequency, sampleRateBandwidthKHz];
			}
		}
		else if(receiverModeText)
		{
			theText = [NSString stringWithFormat:@"%@:%@ (offset:%0.0lf Hz)  -  λ = %2.0fm  -  %2.1f kHz Spectrum", NSLocalizedString(@"Mode", nil), receiverModeText, receiverFrequencyOffsetHz, 300000./defaultsWorkingCopy.centerFrequency, sampleRateBandwidthKHz];
		}
		else
		{
			theText = [NSString stringWithFormat:@"(offset:%0.0lf Hz)  -  λ = %2.0fm  -  %2.1f kHz Spectrum", receiverFrequencyOffsetHz, 300000./defaultsWorkingCopy.centerFrequency, sampleRateBandwidthKHz];
		}
#else
		//		SDR_DEBUGPRINT(("Fc = %4.1f  BW = %4lu\n", defaultsWorkingCopy.centerFrequency, sampleRateBandwidthHz));
		theText = [NSString stringWithFormat:@"λ = %2.0fm  -  %2.1f kHz Spectrum", 300000./defaultsWorkingCopy.centerFrequency, sampleRateBandwidthKHz];
#endif // ISDR_BETA_BUILD
	}

	return theText;
}


- (void)popFatalErrorMessage:(UInt32)reason
{
	UIAlertController *alert=nil;

	[self.eaglView stopAnimation];

	SDR_DEBUGPRINT(("popFatalErrorMessage\n"));

	switch(reason)
	{
			//			kAudioSessionRouteChangeReason_Unknown                    = 0,
			//			kAudioSessionRouteChangeReason_NewDeviceAvailable         = 1,
			//			kAudioSessionRouteChangeReason_OldDeviceUnavailable       = 2,
			//			kAudioSessionRouteChangeReason_CategoryChange             = 3,
			//			kAudioSessionRouteChangeReason_Override                   = 4,
			// this enum has no constant with a value of 5
			//			kAudioSessionRouteChangeReason_WakeFromSleep              = 6,
			//			kAudioSessionRouteChangeReason_NoSuitableRouteForCategory = 7

		case fatalAudioErrorDeviceLost:
        {
			alert = [UIAlertController
                     alertControllerWithTitle:NSLocalizedString(@"Audio Error:", nil)
                     message:NSLocalizedString(@"Device lost.\nApp needs to close.", nil)
                     preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *choice0;

            choice0 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"OK",nil) style:UIAlertActionStyleDefault
                       handler:nil];

            [alert addAction:choice0];
        }
			break;

		case fatalAudioErrorUnknownCause:
        {
            alert = [UIAlertController
                     alertControllerWithTitle:NSLocalizedString(@"Audio Error:", nil)
                     message:NSLocalizedString(@"App needs to close.", nil)
                     preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *choice0;

            choice0 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"OK",nil) style:UIAlertActionStyleDefault
                       handler:nil];

            [alert addAction:choice0];
        }
			break;

		default:
        {
			SDR_DEBUGPRINT(("Uncaught shutdown cause!\n"));
            alert = [UIAlertController
                     alertControllerWithTitle:NSLocalizedString(@"Error:", nil)
                     message:NSLocalizedString(@"App needs to close.", nil)
                     preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *choice0;

            choice0 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"OK",nil) style:UIAlertActionStyleDefault
                       handler:nil];

            [alert addAction:choice0];
        }
			break;
	}

	if(alert != nil)
	{
//		alert.tag = FatalError;
        [self presentViewController:alert animated:YES completion:nil];
	}
}


- (UIAlertController *)makeAlert:(BOOL)override tag:(NSInteger)tag title:(NSString *)title message:(NSString *)message textFieldText:(NSString*)textFieldText delegate:(id)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSArray *)otherButtonTitles
{
	BOOL threadIsMain = [NSThread isMainThread];
//    __block UIAlertController *alert = nil;
    UIAlertController *alert = nil;

	if(threadIsMain)
	{
        alert = [UIAlertController
                 alertControllerWithTitle:title
                 message:message
                 preferredStyle:UIAlertControllerStyleAlert];

        if(cancelButtonTitle) {
            UIAlertAction *choice0 = [UIAlertAction
                       actionWithTitle:cancelButtonTitle style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:alert Button:0 Tag:tag];}];

            [alert addAction:choice0];
        }

		if(otherButtonTitles) // The first argument isn't part of the varargs list,
		{                                   // so we'll handle it separately.
            NSInteger bi = 0;

            for(NSString* button in otherButtonTitles)
            {
                bi++;
                UIAlertAction *choice = [UIAlertAction actionWithTitle:button style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:alert Button:bi Tag:tag];}];
                [alert addAction:choice];
//                NSLog(@"Button %ld Tag %ld", (long)bi, (long)tag);
            }
		}

		if(textFieldText)
		{
			UITextField* tf = [UITextField new];
			tf.clearButtonMode = UITextFieldViewModeWhileEditing;

            [alert addTextFieldWithConfigurationHandler:^(UITextField * tf) {
//                tf.placeholder = @"nn.nn.nn.nn";
                tf.text = textFieldText;
                tf.keyboardType = UIKeyboardTypeDecimalPad;
            }];

	///////////////////////////////////////////////////////////////////////////////////////////
//			// Wifi support changes
//			if(tag == IPAddressError)
//			{
//				[tf setKeyboardType:UIKeyboardTypeDecimalPad];
//			}
//			else
//			{
//                [tf setKeyboardType:UIKeyboardTypeDecimalPad];
////				[tf setKeyboardType:UIKeyboardTypeDefault];
//			}
//			// Wifi support changes
			///////////////////////////////////////////////////////////////////////////////////////////
		}

        [self presentViewController:alert animated:YES completion:nil];
	}

	return alert;
}


- (void)prepareForBackground
{
	SDR_DEBUGPRINT(("prepareForBackground\n"));

	runningInBackground = TRUE;
	holdWifiState = wifi.state;

	if(rssiMeter)
	{
		[rssiMeter sleep];
		[rssiMeter zeroMeter];
		rssiMeter.inBackground = TRUE;
	}

	///////////////////////////////////////////////////////////////////////////////////////////
	// Wifi support changes
	[wifi sendCommand_AI:0];
	// Wifi support changes
	///////////////////////////////////////////////////////////////////////////////////////////

	// Save any changes to default settings, then create a copy for later comparison
	appDelegate.defaults = defaultsWorkingCopy;
	[appDelegate writeDefaultsToFileSystem];
	holdDefaults = defaultsWorkingCopy;

	[self hideButtonCountdown:FireTimer selector:@selector(hideFreqOverlay)];

	savedAnimationState = eaglView.animationState;

	if(savedAnimationState)
	{
		[self.eaglView stopAnimation];
	}

	self.view.userInteractionEnabled = FALSE;

	// Ensure all touch states are initialized
	twoTouchFrequencyEvent = nil;
	slideFrequencyEvent = nil;
	twoTouchFrequencyEvent = nil;
	simpleTouchFrequencyEvent = nil;
	self.baseTouch = nil;
	self.slidingTouch = nil;

	[self.eaglView enableLayout];

	[self.eaglView clearView:TRUE];

	if(!defaultsWorkingCopy.playWhileMinimized || (switchCtl.on == FALSE))
	{
		mixerController.mute = TRUE;
		[mixerController stopAUGraph:FALSE]; // stop audio flow
		switchCtl.on = FALSE; // ensure switch reflects audio flow state
	}

	///////////////////////////////////////////////////////////////////////////////////////////
	// Wifi support changes
	[wifi removeAllListeners];
	[wifi disableWifiInterface:NO]; // shut down any wifi search/connect operations that might be ongoing

    if(wifiStateTranstionAlert) [wifiStateTranstionAlert dismissViewControllerAnimated:FALSE completion:nil];
    if(wifiDisabledOnDeviceAlert) [wifiDisabledOnDeviceAlert dismissViewControllerAnimated:FALSE completion:nil];
    if(wifiEnterNewIPAddress) [wifiEnterNewIPAddress dismissViewControllerAnimated:FALSE completion:nil];
    if(wifiConnectionLostAlert) [wifiConnectionLostAlert dismissViewControllerAnimated:FALSE completion:nil];

	// Wifi support changes
	///////////////////////////////////////////////////////////////////////////////////////////
}


- (void)returnFromBackground
{
	SDR_DEBUGPRINT(("returnFromBackground\n"));

	if(runningInBackground)
	{
		runningInBackground = FALSE;

		SDR_DEBUGPRINT(("Returned from background...\n"));

		if(rssiMeter)
		{
			mixerController.mcMixerUser = rssiMeter;
			[rssiMeter setAu:mixerController.mMixerUnit];

			rssiMeter.inBackground = FALSE;

			if(self.displayMode != DisplayModeWaterfall)
			{
				[rssiMeter showMeter:NO];
			}
			else
			{
				[rssiMeter hideMeter:NO];
			}

			[self clearTextures];
			[self setupDrawBuffers];
		}

		BOOL doReconfigureDisplay = FALSE;

		[self getSavedSettings]; // reload defaultsWorkingCopy

		if(holdDefaults.wifiFunctionalityEnabled != defaultsWorkingCopy.wifiFunctionalityEnabled)
		{
			[self configureUserInterface];
			doReconfigureDisplay = TRUE;
			SDR_DEBUGPRINT(("Enabled features changed while in background!\n"));

			if(defaultsWorkingCopy.wifiFunctionalityEnabled)
			{
				///////////////////////////////////////////////////////////////////////////////////////////
				// Wifi support changes
				// Re-enable all the listeners
				[wifi addWifiStateListener:wifiButton];
				[wifi addWifiStateListener:self];
				[wifi addWifiResultListener:self]; // register to receive notifications from the singleton
				[wifi addCenterFrequencyListener:self]; // register to receive notifications for changes to the center frequency setting
				[wifi addRadioInfoListener:self]; // register to receive notifications for changes to the center frequency setting
				[wifi prepInterface:YES]; // this needs to happen AFTER wifi state listeners have been set
				// Wifi support changes
				///////////////////////////////////////////////////////////////////////////////////////////
			}
		}
		else
		{
			SDR_DEBUGPRINT(("Enabled features did not change while in background!\n"));

			if(defaultsWorkingCopy.wifiFunctionalityEnabled)
			{
				///////////////////////////////////////////////////////////////////////////////////////////
				// Wifi support changes
				// Re-enable all the listeners
				[wifi addWifiStateListener:wifiButton];
				[wifi addWifiStateListener:self];
				[wifi addWifiResultListener:self]; // register to receive notifications from the singleton
				[wifi addCenterFrequencyListener:self]; // register to receive notifications for changes to the center frequency setting
				[wifi addRadioInfoListener:self]; // register to receive notifications for changes to the center frequency setting
				[wifi prepInterface:NO]; // this needs to happen AFTER wifi state listeners have been set
				// Wifi support changes
				///////////////////////////////////////////////////////////////////////////////////////////
			}
		}

		if(holdDefaults.centerFrequency != defaultsWorkingCopy.centerFrequency)
		{
			doReconfigureDisplay = TRUE;
			SDR_DEBUGPRINT(("Center frequency changed while in background!\n"));
		}

		if(holdDefaults.operatingMode != defaultsWorkingCopy.operatingMode)
		{
			switch (defaultsWorkingCopy.operatingMode)
			{
				case CW_mode:
					defaultsWorkingCopy.bpfBandwidth = 1000.;
					break;

				case LSB_mode:
				case USB_mode:
					defaultsWorkingCopy.bpfBandwidth = 3000.;
					break;

				case AM_mode:
					defaultsWorkingCopy.bpfBandwidth = 6000.;
					break;

				case NFM_mode:
					defaultsWorkingCopy.bpfBandwidth = 16000.;
					break;

				case Binaural_mode:
					defaultsWorkingCopy.bpfBandwidth = 0.;
					break;

				default:
					break;
			}

			doReconfigureDisplay = TRUE;

			appDelegate.defaults = defaultsWorkingCopy;

			[appDelegate writeDefaultsToFileSystem];
			// Probably need to reconfigure the app radio for this to work
			SDR_DEBUGPRINT(("Operating mode changed while in background!\n"));
		}

		if(holdDefaults.reverseIQ != defaultsWorkingCopy.reverseIQ)
		{
			doReconfigureDisplay = TRUE;
			SDR_DEBUGPRINT(("ReverseIQ changed while in background!\n"));
		}

		if(holdDefaults.bpfBandwidth != defaultsWorkingCopy.bpfBandwidth)
		{
			doReconfigureDisplay = TRUE;
			// Probably need to reconfigure the radio for this to work
			SDR_DEBUGPRINT(("BPF Bandwidth changed while in background!\n"));
		}

		if(holdDefaults.agcSetting != defaultsWorkingCopy.agcSetting)
		{
			doReconfigureDisplay = TRUE;
			// Also need to reconfigure the radio for this to work
			SDR_DEBUGPRINT(("AGC Setting changed while in background!\n"));
		}

		if(holdDefaults.demoModeOnly != defaultsWorkingCopy.demoModeOnly)
		{
			//doReconfigureDisplay = TRUE;
			[self applyRadioSettings:FALSE];
			SDR_DEBUGPRINT(("DemoModeOnly changed while in background!\n"));
		}

		if(holdDefaults.rxOffset != defaultsWorkingCopy.rxOffset)
		{
			doReconfigureDisplay = TRUE;
			SDR_DEBUGPRINT(("RXOffset changed while in background!\n"));
		}

		if(holdDefaults.simpleTouchMode != defaultsWorkingCopy.simpleTouchMode)
		{
			SDR_DEBUGPRINT(("SimpleTouchMode changed while in background!\n"));
		}

		if(holdDefaults.gridType != defaultsWorkingCopy.gridType)
		{
			doReconfigureDisplay = TRUE;
			SDR_DEBUGPRINT(("GridType changed while in background!\n"));
		}

		if(holdDefaults.gridBrightness != defaultsWorkingCopy.gridBrightness)
		{
			doReconfigureDisplay = TRUE;
			SDR_DEBUGPRINT(("GridBrightness changed while in background!\n"));
		}

		if(holdDefaults.signalScaleFactor != defaultsWorkingCopy.signalScaleFactor)
		{
			fftBufferManager->setSignalScaleFactor( defaultsWorkingCopy.signalScaleFactor);
			SDR_DEBUGPRINT(("SignalScaleFactor changed while in background!\n"));
		}

		///////////////////////////////////////////////////////////////////////////////////////////
		// Wifi support changes
		// Update wifi with any changes to the port settings
		if(defaultsWorkingCopy.wifiFunctionalityEnabled)
		{
			BOOL portsUpdate = FALSE;
			NSString* val = appDelegate.dataPort;

			if(holdDefaults.reversePlusMinus != defaultsWorkingCopy.reversePlusMinus)
			{
				doReconfigureDisplay = TRUE;
			}

			if(![wifi.dataPort isEqualToString:val])
			{
				wifi.dataPort = val;
				portsUpdate = TRUE;
			}

			val = appDelegate.commandPort;
			if(![wifi.commandPort isEqualToString:val])
			{
				wifi.commandPort = val;
				portsUpdate = TRUE;
			}

			if(portsUpdate)
			{
				[self alertUserOfPortChanges:wifi.dataPort commandPort:wifi.commandPort];
			}

			// Need to check IP settings to ensure that they are still set to legal values
			NSString* ipAddr = appDelegate.ipAddress;
			ipAddressText.text = [self ipAddressString];
			centerFrequencyText.text = switchCtl.plainToggle ? @"": [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];
			[self drawButtons:buttonsRedraw];

			BOOL ok2connect = (holdWifiState & SocketEstablished);

			if((ipAddr == nil) && (holdWifiState != Disconnected))
			{
				if(wifiEnterNewIPAddress == nil)
				{
					[self performBlockOnMainThread:^{
                        self->wifiEnterNewIPAddress = [self makeAlert:NO tag:IPAddressError title:NSLocalizedString(@"Enter Valid IP Address", @"") message:nil textFieldText:DEFAULT_IP_ADDRESS delegate:self cancelButtonTitle:NSLocalizedString(@"Done", @"") otherButtonTitles:nil];

                        if(self->defaultsWorkingCopy.soundEffectsEnabled) [self->mixerController playErrorSound];
					}];
				}

				ok2connect = FALSE;
			}

			if(!wifi.wifiIsAvailable && (holdWifiState != Disconnected))
			{
				[self performBlockOnMainThread:^{
                    if(self->wifiDisabledOnDeviceAlert == nil)
					{
                        self->wifiDisabledOnDeviceAlert = [self makeAlert:NO tag:EnableWifiOnDevicePrompt title:NSLocalizedString(@"Wi-Fi Unavailable!", @"") message:NSLocalizedString(@"Wi-Fi is disabled on this device. Please enable in native Settings.", @"") textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];

                        if(self->defaultsWorkingCopy.soundEffectsEnabled) [self->mixerController playErrorSound];
					}
				}];

				ok2connect = FALSE;
			}

			if(ok2connect)
			{
				///////////////////////////////////////////////////////////////////////////////////////////
				// Wifi support changes
				// Give wifi plenty of time to set up its run loop before trying to establish a wifi connection.
				// The user is not likely to notice even if we are very generous since the splash screen will
				// be displayed for several seconds anyway.
				if(defaultsWorkingCopy.hasSuccessfullyConnectedViaWifi)
				{
					[self performSelector:@selector(establishWifiConnection) withObject:nil afterDelay:.5];
				}
				else
				{
					// go straight to Wi-Fi Disconnected state
					[self performSelector:@selector(setupForWifiDisconnectedState) withObject:nil afterDelay:0.1];
				}
				// Wifi support changes
				///////////////////////////////////////////////////////////////////////////////////////////
			}
			else
			{
				[self setupForWifiDisconnectedState];
			}
		}
		//		[self applyRadioSettings:YES];
		// Wifi support changes
		///////////////////////////////////////////////////////////////////////////////////////////

		if(doReconfigureDisplay)
		{
			[self reconfigureDisplaySetup:reInitializeAudioSettings];

			// set switch to off state
			switchCtl.state = SwitchOff;
		}

		if(savedAnimationState)
		{
			// start audio display
			if(rssiMeter)
			{
				[rssiMeter wake];
			}

			fftBufferManager->AudioBufferFlush();
			// start audio display

			mixerController.mute = FALSE;
			[mixerController startAUGraph:FALSE]; // start audio flow
			switchCtl.on = 	YES;

			[self.eaglView startAnimation];
			mixerController.mAutoconfigEnabled = TRUE;
			centerFrequencyText.text = switchCtl.plainToggle ? @"": [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];
		}

		self.view.userInteractionEnabled = TRUE;

		[self flushAudio];
	}
#ifdef SDR_DEBUG
	else
	{
		SDR_DEBUGPRINT(("returnFromBackground: not paused - unpause ignored.\n"));
	}
#endif
}

///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
- (void)configureForWifi
{
	defaultsWorkingCopy = appDelegate.defaults;
	[self configureUserInterface];
	SDR_DEBUGPRINT(("Configuring app for wifi settings.\n"));

	if(defaultsWorkingCopy.wifiFunctionalityEnabled)
	{
		///////////////////////////////////////////////////////////////////////////////////////////
		// Wifi support changes
		// Re-enable all the listeners
		[wifi addWifiStateListener:wifiButton];
		[wifi addWifiStateListener:self];
		[wifi addWifiResultListener:self]; // register to receive notifications from the singleton
		[wifi addCenterFrequencyListener:self]; // register to receive notifications for changes to the center frequency setting
		[wifi addRadioInfoListener:self]; // register to receive notifications for changes to the center frequency setting
		[wifi prepInterface:YES]; // this needs to happen AFTER wifi state listeners have been set
		// Wifi support changes
		///////////////////////////////////////////////////////////////////////////////////////////
	}
}

- (void)alertUserOfPortChanges:(NSString*)dataPort commandPort:(NSString*)commandPort
{
	if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playErrorSound];
	[self makeAlert:NO tag:PortValuesChanged title:NSLocalizedString(@"Port Settings Changed!", @"") message:[NSString stringWithFormat:@"%@: %@\n%@: %@\n%@", NSLocalizedString(@"Command Port", nil), commandPort, NSLocalizedString(@"Data Port", nil), dataPort, NSLocalizedString(@"Use native Settings to make corrections if necessary.", nil)] textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
}
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////


- (BOOL)popoverControllerShouldDismissPopover:(id)_popoverController
{
	if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		SDR_DEBUGPRINT(("iPad! willRotate\n"));
		if(prefViewController)
		{
			[prefViewController preferencesFinished];
		}
	}
	else
	{
		[self preferencesFinished];
	}

	return YES;
}


- (void)reconfigureDisplaySetup:(UInt32)reason
{
	SDR_DEBUGPRINT(("reconfigureDisplaySetup\n"));

	if(reason != reInitializeAudioSettings) // using this constant to flag "no error". Safe?
	{
		[self popFatalErrorMessage:reason];
	}
	else
	{
		initted_oscilloscope = FALSE;
		displayInitialized = FALSE;

		savedAnimationState = eaglView.animationState;
		if(savedAnimationState)
		{
			[self.eaglView stopAnimation];
		}

		self.view.userInteractionEnabled = FALSE;
		twoTouchFrequencyEvent = nil;
		slideFrequencyEvent = nil;
		simpleTouchFrequencyEvent = nil;

		///////////////////////////////////////////////////////////////////////////////////////////
		// Wifi support changes
		CGRect frameP, frameM;
		if(defaultsWorkingCopy.reversePlusMinus)
		{
			frameP = CGRectMake((0.325 * displayLandscapeWidth)-50., displayLandscapeHeight + tunebarVertHeightOffset - tunebarHeight/2.-50., 100, 100);
			frameM = CGRectMake((0.675 * displayLandscapeWidth)-50., displayLandscapeHeight + tunebarVertHeightOffset - tunebarHeight/2-50., 100, 100);
		}
		else
		{
			frameP = CGRectMake((0.675 * displayLandscapeWidth)-50., displayLandscapeHeight + tunebarVertHeightOffset - tunebarHeight/2-50., 100, 100);
			frameM = CGRectMake((0.325 * displayLandscapeWidth)-50., displayLandscapeHeight + tunebarVertHeightOffset - tunebarHeight/2.-50., 100, 100);
		}

		plusButton.frame = frameP;
		minusButton.frame = frameM;
		// Wifi support changes
		///////////////////////////////////////////////////////////////////////////////////////////

		if(!runningInBackground)
		{
			[frequencyOverlayLandscape removeFromSuperview];
			frequencyOverlayLandscape.isVisible = FALSE;
			frequencyOverlayLandscape.doNotTimeout = FALSE;
			//frequencyTextLandscape.textColor = [UIColor whiteColor];
			frequencyTextLandscape.alpha = 1.;
			frequencyTextLandscape.shadowColor = [UIColor clearColor];

			[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:TRUE useFrequency:-1.]; // erase any cursor overlays that have been drawn
			[self.switchCtl removeFromSuperview];
			[self.eaglView setNeedsLayout];
			[self.eaglView drawView];
		}

		fftBufferManager = mixerController.fftBufferManager;
		sampleRateBandwidthHz = (float)mixerController.sampleRateBandwidth;
		sampleRateBandwidthKHz = sampleRateBandwidthHz / 1000.;
		kHertzPerScreenElement = (self.displayMode == DisplayModeWaterfall) ? (sampleRateBandwidthKHz / displayLandscapeHeight) : (sampleRateBandwidthKHz / displayLandscapeWidth);

		if(rssiMeter)
		{
			mixerController.mcMixerUser = rssiMeter;
			[rssiMeter setAu:mixerController.mMixerUnit];
//			[rssiMeter wake];
		}

		fftBufferManager->AudioBufferFlush();

		SDR_DEBUGPRINT(("EAGLview rec'd sampleRateBandwidthHz = %0.0f\n", sampleRateBandwidthHz));

		if(mixerController.mAudioMode == AudioModeDemonstration)
		{
			SDR_DEBUGPRINT(("Starting recorded audio...\n"));
		}
		else
		{
			SDR_DEBUGPRINT(("Receiving live audio (4)...\n"));
		}

		[self initializeRadioSettings];

		// Put audio into state based on switch position
		// Also taking into account that animation might be off if
		// the menu is covering the screen on iPod touch/iPhone
		if((switchCtl.on == TRUE) && (savedAnimationState))
		{
			// start audio display
			if(!runningInBackground) [self.eaglView startAnimation];
			mixerController.mute = FALSE;
			[mixerController startAUGraph:FALSE]; // start audio flow
		}
		else
		{
			[self.eaglView stopAnimation];
			mixerController.mute = TRUE;
			[mixerController stopAUGraph:FALSE]; // stop audio flow
			switchCtl.on = FALSE; // ensure switch reflects audio flow state
			[switchCtl applyState:SwitchOff];
		}

		fftBufferManager->setCopyRawPCM(TRUE); // prevents rare illegal access when enabling live audio

		if(!runningInBackground)
		{
			[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:FALSE useFrequency:-1.];

			if((self.displayMode) == DisplayModeWaterfall)
			{
				SDR_DEBUGPRINT(("Clearing waterfall...\n"));
				//			[self drawButtons:buttonsHide];

				if(!initted_spectrum) [self setupViewForSpectrum];
				[self clearTextures];

				[self drawFrequencyOverlay];
				[self drawButtons:buttonsTurnOn];
				[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];

				numDrawBuffers = kWaveformDrawBuffers;
				drawBufferLen = kWaveformDrawSamples;
				[self setupDrawBuffers];
			}
			else
			{
				[self setupDrawBuffers];
				[self drawFrequencyOverlay];
			}

			[self setUpForDisplayMode:self.displayMode];

			[self.eaglView setNeedsLayout];
		}

		self.view.userInteractionEnabled = TRUE;
	}

	return;
}

- (void)PrintDiagnostics:(iSDRAudioStatus)status inputAvail:(UInt32)audioInputAvailable numChans:(UInt32)numChannels sampleRate:(UInt32)sampleRate maxfps:(UInt32)fps
{
	UIAlertController *alert=nil;
	NSString* cellMessage;

	switch(status)
	{
		case AudioError:
        {
			cellMessage = [NSString stringWithFormat:@"%@: %u kHz \nInput available: %@ \nChannels: %u \nmaxFPS: %u",NSLocalizedString(@"Audio Error\nSample rate:", @""), (unsigned int)sampleRate, ((int)audioInputAvailable == 1) ? NSLocalizedString(@"Yes", @""):NSLocalizedString(@"No", @""), (unsigned int)numChannels, (unsigned int)fps];

            alert = [UIAlertController
                     alertControllerWithTitle:NSLocalizedString(@"Audio Error", nil)
                     message:cellMessage
                     preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction* choice0 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Exit",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:alert Button:0 Tag:0];}];

            UIAlertAction* choice1 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Continue",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:alert Button:1 Tag:0];}];

            [alert addAction:choice0];
            [alert addAction:choice1];
        }
			break;

		case AudioReady:
        {
			cellMessage = [NSString stringWithFormat:@"%@: %u kHz \nInput available: %@ \nChannels: %u \nmaxFPS: %u",NSLocalizedString(@"Audio Ready\nSample rate", @""), (unsigned int)sampleRate, ((int)audioInputAvailable == 1) ? NSLocalizedString(@"Yes", @""):NSLocalizedString(@"No", @""), (unsigned int)numChannels, (unsigned int)fps];

            alert = [UIAlertController
                     alertControllerWithTitle:NSLocalizedString(@"Audio Ready:", nil)
                     message:cellMessage
                     preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction* choice0 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Exit",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:alert Button:0 Tag:0];}];

            UIAlertAction* choice1 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Continue",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:alert Button:1 Tag:0];}];

            [alert addAction:choice0];
            [alert addAction:choice1];
        }
			break;

		case AudioNotReady:
        {
			cellMessage = [NSString stringWithFormat:@"%@: %u kHz \nInput available: %@ \nChannels: %u \nmaxFPS: %u",NSLocalizedString(@"Audio Not Ready\nSample rate", @""), (unsigned int)sampleRate, ((int)audioInputAvailable == 1) ? NSLocalizedString(@"Yes", @""):NSLocalizedString(@"No", @""), (unsigned int)numChannels, (unsigned int)fps];

            alert = [UIAlertController
                     alertControllerWithTitle:NSLocalizedString(@"Audio Not Ready", nil)
                     message:cellMessage
                     preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction* choice0 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Exit",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:alert Button:0 Tag:0];}];

            UIAlertAction* choice1 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Continue",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:alert Button:1 Tag:0];}];

            [alert addAction:choice0];
            [alert addAction:choice1];

        }
			break;

		default:
        {
			cellMessage = [NSString stringWithFormat:@"%@: %u kHz \nInput available: %@ \nChannels: %u \nmaxFPS: %u",NSLocalizedString(@"Unknown\nSample rate", @""), (unsigned int)sampleRate, ((int)audioInputAvailable == 1) ? NSLocalizedString(@"Yes", @""):NSLocalizedString(@"No", @""), (unsigned int)numChannels, (unsigned int)fps];

            alert = [UIAlertController
                     alertControllerWithTitle:NSLocalizedString(@"Audio Unknown State:", nil)
                     message:cellMessage
                     preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction* choice0 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Exit",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:alert Button:0 Tag:0];}];

            UIAlertAction* choice1 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Continue",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:alert Button:1 Tag:0];}];

            [alert addAction:choice0];
            [alert addAction:choice1];

        }
			break;
	}

	if(alert != nil)
	{
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#ifdef SDR_DEBUG
//- (void)PrintMessage:(char*)msg
//{
//	NSString *cellMessage = [NSString stringWithUTF8String:msg];
//
//	UIAlertController *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Diagnostics:", nil) message:cellMessage
//												   delegate:self cancelButtonTitle:NSLocalizedString(@"Exit", nil) otherButtonTitles:NSLocalizedString(@"Continue", nil), nil];
//	if(alert != nil)
//	{
//		[alert show];
//	}
//}
#endif


- (OSStatus)setFile:(NSURL *)fileURL
{
	if(switchCtl.on == TRUE)
	{
		[self.eaglView stopAnimation];
		mixerController.mute = TRUE;
		[mixerController stopAUGraph:FALSE]; // stop audio flow
	}

	OSStatus result = [mixerController loadFile:fileURL setupIfNeeded:TRUE];

	fftBufferManager->AudioBufferFlush();

	if((switchCtl.on == TRUE) && (result == noErr))
	{
		// start audio display
		if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
		{
			[self.eaglView startAnimation];
		}

		mixerController.mute = FALSE;
		[mixerController startAUGraph:FALSE]; // start audio flow
	}

	return result;
}


- (NSURL *)getCurrentFileURL
{
	return [mixerController getCurrentFileURL];
}


- (BOOL)getFilePlayActive
{
	return (mixerController.mAudioMode == AudioModeDemonstration);
}


- (void)setFilePlayActive:(BOOL)useFileAudio
{
	if(useFileAudio)
	{
		holdDefaults.demoModeOnly = TRUE;
	}
	else
	{
		holdDefaults.demoModeOnly = FALSE;
	}

	appDelegate.defaults = holdDefaults;
	defaultsWorkingCopy = appDelegate.defaults;

	SDR_DEBUGPRINT(("Applying radio settings...\n"));
	[self applyRadioSettings:TRUE];

	return;
}

- (void)flushAudio
{
	fftBufferManager->AudioBufferFlush();
}

- (void)createSemiLogGridOverlay:(BOOL)useSmallText
{
	UIImage *img_ui = nil;
	size_t recWidth, recHeight;
	CGFloat fillClr[4], lineClr[4];

	// make sure the scale overlay is removed before releasing it!!
	if(semiLogGridOverlay)
	{
		[semiLogGridOverlay removeFromSuperview];
	}

	self.semiLogGridOverlay = nil;

	{
		fillClr[0]=1.; fillClr[1]=1.; fillClr[2]=1.; fillClr[3]=0.0; // transparent
		lineClr[0]=1.; lineClr[1]=1.; lineClr[2]=1.; lineClr[3]=1.0; // scale line color

		CGPathRef bgPath = nil, narrowPath = nil;
		CGContextRef cxt = nil;
		CGImageRef img_cg = nil;

		CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

		recWidth = gridWidth;
		recHeight = gridHeight;

		//SDR_DEBUGPRINT(("Meters/pixel = %3.2f  recWidth=%ld\n", metersPerPixel, recWidth));

		// Draw the rect for the bg path using this convenience function
		bgPath = createSharpRectPath(CGRectMake(0, 0, recWidth, recHeight));

		// Create the bitmap context into which we will draw
		cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

		if(cxt == NULL)
		{
			SDR_DEBUGPRINT(("Error: Could not create bit map context - 1\n"));
			if(bgPath) CGPathRelease(bgPath);
			if(narrowPath) CGPathRelease(narrowPath);
		}
		else
		{
			CGContextSetFillColorSpace(cxt, cs);

			//		CGContextSetTextPosition(cxt, recWidth/2, recHeight/2);
			CGContextSetRGBFillColor(cxt, 0.65, 0.88, 1.0, 1.0);
			CGContextSetRGBStrokeColor(cxt, 0.65, 0.88, 1.0, 1.0);

			NSString* text;
			size_t textLen;

			// Some initial setup for our text drawing needs.
			// First, we will be doing our drawing in Helvetica-36pt with the MacRoman encoding.
			// This is an 8-bit encoding that can reference standard ASCII characters
			// and many common characters used in the Americas and Western Europe.
			//			CGContextSelectFont(cxt, "Helvetica", 12.0, kCGEncodingMacRoman);
			// Next we set the text matrix to flip our text upside down. We do this because the context itself
			// is flipped upside down relative to the expected orientation for drawing text (much like the case for drawing Images & PDF).
			////CGContextSetTextMatrix(cxt, CGAffineTransformMakeScale(1.0, -1.0));
			// And now we actually draw some text. This screen will demonstrate the typical drawing modes used.
			CGContextSetTextDrawingMode(cxt, kCGTextFill);
			//CGContextShowTextAtPoint(cxt, recWidth/2-(8*textLen/2), recHeight/2, [text fileSystemRepresentation], textLen);
			//		CGContextSetFillColor(cxt, fillClr);
			// Add the rect to the context...
			//		CGContextAddPath(cxt, bgPath);
			// ... and fill it.
			//		CGContextFillPath(cxt);

			CGContextSetLineWidth(cxt, 3.0);
			CGColorRef color = CGColorCreate(cs, lineClr);
			CGContextSetStrokeColorWithColor(cxt, color); // line drawing color

			// draw base
			CGContextMoveToPoint(cxt, 0, 0);
			CGContextAddLineToPoint(cxt, recWidth, 0);
			CGContextStrokePath(cxt);

			if(useSmallText)
			{
				text = [NSString stringWithFormat:@"E%d", 0];
			}
			else
			{
				text = [NSString stringWithFormat:@"1e%d", 0];
			}

			textLen = [text lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
			UIColor* c = [UIColor whiteColor];

			NSDictionary *attribs = @{NSFontAttributeName:[UIFont fontWithName:@"Helvetica" size:12.0], NSForegroundColorAttributeName:c};
			NSAttributedString *fontStr = [[NSAttributedString alloc] initWithString:text attributes:attribs];

			CTLineRef displayLine = CTLineCreateWithAttributedString( (__bridge CFAttributedStringRef)fontStr );
			UIGraphicsBeginImageContext( CGSizeMake(recWidth, recHeight) ); // seems to be required to avoid nil context error
			CGContextSetTextPosition( cxt, 4, 4 );
			CTLineDraw( displayLine, cxt );
			CGContextSetTextPosition( cxt, recWidth-4-7*textLen, 4 );
			CTLineDraw( displayLine, cxt );

			CFRelease( displayLine );

			// draw top
			CGContextMoveToPoint(cxt, 0, recHeight);
			CGContextAddLineToPoint(cxt, recWidth, recHeight);
			CGContextStrokePath(cxt);

			// draw left edge
			CGContextMoveToPoint(cxt, 0, 0);
			CGContextAddLineToPoint(cxt, 0, recHeight);
			CGContextStrokePath(cxt);

			CGContextSetLineWidth(cxt, 1.0);

			double integralPart1, integralPart5;
			float remainderPart1 = modf(sampleRateBandwidthHz/1000., &integralPart1);
			float remainderPart5 = modf(sampleRateBandwidthHz/5000., &integralPart5);

			SDR_DEBUGPRINT(("remainderPart = %0.2f\n", remainderPart1));
			float stepSize1 = 1000. * displayLandscapeWidth/sampleRateBandwidthHz;
			float stepSize5 = 5000. * displayLandscapeWidth/sampleRateBandwidthHz - 0.001; // ensure x1 will catch up to x5

			float x1=stepSize1*remainderPart1/2.;
			float x5=stepSize5*remainderPart5/2.;

			while(x1 < recWidth)
			{
				SDR_DEBUGPRINT(("x1=%0.3f x5=%0.3f \n", x1, x5));
				CGContextMoveToPoint(cxt, x1, 0);
				if(x1 >= x5)
				{
					CGContextAddLineToPoint(cxt, x1, recHeight);
					x5 = x1 + stepSize5;
				}
				else
				{
					CGContextAddLineToPoint(cxt, x1, 5);
				}
				CGContextStrokePath(cxt);
				x1 += stepSize1;
			}
			CGContextSetLineWidth(cxt, 3.0);

			// draw right edge
			CGContextMoveToPoint(cxt, recWidth, 0);
			CGContextAddLineToPoint(cxt, recWidth, recHeight);
			CGContextStrokePath(cxt);

			CGContextSetLineWidth(cxt, 1.0);
			float y=0;
			float decadesToDraw = 6;
			for(int decades=1; y<recHeight && decades<=decadesToDraw; decades++)
			{
				for(int i=2; y<recHeight && i<=10; i++)
				{
					float yy = y + log10((double)i) * (recHeight/decadesToDraw);
					SDR_DEBUGPRINT(("y = %0.2f\n", yy));
					if(y<recHeight)
					{
						CGContextMoveToPoint(cxt, 0, yy);
						CGContextAddLineToPoint(cxt, recWidth, yy);
						CGContextStrokePath(cxt);
					}
				}

				y = decades * recHeight / decadesToDraw;

				if(y<recHeight)
				{
					CGContextMoveToPoint(cxt, 0, y);
					CGContextAddLineToPoint(cxt, recWidth, y);
					CGContextStrokePath(cxt);

					if(useSmallText)
					{
						text = [NSString stringWithFormat:@"E%d", decades];
					}
					else
					{
						text = [NSString stringWithFormat:@"1e%d", decades];
					}

					textLen = [text lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

					NSAttributedString *fontStr = [[NSAttributedString alloc] initWithString:text attributes:attribs];

					CTLineRef displayLine = CTLineCreateWithAttributedString( (__bridge CFAttributedStringRef)fontStr );
					UIGraphicsBeginImageContext( CGSizeMake(recWidth, recHeight) ); // seems to be required to avoid nil context error
					CGContextSetTextPosition( cxt, 4, y+4 );
					CTLineDraw( displayLine, cxt );
					CGContextSetTextPosition( cxt, recWidth-4-7*textLen, y+4 );
					CTLineDraw( displayLine, cxt );

					CFRelease( displayLine );
				}
			}

			CGColorRelease(color);

			// Make a CGImage out of the context
			img_cg = CGBitmapContextCreateImage(cxt);
			// Make a UIImage out of the CGImage
			img_ui = [UIImage imageWithCGImage:img_cg];

			// Clean up
			CGImageRelease(img_cg);
			CGContextRelease(cxt);
			if(bgPath) CGPathRelease(bgPath);
			if(narrowPath) CGPathRelease(narrowPath);

			// Create the image view to hold the background rect which we just drew
			UIImageView* iv = [[UIImageView alloc] initWithImage:img_ui];
			self.semiLogGridOverlay = iv;

			semiLogGridOverlay.frame = CGRectMake(0, 0, recWidth, recHeight);
		}

		semiLogGridOverlay.center = CGPointMake(displayLandscapeWidth/2, recHeight/2+displayStatusBarHeight+FILE_INFO_BANNER_HEIGHT);

		CGColorSpaceRelease(cs);
	}
}

- (void)createLinearGridOverlay
{
	UIImage *img_ui = nil;
	size_t recWidth, recHeight;
	CGFloat fillClr[4], lineClr[4];

	// make sure the scale overlay is removed before releasing it!!
	if(linearGridOverlay)
	{
		[linearGridOverlay removeFromSuperview];
	}

	self.linearGridOverlay = nil;

	{
		fillClr[0]=1.; fillClr[1]=1.; fillClr[2]=1.; fillClr[3]=0.0; // transparent
		lineClr[0]=1.; lineClr[1]=1.; lineClr[2]=1.; lineClr[3]=1.0; // scale line color

		CGPathRef bgPath = nil, narrowPath = nil;
		CGContextRef cxt = nil;
		CGImageRef img_cg = nil;

		CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

		recWidth = gridWidth;
		recHeight = gridHeight;

		//SDR_DEBUGPRINT(("Meters/pixel = %3.2f  recWidth=%ld\n", metersPerPixel, recWidth));

		// Draw the rect for the bg path using this convenience function
		bgPath = createSharpRectPath(CGRectMake(0, 0, recWidth, recHeight));

		// Create the bitmap context into which we will draw
		cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

		if(cxt == NULL)
		{
			SDR_DEBUGPRINT(("Error: Could not create bit map context - 1\n"));
			if(bgPath) CGPathRelease(bgPath);
			if(narrowPath) CGPathRelease(narrowPath);
		}
		else
		{
			CGContextSetFillColorSpace(cxt, cs);

			//		CGContextSetTextPosition(cxt, recWidth/2, recHeight/2);
			CGContextSetRGBFillColor(cxt, 1.0, 1.0, 1.0, 1.0);
			CGContextSetRGBStrokeColor(cxt, 1.0, 1.0, 1.0, 1.0);

			//			NSString* text;
			//			size_t textLen;

			// Some initial setup for our text drawing needs.
			// First, we will be doing our drawing in Helvetica-36pt with the MacRoman encoding.
			// This is an 8-bit encoding that can reference standard ASCII characters
			// and many common characters used in the Americas and Western Europe.
			//			CGContextSelectFont(cxt, "Helvetica", 12.0, kCGEncodingMacRoman);
			// Next we set the text matrix to flip our text upside down. We do this because the context itself
			// is flipped upside down relative to the expected orientation for drawing text (much like the case for drawing Images & PDF).
			////CGContextSetTextMatrix(cxt, CGAffineTransformMakeScale(1.0, -1.0));
			// And now we actually draw some text. This screen will demonstrate the typical drawing modes used.
			//			CGContextSetTextDrawingMode(cxt, kCGTextFill);
			//CGContextShowTextAtPoint(cxt, recWidth/2-(8*textLen/2), recHeight/2, [text fileSystemRepresentation], textLen);
			//		CGContextSetFillColor(cxt, fillClr);
			// Add the rect to the context...
			//		CGContextAddPath(cxt, bgPath);
			// ... and fill it.
			//		CGContextFillPath(cxt);

			CGContextSetLineWidth(cxt, 3.0);
			CGColorRef color = CGColorCreate(cs, lineClr);
			CGContextSetStrokeColorWithColor(cxt, color); // line drawing color

			// draw base
			CGContextMoveToPoint(cxt, 0, 0);
			CGContextAddLineToPoint(cxt, recWidth, 0);
			CGContextStrokePath(cxt);

			//			text = [NSString stringWithFormat:@"1e%d", 0];
			//			textLen = [text length];
			//			CGContextShowTextAtPoint(cxt, 4, 4, [text fileSystemRepresentation], textLen);
			//			CGContextShowTextAtPoint(cxt, recWidth-4-7*textLen, 4, [text fileSystemRepresentation], textLen);

			// draw top
			CGContextMoveToPoint(cxt, 0, recHeight);
			CGContextAddLineToPoint(cxt, recWidth, recHeight);
			CGContextStrokePath(cxt);

			// draw left edge
			CGContextMoveToPoint(cxt, 0, 0);
			CGContextAddLineToPoint(cxt, 0, recHeight);
			CGContextStrokePath(cxt);

			CGContextSetLineWidth(cxt, 1.0);

			double integralPart1, integralPart5;
			float remainderPart1 = modf(sampleRateBandwidthHz/1000., &integralPart1);
			float remainderPart5 = modf(sampleRateBandwidthHz/5000., &integralPart5);

			SDR_DEBUGPRINT(("remainderPart = %0.2f\n", remainderPart1));
			float stepSize1 = 1000. * displayLandscapeWidth/sampleRateBandwidthHz;
			float stepSize5 = 5000. * displayLandscapeWidth/sampleRateBandwidthHz - 0.001; // ensure x1 will catch up to x5

			float x1=stepSize1*remainderPart1/2.;
			float x5=stepSize5*remainderPart5/2.;

			while(x1 < recWidth)
			{
				SDR_DEBUGPRINT(("x1 = %0.2f\n", x1));
				CGContextMoveToPoint(cxt, x1, 0);
				if(x1 >= x5)
				{
					CGContextAddLineToPoint(cxt, x1, recHeight);
					x5 = x1 + stepSize5;
				}
				else
				{
					CGContextAddLineToPoint(cxt, x1, 5);
				}
				CGContextStrokePath(cxt);
				x1 += stepSize1;
			}
			CGContextSetLineWidth(cxt, 3.0);

			// draw right edge
			CGContextMoveToPoint(cxt, recWidth, 0);
			CGContextAddLineToPoint(cxt, recWidth, recHeight);
			CGContextStrokePath(cxt);

			CGContextSetLineWidth(cxt, 1.0);
			float y=0;
			float decadesToDraw = 6;
			for(int decades=1; y<recHeight && decades<=decadesToDraw; decades++)
			{
				for(int i=2; y<recHeight && i<=10; i++)
				{
					float yy = y + (recHeight/decadesToDraw);
					SDR_DEBUGPRINT(("y = %0.2f\n", yy));
					if(y<recHeight)
					{
						CGContextMoveToPoint(cxt, 0, yy);
						CGContextAddLineToPoint(cxt, recWidth, yy);
						CGContextStrokePath(cxt);
					}
				}

				y = decades * recHeight / decadesToDraw;

				if(y<recHeight)
				{
					CGContextMoveToPoint(cxt, 0, y);
					CGContextAddLineToPoint(cxt, recWidth, y);
					CGContextStrokePath(cxt);

					//					text = [NSString stringWithFormat:@"1e%d", decades];
					//					textLen = [text length];
					//					CGContextShowTextAtPoint(cxt, 4, y+4, [text fileSystemRepresentation], textLen);
					//					CGContextShowTextAtPoint(cxt, recWidth-4-7*textLen, y+4, [text fileSystemRepresentation], textLen);
				}
			}

			CGColorRelease(color);

			// Make a CGImage out of the context
			img_cg = CGBitmapContextCreateImage(cxt);
			// Make a UIImage out of the CGImage
			img_ui = [UIImage imageWithCGImage:img_cg];

			// Clean up
			CGImageRelease(img_cg);
			CGContextRelease(cxt);
			if(bgPath) CGPathRelease(bgPath);
			if(narrowPath) CGPathRelease(narrowPath);

			// Create the image view to hold the background rect which we just drew
			UIImageView* iv = [[UIImageView alloc] initWithImage:img_ui];
			self.linearGridOverlay = iv;

			linearGridOverlay.frame = CGRectMake(0, 0, recWidth, recHeight);
		}

		linearGridOverlay.center = CGPointMake(displayLandscapeWidth/2, recHeight/2+displayStatusBarHeight+FILE_INFO_BANNER_HEIGHT);

		CGColorSpaceRelease(cs);
	}
}


- (void)createSignalScopeGridOverlay:(BOOL)useSmallText
{
	UIImage *img_ui = nil;
	size_t recWidth, recHeight;
	CGFloat fillClr[4], lineClr[4];

	// make sure the scale overlay is removed before releasing it!!
	if(signalScopeGridOverlay)
	{
		[signalScopeGridOverlay removeFromSuperview];
	}

	self.signalScopeGridOverlay = nil;

	//	if(metersPerPixel > 0. && metersPerPixel <= 100)
	{

		fillClr[0]=1.; fillClr[1]=1.; fillClr[2]=1.; fillClr[3]=0.0; // transparent
		lineClr[0]=1.; lineClr[1]=1.; lineClr[2]=1.; lineClr[3]=1.0; // scale line color

		CGPathRef bgPath = nil, narrowPath = nil;
		CGContextRef cxt = nil;
		CGImageRef img_cg = nil;

		CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

		recWidth = gridWidth;
		recHeight = gridHeight;

		//SDR_DEBUGPRINT(("Meters/pixel = %3.2f  recWidth=%ld\n", metersPerPixel, recWidth));

		// Draw the rect for the bg path using this convenience function
		bgPath = createSharpRectPath(CGRectMake(0, 0, recWidth, recHeight));

		// Create the bitmap context into which we will draw
		cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

		if(cxt == NULL)
		{
			SDR_DEBUGPRINT(("Error: Could not create bit map context - 1\n"));
			if(bgPath) CGPathRelease(bgPath);
			if(narrowPath) CGPathRelease(narrowPath);
		}
		else
		{
			CGContextSetFillColorSpace(cxt, cs);

			//		CGContextSetTextPosition(cxt, recWidth/2, recHeight/2);
			CGContextSetRGBFillColor(cxt, 1.0, 1.0, 1.0, 1.0);
			CGContextSetRGBStrokeColor(cxt, 1.0, 1.0, 1.0, 1.0);

			//			NSString* text;
			//			size_t textLen;

			// Some initial setup for our text drawing needs.
			// First, we will be doing our drawing in Helvetica-36pt with the MacRoman encoding.
			// This is an 8-bit encoding that can reference standard ASCII characters
			// and many common characters used in the Americas and Western Europe.
			//			CGContextSelectFont(cxt, "Helvetica", 12.0, kCGEncodingMacRoman);
			// Next we set the text matrix to flip our text upside down. We do this because the context itself
			// is flipped upside down relative to the expected orientation for drawing text (much like the case for drawing Images & PDF).
			////CGContextSetTextMatrix(cxt, CGAffineTransformMakeScale(1.0, -1.0));
			// And now we actually draw some text. This screen will demonstrate the typical drawing modes used.
			//			CGContextSetTextDrawingMode(cxt, kCGTextFill);
			//CGContextShowTextAtPoint(cxt, recWidth/2-(8*textLen/2), recHeight/2, [text fileSystemRepresentation], textLen);
			//		CGContextSetFillColor(cxt, fillClr);
			// Add the rect to the context...
			//		CGContextAddPath(cxt, bgPath);
			// ... and fill it.
			//		CGContextFillPath(cxt);

			CGContextSetLineWidth(cxt, 3.0);
			CGColorRef color = CGColorCreate(cs, lineClr);
			CGContextSetStrokeColorWithColor(cxt, color); // line drawing color

			// draw base
			CGContextMoveToPoint(cxt, 0, 0);
			CGContextAddLineToPoint(cxt, recWidth, 0);
			CGContextStrokePath(cxt);

			//			text = [NSString stringWithFormat:@"1e%d", 0];
			//			textLen = [text length];
			//			CGContextShowTextAtPoint(cxt, 4, 4, [text fileSystemRepresentation], textLen);
			//			CGContextShowTextAtPoint(cxt, recWidth-4-7*textLen, 4, [text fileSystemRepresentation], textLen);

			// draw top
			CGContextMoveToPoint(cxt, 0, recHeight);
			CGContextAddLineToPoint(cxt, recWidth, recHeight);
			CGContextStrokePath(cxt);

			// draw left edge
			CGContextMoveToPoint(cxt, 0, 0);
			CGContextAddLineToPoint(cxt, 0, recHeight);
			CGContextStrokePath(cxt);

			CGContextSetLineWidth(cxt, 1.0);

			double integralPart1, integralPart5;
			float remainderPart1 = modf(sampleRateBandwidthHz/1000., &integralPart1);
			float remainderPart5 = modf(sampleRateBandwidthHz/5000., &integralPart5);

			SDR_DEBUGPRINT(("remainderPart = %0.2f\n", remainderPart1));
			float stepSize1 = 1000. * displayLandscapeWidth/sampleRateBandwidthHz;
			float stepSize5 = 5000. * displayLandscapeWidth/sampleRateBandwidthHz - 0.001; // ensure x1 will catch up to x5

			float x1=stepSize1*remainderPart1/2.;
			float x5=stepSize5*remainderPart5/2.;

			while(x1 < recWidth)
			{
				SDR_DEBUGPRINT(("x1 = %0.2f\n", x1));
				//CGContextMoveToPoint(cxt, x1, recHeight/2-3);
				if(x1 >= x5)
				{
					CGContextMoveToPoint(cxt, x1, 0);
					CGContextAddLineToPoint(cxt, x1, recHeight);
					x5 = x1 + stepSize5;
				}
				else
				{
					CGContextMoveToPoint(cxt, x1, recHeight/2-3);
					CGContextAddLineToPoint(cxt, x1, recHeight/2+3);
				}
				CGContextStrokePath(cxt);
				x1 += stepSize1;
			}
			CGContextSetLineWidth(cxt, 3.0);

			// draw right edge
			CGContextMoveToPoint(cxt, recWidth, 0);
			CGContextAddLineToPoint(cxt, recWidth, recHeight);
			CGContextStrokePath(cxt);

			CGContextSetLineWidth(cxt, 1.0);

			//double integralPart1, integralPart5;
			//remainderPart1 = modf(recHeight/50., &integralPart1);
			//remainderPart5 = modf(recHeight/10., &integralPart5);

			//SDR_DEBUGPRINT(("remainderPart = %0.2f\n", remainderPart1));
			stepSize1 = recHeight/50.;
			//stepSize5 = 5. * stepSize1;

			float y1; //=stepSize1; //*remainderPart1/2.;
			//float y5=stepSize5; //*remainderPart5/2.;

			for(int i=0; i<50; i++)
			{
				y1 = i*stepSize1;
				SDR_DEBUGPRINT(("y1 = %0.2f\n", y1));
				if(i % 5)
				{
					if(!useSmallText)
					{
						CGContextMoveToPoint(cxt, recWidth/2-5, y1);
						CGContextAddLineToPoint(cxt, recWidth/2+5, y1);
						CGContextStrokePath(cxt);
					}
				}
				else
				{
					CGContextMoveToPoint(cxt, 0, y1);
					CGContextAddLineToPoint(cxt, recWidth, y1);
					CGContextStrokePath(cxt);
				}
			}

			CGColorRelease(color);

			// Make a CGImage out of the context
			img_cg = CGBitmapContextCreateImage(cxt);
			// Make a UIImage out of the CGImage
			img_ui = [UIImage imageWithCGImage:img_cg];

			// Clean up
			CGImageRelease(img_cg);
			CGContextRelease(cxt);
			if(bgPath) CGPathRelease(bgPath);
			if(narrowPath) CGPathRelease(narrowPath);

			// Create the image view to hold the background rect which we just drew
			UIImageView* iv = [[UIImageView alloc] initWithImage:img_ui];
			self.signalScopeGridOverlay = iv;

			signalScopeGridOverlay.frame = CGRectMake(0, 0, recWidth, recHeight);
		}

		signalScopeGridOverlay.center = CGPointMake(displayLandscapeWidth/2, recHeight/2+displayStatusBarHeight+FILE_INFO_BANNER_HEIGHT);

		CGColorSpaceRelease(cs);
	}
}



#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
- (void)createSemiLogGridOverlay_old:(BOOL)useSmallText
{
	UIImage *img_ui = nil;
	size_t recWidth, recHeight;
	CGFloat fillClr[4], lineClr[4];

	// make sure the scale overlay is removed before releasing it!!
	if(semiLogGridOverlay)
	{
		[semiLogGridOverlay removeFromSuperview];
		semiLogGridOverlay = nil;
	}

	{

		fillClr[0]=1.; fillClr[1]=1.; fillClr[2]=1.; fillClr[3]=0.0; // transparent
		lineClr[0]=1.; lineClr[1]=1.; lineClr[2]=1.; lineClr[3]=1.0; // scale line color

		CGPathRef bgPath = nil, narrowPath = nil;
		CGContextRef cxt = nil;
		CGImageRef img_cg = nil;

		CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

		recWidth = gridWidth;
		recHeight = gridHeight;

		//SDR_DEBUGPRINT(("Meters/pixel = %3.2f  recWidth=%ld\n", metersPerPixel, recWidth));

		// Draw the rect for the bg path using this convenience function
		bgPath = createSharpRectPath(CGRectMake(0, 0, recWidth, recHeight));

		// Create the bitmap context into which we will draw
		cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

		if(cxt == NULL)
		{
			SDR_DEBUGPRINT(("Error: Could not create bit map context - 1\n"));
			if(bgPath) CGPathRelease(bgPath);
			if(narrowPath) CGPathRelease(narrowPath);
		}
		else
		{
			CGContextSetFillColorSpace(cxt, cs);

			//		CGContextSetTextPosition(cxt, recWidth/2, recHeight/2);
			CGContextSetRGBFillColor(cxt, 0.65, 0.88, 1.0, 1.0);
			CGContextSetRGBStrokeColor(cxt, 0.65, 0.88, 1.0, 1.0);

			NSString* text;
			size_t textLen;

			// Some initial setup for our text drawing needs.
			// First, we will be doing our drawing in Helvetica-36pt with the MacRoman encoding.
			// This is an 8-bit encoding that can reference standard ASCII characters
			// and many common characters used in the Americas and Western Europe.
			CGContextSelectFont(cxt, "Helvetica", 12.0, kCGEncodingMacRoman);
			// Next we set the text matrix to flip our text upside down. We do this because the context itself
			// is flipped upside down relative to the expected orientation for drawing text (much like the case for drawing Images & PDF).
			////CGContextSetTextMatrix(cxt, CGAffineTransformMakeScale(1.0, -1.0));
			// And now we actually draw some text. This screen will demonstrate the typical drawing modes used.
			CGContextSetTextDrawingMode(cxt, kCGTextFill);
			//CGContextShowTextAtPoint(cxt, recWidth/2-(8*textLen/2), recHeight/2, [text fileSystemRepresentation], textLen);
			//		CGContextSetFillColor(cxt, fillClr);
			// Add the rect to the context...
			//		CGContextAddPath(cxt, bgPath);
			// ... and fill it.
			//		CGContextFillPath(cxt);

			CGContextSetLineWidth(cxt, 3.0);
			CGColorRef color = CGColorCreate(cs, lineClr);
			CGContextSetStrokeColorWithColor(cxt, color); // line drawing color

			// draw base
			CGContextMoveToPoint(cxt, 0, 0);
			CGContextAddLineToPoint(cxt, recWidth, 0);
			CGContextStrokePath(cxt);

			if(useSmallText)
			{
				text = [NSString stringWithFormat:@"E%d", 0];
			}
			else
			{
				text = [NSString stringWithFormat:@"1e%d", 0];
			}

			textLen = [text length];
			CGContextShowTextAtPoint(cxt, 4, 4, [text fileSystemRepresentation], textLen);
			CGContextShowTextAtPoint(cxt, recWidth-4-7*textLen, 4, [text fileSystemRepresentation], textLen);

			// draw top
			CGContextMoveToPoint(cxt, 0, recHeight);
			CGContextAddLineToPoint(cxt, recWidth, recHeight);
			CGContextStrokePath(cxt);

			// draw left edge
			CGContextMoveToPoint(cxt, 0, 0);
			CGContextAddLineToPoint(cxt, 0, recHeight);
			CGContextStrokePath(cxt);

			CGContextSetLineWidth(cxt, 1.0);

			double integralPart1, integralPart5;
			float remainderPart1 = modf(sampleRateBandwidthHz/1000., &integralPart1);
			float remainderPart5 = modf(sampleRateBandwidthHz/5000., &integralPart5);

			SDR_DEBUGPRINT(("remainderPart = %0.2f\n", remainderPart1));
			float stepSize1 = 1000. * displayLandscapeWidth/sampleRateBandwidthHz;
			float stepSize5 = 5000. * displayLandscapeWidth/sampleRateBandwidthHz - 0.001; // ensure x1 will catch up to x5

			float x1=stepSize1*remainderPart1/2.;
			float x5=stepSize5*remainderPart5/2.;

			while(x1 < recWidth)
			{
				SDR_DEBUGPRINT(("x1=%0.3f x5=%0.3f \n", x1, x5));
				CGContextMoveToPoint(cxt, x1, 0);
				if(x1 >= x5)
				{
					CGContextAddLineToPoint(cxt, x1, recHeight);
					x5 = x1 + stepSize5;
				}
				else
				{
					CGContextAddLineToPoint(cxt, x1, 5);
				}
				CGContextStrokePath(cxt);
				x1 += stepSize1;
			}
			CGContextSetLineWidth(cxt, 3.0);

			// draw right edge
			CGContextMoveToPoint(cxt, recWidth, 0);
			CGContextAddLineToPoint(cxt, recWidth, recHeight);
			CGContextStrokePath(cxt);

			CGContextSetLineWidth(cxt, 1.0);
			float y=0;
			float decadesToDraw = 6;
			for(int decades=1; y<recHeight && decades<=decadesToDraw; decades++)
			{
				for(int i=2; y<recHeight && i<=10; i++)
				{
					float yy = y + log10((double)i) * (recHeight/decadesToDraw);
					SDR_DEBUGPRINT(("y = %0.2f\n", yy));
					if(y<recHeight)
					{
						CGContextMoveToPoint(cxt, 0, yy);
						CGContextAddLineToPoint(cxt, recWidth, yy);
						CGContextStrokePath(cxt);
					}
				}

				y = decades * recHeight / decadesToDraw;

				if(y<recHeight)
				{
					CGContextMoveToPoint(cxt, 0, y);
					CGContextAddLineToPoint(cxt, recWidth, y);
					CGContextStrokePath(cxt);

					if(useSmallText)
					{
						text = [NSString stringWithFormat:@"E%d", decades];
					}
					else
					{
						text = [NSString stringWithFormat:@"1e%d", decades];
					}

					textLen = [text length];
					CGContextShowTextAtPoint(cxt, 4, y+4, [text fileSystemRepresentation], textLen);
					CGContextShowTextAtPoint(cxt, recWidth-4-7*textLen, y+4, [text fileSystemRepresentation], textLen);
				}
			}

			CGColorRelease(color);

			// Make a CGImage out of the context
			img_cg = CGBitmapContextCreateImage(cxt);
			// Make a UIImage out of the CGImage
			img_ui = [UIImage imageWithCGImage:img_cg];

			// Clean up
			CGImageRelease(img_cg);
			CGContextRelease(cxt);
			if(bgPath) CGPathRelease(bgPath);
			if(narrowPath) CGPathRelease(narrowPath);

			// Create the image view to hold the background rect which we just drew
			semiLogGridOverlay = [[UIImageView alloc] initWithImage:img_ui];
			semiLogGridOverlay.frame = CGRectMake(0, 0, recWidth, recHeight);
		}

		semiLogGridOverlay.center = CGPointMake(displayLandscapeWidth/2, recHeight/2+displayStatusBarHeight+FILE_INFO_BANNER_HEIGHT);

		CGColorSpaceRelease(cs);
	}
}

- (void)createLinearGridOverlay_old
{
	UIImage *img_ui = nil;
	size_t recWidth, recHeight;
	CGFloat fillClr[4], lineClr[4];

	// make sure the scale overlay is removed before releasing it!!
	if(linearGridOverlay)
	{
		[linearGridOverlay removeFromSuperview];
		linearGridOverlay = nil;
	}

	{

		fillClr[0]=1.; fillClr[1]=1.; fillClr[2]=1.; fillClr[3]=0.0; // transparent
		lineClr[0]=1.; lineClr[1]=1.; lineClr[2]=1.; lineClr[3]=1.0; // scale line color

		CGPathRef bgPath = nil, narrowPath = nil;
		CGContextRef cxt = nil;
		CGImageRef img_cg = nil;

		CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

		recWidth = gridWidth;
		recHeight = gridHeight;

		//SDR_DEBUGPRINT(("Meters/pixel = %3.2f  recWidth=%ld\n", metersPerPixel, recWidth));

		// Draw the rect for the bg path using this convenience function
		bgPath = createSharpRectPath(CGRectMake(0, 0, recWidth, recHeight));

		// Create the bitmap context into which we will draw
		cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

		if(cxt == NULL)
		{
			SDR_DEBUGPRINT(("Error: Could not create bit map context - 1\n"));
			if(bgPath) CGPathRelease(bgPath);
			if(narrowPath) CGPathRelease(narrowPath);
		}
		else
		{
			CGContextSetFillColorSpace(cxt, cs);

			//		CGContextSetTextPosition(cxt, recWidth/2, recHeight/2);
			CGContextSetRGBFillColor(cxt, 1.0, 1.0, 1.0, 1.0);
			CGContextSetRGBStrokeColor(cxt, 1.0, 1.0, 1.0, 1.0);

			//			NSString* text;
			//			size_t textLen;

			// Some initial setup for our text drawing needs.
			// First, we will be doing our drawing in Helvetica-36pt with the MacRoman encoding.
			// This is an 8-bit encoding that can reference standard ASCII characters
			// and many common characters used in the Americas and Western Europe.
			//			CGContextSelectFont(cxt, "Helvetica", 12.0, kCGEncodingMacRoman);
			// Next we set the text matrix to flip our text upside down. We do this because the context itself
			// is flipped upside down relative to the expected orientation for drawing text (much like the case for drawing Images & PDF).
			////CGContextSetTextMatrix(cxt, CGAffineTransformMakeScale(1.0, -1.0));
			// And now we actually draw some text. This screen will demonstrate the typical drawing modes used.
			//			CGContextSetTextDrawingMode(cxt, kCGTextFill);
			//CGContextShowTextAtPoint(cxt, recWidth/2-(8*textLen/2), recHeight/2, [text fileSystemRepresentation], textLen);
			//		CGContextSetFillColor(cxt, fillClr);
			// Add the rect to the context...
			//		CGContextAddPath(cxt, bgPath);
			// ... and fill it.
			//		CGContextFillPath(cxt);

			CGContextSetLineWidth(cxt, 3.0);
			CGColorRef color = CGColorCreate(cs, lineClr);
			CGContextSetStrokeColorWithColor(cxt, color); // line drawing color

			// draw base
			CGContextMoveToPoint(cxt, 0, 0);
			CGContextAddLineToPoint(cxt, recWidth, 0);
			CGContextStrokePath(cxt);

			//			text = [NSString stringWithFormat:@"1e%d", 0];
			//			textLen = [text length];
			//			CGContextShowTextAtPoint(cxt, 4, 4, [text fileSystemRepresentation], textLen);
			//			CGContextShowTextAtPoint(cxt, recWidth-4-7*textLen, 4, [text fileSystemRepresentation], textLen);

			// draw top
			CGContextMoveToPoint(cxt, 0, recHeight);
			CGContextAddLineToPoint(cxt, recWidth, recHeight);
			CGContextStrokePath(cxt);

			// draw left edge
			CGContextMoveToPoint(cxt, 0, 0);
			CGContextAddLineToPoint(cxt, 0, recHeight);
			CGContextStrokePath(cxt);

			CGContextSetLineWidth(cxt, 1.0);

			double integralPart1, integralPart5;
			float remainderPart1 = modf(sampleRateBandwidthHz/1000., &integralPart1);
			float remainderPart5 = modf(sampleRateBandwidthHz/5000., &integralPart5);

			SDR_DEBUGPRINT(("remainderPart = %0.2f\n", remainderPart1));
			float stepSize1 = 1000. * displayLandscapeWidth/sampleRateBandwidthHz;
			float stepSize5 = 5000. * displayLandscapeWidth/sampleRateBandwidthHz - 0.001; // ensure x1 will catch up to x5

			float x1=stepSize1*remainderPart1/2.;
			float x5=stepSize5*remainderPart5/2.;

			while(x1 < recWidth)
			{
				SDR_DEBUGPRINT(("x1 = %0.2f\n", x1));
				CGContextMoveToPoint(cxt, x1, 0);
				if(x1 >= x5)
				{
					CGContextAddLineToPoint(cxt, x1, recHeight);
					x5 = x1 + stepSize5;
				}
				else
				{
					CGContextAddLineToPoint(cxt, x1, 5);
				}
				CGContextStrokePath(cxt);
				x1 += stepSize1;
			}
			CGContextSetLineWidth(cxt, 3.0);

			// draw right edge
			CGContextMoveToPoint(cxt, recWidth, 0);
			CGContextAddLineToPoint(cxt, recWidth, recHeight);
			CGContextStrokePath(cxt);

			CGContextSetLineWidth(cxt, 1.0);
			float y=0;
			float decadesToDraw = 6;
			for(int decades=1; y<recHeight && decades<=decadesToDraw; decades++)
			{
				for(int i=2; y<recHeight && i<=10; i++)
				{
					float yy = y + (recHeight/decadesToDraw);
					SDR_DEBUGPRINT(("y = %0.2f\n", yy));
					if(y<recHeight)
					{
						CGContextMoveToPoint(cxt, 0, yy);
						CGContextAddLineToPoint(cxt, recWidth, yy);
						CGContextStrokePath(cxt);
					}
				}

				y = decades * recHeight / decadesToDraw;

				if(y<recHeight)
				{
					CGContextMoveToPoint(cxt, 0, y);
					CGContextAddLineToPoint(cxt, recWidth, y);
					CGContextStrokePath(cxt);

					//					text = [NSString stringWithFormat:@"1e%d", decades];
					//					textLen = [text length];
					//					CGContextShowTextAtPoint(cxt, 4, y+4, [text fileSystemRepresentation], textLen);
					//					CGContextShowTextAtPoint(cxt, recWidth-4-7*textLen, y+4, [text fileSystemRepresentation], textLen);
				}
			}

			CGColorRelease(color);

			// Make a CGImage out of the context
			img_cg = CGBitmapContextCreateImage(cxt);
			// Make a UIImage out of the CGImage
			img_ui = [UIImage imageWithCGImage:img_cg];

			// Clean up
			CGImageRelease(img_cg);
			CGContextRelease(cxt);
			if(bgPath) CGPathRelease(bgPath);
			if(narrowPath) CGPathRelease(narrowPath);

			// Create the image view to hold the background rect which we just drew
			linearGridOverlay = [[UIImageView alloc] initWithImage:img_ui];
			linearGridOverlay.frame = CGRectMake(0, 0, recWidth, recHeight);
		}

		linearGridOverlay.center = CGPointMake(displayLandscapeWidth/2, recHeight/2+displayStatusBarHeight+FILE_INFO_BANNER_HEIGHT);

		CGColorSpaceRelease(cs);
	}
}


- (void)createSignalScopeGridOverlay_old:(BOOL)useSmallText
{
	UIImage *img_ui = nil;
	size_t recWidth, recHeight;
	CGFloat fillClr[4], lineClr[4];

	// make sure the scale overlay is removed before releasing it!!
	if(signalScopeGridOverlay)
	{
		[signalScopeGridOverlay removeFromSuperview];
		signalScopeGridOverlay = nil;
	}

	//	if(metersPerPixel > 0. && metersPerPixel <= 100)
	{

		fillClr[0]=1.; fillClr[1]=1.; fillClr[2]=1.; fillClr[3]=0.0; // transparent
		lineClr[0]=1.; lineClr[1]=1.; lineClr[2]=1.; lineClr[3]=1.0; // scale line color

		CGPathRef bgPath = nil, narrowPath = nil;
		CGContextRef cxt = nil;
		CGImageRef img_cg = nil;

		CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

		recWidth = gridWidth;
		recHeight = gridHeight;

		//SDR_DEBUGPRINT(("Meters/pixel = %3.2f  recWidth=%ld\n", metersPerPixel, recWidth));

		// Draw the rect for the bg path using this convenience function
		bgPath = createSharpRectPath(CGRectMake(0, 0, recWidth, recHeight));

		// Create the bitmap context into which we will draw
		cxt = CGBitmapContextCreate(NULL, recWidth, recHeight, 8, 8*recWidth, cs, kCGImageAlphaPremultipliedFirst);

		if(cxt == NULL)
		{
			SDR_DEBUGPRINT(("Error: Could not create bit map context - 1\n"));
			if(bgPath) CGPathRelease(bgPath);
			if(narrowPath) CGPathRelease(narrowPath);
		}
		else
		{
			CGContextSetFillColorSpace(cxt, cs);

			//		CGContextSetTextPosition(cxt, recWidth/2, recHeight/2);
			CGContextSetRGBFillColor(cxt, 1.0, 1.0, 1.0, 1.0);
			CGContextSetRGBStrokeColor(cxt, 1.0, 1.0, 1.0, 1.0);

			//			NSString* text;
			//			size_t textLen;

			// Some initial setup for our text drawing needs.
			// First, we will be doing our drawing in Helvetica-36pt with the MacRoman encoding.
			// This is an 8-bit encoding that can reference standard ASCII characters
			// and many common characters used in the Americas and Western Europe.
			//			CGContextSelectFont(cxt, "Helvetica", 12.0, kCGEncodingMacRoman);
			// Next we set the text matrix to flip our text upside down. We do this because the context itself
			// is flipped upside down relative to the expected orientation for drawing text (much like the case for drawing Images & PDF).
			////CGContextSetTextMatrix(cxt, CGAffineTransformMakeScale(1.0, -1.0));
			// And now we actually draw some text. This screen will demonstrate the typical drawing modes used.
			//			CGContextSetTextDrawingMode(cxt, kCGTextFill);
			//CGContextShowTextAtPoint(cxt, recWidth/2-(8*textLen/2), recHeight/2, [text fileSystemRepresentation], textLen);
			//		CGContextSetFillColor(cxt, fillClr);
			// Add the rect to the context...
			//		CGContextAddPath(cxt, bgPath);
			// ... and fill it.
			//		CGContextFillPath(cxt);

			CGContextSetLineWidth(cxt, 3.0);
			CGColorRef color = CGColorCreate(cs, lineClr);
			CGContextSetStrokeColorWithColor(cxt, color); // line drawing color

			// draw base
			CGContextMoveToPoint(cxt, 0, 0);
			CGContextAddLineToPoint(cxt, recWidth, 0);
			CGContextStrokePath(cxt);

			//			text = [NSString stringWithFormat:@"1e%d", 0];
			//			textLen = [text length];
			//			CGContextShowTextAtPoint(cxt, 4, 4, [text fileSystemRepresentation], textLen);
			//			CGContextShowTextAtPoint(cxt, recWidth-4-7*textLen, 4, [text fileSystemRepresentation], textLen);

			// draw top
			CGContextMoveToPoint(cxt, 0, recHeight);
			CGContextAddLineToPoint(cxt, recWidth, recHeight);
			CGContextStrokePath(cxt);

			// draw left edge
			CGContextMoveToPoint(cxt, 0, 0);
			CGContextAddLineToPoint(cxt, 0, recHeight);
			CGContextStrokePath(cxt);

			CGContextSetLineWidth(cxt, 1.0);

			double integralPart1, integralPart5;
			float remainderPart1 = modf(sampleRateBandwidthHz/1000., &integralPart1);
			float remainderPart5 = modf(sampleRateBandwidthHz/5000., &integralPart5);

			SDR_DEBUGPRINT(("remainderPart = %0.2f\n", remainderPart1));
			float stepSize1 = 1000. * displayLandscapeWidth/sampleRateBandwidthHz;
			float stepSize5 = 5000. * displayLandscapeWidth/sampleRateBandwidthHz - 0.001; // ensure x1 will catch up to x5

			float x1=stepSize1*remainderPart1/2.;
			float x5=stepSize5*remainderPart5/2.;

			while(x1 < recWidth)
			{
				SDR_DEBUGPRINT(("x1 = %0.2f\n", x1));
				//CGContextMoveToPoint(cxt, x1, recHeight/2-3);
				if(x1 >= x5)
				{
					CGContextMoveToPoint(cxt, x1, 0);
					CGContextAddLineToPoint(cxt, x1, recHeight);
					x5 = x1 + stepSize5;
				}
				else
				{
					CGContextMoveToPoint(cxt, x1, recHeight/2-3);
					CGContextAddLineToPoint(cxt, x1, recHeight/2+3);
				}
				CGContextStrokePath(cxt);
				x1 += stepSize1;
			}
			CGContextSetLineWidth(cxt, 3.0);

			// draw right edge
			CGContextMoveToPoint(cxt, recWidth, 0);
			CGContextAddLineToPoint(cxt, recWidth, recHeight);
			CGContextStrokePath(cxt);

			CGContextSetLineWidth(cxt, 1.0);

			//double integralPart1, integralPart5;
			//remainderPart1 = modf(recHeight/50., &integralPart1);
			//remainderPart5 = modf(recHeight/10., &integralPart5);

			//SDR_DEBUGPRINT(("remainderPart = %0.2f\n", remainderPart1));
			stepSize1 = recHeight/50.;
			//stepSize5 = 5. * stepSize1;

			float y1; //=stepSize1; //*remainderPart1/2.;
			//float y5=stepSize5; //*remainderPart5/2.;

			for(int i=0; i<50; i++)
			{
				y1 = i*stepSize1;
				SDR_DEBUGPRINT(("y1 = %0.2f\n", y1));
				if(i % 5)
				{
					if(!useSmallText)
					{
						CGContextMoveToPoint(cxt, recWidth/2-5, y1);
						CGContextAddLineToPoint(cxt, recWidth/2+5, y1);
						CGContextStrokePath(cxt);
					}
				}
				else
				{
					CGContextMoveToPoint(cxt, 0, y1);
					CGContextAddLineToPoint(cxt, recWidth, y1);
					CGContextStrokePath(cxt);
				}
			}

			CGColorRelease(color);

			// Make a CGImage out of the context
			img_cg = CGBitmapContextCreateImage(cxt);
			// Make a UIImage out of the CGImage
			img_ui = [UIImage imageWithCGImage:img_cg];

			// Clean up
			CGImageRelease(img_cg);
			CGContextRelease(cxt);
			if(bgPath) CGPathRelease(bgPath);
			if(narrowPath) CGPathRelease(narrowPath);

			// Create the image view to hold the background rect which we just drew
			signalScopeGridOverlay = [[UIImageView alloc] initWithImage:img_ui];
			signalScopeGridOverlay.frame = CGRectMake(0, 0, recWidth, recHeight);
		}

		signalScopeGridOverlay.center = CGPointMake(displayLandscapeWidth/2, recHeight/2+displayStatusBarHeight+FILE_INFO_BANNER_HEIGHT);

		CGColorSpaceRelease(cs);
	}
}
#endif

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
	return UIInterfaceOrientationLandscapeRight;
	/*
	 switch (defaultsWorkingCopy.displayOrientation)
	 {
	 case LandscapeButtonLeft: 	// The view controller supports a landscape-left interface orientation.
	 return UIInterfaceOrientationLandscapeLeft;
	 break;

	 case Landscape: // The view controller supports a landscape-right interface orientation.
	 return UIInterfaceOrientationLandscapeRight;
	 break;

	 case PortraitButtonTop:
	 return UIInterfaceOrientationPortraitUpsideDown;
	 break;

	 default:
	 return UIInterfaceOrientationPortrait;
	 break;
	 }
	 */
}

+ (NSString*)frequencyString:(frequencyType)frequency
{
	NSString* freqString = nil;

	SDR_DEBUGPRINT(("Frequency for string: %0.3lf\n", frequency));

	if(frequency > 14000)
	{
		frequency /= 1000;
		freqString = [NSString stringWithFormat:@"%3.6lf MHz\n", frequency];
	}
	else
	{
		freqString = [NSString stringWithFormat:@"%4.3lf kHz\n", frequency];
	}

	return freqString;
}


///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
//
- (NSString*)ipAddressString
{
	NSString* returnString = wifi.connectedSSID;

	if(returnString == nil)
	{
		returnString = wifi.connectedIPAddress;

		if(returnString == nil)
		{
			returnString = appDelegate.ipAddress;

			if(returnString == nil)
			{
				returnString = NSLocalizedString(@"IP Invalid", nil);
			}
		}
	}

	return returnString;
}

- (NSString*)centerFrequencyString:(frequencyType)frequency
{
	NSString* freqString = nil;

	SDR_DEBUGPRINT(("Frequency for string: %0.3f\n", frequency));

	if(windowBehavior == FrequencyWindowLockMode)
	{
		freqString = NSLocalizedString(@"Centered", nil);
	}
	else
	{
		freqString = [EAGLViewController frequencyString:frequency];
	}

	SDR_DEBUGPRINT(("Returning string: %s\n", [freqString UTF8String]));

	return freqString;
}
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TextFieldDelegate methods
#pragma textFieldDelegate
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
	return YES;
}

// It is important for you to hide keyboard
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}
// TextFieldDelegate methods
///////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)performBlockOnMainThread:(ABasicBlock)block
{
	[self performSelectorOnMainThread:@selector(callBlock:) withObject:[block copy] waitUntilDone:[NSThread isMainThread]];
}


- (void)callBlock:(ABasicBlock)block
{
	block();
}


- (void)alertDidDismissWithButtonIndexAndTag:(UIAlertController*)alert Button:(NSInteger)buttonIndex Tag:(NSInteger)tag
{
	SDR_DEBUGPRINT(("PVC: alertView did dismiss!\n"));

    NSString* textFieldText = nil;
    UITextField* tf = nil;

    if(alert)
    {
        if(alert.textFields && alert.textFields.count) tf = alert.textFields[0];
        if(tf) textFieldText = tf.text;
    }

	switch(tag)
	{
		case EnterTCPCommandPortPrompt:
		{
			wifiEnterNewIPAddress = nil;

			if(buttonIndex == 0) // if the field was dismissed by user action
			{
				appDelegate.commandPort = textFieldText;
				BOOL success = [appDelegate.commandPort isEqualToString:textFieldText];

				if(!success)
				{
					appDelegate.commandPort = wifi.commandPort; // be sure the old value is restored

					wifiEnterNewIPAddress = [self makeAlert:NO tag:EnterTCPCommandPortPrompt title:NSLocalizedString(@"Enter Valid Port Setting", @"") message:@"(0-65535)" textFieldText:wifi.commandPort delegate:self cancelButtonTitle:NSLocalizedString(@"Apply", @"") otherButtonTitles:nil];

					if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playErrorSound];
				}
				else
				{
					wifi.commandPort = textFieldText;
					if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];

					IpCheckResult result = NoGoodCandidateFound;
					[activeIPAddress setString:[self validateCandidateIPSetting:activeIPAddress result:&result]];

					if(![activeIPAddress isEqualToString:appDelegate.ipAddress])
					{
						defaultsWorkingCopy.hasSuccessfullyConnectedViaWifi = FALSE;
						appDelegate.defaults = defaultsWorkingCopy;
						[appDelegate writeDefaultsToFileSystem];
					}

					appDelegate.ipAddress = activeIPAddress;
					ipAddressText.text = activeIPAddress;
					holdWifiState = Disconnected;
					[wifi establishWifiConnection:activeIPAddress];

					if(result == CandidateDiffersFromConnected)
					{
						[self performSelector:@selector(alertUserOfIPDiscrepancy) withObject:nil afterDelay:10.];
					}
				}
			}
		}
			break;

		case BetaPeriodExpired:
		case FatalError:
		{
			if(buttonIndex == 0)
			{
				exit(0);
			}
		}
			break;

		case OldIOSVersion:
		{
			if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
			[appDelegate markIntroductoryMessageDisplayed];
		}
			break;

			///////////////////////////////////////////////////////////////////////////////////////////
			// Wifi support changes
		case IPAddressError:
		{
			wifiEnterNewIPAddress = nil;

			if(buttonIndex == 0) // if the field was dismissed by user action
			{
				IpCheckResult result;
				[activeIPAddress setString:[self validateCandidateIPSetting:textFieldText result:&result]];

				switch(result)
				{
					case CandidateDiffersFromConnected:
					case CandidateIsConnected:
					case AddressIsOK:
					{
						if(![activeIPAddress isEqualToString:appDelegate.ipAddress])
						{
							defaultsWorkingCopy.hasSuccessfullyConnectedViaWifi = FALSE;
							appDelegate.defaults = defaultsWorkingCopy;
							[appDelegate writeDefaultsToFileSystem];
						}

						appDelegate.ipAddress = activeIPAddress;
						ipAddressText.text = activeIPAddress;
						holdWifiState = Disconnected;
						[wifi establishWifiConnection:activeIPAddress];

						if(result == CandidateDiffersFromConnected)
						{
							[self performSelector:@selector(alertUserOfIPDiscrepancy) withObject:nil afterDelay:10.];
						}

						if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
					}
						break;


					case BetterCandidateFound:
					case NoGoodCandidateFound:
					default:
					{
						if(wifiEnterNewIPAddress == nil)
						{
							wifiEnterNewIPAddress = [self makeAlert:NO tag:IPAddressError title:NSLocalizedString(@"Enter Valid IP Address", @"") message:nil textFieldText:activeIPAddress delegate:self cancelButtonTitle:NSLocalizedString(@"Done", @"") otherButtonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Set Port", @""), nil]];

							if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playErrorSound];
						}
					}
						break;
				}
			}
			else if(buttonIndex == 1) // set port
			{
				IpCheckResult result;
				[activeIPAddress setString:[self validateCandidateIPSetting:textFieldText result:&result]];

				switch(result)
				{
					case BetterCandidateFound:
					case NoGoodCandidateFound:
					{
						if(wifiEnterNewIPAddress == nil)
						{
							wifiEnterNewIPAddress = [self makeAlert:NO tag:IPAddressError title:NSLocalizedString(@"Enter Valid IP Address", @"") message:nil textFieldText:activeIPAddress delegate:self cancelButtonTitle:NSLocalizedString(@"Done", @"") otherButtonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Set Port", @""), nil]];

							if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playErrorSound];
						}
					}
						break;

					default:
					{
						wifiEnterNewIPAddress = [self makeAlert:NO tag:EnterTCPCommandPortPrompt title:NSLocalizedString(@"Enter Valid Port Setting", @"") message:@"(0-65535)" textFieldText:wifi.commandPort delegate:self cancelButtonTitle:NSLocalizedString(@"Apply", @"") otherButtonTitles:nil];

						if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
					}
						break;
				}
			}
		}
			break;

		case WifiConnectionFailedError:
		{
			wifiStateTranstionAlert = nil;

			if(buttonIndex == 0)
			{
				NSString* ipAddr = [self validateCandidateIPSetting:appDelegate.ipAddress result:nil];
				WIFI_DEBUGPRINT(("User chose to attempt to connect...\n"));

				appDelegate.ipAddress = ipAddr;
				holdWifiState = Disconnected;
				[wifi establishWifiConnection:appDelegate.ipAddress];

				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
			}
			else if(buttonIndex == 1)
			{
				[wifi disableWifiInterface:YES];
				WIFI_DEBUGPRINT(("User chose to change the IP address...\n"));

				if(wifiEnterNewIPAddress == nil)
				{
					NSString* ipAddr = [self validateCandidateIPSetting:appDelegate.ipAddress result:nil];

					wifiEnterNewIPAddress = [self makeAlert:NO tag:IPAddressError title:NSLocalizedString(@"Enter Valid IP Address", @"") message:nil textFieldText:ipAddr delegate:self cancelButtonTitle:NSLocalizedString(@"Done", @"") otherButtonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Set Port", @""), nil]];
				}

				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
			}
			else if(buttonIndex == 2)
			{
				[wifi disableWifiInterface:YES];
				WIFI_DEBUGPRINT(("User chose to cancel wifi connect attempts.\n"));
				[self drawButtons:buttonsRedraw];
				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
			}
		}
			break;


		case EnableWifiOnAppPrompt:
		{
			wifiStateTranstionAlert = nil;

			if(buttonIndex == 0)
			{
				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];

				WIFI_DEBUGPRINT(("User chose not to initiate wifi search from disabled state\n"));
			}
			else if(buttonIndex == 1)
			{
				[wifi disableWifiInterface:YES];
				WIFI_DEBUGPRINT(("User chose to change the address...\n"));

				if(iSDRAppDelegate.wifiIsEnabled)
				{
					if(wifiEnterNewIPAddress == nil) // no existing message is displayed
					{
						NSString* ipAddr = [self validateCandidateIPSetting:appDelegate.ipAddress result:nil];

						wifiEnterNewIPAddress = [self makeAlert:NO tag:IPAddressError title:NSLocalizedString(@"Enter Valid IP Address", @"") message:nil textFieldText:ipAddr delegate:self cancelButtonTitle:NSLocalizedString(@"Done", @"") otherButtonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Set Port", @""), nil]];

						if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
					}
				}
				else
				{
					WIFI_DEBUGPRINT(("Wi-Fi reachability failed\n")); // should never happen here
					if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playErrorSound];
				}

				[self drawButtons:buttonsRedraw];
			}
			else if(buttonIndex == 2)
			{
				WIFI_DEBUGPRINT(("User chose to initiate wifi connect from disabled state\n"));

				IpCheckResult result = NoGoodCandidateFound;
				NSString* ipAddr = [self validateCandidateIPSetting:appDelegate.ipAddress result:&result];

				appDelegate.ipAddress = ipAddr;
				holdWifiState = Disconnected;
				[wifi establishWifiConnection:appDelegate.ipAddress];
				[self drawButtons:buttonsRedraw];

				// If the radio IP address differs from the currently connected address, schedule a timer to expire a short time later
				// triggering a check to see if wifi has successfully connected with a networked radio interface. If it has not, then
				// we will pop up an alert message informing the user of the IP address discrepancy.
				if(result == CandidateDiffersFromConnected)
				{
					[self performSelector:@selector(alertUserOfIPDiscrepancy) withObject:nil afterDelay:10.];
				}

				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
			}
		}
			break;


		case CancelWifiSearchPrompt:
		{
			wifiStateTranstionAlert = nil;

			if(buttonIndex == 1)
			{
				WIFI_DEBUGPRINT(("User chose to disable wifi from searching state\n"));
				[wifi disableWifiInterface:YES];
				[self drawButtons:buttonsRedraw];
				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
			}
			else if(buttonIndex == 0)
			{
				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];

				WIFI_DEBUGPRINT(("User chose not to disable wifi from searching state\n"));
			}
		}
			break;


		case DisableWifiPrompt:
		{
			wifiStateTranstionAlert = nil;

			if(buttonIndex == 0)
			{
				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];

				WIFI_DEBUGPRINT(("User chose not to disable wifi from connected state\n"));
			}
			else  if(buttonIndex == 1)
			{
				WIFI_DEBUGPRINT(("User chose to disable wifi from connected state\n"));
				[wifi disableWifiInterface:YES];
				[self drawButtons:buttonsRedraw];
				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
			}
		}
			break;


		case EnableWifiOnDevicePrompt:
		{
			wifiDisabledOnDeviceAlert = nil;

			if(buttonIndex == 0) // ensure the user chose to close the alert
			{
				[wifi disableWifiInterface:YES];
				[self drawButtons:buttonsRedraw];
				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
			}
		}
			break;

		case ConnectionLostReconnectPrompt:
		{
			wifiConnectionLostAlert = nil;

			if(buttonIndex == 0) // ensure the user chose to close the alert
			{
				[wifi disableWifiInterface:YES];
				[self drawButtons:buttonsRedraw];
				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
			}
			else if(buttonIndex == 1)
			{
				IpCheckResult result = NoGoodCandidateFound;
				NSString* ipAddr = [self validateCandidateIPSetting:appDelegate.ipAddress result:&result];

				appDelegate.ipAddress = ipAddr;
				holdWifiState = Disconnected;
				[wifi establishWifiConnection:appDelegate.ipAddress];
				[self drawButtons:buttonsRedraw];

				// If the radio IP address differs from the currently connected address, schedule a timer to expire a short time later
				// triggering a check to see if wifi has successfully connected with a networked radio interface. If it has not, then
				// we will pop up an alert message informing the user of the IP address discrepancy.
				if(result == CandidateDiffersFromConnected)
				{
					[self performSelector:@selector(alertUserOfIPDiscrepancy) withObject:nil afterDelay:10.];
				}

				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
			}
		}
			break;

		case PortValuesChanged:
		case WifiConnectedToOtherDeviceWarning:
		case WifiNotReadyAlert:
		{
			if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
			// No action required
		}
			break;
			// Wifi support changes
			///////////////////////////////////////////////////////////////////////////////////////////

		default:
			break;
	}
}


///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
- (void)centerFrequencyChanged:(frequencyType)newFrequencyKHz spectrumShifted:(BOOL)spectrumShift stepped:(BOOL)stepping radioInitiated:(BOOL)radioInitiated
{
	// We've just been informed that the center frequency setting has been changed by the user.
	// So we need to adjust the position of the frequency overlay in order to keep the received frequency in kHz unchanged (SignalWindowLockMode).
	// If it is not possible to display the frequency overlay on the screen at its current frequency, then the frequency overlay
	// should be set to the edge of the display.
	// This method is also responsible for storing the new center frequency setting to defaults.

	static frequencyType lastReceivedFrequency = -1;

	// Throw out any echoed values
	if(newFrequencyKHz == lastReceivedFrequency)
	{
		if(defaultsWorkingCopy.centerFrequency == newFrequencyKHz) return;
	}

	lastReceivedFrequency = newFrequencyKHz;

	BOOL drawToEdge = FALSE;

	if(windowBehavior == SignalWindowLockMode)
	{
		if(spectrumShift) // if the signal spectrum shifted along with the center frequency setting, as would happen if a command was sent to an external radio
		{
			frequencyType holdLastCenterFrequencySettingkHz = defaultsWorkingCopy.centerFrequency;

#ifdef WIFI_DEBUG
			frequencyType deltaKHz = (newFrequencyKHz - holdLastCenterFrequencySettingkHz);

			WIFI_DEBUGPRINT(("centerFrequenyChanged: new:%0.2f kHz old:%0.2f kHz; Delta:%0.2f kHz; samplerate:%0.1u\n", newFrequencyKHz, holdLastCenterFrequencySettingkHz, deltaKHz, (unsigned int)sampleRateBandwidthHz));
#endif //WIFI_DEBUG

			float cursorFreq = fftBufferManager->getCenterFrequency();

			frequencyType cursorFreqKHz = ((cursorFreq - 0.5) * sampleRateBandwidthKHz) + holdLastCenterFrequencySettingkHz;
			frequencyType deltaCursorToCenterKHz = newFrequencyKHz - cursorFreqKHz;

			WIFI_DEBUGPRINT(("centerFrequenyChanged: cursor freq:%0.2f; deltaToCenter:%0.2f\n", cursorFreqKHz, deltaCursorToCenterKHz));

			frequencyType freq = 0.5;

			freq = 0.5 - 1000. * deltaCursorToCenterKHz / sampleRateBandwidthHz;

			BOOL hugEdge = stepping || radioInitiated;

			if(freq > 1.)
			{
				freq = hugEdge ? 1. : 0.5;
				drawToEdge = hugEdge;
			}
			else if(freq < 0.)
			{
				freq = hugEdge ? 0. : 0.5;
				drawToEdge = hugEdge;
			}

			WIFI_DEBUGPRINT(("centerFrequenyChanged: cursor freq:%0.2f kHz; deltaToCenter:%0.2f kHz; sending:%0.6f\n", cursorFreqKHz, deltaCursorToCenterKHz, freq));
			fftBufferManager->setCenterFrequency(freq);
		}

		defaultsWorkingCopy.centerFrequency = newFrequencyKHz;
		appDelegate.defaults = defaultsWorkingCopy;

		centerFrequencyText.text = switchCtl.plainToggle ? @"": [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];
		[self drawBandwidthOverlay:nil edgeReached:drawToEdge doErase:NO useFrequency:-1.];
		[self drawFrequencyOverlay];
	}
	else
	{
		// Let touchesMoved handle these tasks if these conditions aren't met
		if(radioInitiated || simpleTouchFrequencyEvent || (windowBehavior != FrequencyWindowLockMode) || (wifi.state & SocketEstablished))
		{
			defaultsWorkingCopy.centerFrequency = newFrequencyKHz;
			SDR_DEBUGPRINT(("*************************** New center frequency stored to defaults! **************************** \n"));
			appDelegate.defaults = defaultsWorkingCopy;

			centerFrequencyText.text = switchCtl.plainToggle ? @"": [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];
			[self drawFrequencyOverlay];
		}
	}
}

- (void)sendRadio_AI2
{
	// Auto-Info Set
	[wifi sendCommand_AI:2];
	[self performSelector:@selector(sendRadio_AI) withObject:nil afterDelay:1.];
}

- (void)sendRadio_AI
{
	// Auto-Info Query
	[wifi sendCommand_AI:-1];
}

- (void)radioDataReceived:(CatMessageType)messageType payload:(NSString*)msg
{
	if(msg == nil) return;

	switch(messageType)
	{
		case CAT_AI:
		{
			static NSInteger tries = 0;

			if([msg isEqualToString:@"AI2;"])
			{
				tries = 0;
				autoInfoConfirmationTime = [[NSDate date] timeIntervalSince1970];
				if(wifi.state == SocketEstablished) [wifi applyRadioConnection:self];

				NSRange r = {NSNotFound, 0};

				if(receiverModelText)
				{
					r = [receiverModelText rangeOfString:@"K3"];

					if(r.location == NSNotFound)
					{
						r = [receiverModelText rangeOfString:@"KX3"];
					}
				}

				if(r.location == NSNotFound)
				{
					[wifi performSelector:@selector(sendCommand_OM) withObject:nil afterDelay:1.];
				}

				[wifi performSelector:@selector(sendCommand_MD) withObject:nil afterDelay:2.];

			}
		}
			break;


		case CAT_K3:
		{
			if(receiverModelText == nil)
			{
				receiverModelText = [[NSMutableString alloc] initWithString:@"K3"];
			}
			else
			{
				BOOL isKx3 = ([receiverModelText rangeOfString:@"KX3"].location == 0);

				if(!isKx3)
				{
					[receiverModelText setString:@"K3"];
				}
			}

			fileInfoTextLandscape.text = [self getFileInfoText];

			[self drawButtons:buttonsRedraw];
		}
			break;


		case CAT_OM:
		{
			if(receiverModelText == nil)
			{
				receiverModelText = [[NSMutableString alloc] initWithString:@"K3"];
			}

			frequencyType freq = 0.5;
			iqOffsetFudgeFactorKHz = 0.;
			iqOffsetFudgeFactorNormalized = 0.;
			NSRange r = [msg rangeOfString:@"02;"];

			if(r.location == NSNotFound)
			{
				[receiverModelText setString:@"K3"];
			}
			else
			{
				[receiverModelText setString:@"KX3"];

				if([receiverModeText isEqualToString:@"CW"])
				{
					iqOffsetFudgeFactorKHz = 0.600;
					iqOffsetFudgeFactorNormalized = iqOffsetFudgeFactorKHz / sampleRateBandwidthKHz;

				}
			}

			fileInfoTextLandscape.text = [self getFileInfoText];

			if(windowBehavior == FrequencyWindowLockMode)
			{
				// set the CW offset to account for the KX3's shift of the I/Q spectrum
				freq -= iqOffsetFudgeFactorNormalized;
				fftBufferManager->setCenterFrequency(freq);
				[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:NO useFrequency:-1.];
			}

			centerFrequencyText.text = switchCtl.plainToggle ? @"": [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];
			[self drawFrequencyOverlay];
			[self drawButtons:buttonsRedraw];
		}
			break;


		case CAT_MD: // K3/KX3 Modes
		{
			NSRange r = [msg rangeOfString:@";"];

			if(r.location != NSNotFound)
			{
				if(receiverModeText == nil)
				{
					receiverModeText = [NSMutableString new];
				}

				r.location -= 1;

				NSInteger mode = [[msg substringWithRange:r] integerValue];

				frequencyType freq = 0.5;
				iqOffsetFudgeFactorKHz = 0.;
				iqOffsetFudgeFactorNormalized = 0.;

				switch (mode)
				{
					case 1: // LSB
					{
						[receiverModeText setString:NSLocalizedString(@"LSB", nil)];
						fileInfoTextLandscape.text = [self getFileInfoText];
					}
						break;

					case 2: // USB
					{
						[receiverModeText setString:NSLocalizedString(@"USB", nil)];
						fileInfoTextLandscape.text = [self getFileInfoText];
					}
						break;

					case 3: // CW
					{
						[receiverModeText setString:NSLocalizedString(@"CW", nil)];
						fileInfoTextLandscape.text = [self getFileInfoText];
						if([receiverModelText isEqualToString:@"KX3"])
						{
							iqOffsetFudgeFactorKHz = 0.600;
							iqOffsetFudgeFactorNormalized = iqOffsetFudgeFactorKHz / sampleRateBandwidthKHz;
						}
					}
						break;

					case 4: // FM
					{
						[receiverModeText setString:NSLocalizedString(@"FM", nil)];
						fileInfoTextLandscape.text = [self getFileInfoText];
					}
						break;

					case 5: // AM
					{
						[receiverModeText setString:NSLocalizedString(@"AM", nil)];
						fileInfoTextLandscape.text = [self getFileInfoText];
					}
						break;

					case 6: // DATA
					{
						[receiverModeText setString:NSLocalizedString(@"DATA", nil)];
						fileInfoTextLandscape.text = [self getFileInfoText];
					}
						break;

					case 7: // CW-REV
					{
						[receiverModeText setString:NSLocalizedString(@"CW-REV", nil)];
						fileInfoTextLandscape.text = [self getFileInfoText];
					}
						break;

					case 9: // DATA-REV
					{
						[receiverModeText setString:NSLocalizedString(@"DATA-REV", nil)];
						fileInfoTextLandscape.text = [self getFileInfoText];
					}
						break;

					default:
					{
						[receiverModeText setString:NSLocalizedString(@"?", nil)];
						fileInfoTextLandscape.text = [self getFileInfoText];
					}
						break;
				}


				if(windowBehavior == FrequencyWindowLockMode)
				{
					// set the CW offset to account for the KX3's shift of the I/Q spectrum
					freq -= iqOffsetFudgeFactorNormalized;
					fftBufferManager->setCenterFrequency(freq);
					[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:NO useFrequency:-1.];
				}

				[wifi performSelector:@selector(sendCommand_IS) withObject:nil afterDelay:1.];
				centerFrequencyText.text = switchCtl.plainToggle ? @"": [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];
				[self drawFrequencyOverlay];
				[self drawButtons:buttonsRedraw];
			}
		}
			break;


		case CAT_IS:
		{
			NSRange r = [msg rangeOfString:@";"];

			if(r.location != NSNotFound)
			{
				r.location -= 4;
				r.length = 4;
				receiverFrequencyOffsetHz = [[msg substringWithRange:r] doubleValue];

				fileInfoTextLandscape.text = [self getFileInfoText];
				[self drawButtons:buttonsRedraw];
			}
		}
			break;


		case CAT_IGNORED_DATA:
		{
#ifdef DO_NOT_USE
			if(autoInfoConfirmationTime < 1.)
			{
				static BOOL doOnce = TRUE;

				if(doOnce)
				{
					doOnce = FALSE;
					wifiEnterNewIPAddress = [self makeAlert:NO tag:WifiNotReadyAlert title:NSLocalizedString(@"Ignored data:", @"") message:[NSString stringWithFormat:@"Please report:\"%@\"", msg] textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
				}
			}
#endif // WIFI_DEBUG
		}
			break;

		default:
		{
			NSLog(@"Warning: unhandled wifi message type received: %@", msg);
		}
			break;
	}
}


- (frequencyType)stepCenterFrequency:(BOOL)direction
{
	defaultsWorkingCopy = appDelegate.defaults;

	float shift = direction ? FREQUENCY_STEP_SIZE_KHZ : -FREQUENCY_STEP_SIZE_KHZ;
	frequencyType centerkHz = defaultsWorkingCopy.centerFrequency;
	centerkHz += shift;
	centerkHz = CLAMP(MINIMUM_SETTABLE_RADIO_FREQUENCY_KHZ, centerkHz, MAXIMUM_SETTABLE_RADIO_FREQUENCY_KHZ);
	wifi.frequencyShift = shift;
	WIFI_DEBUGPRINT(("stepCenterFrequency: %0.2f; %0.2f\n", defaultsWorkingCopy.centerFrequency, centerkHz));

	// Send the center frequency to the radio.
	[wifi sendCommand_FA:centerkHz stepmode:YES];

	return centerkHz;
}

- (void)applyCenterFrequency:(UITouch*)touchLocation
{
	if(touchLocation == nil) return;

	static std::atomic_flag applyInProgress = ATOMIC_FLAG_INIT;

	// A second touch update can be dropped while the first one is still being applied.
	if(!applyInProgress.test_and_set(std::memory_order_acquire))
	{
		SDR_DEBUGPRINT(("drawBandwidthOverlay!\n"));

		static BOOL WFdrawn=FALSE, OSdrawn=FALSE;
		frequencyType freq = 0;
		GLfloat modeOverlayOffset = 0;
		GLfloat	thisTouchLocation;

		if(WFdrawn) [cursorLandscapeOverlayWF removeFromSuperview];
		if(OSdrawn) [cursorLandscapeOverlayOS removeFromSuperview];
		WFdrawn = OSdrawn = FALSE;

		if(self.displayMode == DisplayModeWaterfall)
		{
			thisTouchLocation = [touchLocation locationInView:self.view].y + modeOverlayOffset;
			freq = 1.0 - ( (thisTouchLocation - tunebarVertHeightOffset) / displayLandscapeHeight );
			freq = CLAMP(0.0, freq, 1.0);
		}
		else if(self.displayMode == DisplayModeOscilloscopeFFT)
		{
			thisTouchLocation = [touchLocation locationInView:self.view].x - modeOverlayOffset; // foobar - why the sign reversal?
			freq = thisTouchLocation / displayLandscapeWidth;
			freq = CLAMP(0.0, freq, 1.0);
		}

		frequencyType centerkHz = defaultsWorkingCopy.centerFrequency;

		centerkHz += ((freq - 0.5) * sampleRateBandwidthKHz);

		WIFI_DEBUGPRINT(("Frequency position touched: %0.2f kHz\n", centerkHz));

		[wifi sendCommand_FA:centerkHz stepmode:NO];

		applyInProgress.clear(std::memory_order_release);
	}

	return;
}


- (void)buttonWasTapped:(PlusMinusButton *)theButton repeating:(BOOL)repeating
{
	if((theButton == plusButton) || (theButton == minusButton))
	{
#ifdef TEST_WITHOUT_PIGLET
		if(wifi.state == Uninitialized) // allow full button operation without connection
		{
			// Searching state is not tested for, so it will be treated like SocketEstablished - helpful for testing
		}
#else
		if(wifi.state == Searching)
		{
			// buttons are disabled in this state, so ignore them
		}
#endif
		else if(wifi.state == Disconnected)
		{
			// Plus/Minus buttons are hidden in this state, so this should never happen
			// Dismiss any displayed message
            if(wifiStateTranstionAlert) [wifiStateTranstionAlert dismissViewControllerAnimated:FALSE completion:nil];

			// pop a warning message to let the user know that frequency setting changes are having no effect
			wifiStateTranstionAlert = [self makeAlert:NO tag:WifiNotReadyAlert title:NSLocalizedString(@"No Wi-Fi Connection", @"") message:NSLocalizedString(@"Wifi is disabled", @"") textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];

			//				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playErrorSound];
		}
		else
		{
			if(defaultsWorkingCopy.soundEffectsEnabled && !repeating) [mixerController playKeypressSound];

			frequencyType newFreqKHZ;

			if(theButton == minusButton)
			{
				WIFI_DEBUGPRINT(("Minus button tapped!\n"));
				newFreqKHZ = [self stepCenterFrequency:DOWN];
			}
			else // if(theButton == plusButton)
			{
				WIFI_DEBUGPRINT(("Plus button tapped!\n"));
				newFreqKHZ = [self stepCenterFrequency:UP];
			}

			// Handle chores that don't get taken care of since the touch was received by the button instead of EAGLViewController
			baseTouch = nil;
			slidingTouch = nil;
			simpleTouchFrequencyEvent = nil;

			if((windowBehavior == FrequencyWindowLockMode) && (wifi.state & SocketEstablished))
			{
				defaultsWorkingCopy.centerFrequency = newFreqKHZ;
				appDelegate.defaults = defaultsWorkingCopy;
				centerFrequencyText.text = switchCtl.plainToggle ? @"": [self centerFrequencyString:(newFreqKHZ + iqOffsetFudgeFactorKHz)];
			}

			[self drawFrequencyOverlay];

			if(self.displayMode == DisplayModeWaterfall)
			{
				[self drawButtons:buttonsTurnOn];
				[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];
			}
		}
	}
}


- (void)buttonWasTapped:(WifiButton*)theButton withState:(WifiState)state
{
	if(theButton == wifiButton)
	{
		switch(state)
		{
			case ConnectedWithRadio:
			case SocketEstablished:
			{
                if(wifiStateTranstionAlert) [wifiStateTranstionAlert dismissViewControllerAnimated:FALSE completion:nil];

				//[theButton applyStateSetting:Searching];
				// Pop a message asking if the user would like to disconnect
				wifiStateTranstionAlert = [self makeAlert:NO tag:DisableWifiPrompt title:NSLocalizedString(@"TCP Socket Active", @"") message:NSLocalizedString(@"Disconnect?", @"") textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Disconnect", @""), nil]];

				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
			}
				break;

			case Searching:
			{
				if(wifi.wifiIsAvailable)
				{
					switchCtl.plainToggle = FALSE;
					plusButton.highlighted = TRUE;
					minusButton.highlighted	= TRUE;

                    if(wifiStateTranstionAlert) [wifiStateTranstionAlert dismissViewControllerAnimated:FALSE completion:nil];

					[activeIPAddress setString:[self validateCandidateIPSetting:activeIPAddress result:nil]]; // take extra care to present a valid IP

					// Pop a message asking if the user would like to cancel search and disable wifi
					wifiStateTranstionAlert = [self makeAlert:NO tag:CancelWifiSearchPrompt title:NSLocalizedString(@"Wi-Fi Searching", @"") message:[NSString stringWithFormat:@"%@\n%@ (Port %@)", NSLocalizedString(@"Attempting TCP Connection:", @""), activeIPAddress, wifi.commandPort] textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Connect", @"") otherButtonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Quit", @""), nil]];

					if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];
				}
				else
				{
					if(!wifiDisabledOnDeviceAlert)
					{
						wifiDisabledOnDeviceAlert = [self makeAlert:NO tag:EnableWifiOnDevicePrompt title:NSLocalizedString(@"Wi-Fi Unavailable!", @"") message:NSLocalizedString(@"Wi-Fi is disabled on this device. Please enable in native Settings.", @"") textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];

						if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playErrorSound];
					}
				}
			}
				break;

			case Disconnected:
			{
				// Ensure wifi has the very latest wifi availability
				if(defaultsWorkingCopy.wifiFunctionalityEnabled)
				{
					if(wifi.wifiIsAvailable)
					{
						NSString* storedIP = appDelegate.ipAddress;
						[activeIPAddress setString:[self validateCandidateIPSetting:storedIP result:nil]];

						if(storedIP == nil) // The IP address is invalid, and possibly has never been set by the user
						{
							if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];

							if(wifiEnterNewIPAddress == nil)
							{
								wifiEnterNewIPAddress = [self makeAlert:NO tag:IPAddressError title:NSLocalizedString(@"Enter Valid IP Address", @"") message:nil textFieldText:activeIPAddress delegate:self cancelButtonTitle:NSLocalizedString(@"Done", @"") otherButtonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Set Port", @""), nil]];
							}
						}
						else
						{
							if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playKeypressSound];

                            if(wifiStateTranstionAlert) [wifiStateTranstionAlert dismissViewControllerAnimated:FALSE completion:nil];

							// Pop a message asking if the user would like to connect via wifi
							wifiStateTranstionAlert = [self makeAlert:NO tag:EnableWifiOnAppPrompt title:NSLocalizedString(@"Radio Disconnected", @"") message:[NSString stringWithFormat:@"%@\n%@ (Port %@)?", NSLocalizedString(@"Connect to ", @""), activeIPAddress, wifi.commandPort] textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Change", nil), NSLocalizedString(@"Connect", @""), nil]];
						}
					}
					else
					{
						if(!wifiDisabledOnDeviceAlert)
						{
							if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playErrorSound];

							wifiDisabledOnDeviceAlert = [self makeAlert:NO tag:EnableWifiOnDevicePrompt title:NSLocalizedString(@"Wi-Fi Unavailable!", @"") message:NSLocalizedString(@"Wi-Fi is disabled on this device. Please enable in native Settings.", @"") textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
						}
					}
				}
			}
				break;

			default:
				break;
		}

		// Handle chores that don't get taken care of since the touch was received by the button instead of EAGLViewController
		//[self drawFrequencyOverlay];
		baseTouch = nil;
		slidingTouch = nil;
		simpleTouchFrequencyEvent = nil;

		if(self.displayMode == DisplayModeWaterfall)
		{
			[self drawFrequencyOverlay];
			[self drawButtons:buttonsTurnOn];
			[self hideButtonCountdown:StartTimer selector:@selector(hideButtons)];
		}

	}
}


- (void)alertUserOfIPDiscrepancy
{
	// If we still aren't connected, pop up a message advising of IP discrepancy
	if(wifi.state == Searching)
	{
		if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playErrorSound];

		NSString* ssid = wifi.connectedSSID;
		NSString* message;

		if(ssid)
		{
			message = [NSString stringWithFormat:@"%@ %@ (%@). %@ %@ (Port %@).\n%@", NSLocalizedString(@"Wi-Fi is connected to", nil), ssid, wifi.connectedIPAddress, NSLocalizedString(@"This app is trying to establish a TCP socket with ", nil), activeIPAddress, wifi.commandPort, NSLocalizedString(@"If your radio interface is not networked you will need to use native Settings to connect to your radio interface, then return to this app and try again.", nil)];
		}
		else
		{
			message = [NSString stringWithFormat:@"%@ %@. %@ %@ (Port %@).\n%@", NSLocalizedString(@"Wi-Fi is connected to", nil), wifi.connectedIPAddress, NSLocalizedString(@"This app is trying to establish a TCP socket with ", nil), activeIPAddress, wifi.commandPort, NSLocalizedString(@"If your radio interface is not networked you will need to use native Settings to connect to your radio interface, then return to this app and try again.", nil)];
		}

		[self makeAlert:NO tag:WifiConnectedToOtherDeviceWarning title:NSLocalizedString(@"Connected to Router?\nPotential problem detected:", @"") message:message textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
	}
}

/*
 This method accepts a candidate IP address string, or nil, for input, and validates its format as an IPV4 address. It runs further
 comparisons to evaluate the liklihood that it will result in a connection. This method will always return a valid IP address, though it might
 differ from the candidate if the candidate is not a valid IPV4 address. The verdict parameter can be nil if no result value is required
 for evaluating error conditions.
 */
- (NSString*)validateCandidateIPSetting:(NSString*)candidate result:(IpCheckResult*)verdict
{
	NSString* returnValue = candidate;

	// See if the candidate looks ok
	BOOL candidateIsValid = FALSE;
	if(returnValue) candidateIsValid = [appDelegate isValidIPAddress:returnValue];

	if(!candidateIsValid)
	{
		// Candidate is no good so try the stored default value
		if(verdict) *verdict = BetterCandidateFound;
		returnValue = appDelegate.ipAddress;

		if(returnValue == nil)
		{
			// Default value sucked, so try a previously-successful IP address
			returnValue = appDelegate.successfulIPAddress;

			if(returnValue == nil)
			{
				// No previously-successful IP address, so just use a hard-coded valid (but bogus) address
				if(verdict) *verdict = NoGoodCandidateFound;
				returnValue = DEFAULT_IP_ADDRESS;
			}
		}
	}

	NSString* connectedIP = wifi.getWifiConnectedIPAddress;

	if(connectedIP)
	{
		// Wi-Fi is already connected to something... that could indicate a problem
		if(![connectedIP isEqualToString:returnValue])
		{
			// We are currently connected to a Wi-Fi IP that differs from the best choice - alert the caller that there might be a problem
			// Here we might want to try sending the connected device a command to which a valid radio interface device would respond - and
			// if it does respond then we could assume that the connected device IP address is the best candidate.
			if(verdict) *verdict = CandidateDiffersFromConnected;
		}
		else
		{
			if(verdict) *verdict = CandidateIsConnected;
		}

		WIFI_DEBUGPRINT(("SSID = %s\n", [[wifi connectedSSID] UTF8String]));
	}

	return returnValue;
}


- (BOOL)establishWifiConnection
{
	BOOL success = FALSE;

	if(wifi.state & SocketEstablished)
	{
		WIFI_DEBUGPRINT(("Warning: attempted to establish a wifi connect while already connected."));
		return TRUE;
	}

	[wifi addWifiResultListener:self]; // register to receive notifications from the singleton
	[wifi addCenterFrequencyListener:self]; // register to receive notifications for changes to the center frequency setting
	[wifi addRadioInfoListener:self]; // register to receive notifications for changes to the center frequency setting
	NSString* ipAddr = appDelegate.ipAddress;

	if(ipAddr == nil)
	{
		if(wifiEnterNewIPAddress == nil)
		{
			NSString* ipAddr = [self validateCandidateIPSetting:appDelegate.ipAddress result:nil];

			// Have the alert pop up right after we exit loadView in order to avoid errors caused by excessive delay here.
			// The following block will be scheduled to run at the next opportunity.
			wifiEnterNewIPAddress = [self makeAlert:NO tag:IPAddressError title:NSLocalizedString(@"Enter Valid IP Address", @"") message:nil textFieldText:ipAddr delegate:self cancelButtonTitle:NSLocalizedString(@"Done", @"") otherButtonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Set Port", @""), nil]];

			if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playErrorSound];
		}
	}
	else
	{
		WIFI_DEBUGPRINT(("Valid IP address (%s) found: attempting to connect to wifi...\n", [ipAddr UTF8String]));
		// Establish a wifi connection

		IpCheckResult result = NoGoodCandidateFound;
		[self validateCandidateIPSetting:ipAddr result:&result];

		[activeIPAddress setString:ipAddr];
		holdWifiState = Disconnected;
		[wifi establishWifiConnection:ipAddr];
		[self drawButtons:buttonsRedraw];

		// If the radio IP address differs from the currently connected address, schedule a timer to expire a short time later
		// triggering a check to see if wifi has successfully connected with a networked radio interface. If it has not, then
		// we will pop up an alert message informing the user of the IP address discrepancy.
		if(result == CandidateDiffersFromConnected)
		{
			[self performSelector:@selector(alertUserOfIPDiscrepancy) withObject:nil afterDelay:10.];
		}

		success = TRUE;
	}

	return success;
}

- (void)setupForWifiDisconnectedState
{
	WIFI_DEBUGPRINT(("initializeForWifiDisabledState\n"));

	// register as a listener since this state is an entry point for app startup
	[wifi addWifiResultListener:self]; // register to receive notifications from the singleton
	[wifi addCenterFrequencyListener:self]; // register to receive notifications for changes to the center frequency setting
	[wifi addRadioInfoListener:self]; // register to receive notifications for changes to the center frequency setting

	windowBehavior = SignalWindowLockMode; // Allow cursor movement without sound

	if(rssiMeter)
	{
		[rssiMeter sleep];
	}

	[self.eaglView stopAnimation];
	mixerController.mute = TRUE;
	[mixerController stopAUGraph:FALSE]; // stop audio flow
	switchCtl.on = FALSE;

	[self.eaglView clearView:TRUE];

	defaultsWorkingCopy = appDelegate.defaults;
	centerFrequencyText.text = switchCtl.plainToggle ? @"": [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];
	[wifi disableWifiInterface:YES];
}


// Adding mandatory WifiInterfaceListener methods
- (void)receiveWifiInterfaceResult:(WifiResult)data
{
	WIFI_DEBUGPRINT(("Listener: Result received from wifi: "));

	switch(data)
	{
		case WifiStubResultForTesting:
		{
			WIFI_DEBUGPRINT(("Stub value received from wifi (still need to implement something!)\n"));
		}
			break;

		case WifiSuccessEstablishedConnection:
		{
			// Get the initial center frequency and send it to the radio
			[self performSelector:@selector(sendRadio_AI2) withObject:nil afterDelay:3.];
			[wifi sendCommand_FA:-1. stepmode:FALSE]; // request radio's current setting
			[wifi sendCommand_FA:defaultsWorkingCopy.centerFrequency stepmode:NO];
			WIFI_DEBUGPRINT(("Wifi connection established successfully!\n"));
			[self drawButtons:buttonsRedraw];
		}
			break;

		case WifiErrorConnectionFailed:
		case WifiErrorTCPConnectionFailed:
		{
#ifdef WIFI_DEBUG
			if(data == WifiErrorConnectionFailed)
			{
				WIFI_DEBUGPRINT(("Wifi error: failed to establish UDP connection.\n"));
			}
			else
			{
				WIFI_DEBUGPRINT(("Wifi error: failed to establish TCP connection.\n"));
			}
#endif
			if(wifi.state != Disconnected) // ignore connection failures if the user has disabled wifi
			{
                if(wifiStateTranstionAlert) [wifiStateTranstionAlert dismissViewControllerAnimated:FALSE completion:nil];

				NSString* ipAddr = appDelegate.ipAddress;

				if(ipAddr == nil)
				{
					ipAddr = DEFAULT_IP_ADDRESS;
				}

				NSString* message = [NSString stringWithFormat:@"Check your settings: \nRemote IP: %@\nCommand Port: %@\nData Port: %@", ipAddr, wifi.commandPort, wifi.dataPort];

				wifiStateTranstionAlert = [self makeAlert:NO tag:WifiConnectionFailedError title:NSLocalizedString(@"Wi-Fi Unable To Connect", nil) message:message textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Retry", nil) otherButtonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Change", nil), NSLocalizedString(@"Quit", nil), nil]];

				if(defaultsWorkingCopy.soundEffectsEnabled) [mixerController playErrorSound];
			}
		}
			break;

		case WifiErrorInGetAddrInfoCall:
		{
			WIFI_DEBUGPRINT(("Wifi error: connection failed due to address failure.\n"));
		}
			break;

		case WifiErrorCommandPortNotSet:
		{
			WIFI_DEBUGPRINT(("Wifi error: attempted to send a wifi command before the port was set!\n"));
		}
			break;

		case WifiSendCommandSucceeded:
		{
			WIFI_DEBUGPRINT(("Wifi sendCommand succeeded!\n"));
		}
			break;

		case WifiErrorSendCommandFailedDueToNoConnection:
		{
			WIFI_DEBUGPRINT(("Wifi error: sendCommand failed due to no connection!\n"));
		}
			break;

		case WifiErrorSendCommandFailedDueToDisabled:
		{
			WIFI_DEBUGPRINT(("Wifi error: sendCommand failed due to interface being in disabled state!\n"));
		}
			break;

		case WifiErrorTCPSendCommandFailed:
		{
			WIFI_DEBUGPRINT(("Wifi error: TCP sendCommand failed!\n"));
		}
			break;

		case WifiErrorWifiDisablbedOnDevice:
		{
			if(defaultsWorkingCopy.wifiFunctionalityEnabled)
			{
				WIFI_DEBUGPRINT(("Wifi error: Wifi is disabled on the device!\n"));
				[self performBlockOnMainThread:^{
                    if(!self->wifiDisabledOnDeviceAlert)
					{
                        self->wifiDisabledOnDeviceAlert = [self makeAlert:NO tag:EnableWifiOnDevicePrompt title:NSLocalizedString(@"Wi-Fi Unavailable!", @"") message:NSLocalizedString(@"Wi-Fi is disabled on this device. Please enable in native Settings.", @"") textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
					}

                    if(self->defaultsWorkingCopy.soundEffectsEnabled) [self->mixerController playErrorSound];
				}];
			}
		}
			break;

		case WifiInterfaceNotInConnectedState:
		{
			// A message failed to be delivered because wifiInterface is not in connected state.
			if(wifiConnectionLostAlert == nil)
			{
                if(wifiStateTranstionAlert) [wifiStateTranstionAlert dismissViewControllerAnimated:FALSE completion:nil];

				wifiConnectionLostAlert = [self makeAlert:NO tag:ConnectionLostReconnectPrompt title:NSLocalizedString(@"Wi-Fi Connection Lost", @"") message:nil textFieldText:nil delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Reconnect", nil), nil]];
			}
		}
			break;

		default:
		{
			WIFI_DEBUGPRINT(("Oops! Forgot to interpret the result value received! (%d)\n", data));
		}
			break;
	}
}

/*
 Listener method for receiving wifi state change notifications.
 */
- (void)newWifiState:(WifiState)aState
{
	switch(aState)
	{
		case Disconnected:
		{
			WIFI_DEBUGPRINT(("EVC received wifi state transition to Disconnected\n"));

			if(rssiMeter)
			{
				[rssiMeter sleep];
			}

			mixerController.mute = TRUE;
			[mixerController stopAUGraph:FALSE]; // stop audio flow
			iqOffsetFudgeFactorKHz = 0.;
			iqOffsetFudgeFactorNormalized = 0.;

			// Transitioning to disabled state turns off audio
			plusButton.disabled = TRUE;
			minusButton.disabled = TRUE;

			windowBehavior = SignalWindowLockMode;
			centerFrequencyText.text = @""; //[self centerFrequencyString:defaultsWorkingCopy.centerFrequency];

			switchCtl.plainToggle = TRUE;

			if(switchCtl.on == TRUE)
			{
				switchCtl.on = FALSE;
			}

			[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:NO useFrequency:-1.];
			[self drawFrequencyOverlay];
			[self.eaglView clearView:FALSE];
			[self drawButtons:buttonsRedraw];
		}
			break;

		case Searching:
		{
			WIFI_DEBUGPRINT(("EVC received wifi state transition to Searching\n"));
			// Transitioning to the Searching state automatically enables microphone if it is not already enabled

#ifdef TEST_WITHOUT_PIGLET
			// Enable the buttons while searching to facilitate debugging
			plusButton.disabled = FALSE;
			minusButton.disabled = FALSE;
#else
			plusButton.disabled = TRUE;
			minusButton.disabled = TRUE;
#endif
			switchCtl.plainToggle = FALSE;

			if(defaultsWorkingCopy.demoModeOnly)
			{
				defaultsWorkingCopy.demoModeOnly = NO;
				appDelegate.defaults = defaultsWorkingCopy;
				[self applyRadioSettings:TRUE];
			}

			[self drawBandwidthOverlay:nil edgeReached:FALSE doErase:NO useFrequency:-1.];
			[self drawFrequencyOverlay];
			centerFrequencyText.text = switchCtl.plainToggle ? @"": [self centerFrequencyString:(defaultsWorkingCopy.centerFrequency + iqOffsetFudgeFactorKHz)];

			// Update (or add) the address printed below the wifi button
			ipAddressText.text = [self ipAddressString];
			[self drawButtons:buttonsRedraw];
		}
			break;

		case ConnectedWithRadio:
		{
			WIFI_DEBUGPRINT(("EVC received wifi state transition to ConnectedWithRadio\n"));
		}
			break;

		case SocketEstablished:
		{
			WIFI_DEBUGPRINT(("EVC received wifi state transition to Connected\n"));
			plusButton.disabled = FALSE;
			minusButton.disabled = FALSE;
			if(defaultsWorkingCopy.soundEffectsEnabled && (holdWifiState == Disconnected)) [mixerController playSuccessSound];
			defaultsWorkingCopy.hasSuccessfullyConnectedViaWifi = TRUE;
			appDelegate.defaults = defaultsWorkingCopy;
			appDelegate.successfulIPAddress = appDelegate.ipAddress; // record the last successful connection's IP address
			[appDelegate writeDefaultsToFileSystem];
		}
			break;

		default:
		{
			NSLog(@"Warning: a wifi state is not being handled!");
		}
			break;
	}
}
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////


@end

@implementation OverlayView
{
}

@synthesize doNotTimeout;
@synthesize isVisible;

- (id)init
{
	self = [super init];

	if(self)
	{
		doNotTimeout = FALSE;
		isVisible = FALSE;
	}

	return self;
}


@end
