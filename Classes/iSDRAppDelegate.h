/*
 Third-party provenance: portions of this file are derived from Apple's
 aurioTouch/aurioTouch2 sample code.

 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

 File: iSDRAppDelegate.h
 Abstract: App delegate
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

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <CoreFoundation/CFURL.h>

#import "product.h"
#import "EAGLView.h"
#import "SplashView.h"

#ifndef CLAMP
#define CLAMP(min,x,max) (x < min ? min : (x > max ? max : x))
#endif

typedef enum iSDRDisplayMode {
	DisplayModeOscilloscopeWaveform,
	DisplayModeOscilloscopeFFT,
	DisplayModeWaterfall
} iSDRDisplayMode;

typedef struct deviceDescription
{
	//	DeviceType			device;
	NSString*                   			model;
	float									ppm;
	BOOL									hasGyroscope;
	BOOL									hasCamera;
	DisplayHardwareType						display;
	CGFloat									portraitHeight;
	CGFloat									portraitWidth;
	BOOL									use568displayPixelRatio;
//	float									screenDiagonalMeters;
} DeviceDescription;


@class EAGLViewController, SplashView;

@interface iSDRAppDelegate : NSObject <UIApplicationDelegate, SplashViewDelegate>
{
	IBOutlet UIWindow*			window;
	IBOutlet EAGLView*			view;
	EAGLViewController*			eaglViewController;
	SplashView*					mySplash;
    DefaultSettingsType			defaults;
	DefaultSettingsType			holdDefaults;
	BOOL						orientationSupport[UIDeviceOrientationFaceDown+1];
	NSString*                   versionString;
	DeviceDescription			hardware;

	///////////////////////////////////////////////////////////////////////////////////////////
	// Wifi support changes
	NSMutableString*					holdCommandPort;
	NSMutableString*					holdDataPort;
	NSMutableString*					holdIPAddress;
	// Wifi support changes
	///////////////////////////////////////////////////////////////////////////////////////////
}

@property (nonatomic, strong)			UIWindow*				window;
@property (nonatomic, strong)			EAGLView*				view;
@property (nonatomic, strong)			SplashView*				mySplash;

@property (nonatomic, strong)			EAGLViewController*		eaglViewController;
@property (nonatomic, readwrite, setter = setDefaultSettings:, getter = getDefaultSettings)		DefaultSettingsType		defaults;
@property (nonatomic, readonly)			DeviceDescription		hardware;

///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
// These properties will allow you to access the setters and getters using "dot" notation,
@property (weak, setter = setSuccessfulIPAddress:, getter = getSuccessfulIPAddress) NSString* successfulIPAddress;
@property (weak, setter = setIPAddress:, getter = getIPAddress) NSString* ipAddress;
@property (weak, setter = setCommandPort:, getter = getCommandPort) NSString* commandPort;
@property (weak, setter = setDataPort:, getter = getDataPort) NSString* dataPort;
@property (nonatomic, strong) NSMutableString*		holdCommandPort;
@property (nonatomic, strong) NSMutableString*		holdDataPort;
@property (nonatomic, strong) NSMutableString*		holdIPAddress;
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////

- (DefaultSettingsType)getDefaultSettings;
- (DeviceDescription)getHardware;
- (void)setDefaultSettings:(DefaultSettingsType)value;
- (void)splashIsDone;
- (void)writeDefaultsToFileSystem;
- (void)readDefaultsFromFileSystem;
- (void)configureMainWindow;
- (void)defaultsChanged:(NSNotification *)notif;
+ (NSString*)getAppName;
- (void)markIntroductoryMessageDisplayed;
+ (NSTimeInterval)getDateSince1970:(NSString*)dateString;

///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
- (BOOL)isValidIPAddress:(NSString*)address;
- (void)setIPAddress:(NSString*)address;
- (NSString*)getIPAddress;
- (void)setSuccessfulIPAddress:(NSString*)address;
- (NSString*)getSuccessfulIPAddress;
- (void)setCommandPort:(NSString*)port;
- (NSString*)getCommandPort;
- (void)setDataPort:(NSString*)port;
- (NSString*)getDataPort;
+ (BOOL)wifiIsEnabled;
//- (void)wifiPurchaseCompleted;
//- (BOOL)checkForWifiPurchase:(NSArray*)productsList enableIfPurchased:(BOOL)enable;
//- (void)wifiPurchaseRemovalAllPersistence;
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////

+ (BOOL)isNetworkReachableViaWWAN;

@end
