//
//  BigSwitch.h
//  iSDR
//
//  Created by Charles Scharlau on 4/23/14.
//  Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.
//

#import <UIKit/UIKit.h>

@class BigSwitch;

@protocol BigSwitchDelegate
@required
- (void)switchWasTapped:(BigSwitch*)theSwitch;
- (void)switchWasTapped:(BigSwitch*)theSwitch withState:(NSInteger)onState;
@optional
- (NSInteger)switchWasTapped:(BigSwitch *)theSwitch getNextState:(NSInteger)currentState;
@end

typedef enum switchStates
{
	SwitchOff = 0,
	SwitchNormalTuning = 1,
	SwitchFreqLockedTuning = 2
} SwitchState;

@interface BigSwitch : UIImageView
{
	UISwitch*	theSwitch;
	BOOL		plainToggle; // forces BigSwitch to work like Apple's plain on/off switch regardless any loaded images
	SwitchState	state;

@private
	UIEvent*						activeTouchEvent;
	UITouch*						firstTouch;
	CGPoint							firstTouchStartPoint;
	CGPoint							firstTouchLiftPoint;

	CGPoint							centeredLocation;
	CGPoint							offsetLocation;

	UIImageView*					onImage;
	CGPoint							onImageCenteredLocation;
	CGPoint							onImageOffsetLocation;


	UIImageView*					offImage;
	CGPoint							offImageCenteredLocation;
	CGPoint							offImageOffsetLocation;


	NSMutableArray*					onStateImagesList;
	id <BigSwitchDelegate>			delegate;

	BOOL							_delegateHasGetNextState;
}

@property (weak) id <BigSwitchDelegate>										delegate;
@property (nonatomic, strong) UISwitch*										theSwitch;
@property (nonatomic, strong) UIImageView*									onImage;
@property (nonatomic, strong) UIImageView*									offImage;
@property (nonatomic, setter = setOn:, getter = getOn) BOOL					on;
@property (nonatomic, setter = applyState:, getter = getState) SwitchState	state;
@property (nonatomic, strong) NSMutableArray*								onStateImagesList;
@property (nonatomic, readwrite, setter = setPlainToggle:) BOOL				plainToggle;

- (id)initWithFrame:(CGRect)frame showIcons:(BOOL)show;
- (id)initWithFrame:(CGRect)frame images:(NSArray*)imageFilesArray showIcons:(BOOL)show positionOffset:(CGPoint)offset;
- (void)applyState:(SwitchState)state;

@end
