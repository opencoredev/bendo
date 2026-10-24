# 0008: Hono router differences

Status: accepted compatibility record for BND-20, 2026-10-23.

Bendo selects one registration; Hono can return a middleware chain. The fixture
preserves Hono’s complete handler list, registration order, method, pattern and
request, then records a literal Bendo result. This decision records existing contracts and the additional syntax implemented
for BND-78.

## Source and coverage

The source is [Hono](https://github.com/honojs/hono/tree/5ca49b0720755c585c9a9835f0a479ceea36fb52),
commit `5ca49b0720755c585c9a9835f0a479ceea36fb52`. The fixture header carries
Hono’s copyright and full MIT license. No Hono implementation is vendored.

`tests/fixtures/hono-router-cases.json` contains 174 distinct cases: 136 direct
upstream registration/request/result combinations, 15 upstream registration-error
cases (151 upstream ports total), 22 method-matrix expansions
of upstream ALL registration tables, and one greedy-span regression (hono-181)
queried against Hono's TrieRouter 4.13.13. The `origin` field distinguishes them.
Direct cases come from `src/router/common.case.test.ts` and the RegExpRouter,
PatternRouter and LinearRouter tests; TrieRouter’s specific file invokes the
shared suite. Shared-suite repeats with identical inputs and outputs are removed, comparing
parameter maps independently of key order. Seven duplicate rows (hono-152 through
hono-158) were merged into their earlier equivalents; existing IDs stay stable.
The PatternRouter and LinearRouter trailing-slash behavior remains distinct from
the shared TrieRouter behavior. Registration-only tests retain `honoError=UnsupportedPathError`; their `origin`
explicitly marks the added probe request for Bendo. They count as upstream test
ports, not upstream match requests. The minimum-count gate excludes all method
matrix expansions and still requires at least 150 upstream cases.

The data was collected by executing the upstream suites against their actual
routers and checking their original assertions. RegExpRouter’s self-replacing instance-level `match` was captured as well as
the prototype methods. Each method expansion was also
queried against Hono’s TrieRouter. Supported-path expectations were checked
independently against Hono with method filtering removed, then adjusted only for
the documented contracts below. Unsupported patterns retain their original text;
they are never silently rewritten or skipped.

## Result format and execution

All 174 fixtures run through one compiled native Bend driver. After BND-78's
pattern extensions, 132 tables are valid and exercise both engines; 42 still
assert atomic construction errors for deliberately unsupported syntax. For valid
tables the driver calls `Router.route` with both `Spec` and `Trie`, and
`Methods.resolve` with the original method registrations and default options.
The path-only engines see registrations regardless of method, so their result
can differ from method resolution. Each result must equal its literal
expectation; the two path engines must also agree.

A path hit is `index:tag|encoded-name=encoded-value`, with both index and numeric tag
identifying the original registration (zero-based). Method hits append
`;head_from_get=true` for GET fallback and `;head_from_get=false` for direct hits. Param names and values use
uppercase percent-encoded UTF-8 bytes in pattern order. `none` means no path
match; `allow:...` records the exact Allow text. `error:index:Kind` records the
first pattern compilation failure. Invalid tables cannot be prepared or routed:
the driver checks the shared path builder and method builder both reject them,
and repeats the path build error in the two engine columns.

The mutually exclusive case counts are 63 identical and 111 with principled differences only. No fixture retains a
BND-78 syntax-gap marker. These are assertions,
not allowed failures. Every documented difference must continue producing its
recorded result.

## Principled differences

These are deliberate contracts. Counts overlap when a case exercises more than
one contract. The fixture preserves the complete Hono handler list and records
Bendo's literal result in each case.

| Category | Cases | Hono behavior | Bendo behavior | Reason |
| --- | --- | --- | --- | --- |
| first-match | hono-015, hono-016, hono-017, hono-018, hono-023, hono-029, hono-030, hono-041, hono-042, hono-043, hono-044, hono-045, hono-046, hono-059, hono-060, hono-065, hono-066, hono-067, hono-068, hono-069, hono-075, hono-076, hono-077, hono-078, hono-079, hono-080, hono-081, hono-082, hono-087, hono-106, hono-107, hono-108, hono-109, hono-111, hono-112, hono-136 (36) | Returns multiple handlers in registration order. | Returns only the first matching registration and its own params. | Decision 0001 and BND-15 use one app-owned tag per route result. The fixture retains the complete Hono list and explicitly projects its first result. |
| method-not-allowed | hono-004, hono-095, hono-171, hono-172, hono-173, hono-174, hono-175, hono-176, hono-177, hono-178 (10) | Returns an empty match list when a path exists for other methods. | Returns `MethodNotAllowed` with a canonical Allow union, adding HEAD for GET. | BND-18 models HTTP 405 explicitly. The native result records the exact Allow text. |
| head-fallback | hono-170 (1) | The router alone does not fall back from HEAD to GET. | Methods.resolve selects GET when no direct HEAD match exists. | BND-18 supplies HTTP HEAD fallback in the method layer. |
| wildcard-capture | hono-015, hono-016, hono-017, hono-029, hono-030, hono-041, hono-042, hono-043, hono-044, hono-045, hono-046, hono-054, hono-055, hono-057, hono-058, hono-065, hono-074, hono-075, hono-076, hono-077, hono-078, hono-080, hono-081, hono-082, hono-086, hono-100, hono-101, hono-106, hono-107, hono-109, hono-110, hono-111, hono-112, hono-134, hono-179, hono-180 (36) | Unnamed wildcards contribute no param. | Returns an additional `*` param containing the remainder, including an empty string. | BND-14 makes wildcard capture explicit and usable for filling. Existing named params are preserved. |
| unique-params | hono-070, hono-071, hono-072, hono-099 (4) | TrieRouter accepts repeated names in one pattern and returns the first captured value. | Rejects with `DuplicateName`. | BND-14 requires unique names so captures and reverse filling have an unambiguous assignment. PatternRouter also rejects these cases. |
| registration-rejection | hono-099, hono-122, hono-131, hono-132, hono-137, hono-140, hono-141, hono-142, hono-143, hono-144, hono-145, hono-146, hono-147, hono-148, hono-149 (15) | A router-specific upstream test rejects registration with UnsupportedPathError. | Either rejects unsupported Bendo syntax, or accepts the table and routes the recorded probe request. | Hono’s RegExpRouter rejects overlapping static/dynamic patterns and differing capture labels that Bendo supports with registration-order selection. The fixture preserves the exact upstream rejection and marks the additional Bendo probe request; these are original upstream registration tests, not method-matrix expansions. |
| strict-slash | hono-002 (1) | PatternRouter and LinearRouter match `/book/` to `/book`; TrieRouter does not. | Default strict matching returns no match. | BND-14 preserves empty terminal segments; BND-18 exposes an explicit non-strict option. These tests use defaults. |
| hostname-dispatch | hono-020, hono-021, hono-022 (3) | Accepts hostname-prefixed patterns. | Rejects with `MissingSlash`. | Hostname dispatch belongs outside path matching; Bendo route patterns describe raw paths. |
| regex | hono-001, hono-005, hono-006, hono-007, hono-008, hono-009, hono-010, hono-011, hono-012, hono-013, hono-014, hono-038, hono-039, hono-040, hono-103, hono-104, hono-105, hono-113, hono-114, hono-115, hono-116, hono-122, hono-123, hono-124, hono-125, hono-126, hono-127, hono-128, hono-129, hono-130, hono-131, hono-132, hono-133, hono-137, hono-142 (35) | Supports a broader JavaScript regex grammar, including groups, `.*`, custom slash-spanning classes and negated classes; router-specific rejections are recorded separately. | Rejects the entire table with `UnknownConstraint`, `UnbalancedBraces`, or `InvalidClass`. | BND-14 deliberately supports named constraints and simple positive character classes only. Use a terminal named wildcard for a remainder; arbitrary regex is outside the grammar. |

## Syntax added in BND-78

Bare `*` now aliases `/*`. Prefix wildcards such as `/assets*`, interior unnamed
wildcards such as `/a/*/b/*`, consecutive trailing optional captures, literal
colons within static segments, and `{.+}` captures before a suffix all compile
and run through both routers and method resolution. `router-patterns.md`
defines their decoding and filling rules. General JavaScript regex remains
unsupported.

The formerly rejected syntax cases now have literal successful or missing-match
expectations. Cases with one handler and matching params become identical,
including hono-031 through hono-037, hono-048 through hono-053, hono-061 through
hono-064, hono-088, hono-092, hono-102, and hono-117 through hono-121. Cases with
multiple Hono handlers retain the first-match difference. Bare and final
wildcards retain Bendo's existing explicit `*` capture. Accepting these patterns
does not remove those contracts. Three cases that exercise the new syntax stay
principled differences:

- hono-015 registers `*`, `/a/*`, `/a/foo`, `/b/*` and `/b/bar`, then requests
  `GET /b/bar`. Hono returns three handlers (`wildcard`, `star2`, `bar`), none
  with params. Bendo returns only the first registration, `*`, with
  `*="b/bar"`. This is first-match plus wildcard-capture.
- hono-054 registers `/a/*/b/*` and requests `/a/x/b/c`. Both select the same
  handler. Hono returns no params; Bendo also returns `*="c"` from the final
  wildcard. The interior wildcard captures nothing. This is wildcard-capture
  only.
- hono-059 registers `GET /assets*`, `POST /assets/app.js` and `POST /assets*`,
  then requests `POST /assets/app.js`. Hono returns both matching POST handlers.
  Bendo's method resolution returns the first one, `/assets/app.js`, and the
  path-only engines return the first path match, `GET /assets*`. This is
  first-match only.

Spans are greedy, as in Hono's TrieRouter: hono-181 requests
`/a/contents/contents` against `/:prefix{.+}/contents/:id?`, and both give
`prefix="a/contents"` with no `id`.

| Category | Cases | Hono behavior | Bendo behavior | Reason |
| --- | --- | --- | --- | --- |
| registration-priority | hono-134 (1) | RegExpRouter prefers `/a*` over `/a/*` for `/a`. | Selects the earlier `/a/*` registration, with an empty `*` capture. | Registration order remains the BND-15 contract; wildcard spelling does not override it. |

ALL now accepts extension methods, including the PURGE and UNKNOWN_METHOD probes
in hono-168 and hono-003. Both cases are identical. Finite method registrations
retain exact, canonical Allow lists.

## Verification and limits

```sh
bun test --timeout 30000 tests/router-hono-cases.test.ts
bun run check
```

The test compiles once and runs batches of 60 cases with one native runtime
thread. Compilation uses the shared `BEND_COMPILE_TIMEOUT` (180 seconds).
Each batch has a 15-second limit; execution has a 30-second limit.
It checks fixture IDs, removes identical coverage claims, and requires each
listed difference or gap’s ID to occur in its category row above.

The fixture was ported in BND-20 and extended in BND-78. Arbitrary JavaScript
regex and middleware-chain selection remain principled differences. Pattern
construction failures do not exercise either engine.
