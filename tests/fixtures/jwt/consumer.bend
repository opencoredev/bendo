# Text-only wrappers over the pure JWT core for the jose interop tests.
import Base
import ../../../src/crypto/jwt.bend as Jwt
import ../../../src/data/hex.bend as Hex
import ../../../src/data/json.bend as Json
import ../../../src/data/utf8.bend as Utf8

def written(result: Result<&2, &2, Json.Error, String>) -> String:
  match result:
    case Fail{e}: "err:unwritable"
    case Done{s}: "ok:" ++ s

def verified(result: Result<&2, &2, Jwt.Error, Json.Json>) -> String:
  match result:
    case Fail{e}: "err:" ++ Jwt.error_text(e)
    case Done{claims}: written(Json.stringify(claims))

def signed(result: Result<&2, &2, Jwt.Error, String>) -> String:
  match result:
    case Fail{e}: "err:" ++ Jwt.error_text(e)
    case Done{token}: "ok:" ++ token

def parsed(+secret: List<&2, U32>, result: Result<&2, &2, Json.Error, Json.Json>) -> String:
  match result:
    case Fail{e}: "err:json"
    case Done{claims}: signed(Jwt.sign(secret, claims))

def key(secret_hex: String) -> List<&2, U32>:
  Maybe.default(&2, List<&2, U32>, Hex.decode(secret_hex), [])

# claims is JSON text; the result is "ok:<token>" or "err:<reason>".
def sign(secret_hex: String, claims: String) -> String:
  parsed(key(secret_hex), Json.parse(Utf8.encode(claims)))

# now and leeway are Unix seconds; the result is "ok:<claims JSON>" or "err:<reason>".
def verify(secret_hex: String, token: String, now: Nat, leeway: Nat) -> String:
  verified(Jwt.verify(key(secret_hex), token, now, leeway))
