# Security response headers, following Hono's secureHeaders defaults.
import Base
import ../app/observability.bend as Obs
import ./response_policy.bend as Policy
import ./response_fields.bend as Fields
import ../app/context.bend as C
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes

type Field is Data:
  Field{name: String, value: String}

# fields: set on every response, replacing any value the app chose.
# remove_powered_by: drop X-Powered-By, as Hono does by default.
type Config is Data:
  Config{fields: List<&2, Field>, remove_powered_by: Bool}

# Hono 4's defaults, in its order. Cross-Origin-Embedder-Policy is off, as in
# Hono, because require-corp breaks pages that embed cross-origin resources.
# Content-Security-Policy is opt-in: a useful policy is specific to one app.
def defaults() -> Config:
  Config{[
    # Other sites cannot embed responses (blocks Spectre-style reads).
    Field{"cross-origin-resource-policy", "same-origin"},
    # Cross-origin windows get no handle to this page.
    Field{"cross-origin-opener-policy", "same-origin"},
    # Isolate the origin in its own agent cluster.
    Field{"origin-agent-cluster", "?1"},
    # Never leak URLs (paths, tokens in queries) to other sites.
    Field{"referrer-policy", "no-referrer"},
    # HTTPS only for 180 days, subdomains included (defeats SSL-stripping).
    Field{"strict-transport-security", "max-age=15552000; includeSubDomains"},
    # Trust Content-Type instead of sniffing uploads into scripts.
    Field{"x-content-type-options", "nosniff"},
    # Do not reveal linked hosts through DNS prefetching.
    Field{"x-dns-prefetch-control", "off"},
    # Old Internet Explorer saves downloads instead of opening them in place.
    Field{"x-download-options", "noopen"},
    # Only this origin may frame the page (blocks clickjacking).
    Field{"x-frame-options", "SAMEORIGIN"},
    # Flash and PDF readers ignore crossdomain.xml policies.
    Field{"x-permitted-cross-domain-policies", "none"},
    # Disable the old XSS auditors, which could themselves leak data.
    Field{"x-xss-protection", "0"}
  ], True{}}

def keep(f: Field, rest: List<&2, Field>, same: Bool) -> List<&2, Field>:
  match same:
    case True{}: rest
    case False{}: f <> rest

def without(fs: List<&2, Field>, +name: String) -> List<&2, Field>:
  match fs:
    case Nil{}: []
    case Field{+n, v} <> t: keep(Field{n, v}, without(t, name), String.eq(n, name))

# Add a header, or replace the configured value of one (names ignore case).
def set(config: Config, name: String, value: String) -> Config:
  match config:
    case Config{fs, r}:
      +key = Bytes.fold(name)
      Config{List.append(&2, Field, without(fs, key), [Field{key, value}]), r}

# Stop sending a header, default or not.
def unset(config: Config, name: String) -> Config:
  match config:
    case Config{fs, r}: Config{without(fs, Bytes.fold(name)), r}

def keep_powered_by(config: Config) -> Config:
  match config:
    case Config{fs, r}: Config{fs, False{}}

def fields(fs: List<&2, Field>) -> List<&2, Request.Header>:
  match fs:
    case Nil{}: []
    case Field{n, v} <> t: Request.Header{n, Response.utf8(v)} <> fields(t)

def names(fs: List<&2, Field>, remove: Bool) -> List<&2, String>:
  match fs remove:
    case Nil{} True{}: ["x-powered-by"]
    case Nil{} False{}: []
    case Field{n, v} <> t r: n <> names(t, r)

def sent_fields(fs: List<&2, Field>, remove: Bool) -> List<&2, Request.Header>:
  match remove:
    case True{}: Fields.without(fields(fs), "x-powered-by")
    case False{}: fields(fs)

def policy(config: Config) -> Policy.Policy:
  match config:
    case Config{+fs, +r}: Policy.Policy{names(fs, r), sent_fields(fs, r), []}

def secured(config: Config, res: Response.Res) -> Response.Res:
  Policy.apply(policy(config), res)

# Runs a policy built once, when the middleware was registered (BND-68).
def prepared(-Vars: Data, +ready: Policy.Policy, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  do IO<Response.Res>:
    res : Response.Res <- next(c)
    Obs.retain(C.observation(Vars, c), ready)
    return Policy.apply(ready, res)

# The middleware as it ran before BND-68, rebuilding the policy per request.
# Laws hot_secure_prepared_spec and hot_secure_dispatch equate it with the
# prepared shell.
def middleware_spec(-Vars: Data, +config: Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  do IO<Response.Res>:
    res : Response.Res <- next(c)
    Obs.retain(C.observation(Vars, c), policy(config))
    return secured(config, res)

def middleware(-Vars: Data, +config: Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  prepared(Vars, policy(config), c, next)
