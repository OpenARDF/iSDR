/*
 File: SplashView.h
 Abstract: present a splash image at startup
 Version: 1.0

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
#import <UIKit/UIKit.h>
#import <UIKit/UIActivityIndicatorView.h>
#import <QuartzCore/QuartzCore.h>

@protocol SplashViewDelegate <NSObject>
- (DefaultSettingsType)getDefaultSettings;
@optional
- (void)splashIsDone;
@end

typedef enum
{
	SplashViewAnimationNone,
	SplashViewAnimationSlideLeft,
	SplashViewAnimationFade,
} SplashViewAnimation;

typedef enum
{
	Rotate0,
	Rotate90,
	Rotate180,
	Rotate270
} OrientationRotateType;

@class iSDRAppDelegate;

@interface SplashView : UIView
{
@private

	id<SplashViewDelegate>		delegate;
	DefaultSettingsType			defaultSettings;
	CABasicAnimation*			animSplash;
	UIImageView*				splashImage;
	UIActivityIndicatorView*	activityIndicator;

	UIImage*					image;
	NSTimeInterval				delay;
	BOOL						touchAllowed;
	SplashViewAnimation			animation;
	NSTimeInterval				animationDelay;
	CGPoint						textMessageOverlayCenter;
	CGAffineTransform			textMessageOverlayTransform;

	BOOL						isFinishing;
	BOOL						manualDismiss;
	OrientationRotateType		imageRotation;
	iSDRAppDelegate*			appDelegate;
}

@property (retain) id<SplashViewDelegate>				delegate;
@property (retain) CABasicAnimation*					animSplash;
//@property (nonatomic, assign) UIImageView*				splashImage;
//@property (nonatomic, assign) UIActivityIndicatorView*	activityIndicator;
@property (retain) UIImage*								image;
@property NSTimeInterval								delay;
@property BOOL											touchAllowed;
@property SplashViewAnimation							animation;
@property NSTimeInterval								animationDelay;
@property BOOL											isFinishing;
@property BOOL											manualDismiss;
@property (nonatomic, assign) CGPoint					textMessageOverlayCenter;
@property (nonatomic, assign) CGAffineTransform			textMessageOverlayTransform;
@property OrientationRotateType							imageRotation;

- (id)initWithImage:(UIImage *)screenImage;
- (void)startSplash;
- (void)dismissSplash;
- (void)manualSplash:(UIInterfaceOrientation)interfaceOrientation showActivity:(BOOL)showIndicator;
- (void)dismissSplashFinish;

@end
