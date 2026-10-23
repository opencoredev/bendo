#!/bin/sh
# Run inside a disposable default Boat sandbox, never on the shared host.
set -eu
export BEND_NO_TELEMETRY=1
mkdir -p "$HOME/.bend" "$HOME/.local/bin"
curl -fLsS https://github.com/bendlang/bend/releases/download/v2.0.38/bend-2.0.38-linux-x64.tar.gz -o /tmp/bnd3-bend.tar.gz
tar -xzf /tmp/bnd3-bend.tar.gz --strip-components=1 -C "$HOME/.bend"
export PATH="$HOME/.bend/bin:$HOME/.local/bin:$PATH"
test "$(bend version)" = 'bend 2.0.38'
curl -fLsS https://github.com/hatoo/oha/releases/download/v1.8.0/oha-linux-amd64 -o "$HOME/.local/bin/oha"
chmod +x "$HOME/.local/bin/oha"
oha --version
clang --version
python3 --version
