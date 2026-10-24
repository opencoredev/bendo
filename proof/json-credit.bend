# Fuel credit for parser continuations. The parser's budget is four
# transitions per input character plus slack, so a continuation that reaches
# Done keeps reaching it with more fuel, and each consumed character pays for
# its own transition and for non-consuming completions after it.
import Base
import ../src/data/json.bend as J
import ./utf8.bend as P

def is_done(r: Result<&2, &2, J.Error, J.Json>) -> Bool:
  match r:
    case Done{x}: True{}
    case Fail{e}: False{}

def fail_done(e: J.Error, v: J.Json, h: {Fail{e} == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> Empty:
  P.false_true(Equal.cong(Result<&2, &2, J.Error, J.Json>, Bool, r => is_done(r), Fail{e}, Done{v}, h))

def mono1(f: Nat, m: J.Machine, +v: J.Json, h: {J.parse_go(f, m) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(1n+f, m) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match f m:
    case 0n J.Machine{J.MValue{}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MValue{}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MArrayFirst{}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MArrayFirst{}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MReadKey{x1}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MReadKey{x1}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MColon{x1}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MColon{x1}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MArrayAfter{x1}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MArrayAfter{x1}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MObjectAfter{x1}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MObjectAfter{x1}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MEmit{x1}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MEmit{x1}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MText{x1, x2}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MText{x1, x2}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MEscape{x1, x2}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MEscape{x1, x2}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MHex{x1, x2, x3, x4, x5}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MHex{x1, x2, x3, x4, x5}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MLowSlash{x1, x2, x3}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MLowSlash{x1, x2, x3}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MLowU{x1, x2, x3}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MLowU{x1, x2, x3}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MLiteral{x1, x2}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MLiteral{x1, x2}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MNumber{x1, x2}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MNumber{x1, x2}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MBad{e}, s, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MBad{e}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(e, v, h))
    case 0n J.Machine{J.MEnd{w}, SNil{}, Nil{}, 0n}:
      h
    case 0n J.Machine{J.MEnd{w}, SNil{}, Nil{}, 1n+k}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MEnd{w}, SNil{}, Nil{}, 1n+k}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MEnd{w}, SNil{}, y <> ys, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MEnd{w}, SNil{}, y <> ys, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 0n J.Machine{J.MEnd{w}, SCon{c, t}, fs, d}:
      P.absurd({J.parse_go(1n+0n, J.Machine{J.MEnd{w}, SCon{c, t}, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(J.FuelExhausted{}, v, h))
    case 1n+g J.Machine{J.MValue{}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MValue{}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MArrayFirst{}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MArrayFirst{}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MReadKey{x1}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MReadKey{x1}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MColon{x1}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MColon{x1}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MArrayAfter{x1}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MArrayAfter{x1}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MObjectAfter{x1}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MObjectAfter{x1}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MEmit{x1}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MEmit{x1}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MText{x1, x2}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MText{x1, x2}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MEscape{x1, x2}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MEscape{x1, x2}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MHex{x1, x2, x3, x4, x5}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MHex{x1, x2, x3, x4, x5}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MLowSlash{x1, x2, x3}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MLowSlash{x1, x2, x3}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MLowU{x1, x2, x3}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MLowU{x1, x2, x3}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MLiteral{x1, x2}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MLiteral{x1, x2}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MNumber{x1, x2}, s, fs, d}:
      mono1(g, J.step(J.Machine{J.MNumber{x1, x2}, s, fs, d}), v, h)
    case 1n+g J.Machine{J.MBad{e}, s, fs, d}:
      P.absurd({J.parse_go(2n+g, J.Machine{J.MBad{e}, s, fs, d}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, fail_done(e, v, h))
    case 1n+g J.Machine{J.MEnd{w}, SNil{}, Nil{}, 0n}:
      h
    case 1n+g J.Machine{J.MEnd{w}, SNil{}, Nil{}, 1n+k}:
      mono1(g, J.step(J.Machine{J.MEnd{w}, SNil{}, Nil{}, 1n+k}), v, h)
    case 1n+g J.Machine{J.MEnd{w}, SNil{}, y <> ys, d}:
      mono1(g, J.step(J.Machine{J.MEnd{w}, SNil{}, y <> ys, d}), v, h)
    case 1n+g J.Machine{J.MEnd{w}, SCon{c, t}, fs, d}:
      mono1(g, J.step(J.Machine{J.MEnd{w}, SCon{c, t}, fs, d}), v, h)

def fuel_succ(+t: String, +a: Nat) -> {J.fuel_go(t, 1n+a) == 1n+J.fuel_go(t, a) : Nat}:
  match t:
    case SNil{}: {==}
    case SCon{c, r}: fuel_succ(r, 4n+a)

def fuel_lift(+k: Nat, +t: String, +a: Nat) -> {J.fuel_go(t, Nat.add(k, a)) == Nat.add(k, J.fuel_go(t, a)) : Nat}:
  match k:
    case 0n: {==}
    case 1n+p:
      %Equal.sym(Nat, J.fuel_go(t, 1n+Nat.add(p, a)), 1n+J.fuel_go(t, Nat.add(p, a)), fuel_succ(t, Nat.add(p, a))) : {_ == 1n+Nat.add(p, J.fuel_go(t, a)) : Nat}
      %Equal.sym(Nat, J.fuel_go(t, Nat.add(p, a)), Nat.add(p, J.fuel_go(t, a)), fuel_lift(p, t, a)) : {1n+_ == 1n+Nat.add(p, J.fuel_go(t, a)) : Nat}
      {==}

# More credit on the remaining input never hurts a continuation that is done.
def raise1(+t: String, +a: Nat, +m: J.Machine, +v: J.Json, h: {J.parse_go(J.fuel_go(t, a), m) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(t, 1n+a), m) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(Nat, J.fuel_go(t, 1n+a), 1n+J.fuel_go(t, a), fuel_succ(t, a)) : {J.parse_go(_, m) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  mono1(J.fuel_go(t, a), m, v, h)

def raise_add(+k: Nat, +t: String, +a: Nat, +m: J.Machine, +v: J.Json, h: {J.parse_go(J.fuel_go(t, a), m) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(t, Nat.add(k, a)), m) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match k:
    case 0n: h
    case 1n+p: raise1(t, Nat.add(p, a), m, v, raise_add(p, t, a, m, v, h))

# Turn an exact k-transition continuation into a credit step: the input
# before the suffix paid k + extra transitions, and extra is left over.
def credit(+k: Nat, +extra: Nat, +suffix: String, +a: Nat, +m: J.Machine, +next: J.Machine, +v: J.Json, exact: {J.parse_go(Nat.add(k, J.fuel_go(suffix, Nat.add(extra, a))), m) == J.parse_go(J.fuel_go(suffix, Nat.add(extra, a)), next) : Result<&2, &2, J.Error, J.Json>}, h: {J.parse_go(J.fuel_go(suffix, a), next) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(suffix, Nat.add(k, Nat.add(extra, a))), m) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(Nat, J.fuel_go(suffix, Nat.add(k, Nat.add(extra, a))), Nat.add(k, J.fuel_go(suffix, Nat.add(extra, a))), fuel_lift(k, suffix, Nat.add(extra, a))) : {J.parse_go(_, m) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Result<&2, &2, J.Error, J.Json>, J.parse_go(Nat.add(k, J.fuel_go(suffix, Nat.add(extra, a))), m), J.parse_go(J.fuel_go(suffix, Nat.add(extra, a)), next), exact) : {_ == Done{v} : Result<&2, &2, J.Error, J.Json>}
  raise_add(extra, suffix, a, next, v, h)

# One consumed character pays for its own transition with three to spare.
def consume(+c: Char, +t: String, +a: Nat, +m: J.Machine, +v: J.Json, h: {J.parse_go(J.fuel_go(t, a), J.step(m)) == Done{v} : Result<&2, &2, J.Error, J.Json>}, go: {J.parse_go(1n+J.fuel_go(t, 3n+a), m) == J.parse_go(J.fuel_go(t, 3n+a), J.step(m)) : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(SCon{c, t}, a), m) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(Nat, J.fuel_go(t, 1n+(3n+a)), 1n+J.fuel_go(t, 3n+a), fuel_succ(t, 3n+a)) : {J.parse_go(_, m) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Result<&2, &2, J.Error, J.Json>, J.parse_go(1n+J.fuel_go(t, 3n+a), m), J.parse_go(J.fuel_go(t, 3n+a), J.step(m)), go) : {_ == Done{v} : Result<&2, &2, J.Error, J.Json>}
  raise_add(3n, t, a, J.step(m), v, h)

# Word equality from comparison.
def cmp_fin_tail(a: Bool, b: Bool, c: Cmp, e: {Cmp.is_eq(Word.cmp.fin(a, b, c)) == True{} : Bool}) -> {Cmp.is_eq(c) == True{} : Bool}:
  match c:
    case LT{}: e
    case EQ{}: {==}
    case GT{}: e

def word_cmp_self(+n: Nat, +a: Word(n)) -> {Word.cmp(n, a, a) == EQ{} : Cmp}:
  match n:
    case 0n: {==}
    case 1n+p:
      match a:
        case WCon{False{}, t}:
          %word_cmp_self(p, t) : {Word.cmp.fin(False{}, False{}, Word.cmp(p, t, t)) == Word.cmp.fin(False{}, False{}, _) : Cmp}
          {==}
        case WCon{True{}, t}:
          %word_cmp_self(p, t) : {Word.cmp.fin(True{}, True{}, Word.cmp(p, t, t)) == Word.cmp.fin(True{}, True{}, _) : Cmp}
          {==}

def word_head(p: Nat, ah: Bool, bh: Bool, +at: Word(p)) -> {Cmp.is_eq(Bool.cmp(ah, bh)) == True{} : Bool} -> {WCon{ah, at} == WCon{bh, at} : Word(1n+p)}:
  match ah bh:
    case False{} False{}: e => {==}
    case False{} True{}: e => P.absurd({WCon{False{}, at} == WCon{True{}, at} : Word(1n+p)}, P.false_true(e))
    case True{} False{}: e => P.absurd({WCon{True{}, at} == WCon{False{}, at} : Word(1n+p)}, P.false_true(e))
    case True{} True{}: e => {==}

def word_step(+p: Nat, +ah: Bool, +bh: Bool, +at: Word(p), +bt: Word(p), tail: {at == bt : Word(p)}) -> {Cmp.is_eq(Word.cmp.fin(ah, bh, Word.cmp(p, at, bt))) == True{} : Bool} -> {WCon{ah, at} == WCon{bh, bt} : Word(1n+p)}:
  %tail : {Cmp.is_eq(Word.cmp.fin(ah, bh, Word.cmp(p, at, _))) == True{} : Bool} -> {WCon{ah, at} == WCon{bh, _} : Word(1n+p)}
  %Equal.sym(Cmp, Word.cmp(p, at, at), EQ{}, word_cmp_self(p, at)) : {Cmp.is_eq(Word.cmp.fin(ah, bh, _)) == True{} : Bool} -> {WCon{ah, at} == WCon{bh, at} : Word(1n+p)}
  word_head(p, ah, bh, at)

def word_eq_sound(+n: Nat, +a: Word(n), +b: Word(n), +e: {Cmp.is_eq(Word.cmp(n, a, b)) == True{} : Bool}) -> {a == b : Word(n)}:
  match n:
    case 0n:
      match a b:
        case WNil{} WNil{}: {==}
    case 1n+p:
      match a b:
        case WCon{ah, at} WCon{bh, bt}:
          tail = word_eq_sound(p, at, bt, cmp_fin_tail(ah, bh, Word.cmp(p, at, bt), e))
          word_step(p, ah, bh, at, bt, tail, e)

def u32_eq_sound(+a: U32, +b: U32, +e: {U32.is_eq(a, b) == True{} : Bool}) -> {a == b : U32}:
  match a b:
    case U32{x} U32{y}:
      Equal.cong(Word(32n), U32, w => U32{w}, x, y, word_eq_sound(32n, x, y, e))

# The same step, keeping all three spare credits for the continuation.
def consume_full(+c: Char, +t: String, +a: Nat, +m: J.Machine, +v: J.Json, h: {J.parse_go(J.fuel_go(t, 3n+a), J.step(m)) == Done{v} : Result<&2, &2, J.Error, J.Json>}, go: {J.parse_go(1n+J.fuel_go(t, 3n+a), m) == J.parse_go(J.fuel_go(t, 3n+a), J.step(m)) : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(SCon{c, t}, a), m) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(Nat, J.fuel_go(t, 1n+(3n+a)), 1n+J.fuel_go(t, 3n+a), fuel_succ(t, 3n+a)) : {J.parse_go(_, m) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Result<&2, &2, J.Error, J.Json>, J.parse_go(1n+J.fuel_go(t, 3n+a), m), J.parse_go(J.fuel_go(t, 3n+a), J.step(m)), go) : {_ == Done{v} : Result<&2, &2, J.Error, J.Json>}
  h

# One consumed character with a known exact transition to the next machine.
def consume_to(+c: Char, +t: String, +a: Nat, +m: J.Machine, +m2: J.Machine, +v: J.Json, h: {J.parse_go(J.fuel_go(t, a), m2) == Done{v} : Result<&2, &2, J.Error, J.Json>}, go: {J.parse_go(1n+J.fuel_go(t, 3n+a), m) == J.parse_go(J.fuel_go(t, 3n+a), m2) : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(SCon{c, t}, a), m) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(Nat, J.fuel_go(t, 1n+(3n+a)), 1n+J.fuel_go(t, 3n+a), fuel_succ(t, 3n+a)) : {J.parse_go(_, m) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Result<&2, &2, J.Error, J.Json>, J.parse_go(1n+J.fuel_go(t, 3n+a), m), J.parse_go(J.fuel_go(t, 3n+a), m2), go) : {_ == Done{v} : Result<&2, &2, J.Error, J.Json>}
  raise_add(3n, t, a, m2, v, h)
