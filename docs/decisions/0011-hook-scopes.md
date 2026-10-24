# 0011: Route-attached hook scopes and guards

Date: 2026-10-23. Issue: BND-24. Status: accepted for M3.

Groups, guards and route options attach hook data to route registrations before
building the table. They use the existing middleware dispatcher and lifecycle
stages. A guard changes membership, not URL paths; a group prefixes its member
paths. Both return registration lists that can be concatenated or nested.

## Register scoped hooks

Import `src/app/table.bend` as `T` for stage constructors and
`src/router/methods.bend` as `M` for a route registration with local hooks.
`B.Hook(Tag)` is typed hook data, distinct from a global registration.

```python
# These snippets belong inside an app whose Tag defines Auth and Show.
B.group(Tag, "/api", [B.hook(Tag, T.BeforeHandle{}, Auth{})], [
  B.get(Tag, "/items", Show{})
])

B.guard(Tag, B.guard_options(Tag, [B.hook(Tag, T.BeforeHandle{}, Auth{})]), [
  B.get(Tag, "/account", Show{}),
  B.get(Tag, "/settings", Show{})
])

B.route_hooks(Tag, M.get(Tag, "/account", Show{}), [
  B.hook(Tag, T.BeforeHandle{}, Auth{})
])
```

Use `List.concat(&2, B.Registration(Tag), lists)` to combine these lists with
other registrations before calling `B.routes`. A hook declared with an existing
`B.on_*` constructor inside a group or guard list is inherited by every route
in that list, including routes declared earlier in the same list. Explicit
option hooks come before these declarations. Hooks declared at the top level
remain global, including declarations after a group or guard.

Groups prefix each member route's source pattern, including parameterized and
wildcard patterns. Empty and `/` prefixes leave paths unchanged. A non-root
prefix may end in one `/`, which is removed before concatenation. Member paths
retain their leading slash and trailing-slash semantics: grouping `/` under
`/api` produces `/api/`. The normal table builder validates the resulting
patterns and preserves first-error reporting in the flattened registration list.
A route outside a group receives none of that group's hooks, even when its
source starts with the same prefix. Ordinary `use` registrations keep their
existing global/path semantics; these helpers scope lifecycle hooks.

## Precedence and membership

Stage order remains the order in decision 0010. Within each stage, global hooks
run first, in their original registration order. Inherited group and guard hooks
follow from outermost to innermost assembly, then the route's local hooks. Group
and guard have no separate numeric priority: an outer guard precedes an inner
group, and an outer group precedes an inner guard. Every list preserves order
and duplicates. Response hooks use the same order, rather than reversing it.

Membership follows the winning route registration, not a request-path prefix
or a handler identifier. Guarding `GET /items/:id` does not guard an unrelated
`POST /items/:id`. An earlier duplicate registration wins with its own hooks.
HEAD fallback inherits the selected GET registration's hooks; an explicit HEAD
registration uses its own. A 404 or 405 has no route scope and runs global hooks
only. Parameters and wildcard matching remain the router's responsibility.

The middleware table stores each scoped route's ordinal counted from the end
of the route list. Runtime converts the router's forward index once. This
internal key distinguishes duplicate registrations without comparing app tags;
it is not a public identifier or a stable cross-build plugin key.

Request hooks use a provisional resolution of the original method and path.
Their selected chain stays fixed while they run. Once they call their terminal,
routing runs again on the rewritten context: parse, transform, before-handle
and response hooks use that actual route's scope. A request-hook short circuit
keeps the provisional scope for response stages. A later pre-stage rewrite does
not reroute or switch response scopes. A request-local slot retains the actual
route identity separately from the context snapshot, including on early returns.

## Elysia parity and extension seams

Bendo provides Elysia-style route-local and inherited group/guard hooks, plus
explicit global hooks. These are structural scopes over the assembled route
list. Elysia's plugin lifecycle propagation modes `local`, `scoped` and `global`
are not exposed as a mode switch here: plugins and named-plugin deduplication
belong to BND-26. A plugin can return these registration lists without storing
functions in the table or introducing another callback contract. The
[plugin guide](../guides/plugins.md) shows how those modes map onto where a
plugin is used.

`GuardOptions<Tag>` contains `hooks: List<&2, HookSpec<Tag>>` and
`schemas: SchemaSlot`. `B.guard_options` fills it with `NoSchemas{}`;
`B.guard_schemas` fills it with `WithSchemas{schemas}` (BND-36). A guard's
schemas become one `Checks{scope, schemas}` placement after its hook placements
on every member route, so they travel with routes exactly like inherited hooks,
and hook selection skips them. Per slot, the innermost declaration wins; see
[route validation](../validation.md). Nothing serializes the schemas in the
manifest yet (BND-37).

## Laws and verification

The BND-22 middleware laws and BND-23 global selection laws retain their exact
statements. `stage_ids` and `lifecycle` remain their global-only operations.
Runtime uses `scoped_stage_ids` and `scoped_lifecycle`; the new laws compare
these with a separate specification filtering source registrations by selected
route identity and stage. Compositional laws also compare group, guard and local
route assembly with an independent specification, so inherited membership and
ordering are checked before selection. These specifications do not call the
implementation assembly or selection helpers.

`tests/servers/hooks-scope.bend` is a native HTTP consumer. Run
`bun test --timeout 30000 tests/hooks-scope.test.ts` for scope isolation, every
guard member, same-path methods, duplicates, nested groups, local hooks,
rewrites, short circuits, HEAD fallback and routing failures. Existing hook
tests continue to cover deferred observers and the legacy stage order.
