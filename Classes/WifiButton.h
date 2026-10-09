//
//  WifiButton.h
//  iKX3
//
//  Created by Charles Scharlau on 5/7/14.
//  Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.
//

#import <UIKit/UIKit.h>
#import "WifiInterface.h"

@class WifiButton;

@protocol WifiButtonDelegate
@required
- (void)buttonWasTapped:(WifiButton*)theButton withState:(WifiState)state;
@optional
- (NSInteger)buttonWasTapped:(WifiButton *)theButton getNextState:(NSInteger)currentState;
@end

@interface WifiButton : UIImageView <WifiStateListener>
{
	UIButton*		theButton;
	WifiState		state;

@private
	UIEvent*						activeTouchEvent;
	UITouch*						firstTouch;
	CGPoint							firstTouchStartPoint;
	CGPoint							firstTouchLiftPoint;
	NSTimer*						repeatTimer;
	NSTimer*						initiateRepeatingTimer;
	NSMutableArray*					imagesList;
	id <WifiButtonDelegate>			delegate;

	BOOL							_delegateHasGetNextState;
}

@property (weak) id <WifiButtonDelegate>			delegate;
@property (nonatomic, strong) UIButton*				theButton;
@property (nonatomic, strong) NSMutableArray*		imagesList;
@property (nonatomic, readonly) WifiState			state;

- (id)initWithFrame:(CGRect)frame images:(NSArray*)imageFilesArray;
- (void)applyStateSetting:(WifiState)aState;

@end
