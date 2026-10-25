# JWT middleware configuration, kept apart from the clock-reading shell in
# jwt.bend so pure modules (builtin_core.bend and the laws) can name it.
import Base
import ../crypto/jwt.bend as Jwt
import ../data/json.bend as Json
import ../data/utf8.bend as Utf8

# `secret` is None when the configured string holds a non-scalar character:
# UTF-8 encoding would replace it with U+FFFD, so the same secret with U+FFFD
# in its place would verify the same tokens. Such a config verifies nothing.
# An empty key verifies nothing either, even in a config built directly.
type Config is Data:
  Config{secret: Maybe<&2, List<&2, U32>>, leeway: Nat, realm: String}

# A key with no octets is no key: anyone can compute HMAC-SHA256 under it.
def usable(key: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match key:
    case None{}: None{}
    case Some{Nil{}}: None{}
    case Some{h <> t}: Some{h <> t}

# The key for a string secret, given whether it is valid UTF-8 (Utf8.valid).
def text_key(valid: Bool, secret: String) -> Maybe<&2, List<&2, U32>>:
  match valid:
    case True{}: usable(Some{Utf8.encode(secret)})
    case False{}: None{}

def secret_key(+secret: String) -> Maybe<&2, List<&2, U32>>:
  text_key(Utf8.valid(secret), secret)

def verify_usable(key: Maybe<&2, List<&2, U32>>, token: String, +now: Nat, +leeway: Nat) -> Result<&2, &2, Jwt.Error, Json.Json>:
  match key:
    case None{}: Fail{Jwt.BadSignature{}}
    case Some{k}: Jwt.verify(k, token, now, leeway)

# Verify under a configured key; a missing or empty key refuses every token.
def verify_key(key: Maybe<&2, List<&2, U32>>, token: String, +now: Nat, +leeway: Nat) -> Result<&2, &2, Jwt.Error, Json.Json>:
  verify_usable(usable(key), token, now, leeway)

def sign_usable(key: Maybe<&2, List<&2, U32>>, claims: Json.Json) -> Result<&2, &2, Jwt.Error, String>:
  match key:
    case None{}: Fail{Jwt.BadEncoding{}}
    case Some{k}: Jwt.sign(k, claims)

# Sign under a configured key; a missing or empty key signs nothing.
def sign_key(key: Maybe<&2, List<&2, U32>>, claims: Json.Json) -> Result<&2, &2, Jwt.Error, String>:
  sign_usable(usable(key), claims)
