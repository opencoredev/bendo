import Base
import ../../src/main.bend as B
import ../../src/router/methods.bend as Methods
import ../../src/http/request.bend as Request
import ../../src/http/response.bend as Response

type Tag is Data:
  Ok{}
  Cached{}
  Explicit{}
  Large{}

def many(n: Nat, hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match n:
    case 0n: hs
    case 1n+p: many(p, Request.Header{"x", [97]} <> hs)

def response(tag: Tag, +ctx: B.Ctx) -> B.Res:
  match tag:
    case Large{}: Response.body(200, many(11000n, []), [104, 101, 108, 108, 111])
    case Ok{}: B.text(ctx, "hello")
    case Cached{}: B.not_modified([], None{})
    case Explicit{}: B.text(B.header(ctx, "Date", "Sun, 06 Nov 1994 08:49:37 GMT"), "explicit")

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, response(tag, ctx))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid date routes")
    case Done{table}: B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/", Ok{}), B.get(Tag, "/cached", Cached{}), B.get(Tag, "/explicit", Explicit{}), B.get(Tag, "/large", Large{})]))
