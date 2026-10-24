# The CSRF decision as a pure function of the request's method and headers.
# src/mw/csrf.bend reads the headers; LAWS.bend states what the decision is.
import Base
import ../http/request.bend as Request
import ../http/origin.bend as Origin
import ../http/media.bend as Media
import ../http/bytes.bend as Bytes

# origins: serialized origins that may always send unsafe form requests.
# scheme: the scheme browsers use to reach this server, when the deployment
# knows it; it lets "scheme://Host" count as the app's own origin.
type Policy is Data:
  Policy{origins: List<&2, String>, scheme: Maybe<&2, String>}

def kept(m: Maybe<&2, String>, rest: List<&2, String>) -> List<&2, String>:
  match m:
    case None{}: rest
    case Some{o}: o <> rest

def serialized(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case x <> t: kept(Origin.of_url(x), serialized(t))

def scheme_of(s: Maybe<&2, String>) -> Maybe<&2, String>:
  match s:
    case None{}: None{}
    case Some{v}: Some{Bytes.fold(v)}

# Configured origins are serialized once here; any that is not an http or
# https origin can never match and is dropped.
def policy(origins: List<&2, String>, scheme: Maybe<&2, String>) -> Policy:
  Policy{serialized(origins), scheme_of(scheme)}

def safe(m: Request.Method) -> Bool:
  match m:
    case Request.Get{}: True{}
    case Request.Head{}: True{}
    case _: False{}

def form_media(+m: String) -> Bool:
  String.eq(m, "application/x-www-form-urlencoded") || String.eq(m, "multipart/form-data") || String.eq(m, "text/plain")

# Content types an HTML form can send without a CORS preflight. A request
# without Content-Type counts too, since a browser may omit it, and so does a
# malformed media type: the check fails closed rather than exempt a value it
# cannot read.
def form(content_type: Maybe<&2, String>) -> Bool:
  match content_type:
    case None{}: True{}
    case Some{+value}: form_media(Media.essence(value)) || Bool.not(Media.well_formed(value))

type Site is Data:
  SameOrigin{}
  CrossSite{}
  Unknown{}

def site_cross(cross: Bool) -> Site:
  match cross:
    case True{}: CrossSite{}
    case False{}: Unknown{}

def site_named(+v: String, same: Bool) -> Site:
  match same:
    case True{}: SameOrigin{}
    case False{}: site_cross(String.eq(v, "cross-site"))

def site_folded(+v: String) -> Site:
  site_named(v, String.eq(v, "same-origin"))

def site(value: Maybe<&2, String>) -> Site:
  match value:
    case None{}: Unknown{}
    case Some{v}: site_folded(Bytes.fold(v))

# The origin the browser claims: Origin when present, else Referer's origin.
def claimed(origin: Maybe<&2, String>, referer: Maybe<&2, String>) -> Maybe<&2, String>:
  match origin referer:
    case Some{o} _: Origin.canonical(o)
    case None{} Some{r}: Origin.of_url(r)
    case None{} None{}: None{}

def member(+s: String, xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> t: String.eq(x, s) || member(s, t)

def same(+o: String, addressed: Maybe<&2, String>) -> Bool:
  match addressed:
    case None{}: False{}
    case Some{a}: String.eq(a, o)

def own(+o: String, scheme: Maybe<&2, String>, host: Maybe<&2, String>) -> Bool:
  match scheme host:
    case Some{s} Some{h}: same(o, Origin.of_host(s, h))
    case _ _: False{}

def vouched(+origins: List<&2, String>, scheme: Maybe<&2, String>, host: Maybe<&2, String>, s: Site, source: Maybe<&2, String>) -> Bool:
  match s source:
    case SameOrigin{} _: True{}
    case _ None{}: False{}
    case CrossSite{} Some{+o}: member(o, origins)
    case Unknown{} Some{+o}: member(o, origins) || own(o, scheme, host)

def judged(p: Policy, site_value: Maybe<&2, String>, origin: Maybe<&2, String>, referer: Maybe<&2, String>, host: Maybe<&2, String>) -> Bool:
  match p:
    case Policy{+origins, scheme}: vouched(origins, scheme, host, site(site_value), claimed(origin, referer))

def inspect(exposed: Bool, p: Policy, site_value: Maybe<&2, String>, origin: Maybe<&2, String>, referer: Maybe<&2, String>, host: Maybe<&2, String>) -> Bool:
  match exposed:
    case False{}: True{}
    case True{}: judged(p, site_value, origin, referer, host)

# Unsafe form-like requests pass when Sec-Fetch-Site is same-origin, when the
# claimed origin is configured, or (unless Sec-Fetch-Site is cross-site) when
# it is "scheme://Host" for the policy's scheme. Everything else passes.
def decide(p: Policy, method: Request.Method, content_type: Maybe<&2, String>, site_value: Maybe<&2, String>, origin: Maybe<&2, String>, referer: Maybe<&2, String>, host: Maybe<&2, String>) -> Bool:
  inspect(Bool.not(safe(method)) && form(content_type), p, site_value, origin, referer, host)
