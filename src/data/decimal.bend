# Exact decimal ordering without float conversion or exponent expansion.
import Base
import ./json.bend as J
import ./decimal-natural.bend as N
import ./decimal-parts.bend as P
import ./decimal-coefficient.bend as C

def length_go(s: String, n: Nat) -> Nat:
  match s:
    case SNil{}: n
    case SCon{h, t}: length_go(t, 1n+n)

def length(s: String) -> Nat:
  length_go(s, 0n)

def flip(c: Cmp) -> Cmp:
  match c:
    case LT{}: GT{}
    case EQ{}: EQ{}
    case GT{}: LT{}

def up(p: P.Parts) -> N.Digits:
  P.Parts{negative, ds, scale, en, x} = p
  Bool.pick(N.Digits, en, N.End{}, C.read(x))

def down(p: P.Parts) -> N.Digits:
  P.Parts{negative, ds, scale, en, x} = p
  Bool.pick(N.Digits, en, C.read(x), N.End{})

def scale(p: P.Parts) -> Nat:
  P.Parts{negative, ds, scale, en, x} = p
  scale

# Cross-multiplied digit ranks use only natural sums. Counting increments
# bounded token lengths; the exponent itself remains a decimal digit list.
def rank(+a: P.Parts, +b: P.Parts, x: N.Digits) -> N.Digits:
  N.count(C.length(x), N.add(N.count(scale(b), up(a)), down(b)))

def positive(+a: P.Parts, +b: P.Parts, x: N.Digits, y: N.Digits) -> Cmp:
  match x y:
    case N.End{} N.End{}: EQ{}
    case N.End{} N.Digit{d, t}: LT{}
    case N.Digit{d, t} N.End{}: GT{}
    case N.Digit{+d, +t} N.Digit{+e, +u}:
      N.choose(N.cmp(rank(a, b, N.Digit{d, t}), rank(b, a, N.Digit{e, u})), C.padded(N.Digit{d, t}, N.Digit{e, u}))

def negative(p: P.Parts, ds: N.Digits) -> Bool:
  P.Parts{sign, digits, scale, en, exp} = p
  sign && Bool.not(C.is_zero(ds))

def order_go(+a: P.Parts, +b: P.Parts, +x: N.Digits, +y: N.Digits, sa: Bool, sb: Bool) -> Cmp:
  match sa sb:
    case False{} False{}: positive(a, b, x, y)
    case True{} True{}: positive(b, a, y, x)
    case True{} False{}: LT{}
    case False{} True{}: GT{}

def coefficient_order(+a: P.Parts, +b: P.Parts, +x: N.Digits, +y: N.Digits) -> Cmp:
  order_go(a, b, x, y, negative(a, x), negative(b, y))

def normalized_order(+a: P.Parts, +b: P.Parts) -> Cmp:
  P.Parts{na, da, fa, ea, xa} = a
  P.Parts{nb, db, fb, eb, xb} = b
  coefficient_order(a, b, C.coefficient(da), C.coefficient(db))

# Inputs must satisfy Json.number_valid. Schema checks enforce that boundary.
def order(a: String, b: String) -> Cmp:
  normalized_order(P.parts(a), P.parts(b))

def integer_go(s: String, ok: Bool) -> Bool:
  match s:
    case SNil{}: ok
    case SCon{Chr{c}, t}: integer_go(t, ok && J.digit(c))

def integer(s: String) -> Bool:
  integer_go(s, True{})

def is_integer(+s: String) -> Bool:
  match s:
    case SCon{'-', t}: J.number_valid(s) && integer(t)
    case t: J.number_valid(s) && integer(t)
