# 0014: Hot-path performance and the CI throughput budget

Date: 2026-10-24. Issue: BND-68. Status: accepted for M9.

BND-67 measured Bendo's full public pipeline at about 5,000 hello requests per second, against 187,000 for Hono on the same Boat sandbox. The BND-68 profile found that most of the time went to a few pure helpers that did needless work on every byte or character. This record lists the six changes made, what each one bought, how the laws carry over, and how CI now keeps the result.

## Measurements

Requests per second, median (min–max) of three samples:

| Commit | Hello | JSON | Params | Echo | Middleware |
|---|---:|---:|---:|---:|---:|
| Base: main `4eb320a` | 4,285 (4,148–4,685) | 3,345 (2,997–3,417) | 3,750 (3,483–4,040) | 303 (292–316) | 484 (471–485) |
| 1. ASCII encoder `b0e921e` | 8,013 (7,192–8,056) | 7,532 (6,591–7,776) | 5,641 (5,533–6,432) | 1,801 (1,553–1,972) | 776 (671–838) |
| 2. Token classifier `9c1a4c5` | 12,882 (12,215–14,783) | 11,748 (11,275–13,142) | 8,816 (7,241–9,625) | 2,153 (1,968–2,199) | 1,436 (1,364–1,524) |
| 3. Fused encoder, Content-Type `e1bc328` | 14,974 (13,203–15,733) | 13,496 (13,323–14,381) | 9,340 (8,783–9,980) | 2,296 (1,916–2,407) | 1,473 (1,220–1,551) |
| 4. Middleware policy once `4089d73` | 14,840 (12,640–15,132) | 13,529 (11,710–13,827) | 9,403 (8,152–9,672) | 2,310 (1,834–2,318) | 1,675 (1,478–1,691) |
| 5. Connection guard `d96ef62` | 16,959 (15,452–17,455) | 15,613 (15,162–15,741) | 9,847 (8,958–10,085) | 1,973 (1,393–2,347) | 1,560 (1,506–1,693) |
| 6. Head loop `59ac5e5` | 17,370 (16,918–18,911) | 15,625 (14,985–16,730) | 10,122 (9,678–10,889) | 2,280 (1,984–2,378) | 1,647 (1,627–1,844) |
| **Change, base to 6** | **4.1×** | **4.7×** | **2.7×** | **7.5×** | **3.4×** |

Server CPU time per response in microseconds, median:

| Commit | Hello | JSON | Params | Echo | Middleware |
|---|---:|---:|---:|---:|---:|
| Base: main `4eb320a` | 233 | 299 | 266 | 3,294 | 2,200 |
| 1. ASCII encoder `b0e921e` | 125 | 133 | 177 | 555 | 1,410 |
| 2. Token classifier `9c1a4c5` | 78 | 85 | 113 | 464 | 798 |
| 3. Fused encoder, Content-Type `e1bc328` | 67 | 74 | 107 | 435 | 787 |
| 4. Middleware policy once `4089d73` | 67 | 74 | 106 | 432 | 715 |
| 5. Connection guard `d96ef62` | 59 | 64 | 101 | 506 | 773 |
| 6. Head loop `59ac5e5` | 57 | 64 | 99 | 438 | 720 |

Median p50 latency in milliseconds at 64 connections:

| Commit | Hello | JSON | Params | Echo | Middleware |
|---|---:|---:|---:|---:|---:|
| Base: main `4eb320a` | 14.34 | 18.65 | 16.55 | 217.61 | 131.00 |
| 1. ASCII encoder `b0e921e` | 7.74 | 8.31 | 10.77 | 28.64 | 81.33 |
| 2. Token classifier `9c1a4c5` | 4.67 | 5.22 | 6.98 | 9.34 | 43.70 |
| 3. Fused encoder, Content-Type `e1bc328` | 4.13 | 4.60 | 6.67 | 3.74 | 42.93 |
| 4. Middleware policy once `4089d73` | 4.15 | 4.56 | 6.67 | 2.89 | 37.64 |
| 5. Connection guard `d96ef62` | 3.64 | 3.95 | 6.22 | 20.13 | 40.27 |
| 6. Head loop `59ac5e5` | 3.51 | 3.93 | 6.10 | 3.21 | 37.63 |

Each row adds one commit to the row above it, so a row's gain is the change from the previous row, and the base row is main at `4eb320a`. Every number is the median of three 10-second samples, with the range in parentheses. CPU is the server's process CPU time per response, read from `/proc` around the measured run. All seven builds were measured in one session on a Boat large sandbox (AMD Ryzen 9 9950X, 8 vCPUs): server on CPUs 0–3, oha 1.16.0 on CPUs 4–7, 64 keep-alive connections, two oha workers, a 3-second discarded warmup, the BND-67 request headers, and the native release build (`bend … -o x.c`, then `clang -std=c11 -O3`). The sample rounds ran the seven builds forward, then in reverse, then forward. Before each sample the harness checked status 200, the exact body and, for the middleware scenario, all thirteen expected headers. All 105 recorded samples had zero oha errors and only 200 responses. The first attempt at the second base echo sample had 11 timeouts among 3,009 requests, at about 300 requests per second with 64 connections queued, and stopped the run. The harness then counted errors instead of stopping, and the resumed run re-measured that sample with no errors.

Changes 1, 2 and 3 account for most of the gain. Steps 4, 5 and 6 are smaller than the spread between samples in several cells: step 4 moved middleware from 1,473 to 1,675 and left the other scenarios unchanged, as expected, and step 5's lower echo and middleware medians fall inside wide sample ranges for code that does strictly less work. The full-suite rerun at the final commit measured 21,883 hello requests per second with 15-second samples in a separate session, so compare rows within this table rather than across sessions.

`bench/steps.py` is the harness and reproduces the table:

```sh
BENDO_BENCH_BOAT=1 python3 bench/steps.py OUT base=SRC_A next=SRC_B ...
```

The raw samples, including every oha summary and response check, are in [`bench/results/2026-10-24-bnd68-steps.json`](../../bench/results/2026-10-24-bnd68-steps.json). The [full suite against Hono and Elysia](../../bench/results/2026-10-24-bnd68-full-suite.json) was rerun at the final commit, and its [chart](../../bench/results/2026-10-24-bnd68-full-suite.svg) replaces the BND-67 chart in the README. The BND-67 files stay in `bench/results/` for history.

## The changes

1. **ASCII in `Utf8.encode_char`.** The encoder split every character into a 21-bit word before choosing a length, even for ASCII. Below 128 it now returns `[c]`.
2. **`Bytes.tchar` by branching.** `Bool.or` evaluates both sides, so the old predicate built a one-character string and searched `"!#$%&'*+-.^_`|~"` for every character, letters and digits included. Letters and digits now return at once, and punctuation is a chain of comparisons in the old string's order.
3. **Fused `Response.utf8` and fixed Content-Type bytes.** `Response.utf8` built a scalar-replaced copy of the string, reversed it, and ran the general encoder. It now replaces and encodes each character in one pass, and ASCII skips both steps. `Context.text`, `html` and `json_result` also encoded their constant Content-Type string on every response; they now pass fixed bytes to `body_typed`, which keeps `body`'s validation.
4. **Middleware policy built once.** `B.secure_headers()` and `B.secure_headers_with(config)` now register `Builtin.SecurePrepared` with `Secure.policy(config)` computed at registration, instead of building the policy twice per request. CORS derived its grant, preflight test and policy twice per request; it now derives each once. Its policy still depends on the request's origin, so it cannot move to registration.
5. **Connection values parsed only for Connection fields.** `Connection.header_hit` used `&&`, so every header value was split, decoded and trimmed whatever its name.
6. **Head scan without a per-byte state.** The profile after changes 1–5 still showed 6.5% of hello's time in `Body.head_scan_policy` and `head_step`, which built and re-matched a `Head{parser, bytes}` value for each byte. `head_loop` carries the parser and the byte count as arguments. In a separate paired run it gave +8% (median 24,180 against 22,385 req/s, higher in each of three ABBA groups), and the table above confirms the direction.

The profile also listed `term_drop` and `String.starts_with_go` as hot. After these changes `String.starts_with_go` no longer appears in the hello profile above 0.4% self time; its callers were `String.contains` in `tchar`. `term_drop` is the runtime freeing graph nodes and falls only as the code allocates less, which every change above does. The report's other suspects (fixed Date text, request-ID normalization, constant route admission, removing intermediate response checks) gave no clear win, so they were not changed.

## How the laws carry over

Each changed pure function keeps its earlier definition under a `_spec` name, and a new law states that the two are equal for every input: `encode_char_spec`, `tchar_spec`, `utf8_spec`, `text_spec`, `html_spec`, `json_result_spec`, `header_hit_spec` and `head_feed_policy_spec`. The eleven laws are in `proof/hot-path-laws.bend` and are proven in `proof/hot-path.bend`:

| Law | Statement, for every input |
|---|---|
| `hot_utf8_encode_char` | `Utf8.encode_char(c) == Utf8.encode_char_spec(c)` for every U32, including non-scalars |
| `hot_bytes_tchar` | `Bytes.tchar(c) == Bytes.tchar_spec(c)` for every U32 |
| `hot_response_utf8` | `Response.utf8(s) == Response.utf8_spec(s)`, so U+FFFD replacement and byte order are unchanged |
| `hot_context_text`, `_html`, `_json_result` | each equals the earlier `Context.body` call for every context and value |
| `hot_cors_actual` | applying the retained policy to an actual response equals the earlier `Cors.actual` |
| `hot_cors_policy` | the policy CORS derives once equals `RequestPolicy.policy(config, req)` |
| `hot_secure_prepared` | `Secure.middleware(config)` equals `Secure.prepared(Secure.policy(config))` |
| `hot_connection_header_hit` | `Connection.header_hit == Connection.header_hit_spec` for every name, value and token |
| `hot_body_head_feed` | `Body.head_feed`'s scan equals the earlier one for every input, parser state and limit |

`hot_body_head_feed` states the default instance. The lemma behind it, `head_feed_equiv`, is generic over the policy template, so it covers the instances `Connection` uses too.

No law was deleted or weakened. The existing proofs that unfolded a changed definition now rewrite through these laws first, so their statements are unchanged: the UTF-8 codec and percent-encoding proofs through `encode_char_equiv`, the codec, SSE and error proofs through `utf8_spec_equiv`, and the independent cookie serialization spec through `tchar_equiv`. `bend PROOF.bend --verdict` prints `ALL PROOFS CHECK`.

## The CI budget

The `perf` job fails a commit whose hello-world throughput falls more than 25% below a pinned baseline commit. [`bench/README.md`](../../bench/README.md#performance-budget-in-ci) describes the job and how to move the baseline. In short, it builds the baseline and the candidate on the same runner, runs three alternating pairs of 5-second oha samples, and fails when the median per-pair ratio is below 0.75 in a first round and again over both rounds.

Before enabling it, the job ran 18 times on GitHub's standard 4-vCPU runners, which reported five CPU models (AMD EPYC 7763, 9V45 and 9V74, Intel Xeon 6973P-C and Xeon Platinum). Twelve runs came from two temporary calibration matrices on a scratch branch; one is the real `perf` job on this change.


| Candidate | Runs | Median paired ratio | Result |
|---|---:|---:|---|
| Unchanged: the baseline's own code | 13 | 0.983–1.012 | all pass |
| Main before BND-68, `4eb320a` | 1 | 0.303 | fail, after the confirming round |
| ASCII change only, `b0e921e` | 1 | 0.583 | fail, after the confirming round |
| Changes 1–2, `9c1a4c5` | 1 | 0.855 | pass |
| Changes 1–3, `e1bc328` | 1 | 0.871 | pass |
| Changes 1–4, `4089d73` | 1 | 0.883 | pass |

An unchanged candidate never moved more than 2% from the baseline, while the threshold sits 25% below it. Old main, three times slower, and the commit with only the ASCII change both failed, after the confirming round. Commits missing the later changes (12–15% slower on these runners) passed, as a sub-25% regression should. Absolute hello throughput ranged from 11,000 to 20,500 requests per second across runner models, which is why the gate compares two builds on one runner rather than against a fixed number of requests per second.

## Re-pinned after merging main

The baseline was first pinned at `59ac5e5`, the last hot-path change, on top of main at `4eb320a`. Merging main at `c8c5669` (BND-36 validation, BND-62, BND-79 and BND-58) into this branch lowered hello-world throughput. On GitHub, the `perf` job of the merged head measured a median ratio of 0.907 against `59ac5e5` (pairs 0.913, 0.897 and 0.907). On a Boat large sandbox, using the step-table method above with three samples each, the merged head against `38f86d4` (this branch just before the merge) measured:

| | Hello | Echo | Middleware |
|---|---:|---:|---:|
| Before the merge, `38f86d4` | 23,493 (22,826–24,315) | 3,127 (3,087–3,144) | 2,323 (2,297–2,345) |
| After the merge | 20,259 (19,652–20,503) | 3,065 (2,735–3,068) | 2,162 (2,092–2,259) |

All 18 samples had zero errors. The hello server runs no middleware, so the loss comes from main's request pipeline, not from this change. The gate is meant to catch regressions after BND-68 on the current main, so the baseline is now the merge commit `853687e`. That keeps the full 25% margin. Leaving the pin at `59ac5e5` would have started every later run at about 0.91.


## BND-96: recovering the BND-36 regression

Route validation (BND-36) cost every app on the request path, schemas or not. Bisecting main on Boat put the whole loss in the BND-36 merge (`d31b132` to `824dc43` added 62,600 instructions to each hello request; the other commits in that merge added none). For a table without schemas, a request still looked up its route's schemas twice, ran its pre-handler hooks through the validation step's wrapper, built the response check and its route label, and reserved the stream marker by lowering every response field name twice. The pipeline had also grown IO steps that the compiler could no longer inline.

### What changed

- Serving works out once, at startup, whether the table declares any route schema. A table that declares none runs `Handle.parsed_plain`: the pre-BND-36 lifecycle, with no per-route schema lookup, no validation step and no response check. Law `undeclared_table_checks_nothing` states that such a table gives every route an empty schema set, so nothing is skipped that could have mattered.
- The plain entrypoints (`B.serve` and friends, and `src/serve-schemas.bend`) already refuse tables with schemas, so they serve through `Serve.startup_plain` and `Handle.transport_plain`, and their binaries do not contain the validating pipeline. That matters for speed, not just size: Bend's code generator inlines a function only when it has one caller in the binary, and a second copy of the pipeline cost hello about 8,000 instructions and 25,000 cycles per request in a test build.
- Under `src/validated.bend`, a table with schemas still checks each route: a route without params, query, headers or body schemas runs its hooks without the validation step, even when it declares a response schema, and a route without a response schema skips the response check. Laws `response_without_schema_is_sent_run` and `response_without_schema_is_sent_skip` state that the check answers Send for such a route with either validator. Laws `request_free_route_is_admitted_run` and `request_free_route_is_admitted_skip` state that a skipped request step would have admitted the request with no values; without the decoder only a route with no schema at all skips it, so `B.handle` keeps refusing a response-only route. Law `no_values_entry_reads_unchanged` states that admitting with no values changes nothing a handler reads.
- `tests/pipelines.test.ts` serves one app without schemas through `Handle.parsed_plain` and, forced, through `Handle.parsed_checked`, and compares the raw responses and the hook and log traces across buffered responses, errors, rewrites, hook replacements that reapply retained policies, streams and upgrades. It guards the duplicated setup against drift.
- `Marker.named` tests whether a field name is the stream marker by lowering one character at a time and stopping at the first difference. The earlier test, `Marker.named_spec`, lowered the whole name into a new string first; finalization and transport run it three times on every response field. Law `hot_marker_named` states that the two agree for every name.

### Measurements

Per-request work on hello, from `perf stat` on the server over 40,000 requests with 16 connections, on a Boat large sandbox with near-zero CPU steal. Instruction counts repeat to within 0.1% across runs and hosts; cycles vary by a few percent.

| Commit | Instructions per request | Cycles per request |
|---|---:|---:|
| Before BND-36, `38f86d4` | 706,100 | 208,600–208,700 |
| Main, `07b27be` | 757,000 | 251,900–253,000 |
| BND-96, `08a5212` | 717,900 | 215,000–220,600 |

Requests per second, median (min–max) of seven samples, measured with `bench/steps.py` (server on CPUs 0–3, oha on 4–7, 64 connections, the BND-68 method) on a Boat large sandbox:

| Commit | Hello | JSON | Params | Echo | Middleware |
|---|---:|---:|---:|---:|---:|
| Before BND-36, `38f86d4` | 15,353 (14,341–19,073) | 13,306 (11,374–15,701) | 9,234 (7,177–10,357) | 1,558 (1,278–1,980) | 1,414 (1,012–1,690) |
| Main, `07b27be` | 13,172 (12,109–15,189) | 12,435 (9,576–13,070) | 8,109 (5,888–9,303) | 1,686 (1,143–2,057) | 1,428 (1,193–1,651) |
| BND-96, `08a5212` | 15,711 (13,833–17,033) | 13,423 (12,289–15,481) | 8,865 (7,692–9,833) | 1,701 (1,336–2,121) | 1,559 (1,391–1,682) |
| **BND-96 against before BND-36** | **1.023** | **1.009** | **0.960** | **1.091** | **1.103** |
| **BND-96 against main** | **1.193** | **1.079** | **1.093** | **1.009** | **1.092** |

All 105 samples had zero errors. Boat hosts were shared with other large sandboxes that afternoon, which shows in the ranges and in the lower absolute numbers than the tables above; compare rows within this table only. An earlier three-sample run of the same binaries, on a host whose steal rose during the run, measured hello at 0.827 of the pre-BND-36 figure and main at 0.744. Both runs are in [`bench/results/2026-10-24-bnd96-steps.json`](../../bench/results/2026-10-24-bnd96-steps.json). The instruction counts above are the steadier evidence: BND-96 removes 39,000 of the 51,000 instructions BND-36 added to hello, and the remaining 12,000 (1.7%) include the response-policy marker reservation that BND-36 needs for correctness.

On GitHub's `perf` job, `08a5212` measured a median ratio of 1.114 against the previous pin `853687e` (pairs 1.118, 1.114 and 1.112). When BND-36 merged, that pin itself measured 0.907 against the pre-BND-36 code, so in that job BND-96 sits about 1% above where hello was before BND-36. The baseline is now pinned to `08a5212`.
