import Base
import ../../src/main.bend as B
import ../../src/http/response.bend as Response
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Handler{}
  Finished{}
  Health{}
  Timeout{}
  Delay{}

def signal(result: Result<&1, &1, Unit, Unit>) -> IO(Unit):
  match result:
    case Done{u}: IO.pure(Unit, Unit{})
    case Fail{e}: IO.die(Unit, 1, "completion channel closed")

def handler(tag: Tag, c: B.Ctx, +done: Chan(Unit)) -> IO(B.Res):
  match tag:
    case Health{}: IO.pure(B.Res, B.text(c, "healthy"))
    case Finished{}:
      do IO<B.Res>:
        got : Maybe<&1, Unit> <- Chan.recv(Unit, done)
        return B.text(c, "late completed")
    case _:
      do IO<B.Res>:
        sent : Result<&1, &1, Unit, Unit> <- Chan.send(Unit, done, Unit{})
        signal(sent)
        return B.text(c, "handler")

def timed(result: Maybe<&1, B.Res>) -> B.Res:
  match result:
    case None{}: Response.text(504, "timed-out")
    case Some{res}: res

def placement(tag: Tag, c: B.Ctx, next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Timeout{}:
      do IO<B.Res>:
        result : Maybe<&1, B.Res> <- IO.within(B.Res, 1, next(c))
        return timed(result)
    case Delay{}:
      do IO<B.Res>:
        IO.sleep(100)
        next(c)
    case _: next(c)

def selected(tag: Tag, c: B.Ctx, next: B.Ctx -> IO(B.Res), path: String) -> IO(B.Res):
  match path:
    case "/late": placement(tag, c, next)
    case _: next(c)

def middleware(tag: Tag, +c: B.Ctx, env: Chan(Unit), next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  selected(tag, c, next, B.path(c))

def handle(tag: Tag, c: B.Ctx, done: Chan(Unit)) -> IO(B.Res):
  handler(tag, c, done)

def dispatch(tag: Tag, c: B.Ctx, env: Chan(Unit), next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  middleware(tag, c, env, next)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "routes")
    case Done{table}:
      do IO<Unit>:
        done : Chan(Unit) <- Chan.new(Unit, 1)
        B.serve_with(~Unit, ~Tag, ~Chan(Unit), ~handle, ~dispatch, table, done, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.on_request(Tag, Timeout{}), B.before_handle(Tag, Delay{}), B.get(Tag, "/", Health{}), B.get(Tag, "/late-done", Finished{}), B.get(Tag, "/*", Handler{})]))
