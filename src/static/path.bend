# Static file path resolution (BND-45). Pure, so LAWS.bend can state over
# every request path that a resolved path stays inside the static root.
# `raw` is the undecoded request path after the mount prefix, such as
# "/assets/app.js" or "/docs/". See docs/static.md.
import Base
import ../router/encoding.bend as E

# A relative path: one or more decoded segments.
type Segments is Data:
  Segments{first: String, rest: List<&2, String>}

# A segment character may not be a control (below 32, including NUL), DEL,
# '/', '\' or '%'. Rejecting '%' after decoding refuses double encoding.
def code_ok(control: Bool, delete: Bool, slash: Bool, backslash: Bool, percent: Bool) -> Bool:
  Bool.not(control || delete || slash || backslash || percent)

def char_ok(+c: Char) -> Bool:
  +code = Char.to_u32(c)
  code_ok(U32.is_lt(code, 32), U32.is_eq(code, 127), Char.is_eq(c, '/'), U32.is_eq(code, 92), U32.is_eq(code, 37))

def chars_ok(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{+c, t}: char_ok(c) && chars_ok(t)

# A segment is nonempty and does not start with '.', which refuses ".", ".."
# and dotfiles such as .env or .git.
def segment_ok(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{+c, t}: Bool.not(U32.is_eq(Char.to_u32(c), 46)) && char_ok(c) && chars_ok(t)

def segments_ok(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: True{}
    case s <> t: segment_ok(s) && segments_ok(t)

def slash_count(b: Bool, n: Nat) -> Nat:
  match b:
    case True{}: 1n+n
    case False{}: n

# Literal '/' characters in a raw path.
def slashes(s: String) -> Nat:
  match s:
    case SNil{}: 0n
    case SCon{+c, t}: slash_count(Char.is_eq(c, '/'), slashes(t))

def join(rest: List<&2, String>, first: String) -> String:
  match rest:
    case Nil{}: first
    case h <> t: String.append(first, SCon{'/', join(t, h)})

# The final check, independent of how segments were decoded: every segment
# is safe, and there is one segment per '/' in the raw path, so decoding
# introduced no separator.
def check(+raw: String, +first: String, +rest: List<&2, String>) -> Bool:
  segment_ok(first) && segments_ok(rest) && Nat.is_eq(1n+List.length(&2, String, rest), slashes(raw))

def accept(first: String, rest: List<&2, String>, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}: Some{join(rest, first)}
    case False{}: None{}

def guard(+raw: String, m: Maybe<&2, Segments>) -> Maybe<&2, String>:
  match m:
    case None{}: None{}
    case Some{Segments{+first, +rest}}: accept(first, rest, check(raw, first, rest))

# An empty final segment (a trailing slash) names the directory's index.
def decode_last(raw: String, index: String) -> Maybe<&2, String>:
  match raw:
    case SNil{}: Some{index}
    case SCon{c, t}: E.decode(SCon{c, t})

def decode_go(rest: List<&2, String>, raw: String, +index: String) -> Maybe<&2, List<&2, String>>:
  match rest:
    case Nil{}:
      do Maybe<&2, List<&2, String>>:
        last : String <- decode_last(raw, index)
        return [last]
    case h <> t:
      do Maybe<&2, List<&2, String>>:
        x : String <- E.decode(raw)
        xs : List<&2, String> <- decode_go(t, h, index)
        return x <> xs

def segments_of(xs: Maybe<&2, List<&2, String>>) -> Maybe<&2, Segments>:
  match xs:
    case None{}: None{}
    case Some{Nil{}}: None{}
    case Some{h <> t}: Some{Segments{h, t}}

# The raw path must start with '/'. Each segment is percent-decoded once and
# must be valid UTF-8; an invalid escape or overlong sequence rejects it.
def split_raw(parts: List<&2, String>, +index: String) -> Maybe<&2, Segments>:
  match parts:
    case Nil{}: None{}
    case SNil{} <> Nil{}: None{}
    case SNil{} <> h <> t: segments_of(decode_go(t, h, index))
    case SCon{c, s} <> t: None{}

def segments(+raw: String, +index: String) -> Maybe<&2, Segments>:
  split_raw(String.split(raw, '/'), index)

# The relative path to open beneath the root, or None for a path that must
# not be served. `index` names the file served for a trailing slash; "" or
# any unsafe name turns that case into None.
def resolve(+raw: String, +index: String) -> Maybe<&2, String>:
  guard(raw, segments(raw, index))

def under(root: String, m: Maybe<&2, String>) -> Maybe<&2, String>:
  match m:
    case None{}: None{}
    case Some{rel}: Some{root ++ "/" ++ rel}

# The exact path handed to the open effect, which walks it beneath root.
def target(root: String, +raw: String, +index: String) -> Maybe<&2, String>:
  under(root, resolve(raw, index))
