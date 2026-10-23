# Number grammar, lexical integers and exact decimal order agree with the
# independent specification (src/data/schema-spec.bend).
import Base
import ../src/data/json.bend as J
import ../src/data/decimal.bend as D
import ../src/data/schema-spec.bend as Spec
import ./schema-number-arith.bend as Arith
import ./schema-number-grammar.bend as Grammar
import ./schema-number-integer.bend as Integer
import ./schema-number-order.bend as Order

def number_equiv(+s: String) -> {J.number_valid(s) == Spec.number(s) : Bool}:
  Grammar.number_equiv(s)

def integer_equiv(+s: String) -> {D.is_integer(s) == Spec.integer(s) : Bool}:
  Integer.integer_equiv(s)

# Unsigned digit ranks decide magnitudes; equal ranks compare padded coefficients.
def order_equiv(+a: String, +b: String, va: {J.number_valid(a) == True{} : Bool}, vb: {J.number_valid(b) == True{} : Bool}) -> {D.order(a, b) == Spec.order(a, b) : Cmp}:
  Order.order(a, b,
    Equal.trans(Bool, Spec.number(a), J.number_valid(a), True{}, Equal.sym(Bool, J.number_valid(a), Spec.number(a), Grammar.number_equiv(a)), va),
    Equal.trans(Bool, Spec.number(b), J.number_valid(b), True{}, Equal.sym(Bool, J.number_valid(b), Spec.number(b), Grammar.number_equiv(b)), vb))

# Every lexical integer is a valid number token.
def integer_number(+s: String, e: {D.is_integer(s) == True{} : Bool}) -> {J.number_valid(s) == True{} : Bool}:
  Integer.integer_number(s, e)
