# The signup API. POST /api/signup decodes the body with the same Bend schema
# the React form runs in the browser (shared/signup.bend), and answers 201 or
# 422 with the exact JSON the browser computes for the same text.
# BND-36's route validation is not on main yet, so the handler decodes.
import Base
import ../../../../../src/main.bend as B
import ./shared/signup.bend as Signup

type Tag is Data:
  SignupRoute{}
  Health{}

def respond(c: B.Ctx, +checked: Signup.Checked) -> B.Res:
  B.json(B.status(c, Signup.status(checked)), Signup.reply(checked))

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  match tag:
    case SignupRoute{}:
      +c = ctx
      IO.pure(B.Res, respond(c, Signup.check_body(B.raw_body(c))))
    case Health{}: IO.pure(B.Res, B.text(ctx, "ok"))

def ready(result: Result<&2, &2, B.RouteError(), B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}:
      B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())
    case Fail{error}:
      IO.die(Unit, 1, "invalid signup routes")

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.post(Tag, "/api/signup", SignupRoute{}), B.get(Tag, "/api/health", Health{})]))
