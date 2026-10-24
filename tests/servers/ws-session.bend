import Base
import ../../src/main.bend as B
import ../../src/ws/connection.bend as W
import ../../src/ws/message.bend as M
import ../../src/app/store.bend as Store
import ../../src/app/context.bend as C
import ../../src/router/methods.bend as Methods

type Shared is Data:
  Shared{handle: Store.Store<Maybe<&2, W.Handle>>, closed: Store.Store<String>}

type User is Data:
  User{path: String, shared: Shared}

type Route is Data:
  EchoRoute{}
  PushRoute{}
  ClosedRoute{}
  HealthRoute{}

def flag(ok: Bool) -> String:
  match ok:
    case True{}: "yes"
    case False{}: "no"

def open_result(path: String, user: User, +handle: W.Handle, log: Store.Store<String>) -> IO(User):
  match path:
    case "/burst":
      do IO<User>:
        first : Bool <- W.text(handle, "one")
        second : Bool <- W.text(handle, "two")
        saved : Result<&2, &2, Store.Error, Unit> <- Store.set(String, log, flag(first) ++ ":" ++ flag(second))
        return user
    case _: IO.pure(User, user)

def opened_copy(+user: User, +handle: W.Handle) -> IO(User):
  User{path, Shared{registry, closed}} = user
  do IO<User>:
    saved : Result<&2, &2, Store.Error, Unit> <- Store.set(Maybe<&2, W.Handle>, registry, Some{handle})
    open_result(path, user, handle, closed)

def opened(user: User, handle: W.Handle) -> IO(User):
  opened_copy(user, handle)

def text_message(+user: User, handle: W.Handle, +text: String, close: Bool) -> IO(User):
  match close:
    case True{}:
      do IO<User>:
        ok : Bool <- W.close(handle, 1000, "server bye")
        return user
    case False{}:
      do IO<User>:
        ok : Bool <- W.text(handle, text)
        return user

def message(user: User, handle: W.Handle, message: M.Message) -> IO(User):
  match message:
    case M.TextMessage{+text}: text_message(user, handle, text, String.eq(text, "server-close"))
    case M.BinaryMessage{bytes}:
      do IO<User>:
        ok : Bool <- W.binary(handle, bytes)
        return user
    case _: IO.pure(User, user)

def closed(user: User, code: U32, reason: String) -> IO(Unit):
  User{path, Shared{registry, log}} = user
  do IO<Unit>:
    saved : Result<&2, &2, Store.Error, Unit> <- Store.set(String, log, U32.show(code) ++ ":" ++ reason)
    return Unit{}

def session_config(path: String) -> W.Config:
  match path:
    case "/slow-poll": W.Config{1048576, 16, 60000, 0, 0, 100, 1000}
    case "/autobahn": W.Config{16777216, 16, 10, 0, 0, 1000, 30000}
    case "/burst": W.Config{8, 1, 5, 60000, 0, 100, 1000}
    case "/fast-ping": W.Config{1048576, 16, 5, 5000, 1, 100, 1000}
    case "/small": W.Config{8, 2, 5, 60000, 0, 100, 1000}
    case "/idle": W.Config{1048576, 16, 5, 100, 0, 100, 1000}
    case "/ping": W.Config{1048576, 16, 5, 5000, 50, 100, 1000}
    case _: W.Config{1048576, 16, 5, 60000, 0, 200, 1000}

def push_result(ok: Bool, c: B.Context(Unit)) -> B.Res:
  match ok:
    case True{}: B.text(c, "sent")
    case False{}: B.text(c, "rejected")

def push(c: B.Context(Unit), got: Result<&2, &2, Store.Error, Maybe<&2, W.Handle>>) -> IO(B.Res):
  match got:
    case Done{Some{handle}}:
      do IO<B.Res>:
        ok : Bool <- W.text(handle, "from HTTP")
        return push_result(ok, c)
    case _: IO.pure(B.Res, B.text(c, "unavailable"))

def log_result(c: B.Context(Unit), got: Result<&2, &2, Store.Error, String>) -> B.Res:
  match got:
    case Done{text}: B.text(c, text)
    case Fail{e}: B.text(c, "unavailable")

@unsafe
def handler(route: Route, +c: B.Context(Unit), +shared: Shared) -> IO(B.Res):
  match route shared:
    case EchoRoute{} _:
      B.websocket_handlers(~Unit, ~User, ~opened, ~message, ~closed, c, User{C.path(Unit, c), shared}, B.websocket_config(), session_config(C.path(Unit, c)))
    case PushRoute{} Shared{registry, log}:
      do IO<B.Res>:
        got : Result<&2, &2, Store.Error, Maybe<&2, W.Handle>> <- Store.get(Maybe<&2, W.Handle>, registry)
        push(c, got)
    case ClosedRoute{} Shared{registry, log}:
      do IO<B.Res>:
        got : Result<&2, &2, Store.Error, String> <- Store.get(String, log)
        return log_result(c, got)
    case HealthRoute{} _: IO.pure(B.Res, B.text(c, "ok"))

@unsafe
def dispatch(route: Route, c: B.Context(Unit), shared: Shared) -> IO(B.Res):
  handler(route, c, shared)

@unsafe
def ready(shared: Shared, result: Result<&2, &2, Methods.BuildError, B.Routes(Route)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "routes")
    case Done{routes}: B.serve(~Route, ~Shared, ~dispatch, routes, shared, B.config())

@unsafe
def main() -> IO(Unit):
  do IO<Unit>:
    registry : Store.Store<Maybe<&2, W.Handle>> <- B.store_with_timeout(Maybe<&2, W.Handle>, None{}, 1000)
    log : Store.Store<String> <- B.store_with_timeout(String, "", 1000)
    ready(Shared{registry, log}, B.routes(Route, [B.get(Route, "/", HealthRoute{}), B.get(Route, "/push", PushRoute{}), B.get(Route, "/closed", ClosedRoute{}), B.get(Route, "/ws", EchoRoute{}), B.get(Route, "/small", EchoRoute{}), B.get(Route, "/idle", EchoRoute{}), B.get(Route, "/ping", EchoRoute{}), B.get(Route, "/fast-ping", EchoRoute{}), B.get(Route, "/burst", EchoRoute{}), B.get(Route, "/autobahn", EchoRoute{}), B.get(Route, "/slow-poll", EchoRoute{})]))
