# The method-override decision as a pure function of the wire method, the
# override values the request carries and the configured allowlist.
# src/mw/method_override.bend reads the values; LAWS.bend states the rules.
import Base
import ../http/request.bend as Request
import ../http/bytes.bend as Bytes
import ../http/text.bend as Text

# Form: a field of an application/x-www-form-urlencoded or multipart/form-data
# body. Header: a request header.
type Source is Data:
  Form{name: String}
  Header{name: String}

type Config is Data:
  Config{source: Source, allowed: List<&2, Request.Method>}

type Outcome is Data:
  Keep{}
  Rewrite{method: Request.Method}
  Reject{}

# A method an override may switch to. GET, HEAD, OPTIONS, CONNECT and TRACE
# are refused even when configured: a cross-site form POST rewritten to GET or
# HEAD would no longer be an unsafe request, so CSRF checks would skip it.
def destination(m: Request.Method) -> Bool:
  match m:
    case Request.Get{}: False{}
    case Request.Head{}: False{}
    case Request.Post{}: False{}
    case Request.Put{}: True{}
    case Request.Delete{}: True{}
    case Request.Connect{}: False{}
    case Request.Options{}: False{}
    case Request.Trace{}: False{}
    case Request.Patch{}: True{}
    case Request.Extension{t}: True{}

def same(+a: Request.Method, b: Request.Method) -> Bool:
  String.eq(Request.method_text(b), Request.method_text(a))

def member(+m: Request.Method, xs: List<&2, Request.Method>) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> t: same(m, x) || member(m, t)

def parse(s: String) -> Request.Method:
  Request.method(Text.upper(String.trim(s)))

def kept(+m: Request.Method, rest: List<&2, Request.Method>, ok: Bool) -> List<&2, Request.Method>:
  match ok:
    case True{}: m <> rest
    case False{}: rest

# Configured methods, parsed without ASCII case. Safe methods and anything
# that is not an HTTP token are dropped.
def allowlist(xs: List<&2, String>) -> List<&2, Request.Method>:
  match xs:
    case Nil{}: []
    case x <> t:
      +m = parse(x)
      kept(m, allowlist(t), destination(m) && Bytes.token(Request.method_text(m)))

# The names of the methods an override never produces, so an extension
# method can never stand in for one by spelling.
def safe_name(+t: String) -> Bool:
  String.eq(t, "GET") || String.eq(t, "HEAD") || String.eq(t, "OPTIONS") || String.eq(t, "CONNECT") || String.eq(t, "TRACE")

def listed(+m: Request.Method, ok: Bool) -> Outcome:
  match ok:
    case True{}: Rewrite{m}
    case False{}: Reject{}

# POST stays POST; a destination must also be listed.
def chosen(+allowed: List<&2, Request.Method>, m: Request.Method) -> Outcome:
  match m:
    case Request.Get{}: Reject{}
    case Request.Head{}: Reject{}
    case Request.Post{}: Keep{}
    case Request.Put{}: listed(Request.Put{}, member(Request.Put{}, allowed))
    case Request.Delete{}: listed(Request.Delete{}, member(Request.Delete{}, allowed))
    case Request.Connect{}: Reject{}
    case Request.Options{}: Reject{}
    case Request.Trace{}: Reject{}
    case Request.Patch{}: listed(Request.Patch{}, member(Request.Patch{}, allowed))
    case Request.Extension{+t}: listed(Request.Extension{t}, Bool.not(safe_name(t)) && member(Request.Extension{t}, allowed))

# An empty value is no override, as in Hono.
def named(+allowed: List<&2, Request.Method>, v: String) -> Outcome:
  match v:
    case SNil{}: Keep{}
    case SCon{h, t}: chosen(allowed, Request.method(Text.upper(SCon{h, t})))

def single(+allowed: List<&2, Request.Method>, v: String, rest: List<&2, String>) -> Outcome:
  match rest:
    case Nil{}: named(allowed, String.trim(v))
    case w <> u: Reject{}

# Two override values disagree about the method, so the request is refused.
def posted(+allowed: List<&2, Request.Method>, values: List<&2, String>) -> Outcome:
  match values:
    case Nil{}: Keep{}
    case v <> t: single(allowed, v, t)

# Only a POST is overridden, like Rails and Laravel. Hono also overrides other
# non-GET methods; Bendo keeps them as sent.
def decide(+allowed: List<&2, Request.Method>, wire: Request.Method, values: List<&2, String>) -> Outcome:
  match wire:
    case Request.Get{}: Keep{}
    case Request.Head{}: Keep{}
    case Request.Post{}: posted(allowed, values)
    case Request.Put{}: Keep{}
    case Request.Delete{}: Keep{}
    case Request.Connect{}: Keep{}
    case Request.Options{}: Keep{}
    case Request.Trace{}: Keep{}
    case Request.Patch{}: Keep{}
    case Request.Extension{t}: Keep{}

def defaults() -> Config:
  Config{Form{"_method"}, [Request.Put{}, Request.Patch{}, Request.Delete{}]}

def form(name: String, methods: List<&2, String>) -> Config:
  Config{Form{name}, allowlist(methods)}

def header(name: String, methods: List<&2, String>) -> Config:
  Config{Header{Bytes.fold(name)}, allowlist(methods)}
