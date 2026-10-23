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
