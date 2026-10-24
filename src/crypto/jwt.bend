# Pure HS256 JSON Web Tokens (RFC 7515 compact serialization, RFC 7519).
# The signature layer (seal/open) is proven in LAWS.bend; the claim layer
# (sign/verify) parses JSON and checks exp, nbf and iat against a supplied time.
import Base
import ../data/base64.bend as Base64
import ../data/utf8.bend as Utf8
import ../data/json.bend as Json
import ./hmac.bend as HMAC
import ./compare.bend as Compare
import ../http/text.bend as Text

type Error is Data:
  Malformed{}
  BadSignature{}
  BadEncoding{}
  BadHeader{}
  BadAlgorithm{}
  BadClaims{}
  BadClaim{name: String}
  DuplicateMember{}
  TooManyMembers{}
  Expired{}
  NotYetValid{}
  IssuedInFuture{}
  Unwritable{}

# The text on either side of the first '.'.
type Cut is Data:
  Cut{left: String, right: String}

# Decoded header and payload octets.
type Parts is Data:
  Parts{header: List<&2, U32>, payload: List<&2, U32>}

def encode(xs: List<&2, U32>) -> String:
  Base64.encode(xs, True{}, False{})

def decode(s: String) -> Maybe<&2, List<&2, U32>>:
  Base64.decode(s, True{}, False{})

# True when no character is '.', the compact-serialization separator.
def dotfree_spec(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{+c, t}:
      Bool.not(Char.is_eq(c, '.')) && dotfree_spec(t)

# Tail calls throughout (BND-84): tokens may be as long as a header.
def dotfree_go(s: String, acc: Bool) -> Bool:
  match s:
    case SNil{}:
      acc
    case SCon{+c, t}:
      dotfree_go(t, acc && Bool.not(Char.is_eq(c, '.')))

def dotfree(s: String) -> Bool:
  dotfree_go(s, True{})

def prepend(c: Char, r: Maybe<&2, Cut>) -> Maybe<&2, Cut>:
  match r:
    case None{}:
      None{}
    case Some{Cut{a, b}}:
      Some{Cut{SCon{c, a}, b}}

def split_pick(c: Char, t: String, rest: Maybe<&2, Cut>, dot: Bool) -> Maybe<&2, Cut>:
  match dot:
    case True{}:
      Some{Cut{"", t}}
    case False{}:
      prepend(c, rest)

def split_spec(s: String) -> Maybe<&2, Cut>:
  match s:
    case SNil{}:
      None{}
    case SCon{+c, +t}:
      split_pick(c, t, split_spec(t), Char.is_eq(c, '.'))

def from_text(r: Maybe<&2, Text.Cut>) -> Maybe<&2, Cut>:
  match r:
    case None{}:
      None{}
    case Some{Text.Cut{a, b}}:
      Some{Cut{a, b}}

# Split at the first '.'; None when there is none.
def split(s: String) -> Maybe<&2, Cut>:
  from_text(Text.cut(s, '.'))

def codes_spec(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      []
    case SCon{Chr{c}, t}:
      c <> codes_spec(t)

def codes_go(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, t}:
      codes_go(t, c <> acc)

def codes(s: String) -> List<&2, U32>:
  codes_go(String.reverse(s), [])

def signing_input(a: String, b: String) -> String:
  a ++ ("." ++ b)

def token(a: String, b: String, c: String) -> String:
  a ++ ("." ++ (b ++ ("." ++ c)))

# The signature segment for a signing input: unpadded base64url HMAC-SHA256.
def signature(+secret: List<&2, U32>, input: String) -> String:
  encode(HMAC.sha256(secret, Utf8.encode(input)))

# Sign raw header and payload octets.
def seal(+secret: List<&2, U32>, header: List<&2, U32>, payload: List<&2, U32>) -> String:
  +a = encode(header)
  +b = encode(payload)
  token(a, b, signature(secret, signing_input(a, b)))

def decoded(h: Maybe<&2, List<&2, U32>>, p: Maybe<&2, List<&2, U32>>) -> Result<&2, &2, Error, Parts>:
  match h p:
    case Some{h} Some{p}:
      Done{Parts{h, p}}
    case _ _:
      Fail{BadEncoding{}}

def signed(a: String, b: String, ok: Bool) -> Result<&2, &2, Error, Parts>:
  match ok:
    case True{}:
      decoded(decode(a), decode(b))
    case False{}:
      Fail{BadSignature{}}

# The signature is compared as text. Base64 decoding is canonical (it rejects
# nonzero unused bits), so equal text is equivalent to equal tag octets, and a
# malformed signature segment simply fails the comparison.
def third(+secret: List<&2, U32>, +a: String, +b: String, c: String, single: Bool) -> Result<&2, &2, Error, Parts>:
  match single:
    case True{}:
      signed(a, b, Compare.ct_equal(codes(c), codes(signature(secret, signing_input(a, b)))))
    case False{}:
      Fail{Malformed{}}

def second(+secret: List<&2, U32>, a: String, parts: Maybe<&2, Cut>) -> Result<&2, &2, Error, Parts>:
  match parts:
    case None{}:
      Fail{Malformed{}}
    case Some{Cut{b, +c}}:
      third(secret, a, b, c, dotfree(c))

def first(+secret: List<&2, U32>, parts: Maybe<&2, Cut>) -> Result<&2, &2, Error, Parts>:
  match parts:
    case None{}:
      Fail{Malformed{}}
    case Some{Cut{a, rest}}:
      second(secret, a, split(rest))

# Check structure and signature, then return the decoded header and payload.
def open(+secret: List<&2, U32>, token: String) -> Result<&2, &2, Error, Parts>:
  first(secret, split(token))

# ---- Claim layer ----

def header() -> List<&2, U32>:
  Utf8.encode("{\"alg\":\"HS256\",\"typ\":\"JWT\"}")

def written(+secret: List<&2, U32>, result: Result<&2, &2, Json.Error, String>) -> Result<&2, &2, Error, String>:
  match result:
    case Fail{e}:
      Fail{Unwritable{}}
    case Done{text}:
      Done{seal(secret, header(), Utf8.encode(text))}

def key_in(+key: String, fields: List<&2, Json.Field>) -> Bool:
  match fields:
    case Nil{}:
      False{}
    case Json.Field{k, v} <> t:
      String.eq(k, key) || key_in(key, t)

# True when no two top-level members share a name. RFC 7515 and 7519 let a
# parser reject duplicate names, and taking either copy would let the header
# or the claims mean different things to different verifiers.
def unique(fields: List<&2, Json.Field>) -> Bool:
  match fields:
    case Nil{}:
      True{}
    case Json.Field{+k, v} <> +t:
      Bool.not(key_in(k, t)) && unique(t)

# True when fields has at most n members. Linear, so it runs before unique.
def at_most(fields: List<&2, Json.Field>, n: Nat) -> Bool:
  match fields:
    case Nil{}:
      True{}
    case f <> t:
      match n:
        case 0n:
          False{}
        case 1n+p:
          at_most(t, p)

def repeated(distinct: Bool) -> Maybe<&2, Error>:
  match distinct:
    case True{}:
      None{}
    case False{}:
      Some{DuplicateMember{}}

def bounded(+fields: List<&2, Json.Field>, small: Bool) -> Maybe<&2, Error>:
  match small:
    case True{}:
      repeated(unique(fields))
    case False{}:
      Some{TooManyMembers{}}

# The member-name check for a header or claim set. unique compares every pair
# of names, so an object with more than 256 top-level members fails with
# TooManyMembers before that. On the verify path both run only after the
# signature has been checked.
def members(+fields: List<&2, Json.Field>) -> Maybe<&2, Error>:
  bounded(fields, at_most(fields, 256n))

def sign_object(+secret: List<&2, U32>, claims: Json.Json, failure: Maybe<&2, Error>) -> Result<&2, &2, Error, String>:
  match failure:
    case None{}:
      written(secret, Json.stringify(claims))
    case Some{e}:
      Fail{e}

# Sign a JSON object claim set with the fixed header {"alg":"HS256","typ":"JWT"}.
# A claim set with a repeated member name, or more than 256 members, fails,
# since verify would reject it.
def sign(+secret: List<&2, U32>, claims: Json.Json) -> Result<&2, &2, Error, String>:
  match claims:
    case Json.JObject{+fields}:
      sign_object(secret, Json.JObject{fields}, members(fields))
    case _:
      Fail{BadClaims{}}

# A NumericDate split exactly into sign, integer digits (no leading zeros;
# "" is zero) and whether any fractional digit is nonzero.
type Numeric is Data:
  Numeric{negative: Bool, whole: String, fraction: Bool}

def strip_zeros(s: String) -> String:
  match s:
    case SCon{'0', t}:
      strip_zeros(t)
    case _:
      s

def nonzero_spec(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{+c, t}:
      Bool.not(Char.is_eq(c, '0')) || nonzero_spec(t)

def nonzero_go(xs: String, acc: Bool) -> Bool:
  match xs:
    case SNil{}: acc
    case SCon{+c, t}: nonzero_go(t, Bool.not(Char.is_eq(c, '0')) || acc)

def nonzero(xs: String) -> Bool:
  nonzero_go(String.reverse(xs), False{})

type Lexeme is Data:
  Lexeme{negative: Bool, whole: String, fraction: String, exp_negative: Bool, exp: String}

# Split a JSON number lexeme already validated by the JSON parser.
def lex_exp(s: String, negative: Bool, whole: String, fraction: String) -> Lexeme:
  match s:
    case SCon{'-', t}:
      Lexeme{negative, whole, fraction, True{}, t}
    case SCon{'+', t}:
      Lexeme{negative, whole, fraction, False{}, t}
    case _:
      Lexeme{negative, whole, fraction, False{}, s}

def lex_fraction(s: String, rev: String, negative: Bool, whole: String) -> Lexeme:
  match s:
    case SNil{}:
      Lexeme{negative, whole, String.reverse(rev), False{}, ""}
    case SCon{'e', t}:
      lex_exp(t, negative, whole, String.reverse(rev))
    case SCon{'E', t}:
      lex_exp(t, negative, whole, String.reverse(rev))
    case SCon{c, t}:
      lex_fraction(t, SCon{c, rev}, negative, whole)

def lex_whole(s: String, rev: String, negative: Bool) -> Lexeme:
  match s:
    case SNil{}:
      Lexeme{negative, String.reverse(rev), "", False{}, ""}
    case SCon{'.', t}:
      lex_fraction(t, "", negative, String.reverse(rev))
    case SCon{'e', t}:
      lex_exp(t, negative, String.reverse(rev), "")
    case SCon{'E', t}:
      lex_exp(t, negative, String.reverse(rev), "")
    case SCon{c, t}:
      lex_whole(t, SCon{c, rev}, negative)

def lex(s: String) -> Lexeme:
  match s:
    case SCon{'-', t}:
      lex_whole(t, "", True{})
    case _:
      lex_whole(s, "", False{})

def zeros_spec(n: Nat) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      SCon{'0', zeros_spec(p)}

def zeros_go(n: Nat, acc: String) -> String:
  match n:
    case 0n: acc
    case 1n+p: zeros_go(p, SCon{'0', acc})

def zeros(n: Nat) -> String:
  zeros_go(n, "")

# Exponents beyond four significant digits are clamped to 9999. The result
# is then far outside any clock value, which is what the checks need.
def exponent(digits: String, long: Bool) -> Nat:
  match long:
    case True{}:
      9999n
    case False{}:
      Maybe.default(&2, Nat, Nat.read(digits), 0n)

def short_exp(+digits: String) -> Nat:
  exponent(digits, Nat.is_gt(String.length(digits), 4n))

# Move the decimal point left by e digits.
def shift_left(+whole: String, +fraction: String, +e: Nat, inside: Bool) -> String & Bool:
  match inside:
    case True{}:
      +keep = Nat.sub(String.length(whole), e)
      (Text.take(whole, keep), nonzero(String.drop(whole, keep)) || nonzero(fraction))
    case False{}:
      ("", nonzero(whole) || nonzero(fraction))

def shifted(+whole: String, +fraction: String, +e: Nat, left: Bool) -> String & Bool:
  match left:
    case True{}:
      shift_left(whole, fraction, e, Nat.is_le(e, String.length(whole)))
    case False{}:
      (whole ++ Text.take(fraction ++ zeros(e), e), nonzero(String.drop(fraction, e)))

def numeric_parts(negative: Bool, parts: String & Bool) -> Numeric:
  (w, f) = parts
  Numeric{negative, strip_zeros(w), f}

def numeric_of(l: Lexeme) -> Numeric:
  Lexeme{negative, whole, fraction, en, e} = l
  numeric_parts(negative, shifted(whole, fraction, short_exp(strip_zeros(e)), en))

def numeric(s: String) -> Numeric:
  numeric_of(lex(s))

def then(c: Cmp, d: Cmp) -> Cmp:
  match c:
    case EQ{}: d
    case _: c

# Compare digit strings without leading zeros as natural numbers.
def digits_cmp_go(a: String, b: String, c: Cmp) -> Cmp:
  match a b:
    case SCon{Chr{x}, at} SCon{Chr{y}, bt}:
      digits_cmp_go(at, bt, then(c, U32.cmp(x, y)))
    case _ _:
      c

def digits_cmp(+a: String, +b: String) -> Cmp:
  then(Nat.cmp(String.length(a), String.length(b)), digits_cmp_go(a, b, EQ{}))

def nat_digits(n: Nat) -> String:
  strip_zeros(Nat.show(n))

# exp: valid while now < exp + leeway. A negative exp has always expired.
def exp_ok(n: Numeric, +now: Nat, +leeway: Nat) -> Bool:
  match n:
    case Numeric{True{}, whole, fraction}:
      False{}
    case Numeric{False{}, +whole, True{}}:
      Nat.is_lt(now, leeway) || Cmp.is_le(digits_cmp(nat_digits(Nat.sub(now, leeway)), whole))
    case Numeric{False{}, +whole, False{}}:
      Nat.is_lt(now, leeway) || Cmp.is_lt(digits_cmp(nat_digits(Nat.sub(now, leeway)), whole))

# nbf and iat: valid while value <= limit (now + leeway).
def not_after(n: Numeric, +limit: Nat) -> Bool:
  match n:
    case Numeric{True{}, whole, fraction}:
      True{}
    case Numeric{False{}, +whole, True{}}:
      Cmp.is_lt(digits_cmp(whole, nat_digits(limit)))
    case Numeric{False{}, +whole, False{}}:
      Cmp.is_le(digits_cmp(whole, nat_digits(limit)))

type Check is Data:
  Exp{}
  Nbf{}
  Iat{}

def check_name(c: Check) -> String:
  match c:
    case Exp{}: "exp"
    case Nbf{}: "nbf"
    case Iat{}: "iat"

def check_error(c: Check) -> Error:
  match c:
    case Exp{}: Expired{}
    case Nbf{}: NotYetValid{}
    case Iat{}: IssuedInFuture{}

def check_value(c: Check, +n: Numeric, +now: Nat, +leeway: Nat) -> Bool:
  match c:
    case Exp{}: exp_ok(n, now, leeway)
    case Nbf{}: not_after(n, Nat.add(now, leeway))
    case Iat{}: not_after(n, Nat.add(now, leeway))

def verdict(+c: Check, ok: Bool) -> Maybe<&2, Error>:
  match ok:
    case True{}: None{}
    case False{}: Some{check_error(c)}

def claim(+c: Check, value: Maybe<&2, Json.Json>, +now: Nat, +leeway: Nat) -> Maybe<&2, Error>:
  match value:
    case None{}:
      None{}
    case Some{Json.JNumber{s}}:
      verdict(c, check_value(c, numeric(s), now, leeway))
    case Some{_}:
      Some{BadClaim{check_name(c)}}

def first_error(a: Maybe<&2, Error>, b: Maybe<&2, Error>) -> Maybe<&2, Error>:
  match a:
    case None{}: b
    case Some{e}: Some{e}

def times(+fields: List<&2, Json.Field>, +now: Nat, +leeway: Nat) -> Maybe<&2, Error>:
  first_error(claim(Exp{}, Json.lookup(fields, "exp"), now, leeway), first_error(claim(Nbf{}, Json.lookup(fields, "nbf"), now, leeway), claim(Iat{}, Json.lookup(fields, "iat"), now, leeway)))

def accepted(claims: Json.Json, failure: Maybe<&2, Error>) -> Result<&2, &2, Error, Json.Json>:
  match failure:
    case None{}: Done{claims}
    case Some{e}: Fail{e}

def claim_fields(+fields: List<&2, Json.Field>, +now: Nat, +leeway: Nat, failure: Maybe<&2, Error>) -> Result<&2, &2, Error, Json.Json>:
  match failure:
    case None{}:
      accepted(Json.JObject{fields}, times(fields, now, leeway))
    case Some{e}:
      Fail{e}

def payload_claims(result: Result<&2, &2, Json.Error, Json.Json>, +now: Nat, +leeway: Nat) -> Result<&2, &2, Error, Json.Json>:
  match result:
    case Done{Json.JObject{+fields}}:
      claim_fields(fields, now, leeway, members(fields))
    case _:
      Fail{BadClaims{}}

def alg_ok(alg: Maybe<&2, Json.Json>) -> Bool:
  match alg:
    case Some{Json.JString{s}}: String.eq(s, "HS256")
    case _: False{}

def absent(v: Maybe<&2, Json.Json>) -> Bool:
  match v:
    case None{}: True{}
    case Some{x}: False{}

def header_members(payload: List<&2, U32>, +now: Nat, +leeway: Nat, failure: Maybe<&2, Error>) -> Result<&2, &2, Error, Json.Json>:
  match failure:
    case None{}:
      payload_claims(Json.parse(payload), now, leeway)
    case Some{e}:
      Fail{e}

# Only HS256 is accepted; "none", RS256 and every other alg fail. A crit
# header names extensions this verifier does not implement, so it fails too.
# These read the first member of each name. The header is accepted only if no
# name repeats, so a later copy cannot change the outcome; it only changes
# which error is reported.
def header_checked(+fields: List<&2, Json.Field>, payload: List<&2, U32>, +now: Nat, +leeway: Nat, alg: Bool, crit: Bool) -> Result<&2, &2, Error, Json.Json>:
  match alg crit:
    case True{} True{}:
      header_members(payload, now, leeway, members(fields))
    case False{} _:
      Fail{BadAlgorithm{}}
    case True{} False{}:
      Fail{BadHeader{}}

def header_fields(+fields: List<&2, Json.Field>, payload: List<&2, U32>, +now: Nat, +leeway: Nat) -> Result<&2, &2, Error, Json.Json>:
  header_checked(fields, payload, now, leeway, alg_ok(Json.lookup(fields, "alg")), absent(Json.lookup(fields, "crit")))

def header_parsed(result: Result<&2, &2, Json.Error, Json.Json>, payload: List<&2, U32>, +now: Nat, +leeway: Nat) -> Result<&2, &2, Error, Json.Json>:
  match result:
    case Done{Json.JObject{+fields}}:
      header_fields(fields, payload, now, leeway)
    case _:
      Fail{BadHeader{}}

def opened(result: Result<&2, &2, Error, Parts>, +now: Nat, +leeway: Nat) -> Result<&2, &2, Error, Json.Json>:
  match result:
    case Fail{e}:
      Fail{e}
    case Done{Parts{h, p}}:
      header_parsed(Json.parse(h), p, now, leeway)

# Verify an HS256 token at Unix time `now` (seconds), allowing `leeway`
# seconds of clock skew for exp, nbf and iat. Returns the claim set.
def verify(+secret: List<&2, U32>, token: String, +now: Nat, +leeway: Nat) -> Result<&2, &2, Error, Json.Json>:
  opened(open(secret, token), now, leeway)

def error_text(e: Error) -> String:
  match e:
    case Malformed{}: "malformed token"
    case BadSignature{}: "invalid signature"
    case BadEncoding{}: "invalid encoding"
    case BadHeader{}: "invalid header"
    case BadAlgorithm{}: "unsupported algorithm"
    case BadClaims{}: "invalid claims"
    case BadClaim{name}: "invalid " ++ name ++ " claim"
    case DuplicateMember{}: "duplicate member name"
    case TooManyMembers{}: "too many members"
    case Expired{}: "token expired"
    case NotYetValid{}: "token not yet valid"
    case IssuedInFuture{}: "token issued in the future"
    case Unwritable{}: "claims cannot be written"
