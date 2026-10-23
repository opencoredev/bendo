import Base
import ../../../src/data/signed-cookie.bend as S
import ../../../src/data/cookie.bend as C

def configure(keys: List<&2, String>) -> Maybe<&2, S.Keys>:
  S.configure(keys)

def sign(key: String, value: String) -> String:
  S.sign(key, value)

def verify(keys: S.Keys, wire: String) -> Maybe<&2, String>:
  S.verify(keys, wire)

def serialize(name: String, value: String, keys: S.Keys) -> Result<&2, &2, C.Error, String>:
  S.serialize(name, value, keys, C.defaults())

# Construct an invalid scalar inside Bend; .mjs string arguments are normalized
# by the compiler's JavaScript interop before the public API sees them.
def invalid_value(keys: S.Keys) -> Result<&2, &2, C.Error, String>:
  S.serialize("session", SCon{Chr{55296}, ""}, keys, C.defaults())
