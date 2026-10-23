import Base
import ./servers/middleware.bend as App
import ../src/main.bend as B
import ../src/router/methods.bend as Methods
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/http/bytes.bend as Bytes

def assert(ok: Bool, label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit, 1, label)

def check(res: B.Res, code: U32, text: String) -> IO(Unit):
  Response.Res{status, headers, body, rep} = res
  assert(U32.is_eq(status, code) && String.eq(Bytes.ascii(body), text), "handle_with")

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(App.Tag)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "table build failed")
    case Done{+table}:
      do IO<Unit>:
        +counter : Chan(App.Message) <- Chan.new(App.Message, 128)
        IO.spawn(Unit, App.actor(counter, 0, App.Poll{}))
        res : B.Res <- B.handle_with(~App.Vars, ~App.Tag, ~App.Env, ~App.handler, ~App.global_middleware, table, App.Env{counter}, Request.Req{Request.Get{}, "/order", None{}, Request.Http11{}, []}, [])
        check(res, 200, "a-before,b-before,c-before,handler,c-after,b-after,a-after")
        head : B.Res <- B.handle_with(~App.Vars, ~App.Tag, ~App.Env, ~App.handler, ~App.global_middleware, table, App.Env{counter}, Request.Req{Request.Head{}, "/transform", None{}, Request.Http11{}, []}, [])
        check(head, 202, "")
        Chan.close(App.Message, counter)

def invalid(result: Result<&2, &2, Methods.BuildError, B.Routes(App.Tag)>) -> IO(Unit):
  match result:
    case Fail{Methods.InvalidPattern{1n, "bad", error}}: IO.print("PASS invalid middleware pattern index")
    case _: IO.die(Unit, 1, "invalid middleware pattern accepted")

def main() -> IO(Unit):
  do IO<Unit>:
    invalid(B.routes(App.Tag, [B.get(App.Tag, "/", App.Handler{}), B.use_path(App.Tag, "bad", App.User{})]))
    ready(B.routes(App.Tag, App.entries()))

