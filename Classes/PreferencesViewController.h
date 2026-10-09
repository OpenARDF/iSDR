/*
 File: PreferencesViewController.h
 Abstract: The application's main view controller (front page).
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
#import <AvailabilityInternal.h>
#import "iSDRAppDelegate.h"
#import "CenterFrequencyViewController.h"
//#import "StoreViewController.h"

@protocol PreferencesViewControllerDelegate
@required
- (void)preferencesFinished;
- (void)applyRadioSettings:(BOOL)forceApply;
- (void)playKeypressBeep;
- (void)renewDefaults;
@optional
- (void)flushAudio;
@end


@interface PreferencesViewController : UITableViewController <UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource>
{
	NSMutableArray*				menuList;
	iSDRAppDelegate*			__weak appDelegate;
	UIPopoverPresentationController*    __weak popover;
	UIView*						__weak infoview;
	CGRect						buttonrect;

@private
	id <PreferencesViewControllerDelegate> __weak delegate;
	NSIndexPath*				__weak tableSelection;
	DefaultSettingsType			storedDefaultSettings;
	NSIndexPath*				tappedRowIndexPath;
}

- (void)preferencesFinished;
- (void)applyRadioSettings:(BOOL)forceApply;
- (IBAction)action:(id)sender;

@property (nonatomic, strong) IBOutlet UITableView*			tableView;

@property (nonatomic, strong) NSMutableArray*				menuList;
@property (weak) id <PreferencesViewControllerDelegate>		delegate;
@property (nonatomic, weak) NSIndexPath*					tableSelection;
@property (nonatomic, assign) DefaultSettingsType			storedDefaultSettings;
@property (nonatomic, strong) NSIndexPath*					tappedRowIndexPath;
@property (nonatomic, weak) iSDRAppDelegate*				appDelegate;
@property (nonatomic, weak) UIPopoverPresentationController*	popover;
@property (nonatomic, weak) UIView*							infoview;
@property (nonatomic, assign) CGRect						buttonrect;


@end
