# Source provenance record

This record captures the evidence used to resolve ISDR-R012 for a sanitized
public source snapshot. It is an engineering provenance review, not a legal
opinion.

## Ownership basis

Charles Scharlau, manager and sole owner of Digital Confections, designated
Digital Confections-owned iSDR code as OpenARDF open source under the MIT
License. Files carrying OpenARDF or Digital Confections ownership notices are
therefore treated as OpenARDF-owned unless stronger file-specific evidence
identifies third-party portions.

The earlier RIM attribution in `FileSharing/FileHandler.m` was corrected
because the owner confirmed that no RIM code was used.

## Third-party evidence

| Area | Evidence | Resolution |
| --- | --- | --- |
| `SimplePingHelper` | The recovered files identify Chris Hulbert and say “All rights reserved.” The public [SimplePingHelper repository](https://github.com/chrishulbert/SimplePingHelper) has no license grant. | Removed the helper, the unused Apple `SimplePing` dependency, their project entries, and the unreachable ping UI callback. |
| `DeviceHardware` | Identifiers, mappings, and documentation match [duhovny/DeviceHardware](https://github.com/duhovny/DeviceHardware), whose public repository declares no license. | Removed the files and project entries. A small original helper now uses UIKit screen/device information for the only behavior iSDR required. |
| aurioTouch/aurioTouch2 | File names, abstracts, class structure, and mechanically compared source match Apple's aurioTouch family, including `FFTBufferManager`, `EAGLView`, the application entry point, the MainWindow XIB variants, and the renamed remote-I/O helper. | Restored Apple provenance notices and the accompanying sample-code license; OpenARDF modifications remain MIT-licensed. |
| Apple multichannel mixer | `MultichannelMixerController` name, abstract, audio-graph structure, and retained source match Apple's “Using an AUGraph with the Multi-Channel Mixer and Remote I/O Audio Unit” sample. | Restored Apple provenance notices and the accompanying sample-code license; OpenARDF modifications remain MIT-licensed. |
| SpeakHere meters | `GLLevelMeter`, `LevelMeter`, `MeterTable`, and the renamed `AULevelMeter` mechanically match Apple's SpeakHere meter implementation. | Restored Apple provenance notices and the accompanying sample-code license; OpenARDF modifications remain MIT-licensed. |
| Core Audio Utility Classes | File names and implementation match Apple's utility classes; several recovered files already retained Apple's complete notice. | Added equivalent provenance references to the files whose Apple notice had been replaced and retained full notices already present. |
| `SpectrumAnalysis` and `rad2fft` | The recovered files carry Digital Confections/OpenARDF notices. Exact public-code searches for their distinctive exported identifiers and abstracts produced no third-party source match. | Covered by the owner's MIT designation. The negative search is supporting evidence, not an independent proof of authorship. |
| Reachability | The files retain Apple's sample terms and Andrew Donoho's BSD-style extension license. | Retained both notices. |
| CocoaAsyncSocket | The files retain their public-domain dedication. | Retained the dedication. |

## Automated boundary

`just provenance-check` fails if:

- the removed unresolved files or their project references reappear;
- known Apple-derived files lose their license reference;
- the Apple sample-code license text is absent; or
- a source file lacks a recognized ownership, license, or public-domain marker.

`just public-release-check` runs that gate, the sanitizer-backed tests, clean
simulator and device builds with warnings as errors, Clang static analysis, and
a working-tree secret scan.

## Historical boundary

The existing Git object database, tags, branches, and remote refs preserve the
recovered snapshots and therefore still contain the removed files. They are
not part of the cleared public source set. Public release requires a new Git
root created from a clean export of a validated commit; it must not publish or
mirror this repository's existing refs.
