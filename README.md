# iSDR

iSDR is a software-defined radio application for iPhone, iPod touch, and iPad.
It was created for experimenters, shortwave listeners, and amateur radio
operators using external SDR hardware. Development began around 2009, and the
application launched during the first-iPad era.

## Repository status

`main` begins with a curated recovery of the latest iSDR working tree found on
Charles's MacBook Pro. The Xcode project identifies this application as iSDR
5.1, build 115. A matching App Store Xcode archive was created on November 24,
2019, immediately after the latest recovered source edits.

The original working tree, rather than its historical Git `HEAD`, is the
recovery source because release changes made on November 24, 2019 were not
committed to the old repository. Generated build output, old Git internals,
Finder metadata, and per-user Xcode state are deliberately excluded.

The earlier recovered 3.41 snapshot remains available for reference through
the `isdr-3.41-recovered` tag and the `archive/isdr-3.41-recovered` branch.

The recovery baseline is tagged `isdr-5.1-recovered`. Current development on
top of that baseline builds with Xcode 27 and the current iOS SDK, treating
unwaived warnings as errors, and launches successfully in an iOS 27 simulator.
The interface remains intentionally close to the recovered release; current
device-specific layout work and physical SDR/audio-hardware validation are
still deferred.

Run `just --list` to see the supported repository tasks, `just test` for the
sanitizer-backed DSP characterization tests, `just analyze` for Clang static
analysis, and `just check` for the tests plus clean current-SDK simulator and
unsigned device builds. `just public-release-check` adds the source-provenance
and secret-scanning gates. See [RISK_INVENTORY.md](RISK_INVENTORY.md) for the
current, source-grounded correctness priorities,
[PROVENANCE.md](PROVENANCE.md) for the source audit, and
[PUBLIC_RELEASE.md](PUBLIC_RELEASE.md) for the required clean-history public
repository handoff. See
[MIGRATION_NOTES.md](MIGRATION_NOTES.md) for the validation record,
compatibility waivers, and next steps.

## License

OpenARDF-owned code is licensed under the MIT License. See [LICENSE](LICENSE).
OpenARDF modifications to third-party sample code are also MIT-licensed, while
the underlying portions remain under their original terms. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the texts in
[`LICENSES/`](LICENSES).
