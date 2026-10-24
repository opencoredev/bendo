import Base
import ../../src/main.bend as B
import ../../src/data/cookie.bend as C
import ../../src/router/methods.bend as Methods
import ../../src/http/response.bend as R

type Tag is Data:
  Read{}
  First{}
  Write{}
  Invalid{}

def entries(xs: List<&2, C.Entry>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case C.Entry{k, v} <> tail: C.serialize_pair(k, v) <> entries(tail)

def reply(result: Result<&2, &2, C.Error, B.Ctx>) -> B.Res:
  match result:
    case Fail{error}: R.text(400, "invalid")
    case Done{c}: B.text(c, "written")

def all_options() -> C.Options:
  C.Options{Some{"/account"}, Some{"example.com"}, Some{C.Seconds{3600n}}, Some{"Wed, 21 Oct 2015 07:28:00 GMT"}, True{}, True{}, Some{C.NoRestriction{}}, True{}}

def second(result: Result<&2, &2, C.Error, B.Ctx>) -> B.Res:
  match result:
    case Fail{error}: R.text(500, "unexpected error")
    case Done{c}: reply(B.delete_cookie(c, "old", all_options()))

def multiple(result: Result<&2, &2, C.Error, B.Ctx>) -> B.Res:
  match result:
    case Fail{error}: R.text(500, "unexpected error")
    case Done{c}: second(B.set_cookie(c, "other", "two", C.Options{None{}, None{}, Some{C.NegativeSeconds{1n}}, None{}, False{}, False{}, Some{C.Lax{}}, False{}}))

def write(+c: B.Ctx, mode: String) -> B.Res:
  match mode:
    case "all": multiple(B.set_cookie(B.header(B.status(c, 201), "x-kept", "yes"), "session", "abc=123", all_options()))
    case "strict": reply(B.set_cookie(c, "session", "strict", C.Options{Some{"/"}, None{}, None{}, None{}, False{}, True{}, Some{C.Strict{}}, False{}}))
    case "none": reply(B.set_cookie(c, "session", "none", C.Options{None{}, None{}, None{}, None{}, True{}, False{}, Some{C.NoRestriction{}}, False{}}))
    case _: reply(B.set_cookie(c, "session", "raw%20+", C.defaults()))

def response(tag: Tag, +c: B.Ctx) -> B.Res:
  match tag:
    case Read{}: B.text(c, String.join(entries(B.cookies(c)), "|"))
    case First{}: B.text(c, Maybe.default(&2, String, B.cookie(c, "a"), "absent"))
    case Write{}: write(c, Maybe.default(&2, String, B.query(c, "mode"), "default"))
    case Invalid{}: reply(B.set_cookie(c, "session", Maybe.default(&2, String, B.query(c, "value"), "bad;value"), C.defaults()))

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, response(tag, c))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/", Write{}), B.get(Tag, "/read", Read{}), B.get(Tag, "/first", First{}), B.get(Tag, "/invalid", Invalid{})]))
