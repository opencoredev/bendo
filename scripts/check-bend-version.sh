#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
expected=$(cat "$root/.bend-version")
if ! installed=$(bend version); then
  echo 'Cannot run bend version. Install Bend and add ~/.bend/bin to PATH (see AGENTS.md).' >&2
  exit 1
fi
if [ "$installed" != "bend $expected" ]; then
  printf 'Bend version mismatch: expected bend %s from .bend-version, got %s. See AGENTS.md.\n' "$expected" "$installed" >&2
  exit 1
fi
printf 'Bend version OK: %s\n' "$installed"
