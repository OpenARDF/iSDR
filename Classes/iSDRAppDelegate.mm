/*
 Third-party provenance: portions of this file are derived from Apple's
 aurioTouch/aurioTouch2 sample code.

 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

 File: iSDRAppDelegate.mm
 Abstract: n/a
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

#import "product.h"
#import "iSDRAppDelegate.h"
#import "SceneDelegate.h"
#import "AudioUnit/AudioUnit.h"
#import "CAXException.h"
#import "SplashView.h"
#import "EAGLViewController.h"
#import <UIKit/UIDevice.h>
#import <AvailabilityInternal.h>
#import <CoreMotion/CoreMotion.h>
#import <TargetConditionals.h>
#include <atomic>

//#import "RMStore.h"
//#import "RMStoreTransactionReceiptVerifier.h"
//#import "RMStoreAppReceiptVerifier.h"
//#import "RMStoreKeychainPersistence.h"

///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
#if TARGET_OS_IPHONE
#import "Reachability.h"
//#import "ASIAuthenticationDialog.h"
//#import <MobileCoreServices/MobileCoreServices.h>
#else
#import <SystemConfiguration/SystemConfiguration.h>
#endif
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////


//NSString* kPreferencesInitializedKey = @"preferencesInitializedKey";
NSString* kSoundEffectsSettingKey			= @"soundEffectsEnabledKey";
NSString* kiSDRCenterFrequencyKey			= @"iSDRCenterFrequencyKey";
NSString* kiSDRdemoModeOnlyKey				= @"iSDRdemoModeOnlyKey";
NSString* kiSDRreverseIQKey					= @"iSDRreverseIQKey";
NSString* kiSDRoperatingModeKey				= @"iSDRoperatingModeKey";
NSString* kiSDRbpfBandwidthKey				= @"iSDRbpfBandwidthKey";
NSString* kiSDRbpfRxOffsetKey				= @"iSDRbpfRxOffsetKey";
NSString* kiSDRagcSettingKey				= @"iSDRagcSettingKey";
NSString* kSimpleTouchEnabledKey			= @"simpleTouchEnabledKey";
NSString* kSpectrumGridTypeKey				= @"spectrumGridTypeKey";
NSString* kGridBrightnessKey				= @"gridBrightnessKey";
NSString* kSignalDisplayScaleFactorKey		= @"signalDisplayScaleFactorKey";
NSString* kiSDRVersionKey					= @"iSDRVersionKey";
NSString* kPlayWhileMinimizedKey			= @"playWhileMinimizedKey";
NSString* kIntroMessageShownKey				= @"introMessageShownKey";
NSString* kWifiFunctionalityEnabledKey		= @"wifiFunctionalityEnabledKey";
NSString* kWifiFunctionalityPurchasedKey	= @"wifiFunctionalityPurchasedKey";
NSString* kNewInstallKey					= @"newInstallKey";
///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
NSString* kSuccessfulIPAddressKey			= @"successfulIPAddressKey";
NSString* kiSDRIPAddressKey                 = @"iSDRIPAddressKey";
NSString* kiSDRCommandPortKey               = @"iSDRCommandPortKey";
NSString* kiSDRDataPortKey                  = @"iSDRDataPortKey";
NSString* kHasSuccessfullyConnectedKey		= @"hasSuccessfullyConnectedKey";
NSString* kPlusMinusOrientationKey			= @"plusMinusOrientationKey";
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////

static BOOL removePurchasesPersistence = FALSE;

static NSString *iSDRDeviceModelName(void)
{
#if TARGET_OS_SIMULATOR
    return @"Simulator";
#else
    UIDevice *device = [UIDevice currentDevice];

    // The only exact hardware name used by iSDR affects a legacy display-density
    // estimate. Screen geometry preserves that behavior without maintaining a
    // third-party table of Apple machine identifiers.
    if(device.userInterfaceIdiom == UIUserInterfaceIdiomPhone)
    {
        CGSize nativeSize = [UIScreen mainScreen].nativeBounds.size;
        CGFloat longestSide = MAX(nativeSize.width, nativeSize.height);
        if(lround(longestSide) == 2208)
        {
            return @"iPhone 6 Plus";
        }
    }

    return device.model ?: @"Unknown";
#endif
}

@implementation iSDRAppDelegate
{
    ///////////////////////////////////////////////////////////////////////////////////////////
    // Wifi support changes
    BOOL portValidationInProgress; // flag to prevent deadlock
    BOOL portSettingsWereModified; // Flag gets set when port settings validation forced at least one of the settings to be changed
    // Wifi support changes
    ///////////////////////////////////////////////////////////////////////////////////////////

    //    id<RMStoreReceiptVerifier> _receiptVerifier;
    //    RMStoreKeychainPersistence *_persistence;
    NSArray* purchasedProducts;
}

static UIDeviceOrientation deviceOrientation;
static NSString* appName;

@synthesize window;
@synthesize view;
@synthesize eaglViewController;
@synthesize defaults = _defaults;
@synthesize hardware = _hardware;
@synthesize mySplash;

///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
@synthesize holdCommandPort, holdDataPort, holdIPAddress;
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////

#pragma mark-

// UIDeviceOrientationDidChangeNotification selector
+ (void)deviceOrientationDidChange
{
    deviceOrientation = [[UIDevice currentDevice] orientation];
    // Don't update the reference orientation when the device orientation is face up/down or unknown.
    //	if ( UIDeviceOrientationIsPortrait(orientation) || UIDeviceOrientationIsLandscape(orientation) )
    //		[videoProcessor setReferenceOrientation:orientation];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    SDR_DEBUGPRINT(("application didFinishLaunchingWithOptions:...\n"));
    SDR_DEBUGPRINT(("__IPHONE_OS_VERSION_MAX_ALLOWED = %d\n", __IPHONE_OS_VERSION_MAX_ALLOWED));

    //	[self configureStore];

    //	if(removePurchasesPersistence)
    //	{
    //		[self wifiPurchaseRemovalAllPersistence];
    //	}

    // Turn off the idle timer, since this app doesn't rely on constant touch input
    application.idleTimerDisabled = YES;

    // We expect write failures to occur but we want to handle them where
    // the error occurs rather than in a SIGPIPE handler.
    signal(SIGPIPE, SIG_IGN);

#ifdef ENABLE_VIDEO_OUT
    [[UIApplication sharedApplication] performSelector: @selector(startTVOut)
                                            withObject: nil afterDelay: .1];
#endif

    [self readDefaultsFromFileSystem];
    [self getHardware];

    return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
    options:(UISceneConnectionOptions *)options
{
    UISceneConfiguration *configuration =
        [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                       sessionRole:connectingSceneSession.role];
    configuration.delegateClass = [SceneDelegate class];
    return configuration;
}

- (void)configureMainWindow
{
    if(self.eaglViewController != nil)
    {
        return;
    }

    // Set up main view controller
    SDR_DEBUGPRINT(("Creating viewController...\n"));
    EAGLViewController *viewController = [EAGLViewController new];
    self.eaglViewController = viewController;
    [self.window setRootViewController:self.eaglViewController];

    self.eaglViewController.appDelegate = self;
    self.eaglViewController.hideStatusBar = TRUE; // Hide it until splash finishes

    if([self.eaglViewController respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)])
    {
        [self.eaglViewController setNeedsStatusBarAppearanceUpdate];
    }

    [self.window setRootViewController:self.eaglViewController];
    [self.window makeKeyAndVisible];

//    if(SYSTEM_VERSION_LESS_THAN(@"8.0"))
//    {
//        [self doSplash:self.window subview:viewController.view height:self.hardware.portraitHeight width:self.hardware.portraitWidth];
//    }
//
    [self endSplash];
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

- (NSUInteger)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window
{
    return UIInterfaceOrientationMaskLandscape;
}



- (void)doSplash:(UIView*)parentView subview:(UIView*)subview height:(CGFloat)height width:(CGFloat)width
{
    SDR_DEBUGPRINT(("inside doSplash...\n"));
    UIInterfaceOrientation orient = self.window.windowScene.interfaceOrientation;
    // The scene can briefly report unknown while the launch window is being attached.
    if(orient == UIInterfaceOrientationUnknown)
    {
        orient = UIInterfaceOrientationLandscapeRight;
    }
    UIImage* img = nil;
    OrientationRotateType rotation = Rotate0;

    if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
#ifdef SDR_DEBUG
        SDR_DEBUGPRINT(("orient iPad\n"));
        CGFloat aspect = height / width;
        SDR_DEBUGPRINT(("Aspect ratio: %0.2f\n", aspect));
#endif

        if(SYSTEM_VERSION_LESS_THAN(@"6.0")) // iPad 1
        {
            img = [UIImage imageNamed:@"Default-iPad-Landscape.png"];
        }
        else
        {
            UIEdgeInsets capInsets = UIEdgeInsetsMake(0., 0., 0., 0.);
            CGSize newSize = CGSizeMake(width, height);

            img = [[UIImage imageNamed:@"Default-iPad-Landscape@2x.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];

            if(img)
            {
                img = [self imageResize:img andResizeTo:newSize];

                if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
                {
                    rotation = Rotate270;
                }
            }
        }
    }
    else
    {
        CGFloat aspect = height / width;

#ifdef SDR_DEBUG
        SDR_DEBUGPRINT(("orient iPhone\n"));
        SDR_DEBUGPRINT(("Aspect ratio: %0.2f\n", aspect));
#endif

        if(self.hardware.use568displayPixelRatio) // iPhone 5s
        {
            UIEdgeInsets capInsets = UIEdgeInsetsMake(0., 0., 0., 0.);
            CGSize newSize = CGSizeMake(width, height);

            img = [[UIImage imageNamed:@"Default-568h@2x.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];

            if(img)
            {
                img = [self imageResize:img andResizeTo:newSize];

                if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
                {
                    rotation = Rotate270;
                }
            }
        }
        else
        {
            if(SYSTEM_VERSION_LESS_THAN(@"6.0")) // iPhone 3Gs
            {
                img = [UIImage imageNamed:@"Default.png"];
            }
            else
            {
                if((aspect >1.77) && (aspect < 1.79)) // iPhone 6 and 6+ aspect ratio
                {
                    UIEdgeInsets capInsets = UIEdgeInsetsMake(0., 0., 0., 0.);
                    CGSize newSize = CGSizeMake(height, width);

                    img = [[UIImage imageNamed:@"Default-Portrait-iOS8-55.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];

                    if(img)
                    {
                        img = [self imageResize:img andResizeTo:newSize];
                    }
                }
                else
                {
                    UIEdgeInsets capInsets = UIEdgeInsetsMake(0., 0., 0., 0.);
                    CGSize newSize = CGSizeMake(width, height);

                    img = [[UIImage imageNamed:@"Default-iPhone@2x.png"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];

                    if(img)
                    {
                        img = [self imageResize:img andResizeTo:newSize];

                        if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
                        {
                            rotation = Rotate270;
                        }
                    }
                }
            }
        }
    }

    if(img)
    {
        SplashView* splash = [[SplashView alloc] initWithImage:img];
        self.mySplash = splash;

        mySplash.imageRotation = rotation;

        [parentView insertSubview:mySplash aboveSubview:subview];

        // Display splash screen

        mySplash.animation = SplashViewAnimationFade;
        mySplash.delay = 3;
        mySplash.touchAllowed = NO;
        mySplash.delegate = self;
        //[mySplash startSplash];
        [mySplash manualSplash:orient showActivity:FALSE];
    }
    else
    {
        NSLog(@"Warning: missing splash image!");
    }

    SDR_DEBUGPRINT(("...exiting doSplash.\n"));
}


- (void)endSplash
{
    SDR_DEBUGPRINT(("inside endSplash...\n"));
//    [mySplash dismissSplash];
    self.mySplash = nil;

    if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        self.eaglViewController.hideStatusBar = FALSE;
        if([self.eaglViewController respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)])
        {
            [self.eaglViewController setNeedsStatusBarAppearanceUpdate];
        }
    }

    SDR_DEBUGPRINT(("mySplash has been dismissed.\n"));
}


- (void)splashIsDone
{
    SDR_DEBUGPRINT(("Splash finished...\n"));
    self.mySplash = nil;

    if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        self.eaglViewController.hideStatusBar = FALSE;
        if([self.eaglViewController respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)])
        {
            [self.eaglViewController setNeedsStatusBarAppearanceUpdate];
        }
    }

    [eaglViewController refreshDisplay];

    ///////////////////////////////////////////////////////////////////////////////////////////
    // Wifi support changes
    if(portSettingsWereModified)
    {
        [eaglViewController alertUserOfPortChanges:[self getDataPort] commandPort:[self getCommandPort]];
    }
    // Wifi support changes
    ///////////////////////////////////////////////////////////////////////////////////////////
}


- (DeviceDescription)getHardware
{
    static BOOL initialized = FALSE;

    if(!initialized)
    {
        SDR_DEBUGPRINT(("Initializing hardware for the first time!\n"));

        initialized = TRUE;

        CGFloat pointWidth = [[UIScreen mainScreen] bounds].size.width;
        CGFloat pointHeight = [[UIScreen mainScreen] bounds].size.height;
        _hardware.portraitWidth = (pointWidth < pointHeight) ? pointWidth : pointHeight;
        _hardware.portraitHeight = (pointWidth < pointHeight) ? pointHeight : pointWidth;

        SDR_DEBUGPRINT(("Screen points w x h: %0.0f x %0.0f\n", _hardware.portraitWidth, _hardware.portraitHeight));

        SDR_DEBUGPRINT(("Screen pixels w x h: %0.0f x %0.0f\n", [[UIScreen mainScreen] nativeBounds].size.width, [[UIScreen mainScreen] nativeBounds].size.height));

        _hardware.model = iSDRDeviceModelName();

        SDR_DEBUGPRINT(("Product Type: %s\n", [_hardware.model UTF8String]));

        CGFloat height = [[UIScreen mainScreen] nativeBounds].size.height;

        if([_hardware.model  isEqual: @"Simulator"])
        {
            if(height == 2208)
            {
                _hardware.model = @"iPhone 6 Plus";
#ifdef SDR_DEBUG
                SDR_DEBUGPRINT(("Using Product Type: iPhone 6 Plus (simulator)\n"));
#endif // SDR_DEBUG
            }
            else if(height == 1334)
            {
                _hardware.model = @"iPhone 6";
#ifdef SDR_DEBUG
                SDR_DEBUGPRINT(("Using Product Type: iPhone 6 (simulator)\n"));
#endif // SDR_DEBUG
            }
            else if(_hardware.portraitHeight == 568.)
            {
                _hardware.model = @"iPhone 5s";
#ifdef SDR_DEBUG
                SDR_DEBUGPRINT(("Using Product Type: iPhone 5S (simulator)\n"));
#endif // SDR_DEBUG
            }
        }

        // Handle iPhone 5 and iPod 5 extra height/width ratio for things such as splash screens, etc
        _hardware.use568displayPixelRatio = (lround(_hardware.portraitHeight) == lround(568.));
        _hardware.display = [iSDRAppDelegate isRetinaDisplay] ? Retina_Display : NonRetina_Display;

        _hardware.hasGyroscope = [self isGyroscopeAvailable];
        _hardware.hasCamera = [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear];

        if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        {
            // 3: 2048-by-1536-pixel resolution at 264 pixels per inch (ppi)
            // 4: 2048-by-1536 resolution at 264 pixels per inch (ppi)
            // Air: 2048-by-1536 resolution at 264 pixels per inch (ppi)
            // mini retina: 2048-by-1536 resolution at 326 pixels per inch (ppi)
            _hardware.ppm = 5196.85; //pixels per meter = 132 ppi for iPad display
        }
        else
        {
            if(![_hardware.model isEqual: @"iPhone 6 Plus"])
            {
                // 4: 960-by-640-pixel resolution at 326 ppi
                // 5s: 1136-by-640-pixel resolution at 326 ppi
                // 5c: 1136-by-640-pixel resolution at 326 ppi
                // 6: 1334-by-750-pixel resolution at 326 ppi
                _hardware.ppm = 6417.32; // pixels per meter = 163 ppi for most devices
            }
            else
            {
                // 6+: 1920-by-1080-pixel resolution at 401 ppi
                _hardware.ppm = 7893.70;
            }
        }

    }

    return _hardware;
}



/***********************************************************************************************************************
 In-App Store Support
 ***********************************************************************************************************************/

//- (void)configureStore
//{
//	if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0"))
//	{
//		_receiptVerifier = [[RMStoreAppReceiptVerifier alloc] init];
//	}
//#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
//	else
//	{
//		_receiptVerifier = [[RMStoreTransactionReceiptVerificator alloc] init];
//	}
//#endif
//
//    [RMStore defaultStore].receiptVerifier = _receiptVerifier;
//
//    _persistence = [[RMStoreKeychainPersistence alloc] init];
//    [RMStore defaultStore].transactionPersistor = _persistence;
//
//    purchasedProducts = [[_persistence purchasedProductIdentifiers] allObjects];
//
//#ifdef SDR_DEBUG
//	for(NSString* p in purchasedProducts)
//	{
//		SDR_DEBUGPRINT(("Product: %s\n", [p UTF8String]));
//	}
//#endif
//
//	[self checkForWifiPurchase:purchasedProducts enableIfPurchased:NO];
//}
//
//
//- (BOOL)checkForWifiPurchase:(NSArray*)productsList enableIfPurchased:(BOOL)enable
//{
//	BOOL wifiPurchased = (BOOL)[[NSUserDefaults standardUserDefaults] boolForKey:kWifiFunctionalityPurchasedKey];
//
//#ifdef SDR_DEBUG
//	if(wifiPurchased)
//	{
//		SDR_DEBUGPRINT(("Purchase flag is set. Simply returning stored value.\n"));
//	}
//#endif
//
//	if(!wifiPurchased)
//	{
//		if(productsList)
//		{
//			for(NSString* s in productsList)
//			{
//				if([s isEqualToString:@"ISDR_INAPP_WIFI"])
//				{
//					wifiPurchased = TRUE;
//					break;
//				}
//			}
//
//			if(wifiPurchased)
//			{
//				defaults.wifiFunctionalityPurchased = TRUE;
//				NSNumber* boolnum = [NSNumber numberWithBool:TRUE];
//				[[NSUserDefaults standardUserDefaults] setObject:boolnum forKey:kWifiFunctionalityPurchasedKey];
//				[[NSUserDefaults standardUserDefaults] synchronize];
//				SDR_DEBUGPRINT(("Purchase confirmed from list of purchased items.\n"));
//			}
//			else
//			{
//				NSLog(@"Purchase was not found in list of purchased items.");
//			}
//		}
//	}
//
//	if(wifiPurchased && enable)
//	{
//		[self wifiPurchaseCompleted];
//	}
//
//	SDR_DEBUGPRINT(("Wi-Fi Feature has %s purchased\n", wifiPurchased ? "been":"not been"));
//
//	return wifiPurchased;
//}


//- (void)wifiPurchaseCompleted
//{
//	// Set default settings appropriately
//	defaults.wifiFunctionalityPurchased = TRUE;
//	NSNumber* truenum = [NSNumber numberWithBool:TRUE];
//	[[NSUserDefaults standardUserDefaults] setObject:truenum forKey:kWifiFunctionalityPurchasedKey];
//
//	defaults.wifiFunctionalityEnabled = TRUE;
//	[[NSUserDefaults standardUserDefaults] setObject:truenum forKey:kWifiFunctionalityEnabledKey];
//
//	[[NSUserDefaults standardUserDefaults] synchronize];
//
//	// Configure iSDR to use wifi
//	[eaglViewController configureForWifi];
//}


//- (void)wifiPurchaseRemovalAllPersistence
//{
//	[_persistence removeTransactions];
//	defaults.wifiFunctionalityPurchased = TRUE;
//	defaults.wifiFunctionalityEnabled = FALSE;
//	NSNumber* boolnum = [NSNumber numberWithBool:FALSE];
//	[[NSUserDefaults standardUserDefaults] setObject:boolnum forKey:kWifiFunctionalityEnabledKey];
//	[[NSUserDefaults standardUserDefaults] setObject:boolnum forKey:kWifiFunctionalityPurchasedKey];
//	[[NSUserDefaults standardUserDefaults] synchronize];
//}

/***********************************************************************************************************************
 Hardware Detection
 ***********************************************************************************************************************/

- (BOOL)isGyroscopeAvailable
{
    CMMotionManager *motionManager = [CMMotionManager new];
    BOOL gyroAvailable = motionManager.gyroAvailable;
    return gyroAvailable;
}


+ (BOOL)isRetinaDisplay
{
    int scale = 1.0;
    UIScreen *screen = [UIScreen mainScreen];
    if([screen respondsToSelector:@selector(scale)])
        scale = screen.scale;

    if(scale > 1.9f) return YES; // guard against roundoff, and scales > 2

    return NO;
}


+ (NSString*)getAppName
{
    if(appName == nil)
    {
        appName = [[NSString alloc] initWithString:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]];
    }

    return appName;
}


// This gets called upon return from background, and probably various other scenarios, but does not seem to get called on initial app launch.
- (void)applicationWillEnterForeground:(UIApplication *)application
{
    SDR_DEBUGPRINT(("applicationWillEnterForeground:...\n"));
    ///////////////////////////////////////////////////////////////////////////////////////////
    // Wifi support changes
    [iSDRAppDelegate registerForNetworkReachabilityNotifications];
    // Wifi support changes
    ///////////////////////////////////////////////////////////////////////////////////////////
    [[NSUserDefaults standardUserDefaults] synchronize]; // make sure pending setting changes are written
    [self readDefaultsFromFileSystem];
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
    SDR_DEBUGPRINT(("applicationDidEnterBackground:...\n"));
    ///////////////////////////////////////////////////////////////////////////////////////////
    // Wifi support changes
    [iSDRAppDelegate unsubscribeFromNetworkReachabilityNotifications];
    // Wifi support changes
    ///////////////////////////////////////////////////////////////////////////////////////////
    [self writeDefaultsToFileSystem];

    portSettingsWereModified = FALSE;
    SDR_DEBUGPRINT(("Application will monitor default settings changes while in background.\n"));
    // listen for changes to our preferences when the Settings app does so,
    // when we are resumed from the backround, this will give us a chance to update our UI
    //
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
    holdDefaults = defaults;

    if(holdIPAddress == nil)
    {
        self.holdIPAddress = [NSMutableString new];
    }
    else
    {
        [holdIPAddress setString:@""];
    }

    NSString* s = self.ipAddress;
    if(s)
    {
        [holdIPAddress setString:s];
    }

    if(holdCommandPort == nil)
    {
        self.holdCommandPort = [NSMutableString new];
    }
    else
    {
        [holdCommandPort setString:@""];
    }

    s = self.commandPort;
    if(s)
    {
        [holdCommandPort setString:s];
    }


    if(holdDataPort == nil)
    {
        self.holdDataPort = [NSMutableString new];
    }
    else
    {
        [holdDataPort setString:@""];
    }

    s = self.dataPort;
    if(s)
    {
        [holdDataPort setString:s];
    }
}


/*
 Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions
 (such as an incoming phone call or SMS message, or the control panel is accessed) or when the user quits the application and it begins the transition to the background state.
 Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
 */
- (void)applicationWillResignActive:(UIApplication *)application
{
    SDR_DEBUGPRINT(("applicationWillResignActive:...\n"));
    [eaglViewController prepareForBackground];
}


/*
 This gets called when the app returns after a low battery alert is dismissed by the user - as well as on initial app launch, when the app returns from background, and probably various other scenarios. Most importantly this gets called after the control panel is dismissed, and needs to handle undoing applicationWillResignActive actions.
 */
- (void)applicationDidBecomeActive:(UIApplication *)application
{
    SDR_DEBUGPRINT(("applicationDidBecomeActive:...\n"));
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
    [eaglViewController returnFromBackground];
}


// We are being notified that our preferences have changed. This gets called if the app is running in the background and the user
// modifies the settings in the native Settings app. Here we could attempt to update audio configuration settings.
//
- (void)defaultsChanged:(NSNotification *)notif
{
    static std::atomic_flag accessSemaphore = ATOMIC_FLAG_INIT;

    // Prevent a defaults write in this method from cascading into a nested update.
    if(!accessSemaphore.test_and_set(std::memory_order_acquire))
    {
        [self readDefaultsFromFileSystem];
        SDR_DEBUGPRINT(("defaultsChanged: new settings were read\n"));

        ///////////////////////////////////////////////////////////////////////////////////////////
        // Wifi support changes
        if(![holdIPAddress isEqualToString:self.ipAddress])
        {
            SDR_DEBUGPRINT(("IP address changed!\n"));
            [[NSUserDefaults standardUserDefaults] setObject:self.ipAddress forKey:kiSDRIPAddressKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        if(![holdCommandPort isEqualToString:self.commandPort])
        {
            SDR_DEBUGPRINT(("Command port changed!\n"));
            [[NSUserDefaults standardUserDefaults] setObject:self.commandPort forKey:kiSDRCommandPortKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            portSettingsWereModified = TRUE;
        }

        if(![holdDataPort isEqualToString:self.dataPort])
        {
            SDR_DEBUGPRINT(("Data port changed!\n"));
            [[NSUserDefaults standardUserDefaults] setObject:self.dataPort forKey:kiSDRDataPortKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            portSettingsWereModified = TRUE;
        }
        // Wifi support changes
        ///////////////////////////////////////////////////////////////////////////////////////////

        [[NSUserDefaults standardUserDefaults] synchronize];
        accessSemaphore.clear(std::memory_order_release);
    }
}


- (void)readDefaultsFromFileSystem
{
    SDR_DEBUGPRINT(("\nReading settings from file system...\n"));

    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

    // Read default settings for device
    DefaultSettingsType restoredSettings;

    restoredSettings.soundEffectsEnabled = (BOOL)[userDefaults boolForKey:kSoundEffectsSettingKey];
    restoredSettings.centerFrequency = (frequencyType)[[userDefaults stringForKey:kiSDRCenterFrequencyKey] doubleValue];
    restoredSettings.demoModeOnly = (BOOL)[userDefaults boolForKey:kiSDRdemoModeOnlyKey];
    restoredSettings.reverseIQ = (BOOL)[userDefaults boolForKey:kiSDRreverseIQKey];
    restoredSettings.operatingMode = (iSDROperatingMode)[userDefaults integerForKey:kiSDRoperatingModeKey];
    restoredSettings.bpfBandwidth = (frequencyType)[userDefaults floatForKey:kiSDRbpfBandwidthKey];
    restoredSettings.rxOffset = (frequencyType)[[userDefaults stringForKey:kiSDRbpfRxOffsetKey] doubleValue];
    restoredSettings.agcSetting = (AGCSetting)[userDefaults integerForKey:kiSDRagcSettingKey];
    restoredSettings.gridBrightness = (float)[userDefaults floatForKey:kGridBrightnessKey];
    restoredSettings.simpleTouchMode = (BOOL)[userDefaults boolForKey:kSimpleTouchEnabledKey];
    restoredSettings.gridType = (GridType)[userDefaults integerForKey:kSpectrumGridTypeKey];
    restoredSettings.signalScaleFactor = (float)[userDefaults floatForKey:kSignalDisplayScaleFactorKey];
    ///////////////////////////////////////////////////////////////////////////////////////////
    // Wifi support changes
    restoredSettings.hasSuccessfullyConnectedViaWifi = (BOOL)[userDefaults boolForKey:kHasSuccessfullyConnectedKey];
    restoredSettings.reversePlusMinus = (BOOL)[userDefaults boolForKey:kPlusMinusOrientationKey];
    // Wifi support changes
    ///////////////////////////////////////////////////////////////////////////////////////////
    restoredSettings.playWhileMinimized = (BOOL)[userDefaults boolForKey:kPlayWhileMinimizedKey];
    restoredSettings.signalScaleFactor = CLAMP(0., restoredSettings.signalScaleFactor, 1.);
    restoredSettings.centerFrequency = CLAMP(MIN_CENTER_FREQUENCY, restoredSettings.centerFrequency, MAX_CENTER_FREQUENCY);
    restoredSettings.rxOffset = CLAMP(MIN_RX_OFFSET, restoredSettings.rxOffset, MAX_RX_OFFSET);
    restoredSettings.gridBrightness = CLAMP(0., restoredSettings.gridBrightness, 1.);
    restoredSettings.hasShownIntroductionText = (BOOL)[userDefaults boolForKey:kIntroMessageShownKey];
    restoredSettings.wifiFunctionalityPurchased = TRUE;

    //	if(!restoredSettings.wifiFunctionalityPurchased)
    //	{
    //		restoredSettings.wifiFunctionalityEnabled = FALSE;
    //	}
    //	else
    //	{
    restoredSettings.wifiFunctionalityEnabled = (BOOL)[userDefaults boolForKey:kWifiFunctionalityEnabledKey];
    //	}

    defaults = restoredSettings;

#ifdef SDR_DEBUG
    SDR_DEBUGPRINT(("\nApplication Defaults:\n"));
    [self printDefaults:defaults];
#endif

    return;
}

- (void)writeDefaultsToFileSystem
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

#ifdef SDR_DEBUG
    NSString* test = [userDefaults stringForKey:kiSDRVersionKey];
#endif
    NSString* versionInfoString = [NSString stringWithFormat:@"%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];

    SDR_DEBUGPRINT(("Test = %s\n", [test UTF8String]));

    //	if(![test isEqualToString:versionInfoString])
    //	{
    //		[iSDRAppDelegate initialize];
    //		SDR_DEBUGPRINT(("Corrupt settings detected. Resetting all default values!\n"));
    //	}
    //	else
    {
#ifdef SDR_DEBUG
        SDR_DEBUGPRINT(("\nNon-volatilely storing Application Defaults (v. %s):\n", [versionInfoString UTF8String]));
        [self printDefaults:defaults];
#endif

        NSString* str = [NSString stringWithFormat:@"%.0lf", defaults.centerFrequency];
        [userDefaults setObject:str forKey:kiSDRCenterFrequencyKey];

        NSNumber* boolnum = [NSNumber numberWithBool:defaults.demoModeOnly];
        [userDefaults setObject:boolnum forKey:kiSDRdemoModeOnlyKey];

        boolnum = [NSNumber numberWithBool:defaults.reverseIQ];
        [userDefaults setObject:boolnum forKey:kiSDRreverseIQKey];

        NSNumber* intvalue = [NSNumber numberWithInt:(int)defaults.operatingMode];
        [userDefaults setObject:intvalue forKey:kiSDRoperatingModeKey];

        NSNumber* floatnum = [NSNumber numberWithFloat:defaults.bpfBandwidth];
        [userDefaults setObject:floatnum forKey:kiSDRbpfBandwidthKey];

        str = [NSString stringWithFormat:@"%.0lf", defaults.rxOffset];
        [userDefaults setObject:str forKey:kiSDRbpfRxOffsetKey];

        intvalue = [NSNumber numberWithInt:(int)defaults.agcSetting];
        [userDefaults setObject:intvalue forKey:kiSDRagcSettingKey];


        boolnum = [NSNumber numberWithBool:defaults.simpleTouchMode];
        [userDefaults setObject:boolnum forKey:kSimpleTouchEnabledKey];

        boolnum = [NSNumber numberWithBool:defaults.soundEffectsEnabled];
        [userDefaults setObject:boolnum forKey:kSoundEffectsSettingKey];

        intvalue = [NSNumber numberWithInt:(int)defaults.gridType];
        [userDefaults setObject:intvalue forKey:kSpectrumGridTypeKey];

        floatnum = [NSNumber numberWithFloat:(float)defaults.gridBrightness];
        [userDefaults setObject:floatnum forKey:kGridBrightnessKey];

        floatnum = [NSNumber numberWithFloat:(float)defaults.signalScaleFactor];
        [userDefaults setObject:floatnum forKey:kSignalDisplayScaleFactorKey];

        boolnum = [NSNumber numberWithBool:defaults.playWhileMinimized];
        [userDefaults setObject:boolnum forKey:kPlayWhileMinimizedKey];

        boolnum = [NSNumber numberWithBool:defaults.wifiFunctionalityEnabled];
        [userDefaults setObject:boolnum forKey:kWifiFunctionalityEnabledKey];

        boolnum = [NSNumber numberWithBool:defaults.wifiFunctionalityPurchased];
        [userDefaults setObject:boolnum forKey:kWifiFunctionalityPurchasedKey];

        boolnum = [NSNumber numberWithBool:TRUE]; // We will always mark this TRUE after the first time the app is run
        [userDefaults setObject:boolnum forKey:kIntroMessageShownKey];

        [userDefaults setObject:[NSNumber numberWithBool:TRUE] forKey:kNewInstallKey]; // Always gets set to one to indicate the app has been run

        ///////////////////////////////////////////////////////////////////////////////////////////
        // Wifi support changes
        // It seems strange to me, but we must write back every user default value (or none), otherwise
        // unwritten values will be unreadable the next time the app launches
        str = [self getIPAddress];
        [userDefaults setObject:str forKey:kiSDRIPAddressKey];

        str = [self getSuccessfulIPAddress];
        [userDefaults setObject:str forKey:kSuccessfulIPAddressKey];

        str = [self getCommandPort];
        [userDefaults setObject:str forKey:kiSDRCommandPortKey];

        str = [self getDataPort];
        [userDefaults setObject:str forKey:kiSDRDataPortKey];

        boolnum = [NSNumber numberWithBool:defaults.hasSuccessfullyConnectedViaWifi];
        [userDefaults setObject:boolnum forKey:kHasSuccessfullyConnectedKey];

        boolnum = [NSNumber numberWithBool:defaults.reversePlusMinus];
        [userDefaults setObject:boolnum forKey:kPlusMinusOrientationKey];
        // Wifi support changes
        ///////////////////////////////////////////////////////////////////////////////////////////

        [userDefaults setObject:versionInfoString forKey:kiSDRVersionKey];

        if([userDefaults synchronize])
        {
            SDR_DEBUGPRINT(("Stored user settings successfully.\n"));
        }
        else
        {
            SDR_DEBUGPRINT(("Defaults failed to write!!\n"));
        }
    }
}


// +initialize is invoked before the class receives any other messages, so it
// is a good place to set up application defaults
+ (void)initialize
{
    SDR_DEBUGPRINT(("\n+(void)initialize...\n"));

#if USE_MINIMAL_PURCHASE_RETENTION
    BOOL firstInstall = !(BOOL)[[NSUserDefaults standardUserDefaults] boolForKey:kNewInstallKey];

    if(firstInstall)
    {
        SDR_DEBUGPRINT(("First time to run after install!\n"));
        removePurchasesPersistence = TRUE; // force renewal if app is ever re-installed
    }
#endif // USE_MINIMAL_PURCHASE_RETENTION

    // Keep track of changes to the device orientation so we can update the video processor
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(deviceOrientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

    NSString* test = [[NSUserDefaults standardUserDefaults] stringForKey:kiSDRVersionKey];
    NSString* versionInfoString = [NSString stringWithFormat:@"%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];

    SDR_DEBUGPRINT(("Version test: %s == %s?\n", [test cStringUsingEncoding:NSUTF8StringEncoding],[versionInfoString cStringUsingEncoding:NSUTF8StringEncoding]));
    NSLog(@"app dir: %@",[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject]); // will print the full path to data folder

    if((test == nil) || ![test isEqualToString:versionInfoString])
    {
        // no default values have been set, create them here based on what's in our Settings bundle info
        //
        if([self class] == [iSDRAppDelegate class])
        {
            // no default values have been set, create them here based on what's in our Settings bundle info
            //
            NSString *pathStr = [[NSBundle mainBundle] bundlePath];
            NSString *settingsBundlePath = [pathStr stringByAppendingPathComponent:@"Settings.bundle"];
            NSString *finalPath = [settingsBundlePath stringByAppendingPathComponent:@"Root.plist"];

            NSDictionary *settingsDict = [NSDictionary dictionaryWithContentsOfFile:finalPath];
            NSArray *prefSpecifierArray = [settingsDict objectForKey:@"PreferenceSpecifiers"];

            NSString*	centerFrequencyDefault = nil;
            NSNumber*	demoModeOnlyDefault = nil;
            NSNumber*	reverseIQDefault = nil;
            NSNumber*	operatingModeDefault = nil;
            NSNumber*	bpfBandwidthDefault = nil;
            NSString*	bpfRXOffsetDefault = nil;
            NSNumber*	agcSettingDefault = nil;
            NSNumber*	simpleTouchEnabledDefault = nil;
            NSNumber*	soundEffectsEnabledDefault = nil;
            NSNumber*	spectrumGridTypeDefault = nil;
            NSNumber*	gridBrightnessDefault = nil;
            NSNumber*	signalScaleFactorDefault = nil;
            NSNumber*	playWhileMinimizedDefault = nil;
            NSNumber*	wifiFunctionality = nil;
            NSNumber*	wifiPurchased = nil;
            NSNumber*	hasBeenRun = nil;
            ///////////////////////////////////////////////////////////////////////////////////////////
            // Wifi support changes
            NSString*   IPAddressDefault   = nil;
            NSString*	IPAddressSuccessful = nil;
            NSString*   CommandPortDefault = nil;
            NSString*   DataPortDefault    = nil;
            NSNumber*	successfulConnection = nil;
            NSNumber*	reversePlusMinus = nil;
            // Wifi support changes
            ///////////////////////////////////////////////////////////////////////////////////////////

            NSDictionary *prefItem;
            for (prefItem in prefSpecifierArray)
            {
                NSString *keyValueStr = [prefItem objectForKey:@"Key"];
                id defaultValue = [prefItem objectForKey:@"DefaultValue"];

                if(keyValueStr && defaultValue)
                {
                    if([keyValueStr isEqualToString:kiSDRCenterFrequencyKey])
                    {
                        centerFrequencyDefault   = [NSString stringWithString:[(NSNumber*)defaultValue stringValue]];
                        SDR_DEBUGPRINT(("Center Freq Default = %s\n",[centerFrequencyDefault UTF8String]));
                    }
                    else if([keyValueStr isEqualToString:kiSDRdemoModeOnlyKey])
                    {
                        demoModeOnlyDefault = defaultValue;
                    }
                    else if([keyValueStr isEqualToString:kiSDRreverseIQKey])
                    {
                        reverseIQDefault = [NSNumber numberWithBool:[defaultValue boolValue]];
                    }
                    else if([keyValueStr isEqualToString:kiSDRoperatingModeKey])
                    {
                        operatingModeDefault = defaultValue;
                    }
                    else if([keyValueStr isEqualToString:kiSDRbpfBandwidthKey])
                    {
                        SDR_DEBUGPRINT(("BPF Bandwidth Default = %0.2f\n",[defaultValue floatValue]));
                        bpfBandwidthDefault = [NSNumber numberWithFloat:[defaultValue floatValue]];
                    }
                    else if([keyValueStr isEqualToString:kiSDRbpfRxOffsetKey])
                    {
                        bpfRXOffsetDefault =  [NSString stringWithString:(NSString*)defaultValue];
                        SDR_DEBUGPRINT(("CW Offset Default = %s\n",[bpfRXOffsetDefault UTF8String]));
                    }
                    else if([keyValueStr isEqualToString:kiSDRagcSettingKey])
                    {
                        agcSettingDefault = defaultValue;
                        SDR_DEBUGPRINT(("kiSDRagcSettingKey\n"));
                    }
                    else if([keyValueStr isEqualToString:kSimpleTouchEnabledKey])
                    {
                        simpleTouchEnabledDefault = [NSNumber numberWithBool:[defaultValue boolValue]];
                        SDR_DEBUGPRINT(("kSimpleTouchEnabledKey\n"));
                    }
                    else if([keyValueStr isEqualToString:kSoundEffectsSettingKey])
                    {
                        soundEffectsEnabledDefault = [NSNumber numberWithBool:[defaultValue boolValue]];
                        SDR_DEBUGPRINT(("kSoundEffectsSettingKey\n"));
                    }
                    else if([keyValueStr isEqualToString:kSpectrumGridTypeKey])
                    {
                        spectrumGridTypeDefault = defaultValue;
                        SDR_DEBUGPRINT(("kSpectrumGridTypeKey\n"));
                    }
                    else if([keyValueStr isEqualToString:kGridBrightnessKey])
                    {
                        SDR_DEBUGPRINT(("Grid Brightness Default = %0.2f\n",[defaultValue floatValue]));
                        gridBrightnessDefault = [NSNumber numberWithFloat:[defaultValue floatValue]];
                    }
                    else if([keyValueStr isEqualToString:kSignalDisplayScaleFactorKey])
                    {
                        signalScaleFactorDefault = [NSNumber numberWithFloat:[defaultValue floatValue]];
                        SDR_DEBUGPRINT(("Display Scale Factor: %f\n",[defaultValue floatValue]));
                    }
                    else if([keyValueStr isEqualToString:kPlayWhileMinimizedKey])
                    {
                        playWhileMinimizedDefault = [NSNumber numberWithBool:[defaultValue boolValue]];
                        SDR_DEBUGPRINT(("Play in bkgnd: %s\n",[defaultValue boolValue] ? "Yes":"No"));
                    }
                    else if([keyValueStr isEqualToString:kWifiFunctionalityEnabledKey])
                    {
                        wifiFunctionality = [NSNumber numberWithBool:[defaultValue boolValue]];
                        SDR_DEBUGPRINT(("Wifi functionality: %s\n",[defaultValue boolValue] ? "Yes":"No"));
                    }
                    else if([keyValueStr isEqualToString:kWifiFunctionalityPurchasedKey])
                    {
                        wifiPurchased = [NSNumber numberWithBool:[defaultValue boolValue]];
                        SDR_DEBUGPRINT(("Wifi purchased: %s\n", [defaultValue boolValue] ? "Yes":"No"));
                    }
                    else if([keyValueStr isEqualToString:kNewInstallKey])
                    {
                        hasBeenRun = [NSNumber numberWithBool:TRUE];
                        SDR_DEBUGPRINT(("Has been run: %s\n",[defaultValue boolValue] ? "Yes":"No"));
                    }

                    ///////////////////////////////////////////////////////////////////////////////////////////
                    // Wifi support changes
                    else if([keyValueStr isEqualToString:kiSDRIPAddressKey])
                    {
                        IPAddressDefault   = [NSString stringWithString:(NSString*)defaultValue];
                        SDR_DEBUGPRINT(("IP address used to initialize: %s\n", [IPAddressDefault UTF8String]));
                    }
                    else if([keyValueStr isEqualToString:kSuccessfulIPAddressKey])
                    {
                        IPAddressSuccessful = [NSString stringWithString:(NSString*)defaultValue];
                        SDR_DEBUGPRINT(("Last connected with: %s\n", [IPAddressSuccessful UTF8String]));
                    }
                    else if([keyValueStr isEqualToString:kiSDRCommandPortKey])
                    {
                        CommandPortDefault = [NSString stringWithString:(NSString*)defaultValue];
                        SDR_DEBUGPRINT(("From initialize: %s\n", [CommandPortDefault UTF8String]));
                    }
                    else if([keyValueStr isEqualToString:kiSDRDataPortKey])
                    {
                        DataPortDefault = [NSString stringWithString:(NSString*)defaultValue];
                        SDR_DEBUGPRINT(("From initialize: %s\n", [DataPortDefault UTF8String]));
                    }
                    else if([keyValueStr isEqualToString:kHasSuccessfullyConnectedKey])
                    {
                        successfulConnection = [NSNumber numberWithBool:[defaultValue boolValue]];
                        SDR_DEBUGPRINT(("Has Successfully Connected\n"));
                    }
                    else if([keyValueStr isEqualToString:kPlusMinusOrientationKey])
                    {
                        reversePlusMinus = [NSNumber numberWithBool:[defaultValue boolValue]];
                        SDR_DEBUGPRINT(("PlusMinusOrientationKey\n"));
                    }
                    // Wifi support changes
                    ///////////////////////////////////////////////////////////////////////////////////////////

                    else if([keyValueStr isEqualToString:kiSDRVersionKey])
                    {
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kiSDRVersionKey];
                        //[[NSUserDefaults standardUserDefaults] setObject:versionInfoString forKey:kiSDRVersionKey];
                        SDR_DEBUGPRINT(("kiSDRVersionKey\n"));
                    }
                }
            }

            // since no default values have been set (i.e. no preferences file created), create it here
            NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                         centerFrequencyDefault, kiSDRCenterFrequencyKey,
                                         demoModeOnlyDefault, kiSDRdemoModeOnlyKey,
                                         reverseIQDefault, kiSDRreverseIQKey,
                                         operatingModeDefault, kiSDRoperatingModeKey,
                                         bpfBandwidthDefault, kiSDRbpfBandwidthKey,
                                         bpfRXOffsetDefault, kiSDRbpfRxOffsetKey,
                                         agcSettingDefault, kiSDRagcSettingKey,
                                         simpleTouchEnabledDefault, kSimpleTouchEnabledKey,
                                         soundEffectsEnabledDefault, kSoundEffectsSettingKey,
                                         spectrumGridTypeDefault, kSpectrumGridTypeKey,
                                         gridBrightnessDefault, kGridBrightnessKey,
                                         signalScaleFactorDefault, kSignalDisplayScaleFactorKey,
                                         playWhileMinimizedDefault, kPlayWhileMinimizedKey,
                                         wifiFunctionality, kWifiFunctionalityEnabledKey,
                                         wifiPurchased, kWifiFunctionalityPurchasedKey,
                                         ///////////////////////////////////////////////////////////////////////////////////////////
                                         // Wifi support changes
                                         IPAddressDefault,   kiSDRIPAddressKey,
                                         IPAddressSuccessful, kSuccessfulIPAddressKey,
                                         CommandPortDefault, kiSDRCommandPortKey,
                                         DataPortDefault,    kiSDRDataPortKey,
                                         successfulConnection, kHasSuccessfullyConnectedKey,
                                         reversePlusMinus, kPlusMinusOrientationKey,
                                         // Wifi support changes
                                         ///////////////////////////////////////////////////////////////////////////////////////////
                                         versionInfoString, kiSDRVersionKey,
                                         hasBeenRun, kNewInstallKey,
                                         nil];

            [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
            [[NSUserDefaults standardUserDefaults] synchronize];

            SDR_DEBUGPRINT(("Default settings initialization complete!\n"));
        }
    }

    SDR_DEBUGPRINT(("\nExiting initialize...\n"));

    //[(iSDRAppDelegate *)[[UIApplication sharedApplication] delegate] readDefaultsFromFileSystem];
}


// Invoked immediately before the application terminates.
- (void)applicationWillTerminate:(UIApplication *)application
{
    SDR_DEBUGPRINT(("applicationWillTerminate...\n"));

    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [self writeDefaultsToFileSystem];
}


- (DefaultSettingsType)getDefaultSettings
{
#ifdef SDR_DEBUG
    SDR_DEBUGPRINT(("AppDelegate providing following defaults to caller:\n"));
    [self printDefaults:defaults];
#endif

    return defaults;
}


- (void)setDefaultSettings:(DefaultSettingsType)value
{
#ifdef SDR_DEBUG
    SDR_DEBUGPRINT(("AppDelegate received following defaults to save:\n"));
    [self printDefaults:value];
#endif

    defaults = value;

    // Save all settings automatically with each change?
    //[self writeDefaultsToFileSystem];
}

#ifdef SDR_DEBUG
- (void)printDefaults:(DefaultSettingsType)value
{
    SDR_DEBUGPRINT(("Center frequency: %4.3lf kHz\n", value.centerFrequency));
    SDR_DEBUGPRINT(("Demo mode only: %s\n", (value.demoModeOnly) ? "Yes":"No"));
    SDR_DEBUGPRINT(("I/Q reversed: %s\n", (value.reverseIQ) ? "Yes":"No"));
    SDR_DEBUGPRINT(("Operating mode: %d\n", value.operatingMode));
    SDR_DEBUGPRINT(("BPF bandwidth: %4.0f Hz\n", value.bpfBandwidth));
    SDR_DEBUGPRINT(("RX offset: %3.0f Hz\n", value.rxOffset));
    SDR_DEBUGPRINT(("AGC setting: %d\n", value.agcSetting));
    SDR_DEBUGPRINT(("Touch mode: %s\n", (value.simpleTouchMode) ? "Simple":"Normal"));
    SDR_DEBUGPRINT(("Grid type: %s\n", (value.gridType == Linear) ? "Linear":"Semi-Log"));
    SDR_DEBUGPRINT(("Grid brightness: %0.2f\n", value.gridBrightness));
    SDR_DEBUGPRINT(("Signal display scale factor: %f\n", value.signalScaleFactor));
    SDR_DEBUGPRINT(("Sound effects: %s\n", value.soundEffectsEnabled ? "On":"Off"));
    SDR_DEBUGPRINT(("Play in Background: %s\n", value.playWhileMinimized ? "Yes":"No"));
    SDR_DEBUGPRINT(("Intro has shown: %s\n", value.hasShownIntroductionText ? "Yes":"No"));
    ///////////////////////////////////////////////////////////////////////////////////////////
    // Wifi support changes
    SDR_DEBUGPRINT(("Reverse +/-: %s\n", value.reversePlusMinus ? "Reversed":"Normal"));
    SDR_DEBUGPRINT(("Successful connection: %s\n", value.hasSuccessfullyConnectedViaWifi ? "Yes":"No"));
    SDR_DEBUGPRINT(("Command Port: %s\n", [[[NSUserDefaults standardUserDefaults] stringForKey:kiSDRCommandPortKey] UTF8String]));
    SDR_DEBUGPRINT(("Data Port: %s\n", [[[NSUserDefaults standardUserDefaults] stringForKey:kiSDRDataPortKey] UTF8String]));
    // Wifi support changes
    ///////////////////////////////////////////////////////////////////////////////////////////
    SDR_DEBUGPRINT(("Wi-Fi enabled: %s\n", value.wifiFunctionalityEnabled ? "Yes":"No"));
    SDR_DEBUGPRINT(("Wi-Fi purchased: %s\n", value.wifiFunctionalityPurchased ? "Yes":"No"));
    SDR_DEBUGPRINT(("\n"));
}
#endif

- (void)markIntroductoryMessageDisplayed
{
    defaults.hasShownIntroductionText = TRUE;
    [self writeDefaultsToFileSystem];
    //	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:TRUE] forKey:kIntroMessageShownKey];
    SDR_DEBUGPRINT(("Intro Marked Shown\n"));
}


///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
// The following approach for validating IP addresses was taken from Stack Overflow:
// http://stackoverflow.com/questions/1679152/how-to-validate-an-ip-address-with-regular-expression-in-objective-c.
#include <arpa/inet.h>

- (BOOL)isValidIPAddress:(NSString*)address
{
    if(address == nil) return FALSE; // handle this case individually since it will cause a crash
    if([address length] < 1) return FALSE;

    const char *utf8 = [address UTF8String];
    int success;

    struct in_addr dst;
    success = inet_pton(AF_INET, utf8, &dst);

    // Disallow IPV6 addresses for now
    //	if (success != 1) {
    //		struct in6_addr dst6;
    //		success = inet_pton(AF_INET6, utf8, &dst6);
    //	}

    return (success == 1);
}

- (void)setIPAddress:(NSString*)address
{
    if(address == nil) return;
    if(![self isValidIPAddress:address]) return; // prevent invalid IDs from ever being written to defaults

    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:address forKey:kiSDRIPAddressKey];
    WIFI_DEBUGPRINT(("setIPAddress: IPAddress set to %s\n", [address UTF8String]));
}

- (NSString*)getIPAddress
{
    NSString* addr = [[NSUserDefaults standardUserDefaults] stringForKey:kiSDRIPAddressKey];

    WIFI_DEBUGPRINT(("getIPAddress: read from defaults %s\n", [addr UTF8String]));

    if(addr)
    {
        if(![self isValidIPAddress:addr]) addr = nil; // prevent invalid IDs from ever being utilized
    }

    WIFI_DEBUGPRINT(("getIPAddress: returned %s\n", [addr UTF8String]));
    return addr;
}

- (void)setSuccessfulIPAddress:(NSString*)address
{
    if(address == nil)
    {
        address = @"empty";
    }
    else
    {
        if(![self isValidIPAddress:address]) return; // prevent invalid IDs from ever being written to defaults
    }

    [[NSUserDefaults standardUserDefaults] setObject:address forKey:kSuccessfulIPAddressKey];
    WIFI_DEBUGPRINT(("setSuccessfulIPAddress: IPAddress set to %s\n", [address UTF8String]));
}

- (NSString*)getSuccessfulIPAddress
{
    NSString* addr = [[NSUserDefaults standardUserDefaults] stringForKey:kSuccessfulIPAddressKey];

    WIFI_DEBUGPRINT(("getIPAddress: read from defaults %s\n", [addr UTF8String]));

    if(addr)
    {
        if(![self isValidIPAddress:addr]) addr = nil; // prevent invalid IDs from ever being utilized
    }

    WIFI_DEBUGPRINT(("getSuccessfulIPAddress: returned %s\n", [addr UTF8String]));
    return addr;
}

- (void)setCommandPort:(NSString*)port
{
    if(port == nil) return;
    if([port length] < 1) return;

    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

    if(portValidationInProgress)
    {
        [userDefaults setObject:port forKey:kiSDRCommandPortKey];
    }
    else
    {
        NSUInteger setting = [port integerValue];
        if(setting > MAX_PORT_VALUE)
        {
            setting = DEFAULT_COMMAND_PORT;
            portSettingsWereModified = TRUE;
        }

        port = [NSString stringWithFormat:@"%lu", (unsigned long)setting];

        [userDefaults setObject:port forKey:kiSDRCommandPortKey];
        WIFI_DEBUGPRINT(("setCommandPort: port set to %s\n", [port UTF8String]));

        // Prevent the ports from ever being equal
        portValidationInProgress = TRUE; // prevent infinite loop of port changes!
        NSString* dataPort = [self getDataPort];
        if([port isEqualToString:dataPort])
        {
            setting = (setting + 1) % (MAX_PORT_VALUE + 1);
            [self setDataPort:[NSString stringWithFormat:@"%lu", (unsigned long)setting]];
            portSettingsWereModified = TRUE;
        }
        portValidationInProgress = FALSE;
    }
}

- (NSString*)getCommandPort
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSString* port = [userDefaults stringForKey:kiSDRCommandPortKey];

    if(portValidationInProgress)
    {
        return port; // don't run any validity checks
    }

    NSUInteger setting = [port integerValue];
    if(setting > MAX_PORT_VALUE)
    {
        setting = DEFAULT_COMMAND_PORT;
        portSettingsWereModified = TRUE;
    }

    port = [NSString stringWithFormat:@"%lu", (unsigned long)setting];

    WIFI_DEBUGPRINT(("getCommandPort: returned %s\n", [port UTF8String]));

    // Prevent the ports from ever being equal
    portValidationInProgress = TRUE; // prevent infinite loop of port changes!
    NSString* dataPort = [self getDataPort];
    if([port isEqualToString:dataPort])
    {
        setting = (setting + 1) % (MAX_PORT_VALUE + 1);
        [self setDataPort:[NSString stringWithFormat:@"%lu", (unsigned long)setting]];
        portSettingsWereModified = TRUE;
    }
    portValidationInProgress = FALSE;

    return port;
}

- (void)setDataPort:(NSString*)port
{
    if(port == nil) return;
    if([port length] < 1) return;

    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

    if(portValidationInProgress)
    {
        [userDefaults setObject:port forKey:kiSDRDataPortKey];
    }
    else
    {
        NSUInteger setting = [port integerValue];
        if(setting > MAX_PORT_VALUE)
        {
            setting = DEFAULT_DATA_PORT;
            portSettingsWereModified = TRUE;
        }
        port = [NSString stringWithFormat:@"%lu", (unsigned long)setting];

        [userDefaults setObject:port forKey:kiSDRDataPortKey];
        WIFI_DEBUGPRINT(("setDataPort: dataPort set to %s\n", [port UTF8String]));

        // Prevent the ports from ever being equal
        portValidationInProgress = TRUE; // prevent infinite loop of port changes!
        NSString* commandPort = [self getCommandPort];
        if([port isEqualToString:commandPort])
        {
            setting = (setting + 1) % (MAX_PORT_VALUE + 1);
            [self setCommandPort:[NSString stringWithFormat:@"%lu", (unsigned long)setting]];
            portSettingsWereModified = TRUE;
        }
        portValidationInProgress = FALSE;
    }
}

- (NSString*)getDataPort
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSString* port = [userDefaults stringForKey:kiSDRDataPortKey];

    if(portValidationInProgress)
    {
        return port; // don't run any validity checks
    }

    NSUInteger setting = [port integerValue];
    if(setting > MAX_PORT_VALUE)
    {
        setting = DEFAULT_DATA_PORT;
        portSettingsWereModified = TRUE;
    }

    port = [NSString stringWithFormat:@"%lu", (unsigned long)setting];

    WIFI_DEBUGPRINT(("getDataPort: returned %s\n", [port UTF8String]));

    // Prevent the ports from ever being equal
    portValidationInProgress = TRUE; // prevent infinite loop of port changes!
    NSString* commandPort = [self getCommandPort];
    if([port isEqualToString:commandPort])
    {
        setting = (setting + 1) % (MAX_PORT_VALUE + 1);
        [self setCommandPort:[NSString stringWithFormat:@"%lu", (unsigned long)setting]];
        portSettingsWereModified = TRUE;
    }
    portValidationInProgress = FALSE;

    return port;
}

#pragma mark reachability

+ (void)registerForNetworkReachabilityNotifications
{
    [[Reachability reachabilityForInternetConnection] startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
}


+ (void)unsubscribeFromNetworkReachabilityNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
}

+ (BOOL)wifiIsEnabled
{
    BOOL result = ([[Reachability reachabilityForLocalWiFi] currentReachabilityStatus] == ReachableViaWiFi);

#ifdef WIFI_DEBUG
    if(result)
    {
        WIFI_DEBUGPRINT(("Wifi is enabled!\n"));
    }
    else
    {
        WIFI_DEBUGPRINT(("Wifi is disabled!\n"));
    }
#endif

    return result;
}

+ (BOOL)isNetworkReachableViaWWAN
{
    return ([[Reachability reachabilityForInternetConnection] currentReachabilityStatus] == ReachableViaWWAN);
}

+ (void)reachabilityChanged:(NSNotification *)note
{
    WIFI_DEBUGPRINT(("reachabilityChanged: received reachability notification\n"));
    WifiInterface* wifi = [WifiInterface sharedInstance];
    wifi.wifiIsAvailable = ([[Reachability reachabilityForLocalWiFi] currentReachabilityStatus] == ReachableViaWiFi);
}
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////


// Note: currently this only handles one possible format: "yyyy-MM-ddTHH:mm:ssZ"
// TODO: Add "YYYY-MM-DDThh:mm:sszzzzzz" - can that be done based solely on string length?
// Will these automatically handle lower-resolution times? e.g., "yyyy-MM-dd" ??
+ (NSTimeInterval)getDateSince1970:(NSString*)dateString
{
    // Convert the RFC 3339 date time string to an NSDate.
    NSTimeInterval				timeInterval = 0;
    static NSDateFormatter*     sRFC3339DateFormatter;
    NSDate*                     date;

    if(sRFC3339DateFormatter == nil)
    {
        NSLocale* enUSPOSIXLocale;
        sRFC3339DateFormatter = [NSDateFormatter new];
        enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [sRFC3339DateFormatter setLocale:enUSPOSIXLocale];
        [sRFC3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
        [sRFC3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    }

    date = [sRFC3339DateFormatter dateFromString:dateString];

    if(date != nil)
    {
        timeInterval = [date timeIntervalSince1970];
    }

    return  timeInterval;
}

@end
