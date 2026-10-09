# Recovery and migration notes

## Source of this snapshot

The source was recovered from the latest available iSDR working tree. The
original folder was read and copied without being modified.

The recovered Xcode project reports version 5.1, build 115. A matching App
Store archive from November 24, 2019 also reports 5.1 build 115. An earlier
October 24 archive reports 5.1 build 114.

The old repository's `master` ref ends at commit
`b9618432bed652cdd5cd467f9a11c6187124e1e3`, whose reflog message is “IOS 9
changes for no errors or warnings.” Several source and project files were
modified on November 24, 2019 after that commit and immediately before the
build-115 archive. This recovery therefore uses the complete working tree,
not merely the old Git commit.

## Curation performed

- Imported the source and resources from the recovered 5.1 build-115 working
  tree without importing its historical `.git` directory.
- Excluded `DerivedData`, `.DS_Store`, Xcode `xcuserdata`, and other per-user
  or generated Xcode state.
- Replaced machine-relative source-group paths with repository-relative paths.
- Removed obsolete signing-certificate names and provisioning-profile UUIDs.
- Corrected the `FileHandler` attribution that named RIM; the project owner
  confirmed that these files were not derived from RIM code.
- Applied the OpenARDF MIT designation to Digital Confections-owned code while
  retaining third-party notices and documenting unresolved provenance.
- Preserved the previous 3.41 recovery on the `isdr-3.41-recovered` tag and
  `archive/isdr-3.41-recovered` branch.

## Modernization status

### Phase 0: preserve the recovered baseline — complete

The curated build-115 snapshot is preserved by the `isdr-5.1-recovered` tag.
The older 3.41 recovery remains on its own tag and archival branch. Current
modernization is therefore reviewable independently of both recovered trees.

### Phase 1: build with the current SDK — complete

- Raised the deployment target from iOS 9 to iOS 15, the oldest simulator
  target supported by Xcode 27.
- Added `just build` and `just check`; the latter performs clean simulator and
  unsigned device builds and treats all unwaived compiler warnings as errors.
- Removed the empty shell build phase and repaired current-Clang errors,
  including explicit graphics scalar conversions, numeric OpenGL object
  initialization, signed-overflow-safe constants, and bounded formatting.
- Replaced active deprecated atomic primitives with C++ atomics while
  preserving the original non-blocking behavior.
- Updated supported UIKit and AVFoundation call sites without redesigning the
  recovered user interface or audio pipeline.

Validation on October 8, 2026 used Xcode 27 (build 27A266a) and completed a
clean `just check` with no unwaived warnings.

### Phase 2: current iOS launch path — simulator complete

- Added a single-window `UIScene` adapter and retained the existing app
  delegate as the owner of iSDR setup and legacy lifecycle behavior.
- Replaced the removed system-volume alert with a supported `MPVolumeView`.
- Installed and launched the Debug build on an iPhone 18 Pro simulator running
  iOS 27. The application remained running, completed its audio setup, and
  rendered the recovered landscape spectrum interface.

This establishes current-SDK compile and simulator-launch compatibility. It
does not establish correct radio operation on physical hardware.

### Phase 3: physical-device installation — smoke test complete

- Reserved the Debug configuration for local development installs by using
  the distinct `org.openardf.isdr.dev` bundle identifier and the on-device
  name `iSDR Dev`.
- Enabled automatic Apple Development signing for Debug only. The AppStore and
  Distribution configurations retain the recovered
  `com.digitalconfections.iSDR1` identity and `iSDR` display name.
- Assigned the first device-test build version `5.1.0a` and build number 116.
  The Apple-required numeric bundle version remains `5.1.0`; the About screen
  reads a separate display-version key so OpenARDF test suffixes remain visible.
- Verified that Xcode 26.6 can compile an unsigned Debug build targeting iOS
  15.
- Completed a warning-clean signed arm64 build with Xcode 26.6 using automatic
  development provisioning.
- Installed `org.openardf.isdr.dev` over USB without replacing the App Store
  bundle. A debugger-assisted launch reached the audio setup path and remained
  alive through the launch-observation interval without a crash report.
- A hands-on check on physical iOS 15 hardware confirmed that the recovered
  interface remained stable and that monophonic microphone input worked
  correctly.

The command-line launcher intentionally stops the debugged process when its
observation interval ends. The bundled stereo recording exercises the
two-channel DSP and playback path, and monophonic live input has been confirmed
through the display and speaker. Live stereo input remains deferred because a
stereo-capable input interface is not currently available. External radio
hardware and networking also remain deferred.

### Phase 4: functional hardening — complete for available environment

- Assigned test version `5.1.0b`, build 117.
- Added the local-network privacy explanation required before exercising the
  recovered radio-control connection on current iOS.
- Enabled in-place Documents access so imported recordings are available
  through the Files app as well as Finder file sharing, and removed the unused
  photo-library privacy declaration.
- Added current `AVAudioSession` interruption notifications while retaining the
  existing audio-graph start/stop state model.
- Made audio-session notification registration idempotent so route
  reconfiguration cannot accumulate duplicate callbacks.
- Preserved an existing Play-and-Record category during audio reconfiguration
  instead of unnecessarily falling back to MultiRoute.
- Confirmed bundled stereo playback drives the live spectrum display in the
  iOS 27 simulator.
- Confirmed that a CAF copied into the app's Documents folder appears
  immediately in the file list and can be selected.
- Confirmed an I/Q setting survives a background/foreground transition and a
  complete process restart.
- Confirmed radio-control Wi-Fi can be enabled and disabled without connected
  hardware or an application failure. An actual connection still requires the
  external radio interface.
- Confirmed the recovered landscape interface remains usable on a current
  phone simulator. Safe-area polish on new device shapes is intentionally part
  of the later layout phase.
- Added `just device-build-ios15` and `just device-install-ios15` as the
  repeatable Xcode 26.6 signed-build and USB-install workflow for iOS 15 test
  devices. Deployment logs are captured so the device identifier is not
  printed during normal use.
- Built, signed, installed, and launched `iSDR Dev` 5.1.0b (build 117) on
  physical iOS 15 hardware through that workflow.
- A hands-on check confirmed that build 117 runs normally and that its bundled
  stereo sample reaches both the spectrum display and speaker.

The current simulator cannot synthesize a real audio interruption. Hands-on
interruption recovery, live stereo input, and radio communication remain
deferred hardware checks and do not block this phase.

### Phase 5: correctness characterization — started

- Added a host-side test harness that compiles the production radix-2 FFT with
  warnings as errors and runs it under Address Sanitizer and Undefined Behavior
  Sanitizer.
- Added independent DFT, integer impulse, and band-pass-kernel contract tests.
- The first sanitizer run found three instances of undefined signed shifting in
  packed Q15 twiddle handling. The bit container and shifts are now unsigned;
  the characterized FFT results remain unchanged.
- Added a repeatable full-target Clang static-analysis recipe.
- Recorded prioritized, source-linked findings and validation gaps in
  `RISK_INVENTORY.md`.
- Added sanitizer coverage for circular audio copies, file-buffer boundary
  rollover, and the complete mono/stereo USB, AM, and NFM analysis path.
- Replaced unsafe circular copies and file cursor advancement with tested,
  allocation-free helpers shared by production and host tests.
- Made DSP-worker startup and shutdown owned and synchronous, replaced shared
  process-global state and busy-waits, and corrected Core Foundation/C++
  ownership operations.
- Made spectrum construction all-or-nothing, guarded BPF replacement, defined
  saturating DSP arithmetic, and silenced output rather than replaying stale
  samples on underrun.
- Added atomic file-refill ownership and stable spectrum snapshots across
  asynchronous producers and consumers.

The harness now covers the highest-risk platform-neutral DSP and buffer
boundaries. Complete iOS lifecycle stress and radio protocol behavior remain
the next characterization targets.

### Phase 6: public-source provenance — source snapshot complete

- Removed the unlicensed `SimplePingHelper` files and their unused Apple
  `SimplePing` dependency.
- Removed the unlicensed `DeviceHardware` implementation and replaced its
  single required behavior with original UIKit screen/device logic.
- Mechanically compared the recovered audio, OpenGL, meter, application entry
  point, MainWindow XIBs, and Core Audio utility sources with the corresponding
  Apple samples.
- Restored Apple provenance notices and the accompanying sample-code license
  while retaining MIT coverage for OpenARDF modifications.
- Recorded the evidence and licensing boundary in `PROVENANCE.md` and
  `THIRD_PARTY_NOTICES.md`.
- Added `just provenance-check`, `just public-release-check`, and the
  history-free `just public-snapshot` export workflow.
- On October 9, 2026, `just public-release-check` passed the provenance gate,
  both sanitizer-backed test executables, warning-clean simulator and unsigned
  device builds, Clang static analysis, and a gitleaks working-tree scan.

The source snapshot passed the release gate and was published from a new Git
root. The separate recovery archive remains private because its historical Git
objects and preserved refs still contain files that are not part of this public
source set. See `PUBLIC_RELEASE.md` for that boundary.

## Explicit compatibility waivers

- **OpenGL ES:** iSDR's renderer still uses OpenGL ES 1. The target defines
  `GLES_SILENCE_DEPRECATION=1` so that this known, project-wide deprecation does
  not obscure new warnings. A future renderer phase should move this code to
  Metal before Apple removes OpenGL ES from the SDK.
- **Embedded GCDAsyncSocket:** the recovered socket implementation still uses
  deprecated Secure Transport APIs. Only `GCDAsyncSocket.m` receives
  `-Wno-deprecated-declarations`. A future networking phase should update the
  dependency or replace its TLS path with Network.framework.
- **Xcode 26.6 device discovery:** with an older iOS device connected, Xcode can
  emit `DVTDeviceOperation` diagnostics about an empty build number before an
  otherwise successful build. This is an Xcode host diagnostic, not a compiler
  warning; the signed arm64 product still builds and validates.

These are categorical, documented waivers; every other compiler warning is an
error in `just check`.

## Next phases

1. Exercise live stereo/external audio, audio interruptions, and radio
   communication when the required interfaces are available.
2. Adapt the fixed-size recovered interface for current screen sizes and safe
   areas while preserving its landscape operating model.
3. Replace OpenGL ES with Metal and resolve the socket/TLS waiver.
4. Audit App Store privacy, signing, entitlements, accessibility, and current
   review requirements only after functional hardware validation.

This repository is the sanitized public source snapshot. Keep the separate
recovery archive private and do not publish its historical refs.
