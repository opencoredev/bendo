# Decimal naturals, least significant digit first. Runtime digits stay in 0..9;
# a carry stays in 0..1, independently of the number's magnitude.
import Base

type Digits is Data:
  End{}
  Digit{head: Nat, tail: Digits}

def reverse_go(ds: Digits, acc: Digits) -> Digits:
  match ds:
    case End{}: acc
    case Digit{d, t}: reverse_go(t, Digit{d, acc})

def reverse(ds: Digits) -> Digits:
  reverse_go(ds, End{})

def low(n: Nat) -> Nat:
  match n:
    case 0n: 0n
    case 1n: 1n
    case 2n: 2n
    case 3n: 3n
    case 4n: 4n
    case 5n: 5n
    case 6n: 6n
    case 7n: 7n
    case 8n: 8n
    case 9n: 9n
    case 10n+k: k

def carry(n: Nat) -> Nat:
  match n:
    case 0n: 0n
    case 1n: 0n
    case 2n: 0n
    case 3n: 0n
    case 4n: 0n
    case 5n: 0n
    case 6n: 0n
    case 7n: 0n
    case 8n: 0n
    case 9n: 0n
    case 10n+k: 1n

def last(c: Nat) -> Digits:
  match c:
    case 0n: End{}
    case 1n+k: Digit{1n+k, End{}}

def add_go(a: Digits, b: Digits, c: Nat, acc: Digits) -> Digits:
  match a b:
    case End{} End{}: reverse_go(acc, last(c))
    case Digit{d, t} End{}:
      +n = Nat.add(c, Nat.add(d, 0n))
      add_go(t, End{}, carry(n), Digit{low(n), acc})
    case End{} Digit{e, u}:
      +n = Nat.add(c, e)
      add_go(End{}, u, carry(n), Digit{low(n), acc})
    case Digit{d, t} Digit{e, u}:
      +n = Nat.add(c, Nat.add(d, e))
      add_go(t, u, carry(n), Digit{low(n), acc})

def add(a: Digits, b: Digits) -> Digits:
  add_go(a, b, 0n, End{})

# Only the initial run of nines is traversed and rebuilt. Counting n tokens
# therefore takes O(n) digit work in total, including all carries.
def increment_go(ds: Digits, acc: Digits) -> Digits:
  match ds:
    case End{}: reverse_go(acc, Digit{1n, End{}})
    case Digit{9n, t}: increment_go(t, Digit{0n, acc})
    case Digit{d, t}: reverse_go(acc, Digit{1n+d, t})

def increment(ds: Digits) -> Digits:
  increment_go(ds, End{})

def count(n: Nat, acc: Digits) -> Digits:
  match n:
    case 0n: acc
    case 1n+k: count(k, increment(acc))

# A higher unequal digit replaces any decision made at lower positions.
def choose(higher: Cmp, lower: Cmp) -> Cmp:
  match higher:
    case EQ{}: lower
    case other: other

def cmp_go(a: Digits, b: Digits, c: Cmp) -> Cmp:
  match a b:
    case End{} End{}: c
    case Digit{d, t} End{}: cmp_go(t, End{}, choose(Nat.cmp(d, 0n), c))
    case End{} Digit{e, u}: cmp_go(End{}, u, choose(Nat.cmp(0n, e), c))
    case Digit{d, t} Digit{e, u}: cmp_go(t, u, choose(Nat.cmp(d, e), c))

def cmp(a: Digits, b: Digits) -> Cmp:
  cmp_go(a, b, EQ{})
