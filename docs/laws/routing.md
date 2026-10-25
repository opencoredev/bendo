# Routing laws

These laws cover route patterns, the reference router, the trie, method
resolution, route composition and the route manifest. See the
[laws index](README.md) for how to read an entry.

## Patterns

A route pattern compiles once, then matches raw request paths. The two main
laws say that matching agrees with an independent specification for every
pattern and path, and that any admissible set of parameters fills into a path
that matches back to exactly those parameters. The fixed examples pin each
documented syntax form. See [route patterns](../router-patterns.md).

- `pattern_match_spec`: for every pattern and every raw path, matching gives the same hit or miss and the same ordered captures as the independent specification in `proof/router-match-spec.bend`, including precedence: optional captures take present segments, interior wildcards take the fewest segments and spans the most. The specification calls no `Pattern` helper.
- `pattern_fill_match`: for every pattern that compiles and every admissible ordered assignment of its captures, filling succeeds and the filled path matches back to the same assignment. Admissible means the exact capture names in order, nonempty values that meet their constraints and are Unicode scalars, only a trailing run of optional captures omitted, and a wildcard allowed to be empty.
- `compile_bare_star`, `compile_prefix_wildcard`, `compile_interior_wildcards`, `compile_optional_chain`, `compile_static_colon`, `compile_anchored_span`: one example each: `*`, `/assets*`, `/a/*/b/*`, `/v1/:version?/:platform?`, `/v1/name:activate` and `/:prefix{.+}/contents/:id?` compile to the segments the specification reads.
- `compile_unanchored_span`: a span with no static segment after it, as in `/:a{.+}/:b`, is a compile error.
- `spec_prefix_wildcard`, `spec_interior_wildcards`, `spec_optional_chain`, `spec_greedy_span`: one example each of what the specification returns for those forms: `/assets*` matches `/assets-v2` and `/assets/app.js`; `/a/*/b/*` puts `c/d` in the final wildcard for `/a/x/y/b/c/d`; `/v1/x` fills only `version`; a span takes as much as it can while the rest still matches.
- `pattern_compile_spec`: for every string, compiling succeeds with a pattern exactly when the independent source grammar in `proof/router-compile-spec.bend` maps the string to that pattern, and fails exactly when the grammar rejects it. The grammar covers static text with literal `:`, captures with constraints, the trailing optional chain, bare `*`, named, prefix and interior wildcards, and anchored spans with their `InvalidSpan` rules. It calls no `Pattern` helper. It shares the constraint grammar for the text inside `{...}`, and error kinds are not compared.
- `compile_spec_forms`: the grammar accepts `/images*`, `/x/*/y/*`, `/:a?/:b?/:c?`, `/jobs/run:now` and `/:rest{.+}/end`, each with the expected segments.
- `compile_spec_rejects`: the grammar rejects `/*path/x` (named wildcard not last), `/:a?/b` (a present segment after an optional), `/:id/:id` (repeated name), `/:a{.+}?/x` (optional span) and `/:a{.+}/*` (span with a wildcard).

## The reference router

The reference router (`Spec.route`) tries registrations in order and returns
the first match. These laws compare it with an independent per-index lookup,
so first-match-wins holds for every table, path and tag, not for examples.
See [spec router](../router-spec.md).

- `router_sound`: when the router returns registration `i` with its tag and params, that registration matches the path with exactly those params, and every earlier registration misses.
- `router_complete`: if any registration matches the path, the router returns a hit at that index or earlier.
- `router_first_match`: when registration `i` matches and nothing before it does, the router returns exactly `i`, its tag and its params, even if later routes also match.
- `router_priority`: when two registrations match and `a` comes before `b`, the winner is no later than `a` and strictly before `b`.
- `router_fill_match`: filling any admissible assignment into a compiled route at index `i` gives a path the router hits at `i` or earlier, and at exactly `i` with those params when no earlier route matches it.

## Trie and router kinds

The trie router is the fast path. Its laws say it is a drop-in replacement for
the reference router. See [trie router](../router-trie.md).

- `trie_route_spec`: for every table, including hand-built patterns `Pattern.compile` could never produce, and every path, the trie returns the reference router's exact result.
- `trie_matches_spec`: the trie's list of matches is every registration whose pattern matches the path, in index order, with tag and params, as an independent filter over the whole table computes it.
- `router_kind_spec`: every router kind, prepared from a table, routes exactly like the reference router.

## Method resolution

On top of path matching, method resolution picks a handler for the request
method, falls back from HEAD to GET, and answers 404 or 405 with an exact
`Allow` set. These laws hold for every valid table, path, method and option
setting (strict trailing slash and case sensitivity). See
[route by HTTP method](../router-methods.md).

- `methods_found_first`: a direct hit is the first registration that matches both path and method under the given options.
- `methods_default_found_first`: with default options, the same, stated with plain `Pattern.match_path` and an independent method selector.
- `methods_default_path_identity`: default options match exactly as the original pattern matcher.
- `methods_explicit_head_priority`: if any HEAD registration matches, it wins over every GET fallback, and it is the first matching HEAD registration.
- `methods_head_fallback_first_get`: a HEAD-from-GET result happens only for a HEAD request when every HEAD registration misses, and it is exactly the first matching GET registration with its params.
- `methods_not_found_iff_all_paths_miss`: the result is 404 exactly when every registered pattern misses the path, including registrations with an empty method list.
- `methods_allow_exact`: a 405 carries exactly the methods of every registration matching the path, plus HEAD where GET matches, each once, in canonical order, without the requested method. A matching all-methods route never yields a 405.
- `methods_build_valid`: every table built through the public constructor carries valid method tokens.
- `methods_router_resolve`: method resolution through every router kind equals `Methods.resolve`, so every law above holds for the configured router too.

## Route composition

`group`, `mount` and base paths rewrite route lists before the table is built.
The first three laws pin each operation to an independent assembly in
`proof/compose-spec.bend`. The segment laws state the cancellation facts
behind prefixes on compiled segments; the mounting laws below lift them to
source strings. See [compose route lists](../router-compose.md).

- `compose_prepare`, `compose_group`, `compose_mount`: preparing, grouping and mounting a route list equal the independent assembly, entry for entry.
- `compose_mount_routing`: routing a mounted list, for every router kind, path, method and option setting, equals routing the independently prefixed list, build failures included. It does not relate a mounted request to the unmounted suffix.
- `compose_literal_segments_suffix`: a pattern behind literal prefix segments matches the prefix plus a path exactly as the pattern alone matches the path.
- `compose_literal_groups_associate`: nesting literal prefix groups gives the same matches and captures as one combined prefix.
- `compose_literal_boundary_miss`: a literal segment misses a different whole segment, even when one string is a prefix of the other.

## Source-string mounting

These laws start from what users write: a prefix string, a member route
source and a request. They compile the source that `B.route` builds and match
it with the method layer's slash and case options, and compare the result with
the independent specification in `proof/mount-spec.bend`. That specification
joins at the segment level instead of concatenating strings: it splits the
prefix (dropping one terminal slash), reads each prefix segment and the member
with the BND-83 source grammar, and matches with the BND-78 matcher, so it
calls no composition, compilation, splitting or matching helper of the router.

Most of the laws assume an admissible mount. The prefix is empty, `/`, or
any prefix the [pattern syntax](../router-patterns.md) allows: static
segments, captures with or without constraints, optional captures, anonymous
wildcards that become interior wildcards, spans, and repeated slashes inside
it. Two things are required. The assembled pattern compiles, so its rules
hold across the join: one trailing optional chain spanning prefix and member,
wildcard and span placement, distinct names. And the prefix's last segment is
not empty. The only prefixes left out are the ones that end in repeated
slashes, such as `/a//` and `//`: in lenient mode their empty last segment
would drop together with the member's trailing empty segments, which is the
flattening counterexample in [compose route lists](../router-compose.md).
Members must be route sources on their own (start with `/`, or be `*`).

- `match_options_spec`: for every pattern, raw path and option setting, method-layer matching equals the independent option reading: lenient mode drops every terminal empty segment of the path and every terminal empty static of the pattern, keeping one for root, and case-insensitive mode folds ASCII letters (the letter-table fold) only in static text and a prefix wildcard's literal prefix. Captures keep the request's bytes.
- `mount_compile_spec`: for every prefix that is empty or starts with `/`, and every member that starts with `/` or is `*` (any member under a root prefix), the public assembled source compiles to exactly the specification's segment-level join, or fails exactly when the join fails.
- `mount_match_spec`: for an admissible prefix and member, every request path and every option setting, compiling and matching the public assembled source gives exactly the specified mounted match. The prefix walks the request's segments (normalized for the slash option) first, each segment by its own rule: static text compared under the case option, a capture decoded and checked, an optional capture that may stand at the end of the path, an interior wildcard that skips as few whole segments as it can, a span that takes as many as still let the rest match. The member then matches the remaining segments, and prefix captures come before member captures. The member has no root rule of its own; the assembled pattern keeps one, so `/:tenant?` with `/:id?` answers `/`. It gives no match exactly when the specification has none. Under a root prefix the member answers alone, root rule included.
- `mount_resolve_spec`: for a mounted registration list whose routes are all admissible and whose methods are valid, building the table succeeds, and method resolution through every router kind equals first-match over the specified mounted answers in registration order: a direct hit wins, HEAD falls back to the first GET, a path some route answers gives 405 with the canonical Allow set of every answering route, and any other path gives 404.
- `mount_literal_suffix`: under a literal prefix (every prefix segment plain static text), with strict trailing slashes and either case mode, a request for the prefix's path plus `/r` routes exactly as the member alone routes `/r`, unless `/r` is `/` and the member is a chain of optional captures. It needs strict mode; see `mount_lenient_suffix_counterexample`.
- `mount_literal_root`: that exception is the documented root convention. A member made of optional captures answers the bare prefix path as it alone answers `/`, and the prefix path plus `/` not at all.
- `mount_literal_converse`: with default options, every request a literal mount answers is the prefix's path followed by nothing or by a suffix that starts with `/`. A mount under `/api` never answers `/apix` or `/users`.
- `mount_literal_converse_sensitive`: the same conclusion for case-sensitive matching with either slash option.
- `mount_literal_converse_options`: under every slash and case option, every request a literal mount answers starts with segments that spell the prefix's segments under the case option (exactly, or after ASCII folding when matching is case-insensitive), followed by nothing or by a suffix that starts with `/`. A case-insensitive mount under `/api` answers `/API/x` but never `/apix`.
- `mount_admissible_examples`: `/api` with `/users/:id`, `/v1/:tenant` with `/files/*`, `/` with `/:id?`, the empty prefix with `/users`, `/api` with `/:id?`, `/t/:n{int}` with `/` and `/api/` with `*` are admissible.
- `mount_admissible_forms`: `/*` with `/x`, `/:tenant?` with `/:id?`, `/:scope{.+}` with `/x`, `/a//b` with `/x` and `/a/*/b` with `/:id` are admissible; `/:tenant?` with `/x` or with `/` is not, because the assembled pattern does not compile.
- `mount_spec_examples`: the specification answers `/api/users/42` with `id=42` and neither `/users/42` nor `/apix/users/42`; `/v1/acme/files/a/b` with `tenant=acme` then `*=a/b`; `/` under a root mount of `/:id?`; and `/api/users/` for `/API/` with `/Users` under lenient, case-insensitive options.
- `mount_spec_form_examples`: under `/*`, `/x` answers `/a/b/x` and `/x` (an interior wildcard may skip no segments) but not `/a/b`; under `/:tenant?`, `/:id?` answers `/acme/7` with both captures, `/acme` with `tenant` only, and `/` with none; under `/:scope{.+}`, `/x` answers `/a/x/b/x` with `scope=a/x/b` but not `/x`; under `/a//b`, `/x` answers `/a//b/x` but not `/a/b/x`.
- `mount_counterexamples`: mounted `/:id?` answers `/api` but not `/api/`, although alone it answers `/`, so `mount_literal_suffix` excludes it by its root-convention premise; the prefixes `/a//` and `//` are not admissible.
- `mount_lenient_suffix_counterexample`: suffix cancellation fails in lenient mode. Mounted under `/api`, `//:id?` rejects `/api/`, while alone it answers `/` with no captures, even though the mount is admissible, the prefix is literal and the root-convention exception does not apply.

## Route manifest

`--bendo-routes` prints one row per route and method. These laws say the rows
come from the compiled routes, not from guessing at source text. See
[route manifest](../manifest.md).

- `manifest_capture_names`: capture names are read from the compiled segments, as the independent definition lists them.
- `manifest_exact_routes`: the rows are exactly the registered routes with normalized methods and ordered capture names, in registration order with duplicates; `ALL` stays one row of its own.
- `manifest_built_routes`: for every successful build, the rows are exactly the entries' route declarations, in entry order with duplicates: full assembled path, normalized methods (no implicit HEAD) and capture names. Hooks and middleware add no rows.
