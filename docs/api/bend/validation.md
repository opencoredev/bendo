# Validation and JSON

A route can declare a schema for its params, query, headers, JSON body and
response. Bendo checks the request slots before the handler runs and hands the
handler the decoded values. Serve such an app with `V.serve` from
`bendo/validated.bend`; the `B.` entrypoints refuse a table that declares any
schema. [Route validation](../../validation.md) covers when validation runs and
what a rejection looks like, [Schemas](../../data/schema.md) the schema
language, and [JSON values](../../data/json.md) the JSON module.

Examples on this page are one Bend program and share this setup:

```bend
import Base
import ./bendo/main.bend as B
import ./bendo/router/methods.bend as Methods
import ./bendo/data/schema.bend as S
import ./bendo/data/json.bend as J

type Route is Data:
  ListTodos{}
  CreateTodo{}
  ShowTodo{}
  DeleteTodo{}

def title() -> S.Schema:
  S.StringSchema{1n, Some{120n}, None{}, S.Plain{}}

def todo_input() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"title", title(), S.Required{}},
    S.Field{"done", S.BooleanSchema{}, S.Default{J.JBool{False{}}}}
  ], S.Strict{}}

def page_query() -> S.Schema:
  S.ObjectSchema{[S.Field{"page", S.IntegerSchema{Some{"1"}, None{}}, S.Default{J.JNumber{"1"}}}], S.Strip{}}

def id_params() -> S.Schema:
  S.ObjectSchema{[S.Field{"id", S.IntegerSchema{Some{"1"}, None{}}, S.Required{}}], S.Strict{}}
```

## Types

### `B.Schema`, `B.Value`

```bend signature
def Schema() -> Data
def Value() -> Data
```

`B.Schema` is `S.Schema`, a description of a JSON shape, and `B.Value` is
`S.Value`, what a schema decodes to. Construct and match both through `S`,
since `main.bend` names only the types.

```bend
def ex_schema_alias(s: B.Schema) -> S.Schema:
  s

def ex_value_alias(v: S.Value) -> B.Value:
  v
```

### `B.SchemaSlot`, `B.Schemas`

```bend signature
def SchemaSlot() -> Data
def Schemas() -> Data
```

A `B.SchemaSlot` is one prepared schema bound to one slot: params, query,
headers, body or response. `B.Schemas` is the set a route validates with, at
most one schema per slot. Both are opaque; build them with the slot builders
and `B.schemas`.

```bend
def ex_body_slot() -> B.SchemaSlot:
  B.body_schema(todo_input())

def ex_no_schemas() -> B.Schemas:
  B.schemas([])
```

## Declare route schemas

### `B.params_schema`, `B.query_schema`, `B.headers_schema`, `B.body_schema`, `B.response_schema`

```bend signature
def params_schema(schema: B.Schema) -> B.SchemaSlot
def query_schema(schema: B.Schema) -> B.SchemaSlot
def headers_schema(schema: B.Schema) -> B.SchemaSlot
def body_schema(schema: B.Schema) -> B.SchemaSlot
def response_schema(schema: B.Schema) -> B.SchemaSlot
```

Binds `schema` to a slot and prepares it once, when the route list is built:
the schema is checked and its patterns compiled, so requests only decode. An
invalid schema fails every check with one `invalid_schema` error. Params,
query and headers coerce their text; headers arrive with lowercased names, so
declare lowercase keys. The body must have a JSON media type and is never
coerced. The response schema checks 2xx responses other than 204.

```bend
def ex_slots() -> List<&2, B.SchemaSlot>:
  [B.params_schema(id_params()),
   B.query_schema(page_query()),
   B.headers_schema(S.ObjectSchema{[S.Field{"x-api-key", S.StringSchema{1n, None{}, None{}, S.Plain{}}, S.Required{}}], S.Strip{}}),
   B.body_schema(todo_input()),
   B.response_schema(S.ObjectSchema{[S.Field{"id", S.IntegerSchema{Some{"1"}, None{}}, S.Required{}}], S.Strip{}})]
```

### `B.schemas`

```bend signature
def schemas(slots: List<&2, B.SchemaSlot>) -> B.Schemas
```

Collects slots into a set. A later slot of the same kind replaces an earlier
one.

```bend
def ex_create_schemas() -> B.Schemas:
  B.schemas([B.body_schema(todo_input()), B.response_schema(todo_input())])
```

### `B.with_schemas`

```bend signature
def with_schemas(-Tag: Data, entry: B.Registration(Tag), schemas: B.Schemas) -> B.Registration(Tag)
```

Attaches `schemas` to a route entry, such as one from `B.get` or `B.post`. Any
other entry, like `B.use`, is returned unchanged. The schemas travel with the
route through groups, guards, mounts and plugins.

```bend
def ex_routes() -> List<&2, B.Registration(Route)>:
  [B.with_schemas(Route, B.get(Route, "/todos", ListTodos{}), B.schemas([B.query_schema(page_query())])),
   B.with_schemas(Route, B.post(Route, "/todos", CreateTodo{}), B.schemas([B.body_schema(todo_input())]))]
```

### `B.route_schemas`

```bend signature
def route_schemas(-Tag: Data, registration: Methods.Registration(Tag), hooks: List<&2, B.Hook(Tag)>, schemas: B.Schemas) -> B.Registration(Tag)
```

One route with its own scoped hooks and schemas. `registration` comes from the
method router, `Methods.get(Tag, path, tag)` and its siblings, rather than
`B.get`. Validation runs after the route's transform hooks and before its
`before_handle` hooks.

```bend
def ex_create_route() -> B.Registration(Route):
  B.route_schemas(Route, Methods.post(Route, "/todos", CreateTodo{}), [], B.schemas([B.body_schema(todo_input())]))
```

### `B.guard_schemas`

```bend signature
def guard_schemas(-Tag: Data, hooks: List<&2, B.Hook(Tag)>, schemas: B.Schemas) -> B.GuardOptions(Tag)
```

Guard options that apply `hooks` and `schemas` to every route passed to
`B.guard`. When a route inside declares the same slot, its own schema wins for
that slot; the other slots are still inherited.

```bend
def ex_by_id() -> List<&2, B.Registration(Route)>:
  B.guard(Route, B.guard_schemas(Route, [], B.schemas([B.params_schema(id_params())])), [
    B.get(Route, "/todos/:id", ShowTodo{}),
    B.delete(Route, "/todos/:id", DeleteTodo{})])
```

## Read validated values

### `B.valid_params`, `B.valid_query`, `B.valid_headers`, `B.valid_body`

```bend signature
def valid_params(c: B.Ctx) -> Maybe<&2, B.Value>
def valid_query(c: B.Ctx) -> Maybe<&2, B.Value>
def valid_headers(c: B.Ctx) -> Maybe<&2, B.Value>
def valid_body(c: B.Ctx) -> Maybe<&2, B.Value>
```

The slot's decoded value, with defaults filled in, or `None{}` when the route
declares no schema for that slot. A handler only runs once every declared slot
has decoded, so nothing needs parsing again.

```bend
def ex_digits(v: Maybe<&2, B.Value>) -> String:
  match v:
    case Some{S.VInteger{text}}: text
    case _: "?"

def ex_title(v: Maybe<&2, B.Value>) -> String:
  match v:
    case Some{S.VString{text}}: text
    case _: ""

def ex_describe(+c: B.Ctx) -> B.Res:
  id = ex_digits(B.field(B.valid_params(c), "id"))
  page = ex_digits(B.field(B.valid_query(c), "page"))
  key = ex_title(B.field(B.valid_headers(c), "x-api-key"))
  B.text(c, id ++ " " ++ page ++ " " ++ key ++ " " ++ ex_title(B.field(B.valid_body(c), "title")))
```

### `B.valid_params_in`, `B.valid_query_in`, `B.valid_headers_in`, `B.valid_body_in`

```bend signature
def valid_params_in(-Vars: Data, c: B.Context(Vars)) -> Maybe<&2, B.Value>
def valid_query_in(-Vars: Data, c: B.Context(Vars)) -> Maybe<&2, B.Value>
def valid_headers_in(-Vars: Data, c: B.Context(Vars)) -> Maybe<&2, B.Value>
def valid_body_in(-Vars: Data, c: B.Context(Vars)) -> Maybe<&2, B.Value>
```

The same values for a context with [typed variables](context.md#typed-variables).

```bend
type ExVars is Data:
  ExVars{user: String}

def ex_typed(+c: B.Context(ExVars)) -> String:
  p = ex_digits(B.field(B.valid_params_in(ExVars, c), "id"))
  q = ex_digits(B.field(B.valid_query_in(ExVars, c), "page"))
  h = ex_title(B.field(B.valid_headers_in(ExVars, c), "x-api-key"))
  p ++ q ++ h ++ ex_title(B.field(B.valid_body_in(ExVars, c), "title"))
```

### `B.field`

```bend signature
def field(value: Maybe<&2, B.Value>, key: String) -> Maybe<&2, B.Value>
```

The field `key` of a decoded object. It is `None{}` when `value` is `None{}` or
not an object, when the schema declares no such key, and when an optional key
was absent.

```bend
def ex_done(v: Maybe<&2, B.Value>) -> Bool:
  match v:
    case Some{S.VBool{flag}}: flag
    case _: False{}

def ex_is_done(c: B.Ctx) -> Bool:
  ex_done(B.field(B.valid_body(c), "done"))
```

## Schemas

`bendo/data/schema.bend`, imported as `S`, describes JSON shapes as copyable
data and decodes them. The decoder is pure, so the same code runs on the server
and, compiled to JavaScript, in the browser.

### `S.Schema`

```bend signature
type Schema is Data:
  StringSchema{min_len: Nat, max_len: Maybe<&2, Nat>, pattern: Maybe<&2, Pattern>, format: S.Format}
  NumberSchema{min: Maybe<&2, String>, max: Maybe<&2, String>}
  IntegerSchema{min: Maybe<&2, String>, max: Maybe<&2, String>}
  BooleanSchema{}
  LiteralSchema{value: J.Json}
  EnumSchema{values: List<&2, J.Json>}
  ArraySchema{items: S.Schema, min_items: Nat, max_items: Maybe<&2, Nat>}
  ObjectSchema{fields: List<&2, S.Field>, unknown: S.Unknown}
  NullableSchema{inner: S.Schema}
  UnionSchema{members: List<&2, S.Schema>}
```

All bounds are inclusive and `None{}` means no bound. String lengths count
Unicode scalar values. Number and integer bounds are JSON number spellings
compared exactly, never as floats; an integer must be written without a
fraction or exponent. A `pattern` comes from `bendo/data/schema-pattern.bend`
and matches the whole string. Literal and enum values must be scalars. A union
takes the first member that accepts. See
[compound schemas](../../data/schema.md#compound-schemas).

```bend
def ex_tags() -> S.Schema:
  S.ArraySchema{S.EnumSchema{[J.JString{"home"}, J.JString{"work"}]}, 0n, Some{5n}}

def ex_due() -> S.Schema:
  S.NullableSchema{S.StringSchema{10n, Some{10n}, None{}, S.Plain{}}}
```

### `S.Field`, `S.Presence`

```bend signature
type Field is Data:
  Field{key: String, schema: S.Schema, presence: S.Presence}

type Presence is Data:
  Required{}
  Optional{}
  Default{value: J.Json}
```

One declared key of an `ObjectSchema`. `Required{}` keys must appear once and
`Optional{}` keys at most once. A `Default{v}` key may be absent and then
decodes as `v`, which must satisfy the field's schema or the whole schema is
invalid. A key that appears twice is rejected. Use `NullableSchema` for "may be
null".

```bend
def ex_limit() -> S.Field:
  S.Field{"limit", S.IntegerSchema{Some{"1"}, Some{"100"}}, S.Default{J.JNumber{"10"}}}

def ex_optional() -> S.Presence:
  S.Optional{}

def ex_note() -> S.Field:
  S.Field{"note", S.StringSchema{0n, None{}, None{}, S.Plain{}}, ex_optional()}
```

### `S.Unknown`

```bend signature
type Unknown is Data:
  Strict{}
  Strip{}
```

What an object does with keys it does not declare: `Strict{}` rejects them and
`Strip{}` drops them from the value. Header schemas usually want `Strip{}`,
since every request header is part of the slot.

```bend
def ex_loose_keys() -> S.Unknown:
  S.Strip{}

def ex_loose() -> S.Schema:
  S.ObjectSchema{[ex_limit(), ex_note()], ex_loose_keys()}
```

### `S.Format`

```bend signature
type Format is Data:
  Plain{}
  Email{}
  Url{}
```

An extra check on a `StringSchema`. `Plain{}` adds none. `Email{}` and `Url{}`
accept conservative syntactic subsets, described in
[formats](../../data/schema.md#formats); neither does a DNS or deliverability
check.

```bend
def ex_email_format() -> S.Format:
  S.Email{}

def ex_email() -> S.Schema:
  S.StringSchema{3n, Some{254n}, None{}, ex_email_format()}

def ex_homepage() -> S.Schema:
  S.StringSchema{0n, Some{2048n}, None{}, S.Url{}}
```

### `S.Value`

```bend signature
type Value is Data:
  VString{value: String}
  VNumber{value: String}
  VInteger{value: String}
  VBool{value: Bool}
  VLiteral{value: J.Json}
  VNull{}
  VArray{items: List<&2, S.Value>}
  VObject{fields: List<&2, VField>}
  VUnion{index: Nat, value: S.Value}

type VField is Data:
  VField{key: String, value: Maybe<&2, S.Value>}
```

A decoded value. Numbers and integers keep their input spelling. A literal or
enum decodes to `VLiteral` with the input. An object has one `VField` per
declared key in schema order, holding `None{}` for an absent optional key. A
union gives the zero-based index of the member that accepted.

```bend
def ex_value_text(v: S.Value) -> String:
  match v:
    case S.VString{s}: s
    case S.VInteger{digits}: digits
    case S.VBool{True{}}: "true"
    case S.VBool{False{}}: "false"
    case _: "other"
```

### `S.decode`

```bend signature
def decode(+s: S.Schema, +v: J.Json) -> Result<&2, &2, S.Errors(), S.Value>
```

Decodes `v` against `s`. On failure it lists every failing location, at most
100. An invalid schema fails with one `InvalidSchema{}` error before any input
is read. It never coerces text: route slots for params, query and headers
coerce before decoding, and a JSON body does not.

```bend
def ex_decode_title(v: J.Json) -> Result<&2, &2, S.Errors(), S.Value>:
  S.decode(title(), v)
```

### `S.Error`, `S.Errors`, `S.PathPart`

```bend signature
type Error is Data:
  Error{code: Code, message: String, path: List<&2, S.PathPart>}

type Code is Data:
  InvalidSchema{}
  TypeMismatch{}
  Constraint{}

def Errors() -> Data   # List<&2, S.Error>

type PathPart is Data:
  PathKey{value: String}
  PathIndex{value: Nat}
```

One decoding failure: its kind, a message, and the path from the root, through
object keys and zero-based array indexes. A route rejection sends each error as
`{"path": [...], "code": ..., "message": ...}`, with the slot name in front of
the path and the code written `invalid_schema`, `type_mismatch` or
`constraint`. See [errors](../../data/schema.md#errors).

```bend
def ex_part(p: S.PathPart) -> String:
  match p:
    case S.PathKey{key}: key
    case S.PathIndex{i}: Nat.show(i)

def ex_first_error(es: S.Errors()) -> String:
  match es:
    case Nil{}: "no errors"
    case S.Error{code, message, path} <> rest: message
```

## JSON

`bendo/data/json.bend`, imported as `J`, parses and writes RFC 8259 JSON as a
copyable value tree.

### `J.Json`, `J.Field`

```bend signature
type Json is Data:
  JNull{}
  JBool{value: Bool}
  JNumber{value: String}
  JString{value: String}
  JArray{items: List<&2, J.Json>}
  JObject{fields: List<&2, J.Field>}

type Field is Data:
  Field{key: String, value: J.Json}
```

A JSON value. A number keeps its exact decimal spelling, with no precision
limit. An object keeps every member in order, duplicates included;
`J.lookup(fields, key)` returns the first one. Respond with one through
`B.json`.

```bend
def ex_point() -> J.Json:
  J.JObject{[J.Field{"x", J.JNumber{"1.50"}}, J.Field{"tags", J.JArray{[J.JString{"a"}, J.JNull{}]}}]}
```

### `J.Error`

```bend signature
type Error is Data:
  Syntax{}
  InvalidUtf8{}
  DepthLimit{}
  InvalidValue{}
  FuelExhausted{}
```

Why parsing or writing failed. `Syntax{}` is malformed JSON, `InvalidUtf8{}`
malformed body bytes, and `DepthLimit{}` more than 512 open arrays and objects.
`InvalidValue{}` is the writer refusing a constructed value, such as a
`JNumber` that is not a JSON number. `FuelExhausted{}` is an internal limit,
not a size limit. Errors carry no position.

```bend
def ex_json_error(e: J.Error) -> String:
  match e:
    case J.Syntax{}: "malformed JSON"
    case J.DepthLimit{}: "nested too deeply"
    case _: "invalid JSON"
```

### `J.parse_string`

```bend signature
def parse_string(+s: String) -> Result<&2, &2, J.Error, J.Json>
```

Parses an already decoded string. Only space, tab, LF and CR are whitespace,
and a byte order mark is refused. For request body bytes use
`J.parse(body)`, which decodes strict UTF-8 first.

```bend
def ex_parse_title(text: String) -> Result<&2, &2, J.Error, J.Json>:
  J.parse_string(text)
```

### `J.stringify`

```bend signature
def stringify(v: J.Json) -> Result<&2, &2, J.Error, String>
```

Writes compact UTF-8 JSON. It fails with `InvalidValue{}` for a value with an
invalid number spelling, a non-scalar character in a string or key, or more
than 512 nested containers. Numbers are written as stored and duplicate keys
are kept.

```bend
def ex_compact() -> Result<&2, &2, J.Error, String>:
  J.stringify(ex_point())
```
