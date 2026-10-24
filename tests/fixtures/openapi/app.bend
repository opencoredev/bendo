# BND-62 fixture: every route pattern form and schema kind, plus /openapi.json
# and /docs. openapi-doc.bend is generated from this app's own manifest:
#   bun packages/bendo/src/cli.ts openapi tests/fixtures/openapi/app.bend \
#     --config tests/fixtures/openapi/openapi.config.json \
#     --out tests/fixtures/openapi/openapi.json --bend tests/fixtures/openapi/openapi-doc.bend
# tests/openapi.test.ts fails when either file is stale.
import Base
import ../../../src/main.bend as B
import ../../../src/serve-schemas.bend as BS
import ../../../src/api-docs.bend as Docs
import ../../../src/router/methods.bend as Methods
import ../../../src/http/request.bend as Request
import ../../../src/data/schema.bend as S
import ../../../src/data/schema-pattern.bend as P
import ../../../src/data/json.bend as J
import ../../../src/app/table.bend as Table
import ./openapi-doc.bend as OpenApiDoc

type Tag is Data:
  ListTodos{}
  GetTodo{}
  CreateTodo{}
  UpdateTodo{}
  DeleteTodo{}
  First{}
  Second{}
  User{}
  Post{}
  TagName{}
  Archive{}
  Version{}
  Files{}
  Between{}
  Assets{}
  Contents{}
  Purge{}
  Status{}
  Kinds{}
  Spec{}
  Reference{}
  Offline{}
  Bare{}
  Fallback{}

def spec(c: B.Ctx) -> IO(B.Res):
  IO.pure(B.Res, Docs.openapi(c, OpenApiDoc.json()))

def reference(c: B.Ctx) -> IO(B.Res):
  IO.pure(B.Res, Docs.scalar(c, Docs.with_title(Docs.options("/openapi.json"), "Bendo <fixture> API")))

def offline(c: B.Ctx) -> IO(B.Res):
  IO.pure(B.Res, Docs.scalar(c, Docs.self_hosted(Docs.options("/openapi.json"), "/scalar/standalone.js", "")))

def bare(c: B.Ctx) -> IO(B.Res):
  IO.pure(B.Res, Docs.scalar(c, Docs.with_csp(Docs.options("/openapi.json"), "")))

def ok(c: B.Ctx) -> IO(B.Res):
  IO.pure(B.Res, B.text(c, "ok"))

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  match tag:
    case Spec{}: spec(c)
    case Reference{}: reference(c)
    case Offline{}: offline(c)
    case Bare{}: bare(c)
    case _: ok(c)

def text(min: Nat, max: Nat) -> S.Schema:
  S.StringSchema{min, Some{max}, None{}, S.Plain{}}

def id() -> S.Schema:
  S.IntegerSchema{Some{"1"}, None{}}

def word() -> P.Pattern:
  P.Repeat{P.Class{[P.Range{97, 122}, P.Range{48, 57}]}, 1n, None{}}

# [a-z0-9]+(-[a-z0-9]+)*
def slug() -> S.Schema:
  S.StringSchema{1n, Some{40n}, Some{P.seq([word(), P.Repeat{P.Cat{P.Literal{"-"}, word()}, 0n, None{}}])}, S.Plain{}}

def todo() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"id", id(), S.Required{}},
    S.Field{"title", text(1n, 80n), S.Required{}},
    S.Field{"done", S.BooleanSchema{}, S.Required{}},
    S.Field{"link", S.NullableSchema{S.StringSchema{0n, None{}, None{}, S.Url{}}}, S.Optional{}},
    S.Field{"owner", S.StringSchema{0n, None{}, None{}, S.Email{}}, S.Optional{}},
  ], S.Strict{}}

def todo_input() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"title", text(1n, 80n), S.Required{}},
    S.Field{"done", S.BooleanSchema{}, S.Default{J.JBool{False{}}}},
    S.Field{"tags", S.ArraySchema{slug(), 0n, Some{5n}}, S.Optional{}},
    S.Field{"priority", S.EnumSchema{[J.JNumber{"1"}, J.JNumber{"2"}, J.JNumber{"3"}]}, S.Default{J.JNumber{"2"}}},
  ], S.Strict{}}

def list_query() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"limit", S.IntegerSchema{Some{"1"}, Some{"100"}}, S.Default{J.JNumber{"10"}}},
    S.Field{"tag", S.ArraySchema{text(1n, 40n), 0n, None{}}, S.Optional{}},
    S.Field{"done", S.BooleanSchema{}, S.Optional{}},
  ], S.Strip{}}

def id_params() -> S.Schema:
  S.ObjectSchema{[S.Field{"id", id(), S.Required{}}], S.Strict{}}

# Authorization is listed to show that OpenAPI drops that header parameter.
def key_headers() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"x-api-key", text(1n, 128n), S.Required{}},
    S.Field{"authorization", text(1n, 512n), S.Optional{}},
  ], S.Strip{}}

def version_params() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"version", S.EnumSchema{[J.JString{"1"}, J.JString{"2"}]}, S.Optional{}},
    S.Field{"platform", text(1n, 20n), S.Optional{}},
  ], S.Strict{}}

def status() -> S.Schema:
  S.UnionSchema{[
    S.LiteralSchema{J.JString{"ok"}},
    S.NullableSchema{S.NumberSchema{Some{"0"}, Some{"1e2"}}},
    S.UnionSchema{[]},
  ]}

# One field per schema kind and string format.
def kinds() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"plain", text(0n, 10n), S.Required{}},
    S.Field{"pattern", slug(), S.Required{}},
    S.Field{"email", S.StringSchema{0n, None{}, None{}, S.Email{}}, S.Required{}},
    S.Field{"url", S.StringSchema{0n, None{}, None{}, S.Url{}}, S.Required{}},
    S.Field{"number", S.NumberSchema{Some{"-1.5"}, None{}}, S.Required{}},
    S.Field{"integer", S.IntegerSchema{None{}, Some{"9"}}, S.Required{}},
    S.Field{"boolean", S.BooleanSchema{}, S.Required{}},
    S.Field{"literal", S.LiteralSchema{J.JNull{}}, S.Required{}},
    S.Field{"enum", S.EnumSchema{[J.JString{"a"}, J.JNumber{"1"}, J.JBool{True{}}]}, S.Required{}},
    S.Field{"never", S.EnumSchema{[]}, S.Optional{}},
    S.Field{"array", S.ArraySchema{S.IntegerSchema{None{}, None{}}, 1n, Some{3n}}, S.Required{}},
    S.Field{"object", S.ObjectSchema{[S.Field{"x", S.NumberSchema{None{}, None{}}, S.Default{J.JNumber{"0"}}}], S.Strip{}}, S.Required{}},
    S.Field{"nullable", S.NullableSchema{S.BooleanSchema{}}, S.Required{}},
    S.Field{"union", status(), S.Optional{}},
  ], S.Strict{}}

def routes() -> List<&2, Table.Entry<Tag>>:
  [
    B.get(Tag, "/todos", ListTodos{}),
    B.get(Tag, "/todos/:id{int}", GetTodo{}),
    B.post(Tag, "/todos", CreateTodo{}),
    B.on(Tag, [Request.Put{}, Request.Patch{}], "/todos/:id{int}", UpdateTodo{}),
    B.delete(Tag, "/todos/:todo_id", DeleteTodo{}),
    B.get(Tag, "/dup", First{}),
    B.get(Tag, "/dup", Second{}),
    B.get(Tag, "/users/:user{uuid}", User{}),
    B.get(Tag, "/posts/:slug{slug}", Post{}),
    B.get(Tag, "/tags/:name{[a-z0-9-]+}", TagName{}),
    B.get(Tag, "/archive/:year{[0-9]{4}}/:month{int}?", Archive{}),
    B.get(Tag, "/v1/:version?/:platform?", Version{}),
    B.get(Tag, "/files/*path", Files{}),
    B.get(Tag, "/a/*/b", Between{}),
    B.get(Tag, "/assets*", Assets{}),
    B.get(Tag, "/:prefix{.+}/contents/:id?", Contents{}),
    B.on(Tag, [Request.Extension{"PURGE"}], "/cache", Purge{}),
    B.all(Tag, "/status", Status{}),
    B.get(Tag, "/kinds", Kinds{}),
    B.get(Tag, "/openapi.json", Spec{}),
    B.get(Tag, "/docs", Reference{}),
    B.get(Tag, "/docs/offline", Offline{}),
    B.get(Tag, "/docs/bare", Bare{}),
    B.get(Tag, "*", Fallback{}),
  ]

def none() -> BS.RouteSchemas():
  BS.no_schemas()

def schemas() -> List<&2, BS.RouteSchemas()>:
  [
    BS.route_schemas(None{}, Some{list_query()}, None{}, None{}, Some{S.ArraySchema{todo(), 0n, None{}}}),
    BS.route_schemas(Some{id_params()}, None{}, None{}, None{}, Some{todo()}),
    BS.route_schemas(None{}, None{}, Some{key_headers()}, Some{todo_input()}, Some{todo()}),
    BS.route_schemas(Some{id_params()}, None{}, None{}, Some{todo_input()}, None{}),
    none(),
    BS.route_schemas(None{}, None{}, None{}, None{}, Some{S.LiteralSchema{J.JString{"first"}}}),
    BS.route_schemas(None{}, None{}, None{}, None{}, Some{S.LiteralSchema{J.JString{"second"}}}),
    none(),
    none(),
    none(),
    none(),
    BS.route_schemas(Some{version_params()}, None{}, None{}, None{}, None{}),
    none(),
    none(),
    none(),
    none(),
    none(),
    BS.route_schemas(None{}, None{}, None{}, None{}, Some{status()}),
    BS.route_schemas(None{}, None{}, None{}, None{}, Some{kinds()}),
    none(),
    none(),
    none(),
    none(),
    none(),
  ]

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}:
      BS.serve_schemas(~Tag, ~Unit, ~dispatch, table, schemas(), Unit{}, B.config())
    case Fail{error}:
      IO.die(Unit, 1, "invalid openapi fixture routes")

def main() -> IO(Unit):
  ready(B.routes(Tag, routes()))
