# BND-104: proofs of the empty-key laws. Each follows by computation.
import Base
import ../src/mw/jwt_config.bend as JC
import ./jwt-key-laws.bend as Laws

def Laws.jwt_empty_key_verifies_nothing(token, now, leeway): {==}
def Laws.jwt_empty_key_signs_nothing(claims): {==}
def Laws.jwt_empty_secret_has_no_key(): {==}
def Laws.jwt_nonempty_key_verifies_as_jwt(h, t, token, now, leeway): {==}
def Laws.jwt_nonempty_key_signs_as_jwt(h, t, claims): {==}
