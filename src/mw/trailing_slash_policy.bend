# Trailing-slash redirect targets as a pure function of the request method,
# path and raw query. src/mw/trailing_slash.bend decides when to redirect.
import Base
import ../http/request.bend as Request

type Mode is Data:
  Trim{}
  Append{}

# A character a browser could drop or turn into '/' while resolving a
# Location: controls, space, DEL and '\'.
def unsafe_char(c: Char) -> Bool:
  match c:
    case Chr{+x}: (x <= 32 : U32) || U32.is_eq(x, 127) || U32.is_eq(x, 92)

def clean_spec(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: Bool.not(unsafe_char(c)) && clean_spec(t)

# clean_spec as a tail loop over the reversed path (BND-84).
def clean_go(rev: String, acc: Bool) -> Bool:
  match rev:
    case SNil{}: acc
    case SCon{c, r}: clean_go(r, Bool.not(unsafe_char(c)) && acc)

def clean(s: String) -> Bool:
  clean_go(String.reverse(s), True{})

def second(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: Bool.not(Char.is_eq(c, '/'))

# A same-origin path: one leading '/', never "//" (which a browser reads as
# another host), and nothing a browser rewrites into that.
def safe(+s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{c, t}: Char.is_eq(c, '/') && second(t) && clean(SCon{c, t})

def guarded(+loc: String, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}: Some{loc}
    case False{}: None{}

def checked(+loc: String) -> Maybe<&2, String>:
  guarded(loc, safe(loc))

def slash_only(ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}: Some{""}
    case False{}: None{}

def prefixed(c: Char, m: Maybe<&2, String>) -> Maybe<&2, String>:
  match m:
    case None{}: None{}
    case Some{b}: Some{SCon{c, b}}

def trim_step(+c: Char, t: String, rest: Maybe<&2, String>) -> Maybe<&2, String>:
  match t:
    case SNil{}: slash_only(Char.is_eq(c, '/'))
    case SCon{d, u}: prefixed(c, rest)

def trim_last_spec(s: String) -> Maybe<&2, String>:
  match s:
    case SNil{}: None{}
    case SCon{+c, +t}: trim_step(c, t, trim_last_spec(t))

# Right folds run as tail loops over the reversed path (BND-84); the
# accumulator holds the suffix read so far and the spec's answer for it.
type Trimmed is Data:
  Trimmed{rest: String, trimmed: Maybe<&2, String>}

def trim_fold(+c: Char, acc: Trimmed) -> Trimmed:
  match acc:
    case Trimmed{+t, res}: Trimmed{SCon{c, t}, trim_step(c, t, res)}

def trim_answer(acc: Trimmed) -> Maybe<&2, String>:
  match acc:
    case Trimmed{t, res}: res

def trim_last_go(rev: String, acc: Trimmed) -> Maybe<&2, String>:
  match rev:
    case SNil{}: trim_answer(acc)
    case SCon{+c, r}: trim_last_go(r, trim_fold(c, acc))

# The path without its final '/', when it ends with one.
def trim_last(s: String) -> Maybe<&2, String>:
  trim_last_go(String.reverse(s), Trimmed{"", None{}})

def slash_step(+c: Char, t: String, rest: Bool) -> Bool:
  match t:
    case SNil{}: Char.is_eq(c, '/')
    case SCon{d, u}: rest

def final_slash_spec(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{+c, +t}: slash_step(c, t, final_slash_spec(t))

type Slashed is Data:
  Slashed{rest: String, slash: Bool}

def slash_fold(+c: Char, acc: Slashed) -> Slashed:
  match acc:
    case Slashed{+t, res}: Slashed{SCon{c, t}, slash_step(c, t, res)}

def slash_answer(acc: Slashed) -> Bool:
  match acc:
    case Slashed{t, res}: res

def final_slash_go(rev: String, acc: Slashed) -> Bool:
  match rev:
    case SNil{}: slash_answer(acc)
    case SCon{+c, r}: final_slash_go(r, slash_fold(c, acc))

# Whether the path ends with '/'.
def final_slash(s: String) -> Bool:
  final_slash_go(String.reverse(s), Slashed{"", False{}})

def located(base: Maybe<&2, String>, q: Maybe<&2, String>) -> Maybe<&2, String>:
  match base:
    case None{}: None{}
    case Some{b}: checked(b ++ Request.query_text(q))

def appended(+path: String, q: Maybe<&2, String>, ends: Bool) -> Maybe<&2, String>:
  match ends:
    case True{}: None{}
    case False{}: checked(path ++ ("/" ++ Request.query_text(q)))

def moved(mode: Mode, +path: String, q: Maybe<&2, String>) -> Maybe<&2, String>:
  match mode:
    case Trim{}: located(trim_last(path), q)
    case Append{}: appended(path, q, final_slash(path))

# The Location for a GET or HEAD whose path should gain or lose its final
# '/', keeping the raw query. "/" is never trimmed, and a target that is not
# a safe same-origin path, such as "//evil.example", is never produced.
def target(mode: Mode, method: Request.Method, +path: String, q: Maybe<&2, String>) -> Maybe<&2, String>:
  match method:
    case Request.Get{}: moved(mode, path, q)
    case Request.Head{}: moved(mode, path, q)
    case Request.Post{}: None{}
    case Request.Put{}: None{}
    case Request.Delete{}: None{}
    case Request.Connect{}: None{}
    case Request.Options{}: None{}
    case Request.Trace{}: None{}
    case Request.Patch{}: None{}
    case Request.Extension{t}: None{}
