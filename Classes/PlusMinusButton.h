//
//  PlusMinusButton.h
//  iKX3
//
//  Created by Charles Scharlau on 5/6/14.
//  Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.
//

#import <UIKit/UIKit.h>

@class PlusMinusButton;

@protocol PlusMinusButtonDelegate
@required
- (void)buttonWasTapped:(PlusMinusButton*)theButton repeating:(BOOL)repeating;
@optional
@end

@interface PlusMinusButton : UIImageView
{
	UIButton* theButton;

@private
	UIEvent*						activeTouchEvent;
	UITouch*						firstTouch;
	CGPoint							firstTouchStartPoint;
	CGPoint							firstTouchLiftPoint;
	NSTimer*						repeatTimer;
	NSTimer*						initiateRepeatingTimer;
	id <PlusMinusButtonDelegate>			delegate;
}

@property (weak) id <PlusMinusButtonDelegate>		delegate;
@property (nonatomic, strong) UIButton*			theButton;
@property (nonatomic, readwrite, setter = disabled:, getter = disabled) BOOL			disabled;

- (id)initWithFrame:(CGRect)frame image:(NSString*)mainImage disabledImage:(NSString*)disabledImage;

@end
