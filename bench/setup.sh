#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.bend/bin:$HOME/.bun/bin:$PATH"
export BEND_NO_TELEMETRY=1
sudo apt-get update -qq
sudo apt-get install -y -qq ca-certificates curl git unzip build-essential clang
curl -fsSL https://bun.sh/install -o /tmp/bun-install.sh
bash /tmp/bun-install.sh bun-v1.4.4
# run.ts uploads the exact pinned toolchain from the orchestrating machine.
mkdir -p "$HOME/.bend"
tar -xzf /tmp/bend-local.tar.gz -C "$HOME"
bun run check:bend
curl -fLsS https://github.com/hatoo/oha/releases/download/v1.16.0/oha-linux-amd64 -o /tmp/oha
sudo install -m 755 /tmp/oha /usr/local/bin/oha
bun install --frozen-lockfile
(cd bench/servers && bun install --frozen-lockfile)
bunx tsc -p bench/tsconfig.json
