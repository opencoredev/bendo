import Base
import ../../src/main.bend as B
import ../../src/data/cookie.bend as C
import ../../src/data/signed-cookie.bend as S
import ../../src/router/methods.bend as Methods
import ../../src/http/response.bend as R

type Tag is Data:
  Read{}
  Write{}
  BadRead{slot: Nat}
  BadWrite{slot: Nat}

def keys() -> S.Keys:
  S.Keys{"new-secret", ["old-secret"]}

# Built directly, bypassing configure: an empty secret in each slot position.
def unusable(slot: Nat) -> S.Keys:
  match slot:
    case 0n: S.Keys{"", ["new-secret"]}
    case 1n: S.Keys{"new-secret", ["", "old-secret"]}
    case 2n+p: S.Keys{"new-secret", ["old-secret", ""]}

def failed(error: C.Error) -> B.Res:
  match error:
    case C.InvalidSecret{}: R.text(500, "invalid-secret")
    case _: R.text(400, "invalid")

def written(result: Result<&2, &2, C.Error, B.Ctx>) -> B.Res:
  match result:
    case Fail{error}: failed(error)
    case Done{c}: B.text(c, "written")

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
    case BadRead{slot}: B.text(c, Maybe.default(&2, String, B.signed_cookie(c, "session", unusable(slot)), "absent-or-invalid"))
    case BadWrite{slot}: written(B.set_signed_cookie(c, "session", "hello", unusable(slot), C.defaults()))
    case Write{}: second(B.set_signed_cookie(B.header(B.status(c, 201), "x-kept", "yes"), "session", Maybe.default(&2, String, B.query(c, "value"), "hello"), keys(), C.Options{Some{"/"}, None{}, None{}, None{}, True{}, True{}, Some{C.Lax{}}, False{}}))

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, response(tag, c))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/", Write{}), B.get(Tag, "/read", Read{}), B.get(Tag, "/bad/0/read", BadRead{0n}), B.get(Tag, "/bad/1/read", BadRead{1n}), B.get(Tag, "/bad/2/read", BadRead{2n}), B.get(Tag, "/bad/0/write", BadWrite{0n}), B.get(Tag, "/bad/1/write", BadWrite{1n}), B.get(Tag, "/bad/2/write", BadWrite{2n})]))
