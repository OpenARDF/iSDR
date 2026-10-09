# Public repository boundary

This repository was created from the ISDR-R012-cleared source snapshot as a new
Git root. It does not contain the private recovery repository's historical
objects, refs, reflogs, bundles, or archives.

The separate recovery archive is not cleared for public visibility because its
history preserves files that were removed for lack of a redistribution
license.

## Reproducing a sanitized export

Run the complete release gate before exporting a future snapshot:

```sh
just public-release-check
just public-snapshot /absolute/path/to/new-empty-directory
```

The export contains only the source set covered by the licensing record in
[PROVENANCE.md](PROVENANCE.md). If it is used to create another repository, do
not copy Git metadata from the private recovery archive.
