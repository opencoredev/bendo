# Number grammar, lexical integers and exact decimal order agree with the
# independent specification (src/data/schema-spec.bend).
import Base
import ../src/data/json.bend as J
import ../src/data/decimal.bend as D
import ../src/data/schema-spec.bend as Spec

def number_equiv(+s: String) -> {J.number_valid(s) == Spec.number(s) : Bool}:
  ?TODO

def integer_equiv(+s: String) -> {D.is_integer(s) == Spec.integer(s) : Bool}:
  ?TODO

def order_equiv(+a: String, +b: String, va: {J.number_valid(a) == True{} : Bool}, vb: {J.number_valid(b) == True{} : Bool}) -> {D.order(a, b) == Spec.order(a, b) : Cmp}:
  ?TODO

# Every lexical integer is a valid number token.
def integer_number(+s: String, e: {D.is_integer(s) == True{} : Bool}) -> {J.number_valid(s) == True{} : Bool}:
  ?TODO
