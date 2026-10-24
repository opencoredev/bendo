# HTTP bytes are octets, never UTF-8 decoded text (decision 0002).
# Every loop over request-sized input is a tail call (BND-84); each *_spec
# def keeps the earlier direct recursion, and LAWS.bend equates the two.
import Base
import ./text.bend as Text

def append(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  Text.bytes_append(xs, ys)

def encode_spec(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      []
    case SCon{Chr{c}, t}:
      c <> encode_spec(t)

# Prepends the code of each character of a reversed string.
def encode_go(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, t}:
      encode_go(t, c <> acc)

def encode(s: String) -> List<&2, U32>:
  encode_go(String.reverse(s), [])

def ascii_spec(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      SCon{Chr{h}, ascii_spec(t)}

def ascii_go(xs: List<&2, U32>, acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      ascii_go(t, SCon{Chr{h}, acc})

# Only use after ASCII validation; this does not decode UTF-8.
def ascii(xs: List<&2, U32>) -> String:
  ascii_go(List.reverse(&2, U32, xs), "")

# RFC 9110 tchar. Bool.or is eager, so this spec builds and searches the
# punctuation string for every character, letters and digits included.
def tchar_spec(+c: U32) -> Bool:
  ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || String.contains("!#$%&'*+-.^_`|~", Char.show(Chr{c}))

# The punctuation search as a chain of branches, one per character in the
# spec's order; `hit` is the comparison with that character (BND-68).
def tchar_punct_14(c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      False{}

def tchar_punct_13(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_14(c, U32.is_eq(126, c))

def tchar_punct_12(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_13(c, U32.is_eq(124, c))

def tchar_punct_11(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_12(c, U32.is_eq(96, c))

def tchar_punct_10(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_11(c, U32.is_eq(95, c))

def tchar_punct_9(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_10(c, U32.is_eq(94, c))

def tchar_punct_8(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_9(c, U32.is_eq(46, c))

def tchar_punct_7(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_8(c, U32.is_eq(45, c))

def tchar_punct_6(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_7(c, U32.is_eq(43, c))

def tchar_punct_5(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_6(c, U32.is_eq(42, c))

def tchar_punct_4(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_5(c, U32.is_eq(39, c))

def tchar_punct_3(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_4(c, U32.is_eq(38, c))

def tchar_punct_2(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_3(c, U32.is_eq(37, c))

def tchar_punct_1(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_2(c, U32.is_eq(36, c))

def tchar_punct_0(+c: U32, hit: Bool) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      tchar_punct_1(c, U32.is_eq(35, c))

def tchar_pick(+c: U32, alnum: Bool) -> Bool:
  match alnum:
    case True{}:
      True{}
    case False{}:
      tchar_punct_0(c, U32.is_eq(33, c))

# Equal to tchar_spec for every U32 (law hot_bytes_tchar), without the
# allocation, and letters and digits skip the punctuation tests.
def tchar(+c: U32) -> Bool:
  tchar_pick(c, ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)))

def token_tail_spec(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{c}, t}:
      tchar(c) && token_tail_spec(t)

# Bool.and is strict in the JavaScript target, so `p && go(t)` is not a tail
# call. Fold the verdict into an accumulator instead.
def token_go(s: String, acc: Bool) -> Bool:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, t}:
      token_go(t, acc && tchar(c))

def token_tail(s: String) -> Bool:
  token_go(s, True{})

def token(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{c}, t}:
      tchar(c) && token_tail(t)

def ows(+c: U32) -> Bool:
  U32.is_eq(c, 32) || U32.is_eq(c, 9)

# c is the octet read before xs, and space whether it is SP or HTAB. The
# octet tests are Bool values rather than literal patterns, so proofs can
# split on them (BND-85).
def trim_lead(xs: List<&2, U32>, +c: U32, space: Bool) -> List<&2, U32>:
  match xs space:
    case Nil{} False{}:
      [c]
    case Nil{} True{}:
      []
    case +d <> t False{}:
      c <> (d <> t)
    case +d <> t True{}:
      trim_lead(t, d, ows(d))

def trim_start(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      []
    case +c <> t:
      trim_lead(t, c, ows(c))

# Without leading and trailing SP and HTAB. proof/trim-spec.bend states this
# for every input.
def trim(xs: List<&2, U32>) -> List<&2, U32>:
  List.reverse(&2, U32, trim_start(List.reverse(&2, U32, trim_start(xs))))

# The same trim over text, one character per code.
def trim_text(s: String) -> String:
  ascii(trim(encode(s)))

def value_octet(+c: U32) -> Bool:
  U32.is_eq(c, 9) || ((c >= 32 : U32) && (c <= 255 : U32) && U32.is_ne(c, 127))

def value_spec(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      value_octet(h) && value_spec(t)

def value_go(xs: List<&2, U32>, acc: Bool) -> Bool:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      value_go(t, acc && value_octet(h))

def value(xs: List<&2, U32>) -> Bool:
  value_go(xs, True{})

# ASCII folding only; Base's Char.to_lower also uses ASCII ranges.
def fold(s: String) -> String:
  Text.lower(s)

def hex(+c: U32) -> Bool:
  ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 70 : U32)) || ((c >= 97 : U32) && (c <= 102 : U32))

# RFC 3986 pchar plus slash; '?' is additionally allowed in a query.
def uri_char(+c: U32, query: Bool) -> Bool:
  ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || String.contains("-._~!$&'()*+,;=:@/", Char.show(Chr{c})) || (query && U32.is_eq(c, 63))

def uri_spec(s: String, +query: Bool) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{37}, SCon{Chr{a}, SCon{Chr{b}, t}}}:
      hex(a) && hex(b) && uri_spec(t, query)
    case SCon{Chr{c}, t}:
      uri_char(c, query) && uri_spec(t, query)

# The same patterns as uri_spec, so the two reduce in step in proofs.
def uri_go(s: String, +query: Bool, acc: Bool) -> Bool:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{37}, SCon{Chr{a}, SCon{Chr{b}, t}}}:
      uri_go(t, query, acc && (hex(a) && hex(b)))
    case SCon{Chr{c}, t}:
      uri_go(t, query, acc && uri_char(c, query))

def uri(s: String, +query: Bool) -> Bool:
  uri_go(s, query, True{})

def split_push(c: Char, parts: String & Maybe<&2, String>) -> String & Maybe<&2, String>:
  (p, q) = parts
  (SCon{c, p}, q)

def split_target_spec(s: String) -> String & Maybe<&2, String>:
  match s:
    case SNil{}:
      ("", None{})
    case SCon{Chr{63}, t}:
      ("", Some{t})
    case SCon{c, t}:
      split_push(c, split_target_spec(t))

# rev holds the path read so far, reversed.
def split_target_go(s: String, rev: String) -> String & Maybe<&2, String>:
  match s:
    case SNil{}:
      (String.reverse(rev), None{})
    case SCon{Chr{63}, t}:
      (String.reverse(rev), Some{t})
    case SCon{c, t}:
      split_target_go(t, SCon{c, rev})

# Only the first '?' separates the path and query; an empty query is Some{""}.
def split_target(s: String) -> String & Maybe<&2, String>:
  split_target_go(s, "")

def prefix_pair(parts: String & Maybe<&2, String>) -> String:
  (p, q) = parts
  p

def prefix(s: String) -> String:
  prefix_pair(split_target(s))
