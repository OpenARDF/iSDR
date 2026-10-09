/*
 File: PreferencesViewController.m
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

#import "product.h"
#import "Constants.h"
#import <AvailabilityInternal.h>
#import "CAXException.h"
#import "PreferencesViewController.h"
#import "CenterFrequencyViewController.h"
#import "AboutViewController.h"
#import "iSDRAppDelegate.h"
#import "DITableViewController.h"

#define ABOUT_ROW 0
#define ON_OFF_LINE_ROW 1
#define IQ_REVERSAL_ROW 2
#define CENTER_FREQUENCY_ROW 3
#define FILES_ROW 4
#define WIFI_ENABLE_ROW 5

static NSString *kCellIdentifier = @"MyIdentifier";

@implementation PreferencesViewController
{
//	id<RMStoreReceiptVerifier> _receiptVerificator;
//    RMStoreKeychainPersistence *_persistence;
}

@dynamic tableView;

@synthesize menuList;
@synthesize delegate;
@synthesize tableSelection;
@synthesize storedDefaultSettings;
@synthesize tappedRowIndexPath;
@synthesize appDelegate;
@synthesize popover;
@synthesize infoview, buttonrect;


- (void)viewDidLoad
{
	[super viewDidLoad];

	SDR_DEBUGPRINT(("PVC: viewDidLoad!\n"));

	self.title = NSLocalizedString(@"Options", nil);

	// construct the array of page descriptions we will use (each description is a dictionary)
	self.menuList = [NSMutableArray new];

	storedDefaultSettings = appDelegate.defaults;
	AboutViewController *aboutViewController;

	// for showing UITextView:
	if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
	{
		if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
		{
			aboutViewController = [[AboutViewController alloc]
								   initWithNibName:@"AboutViewController8plus_iPad" bundle:nil];
		}
		else
		{
			aboutViewController = [[AboutViewController alloc]
								   initWithNibName:@"AboutViewController8plus" bundle:nil];

		}
	}
	else if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
	{
		if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
		{
			aboutViewController = [[AboutViewController alloc]
								   initWithNibName:@"AboutViewController_iPad" bundle:nil];
		}
		else
		{
			aboutViewController = [[AboutViewController alloc]
								   initWithNibName:@"AboutViewController" bundle:nil];

		}
	}
	else
	{
		if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
		{
			aboutViewController = [[AboutViewController alloc]
								   initWithNibName:@"AboutViewController_old_iPad" bundle:nil];
		}
		else
		{
			aboutViewController = [[AboutViewController alloc]
								   initWithNibName:@"AboutViewController_old" bundle:nil];

		}
	}

	aboutViewController.appDelegate = appDelegate;
	[self.menuList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedString(@"AboutViewTitle", @""), kTitleKey,
							  aboutViewController, kViewControllerKey,
							  nil]];


	NSString* cellMessage;

	// Cell for selecting off-line-only mode
	if(storedDefaultSettings.demoModeOnly == TRUE)
	{
		cellMessage = [NSString stringWithFormat:@"%@",NSLocalizedString(@"OffLineModeON", @"")];
	}
	else
	{
		cellMessage = [NSString stringWithFormat:@"%@",NSLocalizedString(@"OffLineModeOFF", @"")];
	}

	[self.menuList addObject:[NSDictionary dictionaryWithObjectsAndKeys: cellMessage, kTitleKey,
							  nil]];


	// Cell for selecting to reverse I/Q logic
	if(storedDefaultSettings.reverseIQ == TRUE)
	{
		cellMessage = [NSString stringWithFormat:@"%@",NSLocalizedString(@"ReverseIQON", @"")];
	}
	else
	{
		cellMessage = [NSString stringWithFormat:@"%@",NSLocalizedString(@"ReverseIQOFF", @"")];
	}

	[self.menuList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							  cellMessage, kTitleKey,
							  nil]];


	// Center Frequency ----------------------------------------------------------------------------------

	cellMessage = [NSString stringWithFormat:@"%@: %4.3lf kHz",NSLocalizedString(@"CenterFreqTitle", @""), storedDefaultSettings.centerFrequency];

	CenterFrequencyViewController*	textFieldViewController;

	if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		// UITextField for center frequency setting:
		textFieldViewController = [[CenterFrequencyViewController alloc] initWithNibName:@"CenterFrequencyViewController_iPad" bundle:nil];
	}
	else
	{
		// UITextField for center frequency setting:
		textFieldViewController = [[CenterFrequencyViewController alloc]
								   initWithNibName:@"CenterFrequencyViewController" bundle:nil];
	}

	textFieldViewController.appDelegate = appDelegate;
	[self.menuList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							  cellMessage, kTitleKey,
							  textFieldViewController, kViewControllerKey,
							  nil]];


	// Files Access ----------------------------------------------------------------------------------

	// Check whether operating system supports file downloads
	Class classUIDocumentInteractionController = NSClassFromString(@"UIDocumentInteractionController");
	if(classUIDocumentInteractionController != nil)
	{
		// for showing UITextView:
		DITableViewController *docInteractTVC;

		if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
		{

			docInteractTVC = [[DITableViewController alloc]
							  initWithNibName:@"DITableViewController_iPad" bundle:nil];

		}
		else
		{
			docInteractTVC = [[DITableViewController alloc]
							  initWithNibName:@"DITableViewController" bundle:nil];
		}

		docInteractTVC.delegate = (id)delegate;
		SDR_DEBUGPRINT(("Setting menuList for Files view controller\n"));
		[self.menuList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
								  NSLocalizedString(@"FilesTitle", @""), kTitleKey,
								  docInteractTVC, kViewControllerKey,
								  nil]];

	}


    if(storedDefaultSettings.wifiFunctionalityEnabled == TRUE)
    {
        cellMessage = [NSString stringWithFormat:@"%@",NSLocalizedString(@"WiFiEnabled", @"")];
    }
    else
    {
        cellMessage = [NSString stringWithFormat:@"%@",NSLocalizedString(@"WiFiDisabled", @"")];
    }

    [self.menuList addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                              cellMessage, kTitleKey,
                              nil]];


	// END ----------------------------------------------------------------------------------

	// Create navigation bar's "done" button and point it to the exit method
	UIBarButtonItem *temporaryBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"") style:UIBarButtonItemStylePlain target:self action:@selector(action:)];
	self.navigationItem.leftBarButtonItem = temporaryBarButtonItem;

	tappedRowIndexPath = nil;
}

- (IBAction)action:(id)sender
{
	SDR_DEBUGPRINT(("PVC: action:(id)sender!\n"));
	[self preferencesFinished];
	// the custom icon button was clicked, handle it here
}


- (void)preferencesFinished
{
	SDR_DEBUGPRINT(("PVC: preferencesFinished!\n"));

	self.tappedRowIndexPath = nil;
	[[self navigationController] popToRootViewControllerAnimated:TRUE];

//    popoverPresentationController

	[self setStoredDefaults:storedDefaultSettings];
	[delegate preferencesFinished];
}


- (void)applyRadioSettings:(BOOL)forceApply
{
	SDR_DEBUGPRINT(("PVC: applyRadioSettings!\n"));
	[self setStoredDefaults:storedDefaultSettings];
	[delegate applyRadioSettings:forceApply];
}


#pragma mark -
#pragma mark UIViewController delegate

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

//	[self getStoredDefaults:&storedDefaultSettings];
	[delegate playKeypressBeep];

	if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
		if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0"))
#endif
		{
			self.preferredContentSize = CGSizeMake(IPAD_POPOVER_MENU_WIDTH, IPAD_POPOVER_MENU_HEIGHT);
		}
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
		else
		{
			self.contentSizeForViewInPopover = CGSizeMake(IPAD_POPOVER_MENU_WIDTH, IPAD_POPOVER_MENU_HEIGHT);
		}
#endif

		DefaultSettingsType currentDefaultSettings = appDelegate.defaults;
		[delegate renewDefaults]; // sync up the display ASAP

		if((storedDefaultSettings.reverseIQ != currentDefaultSettings.reverseIQ) || (storedDefaultSettings.demoModeOnly != currentDefaultSettings.demoModeOnly))
		{
			[self applyRadioSettings:FALSE];
		}

//		[self.popover presentPopoverFromRect:self.buttonrect
//									  inView:self.infoview
//					permittedArrowDirections:UIPopoverArrowDirectionAny
//									animated:NO];

		// iPad only: Calling reloadData here seems to be necessary to ensure that
		// the table redraws if settings have been changed by one of the child
		// view controllers (e.g., fileHandler)
		[self.tableView reloadData];
		[delegate flushAudio];
	}
	else
	{
		[self.tableView reloadData];
	}
}


- (void)viewDidAppear:(BOOL)animated
{
	// Calling reloadData here seems to be necessary to ensure that the
	// table redraws if settings have been changed by one of the child
	// view controllers (e.g., fileHandler)
	SDR_DEBUGPRINT(("Prefs view did appear!\n"));
	storedDefaultSettings = appDelegate.defaults;
	[self.tableView reloadData]; //
	[super viewDidAppear:animated];
	[delegate flushAudio];

	if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
        self.popover.sourceRect = CGRectMake(popover.sourceRect.origin.x,popover.sourceRect.origin.y,IPAD_POPOVER_MENU_WIDTH, IPAD_POPOVER_MENU_HEIGHT);

        self.popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
	}
}


#pragma mark -
#pragma mark UITableViewDelegate

// A row has been selected: switch to that item's UIViewController
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	self.tappedRowIndexPath = nil;
	self.tappedRowIndexPath = indexPath;

	UIViewController *targetViewController = [[self.menuList objectAtIndex: indexPath.row] objectForKey:kViewControllerKey];

	SDR_DEBUGPRINT(("PVC: row selected!\n"));
	switch(tappedRowIndexPath.row)
	{
		case ABOUT_ROW: // About iSDR
		{
			if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
			{
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
				if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0"))
#endif
				{
					targetViewController.preferredContentSize = CGSizeMake(IPAD_POPOVER_MENU_WIDTH_FOR_ABOUT_PAGE, IPAD_POPOVER_MENU_HEIGHT_FOR_ABOUT_PAGE);
				}
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
				else
				{
					targetViewController.contentSizeForViewInPopover = CGSizeMake(IPAD_POPOVER_MENU_WIDTH_FOR_ABOUT_PAGE, IPAD_POPOVER_MENU_HEIGHT_FOR_ABOUT_PAGE);
				}
#endif

					[self.navigationController pushViewController:targetViewController animated:NO];
			}
			else
			{
				[self.navigationController pushViewController:targetViewController animated:YES];
			}
		}
			break;

		// These rows require additional user input to accept changes
		case ON_OFF_LINE_ROW: // Online/Offline
		case IQ_REVERSAL_ROW: // I/Q
        case WIFI_ENABLE_ROW: // WiFi Enable
			[self tableView:self.tableView accessoryButtonTappedForRowWithIndexPath:indexPath];
			break;

		case CENTER_FREQUENCY_ROW: // Center Frequency
		{
			if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
			{
//				targetViewController.modalInPopover = TRUE; // prevent touches outside popover from dismissing the view

#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
				if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0"))
#endif
				{
					targetViewController.preferredContentSize = CGSizeMake(IPAD_POPOVER_MENU_WIDTH_FOR_FREQUENCY_ENTRY, IPAD_POPOVER_MENU_HEIGHT_FOR_FREQUENCY_ENTRY);
				}
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
				else
				{
					targetViewController.contentSizeForViewInPopover = CGSizeMake(IPAD_POPOVER_MENU_WIDTH_FOR_FREQUENCY_ENTRY, IPAD_POPOVER_MENU_HEIGHT_FOR_FREQUENCY_ENTRY);
				}
#endif

				[self.navigationController pushViewController:targetViewController animated:NO];
			}
			else
			{
				[self.navigationController pushViewController:targetViewController animated:YES];
			}
		}
			break;

		// Files
		case FILES_ROW:
		{
			// Check whether operating system supports file downloads
			Class classUIDocumentInteractionController = NSClassFromString(@"UIDocumentInteractionController");
			if(classUIDocumentInteractionController == nil) break;

			if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
			{
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
				if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0"))
#endif
				{
					targetViewController.preferredContentSize = CGSizeMake(IPAD_POPOVER_MENU_WIDTH, IPAD_POPOVER_MENU_HEIGHT);
				}
#if (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0)
				else
				{
					targetViewController.contentSizeForViewInPopover = CGSizeMake(IPAD_POPOVER_MENU_WIDTH, IPAD_POPOVER_MENU_HEIGHT);
				}
#endif

				[self.navigationController pushViewController:targetViewController animated:YES];
			}
			else
			{
				SDR_DEBUGPRINT(("Calling Files view controller...\n"));
				[self.navigationController pushViewController:targetViewController animated:YES];
			}
		}
			break;


		default:
			SDR_DEBUGPRINT(("Non-existent row selected in PreferencesViewController: %ld\n", (long)tappedRowIndexPath.row));
			break;
	}

	// find the cell being touched and update its checked/unchecked image
	//	CustomCell *targetCustomCell = (CustomCell *)[tableView cellForRowAtIndexPath:indexPath];
	//	[targetCustomCell checkAction:nil];

	// don't keep the table selection
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	SDR_DEBUGPRINT(("row selected: %ld\n", (long)indexPath.row));

	[delegate playKeypressBeep];

	// update our data source array with the new checked state
	//	NSMutableDictionary *selectedItem = [self.dataArray objectAtIndex:indexPath.row];
	//	[selectedItem setObject:[NSNumber numberWithBool:targetCustomCell.checked] forKey:@"checked"];
}


#pragma mark -
#pragma mark UITableViewDataSource

// tell our table how many rows it will have, in our case the size of our menuList
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSInteger rows = [self.menuList count];
	return rows;
}


//- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
//{
//	SDR_DEBUGPRINT(("Will display cell!!!!\n"));
//	tappedRowIndexPath = indexPath;
//}

// Provide kind of cell to use and its title for the given row
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString* cellMessage;

	SDR_DEBUGPRINT(("PVC: providing cell info\n"));
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
	if(cell == nil)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifier];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	else
	{
		cell.accessoryView = nil;
	}

	//=============================
	switch(indexPath.row)
	{
		case ON_OFF_LINE_ROW: // Online/Offline
		{
			// Cell for selecting off-line-only mode
			if(storedDefaultSettings.demoModeOnly == TRUE)
			{
				cellMessage = [NSString stringWithFormat:@"%@",NSLocalizedString(@"OffLineModeON", @"")];
			}
			else
			{
				cellMessage = [NSString stringWithFormat:@"%@",NSLocalizedString(@"OffLineModeOFF", @"")];
			}

			SDR_DEBUGPRINT(("demoModeOnly: %s cell2 text: %s\n",(storedDefaultSettings.demoModeOnly) ? "Yes":"No", [cellMessage UTF8String]));

			[self.menuList replaceObjectAtIndex:indexPath.row withObject:[NSDictionary dictionaryWithObjectsAndKeys:cellMessage, kTitleKey, nil]];

			UIImage *image = (!storedDefaultSettings.demoModeOnly) ? [UIImage imageNamed:@"micused.png"] : [UIImage imageNamed:@"nomicused.png"];

			// SDR_DEBUGPRINT(("Setting demo mode check image = %d\n",storedDefaultSettings.demoModeOnly));
			UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
			CGRect frame = CGRectMake(0.0, 0.0, image.size.width, image.size.height);
			button.frame = frame;	// match the button's size with the image size

			[button setBackgroundImage:image forState:UIControlStateNormal];

			// set the button's target to this table view controller so we can interpret touch events and map that to a NSIndexSet
			[button addTarget:self action:@selector(checkButtonTapped:event:) forControlEvents:UIControlEventTouchUpInside];
			button.backgroundColor = [UIColor clearColor];
			cell.accessoryView = button;
		}
			break;

		case IQ_REVERSAL_ROW: // I/Q
		{
			// Cell for selecting to reverse I/Q logic
			if(storedDefaultSettings.reverseIQ == TRUE)
			{
				cellMessage = [NSString stringWithFormat:@"%@",NSLocalizedString(@"ReverseIQON", @"")];
			}
			else
			{
				cellMessage = [NSString stringWithFormat:@"%@",NSLocalizedString(@"ReverseIQOFF", @"")];
			}

			[self.menuList replaceObjectAtIndex:indexPath.row withObject:[NSDictionary dictionaryWithObjectsAndKeys: cellMessage, kTitleKey, nil]];

			UIImage *image = (storedDefaultSettings.reverseIQ) ? [UIImage imageNamed:@"qi.png"] : [UIImage imageNamed:@"iq.png"];

			UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
			CGRect frame = CGRectMake(0.0, 0.0, image.size.width, image.size.height);
			button.frame = frame;	// match the button's size with the image size

			[button setBackgroundImage:image forState:UIControlStateNormal];

			// set the button's target to this table view controller so we can interpret touch events and map that to a NSIndexSet
			[button addTarget:self action:@selector(checkButtonTapped:event:) forControlEvents:UIControlEventTouchUpInside];
			button.backgroundColor = [UIColor clearColor];
			cell.accessoryView = button;
		}
			break;


        case WIFI_ENABLE_ROW: // WIFI
        {
            // Cell for selecting to enable WiFi
            if(storedDefaultSettings.wifiFunctionalityEnabled == TRUE)
            {
                cellMessage = [NSString stringWithFormat:@"%@",NSLocalizedString(@"WiFiEnabled", @"")];
            }
            else
            {
                cellMessage = [NSString stringWithFormat:@"%@",NSLocalizedString(@"WiFiDisabled", @"")];
            }

            [self.menuList replaceObjectAtIndex:indexPath.row withObject:[NSDictionary dictionaryWithObjectsAndKeys: cellMessage, kTitleKey, nil]];

//            UIImage *image = (storedDefaultSettings.wifiFunctionalityEnabled) ? [UIImage imageNamed:@"qi.png"] : [UIImage imageNamed:@"iq.png"];

            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
//            CGRect frame = CGRectMake(0.0, 0.0, image.size.width, image.size.height);
//            button.frame = frame;    // match the button's size with the image size
//
//            [button setBackgroundImage:image forState:UIControlStateNormal];

            // set the button's target to this table view controller so we can interpret touch events and map that to a NSIndexSet
            [button addTarget:self action:@selector(checkButtonTapped:event:) forControlEvents:UIControlEventTouchUpInside];
            button.backgroundColor = [UIColor clearColor];
            cell.accessoryView = button;
        }
            break;



		case CENTER_FREQUENCY_ROW: // Center Frequency
		{
            // UITextField for center frequency setting:
			cellMessage = [NSString stringWithFormat:@"%@: %4.3lf kHz",NSLocalizedString(@"CenterFreqTitle", @""), storedDefaultSettings.centerFrequency];
			CenterFrequencyViewController*	textFieldViewController;

			if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
			{
				// UITextField for center frequency setting:
				textFieldViewController = [[CenterFrequencyViewController alloc] initWithNibName:@"CenterFrequencyViewController_iPad" bundle:nil];
			}
			else
			{
				// UITextField for center frequency setting:
				textFieldViewController = [[CenterFrequencyViewController alloc] initWithNibName:@"CenterFrequencyViewController" bundle:nil];
			}

			textFieldViewController.appDelegate = appDelegate;
			[self.menuList replaceObjectAtIndex:indexPath.row withObject:[NSDictionary dictionaryWithObjectsAndKeys: cellMessage, kTitleKey, textFieldViewController, kViewControllerKey, nil]];
		}
			break;

		default:
			break;
	}

	cell.textLabel.text = [[self.menuList objectAtIndex:indexPath.row] objectForKey:kTitleKey];
	// cell's title label properties
	cell.textLabel.backgroundColor = cell.backgroundColor;
	cell.textLabel.opaque = NO;
	cell.textLabel.textColor = [UIColor blackColor];
	cell.textLabel.highlightedTextColor = [UIColor whiteColor];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:18.0];

	return cell;
}


- (void)checkButtonTapped:(id)sender event:(id)event
{
    NSSet *touches = [event allTouches];
	UITouch *touch = [touches anyObject];
	CGPoint currentTouchPosition = [touch locationInView:self.tableView];
	NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint: currentTouchPosition];
	if(indexPath != nil)
	{
        SDR_DEBUGPRINT(("PVC: button tapped on row %ld!\n", (long)indexPath.row));
		self.tappedRowIndexPath = nil;
		self.tappedRowIndexPath = indexPath;

		[self tableView: self.tableView accessoryButtonTappedForRowWithIndexPath: indexPath];
	}
}


- (void)alertDidDismissWithButtonIndex:(NSInteger)buttonIndex
{
	SDR_DEBUGPRINT(("PVC: alertView did dismiss!\n"));

	[delegate playKeypressBeep];

	switch(tappedRowIndexPath.row)
	{
		case ON_OFF_LINE_ROW:
		{
			if(buttonIndex != 0)
			{
				storedDefaultSettings.demoModeOnly = !storedDefaultSettings.demoModeOnly;
				[self setStoredDefaults:storedDefaultSettings];
				[self tableView: self.tableView cellForRowAtIndexPath:tappedRowIndexPath];
				[self.tableView reloadData];
				[self applyRadioSettings:FALSE];
			}
		}
			break;

        case IQ_REVERSAL_ROW:
        {
            if(buttonIndex != 0)
            {
                storedDefaultSettings.reverseIQ = !storedDefaultSettings.reverseIQ;
                [self setStoredDefaults:storedDefaultSettings];
                [self tableView: self.tableView cellForRowAtIndexPath:tappedRowIndexPath];
                [self.tableView reloadData];
                [self applyRadioSettings:FALSE];
            }
        }
            break;

        case WIFI_ENABLE_ROW:
        {
            if(buttonIndex != 0)
            {
                storedDefaultSettings.wifiFunctionalityEnabled = !storedDefaultSettings.wifiFunctionalityEnabled;
                [self setStoredDefaults:storedDefaultSettings];
                [self tableView: self.tableView cellForRowAtIndexPath:tappedRowIndexPath];
                [self.tableView reloadData];
                [self applyRadioSettings:FALSE];
            }
        }
            break;

		default:
			SDR_DEBUGPRINT(("Error: unhandled row selection in PreferencesViewController.\n"));
			break;
	}

	self.tappedRowIndexPath = nil;
}


- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{

	//self.tappedRowIndexPath = nil;
	//self.tappedRowIndexPath = indexPath;

	switch(indexPath.row)
	{
		case ON_OFF_LINE_ROW:
		{
            UIAlertController *alert;
            UIAlertAction *choice0, *choice1;

			// open an alert with an OK and cancel button
			if(storedDefaultSettings.demoModeOnly == TRUE)
			{
				alert = [UIAlertController
                         alertControllerWithTitle:NSLocalizedString(@"Enable mic. audio?", nil)
                         message:NSLocalizedString(@"Audio file still plays if no mic. found.", nil)
                         preferredStyle:UIAlertControllerStyleAlert];
            }
			else
			{
                alert = [UIAlertController
                         alertControllerWithTitle:NSLocalizedString(@"Disable mic. audio input?", nil)
                         message:NSLocalizedString(@"Always uses audio file.", nil)
                         preferredStyle:UIAlertControllerStyleAlert];
            }

            choice0 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Cancel",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndex:0];}];

            choice1 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Yes",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndex:1];}];

            [alert addAction:choice0];
            [alert addAction:choice1];

			[self presentViewController:alert animated:YES completion:nil];
        }
        break;

		case IQ_REVERSAL_ROW:
		{
            UIAlertController *alert;
            UIAlertAction *choice0, *choice1;

			// open an alert with an OK and cancel button
			if(storedDefaultSettings.reverseIQ == FALSE)
			{
                alert = [UIAlertController
                         alertControllerWithTitle:NSLocalizedString(@"Invert I&Q audio input logic?", nil)
                         message:NSLocalizedString(@"Inverts original setting.", nil)
                         preferredStyle:UIAlertControllerStyleAlert];
			}
			else
			{
                alert = [UIAlertController
                         alertControllerWithTitle:NSLocalizedString(@"Uninvert I&Q audio input logic?", nil)
                         message:NSLocalizedString(@"Sets logic to original setting.", nil)
                         preferredStyle:UIAlertControllerStyleAlert];
            }

            choice0 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Cancel",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndex:0];}];

            choice1 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Yes",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndex:1];}];

            [alert addAction:choice0];
            [alert addAction:choice1];

            [self presentViewController:alert animated:YES completion:nil];
		}
			break;


        case WIFI_ENABLE_ROW:
        {
            UIAlertController *alert;
            UIAlertAction *choice0, *choice1;

            // open an alert with an OK and cancel button
            if(storedDefaultSettings.wifiFunctionalityEnabled == FALSE)
            {
                alert = [UIAlertController
                         alertControllerWithTitle:NSLocalizedString(@"Enable WiFi?", nil)
                         message:NSLocalizedString(@"Enables KX3 Control", nil)
                         preferredStyle:UIAlertControllerStyleAlert];
            }
            else
            {
                alert = [UIAlertController
                         alertControllerWithTitle:NSLocalizedString(@"Disable WiFi?", nil)
                         message:NSLocalizedString(@"Disables KX3 Control.", nil)
                         preferredStyle:UIAlertControllerStyleAlert];
            }

            choice0 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Cancel",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndex:0];}];

            choice1 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Yes",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndex:1];}];

            [alert addAction:choice0];
            [alert addAction:choice1];

            [self presentViewController:alert animated:YES completion:nil];
        }
            break;


		default:
			SDR_DEBUGPRINT(("Error: unhandled row selection in PreferencesViewController alert check.\n"));
			break;
	}

	SDR_DEBUGPRINT(("Handled tapped row action!\n"));
}


- (void)playKeypressBeep
{
	if(delegate) [delegate playKeypressBeep];
}


- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)shouldAutorotate
{
	return YES;
}


//- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
//{
//	[self preferencesFinished];
//}


//- (void)getStoredDefaults:(DefaultSettingsType*)defaultSettings
//{
//	// Read default settings for device
//	SDR_DEBUGPRINT(("PVC: getting saved default value(s)!\n"));
//	*defaultSettings = appDelegate.defaults;
//}


- (void)setStoredDefaults:(DefaultSettingsType)defaultSettings
{
	// Save default settings for device
	SDR_DEBUGPRINT(("PVC: setting new default value(s)!\n"));
	appDelegate.defaults = defaultSettings;
	[appDelegate writeDefaultsToFileSystem];
}


- (BOOL)prefersStatusBarHidden
{
	return ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad);
}


- (id <PreferencesViewControllerDelegate>)delegate { return delegate; }

- (void)setDelegate:(id <PreferencesViewControllerDelegate>)v
{
	delegate = v;
}

// OLD STUFF FOR iOS 5.1
//-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
//{
//	// Return YES for supported orientations
//	return ((interfaceOrientation == UIInterfaceOrientationLandscapeLeft) || (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
//}

@end
