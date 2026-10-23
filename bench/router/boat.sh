#!/bin/sh
# Run from the repo root. Cleanup covers failed setup, measurement, and copying.
set -eu
export BOAT_SBX_LABEL="bnd-16-router-trie-$$"
sandbox_id=$(boat-sbx new --type default --ttl 1800)
trap 'boat-sbx gc --label "$BOAT_SBX_LABEL"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
boat-sbx exec "$sandbox_id" -- 'mkdir -p /home/user/bendo/src /home/user/bendo/bench'
boat scp -r src/router "$sandbox_id":/home/user/bendo/src/
boat scp -r bench/router "$sandbox_id":/home/user/bendo/bench/
boat scp .bend-version "$sandbox_id":/home/user/bendo/.bend-version
boat-sbx exec "$sandbox_id" --cwd /home/user/bendo --timeout 180 -- '
  set -eu
  version=$(cat .bend-version)
  mkdir -p "$HOME/.bend"
  curl -fLsS "https://github.com/bendlang/bend/releases/download/v$version/bend-$version-linux-x64.tar.gz" -o /tmp/bendo-bend.tar.gz
  tar -xzf /tmp/bendo-bend.tar.gz --strip-components=1 -C "$HOME/.bend"
  export PATH="$HOME/.bend/bin:$PATH"
  test "$(bend version)" = "bend $version"
'
boat-sbx exec "$sandbox_id" --cwd /home/user/bendo --timeout 480 -- \
  "export PATH=\"\$HOME/.bend/bin:\$PATH\"; export BOAT_SANDBOX_ID='$sandbox_id'; timeout 7m python3 -u bench/router/run.py"
boat scp "$sandbox_id":/home/user/bendo/bench/router/results.json bench/router/results.json
boat-sbx gc --label "$BOAT_SBX_LABEL"
boat-sbx ls --label "$BOAT_SBX_LABEL"
trap - EXIT INT TERM
