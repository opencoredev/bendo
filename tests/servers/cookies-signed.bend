import Base
import ../../src/main.bend as B
import ../../src/data/cookie.bend as C
import ../../src/data/signed-cookie.bend as S
import ../../src/router/methods.bend as Methods
import ../../src/http/response.bend as R

type Tag is Data:
  Read{}
  Write{}

def keys() -> S.Keys:
  S.Keys{"new-secret", ["old-secret"]}

def reply(result: Result<&2, &2, C.Error, B.Ctx>) -> B.Res:
  match result:
    case Fail{error}: R.text(400, "invalid")
    case Done{c}: B.text(c, "written")

def second(result: Result<&2, &2, C.Error, B.Ctx>) -> B.Res:
  match result:
    case Fail{error}: R.text(400, "invalid")
    case Done{c}: reply(B.set_signed_cookie(c, "session", "second", keys(), C.defaults()))

def response(tag: Tag, +c: B.Ctx) -> B.Res:
  match tag:
    case Read{}: B.text(c, Maybe.default(&2, String, B.signed_cookie(c, "session", keys()), "absent-or-invalid"))
    case Write{}: second(B.set_signed_cookie(B.header(B.status(c, 201), "x-kept", "yes"), "session", Maybe.default(&2, String, B.query(c, "value"), "hello"), keys(), C.Options{Some{"/"}, None{}, None{}, None{}, True{}, True{}, Some{C.Lax{}}, False{}}))

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, response(tag, c))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/", Write{}), B.get(Tag, "/read", Read{})]))
