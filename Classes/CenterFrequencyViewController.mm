/*
 File: CenterFrequencyViewController.m
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

#import "CenterFrequencyViewController.h"
#import "product.h"
#import "iSDRAppDelegate.h"
///////////////////////////////////////////////////////////////////////////////////////////
// Wifi support changes
#import "WifiInterface.h"
// Wifi support changes
///////////////////////////////////////////////////////////////////////////////////////////

static NSString *kSectionTitleKey = @"sectionTitleKey";
static NSString *kSourceKey = @"sourceKey";
static NSString *kViewKey = @"viewKey";
static frequencyType centerFrequencykHz, holdCenterFrequencykHz;

const NSInteger kViewTag = 1;

@implementation CenterFrequencyViewController

@synthesize textFieldNormal;
@synthesize dataSourceArray;
@synthesize appDelegate;
@synthesize defaultText;


- (void)viewDidLoad
{
	[super viewDidLoad];

	viewAppearded = FALSE;
	appDelegate = (iSDRAppDelegate *)[[UIApplication sharedApplication] delegate];
	centerFrequencykHz = [self getStoredCenterFrequency];
	holdCenterFrequencykHz = centerFrequencykHz;

	SDR_DEBUGPRINT(("CenterFreq viewDidLoad...\n"));

	self.title = NSLocalizedString(@"Center Frequency", @"");

	self.editing = NO; // editing of the table rows is not allowed

	self.navigationItem.hidesBackButton = TRUE;

	if(defaultText == nil)
	{
		self.defaultText = [NSMutableString new];
	}

	[defaultText setString:[NSString stringWithFormat:@"%4.3lf", centerFrequencykHz]];

	//See: NSMutableArray Class Reference
	if(self.dataSourceArray == nil)
	{
		NSMutableArray* ma = [NSMutableArray new];
		self.dataSourceArray = ma;
	}
	else
	{
		[self.dataSourceArray removeAllObjects];
	}

	[self.dataSourceArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
							[NSString stringWithFormat:@"Current Setting: %@ kHz",defaultText], kSectionTitleKey,
									 [NSString stringWithFormat:@"Valid range: %1.1f kHz to %1.1f kHz",MIN_CENTER_FREQUENCY,MAX_CENTER_FREQUENCY], kSourceKey,
//							self.textFieldNormal, kViewKey,
									 nil]];
	textFieldNormal = nil;

//	[[NSNotificationCenter defaultCenter] addObserver:self
//											 selector:@selector(keyboardWillBeShown:)
//												 name:UIKeyboardWillShowNotification object:nil];

//	[[NSNotificationCenter defaultCenter] addObserver:self
//											 selector:@selector(keyboardWillBeHidden:)
//												 name:UIKeyboardWillHideNotification object:nil];

}


-(void)cancelNumberPad
{
	self.textFieldNormal.text = [NSString stringWithFormat:@"%f", MAX_CENTER_FREQUENCY + 1];
	[self textFieldShouldReturn:textFieldNormal];
}

-(void)doneWithNumberPad
{
	[self textFieldShouldReturn:textFieldNormal];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	SDR_DEBUGPRINT(("CF: viewWillAppear: %4.2f kHz\n", centerFrequencykHz));
	SDR_DEBUGPRINT(("CF: visible cells = %lu\n\n",(unsigned long)[self.tableView visibleCells].count));

	[self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	SDR_DEBUGPRINT(("ViewDidAppear\n"));
	viewAppearded = TRUE;
}


- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	SDR_DEBUGPRINT(("CF viewWillDisappear...\n"));
	viewAppearded = FALSE;

	///////////////////////////////////////////////////////////////////////////////////////////
	// Wifi support changes
	[[WifiInterface sharedInstance] sendCommand_FA:centerFrequencykHz stepmode:NO];
	// Wifi support changes
	///////////////////////////////////////////////////////////////////////////////////////////
}


- (frequencyType)getStoredCenterFrequency
{
	// Read default settings for device
	DefaultSettingsType	defaults = appDelegate.defaults;
	return(defaults.centerFrequency);
}


- (void)setStoredCenterFrequency:(frequencyType)freq
{
	SDR_DEBUGPRINT(("CenterFreq setStoredCenterFrequency: %0.3lf\n", freq));

	// Read default settings for device
	DefaultSettingsType	defaults = appDelegate.defaults;
	defaults.centerFrequency = freq;
	appDelegate.defaults = defaults;
}


// called after the view controller's view is released and set to nil.
// For example, a memory warning which causes the view to be purged. Not invoked as a result of -dealloc.
// So release any properties that are loaded in viewDidLoad or can be recreated lazily.
//
//- (void)viewDidUnload
//{
//	[super viewDidUnload];
//
//	SDR_DEBUGPRINT(("CF viewDidUnload\n"));
//
//	// release the controls and set them nil in case they were ever created
//	//
//	self.defaultText = nil;
//	self.textFieldNormal = nil;
//	self.dataSourceArray = nil;
//
//	//[[NSNotificationCenter defaultCenter] removeObserver:self];
//}


#pragma mark -
#pragma mark UITableViewDataSource
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if([view isKindOfClass:[UITableViewHeaderFooterView class]])
	{
        UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView *) view;
        tableViewHeaderFooterView.textLabel.text = [tableViewHeaderFooterView.textLabel.text capitalizedStringWithLocale:nil];
//		tableViewHeaderFooterView.textLabel.textAlignment = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) ? NSTextAlignmentCenter : NSTextAlignmentLeft;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	SDR_DEBUGPRINT(("CF: numberOfSectionsInTableView\n"));
	return [self.dataSourceArray count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	SDR_DEBUGPRINT(("CF: titleForHeaderInSection: %s\n", [[[self.dataSourceArray objectAtIndex: section] valueForKey:kSectionTitleKey] UTF8String]));
	return [[self.dataSourceArray objectAtIndex: section] valueForKey:kSectionTitleKey];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	SDR_DEBUGPRINT(("CF: titleForFooterInSection: %s\n", [[[self.dataSourceArray objectAtIndex: section] valueForKey:kSourceKey] UTF8String]));
	return [[self.dataSourceArray objectAtIndex: section] valueForKey:kSourceKey];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	SDR_DEBUGPRINT(("CF: numberOfRowsInSection\n"));
	return 1;
}

// to determine specific row height for each cell, override this.
// In this example, each row is determined by its subviews that are embedded.
//
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	SDR_DEBUGPRINT(("CF: heightForRowAtIndexPath\n"));
//	return ([indexPath row] == 0) ? 70.0 : 22.0;
	return kFrequencyEntryTextFieldHeight;
}

// to determine which UITableViewCell to be used on a given row.
//
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = nil;
	NSUInteger row = [indexPath row];

	SDR_DEBUGPRINT(("CF: cellForRowAtIndexPath: row=%lu\n",(unsigned long)row));

	if(row == 0)
	{
		static NSString *kCellTextField_ID = @"CellTextField_ID";
		cell = [tableView dequeueReusableCellWithIdentifier:kCellTextField_ID];
		if(cell == nil)
		{
			// a new cell needs to be created
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellTextField_ID];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		else
		{
			// a cell is being recycled, remove the old edit field (if it contains one of our tagged edit fields)
			UIView *viewToCheck = nil;
			viewToCheck = [cell.contentView viewWithTag:kViewTag];
			if (!viewToCheck)
				[viewToCheck removeFromSuperview];
		}

		if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
		{
			if(viewAppearded) // wait until view has appeared to avoid potential timing issues affecting the keyboard
			{
				[cell.contentView addSubview:self.textFieldNormal];
				// Delay seems to prevent problems with keyboard in iOS8
				[self performSelector:@selector(startEditingSession) withObject:nil afterDelay:0.5];
			}
		}
		else
		{
			[cell.contentView addSubview:self.textFieldNormal];
			SDR_DEBUGPRINT(("textField added to view.\n"));
			[textFieldNormal becomeFirstResponder];
		}
	}
	else /* (row == 1) */
	{
		static NSString *kSourceCell_ID = @"SourceCell_ID";
		cell = [tableView dequeueReusableCellWithIdentifier:kSourceCell_ID];
		if(cell == nil)
		{
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kSourceCell_ID];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;

//            cell.textLabel.textAlignment = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) ? NSTextAlignmentCenter : NSTextAlignmentLeft;
            cell.textLabel.textColor = [UIColor blackColor];
			cell.textLabel.highlightedTextColor = [UIColor redColor];
            cell.textLabel.font = [UIFont systemFontOfSize:14];
		}

		cell.textLabel.text = [[self.dataSourceArray objectAtIndex:indexPath.section] valueForKey:kSourceKey];
	}

    return cell;
}


#pragma mark -
#pragma mark UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	// the user pressed the "Done" button, so dismiss the keyboard
	[textField resignFirstResponder];

	if(textField == textFieldNormal)
	{
		SDR_DEBUGPRINT(("CF: textFieldShouldReturn\n"));

		centerFrequencykHz = [textField.text doubleValue];

		if((centerFrequencykHz < MIN_CENTER_FREQUENCY) || (centerFrequencykHz > MAX_CENTER_FREQUENCY))
		{
			SDR_DEBUGPRINT(("Error: frequency out of bounds = %f\n", centerFrequencykHz));
			centerFrequencykHz = holdCenterFrequencykHz;
		}
		else
		{
			[self setStoredCenterFrequency:centerFrequencykHz];
		}
	}

	[[self navigationController] popToRootViewControllerAnimated:TRUE];

	return YES;
}


- (void)textFieldDidEndEditing:(UITextField *)textField
{
	SDR_DEBUGPRINT(("textFieldDidEndEditing\n"));
}

- (void)startEditingSession
{
	if(textFieldNormal && !textFieldNormal.isFirstResponder)
	{
		SDR_DEBUGPRINT(("Starting keyboard\n"));
//		[[self navigationController] popViewControllerAnimated:TRUE];
//		UIView* main = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
//		[main addSubview:textFieldNormal];
		if(textFieldNormal)
		{
			if(textFieldNormal.canBecomeFirstResponder)
			{
				if(!self.view.window)
				{
					SDR_DEBUGPRINT(("Error: window not found in self.view.window!\n"));
				}

				if(!textFieldNormal.window)
				{
					SDR_DEBUGPRINT(("Error: window not found in textFieldNormal.window!\n"));
				}

				if([textFieldNormal becomeFirstResponder])
				{
					SDR_DEBUGPRINT(("Success: textField accepted responder status!\n"));
				}

			}
			else
			{
				SDR_DEBUGPRINT(("Error: textField cannot become first responder!\n"));
			}
		}
	}
}


- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
	if(textField == textFieldNormal)
	{
		SDR_DEBUGPRINT(("CF: textFieldShouldBeginEditing\n"));

		//		textField.keyboardType = UIKeyboardTypeDecimalPad;
		//		textField.returnKeyType = UIReturnKeyDone;
		//		textField.enablesReturnKeyAutomatically = NO;
		//		textField.keyboardAppearance = UIKeyboardAppearanceAlert;
		holdCenterFrequencykHz = centerFrequencykHz;
		return YES;
	}

	SDR_DEBUGPRINT(("CF: requested textField is not allowed to begin editing."));
	return NO;
}

//- (void)keyboardWillBeHidden:(NSNotification*)aNotification
//{
//	SDR_DEBUGPRINT(("Keyboard will be hidden!\n"));
//	if ([self respondsToSelector:@selector(preferredContentSize)]) {
//		self.preferredContentSize = CGSizeMake(320, 480);
//	}
//}

//- (void)keyboardWillBeShown:(NSNotification*)aNotification
//{
//	SDR_DEBUGPRINT(("Keyboard will be shown!\n"));
//	if ([self respondsToSelector:@selector(preferredContentSize)]) {
//		self.preferredContentSize = CGSizeMake(320, 200);
//	}
//}



#pragma mark -
#pragma mark Text Fields

- (UITextField *)textFieldNormal
{
	if(textFieldNormal == nil)
	{
		SDR_DEBUGPRINT(("CF: Creating textField\n"));
		CGFloat xcenter = (IPAD_POPOVER_MENU_WIDTH_FOR_FREQUENCY_ENTRY - kFrequencyEntryTextFieldWidth)/2.;
		CGRect frame = CGRectMake(xcenter, 0., kFrequencyEntryTextFieldWidth, kFrequencyEntryTextFieldHeight);

		textFieldNormal = [[UITextField alloc] initWithFrame:frame];

		textFieldNormal.borderStyle = UITextBorderStyleRoundedRect;
		textFieldNormal.textColor = [UIColor blackColor];
		textFieldNormal.font = [UIFont systemFontOfSize:22.0];
		textFieldNormal.placeholder = NSLocalizedString(@"Center Freq (kHz)", nil);

		textFieldNormal.center = CGPointMake(textFieldNormal.center.x, kFrequencyEntryTextFieldHeight/2.);

		//		textFieldNormal.text = nil;

		textFieldNormal.text = defaultText;

		textFieldNormal.backgroundColor = [UIColor whiteColor];
		textFieldNormal.autocorrectionType = UITextAutocorrectionTypeNo;	// no auto correction support

		textFieldNormal.returnKeyType = UIReturnKeyDone;

		textFieldNormal.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x' button to the right

		textFieldNormal.tag = kViewTag;		// tag this control so we can remove it later for recycled cells

		textFieldNormal.delegate = self;	// let us be the delegate so we know when the keyboard's "Done" button is pressed

		// Add an accessibility label that describes what the text field is for.
		[textFieldNormal setAccessibilityLabel:NSLocalizedString(@"CenterFrequency", @"")];

		if([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
		{
			textFieldNormal.keyboardType = UIKeyboardTypeNumbersAndPunctuation;	// use numbers and punctuation keypad
		}
		else
		{
			textFieldNormal.keyboardType = UIKeyboardTypeDecimalPad;	// use numbers and punctuation keypad
			UIToolbar* numberToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 150, 30)];

			numberToolbar.items = [NSArray arrayWithObjects:
								   [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", nil) style:UIBarButtonItemStylePlain target:self action:@selector(cancelNumberPad)],
								   [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
								   [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Apply", nil) style:UIBarButtonItemStyleDone target:self action:@selector(doneWithNumberPad)],
								   nil];

			textFieldNormal.inputAccessoryView = numberToolbar;
		}
	}
#ifdef SDR_DEBUG
	else
	{
		SDR_DEBUGPRINT(("CF: textField already created.\n"));
	}
#endif

	return textFieldNormal;
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
//	printf("CenterFreqViewController: willRotate!\n");
//	[[self navigationController] popToRootViewControllerAnimated:TRUE];
//}


- (BOOL)prefersStatusBarHidden
{
	return ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad);
}

// OLD STUFF FOR iOS 5.1
//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
//{
//	// Return YES for supported orientations
//	return ((interfaceOrientation == UIInterfaceOrientationLandscapeLeft) || (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
//}


@end
