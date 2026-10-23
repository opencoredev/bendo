import Base
import ../../src/main.bend as B
import ../../src/app/context.bend as C
import ../../src/http/response.bend as Response
import ../../src/http/request.bend as Request
import ../../src/router/methods.bend as Methods

type Vars is Data:
  Vars{label: String}

type Tag is Data:
  Hello{}
  Id{}
  Json{}
  InvalidJson{}
  PlainText{}
  Partial{}
  Encoded{}
  Broken{}
  Custom{}
  Builtin{id: B.Builtin}

def handle(tag: Tag, +c: B.Context(Vars), env: Unit) -> IO(B.Res):
  match tag:
    case Id{}: IO.pure(B.Res, C.text(Vars, c, Maybe.default(&2, String, C.request_id(Vars, c), "none")))
    case Broken{}: IO.pure(B.Res, Response.body(200, [Request.Header{"bad", [13]}], []))
    case Json{}:
      do IO<B.Res>:
        db : Bool <- B.timing_mark(Vars, c, "db", 4n)
        escaped : Bool <- B.timing_mark(Vars, c, "cache; hit\r\n", 2n)
        return C.body(Vars, C.header(Vars, c, "etag", "old"), Response.utf8("{\"a\":[1,true],\"b\":\"é\"}"), Some{"application/json; charset=utf-8"})
    case InvalidJson{}: IO.pure(B.Res, C.body(Vars, c, Response.utf8("{bad}"), Some{"application/json"}))
    case PlainText{}: IO.pure(B.Res, C.text(Vars, c, "{\"a\":1}"))
    case Partial{}: IO.pure(B.Res, C.body(Vars, C.status(Vars, c, 206), Response.utf8("{\"a\":1}"), Some{"application/json"}))
    case Encoded{}: IO.pure(B.Res, C.body(Vars, C.header(Vars, c, "content-encoding", "identity"), Response.utf8("{\"a\":1}"), Some{"application/json"}))
    case _: IO.pure(B.Res, C.text(Vars, c, "hello"))

def handler(tag: Tag, c: B.Context(Vars), env: Unit) -> IO(B.Res):
  handle(tag, c, env)

def middleware(tag: Tag, c: B.Context(Vars), env: Unit, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Vars, id, c, next)
    case Custom{}: next(C.set(Vars, C.header(Vars, c, "x-custom", "yes"), Vars{"app"}))
    case _: next(c)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve_with(~Vars, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.use(Tag, Builtin{B.logger()}),
    B.use(Tag, Custom{}),
    B.use_path(Tag, "/id", Builtin{B.request_id()}),
    B.use_path(Tag, "/reverse", Builtin{B.request_id()}),
    B.use_path(Tag, "/reverse", Builtin{B.logger()}),
    B.use_path(Tag, "/json", Builtin{B.server_timing()}),
    B.use_path(Tag, "/json", Builtin{B.server_timing()}),
    B.use(Tag, Builtin{B.pretty_json()}),
    B.use_path(Tag, "/powered", Builtin{B.powered_by("Bendo")} ),
    B.get(Tag, "/", Hello{}),
    B.get(Tag, "/id", Id{}),
    B.get(Tag, "/reverse", Id{}),
    B.get(Tag, "/json", Json{}),
    B.get(Tag, "/invalid", InvalidJson{}),
    B.get(Tag, "/text", PlainText{}),
    B.get(Tag, "/partial", Partial{}),
    B.get(Tag, "/encoded", Encoded{}),
    B.get(Tag, "/broken", Broken{}),
    B.get(Tag, "/powered", Hello{})
  ]))
