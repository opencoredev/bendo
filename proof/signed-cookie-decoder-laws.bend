# BND-87: the decoders inside signed-cookie verification, specified
# independently. signed_cookie_wire_spec states verification through
# Url.decode and Base64.decode; these laws pin both decoders down and
# restate verification against the independent decoders alone.
import Base
import ../src/data/signed-cookie.bend as S
import ../src/data/base64.bend as Base64
import ../src/data/urlencoded.bend as Url
import ../src/data/utf8.bend as Utf8
import ../src/crypto/octets.bend as Octets
import ../src/crypto/hmac.bend as Hmac
import ./signed-cookie-spec.bend as Spec
import ./url-decode-spec.bend as DSpec

# Strict padded standard Base64 accepts only the canonical RFC 4648
# encoding of the bytes it returns, and every returned byte is an octet.
law signed_cookie_base64_canonical:
  for +s: String
  for +bytes: List<&2, U32>
  for decoded: {Base64.decode(s, False{}, True{}) == Some{bytes} : Maybe<&2, List<&2, U32>>}
  {s == Spec.base64(bytes) : String} & {Octets.valid(bytes) == True{} : Bool}

# Url.decode's percent stage is the independent RFC 3986 decoder: "%HH"
# in either hex case is one octet, a bad "%" fails, "+" stays literal.
law signed_cookie_percent_spec:
  for +xs: List<&2, U32>
  {Url.percent_decode(xs, False{}) == DSpec.unpercent(xs) : Result<&2, &2, Url.Error, List<&2, U32>>}

# Strict UTF-8 decoding returns only Unicode scalar strings, and the string
# it returns encodes back to exactly the input octets.
law signed_cookie_utf8_sound:
  for +xs: List<&2, U32>
  for +s: String
  for decoded: {Utf8.decode(xs) == Some{s} : Maybe<&2, String>}
  {Utf8.valid(s) == True{} : Bool} & {Utf8.encode(s) == xs : List<&2, U32>}

# The next four laws determine Url.decode completely. A decoded value is a
# scalar string whose UTF-8 octets are the independent percent decoding of
# the wire's octets.
law signed_cookie_url_decode_sound:
  for +wire: String
  for +value: String
  for decoded: {Url.decode(wire) == Done{value} : Result<&2, &2, Url.Error, String>}
  {Utf8.valid(value) == True{} : Bool} & {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(value)} : Result<&2, &2, Url.Error, List<&2, U32>>}

# Every scalar string whose UTF-8 octets are the percent decoding is
# returned.
law signed_cookie_url_decode_complete:
  for +wire: String
  for +value: String
  for valid: {Utf8.valid(value) == True{} : Bool}
  for escaped: {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(value)} : Result<&2, &2, Url.Error, List<&2, U32>>}
  {Url.decode(wire) == Done{value} : Result<&2, &2, Url.Error, String>}

# A wire the independent percent decoder rejects fails with its error.
law signed_cookie_url_decode_percent_error:
  for +wire: String
  for +error: Url.Error
  for rejected: {DSpec.unpercent(Utf8.encode(wire)) == Fail{error} : Result<&2, &2, Url.Error, List<&2, U32>>}
  {Url.decode(wire) == Fail{error} : Result<&2, &2, Url.Error, String>}

# A failure after a successful percent stage is always InvalidUtf8.
law signed_cookie_url_decode_utf8_error:
  for +wire: String
  for +octets: List<&2, U32>
  for +error: Url.Error
  for escaped: {DSpec.unpercent(Utf8.encode(wire)) == Done{octets} : Result<&2, &2, Url.Error, List<&2, U32>>}
  for failed: {Url.decode(wire) == Fail{error} : Result<&2, &2, Url.Error, String>}
  {error == Url.InvalidUtf8{} : Url.Error}

# Verification, restated against the independent decoders alone. A wire
# verifies to value only if the keys are usable, value is a scalar string,
# and some listed key signed it: the wire percent decodes to the UTF-8
# octets of value, ".", and the canonical Base64 of that key's HMAC.
law signed_cookie_verify_sound:
  for +first: String
  for +rest: List<&2, String>
  for +wire: String
  for +value: String
  for verified: {S.verify(S.Keys{first, rest}, wire) == Some{value} : Maybe<&2, String>}
  exs key: String
  Spec.contains(key, first <> rest) & ({Spec.secrets(first <> rest) == True{} : Bool} & ({Utf8.valid(value) == True{} : Bool} & {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(value ++ "." ++ Spec.base64(Hmac.sha256(Utf8.encode(key), Utf8.encode(value))))} : Result<&2, &2, Url.Error, List<&2, U32>>}))

# Conversely, every such wire verifies, however its octets are escaped.
law signed_cookie_verify_complete:
  for +first: String
  for +rest: List<&2, String>
  for +key: String
  for +wire: String
  for +value: String
  for member: Spec.contains(key, first <> rest)
  for usable: {Spec.secrets(first <> rest) == True{} : Bool}
  for valid: {Utf8.valid(value) == True{} : Bool}
  for escaped: {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(value ++ "." ++ Spec.base64(Hmac.sha256(Utf8.encode(key), Utf8.encode(value))))} : Result<&2, &2, Url.Error, List<&2, U32>>}
  {S.verify(S.Keys{first, rest}, wire) == Some{value} : Maybe<&2, String>}
