# Number grammar, lexical integers and exact decimal order agree with the
# independent specification (src/data/schema-spec.bend).
import Base
import ../src/data/json.bend as J
import ../src/data/decimal.bend as D
import ../src/data/schema-spec.bend as Spec
import ./schema-number-arith.bend as Arith
import ./schema-number-grammar.bend as Grammar
import ./schema-number-integer.bend as Integer

def number_equiv(+s: String) -> {J.number_valid(s) == Spec.number(s) : Bool}:
  Grammar.number_equiv(s)

def integer_equiv(+s: String) -> {D.is_integer(s) == Spec.integer(s) : Bool}:
  Integer.integer_equiv(s)

# Remaining bridge: signed decimal-string arithmetic and normalization must
# agree with Spec.magnitude_cmp. Arith supplies positional values and common
# power-of-ten cancellation without changing the runtime representation.
def order_equiv(+a: String, +b: String, va: {J.number_valid(a) == True{} : Bool}, vb: {J.number_valid(b) == True{} : Bool}) -> {D.order(a, b) == Spec.order(a, b) : Cmp}:
  ?TODO

# Every lexical integer is a valid number token.
def integer_number(+s: String, e: {D.is_integer(s) == True{} : Bool}) -> {J.number_valid(s) == True{} : Bool}:
  Integer.integer_number(s, e)
