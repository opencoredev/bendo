# GET /json answers a small object serialized by Bendo's JSON writer (BND-67).
import Base
import ../../src/main.bend as B
import ../../src/data/json.bend as Json
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Message{}

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, B.json(c, Json.JObject{[Json.Field{"message", Json.JString{"Hello, world!"}}]}))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/json", Message{})]))
