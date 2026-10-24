# Independent authentication relation: compare HMAC bytes structurally.
import Base
import ../src/data/utf8.bend as Utf8
import ../src/crypto/hmac.bend as Hmac
import ../src/data/signed-cookie.bend as S
import ../src/data/cookie.bend as Cookie
import ../src/data/base64.bend as Base64
import ../src/data/urlencoded.bend as Url
import ../src/http/request.bend as Request

def bit_equal(a: Bool, b: Bool) -> Bool:
  match a b:
    case False{} False{}: True{}
    case True{} True{}: True{}
    case _ _: False{}

def word_equal(n: Nat, a: Word(n), b: Word(n)) -> Bool:
  match n a b:
    case 0n WNil{} WNil{}: True{}
    case 1n+p WCon{a, at} WCon{b, bt}:
      bit_equal(a, b) && word_equal(p, at, bt)

def u32_equal(a: U32, b: U32) -> Bool:
  match a b:
    case U32{aw} U32{bw}: word_equal(32n, aw, bw)

def bytes_equal(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}: True{}
    case U32{a} <> at U32{b} <> bt:
      word_equal(32n, a, b) && bytes_equal(at, bt)
    case _ _: False{}

def authentic(keys: List<&2, String>, +value: String, +signature: List<&2, U32>) -> Bool:
  match keys:
    case Nil{}: False{}
    case key <> rest:
      bytes_equal(Hmac.sha256(Utf8.encode(key), Utf8.encode(value)), signature) || authentic(rest, value, signature)

# Membership is structural string equality expressed as propositional evidence.
def contains(+key: String, keys: List<&2, String>) -> Type:
  match keys:
    case Nil{}: Empty
    case first <> rest: {key == first : String} | contains(key, rest)

def different(keys: List<&2, String>, +value: String, +signature: List<&2, U32>) -> Type:
  match keys:
    case Nil{}: Unit
    case key <> rest:
      {Hmac.sha256(Utf8.encode(key), Utf8.encode(value)) != signature : List<&2, U32>} & different(rest, value, signature)

# A usable secret is a nonempty string of Unicode scalar values.
def nonempty(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{h, t}: True{}

def all_nonempty(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: True{}
    case x <> t: nonempty(x) && all_nonempty(t)

def secret(+s: String) -> Bool:
  nonempty(s) && Utf8.valid(s)

def secrets(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: True{}
    case x <> t: secret(x) && secrets(t)

def keys_when(keys: S.Keys, ok: Bool) -> Maybe<&2, S.Keys>:
  match ok:
    case True{}: Some{keys}
    case False{}: None{}

# Configuration accepts exactly the nonempty lists of usable secrets.
def configure(xs: List<&2, String>) -> Maybe<&2, S.Keys>:
  match xs:
    case Nil{}: None{}
    case +first <> +rest: keys_when(S.Keys{first, rest}, secrets(first <> rest))

def nth(s: String, n: Nat) -> Char:
  match s n:
    case SNil{} _: '?'
    case SCon{h, t} 0n: h
    case SCon{h, t} 1n+p: nth(t, p)

def weight(b: Bool, w: Nat) -> Nat:
  match b:
    case False{}: 0n
    case True{}: w

# RFC 4648 section 4 over bits: read each octet most significant bit first,
# take six-bit groups, fill the last group with zero bits and pad with '='.
def sextet(a: Bool, b: Bool, c: Bool, d: Bool, e: Bool, f: Bool) -> Char:
  nth("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", Nat.add(weight(a, 32n), Nat.add(weight(b, 16n), Nat.add(weight(c, 8n), Nat.add(weight(d, 4n), Nat.add(weight(e, 2n), weight(f, 1n)))))))

# The eight bits of an octet, most significant first.
def octet_bits(x: U32) -> List<&2, Bool>:
  match x:
    case U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, hi}}}}}}}}}:
      [b7, b6, b5, b4, b3, b2, b1, b0]

def sextets(bits: List<&2, Bool>) -> String:
  match bits:
    case a <> b <> c <> d <> e <> f <> t: SCon{sextet(a, b, c, d, e, f), sextets(t)}
    case _: ""

def base64(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}: ""
    case a <> Nil{}:
      sextets(List.append(&2, Bool, octet_bits(a), [False{}, False{}, False{}, False{}])) ++ "=="
    case a <> b <> Nil{}:
      sextets(List.append(&2, Bool, octet_bits(a), List.append(&2, Bool, octet_bits(b), [False{}, False{}]))) ++ "="
    case a <> b <> c <> t:
      sextets(List.append(&2, Bool, octet_bits(a), List.append(&2, Bool, octet_bits(b), octet_bits(c)))) ++ base64(t)

# RFC 3986 section 2: unreserved octets stay literal; every other octet
# becomes '%' and two uppercase hexadecimal digits.
def unreserved(+c: U32) -> Bool:
  ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || ((c >= 48 : U32) && (c <= 57 : U32)) || U32.is_eq(c, 45) || U32.is_eq(c, 46) || U32.is_eq(c, 95) || U32.is_eq(c, 126)

def hex(a: Bool, b: Bool, c: Bool, d: Bool) -> Char:
  nth("0123456789ABCDEF", Nat.add(weight(a, 8n), Nat.add(weight(b, 4n), Nat.add(weight(c, 2n), weight(d, 1n)))))

def escape(x: U32) -> String:
  match x:
    case U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, hi}}}}}}}}}:
      SCon{'%', SCon{hex(b7, b6, b5, b4), SCon{hex(b3, b2, b1, b0), ""}}}

def percent_octet(+x: U32, keep: Bool) -> String:
  match keep:
    case True{}: SCon{Chr{x}, ""}
    case False{}: escape(x)

def percent(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}: ""
    case +x <> t: percent_octet(x, unreserved(x)) ++ percent(t)

# Hono's wire value: URL-encode value ++ "." ++ base64(HMAC-SHA256(key, value))
# over the UTF-8 bytes. HMAC is the shared RFC 2104 primitive.
def signed_wire(key: String, +value: String) -> String:
  percent(Utf8.encode(value ++ "." ++ base64(Hmac.sha256(Utf8.encode(key), Utf8.encode(value)))))

# No entry carries this exact, case-sensitive cookie name.
def unnamed(entries: List<&2, Cookie.Entry>, +name: String) -> Bool:
  match entries:
    case Nil{}: True{}
    case Cookie.Entry{k, v} <> t: Bool.not(String.eq(k, name)) && unnamed(t, name)

type Parts is Data:
  Parts{value: String, signature: String}

def with_head(c: Char, parts: Parts) -> Parts:
  match parts:
    case Parts{value, signature}: Parts{SCon{c, value}, signature}

def last_dot_at(+c: Char, +t: String, later: Maybe<&2, Parts>, dot: Bool) -> Maybe<&2, Parts>:
  match later dot:
    case Some{parts} _: Some{with_head(c, parts)}
    case None{} True{}: Some{Parts{"", t}}
    case None{} False{}: None{}

# The value and signature around the last '.', or None without a '.'.
def last_dot(s: String) -> Maybe<&2, Parts>:
  match s:
    case SNil{}: None{}
    case SCon{+c, +t}: last_dot_at(c, t, last_dot(t), Char.is_eq(c, '.'))
def accept(value: String, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}: Some{value}
    case False{}: None{}

# Keys whose slots configure would reject authenticate nothing.
def authenticated_by(keys: S.Keys, +value: String, +bytes: List<&2, U32>) -> Maybe<&2, String>:
  match keys:
    case S.Keys{+first, +rest}: accept(value, secrets(first <> rest) && authentic(first <> rest, value, bytes))

def authenticated(keys: S.Keys, +value: String, signature: Maybe<&2, List<&2, U32>>) -> Maybe<&2, String>:
  match signature:
    case None{}: None{}
    case Some{bytes}: authenticated_by(keys, value, bytes)

def split_parts(keys: S.Keys, parts: Parts) -> Maybe<&2, String>:
  match parts:
    case Parts{+value, signature}: authenticated(keys, value, Base64.decode(signature, False{}, True{}))

def verify_split(keys: S.Keys, parts: Maybe<&2, Parts>) -> Maybe<&2, String>:
  match parts:
    case None{}: None{}
    case Some{p}: split_parts(keys, p)

def verify_payload(keys: S.Keys, decoded: Result<&2, &2, Url.Error, String>) -> Maybe<&2, String>:
  match decoded:
    case Fail{e}: None{}
    case Done{payload}: verify_split(keys, last_dot(payload))

# Accept exactly when the keys are usable, the wire URL-decodes, the payload
# has a last '.', the suffix decodes as padded standard Base64, and the bytes
# equal some listed key's HMAC over the prefix. Every other wire is rejected.
#
# Only the last-dot split and the key and HMAC relation are written
# independently here. URL and Base64 decoding call the same Url.decode and
# Base64.decode as the implementation, so the wire law rules out composition,
# split and authentication bugs but not decoder bugs. BND-87's laws in
# signed-cookie-decoder-laws.bend specify both decoders independently and
# restate verification against them (docs/cookies.md).
def verify(keys: S.Keys, wire: String) -> Maybe<&2, String>:
  verify_payload(keys, Url.decode(wire))

# A request header's octets, one per character. Cookie headers are ASCII.
def octets(s: String) -> List<&2, U32>:
  match s:
    case SNil{}: []
    case SCon{Chr{c}, t}: c <> octets(t)

# No header in the list is named exactly "cookie" (names arrive lowercased).
def cookieless(headers: List<&2, Request.Header>) -> Bool:
  match headers:
    case Nil{}: True{}
    case Request.Header{n, v} <> t: Bool.not(String.eq(n, "cookie")) && cookieless(t)
