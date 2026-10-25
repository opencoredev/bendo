# JWT middleware configuration, kept apart from the clock-reading shell in
# jwt.bend so pure modules (builtin_core.bend and the laws) can name it.
import Base

# `secret` is None when the configured string holds a non-scalar character:
# UTF-8 encoding would replace it with U+FFFD, so the same secret with U+FFFD
# in its place would verify the same tokens. Such a config verifies nothing.
type Config is Data:
  Config{secret: Maybe<&2, List<&2, U32>>, leeway: Nat, realm: String}
