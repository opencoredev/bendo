import Base
import ../../src/main.bend as B
import ../../src/app/context.bend as C
import ../../src/router/methods.bend as Methods
import ../../src/http/request.bend as Request
import ../../src/data/json.bend as Json

type Tag is Data:
  TParam{}
  TQuery{}
  TQueries{}
  THeader{}
  THeaderBytes{}
  TMethod{}
  TPath{}
  TUrl{}
  TText{}
  THtml{}
  TJsonValue{}
  TInvalidJson{}
  TBody{}
  TUntypedBody{}
  TEcho{}
  TRedirect{}
  TRedirectCode{}
  TBadLocation{}
  TBadRedirect{}
  TMissing{}
  TState{}
  TBadHeader{}
  TBadName{}
  TBadStatus{}
  TSetVar{}
  TUnsetVar{}

type Vars is Data:
  Vars{user: String, count: U32}

def optional(s: Maybe<&2, String>) -> String:
  Maybe.default(&2, String, s, "<none>")

def user(s: Maybe<&2, Vars>) -> String:
  match s:
    case None{}: "unset"
    case Some{Vars{name, count}}: name ++ ":" ++ U32.show(count)

def byte_text(xs: List<&2, U32>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case b <> t: U32.show(b) <> byte_text(t)

def headers_text(xs: List<&2, List<&2, U32>>) -> String:
  match xs:
    case Nil{}: "absent"
    case bytes <> rest: String.join(byte_text(bytes), ",")

def typed_response(+c: B.Context(Vars)) -> B.Res:
  C.text(Vars, c, user(C.get(Vars, c)))

def response(tag: Tag, +c: B.Ctx) -> B.Res:
  match tag:
    case TParam{}: B.text(c, optional(B.param(c, "name")) ++ "|" ++ optional(B.param(c, "absent")))
    case TQuery{}: B.text(c, optional(B.query(c, "q")) ++ "|" ++ optional(B.query(c, "absent")))
    case TQueries{}: B.text(c, String.join(B.queries(c, "q"), "|"))
    case THeader{}: B.text(c, optional(B.request_header(c, "X-VaLuE")))
    case THeaderBytes{}: B.text(c, headers_text(B.header_bytes(c, "x-value")))
    case TMethod{}: B.text(c, Request.method_text(B.method(c)))
    case TPath{}: B.text(c, B.path(c))
    case TUrl{}: B.text(c, B.url(c))
    case TText{}: B.text(c, "héllo 🌍")
    case THtml{}: B.html(c, "<p>héllo</p>")
    case TJsonValue{}: B.json(c, Json.JObject{[Json.Field{"hello", Json.JString{"世界"}}, Json.Field{"ok", Json.JBool{True{}}}]})
    case TInvalidJson{}: B.json(c, Json.JNumber{"nan"})
    case TBody{}: B.body(c, [0, 255, 65], Some{"application/octet-stream"})
    case TUntypedBody{}: B.body(c, [65], None{})
    case TEcho{}: B.body(c, B.raw_body(c), Some{"application/octet-stream"})
    case TRedirect{}: B.redirect(B.header(c, "x-state", "kept"), "/next?q=1")
    case TRedirectCode{}: B.redirect_status(c, "/next", Maybe.default(&2, U32, U32.read(optional(B.query(c, "code"))), 307))
    case TBadLocation{}: B.redirect(c, "/next\r\nx-injected: yes")
    case TBadRedirect{}: B.redirect_status(c, "/next", 200)
    case TMissing{}: B.not_found(B.header(c, "x-state", "kept"))
    case TState{}: B.text(B.header(B.header(B.status(c, 201), "X-State", "old"), "x-STATE", "new"), "created")
    case TBadHeader{}: B.text(B.header(c, "x-bad", "safe\r\nx-injected: yes"), "no")
    case TBadName{}: B.text(B.header(c, "bad name", "no"), "no")
    case TBadStatus{}: B.text(B.status(c, 600), "no")
    case TSetVar{}:
      typed = C.set(Vars, C.variables(Vars, B.header(B.status(c, 201), "x-vars", "kept")), Vars{"Ada", 42})
      typed_response(typed)
    case TUnsetVar{}:
      typed_response(C.variables(Vars, c))

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, response(tag, c))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid context routes")
    case Done{table}: B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.get(Tag, "/param/:name", TParam{}),
    B.get(Tag, "/query", TQuery{}), B.get(Tag, "/queries", TQueries{}),
    B.get(Tag, "/header", THeader{}), B.get(Tag, "/header-bytes", THeaderBytes{}),
    B.all(Tag, "/method", TMethod{}), B.get(Tag, "/path", TPath{}), B.get(Tag, "/url", TUrl{}),
    B.get(Tag, "/text", TText{}), B.get(Tag, "/html", THtml{}), B.get(Tag, "/json", TJsonValue{}),
    B.get(Tag, "/invalid-json", TInvalidJson{}), B.get(Tag, "/body", TBody{}), B.get(Tag, "/untyped-body", TUntypedBody{}),
    B.post(Tag, "/echo", TEcho{}), B.get(Tag, "/redirect", TRedirect{}), B.get(Tag, "/redirect-code", TRedirectCode{}),
    B.get(Tag, "/bad-location", TBadLocation{}), B.get(Tag, "/bad-redirect", TBadRedirect{}),
    B.get(Tag, "/missing", TMissing{}), B.get(Tag, "/state", TState{}),
    B.get(Tag, "/bad-header", TBadHeader{}), B.get(Tag, "/bad-name", TBadName{}), B.get(Tag, "/bad-status", TBadStatus{}),
    B.get(Tag, "/set-var", TSetVar{}), B.get(Tag, "/unset-var", TUnsetVar{})
  ]))
