//
//  AboutViewController.h
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

#import <UIKit/UIKit.h>
#import "iSDRAppDelegate.h"

#define ABOUT_TEXT_WIFI_NEWER ([NSString stringWithFormat:@"Support for %@ is available at http://isdr.digitalconfections.com\
\nPlease scroll down to read basic instructions for use.\n\
\n%@ is a software defined radio application for the iPhone, iPod touch and iPad. This app is designed for experimenters, shortwave listeners, and amateur radio enthusiasts who would like to use iOS products to control their radios via Wi-Fi and demodulate I/Q signals without a PC.\n\n\
h^INSTRUCTIONS^h\n\n\
b^FRONT PANEL^b (Main screen)\n\n\
o   i^_i.png^i - Takes you to the Options Menu.\n\
o   i^_switch.png^i - Turns audio on or off.\n\
o   i^_wifi disabled^i - Tap to connect to radio interface.\n\
o   Tune - Slide one finger along the Tune bar to change frequency.\n\
o   Toggle between display modes - Tap the signal display twice (avoid red cursor).\n\
o   Change filter bandwidth setting - Tap the red cursor twice.\n\
o   Change receiver mode (LSB, USB, CW etc.) - Tap the freq/mode text twice.\n\
o   Change AGC setting (Slow, Fast, or Off) - Tap the signal strength meter twice.\n\n\
b^OPTIONS MENU^b\n\n\
o   About %@ > This page.\n\
o   Off Line Only - prevents %@ from using live microphone signals.\n\
o   I/Q: - inverts %@'s in-phase quadrature logic.\n\
o   Center Frequency: > sets frequency displayed at middle of the tuning scale.\n\
o   Files: > select file to play. Hold for 3-seconds to delete a file.\n\n\
b^Be sure to check the native Settings app for more preferences options.^b\n\n\
\nb^ACKNOWLEDGEMENTS^b\n\n\
Special thanks to Richard Quick, W4RQ for his excellent interoperability testing. His detailed test reports have made this app a better product.\n\n\
Thanks to Mel Seyle, W4MEL and to Terry Fox, WB4JFI for many hours of testing, research and development support. This app has benefitted greatly from their efforts!\n\n\
On-air recording of 2008 CQ World-Wide WPX Contest used with permission, courtesy of Fred Krom (PE0FKO).\n\n\
\nb^BIBLIOGRAPHY^b\n\n\
%@ was made possible by the information provided by the following technical resources:\n\n\
\"An Introduction to Signal Processing and Fast Fourier Transform (FFT)\" by Kevin J. McGee.\n\n\
\"The Scientist and Engineer's Guide to Digital Signal Processing\" by Steven W. Smith, Ph.D.\n\n\
The QST series of articles titled \"A Software-Defined Radio for the Masses\" parts 1-4 by Gerald Youngblood, AC5OG\n\n\
Copyright © 2009-2026 OpenARDF\n\
All Rights Reserved.", appname, appname, appname, appname, appname, appname])

#define ABOUT_TEXT_ISDR_NEWER ([NSString stringWithFormat:@"Support for %@ is available at http://isdr.digitalconfections.com\
\nPlease scroll down to read basic instructions for use.\n\
\n%@ is a software defined radio application for the iPhone, iPod touch and iPad. This app is designed for experimenters, shortwave listeners, and Amateur Radio enthusiasts who would like to experiment with portable SDR.\n\n\
h^INSTRUCTIONS^h\n\n\
b^FRONT PANEL^b (Main screen)\n\n\
o   i^_i.png^i - Takes you to the Options Menu.\n\
o   i^_switch.png^i - Turns audio on or off.\n\
o   i^lock_off.png^i - Tap twice to lock/unlock the screen.\n\
o   Tune - Slide one finger along the Tune bar to change frequency.\n\
o   Toggle between display modes - Tap the signal display twice (avoid red cursor).\n\
o   Change filter bandwidth setting - Tap the red cursor twice.\n\
o   Change receiver mode (LSB, USB, CW etc.) - Tap the freq/mode text twice.\n\
o   Change AGC setting (Slow, Fast, or Off) - Tap the signal strength meter twice.\n\n\
b^OPTIONS MENU^b\n\n\
o   About %@ > This page.\n\
o   Off Line Only - prevents %@ from using live microphone signals.\n\
o   I/Q: - inverts %@'s in-phase quadrature logic.\n\
o   Center Frequency: > sets frequency displayed at middle of the tuning scale.\n\
o   Files: > select file to play. Hold for 3-seconds to delete a file.\n\n\
b^Be sure to check the native Settings app for more preferences options.^b\n\n\
\nb^ACKNOWLEDGEMENTS^b\n\n\
On air recording of 2008 CQ World-Wide WPX Contest used with permission, courtesy of Fred Krom (PE0FKO).\n\n\
\nb^BIBLIOGRAPHY^b\n\n\
%@ was made possible by the information provided by the following technical resources:\n\n\
\"An Introduction to Signal Processing and Fast Fourier Transform (FFT)\" by Kevin J. McGee.\n\n\
\"The Scientist and Engineer's Guide to Digital Signal Processing\" by Steven W. Smith, Ph.D.\n\n\
The QST series of articles titled \"A Software-Defined Radio for the Masses\" parts 1-4 by Gerald Youngblood, AC5OG\n\n\
Copyright © 2009-2026 OpenARDF\n\
All Rights Reserved.", appname, appname, appname, appname, appname, appname])

#define ABOUT_TEXT_WIFI_OLD ([NSString stringWithFormat:@"Support for %@ is available at http://isdr.digitalconfections.com\
\nPlease scroll down to read basic instructions for use.\n\
\n%@ is a software defined radio application for the iPhone, iPod touch and iPad. This app is designed for experimenters, shortwave listeners, and amateur radio enthusiasts who would like to use iOS products to control their radios via Wi-Fi and demodulate I/Q signals without a PC.\n\n\
INSTRUCTIONS\n\n\
FRONT PANEL (Main screen)\n\n\
o   i - Takes you to the Options Menu.\n\
o   ON/OFF - Turns audio on or off.\n\
o   Wi-Fi - Tap to connect to radio interface.\n\
o   Tune - Slide one finger along the Tune bar to change frequency.\n\
o   Toggle between display modes - Tap the signal display twice (avoid red cursor).\n\
o   Change filter bandwidth setting - Tap the red cursor twice.\n\
o   Change receiver mode (LSB, USB, CW etc.) - Tap the freq/mode text twice.\n\
o   Change AGC setting (Slow, Fast, or Off) - Tap the signal strength meter twice.\n\n\
OPTIONS MENU\n\n\
o   About %@ > This page.\n\
o   Off Line Only - prevents %@ from using live microphone signals.\n\
o   I/Q: - inverts %@'s in-phase quadrature logic.\n\
o   Center Frequency: > sets frequency displayed at middle of the tuning scale.\n\
o   Files: > select file to play. Hold for 3 seconds to delete a file.\n\n\
Be sure to check the native Settings app for more preferences options.\n\n\
\nACKNOWLEDGEMENTS\n\n\
Special thanks to Richard Quick, W4RQ for his excellent interoperability testing. His detailed test reports have made this app a better product.\n\n\
Thanks to Mel Seyle, W4MEL and to Terry Fox, WB4JFI for many hours of testing, research and development support. This app has benefitted greatly from their efforts!\n\n\
On-air recording of 2008 CQ World-Wide WPX Contest used with permission, courtesy of Fred Krom (PE0FKO).\n\n\
\nBIBLIOGRAPHY\n\n\
%@ was made possible by the information provided by the following technical resources:\n\n\
\"An Introduction to Signal Processing and Fast Fourier Transform (FFT)\" by Kevin J. McGee.\n\n\
\"The Scientist and Engineer's Guide to Digital Signal Processing\" by Steven W. Smith, Ph.D.\n\n\
The QST series of articles titled \"A Software-Defined Radio for the Masses\" parts 1-4 by Gerald Youngblood, AC5OG\n\n\
Copyright © 2009-2026 OpenARDF\n\
All Rights Reserved.", appname, appname, appname, appname, appname, appname])

#define ABOUT_TEXT_ISDR_OLD ([NSString stringWithFormat:@"Support for %@ is available at http://isdr.digitalconfections.com\
\nPlease scroll down to read basic instructions for use.\n\
\n%@ is a software defined radio application for the iPhone, iPod touch and iPad. This app is designed for experimenters, shortwave listeners, and Amateur Radio enthusiasts who would like to experiment with portable SDR.\n\n\
INSTRUCTIONS\n\n\
FRONT PANEL (Main screen)\n\n\
o   i - Takes you to the Options Menu.\n\
o   ON/OFF - Turns audio on or off.\n\
o   Lock - Tap twice to lock/unlock the screen.\n\
o   Tune - Slide one finger along the Tune bar to change frequency.\n\
o   Toggle between display modes - Tap the signal display twice (avoid red cursor).\n\
o   Change filter bandwidth setting - Tap the red cursor twice.\n\
o   Change receiver mode (LSB, USB, CW etc.) - Tap the freq/mode text twice.\n\
o   Change AGC setting (Slow, Fast, or Off) - Tap the signal strength meter twice.\n\n\
OPTIONS MENU\n\n\
o   About %@ > This page.\n\
o   Off Line Only - prevents %@ from using live microphone signals.\n\
o   I/Q: - inverts %@'s in-phase quadrature logic.\n\
o   Center Frequency: > sets frequency displayed at middle of the tuning scale.\n\
o   Files: > select file to play. Hold for 3 seconds to delete a file.\n\n\
Be sure to check the native Settings app for more preferences options.\n\n\
\nACKNOWLEDGEMENTS\n\n\
On air recording of 2008 CQ World-Wide WPX Contest used with permission, courtesy of Fred Krom (PE0FKO).\n\n\
\nBIBLIOGRAPHY\n\n\
%@ was made possible by the information provided by the following technical resources:\n\n\
\"An Introduction to Signal Processing and Fast Fourier Transform (FFT)\" by Kevin J. McGee.\n\n\
\"The Scientist and Engineer's Guide to Digital Signal Processing\" by Steven W. Smith, Ph.D.\n\n\
The QST series of articles titled \"A Software-Defined Radio for the Masses\" parts 1-4 by Gerald Youngblood, AC5OG\n\n\
Copyright © 2009-2026 OpenARDF\n\
All Rights Reserved.", appname, appname, appname, appname, appname, appname])

@interface AboutViewController : UIViewController <UITextViewDelegate>
{
	UITextView*					textViewVersion;
	UITextView*					textViewBuild;
	UITextView*					textViewInstructions;
	iSDRAppDelegate*			__weak appDelegate;
}

@property (nonatomic, strong) IBOutlet UITextView*	textViewVersion;
@property (nonatomic, strong) IBOutlet UITextView*	textViewBuild;
@property (nonatomic, strong) IBOutlet UITextView*	textViewInstructions;
@property (nonatomic, weak) iSDRAppDelegate*		appDelegate;

+ (NSMutableAttributedString*)styledDescription:(NSString*)description fontsize:(float)fontSize;
+ (NSString*)stripFormatting:(NSString*)description;

@end
