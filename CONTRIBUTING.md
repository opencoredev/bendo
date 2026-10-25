# Contributing to Bendo

Bendo is built against [the plan](docs/PLAN.md), which holds the design
decisions every change follows. Read it before you start. Changing a design
decision needs a written record in [`docs/decisions/`](docs/decisions/).

## Set up the toolchain

You need Bun, Bend at the pinned version, clang, libsqlite3 for the SQLite
effect's tests, and Lean for the proofs. Bend is pinned in
[`.bend-version`](.bend-version) and Lean in
[`lean-toolchain`](lean-toolchain), at the version Bend's proof kernel needs.
CI uses Bun 1.4.4. On Ubuntu 24.04 x64, from the repository root:

```sh
sudo apt-get update
sudo apt-get install -y ca-certificates curl git unzip build-essential clang libsqlite3-0

curl -fsSL https://bun.sh/install | bash -s bun-v1.4.4
export PATH="$HOME/.bun/bin:$PATH"

version="$(cat .bend-version)"
curl -fsSL "https://github.com/bendlang/bend/releases/download/v${version}/bend-${version}-linux-x64.tar.gz" -o /tmp/bendo-bend.tar.gz
mkdir -p ~/.bend
tar -xzf /tmp/bendo-bend.tar.gz -C ~/.bend --strip-components=1 --warning=no-unknown-keyword
export PATH="$HOME/.bend/bin:$PATH"
export BEND_NO_TELEMETRY=1
bun run check:bend

curl -fsSL https://elan.lean-lang.org/elan-init.sh -o /tmp/bendo-elan-init.sh
sh /tmp/bendo-elan-init.sh -y --no-modify-path --default-toolchain none
export PATH="$HOME/.elan/bin:$PATH"
elan toolchain install "$(cat lean-toolchain)"

bun install --frozen-lockfile
timeout --foreground 10m bun run prove
```

`bun run prove` prints `ALL PROOFS CHECK`. Bend builds its proof kernel on the
first strict check, so the first run is the slowest. Elan picks the repository's
`lean-toolchain` by itself; you do not need a global Lean default. Add
`~/.bun/bin`, `~/.bend/bin` and `~/.elan/bin` to your shell's PATH for later
sessions.

Do not use the bend-lang.com installer here. It installs the newest Bend
release, currently 2.0.39, and takes no version argument. `bun run check:bend`
compares `bend version` with `.bend-version` and stops on a mismatch, in CI
too. The commands above install the pinned release the same way CI does: the
GitHub release archive, which holds the `bin`, `bend2` and `guide` directories
that go under `~/.bend`. Do not change the pin to get past a mismatch; moving
to a new Bend is its own change, with the proofs and the full suite rerun.

Bend v2 is newer than most tutorials and model training data. Read
`~/.bend/guide/GUIDE.md` and `bend base <Name>` before writing Bend, and do not
copy syntax from Bend v1 or HVM examples.

## Commands

| Command | What it runs |
| --- | --- |
| `bun run check` | `check:static`, then `check:docs`, then `test`. It must pass before a change lands. |
| `bun run check:docs` | Installs the docs site's own dependencies, typechecks its config and builds it. The build fails on a dead link or a page missing from the sidebar. |
| `bun run check:static` | The Bend version check, proofs, lint, format check and both typechecks. |
| `bun run check:bend` | Compares the installed Bend with `.bend-version`. |
| `bun run prove` | `bend PROOF.bend --verdict`: every proof, on the Lean-backed kernel. |
| `bun run lint` | oxlint, with warnings as errors. |
| `bun run format` / `format:check` | oxfmt, writing or checking. |
| `bun run typecheck` | TypeScript for the packages, tests and scripts. The todo example typechecks inside its test. |
| `bun run typecheck:bench` | TypeScript for `bench/`, after installing its pinned servers. |
| `bun run test` | The integration tests, within 10 minutes. |
| `bun run test:ci` | The same tests with CI's 20-minute budget; set `BENDO_TEST_SHARD` to run one shard. |
| `bun run test:shards` | Prints and validates the assignment of test files to the six shards. |

The full `bun run check` took 7.5 minutes warm on a 16 GB, four-CPU machine.
On a smaller machine, or with a cold fixture cache, run the static checks, the
docs build and then one shard at a time:

```sh
bun run check:static
bun run check:docs
for shard in 1 2 3 4 5 6; do CI=true BENDO_TEST_SHARD=$shard bun run test:ci; done
```

[Test runner budgets](docs/test-runners.md) explains the shards, the fixture
cache and how many test workers fit in memory.

## Laws and proofs

[`LAWS.bend`](LAWS.bend) and the `proof/*-laws.bend` modules it imports state
what Bendo's pure code must do. [`PROOF.bend`](PROOF.bend) proves them.

- You may add laws. Never delete or weaken one without a written reason in the
  commit message and on the Linear issue. A proof that will not go through is
  not a reason.
- Every law needs an entry in [`docs/laws/`](docs/laws/README.md).
  `tests/laws-docs.test.ts` fails when a law has no entry or an entry names a
  law that no longer exists.
- Put pure code in modules the laws can import. IO and `@unsafe` code stays in
  thin shells, and integration tests cover those instead of proofs.

## Tests

Test real behavior. Integration tests compile a Bend server, start it, and talk
to it with `fetch` or raw sockets; avoid mocks. Keep every run bounded:
`bun test --timeout 30000` for a single file, and the `timeout` wrappers in
`package.json` for the suite. Run benchmarks and fuzzing on a separate machine
or sandbox, not on a shared one. Changing hello-world throughput by more than
25% fails CI's `perf` job; [bench/README.md](bench/README.md#performance-budget-in-ci)
says how to move the baseline after an intentional change.

TypeScript code uses discriminated unions, parses external data at the
boundary, avoids `as` casts and switches exhaustively.

Every public function, type and export needs an entry in the
[API reference](docs/api/index.md), with an example.
`tests/api-coverage.test.ts` fails when one is missing and compiles or
typechecks every example. [`docs/SITE.md`](docs/SITE.md) gives the entry format.

## How work is tracked

Work is tracked in Linear, team BND, project "Bendo v1". Each change belongs to
an issue:

- Branch from `main` with the issue's branch name, which contains its key (for
  example `leoplayz317/bnd-73-readme-contributing`).
- Prefix commit subjects with the key: `BND-73: Write the README`.
- Before it lands, run `bun run check` and the issue's "How to verify" steps,
  and record PASS, FAIL or NOT CHECKED for each acceptance criterion on the
  issue.
- Changes land on `main` as a merge commit that names the issue.

[`docs/RUNBOOK.md`](docs/RUNBOOK.md) describes how the agents that build Bendo
pick up, review and land issues.
