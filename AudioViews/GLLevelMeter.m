/*
 Third-party provenance: portions of this file are derived from Apple's
 SpeakHere audio-meter sample code.

 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

 File: GLLevelMeter.m
 Abstract: dB meter class for displaying audio power levels using OpenGL
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


#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

#import "GLLevelMeter.h"


@implementation GLLevelMeter

@synthesize eaglContext;

+ (Class) layerClass
{
	return [CAEAGLLayer class];
}

- (BOOL)_createFramebuffer
{
//	glReadPixels();
	if([[UIScreen mainScreen] respondsToSelector:NSSelectorFromString(@"scale")])
	{
		if([self respondsToSelector:NSSelectorFromString(@"contentScaleFactor")])
		{
			SDR_DEBUGPRINT(("1. GLLevelMeter::_createFramebuffer:scale = %f\n", self.contentScaleFactor));
		}
	}

	glGenFramebuffersOES(1, &_viewFramebuffer);
	glGenRenderbuffersOES(1, &_viewRenderbuffer);

	glBindFramebufferOES(GL_FRAMEBUFFER_OES, _viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, _viewRenderbuffer);
	[eaglContext renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(id<EAGLDrawable>)self.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, _viewRenderbuffer);

	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &_backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &_backingHeight);

	if (glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
		NSLog(@"Error: failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		return NO;
	}

	return YES;
}

- (void)_destroyFramebuffer
{
	glDeleteFramebuffersOES(1, &_viewFramebuffer);
	_viewFramebuffer = 0;
	glDeleteRenderbuffersOES(1, &_viewRenderbuffer);
	_viewRenderbuffer = 0;

}

- (void)_setupView
{
	CGFloat scale = 1.;

//	if([[UIScreen mainScreen] respondsToSelector:NSSelectorFromString(@"scale")])
//	{
//		if([self respondsToSelector:NSSelectorFromString(@"contentScaleFactor")])
//		{
//			scale = self.contentScaleFactor;
//		}
//
//		scale = 1.; // foobar
//	}

	SDR_DEBUGPRINT(("2. GLLevelMeter::_setupView:scale = %f\n", scale));
	// Sets up matrices and transforms for OpenGL ES
	glViewport(0, 0, _backingWidth * scale, _backingHeight * scale);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrthof(0, _backingWidth * scale, 0, _backingHeight * scale, -1.0f, 1.0f);
	glMatrixMode(GL_MODELVIEW);

	glEnableClientState(GL_VERTEX_ARRAY);
	glEnable(GL_BLEND);
	glDisable(GL_LINE_SMOOTH);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}


- (void)_performInit:(MeterOrientation)orientation dBWidth:(float)widthInDB dBMin:(float)minInDB
{
	inBackground = FALSE;

//#ifdef RETINA_DISPLAY_GL_SUPPORT
	CGFloat scaleFactor = 1.;

	if([[UIScreen mainScreen] respondsToSelector:NSSelectorFromString(@"scale")])
	{
		if([self respondsToSelector:NSSelectorFromString(@"contentScaleFactor")])
		{
			scaleFactor = [[UIScreen mainScreen] scale];
			self.contentScaleFactor = scaleFactor;
		}
	}
//#endif

	if([[UIScreen mainScreen] respondsToSelector:NSSelectorFromString(@"scale")])
	{
		if([self respondsToSelector:NSSelectorFromString(@"contentScaleFactor")])
		{
			SDR_DEBUGPRINT(("3. GLLevelMeter::_performInit:scale = %f\n", self.contentScaleFactor));
		}
	}

	_level = 0.;
	_peakLevel = -1.;
	_numLights = 0;
	_numColorThresholds = 3;
//	_variableLightIntensity = YES;
	_bgColor = [[UIColor alloc] initWithRed:0. green:0. blue:0. alpha:0.6];
	_borderColor = [[UIColor alloc] initWithRed:0. green:0. blue:0. alpha:1.];

	_colorThresholds = (LevelMeterColorThreshold*)malloc(_numColorThresholds * sizeof(LevelMeterColorThreshold));
	_orientation = orientation;

	switch(_orientation)
	{
		case VerticalBottomToTop:
			_vertical = YES;
			_reverseDirection = YES;
			break;
		case VerticalTopToBottom:
			_vertical = YES;
			_reverseDirection = NO;
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

	CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
	CGFloat scale = 1.;

	if([[UIScreen mainScreen] respondsToSelector:NSSelectorFromString(@"scale")])
	{
		if([self respondsToSelector:NSSelectorFromString(@"contentScaleFactor")])
		{
			scale = [[UIScreen mainScreen] scale];
			self.contentScaleFactor = scale;
		}

//		scale = 1.; // foobar
	}


	self.opaque = NO;
	eaglLayer.opaque = NO;

	eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
									[NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];

	EAGLContext* c = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
	self.eaglContext = c;
	[c release];

	if(!eaglContext || ![EAGLContext setCurrentContext:eaglContext] || ![self _createFramebuffer]) {
		[self release];
		return;
	}

	int largeBlocks = 0;
	float remainder = 0.;

	if(widthInDB < 0.) widthInDB = -widthInDB;

	if(widthInDB > 54.)
	{
		largeBlocks = ((int)(widthInDB - 54.)) / 10;
		remainder = widthInDB - 54. - 10.*largeBlocks;
		_numLights = 9 + largeBlocks;
		if(remainder > 0.) _numLights++;
		_colorThresholds[0].maxValue = 54./widthInDB;
		_colorThresholds[1].maxValue = 0.889;
//		_colorThresholds[2].maxValue = 0.889;
//		_colorThresholds[3].maxValue = 0.956;
		_colorThresholds[2].maxValue = 1.;
	}
	else
	{
		_numLights = widthInDB / 6.;
		_colorThresholds[0].maxValue = 1.;
		_colorThresholds[1].maxValue = 0.889;
//		_colorThresholds[2].maxValue = 0.889;
//		_colorThresholds[3].maxValue = 0.956;
		_colorThresholds[2].maxValue = 1.;
	}

	_colorThresholds[0].color = [[UIColor alloc] initWithRed:0. green:1. blue:0. alpha:1.];
	_colorThresholds[1].color = [[UIColor alloc] initWithRed:1. green:1. blue:0. alpha:1.];
//	_colorThresholds[2].color = [[UIColor alloc] initWithRed:1. green:.5 blue:0. alpha:1.];
//	_colorThresholds[3].color = [[UIColor alloc] initWithRed:1. green:0. blue:0. alpha:1.];
	_colorThresholds[2].color = [[UIColor alloc] initWithRed:.5 green:0. blue:1. alpha:1.];

	SDR_DEBUGPRINT(("Meter dB width = %f;  Meter segments = %lu; 10dB segments = %d; Extra seg = %fdB\n", widthInDB, (unsigned long)_numLights, largeBlocks, remainder));

	_lightRectArray = (CGRect*)malloc(_numLights * sizeof(CGRect));
	_lightRectThresholdArray = (float*)malloc(_numLights * sizeof(float));

	float sUnitfactor = (54. / (9.*widthInDB));
	float tenDBUnitFactor = ((widthInDB - 54. - remainder)/(largeBlocks * widthInDB));
	float remainderFactor = remainder / widthInDB;
	float position = 0.;
	CGRect bds;

	if(_vertical)
	{
		bds = [self bounds];
	}
	else
	{
		bds = CGRectMake(0., 0., [self bounds].size.height, [self bounds].size.width);
	}

	SDR_DEBUGPRINT(("\nMeter bounds: origin.x=%f .y=%f size.width=%f size.height=%f \n\n", bds.origin.x, bds.origin.y, bds.size.width, bds.size.height));

	float lightThreshold = 0.;
	for(int j=0; j<_numLights; j++)
	{
		if(j<9)
		{
			if(_reverseDirection)
			{
				_lightRectArray[j] = CGRectMake(
											   0.,
											   (bds.size.height - position) * scale, // Reverse direction of bar climb
											   bds.size.width * scale,
											   bds.size.height * sUnitfactor * scale
											   );

			}
			else
			{
				_lightRectArray[j] = CGRectMake(
											   0.,
											   position * scale, // Reverse direction of bar climb
											   bds.size.width * scale,
											   bds.size.height * sUnitfactor * scale
											   );

			}

			_lightRectThresholdArray[j] = lightThreshold / widthInDB;
			_lightRectThresholdArray[j] = LEVELMETER_CLAMP(1. / widthInDB, _lightRectThresholdArray[j], 1.);
			lightThreshold += 6.; // 6dB per light

			position += bds.size.height * sUnitfactor;

			SDR_DEBUGPRINT(("\nLight #%d. position= %f\n", j, position));

		}
		else
		{
			if(j<_numLights-1)
			{
				if(_reverseDirection)
				{
					_lightRectArray[j] = CGRectMake(
												   0.,
												   (bds.size.height - position) * scale, // Reverse direction of bar climb
												   bds.size.width * scale,
												   bds.size.height * tenDBUnitFactor * scale
												   );
				}
				else
				{
					_lightRectArray[j] = CGRectMake(
												   0.,
												   position * scale, // Reverse direction of bar climb
												   bds.size.width * scale,
												   bds.size.height * tenDBUnitFactor * scale
												   );

				}

				_lightRectThresholdArray[j] = lightThreshold / widthInDB;
				lightThreshold += 10.; // 10 dB per light

				position += bds.size.height * tenDBUnitFactor;

				SDR_DEBUGPRINT(("\nLight #%d. position= %f\n", j, position));
			}
			else if(remainderFactor != 0.)
			{
				if(_reverseDirection)
				{
					_lightRectArray[j] = CGRectMake(
												   0.,
												   (bds.size.height - position) * scale, // Reverse direction of bar climb
												   bds.size.width * scale,
												   bds.size.height * remainderFactor * scale
												   );
				}
				else
				{
					_lightRectArray[j] = CGRectMake(
												   0.,
												   position * scale, // Reverse direction of bar climb
												   bds.size.width * scale,
												   bds.size.height * remainderFactor * scale
												   );

				}

				_lightRectThresholdArray[j] = 1.;
			}
		}
	}

	[self _setupView];
}



- (void)clearView:(BOOL)stopAnimation
{
//	if(stopAnimation) [self stopAnimation];
	[EAGLContext setCurrentContext:eaglContext];
	glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
	//	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	[self _drawView];
}

- (void)_drawView
{
	if(!_viewFramebuffer) return;
	if(inBackground) return;

//	SDR_DEBUGPRINT(("4. GLLevelMeter::_drawView = %f\n", self.contentScaleFactor));
	// Make sure that you are drawing to the current context
	[EAGLContext setCurrentContext:eaglContext];

	glBindFramebufferOES(GL_FRAMEBUFFER_OES, _viewFramebuffer);

	CGColorRef bgc = self.bgColor.CGColor;

	if (CGColorGetNumberOfComponents(bgc) != 4) goto bail;

	const CGFloat *bg_rgba;

	bg_rgba = CGColorGetComponents(bgc);

	glClearColor(0., 0., 0., 0.);
	glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);

	glPushMatrix();

	CGRect bds;

//	if(_vertical)
//	{
//		glTranslatef(0., [self bounds].size.height, 0.);
//		glScalef(1., -1., 1.);
//		bds = [self bounds];
//	}
//	else
//	{
//		glTranslatef(0., [self bounds].size.height, 0.);
//		glRotatef(-90., 0., 0., 1.);
//		bds = CGRectMake(0., 0., [self bounds].size.height, [self bounds].size.width);
//	}

	if (_vertical)
	{
		glTranslatef(0., _backingWidth, 0.);
		glScalef(1., -1., 1.);
		bds = CGRectMake(0., 0., _backingWidth, _backingHeight);
	} else
	{
		glTranslatef(0., _backingHeight, 0.);
		glRotatef(-90., 0., 0., 1.);
		bds = CGRectMake(0., 0., _backingHeight, _backingWidth);
	}


	if(_numLights == 0)
	{
		int i;
		CGFloat currentTop = 0.;

		for (i=0; i<_numColorThresholds; i++)
		{
			LevelMeterColorThreshold thisThresh = _colorThresholds[i];
			CGFloat val = MIN(thisThresh.maxValue, _level);

			CGRect rect = CGRectMake(
									 0,
									 (bds.size.height) * currentTop,
									 bds.size.width,
									 (bds.size.height) * (val - currentTop)
									 );

			SDR_DEBUGPRINT(("\nMeter rect: origin.x=%f .y=%f size.width=%f size.height=%f \n\n", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height));

			GLfloat vertices[] =
			{
				(GLfloat)CGRectGetMinX(rect), (GLfloat)CGRectGetMinY(rect),
				(GLfloat)CGRectGetMaxX(rect), (GLfloat)CGRectGetMinY(rect),
				(GLfloat)CGRectGetMinX(rect), (GLfloat)CGRectGetMaxY(rect),
				(GLfloat)CGRectGetMaxX(rect), (GLfloat)CGRectGetMaxY(rect),
			};

			CGColorRef clr = thisThresh.color.CGColor;
			if (CGColorGetNumberOfComponents(clr) != 4) goto bail;
			const CGFloat *rgba;
			rgba = CGColorGetComponents(clr);
			glColor4f(rgba[0], rgba[1], rgba[2], rgba[3]);


			glVertexPointer(2, GL_FLOAT, 0, vertices);
			glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);


			if (_level < thisThresh.maxValue) break;

			currentTop = val;
		}
	}
	else
	{
		int light_i;
		CGFloat lightMinVal = 0.;
		CGFloat insetAmount, lightVSpace;
		lightVSpace = bds.size.height / (CGFloat)_numLights;
		if (lightVSpace < 4.)
		{
			insetAmount = 0.;
		}
		else if (lightVSpace < 8.)
		{
			insetAmount = 0.5;
		}
		else
		{
			insetAmount = 1.;
		}

		int peakLight = -1;
		if(_peakLevel > 0.)
		{
			int i;
			for(i=0; _peakLevel>_lightRectThresholdArray[i] && i<_numLights; i++);
			peakLight = i;

			if (peakLight >= _numLights) peakLight = (int)(_numLights - 1);
		}

		for(light_i=0; light_i<_numLights; light_i++)
		{
			CGFloat lightIntensity;
			CGFloat lightMaxVal = _lightRectThresholdArray[light_i]; //(CGFloat)(light_i + 1) / (CGFloat)_numLights;
			CGRect lightRect;
			UIColor *lightColor;

#ifdef SDR_DEBUG
			if(lightMaxVal == lightMinVal)
			{
				printf("\n\nGLLevelMeter Error!! must initialize lightMaxVal to a non-zero value.\n\n");
			}
#endif

			if(light_i == peakLight)
			{
				lightIntensity = 1.;
			}
			else
			{
				//				SDR_DEBUGPRINT(("_level=%f lightMinVal=%f\n", _level, lightMinVal));
				lightIntensity = (_level - lightMinVal) / (lightMaxVal - lightMinVal);
				lightIntensity = LEVELMETER_CLAMP(0., lightIntensity, 1.);
				//				if((!_variableLightIntensity) && (lightIntensity > 0.)) lightIntensity = 1.;
			}

			lightColor = _colorThresholds[0].color;
			int color_i;
			for(color_i=0; color_i<(_numColorThresholds-1); color_i++)
			{
				LevelMeterColorThreshold thisThresh = _colorThresholds[color_i];
				LevelMeterColorThreshold nextThresh = _colorThresholds[color_i + 1];
				if(thisThresh.maxValue <= lightMaxVal) lightColor = nextThresh.color;
			}

			lightRect = _lightRectArray[light_i];

			lightRect = CGRectInset(lightRect, insetAmount, insetAmount);

//			SDR_DEBUGPRINT(("\nMeter lightRect: origin.x=%f .y=%f size.width=%f size.height=%f \n\n", lightRect.origin.x, lightRect.origin.y, lightRect.size.width, lightRect.size.height));

			GLfloat vertices[] =
			{
				(GLfloat)CGRectGetMinX(lightRect), (GLfloat)CGRectGetMinY(lightRect),
				(GLfloat)CGRectGetMaxX(lightRect), (GLfloat)CGRectGetMinY(lightRect),
				(GLfloat)CGRectGetMinX(lightRect), (GLfloat)CGRectGetMaxY(lightRect),
				(GLfloat)CGRectGetMaxX(lightRect), (GLfloat)CGRectGetMaxY(lightRect),
			};

			CGColorRef clr = lightColor.CGColor;
			if (CGColorGetNumberOfComponents(clr) != 4) goto bail;
			const CGFloat *rgba;
			rgba = CGColorGetComponents(clr);

			glVertexPointer(2, GL_FLOAT, 0, vertices);

			glColor4f(bg_rgba[0], bg_rgba[1], bg_rgba[2], bg_rgba[3]);
			glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

			GLfloat lightAlpha = rgba[3] * lightIntensity;
			if((lightIntensity < 1.) && (lightIntensity > 0.) && (lightAlpha > .8)) lightAlpha = .8;

			glColor4f(rgba[0], rgba[1], rgba[2], lightAlpha);
			glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

			lightMinVal = lightMaxVal;
		}
	}

bail:
	glPopMatrix();

	glFlush();
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, _viewRenderbuffer);
	[eaglContext presentRenderbuffer:GL_RENDERBUFFER_OES];
}


- (void)layoutSubviews
{
	[EAGLContext setCurrentContext:eaglContext];
	[self _destroyFramebuffer];
	[self _createFramebuffer];
	[self _drawView];
}


- (void)drawRect:(CGRect)rect
{
	[self _drawView];
}


- (void)setNeedsDisplay
{
	[self _drawView];
}


- (void)dealloc
{
	if([EAGLContext currentContext] == eaglContext)
	{
		[EAGLContext setCurrentContext:nil];
	}

	self.eaglContext = nil;
	[super dealloc];
}



@end
