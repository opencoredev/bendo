# BND-32: independent digest authentication, configuration and wire laws.
import Base
import ../src/data/signed-cookie.bend as S
import ../src/data/utf8.bend as Utf8
import ../src/data/urlencoded.bend as Url
import ../src/crypto/hmac.bend as Hmac
import ../src/crypto/compare.bend as Compare
import ./signed-cookie-spec.bend as Spec
import ../src/data/cookie.bend as Cookie
import ../src/app/context.bend as Context
import ./cookie-serialization-spec.bend as CookieSpec
import ./cookie-ows-spec.bend as CookieList

law signed_cookie_compare_structural:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  {Compare.ct_equal(xs, ys) == Spec.bytes_equal(xs, ys) : Bool}

law signed_cookie_digest_first:
  for +first: String
  for +rest: List<&2, String>
  for +value: String
  {S.verify_digest(S.Keys{first, rest}, value, Hmac.sha256(Utf8.encode(first), Utf8.encode(value))) == Some{value} : Maybe<&2, String>}

law signed_cookie_digest_member:
  for +first: String
  for +rest: List<&2, String>
  for +key: String
  for +value: String
  for member: Spec.contains(key, first <> rest)
  {S.verify_digest(S.Keys{first, rest}, value, Hmac.sha256(Utf8.encode(key), Utf8.encode(value))) == Some{value} : Maybe<&2, String>}

law signed_cookie_digest_reject:
  for +first: String
  for +rest: List<&2, String>
  for +value: String
  for +signature: List<&2, U32>
  for different: Spec.different(first <> rest, value, signature)
  {S.verify_digest(S.Keys{first, rest}, value, signature) == None{} : Maybe<&2, String>}

law signed_cookie_empty_configuration:
  {S.configure([]) == None{} : Maybe<&2, S.Keys>}

law signed_cookie_percent_roundtrip:
  for +value: String
  for valid: {Utf8.valid(value) == True{} : Bool}
  {Url.decode(Url.encode(value)) == Done{value} : Result<&2, &2, Url.Error, String>}

# Configuration accepts exactly the nonempty lists of nonempty scalar secrets.
law signed_cookie_configure_spec:
  for +xs: List<&2, String>
  {S.configure(xs) == Spec.configure(xs) : Maybe<&2, S.Keys>}

law signed_cookie_configure_nonempty:
  for +xs: List<&2, String>
  for +keys: S.Keys
  for configured: {S.configure(xs) == Some{keys} : Maybe<&2, S.Keys>}
  {Spec.all_nonempty(xs) == True{} : Bool}

# The public wire format: URL decoding, last-dot split and strict Base64
# decoding recover what the signer produced, for every scalar value.
law signed_cookie_wire_first:
  for +first: String
  for +rest: List<&2, String>
  for +value: String
  for valid: {Utf8.valid(value) == True{} : Bool}
  {S.verify(S.Keys{first, rest}, S.sign(first, value)) == Some{value} : Maybe<&2, String>}

law signed_cookie_wire_member:
  for +first: String
  for +rest: List<&2, String>
  for +key: String
  for +value: String
  for member: Spec.contains(key, first <> rest)
  for valid: {Utf8.valid(value) == True{} : Bool}
  {S.verify(S.Keys{first, rest}, S.sign(key, value)) == Some{value} : Maybe<&2, String>}

# The signer is exactly the independent RFC 4648 / RFC 3986 wire value.
law signed_cookie_sign_spec:
  for +key: String
  for +value: String
  {S.sign(key, value) == Spec.signed_wire(key, value) : String}

# serialize signs with the first key, then applies ordinary cookie rules.
law signed_cookie_serialize_first:
  for +name: String
  for +value: String
  for +first: String
  for +rest: List<&2, String>
  for +options: Cookie.Options
  for valid: {Utf8.valid(value) == True{} : Bool}
  {S.serialize(name, value, S.Keys{first, rest}, options) == Cookie.serialize(name, Spec.signed_wire(first, value), options) : Result<&2, &2, Cookie.Error, String>}

law signed_cookie_serialize_invalid:
  for +name: String
  for +value: String
  for +first: String
  for +rest: List<&2, String>
  for +options: Cookie.Options
  for invalid: {Utf8.valid(value) == False{} : Bool}
  {S.serialize(name, value, S.Keys{first, rest}, options) == Fail{Cookie.InvalidValue{}} : Result<&2, &2, Cookie.Error, String>}

# The public setter is the ordinary setter applied to the signed wire value.
law signed_cookie_setter_first:
  for -Vars: Data
  for +c: Context.Ctx<Vars>
  for +name: String
  for +value: String
  for +first: String
  for +rest: List<&2, String>
  for +options: Cookie.Options
  for valid: {Utf8.valid(value) == True{} : Bool}
  {Context.set_signed_cookie(Vars, c, name, value, S.Keys{first, rest}, options) == Context.set_cookie(Vars, c, name, Spec.signed_wire(first, value), options) : Result<&2, &2, Cookie.Error, Context.Ctx<Vars>>}

# For an admissible name and options, the emitted Set-Cookie field is the
# independent BND-31 serialization of name=signed_wire with those options.
law signed_cookie_set_cookie_field:
  for +name: String
  for +value: String
  for +first: String
  for +rest: List<&2, String>
  for +options: Cookie.Options
  for valid: {Utf8.valid(value) == True{} : Bool}
  for admissible: {CookieSpec.admissible(name, "", options) == True{} : Bool}
  {S.serialize(name, value, S.Keys{first, rest}, options) == Done{CookieSpec.wire(name, Spec.signed_wire(first, value), options)} : Result<&2, &2, Cookie.Error, String>}

# The public reader is BND-31's first-wins lookup followed by verification.
law signed_cookie_context_read:
  for -Vars: Data
  for +c: Context.Ctx<Vars>
  for +name: String
  for +keys: S.Keys
  {Context.signed_cookie(Vars, c, name, keys) == S.read(keys, Cookie.first(Context.cookies(Vars, c), name)) : Maybe<&2, String>}

# A Cookie header carrying the emitted pair, after differently named valid
# pairs and before any valid pairs (including later duplicates), verifies
# under every key list that contains the signing key.
law signed_cookie_request_roundtrip:
  for +name: String
  for +value: String
  for +first: String
  for +rest: List<&2, String>
  for +key: String
  for +before: List<&2, Cookie.Entry>
  for +after: List<&2, Cookie.Entry>
  for member: Spec.contains(key, first <> rest)
  for valid: {Utf8.valid(value) == True{} : Bool}
  for named: {CookieSpec.name_valid(name) == True{} : Bool}
  for earlier: {CookieList.entries_valid(before) == True{} : Bool}
  for later: {CookieList.entries_valid(after) == True{} : Bool}
  for distinct: {Spec.unnamed(before, name) == True{} : Bool}
  {S.read(S.Keys{first, rest}, Cookie.first(Cookie.parse(String.join(CookieList.pairs(List.append(&2, Cookie.Entry, before, Cookie.Entry{name, Spec.signed_wire(key, value)} <> after)), "; ")), name)) == Some{value} : Maybe<&2, String>}

# Every wire string, tampered or not: verify accepts exactly what the
# independent decoder accepts. Malformed percent escapes or UTF-8, a missing
# dot, non-canonical Base64, or bytes unequal to every listed key's HMAC over
# the decoded value all give None; a match under any listed key gives Some.
law signed_cookie_wire_spec:
  for +keys: S.Keys
  for +wire: String
  {S.verify(keys, wire) == Spec.verify(keys, wire) : Maybe<&2, String>}
