#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.bend/bin:$HOME/.elan/bin:$HOME/.bun/bin:$PATH"
cd "$(dirname "$0")"
output=${BND4_OUT:-/tmp/bendo-0002-bytes}
mkdir -p "$output"
test "$(bend version)" = "bend 2.0.38"
for kind in bytes strings; do
  timeout 60 bend "server-$kind.bend" -o "$output/server-$kind"
  timeout 60 bend "bench-$kind.bend" -o "$output/bench-$kind"
done
