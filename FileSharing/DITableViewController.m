/*
     File: DITableViewController.m
 Abstract: The table view that display docs of different types.
  Version: 1.2

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (c) 2010 Apple Inc. All Rights Reserved.

 */

#import "DITableViewController.h"
#import "iSDRAppDelegate.h"

@interface DITableViewController (private)
- (NSString *)applicationDocumentsDirectory;
@end

static NSString* documents[] =
	{
		DEFAULT_AUDIO_FILE_NAME
	};
#define NUM_DOCS 1

#define kRowHeight 58.0


@implementation DITableViewController

@synthesize docWatcher, documentURLs;
@synthesize docInteractionController;

#pragma mark -
#pragma mark View Controller

- (void)setupDocumentControllerWithURL:(NSURL *)url
{
	if(docInteractionController && ![docInteractionController.URL isEqual:url])
	{
		self.docInteractionController = nil;
	}

	if(docInteractionController == nil)
	{
		self.docInteractionController = [UIDocumentInteractionController interactionControllerWithURL:url];
		self.docInteractionController.delegate = self;
	}
}


- (void)viewDidLoad
{
	[super viewDidLoad];

	// start monitoring the document directory…
	self.docWatcher = [DirectoryWatcher watchFolderWithPath:[self applicationDocumentsDirectory] delegate:self];

	NSMutableArray* ma = [NSMutableArray new];
	self.documentURLs = ma;

	// scan for existing documents
	[self directoryDidChange:self.docWatcher];
}


//- (void)viewDidUnload
//{
//	self.documentURLs = nil;
//	[docWatcher invalidate]; // ARC: need to invalidate here because DirectoryWatcher does not invalidate itself in dealloc anymore
//	self.docWatcher = nil;
//	[super viewDidUnload];
//}


- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[delegate flushAudio];
}




- (BOOL)shouldAutorotate
{
	return YES;
}


#pragma mark -
#pragma mark UITableViewDataSource

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if([view isKindOfClass:[UITableViewHeaderFooterView class]])
	{
        UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView *) view;
        tableViewHeaderFooterView.textLabel.text = [tableViewHeaderFooterView.textLabel.text capitalizedStringWithLocale:nil];
    }
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(section == 0)
	{
		return NUM_DOCS;
	}
	else
	{
		return self.documentURLs.count;
	}

}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	NSString *title = nil;

	if (section == 0)
		title = @"Sample file";
	else
	{
		if (self.documentURLs.count > 0) title = @"Your files";
	}

	return title;
}


- (NSString *)formattedFileSize:(unsigned long long)size
{
	NSString *formattedStr = nil;
	if (size == 0)
		formattedStr = @"Empty";
	else if (size > 0 && size < 1024)
			formattedStr = [NSString stringWithFormat:@"%qu bytes", size];
	else if (size >= 1024 && size < pow(1024, 2))
		formattedStr = [NSString stringWithFormat:@"%.1f KB", (size / 1024.)];
	else if (size >= pow(1024, 2) && size < pow(1024, 3))
		formattedStr = [NSString stringWithFormat:@"%.2f MB", (size / pow(1024, 2))];
	else if (size >= pow(1024, 3))
		formattedStr = [NSString stringWithFormat:@"%.3f GB", (size / pow(1024, 3))];

	return formattedStr;
}


// if we installed a custom UIGestureRecognizer (i.e. long-hold), then this would be called
- (void)handleLongPress:(UILongPressGestureRecognizer *)longPressGesture
{
	SDR_DEBUGPRINT(("Long press detected!\n"));
	if(longPressGesture.state == UIGestureRecognizerStateBegan)
	{
		NSIndexPath *cellIndexPath = [self.tableView indexPathForRowAtPoint:[longPressGesture locationInView:self.tableView]];

		if (cellIndexPath.section == 0)
			_selectedFileURL = nil; //[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:documents[cellIndexPath.row] ofType:nil]];
		else
			_selectedFileURL = [self.documentURLs objectAtIndex:cellIndexPath.row];

		// pop modal dialog to confirm file delete

		if(_selectedFileURL != nil)
		{
			NSString *URLString = [[_selectedFileURL path] lastPathComponent];
			NSString *message = [NSString stringWithFormat:@"File name: %@", URLString];

			UIAlertController *alert = [UIAlertController
                     alertControllerWithTitle:NSLocalizedString(@"Delete File", nil)
                     message:message
                     preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *choice0, *choice1;

            choice0 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Cancel",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:0 Tag:DeleteFileAlert];}];

            choice1 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Delete!",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:1 Tag:DeleteFileAlert];}];

            [alert addAction:choice0];
            [alert addAction:choice1];

            [self presentViewController:alert animated:YES completion:nil];
		}
	}
}


- (UITableViewCell *)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"cellID";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

	if(!cell)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
	}

	NSURL *fileURL;
	if(indexPath.section == 0)
	{
		// first section is our build-in documents
		fileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:documents[indexPath.row] ofType:nil]];
	}
	else
	{
		// second section is the contents of the Documents folder
		fileURL = [self.documentURLs objectAtIndex:indexPath.row];
	}

	[self setupDocumentControllerWithURL:fileURL];

	// layout the cell
	cell.textLabel.text = [[fileURL path] lastPathComponent];
	NSInteger iconCount = [docInteractionController.icons count];
	if(iconCount > 0)
	{
		cell.imageView.image = [docInteractionController.icons objectAtIndex:iconCount - 1];
	}

	NSError *error;
	NSString *fileURLString = [self.docInteractionController.URL path];
	NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fileURLString error:&error];
	NSInteger fileSize = [[fileAttributes objectForKey:NSFileSize] intValue];

	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", [self formattedFileSize:fileSize], docInteractionController.UTI];

	NSURL* activeFileURL = ([delegate getCurrentFileURL]);

	if(activeFileURL == nil)
	{
		SDR_DEBUGPRINT(("No file currently loaded. Use default sample file.\n"));
		activeFileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:DEFAULT_AUDIO_FILE_NAME ofType:nil]];
		[delegate setFile:activeFileURL];
	}

	NSString* activeFileURLString = [activeFileURL path];

	fileURLString = [fileURL path];

	if([activeFileURLString caseInsensitiveCompare:fileURLString] == 0)
	{
		_selectedRowIndexPath = indexPath;
		SDR_DEBUGPRINT(("Active URL = %s\n", [activeFileURLString UTF8String]));
		SDR_DEBUGPRINT(("Match found!\n"));
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	}
	else
	{
		cell.accessoryType = UITableViewCellAccessoryNone;
	}

	if(indexPath.section != 0)
	{
		UILongPressGestureRecognizer *longPressGesture =
		[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
		longPressGesture.minimumPressDuration = 3.;
		[cell.contentView addGestureRecognizer:longPressGesture];
	}

	return cell;
}


- (CGFloat)tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return kRowHeight;
}


#pragma mark -
#pragma mark UITableView delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSURL *fileURL;
	if (indexPath.section == 0)
	{
		fileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:documents[indexPath.row] ofType:nil]];
	}
	else
	{
		fileURL = [self.documentURLs objectAtIndex:indexPath.row];
	}

	NSString *URLString = [[fileURL path] lastPathComponent];

	if([delegate setFile:fileURL])
	{
		SDR_DEBUGPRINT(("Error setting file!!\n"));

		NSString *message = [NSString stringWithFormat:@"Unable to open %@.\n%@ does not support this file type!", URLString, [iSDRAppDelegate getAppName]];

		UIAlertController *alert = [UIAlertController
                 alertControllerWithTitle:NSLocalizedString(@"File Error!", nil)
                 message:message
                 preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *choice0;

        choice0 = [UIAlertAction
                   actionWithTitle:NSLocalizedString(@"OK",nil) style:UIAlertActionStyleDefault
                   handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:0 Tag:AlertInactive];}];

        [alert addAction:choice0];

        [self presentViewController:alert animated:YES completion:nil];


		if(_selectedRowIndexPath.section == 0)
		{
			fileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:documents[_selectedRowIndexPath.row] ofType:nil]];
		}
		else
		{
			fileURL = [self.documentURLs objectAtIndex:_selectedRowIndexPath.row];
		}

		[delegate setFile:fileURL];

	}
	else
	{
		_selectedRowIndexPath = indexPath;

		// check whether off-line mode is currently enabled.
		// If not, then pop alert to ask if it should be enabled.
		if(![delegate getFilePlayActive])
		{
			NSString *message = [NSString stringWithFormat:@"Play is currently disabled"];
			UIAlertController *alert = [UIAlertController
                     alertControllerWithTitle:NSLocalizedString(@"Play file now?", nil)
                     message:message
                     preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *choice0, *choice1;

            choice0 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"No",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:0 Tag:EnableFileplayingAlert];}];

            choice1 = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Play!",nil) style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action){[self alertDidDismissWithButtonIndexAndTag:1 Tag:EnableFileplayingAlert];}];

            [alert addAction:choice0];
            [alert addAction:choice1];

            [self presentViewController:alert animated:YES completion:nil];

		}

		[delegate applyRadioSettings:FALSE]; // update frequency display if needed
	}

	// don't keep the table selection
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	SDR_DEBUGPRINT(("row selected: %ld\n", (long)indexPath.row));
	[self.tableView reloadData];
}


- (void)alertDidDismissWithButtonIndexAndTag:(NSInteger)buttonIndex Tag:(NSInteger)tag
{
	switch(tag)
	{
		case DeleteFileAlert:

			if(buttonIndex == 0)
			{
				SDR_DEBUGPRINT(("User chose to keep!\n"));
			}
			else
			{
				SDR_DEBUGPRINT(("User chose to delete!\n"));
				if ([[NSFileManager defaultManager] fileExistsAtPath:[_selectedFileURL path]])
				{
					[[NSFileManager defaultManager] removeItemAtURL:_selectedFileURL error:nil];
				}
			}
			break;

		case EnableFileplayingAlert:
			if(buttonIndex == 0)
			{
				SDR_DEBUGPRINT(("User chose to make no change!\n"));
			}
			else
			{
				[delegate setFilePlayActive:TRUE];
				SDR_DEBUGPRINT(("User chose to enable file playing!\n"));
			}
			break;

		default:
			break;
	}

	return;
}


#pragma mark -
#pragma mark File system support

- (NSString *)applicationDocumentsDirectory
{
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}


- (void)directoryDidChange:(DirectoryWatcher *)folderWatcher
{
	[self.documentURLs removeAllObjects];    // clear out the old docs and start over

	NSString *documentsDirectoryPath = [self applicationDocumentsDirectory];

	NSArray *documentsDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectoryPath error:NULL];

	for(NSString* curFileName in [documentsDirectoryContents objectEnumerator])
	{
		NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:curFileName];
		NSURL *fileURL = [NSURL fileURLWithPath:filePath];

		BOOL isDirectory;
		[[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];

		// proceed to add the document URL to our list (ignore the "Inbox" folder)
		if (!(isDirectory && [curFileName isEqualToString: @"Inbox"]))
		{
			[self.documentURLs addObject:fileURL];
		}
	}

	[self.tableView reloadData];
}


- (id <DITableViewControllerDelegate>)delegate { return delegate; }

- (void)setDelegate:(id <DITableViewControllerDelegate>)v
{
	delegate = v;
}

// OLD STUFF FOR iOS 5.1
//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
//{
//	// Return YES for supported orientations
//	return ((interfaceOrientation == UIInterfaceOrientationLandscapeLeft) || (interfaceOrientation == UIInterfaceOrientationLandscapeRight));
//}


@end
