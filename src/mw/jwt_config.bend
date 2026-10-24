# JWT middleware configuration, kept apart from the clock-reading shell in
# jwt.bend so pure modules (builtin_core.bend and the laws) can name it.
import Base

type Config is Data:
  Config{secret: List<&2, U32>, leeway: Nat, realm: String}
