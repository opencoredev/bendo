# BND-36 route validation: one route per slot, a guard, a mounted sub-app,
# a route whose hooks show where validation runs in the lifecycle, and routes
# whose hooks produce or replace the response the response schema checks.
# The stream, forged-marker and socket routes show that only a response the
# transport really streams or upgrades skips the response schema.
import Base
import ../../src/main.bend as B
import ../../src/app/table.bend as T
import ../../src/validated.bend as V
import ../../src/app/context.bend as C
import ../../src/router/methods.bend as M
import ../../src/data/schema.bend as S
import ../../src/data/schema-pattern.bend as P
import ../../src/data/json.bend as J
import ../../src/http/stream_types.bend as ST

type Tag is Data:
  Item{}
  Search{}
  WhoAmI{}
  CreateTodo{}
  Report{}
  ReportBad{}
  ReportText{}
  Ordered{}
  Plain{}
  Combo{}
  Wide{}
  Member{}
  Mounted{}
  Stamp{}
  Stop{}
  Flood{}
  Hooked{}
  BadBefore{}
  BadMap{}
  Leak{}
  Streamed{}
  Forged{}
  ForgeMap{}
  Socket{}

def text() -> S.Schema:
  S.StringSchema{1n, Some{80n}, None{}, S.Plain{}}

def id_params(key: String) -> S.Schema:
  S.ObjectSchema{[S.Field{key, S.IntegerSchema{Some{"1"}, None{}}, S.Required{}}], S.Strict{}}

def search_query() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"q", S.StringSchema{1n, Some{40n}, None{}, S.Plain{}}, S.Required{}},
    S.Field{"page", S.IntegerSchema{Some{"1"}, Some{"100"}}, S.Default{J.JNumber{"1"}}},
    S.Field{"tag", S.ArraySchema{text(), 0n, Some{3n}}, S.Optional{}}], S.Strip{}}

# [a-z0-9]{8,64}: a pattern, so the route's table is prepared once.
def key_pattern() -> P.Pattern:
  P.Repeat{P.Class{[P.Range{97, 122}, P.Range{48, 57}]}, 8n, Some{64n}}

def whoami_headers() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"x-api-key", S.StringSchema{8n, Some{64n}, Some{key_pattern()}, S.Plain{}}, S.Required{}},
    S.Field{"x-count", S.IntegerSchema{Some{"0"}, None{}}, S.Optional{}}], S.Strip{}}

# (?:(?:[a]{0,10}){0,11})*: about 110 automaton nodes, the widest shape in
# docs/data/schema.md, whose table takes tens of milliseconds to build.
def wide_pattern() -> P.Pattern:
  P.Repeat{P.Repeat{P.Repeat{P.Class{[P.Range{97, 97}]}, 0n, Some{10n}}, 0n, Some{11n}}, 0n, None{}}

def wide(+p: Maybe<&2, P.Pattern>) -> S.Schema:
  S.StringSchema{0n, Some{64n}, p, S.Plain{}}

def wide_headers(+p: Maybe<&2, P.Pattern>) -> S.Schema:
  S.ObjectSchema{[S.Field{"x-wide", wide(p), S.Required{}}, S.Field{"x-wide-2", wide(p), S.Required{}}, S.Field{"x-wide-3", wide(p), S.Required{}}], S.Strip{}}

def todo_body() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"title", text(), S.Required{}},
    S.Field{"done", S.BooleanSchema{}, S.Default{J.JBool{False{}}}},
    S.Field{"tags", S.ArraySchema{text(), 0n, Some{5n}}, S.Optional{}}], S.Strict{}}

def todo_response() -> S.Schema:
  S.ObjectSchema{[S.Field{"id", S.IntegerSchema{None{}, None{}}, S.Required{}}, S.Field{"todo", S.ObjectSchema{[], S.Strip{}}, S.Required{}}], S.Strict{}}

def report_response() -> S.Schema:
  S.ObjectSchema{[S.Field{"count", S.IntegerSchema{Some{"0"}, None{}}, S.Required{}}], S.Strict{}}

# 60 required keys, k0 to k59, so 60 errors when all are missing.
def required(+prefix: String, n: Nat) -> List<&2, S.Field>:
  match n:
    case 0n: []
    case 1n+(+k): S.Field{prefix ++ Nat.show(k), text(), S.Required{}} <> required(prefix, k)

def flood(prefix: String) -> S.Schema:
  S.ObjectSchema{required(prefix, 60n), S.Strip{}}

def token(schema: S.Schema) -> S.Schema:
  S.ObjectSchema{[S.Field{"token", schema, S.Required{}}], S.Strip{}}

def decoded(v: Maybe<&2, S.Value>) -> J.Json:
  match v:
    case None{}: J.JNull{}
    case Some{x}: S.to_json(x)

def integer(v: Maybe<&2, S.Value>) -> String:
  match v:
    case Some{S.VInteger{x}}: x
    case _: "?"

def string(v: Maybe<&2, S.Value>) -> String:
  match v:
    case Some{S.VString{x}}: x
    case _: "?"

def none(v: Maybe<&2, S.Value>) -> String:
  match v:
    case None{}: "none"
    case Some{x}: "some"

# One chunk of text that is not JSON, then the end.
def pull(left: Nat) -> IO(ST.Step<Nat>):
  match left:
    case 0n: IO.pure(ST.Step<Nat>, ST.End{0n})
    case 1n+n: IO.pure(ST.Step<Nat>, ST.Chunk{[110, 111, 116, 32, 106, 115, 111, 110], n})

def released(left: Nat) -> IO(Unit):
  IO.pure(Unit, Unit{})

def opened(label: Unit, s: Socket, rest: List<&2, U32>) -> IO(Unit):
  Socket.close(s)

def closed(label: Unit) -> IO(Unit):
  IO.pure(Unit, Unit{})

def marker() -> String: "x-bendo-stream-internal"

def answer(tag: Tag, +c: B.Ctx) -> IO(B.Res):
  match tag:
    case Item{}: IO.pure(B.Res, B.text(c, "id=" ++ integer(B.field(B.valid_params(c), "id"))))
    case Mounted{}: IO.pure(B.Res, B.text(c, "n=" ++ integer(B.field(B.valid_params(c), "n"))))
    case Search{}: IO.pure(B.Res, B.json(c, decoded(B.valid_query(c))))
    case WhoAmI{}: IO.pure(B.Res, B.json(c, decoded(B.valid_headers(c))))
    case Member{}: IO.pure(B.Res, B.json(c, decoded(B.valid_query(c))))
    case CreateTodo{}: IO.pure(B.Res, B.json(B.status(c, 201), J.JObject{[J.Field{"id", J.JNumber{"1"}}, J.Field{"todo", decoded(B.valid_body(c))}]}))
    case Report{}: IO.pure(B.Res, B.json(c, J.JObject{[J.Field{"count", J.JNumber{"3"}}]}))
    case ReportBad{}: IO.pure(B.Res, B.json(c, J.JObject{[J.Field{"count", J.JString{"three"}}, J.Field{"secret", J.JString{"internal"}}]}))
    case ReportText{}: IO.pure(B.Res, B.text(c, "count=3"))
    case Ordered{}: IO.pure(B.Res, B.text(c, "handler"))
    case Combo{}: IO.pure(B.Res, B.text(c, "combo"))
    case Wide{}: IO.pure(B.Res, B.text(c, string(B.field(B.valid_headers(c), "x-wide"))))
    case Flood{}: IO.pure(B.Res, B.text(c, "flood"))
    case Hooked{}: IO.pure(B.Res, B.json(c, J.JObject{[J.Field{"count", J.JNumber{"3"}}]}))
    case Leak{}: IO.pure(B.Res, B.json(c, J.JObject{[J.Field{"count", J.JString{"three"}}]}))
    case Streamed{}: B.stream(~Unit, ~Nat, ~pull, ~released, B.header(c, "content-type", "text/plain"), 1n, B.stream_config())
    case Forged{}: IO.pure(B.Res, B.json(B.header(c, marker(), "anything"), J.JObject{[J.Field{"count", J.JString{"three"}}]}))
    case Socket{}: B.websocket(~Unit, ~Unit, ~opened, ~closed, c, Unit{}, B.websocket_config())
    case Plain{}: IO.pure(B.Res, B.text(c, none(B.valid_params(c)) ++ "," ++ none(B.valid_query(c)) ++ "," ++ none(B.valid_headers(c)) ++ "," ++ none(B.valid_body(c))))
    case _: IO.pure(B.Res, B.not_found(c))

# Stamp is a transform hook: its header shows up on a rejection, so it ran
# first. Stop is a before_handle hook: it never runs on a rejection, and it
# already sees the decoded body.
def hook(tag: Tag, +c: B.Ctx, next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Stamp{}: next(B.header(c, "x-stamp", "transform"))
    case Stop{}: IO.pure(B.Res, B.text(c, "before-handle:" ++ string(B.field(B.valid_body(c), "title"))))
    case BadBefore{}: IO.pure(B.Res, B.json(c, J.JObject{[J.Field{"count", J.JNumber{"-1"}}]}))
    case BadMap{}: IO.pure(B.Res, B.json(c, J.JObject{[J.Field{"count", J.JNumber{"3"}}, J.Field{"mapped", J.JBool{True{}}}]}))
    case ForgeMap{}: IO.pure(B.Res, B.json(B.header(c, marker(), "forged"), J.JObject{[J.Field{"count", J.JString{"three"}}]}))
    case _: next(c)

def handler(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  answer(tag, c)

def middleware(tag: Tag, c: B.Ctx, env: Unit, next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  hook(tag, c, next)

def one(slot: B.SchemaSlot) -> B.Schemas:
  B.schemas([slot])

def entries() -> List<&2, B.Registration(Tag)>:
  List.concat(&2, B.Registration(Tag), [
    [B.with_schemas(Tag, B.get(Tag, "/items/:id", Item{}), one(B.params_schema(id_params("id")))),
     B.with_schemas(Tag, B.get(Tag, "/search", Search{}), one(B.query_schema(search_query()))),
     B.with_schemas(Tag, B.get(Tag, "/whoami", WhoAmI{}), one(B.headers_schema(whoami_headers()))),
     B.with_schemas(Tag, B.post(Tag, "/todos", CreateTodo{}), B.schemas([B.body_schema(todo_body()), B.response_schema(todo_response())])),
     B.with_schemas(Tag, B.get(Tag, "/report", Report{}), one(B.response_schema(report_response()))),
     B.with_schemas(Tag, B.get(Tag, "/report-bad", ReportBad{}), one(B.response_schema(report_response()))),
     B.with_schemas(Tag, B.get(Tag, "/report-text", ReportText{}), one(B.response_schema(report_response()))),
     B.route_schemas(Tag, M.post(Tag, "/ordered", Ordered{}), [B.hook(Tag, T.Transform{}, Stamp{}), B.hook(Tag, T.BeforeHandle{}, Stop{})], one(B.body_schema(todo_body()))),
     B.with_schemas(Tag, B.post(Tag, "/combo/:id", Combo{}), B.schemas([B.params_schema(id_params("id")), B.query_schema(search_query()), B.headers_schema(whoami_headers()), B.body_schema(todo_body())])),
     B.with_schemas(Tag, B.get(Tag, "/wide", Wide{}), one(B.headers_schema(wide_headers(Some{wide_pattern()})))),
     B.with_schemas(Tag, B.get(Tag, "/narrow", Wide{}), one(B.headers_schema(wide_headers(None{})))),
     B.get(Tag, "/plain", Plain{}),
     B.with_schemas(Tag, B.get(Tag, "/flood", Flood{}), B.schemas([B.query_schema(flood("k")), B.headers_schema(flood("h"))])),
     B.route_schemas(Tag, M.get(Tag, "/hooked/before", Hooked{}), [B.hook(Tag, T.BeforeHandle{}, BadBefore{})], one(B.response_schema(report_response()))),
     B.route_schemas(Tag, M.get(Tag, "/hooked/map", Hooked{}), [B.hook(Tag, T.MapResponse{}, BadMap{})], one(B.response_schema(report_response()))),
     B.with_schemas(Tag, B.get(Tag, "/leak/:token", Leak{}), one(B.response_schema(report_response()))),
     B.with_schemas(Tag, B.get(Tag, "/stream/report", Streamed{}), one(B.response_schema(report_response()))),
     B.with_schemas(Tag, B.get(Tag, "/forged", Forged{}), one(B.response_schema(report_response()))),
     B.route_schemas(Tag, M.get(Tag, "/stream/forged", Streamed{}), [B.hook(Tag, T.MapResponse{}, ForgeMap{})], one(B.response_schema(report_response()))),
     B.route_schemas(Tag, M.get(Tag, "/stream/mapped", Streamed{}), [B.hook(Tag, T.MapResponse{}, BadMap{})], one(B.response_schema(report_response()))),
     B.with_schemas(Tag, B.get(Tag, "/socket", Socket{}), one(B.response_schema(report_response())))],
    B.guard(Tag, B.guard_schemas(Tag, [], one(B.query_schema(token(text())))), [
      B.get(Tag, "/guarded/a", Member{}),
      B.with_schemas(Tag, B.get(Tag, "/guarded/b", Member{}), one(B.query_schema(token(S.IntegerSchema{None{}, None{}}))))]),
    B.route(Tag, "/api", [B.with_schemas(Tag, B.get(Tag, "/thing/:n", Mounted{}), one(B.params_schema(id_params("n"))))])])

def ready(result: Result<&2, &2, M.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "bad validation table")
    case Done{table}: V.serve_with(~Unit, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, entries()))
