# Shared by the BND-84 routing-stack fixtures: each export renders its result
# as a string so the test compares exact values on both targets.
import Base
import ../../../src/router/encoding.bend as E
import ../../../src/router/pattern.bend as P
import ../../../src/router/constraint.bend as C
import ../../../src/router/methods.bend as M
import ../../../src/static/path.bend as S

def bool(b: Bool) -> String:
  match b:
    case True{}:
      "true"
    case False{}:
      "false"

def text(m: Maybe<&2, String>) -> String:
  match m:
    case Some{s}:
      "some:" ++ s
    case None{}:
      "none"

def param(p: P.Param) -> String:
  match p:
    case P.Param{name, value}:
      name ++ "=" ++ value

# Params are few (one per pattern capture), so this recursion is bounded by
# the pattern, not the request.
def params(ps: P.Params) -> String:
  match ps:
    case Nil{}:
      ""
    case h <> Nil{}:
      param(h)
    case h <> t:
      param(h) ++ "&" ++ params(t)

def found(m: Maybe<&2, P.Params>) -> String:
  match m:
    case Some{ps}:
      "match:" ++ params(ps)
    case None{}:
      "none"

def compiled(r: Result<&2, &2, P.PatternError, P.Pattern>, path: String) -> String:
  match r:
    case Done{p}:
      found(P.match_path(p, path))
    case Fail{e}:
      "bad-pattern"

def route(pattern: String, path: String) -> String:
  compiled(P.compile(pattern), path)

def encode(s: String) -> String:
  E.encode(s)

def decode(s: String) -> String:
  text(E.decode(s))

def scalars(s: String) -> String:
  bool(E.scalars(s))

def digits(s: String) -> String:
  bool(C.digits(s))

def slug(s: String) -> String:
  bool(C.slug(s))

def uuid(s: String) -> String:
  bool(C.uuid(s, 0n))

def letters(s: String) -> String:
  bool(C.class_chars(s, [C.Range{97, 122}]))

# Base List.length recurses once per element; count in a tail loop instead.
def count(xs: List<&2, String>, n: Nat) -> Nat:
  match xs:
    case Nil{}:
      n
    case h <> t:
      count(t, 1n+n)

def segments(s: String) -> String:
  Nat.show(count(P.path_segments(s), 0n))

def wildcard(s: String) -> String:
  text(P.decode_segments(P.path_segments(s)))

def resolve(raw: String) -> String:
  text(S.resolve(raw, "index.html"))

def options_compiled(r: Result<&2, &2, P.PatternError, P.Pattern>, path: String, opts: M.Options) -> String:
  match r:
    case Done{p}: found(M.match_path(p, path, opts))
    case Fail{e}: "bad-pattern"

def route_options(pattern: String, path: String) -> String:
  options_compiled(P.compile(pattern), path, M.Options{False{}, False{}})
