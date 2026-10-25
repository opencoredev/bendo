# Bendo agent guide

Bendo is a Hono-style web framework written in Bend, plus a TypeScript toolkit. Read `docs/PLAN.md` before any work: it holds the design decisions, milestones and the definition of done. Work is tracked in Linear, team BND, project "Bendo v1". An orchestrating agent also reads `docs/RUNBOOK.md`.

## Toolchain

`CONTRIBUTING.md` has the full setup for a clean Ubuntu 24.04 machine. In short: Bun 1.4.4, Bend at `.bend-version` (2.0.38), clang, and Lean at `lean-toolchain` through elan. Put `~/.bun/bin`, `~/.bend/bin` and `~/.elan/bin` on PATH and set `BEND_NO_TELEMETRY=1`.

The bend-lang.com installer installs the newest release (2.0.39 now) and takes no version argument, so it does not give you the pin. Install the pinned GitHub release archive into `~/.bend` as CONTRIBUTING.md and CI do, or copy a known-good `~/.bend` (its `bin`, `bend2` and `guide` directories) from a machine that has it. `bun run check:bend` stops on any mismatch, including in CI. Never change the pin just to get past a mismatch.

Bend v2 is newer than most model training data. Read `~/.bend/guide/GUIDE.md` and `bend base <Name>` before writing Bend. Do not guess syntax from Bend v1 or HVM examples.

## Commands

- `bun run check`: `check:static`, then `check:docs`, then `test`. It must pass before work lands.
- `bun run check:docs`: installs the docs site's dependencies (`docs/bun.lock`), typechecks its config and builds it with VitePress. It fails on a dead link or a published page missing from `docs/.vitepress/sidebar.ts`. CI runs it as the `docs` job.
- `bun run check:static`: `check:bend`, `prove`, `lint`, `format:check`, `typecheck` and `typecheck:bench`. CI runs this as its own job.
- `bun run prove`: every proof on the Lean-backed kernel (`bend PROOF.bend --verdict`). It must print `ALL PROOFS CHECK`.
- `bun run lint` (oxlint, warnings are errors), `bun run format` and `bun run format:check` (oxfmt).
- `bun run typecheck`: TypeScript. `bun run typecheck:bench`: the benchmark code.
- `bun run test`: integration tests, under a 10-minute `timeout`. They compile Bend fixtures to native binaries and talk to them over HTTP.
- `bun run test:ci`: the same with a 20-minute budget. `BENDO_TEST_SHARD=1` to `6` runs one of CI's six shards; `bun run test:shards` prints and validates the assignment.
- `bun bench/run.ts`: the Hono and Elysia comparison, on a Boat sandbox. See `bench/README.md`.

## Test budgets and sharding

The full local `bun run check` was measured at 7.5 minutes warm on 16 GB and four CPUs. On smaller machines, or with a cold fixture cache, run `bun run check:static`, `bun run check:docs` and then each shard with `CI=true BENDO_TEST_SHARD=<n> bun run test:ci`, as `docs/test-runners.md` describes. New test files are assigned to a shard automatically (90 seconds of estimated cost until `scripts/test-timings.json` has a measurement).

One `bend` compile of a fixture has a 180-second ceiling, or 360 seconds with `CI=true` (`tests/harness.ts`), because GitHub runners compile about twice as slowly. A test whose body compiles gets `COMPILE_TEST_TIMEOUT_MS`. The runner allows 6 GiB of memory per test worker and at most four workers; `BENDO_TEST_WORKERS` lowers that. `tests/json.test.ts`, `tests/multipart.test.ts` and `tests/schema-compound.test.ts` run alone in their own process because of their memory peaks. Every import added to `src/main.bend` or the serving modules slows every fixture compile, so keep new features in opt-in modules.

The `perf` CI job fails a commit whose hello-world throughput is more than 25% below the baseline pinned in `bench/perf-baseline.json`. `bun run check` does not run it. Move the pin only with the change that justifies it (`bun bench/budget.ts pin`).

## Bend rules that bite

- Define a def above every def that calls it.
- `match` only on a parameter or a pattern variable, never on a computed value. Give the computation its own def.
- No `if`. Match on `True{}` and `False{}`.
- Recursion must shrink an argument. A loop bounded by the outside world counts down a `Nat` fuel argument or is marked `@unsafe`.
- No mutual recursion. Merge the functions into one def with a mode argument.
- Functions are not copyable. Pass handlers as templates (`~app`), which inline at compile time.
- Mark a value `+` to use it more than once (it must be `Data`).

## Laws

`LAWS.bend` and the `proof/*-laws.bend` modules it imports state what must hold. `PROOF.bend` proves it. You may add laws. Never delete or weaken a law without a written reason in the commit message and a comment on the Linear issue. Pure code goes in modules the laws can import. IO and `@unsafe` code stays in thin shells covered by integration tests.

Every law needs an entry in `docs/laws/`. `tests/laws-docs.test.ts` reads the law names through `scripts/laws-index.ts` and fails when a law has no entry or an entry names a law that no longer exists. `docs/laws/README.md` gives the entry format.

Every public API needs an entry in `docs/api/`: each def in `src/main.bend`, each name an example or guide calls through another `src/` module, and each export of the `bendo` and `vite-plugin-bendo` entry points. `tests/api-coverage.test.ts` fails on a missing or unknown entry and compiles or typechecks every example on those pages. `docs/SITE.md` gives the entry format.

## TypeScript

Follow `~/.agents/skills/typescript-best-practices/SKILL.md` when it exists on your machine: discriminated unions, no `as` casts, parse external data at the boundary, exhaustive switches.

## Testing

Test real behavior. Integration tests compile a Bend server and talk to it with `fetch` or raw sockets. Keep runs bounded: `bun test --timeout 30000`. Heavy benchmarks, fuzzing and full cold check runs go on Boat sandboxes, not the shared server.

## Docs

Relative links in Markdown files must resolve; `tests/docs-links.test.ts` checks every tracked `.md` file. The README's benchmark numbers come from `bench/results/` and decisions 0014 and 0017; update them together when a new full-suite run lands.
