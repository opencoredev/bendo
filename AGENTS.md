# Bendo agent guide

Bendo is a Hono-style web framework written in Bend, plus a TypeScript toolkit. Read `docs/PLAN.md` before any work: it holds the design decisions, milestones and the definition of done. Work is tracked in Linear, team BND, project "Bendo v1".

## Toolchain

Bend is pinned in `.bend-version`; Lean is pinned in `lean-toolchain` at the
version required by Bend's strict proof kernel. Run the following from the repo
root on a clean Ubuntu 24.04 machine (with sudo access):

```sh
sudo apt-get update
sudo apt-get install -y ca-certificates curl git unzip build-essential clang

curl -fsSL https://bun.sh/install -o /tmp/bendo-bun-install.sh
bash /tmp/bendo-bun-install.sh
export PATH="$HOME/.bun/bin:$PATH"

curl -fsSL https://bend-lang.com/install.sh -o /tmp/bendo-bend-install.sh
BEND_NO_TELEMETRY=1 sh /tmp/bendo-bend-install.sh
export PATH="$HOME/.bend/bin:$PATH"
export BEND_NO_TELEMETRY=1
bun run check:bend

curl -fsSL https://elan.lean-lang.org/elan-init.sh -o /tmp/bendo-elan-init.sh
sh /tmp/bendo-elan-init.sh -y --no-modify-path --default-toolchain none
export PATH="$HOME/.elan/bin:$PATH"
elan toolchain install "$(cat lean-toolchain)"

bun install --frozen-lockfile
timeout --foreground 10m bun run check
timeout --foreground 10m bend PROOF.bend --verdict
```

Both proof commands must print `ALL PROOFS CHECK`. Elan selects the repo's
`lean-toolchain` automatically; no global Lean default is needed. Add
`~/.bun/bin`, `~/.bend/bin` and `~/.elan/bin` to your shell's PATH for later
sessions. Bend builds its proof kernel on the first strict check.

The Bend installer currently installs its bundled release and accepts no version
argument. `bun run check:bend` compares `bend version` with `.bend-version` and
stops on a mismatch, including in CI. If the installer advances, obtain the
pinned release from https://github.com/bendlang/bend/releases (including its
`bin`, `bend2` and `guide` directories under `~/.bend`), then rerun the check.
Do not change the pin just to bypass a mismatch.

Bend v2 is newer than most model training data. Read `~/.bend/guide/GUIDE.md` and `bend base <Name>` before writing Bend. Do not guess syntax from Bend v1 or HVM examples.

## Commands

- `bun run prove`: check every proof with the Lean-backed kernel (`bend PROOF.bend --verdict`).
- `bun run typecheck`: TypeScript.
- `bun run test`: integration tests. They compile Bend examples to native binaries and hit them over HTTP.
- `bun run check:bend`: validate the installed Bend version against `.bend-version`.
- `bun run check`: the version check and all of the above. It must pass before work lands.

## Bend rules that bite

- Define a def above every def that calls it.
- `match` only on a parameter or a pattern variable, never on a computed value. Give the computation its own def.
- No `if`. Match on `True{}` and `False{}`.
- Recursion must shrink an argument. A loop bounded by the outside world counts down a `Nat` fuel argument or is marked `@unsafe`.
- No mutual recursion. Merge the functions into one def with a mode argument.
- Functions are not copyable. Pass handlers as templates (`~app`), which inline at compile time.
- Mark a value `+` to use it more than once (it must be `Data`).

## Laws

`LAWS.bend` states what must hold. `PROOF.bend` proves it. You may add laws. Never delete or weaken a law without a written reason in the commit message and a comment on the Linear issue. Pure code goes in modules the laws can import. IO and `@unsafe` code stays in thin shells covered by integration tests.

## TypeScript

Follow `~/.agents/skills/typescript-best-practices/SKILL.md` when it exists on your machine: discriminated unions, no `as` casts, parse external data at the boundary, exhaustive switches.

## Testing

Test real behavior. Integration tests compile a Bend server and talk to it with `fetch` or raw sockets. Keep runs bounded: `bun test --timeout 30000`. Heavy benchmarks and fuzzing run on Boat sandboxes, not the shared server.
