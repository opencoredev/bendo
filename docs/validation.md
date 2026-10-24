# Route validation

A route can declare a [schema](data/schema.md) for each of five slots: its path
params, query string, headers, JSON body and response. Bendo checks the request
slots before the handler runs. A request that fails gets a JSON list of every
failing path, and the handler never runs. A request that passes reaches the
handler with the decoded values, so the handler does not parse anything again.

```python
import Base
import ../src/main.bend as B
import ../src/validated.bend as V
import ../src/data/schema.bend as S
import ../src/data/json.bend as J

def todo_input() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"title", S.StringSchema{1n, Some{80n}, None{}, S.Plain{}}, S.Required{}},
    S.Field{"done", S.BooleanSchema{}, S.Default{J.JBool{False{}}}}], S.Strict{}}

def page() -> S.Schema:
  S.ObjectSchema{[S.Field{"page", S.IntegerSchema{Some{"1"}, None{}}, S.Default{J.JNumber{"1"}}}], S.Strip{}}

def routes() -> List<&2, B.Registration(Tag)>:
  [B.with_schemas(Tag, B.get(Tag, "/todos", ListTodos{}), B.schemas([B.query_schema(page())])),
   B.with_schemas(Tag, B.post(Tag, "/todos", CreateTodo{}), B.schemas([B.body_schema(todo_input())]))]

def ready(result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}: V.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
```

`POST /todos` with `{"title":""}` answers 422:

```json
{"error":"Unprocessable Content","status":422,"errors":[{"path":["body","title"],"code":"constraint","message":"value does not satisfy scalar checks"}]}
```

`tests/servers/validate.bend` is a complete server with a route per slot, a
guard, a mounted sub-app and hooks around validation; `tests/validate.test.ts`
drives it over HTTP.

## Serve with validation

Serve an app that declares schemas with the entrypoints in
`src/validated.bend`: `V.serve`, `V.serve_with`, `V.serve_limits_with`,
`V.handle` and `V.handle_with` take the same arguments as their `B.` namesakes
and add validation. The `B.` entrypoints link no schema decoder, which keeps
apps without schemas small: linking the decoder adds about 0.85 MB (21%) to a
hello app's generated C and 0.5 GB to its peak compile memory. They never
ignore schemas, though: `B.serve`, `B.serve_with` and `B.serve_limits_with` exit
at startup with a
message naming `src/validated.bend` when any route declares a schema, and
`B.handle` and `B.handle_with` answer such a route's requests with a 500 whose
single error says the same, before the handler runs. That includes a route
whose only schema is a response schema.

## Declare schemas

Build each slot with `B.params_schema`, `B.query_schema`, `B.headers_schema`,
`B.body_schema` or `B.response_schema`, and collect them with
`B.schemas([...])`, which returns `B.Schemas`. A later slot of the same kind
replaces an earlier one. Then attach the set:

| Where | Call |
| --- | --- |
| One route | `B.with_schemas(Tag, B.post(Tag, "/todos", T{}), schemas)` |
| One route with hooks | `B.route_schemas(Tag, M.post(Tag, "/todos", T{}), hooks, schemas)` |
| Every route in a guard | `B.guard(Tag, B.guard_schemas(Tag, hooks, schemas), entries)` |

Schemas travel with their routes through `B.group`, `B.guard`, `B.route`,
`B.base_path` and plugins, exactly like scoped hooks. When a guard and a route
inside it both declare the same slot, the innermost declaration wins for that
slot; other slots are still inherited. For example, a guard with a query schema
and a member route with its own query schema validates that route's query only
against the route's schema.

Each slot builder prepares its schema once, when the route list is built: it
checks the schema is valid and builds the automaton table of every pattern in
it. Requests only decode. A table that fails its own check is never used; the
proven derivative matcher runs instead, as in [patterns](data/schema.md#patterns).
Law `schema_prepared_decode` states that decoding with a prepared schema equals
`Schema.decode_from` with the schema itself.

## What each slot reads

Params, query and headers carry only text, so they decode with coercion
(`decode_from(TextSource{}, ...)`, see
[coercion](data/schema.md#coercion-for-text-sources)): numbers, booleans and
repeated keys under an array field become JSON values. Each slot is an object of
string members in arrival order.

- **Params** are the matched route's percent-decoded captures, keyed by name.
- **Query** is every `key=value` pair of the query string, repeats kept, so
  `?tag=a&tag=b` under an array field gives `["a","b"]`.
- **Headers** are every request header. Names are lowercased before decoding,
  so `X-Api-Key` and `x-api-key` both match the key `"x-api-key"`. Declare header
  schema keys in lowercase, and use `Strip{}` unless you want to reject every
  header the schema does not name. A value is read as UTF-8 when it decodes,
  otherwise byte for byte as ISO-8859-1.
- **Body** needs a JSON media type: the first `Content-Type` must be
  `application/json` or `application/*+json`, in any case, with any parameters.
  Anything else, including a missing `Content-Type`, is 415. A body that is not
  well-formed JSON is 400. The parsed JSON then decodes without coercion, so
  `"done":"true"` is a type mismatch for a boolean.

## When validation runs

Validation runs after `on_request` hooks, routing, `B.use` middleware,
`on_parse` and `on_transform` hooks, and before `before_handle` hooks. A transform
hook can therefore set response headers or variables first, and a
`before_handle` hook already sees the decoded values. A rejection skips the
`before_handle` hooks and the handler. Like any response, it then passes through
`after_handle`, `map_response` and, being a 4xx, `on_error` hooks. A route that
declares no schema at all skips this stage.

## Rejections

A rejection lists the errors of every failing slot, in the order params, query,
headers, body. Within a slot the errors are exactly the
[schema error list](data/schema.md#errors), with the slot name in front of each
path, so a query error for `page` has the path `["query","page"]`. A request
reports at most 100 errors in all: the first 100 in slot order. Every slot is
still checked, so the status follows the table below even when the list is
cut before the body's errors.

| What failed | Status |
| --- | --- |
| Params, query or headers (whatever else failed) | 400 |
| Otherwise, the body's media type | 415 |
| Otherwise, the body is not well-formed JSON | 400 |
| Otherwise, the body's schema | 422 |

The body is always JSON, whatever the request's `Accept` says:
`{"error": reason, "status": code, "errors": [...]}`. The `error` and `status`
members match the body of other [HTTP errors](decisions/0011-crash.md), and each entry
of `errors` has the `path`, `code` and `message` keys of `errors_json`. A media
type or syntax failure is one `type_mismatch` error at the path `["body"]`, with
the message `expected an application/json body` or `body is not valid JSON`.
Headers already set on the context, for example by a transform hook, are kept.

## Read the decoded values

`B.valid_params(c)`, `B.valid_query(c)`, `B.valid_headers(c)` and
`B.valid_body(c)` return the slot's decoded `Maybe<&2, B.Value>`. For apps with
variables, use `B.valid_params_in(Vars, c)` and the other `_in` forms. Each
returns `None{}` when the route declares no schema for that slot.

The value is the schema decoder's `Value`: an object schema gives `VObject` with
one field per declared key in schema order, defaults filled in and undeclared
keys stripped or rejected as the schema says. `B.field(value, key)` returns one
field. A typed record reads the fields by position, as decision
[0003](decisions/0003-typed-values.md) describes.

```python
def digits(v: Maybe<&2, B.Value>) -> String:
  match v:
    case Some{S.VInteger{text}}: text
    case _: "1"

def page_number(c: B.Ctx) -> String:
  digits(B.field(B.valid_query(c), "page"))
```

## Response schemas

A response schema checks the response the client would get: after middleware
and `before_handle` hooks unwind and after `after_handle`, `map_response` and
`on_error` hooks, and before the `Date` field, request ID and transport
framing are added. So a `before_handle` hook that answers by itself, or a
`map_response` hook that replaces the handler's response, is checked like the
handler's own response. The check uses the route the request resolved to. Only
a 2xx response other than 204 is checked; it must have a JSON media type and a
body its schema decodes, without coercion. Error responses, 304s and routes
without a response schema are not checked. A streamed or upgraded response has
no buffered body, so it is never checked and is sent as it is; do not rely on a
response schema for a streaming route. A response counts as streamed or
upgraded only when the transport will actually hand it to the stream or
WebSocket the request registered, by the same test transport selection uses.
A response that merely carries the private stream marker header, or the marker
of another registration, is buffered and checked. So is a response a hook put
in place of a registered stream. Response policies that middleware such as CORS
and security headers reapply after validation cannot set, replace or remove
the marker, so they cannot move a response between streamed and buffered.

What a violation does depends on the server's mode:

- **Development** (the default) replaces the response with a 500 whose body is
  public [HTTP error](decisions/0011-crash.md) body: `Internal Server Error` as text, or
  `{"error":"Internal Server Error","status":500}` when the client accepts JSON.
  Nothing from the failed response or its errors reaches the client.
- **Production** sends the handler's response unchanged and writes one line to
  stderr:

  ```text
  bendo: response schema violation: GET /report [{"path":["body","count"],"code":"type_mismatch","message":"expected schema scalar kind"}]
  ```

  The line names the registered route pattern, such as `/reset/:token`, never
  the request path, so captured values like tokens stay out of logs.

Choose production with `V.serve(..., B.production(B.config()))`, or start the
server with `BENDO_ENV=production`, which overrides the configured mode at
startup the way `$PORT` overrides the port. `V.handle` and `V.handle_with` always
run in development mode.

## Guarantees

`proof/validate-laws.bend` states these laws for every route schema set and
every request input, against the specification in `proof/validate-spec.bend`.
The specification decodes each slot with `Schema.decode_from` and the raw schema,
so the BND-33/34/35 schema laws describe what each slot accepts and reports.

- `schema_prepared_decode`: a prepared schema decodes exactly like the schema.
- `route_validation_matches_spec`: the verdict, the decoded values, the status
  and the error list are the specification's.
- `route_admits_iff_slots_decode`: the request is admitted exactly when every
  declared slot decodes.
- `route_rejection_lists_slot_errors`: a rejection lists exactly the union of the
  slots' errors with slot-prefixed paths, and an admitted request lists none.
- `route_response_matches_spec`: which responses are checked and when one
  conforms.
- `route_rejection_within_budget`: a rejection lists at most 100 errors.
- `plain_admission_rejects_declared`: the plain entrypoints reject every route
  that declares any schema, a response schema alone included.
- `handler_entry_valid`, `handler_entry_invalid` and
  `handler_enters_iff_admitted`: a valid verdict enters the handler with exactly
  its values in the context, an invalid one answers its rejection without
  dispatch, and with the decoding validator the handler is entered exactly when
  every declared slot decodes.
- `route_response_policy`: in either mode and for either delivery, a streamed
  response is sent as is, a violating buffered response is replaced in
  development and sent with a log line in production, and every other response
  is sent.
- `transport_eligibility_matches_spec`, `route_response_delivery_matches_transport`,
  `unclaimed_response_is_buffered` and `route_response_claimed_policy`: a
  response is treated as streamed or upgraded exactly when transport hands it
  to the request's registration (its own marker, and a 101 for an upgrade); a
  marker header with no registration behind it never skips the check.
- `finalized_policies_keep_delivery`: retained response policies, applied
  after validation, leave delivery as validation saw it; if they make the
  response invalid, its replacement 500 is buffered.
- `route_schemas_innermost`, `route_schemas_guard_innermost` and
  `route_schemas_group_innermost`: for every built table, route and slot, the
  schema used is the last declaration of that slot among the route's scopes,
  outer to inner; undeclared slots keep the outer schema.
- `table_schemas_in_source_order`: the manifest's schema list is the routes in
  source order, each with the raw schemas of its effective set, slot by slot.
  `table_schemas_one_per_route` states its length.

These laws rely on the JSON parser, `Bytes.fold` and the raw query parser
that the implementation and the specification share; BND-92 tracks proving
those independently.

The lifecycle wiring is IO and is covered by `tests/validate.test.ts` instead:
it checks that the handler does not run on a rejection, that transform hooks run
before validation and `before_handle` hooks after it, both response modes,
responses produced or replaced by hooks, that only real streams and upgrades
skip the response check, the request-wide error budget, the
manifest, and that the plain entrypoints refuse schemas.

## Export the schemas

A binary served with `V.serve`, `V.serve_with` or `V.serve_limits_with` prints
its [route manifest](manifest.md#route-schemas) with every route's effective
schemas when run with `--bendo-routes`: the schemas each route validates with,
after guards, groups, mounts and plugins, as JSON Schema. The TypeScript
toolkit reads them for type generation.
