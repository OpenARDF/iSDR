/*
 File: CenterFrequencyViewController.h
 Abstract: The view controller for hosting the UITextField features of this sample.
 Version: 2.6

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
#import "iSDRAppDelegate.h"

#define kFrequencyEntryTextFieldHeight 40.0
#define kFrequencyEntryTextFieldWidth  (IPAD_POPOVER_MENU_WIDTH_FOR_FREQUENCY_ENTRY - 100.)
//#define kFrequencyEntryTextFieldLeftMargin 50.

@interface CenterFrequencyViewController : UITableViewController <UITextFieldDelegate>
{
	UITextField*				textFieldNormal;
	NSMutableArray*				dataSourceArray;
	iSDRAppDelegate*			__weak appDelegate;
	NSMutableString*			defaultText;
	BOOL						viewAppearded;
}

@property (nonatomic, strong)	UITextField*		textFieldNormal;
@property (nonatomic, strong)	NSMutableArray*		dataSourceArray;
@property (nonatomic, strong)	NSMutableString*	defaultText;
@property (nonatomic, weak)	iSDRAppDelegate*	appDelegate;

- (frequencyType)getStoredCenterFrequency;
- (void)setStoredCenterFrequency:(frequencyType)freq;

@end
