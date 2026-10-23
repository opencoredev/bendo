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
   result on the filtered list as on the whole indexed table.
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
captures, optional captures, wildcards, and all supported constraint families.
Most paths fill a generated pattern; others mutate fills or use unrelated
paths, including malformed escapes and Unicode. A native Bend driver receives
250 pairs per invocation and prints the spec match, trie match, and both
configuration paths. The comparison includes indexes, distinct numeric tags,
ordered parameter names, and decoded values. A disagreement reports the seed,
pair index, original case, and a bounded deletion-reduced table/path case.
Literal fixtures independently cover registration priority, ancestor keys,
empty segments, root optionals, decoding, and empty tables.

With the segment trie, the generated run produced `pairs=10000
disagreements=0` in 31.8 seconds on a loaded ms-a2, excluding compilation. The
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
copies the router and benchmark, runs the bounded harness, retrieves results,
and deletes its sandbox even on failure. It replaces the local results file.
For a short development run, use
`timeout --foreground 90s python3 bench/router/run.py --quick --output /tmp/router-results.json`.

The trie accelerates selective static prefixes. Routes sharing a static key
remain in one ordered list, so lookup can still be linear. First-hit spec
lookups can beat the trie because they avoid prefix traversal. The 500-route target concerns the documented static mixed workload;
it does not promise a fivefold gain for every route distribution or request.
