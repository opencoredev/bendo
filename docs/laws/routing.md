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
behind prefixes; they are stated on compiled segments, and lifting them to
source strings is not claimed. See [compose route lists](../router-compose.md).

- `compose_prepare`, `compose_group`, `compose_mount`: preparing, grouping and mounting a route list equal the independent assembly, entry for entry.
- `compose_mount_routing`: routing a mounted list, for every router kind, path, method and option setting, equals routing the independently prefixed list, build failures included. It does not relate a mounted request to the unmounted suffix.
- `compose_literal_segments_suffix`: a pattern behind literal prefix segments matches the prefix plus a path exactly as the pattern alone matches the path.
- `compose_literal_groups_associate`: nesting literal prefix groups gives the same matches and captures as one combined prefix.
- `compose_literal_boundary_miss`: a literal segment misses a different whole segment, even when one string is a prefix of the other.

## Route manifest

`--bendo-routes` prints one row per route and method. These laws say the rows
come from the compiled routes, not from guessing at source text. See
[route manifest](../manifest.md).

- `manifest_capture_names`: capture names are read from the compiled segments, as the independent definition lists them.
- `manifest_exact_routes`: the rows are exactly the registered routes with normalized methods and ordered capture names, in registration order with duplicates; `ALL` stays one row of its own.
- `manifest_built_routes`: for every successful build, the rows are exactly the entries' route declarations, in entry order with duplicates: full assembled path, normalized methods (no implicit HEAD) and capture names. Hooks and middleware add no rows.
