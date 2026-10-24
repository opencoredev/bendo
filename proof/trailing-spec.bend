# BND-40: what a trailing-slash redirect target must be.
import Base
import ../src/http/request.bend as Request
import ../src/mw/trailing_slash_policy.bend as P
import ./csrf-spec.bend as CsrfSpec

# Characters a browser may strip or read as '/' while resolving a Location:
# C0 controls, space, DEL and backslash.
def resolver_char(c: Char) -> Bool:
  match c:
    case Chr{+x}: (x <= 32 : U32) || U32.is_eq(x, 127) || U32.is_eq(x, 92)

def plain(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: Bool.not(resolver_char(c)) && plain(t)

def not_slash(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: Bool.not(Char.is_eq(c, '/'))

# A Location that stays on this origin: it starts with exactly one '/', so a
# browser cannot read it as "//host", and has no character that a browser
# could strip or turn into '/' to form one.
def same_origin_path(+s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{c, t}: Char.is_eq(c, '/') && not_slash(t) && plain(SCon{c, t})

def ends_here(+c: Char, t: String, rest: Bool) -> Bool:
  match t:
    case SNil{}: Char.is_eq(c, '/')
    case SCon{d, u}: rest

# The last character is '/'.
def final_slash(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{+c, +t}: ends_here(c, t, final_slash(t))

def empty_if(slash: Bool) -> Maybe<&2, String>:
  match slash:
    case True{}: Some{""}
    case False{}: None{}

def last_dropped(+c: Char, t: String, rest: Maybe<&2, String>) -> Maybe<&2, String>:
  match t rest:
    case SNil{} r: empty_if(Char.is_eq(c, '/'))
    case SCon{d, u} None{}: None{}
    case SCon{d, u} Some{b}: Some{SCon{c, b}}

# The text before a final '/', when the last character is '/'.
def before_final_slash(s: String) -> Maybe<&2, String>:
  match s:
    case SNil{}: None{}
    case SCon{+c, +t}: last_dropped(c, t, before_final_slash(t))

def offered(+loc: String, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}: Some{loc}
    case False{}: None{}

# A target is offered only when it is a same-origin path.
def offer(+loc: String) -> Maybe<&2, String>:
  offered(loc, same_origin_path(loc))

def trimmed(base: Maybe<&2, String>, q: Maybe<&2, String>) -> Maybe<&2, String>:
  match base:
    case None{}: None{}
    case Some{b}: offer(b ++ Request.query_text(q))

def extended(+path: String, q: Maybe<&2, String>, ends: Bool) -> Maybe<&2, String>:
  match ends:
    case True{}: None{}
    case False{}: offer(path ++ ("/" ++ Request.query_text(q)))

def moved(mode: P.Mode, +path: String, q: Maybe<&2, String>) -> Maybe<&2, String>:
  match mode:
    case P.Trim{}: trimmed(before_final_slash(path), q)
    case P.Append{}: extended(path, q, final_slash(path))

def gated(reads: Bool, x: Maybe<&2, String>) -> Maybe<&2, String>:
  match reads:
    case True{}: x
    case False{}: None{}

# The full target: only GET and HEAD move. Trim moves a path ending in '/'
# to the text before that '/'; append moves a path not ending in '/' to the
# path plus '/'. Either keeps the raw query and is offered only when the
# result is a same-origin path. Every other request stays where it is.
def target(mode: P.Mode, m: Request.Method, +path: String, q: Maybe<&2, String>) -> Maybe<&2, String>:
  gated(CsrfSpec.reads_only(m), moved(mode, path, q))
