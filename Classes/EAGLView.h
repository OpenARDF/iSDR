/*
 Third-party provenance: portions of this file are derived from Apple's
 aurioTouch/aurioTouch2 sample code.

 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 Apple's portions are distributed under the Apple Sample Code License in
 LICENSES/Apple-Sample-Code.txt. OpenARDF modifications are licensed under
 the MIT License in LICENSE.
*/


/*

 File: EAGLView.h
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

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>


typedef void (^ABasicBlock)(void);

@protocol EAGLViewDelegate
@required
- (void)drawView;
- (void)drawViewWithAnimation;
@optional
- (BOOL)drawEnabled;
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
@end

@class EAGLViewController;

@interface EAGLView : UIView
{

	BOOL animationState;

	//	EAGLViewController* eaglViewController;
@private

	/* The pixel dimensions of the backbuffer */
	GLint backingWidth;
	GLint backingHeight;

	EAGLContext *context;

	/* OpenGL names for the renderbuffer and framebuffers used to render to this view */
	GLuint viewRenderbuffer, viewFramebuffer;

	/* OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist) */
	GLuint depthRenderbuffer;

	/* OpenGL name for the sprite texture */
//	GLuint bgTexture;

	id <EAGLViewDelegate> delegate;

	NSTimer* animationTimer;
	NSTimeInterval animationInterval;

	BOOL layoutEnabled;
}

- (void)startAnimation;
- (void)stopAnimation;
- (void)drawView;
- (void)enableLayout;
- (void)disableLayout;
- (void)layoutSubviews;
- (void)setupView;
- (void)clearView:(BOOL)stopAnimation;


@property (nonatomic, strong)   EAGLContext*			context;
@property (nonatomic, assign)   NSTimeInterval animationInterval;
@property (weak)				id <EAGLViewDelegate>	delegate;
@property (nonatomic, assign)	BOOL					animationState;
@property (nonatomic, strong)	NSTimer*				animationTimer;

@end
