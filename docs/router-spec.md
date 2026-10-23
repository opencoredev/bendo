# Spec router

Use `src/router/spec.bend` to select the first matching route in registration
order. This linear router defines the behavior that faster routers must preserve.
It matches paths only; methods, HEAD fallback and 404/405 responses belong to the
layer above it.

`Route<T>` stores a compiled `Pattern` and an app-owned `Data` tag. `Table(T)` is
`List<&2, Route<T>>`. `route(T, table, path)` returns
`Maybe<&2, Match<T>>`, where `Match{index, tag, params}` contains the zero-based
registration index, selected tag and decoded ordered params. `None` means no
pattern matches. Pass the raw path without a query string or fragment.

Build a table once with `build_table(T, registrations)`. Each
`Registration<T>{source, tag}` supplies a pattern string and its tag. The result
is `Result<&2, &2, BuildError, Table(T)>`. Construction compiles patterns in
registration order and stops at the first error. It returns
`BuildError{index, source, error}`, where `error` is the original `PatternError`.
Failure rejects the entire table; it never drops invalid entries or renumbers
later registrations. Successful construction preserves every tag and position.

Tags can be a closed app-owned sum type. Dispatch the returned tag to a top-level
handler, and pass `params` into the request context. The table never stores
handler functions. See the complete native consumer in
[`tests/servers/router-spec.bend`](../tests/servers/router-spec.bend), which builds
its table at startup and copies it into each connection.

Registration order takes precedence over specificity. Registering `/users/:name`
before `/users/new` selects the parameter route for `/users/new`. A failed
constraint tries the next route. Decode behavior and pattern syntax are defined
in [Route patterns](router-patterns.md).

Indexes are positions in the original table. Keep this table in registration
order when attaching metadata or compiling another search structure. A match
from a faster router must retain that original index.

Run the native HTTP and construction checks with:

```sh
bun test --timeout 30000 tests/router-spec.test.ts
bun run prove
```

The `# BND-15` block in `LAWS.bend` states five universal guarantees:
`router_sound` checks the selected entry and every earlier miss;
`router_complete` guarantees a winner whenever an entry matches;
`router_first_match` returns the exact first matching entry;
`router_priority` excludes a later matching route when an earlier one matches;
and `router_fill_match` guarantees that every admissible assignment for a
compiled entry fills to a routed path, with a winner no later than that entry.
If no earlier route matches the filled path, the selected tag, index and params
are exactly those of that entry. The fill guarantee reuses `pattern_fill_match`.

For per-method registration, HEAD fallback, 404/405, and slash/case options,
use the [method-aware router](router-methods.md).
