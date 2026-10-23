# The derivative matcher agrees with the split-based regular-language
# specification (src/data/schema-spec.bend).
import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec

def valid_equiv(+p: P.Pattern) -> {P.valid(p) == Spec.pattern_ok(p) : Bool}:
  ?TODO

def matches_equiv(+p: P.Pattern, +s: String) -> {P.matches(p, s) == Spec.matches(p, s) : Bool}:
  ?TODO
