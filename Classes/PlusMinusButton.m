//
//  PlusMinusButton.m
//  iKX3
//
//  Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.
//

#import "product.h"
#import "PlusMinusButton.h"

@implementation PlusMinusButton

@synthesize theButton;
@synthesize disabled;

- (id)initWithFrame:(CGRect)frame image:(NSString*)mainImage disabledImage:(NSString*)disabledImage
{
	self = [super initWithFrame:frame];

	if(self)
	{
		self.userInteractionEnabled = TRUE;
		// self.backgroundColor = [UIColor redColor];

		UIButton* button = [[UIButton alloc] initWithFrame:frame];
		self.theButton = button;

		if(mainImage)
		{
			UIImage* img = [UIImage imageNamed:mainImage];
			[theButton setImage:img forState:UIControlStateNormal];
		}

		if(disabledImage)
		{
			UIImage* img = [UIImage imageNamed:disabledImage];
			[theButton setImage:img forState:UIControlStateHighlighted];
		}

		theButton.center = CGPointMake(self.frame.size.width/2., self.frame.size.height/2.);

		// Prevent the swith from responding to user touch gestures. Instead the view will
		// handle them and set the switch accordingly.
		theButton.userInteractionEnabled = FALSE;

		[self addSubview:theButton];
	}

	return self;
}

- (void)disabled:(BOOL)setting
{
	theButton.highlighted = setting;
	self.userInteractionEnabled = !setting;
}

- (BOOL)disabled
{
	return theButton.highlighted;
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	WIFI_DEBUGPRINT(("touchesBegan in button\n"));
	NSArray *t = [[event allTouches] allObjects];
	int touchCount = (int)[[event allTouches] count];
	//	UITouch *touch = [touches anyObject];

	if(touchCount == 1)
	{
		//The first touch is considered to be the stationary finger - the next touch sets the frequency
		activeTouchEvent = event;

		if(firstTouch != nil)
		{
			firstTouch = nil;
		}

		firstTouch = [t objectAtIndex:0];
		firstTouchStartPoint = [firstTouch locationInView:self];
		theButton.selected = TRUE;

		if(initiateRepeatingTimer)
		{
			[initiateRepeatingTimer invalidate];
			initiateRepeatingTimer = nil;
		}

		initiateRepeatingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(sendRepeatTap) userInfo:nil repeats:NO];

		if(repeatTimer)
		{
			[repeatTimer invalidate];
			repeatTimer = nil;
		}

		[delegate buttonWasTapped:self repeating:NO];
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
//	UITouch *touch = [touches anyObject];
	int touchCount = (int)[[event allTouches] count];

	theButton.selected = FALSE;

	// Any ending touch immediately ceases all button repeats
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
	theButton.selected = FALSE;
}


- (void)sendRepeatTap
{
	[delegate buttonWasTapped:self repeating:YES];

	if(repeatTimer == nil)
	{
		repeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(sendRepeatTap) userInfo:nil repeats:YES];
	}

	if(initiateRepeatingTimer)
	{
		initiateRepeatingTimer = nil;
	}
}



- (id <PlusMinusButtonDelegate>)delegate { return delegate; }

- (void)setDelegate:(id <PlusMinusButtonDelegate>)v
{
	delegate = v;
}



@end
