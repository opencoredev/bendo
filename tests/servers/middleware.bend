import Base
import ../../src/main.bend as B
import ../../src/app/context.bend as C
import ../../src/http/response.bend as Response
import ../../src/http/request.bend as Request
import ../../src/router/methods.bend as Methods

# The same Data sum supplies identifiers to both closed dispatchers.
type Tag is Data:
  Handler{}
  Count{}
  A{}
  BTag{}
  CTag{}
  Auth{}
  User{}
  Identity{}
  Transform{}
  Invalid{}

type Message is Data:
  Add{reply: Chan(U32)}
  Read{reply: Chan(U32)}

type Env is Data:
  Env{counter: Chan(Message)}

def send_ok(-A: Type, r: Result<&1, &1, A, Unit>) -> IO(Unit):
  match r:
    case Done{u}:
      IO.pure(Unit, Unit{})
    case Fail{e}:
      IO.die(Unit, 1, "counter send failed")

def take(got: Maybe<&1, U32>) -> IO(U32):
  match got:
    case Some{n}:
      IO.pure(U32, n)
    case None{}:
      IO.die(U32, 1, "counter reply channel closed")

type ActorStep is Type:
  Poll{}
  MessageReady{message: Maybe<&1, Message>}

@unsafe
def actor(+chan: Chan(Message), +count: U32, step: ActorStep) -> IO(Unit):
  match step:
    case Poll{}:
      do IO<Unit>:
        msg : Maybe<&1, Message> <- Chan.recv(Message, chan)
        actor(chan, count, MessageReady{msg})
    case MessageReady{None{}}:
      IO.pure(Unit, Unit{})
    case MessageReady{Some{Add{reply}}}:
      do IO<Unit>:
        sent : Result<&1, &1, U32, Unit> <- Chan.send(U32, reply, (count + 1 : U32))
        send_ok(U32, sent)
        actor(chan, (count + 1 : U32), Poll{})
    case MessageReady{Some{Read{reply}}}:
      do IO<Unit>:
        sent : Result<&1, &1, U32, Unit> <- Chan.send(U32, reply, count)
        send_ok(U32, sent)
        actor(chan, count, Poll{})

def ask_send(chan: Chan(Message), +reply: Chan(U32), read: Bool) -> IO(U32):
  match read:
    case True{}:
      do IO<U32>:
        sent : Result<&1, &1, Message, Unit> <- Chan.send(Message, chan, Read{reply})
        send_ok(Message, sent)
        got : Maybe<&1, U32> <- Chan.recv(U32, reply)
        Chan.close(U32, reply)
        take(got)
    case False{}:
      do IO<U32>:
        sent : Result<&1, &1, Message, Unit> <- Chan.send(Message, chan, Add{reply})
        send_ok(Message, sent)
        got : Maybe<&1, U32> <- Chan.recv(U32, reply)
        Chan.close(U32, reply)
        take(got)

def ask(+chan: Chan(Message), read: Bool) -> IO(U32):
  do IO<U32>:
    +reply : Chan(U32) <- Chan.new(U32, 1)
    ask_send(chan, reply, read)

type Vars is Data:
  Vars{trace: String, user: String}

def values(c: B.Context(Vars)) -> Vars:
  Maybe.default(&2, Vars, C.get(Vars, c), Vars{"", "unset"})

def before_vars(c: B.Context(Vars), label: String, vars: Vars) -> B.Context(Vars):
  Vars{trace, user} = vars
  C.set(Vars, c, Vars{trace ++ label ++ "-before,", user})

def before(+c: B.Context(Vars), label: String) -> B.Context(Vars):
  before_vars(c, label, values(c))

def after(res: B.Res, label: String) -> B.Res:
  Response.Res{code, hs, body, rep} = res
  +out = List.append(&2, U32, body, Response.utf8("," ++ label ++ "-after"))
  Response.Res{code, Request.Header{"x-order", out} <> C.without(hs, "x-order"), out, rep}

def handler_text(trace: String, user: String) -> String:
  match trace:
    case "": "handler:" ++ user
    case _: trace ++ "handler"

def handler_vars(c: B.Context(Vars), vars: Vars) -> IO(B.Res):
  Vars{trace, user} = vars
  IO.pure(B.Res, C.text(Vars, C.header(Vars, c, "x-handler", "ran"), handler_text(trace, user)))

def handler(tag: Tag, c: B.Context(Vars), env: Env) -> IO(B.Res):
  match tag:
    case Count{}:
      Env{counter} = env
      do IO<B.Res>:
        count : U32 <- ask(counter, True{})
        return C.text(Vars, c, U32.show(count))
    case _:
      Env{counter} = env
      do IO<B.Res>:
        count : U32 <- ask(counter, False{})
        +ctx : B.Context(Vars) = c
        handler_vars(ctx, values(ctx))

def set_user_vars(c: B.Context(Vars), vars: Vars) -> B.Context(Vars):
  Vars{trace, old} = vars
  C.set(Vars, c, Vars{trace, "Ada"})

def set_user(+c: B.Context(Vars)) -> B.Context(Vars):
  set_user_vars(c, values(c))

def auth(c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res), allowed: Maybe<&2, String>) -> IO(B.Res):
  match allowed:
    case Some{"yes"}: next(c)
    case _: IO.pure(B.Res, C.text(Vars, C.status(Vars, c, 401), "denied"))

def transform(res: B.Res) -> B.Res:
  Response.Res{code, hs, body, rep} = res
  Response.Res{202, Request.Header{"x-transformed", Response.utf8("yes")} <> hs, List.append(&2, U32, body, Response.utf8("!")), rep}

def invalid(res: B.Res) -> B.Res:
  Response.Res{code, hs, body, rep} = res
  Response.Res{code, Request.Header{"bad name", []} <> hs, body, rep}

def middleware(tag: Tag, +c: B.Context(Vars), env: Env, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case A{}:
      do IO<B.Res>:
        res : B.Res <- next(before(c, "a"))
        return after(res, "a")
    case BTag{}:
      do IO<B.Res>:
        res : B.Res <- next(before(c, "b"))
        return after(res, "b")
    case CTag{}:
      do IO<B.Res>:
        res : B.Res <- next(before(c, "c"))
        return after(res, "c")
    case Auth{}: auth(c, next, C.request_header(Vars, c, "x-auth"))
    case User{}: next(set_user(c))
    case Identity{}: next(c)
    case Transform{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return transform(res)
    case Invalid{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return invalid(res)
    case Handler{}: next(c)
    case Count{}: next(c)

# Global middleware is observable on misses, too.
def global_middleware(tag: Tag, c: B.Context(Vars), env: Env, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  middleware(tag, C.header(Vars, c, "x-middleware", "yes"), env, next)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid middleware routes")
    case Done{table}:
      do IO<Unit>:
        +counter : Chan(Message) <- Chan.new(Message, 128)
        IO.spawn(Unit, actor(counter, 0, Poll{}))
        B.serve_with(~Vars, ~Tag, ~Env, ~handler, ~global_middleware, table, Env{counter}, B.config())

def entries() -> List<&2, B.Registration(Tag)>:
  [
    B.use(Tag, Identity{}),
    B.get(Tag, "/__count", Count{}),
    B.use_path(Tag, "/order", A{}),
    B.use_path(Tag, "/order", Identity{}),
    B.get(Tag, "/order", Handler{}),
    B.use_path(Tag, "/order", BTag{}),
    B.use_path(Tag, "/order", CTag{}),
    B.use_path(Tag, "/private/*", Auth{}),
    B.use_path(Tag, "/private/*", User{}),
    B.get(Tag, "/private/hello", Handler{}),
    B.use_path(Tag, "/transform", Transform{}),
    B.get(Tag, "/transform", Handler{}),
    B.use_path(Tag, "/bad", Invalid{}),
    B.get(Tag, "/bad", Handler{}),
    B.use_path(Tag, "/users/:id{int}", User{}),
    B.get(Tag, "/users/:id", Handler{}),
    B.use_path(Tag, "/optional/:name?", User{}),
    B.get(Tag, "/optional/*", Handler{}),
    B.route(Tag, Methods.get(Tag, "/plain", Handler{}))
  ]

def main() -> IO(Unit):
  ready(B.routes(Tag, entries()))
