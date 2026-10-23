# HTTP bytes are octets, never UTF-8 decoded text (decision 0002).
import Base

def append(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, xs, ys)

def encode(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      []
    case SCon{Chr{c}, t}:
      c <> encode(t)

# Only use after ASCII validation; this does not decode UTF-8.
def ascii(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      SCon{Chr{h}, ascii(t)}

def tchar(+c: U32) -> Bool:
  ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || String.contains("!#$%&'*+-.^_`|~", Char.show(Chr{c}))

def token_tail(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{c}, t}:
      tchar(c) && token_tail(t)

def token(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{c}, t}:
      tchar(c) && token_tail(t)

def ows(+c: U32) -> Bool:
  U32.is_eq(c, 32) || U32.is_eq(c, 9)

def trim_start(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      []
    case 9 <> xs:
      trim_start(xs)
    case 32 <> xs:
      trim_start(xs)
    case c <> xs:
      c <> xs

def trim(xs: List<&2, U32>) -> List<&2, U32>:
  List.reverse(&2, U32, trim_start(List.reverse(&2, U32, trim_start(xs))))

def value_octet(+c: U32) -> Bool:
  U32.is_eq(c, 9) || ((c >= 32 : U32) && (c <= 255 : U32) && U32.is_ne(c, 127))

def value(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      value_octet(h) && value(t)

# ASCII folding only; Base's Char.to_lower also uses ASCII ranges.
def fold(s: String) -> String:
  String.to_lower(s)

def hex(+c: U32) -> Bool:
  ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 70 : U32)) || ((c >= 97 : U32) && (c <= 102 : U32))

# RFC 3986 pchar plus slash; '?' is additionally allowed in a query.
def uri_char(+c: U32, query: Bool) -> Bool:
  ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || String.contains("-._~!$&'()*+,;=:@/", Char.show(Chr{c})) || (query && U32.is_eq(c, 63))

def uri(s: String, +query: Bool) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{37}, SCon{Chr{a}, SCon{Chr{b}, t}}}:
      hex(a) && hex(b) && uri(t, query)
    case SCon{Chr{c}, t}:
      uri_char(c, query) && uri(t, query)

def split_push(c: Char, parts: String & Maybe<&2, String>) -> String & Maybe<&2, String>:
  (p, q) = parts
  (SCon{c, p}, q)

# Only the first '?' separates the path and query; an empty query is Some{""}.
def split_target(s: String) -> String & Maybe<&2, String>:
  match s:
    case SNil{}:
      ("", None{})
    case SCon{Chr{63}, t}:
      ("", Some{t})
    case SCon{c, t}:
      split_push(c, split_target(t))

def prefix_pair(parts: String & Maybe<&2, String>) -> String:
  (p, q) = parts
  p

def prefix(s: String) -> String:
  prefix_pair(split_target(s))
