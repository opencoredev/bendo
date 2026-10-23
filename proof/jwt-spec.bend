# BND-43: independent specifications for the JWT structure and header laws.
# Nothing here calls the verifier's helpers; the JWT import is for its types.
import Base
import ../src/data/json.bend as Json
import ../src/crypto/jwt.bend as Jwt

def count_dot(here: Bool, n: Nat) -> Nat:
  match here:
    case True{}:
      1n+n
    case False{}:
      n

# The number of '.' characters in s.
def dots(s: String) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{+c, t}:
      count_dot(Char.is_eq(c, '.'), dots(t))

# True for every failure, whatever its error.
def failed(r: Result<&2, &2, Jwt.Error, Json.Json>) -> Bool:
  match r:
    case Fail{e}:
      True{}
    case Done{v}:
      False{}

def count_if(hit: Bool, n: Nat) -> Nat:
  match hit:
    case True{}:
      1n+n
    case False{}:
      n

# The JSON string "HS256".
def hs256(v: Json.Json) -> Bool:
  match v:
    case Json.JString{s}:
      String.eq(s, "HS256")
    case _:
      False{}

# How many top-level members are named "alg".
def alg_members(fields: List<&2, Json.Field>) -> Nat:
  match fields:
    case Nil{}:
      0n
    case Json.Field{k, v} <> t:
      count_if(String.eq(k, "alg"), alg_members(t))

# How many top-level members are named "alg" and hold the string "HS256".
def hs256_members(fields: List<&2, Json.Field>) -> Nat:
  match fields:
    case Nil{}:
      0n
    case Json.Field{k, v} <> t:
      count_if(String.eq(k, "alg") && hs256(v), hs256_members(t))

# A header names HS256 exactly when it has exactly one "alg" member and that
# member is the string "HS256". An absent, repeated or non-string alg fails.
def alg_accepted(+fields: List<&2, Json.Field>) -> Bool:
  Nat.is_eq(alg_members(fields), 1n) && Nat.is_eq(hs256_members(fields), 1n)

def named(+key: String, fields: List<&2, Json.Field>) -> Bool:
  match fields:
    case Nil{}:
      False{}
    case Json.Field{k, v} <> t:
      String.eq(k, key) || named(key, t)

# No two top-level members share a name.
def distinct(fields: List<&2, Json.Field>) -> Bool:
  match fields:
    case Nil{}:
      True{}
    case Json.Field{+k, v} <> +t:
      Bool.not(named(k, t)) && distinct(t)

# The 64 characters of the base64url alphabet (RFC 4648 section 5).
def url_char(c: Char) -> Bool:
  match c:
    case 'A': True{}
    case 'B': True{}
    case 'C': True{}
    case 'D': True{}
    case 'E': True{}
    case 'F': True{}
    case 'G': True{}
    case 'H': True{}
    case 'I': True{}
    case 'J': True{}
    case 'K': True{}
    case 'L': True{}
    case 'M': True{}
    case 'N': True{}
    case 'O': True{}
    case 'P': True{}
    case 'Q': True{}
    case 'R': True{}
    case 'S': True{}
    case 'T': True{}
    case 'U': True{}
    case 'V': True{}
    case 'W': True{}
    case 'X': True{}
    case 'Y': True{}
    case 'Z': True{}
    case 'a': True{}
    case 'b': True{}
    case 'c': True{}
    case 'd': True{}
    case 'e': True{}
    case 'f': True{}
    case 'g': True{}
    case 'h': True{}
    case 'i': True{}
    case 'j': True{}
    case 'k': True{}
    case 'l': True{}
    case 'm': True{}
    case 'n': True{}
    case 'o': True{}
    case 'p': True{}
    case 'q': True{}
    case 'r': True{}
    case 's': True{}
    case 't': True{}
    case 'u': True{}
    case 'v': True{}
    case 'w': True{}
    case 'x': True{}
    case 'y': True{}
    case 'z': True{}
    case '0': True{}
    case '1': True{}
    case '2': True{}
    case '3': True{}
    case '4': True{}
    case '5': True{}
    case '6': True{}
    case '7': True{}
    case '8': True{}
    case '9': True{}
    case '-': True{}
    case '_': True{}
    case _: False{}

# base64url characters whose value is a multiple of 16: the low four bits,
# unused after two final characters, are zero.
def last4(c: Char) -> Bool:
  match c:
    case 'A': True{}
    case 'Q': True{}
    case 'g': True{}
    case 'w': True{}
    case _: False{}

# base64url characters whose value is a multiple of 4: the low two bits,
# unused after three final characters, are zero.
def last2(c: Char) -> Bool:
  match c:
    case 'A': True{}
    case 'E': True{}
    case 'I': True{}
    case 'M': True{}
    case 'Q': True{}
    case 'U': True{}
    case 'Y': True{}
    case 'c': True{}
    case 'g': True{}
    case 'k': True{}
    case 'o': True{}
    case 's': True{}
    case 'w': True{}
    case '0': True{}
    case '4': True{}
    case '8': True{}
    case _: False{}

# Strict unpadded base64url (RFC 4648 section 5, no padding): only alphabet
# characters, a length that is not 1 more than a multiple of 4, and zero
# unused bits in the final character of a 2- or 3-character tail.
def base64url(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{a, SNil{}}:
      False{}
    case SCon{a, SCon{b, SNil{}}}:
      url_char(a) && last4(b)
    case SCon{a, SCon{b, SCon{c, SNil{}}}}:
      url_char(a) && url_char(b) && last2(c)
    case SCon{a, SCon{b, SCon{c, SCon{d, t}}}}:
      url_char(a) && url_char(b) && url_char(c) && url_char(d) && base64url(t)
