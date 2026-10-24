# Shared Authorization parsing and challenge responses for the auth middleware.
import Base
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes
import ../crypto/sha256.bend as SHA256
import ../crypto/compare.bend as Compare
import ../data/utf8.bend as Utf8

# Missing: no Authorization header. Other: a different scheme or no
# credentials after the scheme. Given: the credentials after the scheme.
type Supplied is Data:
  Missing{}
  Other{}
  Given{value: String}

type Cut is Data:
  Cut{left: String, right: String}

def cut_prepend(c: Char, r: Maybe<&2, Cut>) -> Maybe<&2, Cut>:
  match r:
    case None{}: None{}
    case Some{Cut{a, b}}: Some{Cut{SCon{c, a}, b}}

def cut_pick(c: Char, t: String, rest: Maybe<&2, Cut>, here: Bool) -> Maybe<&2, Cut>:
  match here:
    case True{}: Some{Cut{"", t}}
    case False{}: cut_prepend(c, rest)

# Split at the first occurrence of sep.
def cut(s: String, +sep: Char) -> Maybe<&2, Cut>:
  match s:
    case SNil{}: None{}
    case SCon{+c, +t}: cut_pick(c, t, cut(t, sep), Char.is_eq(c, sep))

def spaces(s: String) -> String:
  match s:
    case SCon{' ', t}: spaces(t)
    case _: s

def trim(s: String) -> String:
  String.reverse(spaces(String.reverse(spaces(s))))

def nonempty(value: String, empty: Bool) -> Supplied:
  match empty:
    case True{}: Other{}
    case False{}: Given{value}

def credentials(+rest: String) -> Supplied:
  nonempty(rest, String.is_empty(rest))

def matched(rest: String, same: Bool) -> Supplied:
  match same:
    case True{}: credentials(trim(rest))
    case False{}: Other{}

def schemed(parts: Cut, +scheme: String) -> Supplied:
  Cut{name, rest} = parts
  matched(rest, String.eq(Bytes.fold(name), scheme))

def split_scheme(parts: Maybe<&2, Cut>, +scheme: String) -> Supplied:
  match parts:
    case None{}: Other{}
    case Some{p}: schemed(p, scheme)

# Parse "<scheme> <credentials>"; the scheme compares case-insensitively and
# any number of spaces may separate it from the credentials.
def supplied(header: Maybe<&2, String>, +scheme: String) -> Supplied:
  match header:
    case None{}: Missing{}
    case Some{value}: split_scheme(cut(trim(value), ' '), scheme)

def escape(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{'"', t}: "\\\"" ++ escape(t)
    case SCon{'\\', t}: "\\\\" ++ escape(t)
    case SCon{c, t}: SCon{c, escape(t)}

# A quoted-string auth-param value.
def quoted(s: String) -> String:
  "\"" ++ escape(s) ++ "\""

def reason(status: U32) -> String:
  match status:
    case 400: "Bad Request"
    case 401: "Unauthorized"
    case _: "Error"

def challenge(+status: U32, value: String) -> Response.Res:
  Response.body(status, [Request.Header{"www-authenticate", Response.utf8(value)}, Request.Header{"content-type", Bytes.encode("text/plain; charset=utf-8")}], Response.utf8(reason(status)))

def digest(s: String) -> List<&2, U32>:
  SHA256.hash(Utf8.encode(s))

# Compare fixed-length SHA-256 digests so secret length and the position of
# the first differing byte do not change the comparison's work.
def same(a: String, b: String) -> Bool:
  Compare.ct_equal(digest(a), digest(b))

# Check every candidate and accumulate with U32.or, which evaluates both
# operands, so no candidate's result ends the scan early.
def any_go(+given: List<&2, U32>, candidates: List<&2, List<&2, U32>>, found: U32) -> U32:
  match candidates:
    case Nil{}: found
    case c <> t: any_go(given, t, U32.or(found, Bool.to_u32(Compare.ct_equal(given, c))))

def any(given: List<&2, U32>, candidates: List<&2, List<&2, U32>>) -> Bool:
  U32.is_ne(any_go(given, candidates, 0), 0)
