//
//  WifiButton.m
//  iKX3
//
//  Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.
//

#import "product.h"
#import "WifiButton.h"

@implementation WifiButton

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

		// Prevent the swith from responding to user touch gestures. Instead the view will
		// handle them and set the switch accordingly.
		theButton.userInteractionEnabled = FALSE;

		[self addSubview:theButton];
	}

	return self;
}

/*
 Listener method for receiving wifi state change notifications.
 */
- (void)newWifiState:(WifiState)aState
{
	state = CLAMP(0, aState, (WifiState)[imagesList count]);

	UIImage* img = [imagesList objectAtIndex:state];

	if(img)
	{
		[theButton setImage:img forState:UIControlStateNormal];
	}
}

/*
  Used mainly for initialization or debugging. The preferred way to apply a new state is by registering as a listener for state transitions.
 */
- (void)applyStateSetting:(WifiState)aState;
{
	state = CLAMP(0, aState, (WifiState)[imagesList count]);

	UIImage* img = [imagesList objectAtIndex:state];

	if(img)
	{
		[theButton setImage:img forState:UIControlStateNormal];
	}
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	WIFI_DEBUGPRINT(("touchesBegan in button\n"));
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

		if(initiateRepeatingTimer)
		{
			[initiateRepeatingTimer invalidate];
			initiateRepeatingTimer = nil;
		}

		// disable repeating
		// initiateRepeatingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(sendRepeatTap) userInfo:nil repeats:NO];

		if(repeatTimer)
		{
			[repeatTimer invalidate];
			repeatTimer = nil;
		}

		[delegate buttonWasTapped:self withState:state];
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
	SDR_DEBUGPRINT(("touchesEnded in WifiButton\n"));

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
			firstTouchLiftPoint = [firstTouch locationInView:self];

#ifdef DEBUG_SWITCH
			SDR_DEBUGPRINT(("Switch touch ended: dx=%3.0f dy=%3.0f\n", firstTouchLiftPoint.x-firstTouchStartPoint.x, firstTouchLiftPoint.y-firstTouchStartPoint.y));
#endif

			float motion = fabs(firstTouchLiftPoint.x - firstTouchStartPoint.x);

			if(motion > (float)(self.frame.size.width / 4))
			{
				if(firstTouchLiftPoint.x > firstTouchStartPoint.x)
				{
					SDR_DEBUGPRINT(("Right swipe detected!\n"));
					//					[delegate switchWasTapped:self];
				}
				else
				{
					SDR_DEBUGPRINT(("Left swipe detected!\n"));
					//					[delegate switchWasTapped:self];
				}
			}

			//			if(touch.tapCount == 1)
			//			{
			//				SDR_DEBUGPRINT(("One tap on button detected!\n"));
			//				activeTouchEvent = nil;
			//				[delegate buttonWasTapped:self];
			//
			if(repeatTimer)
			{
				[repeatTimer invalidate];
				repeatTimer = nil;
			}

			if(initiateRepeatingTimer)
			{
				[initiateRepeatingTimer invalidate];
				initiateRepeatingTimer = nil;
			}

			//			}

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

	if(repeatTimer)
	{
		[repeatTimer invalidate];
		repeatTimer = nil;
	}

	if(initiateRepeatingTimer)
	{
		[initiateRepeatingTimer invalidate];
		initiateRepeatingTimer = nil;
	}

	activeTouchEvent = nil;
	theButton.highlighted = FALSE;
}


- (void)sendRepeatTap
{
	[delegate buttonWasTapped:self withState:state];

	if(repeatTimer == nil)
	{
		repeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(sendRepeatTap) userInfo:nil repeats:YES];
	}

	if(initiateRepeatingTimer)
	{
		initiateRepeatingTimer = nil;
	}
}



- (id <WifiButtonDelegate>)delegate { return delegate; }

- (void)setDelegate:(id <WifiButtonDelegate>)v
{
	delegate = v;
	_delegateHasGetNextState = [(id)delegate respondsToSelector:@selector(buttonWasTapped: getNextState:)];
}

@end
