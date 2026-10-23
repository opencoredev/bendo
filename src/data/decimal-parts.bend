# A tail-recursive parser kept separate from decimal normalization.
import Base
import ./json.bend as J

type Parts is Data:
  Parts{negative: Bool, digits: String, scale: Nat, exponent_negative: Bool, exponent: String}

type Exponent is Data:
  Exponent{negative: Bool, digits: String}

def head_digit(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{c}, t}: J.digit(c)

def scan_go(s: String, rev: String, digit: Bool) -> String & String:
  match s digit:
    case SNil{} _: (String.reverse(rev), "")
    case SCon{h, +t} True{}: scan_go(t, SCon{h, rev}, head_digit(t))
    case other False{}: (String.reverse(rev), other)

def scan(+s: String) -> String & String:
  scan_go(s, "", head_digit(s))

def signed_exponent(s: String) -> Exponent:
  match s:
    case SNil{}: Exponent{False{}, ""}
    case SCon{Chr{+c}, +t}:
      Bool.pick(Exponent, U32.is_eq(c, 45), Exponent{True{}, t}, Bool.pick(Exponent, U32.is_eq(c, 43), Exponent{False{}, t}, Exponent{False{}, SCon{Chr{c}, t}}))

def exponent(s: String) -> Exponent:
  match s:
    case SNil{}: Exponent{False{}, ""}
    case SCon{c, t}: signed_exponent(t)

def length_go(s: String, n: Nat) -> Nat:
  match s:
    case SNil{}: n
    case SCon{h, t}: length_go(t, 1n+n)

# Prepending the reversed whole part avoids a non-tail String.append.
def assemble(negative: Bool, whole: String, +frac: String, e: Exponent) -> Parts:
  Exponent{en, x} = e
  Parts{negative, String.reverse.go(String.reverse(whole), frac), length_go(frac, 0n), en, x}

def fraction(negative: Bool, whole: String, p: String & String) -> Parts:
  (frac, rest) = p
  assemble(negative, whole, frac, exponent(rest))

def after_whole(negative: Bool, whole: String, +rest: String, dotted: Bool) -> Parts:
  match rest dotted:
    case SCon{c, t} True{}: fraction(negative, whole, scan(t))
    case other _: assemble(negative, whole, "", exponent(other))

def head_dot(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{c}, t}: U32.is_eq(c, 46)

def unsigned_done(negative: Bool, p: String & String) -> Parts:
  (whole, +rest) = p
  after_whole(negative, whole, rest, head_dot(rest))

def unsigned(negative: Bool, s: String) -> Parts:
  unsigned_done(negative, scan(s))

def parts(s: String) -> Parts:
  match s:
    case SNil{}: unsigned(False{}, "")
    case SCon{Chr{+c}, +t}:
      Bool.pick(Parts, U32.is_eq(c, 45), unsigned(True{}, t), unsigned(False{}, SCon{Chr{c}, t}))
