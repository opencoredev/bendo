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
  HookRequest{}
  HookTiming{}
  HookRewrite{}
  HookLogger{}
  HookMap{}
  HookId{}
  Builtin{id: B.Builtin}

def handle(tag: Tag, +c: B.Context(Vars), env: Unit) -> IO(B.Res):
  match tag:
    case HookId{}: IO.pure(B.Res, C.text(Vars, c, Maybe.default(&2, String, C.request_id(Vars, c), "none") ++ ":" ++ Maybe.default(&2, String, C.param(Vars, c, "id"), "none")))
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

def optional_builtin(id: B.Builtin, c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res), active: Bool) -> IO(B.Res):
  match active:
    case True{}: B.builtin(Vars, id, c, next)
    case False{}: next(c)

def rewritten(c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res), path: String) -> IO(B.Res):
  match path:
    case "/hook-id": next(C.rewrite(Vars, c, Request.Get{}, "/hook-target/42"))
    case "/hook-json": next(C.rewrite(Vars, c, Request.Get{}, "/json"))
    case _: next(c)

def accepted(res: B.Res) -> B.Res:
  Response.Res{code, hs, body, rep} = res
  Response.Res{202, hs, body, rep}

def mapped(res: B.Res, path: String) -> B.Res:
  match path:
    case "/hook-target/42": accepted(res)
    case _: res

def middleware_go(tag: Tag, +c: B.Context(Vars), env: Unit, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Vars, id, c, next)
    case HookRequest{}: optional_builtin(B.request_id(), c, next, String.starts_with(C.path(Vars, c), "/hook"))
    case HookTiming{}: optional_builtin(B.server_timing(), c, next, String.starts_with(C.path(Vars, c), "/hook"))
    case HookRewrite{}: rewritten(c, next, C.path(Vars, c))
    case HookLogger{}: optional_builtin(B.logger(), c, next, String.starts_with(C.path(Vars, c), "/hook-target") || String.eq(C.path(Vars, c), "/json"))
    case HookMap{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return mapped(res, C.path(Vars, c))
    case Custom{}: next(C.set(Vars, C.header(Vars, c, "x-custom", "yes"), Vars{"app"}))
    case _: next(c)

def middleware(tag: Tag, c: B.Context(Vars), env: Unit, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  middleware_go(tag, c, env, next)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve_with(~Vars, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.on_request(Tag, HookRequest{}),
    B.on_request(Tag, HookTiming{}),
    B.on_request(Tag, HookRewrite{}),
    B.map_response(Tag, HookMap{}),
    B.on_after_response(Tag, HookLogger{}),
    B.use(Tag, Builtin{B.logger()}),
    B.use(Tag, Custom{}),
    B.use_path(Tag, "/id", Builtin{B.request_id()}),
    B.use_path(Tag, "/reverse", Builtin{B.request_id()}),
    B.use_path(Tag, "/reverse", Builtin{B.logger()}),
    B.use_path(Tag, "/json", Builtin{B.server_timing()}),
    B.use_path(Tag, "/json", Builtin{B.server_timing()}),
    B.use(Tag, Builtin{B.pretty_json()}),
    B.use_path(Tag, "/powered", Builtin{B.powered_by("Bendo")} ),
    B.get(Tag, "/hook-target/:id", HookId{}),
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
