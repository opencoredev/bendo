import Base
import ../../../src/data/signed-cookie.bend as S
import ../../../src/data/cookie.bend as C

def configure(keys: List<&2, String>) -> Maybe<&2, S.Keys>:
  S.configure(keys)

def unchecked_sign(key: String, value: String) -> String:
  S.unchecked_sign(key, value)

def sign(keys: S.Keys, value: String) -> Maybe<&2, String>:
  S.sign(keys, value)

def verify(keys: S.Keys, wire: String) -> Maybe<&2, String>:
  S.verify(keys, wire)

def read(keys: S.Keys, wire: Maybe<&2, String>) -> Maybe<&2, String>:
  S.read(keys, wire)

def verify_digest(keys: S.Keys, value: String, signature: List<&2, U32>) -> Maybe<&2, String>:
  S.verify_digest(keys, value, signature)

def serialize(name: String, value: String, keys: S.Keys) -> Result<&2, &2, C.Error, String>:
  S.serialize(name, value, keys, C.defaults())

# Construct an invalid scalar inside Bend; .mjs string arguments are normalized
# by the compiler's JavaScript interop before the public API sees them.
def invalid_value(keys: S.Keys) -> Result<&2, &2, C.Error, String>:
  S.serialize("session", SCon{Chr{55296}, ""}, keys, C.defaults())

def invalid_sign(keys: S.Keys) -> Maybe<&2, String>:
  S.sign(keys, SCon{Chr{55296}, ""})

# Keys built directly with a lone surrogate in the first or a later slot.
def surrogate_keys(first: Bool) -> S.Keys:
  match first:
    case True{}: S.Keys{SCon{Chr{55296}, ""}, ["strong-current-secret"]}
    case False{}: S.Keys{"strong-current-secret", [SCon{Chr{57343}, ""}, "previous"]}
