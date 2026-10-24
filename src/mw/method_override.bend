# Method override from a form field or a request header, following Hono's
# methodOverride. Register it with B.on_request so the rewritten method
# selects the route. The decision is pure and lives in
# method_override_policy.bend.
import Base
import ../app/context.bend as C
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/media.bend as Media
import ../data/utf8.bend as Utf8
import ../data/form.bend as Form
import ../data/multipart.bend as Multipart
import ./method_override_policy.bend as P

type Values is Data:
  Values{list: List<&2, String>}
  Unreadable{}

# Undecodable header text can never name a configured method.
def text(m: Maybe<&2, String>) -> String:
  match m:
    case None{}: "?"
    case Some{s}: s

def texts(xs: List<&2, List<&2, U32>>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case x <> t: text(Utf8.decode(x)) <> texts(t)

def pick(v: String, rest: List<&2, String>, same: Bool) -> List<&2, String>:
  match same:
    case True{}: v <> rest
    case False{}: rest

# Field values named name. A file part with that name counts, as an
# unreadable value, so it cannot be ignored.
def field_values(parts: List<&2, Multipart.Part>, +name: String) -> List<&2, String>:
  match parts:
    case Nil{}: []
    case Multipart.Field{+k, v} <> t: pick(v, field_values(t, name), String.eq(k, name))
    case Multipart.File{+k, f, ct, b} <> t: pick("?", field_values(t, name), String.eq(k, name))

def parsed(r: Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>, +name: String) -> Values:
  match r:
    case Fail{e}: Unreadable{}
    case Done{parts}: Values{field_values(parts, name)}

def form_media(+e: String) -> Bool:
  String.eq(e, "application/x-www-form-urlencoded") || String.eq(e, "multipart/form-data")

def form_body(-Vars: Data, +c: C.Ctx<Vars>, +name: String, +content_type: String, form: Bool) -> Values:
  match form:
    case True{}: parsed(Form.parse_body(content_type, C.raw_body(Vars, c)), name)
    case False{}: Values{[]}

def typed(-Vars: Data, +c: C.Ctx<Vars>, +name: String, content_type: Maybe<&2, String>) -> Values:
  match content_type:
    case None{}: Values{[]}
    case Some{+ct}: form_body(Vars, c, name, ct, form_media(Media.essence(ct)))

def from_source(-Vars: Data, +c: C.Ctx<Vars>, source: P.Source) -> Values:
  match source:
    case P.Form{+name}: typed(Vars, c, name, C.request_header(Vars, c, "content-type"))
    case P.Header{name}: Values{texts(C.header_bytes(Vars, c, name))}

# Only a POST body is read.
def values(-Vars: Data, +c: C.Ctx<Vars>, source: P.Source, post: Bool) -> Values:
  match post:
    case True{}: from_source(Vars, c, source)
    case False{}: Values{[]}

def is_post(m: Request.Method) -> Bool:
  match m:
    case Request.Post{}: True{}
    case _: False{}

def bad() -> Response.Res:
  Response.text(400, "Bad Request")

def apply(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), o: P.Outcome) -> IO(Response.Res):
  match o:
    case P.Keep{}: next(c)
    case P.Rewrite{m}: next(C.rewrite(Vars, c, m, C.path(Vars, c)))
    case P.Reject{}: IO.pure(Response.Res, bad())

def outcome(+allowed: List<&2, Request.Method>, +method: Request.Method, v: Values) -> P.Outcome:
  match v:
    case Values{xs}: P.decide(allowed, method, xs)
    case Unreadable{}: P.Reject{}

# A POST with one valid override value continues with the method replaced and
# the body, query and headers unchanged. Two values, an unlisted or safe
# method, or an unreadable form body answer 400 without calling next.
def middleware(-Vars: Data, config: P.Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  match config:
    case P.Config{source, +allowed}:
      +method = C.method(Vars, c)
      apply(Vars, c, next, outcome(allowed, method, values(Vars, c, source, is_post(method))))
