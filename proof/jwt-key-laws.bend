# BND-104: an empty HMAC key signs and verifies nothing. Every JWT entry
# point that takes a key (B.jwt, B.jwt_with, B.jwt_verify, B.jwt_sign and
# B.jwt_signed) goes through JwtConfig.verify_key or JwtConfig.sign_key, and
# the string secrets through JwtConfig.secret_key.
import Base
import ../src/crypto/jwt.bend as Jwt
import ../src/data/json.bend as Json
import ../src/mw/jwt_config.bend as JC

# No token verifies under an empty key, even in a config built directly
# with JwtConfig.Config{Some{[]}, ..}: every token fails with BadSignature.
law jwt_empty_key_verifies_nothing:
  for +token: String
  for +now: Nat
  for +leeway: Nat
  {JC.verify_key(Some{[]}, token, now, leeway) == Fail{Jwt.BadSignature{}} : Result<&2, &2, Jwt.Error, Json.Json>}

# Nothing is signed under an empty key: every claim set fails with BadEncoding.
law jwt_empty_key_signs_nothing:
  for +claims: Json.Json
  {JC.sign_key(Some{[]}, claims) == Fail{Jwt.BadEncoding{}} : Result<&2, &2, Jwt.Error, String>}

# The empty string secret has no key, like a secret with no UTF-8 form.
law jwt_empty_secret_has_no_key:
  {JC.secret_key("") == None{} : Maybe<&2, List<&2, U32>>}

# A key with at least one octet verifies exactly as Jwt.verify does, so the
# laws about Jwt.verify hold for every configured nonempty key.
law jwt_nonempty_key_verifies_as_jwt:
  for +h: U32
  for +t: List<&2, U32>
  for +token: String
  for +now: Nat
  for +leeway: Nat
  {JC.verify_key(Some{h <> t}, token, now, leeway) == Jwt.verify(h <> t, token, now, leeway) : Result<&2, &2, Jwt.Error, Json.Json>}

# A key with at least one octet signs exactly as Jwt.sign does.
law jwt_nonempty_key_signs_as_jwt:
  for +h: U32
  for +t: List<&2, U32>
  for +claims: Json.Json
  {JC.sign_key(Some{h <> t}, claims) == Jwt.sign(h <> t, claims) : Result<&2, &2, Jwt.Error, String>}
