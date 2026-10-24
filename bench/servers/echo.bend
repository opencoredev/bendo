# POST /echo parses the JSON body and serializes it again (BND-67).
import Base
import ../../src/main.bend as B
import ../../src/data/json.bend as Json
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Echo{}

def reply(c: B.Ctx, parsed: Result<&2, &2, Json.Error, Json.Json>) -> B.Res:
  match parsed:
    case Fail{error}: B.error(c, B.http_error(400, "invalid JSON"))
    case Done{value}: B.json(c, value)

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  +c = ctx
  IO.pure(B.Res, reply(c, Json.parse(B.raw_body(c))))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.post(Tag, "/echo", Echo{})]))
