import Base
import ../../../src/main.bend as B
import ../../../src/http/request.bend as Request
import ../../../src/http/response.bend as Response
import ../../../src/http/bytes.bend as Bytes
import ../../../src/router/methods.bend as Methods

type Tag is Data:
  Ok{}

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, B.text(ctx, "hello"))

def print_date(res: Response.Res) -> IO(Unit):
  Response.Res{status, hs, body, rep} = res
  IO.print(U32.show(status) ++ " " ++ Bytes.ascii(List.concat(&2, U32, Request.lookup(hs, "date"))))

def request(+table: B.Routes(Tag), path: String, query: Maybe<&2, String>) -> IO(Unit):
  do IO<Unit>:
    res : B.Res <- B.handle(~Tag, ~Unit, ~dispatch, table, Unit{}, Request.Req{Request.Get{}, path, query, Request.Http11{}, []}, [])
    print_date(res)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid date table")
    case Done{+table}:
      do IO<Unit>:
        request(table, "/", None{})
        request(table, "/missing", None{})
        request(table, "/", Some{"bad=%GG"})

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/", Ok{})]))
