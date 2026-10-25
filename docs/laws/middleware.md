# Middleware laws

These laws cover middleware composition, lifecycle hooks and their scopes,
plugins, and the built-in middleware: CORS, secure headers, CSRF, method
override, trailing slash, IP restriction, client addresses, rate limiting and
proxying. See the [laws index](README.md) for how to read an entry.

Most built-in middleware is a pure policy function wrapped in a thin IO
shell. The laws are about the policy function. That the shell calls it and
sends what it returns is covered by integration tests.

## Composition

Middleware composes like functions: identity changes nothing and grouping does
not matter, so an app can be split into reusable stacks without changing its
behavior. See [middleware](../middleware.md).

- `middleware_application`: composing `a` then `b` runs `a` with a continuation that runs `b` on whatever context `a` passes on.
- `middleware_identity_left`, `middleware_identity_right`: composing with the identity middleware on either side changes nothing.
- `middleware_identity_insert`: inserting an identity between two middleware changes no result, even when the first short-circuits or changes the context.
- `middleware_associative`: `(a then b) then c` equals `a then (b then c)`.

## Lifecycle selection and hook scopes

At build time each request stage (request, parse, transform, before handle,
after handle, map response, error, after response) gets a list of hook ids.
These laws say that list is exactly what the registrations ask for, in
registration order with duplicates kept, and that scoped hooks (from `group`,
`guard` and route-local declarations) reach only member routes. Each is
stated against independent specifications in `proof/middleware-selection-spec.bend`,
`proof/scoped-selection-spec.bend` and `proof/scoped-assembly-spec.bend`.
They describe selection, not execution: a stage that a short circuit skips
still selects its hooks. See [decision 0010](../decisions/0010-hooks.md) and
[decision 0011](../decisions/0011-hook-scopes.md).

- `middleware_registration_selection`: for every successful build and raw path, ordinary middleware selection keeps registration order and duplicates, interleaving global and matching path-specific ids. Hooks add no ordinary ids.
- `lifecycle_stage_selection`: every stage selects exactly its ids, in registration order with duplicates.
- `lifecycle_ordered_selection`: the full plan the request handler consumes equals the specification for every path. Only ordinary path-specific middleware depends on the path (as the request hooks rewrote it); request and response hooks do not.
- `scoped_stage_selection`, `scoped_lifecycle_selection`: with scopes, a stage selects global hooks first, then inherited group and guard placements, then route-local hooks, keeping each source's order and every duplicate. No selected route (a routing miss or method failure) means global hooks only.
- `scoped_nonmember_global_only`: a route that is not a member of a scope gets only global hooks, even when its path matches the scope's prefix.
- `scoped_miss_global_only`: with no selected route, every stage selects only global hooks.
- `scoped_resolved_stage_selection`: at the real runtime boundary (every path, method, router kind and option setting) the hooks selected for the resolved route equal the specification's. This also checks the conversion from router index to source position.
- `scoped_guard_assembly`, `scoped_group_assembly`, `scoped_local_assembly`: `guard`, `group` and route-local hooks assemble entries equal to the independent assembly, including scope provenance, route order, every duplicate and every placement. Explicit hooks come before direct declarations, and outer placements before inner ones.
- `scoped_nested_assembly_isolation`: a guard around a group, with any contents, leaves the entries before and after it untouched.
- `scoped_guard_built_selection`, `scoped_group_built_selection`: building a table from a guard or group followed by any other entries selects, per route and stage, exactly what the specification selects from the independent assembly.

At startup the server indexes the scoped layers by route identity and keeps
the global layers in their own list, so a request reads its own route's hooks
and never walks another route's (BND-82, [decision 0014](../decisions/0014-performance.md)).
These laws say the index changes nothing that is selected. The first five hold
for every layer list, not only built ones, so every law above carries over to
the index.

- `scoped_index_stage_selection`, `scoped_index_lifecycle_selection`: selecting a stage's hooks, or the whole lifecycle plan, from the globals plus the route's bucket gives exactly what selecting from every layer gives, for every route (or none), path and stage.
- `scoped_index_route_schemas`: a route's schemas read from its bucket equal the schemas read from every layer.
- `scoped_index_global_stages`, `scoped_index_global_selected`: the global list alone selects every global stage hook and every path middleware, as the full list does. Not-found hooks and the path middleware before routing use it.
- `scoped_index_spec_stage_selection`, `scoped_index_spec_lifecycle_selection`: for every built table, selection through the index equals the BND-24 specification read from the source registrations.

## Plugins

A plugin is a named or anonymous bundle of registrations. These laws make
named plugins idempotent and anonymous ones plain concatenation. See
[write a plugin](../guides/plugins.md).

- `plugin_first_use_assembly`: any sequence of plugin uses, nested to any depth, from any starting app, equals an independent assembly in which only the first use of each identity counts. Equality covers the applied identities and every entry: order, duplicates, prefixes and hook provenance.
- `plugin_named_repeat`: using a named plugin a second time right after the first is a no-op, whatever either body contains.
- `plugin_anonymous_flatten`: anonymous plugins add exactly their flattened bodies to the entry list and never change the applied identities.

## CORS

The CORS middleware decides a grant (an `Access-Control-Allow-Origin` value
and a credentials flag) from the policy and the request's `Origin`, then
rewrites the response. These laws compare each step with
`proof/cors-spec.bend` and `proof/cors-response-spec.bend`. Together they say
a wildcard policy never allows credentials, a listed policy only ever echoes
the request's own origin, and every CORS response varies on `Origin`. See
[CORS, secure headers, method override and trailing slash](../web-middleware.md).

- `cors_grant_spec`: the grant equals the specification for every policy and `Origin` field: a wildcard policy answers `*` without credentials; a listed policy answers only a request whose single `Origin` serializes to a configured origin, echoing it with that entry's credentials flag.
- `cors_wildcard_never_credentials`: a wildcard policy grants `*` without credentials for every request.
- `cors_listed_denies_unusable_origin`: a listed policy denies a request with no `Origin`, a repeated one, `null`, or anything that is not a bare http or https origin, and never falls back to `*`.
- `cors_listed_grant_echoes_origin`: whatever a listed policy grants names exactly the request's own serialized origin.
- `cors_configured_origins`: configured origins are compared as URL origins, in order; entries that are not http or https URLs, including `*` and `null`, are dropped.
- `cors_preflight_spec`: a preflight is exactly an OPTIONS request with both `Origin` and `Access-Control-Request-Method`; every other request, other OPTIONS requests included, reaches the app.
- `cors_preflight_fields_spec`: a preflight answer carries the granted origin, credentials when granted, the configured methods, the configured (or else reflected) headers and the max age, in that order; a denied origin gets no CORS field.
- `cors_actual_fields_spec`: an ordinary response carries the granted origin, credentials when granted and the exposed headers; a denied origin gets no CORS field.
- `cors_response_spec`: the policy applied to any response the app produced equals the specification: status, body and unrelated fields stay; every downstream copy of the six CORS fields, in any case, is dropped; the complete preflight or actual field set is added, then `Vary` is merged.
- `cors_vary_origin`: a listed-origin response always ends with exactly one `Vary` that covers `Origin`: `*` if downstream `Vary` had `*`, otherwise the downstream values byte for byte followed by `Origin` (and `Access-Control-Request-Headers` for a reflecting preflight) unless already listed.
- `vary_add_spec`: adding names to `Vary` equals the independent merge for every header list.

## Secure headers

- `secure_headers_defaults_spec`: the default policy, applied to any response, keeps status, body and every unrelated field, drops every copy of the eleven default fields and of `X-Powered-By` in any case, and appends the eleven defaults once each. See [web middleware](../web-middleware.md).

## Origins

CORS, CSRF and the WebSocket handshake all compare serialized origins. These
laws tie the shared origin parser to an independent specification
(`proof/origin-spec.bend`, BND-85) and pin the cases from that review. See
[authentication and CSRF](../auth.md).

- `origin_canonical_spec`, `origin_of_url_spec`, `origin_of_host_spec`: the serialized origin of every `Origin` value, every URL (`Referer` values and configured origins) and every scheme and `Host` pair is the specification's.
- `origin_read_back`: reading a serialized origin gives back exactly the scheme, host and port it was parsed from, so two inputs serialize alike only when all three agree. `http` and `https` stay distinct, as do `:8443` and the default port.
- `origin_rejects_invalid_ipv6`, `origin_rejects_ipv6_word`, `origin_rejects_invalid_ipv6_port`: `https://[:::]`, `https://[abc]` and `https://[:::]:443` are not origins; a port does not rescue an invalid host.
- `origin_rejects_ipv4_shorthand`, `origin_rejects_uncompressed_ipv6`: a configured host that a browser would rewrite, such as `http://127.1` or `https://[0::1]`, is refused.
- `origin_keeps_ipv4_quad`, `origin_keeps_compressed_ipv6`: the forms browsers send, `http://127.0.0.1` and `https://[::1]`, are kept unchanged.
- `origin_default_port`, `origin_keeps_other_port`, `origin_keeps_scheme`: `https://a:443` serializes as `https://a`, while `https://a:8443` and `http://a:443` keep their port.

## CSRF

The CSRF middleware blocks cross-site form posts. Its decision equals a
specification that inspects only unsafe requests with a form-like, malformed or
missing `Content-Type`. See [authentication and CSRF](../auth.md).

- `csrf_decision_spec`: for every policy, method and header combination the decision equals `CsrfSpec.allows`. It trusts `Sec-Fetch-Site: same-origin`, a listed source, or the `scheme://Host` origin unless `Sec-Fetch-Site` says cross-site; it prefers `Origin` over `Referer`; it never trusts a missing or unparsable source such as `null`.
- `csrf_configured_decision_spec`: the same, stated from the configuration the middleware is built with: configured entries become their URL origins (non-http and non-https entries are dropped) and the scheme is compared in lowercase.
- `csrf_spec_v1_inspected`, `csrf_spec_v1_denies`: the BND-85 change to fail closed on malformed media types only adds denials: every request the earlier rule inspected is still inspected, and every request it denied is still denied.

## Method override

Method override lets an HTML form POST stand in for another method. These
laws say it can never turn a request into a safe method, so CSRF protection
still sees the rewritten request. See [web middleware](../web-middleware.md).

- `override_decision_spec`: the decision equals the specification: a non-POST, or a POST without an override value, is kept; two or more values are rejected; one value is trimmed, an empty one keeps the request, and otherwise its uppercase method keeps POST, rewrites to exactly that method when it is listed and not a safe name, and is rejected in every other case.
- `override_rewrites_only_post`: a rewrite happens only for a POST.
- `override_keeps_non_post`: any other method is kept as sent.
- `override_rejects_repeated`: a POST with two or more override values is rejected.
- `override_destination_listed`: a rewrite produces only a method on the configured allowlist.
- `override_never_safe_destination`: a rewrite never produces GET or HEAD.
- `override_never_safe_name`: a rewrite never produces a method named GET, HEAD, OPTIONS, CONNECT or TRACE, so an extension method cannot stand in for one by spelling.
- `override_allowlist_unsafe`: a configured allowlist never contains GET or HEAD.

## Trailing slash

The trailing-slash middleware redirects GET and HEAD requests to the path with
the slash trimmed or appended. Its laws rule out open redirects. See
[web middleware](../web-middleware.md).

- `trailing_target_spec`: the redirect target equals the specification: only GET and HEAD move; trim removes a final `/`, append adds one; the raw query is kept; a target is offered only when it is a same-origin path.
- `trailing_redirect_same_origin`: every redirect target is a same-origin path: one leading `/`, never `//`, and no character a browser strips or reads as `/`.
- `trailing_redirect_reads_only`: only GET and HEAD are redirected.
- `trailing_trim_keeps_root`: `/` is never trimmed.
- `trailing_trim_target`, `trailing_append_target`: trimming `base/` targets `base`, and appending to a path without a final slash targets the path plus `/`, each with the raw query unchanged, whenever that target is a same-origin path.

## IP restriction and client address

IP rules allow or deny CIDR ranges, and the client address comes from the
socket peer unless the peer is a trusted proxy. These laws make membership
mean "the first prefix bits agree", make deny win, and make forwarded headers
count only behind trusted proxies. See
[connection info, IP restriction and rate limiting](../connection.md).

- `ip_member_bits`: an address in a range agrees with the network on every bit below the prefix length.
- `ip_member_family`, `ip_member_width`: a member has the network's family, both are full width, and the prefix length fits the family.
- `ip_member_complete`: conversely, a full-width address of the network's family whose first prefix bits agree with the network is a member.
- `ip_permitted_spec`: an address is permitted exactly when no deny range contains it and the allow list is empty or contains it.
- `ip_deny_wins`: an address inside any deny range is refused, whatever allows it.
- `ip_allow_listed`: an address outside every deny range and inside some allow range is admitted.
- `ip_unknown_denied`, `ip_unknown_not_allowed`: when the address is unknown, any configured deny range or allow range refuses the request.
- `client_default_peer`: with no trusted proxies, the client address is the socket peer, whatever `X-Forwarded-For` says.
- `client_untrusted_peer`: a peer outside the trusted ranges is the client, whatever it forwards.
- `client_trusted_chain`: behind a trusted peer, the `X-Forwarded-For` entries are scanned from the nearest hop outward, starting from the peer.
- `chain_skips_trusted`: a trusted hop is skipped and becomes the fallback.
- `chain_first_untrusted`: the first address outside the trusted ranges is the client.
- `chain_malformed_stops`, `chain_exhausted`: a malformed entry, or running out of entries, stops the scan at the last trusted hop.
- `conn_entries_spec`: every `X-Forwarded-For` field splits at each comma, empty entries included, and each entry loses only its surrounding spaces and tabs, keeping field and entry order.

## Rate limiting

The pure step functions behind the fixed-window and token-bucket limiters.
The store and clock are IO and are tested separately. See
[connection info, IP restriction and rate limiting](../connection.md).

- `rate_fixed_allow`, `rate_fixed_deny`: in the counter's window (or an earlier one that reached the store late) a request is allowed exactly when fewer than `limit` were counted; an allowed request is counted and a denied one is not.
- `rate_fixed_new_window`: with a positive limit, a request in a later window is allowed and starts a fresh count of one.
- `rate_fixed_zero_limit`: a zero limit refuses every request.
- `rate_fixed_quota`: for any run of requests inside one window, the first `limit - count` are allowed and every later one is denied. From an empty counter with limit 100, the 101st request is the first refused.
- `rate_bucket_capacity`: the bucket level never exceeds its full level, for every input, even a stored level above it.
- `rate_bucket_allow`, `rate_bucket_deny`, `rate_bucket_conserve`: with at least one token after refilling, a request is allowed and takes exactly one token; otherwise it is denied and takes nothing.
- `rate_full_level`: the full level is the capacity times the refill interval, because the bucket counts in token-milliseconds.

## Proxy

- `proxy_forward_spec`: the forwarded header list is exactly the clean fields of the original, unchanged and in order: nothing clean is dropped, added or reordered. See [proxy requests](../proxy.md).
- `proxy_forward_clean`: no forwarded field is hop-by-hop or named by a `Connection` option of the original message.

The upstream host laws compare `Upstream.read_authority` with `proof/upstream-host-spec.bend`, which splits the authority at every `]` or `:` and states labels, ports and embedded IPv4 in its own terms, where the parser cuts at the first separator. It reuses BND-85's origin specification for IPv6 form and the name grammar. See [the upstream URL](../proxy.md#options).

- `proxy_upstream_authority_spec`: every authority string yields the same acceptance, host kind, host text and optional port digits as the specification.
- `proxy_upstream_host_round_trip`: serializing a parsed endpoint as the `Host` value and parsing that again gives back exactly the same endpoint.
- `proxy_upstream_ipv6_url`, `proxy_upstream_name_url`: `http://[::1]:8080/api/` dials `::1` port 8080 with `Host: [::1]:8080` and base `/api`, and `HTTP://Api.Internal` dials `api.internal` port 80 with no base.
- `proxy_upstream_rejects_ipv4_shorthand`: `127.1`, which a resolver would read as IPv4, is refused.
- `proxy_upstream_rejects_noncanonical_ipv6`: `[0::1]` is refused, because RFC 5952 writes it `[::1]`.
- `proxy_upstream_rejects_ipv4_mapped`, `proxy_upstream_rejects_ipv4_compatible`: `[::ffff:c000:201]` and `[::c000:201]`, which carry the IPv4 address 192.0.2.1, are refused.
- `proxy_upstream_rejects_empty_label`, `proxy_upstream_rejects_trailing_dot`: `a..b` and `a.example.` are refused for their empty label.
- `proxy_upstream_rejects_hyphen_edge`, `proxy_upstream_rejects_trailing_hyphen`: `-a.example` and `a-.example` are refused, because a label may not start or end with `-`.
- `proxy_upstream_rejects_port_zero`: `a.example:0` is refused.
- `proxy_upstream_keeps_port_digits`: `a.example:080` is accepted and keeps the port digits `080` as written.
