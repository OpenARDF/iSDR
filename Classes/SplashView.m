/*
 File: SplashView.m
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


#import "SplashView.h"
#import "product.h"
#import <UIKit/UIDevice.h>
#import <AvailabilityInternal.h>
#import "iSDRAppDelegate.h"

@implementation SplashView

@synthesize delegate;
@synthesize image;
@synthesize delay;
@synthesize touchAllowed;
@synthesize animation;
@synthesize isFinishing;
@synthesize animationDelay;
@synthesize manualDismiss;
@synthesize imageRotation;
@synthesize animSplash;
@synthesize textMessageOverlayCenter;
@synthesize textMessageOverlayTransform;

- (id)initWithImage:(UIImage *)screenImage
{
	if(![NSThread isMainThread])
	{
		NSLog(@"Error: SplashView must always run on main thread!");
		return nil;
	}

	appDelegate = (iSDRAppDelegate *)[[UIApplication sharedApplication] delegate];

	if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		SDR_DEBUGPRINT(("iPad! initWithImage\n"));

        CGRect frame = UIScreen.mainScreen.bounds;

		if(self = [super initWithFrame:frame])
		{
			self.image = screenImage;
			self.delay = 2;
			self.touchAllowed = NO;
			self.animation = SplashViewAnimationNone;
			self.animationDelay = 3;
			self.isFinishing = NO;
			self.manualDismiss = NO;
			self.animSplash = nil;
			self.imageRotation = Rotate0;
		}
	}
	else
	{
		if(self = [super initWithFrame:UIScreen.mainScreen.bounds])
		{
			self.image = screenImage;
			self.delay = 2;
			self.touchAllowed = NO;
			self.animation = SplashViewAnimationNone;
			self.animationDelay = 3;
			self.isFinishing = NO;
			self.manualDismiss = NO;
			self.animSplash = nil;
			self.imageRotation = Rotate0;
		}
	}

	return self;
}


- (void)manualSplash:(UIInterfaceOrientation)interfaceOrientation showActivity:(BOOL)showIndicator
{
	if(![NSThread isMainThread])
	{
		NSLog(@"Error: SplashView must always run on main thread!");
		return;
	}

	SDR_DEBUGPRINT(("Manual splash screen started...\n"));

	appDelegate = (iSDRAppDelegate *)[[UIApplication sharedApplication] delegate];

	if(self.animation == SplashViewAnimationSlideLeft)
	{
		self.animSplash = [CABasicAnimation animationWithKeyPath:@"transform"];
		self.animSplash.duration = self.animationDelay;
		self.animSplash.removedOnCompletion = NO;
		self.animSplash.fillMode = kCAFillModeForwards;

		if(appDelegate && [appDelegate respondsToSelector:@selector(getHardware)])
		{
			if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
			{
				// The device is an iPhone or iPod touch
				self.animSplash.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeAffineTransform(CGAffineTransformMakeTranslation(-appDelegate.hardware.portraitHeight, 0))];
			}
		}

		self.animSplash.delegate = (id)self;
	}
	else if(self.animation == SplashViewAnimationFade)
	{
		self.animSplash = [CABasicAnimation animationWithKeyPath:@"opacity"];
		self.animSplash.duration = self.animationDelay;
		self.animSplash.removedOnCompletion = NO;
		self.animSplash.fillMode = kCAFillModeForwards;
		self.animSplash.toValue = [NSNumber numberWithFloat:0];
		self.animSplash.delegate = (id)self;
	}

	splashImage = [[UIImageView alloc] initWithImage:self.image];

	CGFloat midwidth = (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) ? self.image.size.height/2. : self.image.size.width/2.;
	CGFloat midheight = (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) ? self.image.size.width/2. : self.image.size.height/2.;

	splashImage.center = CGPointMake(midwidth, midheight);

	switch(self.imageRotation)
	{
		case Rotate270:
		{
			splashImage.transform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(-PI/2., 0., 0., 1.));
		}
			break;

		case Rotate90:
		{
			splashImage.transform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(PI/2., 0., 0., 1.));
		}
			break;

		case Rotate180:
		{
			splashImage.transform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(PI, 0., 0., 1.));
		}
			break;

		default:
			break;
	}

	[self addSubview:splashImage];

	if(showIndicator)
	{
		activityIndicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
		activityIndicator.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);
		activityIndicator.color = [UIColor blackColor];
		CGPoint indicatorCenter = splashImage.center;

		defaultSettings = [delegate getDefaultSettings];

		if(defaultSettings.displayOrientation == Landscape)
		{
			indicatorCenter.x -= 50;
			activityIndicator.center = indicatorCenter;
			indicatorCenter.x += 50;
			self.textMessageOverlayCenter = indicatorCenter;
			self.textMessageOverlayTransform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(-PI/2., 0., 0., 1.));
		}
		else if(defaultSettings.displayOrientation == LandscapeButtonLeft)
		{
			indicatorCenter.x += 50;
			activityIndicator.center = indicatorCenter;
			indicatorCenter.x -= 50;
			self.textMessageOverlayCenter = indicatorCenter;
			self.textMessageOverlayTransform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(PI/2., 0., 0., 1.));
		}
		else if(defaultSettings.displayOrientation == Portrait)
		{
			indicatorCenter.y -= 50;
			activityIndicator.center = indicatorCenter;
			indicatorCenter.y += 50;
			self.textMessageOverlayCenter = indicatorCenter;
			self.textMessageOverlayTransform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(0., 0., 0., 1.));
		}
		else if(defaultSettings.displayOrientation == PortraitButtonTop)
		{
			indicatorCenter.y += 50;
			activityIndicator.center = indicatorCenter;
			indicatorCenter.y -= 50;
			self.textMessageOverlayCenter = indicatorCenter;
			self.textMessageOverlayTransform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(PI, 0., 0., 1.));
		}
		else
		{
			if(interfaceOrientation == UIInterfaceOrientationPortrait)
			{
				indicatorCenter.y -= 50;
				activityIndicator.center = indicatorCenter;
				indicatorCenter.y += 50;
				self.textMessageOverlayCenter = indicatorCenter;
				self.textMessageOverlayTransform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(0., 0., 0., 1.));
			}
			else if(interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
			{
				indicatorCenter.y += 50;
				activityIndicator.center = indicatorCenter;
				indicatorCenter.y -= 50;
				self.textMessageOverlayCenter = indicatorCenter;
				self.textMessageOverlayTransform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(PI, 0., 0., 1.));
			}
			else if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
			{
				indicatorCenter.x += 50;
				activityIndicator.center = indicatorCenter;
				indicatorCenter.x -= 50;
				self.textMessageOverlayCenter = indicatorCenter;
				self.textMessageOverlayTransform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(PI/2., 0., 0., 1.));
			}
			else
			{
				indicatorCenter.x -= 50;
				activityIndicator.center = indicatorCenter;
				indicatorCenter.x += 50;
				self.textMessageOverlayCenter = indicatorCenter;
				self.textMessageOverlayTransform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(-PI/2., 0., 0., 1.));
			}
		}

		[self addSubview: activityIndicator];
		[activityIndicator startAnimating];
	}
}


- (void)startSplash
{
	if(![NSThread isMainThread])
	{
		NSLog(@"Error: SplashView must always run on main thread!");
		return;
	}

	if(appDelegate == nil)
	{
		appDelegate = (iSDRAppDelegate *)[[UIApplication sharedApplication] delegate];
	}

	if(self.animation == SplashViewAnimationSlideLeft)
	{
		self.animSplash = [CABasicAnimation animationWithKeyPath:@"transform"];
		self.animSplash.duration = self.animationDelay;
		self.animSplash.removedOnCompletion = NO;
		self.animSplash.fillMode = kCAFillModeForwards;

		if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
		{
			// The device is an iPhone or iPod touch.
			self.animSplash.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeAffineTransform(CGAffineTransformMakeTranslation(-appDelegate.hardware.portraitHeight, 0))];
		}

		self.animSplash.delegate = (id)self;
	}
	else if(self.animation == SplashViewAnimationFade)
	{
		self.animSplash = [CABasicAnimation animationWithKeyPath:@"opacity"];
		self.animSplash.duration = self.animationDelay;
		self.animSplash.removedOnCompletion = NO;
		self.animSplash.fillMode = kCAFillModeForwards;
		self.animSplash.toValue = [NSNumber numberWithFloat:0];
		self.animSplash.delegate = (id)self;
	}

	splashImage = [[UIImageView alloc] initWithImage:self.image];

	CGFloat midwidth = self.image.size.width/2.;
	CGFloat midheight = self.image.size.height/2.;

	if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
	{
		CGPoint midpoint = CGPointMake(midwidth, midheight);
		[self convertPoint:midpoint toCoordinateSpace:self.window.screen.fixedCoordinateSpace];
		midwidth = midpoint.y;
		midheight = midpoint.x;
	}

	splashImage.center = CGPointMake(midwidth, midheight);

	switch(self.imageRotation)
	{
		case Rotate270:
		{
			splashImage.transform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(-PI/2., 0., 0., 1.));
		}
			break;

		case Rotate90:
		{
			splashImage.transform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(PI/2., 0., 0., 1.));
		}
			break;

		case Rotate180:
		{
			splashImage.transform = CATransform3DGetAffineTransform(CATransform3DMakeRotation(PI, 0., 0., 1.));
		}
			break;

		default:
			break;
	}

	[self addSubview:splashImage];

	activityIndicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
	activityIndicator.color = [UIColor whiteColor];
	activityIndicator.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);
	activityIndicator.center = self.center;
	[self addSubview:activityIndicator];
	[activityIndicator startAnimating];

	if(!self.manualDismiss)
	{
		[self performSelector:@selector(dismissSplash) withObject:self afterDelay:self.delay];
	}
	else if((self.delegate != nil) && [self.delegate respondsToSelector:@selector(splashIsDone)])
	{
		[delegate splashIsDone];
	}
	else
	{
		[self dismissSplash];
	}

}


- (void)dismissSplash
{
	if(![NSThread isMainThread])
	{
		NSLog(@"Error: SplashView must always run on main thread!");
		return;
	}

	if (self.isFinishing || self.animation == SplashViewAnimationNone)
	{
		[self dismissSplashFinish];
	}
	else if(self.animation == SplashViewAnimationSlideLeft)
	{
		//animSplash = [CABasicAnimation animationWithKeyPath:@"transform"];
		[self.layer addAnimation:self.animSplash forKey:@"animateTransform"];
	}
	else if(self.animation == SplashViewAnimationFade)
	{
		//animSplash = [CABasicAnimation animationWithKeyPath:@"opacity"];
		[self.layer addAnimation:self.animSplash forKey:@"animateOpacity"];
	}

	self.isFinishing = YES;
}


- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag
{
	[self dismissSplashFinish];
}


- (void)dismissSplashFinish
{
	if(activityIndicator)
	{
		[activityIndicator removeFromSuperview];
	}

	//	if(self.animSplash)
	//	{
	//		[self.animSplash release];
	//	}

	if(splashImage)
	{
		[splashImage removeFromSuperview];
		[self removeFromSuperview];
	}

	if(self.delegate != NULL && [self.delegate respondsToSelector:@selector(splashIsDone)])
	{
		[delegate splashIsDone];
	}
}


- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (self.touchAllowed)
	{
		[self dismissSplash];
	}
}


- (BOOL)prefersStatusBarHidden
{
	return TRUE;
}


- (void)dealloc
{
//	[super dealloc];
}


@end
