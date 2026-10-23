# Little-endian bit packing for UTF-8 payloads.
import Base

def cat(n: Nat, -m: Nat, a: Word(n), b: Word(m)) -> Word(Nat.add(n, m)):
  match n a:
    case 0n WNil{}:
      b
    case 1n+k WCon{h, t}:
      WCon{h, cat(k, m, t, b)}

def split_con(-n: Nat, -m: Nat, h: Bool, parts: Word(n) & Word(m)) -> Word(1n+n) & Word(m):
  (lo, hi) = parts
  (WCon{h, lo}, hi)

def split(n: Nat, -m: Nat, w: Word(Nat.add(n, m))) -> Word(n) & Word(m):
  match n:
    case 0n:
      (WNil{}, w)
    case 1n+k:
      WCon{h, t} = w
      split_con(k, m, h, split(k, m, t))

def pad(n: Nat, m: Nat, w: Word(n)) -> Word(Nat.add(n, m)):
  cat(n, m, w, Word.zero(m))

law split_cat:
  for +n: Nat
  for +m: Nat
  for +a: Word(n)
  for +b: Word(m)
  {split(n, m, cat(n, m, a, b)) == (a, b) : Word(n) & Word(m)}

def split_cat(n, m, a, b):
  match n a:
    case 0n WNil{}:
      {==}
    case 1n+k WCon{+h, +t}:
      %Equal.sym(Word(k) & Word(m), split(k, m, cat(k, m, t, b)), (t, b), split_cat(k, m, t, b)) : {split_con(k, m, h, _) == (WCon{h, t}, b) : Word(1n+k) & Word(m)}
      {==}

def rejoin(+n: Nat, +m: Nat, parts: Word(n) & Word(m)) -> Word(Nat.add(n, m)):
  (lo, hi) = parts
  cat(n, m, lo, hi)

def rejoin_con(+n: Nat, +m: Nat, +h: Bool, parts: Word(n) & Word(m)) ->
    {rejoin(1n+n, m, split_con(n, m, h, parts)) == WCon{h, rejoin(n, m, parts)} : Word(Nat.add(1n+n, m))}:
  match parts:
    case (lo, hi):
      {==}

law cat_split:
  for +n: Nat
  for +m: Nat
  for +w: Word(Nat.add(n, m))
  {rejoin(n, m, split(n, m, w)) == w : Word(Nat.add(n, m))}

def cat_split(n, m, w):
  match n:
    case 0n:
      {==}
    case 1n+k:
      WCon{+h, +t} = w
      %Equal.sym(Word(Nat.add(1n+k, m)), rejoin(1n+k, m, split_con(k, m, h, split(k, m, t))), WCon{h, rejoin(k, m, split(k, m, t))}, rejoin_con(k, m, h, split(k, m, t))) : {_ == WCon{h, t} : Word(Nat.add(1n+k, m))}
      Equal.cong(Word(Nat.add(k, m)), Word(Nat.add(1n+k, m)), x => WCon{h, x}, rejoin(k, m, split(k, m, t)), t, cat_split(k, m, t))

def zeros(n: Nat, w: Word(n)) -> Bool:
  match n w:
    case 0n WNil{}:
      True{}
    case 1n+k WCon{False{}, t}:
      zeros(k, t)
    case 1n+k WCon{True{}, t}:
      False{}

def true_type(b: Bool) -> Type:
  match b:
    case True{}:
      Unit
    case False{}:
      Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %Equal.sym(Bool, False{}, True{}, e) : true_type(_)
  Unit{}

def absurd(-A: Type, impossible: Empty) -> A:
  match impossible:

law zeros_sound:
  for +n: Nat
  for +w: Word(n)
  for yes: {zeros(n, w) == True{} : Bool}
  {w == Word.zero(n) : Word(n)}

def zeros_sound(n, w, yes):
  match n w:
    case 0n WNil{}:
      {==}
    case 1n+k WCon{False{}, +t}:
      Equal.cong(Word(k), Word(1n+k), x => WCon{False{}, x}, t, Word.zero(k), zeros_sound(k, t, yes))
    case 1n+k WCon{True{}, t}:
      absurd({WCon{True{}, t} == Word.zero(1n+k) : Word(1n+k)}, false_true(yes))

# A nonzero high word makes an unsigned comparison strictly greater, regardless
# of the low payload bits.
law cmp_nonzero:
  for +n: Nat
  for +w: Word(n)
  for no: {zeros(n, w) == False{} : Bool}
  {Word.cmp(n, w, Word.zero(n)) == GT{} : Cmp}

def true_false(e: {True{} == False{} : Bool}) -> Empty:
  false_true(Equal.sym(Bool, True{}, False{}, e))

def cmp_true_tail(+c: Cmp, no_lt: {Cmp.is_lt(c) == False{} : Bool}) ->
    {Word.cmp.fin(True{}, False{}, c) == GT{} : Cmp}:
  match c:
    case LT{}:
      absurd({LT{} == GT{} : Cmp}, true_false(no_lt))
    case EQ{}:
      {==}
    case GT{}:
      {==}

def cmp_no_lt_fin(+a: Bool, +c: Cmp, no_lt: {Cmp.is_lt(c) == False{} : Bool}) ->
    {Cmp.is_lt(Word.cmp.fin(a, False{}, c)) == False{} : Bool}:
  match a c:
    case b LT{}:
      absurd({Cmp.is_lt(Word.cmp.fin(b, False{}, LT{})) == False{} : Bool}, true_false(no_lt))
    case False{} EQ{}:
      {==}
    case True{} EQ{}:
      {==}
    case b GT{}:
      {==}

law cmp_zero_not_lt:
  for +n: Nat
  for +w: Word(n)
  {Cmp.is_lt(Word.cmp(n, w, Word.zero(n))) == False{} : Bool}

def cmp_zero_not_lt(n, w):
  match n w:
    case 0n WNil{}:
      {==}
    case 1n+k WCon{+h, +t}:
      cmp_no_lt_fin(h, Word.cmp(k, t, Word.zero(k)), cmp_zero_not_lt(k, t))

def cmp_nonzero(n, w, no):
  match n w:
    case 0n WNil{}:
      absurd({EQ{} == GT{} : Cmp}, true_false(no))
    case 1n+k WCon{False{}, +t}:
      %Equal.sym(Cmp, Word.cmp(k, t, Word.zero(k)), GT{}, cmp_nonzero(k, t, no)) : {Word.cmp.fin(False{}, False{}, _) == GT{} : Cmp}
      {==}
    case 1n+k WCon{True{}, +t}:
      cmp_true_tail(Word.cmp(k, t, Word.zero(k)), cmp_zero_not_lt(k, t))

law cmp_high_gt:
  for +n: Nat
  for +m: Nat
  for +lo: Word(n)
  for +bound: Word(n)
  for +hi: Word(m)
  for greater: {Word.cmp(m, hi, Word.zero(m)) == GT{} : Cmp}
  {Word.cmp(Nat.add(n, m), cat(n, m, lo, hi), cat(n, m, bound, Word.zero(m))) == GT{} : Cmp}

def cmp_high_gt(n, m, lo, bound, hi, greater):
  match n lo bound:
    case 0n WNil{} WNil{}:
      greater
    case 1n+k WCon{+h, +t} WCon{+bh, +bt}:
      %Equal.sym(Cmp, Word.cmp(Nat.add(k, m), cat(k, m, t, hi), cat(k, m, bt, Word.zero(m))), GT{}, cmp_high_gt(k, m, t, bt, hi, greater)) : {Word.cmp.fin(h, bh, _) == GT{} : Cmp}
      {==}
