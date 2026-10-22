# Bendo agent guide

Bendo is a Hono-style web framework written in Bend, plus a TypeScript toolkit. Read `docs/PLAN.md` before any work: it holds the design decisions, milestones and the definition of done. Work is tracked in Linear, team BND, project "Bendo v1".

## Toolchain

- Bend 2.0.38, installed with `curl -fsSL https://bend-lang.com/install.sh | BEND_NO_TELEMETRY=1 sh`. Add `~/.bend/bin` to PATH.
- Bun for the TypeScript packages and tests.
- Lean (through elan) for `bend PROOF.bend --verdict`.

Bend v2 is newer than most model training data. Read `~/.bend/guide/GUIDE.md` and `bend base <Name>` before writing Bend. Do not guess syntax from Bend v1 or HVM examples.

## Commands

- `bun run prove`: check every proof (`bend PROOF.bend`).
- `bun run typecheck`: TypeScript.
- `bun run test`: integration tests. They compile Bend examples to native binaries and hit them over HTTP.
- `bun run check`: all of the above. It must pass before work lands.

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
