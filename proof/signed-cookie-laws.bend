# BND-32: independent digest authentication, not a wire-roundtrip claim.
import Base
import ../src/data/signed-cookie.bend as S
import ../src/data/utf8.bend as Utf8
import ../src/data/urlencoded.bend as Url
import ../src/crypto/hmac.bend as Hmac
import ../src/crypto/compare.bend as Compare
import ./signed-cookie-spec.bend as Spec

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
