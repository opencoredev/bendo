# BND-106: a buffered response's write deadline. /big and /slow answer an
# 8 MiB buffered body and record each run of their after-response hook on a
# channel; /count drains it and answers how many runs it held.
import Base
import ../../src/main.bend as B
import ../../src/app/config.bend as Config
import ../../src/app/context.bend as C
import ../../src/http/response.bend as Response
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Big{}
  Count{}
  Ping{}
  Observe{}

type Env is Data:
  Env{runs: Chan(Unit)}

def drained(fuel: Nat, +runs: Chan(Unit), n: U32, got: Poll<&1, &1, Maybe<&1, Unit>, Unit>) -> IO(U32):
  match fuel got:
    case 1n+f Ready{Some{u}}:
      do IO<U32>:
        next : Poll<&1, &1, Maybe<&1, Unit>, Unit> <- Chan.try_recv(Unit, runs, 0)
        drained(f, runs, (n + 1 : U32), next)
    case _ _: IO.pure(U32, n)

def count(+runs: Chan(Unit)) -> IO(U32):
  do IO<U32>:
    first : Poll<&1, &1, Maybe<&1, Unit>, Unit> <- Chan.try_recv(Unit, runs, 0)
    drained(64n, runs, 0, first)

def big() -> List<&2, U32>:
  List.replicate(U32, Nat.mul(8192n, 1024n), 120)

def counted(c: B.Context(Unit), env: Env) -> IO(B.Res):
  Env{runs} = env
  do IO<B.Res>:
    n : U32 <- count(runs)
    return C.text(Unit, c, U32.show(n))

def handler(tag: Tag, c: B.Context(Unit), env: Env) -> IO(B.Res):
  match tag:
    case Big{}: IO.pure(B.Res, Response.body(200, [], big()))
    case Count{}: counted(c, env)
    case Ping{}: IO.pure(B.Res, C.text(Unit, c, "pong"))
    case Observe{}: IO.pure(B.Res, C.text(Unit, c, "unused"))

def observed(path: String) -> Bool:
  match path:
    case "/big": True{}
    case "/slow": True{}
    case _: False{}

def record(c: B.Context(Unit), env: Env, next: B.Context(Unit) -> IO(B.Res), yes: Bool) -> IO(B.Res):
  Env{runs} = env
  match yes:
    case False{}: next(c)
    case True{}:
      do IO<B.Res>:
        sent : Poll<&1, &1, Result<&1, &1, Unit, Unit>, Unit> <- Chan.try_send(Unit, runs, Unit{}, 0)
        return C.text(Unit, c, "ignored")

def observing(tag: Tag, +c: B.Context(Unit), env: Env, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Observe{}: record(c, env, next, observed(C.path(Unit, c)))
    case _: next(c)

def middleware(tag: Tag, c: B.Context(Unit), env: Env, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  observing(tag, c, env, next)

def configured(config: Config.Config) -> Config.Config:
  Config.Config{host, port, limit, headers, idle, head, body, old, max, keep, router, mode, workers} = config
  Config.Config{host, port, limit, headers, idle, head, body, 1000, max, keep, router, mode, workers}

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "invalid routes")
    case Done{table}:
      do IO<Unit>:
        runs : Chan(Unit) <- Chan.new(Unit, 64)
        B.serve_with(~Unit, ~Tag, ~Env, ~handler, ~middleware, table, Env{runs}, configured(B.config()))

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.on_after_response(Tag, Observe{}),
    B.get(Tag, "/big", Big{}), B.get(Tag, "/slow", Big{}),
    B.get(Tag, "/count", Count{}), B.get(Tag, "/ping", Ping{})
  ]))
