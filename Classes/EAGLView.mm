/*
 Third-party provenance: portions of this file are derived from Apple's
 aurioTouch/aurioTouch2 sample code.

 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

 File: EAGLView.m
 Abstract: This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView subclass. The view content is basically an EAGL surface you render your OpenGL scene into.  Note that setting the view non-opaque will only work if the EAGL surface has an alpha channel.
 Version: 1.11

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
#import <libkern/OSAtomic.h>

#import "product.h"
#import "EAGLView.h"
//#import "EAGLViewController.h"

#define USE_DEPTH_BUFFER 1

@interface EAGLView (EAGLViewPrivate)
- (BOOL)createFramebuffer;
- (void)destroyFramebuffer;
//- (void)setupSubviewsWithContentFrame:(CGRect)frameRect;
@end

@interface EAGLView (EAGLViewSprite)

- (void)setupView;

@end

@implementation EAGLView

@synthesize animationInterval;
@synthesize animationState;
@synthesize animationTimer;
@synthesize context;

//static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180.0;};

// You must implement this
+ (Class) layerClass
{
	return [CAEAGLLayer class];
}


- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];

#ifdef RETINA_DISPLAY_GL_SUPPORT
	CGFloat scaleFactor = 1;

	if([[UIScreen mainScreen] respondsToSelector:NSSelectorFromString(@"scale")])
	{
		if([self respondsToSelector:NSSelectorFromString(@"contentScaleFactor")])
		{
			scaleFactor = [[UIScreen mainScreen] scale];
			self.contentScaleFactor = scaleFactor;
		}
	}
#endif

	if(self)
	{
		layoutEnabled = TRUE;
		animationState = NO;
		viewFramebuffer = 0;
		viewRenderbuffer = 0;
		depthRenderbuffer = 0;

		// Get the layer
		CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
		eaglLayer.opaque = YES;
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];

		EAGLContext* eaglcxt = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
		self.context = eaglcxt;

		if(!context || ![EAGLContext setCurrentContext:context] || ![self createFramebuffer])
		{
			return nil;
		}

		animationInterval = 0.1; // Set a reasonable initial value; view controller can use setter method to change

		[self setupView];
		[self drawView];
	}

	return self;
}


- (void)layoutSubviews
{
	if(layoutEnabled)
	{
		SDR_DEBUGPRINT(("layoutSubviews!\n"));
		[EAGLContext setCurrentContext:context];
		//[self destroyFramebuffer];
		if([self createFramebuffer])
		{
			[self drawView];
		}
	}
}


//- (void)layoutSubviewsWithOverride
//{
//	SDR_DEBUGPRINT(("layoutSubviewsWithOverride!\n"));
//	[EAGLContext setCurrentContext:context];
//	[self destroyFramebuffer];
//	[self createFramebuffer];
//	[self drawView];
//}


- (void)enableLayout
{
	SDR_DEBUGPRINT(("--layout enabled!\n"));
	layoutEnabled = TRUE;
}


- (void)disableLayout
{
	SDR_DEBUGPRINT(("--layout disabled!\n"));
	layoutEnabled = FALSE;
}


- (BOOL)createFramebuffer
{
	static BOOL frameBufferExists = FALSE;

	if(!frameBufferExists)
	{
		SDR_DEBUGPRINT(("createFramebuffer\n"));
		glGenFramebuffersOES(1, &viewFramebuffer);
		glGenRenderbuffersOES(1, &viewRenderbuffer);

		//	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); // does not seem to resolve error below: GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT_OES

		glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
		[context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(id<EAGLDrawable>)self.layer];
		glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);

		glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
		glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);

		if(USE_DEPTH_BUFFER)
		{
			glGenRenderbuffersOES(1, &depthRenderbuffer);
			glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
			glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
			glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
		}

		//	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);


		if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
		{
			// GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT_OES == 8cd6
			NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		}
		else
		{
			frameBufferExists = TRUE;
		}
	}

	return frameBufferExists;
}


- (void)destroyFramebuffer
{
	SDR_DEBUGPRINT(("destroyFramebuffer\n"));
	if(viewFramebuffer)
	{
		SDR_DEBUGPRINT((" destroying viewFramebuffer\n"));
		glDeleteFramebuffersOES(1, &viewFramebuffer);
		viewFramebuffer = 0;
	}

	if(viewRenderbuffer)
	{
		SDR_DEBUGPRINT((" destroying viewRenderbuffer\n"));
		glDeleteRenderbuffersOES(1, &viewRenderbuffer);
		viewRenderbuffer = 0;
	}

	if(depthRenderbuffer)
	{
		SDR_DEBUGPRINT((" destroying depthRenderbuffer\n"));
		glDeleteRenderbuffersOES(1, &depthRenderbuffer);
		depthRenderbuffer = 0;
	}
}


- (void)startAnimation
{
	if(!animationState)
	{
		SDR_DEBUGPRINT(("startAnimation\n"));
		self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:animationInterval target:self selector:@selector(drawViewWithAnimation) userInfo:nil repeats:YES];

		animationState = YES;
	}
	else
	{
		SDR_DEBUGPRINT(("startAnimation: Already started. Start ignored.\n"));
	}

}


- (void)stopAnimation
{
	SDR_DEBUGPRINT(("stopAnimation\n"));
	if(animationState)
	{
		[animationTimer invalidate];
		self.animationTimer = nil;
		animationState = NO;
	}
	else
	{
		SDR_DEBUGPRINT(("stopAnimation: Already stopped. Stop ignored.\n"));
	}

}


- (void)setAnimationInterval:(NSTimeInterval)interval
{
	SDR_DEBUGPRINT(("setAnimationInterval\n"));
	animationInterval = interval;

	if(animationTimer)
	{
		[self stopAnimation];
		[self startAnimation];
	}
}


- (NSTimeInterval)getAnimationInterval
{
	return animationInterval;
}


- (void)setupView
{
	// Sets up matrices and transforms for OpenGL ES
	glViewport(0, 0, backingWidth, backingHeight);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrthof(0, backingWidth, 0, backingHeight, -1.0f, 1.0f);
	glMatrixMode(GL_MODELVIEW);

	// Clears the view with black
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

	glEnableClientState(GL_VERTEX_ARRAY);
	///glEnableClientState(GL_TEXTURE_COORD_ARRAY);

}

- (void)clearView:(BOOL)stopAnimation
{
	if(stopAnimation) [self stopAnimation];
	[EAGLContext setCurrentContext:context];
	glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
	[self drawView];
}

- (void)drawViewWithAnimation
{
	// Drawing on the main thread seems to eliminate some very nasty intermittent Open GL crashes observed when running iSDR
	// on iOS 7 while streaming to Air Play and changing audio routes by plugging in headphones.
	[self performBlockOnMainThread:^{

        if([self->delegate drawEnabled])
	{
		// Make sure that you are drawing to the current context
        [EAGLContext setCurrentContext:self->context];

        glBindFramebufferOES(GL_FRAMEBUFFER_OES, self->viewFramebuffer);

        [self->delegate drawViewWithAnimation];

		/*
		 glRotatef(3.0f, 0.0f, 0.0f, 1.0f);

		 glClear(GL_COLOR_BUFFER_BIT);
		 glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

		 */

        glBindRenderbufferOES(GL_RENDERBUFFER_OES, self->viewRenderbuffer);
        [self->context presentRenderbuffer:GL_RENDERBUFFER_OES];
	}
#ifdef SDR_DEBUG
	else
	{
		SDR_DEBUGPRINT(("Skipped drawView!\n"));
	}
#endif
	}];
}

- (void)performBlockOnMainThread:(ABasicBlock)block
{
	[self performSelectorOnMainThread:@selector(callBlock:) withObject:[block copy] waitUntilDone:[NSThread isMainThread]];
}


- (void)callBlock:(ABasicBlock)block
{
	block();
}

// External requests to redraw subviews results in this method being called
- (void)drawView
{
	if([delegate drawEnabled])
	{
		// Make sure that you are drawing to the current context
		[EAGLContext setCurrentContext:context];

		glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);

		[delegate drawView];

		/*
		 glRotatef(3.0f, 0.0f, 0.0f, 1.0f);

		 glClear(GL_COLOR_BUFFER_BIT);
		 glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

		 */

		glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
		[context presentRenderbuffer:GL_RENDERBUFFER_OES];
	}
#ifdef SDR_DEBUG
	else
	{
		SDR_DEBUGPRINT(("Skipped drawView!\n"));
	}
#endif
}


// Stop animating and release resources when they are no longer needed.

// ARC: support closing down - this needs to be called before deallocating EAGLView
- (void)dealloc
{
	[self stopAnimation];

	if([EAGLContext currentContext] == context)
	{
		[EAGLContext setCurrentContext:nil];
	}
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if([(id)delegate respondsToSelector:@selector(touchesBegan:withEvent:)])
		[delegate touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if([(id)delegate respondsToSelector:@selector(touchesMoved:withEvent:)])
		[delegate touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if([(id)delegate respondsToSelector:@selector(touchesEnded:withEvent:)])
		[delegate touchesEnded:touches withEvent:event];
}

- (id <EAGLViewDelegate>)delegate { return delegate; }
- (void)setDelegate:(id <EAGLViewDelegate>)v
{
	delegate = v;
}

@end
