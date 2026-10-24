# A small todo API for the typed client (BND-57). Routes carry schemas so
# `bendo gen` derives Routes and the response table from the real manifest,
# and the server validates requests with them (BND-36), so a bad POST /todos
# body gets Bendo's own 422. GET /broken breaks its response schema on purpose:
# under BENDO_ENV=production the server sends it unchanged so the client's own
# check sees it, and in the default development mode the server answers 500.
# ALL /any answers HEAD with a JSON Content-Type and no body. /int, /num and
# /big only validate a numeric capture, so the client's admission of number
# tokens can be compared with the server's decoder.
import Base
import ../../../src/main.bend as B
import ../../../src/validated.bend as V
import ../../../src/data/schema.bend as S
import ../../../src/data/json.bend as J
import ../../../src/http/request.bend as Request

type Tag is Data:
  Echo{}
  GetTodo{}
  CreateTodo{}
  Broken{}
  Any{}
  Admitted{}

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

# Validation already decoded the body, so the title is there.
def create(+c: B.Ctx, title: Maybe<&2, S.Value>) -> B.Res:
  match title:
    case Some{S.VString{t}}: B.json(B.status(c, 201), todo_json("2", J.JString{t}))
    case _: B.not_found(c)

def response(tag: Tag, +c: B.Ctx) -> B.Res:
  match tag:
    case Echo{}: echo(c)
    case GetTodo{}: get_todo(c, B.param(c, "id"))
    case CreateTodo{}: create(c, B.field(B.valid_body(c), "title"))
    case Broken{}: B.json(c, J.JObject{[J.Field{"id", J.JString{"one"}}, J.Field{"done", J.JBool{True{}}}]})
    case Any{}: B.json(c, J.JObject{[J.Field{"method", J.JString{Request.method_text(B.method(c))}}]})
    case Admitted{}: B.json(c, J.JObject{[]})

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

def number_params(key: String, s: S.Schema) -> S.Schema:
  S.ObjectSchema{[S.Field{key, s, S.Required{}}], S.Strict{}}

def any_response() -> S.Schema:
  S.ObjectSchema{[S.Field{"method", text(1n), S.Required{}}], S.Strict{}}

def routes() -> List<&2, B.Registration(Tag)>:
  [
    B.with_schemas(Tag, B.get(Tag, "/echo/:name/*rest", Echo{}), B.schemas([B.params_schema(echo_params()), B.query_schema(echo_query()), B.headers_schema(echo_headers()), B.response_schema(echo_response())])),
    B.with_schemas(Tag, B.get(Tag, "/todos/:id{int}", GetTodo{}), B.schemas([B.params_schema(id_params()), B.response_schema(todo())])),
    B.with_schemas(Tag, B.post(Tag, "/todos", CreateTodo{}), B.schemas([B.body_schema(todo_input()), B.response_schema(todo())])),
    B.with_schemas(Tag, B.get(Tag, "/broken", Broken{}), B.schemas([B.response_schema(todo())])),
    B.with_schemas(Tag, B.all(Tag, "/any", Any{}), B.schemas([B.response_schema(any_response())])),
    B.with_schemas(Tag, B.get(Tag, "/int/:i", Admitted{}), B.schemas([B.params_schema(number_params("i", S.IntegerSchema{Some{"-5"}, Some{"9007199254740992"}}))])),
    B.with_schemas(Tag, B.get(Tag, "/num/:n", Admitted{}), B.schemas([B.params_schema(number_params("n", S.NumberSchema{Some{"-1.5"}, Some{"1e3"}}))])),
    B.with_schemas(Tag, B.get(Tag, "/big/:n", Admitted{}), B.schemas([B.params_schema(number_params("n", S.NumberSchema{None{}, None{}}))])),
  ]

def ready(result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}: V.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())
    case Fail{error}: IO.die(Unit, 1, "invalid client fixture routes")

def main() -> IO(Unit):
  ready(B.routes(Tag, routes()))
