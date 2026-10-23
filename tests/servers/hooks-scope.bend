import Base
import ../../src/main.bend as B
import ../../src/app/table.bend as T
import ../../src/app/context.bend as C
import ../../src/router/methods.bend as M
import ../../src/http/response.bend as R
import ../../src/http/request.bend as Req

type Tag is Data:
  Handler{}
  Trace{label: String}
  PostTrace{label: String}
  Rewrite{}
  RewriteLate{}
  Stop{}
  Observe{}
  Events{}

type Env is Data:
  Env{events: Chan(String)}

type Vars is Data:
  Vars{trace: String}

def trace(value: Maybe<&2, Vars>) -> String:
  match value:
    case None{}: ""
    case Some{Vars{text}}: text

def add(+c: B.Context(Vars), label: String) -> B.Context(Vars):
  C.set(Vars, c, Vars{trace(C.get(Vars, c)) ++ label ++ ","})

def append(res: B.Res, label: String) -> B.Res:
  R.Res{code, hs, body, rep} = res
  R.Res{code, hs, List.append(&2, U32, body, R.utf8("," ++ label)), rep}

def handled(+c: B.Context(Vars)) -> IO(B.Res):
  IO.pure(B.Res, C.text(Vars, c, trace(C.get(Vars, c)) ++ "handler"))

def event(c: B.Context(Vars), value: Maybe<&1, String>) -> IO(B.Res):
  match value:
    case Some{text}: IO.pure(B.Res, C.text(Vars, c, text))
    case None{}: IO.die(B.Res, 1, "event slot closed")

def handler_status(+c: B.Context(Vars), path: String) -> IO(B.Res):
  match path:
    case "/stages-error": handled(C.status(Vars, c, 403))
    case _: handled(c)

def handler_path(+c: B.Context(Vars)) -> IO(B.Res):
  handler_status(c, C.path(Vars, c))

def handler(tag: Tag, c: B.Context(Vars), env: Env) -> IO(B.Res):
  match tag:
    case Events{}:
      Env{events} = env
      do IO<B.Res>:
        value : Maybe<&1, String> <- Chan.recv(String, events)
        event(c, value)
    case _: handler_path(c)

def rewrite(+c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res), path: String) -> IO(B.Res):
  match path:
    case "/rewrite-in": next(C.rewrite(Vars, c, Req.Get{}, "/g/a"))
    case "/g/rewrite-out": next(C.rewrite(Vars, c, Req.Get{}, "/outside"))
    case _: next(c)

def middleware_impl(tag: Tag, +c: B.Context(Vars), env: Env, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Trace{label}: next(add(c, label))
    case PostTrace{label}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return append(res, label)
    case Rewrite{}: rewrite(c, next, C.path(Vars, c))
    case RewriteLate{}: next(C.rewrite(Vars, c, Req.Post{}, "/outside"))
    case Stop{}: IO.pure(B.Res, C.text(Vars, c, trace(C.get(Vars, c)) ++ "stopped"))
    case Handler{}: next(c)
    case Events{}: next(c)
    case Observe{}:
      Env{events} = env
      do IO<B.Res>:
        sent : Result<&1, &1, String, Unit> <- Chan.send(String, events, C.path(Vars, c))
        next(c)

def middleware(tag: Tag, c: B.Context(Vars), env: Env, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  middleware_impl(tag, c, env, next)

def hooks(label: String) -> List<&2, B.Hook(Tag)>:
  [B.hook(Tag, T.BeforeHandle{}, Trace{label})]

def group_entries() -> List<&2, B.Registration(Tag)>:
  List.concat(&2, B.Registration(Tag), [
    [B.get(Tag, "/a", Handler{}), B.get(Tag, "/b", Handler{}), B.get(Tag, "/rewrite-out", Handler{})],
    B.guard(Tag, B.guard_options(Tag, hooks("guard")), [
      B.get(Tag, "/guard-a", Handler{}),
      B.route_hooks(Tag, M.get(Tag, "/guard-b", Handler{}), [B.hook(Tag, T.BeforeHandle{}, Trace{"local"}), B.hook(Tag, T.BeforeHandle{}, Trace{"local"})]),
      B.route_hooks(Tag, M.get(Tag, "/late", Handler{}), [B.hook(Tag, T.BeforeHandle{}, RewriteLate{})]),
      B.route_hooks(Tag, M.get(Tag, "/stop", Handler{}), [B.hook(Tag, T.BeforeHandle{}, Stop{})]),
      B.route_hooks(Tag, M.get(Tag, "/request-stop", Handler{}), [B.hook(Tag, T.Request{}, Stop{})])]),
    [B.get(Tag, "/guard-a", Handler{}), B.post(Tag, "/guard-a", Handler{})]])

def entries() -> List<&2, B.Registration(Tag)>:
  List.concat(&2, B.Registration(Tag), [
    [B.on_request(Tag, Rewrite{}), B.before_handle(Tag, Trace{"global1"})],
    B.group(Tag, "/g", [B.hook(Tag, T.Request{}, Trace{"group-request"}), B.hook(Tag, T.BeforeHandle{}, Trace{"group"}), B.hook(Tag, T.AfterHandle{}, PostTrace{"group-after"})], group_entries()),
    B.guard(Tag, B.guard_options(Tag, hooks("root-guard")), [B.get(Tag, "/members/:id", Handler{}), B.get(Tag, "/other", Handler{})]),
    [B.post(Tag, "/members/:id", Handler{}), B.get(Tag, "/outside", Handler{}), B.get(Tag, "/g-prefix", Handler{}), B.before_handle(Tag, Trace{"global2"})],
    B.group(Tag, "/nested/", hooks("outer"), B.group(Tag, "/inner", hooks("inner"), [B.get(Tag, "/item", Handler{})])),
    B.group(Tag, "/declared", [], [B.before_handle(Tag, Trace{"declared"}), B.get(Tag, "/item", Handler{})]),
    [B.get(Tag, "/duplicate", Handler{}), B.get(Tag, "/events", Events{})],
    B.guard(Tag, B.guard_options(Tag, [
      B.hook(Tag, T.Request{}, Trace{"request"}),
      B.hook(Tag, T.Parse{}, Trace{"parse"}),
      B.hook(Tag, T.Transform{}, Trace{"transform"}),
      B.hook(Tag, T.BeforeHandle{}, Trace{"before"}),
      B.hook(Tag, T.AfterHandle{}, PostTrace{"after"}),
      B.hook(Tag, T.MapResponse{}, PostTrace{"map"}),
      B.hook(Tag, T.Error{}, PostTrace{"error"}),
      B.hook(Tag, T.AfterResponse{}, Observe{})]), [B.get(Tag, "/stages", Handler{}), B.get(Tag, "/stages-error", Handler{})]),
    B.guard(Tag, B.guard_options(Tag, hooks("shadowed")), [B.get(Tag, "/duplicate", Handler{})])])

def ready(result: Result<&2, &2, M.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "bad scope table")
    case Done{table}:
      do IO<Unit>:
        events : Chan(String) <- Chan.new(String, 128)
        B.serve_with(~Vars, ~Tag, ~Env, ~handler, ~middleware, table, Env{events}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, entries()))
