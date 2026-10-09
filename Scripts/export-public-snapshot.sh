#!/usr/bin/env bash

# Copyright (c) 2026 OpenARDF. Licensed under the MIT License.

set -euo pipefail

if (($# != 1)); then
	printf 'usage: %s DESTINATION\n' "$0" >&2
	exit 2
fi

repo_root=$(git rev-parse --show-toplevel)
destination=$1

cd "$repo_root"

if ! git diff --quiet || ! git diff --cached --quiet; then
	printf 'error: commit or stash working-tree changes before exporting\n' >&2
	exit 1
fi

"$repo_root/Scripts/check-provenance.sh"

if ! mkdir "$destination"; then
	printf 'error: destination must not already exist: %s\n' "$destination" >&2
	exit 1
fi

git archive --format=tar HEAD | tar -xf - -C "$destination"

printf 'Exported a history-free source snapshot to %s\n' "$destination"
printf 'Initialize a new Git repository there; do not copy this repository .git directory.\n'
