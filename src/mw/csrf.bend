# CSRF protection by origin check, following Hono's csrf middleware.
import Base
import ../app/context.bend as C
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes
import ./auth_common.bend as A

def safe(m: Request.Method) -> Bool:
  match m:
    case Request.Get{}: True{}
    case Request.Head{}: True{}
    case _: False{}

def media(value: String) -> String:
  Bytes.fold(A.trim(Maybe.default(&2, String, List.head(&2, String, String.split(value, ';')), "")))

def form_media(+m: String) -> Bool:
  String.eq(m, "application/x-www-form-urlencoded") || String.eq(m, "multipart/form-data") || String.eq(m, "text/plain")

# Content types an HTML form can send without a CORS preflight. A request
# without Content-Type counts too, since a browser may omit it.
def form(content_type: Maybe<&2, String>) -> Bool:
  match content_type:
    case None{}: True{}
    case Some{value}: form_media(media(value))

def host_only(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{'/', t}: ""
    case SCon{'?', t}: ""
    case SCon{'#', t}: ""
    case SCon{c, t}: SCon{c, host_only(t)}

# "scheme://host[:port]" -> lowercase "host[:port]" for http and https only.
def host_part(web: Bool, rest: String) -> Maybe<&2, String>:
  match web rest:
    case True{} SCon{'/', SCon{'/', +host}}: Some{Bytes.fold(host_only(host))}
    case _ _: None{}

def scheme_host(+scheme: String, rest: String) -> Maybe<&2, String>:
  host_part(String.eq(scheme, "http") || String.eq(scheme, "https"), rest)

def after_scheme(parts: Maybe<&2, A.Cut>) -> Maybe<&2, String>:
  match parts:
    case None{}: None{}
    case Some{A.Cut{scheme, rest}}: scheme_host(Bytes.fold(scheme), rest)

def authority(origin: String) -> Maybe<&2, String>:
  after_scheme(A.cut(origin, ':'))

# The origin of a Referer URL: everything before the path.
def referer_go(s: String, slashes: Nat) -> String:
  match s slashes:
    case SNil{} _: ""
    case SCon{'/', t} 2n: ""
    case SCon{'/', t} k: SCon{'/', referer_go(t, Nat.add(k, 1n))}
    case SCon{c, t} k: SCon{c, referer_go(t, k)}

def referer_origin(s: String) -> String:
  referer_go(s, 0n)

def member(+s: String, xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> t: String.eq(x, s) || member(s, t)

def same_host(origin: Maybe<&2, String>, host: Maybe<&2, String>) -> Bool:
  match origin host:
    case Some{a} Some{h}: String.eq(a, Bytes.fold(A.trim(h)))
    case _ _: False{}

def origin_allowed(+origin: String, host: Maybe<&2, String>, origins: List<&2, String>) -> Bool:
  member(origin, origins) || same_host(authority(origin), host)

def source(origin: Maybe<&2, String>, referer: Maybe<&2, String>) -> Maybe<&2, String>:
  match origin referer:
    case Some{o} _: Some{o}
    case None{} Some{r}: Some{referer_origin(r)}
    case None{} None{}: None{}

def checked_origin(claimed: Maybe<&2, String>, host: Maybe<&2, String>, origins: List<&2, String>) -> Bool:
  match claimed:
    case None{}: False{}
    case Some{+o}: origin_allowed(o, host, origins)

def fetch_site(value: Maybe<&2, String>) -> Bool:
  match value:
    case None{}: False{}
    case Some{v}: String.eq(Bytes.fold(v), "same-origin")

def allowed(-Vars: Data, +c: C.Ctx<Vars>, origins: List<&2, String>) -> Bool:
  fetch_site(C.request_header(Vars, c, "sec-fetch-site")) || checked_origin(source(C.request_header(Vars, c, "origin"), C.request_header(Vars, c, "referer")), C.request_header(Vars, c, "host"), origins)

def decided(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), ok: Bool) -> IO(Response.Res):
  match ok:
    case True{}: next(c)
    case False{}: IO.pure(Response.Res, Response.text(403, "Forbidden"))

def guarded(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), origins: List<&2, String>, exposed: Bool) -> IO(Response.Res):
  match exposed:
    case False{}: next(c)
    case True{}: decided(Vars, c, next, allowed(Vars, c, origins))

# Unsafe form-like requests pass when Sec-Fetch-Site is same-origin, or when
# Origin (else the Referer's origin) is listed or names the request's Host.
def middleware(-Vars: Data, origins: List<&2, String>, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  guarded(Vars, c, next, origins, Bool.not(safe(C.method(Vars, c))) && form(C.request_header(Vars, c, "content-type")))
