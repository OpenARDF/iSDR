# Public repository handoff

ISDR-R012 is cleared for the current sanitized source snapshot, subject to the
remaining release process below. The private recovery repository itself is not
cleared for public visibility because its historical objects and refs still
contain files removed for lack of a redistribution license.

## Required release model

1. Keep this recovery repository private as the historical archive.
2. Finish and commit the sanitized tree, then run `just public-release-check`.
3. Export that exact clean commit with:

   ```sh
   just public-snapshot /absolute/path/to/new-empty-directory
   ```

4. Initialize a new Git repository in the exported directory and make one root
   commit. Do not copy this repository's `.git` directory, tags, branches,
   reflogs, bundles, or archives.
5. Run `just public-release-check` again in the new repository before making
   it public.
6. Confirm the public repository's name and the private archive's final name
   before changing any GitHub visibility or remotes.

This preserves the recovered history privately while publishing only the
source set covered by the licensing record in [PROVENANCE.md](PROVENANCE.md).
