//
//  BigSwitch.m
//  iSDR
//
//  Created by Charles Scharlau on 4/23/14.
//  Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.
//

#import "BigSwitch.h"
#import "product.h"

@interface BigSwitch (PrivateMethods)
@end

@implementation BigSwitch
{
	NSInteger onStateImagesCount;
	NSInteger onState;
}

@synthesize theSwitch;
@synthesize on;
@synthesize onImage;
@synthesize offImage;
@synthesize onStateImagesList;
@synthesize plainToggle;
@synthesize state;

- (id)initWithFrame:(CGRect)frame showIcons:(BOOL)show
{
    self = [super initWithFrame:frame];

    if(self)
	{
		self.userInteractionEnabled = TRUE;
		onState = 0;
		state = SwitchOff;
		plainToggle = TRUE;

		//		self.backgroundColor = [UIColor redColor];

		UISwitch* sw = [[UISwitch alloc] initWithFrame:frame];
		self.theSwitch = sw;

		centeredLocation = CGPointMake(self.frame.size.width/2., self.frame.size.height/2.);
		offsetLocation = centeredLocation;
		theSwitch.center = centeredLocation;

		[self addSubview:theSwitch];

		// Prevent the swith from responding to user touch gestures. Instead the view will
		// handle them and set the switch accordingly.
		theSwitch.userInteractionEnabled = FALSE;

		if(show)
		{
			UIImageView* iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"no_audio_tiny.png"]];
			self.offImage = iv;

			offImage.frame = CGRectMake(0, centeredLocation.y - offImage.frame.size.height/2., offImage.frame.size.width, offImage.frame.size.height);

			[self addSubview:offImage];

			offImageCenteredLocation = offImage.center;
			offImageOffsetLocation = CGPointMake(offImageCenteredLocation.x, offImageCenteredLocation.y);
			offImage.center = plainToggle ? offImageCenteredLocation : offImageOffsetLocation;

			iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"yes_audio_tiny.png"]];
			self.onImage = iv;

			onImage.frame = CGRectMake(self.frame.size.width - onImage.frame.size.width,  centeredLocation.y - onImage.frame.size.height/2., onImage.frame.size.width, onImage.frame.size.height);

			[self addSubview:onImage];

			onImageCenteredLocation = onImage.center;
			onImageOffsetLocation = CGPointMake(onImageCenteredLocation.x, onImageCenteredLocation.y);
			onImage.center = plainToggle ? onImageCenteredLocation : onImageOffsetLocation;
		}
    }

    return self;
}


- (id)initWithFrame:(CGRect)frame images:(NSArray*)imageFilesArray showIcons:(BOOL)show positionOffset:(CGPoint)offset
{
    self = [super initWithFrame:frame];

    if(self)
	{
		self.userInteractionEnabled = TRUE;
		onState = 0;
		state = SwitchOff;
		plainToggle = !(imageFilesArray && [imageFilesArray count]);

		//		self.backgroundColor = [UIColor redColor];

		UISwitch* sw = [[UISwitch alloc] initWithFrame:frame];
		self.theSwitch = sw;

		centeredLocation = CGPointMake(self.frame.size.width/2., self.frame.size.height/2.);
		offsetLocation = CGPointMake(centeredLocation.x + offset.x, centeredLocation.y + offset.y);
		theSwitch.center = plainToggle ? centeredLocation : offsetLocation;

		[self addSubview:theSwitch];

		// Prevent the switch from responding to user touch gestures. Instead the view will
		// handle them and set the switch accordingly.
		theSwitch.userInteractionEnabled = FALSE;

		if(imageFilesArray)
		{
			NSMutableArray* ma = [NSMutableArray new];
			self.onStateImagesList = ma;

			UIImage* img;

			for(NSString* name in imageFilesArray)
			{
				img = [UIImage imageNamed:name];
				if(img) [onStateImagesList addObject:img];
			}

			onStateImagesCount = [onStateImagesList count];
		}

		if(show)
		{
			UIImageView* iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"no_audio_tiny.png"]];
			self.offImage = iv;

			offImage.frame = CGRectMake(0, centeredLocation.y - offImage.frame.size.height/2., offImage.frame.size.width, offImage.frame.size.height);

			[self addSubview:offImage];

			offImageCenteredLocation = offImage.center;
			offImageOffsetLocation = CGPointMake(offImageCenteredLocation.x + offset.x, offImageCenteredLocation.y + offset.y);
			offImage.center = plainToggle ? offImageCenteredLocation : offImageOffsetLocation;

			iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"yes_audio_tiny.png"]];
			self.onImage = iv;

			onImage.frame = CGRectMake(self.frame.size.width - onImage.frame.size.width,  centeredLocation.y - onImage.frame.size.height/2., onImage.frame.size.width, onImage.frame.size.height);

			[self addSubview:onImage];

			onImageCenteredLocation = onImage.center;
			onImageOffsetLocation = CGPointMake(onImageCenteredLocation.x + offset.x, onImageCenteredLocation.y + offset.y);
			onImage.center = plainToggle ? onImageCenteredLocation : onImageOffsetLocation;
		}
    }

    return self;
}


- (void)setPlainToggle:(BOOL)setting
{
	if(plainToggle == setting) return;

	plainToggle = setting;

	if(onStateImagesCount)
	{
		if(setting) // binary plain toggle images
		{
			self.on = onState > 0;
			onState = 0; // state zero is assumed to be "off"
			self.image = [onStateImagesList objectAtIndex:0];
			state = (SwitchState)0; // always set to the state corresponding to image 0
			theSwitch.alpha = 1.; // show the switch
		}
		else // multiple-state images
		{
			if(theSwitch.on) // switch is on, so leave it on but adjust images appropriately
			{
				[theSwitch setOn:YES animated:NO];
				theSwitch.alpha = 0.; // hide the switch

				onState = 1; // state zero is assumed to be "off"
				self.image = [onStateImagesList objectAtIndex:1];
				state = (SwitchState)1; // always set to the state corresponding to image 1
				if(onImage) onImage.hidden = TRUE;
				if(offImage) offImage.hidden = TRUE;
			}
			else
			{
				theSwitch.alpha = 1.; // show the switch
				[theSwitch setOn:NO animated:NO];
				onState = 0;
				state = (SwitchState)0; // always set to the state corresponding to image 0
			}
		}
	}

	if(plainToggle)
	{
		theSwitch.center = centeredLocation;
		onImage.center = onImageCenteredLocation;
		offImage.center = offImageCenteredLocation;
	}
	else
	{
		theSwitch.center = offsetLocation;
		onImage.center = onImageOffsetLocation;
		offImage.center = offImageOffsetLocation;
	}
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	SDR_DEBUGPRINT(("touchesBegan in switch\n"));
	NSArray *t = [[event allTouches] allObjects];
	int touchCount = (int)[[event allTouches] count];
	//	UITouch *touch = [touches anyObject];

	if(touchCount == 1)
	{
		//		if(self.enableSounds) AudioServicesPlaySystemSound(tapSound);
		//The first touch is considered to be the stationary finger - the next touch sets the frequency
		activeTouchEvent = event;

		if(firstTouch != nil)
		{
			firstTouch = nil;
		}

		firstTouch = [t objectAtIndex:0];
		firstTouchStartPoint = [firstTouch locationInView:self];
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
//	SDR_DEBUGPRINT(("touchesMoved in switch\n"));
	UITouch *touch = [touches anyObject];
	int touchCount = (int)[[event allTouches] count];

	if(touchCount > 1)
	{
		activeTouchEvent = nil;

		if(firstTouch != nil)
		{
			firstTouch = nil;
		}

		return;
	}

	if(touch.tapCount > 1) // avoid strange tap-and-slide conditions
	{
		return;
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	SDR_DEBUGPRINT(("touchesEnded in switch\n"));

//	NSArray *t = [[event allTouches] allObjects];
	UITouch *touch = [touches anyObject];
	int touchCount = (int)[[event allTouches] count];

	if(touchCount > 1)
	{
		if(firstTouch != nil)
		{
			firstTouch = nil;
		}

		return;
	}

	if(activeTouchEvent == event)
	{
		if(firstTouch != nil)
		{
			firstTouchLiftPoint = [firstTouch locationInView:self];

#ifdef DEBUG_SWITCH
			SDR_DEBUGPRINT(("Switch touch ended: dx=%3.0f dy=%3.0f\n", firstTouchLiftPoint.x-firstTouchStartPoint.x, firstTouchLiftPoint.y-firstTouchStartPoint.y));
#endif

			float motion = fabs(firstTouchLiftPoint.x - firstTouchStartPoint.x);

			if(motion > (float)(self.frame.size.width / 4.))
			{
				if(firstTouchLiftPoint.x > firstTouchStartPoint.x)
				{
					if(!theSwitch.on)
					{
						SDR_DEBUGPRINT(("Right swipe detected!\n"));
						[self handleTapEvent];
					}
				}
				else
				{
					if(theSwitch.on)
					{
						SDR_DEBUGPRINT(("Left swipe detected!\n"));
						[self handleTapEvent];
					}
				}
			}

			if(touch.tapCount == 1)
			{
				SDR_DEBUGPRINT(("One tap on switch detected!\n"));
				[self handleTapEvent];
			}

			firstTouch = nil;
		}
	}
}


- (void)handleTapEvent
{
	activeTouchEvent = nil;

	if(_delegateHasGetNextState)
	{
		onState = [delegate switchWasTapped:self getNextState:onState];
		state = (SwitchState)onState;

		if(!plainToggle)
		{
			if(onState >= onStateImagesCount)
			{
				NSLog(@"Error: illegal state encountered by on/off switch.");
				return;
			}

			if(onState == 0) // switch off
			{
				theSwitch.alpha = 1.; // show the switch
				[theSwitch setOn:NO animated:NO];
				if(onImage) onImage.hidden = FALSE;
				if(offImage) offImage.hidden = FALSE;
			}
			else // show the next image
			{
				theSwitch.alpha = 0.; // hide the switch
				if(onImage) onImage.hidden = TRUE;
				if(offImage) offImage.hidden = TRUE;
			}

			self.image = [onStateImagesList objectAtIndex:onState];
		}
		else
		{
			if(onImage) onImage.hidden = FALSE;
			if(offImage) offImage.hidden = FALSE;

			if(onState)
			{
				[theSwitch setOn:YES animated:YES];
			}
			else
			{
				[theSwitch setOn:NO animated:YES];
			}
		}

	}
	else
	{
		if(onStateImagesCount && !plainToggle)
		{
			if(!theSwitch.on) // switch is off
			{
				[theSwitch setOn:YES animated:NO];
				theSwitch.alpha = 0.; // hide the switch

				onState = 1; // state zero is assumed to be "off"
				self.image = [onStateImagesList objectAtIndex:1];
			}
			else
			{
				onState++;

				if(onState >= onStateImagesCount) // turn the switch off
				{
					theSwitch.alpha = 1.; // show the switch
					[theSwitch setOn:NO animated:NO];
					onState = 0;
					state = SwitchOff;
				}
				else // show the next image
				{
					theSwitch.alpha = 0.; // hide the switch
					state = (SwitchState)onState;
					if(onImage) onImage.hidden = TRUE;
					if(offImage) offImage.hidden = TRUE;
				}

				self.image = [onStateImagesList objectAtIndex:onState];
			}

			[delegate switchWasTapped:self withState:onState];
		}
		else
		{
			if(onImage) onImage.hidden = FALSE;
			if(offImage) offImage.hidden = FALSE;

			if(theSwitch.on)
			{
				[theSwitch setOn:NO animated:YES];
			}
			else
			{
				[theSwitch setOn:YES animated:YES];
			}

			[delegate switchWasTapped:self];
		}
	}
}


- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	SDR_DEBUGPRINT(("touchesCancelled in switch\n"));
	if(firstTouch != nil)
	{
		firstTouch = nil;
	}

	activeTouchEvent = nil;
}

// Setter for applying on-state images after the object has been initialized
- (void)addOnStateImages:(NSArray*)imageArray
{
	if(imageArray)
	{
		if([imageArray count])
		{
			if(onStateImagesList)
			{
				[onStateImagesList removeAllObjects];
			}
			else
			{
				NSMutableArray* ma = [NSMutableArray new];
				self.onStateImagesList = ma;
			}

			[onStateImagesList addObjectsFromArray:imageArray];
			onStateImagesCount = [onStateImagesList count];
		}
	}
	else
	{
		if(onStateImagesList)
		{
			[onStateImagesList removeAllObjects];
			onStateImagesCount = 0;
		}
	}
}

- (void)applyState:(SwitchState)newState
{
	if(onStateImagesCount && !plainToggle)
	{
		newState = CLAMP(0, newState, (SwitchState)onStateImagesCount); // prevent crashes

		UIImage* img = [onStateImagesList objectAtIndex:state];

		if(img)
		{
			self.image = img;
		}
	}

	if(newState == 0) // zero is always the off position regardless the number of states
	{
		theSwitch.alpha = 1.; // show the switch
		[theSwitch setOn:NO animated:NO];
		onState = 0;
		if(onImage) onImage.hidden = FALSE;
		if(offImage) offImage.hidden = FALSE;
	}
	else if(!plainToggle)
	{
		if(onImage) onImage.hidden = TRUE;
		if(offImage) offImage.hidden = TRUE;
	}

	state = newState;
}

- (void)setOn:(BOOL)onSetting
{
	theSwitch.on = onSetting;

	if(plainToggle || !onSetting)
	{
		if(onImage) onImage.hidden = FALSE;
		if(offImage) offImage.hidden = FALSE;
	}
}

- (BOOL)getOn
{
	return theSwitch.on;
}

- (SwitchState)getState
{
	return state;
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/



- (id <BigSwitchDelegate>)delegate { return delegate; }

- (void)setDelegate:(id <BigSwitchDelegate>)v
{
	delegate = v;
	_delegateHasGetNextState = [(id)delegate respondsToSelector:@selector(switchWasTapped:getNextState:)];
}


@end
