# BND-40: the CORS decision, stated without the middleware's helpers.
# Origin serialization (src/http/origin.bend) is a shared parsing primitive,
# not policy.
import Base
import ../src/mw/cors_policy.bend as P
import ../src/http/request.bend as Request
import ../src/http/origin.bend as Origin

# The origin a request names: exactly one Origin field that serializes as an
# http or https origin. "null", a path, a repeated or absent Origin give None.
def request_origin(sent: P.Sent) -> Maybe<&2, String>:
  match sent:
    case P.Absent{}: None{}
    case P.Sent{v}: Origin.canonical(v)
    case P.Repeated{}: None{}

def first_flag(c: Bool, rest: Maybe<&2, Bool>, here: Bool) -> Maybe<&2, Bool>:
  match here:
    case True{}: Some{c}
    case False{}: rest

# The credentials flag of the first configured entry for o, if any.
def credentials_for(+o: String, es: List<&2, P.Entry>) -> Maybe<&2, Bool>:
  match es:
    case Nil{}: None{}
    case P.Entry{x, c} <> t: first_flag(c, credentials_for(o, t), String.eq(x, o))

def credited(+o: String, m: Maybe<&2, Bool>) -> Maybe<&2, P.Grant>:
  match m:
    case None{}: None{}
    case Some{c}: Some{P.Grant{o, c}}

def found(origin: Maybe<&2, String>, es: List<&2, P.Entry>) -> Maybe<&2, P.Grant>:
  match origin:
    case None{}: None{}
    case Some{+o}: credited(o, credentials_for(o, es))

# Any allows every request with "*" and never credentials. Listed allows a
# request only when its origin is configured, echoing that origin with the
# entry's credentials flag.
def grant(origins: P.Origins, sent: P.Sent) -> Maybe<&2, P.Grant>:
  match origins:
    case P.Any{}: Some{P.Grant{"*", False{}}}
    case P.Listed{es}: found(request_origin(sent), es)

def present(m: Maybe<&2, String>, credentials: Bool) -> List<&2, P.Entry>:
  match m:
    case None{}: []
    case Some{o}: [P.Entry{o, credentials}]

# Configured entries as the policy compares them: each entry's URL origin,
# in order. An entry that is not an http or https URL contributes nothing.
def configured(xs: List<&2, P.Entry>) -> List<&2, P.Entry>:
  match xs:
    case Nil{}: []
    case P.Entry{o, c} <> t: List.append(&2, P.Entry, present(Origin.of_url(o), c), configured(t))

def is_options(m: Request.Method) -> Bool:
  match m:
    case Request.Get{}: False{}
    case Request.Head{}: False{}
    case Request.Post{}: False{}
    case Request.Put{}: False{}
    case Request.Delete{}: False{}
    case Request.Connect{}: False{}
    case Request.Options{}: True{}
    case Request.Trace{}: False{}
    case Request.Patch{}: False{}
    case Request.Extension{t}: False{}

def has_origin(sent: P.Sent) -> Bool:
  match sent:
    case P.Absent{}: False{}
    case P.Sent{v}: True{}
    case P.Repeated{}: True{}

# A preflight is an OPTIONS request with an Origin field (even an unusable or
# repeated one) and an Access-Control-Request-Method field.
def preflight(method: Request.Method, sent: P.Sent, requests_method: Bool) -> Bool:
  is_options(method) && has_origin(sent) && requests_method

def flag(c: Bool) -> List<&2, P.Field>:
  match c:
    case False{}: []
    case True{}: [P.Field{"access-control-allow-credentials", "true"}]

def csv(name: String, xs: List<&2, String>) -> List<&2, P.Field>:
  match xs:
    case Nil{}: []
    case x <> t: [P.Field{name, String.join(x <> t, ",")}]

# The configured header list, or else the reflected request headers.
def headers_answer(configured_headers: List<&2, String>, reflected: Maybe<&2, String>) -> List<&2, P.Field>:
  match configured_headers reflected:
    case Nil{} None{}: []
    case Nil{} Some{v}: [P.Field{"access-control-allow-headers", v}]
    case (x <> t) r: [P.Field{"access-control-allow-headers", String.join(x <> t, ",")}]

def age(m: Maybe<&2, Nat>) -> List<&2, P.Field>:
  match m:
    case None{}: []
    case Some{n}: [P.Field{"access-control-max-age", Nat.show(n)}]

# A granted preflight answer, in order: the granted origin, credentials when
# the grant has them, the configured methods, the configured headers (or the
# reflected ones), and the configured max age. A denied one carries none.
def preflight_fields(config: P.Config, g: Maybe<&2, P.Grant>, reflected: Maybe<&2, String>) -> List<&2, P.Field>:
  match config g:
    case P.Config{origins, methods, headers, expose, max} None{}: []
    case P.Config{origins, methods, headers, expose, max} Some{P.Grant{o, c}}:
      P.Field{"access-control-allow-origin", o} <> List.append(&2, P.Field, flag(c), List.append(&2, P.Field, csv("access-control-allow-methods", methods), List.append(&2, P.Field, headers_answer(headers, reflected), age(max))))

# A granted ordinary response: the granted origin, credentials when granted,
# and the exposed headers. A denied one carries none.
def actual_fields(config: P.Config, g: Maybe<&2, P.Grant>) -> List<&2, P.Field>:
  match config g:
    case P.Config{origins, methods, headers, expose, max} None{}: []
    case P.Config{origins, methods, headers, expose, max} Some{P.Grant{o, c}}:
      P.Field{"access-control-allow-origin", o} <> List.append(&2, P.Field, flag(c), csv("access-control-expose-headers", expose))
