# Compose route lists

Use `B.route(Tag, prefix, sub)` to mount a reusable sub-app registration list.
`B.base_path(Tag, prefix, entries)` has the same behavior. Build the final table
once with `B.routes`. Sub-apps share the parent's `Tag`, context variables,
environment and closed handler/middleware dispatchers. They do not store functions
or start separate servers.

```python
import Base
import ../src/main.bend as B

type Tag is Data:
  ListItems{}
  GetItem{}

def items() -> List<&2, B.Registration(Tag)>:
  [B.get(Tag, "/", ListItems{}), B.get(Tag, "/:id{int}", GetItem{})]

def entries() -> List<&2, B.Registration(Tag)>:
  List.concat(&2, B.Registration(Tag), [
    B.route(Tag, "/api/v1/items", items()),
    B.group(Tag, "/admin", [], B.group(Tag, "/v1", [],
      B.group(Tag, "/items", [], items())))])
```

The first mount answers `GET /api/v1/items/` and `GET /api/v1/items/42`.
It does not register `/items/42` or `/api/v1/itemsx/42`. The nested groups
register `/admin/v1/items/` and `/admin/v1/items/:id{int}`. Groups use the
existing [scoped hook API](decisions/0011-hook-scopes.md): the third argument
is a hook list, which may be empty. There is no second grouping mechanism.

## Joining and validation

Empty and `/` prefixes are identities. For any other prefix, composition removes
one trailing `/` before appending the member path. A member `/` therefore becomes
`/api/` under `/api`; `/api` is a different path. Repeated slashes inside a prefix
or member remain meaningful. Bare `*` members are expanded to `/*` before joining,
so mounting them under `/api` produces `/api/*`, never the prefix wildcard `/api*`.

Prefixes may contain the [route pattern syntax](router-patterns.md), including
captures such as `/:tenant` or `/:tenant{int}`. All captures, constraints, order
and route tags survive composition. The normal pattern compiler validates each
full assembled route and middleware pattern when `B.routes` builds the table.
Duplicate capture names across a join fail. A prefix with an optional capture
followed by a required member segment fails; an anonymous wildcard can become an
interior wildcard. A terminal named wildcard or prefix wildcard cannot be followed
by another segment. Errors retain the index and source of the first invalid entry
in the flattened list. An empty sub-app emits no entries and therefore validates
no prefix. Composition itself returns data, not a validated table.

An omitted optional root needs special care: `/:id?` alone matches `/`, but
mounted under `/api` it matches `/api` and rejects `/api/` in strict mode.
Composition preserves the assembled pattern's rules, rather than rerouting by
removing a string prefix from every request.

## Hooks, middleware and errors

Mounting lowers through `group`, retaining inherited hooks, guards and local route
hooks. A route that ends up with no hooks adds no scoped record to
the built table, so a hook-free mount or group adds no per-route middleware layer
for each request to walk. Global parent hooks precede child hooks. Only the winning child route
receives its scoped hooks, including HEAD fallback to GET. A parent route with
the same URL prefix does not inherit them.

Ordinary middleware inside a mount becomes prefix-aware path middleware. A child
`use` applies under the mount prefix, including the prefix itself, 404/405 paths,
and parent routes inside that prefix. A child `use_path` gets the same prefix
as its routes. Outer groups and mounts move these middleware patterns again, so
nesting keeps them aligned. Their dispatcher sees the full request path and
captures from the winning route. Legacy ordinary `use` declared directly inside
`group` keeps its existing global/path semantics; group scopes lifecycle hooks.

The parent owns routing fallbacks: mounted `on_not_found` declarations do not
handle missing paths under the prefix. A 404 or 405 has no winning route and runs
parent global lifecycle hooks only. Mounted ordinary path middleware can still
short-circuit those requests. A child's `on_error` runs for error responses from
its selected routes, after parent error hooks, following the existing lifecycle
rule for any status of 400 or higher. This includes returned typed HTTP errors;
it does not catch native crashes or `IO.die`.

`B.route` now mounts registration lists. Code adapting a low-level
`Methods.Registration(Tag)` to one public entry uses `B.registration(Tag, entry)`.

## Inspect the built table

`B.show_routes(Tag, table)` prints a tab-separated `METHOD` and `PATH` table.
It includes explicit normalized methods in registration order, preserves duplicate
routes, and emits one `ALL` row for an all-method registration. It does not add
implicit HEAD fallback rows. The runtime and manifest read that same built table.

Run a compiled server with `--bendo-routes` to print JSON and exit before binding:

```sh
./example --bendo-routes | jq
```

The version-1 envelope stays `{ "bendo": 1, "routes": [...] }`. Each route now
also has `params`, an array of capture names in compiled segment order:

```json
{"bendo":1,"routes":[{"method":"GET","path":"/api/:tenant/items/:id{int}","params":["tenant","id"]}]}
```

Optional captures, spanning captures and terminal wildcards contribute their
names. Anonymous terminal wildcards contribute `"*"`; interior wildcards and
prefix wildcards contribute none. An `ALL` row retains `"all": true`, distinct
from an extension method literally named `ALL`. Middleware and hooks emit no
rows. Existing method/path fields retain their meaning, so version-1 readers can
ignore the additive `params` field. Future schema export (BND-37) can extend each
row with schema fields; BND-56 can consume both schemas and these param names.

The native consumer is [tests/servers/router-compose.bend](../tests/servers/router-compose.bend).
Run `bun test --timeout 30000 tests/router-compose.test.ts` for HTTP behavior,
nested groups/mounts, validation, manifest contents and `show_routes` output.

## Proven guarantees and remaining lemmas

The BND-19 laws cover three things: assembly, routing against the assembled
registrations, and segment properties. The composition laws compare complete
group/mount assembly with an independent source specification, including order,
tags, hook placements and prefix-aware middleware. They compare method routing
through either router with linear resolution over that independent assembly,
including build failures. Separate segment-level laws prove cancellation of a
literal prefix, associativity of literal prefix groups, and misses at a
differing whole segment.

Two manifest laws cover the exported rows. `manifest_exact_routes` compares them
with a separate projection of the certified table. `manifest_built_routes`
starts from the entries instead: whenever `Table.build(entries)` succeeds, the
rows equal an enumeration of every route declaration in those entries, with the
full assembled source path, methods normalized as registration normalizes them
(order and duplicates kept, one `ALL` row, no implicit HEAD) and capture names
taken from compiling that route's own source. Hooks and middleware add no rows.

The BND-86 laws prove the source-string bridge end to end, against the
independent specification in
[`proof/mount-spec.bend`](../proof/mount-spec.bend). They cover every prefix
the pattern syntax allows, including optional captures, interior wildcards,
spans and repeated slashes inside the prefix, as long as the assembled
pattern compiles and the prefix does not end in repeated slashes. For such a
mount, compiling the source that `B.route` builds and matching it under any
slash and case options gives exactly this: the prefix walks the request's
segments first, each segment by its own rule, then the member matches the
rest, prefix captures first. Under a nonroot prefix the member has no root
rule of its own; the assembled pattern keeps one, so `/:tenant?` with `/:id?`
still answers `/`. Under an empty or `/` prefix the member answers alone,
root rule included, so `/:id?` under `/` answers `/`. Method resolution over
a mounted registration list, through either router, is first-match over
those answers, with HEAD fallback, 405 and 404.

Under a literal prefix with strict trailing slashes, `prefix + /r` routes as
the member alone routes `/r`, except that an optional-capture member such as
`/:id?` answers `/api` and rejects `/api/` (the root convention above). This
suffix cancellation needs strict mode: in lenient mode `//:id?` alone answers
`/`, but mounted under `/api` it rejects `/api/`. Under every option setting a
literal mount answers nothing outside its prefix path: case-sensitive
matching needs the prefix's exact segments, and case-insensitive matching the
same segments after ASCII folding, followed by nothing or by `/`. The
[routing laws](laws/routing.md#source-string-mounting) list each statement.

Arbitrary group flattening is not an equality of entries: hook provenance records
the original inner prefixes. Even path joining is not associative for every raw
string: nesting `/a//`, an empty prefix and `/x` gives `/a//x`, while flattening
the first two prefixes and joining `/x` gives `/a/x`. The mounting laws exclude
prefixes that end in repeated slashes, since `/a//` ends with an empty prefix
segment. A route-observable
associativity theorem for normalized prefixes, preserving nested hook order,
remains unproved. Existing BND-24 laws and slash behavior are unchanged.
