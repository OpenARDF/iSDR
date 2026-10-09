//
//  LockButton.m
//  iKX3
//
//  Created by Charles Scharlau on 5/7/14.
//  Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.
//

#import "product.h"
#import "LockButton.h"

@implementation LockButton

@synthesize theButton;
@synthesize imagesList;
@synthesize state;

- (id)initWithFrame:(CGRect)frame images:(NSArray*)imageFilesArray
{
	self = [super initWithFrame:frame];

	if(self)
	{
		self.userInteractionEnabled = TRUE;
		//self.backgroundColor = [UIColor redColor];

		state = UNLOCKED;

		UIButton* button = [[UIButton alloc] initWithFrame:frame];
		self.theButton = button;

		if(imageFilesArray)
		{
			NSMutableArray* ma = [NSMutableArray new];
			self.imagesList = ma;

			UIImage* img;

			for(NSString* name in imageFilesArray)
			{
				img = [UIImage imageNamed:name];
				if(img) [imagesList addObject:img];
			}

			img = [imagesList firstObject];
			if(img) [theButton setImage:img forState:UIControlStateNormal]; // use the first image by default
		}

		theButton.center = CGPointMake(self.frame.size.width/2., self.frame.size.height/2.);

		// Prevent the switch from responding to user touch gestures. Instead the view will
		// handle them and set the switch accordingly.
		theButton.userInteractionEnabled = FALSE;

		[self addSubview:theButton];
	}

	return self;
}

/*
  Used mainly for initialization or debugging. The preferred way to apply a new state is by registering as a listener for state transitions.
 */
- (void)buttonState:(NSInteger)aState;
{
	state = CLAMP(0, aState, [imagesList count]);

	UIImage* img = [imagesList objectAtIndex:state];

	if(img)
	{
		[theButton setImage:img forState:UIControlStateNormal];
	}
}

- (NSInteger)buttonState
{
	return state;
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	SDR_DEBUGPRINT(("touchesBegan in LockButton\n"));
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
		theButton.highlighted = TRUE;
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	//	SDR_DEBUGPRINT(("touchesMoved in LockButton\n"));
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
	SDR_DEBUGPRINT(("touchesEnded in LockButton\n"));

	//	NSArray *t = [[event allTouches] allObjects];
	//	UITouch *touch = [touches anyObject];
	int touchCount = (int)[[event allTouches] count];

	theButton.highlighted = FALSE;

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
			if(firstTouch.tapCount == 1)
			{
				[delegate buttonWasTapped:self withState:state];
			}
			else if(firstTouch.tapCount == 2)
			{
				[delegate buttonWasActivated:self withState:state];
			}

			firstTouch = nil;
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
	theButton.highlighted = FALSE;
}



- (id <LockButtonDelegate>)delegate { return delegate; }

- (void)setDelegate:(id <LockButtonDelegate>)v
{
	delegate = v;
}

@end
