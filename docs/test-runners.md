# Test runner budgets

`bun run check` runs the static checks and the local 10-minute `test` budget.
CI runs static checks separately and gives each of four test shards the existing
20-minute `test:ci` budget inside a 25-minute job. A failed shard fails the
workflow; the matrix does not cancel the other shards when one fails.

Run `bun run test:shards` to print and validate the assignment. Set
`BENDO_TEST_SHARD=1` through `4` when running `bun run test:ci` to reproduce one
shard. Without that variable, both test commands run the complete suite.

The planner discovers `.test`, `_test`, `.spec` and `_spec` JavaScript and
TypeScript files under `tests`, `bench`, `packages/bendo` and `packages/vite-plugin-bendo`. It assigns the
largest estimated costs first to the lightest shard, with stable filename and
shard-ID tie breaks. Costs come from the committed `scripts/test-timings.json`;
new files default to 90 seconds. Restored `.cache/test-timings.json` only controls
Bun's scheduling inside a shard. It cannot change shard ownership. The guard
checks that every discovered file appears exactly once, with no unknown files.

Each shard prewarms only its assigned heavy fixtures, sequentially. Other
fixtures compile lazily through the dependency-graph cache. Native fixtures first
emit C with Bend, then compile it with clang using the pinned Bend flags
(`-std=c11 -O3 -lpthread -lm`). This releases Bend's typechecker heap before clang
starts. Both stages share the original 180-second compile budget; the cache
identity distinguishes this pipeline from earlier native entries. JSON, multipart and
schema-compound tests each run in a fresh serial process when assigned to that
shard. The remaining pool recalculates concurrency from available host/cgroup
memory, allowing 6 GiB per worker plus a 128 MiB reserve, capped at four workers
and the available CPU count. The larger allowance covers lazy compiles after
request-core changes; two such compiles exhausted an 8 GiB Boat sandbox with the
old 2 GiB allowance. `BENDO_TEST_WORKERS` can lower that cap.

Fixture cache keys include the native toolchain and shard ID. Restore prefixes
try the same shard first, then any shard; GitHub also searches the default
branch. Separate save steps preserve completed fixtures after test failures.

The multipart native fixture has reached 6.36 GiB RSS on Boat. Splitting that
fixture into smaller, assertion-preserving consumers remains the next reduction
in peak compiler memory. Sharding reduces cold-run wall time; it does not reduce
the memory needed by an individual compiler. The worker allowance is a scheduling
estimate, and one worker cannot make an undersized machine safe.
