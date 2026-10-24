# A small todo API for the typed client (BND-57). Routes carry schemas so
# `bendo gen` derives Routes and the response table from the real manifest.
# Request validation (BND-36) is not wired yet, so POST /todos decodes its own
# body and answers 422 with Bendo's error list. GET /broken breaks its response
# schema on purpose.
import Base
import ../../../src/main.bend as B
import ../../../src/serve-schemas.bend as BS
import ../../../src/router/methods.bend as Methods
import ../../../src/data/schema.bend as S
import ../../../src/data/json.bend as J
import ../../../src/app/table.bend as Table

type Tag is Data:
  Echo{}
  GetTodo{}
  CreateTodo{}
  Broken{}

def text_or_empty(s: Maybe<&2, String>) -> String:
  Maybe.default(&2, String, s, "")

def strings(xs: List<&2, String>) -> List<&2, J.Json>:
  match xs:
    case Nil{}: []
    case x <> t: J.JString{x} <> strings(t)

def echo(+c: B.Ctx) -> B.Res:
  B.json(c, J.JObject{[
    J.Field{"url", J.JString{B.url(c)}},
    J.Field{"name", J.JString{text_or_empty(B.param(c, "name"))}},
    J.Field{"rest", J.JString{text_or_empty(B.param(c, "rest"))}},
    J.Field{"tags", J.JArray{strings(B.queries(c, "tag"))}},
    J.Field{"token", J.JString{text_or_empty(B.request_header(c, "x-token"))}},
    J.Field{"extra", J.JString{text_or_empty(B.request_header(c, "x-extra"))}},
  ]})

def todo_json(id: String, title: J.Json) -> J.Json:
  J.JObject{[J.Field{"id", J.JNumber{id}}, J.Field{"title", title}, J.Field{"done", J.JBool{False{}}}]}

def get_todo(+c: B.Ctx, id: Maybe<&2, String>) -> B.Res:
  match id:
    case Some{"1"}: B.json(c, todo_json("1", J.JString{"write the client"}))
    case _: B.not_found(c)

def todo_input() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"title", S.StringSchema{1n, Some{80n}, None{}, S.Plain{}}, S.Required{}},
    S.Field{"done", S.BooleanSchema{}, S.Default{J.JBool{False{}}}},
  ], S.Strict{}}

def unprocessable(+c: B.Ctx, errors: List<&2, S.Error>) -> B.Res:
  B.json(B.status(c, 422), J.JObject{[
    J.Field{"error", J.JString{"Unprocessable Entity"}},
    J.Field{"status", J.JNumber{"422"}},
    J.Field{"errors", S.errors_json(errors)},
  ]})

def created(+c: B.Ctx, body: J.Json, decoded: Result<&2, &2, S.Errors(), S.Value>) -> B.Res:
  match body decoded:
    case _ Fail{errors}: unprocessable(c, errors)
    case J.JObject{fields} Done{value}: B.json(B.status(c, 201), todo_json("2", Maybe.default(&2, J.Json, J.lookup(fields, "title"), J.JNull{})))
    case _ Done{value}: B.not_found(c)

def decoded(+c: B.Ctx, +body: J.Json) -> B.Res:
  created(c, body, S.decode(todo_input(), body))

def create(+c: B.Ctx, parsed: Result<&2, &2, J.Error, J.Json>) -> B.Res:
  match parsed:
    case Done{body}: decoded(c, body)
    case Fail{e}: B.text(B.status(c, 400), "bad json")

def response(tag: Tag, +c: B.Ctx) -> B.Res:
  match tag:
    case Echo{}: echo(c)
    case GetTodo{}: get_todo(c, B.param(c, "id"))
    case CreateTodo{}: create(c, J.parse(B.raw_body(c)))
    case Broken{}: B.json(c, J.JObject{[J.Field{"id", J.JString{"one"}}, J.Field{"done", J.JBool{True{}}}]})

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, response(tag, c))

def text(min: Nat) -> S.Schema:
  S.StringSchema{min, None{}, None{}, S.Plain{}}

def todo() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"id", S.IntegerSchema{Some{"1"}, None{}}, S.Required{}},
    S.Field{"title", text(1n), S.Required{}},
    S.Field{"done", S.BooleanSchema{}, S.Required{}},
  ], S.Strict{}}

def echo_params() -> S.Schema:
  S.ObjectSchema{[S.Field{"name", text(1n), S.Required{}}, S.Field{"rest", text(0n), S.Required{}}], S.Strict{}}

def echo_query() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"n", S.NumberSchema{None{}, None{}}, S.Optional{}},
    S.Field{"flag", S.BooleanSchema{}, S.Optional{}},
    S.Field{"tag", S.ArraySchema{text(1n), 0n, None{}}, S.Optional{}},
  ], S.Strip{}}

def echo_headers() -> S.Schema:
  S.ObjectSchema{[S.Field{"x-token", text(1n), S.Required{}}], S.Strip{}}

def echo_response() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"url", text(0n), S.Required{}},
    S.Field{"name", text(0n), S.Required{}},
    S.Field{"rest", text(0n), S.Required{}},
    S.Field{"tags", S.ArraySchema{text(0n), 0n, None{}}, S.Required{}},
    S.Field{"token", text(0n), S.Required{}},
    S.Field{"extra", text(0n), S.Required{}},
  ], S.Strict{}}

def id_params() -> S.Schema:
  S.ObjectSchema{[S.Field{"id", S.IntegerSchema{Some{"1"}, None{}}, S.Required{}}], S.Strict{}}

def routes() -> List<&2, Table.Entry<Tag>>:
  [
    B.get(Tag, "/echo/:name/*rest", Echo{}),
    B.get(Tag, "/todos/:id{int}", GetTodo{}),
    B.post(Tag, "/todos", CreateTodo{}),
    B.get(Tag, "/broken", Broken{}),
  ]

def schemas() -> List<&2, BS.RouteSchemas()>:
  [
    BS.route_schemas(Some{echo_params()}, Some{echo_query()}, Some{echo_headers()}, None{}, Some{echo_response()}),
    BS.route_schemas(Some{id_params()}, None{}, None{}, None{}, Some{todo()}),
    BS.route_schemas(None{}, None{}, None{}, Some{todo_input()}, Some{todo()}),
    BS.route_schemas(None{}, None{}, None{}, None{}, Some{todo()}),
  ]

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}: BS.serve_schemas(~Tag, ~Unit, ~dispatch, table, schemas(), Unit{}, B.config())
    case Fail{error}: IO.die(Unit, 1, "invalid client fixture routes")

def main() -> IO(Unit):
  ready(B.routes(Tag, routes()))
