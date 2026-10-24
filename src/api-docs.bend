# BND-62: serve an OpenAPI document and a Scalar API reference page. Import
# this module beside main.bend only in apps that publish docs; plain apps never
# compile it. `bendo openapi` writes the document (docs/openapi.md).
#
#   import ../../src/api-docs.bend as Docs
#   import ./openapi-doc.bend as OpenApiDoc        # bendo openapi --bend
#
#   case Spec{}: IO.pure(B.Res, Docs.openapi(c, OpenApiDoc.json()))
#   case Docs{}: IO.pure(B.Res, Docs.scalar(c, Docs.options("/openapi.json")))
import Base
import ./app/context.bend as Context
import ./http/response.bend as Response

# Scalar API Reference, pinned. Upgrade all three together: the hash is the
# SHA-384 of exactly this file, so the browser refuses any other bytes.
def scalar_version() -> String: "1.75.1"
def scalar_cdn() -> String: "https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.75.1/dist/browser/standalone.js"
def scalar_integrity() -> String: "sha384-G+2Q2i9l3PPfmYkk0b4BAIUrs7xb/DNaTL1wCYYab4c9dIKlCyiqzC0Qx3eq9Wf6"

# What the page's own Content-Security-Policy allows with the CDN script.
# Scalar injects inline styles and loads its fonts from fonts.scalar.com; the
# document and "try it" requests go to this origin.
def cdn_csp() -> String:
  "default-src 'none'; script-src https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline' https://fonts.scalar.com; font-src 'self' https://fonts.scalar.com data:; img-src 'self' data: https:; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'self'"

# The same with a script served by this app and no font host.
def self_hosted_csp() -> String:
  "default-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self' data:; img-src 'self' data:; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'self'"

# spec_url: where the page fetches the document. integrity: "" omits the
# attribute. csp: "" sends no Content-Security-Policy. fonts: False tells
# Scalar not to load its default fonts, so the page needs no other host.
type Options is Data:
  Options{spec_url: String, title: String, script: String, integrity: String, csp: String, fonts: Bool}

def options(spec_url: String) -> Options:
  Options{spec_url, "API Reference", scalar_cdn(), scalar_integrity(), cdn_csp(), True{}}

def with_title(o: Options, title: String) -> Options:
  match o:
    case Options{u, t, s, i, p, f}: Options{u, title, s, i, p, f}

# Serve Scalar's standalone.js yourself (offline or air-gapped). Pass its
# SHA-384 as "sha384-..." or "" to skip the check. The page then allows
# scripts and fonts from this origin only and skips Scalar's font host.
def self_hosted(o: Options, script: String, integrity: String) -> Options:
  match o:
    case Options{u, t, s, i, p, f}: Options{u, t, script, integrity, self_hosted_csp(), False{}}

# Replace the page's policy, or pass "" to send none.
def with_csp(o: Options, policy: String) -> Options:
  match o:
    case Options{u, t, s, i, p, f}: Options{u, t, s, i, policy, f}

def choose(hit: Bool, yes: String, no: String) -> String:
  match hit:
    case True{}: yes
    case False{}: no

def escaped(+c: U32) -> String:
  choose(U32.is_eq(c, 38), "&amp;", choose(U32.is_eq(c, 60), "&lt;", choose(U32.is_eq(c, 62), "&gt;", choose(U32.is_eq(c, 34), "&quot;", choose(U32.is_eq(c, 39), "&#39;", SCon{Chr{c}, SNil{}})))))

def escape_go(s: String, acc: String) -> String:
  match s:
    case SNil{}: acc
    case SCon{Chr{+c}, t}: escape_go(t, acc ++ escaped(c))

# Text for an HTML attribute value or element content.
def escape_html(s: String) -> String:
  escape_go(s, "")

def integrity_attr(integrity: String, +empty: Bool) -> String:
  match empty:
    case True{}: ""
    case False{}: " integrity=\"" ++ escape_html(integrity) ++ "\" crossorigin=\"anonymous\""

def fonts_attr(fonts: Bool) -> String:
  match fonts:
    case True{}: ""
    case False{}: " data-configuration=\"{&quot;withDefaultFonts&quot;:false}\""

# The page. Scalar reads the document URL from the #api-reference element, so
# the page has no inline script and its policy needs no hash or nonce.
def page(o: Options) -> String:
  match o:
    case Options{u, t, s, +i, p, f}:
      +spec = escape_html(u)
      "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n<title>" ++ escape_html(t) ++ "</title>\n</head>\n<body>\n<noscript>This page needs JavaScript. The OpenAPI document is at <a href=\"" ++ spec ++ "\">" ++ spec ++ "</a>.</noscript>\n<script id=\"api-reference\" data-url=\"" ++ spec ++ "\"" ++ fonts_attr(f) ++ "></script>\n<script src=\"" ++ escape_html(s) ++ "\"" ++ integrity_attr(i, String.eq(i, "")) ++ "></script>\n</body>\n</html>\n"

def policy(o: Options) -> String:
  match o:
    case Options{u, t, s, i, p, f}: p

def with_policy(-Vars: Data, c: Context.Ctx<Vars>, +csp: String, empty: Bool) -> Context.Ctx<Vars>:
  match empty:
    case True{}: c
    case False{}: Context.header(Vars, c, "content-security-policy", csp)

def scalar_with(-Vars: Data, c: Context.Ctx<Vars>, +o: Options) -> Response.Res:
  +csp = policy(o)
  Context.html(Vars, with_policy(Vars, c, csp, String.eq(csp, "")), page(o))

def openapi_with(-Vars: Data, c: Context.Ctx<Vars>, document: String) -> Response.Res:
  Context.body(Vars, c, Response.utf8(document), Some{"application/json; charset=utf-8"})

# The Scalar page as text/html with the options' Content-Security-Policy.
def scalar(c: Context.Ctx<Unit>, o: Options) -> Response.Res:
  scalar_with(Unit, c, o)

# A JSON document, such as the json() of a `bendo openapi --bend` module.
def openapi(c: Context.Ctx<Unit>, document: String) -> Response.Res:
  openapi_with(Unit, c, document)
