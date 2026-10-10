# Third-party notices

OpenARDF-owned code and OpenARDF modifications are licensed under the MIT
License in [LICENSE](LICENSE). That grant does not replace the terms governing
third-party portions identified below.

## Apple sample code

The following source groups contain code from, or derived from, Apple sample
projects:

- aurioTouch and aurioTouch2:
  - `Classes/EAGLView.h` and `.mm`
  - `Classes/EAGLViewController.h` and `Classes/EAGLviewController.mm`
  - `Classes/FFTBufferManager.h` and `.cpp`
  - `Classes/iSDRAppDelegate.h` and `.mm`
  - `Other Sources/iSDR_helper.h` and `.cpp`
  - `Other Sources/main.m`
  - `Resources/Base.lproj/MainWindow.xib`
  - `Resources-iPad/Base.lproj/MainWindow-iPad.xib`
  - `Resources-iPad/Resources/en.lproj/MainWindow-iPad.xib`
- SpeakHere audio meters:
  - `AudioViews/AULevelMeter.h` and `.mm`
  - `AudioViews/GLLevelMeter.h` and `.m`
  - `AudioViews/LevelMeter.h` and `.m`
  - `AudioViews/MeterTable.h` and `.cpp`
- Multi-Channel Mixer:
  - `Classes/MultichannelMixerController.h` and `.mm`
- Core Audio Utility Classes:
  - `Other Sources/iPublicUtility/*`
- Other Apple sample components:
  - `FileSharing/DITableViewController.h` and `.m`
  - `FileSharing/DirectoryWatcher.h` and `.m`

The files retain an Apple notice or a provenance notice referring to
[LICENSES/Apple-Sample-Code.txt](LICENSES/Apple-Sample-Code.txt). OpenARDF's
substantial modifications are MIT-licensed; Apple's underlying portions
remain under Apple's sample-code terms.

## Reachability

`Wifi/Reachability/Reachability.h` and `.m` contain Apple's original
sample-code terms and the BSD-style license for extensions by Andrew W.
Donoho and Donoho Design Group, LLC. Both notices remain in the files.

## CocoaAsyncSocket

`Wifi/GCD/GCDAsyncSocket.*` and `Wifi/GCD/GCDAsyncUdpSocket.*` identify
themselves as public-domain code created and maintained by Robbie Hanson,
Deusty LLC, and the Apple development community. Their original notices
remain in the files.

## Excluded unresolved material

This public repository excludes `SimplePingHelper`, whose public upstream
carried no redistribution license, and `DeviceHardware`, whose public upstream
declared no license. The unused Apple `SimplePing` copies were also excluded so
the repository contains no dormant ping implementation.

These files were removed before this public repository's initial root commit
and are not present in its Git history. The separate private recovery archive
retains historical evidence that is outside this repository's cleared source
set, as described in [PUBLIC_RELEASE.md](PUBLIC_RELEASE.md).
