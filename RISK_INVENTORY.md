# iSDR risk inventory

This is a source-grounded correctness inventory for the recovered iSDR 5.1
codebase. It distinguishes repaired defects from risks that still need hardware,
stress, or provenance evidence.

Priority meanings:

- **P0:** observed critical failure or release blocker.
- **P1:** credible crash, memory-corruption, or core correctness risk.
- **P2:** bounded correctness, reliability, or maintainability risk.
- **P3:** modernization or validation gap without evidence of current failure.

## Open risks

| ID | Priority | Evidence | Remaining work |
| --- | --- | --- | --- |
| ISDR-R003 | P2 | Cross-thread counters, flags, indices, and configuration are now atomic or mutex-protected in [`FFTBufferManager.h`](Classes/FFTBufferManager.h), [`FFTBufferManager.cpp`](Classes/FFTBufferManager.cpp), and [`SpectrumAnalysis.cpp`](Other%20Sources/fft/SpectrumAnalysis.cpp). Spectrum results are copied to a size-checked UI snapshot at [`FFTBufferManager.cpp:450`](Classes/FFTBufferManager.cpp#L450). | The known C++ data races have been removed, but Thread Sanitizer has not been run against the complete iOS audio lifecycle. Stress repeated route changes, flushes, backgrounding, and controller teardown on a device; investigate any underrun rather than relaxing synchronization. |
| ISDR-R011 | P2 | Wi-Fi control was checked only without external radio hardware. The recovered socket dependency has a documented Secure Transport waiver, and command throttling still uses shared global timing state in [`WifiInterface.m`](Wifi/WifiInterface.m). | Add a loopback fake-radio server to cover parsing, reconnection, and delayed-command ordering before replacing the socket layer; then validate with the actual radio interface. |
| ISDR-R013 | P2 | Filter/configuration mutation and DSP processing now share a mutex at [`SpectrumAnalysis.cpp:348`](Other%20Sources/fft/SpectrumAnalysis.cpp#L348) and [`SpectrumAnalysis.cpp:362`](Other%20Sources/fft/SpectrumAnalysis.cpp#L362). This protects correctness, and the real-time render callback itself never takes this lock. | Measure tuning and mode-change latency on hardware. A filter rebuild can briefly delay the worker and cause a deliberately silenced output underrun; if measurable, move to versioned immutable filter snapshots. |

## Risks addressed in this branch

| ID | Original risk | Repair and evidence |
| --- | --- | --- |
| ISDR-R001 | `new`/`free` mismatch and worker use-after-free during controller teardown. | The audio graph is stopped first, the joinable DSP worker is synchronously terminated and deleted, then the buffer manager is deleted in [`MultichannelMixerController.mm:601`](Classes/MultichannelMixerController.mm#L601). Both worker shutdown paths join in [`dspThread.cpp:129`](Other%20Sources/Threads/dspThread.cpp#L129) and [`dspThread.cpp:159`](Other%20Sources/Threads/dspThread.cpp#L159). |
| ISDR-R002 | A `CFRunLoopSourceRef` was freed with the C allocator, and dormant mismatched ownership remained. | The source is removed and released with `CFRelease` at [`dspThread.cpp:84`](Other%20Sources/Threads/dspThread.cpp#L84). The unused controller fields and stale free blocks were removed. |
| ISDR-R004 | Ring copies could run past the allocation at wraparound and assumed at most two buffers. | [`AudioBufferUtilities.h:14`](Classes/AudioBufferUtilities.h#L14) splits a copy at the ring boundary; `GrabAudioData` rejects unsupported lists and uses the helper. [`DSPCoreTests.c:140`](Tests/DSPCoreTests.c#L140) checks a two-part wrap and invalid bounds under Address Sanitizer. |
| ISDR-R005 | File playback changed buffer indices without changing the source pointer during the same render call. | [`AudioBufferUtilities.h:59`](Classes/AudioBufferUtilities.h#L59) owns cursor advancement across both file buffers. The callback uses it at [`MultichannelMixerController.mm:490`](Classes/MultichannelMixerController.mm#L490), and [`DSPCoreTests.c:156`](Tests/DSPCoreTests.c#L156) covers a render spanning the boundary. |
| ISDR-R006 | Signed shifts/overflow, AM magnitude overflow, and an NFM zero denominator made DSP behavior undefined. | Saturating sample arithmetic and guarded magnitude/demodulation are centralized beginning at [`SpectrumAnalysis.cpp:68`](Other%20Sources/fft/SpectrumAnalysis.cpp#L68). The sanitizer harness covers mono/stereo USB, AM, and NFM with silence and extreme signed input in [`SpectrumAnalysisTests.cpp`](Tests/SpectrumAnalysisTests.cpp). The first extended run found an additional signed shift in magnitude conversion; it was repaired before this branch was validated. |
| ISDR-R007 | Partial allocation failure could escape constructors, and BPF creation dereferenced a failed allocation. | Spectrum construction is all-or-nothing starting at [`SpectrumAnalysis.cpp:216`](Other%20Sources/fft/SpectrumAnalysis.cpp#L216); BPF replacement is prepared before the old kernel is released. [`rad2fft.c:260`](Other%20Sources/fft/rad2fft.c#L260) validates dimensions and every allocation. `FFTBufferManager::isValid()` makes worker startup fail closed. Actual allocator-fault injection remains a useful P3 test enhancement. |
| ISDR-R008 | Process-global worker state and unbounded busy-waits could hang startup or couple controller instances. | Worker state is per-instance and atomic. A condition variable provides a thread-startup handshake, failed creation unwinds ownership, and all six setup paths use [`ensureDSPResourcesForChannels:`](Classes/MultichannelMixerController.mm#L568) instead of spinning. |
| ISDR-R009 | The render callback and refill timer raced on a plain file-buffer bitmask. | Every shared flag load and update now uses acquire/release atomic builtins; callback exhaustion is an atomic OR at [`MultichannelMixerController.mm:497`](Classes/MultichannelMixerController.mm#L497), while refills atomically clear their owned bit in [`FileHandler.m`](FileSharing/FileHandler.m). |
| ISDR-R010 | The initial review suspected a missing `[super dealloc]` leak. | Withdrawn as a false positive: `FileHandler.m` is compiled with ARC. Adding `[super dealloc]` produced the expected ARC compiler error, confirming that ARC performs superclass teardown. Its manually allocated audio buffers are still explicitly freed in `dealloc`. |
| ISDR-R012 | Unlicensed `SimplePingHelper` and `DeviceHardware` files, plus Apple-derived source whose original notices had been replaced, blocked public release. | The unlicensed and unused files were removed, the one required device-model behavior was replaced with original UIKit-based code, and the Apple sample provenance/license references were restored. `just provenance-check` enforces the boundary. [`PROVENANCE.md`](PROVENANCE.md) records the evidence. Existing recovery history remains private; only a clean-root export described in [`PUBLIC_RELEASE.md`](PUBLIC_RELEASE.md) is cleared for publication. |

The earlier Q15 finding also remains fixed: `PackedInt16Cplx` is an unsigned
32-bit bit container, so packing negative twiddle components no longer performs
undefined signed shifts while preserving the represented bits.

## Automated evidence

`just test` now builds two host executables from production DSP sources with
`-Wall -Wextra -Werror`, Address Sanitizer, and Undefined Behavior Sanitizer:

- `DSPCoreTests.c` compares the floating FFT with an independent DFT, checks an
  integer impulse invariant and BPF contracts, and exercises ring and file
  cursor boundary behavior.
- `SpectrumAnalysisTests.cpp` covers mono and stereo creation plus USB, AM, and
  NFM processing using silence and alternating `INT32_MIN`/`INT32_MAX` input.

`just analyze` runs Clang's interprocedural analyzer over the complete iOS
target. `just check` runs both host test executables before warning-clean
simulator and unsigned-device builds.

Validation on October 8, 2026 passed all three gates: both sanitizer-backed
host executables, the complete Clang analysis, and clean simulator plus device
builds with unwaived warnings treated as errors.

Validation on October 9, 2026 additionally passed `just
public-release-check`: the source-provenance gate, both sanitizer executables,
clean simulator and unsigned-device builds, Clang static analysis, and the
gitleaks working-tree scan.

## Recommended next order

1. Perform repeated audio start/stop, route-change, interruption, tuning, and
   background/foreground stress on the iOS 15 device; add Thread Sanitizer
   coverage wherever Apple's audio stack permits it.
2. Add the fake-radio protocol harness for R011, then test the real interface.
3. Create the clean-root public repository from a validated sanitized snapshot;
   do not publish this private recovery repository's historical refs.
4. Begin layout, Metal, and socket-framework modernization with the DSP and
   cursor tests retained as regression gates.
