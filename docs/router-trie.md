# Trie router

The trie is Bendo's default router. It filters routes by their leading raw
static segments, then uses the [pattern matcher](router-patterns.md) to
validate the remaining candidates. BND-17 proved it returns exactly what the
[spec router](router-spec.md) returns, for every table and path, so the spec
router stays as the reference and as a configuration choice.

`src/router/trie.bend` exports `build_trie(Tag, table)`, `trie_route(Tag, trie,
path)`, `candidates(Tag, trie, path)` and `matches(Tag, trie, path)`. Both the
table and trie are copyable `Data`. `trie_route` returns the existing
`Maybe<&2, Spec.Match<Tag>>`, including the original registration index,
application-owned tag, and ordered decoded params. `matches` returns every
matching registration in index order. `src/router/router.bend` provides
`RouterKind` (`Spec` or `Trie`), `default_kind()` (`Trie`), `prepare(Tag,
table)`, and `route(Tag, kind, prepared, path)`. Prepare once after successful
`Spec.build_table`, then reuse that prepared value for requests. It retains the
table and its derived trie together; rebuilding after registration changes
keeps them consistent. Method-aware resolution goes through the same trie; see
[method routing](router-methods.md#router-selection).

## Shape

A route's key is its leading run of `Static` segments: `/users/:id` has key
`["users"]`, `/files/*rest` has `["files"]`, and `/:id?` has `[]`. The query is
the list of raw path segments that `Pattern.match_path` itself compares, so
`/users/42` queries `["users", "42"]`. A path that does not start with `/`
queries `[]`.

The trie has three constructors. `Fork` branches on one character of a
segment, `Node` marks a complete segment, and `Tip` is empty. Each node stores
every route whose key is a prefix of the segments read to reach it, in
registration order. Lookup walks the query and returns the list of the deepest
node it reaches. Because each list is already complete and ordered, lookup
never merges or sorts. `first` then validates candidates in order with
`match_path` and stops at the first hit; `matches` keeps every hit.

Building inserts routes from the last registration to the first. An insert
prepends its route to the node at its key and to every node below it, so lists
stay ascending. A route keyed `["files"]` therefore also appears under
`/files/new`. Routes sharing a key share one list, so a table of 500
`/shared/:value` routes is still scanned linearly. Deeply nested keys copy
ancestor entries into each descendant list; construction is proportional to
that total.

Every operation recurses structurally on a string, key, or subtree. No
function fields, maps, unsafe code, or mutable arrays enter this core. Static
text stays raw, including percent signs and Unicode. Constraints, decoding,
optional captures, wildcards and the root `/:id?` case all stay inside
`match_path`, which the trie never reimplements.

## Equivalence proof

`LAWS.bend` states four BND-17 laws, checked by `bun run prove`:

- `trie_route_spec`: `Trie.trie_route(T, Trie.build_trie(T, table), path) ==
  Spec.route(T, table, path)` for every table, including hand-built patterns,
  and every path.
- `trie_matches_spec`: `Trie.matches(T, Trie.build_trie(T, table), path) ==
  SpecProof.matching(T, table, path)`. `matching` filters the whole table by
  `match_path`, ascending by index, and never consults a router.
- `router_kind_spec`: `Router.route` with either kind, prepared from a table,
  equals `Spec.route`.
- `methods_router_resolve`: method resolution through either kind equals
  `Methods.resolve` for every valid table, path, method and option combination.

The proof lives in `src/router/trie-proofs.bend` and
`src/router/methods-trie-proofs.bend`. It has three steps:

1. Lookup after insertion (`insert_find`): looking up a query in
   `insert(trie, key, entry)` returns the old result with `entry` prepended
   exactly when the key is a prefix of the query. By induction on the build,
   `candidates(build_trie(table), path)` equals the indexed table filtered by
   "key is a prefix of `query(path)`" (`candidates_filtered`).
2. Every match passes the filter (`pattern_prefix`): if
   `match_path(pattern, path)` succeeds, each leading static segment equals
   the corresponding query segment. So filtering only removes routes that
   cannot match, and `first`, `matches` and the method helpers return the same
   result on the filtered list as on the whole indexed table. For methods,
   `direct_hits` shows that the short-circuiting `first_direct` equals taking
   the first allowed entry of the full matching list.
3. The whole indexed table reproduces the spec: `first` over it equals
   `Spec.route` (with an index shift), and `matches` over it equals
   `SpecProof.matching`.

Breaking `prepend` so it skips a node's own list makes `bend PROOF.bend
--verdict` fail; restoring it passes.

## Differential checks

```sh
bun test tests/router-trie.test.ts
```

The TypeScript generator uses seed `0xb0162026`. It creates 10,000 table/path
pairs with 1–60 registrations, duplicates and overlaps, static routes,
captures, consecutive trailing optionals, bare and prefix wildcards, interior
wildcards, literal static colons, `{.+}` spans, and all other supported
constraint families.
Most paths fill a generated pattern; others mutate fills or use unrelated
paths, including malformed escapes and Unicode. A native Bend driver receives
250 pairs per invocation and prints the spec match, trie match, and both
configuration paths. The comparison includes indexes, distinct numeric tags,
ordered parameter names, and decoded values. A disagreement reports the seed,
pair index, original case, and a bounded deletion-reduced table/path case.
Literal fixtures independently cover registration priority, ancestor keys,
empty segments, root optionals, decoding, and empty tables.

The 10,000 pairs are one seeded sequence checked as four test cases of 2,500,
each with its own 60-second deadline, so a slow machine cannot fail the whole
run on one timer. On a Boat `large` sandbox each slice took about 4 seconds
with `disagreements=0`, excluding compilation. The
laws above are the guarantee; the differential run guards the native build
and test transport around them.

## Lookup benchmark

`bench/router/lookup.bend` runs bounded in-process batches in a native executable
with `+RTS --threads 1`. `bench/router/run.py` compiles it, calibrates each
workload, verifies every checksum, rotates engine order across three repeats,
and reports medians. Paths and the prepared table/trie are forced before the
lookup timer. Preparation is reported separately, including pattern compilation
and trie construction. Lookup timings include list traversal, a `Router.route`
config dispatch, checksum accumulation, and one print. `IO.now` has millisecond
resolution; no baseline is subtracted. Each subprocess is bounded to 30 seconds,
with at most 1,000,000 lookups per sample. A sample targets 200 ms but always
finishes at least one complete route cycle.

Static routes are `/r001` through `/rNNN`. Mixed visits all registrations in
descending order; first and last repeat the corresponding route; miss uses
`/r999`. Shared-dynamic tables register `/shared/:value{int}` at every index
except the last, which is `/shared/:value`. Dynamic-first uses `/shared/42`;
dynamic-last uses `/shared/word`. Expected checksums are calculated independently
from registration tags (1 through N): mixed is `cycles*N*(N+1)/2`, first is
`iterations`, last is `iterations*N`, and miss is zero, all modulo 2^32.

Measured on 2026-10-23 in Boat sandbox `bx_6fr7swqh` (`default`, 4 vCPU,
8 GB RAM), AMD Ryzen 9 9950X under KVM, x86-64 Linux, Bend 2.0.38, and Ubuntu
clang 18.1.3, with the BND-17 segment trie. The executable was 587,968 bytes
and compiled in 4.43 seconds. All 108 measured samples
passed their independent checksum checks. The full benchmark took
49.6 seconds, including calibration and compilation. Preparation
was 0–1 ms at the measured clock resolution. The sandbox was deleted.

| Routes | Workload | Spec ns/lookup | Trie ns/lookup | Spec / Trie |
| --- | --- | ---: | ---: | ---: |
| 5 | mixed | 350 | 400 | 0.88x |
| 5 | last | 550 | 300 | 1.83x |
| 5 | miss | 600 | 200 | 3.00x |
| 5 | first | 150 | 450 | 0.33x |
| 5 | dynamic-first | 9,250 | 9,450 | 0.98x |
| 5 | dynamic-last | 87,838 | 88,288 | 0.99x |
| 50 | mixed | 2,650 | 600 | 4.42x |
| 50 | last | 5,150 | 300 | 17.17x |
| 50 | miss | 5,700 | 150 | 38.00x |
| 50 | first | 150 | 700 | 0.21x |
| 50 | dynamic-first | 9,050 | 9,300 | 0.97x |
| 50 | dynamic-last | 880,000 | 870,000 | 1.01x |
| 500 | mixed | 29,385 | 730 | 40.25x |
| 500 | last | 57,000 | 300 | 190.00x |
| 500 | miss | 55,667 | 360 | 154.63x |
| 500 | first | 130 | 1,090 | 0.12x |
| 500 | dynamic-first | 9,040 | 9,600 | 0.94x |
| 500 | dynamic-last | 8,924,000 | 8,906,000 | 1.00x |

The 500-route mixed lookup is 40.25x faster, passing the 5x target. Raw samples, preparation times, iteration counts, environment details,
and checksums are in [`bench/router/results.json`](../bench/router/results.json).

Reproduce official measurements from the repo root with Boat CLI access:

```sh
sh bench/router/boat.sh
```

The script creates a `default` sandbox, installs the pinned Bend release,
copies the router, HTTP sources and benchmarks, runs both bounded harnesses,
retrieves results, and deletes its sandbox even on failure. It replaces both
local results files.
For a short development run, use
`timeout --foreground 90s python3 bench/router/run.py --quick --output /tmp/router-results.json`
(or `bench/router/methods.py` with `/tmp/methods-results.json`).

The trie accelerates selective static prefixes. Routes sharing a static key
remain in one ordered list, so lookup can still be linear. First-hit spec
lookups can beat the trie because they avoid prefix traversal. The 500-route target concerns the documented static mixed workload;
it does not promise a fivefold gain for every route distribution or request.

## Method resolution benchmark

`bench/router/methods.bend` times `Methods.resolve_with` itself, which the
application router calls for every request. `bench/router/methods.py` uses the
same calibration, three rotated repeats, 30-second subprocess bound and
medians as the lookup benchmark, and writes
[`bench/router/methods-results.json`](../bench/router/methods-results.json).
Every registration is a GET route on `/shared/:value{int}` except the last,
which is `/shared/:value`, so every route shares one trie list. The workloads
send one request repeatedly:

- first: `GET /shared/42` hits registration 1.
- last: `GET /shared/word` hits only the last registration.
- miss: `GET /shared/1/2` matches nothing, giving 404.
- 405: `POST /shared/42` matches every route with the wrong method, so the
  resolver must collect `Allow: GET, HEAD`.
- head: `HEAD /shared/42` has no HEAD route and falls back to GET.

Checksums are computed independently: a hit adds its tag (plus 1,000,000 when
HEAD came from GET), a 405 adds 100,000 plus the length of `Allow`, a 404 adds
nothing. The harness fails if any Trie median exceeds twice the Spec median
plus 2 µs.

Before this fix, the Trie path matched every candidate before choosing a
direct hit. Measured in Boat sandbox `bx_khq4rbsv` (`default`, 4 vCPU, AMD
Ryzen 9 9950X, Bend 2.0.38, clang 18.1.3) on 2026-10-23, with 90 checked
samples for each version:

| Routes | Workload | Spec ns/request | Trie before | Trie after | Spec / Trie after |
| --- | --- | ---: | ---: | ---: | ---: |
| 5 | first | 9,500 | 49,000 | 10,000 | 0.95x |
| 5 | last | 91,500 | 90,000 | 92,500 | 0.99x |
| 5 | miss | 74,500 | 25,500 | 52,000 | 1.43x |
| 5 | 405 | 141,000 | 50,000 | 96,000 | 1.47x |
| 5 | head | 57,000 | 47,500 | 58,000 | 0.98x |
| 50 | first | 9,500 | 485,000 | 10,000 | 0.95x |
| 50 | last | 905,405 | 945,946 | 909,910 | 1.00x |
| 50 | miss | 744,000 | 252,252 | 497,500 | 1.50x |
| 50 | 405 | 1,415,493 | 489,489 | 990,000 | 1.43x |
| 50 | head | 492,500 | 501,502 | 500,000 | 0.98x |
| 500 | first | 10,000 | 4,750,000 | 10,500 | 0.95x |
| 500 | last | 9,380,952 | 9,000,000 | 9,095,238 | 1.03x |
| 500 | miss | 7,680,000 | 2,506,024 | 5,179,487 | 1.48x |
| 500 | 405 | 14,846,154 | 4,785,714 | 9,526,316 | 1.56x |
| 500 | head | 4,815,789 | 4,790,698 | 4,769,231 | 1.01x |

Spec numbers are from the run after the fix; Spec code did not change, and the
earlier run agreed within 6%. A 500-route first hit was 475 times slower than
Spec and is now within 5%. Misses and 405s now pay one failed direct walk
plus one collecting walk, so they cost about twice as much as before. They
still beat Spec, which walks the table three times (`find`, `path_exists`,
`matching_methods`). Every pattern here shares one static key, so the trie
cannot prune. Selective static prefixes prune as in the lookup benchmark.
