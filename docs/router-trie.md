# Trie router

The experimental trie filters routes by their leading raw static text, then
uses the [pattern matcher](router-patterns.md) to validate candidates. The
[spec router](router-spec.md) remains the default until BND-17 proves the two
engines equivalent. BND-12 will connect this choice to `B.config`.

`src/router/trie.bend` exports `build_trie(Tag, table)` and
`trie_route(Tag, trie, path)`. Both the table and trie are copyable `Data`;
lookup returns the existing `Maybe<&2, Spec.Match<Tag>>`, including the original
registration index, application-owned tag, and ordered decoded params.
`src/router/router.bend` provides `RouterKind` (`Spec` or `Trie`),
`default_kind()` (`Spec`), `prepare(Tag, table)`, and
`route(Tag, kind, prepared, path)`. Prepare once after successful
`Spec.build_table`, then reuse that prepared value for requests. It retains the
table and its derived trie together; rebuilding after registration changes
keeps them consistent.

## Shape and equivalence argument for BND-17

The trie has three constructors: `Empty`, `Fork` (one character with equal and
other subtrees), and `Bucket` (indexed candidate routes and a child). Every
operation recurses structurally on a string, table, candidate list, or subtree.
No function fields, maps, unsafe code, or mutable arrays enter this core.
Character edges share prefixes within static segments as well as across them.
The trie stops indexing at the first dynamic segment. Thus `/files/*rest`
enters a bucket at `/files`, while `/files/new` enters a deeper one. Lookup
checks every visited bucket, including at end of input. A deeper mismatch
cannot discard an ancestor hit. Broad prefixes can collect extra candidates;
the full matcher rejects them.

The intended equivalence is
`trie_route(Tag, build_trie(Tag, table), path) == Spec.route(Tag, table, path)`
for every table and path, including tables containing manually constructed
patterns. The proof should establish: (1) any successful `match_path` has the
raw prefix extracted by `prefix`; (2) insertion preserves existing buckets and
adds exactly its indexed route at that prefix; (3) `build_go` assigns precisely
the spec's consecutive indexes and leaves each bucket in ascending order;
(4) lookup visits the bucket of every matching route; (5) the first successful
candidate in a sorted bucket is its least matching index; and (6) combining
bucket results with `minimum` selects the globally least matching index.
Validation through the same `match_path` gives soundness and identical params
and tags. Completeness and minimum-index selection then give the spec result.
The invariant applies to tries constructed by `build_trie`, rather than to
arbitrary independently supplied tries or mismatched prepared fields.

Optional params and wildcards can omit their preceding slash, so prefix
extraction stops before that slash. It preserves empty static segments:
`//:id?` indexes at `/`, and `/a//:id?` at `/a/`. The special root optional
case remains entirely in `match_path`. Constraints run on decoded captures;
the trie neither interprets them nor favors a constrained or static route over
an earlier registration. Static text stays raw, including percent signs and
Unicode. Captures decode once, with encoded slash staying inside its original
segment and invalid UTF-8 or escapes rejecting only that candidate. Wildcards
also retain repeated and trailing separators. These cases need no second
decoder proof: the prefix lemma must avoid assuming decoded static text or
requiring a slash that an omitted terminal segment does not consume.

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
Literal fixtures independently cover registration priority, ancestor buckets,
empty segments, root optionals, decoding, and empty tables.

The generated run produced `pairs=10000 disagreements=0` in 16.1 seconds on
ms-a2, excluding compilation. Reversing `minimum` deliberately made the
earlier-wildcard fixture fail; restoring it passed. Existing laws and the
pattern/spec modules are unchanged. These checks provide evidence, not the
equivalence proof assigned to BND-17.

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

Measured on 2026-10-22 in Boat sandbox `bx_evcnpxyu` (`default`, 4 vCPU,
8 GB RAM), AMD Ryzen 9 9950X under KVM, x86-64 Linux, Bend 2.0.38, and Ubuntu
clang 18.1.3. The executable was 579,560 bytes and compiled in 5.09 seconds.
All 108 measured samples passed their independent checksum checks. The full
benchmark took 53.1 seconds, including calibration and compilation. Preparation
was 0–2 ms at the measured clock resolution. The sandbox was deleted; the final
`boat-sbx ls --label bnd-16-router-trie` listing was empty.

| Routes | Workload | Spec ns/lookup | Trie ns/lookup | Spec / Trie |
| --- | --- | ---: | ---: | ---: |
| 5 | mixed | 500 | 550 | 0.91x |
| 5 | last | 600 | 450 | 1.33x |
| 5 | miss | 700 | 200 | 3.50x |
| 5 | first | 200 | 700 | 0.29x |
| 5 | dynamic-first | 9,600 | 10,000 | 0.96x |
| 5 | dynamic-last | 96,500 | 93,694 | 1.03x |
| 50 | mixed | 2,900 | 850 | 3.41x |
| 50 | last | 5,800 | 500 | 11.60x |
| 50 | miss | 6,300 | 150 | 42.00x |
| 50 | first | 200 | 1,100 | 0.18x |
| 50 | dynamic-first | 9,550 | 9,900 | 0.96x |
| 50 | dynamic-last | 965,000 | 920,000 | 1.05x |
| 500 | mixed | 30,000 | 1,070 | 28.04x |
| 500 | last | 61,333 | 470 | 130.50x |
| 500 | miss | 57,000 | 420 | 135.71x |
| 500 | first | 150 | 1,490 | 0.10x |
| 500 | dynamic-first | 9,700 | 11,000 | 0.88x |
| 500 | dynamic-last | 9,334,000 | 9,328,000 | 1.00x |

The 500-route mixed lookup is 28.04x faster, passing the 5x target. Raw samples,
preparation times, iteration counts, environment details, and checksums are in
[`bench/router/results.json`](../bench/router/results.json).

Reproduce official measurements from the repo root with Boat CLI access:

```sh
sh bench/router/boat.sh
```

The script creates a `default` sandbox, installs the pinned Bend release,
copies the router and benchmark, runs the bounded harness, retrieves results,
and deletes its sandbox even on failure. It replaces the local results file.
For a short development run, use
`timeout --foreground 90s python3 bench/router/run.py --quick --output /tmp/router-results.json`.

This conservative trie accelerates selective static prefixes. Routes sharing
their first dynamic prefix remain in one ordered bucket, so lookup can still
be linear. First-hit spec lookups can beat the trie because they avoid prefix
traversal. The 500-route target concerns the documented static mixed workload;
it does not promise a fivefold gain for every route distribution or request.
