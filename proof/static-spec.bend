# BND-45: an independent statement of what a confined static path is. It
# shares no code with src/static/path.bend. It reads a relative path by
# splitting it on '/' with Base's String.split and checks every piece.
# Decoding a single segment uses the router's percent decoder.
import Base
import ../src/router/encoding.bend as Url

def empty(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: False{}

def dot(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{code}, t}: U32.is_eq(code, 46) && empty(t)

def dotdot(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{code}, t}: U32.is_eq(code, 46) && dot(t)

# No control character (code below 32, which includes NUL), no DEL, no
# backslash and no '%', so no encoded separator or escape remains. A '/'
# cannot occur inside a piece of a split.
def char_safe(+code: U32) -> Bool:
  Bool.not(U32.is_lt(code, 32)) && Bool.not(U32.is_eq(code, 127)) && Bool.not(U32.is_eq(code, 92)) && Bool.not(U32.is_eq(code, 37))

def chars_safe(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+code}, t}: char_safe(code) && chars_safe(t)

# An in-root segment: not empty, not ".", not "..", and only safe characters.
def segment_safe(+s: String) -> Bool:
  Bool.not(empty(s)) && Bool.not(dot(s)) && Bool.not(dotdot(s)) && chars_safe(s)

def all_safe(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: True{}
    case s <> t: segment_safe(s) && all_safe(t)

def pieces(s: String) -> List<&2, String>:
  String.split(s, '/')

# A resolution is confined when it is refused, or when its relative path
# consists only of in-root segments and has exactly as many segments as the
# raw request path has after its leading '/'. The count rules out a decoded
# '/' that would add a separator the request did not contain.
def confined(raw: String, resolved: Maybe<&2, String>) -> Bool:
  match resolved:
    case None{}: True{}
    case Some{+rel}:
      all_safe(pieces(rel)) && Nat.is_eq(1n+List.length(&2, String, pieces(rel)), List.length(&2, String, pieces(raw)))

# The path the open effect receives for a relative path under a root.
def opened(root: String, resolved: Maybe<&2, String>) -> Maybe<&2, String>:
  match resolved:
    case None{}: None{}
    case Some{rel}: Some{root ++ "/" ++ rel}

# Per-segment decoding. A segment of printable ASCII other than space, '%',
# '/' and '\' contains no escape, so it decodes to itself; any other segment
# goes through the router's percent decoder.
def plain_char(+code: U32) -> Bool:
  Bool.not(U32.is_lt(code, 32)) && Bool.not(U32.is_eq(code, 32)) && Bool.not(U32.is_eq(code, 127)) && Bool.not(U32.is_lt(127, code)) && Bool.not(Char.is_eq(Chr{code}, '/')) && Bool.not(U32.is_eq(code, 92)) && Bool.not(U32.is_eq(code, 37))

def plain(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+code}, t}: plain_char(code) && plain(t)

def decode_plain(+s: String, p: Bool) -> Maybe<&2, String>:
  match p:
    case True{}: Some{s}
    case False{}: Url.decode(s)

def decode(+s: String) -> Maybe<&2, String>:
  decode_plain(s, plain(s))

# The final raw segment: empty after a trailing '/', it names the index.
def decode_final(s: String, index: String) -> Maybe<&2, String>:
  match s:
    case SNil{}: Some{index}
    case SCon{c, t}: decode(SCon{c, t})

def cons(x: String, xs: Maybe<&2, List<&2, String>>) -> Maybe<&2, List<&2, String>>:
  match xs:
    case None{}: None{}
    case Some{ys}: Some{x <> ys}

def cons_decoded(x: Maybe<&2, String>, xs: Maybe<&2, List<&2, String>>) -> Maybe<&2, List<&2, String>>:
  match x:
    case None{}: None{}
    case Some{y}: cons(y, xs)

def final_only(x: Maybe<&2, String>) -> Maybe<&2, List<&2, String>>:
  match x:
    case None{}: None{}
    case Some{y}: Some{[y]}

# Decode each raw segment h, rest... separately, in order.
def decode_each(rest: List<&2, String>, h: String, +index: String) -> Maybe<&2, List<&2, String>>:
  match rest:
    case Nil{}: final_only(decode_final(h, index))
    case r <> t: cons_decoded(decode(h), decode_each(t, r, index))

def after_root(ps: List<&2, String>, +index: String) -> Maybe<&2, List<&2, String>>:
  match ps:
    case Nil{}: None{}
    case SNil{} <> Nil{}: None{}
    case SNil{} <> h <> t: decode_each(t, h, index)
    case SCon{c, s} <> t: None{}

# The raw path's segments after its leading '/', each decoded on its own.
def decoded(+raw: String, +index: String) -> Maybe<&2, List<&2, String>>:
  after_root(pieces(raw), index)

# The pieces of a resolution, and the decoded segments only when resolved.
def resolved_pieces(resolved: Maybe<&2, String>) -> Maybe<&2, List<&2, String>>:
  match resolved:
    case None{}: None{}
    case Some{rel}: Some{pieces(rel)}

def when_resolved(resolved: Maybe<&2, String>, xs: Maybe<&2, List<&2, String>>) -> Maybe<&2, List<&2, String>>:
  match resolved:
    case None{}: None{}
    case Some{rel}: xs

# Dotfiles: no piece of a resolution starts with '.'.
def visible(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{code}, t}: Bool.not(U32.is_eq(code, 46))

def all_visible(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: True{}
    case s <> t: visible(s) && all_visible(t)

def no_dotfiles(resolved: Maybe<&2, String>) -> Bool:
  match resolved:
    case None{}: True{}
    case Some{rel}: all_visible(pieces(rel))

# Completeness. A servable segment is plain, nonempty and does not start
# with '.'. `request` writes segments as a request path, "/a/b"; `directory`
# writes them with a trailing slash, "/a/b/" (or "/" for none).
def servable_segment(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+code}, t}: Bool.not(U32.is_eq(code, 46)) && plain(SCon{Chr{code}, t})

def servable(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: True{}
    case s <> t: servable_segment(s) && servable(t)

def request(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}: SNil{}
    case s <> t: SCon{'/', String.append(s, request(t))}

def directory(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}: "/"
    case s <> t: SCon{'/', String.append(s, directory(t))}

# The segments first, rest... joined by '/'.
def joined(rest: List<&2, String>, first: String) -> String:
  match rest:
    case Nil{}: first
    case h <> t: String.append(first, SCon{'/', joined(t, h)})

# Segments joined by '/', then the index as the last segment.
def joined_index(xs: List<&2, String>, index: String) -> String:
  match xs:
    case Nil{}: index
    case s <> t: String.append(s, SCon{'/', joined_index(t, index)})
