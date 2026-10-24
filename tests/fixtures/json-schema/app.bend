# A todo API whose routes carry schemas (BND-37). `--bendo-routes` prints them
# as JSON Schema. BENDO_FIXTURE_SCHEMAS=short drops the last entry and
# =invalid breaks the body schema of POST /todos, to test both failures.
import Base
import ../../../src/main.bend as B
import ../../../src/serve-schemas.bend as BS
import ../../../src/router/methods.bend as Methods
import ../../../src/http/request.bend as Request
import ../../../src/data/schema.bend as S
import ../../../src/data/schema-pattern.bend as P
import ../../../src/data/json.bend as J
import ../../../src/app/table.bend as Table

type Tag is Data:
  ListTodos{}
  GetTodo{}
  CreateTodo{}
  UpdateTodo{}
  First{}
  Second{}
  Health{}
  Status{}

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  +c = ctx
  IO.pure(B.Res, B.text(c, "ok"))

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
    S.Field{"priority", S.EnumSchema{[J.JNumber{"1"}, J.JNumber{"2"}, J.JNumber{"1.0"}, J.JNumber{"3"}]}, S.Default{J.JNumber{"2"}}},
  ], S.Strict{}}

def list_query() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"limit", S.IntegerSchema{Some{"1"}, Some{"100"}}, S.Default{J.JNumber{"10"}}},
    S.Field{"tag", S.ArraySchema{text(1n, 40n), 0n, None{}}, S.Optional{}},
  ], S.Strip{}}

def id_params() -> S.Schema:
  S.ObjectSchema{[S.Field{"id", id(), S.Required{}}], S.Strict{}}

def key_headers() -> S.Schema:
  S.ObjectSchema{[S.Field{"x-api-key", text(1n, 128n), S.Required{}}], S.Strip{}}

def status() -> S.Schema:
  S.UnionSchema{[
    S.LiteralSchema{J.JString{"ok"}},
    S.NullableSchema{S.NumberSchema{Some{"0"}, Some{"1e2"}}},
    S.UnionSchema{[]},
  ]}

def routes() -> List<&2, Table.Entry<Tag>>:
  [
    B.get(Tag, "/todos", ListTodos{}),
    B.get(Tag, "/todos/:id{int}", GetTodo{}),
    B.post(Tag, "/todos", CreateTodo{}),
    B.on(Tag, [Request.Put{}, Request.Patch{}], "/todos/:id{int}", UpdateTodo{}),
    B.get(Tag, "/dup", First{}),
    B.get(Tag, "/dup", Second{}),
    B.get(Tag, "/health", Health{}),
    B.all(Tag, "/status", Status{}),
  ]

def leading(body: S.Schema) -> List<&2, BS.RouteSchemas()>:
  [
    BS.route_schemas(None{}, Some{list_query()}, None{}, None{}, Some{S.ArraySchema{todo(), 0n, None{}}}),
    BS.route_schemas(Some{id_params()}, None{}, None{}, None{}, Some{todo()}),
    BS.route_schemas(None{}, None{}, Some{key_headers()}, Some{body}, Some{todo()}),
    BS.route_schemas(Some{id_params()}, None{}, None{}, Some{todo_input()}, None{}),
    BS.route_schemas(None{}, None{}, None{}, None{}, Some{S.LiteralSchema{J.JString{"first"}}}),
    BS.route_schemas(None{}, None{}, None{}, None{}, Some{S.LiteralSchema{J.JString{"second"}}}),
    BS.no_schemas(),
  ]

def chosen(short: Bool, invalid: Bool) -> List<&2, BS.RouteSchemas()>:
  match short invalid:
    case True{} _: leading(todo_input())
    case False{} True{}: List.append(&2, BS.RouteSchemas(), leading(text(3n, 2n)), [BS.route_schemas(None{}, None{}, None{}, None{}, Some{status()})])
    case False{} False{}: List.append(&2, BS.RouteSchemas(), leading(todo_input()), [BS.route_schemas(None{}, None{}, None{}, None{}, Some{status()})])

def schemas(+mode: String) -> List<&2, BS.RouteSchemas()>:
  chosen(String.eq(mode, "short"), String.eq(mode, "invalid"))

def mode(r: Result<&1, &1, U32 & String, String>) -> String:
  match r:
    case Done{value}: value
    case Fail{e}: ""

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>, mode: String) -> IO(Unit):
  match result:
    case Done{table}:
      BS.serve_schemas(~Tag, ~Unit, ~dispatch, table, schemas(mode), Unit{}, B.config())
    case Fail{error}:
      IO.die(Unit, 1, "invalid json-schema fixture routes")

def main() -> IO(Unit):
  do IO<Unit>:
    env : Result<&1, &1, U32 & String, String> <- IO.get_env("BENDO_FIXTURE_SCHEMAS")
    ready(B.routes(Tag, routes()), mode(env))
