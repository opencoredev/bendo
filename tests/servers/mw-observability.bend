import Base
import ../../src/main.bend as B
import ../../src/app/context.bend as C
import ../../src/http/response.bend as Response
import ../../src/http/request.bend as Request
import ../../src/router/methods.bend as Methods

type Vars is Data:
  Vars{label: String}

type Tag is Data:
  DelayAfter{}
  Slow{}
  Hello{}
  Id{}
  ExplicitId{}
  EchoId{}
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
  HandlerError{}
  HookAfter{}
  HookError{}
  Builtin{id: B.Builtin}

# Select Unicode with an ASCII request marker; HTTP header decoding may reject
# a client's Latin-1 byte before it reaches the outgoing-ID validation path.
def outgoing_id(value: String) -> String:
  match value:
    case "non-ascii": "é"
    case _: value

def handle(tag: Tag, +c: B.Context(Vars), env: Unit) -> IO(B.Res):
  match tag:
    case HookId{}: IO.pure(B.Res, C.text(Vars, c, Maybe.default(&2, String, C.request_id(Vars, c), "none") ++ ":" ++ Maybe.default(&2, String, C.param(Vars, c, "id"), "none")))
    case ExplicitId{}: IO.pure(B.Res, Response.body(200, [Request.Header{"x-request-id", Response.utf8(outgoing_id(Maybe.default(&2, String, C.request_header(Vars, c, "x-outgoing-id"), "")))}], []))
    case EchoId{}: IO.pure(B.Res, Response.body(200, [Request.Header{"x-request-id", Response.utf8(Maybe.default(&2, String, C.request_header(Vars, c, "x-request-id"), ""))}], Response.utf8(Maybe.default(&2, String, C.request_id(Vars, c), "none"))))
    case Id{}: IO.pure(B.Res, C.text(Vars, c, Maybe.default(&2, String, C.request_id(Vars, c), "none")))
    case Slow{}:
      do IO<B.Res>:
        IO.sleep(150)
        IO.print_err("late-handler-finished " ++ C.path(Vars, c))
        return C.text(Vars, c, "late")
    case Hello{}: IO.pure(B.Res, C.text(Vars, c, "hello"))
    case HandlerError{}: IO.pure(B.Res, Response.text(500, "handler error"))
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

def mapped(res: B.Res, path: String, outgoing: String) -> B.Res:
  match path:
    case "/hook-outgoing": Response.body(200, [Request.Header{"x-request-id", Response.utf8(outgoing_id(outgoing))}], [])
    case "/hook-map": Response.text(201, "mapped")
    case "/hook-explicit": Response.body(200, [Request.Header{"x-request-id", Response.utf8("explicit")}, Request.Header{"server-timing", Response.utf8("custom;dur=7")}], [])
    case "/hook-invalid-map": Response.body(200, [Request.Header{"bad", [13]}], [])
    case "/hook-target/42": accepted(res)
    case _: res

def after_response(res: B.Res, path: String) -> B.Res:
  match path:
    case "/hook-after": Response.text(202, "after")
    case _: res

def recover_hook(res: B.Res, active: Bool) -> B.Res:
  match active:
    case True{}: Response.text(503, "recovered")
    case False{}: res

def error_response(res: B.Res, path: String) -> B.Res:
  match path:
    case "/hook-invalid": res
    case "/hook-invalid-map": res
    case "/hook-invalid-recovery": Response.body(200, [Request.Header{"bad", [13]}], [])
    case _: recover_hook(res, String.starts_with(path, "/hook"))

def middleware_go(tag: Tag, +c: B.Context(Vars), env: Unit, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case DelayAfter{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        IO.sleep(150)
        return res
    case Builtin{id}: B.builtin(Vars, id, c, next)
    case HookRequest{}: optional_builtin(B.request_id(), c, next, String.starts_with(C.path(Vars, c), "/hook"))
    case HookTiming{}: optional_builtin(B.server_timing(), c, next, String.starts_with(C.path(Vars, c), "/hook"))
    case HookRewrite{}: rewritten(c, next, C.path(Vars, c))
    case HookLogger{}: optional_builtin(B.logger(), c, next, String.starts_with(C.path(Vars, c), "/hook-target") || String.eq(C.path(Vars, c), "/json"))
    case HookAfter{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return after_response(res, C.path(Vars, c))
    case HookError{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return error_response(res, C.path(Vars, c))
    case HookMap{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return mapped(res, C.path(Vars, c), Maybe.default(&2, String, C.request_header(Vars, c, "x-outgoing-id"), ""))
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
    B.after_handle(Tag, HookAfter{}),
    B.map_response(Tag, HookMap{}),
    B.on_error(Tag, HookError{}),
    B.on_after_response(Tag, HookLogger{}),
    B.use_path(Tag, "/timeout-outer", Builtin{B.timeout(30)}),
    B.use(Tag, Builtin{B.logger()}),
    B.use_path(Tag, "/timeout-inner", Builtin{B.timeout(30)}),
    B.use_path(Tag, "/duration", DelayAfter{}),
    B.use_path(Tag, "/duration", Builtin{B.logger()}),
    B.use(Tag, Custom{}),
    B.use_path(Tag, "/id-echo", Builtin{B.request_id()}),
    B.use_path(Tag, "/id", Builtin{B.request_id()}),
    B.use_path(Tag, "/reverse", Builtin{B.request_id()}),
    B.use_path(Tag, "/reverse", Builtin{B.logger()}),
    B.use_path(Tag, "/json", Builtin{B.server_timing()}),
    B.use_path(Tag, "/json", Builtin{B.server_timing()}),
    B.use(Tag, Builtin{B.pretty_json()}),
    B.use_path(Tag, "/powered", Builtin{B.powered_by("Bendo")} ),
    B.get(Tag, "/hook-target/:id", HookId{}),
    B.get(Tag, "/hook-method", Hello{}),
    B.get(Tag, "/hook-handler-error", HandlerError{}),
    B.get(Tag, "/hook-invalid", Broken{}),
    B.get(Tag, "/hook-invalid-recovery", Broken{}),
    B.get(Tag, "/hook-invalid-map", Hello{}),
    B.get(Tag, "/hook-map", Hello{}),
    B.get(Tag, "/hook-after", Hello{}),
    B.get(Tag, "/hook-explicit", Hello{}),
    B.get(Tag, "/hook-outgoing", Hello{}),
    B.get(Tag, "/hook-outgoing-handler", ExplicitId{}),
    B.get(Tag, "/outgoing", ExplicitId{}),
    B.get(Tag, "/id-echo", EchoId{}),
    B.get(Tag, "/timeout-outer", Slow{}),
    B.get(Tag, "/timeout-inner", Slow{}),
    B.get(Tag, "/duration", Hello{}),
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
