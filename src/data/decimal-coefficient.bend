# Token-sized coefficients and exponent digit text. No numeric exponent is
# ever constructed by the runtime.
import Base
import ./decimal-natural.bend as N

def read_go(s: String, acc: N.Digits) -> N.Digits:
  match s:
    case SNil{}: acc
    case SCon{Chr{c}, t}: read_go(t, N.Digit{Nat.sub(U32.to_nat(c), 48n), acc})

def read(s: String) -> N.Digits:
  read_go(s, N.End{})

# Here the digit list is most significant first.
def trim(ds: N.Digits) -> N.Digits:
  match ds:
    case N.Digit{0n, t}: trim(t)
    case other: other

def coefficient(s: String) -> N.Digits:
  trim(N.reverse(read(s)))

def length_go(ds: N.Digits, n: Nat) -> Nat:
  match ds:
    case N.End{}: n
    case N.Digit{d, t}: length_go(t, 1n+n)

def length(ds: N.Digits) -> Nat:
  length_go(ds, 0n)

def zeros(n: Nat, ds: N.Digits) -> N.Digits:
  match n:
    case 0n: ds
    case 1n+k: zeros(k, N.Digit{0n, ds})

def padded(+a: N.Digits, +b: N.Digits) -> Cmp:
  N.cmp(zeros(length(b), N.reverse(a)), zeros(length(a), N.reverse(b)))

def is_zero(ds: N.Digits) -> Bool:
  match ds:
    case N.End{}: True{}
    case N.Digit{d, t}: False{}
