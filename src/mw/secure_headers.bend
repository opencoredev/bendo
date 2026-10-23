# Security response headers, following Hono's secureHeaders defaults.
import Base
import ../app/context.bend as C
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes
import ./common.bend as Common

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

def applied(fs: List<&2, Field>, res: Response.Res) -> Response.Res:
  match fs:
    case Nil{}: res
    case Field{n, v} <> t: applied(t, Common.header(res, n, v))

def powered(remove: Bool, res: Response.Res) -> Response.Res:
  match remove res:
    case False{} r: r
    case True{} Response.Res{s, hs, b, rep}: Response.Res{s, C.without(hs, "x-powered-by"), b, rep}

def secured(config: Config, res: Response.Res) -> Response.Res:
  match config:
    case Config{fs, r}: powered(r, applied(fs, res))

def middleware(-Vars: Data, config: Config, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  do IO<Response.Res>:
    res : Response.Res <- next(c)
    return secured(config, res)
