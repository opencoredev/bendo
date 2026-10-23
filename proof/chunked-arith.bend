# Unsigned word arithmetic read through Word.to_nat, for the chunk decoder's
# budget and counters. Every fact here is about Base's own definitions.
import Base
import ../src/router/codec-bits.bend as Bits

def bit(b: Bool) -> Nat:
  match b:
    case False{}:
      0n
    case True{}:
      1n

def pred(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+p:
      p

def eq_not_lt(-A: Type, e: {EQ{} == LT{} : Cmp}) -> A:
  Bits.absurd(A, Bits.false_true(Equal.cong(Cmp, Bool, c => Cmp.is_lt(c), EQ{}, LT{}, e)))

def gt_not_lt(-A: Type, e: {GT{} == LT{} : Cmp}) -> A:
  Bits.absurd(A, Bits.false_true(Equal.cong(Cmp, Bool, c => Cmp.is_lt(c), GT{}, LT{}, e)))

# Natural number facts.

law add_zero_r:
  for +a: Nat
  {Nat.add(a, 0n) == a : Nat}

def add_zero_r(a):
  match a:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(p, 0n), p, add_zero_r(p))

law add_succ_r:
  for +a: Nat
  for +b: Nat
  {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}

def add_succ_r(a, b):
  match a:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(p, 1n+b), 1n+Nat.add(p, b), add_succ_r(p, b))

law cmp_add_cancel:
  for +k: Nat
  for +x: Nat
  for +y: Nat
  {Nat.cmp(Nat.add(k, x), Nat.add(k, y)) == Nat.cmp(x, y) : Cmp}

def cmp_add_cancel(k, x, y):
  match k:
    case 0n:
      {==}
    case 1n+p:
      cmp_add_cancel(p, x, y)

law double_add:
  for +a: Nat
  for +b: Nat
  {Nat.add(Nat.double(a), Nat.double(b)) == Nat.double(Nat.add(a, b)) : Nat}

def double_add(a, b):
  match a:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, x => 2n+x, Nat.add(Nat.double(p), Nat.double(b)), Nat.double(Nat.add(p, b)), double_add(p, b))

law double_add_odd:
  for +a: Nat
  for +b: Nat
  {Nat.add(Nat.double(a), 1n+Nat.double(b)) == 1n+Nat.double(Nat.add(a, b)) : Nat}

def double_add_odd(a, b):
  %double_add(a, b) : {Nat.add(Nat.double(a), 1n+Nat.double(b)) == 1n+_ : Nat}
  add_succ_r(Nat.double(a), Nat.double(b))

law le_succ_r:
  for +a: Nat
  for +b: Nat
  for le: {Nat.is_le(a, b) == True{} : Bool}
  {Nat.is_le(a, 1n+b) == True{} : Bool}

def le_succ_r(a, b, le):
  match a b:
    case 0n b:
      {==}
    case 1n+p 0n:
      Bits.absurd({Nat.is_le(1n+p, 1n) == True{} : Bool}, Bits.false_true(le))
    case 1n+p 1n+q:
      le_succ_r(p, q, le)

law le_add_l:
  for +x: Nat
  for +y: Nat
  {Nat.is_le(x, Nat.add(y, x)) == True{} : Bool}

def le_refl(+x: Nat) -> {Nat.is_le(x, x) == True{} : Bool}:
  match x:
    case 0n:
      {==}
    case 1n+p:
      le_refl(p)

def le_add_l(x, y):
  match y:
    case 0n:
      le_refl(x)
    case 1n+q:
      le_succ_r(x, Nat.add(q, x), le_add_l(x, q))

law le_add_r:
  for +a: Nat
  for +x: Nat
  for +b: Nat
  for le: {Nat.is_le(Nat.add(a, x), b) == True{} : Bool}
  {Nat.is_le(a, b) == True{} : Bool}

def zero_le(+b: Nat) -> {Nat.is_le(0n, b) == True{} : Bool}:
  match b:
    case 0n:
      {==}
    case 1n+q:
      {==}

def le_add_r(a, x, b, le):
  match a b:
    case 0n b:
      zero_le(b)
    case 1n+p 0n:
      Bits.absurd({Nat.is_le(1n+p, 0n) == True{} : Bool}, Bits.false_true(le))
    case 1n+p 1n+q:
      le_add_r(p, x, q, le)

law le_pred:
  for +a: Nat
  for +b: Nat
  for le: {Nat.is_le(1n+a, b) == True{} : Bool}
  {Nat.is_le(a, b) == True{} : Bool}

def le_pred(a, b, le):
  le_add_r(a, 1n, b, Equal.trans(Bool, Nat.is_le(Nat.add(a, 1n), b), Nat.is_le(1n+Nat.add(a, 0n), b), True{},
    Equal.cong(Nat, Bool, x => Nat.is_le(x, b), Nat.add(a, 1n), 1n+Nat.add(a, 0n), add_succ_r(a, 0n)),
    %Equal.sym(Nat, Nat.add(a, 0n), a, add_zero_r(a)) : {Nat.is_le(1n+_, b) == True{} : Bool}
    le))

law succ_le_lt:
  for +a: Nat
  for +b: Nat
  for le: {Nat.is_le(1n+a, b) == True{} : Bool}
  {Nat.cmp(a, b) == LT{} : Cmp}

def succ_le_lt(a, b, le):
  match a b:
    case a 0n:
      Bits.absurd({Nat.cmp(a, 0n) == LT{} : Cmp}, Bits.false_true(le))
    case 0n 1n+q:
      {==}
    case 1n+p 1n+q:
      succ_le_lt(p, q, le)

# Comparing two words compares their numeric values.

def word_value(b: Bool, n: Nat) -> Nat:
  match b:
    case False{}:
      Nat.double(n)
    case True{}:
      1n+Nat.double(n)

law cmp_bits:
  for +x: Bool
  for +y: Bool
  for +s: Nat
  for +t: Nat
  {Nat.cmp(word_value(x, s), word_value(y, t)) == Word.cmp.fin(x, y, Nat.cmp(s, t)) : Cmp}

def cmp_bits(x, y, s, t):
  match x y s t:
    case False{} False{} 0n 0n:
      {==}
    case False{} True{} 0n 0n:
      {==}
    case True{} False{} 0n 0n:
      {==}
    case True{} True{} 0n 0n:
      {==}
    case False{} False{} 0n 1n+q:
      {==}
    case False{} True{} 0n 1n+q:
      {==}
    case True{} False{} 0n 1n+q:
      {==}
    case True{} True{} 0n 1n+q:
      {==}
    case False{} False{} 1n+p 0n:
      {==}
    case False{} True{} 1n+p 0n:
      {==}
    case True{} False{} 1n+p 0n:
      {==}
    case True{} True{} 1n+p 0n:
      {==}
    case False{} False{} 1n+p 1n+q:
      cmp_bits(False{}, False{}, p, q)
    case False{} True{} 1n+p 1n+q:
      cmp_bits(False{}, True{}, p, q)
    case True{} False{} 1n+p 1n+q:
      cmp_bits(True{}, False{}, p, q)
    case True{} True{} 1n+p 1n+q:
      cmp_bits(True{}, True{}, p, q)

law word_nat_cmp:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  {Word.cmp(n, a, b) == Nat.cmp(Word.to_nat(n, a), Word.to_nat(n, b)) : Cmp}

def word_nat_cmp(n, a, b):
  match n a b:
    case 0n WNil{} WNil{}:
      {==}
    case 1n+k WCon{False{}, +s} WCon{False{}, +t}:
      %Equal.sym(Cmp, Word.cmp(k, s, t), Nat.cmp(Word.to_nat(k, s), Word.to_nat(k, t)), word_nat_cmp(k, s, t)) : {Word.cmp.fin(False{}, False{}, _) == Nat.cmp(Nat.double(Word.to_nat(k, s)), Nat.double(Word.to_nat(k, t))) : Cmp}
      Equal.sym(Cmp, Nat.cmp(word_value(False{}, Word.to_nat(k, s)), word_value(False{}, Word.to_nat(k, t))), Word.cmp.fin(False{}, False{}, Nat.cmp(Word.to_nat(k, s), Word.to_nat(k, t))), cmp_bits(False{}, False{}, Word.to_nat(k, s), Word.to_nat(k, t)))
    case 1n+k WCon{False{}, +s} WCon{True{}, +t}:
      %Equal.sym(Cmp, Word.cmp(k, s, t), Nat.cmp(Word.to_nat(k, s), Word.to_nat(k, t)), word_nat_cmp(k, s, t)) : {Word.cmp.fin(False{}, True{}, _) == Nat.cmp(Nat.double(Word.to_nat(k, s)), 1n+Nat.double(Word.to_nat(k, t))) : Cmp}
      Equal.sym(Cmp, Nat.cmp(word_value(False{}, Word.to_nat(k, s)), word_value(True{}, Word.to_nat(k, t))), Word.cmp.fin(False{}, True{}, Nat.cmp(Word.to_nat(k, s), Word.to_nat(k, t))), cmp_bits(False{}, True{}, Word.to_nat(k, s), Word.to_nat(k, t)))
    case 1n+k WCon{True{}, +s} WCon{False{}, +t}:
      %Equal.sym(Cmp, Word.cmp(k, s, t), Nat.cmp(Word.to_nat(k, s), Word.to_nat(k, t)), word_nat_cmp(k, s, t)) : {Word.cmp.fin(True{}, False{}, _) == Nat.cmp(1n+Nat.double(Word.to_nat(k, s)), Nat.double(Word.to_nat(k, t))) : Cmp}
      Equal.sym(Cmp, Nat.cmp(word_value(True{}, Word.to_nat(k, s)), word_value(False{}, Word.to_nat(k, t))), Word.cmp.fin(True{}, False{}, Nat.cmp(Word.to_nat(k, s), Word.to_nat(k, t))), cmp_bits(True{}, False{}, Word.to_nat(k, s), Word.to_nat(k, t)))
    case 1n+k WCon{True{}, +s} WCon{True{}, +t}:
      %Equal.sym(Cmp, Word.cmp(k, s, t), Nat.cmp(Word.to_nat(k, s), Word.to_nat(k, t)), word_nat_cmp(k, s, t)) : {Word.cmp.fin(True{}, True{}, _) == Nat.cmp(1n+Nat.double(Word.to_nat(k, s)), 1n+Nat.double(Word.to_nat(k, t))) : Cmp}
      Equal.sym(Cmp, Nat.cmp(word_value(True{}, Word.to_nat(k, s)), word_value(True{}, Word.to_nat(k, t))), Word.cmp.fin(True{}, True{}, Nat.cmp(Word.to_nat(k, s), Word.to_nat(k, t))), cmp_bits(True{}, True{}, Word.to_nat(k, s), Word.to_nat(k, t)))

law u32_nat_cmp:
  for +a: U32
  for +b: U32
  {U32.cmp(a, b) == Nat.cmp(U32.to_nat(a), U32.to_nat(b)) : Cmp}

def u32_nat_cmp(a, b):
  match a b:
    case U32{+x} U32{+y}:
      word_nat_cmp(32n, x, y)

law u32_nat_eq:
  for +a: U32
  for +b: U32
  {U32.is_eq(a, b) == Nat.is_eq(U32.to_nat(a), U32.to_nat(b)) : Bool}

def u32_nat_eq(a, b):
  Equal.cong(Cmp, Bool, c => Cmp.is_eq(c), U32.cmp(a, b), Nat.cmp(U32.to_nat(a), U32.to_nat(b)), u32_nat_cmp(a, b))

law u32_nat_le:
  for +a: U32
  for +b: U32
  {U32.is_le(a, b) == Nat.is_le(U32.to_nat(a), U32.to_nat(b)) : Bool}

def u32_nat_le(a, b):
  Equal.cong(Cmp, Bool, c => Cmp.is_le(c), U32.cmp(a, b), Nat.cmp(U32.to_nat(a), U32.to_nat(b)), u32_nat_cmp(a, b))

# Incrementing a word below some other word does not wrap.

def fin_true_lt(+b: Bool, +c: Cmp, lt: {Word.cmp.fin(True{}, b, c) == LT{} : Cmp}) -> {c == LT{} : Cmp}:
  match b c:
    case b LT{}:
      {==}
    case False{} EQ{}:
      gt_not_lt({EQ{} == LT{} : Cmp}, lt)
    case True{} EQ{}:
      eq_not_lt({EQ{} == LT{} : Cmp}, lt)
    case b GT{}:
      gt_not_lt({GT{} == LT{} : Cmp}, lt)

law word_inc_lt:
  for +n: Nat
  for +w: Word(n)
  for +v: Word(n)
  for lt: {Word.cmp(n, w, v) == LT{} : Cmp}
  {Word.to_nat(n, Word.inc(n, w)) == 1n+Word.to_nat(n, w) : Nat}

def word_inc_lt(n, w, v, lt):
  match n w v:
    case 0n WNil{} WNil{}:
      eq_not_lt({0n == 1n : Nat}, lt)
    case 1n+k WCon{False{}, +t} WCon{+b, +s}:
      {==}
    case 1n+k WCon{True{}, +t} WCon{+b, +s}:
      Equal.cong(Nat, Nat, x => Nat.double(x), Word.to_nat(k, Word.inc(k, t)), 1n+Word.to_nat(k, t), word_inc_lt(k, t, s, fin_true_lt(b, Word.cmp(k, t, s), lt)))

law u32_inc_lt:
  for +u: U32
  for +v: U32
  for lt: {U32.cmp(u, v) == LT{} : Cmp}
  {U32.to_nat(U32.inc(u)) == 1n+U32.to_nat(u) : Nat}

def u32_inc_lt(u, v, lt):
  match u v:
    case U32{+x} U32{+y}:
      word_inc_lt(32n, x, y, lt)

# A length that fits under some U32 converts without wrapping.
law from_nat_exact:
  for +k: Nat
  for +lim: U32
  for le: {Nat.is_le(k, U32.to_nat(lim)) == True{} : Bool}
  {U32.to_nat(U32.from_nat(k)) == k : Nat}

def from_nat_exact(k, lim, le):
  match k:
    case 0n:
      {==}
    case 1n+p:
      +le = le
      +back = from_nat_exact(p, lim, le_pred(p, U32.to_nat(lim), le))
      lt = Equal.trans(Cmp, U32.cmp(U32.from_nat(p), lim), Nat.cmp(U32.to_nat(U32.from_nat(p)), U32.to_nat(lim)), LT{},
        u32_nat_cmp(U32.from_nat(p), lim),
        %Equal.sym(Nat, U32.to_nat(U32.from_nat(p)), p, back) : {Nat.cmp(_, U32.to_nat(lim)) == LT{} : Cmp}
        succ_le_lt(p, U32.to_nat(lim), le))
      %back : {U32.to_nat(U32.inc(U32.from_nat(p))) == 1n+_ : Nat}
      u32_inc_lt(U32.from_nat(p), lim, lt)

# Subtraction with an incoming carry (True: no borrow) reads as numeric
# subtraction whenever the subtrahend, plus any borrow, fits under the minuend.
def sub_ok(c: Bool, o: Cmp) -> Bool:
  match c:
    case True{}:
      Cmp.is_le(o)
    case False{}:
      Cmp.is_lt(o)

def carry(pair: Bool & Bool) -> Bool:
  (s, k) = pair
  k

def sub_pre(+x: Bool, +y: Bool, +c: Bool, +o: Cmp, ok: {sub_ok(c, Word.cmp.fin(y, x, o)) == True{} : Bool}) ->
    {sub_ok(carry(Bool.full_add(x, Bool.not(y), c)), o) == True{} : Bool}:
  match x y c o:
    case False{} False{} False{} LT{}:
      {==}
    case False{} False{} False{} EQ{}:
      Bits.absurd({sub_ok(False{}, EQ{}) == True{} : Bool}, Bits.false_true(ok))
    case False{} False{} False{} GT{}:
      Bits.absurd({sub_ok(False{}, GT{}) == True{} : Bool}, Bits.false_true(ok))
    case False{} False{} True{} LT{}:
      {==}
    case False{} False{} True{} EQ{}:
      {==}
    case False{} False{} True{} GT{}:
      Bits.absurd({sub_ok(True{}, GT{}) == True{} : Bool}, Bits.false_true(ok))
    case False{} True{} False{} LT{}:
      {==}
    case False{} True{} False{} EQ{}:
      Bits.absurd({sub_ok(False{}, EQ{}) == True{} : Bool}, Bits.false_true(ok))
    case False{} True{} False{} GT{}:
      Bits.absurd({sub_ok(False{}, GT{}) == True{} : Bool}, Bits.false_true(ok))
    case False{} True{} True{} LT{}:
      {==}
    case False{} True{} True{} EQ{}:
      Bits.absurd({sub_ok(False{}, EQ{}) == True{} : Bool}, Bits.false_true(ok))
    case False{} True{} True{} GT{}:
      Bits.absurd({sub_ok(False{}, GT{}) == True{} : Bool}, Bits.false_true(ok))
    case True{} False{} False{} LT{}:
      {==}
    case True{} False{} False{} EQ{}:
      {==}
    case True{} False{} False{} GT{}:
      Bits.absurd({sub_ok(True{}, GT{}) == True{} : Bool}, Bits.false_true(ok))
    case True{} False{} True{} LT{}:
      {==}
    case True{} False{} True{} EQ{}:
      {==}
    case True{} False{} True{} GT{}:
      Bits.absurd({sub_ok(True{}, GT{}) == True{} : Bool}, Bits.false_true(ok))
    case True{} True{} False{} LT{}:
      {==}
    case True{} True{} False{} EQ{}:
      Bits.absurd({sub_ok(False{}, EQ{}) == True{} : Bool}, Bits.false_true(ok))
    case True{} True{} False{} GT{}:
      Bits.absurd({sub_ok(False{}, GT{}) == True{} : Bool}, Bits.false_true(ok))
    case True{} True{} True{} LT{}:
      {==}
    case True{} True{} True{} EQ{}:
      {==}
    case True{} True{} True{} GT{}:
      Bits.absurd({sub_ok(True{}, GT{}) == True{} : Bool}, Bits.false_true(ok))

law word_sub_nat:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  for +c: Bool
  for ok: {sub_ok(c, Word.cmp(n, b, a)) == True{} : Bool}
  {Nat.add(bit(Bool.not(c)), Nat.add(Word.to_nat(n, b), Word.to_nat(n, Word.adc(n, a, b, True{}, c)))) == Word.to_nat(n, a) : Nat}

def word_sub_nat(n, a, b, c, ok):
  match n a b c:
    case 0n WNil{} WNil{} True{}:
      {==}
    case 0n WNil{} WNil{} False{}:
      Bits.absurd({1n == 0n : Nat}, Bits.false_true(ok))
    case 1n+k WCon{False{}, +s} WCon{False{}, +t} False{}:
      %word_sub_nat(k, s, t, False{}, sub_pre(False{}, False{}, False{}, Word.cmp(k, t, s), ok)) : {Nat.add(bit(Bool.not(False{})), Nat.add(Word.to_nat(1n+k, WCon{False{}, t}), Word.to_nat(1n+k, WCon{True{}, Word.adc(k, s, t, True{}, False{})}))) == Nat.double(_) : Nat}
      %double_add_odd(Word.to_nat(k, t), Word.to_nat(k, Word.adc(k, s, t, True{}, False{}))) : {1n+Nat.add(Nat.double(Word.to_nat(k, t)), 1n+Nat.double(Word.to_nat(k, Word.adc(k, s, t, True{}, False{})))) == 1n+_ : Nat}
      {==}
    case 1n+k WCon{False{}, +s} WCon{False{}, +t} True{}:
      %word_sub_nat(k, s, t, True{}, sub_pre(False{}, False{}, True{}, Word.cmp(k, t, s), ok)) : {Nat.add(bit(Bool.not(True{})), Nat.add(Word.to_nat(1n+k, WCon{False{}, t}), Word.to_nat(1n+k, WCon{False{}, Word.adc(k, s, t, True{}, True{})}))) == Nat.double(_) : Nat}
      %double_add(Word.to_nat(k, t), Word.to_nat(k, Word.adc(k, s, t, True{}, True{}))) : {Nat.add(Nat.double(Word.to_nat(k, t)), Nat.double(Word.to_nat(k, Word.adc(k, s, t, True{}, True{})))) == _ : Nat}
      {==}
    case 1n+k WCon{False{}, +s} WCon{True{}, +t} False{}:
      %word_sub_nat(k, s, t, False{}, sub_pre(False{}, True{}, False{}, Word.cmp(k, t, s), ok)) : {Nat.add(bit(Bool.not(False{})), Nat.add(Word.to_nat(1n+k, WCon{True{}, t}), Word.to_nat(1n+k, WCon{False{}, Word.adc(k, s, t, True{}, False{})}))) == Nat.double(_) : Nat}
      %double_add(Word.to_nat(k, t), Word.to_nat(k, Word.adc(k, s, t, True{}, False{}))) : {2n+Nat.add(Nat.double(Word.to_nat(k, t)), Nat.double(Word.to_nat(k, Word.adc(k, s, t, True{}, False{})))) == 2n+_ : Nat}
      {==}
    case 1n+k WCon{False{}, +s} WCon{True{}, +t} True{}:
      %word_sub_nat(k, s, t, False{}, sub_pre(False{}, True{}, True{}, Word.cmp(k, t, s), ok)) : {Nat.add(bit(Bool.not(True{})), Nat.add(Word.to_nat(1n+k, WCon{True{}, t}), Word.to_nat(1n+k, WCon{True{}, Word.adc(k, s, t, True{}, False{})}))) == Nat.double(_) : Nat}
      %double_add_odd(Word.to_nat(k, t), Word.to_nat(k, Word.adc(k, s, t, True{}, False{}))) : {1n+Nat.add(Nat.double(Word.to_nat(k, t)), 1n+Nat.double(Word.to_nat(k, Word.adc(k, s, t, True{}, False{})))) == 1n+_ : Nat}
      {==}
    case 1n+k WCon{True{}, +s} WCon{False{}, +t} False{}:
      %word_sub_nat(k, s, t, True{}, sub_pre(True{}, False{}, False{}, Word.cmp(k, t, s), ok)) : {Nat.add(bit(Bool.not(False{})), Nat.add(Word.to_nat(1n+k, WCon{False{}, t}), Word.to_nat(1n+k, WCon{False{}, Word.adc(k, s, t, True{}, True{})}))) == 1n+Nat.double(_) : Nat}
      %double_add(Word.to_nat(k, t), Word.to_nat(k, Word.adc(k, s, t, True{}, True{}))) : {1n+Nat.add(Nat.double(Word.to_nat(k, t)), Nat.double(Word.to_nat(k, Word.adc(k, s, t, True{}, True{})))) == 1n+_ : Nat}
      {==}
    case 1n+k WCon{True{}, +s} WCon{False{}, +t} True{}:
      %word_sub_nat(k, s, t, True{}, sub_pre(True{}, False{}, True{}, Word.cmp(k, t, s), ok)) : {Nat.add(bit(Bool.not(True{})), Nat.add(Word.to_nat(1n+k, WCon{False{}, t}), Word.to_nat(1n+k, WCon{True{}, Word.adc(k, s, t, True{}, True{})}))) == 1n+Nat.double(_) : Nat}
      %double_add_odd(Word.to_nat(k, t), Word.to_nat(k, Word.adc(k, s, t, True{}, True{}))) : {Nat.add(Nat.double(Word.to_nat(k, t)), 1n+Nat.double(Word.to_nat(k, Word.adc(k, s, t, True{}, True{})))) == _ : Nat}
      {==}
    case 1n+k WCon{True{}, +s} WCon{True{}, +t} False{}:
      %word_sub_nat(k, s, t, False{}, sub_pre(True{}, True{}, False{}, Word.cmp(k, t, s), ok)) : {Nat.add(bit(Bool.not(False{})), Nat.add(Word.to_nat(1n+k, WCon{True{}, t}), Word.to_nat(1n+k, WCon{True{}, Word.adc(k, s, t, True{}, False{})}))) == 1n+Nat.double(_) : Nat}
      %double_add_odd(Word.to_nat(k, t), Word.to_nat(k, Word.adc(k, s, t, True{}, False{}))) : {2n+Nat.add(Nat.double(Word.to_nat(k, t)), 1n+Nat.double(Word.to_nat(k, Word.adc(k, s, t, True{}, False{})))) == 2n+_ : Nat}
      {==}
    case 1n+k WCon{True{}, +s} WCon{True{}, +t} True{}:
      %word_sub_nat(k, s, t, True{}, sub_pre(True{}, True{}, True{}, Word.cmp(k, t, s), ok)) : {Nat.add(bit(Bool.not(True{})), Nat.add(Word.to_nat(1n+k, WCon{True{}, t}), Word.to_nat(1n+k, WCon{False{}, Word.adc(k, s, t, True{}, True{})}))) == 1n+Nat.double(_) : Nat}
      %double_add(Word.to_nat(k, t), Word.to_nat(k, Word.adc(k, s, t, True{}, True{}))) : {1n+Nat.add(Nat.double(Word.to_nat(k, t)), Nat.double(Word.to_nat(k, Word.adc(k, s, t, True{}, True{})))) == 1n+_ : Nat}
      {==}

law u32_sub_nat:
  for +a: U32
  for +b: U32
  for le: {U32.is_le(b, a) == True{} : Bool}
  {Nat.add(U32.to_nat(b), U32.to_nat((a - b : U32))) == U32.to_nat(a) : Nat}

def u32_sub_nat(a, b, le):
  match a b:
    case U32{+x} U32{+y}:
      word_sub_nat(32n, x, y, True{}, le)
