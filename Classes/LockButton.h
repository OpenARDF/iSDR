//
//  LockButton.h
//  iKX3
//
//  Created by Charles Scharlau on 5/7/14.
//  Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.
//

#import <UIKit/UIKit.h>

@class LockButton;

@protocol LockButtonDelegate
@required
- (void)buttonWasTapped:(LockButton*)theButton withState:(NSInteger)state;
- (void)buttonWasActivated:(LockButton*)theButton withState:(NSInteger)state;
@optional
@end

@interface LockButton : UIImageView
{
	UIButton*		theButton;
	NSInteger		state;

@private
	UIEvent*						activeTouchEvent;
	UITouch*						firstTouch;
	CGPoint							firstTouchStartPoint;
	NSMutableArray*					imagesList;
	id <LockButtonDelegate>		delegate;
}

@property (weak) id <LockButtonDelegate>			delegate;
@property (nonatomic, strong) UIButton*				theButton;
@property (nonatomic, strong) NSMutableArray*		imagesList;
@property (nonatomic, readwrite, setter = buttonState:, getter = buttonState) NSInteger			state;

- (id)initWithFrame:(CGRect)frame images:(NSArray*)imageFilesArray;

@end
