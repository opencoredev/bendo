# BND-43: the CSRF request policy, stated without the middleware's helpers.
# Origins and media types come from the independent specifications
# (proof/origin-spec.bend, proof/media-spec.bend; BND-85), not from the
# parsers the middleware runs.
import Base
import ../src/http/request.bend as Request
import ./origin-spec.bend as OriginSpec
import ./media-spec.bend as MediaSpec
import ../src/http/bytes.bend as Bytes

# GET and HEAD are never inspected.
def reads_only(m: Request.Method) -> Bool:
  match m:
    case Request.Get{}: True{}
    case Request.Head{}: True{}
    case Request.Post{}: False{}
    case Request.Put{}: False{}
    case Request.Delete{}: False{}
    case Request.Connect{}: False{}
    case Request.Options{}: False{}
    case Request.Trace{}: False{}
    case Request.Patch{}: False{}
    case Request.Extension{t}: False{}

def form_essence(+e: String) -> Bool:
  String.eq(e, "application/x-www-form-urlencoded") || String.eq(e, "multipart/form-data") || String.eq(e, "text/plain")

# A body an HTML form can send without a CORS preflight. A request without
# Content-Type counts, since a browser may omit it. So does a value whose media
# type is malformed (MediaSpec.well_formed): the policy fails closed, and a
# value main's looser trim read as a form type is never exempt (BND-85,
# law csrf_spec_v1_denies).
def simple_body(content_type: Maybe<&2, String>) -> Bool:
  match content_type:
    case None{}: True{}
    case Some{+v}: form_essence(MediaSpec.essence(v)) || Bool.not(MediaSpec.well_formed(v))

def inspected(m: Request.Method, content_type: Maybe<&2, String>) -> Bool:
  Bool.not(reads_only(m)) && simple_body(content_type)

# Sec-Fetch-Site equals value, ignoring ASCII case. An absent header equals
# nothing.
def site_is(site: Maybe<&2, String>, +value: String) -> Bool:
  match site:
    case None{}: False{}
    case Some{v}: String.eq(Bytes.fold(v), value)

# The source the browser claims: Origin whenever it is present, even when it
# is "null" or malformed; the Referer's origin only without Origin.
def source(origin: Maybe<&2, String>, referer: Maybe<&2, String>) -> Maybe<&2, String>:
  match origin referer:
    case Some{o} r: OriginSpec.canonical(o)
    case None{} Some{r}: OriginSpec.of_url(r)
    case None{} None{}: None{}

def listed(+o: String, origins: List<&2, String>) -> Bool:
  match origins:
    case Nil{}: False{}
    case x <> t: String.eq(x, o) || listed(o, t)

# The origin the request addressed, when the deployment supplies its scheme.
def addressed(scheme: Maybe<&2, String>, host: Maybe<&2, String>) -> Maybe<&2, String>:
  match scheme host:
    case Some{s} Some{h}: OriginSpec.of_host(s, h)
    case _ _: None{}

def names(m: Maybe<&2, String>, +o: String) -> Bool:
  match m:
    case None{}: False{}
    case Some{x}: String.eq(x, o)

# A claimed source is trusted when it is listed, or when it is the addressed
# origin and Sec-Fetch-Site does not say cross-site. A missing source, which
# includes Origin: null, is never trusted.
def trusted(+origins: List<&2, String>, scheme: Maybe<&2, String>, +site: Maybe<&2, String>, src: Maybe<&2, String>, host: Maybe<&2, String>) -> Bool:
  match src:
    case None{}: False{}
    case Some{+o}: listed(o, origins) || (Bool.not(site_is(site, "cross-site")) && names(addressed(scheme, host), o))

# A request is allowed unless it is inspected and neither Sec-Fetch-Site:
# same-origin nor a trusted source vouches for it.
def allows(+origins: List<&2, String>, scheme: Maybe<&2, String>, method: Request.Method, content_type: Maybe<&2, String>, +site: Maybe<&2, String>, origin: Maybe<&2, String>, referer: Maybe<&2, String>, host: Maybe<&2, String>) -> Bool:
  Bool.not(inspected(method, content_type)) || site_is(site, "same-origin") || trusted(origins, scheme, site, source(origin, referer), host)

def present(m: Maybe<&2, String>) -> List<&2, String>:
  match m:
    case None{}: []
    case Some{o}: [o]

# The configured origins as the policy compares them: each entry's origin
# (scheme, host and port of the URL, any path ignored), in order. An entry
# that is not an http or https URL contributes nothing.
def configured(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case x <> t: List.append(&2, String, present(OriginSpec.of_url(x)), configured(t))

# The configured scheme, compared in ASCII lowercase.
def configured_scheme(s: Maybe<&2, String>) -> Maybe<&2, String>:
  match s:
    case None{}: None{}
    case Some{v}: Some{Bytes.fold(v)}
