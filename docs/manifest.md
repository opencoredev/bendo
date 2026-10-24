# Route manifest

Run a compiled app with `--bendo-routes` to print its route registrations as JSON.
The app exits with status 0 before reading `PORT` or opening a listening socket.
For example:

```sh
bend examples/hello/main.bend -o /tmp/bendo-hello
/tmp/bendo-hello --bendo-routes | jq .
```

The version 1 envelope is:

```json
{
  "bendo": 1,
  "routes": [{ "method": "GET", "path": "/*", "params": ["*"] }]
}
```

`bendo` is the manifest format version, independent of the package version.
`routes` is an array in registration order. Each explicitly registered method
produces an entry with its canonical case-sensitive HTTP token and the full assembled path
pattern, including constraints such as `/todos/:id{int}`. Multiple methods on
one registration produce adjacent entries in the method list's order. Duplicate
registrations remain visible. Implicit HEAD fallback is not an extra registration.
`B.all` emits one row with `"method": "ALL"` and `"all": true`; an extension
method literally named `ALL` has no `all` flag. An empty app exports `routes: []`.

Consumers must check `bendo`, accept unknown object fields and preserve route
order. `params` lists compiled capture names in segment order, including optional
captures, spans and terminal wildcards. Interior and prefix wildcards have no names.
See [composition](router-compose.md) for base paths, mounting and `B.show_routes`.
BND-56 consumes this envelope for TypeScript generation. Additive fields keep version 1;
a change to existing field meanings requires a new version.

## Route schemas

Apps that pass route schemas (BND-37) get an additive `schemas` member on each
row whose registration sets one. It holds a JSON Schema 2020-12 document per
slot: `params`, `query`, `headers`, `body` and `response`, in that order, and
only the slots the route sets. Rows without schemas print exactly as above.

```json
{
  "method": "GET",
  "path": "/todos/:id{int}",
  "params": ["id"],
  "schemas": {
    "params": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": { "id": { "type": "integer", "minimum": 1 } },
      "required": ["id"],
      "additionalProperties": false
    },
    "response": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": { "id": { "type": "integer" }, "done": { "type": "boolean" } },
      "required": ["id", "done"],
      "additionalProperties": false
    }
  }
}
```

[JSON Schema export](data/json-schema.md) describes each document and its
[decoder policy and validator differences](data/json-schema.md#decoder-policy-and-validator-differences). The `params`, `query` and `headers`
schemas describe the values after text coercion
([Coercion](data/schema.md#coercion-for-text-sources)); they do not describe
raw strings.

Import `src/serve-schemas.bend` beside `src/main.bend` and pass one
`BS.RouteSchemas()` per route registration, in registration order. Only apps
that import it compile the schema exporter; `B.serve` and the plain manifest
are unchanged.

```python
import ../../src/main.bend as B
import ../../src/serve-schemas.bend as BS

def schemas() -> List<&2, BS.RouteSchemas()>:
  [
    BS.route_schemas(None{}, Some{list_query()}, None{}, None{}, Some{todo_list()}),  # GET /todos
    BS.route_schemas(Some{id_params()}, None{}, None{}, None{}, Some{todo()}),       # GET /todos/:id{int}
    BS.no_schemas(),                                                                # GET /health
  ]

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}: BS.serve_schemas(~Tag, ~Unit, ~dispatch, table, schemas(), Unit{}, B.config())
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
```

`BS.route_schemas(params, query, headers, body, response)` takes a
`Maybe<&2, Schema.Schema>` per slot. `BS.serve_schemas`,
`BS.serve_schemas_with` (with middleware) and `BS.serve_schemas_limits_with`
take the list after the route table and otherwise behave like `B.serve`,
`B.serve_with` and `B.serve_limits_with`. `BS.routes_json(Tag, table, schemas)`
returns the manifest text without running a server.

Schemas are positional. Entry *i* belongs to the *i*-th registration in the
route table, after groups, mounts and plugins have assembled it: the order the
manifest lists. Each method row of one registration (`B.on` with two
methods, for example) carries that registration's schemas. Duplicate
registrations each keep their own entry.

`--bendo-routes` fails before printing anything, writes the reason to stderr,
and exits 1 when:

- the list has a different length from the registrations:
  `bendo: route schemas: 8 route registrations but 7 schema entries`;
- a slot holds an invalid schema, so the decoder would reject every input:
  `bendo: route schemas: route 2 has an invalid body schema` (routes count
  from 0);
- a schema is nested too deep for the JSON writer's 512-level limit.

Starting the server does not check the list. Schemas are not validated at
request time yet; that is BND-36.

### Slot interface for BND-36

`src/app/route-schemas.bend` owns the slot type, so route validation and the
manifest read the same data:

```python
type RouteSchemas is Data:
  RouteSchemas{params: Maybe<&2, S.Schema>, query: Maybe<&2, S.Schema>, headers: Maybe<&2, S.Schema>, body: Maybe<&2, S.Schema>, response: Maybe<&2, S.Schema>}
```

The list is indexed by forward registration ordinal. `RouteSlot.identity`
returns the reversed ordinal `count - 1 - index`, so BND-36 converts once at
the runtime boundary before indexing. `ManifestSchemas.attach(Tag, table, schemas)`
in `src/app/manifest-schemas.bend`
returns `Done{List<Attached>}` with `Attached{route, row, schemas}`, or the
`AttachError` above. BND-36 may check the same result at startup. If BND-36
moves schemas into the table or `GuardOptions.schemas` (today the closed slot
`Table.NoSchemas{}`), it should keep `RouteSchemas` as the per-route value and
feed `ManifestSchemas.attach` the same positional list, so the laws below keep
covering the manifest.

### Guarantees

`LAWS.bend` states three laws about attachment:

- `manifest_schema_rows`: a successful attachment's rows equal the
  specification's version-1 rows (the rows `manifest_exact_routes` already
  fixes), so schemas never add, drop or reorder a row.
- `manifest_schema_positions`: the schemas on those rows are entry *i*
  repeated once per row of registration *i*.
- `manifest_schema_accepted`: attachment succeeds exactly when there is one
  entry per registration and every set slot holds a valid schema.

`tests/json-schema-manifest.test.ts` builds `tests/fixtures/json-schema/app.bend`,
runs it with `--bendo-routes`, checks the rows, positions and failures, compiles
every slot with Ajv, and compares one document with the `.mjs` exporter's.

### The CLI parser

`parseManifest` in `packages/bendo/src/manifest.ts` returns routes with
`method`, `path`, `params`, `all` and `schemas`. `params` defaults to `[]`,
`all` to `false` and `schemas` to `{}`. Each slot must be a JSON object or
boolean. Unknown slots and fields are ignored, so later additive versions
still parse. When `--bendo-routes` exits non-zero, `fetchManifest` includes
the app's stderr in its error.

The exporter currently uses a local
writer that escapes quotation marks, backslashes and every JSON control character.
Its source has a TODO to adopt BND-28's shared writer.

## Public entrypoints

Import `src/main.bend as B`. The closed dispatcher has the signature
`dispatch(tag: Tag, ctx: B.Ctx, env: Env) -> IO(B.Res)`, where `Tag` and `Env`
are app-owned `Data` types. Startup state travels in `env`.

- `B.routes(Tag, registrations)` returns
  `Result<&2, &2, Methods.BuildError, B.Routes(Tag)>`. It validates registrations
  atomically and retains their source strings beside a proof-carrying
  `Methods.Valid<Tag>`. `B.Routes(Tag)` wraps those registrations and the validated
  table; `B.handle` and `B.serve` accept that same value. The manifest reads methods
  through `Methods.raw(Tag, valid)`, so canonical method names match dispatch.
- `B.handle(~Tag, ~Env, ~dispatch, table, env, req, body)` returns `IO(B.Res)`
  without opening a socket. Matching and response framing are pure; dispatcher IO
  still runs. `req` is `B.Req`; `body` is a list of octets. The returned response
  includes normalized framing headers and an empty body for HEAD, while preserving
  the GET representation's content length. Invalid dispatcher responses become 500.
- `B.serve(~Tag, ~Env, ~dispatch, table, env, config)` returns `IO(Unit)`, checks
  the manifest flag, then serves the same handler over TCP.
- `B.config()` returns the documented defaults in
  [`src/app/config.bend`](../src/app/config.bend). To customize fields, import that
  module and construct its `Config` record. `host` is an IPv4 literal. A valid
  decimal `PORT` between 1 and 65535 overrides `config.port`; missing, malformed,
  zero or out-of-range values use the configured port.

`B.Ctx` aliases `src/app/context.bend`'s `Ctx<Unit>`. Use the
[context accessors and helpers](context.md) to read requests, build responses,
and derive typed per-request variables.

`B` also exposes `Req`, `Res`, `ServerConfig`, `RouterKind`, `spec`, `trie`,
`text`, `body`, `not_modified`, `get`, `head`, `post`, `put`, `patch`, `delete`,
`options`, `all` and `on`. `spec()` and `trie()` construct router-kind values.
`B.config()` defaults `router` to `trie()`, and `B.serve` resolves methods with
the configured kind. `B.handle` uses the trie. Both kinds return identical
results ([trie router](router-trie.md#equivalence-proof)). Header limits, idle/head/body timeouts, max requests and keep-alive
are enforced by the connection loop. HTTP/1.1 connections persist by default;
HTTP/1.0 connections always close, including requests for keep-alive. See
[connection policy](decisions/0009-connections.md) for deadlines and close rules.

The legacy byte-handler `Serve.serve` and two-field `Serve.Config` remain available
for existing low-level consumers. New applications use `B.serve` and `B.config`.
