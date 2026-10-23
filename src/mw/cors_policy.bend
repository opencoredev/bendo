# The CORS decision as pure functions of configuration and request headers.
# src/mw/cors.bend reads the headers; LAWS.bend states what the decision is.
import Base
import ../http/request.bend as Request
import ../http/origin.bend as Origin
import ../http/bytes.bend as Bytes

# One allowed origin. credentials: whether responses to it may carry
# Access-Control-Allow-Credentials: true.
type Entry is Data:
  Entry{origin: String, credentials: Bool}

# Any answers every request with "*" and can never send credentials. Listed
# holds serialized origins, each with its own credentials flag.
type Origins is Data:
  Any{}
  Listed{entries: List<&2, Entry>}

type Config is Data:
  Config{origins: Origins, methods: List<&2, String>, headers: List<&2, String>, expose: List<&2, String>, max_age: Maybe<&2, Nat>}

# The request's Origin field: absent, exactly one value, or repeated.
type Sent is Data:
  Absent{}
  Sent{value: String}
  Repeated{}

# The Access-Control-Allow-Origin value and whether credentials are allowed.
type Grant is Data:
  Grant{origin: String, credentials: Bool}

type Field is Data:
  Field{name: String, value: String}

def entry_kept(m: Maybe<&2, String>, credentials: Bool, rest: List<&2, Entry>) -> List<&2, Entry>:
  match m:
    case None{}: rest
    case Some{o}: Entry{o, credentials} <> rest

# Configured origins are serialized once, as URL origins (any path is
# ignored). An entry that is not an http or https URL, such as "*" or "null",
# can never match and is dropped.
def serialized(xs: List<&2, Entry>) -> List<&2, Entry>:
  match xs:
    case Nil{}: []
    case Entry{o, c} <> t: entry_kept(Origin.of_url(o), c, serialized(t))

def listed(xs: List<&2, Entry>) -> Origins:
  Listed{serialized(xs)}

# The request's origin, serialized. A repeated Origin, an absent one, "null"
# and anything that is not a bare http or https origin give None.
def requested(sent: Sent) -> Maybe<&2, String>:
  match sent:
    case Absent{}: None{}
    case Sent{v}: Origin.canonical(v)
    case Repeated{}: None{}

def lookup_pick(+o: String, c: Bool, rest: Maybe<&2, Grant>, here: Bool) -> Maybe<&2, Grant>:
  match here:
    case True{}: Some{Grant{o, c}}
    case False{}: rest

# The first entry naming o. The grant echoes the request's own origin.
def lookup(+o: String, es: List<&2, Entry>) -> Maybe<&2, Grant>:
  match es:
    case Nil{}: None{}
    case Entry{x, c} <> t: lookup_pick(o, c, lookup(o, t), String.eq(x, o))

def listed_grant(es: List<&2, Entry>, origin: Maybe<&2, String>) -> Maybe<&2, Grant>:
  match origin:
    case None{}: None{}
    case Some{+o}: lookup(o, es)

def grant(origins: Origins, sent: Sent) -> Maybe<&2, Grant>:
  match origins:
    case Any{}: Some{Grant{"*", False{}}}
    case Listed{es}: listed_grant(es, requested(sent))

def options(m: Request.Method) -> Bool:
  match m:
    case Request.Options{}: True{}
    case _: False{}

def present(sent: Sent) -> Bool:
  match sent:
    case Absent{}: False{}
    case _: True{}

# A preflight is OPTIONS with an Origin and an Access-Control-Request-Method.
# Any other OPTIONS request reaches the application.
def preflight(method: Request.Method, sent: Sent, requests_method: Bool) -> Bool:
  options(method) && present(sent) && requests_method

def kept_token(+t: String, rest: List<&2, String>, ok: Bool) -> List<&2, String>:
  match ok:
    case True{}: t <> rest
    case False{}: rest

def tokens(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case x <> t:
      +name = Bytes.fold(String.trim(x))
      kept_token(name, tokens(t), Bytes.token(name))

def joined(xs: List<&2, String>) -> Maybe<&2, String>:
  match xs:
    case Nil{}: None{}
    case x <> t: Some{String.join(x <> t, ",")}

# Access-Control-Request-Headers as a lowercase comma list of the field names
# it lists. Items that are not tokens are dropped.
def reflect(requested_headers: Maybe<&2, String>) -> Maybe<&2, String>:
  match requested_headers:
    case None{}: None{}
    case Some{v}: joined(tokens(String.split(v, ',')))

def cat(xs: List<&2, Field>, ys: List<&2, Field>) -> List<&2, Field>:
  List.append(&2, Field, xs, ys)

def credential_fields(c: Bool) -> List<&2, Field>:
  match c:
    case True{}: [Field{"access-control-allow-credentials", "true"}]
    case False{}: []

def list_field(name: String, xs: List<&2, String>) -> List<&2, Field>:
  match xs:
    case Nil{}: []
    case x <> t: [Field{name, String.join(x <> t, ",")}]

def reflected_field(r: Maybe<&2, String>) -> List<&2, Field>:
  match r:
    case None{}: []
    case Some{v}: [Field{"access-control-allow-headers", v}]

# Configured headers win; with none configured, the requested ones are
# reflected, as in Hono.
def allow_headers(configured: List<&2, String>, reflected: Maybe<&2, String>) -> List<&2, Field>:
  match configured:
    case Nil{}: reflected_field(reflected)
    case x <> t: [Field{"access-control-allow-headers", String.join(x <> t, ",")}]

def age_field(m: Maybe<&2, Nat>) -> List<&2, Field>:
  match m:
    case None{}: []
    case Some{n}: [Field{"access-control-max-age", Nat.show(n)}]

def granted_preflight(g: Grant, config: Config, reflected: Maybe<&2, String>) -> List<&2, Field>:
  match g config:
    case Grant{o, c} Config{origins, methods, headers, expose, age}:
      Field{"access-control-allow-origin", o} <> cat(credential_fields(c), cat(list_field("access-control-allow-methods", methods), cat(allow_headers(headers, reflected), age_field(age))))

# The CORS fields of a preflight answer. A denied origin gets none.
def preflight_fields(config: Config, g: Maybe<&2, Grant>, reflected: Maybe<&2, String>) -> List<&2, Field>:
  match g:
    case None{}: []
    case Some{x}: granted_preflight(x, config, reflected)

def granted_actual(g: Grant, config: Config) -> List<&2, Field>:
  match g config:
    case Grant{o, c} Config{origins, methods, headers, expose, age}:
      Field{"access-control-allow-origin", o} <> cat(credential_fields(c), list_field("access-control-expose-headers", expose))

# The CORS fields added to an ordinary response. A denied origin gets none.
def actual_fields(config: Config, g: Maybe<&2, Grant>) -> List<&2, Field>:
  match g:
    case None{}: []
    case Some{x}: granted_actual(x, config)

def origin_vary(o: Origins) -> List<&2, String>:
  match o:
    case Any{}: []
    case Listed{es}: ["Origin"]

def headers_vary(preflight_answer: Bool, configured: List<&2, String>) -> List<&2, String>:
  match preflight_answer configured:
    case True{} Nil{}: ["Access-Control-Request-Headers"]
    case _ _: []

# Names the answer depends on. A listed policy varies by Origin on every
# response, allowed, denied or without Origin, so a cache never replays one
# origin's answer to another. Reflected preflight headers vary by the request.
def vary(config: Config, preflight_answer: Bool) -> List<&2, String>:
  match config:
    case Config{origins, methods, headers, expose, age}:
      List.append(&2, String, origin_vary(origins), headers_vary(preflight_answer, headers))

# The ordinary response fields this middleware owns. Values the application
# set for them are replaced, so two conflicting grants are never sent.
def owned() -> List<&2, String>:
  ["access-control-allow-origin", "access-control-allow-credentials", "access-control-expose-headers"]

def any_defaults() -> Config:
  Config{Any{}, ["GET", "HEAD", "PUT", "POST", "DELETE", "PATCH", "QUERY"], [], [], None{}}

def allow(entries: List<&2, Entry>) -> Config:
  Config{listed(entries), ["GET", "HEAD", "PUT", "POST", "DELETE", "PATCH", "QUERY"], [], [], None{}}

def with_methods(config: Config, methods: List<&2, String>) -> Config:
  match config:
    case Config{o, m, h, e, a}: Config{o, methods, h, e, a}

def with_headers(config: Config, headers: List<&2, String>) -> Config:
  match config:
    case Config{o, m, h, e, a}: Config{o, m, headers, e, a}

def with_expose(config: Config, expose: List<&2, String>) -> Config:
  match config:
    case Config{o, m, h, e, a}: Config{o, m, h, expose, a}

def with_max_age(config: Config, seconds: Nat) -> Config:
  match config:
    case Config{o, m, h, e, a}: Config{o, m, h, e, Some{seconds}}

def origins_of(config: Config) -> Origins:
  match config:
    case Config{o, m, h, e, a}: o
