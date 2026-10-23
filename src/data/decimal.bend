# Exact decimal ordering without float conversion or exponent expansion.
import Base
import ./json.bend as J

def length_go(s: String, n: Nat) -> Nat:
  match s:
    case SNil{}: n
    case SCon{h, t}: length_go(t, 1n+n)

def length(s: String) -> Nat:
  length_go(s, 0n)

def trim(s: String) -> String:
  match s:
    case SCon{'0', t}: trim(t)
    case t: t

def magnitude_go(a: String, b: String, sizes: Cmp) -> Cmp:
  match sizes:
    case EQ{}: String.order(a, b)
    case other: other

def magnitude(+a: String, +b: String) -> Cmp:
  magnitude_go(a, b, Nat.cmp(length(a), length(b)))

type Signed is Data:
  Signed{negative: Bool, digits: String}

def signed(negative: Bool, digits: String) -> Signed:
  match digits:
    case SNil{}: Signed{False{}, ""}
    case other: Signed{negative, other}

def from_text(s: String) -> Signed:
  match s:
    case SCon{'-', t}: signed(True{}, trim(t))
    case SCon{'+', t}: signed(False{}, trim(t))
    case t: signed(False{}, trim(t))

def flip(c: Cmp) -> Cmp:
  match c:
    case LT{}: GT{}
    case EQ{}: EQ{}
    case GT{}: LT{}

def signed_cmp(a: Signed, b: Signed) -> Cmp:
  match a b:
    case Signed{False{}, x} Signed{False{}, y}: magnitude(x, y)
    case Signed{True{}, x} Signed{True{}, y}: flip(magnitude(x, y))
    case Signed{True{}, x} Signed{False{}, y}: LT{}
    case Signed{False{}, x} Signed{True{}, y}: GT{}

def digit(c: Char) -> U32:
  Chr{x} = c
  (x - 48 : U32)

# Reversed digits, with an explicit carry/borrow, accumulated most significant first.
def add_go(a: String, b: String, +carry: U32, acc: String) -> String:
  match a b:
    case SNil{} SNil{}:
      match carry:
        case 0: acc
        case _: SCon{'1', acc}
    case SCon{h, t} SNil{}:
      +v = (digit(h) + carry : U32)
      add_go(t, "", (v / 10 : U32), SCon{Chr{(48 + v % 10 : U32)}, acc})
    case SNil{} SCon{h, t}:
      +v = (digit(h) + carry : U32)
      add_go("", t, (v / 10 : U32), SCon{Chr{(48 + v % 10 : U32)}, acc})
    case SCon{h, t} SCon{k, u}:
      +v = (digit(h) + digit(k) + carry : U32)
      add_go(t, u, (v / 10 : U32), SCon{Chr{(48 + v % 10 : U32)}, acc})

def borrow(v: U32) -> U32:
  match v:
    case 0: 1
    case _: 0

def sub_go(a: String, b: String, debt: U32, acc: String) -> String:
  match a b:
    case SNil{} _: trim(acc)
    case SCon{h, t} SNil{}:
      +v = (10 + digit(h) - debt : U32)
      sub_go(t, "", borrow((v / 10 : U32)), SCon{Chr{(48 + v % 10 : U32)}, acc})
    case SCon{h, t} SCon{k, u}:
      +v = (10 + digit(h) - digit(k) - debt : U32)
      sub_go(t, u, borrow((v / 10 : U32)), SCon{Chr{(48 + v % 10 : U32)}, acc})

def subtract(+a: String, +b: String, negative: Bool, c: Cmp) -> Signed:
  match c:
    case LT{}: signed(Bool.not(negative), sub_go(String.reverse(b), String.reverse(a), 0, ""))
    case _: signed(negative, sub_go(String.reverse(a), String.reverse(b), 0, ""))

def add(a: Signed, b: Signed) -> Signed:
  match a b:
    case Signed{False{}, +x} Signed{False{}, +y}: signed(False{}, trim(add_go(String.reverse(x), String.reverse(y), 0, "")))
    case Signed{True{}, +x} Signed{True{}, +y}: signed(True{}, trim(add_go(String.reverse(x), String.reverse(y), 0, "")))
    case Signed{False{}, +x} Signed{True{}, +y}: subtract(x, y, False{}, magnitude(x, y))
    case Signed{True{}, +x} Signed{False{}, +y}: subtract(x, y, True{}, magnitude(x, y))

type Parts is Data:
  Parts{digits: String, fraction: Nat, exponent: String}

def collect(s: String, dotted: Bool, frac: Nat, rev: String) -> Parts:
  match s:
    case SNil{}: Parts{trim(String.reverse(rev)), frac, ""}
    case SCon{'e', t}: Parts{trim(String.reverse(rev)), frac, t}
    case SCon{'E', t}: Parts{trim(String.reverse(rev)), frac, t}
    case SCon{'.', t}: collect(t, True{}, frac, rev)
    case SCon{h, t}:
      match dotted:
        case True{}: collect(t, True{}, 1n+frac, SCon{h, rev})
        case False{}: collect(t, False{}, frac, SCon{h, rev})

type Decimal is Data:
  Decimal{negative: Bool, digits: String, order: Signed}

def parts(negative: Bool, p: Parts) -> Decimal:
  Parts{+digits, frac, exponent} = p
  Decimal{negative, digits, add(add(from_text(exponent), from_text(Nat.show(length(digits)))), signed(True{}, trim(Nat.show(frac))))}

def normalize(s: String) -> Decimal:
  match s:
    case SCon{'-', t}: parts(True{}, collect(t, False{}, 0n, ""))
    case t: parts(False{}, collect(t, False{}, 0n, ""))

# Pad missing coefficient digits with zero, without allocating exponent-sized text.
def coefficient(a: String, b: String, c: Cmp) -> Cmp:
  match a b c:
    case SNil{} SNil{} EQ{}: EQ{}
    case SCon{'0', t} SNil{} EQ{}: coefficient(t, "", EQ{})
    case SCon{h, t} SNil{} EQ{}: GT{}
    case SNil{} SCon{'0', t} EQ{}: coefficient("", t, EQ{})
    case SNil{} SCon{h, t} EQ{}: LT{}
    case SCon{h, t} SCon{k, u} EQ{}: coefficient(t, u, U32.cmp(digit(h), digit(k)))
    case _ _ other: other

def positive_order(x: String, y: String, c: Cmp) -> Cmp:
  match c:
    case EQ{}: coefficient(x, y, EQ{})
    case other: other

def positive_digits(+x: String, e: Signed, +y: String, f: Signed) -> Cmp:
  match x y:
    case SNil{} SNil{}: EQ{}
    case SNil{} _: LT{}
    case _ SNil{}: GT{}
    case _ _: positive_order(x, y, signed_cmp(e, f))

def positive(a: Decimal, b: Decimal) -> Cmp:
  Decimal{s, x, e} = a
  Decimal{t, y, f} = b
  positive_digits(x, e, y, f)

def negative(d: Decimal) -> Bool:
  Decimal{s, ds, e} = d
  s && Bool.not(String.is_empty(ds))

def order_go(+a: Decimal, +b: Decimal, sa: Bool, sb: Bool) -> Cmp:
  match sa sb:
    case False{} False{}: positive(a, b)
    case True{} True{}: flip(positive(a, b))
    case True{} False{}: LT{}
    case False{} True{}: GT{}

def normalized_order(+a: Decimal, +b: Decimal) -> Cmp:
  order_go(a, b, negative(a), negative(b))

# Inputs must satisfy Json.number_valid. Schema checks enforce that boundary.
def order(a: String, b: String) -> Cmp:
  normalized_order(normalize(a), normalize(b))

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
