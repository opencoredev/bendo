# 0008: Hono router differences

Status: accepted compatibility record for BND-20, 2026-10-23.

Bendo selects one registration; Hono can return a middleware chain. The fixture
preserves Hono’s complete handler list, registration order, method, pattern and
request, then records a literal Bendo result. This decision records existing
contracts; it does not expand or change the router grammar.

## Source and coverage

The source is [Hono](https://github.com/honojs/hono/tree/5ca49b0720755c585c9a9835f0a479ceea36fb52),
commit `5ca49b0720755c585c9a9835f0a479ceea36fb52`. The fixture header carries
Hono’s copyright and full MIT license. No Hono implementation is vendored.

`tests/fixtures/hono-router-cases.json` contains 180 distinct cases: 143 direct
upstream registration/request/result combinations, 15 upstream registration-error
cases, and 22 method-matrix expansions
of upstream ALL registration tables. The `origin` field distinguishes them.
Direct cases come from `src/router/common.case.test.ts` and the RegExpRouter,
PatternRouter and LinearRouter tests; TrieRouter’s specific file invokes the
shared suite. Shared-suite repeats with identical inputs and outputs are removed.
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

Every fixture runs through one compiled native Bend driver. For valid tables it
calls `Router.route` with both `Spec` and `Trie`, and `Methods.resolve` with the
original method registrations and default options. The path-only engines see all
registrations regardless of method, so their result can legitimately differ
from method resolution. Each result must equal its own literal expectation;
the two path engines must also agree with each other.

A path hit is `index:tag|encoded-name=encoded-value`, with both index and numeric tag
identifying the original registration (zero-based). Method hits append
`;head_from_get=true` for GET fallback and `;head_from_get=false` for direct hits. Param names and values use
uppercase percent-encoded UTF-8 bytes in pattern order. `none` means no path
match; `allow:...` records the exact Allow text. `error:index:Kind` records the
first pattern compilation failure. Invalid tables cannot be prepared or routed:
the driver checks the shared path builder and method builder both reject them,
and repeats the path build error in the two engine columns.

These are assertions, not allowed failures. Every documented difference must
continue producing its recorded result. A new difference needs an explicit
fixture and a reason here; passing merely because the routers agree is insufficient.

## Differences

Counts overlap when a case exercises more than one decision. The fixture is the
per-case record of the Hono handler list and the actual expected Bendo result.

| Category | Cases | Hono behavior | Bendo behavior | Reason |
| --- | --- | --- | --- | --- |
| registration-rejection | hono-099, hono-122, hono-131, hono-132, hono-137, hono-140, hono-141, hono-142, hono-143, hono-144, hono-145, hono-146, hono-147, hono-148, hono-149 (15) | A router-specific upstream test rejects registration with UnsupportedPathError. | Either rejects unsupported Bendo syntax, or accepts the table and routes the recorded probe request. | Hono’s RegExpRouter rejects overlapping static/dynamic patterns and differing capture labels that Bendo supports with registration-order selection. The fixture preserves the exact upstream rejection and marks the additional Bendo probe request; these are original upstream registration tests, not method-matrix expansions. |
| static-punctuation | hono-117, hono-118, hono-119, hono-120 (4) | RegExpRouter treats a colon inside a static segment as literal text. | Rejects with InvalidStatic. | BND-14 reserves colon for captures and rejects it inside static segments. |
| path-only-syntax | hono-015, hono-017, hono-018, hono-020, hono-021, hono-022, hono-041, hono-042, hono-043, hono-044, hono-045, hono-046, hono-065, hono-066, hono-067, hono-074, hono-075, hono-076, hono-077, hono-078, hono-079, hono-080, hono-112, hono-154, hono-155, hono-156, hono-157 (27) | Accepts bare `*` and hostname-prefixed patterns. | Rejects with `MissingSlash` at the recorded registration index. | BND-14 requires a slash-prefixed raw path. Use `/*` for a catch-all; hostname dispatch belongs outside path matching. |
| regex | hono-001, hono-005, hono-006, hono-007, hono-008, hono-009, hono-010, hono-011, hono-012, hono-013, hono-014, hono-031, hono-032, hono-033, hono-034, hono-035, hono-036, hono-037, hono-038, hono-039, hono-040, hono-103, hono-104, hono-105, hono-113, hono-114, hono-115, hono-116, hono-122, hono-123, hono-124, hono-125, hono-126, hono-127, hono-128, hono-129, hono-130, hono-131, hono-132, hono-133, hono-137, hono-142, hono-152 (43) | Supports a broader JavaScript regex grammar, including groups, `.*`, `.+`, slash-spanning captures and negated classes; router-specific rejections are recorded separately. | Rejects the entire table with `UnknownConstraint`, `UnbalancedBraces`, or `InvalidClass`. | BND-14 deliberately supports named constraints and simple positive character classes only. Use a terminal named wildcard for a remainder; arbitrary regex is outside the grammar. |
| unique-params | hono-070, hono-071, hono-072, hono-099 (4) | TrieRouter accepts repeated names in one pattern and returns the first captured value. | Rejects with `DuplicateName`. | BND-14 requires unique names so captures and reverse filling have an unambiguous assignment. PatternRouter also rejects these cases. |
| suffix-wildcards | hono-059, hono-060, hono-061, hono-062, hono-063, hono-064, hono-134, hono-135 (8) | Matches `/assets*` as a static prefix wildcard. | Rejects with `InvalidStatic`. | BND-14 permits wildcard segments only; `/assets/*` does not mean `/assets-v2`. |
| terminal-wildcards | hono-053, hono-054, hono-055, hono-088, hono-092, hono-102, hono-121 (7) | Accepts wildcard segments before later segments. | Rejects with `WildcardNotLast`. | BND-14 requires wildcards to consume the terminal remainder. |
| terminal-optionals | hono-048, hono-049, hono-050, hono-051, hono-052, hono-153 (6) | Expands optional params before other optional params. | Rejects atomically with `OptionalNotLast`, even when the request could match a different valid registration. | BND-14 permits only a terminal optional capture. A rejected table never partially registers valid entries. |
| wildcard-capture | hono-016, hono-029, hono-030, hono-057, hono-058, hono-081, hono-082, hono-086, hono-100, hono-101, hono-106, hono-107, hono-109, hono-110, hono-111, hono-179, hono-180 (17) | Unnamed wildcards contribute no param. | Returns an additional `*` param containing the remainder, including an empty string. | BND-14 makes wildcard capture explicit and usable for filling. Existing named params are preserved. |
| first-match | hono-016, hono-023, hono-029, hono-030, hono-068, hono-069, hono-081, hono-082, hono-087, hono-106, hono-107, hono-108, hono-109, hono-111, hono-136 (15) | Returns multiple handlers in registration order. | Returns only the first matching registration and its own params. | Decision 0001 and BND-15 use one app-owned tag per route result. The fixture retains the complete Hono list and explicitly projects its first result. |
| method-not-allowed | hono-003, hono-004, hono-095, hono-168, hono-171, hono-172, hono-173, hono-174, hono-175, hono-176, hono-177, hono-178 (12) | Returns an empty match list when a path exists for other methods. | Returns `MethodNotAllowed` with a canonical Allow union, adding HEAD for GET. | BND-18 models HTTP 405 explicitly. The native result records the exact Allow text. |
| all-standard-methods | hono-003, hono-168 (2) | ALL accepts extension methods, including PURGE and UNKNOWN_METHOD. | ALL accepts nine standard methods only; unmatched extension methods return 405. | BND-18 explicitly defines the finite standard-method set. Register extensions with `on`. |
| head-fallback | hono-170 (1) | The router alone does not fall back from HEAD to GET. | Methods.resolve selects GET when no direct HEAD match exists. | BND-18 supplies HTTP HEAD fallback in the method layer. |
| strict-slash | hono-002 (1) | PatternRouter and LinearRouter match `/book/` to `/book`; TrieRouter does not. | Default strict matching returns no match. | BND-14 preserves empty terminal segments; BND-18 exposes an explicit non-strict option. These tests use defaults. |

## Verification and limits

```sh
bun test --timeout 30000 tests/router-hono-cases.test.ts
bun run check
```

The test compiles once and runs batches of 60 cases with one native runtime
thread. Each batch has a 15-second limit; the test has a 30-second limit.
It checks fixture IDs, removes identical coverage claims, and requires each
listed difference’s ID to occur in its category row above.

No router source or law changes are part of BND-20. The port found no unexplained
Spec/Trie disagreement or suspected Bendo bug. Rejected JavaScript regex and
middleware-chain differences are intentional contract differences, not bug fixes.
