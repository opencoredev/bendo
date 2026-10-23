#!/usr/bin/env bash
# Reproduce on an isolated default Boat VM; cleanup also runs on failure.
set -euo pipefail
cd "$(dirname "$0")/../.."
label="bnd4-bytes-$(date +%s)-$$"
cleanup() {
  boat-sbx gc --label "$label"
  boat-sbx ls --label "$label"
}
trap cleanup EXIT
sandbox=$(boat-sbx new --type default --label "$label")
printf 'sandbox=%s label=%s\n' "$sandbox" "$label"
archive=$(mktemp /tmp/bnd4-toolchain-XXXXXX.tgz)
# Transfer the installed, pinned toolchain; do not rely on installer latest.
tar -czf "$archive" -C "$HOME" .bend/bin .bend/bend2 .bend/guide
boat scp "$archive" "$sandbox:/home/user/toolchain.tgz"
rm "$archive"
boat scp -r prototypes/0002-bytes "$sandbox:/home/user/prototype"
boat-sbx exec "$sandbox" --timeout 300 -- 'set -eu
cd /home/user
tar -xzf toolchain.tgz
curl -fsSL https://github.com/hatoo/oha/releases/download/v1.14.0/oha-linux-amd64 -o oha
chmod +x oha
uname -a
lscpu
clang --version
./oha --version
cd prototype
./build.sh
timeout 60 python3 correctness.py
timeout 180 python3 measure.py'
