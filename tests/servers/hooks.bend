import Base
import ../../src/main.bend as B
import ../../src/app/context.bend as C
import ../../src/http/request.bend as Request
import ../../src/http/response.bend as Response
import ../../src/router/methods.bend as Methods
import ../../src/data/utf8.bend as Utf8

type Tag is Data:
  Handler{}
  Release{}
  Completed{}
  Request1{}
  Request2{}
  Parse{}
  Transform{}
  Before{}
  After1{}
  After2{}
  Map1{}
  Map2{}
  Error1{}
  Error2{}
  Observe1{}
  Observe2{}
  PathMiddleware{}

type Vars is Data:
  Vars{trace: String, parsed: String}

type Env is Data:
  Env{gate: Chan(Unit), observed: Chan(String), completed: Chan(String)}

def values(c: B.Context(Vars)) -> Vars:
  Maybe.default(&2, Vars, C.get(Vars, c), Vars{"", ""})

def append_vars(c: B.Context(Vars), label: String, vars: Vars) -> B.Context(Vars):
  Vars{trace, parsed} = vars
  C.set(Vars, c, Vars{trace ++ label ++ ",", parsed})

def mark(+c: B.Context(Vars), label: String) -> B.Context(Vars):
  append_vars(c, label, values(c))

def trace(c: B.Context(Vars), vars: Vars, label: String) -> B.Res:
  Vars{trace, parsed} = vars
  C.text(Vars, c, trace ++ label)

def respond(+c: B.Context(Vars), label: String) -> B.Res:
  trace(c, values(c), label)

def append(res: B.Res, label: String) -> B.Res:
  Response.Res{code, hs, body, rep} = res
  Response.Res{code, hs, List.append(&2, U32, body, Response.utf8("," ++ label)), rep}

def code(res: B.Res, status: U32) -> B.Res:
  Response.Res{old, hs, body, rep} = res
  Response.Res{status, hs, body, rep}

def mapped(res: B.Res, parsed: String) -> B.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{status, Request.Header{"x-transformed", Response.utf8(parsed)} <> Request.Header{"content-type", Response.utf8("application/x-hooks")} <> C.without(hs, "content-type"), body, rep}

def parsed_value(vars: Vars) -> String:
  Vars{trace, parsed} = vars
  parsed

def send_ok(-A: Type, result: Result<&1, &1, A, Unit>) -> IO(Unit):
  match result:
    case Done{u}: IO.pure(Unit, Unit{})
    case Fail{e}: IO.die(Unit, 1, "fixture channel closed")

def completed(c: B.Context(Vars), result: Maybe<&1, String>) -> B.Res:
  match result:
    case Some{s}: C.text(Vars, c, s)
    case None{}: C.text(Vars, C.status(Vars, c, 500), "channel closed")

def handle_path(+c: B.Context(Vars), path: String) -> B.Res:
  match path:
    case "/error": respond(C.status(Vars, c, 500), "handler")
    case "/after-error-gate": respond(C.status(Vars, c, 500), "handler")
    case _: respond(c, "handler")

def handler_impl(tag: Tag, +c: B.Context(Vars), env: Env) -> IO(B.Res):
  match tag:
    case Release{}:
      Env{gate, observed, done} = env
      do IO<B.Res>:
        sent : Result<&1, &1, Unit, Unit> <- Chan.send(Unit, gate, Unit{})
        send_ok(Unit, sent)
        return C.text(Vars, c, "released")
    case Completed{}:
      Env{gate, observed, done} = env
      do IO<B.Res>:
        result : Maybe<&1, String> <- Chan.recv(String, done)
        return completed(c, result)
    case _:
      IO.pure(B.Res, handle_path(c, C.path(Vars, c)))

def request1(+c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res), path: String) -> IO(B.Res):
  match path:
    case "/request-stop": IO.pure(B.Res, respond(c, "request1"))
    case "/request-error": IO.pure(B.Res, respond(C.status(Vars, c, 500), "request1"))
    case "/rewrite": next(mark(C.rewrite(Vars, c, Request.Post{}, "/order"), "request1"))
    case _: next(mark(c, "request1"))

def parse_body(c: B.Context(Vars), vars: Vars, decoded: Maybe<&2, String>) -> B.Context(Vars):
  Vars{trace, old} = vars
  match decoded:
    case Some{body}: C.set(Vars, c, Vars{trace ++ "parse,", body})
    case None{}: C.status(Vars, c, 400)

def parsed(+c: B.Context(Vars)) -> B.Context(Vars):
  parse_body(c, values(c), Utf8.decode(C.raw_body(Vars, c)))

def transformed(c: B.Context(Vars), vars: Vars) -> B.Context(Vars):
  Vars{trace, +parsed} = vars
  C.set(Vars, C.header(Vars, c, "x-parsed", parsed), Vars{trace ++ "transform,", parsed ++ "!"})

def before(+c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res), path: String) -> IO(B.Res):
  match path:
    case "/before-stop": IO.pure(B.Res, respond(c, "before"))
    case "/before-error": IO.pure(B.Res, respond(C.status(Vars, c, 500), "before"))
    case _: next(mark(c, "before"))

def map_error(res: B.Res, path: String) -> B.Res:
  match path:
    case "/map-error": code(res, 500)
    case _: res

def gated(path: String) -> Bool:
  match path:
    case "/after-gate": True{}
    case "/after-error-gate": True{}
    case _: False{}

def observe1(c: B.Context(Vars), env: Env, next: B.Context(Vars) -> IO(B.Res), gate_path: Bool) -> IO(B.Res):
  Env{gate, observed, done} = env
  match gate_path:
    case False{}: next(c)
    case True{}:
      do IO<B.Res>:
        released : Maybe<&1, Unit> <- Chan.recv(Unit, gate)
        sent : Result<&1, &1, String, Unit> <- Chan.send(String, observed, "after-response1")
        send_ok(String, sent)
        return C.text(Vars, c, "must never replace sent bytes")

def observe2(c: B.Context(Vars), env: Env, next: B.Context(Vars) -> IO(B.Res), gate_path: Bool) -> IO(B.Res):
  Env{gate, observed, done} = env
  match gate_path:
    case False{}: next(c)
    case True{}:
      do IO<B.Res>:
        first : Maybe<&1, String> <- Chan.recv(String, observed)
        sent : Result<&1, &1, String, Unit> <- Chan.send(String, done, Maybe.default(&1, String, first, "missing") ++ ",after-response2")
        send_ok(String, sent)
        return C.text(Vars, c, "ignored too")

def middleware_impl(tag: Tag, +c: B.Context(Vars), env: Env, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Request1{}: request1(c, next, C.path(Vars, c))
    case Request2{}: next(mark(c, "request2"))
    case Parse{}: next(parsed(c))
    case Transform{}: next(transformed(c, values(c)))
    case Before{}: before(c, next, C.path(Vars, c))
    case After1{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return append(res, "after1")
    case After2{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return append(res, "after2")
    case Map1{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return map_error(mapped(append(res, "map1"), parsed_value(values(c))), C.path(Vars, c))
    case Map2{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return append(res, "map2")
    case Error1{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return code(append(res, "error1"), 202)
    case Error2{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return append(res, "error2")
    case Observe1{}: observe1(c, env, next, gated(C.path(Vars, c)))
    case Observe2{}: observe2(c, env, next, gated(C.path(Vars, c)))
    case PathMiddleware{}: next(C.header(Vars, c, "x-path-middleware", "yes"))
    case _: next(c)

def handler(tag: Tag, c: B.Context(Vars), env: Env) -> IO(B.Res):
  handler_impl(tag, c, env)

def middleware_path(tag: Tag, c: B.Context(Vars), env: Env, next: B.Context(Vars) -> IO(B.Res), path: String) -> IO(B.Res):
  match path:
    case "/release": next(c)
    case "/completed": next(c)
    case _: middleware_impl(tag, c, env, next)

def middleware(tag: Tag, +c: B.Context(Vars), env: Env, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  middleware_path(tag, c, env, next, C.path(Vars, c))

def middleware_dispatch(tag: Tag, c: B.Context(Vars), env: Env, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  middleware(tag, c, env, next)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "invalid routes")
    case Done{table}:
      do IO<Unit>:
        gate : Chan(Unit) <- Chan.new(Unit, 1)
        observed : Chan(String) <- Chan.new(String, 1)
        done : Chan(String) <- Chan.new(String, 1)
        B.serve_with(~Vars, ~Tag, ~Env, ~handler, ~middleware_dispatch, table, Env{gate, observed, done}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.map_response(Tag, Map1{}), B.on_after_response(Tag, Observe1{}),
    B.after_handle(Tag, After1{}), B.before_handle(Tag, Before{}),
    B.on_error(Tag, Error1{}), B.on_transform(Tag, Transform{}),
    B.on_request(Tag, Request1{}), B.on_parse(Tag, Parse{}),
    B.on_request(Tag, Request2{}), B.map_response(Tag, Map2{}),
    B.after_handle(Tag, After2{}), B.on_error(Tag, Error2{}),
    B.on_after_response(Tag, Observe2{}), B.use_path(Tag, "/order", PathMiddleware{}),
    B.get(Tag, "/release", Release{}), B.get(Tag, "/completed", Completed{}),
    B.post(Tag, "/order", Handler{}), B.get(Tag, "/*", Handler{})
  ]))
