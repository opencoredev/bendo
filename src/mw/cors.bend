# CORS, following Hono's cors middleware. The decision is pure and lives in
# cors_policy.bend; this shell reads the request and edits the response.
import Base
import ../app/context.bend as C
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../data/utf8.bend as Utf8
import ./cors_policy.bend as P
import ./vary.bend as Vary

def text(m: Maybe<&2, String>) -> String:
  match m:
    case None{}: ""
    case Some{s}: s

# Undecodable UTF-8 becomes "", which is not an origin and is denied.
def sent(values: List<&2, List<&2, U32>>) -> P.Sent:
  match values:
    case Nil{}: P.Absent{}
    case v <> Nil{}: P.Sent{text(Utf8.decode(v))}
    case _: P.Repeated{}

def some(values: List<&2, List<&2, U32>>) -> Bool:
  match values:
    case Nil{}: False{}
    case _: True{}

def texts(values: List<&2, List<&2, U32>>) -> List<&2, String>:
  match values:
    case Nil{}: []
    case v <> t: text(Utf8.decode(v)) <> texts(t)

# Every Access-Control-Request-Headers field, combined as one comma list.
# An undecodable field contributes nothing.
def combined(values: List<&2, List<&2, U32>>) -> Maybe<&2, String>:
  match values:
    case Nil{}: None{}
    case v <> t: Some{String.join(texts(v <> t), ",")}

def fields(xs: List<&2, P.Field>) -> List<&2, Request.Header>:
  match xs:
    case Nil{}: []
    case P.Field{n, v} <> t: Request.Header{n, Response.utf8(v)} <> fields(t)

def stripped(names: List<&2, String>, hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match names:
    case Nil{}: hs
    case n <> t: stripped(t, C.without(hs, n))

def actual(+config: P.Config, g: Maybe<&2, P.Grant>, res: Response.Res) -> Response.Res:
  match res:
    case Response.Res{s, hs, b, rep}:
      Response.Res{s, Vary.add(List.append(&2, Request.Header, stripped(P.owned(), hs), fields(P.actual_fields(config, g))), P.vary(config, False{})), b, rep}

def answer(+config: P.Config, g: Maybe<&2, P.Grant>, requested: Maybe<&2, String>) -> Response.Res:
  Response.body(204, Vary.add(fields(P.preflight_fields(config, g, P.reflect(requested))), P.vary(config, True{})), [])

def respond(-Vars: Data, +config: P.Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), +g: Maybe<&2, P.Grant>, preflight: Bool) -> IO(Response.Res):
  match preflight:
    case True{}: IO.pure(Response.Res, answer(config, g, combined(C.header_bytes(Vars, c, "access-control-request-headers"))))
    case False{}:
      do IO<Response.Res>:
        res : Response.Res <- next(c)
        return actual(config, g, res)

# A preflight is answered here with 204 and never reaches the application.
# Every other request, including other OPTIONS requests, calls next.
def middleware(-Vars: Data, +config: P.Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  +who = sent(C.header_bytes(Vars, c, "origin"))
  respond(Vars, config, c, next, P.grant(P.origins_of(config), who), P.preflight(C.method(Vars, c), who, some(C.header_bytes(Vars, c, "access-control-request-method"))))
