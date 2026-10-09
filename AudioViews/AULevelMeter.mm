/*
 Third-party provenance: portions of this file are derived from Apple's
 SpeakHere audio-meter sample code.

 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

 File: AULevelMeter.mm
 Abstract: n/a
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


#import "AULevelMeter.h"

#import "LevelMeter.h"
#import "GLLevelMeter.h"

#import "CAStreamBasicDescription.h"

@interface AULevelMeter (AULevelMeter_priv)
- (void)layoutSubLevelMeters:(float)dBmin;
@end


@implementation AULevelMeter

@synthesize showsPeaks = _showsPeaks;
@synthesize vertical = _vertical;
@synthesize agc;
@synthesize inBackground;


- (id)initWithFrame:(CGRect)frame orient:(MeterOrientation)orientation dBWidth:(float)widthInDB
{
	if(self = [super initWithFrame:frame])
	{
		inBackground = FALSE;
		SDR_DEBUGPRINT(("\nMeter frame: origin.x=%f .y=%f size.width=%f size.height=%f \n\n", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height));
		_rangedB = widthInDB;
		_displayMeter = FALSE;
		_refreshHz = METER_REFRESH_RATE;
		_showsPeaks = YES;
		agc = AGC_SLOW;
		_channelNumbers = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], nil];
		_orientation = orientation;

		switch(_orientation)
		{
			case VerticalBottomToTop:
				_vertical = YES;
				_reverseDirection = YES;
				break;
			case VerticalTopToBottom:
				_vertical = YES;
				_reverseDirection = YES;
				break;
			case HorizontalLeftToRight:
				_vertical = NO;
				_reverseDirection = NO;
				break;
			case HorizontalRightToLeft:
				_vertical = NO;
				_reverseDirection = YES;
				break;
			default:
				_vertical = NO;
				_reverseDirection = NO;
				break;
		}

		_useGL = YES;
		_chan_lvls = (AudioQueueLevelMeterState*)malloc(sizeof(AudioQueueLevelMeterState) * [_channelNumbers count]);
		_meterTable = new MeterTable(kMinDBvalue);
		_bgColor = nil;
		_borderColor = nil;

		[self layoutSubLevelMeters:kMinDBvalue];
	}

	return self;
}


-(id)initWithFrame:(CGRect)frame orient:(MeterOrientation)orientation dBWidth:(float)widthInDB dBMin:(float)minInDB;
{
	if(self = [super initWithFrame:frame])
	{
		inBackground = FALSE;
		_rangedB = widthInDB;
		_displayMeter = FALSE;
		_refreshHz = METER_REFRESH_RATE;
		_showsPeaks = YES;
		agc = AGC_SLOW;
		_channelNumbers = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], nil];
		_orientation = orientation;

		switch(_orientation)
		{
			case VerticalBottomToTop:
				_vertical = YES;
				_reverseDirection = YES;
				break;
			case VerticalTopToBottom:
				_vertical = YES;
				_reverseDirection = YES;
				break;
			case HorizontalLeftToRight:
				_vertical = NO;
				_reverseDirection = NO;
				break;
			case HorizontalRightToLeft:
				_vertical = NO;
				_reverseDirection = YES;
				break;
			default:
				_vertical = NO;
				_reverseDirection = NO;
				break;
		}

		_useGL = YES;
		_chan_lvls = (AudioQueueLevelMeterState*)malloc(sizeof(AudioQueueLevelMeterState) * [_channelNumbers count]);
		_meterTable = new MeterTable(kMinDBvalue);
		_bgColor = nil;
		_borderColor = nil;

		[self layoutSubLevelMeters:minInDB];
	}
	return self;
}


- (id)initWithCoder:(NSCoder *)coder {
	if(self = [super initWithCoder:coder]) {
		inBackground = FALSE;
		_refreshHz = METER_REFRESH_RATE;
		_showsPeaks = YES;
		agc = AGC_SLOW;
		_channelNumbers = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], nil];
		_chan_lvls = (AudioQueueLevelMeterState*)malloc(sizeof(AudioQueueLevelMeterState) * [_channelNumbers count]);
		_vertical = NO;
		_useGL = YES;
		_meterTable = new MeterTable(kMinDBvalue);
		[self layoutSubLevelMeters:kMinDBvalue];
	}
	return self;
}

-(void)setBorderColor: (UIColor *)borderColor
{
	if(_borderColor) [_borderColor release];
	_borderColor = borderColor;
	[_borderColor retain];

	for(NSUInteger i=0; i < [_subLevelMeters count]; i++)
	{
		id meter = [_subLevelMeters objectAtIndex:i];
		if(_useGL)
		{
//			UIColor *oldColor = ((GLLevelMeter*)meter).borderColor;
			((GLLevelMeter*)meter).borderColor = borderColor;
//			[oldColor release];
		}
		else
		{
//			UIColor *oldColor = ((LevelMeter*)meter).borderColor;
			((LevelMeter*)meter).borderColor = borderColor;
//			[oldColor release];
		}
	}
}

-(void)setBackgroundColor: (UIColor *)bgColor
{
	if(_bgColor) [_bgColor release];
	_bgColor = bgColor;
	[_bgColor retain];

	for(NSUInteger i=0; i < [_subLevelMeters count]; i++)
	{
		id meter = [_subLevelMeters objectAtIndex:i];
		if (_useGL)
			((GLLevelMeter*)meter).bgColor = bgColor;
		else
			((LevelMeter*)meter).bgColor = bgColor;
	}

}

- (void)layoutSubLevelMeters:(float)dBmin
{
	int i;

	if([[UIScreen mainScreen] respondsToSelector:NSSelectorFromString(@"scale")])
	{
		if([self respondsToSelector:NSSelectorFromString(@"contentScaleFactor")])
		{
			self.contentScaleFactor = [[UIScreen mainScreen] scale];
			SDR_DEBUGPRINT(("AULevelMeter::layoutSubLevelMeters:scale = %f\n", self.contentScaleFactor));
		}
	}

	for(i=0; i<[_subLevelMeters count]; i++)
	{
		UIView *thisMeter = [_subLevelMeters objectAtIndex:i];
		[thisMeter removeFromSuperview];
	}

	[_subLevelMeters release];

	NSMutableArray *meters_build = [[NSMutableArray alloc] initWithCapacity:[_channelNumbers count]];

	CGRect totalRect;

	if(_vertical)
	{
		totalRect = CGRectMake(0., 0., [self frame].size.width + 2., [self frame].size.height);
	}
	else
	{
		totalRect = CGRectMake(0., 0., [self frame].size.width, [self frame].size.height + 2.);
	}

	SDR_DEBUGPRINT(("Total width = %f\n",(float)totalRect.size.width));

	for(i=0; i<[_channelNumbers count]; i++)
	{
		CGRect fr;

		if(_vertical)
		{
			fr = CGRectMake(
							totalRect.origin.x + (((CGFloat)i / (CGFloat)[_channelNumbers count]) * totalRect.size.width),
							totalRect.origin.y,
							(1. / (CGFloat)[_channelNumbers count]) * totalRect.size.width - 2.,
							totalRect.size.height
							);
		}
		else
		{
			fr = CGRectMake(
							totalRect.origin.x,
							totalRect.origin.y + (((CGFloat)i / (CGFloat)[_channelNumbers count]) * totalRect.size.height),
							totalRect.size.width,
							(1. / (CGFloat)[_channelNumbers count]) * totalRect.size.height - 2.
							);
		}

		if(_useGL)
		{
			_newMeter = [[GLLevelMeter alloc] initWithFrame:fr orient:_orientation dBWidth:_rangedB dBMin:dBmin];
		}
		else
		{
			_newMeter = [[LevelMeter alloc] initWithFrame:fr orient:_orientation dBWidth:dBmin];
		}

//		SDR_DEBUGPRINT(("Meter segments = %d scale = %fdB\n",_newMeter.numLights, dBmin));
		_newMeter.vertical = self.vertical;
		_newMeter.bgColor = _bgColor;
		_newMeter.borderColor = _borderColor;

		[meters_build addObject:_newMeter];
	}

	_subLevelMeters = [[NSArray alloc] initWithArray:meters_build];

	[meters_build release];
}


- (void)_refresh
{
	BOOL success = NO;

	if(_displayMeter)
	{
		// if we have no audio unit, but still have levels, gradually bring them down
		if((_au == NULL) || _sleeping)
		{
			CGFloat maxLvl = -1.;

#ifdef ENABLE_METER_FALLOFF
			CFAbsoluteTime thisFire = CFAbsoluteTimeGetCurrent();
			// calculate how much time passed since the last draw
			CFAbsoluteTime timePassed = thisFire - _peakFalloffLastFire;
			for(LevelMeter *thisMeter in _subLevelMeters)
			{
				CGFloat newPeak, newLevel;
				newLevel = thisMeter.level - timePassed * kLevelFalloffPerSec;
				SDR_DEBUGPRINT(("averageLevel... %f %f\n", maxLvl, newLevel));
				if(newLevel < 0.) newLevel = 0.;
				thisMeter.level = newLevel;
				if(_showsPeaks)
				{
					newPeak = thisMeter.peakLevel - timePassed * kPeakFalloffPerSec;
					SDR_DEBUGPRINT(("peakLevel... %f %f\n", maxLvl, newPeak));
					if(newPeak < 0.) newPeak = 0.;
					thisMeter.peakLevel = newPeak;
					if(newPeak > maxLvl) maxLvl = newPeak;
				}
				else if (newLevel > maxLvl) maxLvl = newLevel;

				[thisMeter setNeedsDisplay];
			}

			SDR_DEBUGPRINT(("Meter falling... %f\n", maxLvl));

			_peakFalloffLastFire = thisFire;
#endif
			// stop the timer when the last level has hit 0
			if(maxLvl <= 0.)
			{
				[_updateTimer invalidate];
				_updateTimer = nil;
//				_sleeping = FALSE;
				SDR_DEBUGPRINT(("Meter now at zero.\n"));
			}

			success = YES;
		}
		else
		{
			if([self calcAGC] != noErr) goto bail;

			if(!_sleeping)
			{
				for(int i=0; i<[_channelNumbers count]; i++)
				{
					NSInteger channelIdx = [(NSNumber *)[_channelNumbers objectAtIndex:i] intValue];
					LevelMeter *channelView = [_subLevelMeters objectAtIndex:channelIdx];

					if(channelIdx >= [_channelNumbers count]) goto bail;
					if(channelIdx > 127) goto bail;

					if(_chan_lvls)
					{
						channelView.level = _meterTable->ValueAt((float)(_chan_lvls[channelIdx].mAveragePower));
						//				SDR_DEBUGPRINT(("%d. channelView.level=%f\n", i, channelView.level));
						if(_showsPeaks)
						{
							channelView.peakLevel = _meterTable->ValueAt((float)(_chan_lvls[channelIdx].mPeakPower));
						}
						else
						{
							channelView.peakLevel = 0.;
						}

						[channelView setNeedsDisplay];
						success = YES;
					}
				}
			}
		}
	}
	else
	{
		if([self calcAGC] != noErr) goto bail;

		success = YES;
	}


bail:

	if(!success)
	{
		if(_displayMeter) // avoid background crash
		{
			for (LevelMeter *thisMeter in _subLevelMeters) { thisMeter.level = 0.; [thisMeter setNeedsDisplay]; }
			SDR_DEBUGPRINT(("Warning: metering failed\n"));
		}
	}
}


- (void)zeroMeter
{
	if(_updateTimer)
	{
		[_updateTimer invalidate];
		_updateTimer = nil;
	}

	for(LevelMeter *thisMeter in _subLevelMeters)
	{
		CGFloat newPeak, newLevel;
		newLevel = 0.;
		thisMeter.level = newLevel;
		if(_showsPeaks)
		{
			newPeak = 0.;
			thisMeter.peakLevel = newPeak;
		}

		[thisMeter setNeedsDisplay];
	}

	[EAGLContext setCurrentContext:((GLLevelMeter*)_newMeter).eaglContext];
	glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
	_displayMeter = TRUE;
	_sleeping = TRUE;
	[self _refresh];

}


- (OSErr)calcAGC
{
	static Float32 lastAvgPwr = -99.;
	static AudioUnitParameterValue value = 1.;

	if(_au == nil)
	{
		SDR_DEBUGPRINT(("Warning: No audio unit available to RSSI meter!\n"));
		return !noErr;
	}

	OSErr status = AudioUnitGetParameter(_au, kMultiChannelMixerParam_PreAveragePower, kAudioUnitScope_Input, 0, &_chan_lvls->mAveragePower);
	if(status)
	{
		SDR_DEBUGPRINT(("AvgPower1: AudioUnitGetProperty result %d %08X %4.4s\n", (int)status, (int)status, (char*)&status));
		return status;
	}

	status = AudioUnitGetParameter(_au, kMultiChannelMixerParam_PrePeakHoldLevel, kAudioUnitScope_Input, 0, &_chan_lvls->mPeakPower);
	if(status)
	{
		SDR_DEBUGPRINT(("AvgPower1: AudioUnitGetProperty result %d %08X %4.4s\n", (int)status, (int)status, (char*)&status));
		return status;
	}

	switch(agc)
	{
		case AGC_SLOW:
			if((_chan_lvls->mAveragePower > -14.))
			{
				if(_chan_lvls->mAveragePower > lastAvgPwr)
				{
					value = powf(10., -((14. + _chan_lvls->mAveragePower)/20.));
				}
				//					SDR_DEBUGPRINT(("g=%1.4f\n", value));
			}
			else
			{
				value = (24.*value + 1.)/25.;
			}

			lastAvgPwr = _chan_lvls->mAveragePower;

			status = AudioUnitSetParameter(_au, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, value, 0);
#ifdef SDR_DEBUG
			if(status)
			{
				SDR_DEBUGPRINT(("AudioUnitSetParameter kMultiChannelMixerParam_Volume Output result %d %08X %4.4s\n", status, status, (char*)&status));
			}
#endif
			break;

		case AGC_FAST:
			if((_chan_lvls->mAveragePower > -14.))
			{
				if(_chan_lvls->mAveragePower > lastAvgPwr)
				{
					value = powf(10., -((14. + _chan_lvls->mAveragePower)/20.));
				}
				//					SDR_DEBUGPRINT(("g=%1.4f\n", value));
			}
			else
			{
				value = 1.;
			}

			lastAvgPwr = _chan_lvls->mAveragePower;

			status = AudioUnitSetParameter(_au, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, value, 0);
#ifdef SDR_DEBUG
			if(status)
			{
				SDR_DEBUGPRINT(("AudioUnitSetParameter kMultiChannelMixerParam_Volume Output result %d %08X %4.4s\n", status, status, (char*)&status));
			}
#endif
			break;

		default: //off
			if(value != 1.)
			{
				value = 1.;
				lastAvgPwr = -99.;
				status = AudioUnitSetParameter(_au, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, value, 0);
				if(status)
				{
					SDR_DEBUGPRINT(("AudioUnitSetParameter kMultiChannelMixerParam_Volume Output result %d %08X %4.4s\n", status, status, (char*)&status));
				}
			}
			break;
	}

	return status;
}


- (void)dealloc
{
	[_updateTimer invalidate];
	[_channelNumbers release];
	[_subLevelMeters release];
	[_bgColor release];
	[_borderColor release];
	[_newMeter release];

	delete _meterTable;

	[super dealloc];
}


- (void)hideMeter:(BOOL)wakeup
{
	if(_displayMeter)
	{
		SDR_DEBUGPRINT(("Meter hidden!\n"));
		_displayMeter = FALSE;
		[_newMeter removeFromSuperview];
	}

	if(wakeup && (_updateTimer == nil))
	{
		SDR_DEBUGPRINT(("showMeter: starting timer\n"));
		_updateTimer = [NSTimer
						scheduledTimerWithTimeInterval:_refreshHz
						target:self
						selector:@selector(_refresh)
						userInfo:nil
						repeats:YES
						];
	}
}


- (void)showMeter:(BOOL)wakeup
{
	if(!_displayMeter)
	{
		SDR_DEBUGPRINT(("Meter displayed!\n"));
		[self addSubview:_newMeter];
		_displayMeter = TRUE;

		if(wakeup && (_updateTimer == nil))
		{
			SDR_DEBUGPRINT(("showMeter: starting timer\n"));
			_updateTimer = [NSTimer
							scheduledTimerWithTimeInterval:_refreshHz
							target:self
							selector:@selector(_refresh)
							userInfo:nil
							repeats:YES
							];
		}
	}
}


- (AudioUnit)au { return _au; }
- (void)setAu:(AudioUnit)v
{
	OSStatus result = noErr;

	if ((_au == NULL) && (v != NULL))
	{
		SDR_DEBUGPRINT(("Meter initialized!\n"));
		if (_updateTimer) [_updateTimer invalidate];
		_updateTimer = nil;
	} else if ((_au != NULL) && (v == NULL)) {
		_peakFalloffLastFire = CFAbsoluteTimeGetCurrent();
	}

	_au = v;

	if(_au)
	{
		try {
			UInt32 meteringMode = 1;
			result = AudioUnitSetProperty(_au, kAudioUnitProperty_MeteringMode, kAudioUnitScope_Input, 0, &meteringMode, sizeof(meteringMode) );
			if(result)
			{
				SDR_DEBUGPRINT(("Metering: AudioUnitSetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result));
			}
			else
			{
				SDR_DEBUGPRINT(("Metering mode enabled!\n"));
			}

			// now check the number of channels in the new queue, we will need to reallocate if this has changed
			CAStreamBasicDescription streamDesc;
			UInt32 size = sizeof(streamDesc);
			result = AudioUnitGetProperty(_au, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamDesc, &size);
			if(result) { SDR_DEBUGPRINT(("AudioUnitGetProperty result %d %08X %4.4s\n", (int)result, (int)result, (char*)&result)); }

			streamDesc.ChangeNumberChannels(1, FALSE);		// kluge - we only want one channel displayed

			if (streamDesc.NumberChannels() != [_channelNumbers count])
			{
				NSArray *chan_array;
				if (streamDesc.NumberChannels() < 2)
					chan_array = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], nil];
				else
					chan_array = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], [NSNumber numberWithInt:1], nil];

				[self setChannelNumbers:chan_array];
				[chan_array release];

				_chan_lvls = (AudioQueueLevelMeterState*)realloc(_chan_lvls, streamDesc.NumberChannels() * sizeof(AudioQueueLevelMeterState));
			}
		}
		catch (CAXException e) {
			char buf[256];
			fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		}
	}
#ifdef ENABLE_METER_FALLOFF
	else
	{
		if(_displayMeter) // avoid background crash
		{
			for(LevelMeter *thisMeter in _subLevelMeters)
			{
				[thisMeter setNeedsDisplay];
			}
		}
	}
#endif
}




- (CGFloat)refreshHz { return _refreshHz; }
- (void)setRefreshHz:(CGFloat)v
{
	_refreshHz = v;
	if(_updateTimer != nil)
	{
		[_updateTimer invalidate];
		_updateTimer = [NSTimer
						scheduledTimerWithTimeInterval:_refreshHz
						target:self
						selector:@selector(_refresh)
						userInfo:nil
						repeats:YES
						];
	}
}


- (void)sleep
{
	_sleeping = TRUE;
}


- (void)wake
{
	_sleeping = FALSE;

	if(_updateTimer == nil)
	{
		_updateTimer = [NSTimer
						scheduledTimerWithTimeInterval:_refreshHz
						target:self
						selector:@selector(_refresh)
						userInfo:nil
						repeats:YES
						];
	}
}

- (void)inBackground:(BOOL)background
{
	inBackground = background;
	_newMeter.inBackground = background;
}

- (BOOL)inBackground
{
	return inBackground;
}


- (NSArray *)channelNumbers { return _channelNumbers; }
- (void)setChannelNumbers:(NSArray *)v
{
	[v retain];
	[_channelNumbers release];
	_channelNumbers = v;
	[self layoutSubLevelMeters:kMinDBvalue];
}


- (BOOL)useGL { return _useGL; }
- (void)setUseGL:(BOOL)v
{
	_useGL = v;
	[self layoutSubLevelMeters:kMinDBvalue];
}

@end
