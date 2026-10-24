# The recursive static path resolver that BND-45 proved, kept as the model
# for src/static/path.bend (BND-84). The production resolver replaces each
# recursion below with a tail loop; proof/static-path-equiv.bend proves the
# two equal, and proof/static-path.bend proves the laws against this model.
# It shares the production Segments type.
import Base
import ../src/router/encoding.bend as E
import ../src/static/path.bend as Path

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
# is safe and free of '/', and there is one segment per '/' in the raw path.
def check(+raw: String, +first: String, +rest: List<&2, String>) -> Bool:
  segment_ok(first) && segments_ok(rest) && Nat.is_eq(1n+List.length(&2, String, rest), slashes(raw))

def accept(first: String, rest: List<&2, String>, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}: Some{join(rest, first)}
    case False{}: None{}

def guard(+raw: String, m: Maybe<&2, Path.Segments>) -> Maybe<&2, String>:
  match m:
    case None{}: None{}
    case Some{Path.Segments{+first, +rest}}: accept(first, rest, check(raw, first, rest))

# A plain character is printable ASCII other than space, '%', '/' and '\'.
# Percent-decoding leaves a run of them unchanged, so a plain segment skips
# the decoder. The tests are Bools so the completeness proofs can split them.
def plain_code(control: Bool, space: Bool, delete: Bool, high: Bool, slash: Bool, backslash: Bool, percent: Bool) -> Bool:
  Bool.not(control || space || delete || high || slash || backslash || percent)

def plain_char(+c: Char) -> Bool:
  +code = Char.to_u32(c)
  plain_code(U32.is_lt(code, 32), U32.is_eq(code, 32), U32.is_eq(code, 127), U32.is_lt(127, code), Char.is_eq(c, '/'), U32.is_eq(code, 92), U32.is_eq(code, 37))

def plain(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{+c, t}: plain_char(c) && plain(t)

def decoded(+s: String, plain: Bool) -> Maybe<&2, String>:
  match plain:
    case True{}: Some{s}
    case False{}: E.decode(s)

# One raw segment, percent-decoded on its own.
def decode_segment(+s: String) -> Maybe<&2, String>:
  decoded(s, plain(s))

# An empty final segment (a trailing slash) names the directory's index.
def decode_last(raw: String, index: String) -> Maybe<&2, String>:
  match raw:
    case SNil{}: Some{index}
    case SCon{c, t}: decode_segment(SCon{c, t})

def single(x: Maybe<&2, String>) -> Maybe<&2, List<&2, String>>:
  match x:
    case None{}: None{}
    case Some{y}: Some{[y]}

def prepend_to(y: String, xs: Maybe<&2, List<&2, String>>) -> Maybe<&2, List<&2, String>>:
  match xs:
    case None{}: None{}
    case Some{ys}: Some{y <> ys}

def prepend(x: Maybe<&2, String>, xs: Maybe<&2, List<&2, String>>) -> Maybe<&2, List<&2, String>>:
  match x:
    case None{}: None{}
    case Some{y}: prepend_to(y, xs)

# Each raw segment decodes on its own, so one segment yields one piece.
def decode_go(rest: List<&2, String>, raw: String, +index: String) -> Maybe<&2, List<&2, String>>:
  match rest:
    case Nil{}: single(decode_last(raw, index))
    case h <> t: prepend(decode_segment(raw), decode_go(t, h, index))

def segments_of(xs: Maybe<&2, List<&2, String>>) -> Maybe<&2, Path.Segments>:
  match xs:
    case None{}: None{}
    case Some{Nil{}}: None{}
    case Some{h <> t}: Some{Path.Segments{h, t}}

# The raw path must start with '/'. Each segment is percent-decoded once and
# must be valid UTF-8; an invalid escape or overlong sequence rejects it.
def split_raw(parts: List<&2, String>, +index: String) -> Maybe<&2, Path.Segments>:
  match parts:
    case Nil{}: None{}
    case SNil{} <> Nil{}: None{}
    case SNil{} <> h <> t: segments_of(decode_go(t, h, index))
    case SCon{c, s} <> t: None{}

def segments(+raw: String, +index: String) -> Maybe<&2, Path.Segments>:
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
