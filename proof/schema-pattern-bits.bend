# Bit words as the automaton reads them: a U32's bits, lowest first. The scan
# tests the low bit with `.&. 1` and shifts right; these lemmas tie both
# operations, and `.|.`, to the word's structure.
import Base

def bits(n: Nat, w: Word(n)) -> List<&2, Bool>:
  match n:
    case 0n: []
    case 1n+p:
      match w:
        case WCon{b, t}: b <> bits(p, t)

def bits32(x: U32) -> List<&2, Bool>:
  match x:
    case U32{w}: bits(32n, w)

# Pointwise or; the longer list keeps its tail.
def zip_or(xs: List<&2, Bool>, ys: List<&2, Bool>) -> List<&2, Bool>:
  match xs ys:
    case Nil{} _: ys
    case a <> s Nil{}: a <> s
    case a <> s b <> t: (a || b) <> zip_or(s, t)

def or_bits(+n: Nat, +x: Word(n), +y: Word(n)) -> {bits(n, Word.or(n, x, y)) == zip_or(bits(n, x), bits(n, y)) : List<&2, Bool>}:
  match n:
    case 0n: {==}
    case 1n+p:
      match x y:
        case WCon{a, s} WCon{b, t}:
          %or_bits(p, s, t) : {bits(1n+p, Word.or(1n+p, WCon{a, s}, WCon{b, t})) == Bool.or(a, b) <> _ : List<&2, Bool>}
          {==}

def or32(+x: U32, +y: U32) -> {bits32((x .|. y : U32)) == zip_or(bits32(x), bits32(y)) : List<&2, Bool>}:
  match x y:
    case U32{a} U32{b}: or_bits(32n, a, b)

def and_zero(+n: Nat, +w: Word(n)) -> {Word.and(n, w, Word.zero(n)) == Word.zero(n) : Word(n)}:
  match n:
    case 0n: {==}
    case 1n+p:
      match w:
        case WCon{False{}, t}:
          %and_zero(p, t) : {WCon{False{}, Word.and(p, t, Word.zero(p))} == WCon{False{}, _} : Word(1n+p)}
          {==}
        case WCon{True{}, t}:
          %and_zero(p, t) : {WCon{False{}, Word.and(p, t, Word.zero(p))} == WCon{False{}, _} : Word(1n+p)}
          {==}

def head(xs: List<&2, Bool>) -> Bool:
  match xs:
    case Nil{}: False{}
    case b <> t: b

def low_bits(+b: Bool, +t: Word(31n)) -> {U32.is_ne((U32{WCon{b, t}} .&. 1 : U32), 0) == b : Bool}:
  match b:
    case True{}:
      %Equal.sym(Word(31n), Word.and(31n, t, Word.zero(31n)), Word.zero(31n), and_zero(31n, t)) : {Bool.not(Cmp.is_eq(Word.cmp.fin(True{}, False{}, Word.cmp(31n, _, Word.zero(31n))))) == True{} : Bool}
      {==}
    case False{}:
      %Equal.sym(Word(31n), Word.and(31n, t, Word.zero(31n)), Word.zero(31n), and_zero(31n, t)) : {Bool.not(Cmp.is_eq(Word.cmp.fin(False{}, False{}, Word.cmp(31n, _, Word.zero(31n))))) == False{} : Bool}
      {==}

# The low bit is the first bit.
def low32(+x: U32) -> {U32.is_ne((x .&. 1 : U32), 0) == head(bits32(x)) : Bool}:
  match x:
    case U32{w}:
      match w:
        case WCon{b, t}: low_bits(b, t)

def pad_bits(+n: Nat, +w: Word(n)) -> {bits(1n+n, Word.shr.pad(n, w)) == List.append(&2, Bool, bits(n, w), [False{}]) : List<&2, Bool>}:
  match n:
    case 0n: {==}
    case 1n+p:
      match w:
        case WCon{b, t}:
          %pad_bits(p, t) : {bits(2n+p, Word.shr.pad(1n+p, WCon{b, t})) == b <> _ : List<&2, Bool>}
          {==}

def tail(xs: List<&2, Bool>) -> List<&2, Bool>:
  match xs:
    case Nil{}: []
    case b <> t: t

# Shifting right drops the first bit and brings in a clear one at the end.
def shift32(+x: U32) -> {bits32((x >> 1n : U32)) == List.append(&2, Bool, tail(bits32(x)), [False{}]) : List<&2, Bool>}:
  match x:
    case U32{w}:
      match w:
        case WCon{b, t}: pad_bits(31n, t)
