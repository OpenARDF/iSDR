/*
 Third-party provenance: portions of this file are derived from Apple's
 SpeakHere audio-meter sample code.

 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

 File: LevelMeter.h
 Abstract: Base level metering class
 Version: 2.0

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


#import <UIKit/UIKit.h>
#import "product.h"

#ifndef LEVELMETER_CLAMP
#define LEVELMETER_CLAMP(min,x,max) (x < min ? min : (x > max ? max : x))
#endif

// The levelMeter can be oriented any of four ways: two horizontal and two vertical.
// BottomToTop implies signal strength increases from the bottom up, etc.
// LeftToRight implies signal strength increases from left to right, etc.
typedef enum MeterOrientation
{
	VerticalBottomToTop,
	VerticalTopToBottom,
	HorizontalLeftToRight,
	HorizontalRightToLeft
} MeterOrientation;

// The LevelMeterColorThreshold struct is used to define the colors for the LevelMeter,
// and at what values each of those colors begins.
typedef struct LevelMeterColorThreshold
{
	CGFloat			maxValue; // A value from 0 - 1. The maximum value shown in this color
	UIColor			*color; // A UIColor to be used for this value range
} LevelMeterColorThreshold;

@interface LevelMeter : UIView
{
	NSUInteger					_numLights;
	CGFloat						_level, _peakLevel;
	LevelMeterColorThreshold	*_colorThresholds;
	NSUInteger					_numColorThresholds;
	BOOL						_vertical;
	BOOL						_reverseDirection;
	MeterOrientation			_orientation;
//	BOOL						_variableLightIntensity;
	UIColor						*_bgColor, *_borderColor;
	BOOL						inBackground;
}

// The current level, from 0 - 1
@property						CGFloat level;

// Optional peak level, will be drawn if > 0
@property						CGFloat peakLevel;

// The number of lights to show, or 0 to show a continuous bar
@property						NSUInteger numLights;

// Whether the view is oriented V or H. This is initially automatically set based on the
// aspect ratio of the view.
@property(getter=isVertical)	BOOL vertical;

// Whether to use variable intensity lights. Has no effect if numLights == 0.
//@property						BOOL variableLightIntensity;

// The background color of the lights
@property(retain)				UIColor *bgColor;

// The border color of the lights
@property(retain)				UIColor *borderColor;

@property						BOOL inBackground;

// Returns a pointer to the first LevelMeterColorThreshold struct. The number of color
// thresholds is returned in count
- (LevelMeterColorThreshold *)colorThresholds:(NSUInteger *)count;

// Load <count> elements from <thresholds> and use these as our color threshold values.
- (void)setColorThresholds:(LevelMeterColorThreshold *)thresholds count:(NSUInteger)count;

- (id)initWithFrame:(CGRect)frame;
- (id)initWithFrame:(CGRect)frame orient:(MeterOrientation)orientation dBWidth:(float)widthInDB;
- (id)initWithFrame:(CGRect)frame orient:(MeterOrientation)orientation dBWidth:(float)widthInDB dBMin:(float)minInDB;
- (id)initWithCoder:(NSCoder *)coder;
- (id)initWithCoder:(NSCoder *)coder orient:(MeterOrientation)orientation dBWidth:(float)widthInDB;
@end
