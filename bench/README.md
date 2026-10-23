# Compare Bendo, Hono and Elysia

From the repo root, run:

```sh
bun bench/run.ts
```

You need Bun, Git, and the logged-in `boat` CLI with the `boat-sbx` lifecycle wrapper described in the Boat skill. The command creates a **default** Boat sandbox (4 vCPU, 8 GB advertised RAM), uploads a fixed snapshot of the current source, installs the tools, runs the comparison and saves `bench/results/<UTC timestamp>.json`. All servers and load generation run inside that sandbox. The local machine only orchestrates and downloads results.

Provisioning follows the Ubuntu setup in `AGENTS.md`: system build tools, Bun, and Bend. It installs the Bend release named by `.bend-version`, Bun 1.4.4, oha 1.16.0, and the exact Hono/Elysia versions and transitive lockfile in `servers/`. Lean is unnecessary for the benchmark: this command compiles servers; `bun run check` separately checks proofs.

## Method

Each framework answers `GET /` with status 200 and the UTF-8 body `Hello, world!` as plain text. The harness checks that response before applying load. It compiles the Bendo fixture against the repo's actual HTTP helpers and server loop, and runs Hono and Elysia on Bun. Only one server runs at a time, on the same loopback address and port.

For each scenario the order is **Bendo, Hono, Elysia**. Each server gets a 3-second oha warmup, discarded, followed immediately by a 10-second measurement with 32 concurrent connections. Both phases use HTTP/1.1, a 5-second request timeout, two oha worker threads, and `--disable-keepalive`. Bendo's current server closes each response, so the same connection policy applies to all three. oha waits for outstanding requests after the deadline rather than counting the final in-flight requests as failures. Actual wall time can exceed 10 seconds while those requests finish.

The server and load generator share the sandbox's CPU and network stack. This measures that combined setup, including connection establishment, rather than a server's maximum throughput. One fixed-order sample does not control for order effects or quantify variance. Keep the method and sandbox size identical when comparing runs; repeat runs to assess noise. This ticket does not optimize any framework.

The JSON records CPU model, logical core count, RAM, architecture, kernel, CPU quota when exposed, sandbox size and ID, tool versions, method, scenarios, and requests/second, p50/p99 **in milliseconds**, and error count for every framework/scenario. Error count sums oha transport errors and non-2xx responses. Percentiles come from oha's seconds-valued JSON and are converted to milliseconds at the boundary. Results record the source commit, dirty flag, and SHA-256 of the uploaded input files; the hash identifies the exact input when local changes are present. Existing result files are excluded from the snapshot.

## Add a scenario

Add an entry to `scenarios.ts` with `name`, `path`, `method`, optional `body`, `expectedBody`, and `bendoSource`. Add its native Bend fixture under `servers/` and its Hono/Elysia implementation in their respective registries. Each registry must reject missing implementations. The runner iterates scenarios and frameworks without needing scenario-specific load logic. JSON, params, echo and middleware scenarios belong to BND-67.

Dependencies stay in `servers/package.json` and `servers/bun.lock`. After changing them, install there and commit both files. Provisioning installs with `--frozen-lockfile` and checks all benchmark TypeScript with `bench/tsconfig.json`; root TypeScript configuration intentionally stays untouched.

## Cleanup and failures

The command uses a unique Boat label and deletes only sandboxes recorded under that label in a `finally` block. It checks that `boat-sbx ls --label <label>` is empty before exiting. SIGINT and SIGTERM cancel active upload/setup/measurement commands and then delete the sandbox. If interrupted during creation, it first lets creation return so the lifecycle wrapper can record the ID, then deletes it. SIGKILL or a machine loss cannot run cleanup; the 30-minute TTL stops compute but does not delete the disk. Use the printed label to recover:

```sh
boat-sbx ls --label <label>
boat-sbx gc --label <label>
```

To exercise the failure path without provisioning or load:

```sh
BENCH_FAIL_AFTER_CREATE=1 bun bench/run.ts
```

Expect exit code 1, an injected-failure message, and an empty scoped listing. A failed measurement writes no result file. A cleanup failure exits nonzero and includes the CLI error; resolve it before considering the run complete.
