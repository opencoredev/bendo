# BND-40: what a method override may do, stated without the middleware's
# helpers.
import Base
import ../src/http/request.bend as Request
import ./csrf-spec.bend as CsrfSpec
import ../src/mw/method_override_policy.bend as P

def is_post(m: Request.Method) -> Bool:
  match m:
    case Request.Get{}: False{}
    case Request.Head{}: False{}
    case Request.Post{}: True{}
    case Request.Put{}: False{}
    case Request.Delete{}: False{}
    case Request.Connect{}: False{}
    case Request.Options{}: False{}
    case Request.Trace{}: False{}
    case Request.Patch{}: False{}
    case Request.Extension{t}: False{}

# m is configured: some allowlist entry has the same method name.
def listed(+m: Request.Method, xs: List<&2, Request.Method>) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> t: String.eq(Request.method_text(x), Request.method_text(m)) || listed(m, t)

# No allowlist entry is GET or HEAD, the methods CSRF checks skip.
def all_unsafe(xs: List<&2, Request.Method>) -> Bool:
  match xs:
    case Nil{}: True{}
    case x <> t: Bool.not(CsrfSpec.reads_only(x)) && all_unsafe(t)

# The names of the methods CSRF checks skip or that carry no body semantics
# for a form: an override must never produce one, by constructor or spelling.
def named_safe(+t: String) -> Bool:
  String.eq(t, "GET") || String.eq(t, "HEAD") || String.eq(t, "OPTIONS") || String.eq(t, "CONNECT") || String.eq(t, "TRACE")

def granted(+m: Request.Method, ok: Bool) -> P.Outcome:
  match ok:
    case True{}: P.Rewrite{m}
    case False{}: P.Reject{}

def judged(+allowed: List<&2, Request.Method>, +m: Request.Method, safe: Bool) -> P.Outcome:
  match safe:
    case True{}: P.Reject{}
    case False{}: granted(m, listed(m, allowed))

def pick(+allowed: List<&2, Request.Method>, +m: Request.Method, post: Bool, safe: Bool) -> P.Outcome:
  match post:
    case True{}: P.Keep{}
    case False{}: judged(allowed, m, safe)

# One trimmed value: empty keeps the request; otherwise its uppercase method
# m is kept when it is POST, rewritten to exactly m when m is listed and not
# a safe name, and rejected in every other case.
def one(+allowed: List<&2, Request.Method>, v: String) -> P.Outcome:
  match v:
    case SNil{}: P.Keep{}
    case SCon{h, t}:
      +m = Request.method(String.to_upper(SCon{h, t}))
      pick(allowed, m, is_post(m), named_safe(Request.method_text(m)))

def values_decision(+allowed: List<&2, Request.Method>, values: List<&2, String>) -> P.Outcome:
  match values:
    case Nil{}: P.Keep{}
    case v <> Nil{}: one(allowed, String.trim(v))
    case v <> (w <> rest): P.Reject{}

# The whole decision: a non-POST is kept; a POST without a value is kept,
# with two or more values is rejected, and with one value follows one().
def decide(+allowed: List<&2, Request.Method>, wire: Request.Method, values: List<&2, String>) -> P.Outcome:
  match wire:
    case Request.Post{}: values_decision(allowed, values)
    case Request.Get{}: P.Keep{}
    case Request.Head{}: P.Keep{}
    case Request.Put{}: P.Keep{}
    case Request.Delete{}: P.Keep{}
    case Request.Connect{}: P.Keep{}
    case Request.Options{}: P.Keep{}
    case Request.Trace{}: P.Keep{}
    case Request.Patch{}: P.Keep{}
    case Request.Extension{t}: P.Keep{}
