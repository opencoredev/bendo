# Word arithmetic over partly symbolic bits, for surrogate-pair escapes.
# Each lemma keeps the symbolic low bits structural, so the concrete high
# bits still compute, or cancels a constant without assuming ring laws.
import Base
import ../src/data/utf8.bend as U

def ones(n: Nat) -> Word(n):
  match n:
    case 0n: WNil{}
    case 1n+p: WCon{True{}, ones(p)}

# Subtracting a constant whose low k bits are zero keeps those bits.
def sub_low_zero(+k: Nat, +m: Nat, +x: Word(k), +a: Word(m), +b: Word(m)) -> {Word.adc(Nat.add(k, m), U.join(k, m, x, a), U.join(k, m, Word.zero(k), b), True{}, True{}) == U.join(k, m, x, Word.adc(m, a, b, True{}, True{})) : Word(Nat.add(k, m))}:
  match k:
    case 0n: {==}
    case 1n+p:
      match x:
        case WCon{False{}, t}:
          %sub_low_zero(p, m, t, a, b) : {WCon{False{}, Word.adc(Nat.add(p, m), U.join(p, m, t, a), U.join(p, m, Word.zero(p), b), True{}, True{})} == WCon{False{}, _} : Word(1n+Nat.add(p, m))}
          {==}
        case WCon{True{}, t}:
          %sub_low_zero(p, m, t, a, b) : {WCon{True{}, Word.adc(Nat.add(p, m), U.join(p, m, t, a), U.join(p, m, Word.zero(p), b), True{}, True{})} == WCon{True{}, _} : Word(1n+Nat.add(p, m))}
          {==}

# Adding a constant whose low k bits are zero keeps the other operand's bits.
def add_low_zero(+k: Nat, +m: Nat, +x: Word(k), +a: Word(m), +b: Word(m)) -> {Word.adc(Nat.add(k, m), U.join(k, m, Word.zero(k), a), U.join(k, m, x, b), False{}, False{}) == U.join(k, m, x, Word.adc(m, a, b, False{}, False{})) : Word(Nat.add(k, m))}:
  match k:
    case 0n: {==}
    case 1n+p:
      match x:
        case WCon{False{}, t}:
          %add_low_zero(p, m, t, a, b) : {WCon{False{}, Word.adc(Nat.add(p, m), U.join(p, m, Word.zero(p), a), U.join(p, m, t, b), False{}, False{})} == WCon{False{}, _} : Word(1n+Nat.add(p, m))}
          {==}
        case WCon{True{}, t}:
          %add_low_zero(p, m, t, a, b) : {WCon{True{}, Word.adc(Nat.add(p, m), U.join(p, m, Word.zero(p), a), U.join(p, m, t, b), False{}, False{})} == WCon{True{}, _} : Word(1n+Nat.add(p, m))}
          {==}

def and_zero(+n: Nat, +w: Word(n)) -> {Word.and(n, w, Word.zero(n)) == Word.zero(n) : Word(n)}:
  match n:
    case 0n:
      match w:
        case WNil{}: {==}
    case 1n+p:
      match w:
        case WCon{False{}, t}:
          %and_zero(p, t) : {WCon{False{}, Word.and(p, t, Word.zero(p))} == WCon{False{}, _} : Word(1n+p)}
          {==}
        case WCon{True{}, t}:
          %and_zero(p, t) : {WCon{False{}, Word.and(p, t, Word.zero(p))} == WCon{False{}, _} : Word(1n+p)}
          {==}

# A low mask keeps exactly the low k bits.
def and_low_ones(+k: Nat, +m: Nat, +x: Word(k), +a: Word(m)) -> {Word.and(Nat.add(k, m), U.join(k, m, x, a), U.join(k, m, ones(k), Word.zero(m))) == U.join(k, m, x, Word.zero(m)) : Word(Nat.add(k, m))}:
  match k:
    case 0n: and_zero(m, a)
    case 1n+p:
      match x:
        case WCon{False{}, t}:
          %and_low_ones(p, m, t, a) : {WCon{False{}, Word.and(Nat.add(p, m), U.join(p, m, t, a), U.join(p, m, ones(p), Word.zero(m)))} == WCon{False{}, _} : Word(1n+Nat.add(p, m))}
          {==}
        case WCon{True{}, t}:
          %and_low_ones(p, m, t, a) : {WCon{True{}, Word.and(Nat.add(p, m), U.join(p, m, t, a), U.join(p, m, ones(p), Word.zero(m)))} == WCon{True{}, _} : Word(1n+Nat.add(p, m))}
          {==}

# Adding k with carry c, then subtracting k with borrow-in not(c), restores
# the word. The outgoing carries stay complementary at every bit.
def add_sub_cancel(+n: Nat, +a: Word(n), +k: Word(n), +c: Bool) -> {Word.adc(n, Word.adc(n, a, k, False{}, c), k, True{}, Bool.not(c)) == a : Word(n)}:
  match n:
    case 0n:
      match a:
        case WNil{}: {==}
    case 1n+p:
      match a k c:
        case WCon{False{}, at} WCon{False{}, kt} False{}:
          %add_sub_cancel(p, at, kt, False{}) : {WCon{False{}, Word.adc(p, Word.adc(p, at, kt, False{}, False{}), kt, True{}, True{})} == WCon{False{}, _} : Word(1n+p)}
          {==}
        case WCon{False{}, at} WCon{False{}, kt} True{}:
          %add_sub_cancel(p, at, kt, False{}) : {WCon{False{}, Word.adc(p, Word.adc(p, at, kt, False{}, False{}), kt, True{}, True{})} == WCon{False{}, _} : Word(1n+p)}
          {==}
        case WCon{False{}, at} WCon{True{}, kt} False{}:
          %add_sub_cancel(p, at, kt, False{}) : {WCon{False{}, Word.adc(p, Word.adc(p, at, kt, False{}, False{}), kt, True{}, True{})} == WCon{False{}, _} : Word(1n+p)}
          {==}
        case WCon{False{}, at} WCon{True{}, kt} True{}:
          %add_sub_cancel(p, at, kt, True{}) : {WCon{False{}, Word.adc(p, Word.adc(p, at, kt, False{}, True{}), kt, True{}, False{})} == WCon{False{}, _} : Word(1n+p)}
          {==}
        case WCon{True{}, at} WCon{False{}, kt} False{}:
          %add_sub_cancel(p, at, kt, False{}) : {WCon{True{}, Word.adc(p, Word.adc(p, at, kt, False{}, False{}), kt, True{}, True{})} == WCon{True{}, _} : Word(1n+p)}
          {==}
        case WCon{True{}, at} WCon{False{}, kt} True{}:
          %add_sub_cancel(p, at, kt, True{}) : {WCon{True{}, Word.adc(p, Word.adc(p, at, kt, False{}, True{}), kt, True{}, False{})} == WCon{True{}, _} : Word(1n+p)}
          {==}
        case WCon{True{}, at} WCon{True{}, kt} False{}:
          %add_sub_cancel(p, at, kt, True{}) : {WCon{True{}, Word.adc(p, Word.adc(p, at, kt, False{}, True{}), kt, True{}, False{})} == WCon{True{}, _} : Word(1n+p)}
          {==}
        case WCon{True{}, at} WCon{True{}, kt} True{}:
          %add_sub_cancel(p, at, kt, True{}) : {WCon{True{}, Word.adc(p, Word.adc(p, at, kt, False{}, True{}), kt, True{}, False{})} == WCon{True{}, _} : Word(1n+p)}
          {==}
