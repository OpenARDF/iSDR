/*
 Third-party provenance: portions of this file are derived from Apple's
 SpeakHere audio-meter sample code.

 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

 File: AULevelMeter.h
 Abstract: Class for handling and displaying AudioQueue meter data
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
#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>

#import "product.h"
#import "CAStreamBasicDescription.h"
#import "LevelMeter.h"

#import "MeterTable.h"
#import "CAXException.h"

#define kPeakFalloffPerSec	.8
#define kLevelFalloffPerSec .8
#define kMinDBvalue (-90.0)
#define ENABLE_METER_FALLOFF
#define METER_REFRESH_RATE (1. / 11.)

// A LevelMeter subclass which is used specifically for AudioQueue objects
@interface AULevelMeter : UIView {
	AudioUnit					_au;
	AudioQueueLevelMeterState	*_chan_lvls;
	NSArray						*_channelNumbers;
	NSArray						*_subLevelMeters;
	MeterTable					*_meterTable;
	NSTimer						*_updateTimer;
	CGFloat						_refreshHz;
	float						_rangedB;
	BOOL						_showsPeaks;
	BOOL						_vertical;
	BOOL						_reverseDirection;
	MeterOrientation			_orientation;
	BOOL						_useGL;
	BOOL						_displayMeter;
	BOOL						_sleeping;
	AGCSetting					agc;

	LevelMeter*					_newMeter;
	UIColor						*_bgColor, *_borderColor;
	CFAbsoluteTime				_peakFalloffLastFire;
	BOOL						inBackground;
}

@property						AudioUnit	au; // The MultiChannalMixer AudioUnit object
@property						CGFloat		refreshHz; // How many times per second to redraw
@property (retain)				NSArray*	channelNumbers; // Array of NSNumber objects: The indices of the channels to display in this meter
@property						BOOL		showsPeaks; // Whether or not we show peak levels
@property						BOOL		vertical; // Whether the view is oriented V or H
@property						BOOL		useGL; // Whether or not to use OpenGL for drawing
@property (nonatomic, assign)	AGCSetting	agc;
@property (nonatomic, readwrite, setter = inBackground:, getter = inBackground) BOOL		inBackground;

- (id)initWithFrame:(CGRect)frame orient:(MeterOrientation)orientation dBWidth:(float)widthInDB;
- (id)initWithFrame:(CGRect)frame orient:(MeterOrientation)orientation dBWidth:(float)widthInDB dBMin:(float)minInDB;
- (void)setBorderColor: (UIColor *)borderColor;
- (void)setBackgroundColor: (UIColor *)backgroundColor;
- (void)hideMeter:(BOOL)wakeup;
- (void)showMeter:(BOOL)wakeup;
- (void)sleep;
- (void)wake;
- (OSErr)calcAGC;
- (void)zeroMeter;

@end
