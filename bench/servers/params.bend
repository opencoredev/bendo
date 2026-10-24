# GET /user/:id reads the matched parameter from the context (BND-67).
import Base
import ../../src/main.bend as B
import ../../src/router/methods.bend as Methods

type Tag is Data:
  User{}

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  +c = ctx
  IO.pure(B.Res, B.text(c, "User " ++ Maybe.default(&2, String, B.param(c, "id"), "")))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/user/:id", User{})]))
