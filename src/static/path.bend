# Static file path resolution (BND-45). Pure, so LAWS.bend can state over
# every request path that a resolved path stays inside the static root.
# `raw` is the undecoded request path after the mount prefix, such as
# "/assets/app.js" or "/docs/". See docs/static.md.
#
# Every loop over the path or its segments is a tail call, so a long request
# path cannot exhaust the JavaScript stack (BND-84).
# proof/static-path-equiv.bend proves this resolver equal to the recursive
# one in proof/static-path-model.bend, which carries the BND-45 proofs.
import Base
import ../router/encoding.bend as E
import ../http/text.bend as Text

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

def chars_go(s: String, ok: Bool) -> Bool:
  match s:
    case SNil{}: ok
    case SCon{+c, t}: chars_go(t, ok && char_ok(c))

def chars_ok(s: String) -> Bool:
  chars_go(s, True{})

# A segment is nonempty and does not start with '.', which refuses ".", ".."
# and dotfiles such as .env or .git.
def segment_ok(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{+c, t}: Bool.not(U32.is_eq(Char.to_u32(c), 46)) && char_ok(c) && chars_ok(t)

def segments_go(xs: List<&2, String>, ok: Bool) -> Bool:
  match xs:
    case Nil{}: ok
    case s <> t: segments_go(t, ok && segment_ok(s))

def segments_ok(xs: List<&2, String>) -> Bool:
  segments_go(xs, True{})

def slash_count(b: Bool, n: Nat) -> Nat:
  match b:
    case True{}: 1n+n
    case False{}: n

def slashes_go(s: String, n: Nat) -> Nat:
  match s:
    case SNil{}: n
    case SCon{+c, t}: slashes_go(t, slash_count(Char.is_eq(c, '/'), n))

# Literal '/' characters in a raw path.
def slashes(s: String) -> Nat:
  slashes_go(s, 0n)

def count_go(xs: List<&2, String>, n: Nat) -> Nat:
  match xs:
    case Nil{}: n
    case h <> t: count_go(t, 1n+n)

# List.length, counted in a tail loop.
def count(xs: List<&2, String>) -> Nat:
  count_go(xs, 0n)

# `out` holds the joined prefix reversed; each segment is pushed onto it
# after a '/'. Appending instead would be quadratic in native builds.
def join_go(rest: List<&2, String>, out: String) -> String:
  match rest:
    case Nil{}: out
    case h <> t: join_go(t, String.reverse.go(h, SCon{'/', out}))

def join(rest: List<&2, String>, first: String) -> String:
  String.reverse(join_go(rest, String.reverse(first)))

# The final check, independent of how segments were decoded: every segment
# is safe and free of '/', and there is one segment per '/' in the raw path.
def check(+raw: String, +first: String, +rest: List<&2, String>) -> Bool:
  segment_ok(first) && segments_ok(rest) && Nat.is_eq(1n+count(rest), slashes(raw))

def accept(first: String, rest: List<&2, String>, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}: Some{join(rest, first)}
    case False{}: None{}

def guard(+raw: String, m: Maybe<&2, Segments>) -> Maybe<&2, String>:
  match m:
    case None{}: None{}
    case Some{Segments{+first, +rest}}: accept(first, rest, check(raw, first, rest))

# A plain character is printable ASCII other than space, '%', '/' and '\'.
# Percent-decoding leaves a run of them unchanged, so a plain segment skips
# the decoder. The tests are Bools so the completeness proofs can split them.
def plain_code(control: Bool, space: Bool, delete: Bool, high: Bool, slash: Bool, backslash: Bool, percent: Bool) -> Bool:
  Bool.not(control || space || delete || high || slash || backslash || percent)

def plain_char(+c: Char) -> Bool:
  +code = Char.to_u32(c)
  plain_code(U32.is_lt(code, 32), U32.is_eq(code, 32), U32.is_eq(code, 127), U32.is_lt(127, code), Char.is_eq(c, '/'), U32.is_eq(code, 92), U32.is_eq(code, 37))

def plain_go(s: String, ok: Bool) -> Bool:
  match s:
    case SNil{}: ok
    case SCon{+c, t}: plain_go(t, ok && plain_char(c))

def plain(s: String) -> Bool:
  plain_go(s, True{})

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

def push_piece(acc: Maybe<&2, List<&2, String>>, x: Maybe<&2, String>) -> Maybe<&2, List<&2, String>>:
  match acc x:
    case Some{ys} Some{y}: Some{y <> ys}
    case _ _: None{}

def finish(acc: Maybe<&2, List<&2, String>>, x: Maybe<&2, String>) -> Maybe<&2, List<&2, String>>:
  match acc x:
    case Some{ys} Some{y}: Some{List.reverse(&2, String, y <> ys)}
    case _ _: None{}

# Each raw segment decodes on its own, so one segment yields one piece.
# `acc` holds the pieces so far, most recent first.
def decode_go_loop(rest: List<&2, String>, raw: String, +index: String, acc: Maybe<&2, List<&2, String>>) -> Maybe<&2, List<&2, String>>:
  match rest:
    case Nil{}: finish(acc, decode_last(raw, index))
    case h <> t: decode_go_loop(t, h, index, push_piece(acc, decode_segment(raw)))

# Keep the original helper interface; only its worker carries state.
def decode_go(rest: List<&2, String>, raw: String, index: String) -> Maybe<&2, List<&2, String>>:
  decode_go_loop(rest, raw, index, Some{Nil{}})

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
  split_raw(Text.split(raw, '/'), index)

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
