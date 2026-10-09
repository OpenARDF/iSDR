//
//  AboutViewController.m
//  iSDR
//
//  This software is provided by OpenARDF on an "AS IS" basis.
//  OPENARDF MAKES NO WARRANTIES, EXPRESS OR IMPLIED,
//  INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
//  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE
//  SOFTWARE OR ITS USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
//
//  IN NO EVENT SHALL OPENARDF BE LIABLE FOR ANY SPECIAL,
//  INDIRECT, INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
//  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
//  PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE,
//  REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE OPENARDF SOFTWARE,
//  HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
//  STRICT LIABILITY OR OTHERWISE, EVEN IF OPENARDF HAS BEEN
//  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  Copyright (c) 2009-2026 OpenARDF. Licensed under the MIT License.
//

#import "AboutViewController.h"
#import "product.h"
#import "PreferencesViewController.h"
#import <CoreText/CoreText.h>
#import <CoreFoundation/CFAttributedString.h>

@implementation AboutViewController

@synthesize textViewVersion;
@synthesize textViewBuild;
@synthesize textViewInstructions;
@synthesize appDelegate;

- (void)setupTextView
{
	if(textViewVersion)
	{
		// Apple's bundle version stays numeric; this separate value carries the
		// OpenARDF test suffix shown to testers without invalidating the bundle.
		NSString *displayVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"ISDRDisplayVersion"];
		if(displayVersion.length == 0)
		{
			displayVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		}
		self.textViewVersion.textColor = [UIColor blackColor];
		self.textViewVersion.font = [UIFont fontWithName:@"Arial" size:18];
		self.textViewVersion.backgroundColor = [UIColor clearColor];
#ifdef ISDR_BETA_BUILD
		self.textViewVersion.text = [NSString stringWithFormat:@"Version: %@ (BETA) Exp:%@", displayVersion, EXPIRATION_DATE];
#else
		self.textViewVersion.text = [NSString stringWithFormat:@"Version: %@", displayVersion];
#endif
		self.textViewVersion.scrollEnabled = NO;
		self.textViewVersion.editable = NO;
		self.textViewVersion.dataDetectorTypes = UIDataDetectorTypeLink;
		// this will cause automatic vertical resize when the table is resized
		self.textViewVersion.autoresizingMask = UIViewAutoresizingFlexibleHeight;
	}

	if(textViewBuild)
	{
		self.textViewBuild.textColor = [UIColor blackColor];
		self.textViewBuild.font = [UIFont fontWithName:@"Arial" size:18];
		self.textViewBuild.backgroundColor = [UIColor clearColor];
		self.textViewBuild.scrollEnabled = NO;
		self.textViewBuild.editable = NO;
		self.textViewBuild.dataDetectorTypes = UIDataDetectorTypeLink;
		// this will cause automatic vertical resize when the table is resized
		self.textViewBuild.autoresizingMask = UIViewAutoresizingFlexibleHeight;
		self.textViewBuild.text = [NSString stringWithFormat:@"Thank you for using %@!\n\n", [iSDRAppDelegate getAppName]];
	}

	if(textViewInstructions)
	{
		self.textViewInstructions.textColor = [UIColor blackColor];
		self.textViewInstructions.font = [UIFont fontWithName:@"Arial" size:18];
		self.textViewInstructions.backgroundColor = [UIColor clearColor];
		self.textViewInstructions.scrollEnabled = YES;
		self.textViewInstructions.editable = NO;
		self.textViewInstructions.dataDetectorTypes = UIDataDetectorTypeLink;
		// this will cause automatic vertical resize when the table is resized
		self.textViewInstructions.autoresizingMask = UIViewAutoresizingFlexibleHeight;

		NSString* appname = [iSDRAppDelegate getAppName];
		DefaultSettingsType defaults = appDelegate.defaults;

		if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
		{
			NSString* txt;

			if(defaults.wifiFunctionalityEnabled)
			{
				txt = ABOUT_TEXT_WIFI_NEWER;
			}
			else
			{
				txt = ABOUT_TEXT_ISDR_NEWER;
			}

			self.textViewInstructions.attributedText = [AboutViewController styledDescription:txt fontsize:([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) ? 18.:16.];
		}
		else
		{
			NSString* txt;

			if(defaults.wifiFunctionalityEnabled)
			{
				txt = ABOUT_TEXT_WIFI_OLD;
			}
			else
			{
				txt = ABOUT_TEXT_ISDR_OLD;
			}

			self.textViewInstructions.text = txt;
		}
	}
}



/*
 Returns an attributed string with attributes as flagged within the description text:
 Boldface: b^ ^b
 Red: r^ ^r
 Link: l^ ^l
 Heading: h^ ^h
 Image: i^filename^i
 Formatting regions must not overlap
 */
+ (NSMutableAttributedString*)styledDescription:(NSString*)description fontsize:(float)fontSize
{
	NSString* infoString = [description stringByReplacingOccurrencesOfString:@"\t" withString:@""];
	infoString = [infoString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	NSMutableAttributedString *attString = [[NSMutableAttributedString alloc] initWithString:infoString];

	UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:fontSize];
	UIFont *fontBold = [UIFont fontWithName:@"HelveticaNeue-Bold" size:fontSize];
	UIFont *fontBig = [UIFont fontWithName:@"HelveticaNeue-Bold" size:fontSize+2];

	// Create a color that will be added as an attribute to the attrString.
	CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
	CGFloat components[] = { 1.0, 0.0, 0.0, 0.8 };
	CGColorRef red = CGColorCreate(rgbColorSpace, components);
	CGColorSpaceRelease(rgbColorSpace);

	// Apply boldface formatting
	NSInteger nextIndex = 0;
	NSMutableString* stringContents = [attString mutableString];
	NSInteger stringLength = [stringContents length];
	NSRange r = NSMakeRange(0, stringLength-1);
	// plain font for all text up to the first boldface flag in the description
	[attString addAttribute:NSFontAttributeName value:font range:r];
	NSRange flagStartCharacterRange = [stringContents rangeOfString:@"b^" options:NSLiteralSearch range:r];
	NSRange flagEndCharacterRange = [stringContents rangeOfString:@"^b" options:NSLiteralSearch range:r];


	while((flagEndCharacterRange.location != NSNotFound) && (flagStartCharacterRange.location != NSNotFound) && (flagStartCharacterRange.location < flagEndCharacterRange.location))
	{
		// bold all the characters between the flags
		r = NSMakeRange(flagStartCharacterRange.location, 2+flagEndCharacterRange.location-flagStartCharacterRange.location);
		[attString addAttribute:NSFontAttributeName value:fontBold range:r];

		// Remove formatting flags and update string data
		NSRange rWithoutFlags = NSMakeRange(r.location+2, r.length-4);
		[attString replaceCharactersInRange:r withString:[stringContents substringWithRange:rWithoutFlags]];
		stringContents = [attString mutableString];
		stringLength = [stringContents length];
		flagEndCharacterRange.location -= 4; // account for removed characters

		SDR_DEBUGPRINT(("Setting bold: %s\n", [[stringContents substringWithRange:r] UTF8String]));

		nextIndex = flagEndCharacterRange.location + 3;
		r = NSMakeRange(nextIndex, stringLength - nextIndex);
		NSRange nextFlag = [stringContents rangeOfString:@"b^" options:NSLiteralSearch range:r];
		SDR_DEBUGPRINT(("nextFlag = %lu, %lu; nextIndex = %ld\n", (unsigned long)nextFlag.location, (unsigned long)nextFlag.length, (long)nextIndex));

		if(nextFlag.location != NSNotFound)
		{
			if(nextFlag.location > nextIndex) // need at least one character
			{
				// unbold an characters outside the flags
				r = NSMakeRange(nextIndex, nextFlag.location - nextIndex);
				[attString addAttribute:NSFontAttributeName value:font range:r];
			}
			SDR_DEBUGPRINT(("Setting unbold: >%s< (%lu, %lu)\n", [[stringContents substringWithRange:r] UTF8String], (unsigned long)r.location, (unsigned long)r.length));
		}
		else
		{
			// unbold to the end of the text
			r = NSMakeRange(nextIndex, stringLength - nextIndex);
			[attString addAttribute:NSFontAttributeName value:font range:r];
			SDR_DEBUGPRINT(("Setting unbold: >%s<\n", [[stringContents substringWithRange:r] UTF8String]));
		}

		flagStartCharacterRange = nextFlag;

		if(nextFlag.location != NSNotFound)
		{
			r = NSMakeRange(nextFlag.location, stringLength - nextFlag.location);
			flagEndCharacterRange = [stringContents rangeOfString:@"^b" options:NSLiteralSearch range:r];

			stringContents = [attString mutableString];
		}
	}

	// Red Text
	nextIndex = 0;
	stringContents = [attString mutableString];
	stringLength = [stringContents length];
	r = NSMakeRange(nextIndex, stringLength-nextIndex);
	flagStartCharacterRange = [stringContents rangeOfString:@"r^" options:NSLiteralSearch range:r];
	flagEndCharacterRange = [stringContents rangeOfString:@"^r" options:NSLiteralSearch range:r];


	while((flagEndCharacterRange.location != NSNotFound) && (flagStartCharacterRange.location != NSNotFound) && (flagStartCharacterRange.location < flagEndCharacterRange.location))
	{
		// red all the characters between the flags
		r = NSMakeRange(flagStartCharacterRange.location, 2+flagEndCharacterRange.location-flagStartCharacterRange.location);
		[attString addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:r];

		// Remove formatting flags and update string data
		NSRange rWithoutFlags = NSMakeRange(r.location+2, r.length-4);
		[attString replaceCharactersInRange:r withString:[stringContents substringWithRange:rWithoutFlags]];
		stringContents = [attString mutableString];
		stringLength = [stringContents length];
		flagEndCharacterRange.location -= 4; // account for removed characters

		SDR_DEBUGPRINT(("Setting red: %s\n", [[stringContents substringWithRange:r] UTF8String]));

		nextIndex = flagEndCharacterRange.location + 3;
		r = NSMakeRange(nextIndex, stringLength - nextIndex);
		NSRange nextFlag = [stringContents rangeOfString:@"r^" options:NSLiteralSearch range:r];
		SDR_DEBUGPRINT(("nextFlag = %lu, %lu; nextIndex = %ld\n", (unsigned long)nextFlag.location, (unsigned long)nextFlag.length, (long)nextIndex));

		flagStartCharacterRange = nextFlag;

		if(nextFlag.location != NSNotFound)
		{
			r = NSMakeRange(nextFlag.location, stringLength - nextFlag.location);
			flagEndCharacterRange = [stringContents rangeOfString:@"^r" options:NSLiteralSearch range:r];

			stringContents = [attString mutableString];
		}
	}

	CFRelease(red);

	// Apply heading font formatting
	nextIndex = 0;
	stringContents = [attString mutableString];
	stringLength = [stringContents length];
	r = NSMakeRange(nextIndex, stringLength-nextIndex);
	flagStartCharacterRange = [stringContents rangeOfString:@"h^" options:NSLiteralSearch range:r];
	flagEndCharacterRange = [stringContents rangeOfString:@"^h" options:NSLiteralSearch range:r];

	// plain font for all text up to the first boldface flag in the description
	while((flagEndCharacterRange.location != NSNotFound) && (flagStartCharacterRange.location != NSNotFound) && (flagStartCharacterRange.location < flagEndCharacterRange.location))
	{
		// bold all the characters between the flags
		r = NSMakeRange(flagStartCharacterRange.location, 2+flagEndCharacterRange.location-flagStartCharacterRange.location);
		[attString addAttribute:NSFontAttributeName value:fontBig range:r];

		// Remove formatting flags and update string data
		NSRange rWithoutFlags = NSMakeRange(r.location+2, r.length-4);
		[attString replaceCharactersInRange:r withString:[stringContents substringWithRange:rWithoutFlags]];
		stringContents = [attString mutableString];
		stringLength = [stringContents length];
		flagEndCharacterRange.location -= 4; // account for removed characters

		SDR_DEBUGPRINT(("Setting bold: %s\n", [[stringContents substringWithRange:r] UTF8String]));

		nextIndex = flagEndCharacterRange.location + 3;
		r = NSMakeRange(nextIndex, stringLength - nextIndex);
		NSRange nextFlag = [stringContents rangeOfString:@"h^" options:NSLiteralSearch range:r];
		SDR_DEBUGPRINT(("nextFlag = %lu, %lu; nextIndex = %ld\n", (unsigned long)nextFlag.location, (unsigned long)nextFlag.length, (long)nextIndex));

		flagStartCharacterRange = nextFlag;

		if(nextFlag.location != NSNotFound)
		{
			r = NSMakeRange(nextFlag.location, stringLength - nextFlag.location);
			flagEndCharacterRange = [stringContents rangeOfString:@"^h" options:NSLiteralSearch range:r];

			stringContents = [attString mutableString];
		}
	}

	// Insert images
	nextIndex = 0;
	stringContents = [attString mutableString];
	stringLength = [stringContents length];
	r = NSMakeRange(nextIndex, stringLength-1);
	flagStartCharacterRange = [stringContents rangeOfString:@"i^" options:NSLiteralSearch range:r];
	flagEndCharacterRange = [stringContents rangeOfString:@"^i" options:NSLiteralSearch range:r];

	// plain font for all text up to the first boldface flag in the description
	while((flagEndCharacterRange.location != NSNotFound) && (flagStartCharacterRange.location != NSNotFound) && (flagStartCharacterRange.location < flagEndCharacterRange.location))
	{
		// bold all the characters between the flags
		r = NSMakeRange(flagStartCharacterRange.location, 2+flagEndCharacterRange.location-flagStartCharacterRange.location);
		[attString addAttribute:NSFontAttributeName value:fontBig range:r];

		// Remove formatting flags and update string data
		NSRange rWithoutFlags = NSMakeRange(r.location+2, r.length-4);
		SDR_DEBUGPRINT(("r = {%lu,%lu}; rWithFlags = {%lu,%lu}\n", (unsigned long)r.location, (unsigned long)r.length, (unsigned long)rWithoutFlags.location, (unsigned long)rWithoutFlags.length));
		NSString* filename = [stringContents substringWithRange:rWithoutFlags];
		NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
		textAttachment.image = [UIImage imageNamed:filename];
		[attString replaceCharactersInRange:r withAttributedString:[NSAttributedString attributedStringWithAttachment:textAttachment]];

		stringContents = [attString mutableString];
		stringLength = [stringContents length];
		flagEndCharacterRange.location -= 4; // account for removed characters

		SDR_DEBUGPRINT(("Setting bold: %s\n", [[stringContents substringWithRange:r] UTF8String]));

		nextIndex = flagEndCharacterRange.location + 3;
		r = NSMakeRange(nextIndex, stringLength - nextIndex);
		NSRange nextFlag = [stringContents rangeOfString:@"i^" options:NSLiteralSearch range:r];
		SDR_DEBUGPRINT(("nextFlag = %lu, %lu; nextIndex = %ld\n", (unsigned long)nextFlag.location, (unsigned long)nextFlag.length, (long)nextIndex));

		flagStartCharacterRange = nextFlag;

		if(nextFlag.location != NSNotFound)
		{
			r = NSMakeRange(nextFlag.location, stringLength - nextFlag.location);
			flagEndCharacterRange = [stringContents rangeOfString:@"^i" options:NSLiteralSearch range:r];

			stringContents = [attString mutableString];
		}
	}

	// Insert URL links
	nextIndex = 0;
	stringContents = [attString mutableString];
	stringLength = [stringContents length];
	r = NSMakeRange(nextIndex, stringLength-1);
	flagStartCharacterRange = [stringContents rangeOfString:@"l^" options:NSLiteralSearch range:r];
	flagEndCharacterRange = [stringContents rangeOfString:@"^l" options:NSLiteralSearch range:r];

	// plain font for all text up to the first boldface flag in the description
	while((flagEndCharacterRange.location != NSNotFound) && (flagStartCharacterRange.location != NSNotFound) && (flagStartCharacterRange.location < flagEndCharacterRange.location))
	{
		// make link from all the characters between the flags

		r = NSMakeRange(flagStartCharacterRange.location, 2+flagEndCharacterRange.location-flagStartCharacterRange.location);
		NSRange rWithoutFlags = NSMakeRange(r.location+2, r.length-4);
		NSString* urlstring = [stringContents substringWithRange:rWithoutFlags];

		if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0"))
		{
			NSURL *url = [NSURL URLWithString:urlstring];
			[attString addAttribute:NSLinkAttributeName value:url range:r];
		}
		else
		{
			[attString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:r];
		}

		// Remove formatting flags and update string data
		[attString replaceCharactersInRange:r withString:[stringContents substringWithRange:rWithoutFlags]];
		stringContents = [attString mutableString];
		stringLength = [stringContents length];
		flagEndCharacterRange.location -= 4; // account for removed characters

		r.length = MIN(r.length, [stringContents length]-r.location-1);
		SDR_DEBUGPRINT(("stringContents:>%s<\nr = {%lu,%lu}\n", [stringContents UTF8String], (unsigned long)r.location, (unsigned long)r.length));
		SDR_DEBUGPRINT(("Set link to: >%s<\n", [urlstring UTF8String]));

		nextIndex = flagEndCharacterRange.location + 3;
		r = NSMakeRange(nextIndex, stringLength - nextIndex);
		NSRange nextFlag = [stringContents rangeOfString:@"l^" options:NSLiteralSearch range:r];
		SDR_DEBUGPRINT(("nextFlag = %lu, %lu; nextIndex = %ld\n", (unsigned long)nextFlag.location, (unsigned long)nextFlag.length, (long)nextIndex));

		flagStartCharacterRange = nextFlag;

		if(nextFlag.location != NSNotFound)
		{
			r = NSMakeRange(nextFlag.location, stringLength - nextFlag.location);
			flagEndCharacterRange = [stringContents rangeOfString:@"^l" options:NSLiteralSearch range:r];

			stringContents = [attString mutableString];
		}
	}

	//add alignment
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	[paragraphStyle setAlignment:NSTextAlignmentNatural];
	[attString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, stringLength)];



	/*
	 Experiment for inserting images into the attributed string:
	 http://stackoverflow.com/questions/20930462/ios-7-textkit-how-to-insert-images-inline-with-text
	 */
	//NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@"like after"];



	return attString;
}

+ (NSString*)stripFormatting:(NSString*)description
{
// Boldface: b^ ^b
// Red: r^ ^r
// Link: l^ ^l
// Heading: h^ ^h
// Image: i^filename^i
	NSString* result = [description stringByReplacingOccurrencesOfString:@"b^" withString:@""];
	result = [result stringByReplacingOccurrencesOfString:@"^b" withString:@""];
	result = [result stringByReplacingOccurrencesOfString:@"^l" withString:@""];
	result = [result stringByReplacingOccurrencesOfString:@"l^" withString:@""];
	result = [result stringByReplacingOccurrencesOfString:@"^r" withString:@""];
	result = [result stringByReplacingOccurrencesOfString:@"r^" withString:@""];
	result = [result stringByReplacingOccurrencesOfString:@"^h" withString:@""];
	result = [result stringByReplacingOccurrencesOfString:@"h^" withString:@""];
	result = [result stringByReplacingOccurrencesOfString:@"^i" withString:@""];
	result = [result stringByReplacingOccurrencesOfString:@"i^" withString:@""];
	return result;
}


// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
//- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
//{
//	if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
//	{
//		// Custom initialization
//	}
//	return self;
//}


- (void)viewDidLoad
{
	[super viewDidLoad];

	appDelegate = (iSDRAppDelegate *)[[UIApplication sharedApplication] delegate];

	//	[self setupTextView];
	//	printf("AboutView viewDidLoad\n");
}

// called after the view controller's view is released and set to nil.
// For example, a memory warning which causes the view to be purged. Not invoked as a result of -dealloc.
// So release any properties that are loaded in viewDidLoad or can be recreated lazily.
//
//- (void)viewDidUnload
//{
//	[super viewDidUnload];
//
//	self.textViewVersion = nil;
//	self.textViewBuild = nil;
//	self.textViewInstructions = nil;
//}

- (void)viewWillAppear:(BOOL)animated
{
    // listen for keyboard hide/show notifications so we can properly adjust the table's height
	[super viewWillAppear:animated];
	self.title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"AboutViewTitle", @""), [iSDRAppDelegate getAppName]];
	[self setupTextView];
	//	printf("AboutView viewWillAppear\n");
}



//- (void)viewDidAppear:(BOOL)animated
//{
//	PreferencesViewController* pvc = (PreferencesViewController*)self.presentingViewController;
//	[pvc.popover setPopoverContentSize:CGSizeMake(IPAD_POPOVER_MENU_WIDTH, IPAD_POPOVER_HEIGHT) animated:YES];
//}


- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
	//	printf("AboutView viewDidDisappear\n");
}

#pragma mark -
#pragma mark UITextViewDelegate

//- (void)textViewDidBeginEditing:(UITextView *)textView
//{
// provide my own Save button to dismiss the keyboard
//	UIBarButtonItem* saveItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
//																			  target:self action:@selector(saveAction:)];
//	self.navigationItem.rightBarButtonItem = saveItem;
//	[saveItem release];
//}

//- (void)saveAction:(id)sender
//{
// finish typing text/dismiss the keyboard by removing it as the first responder
//
//	[self.textView resignFirstResponder];
//	self.navigationItem.rightBarButtonItem = nil;	// this will remove the "save" button
//}


//- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
//{
//	[self initWithNibName:@"AboutViewController" bundle:nil];
//	[self setupTextView];
//	printf("AboutView viewWillRotateToInterfaceOrientation\n");
//}


//- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
//{
//	[self initWithNibName:@"AboutViewController" bundle:nil];
//	[self setupTextView];
//}

- (BOOL)prefersStatusBarHidden
{
	return ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad);
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)shouldAutorotate
{
	return YES;
}

// OLD STUFF FOR iOS 5.1
//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
//{
//	// Return YES for supported orientations
//	return ((interfaceOrientation == UIInterfaceOrientationLandscapeLeft) || (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
//}

@end
