# BND-45: an independent statement of what a confined static path is. It
# shares no code with src/static/path.bend. It reads a relative path by
# splitting it on '/' with Base's String.split and checks every piece.
import Base

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
