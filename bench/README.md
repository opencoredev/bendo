# Compare Bendo, Hono and Elysia

Run the suite from the repo root:

```sh
bun bench/run.ts
```

You need Bun, Git, a Linux x64 Bend 2.0.38 installation in `~/.bend`, and the logged-in `boat` CLI with the `boat-sbx` lifecycle wrapper. The runner creates a **large** Boat sandbox (8 vCPU, 16 GB advertised RAM), uploads a fixed source snapshot, copies `~/.bend/{bin,bend2,guide}`, installs the other tools, measures the servers, downloads the results and generates an SVG beside the JSON. All load generation runs on Boat. `remote.ts` requires an explicit Boat environment flag and eight CPUs; the ordinary test suite never invokes it.

Bun **1.4.4**, oha **1.16.0**, Hono **4.13.13**, Elysia **1.4.30** and Bend **2.0.38** are pinned. Hono/Elysia transitive dependencies come from `servers/bun.lock`, installed with `--frozen-lockfile`. The JSON records compiler and runtime versions, a toolchain archive hash, native binary hashes, and source provenance. Lean is needed for `bun run check`, not for measurements.

## Method

The five scenarios are hello (`GET /`, text), JSON (`GET /json`, a small object), params (`GET /user/42`, matched by `/user/:id`), body echo (`POST /echo`, about 1 KiB of JSON parsed and serialized), and five middleware (`GET /middleware`). Each sample checks status 200, exact body and required response headers before starting oha. Captured response checks and complete oha JSON are included in the results.

Each server gets a **3-second warmup**, discarded, followed by **15 seconds with 64 connections**. There are **three repetitions** of every scenario/framework/variant. Servers restart and warm up for each repetition. The starting variant rotates between repetitions to reduce order effects. oha uses HTTP/1.1, keep-alive, two worker threads and a five-second request timeout; `-w` lets outstanding requests finish after the deadline. Actual wall time can therefore exceed 15 seconds. Every request includes `Content-Type: application/json` and `Origin: https://bench.example`.

One server runs at a time on loopback port 8787. `taskset` restricts the server to CPUs **0–3** and oha to CPUs **4–7** in the same large VM. They share memory, cache and the kernel network stack. This is a reproducible comparison of this setup, not a claim about maximum production throughput or a two-machine network test. Full checks run separately from load generation. The runner uses a transient `systemd-run --uid=user` service to keep native compilation outside Boat's smaller interactive user-slice memory limit; `taskset` still controls each measured process.

Bendo uses the real application/router/context/server implementation. Its native release build runs the two compiler stages separately to avoid overlapping their memory peaks:

```sh
bend bench/servers/hello.bend -o /tmp/bendo-bench.c
clang -std=c11 -O3 /tmp/bendo-bench.c -o /tmp/bendo-bench -lpthread -lm
```

The default Bendo runtime selects the CPUs allowed by affinity, so it has four runtime workers here. A separate **threads-1** variant runs `+RTS --threads 1`. These are runtime worker counts, not four independent accept loops; multi-core serving work belongs to BND-69. Hono and Elysia each run one Bun process with no `reusePort` worker pool. Bendo keeps its default trie router, 1 MiB body limit, 5-second idle timeout and **100 requests per connection** cap. Bun servers keep their own defaults; the suite does not force their keep-alive lifetime to match Bendo. oha honors connection-close responses and reconnects when required.

For requests/second, p50 and p99, `summary` contains the median, minimum and maximum across repetitions. Latencies are in **milliseconds**, converted from oha's seconds at the boundary. The median p99 is the median of three per-run p99s, not a percentile pooled across all requests. `samples` preserves each repetition, and `rawRuns` preserves oha's complete measurements. Error counts sum transport failures and non-2xx responses; errors remain visible rather than silently discarding a slow or failed run. Chart rows with any errors are labelled INVALID and omit their throughput bar.

## Middleware comparison

Each framework uses five middleware or lifecycle stages: timing without log output, CORS, secure headers, request ID and one custom response header. See the fixtures in `servers/` for exact ordering and configuration. The response checks cover the shared headers; the captured full headers expose framework-specific defaults.

Bendo and Hono use their built-in CORS, secure-header and request-ID middleware, with custom timing and custom-header stages. Elysia uses one plugin composed from lifecycle hooks: `derive` plus `onAfterHandle` for timing, `onRequest` for CORS and request ID, and `onAfterHandle` for secure headers and the custom header. It does not use extra npm plugins. All three write the same eleven secure headers and `x-bench: middleware`; CORS answers the measured GET with `Access-Control-Allow-Origin: *`. Preflight handling is outside this measurement; Elysia's small hook is not a complete CORS plugin.

Timing reads Bend's monotonic `IO.now` twice, or Bun's `performance.now` twice, without log output or a timing response header. Bendo creates 16 random bytes and hex-encodes them for a new request ID; Hono and Elysia use `crypto.randomUUID()`. No incoming request ID is sent, so every measured middleware request generates one. The accepted incoming-ID rules differ, but that path is not measured. Bendo and Hono wrap downstream execution with onion middleware; Elysia uses its native lifecycle. Header ordering and `Date` may differ. For JSON, Bendo sends `application/json; charset=utf-8`, Hono sends `application/json`, and Elysia sends `application/json;charset=utf-8`; text responses also differ in charset spacing. Readiness compares the MIME type and shared header values. Elysia's lifecycle custom header is only applied to matching routes; Bendo and Hono also wrap 404s, which this suite does not request.

JSON and echo serialize JSON values in all three frameworks. Elysia parses the body automatically, Hono awaits `context.req.json()`, and Bendo parses `B.raw_body(c)` through its JSON parser. The 1024-byte document contains twelve item objects with strings, integers and booleans, plus an ASCII note. None applies a schema validator in this suite. The params route uses the real parameter router and context accessor in each framework.

## Results and chart

The [2026-10-24 results](results/2026-10-24-full-suite.json) and [generated chart](results/2026-10-24-full-suite.svg) contain all five scenarios, all three frameworks and the additional Bendo threads-1 variant: **60 measurements, zero errors**. The large Boat VM reported an AMD Ryzen 9 9950X 16-Core Processor, **8 vCPUs**, **16,764,223,488 bytes of RAM** (15.61 GiB), x64 Linux and kernel **7.0.0-38-generic**. The C compiler was Ubuntu clang 18.1.3. CPU quota information was unavailable.

Bendo's default median throughput was 5,083 req/s for hello, 4,102 for JSON, 4,587 for params, 330 for echo and 522 for middleware. Hono ranged from 100,281 to 234,624 req/s and Elysia from 129,924 to 266,165 req/s across these scenarios. These results measure the full public application pipeline, including routing and context, rather than the historical fixture's direct HTTP helper. The threads-1 variant did not close the gap. Run-to-run variation was substantial in some cases: Hono middleware ranged from 46,361 to 111,832 req/s. Three repetitions on a virtual machine support a baseline comparison, not a precise capacity estimate or a claim that overlapping ranges establish a ranking. This is the baseline for BND-68/BND-69; the suite makes no hot-path or serving changes.

A separate single-request probe after the benchmark confirmed BND-90: with `Connection: close`, the complete middleware response body arrived at **8.63 ms**, but socket EOF arrived at **1010.14 ms**. Its request and complete response are in `diagnostics.connectionClose`. This diagnostic is outside the oha samples. oha used keep-alive for every measurement; the observed closing delay should not be read as a one-second latency on every benchmark request. This suite does not isolate whether the delay affects throughput when Bendo reaches its 100-request connection cap.

The JSON records CPU model, logical CPU count, RAM, architecture, kernel, CPU quota when exposed, sandbox size and ID. Source provenance includes the commit, dirty flag and SHA-256 of sorted uploaded input files; existing result files are excluded. A dirty run is identified by its input hash rather than just its base commit.

Regenerate a chart from a schema-v2 result file:

```sh
bun bench/chart.ts bench/results/<run>.json
```

The SVG shows median throughput with min/max whiskers, and median p50/p99 latency. Schema-v1 hello-only results are historical and use a different connection policy, CPU allocation and repetition count; do not compare them directly with this suite.

## Cleanup and failures

The runner uses a unique Boat label and deletes sandboxes recorded under that label in a `finally` block. It checks that `boat-sbx ls --label <label>` is empty before exiting. SIGINT and SIGTERM cancel active commands and then delete the sandbox. SIGKILL or machine loss cannot run cleanup; the two-hour TTL stops compute but does not delete the disk. Recover with the printed label:

```sh
boat-sbx ls --label <label>
boat-sbx gc --label <label>
```

To exercise cleanup without provisioning or load:

```sh
BENCH_FAIL_AFTER_CREATE=1 bun bench/run.ts
```

Expect exit code 1, an injected-failure message and an empty scoped listing. A failed measurement writes no final result. A cleanup failure exits nonzero and includes the CLI error.
