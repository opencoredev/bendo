# Generic Nat facts for the HTTP date proofs. Every lemma is stated over
# variables, so a large constant such as 146097n is only ever substituted,
# never computed: Bend's checkers expand closed Nats in unary.
import Base

def true_type(b: Bool) -> Type:
  match b:
    case True{}:
      Unit
    case False{}:
      Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %Equal.sym(Bool, False{}, True{}, e) : true_type(_)
  Unit{}

def true_false(e: {True{} == False{} : Bool}) -> Empty:
  false_true(Equal.sym(Bool, True{}, False{}, e))

def absurd(-A: Type, impossible: Empty) -> A:
  match impossible:

# Addition and multiplication.

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

law add_comm:
  for +a: Nat
  for +b: Nat
  {Nat.add(a, b) == Nat.add(b, a) : Nat}

def add_comm(a, b):
  match a:
    case 0n:
      Equal.sym(Nat, Nat.add(b, 0n), b, add_zero_r(b))
    case 1n+p:
      %Equal.sym(Nat, Nat.add(p, b), Nat.add(b, p), add_comm(p, b)) : {1n+_ == Nat.add(b, 1n+p) : Nat}
      Equal.sym(Nat, Nat.add(b, 1n+p), 1n+Nat.add(b, p), add_succ_r(b, p))

law add_assoc:
  for +a: Nat
  for +b: Nat
  for +c: Nat
  {Nat.add(Nat.add(a, b), c) == Nat.add(a, Nat.add(b, c)) : Nat}

def add_assoc(a, b, c):
  match a:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(Nat.add(p, b), c), Nat.add(p, Nat.add(b, c)), add_assoc(p, b, c))

law mul_zero_r:
  for +a: Nat
  {Nat.mul(a, 0n) == 0n : Nat}

def mul_zero_r(a):
  match a:
    case 0n:
      {==}
    case 1n+p:
      mul_zero_r(p)

law mul_distrib_r:
  for +a: Nat
  for +b: Nat
  for +k: Nat
  {Nat.mul(Nat.add(a, b), k) == Nat.add(Nat.mul(a, k), Nat.mul(b, k)) : Nat}

def mul_distrib_r(a, b, k):
  match a:
    case 0n:
      {==}
    case 1n+p:
      %Equal.sym(Nat, Nat.mul(Nat.add(p, b), k), Nat.add(Nat.mul(p, k), Nat.mul(b, k)), mul_distrib_r(p, b, k)) : {Nat.add(k, _) == Nat.add(Nat.add(k, Nat.mul(p, k)), Nat.mul(b, k)) : Nat}
      Equal.sym(Nat, Nat.add(Nat.add(k, Nat.mul(p, k)), Nat.mul(b, k)), Nat.add(k, Nat.add(Nat.mul(p, k), Nat.mul(b, k))), add_assoc(k, Nat.mul(p, k), Nat.mul(b, k)))

law mul_assoc:
  for +a: Nat
  for +b: Nat
  for +c: Nat
  {Nat.mul(Nat.mul(a, b), c) == Nat.mul(a, Nat.mul(b, c)) : Nat}

def mul_assoc(a, b, c):
  match a:
    case 0n:
      {==}
    case 1n+p:
      %Equal.sym(Nat, Nat.mul(Nat.add(b, Nat.mul(p, b)), c), Nat.add(Nat.mul(b, c), Nat.mul(Nat.mul(p, b), c)), mul_distrib_r(b, Nat.mul(p, b), c)) : {_ == Nat.add(Nat.mul(b, c), Nat.mul(p, Nat.mul(b, c))) : Nat}
      Equal.cong(Nat, Nat, x => Nat.add(Nat.mul(b, c), x), Nat.mul(Nat.mul(p, b), c), Nat.mul(p, Nat.mul(b, c)), mul_assoc(p, b, c))

law sub_add_cancel:
  for +k: Nat
  for +x: Nat
  {Nat.sub(Nat.add(k, x), k) == x : Nat}

def sub_add_cancel(k, x):
  match k:
    case 0n:
      match x:
        case 0n:
          {==}
        case 1n+p:
          {==}
    case 1n+p:
      sub_add_cancel(p, x)

# Order.

law le_refl:
  for +a: Nat
  {Nat.is_le(a, a) == True{} : Bool}

def le_refl(a):
  match a:
    case 0n:
      {==}
    case 1n+p:
      le_refl(p)

law zero_le:
  for +b: Nat
  {Nat.is_le(0n, b) == True{} : Bool}

def zero_le(b):
  match b:
    case 0n:
      {==}
    case 1n+p:
      {==}

def not_lt_one(+p: Nat, lt: {Nat.is_lt(1n+p, 1n) == True{} : Bool}) -> Empty:
  match p:
    case 0n:
      false_true(lt)
    case 1n+q:
      false_true(lt)

def lt_zero(+r: Nat, lt: {Nat.is_lt(r, 0n) == True{} : Bool}) -> Empty:
  match r:
    case 0n:
      false_true(lt)
    case 1n+p:
      false_true(lt)

law le_of_lt_succ:
  for +a: Nat
  for +b: Nat
  for lt: {Nat.is_lt(a, 1n+b) == True{} : Bool}
  {Nat.is_le(a, b) == True{} : Bool}

def le_of_lt_succ(a, b, lt):
  match a b:
    case 0n b:
      zero_le(b)
    case 1n+p 0n:
      absurd({Nat.is_le(1n+p, 0n) == True{} : Bool}, not_lt_one(p, lt))
    case 1n+p 1n+q:
      le_of_lt_succ(p, q, lt)

law lt_succ_of_le:
  for +a: Nat
  for +b: Nat
  for le: {Nat.is_le(a, b) == True{} : Bool}
  {Nat.is_lt(a, 1n+b) == True{} : Bool}

def lt_succ_of_le(a, b, le):
  match a b:
    case 0n b:
      {==}
    case 1n+p 0n:
      absurd({Nat.is_lt(1n+p, 1n) == True{} : Bool}, false_true(le))
    case 1n+p 1n+q:
      lt_succ_of_le(p, q, le)

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
      absurd({Nat.is_le(1n+p, 1n) == True{} : Bool}, false_true(le))
    case 1n+p 1n+q:
      le_succ_r(p, q, le)

law le_add_l:
  for +x: Nat
  for +y: Nat
  {Nat.is_le(x, Nat.add(y, x)) == True{} : Bool}

def le_add_l(x, y):
  match y:
    case 0n:
      le_refl(x)
    case 1n+q:
      le_succ_r(x, Nat.add(q, x), le_add_l(x, q))

law carry_shift:
  for +k: Nat
  for +m: Nat
  for +n: Nat
  {1n+Nat.add(Nat.add(k, m), n) == Nat.add(m, Nat.add(k, 1n+n)) : Nat}

def carry_shift(k, m, n):
  %Equal.sym(Nat, Nat.add(k, 1n+n), 1n+Nat.add(k, n), add_succ_r(k, n)) : {1n+Nat.add(Nat.add(k, m), n) == Nat.add(m, _) : Nat}
  %Equal.sym(Nat, Nat.add(m, 1n+Nat.add(k, n)), 1n+Nat.add(m, Nat.add(k, n)), add_succ_r(m, Nat.add(k, n))) : {1n+Nat.add(Nat.add(k, m), n) == _ : Nat}
  %Equal.sym(Nat, Nat.add(k, m), Nat.add(m, k), add_comm(k, m)) : {1n+Nat.add(_, n) == 1n+Nat.add(m, Nat.add(k, n)) : Nat}
  Equal.cong(Nat, Nat, x => 1n+x, Nat.add(Nat.add(m, k), n), Nat.add(m, Nat.add(k, n)), add_assoc(m, k, n))

# Base's division loop: divmod.go(n, m, d, r) reads n more units, with m
# units left before the quotient d next increases.

law go_value:
  for +n: Nat
  for +m: Nat
  for +d: Nat
  for +r: Nat
  for +kp: Nat
  for +inv: {Nat.add(m, r) == kp : Nat}
  {Nat.add(Nat.mul(Pair.fst(Nat, Nat, Nat.divmod.go(n, m, d, r)), 1n+kp), Pair.snd(Nat, Nat, Nat.divmod.go(n, m, d, r))) == Nat.add(Nat.mul(d, 1n+kp), Nat.add(r, n)) : Nat}

def go_value(n, m, d, r, kp, inv):
  match n m:
    case 0n m:
      Equal.sym(Nat, Nat.add(Nat.mul(d, 1n+kp), Nat.add(r, 0n)), Nat.add(Nat.mul(d, 1n+kp), r), Equal.cong(Nat, Nat, x => Nat.add(Nat.mul(d, 1n+kp), x), Nat.add(r, 0n), r, add_zero_r(r)))
    case 1n+np 0n:
      +ih = go_value(np, r, 1n+d, 0n, kp, Equal.trans(Nat, Nat.add(r, 0n), r, kp, add_zero_r(r), inv))
      %Equal.sym(Nat, r, kp, inv) : {Nat.add(Nat.mul(Pair.fst(Nat, Nat, Nat.divmod.go(np, r, 1n+d, 0n)), 1n+kp), Pair.snd(Nat, Nat, Nat.divmod.go(np, r, 1n+d, 0n))) == Nat.add(Nat.mul(d, 1n+kp), Nat.add(_, 1n+np)) : Nat}
      Equal.trans(Nat, Nat.add(Nat.mul(Pair.fst(Nat, Nat, Nat.divmod.go(np, r, 1n+d, 0n)), 1n+kp), Pair.snd(Nat, Nat, Nat.divmod.go(np, r, 1n+d, 0n))), 1n+Nat.add(Nat.add(kp, Nat.mul(d, 1n+kp)), np), Nat.add(Nat.mul(d, 1n+kp), Nat.add(kp, 1n+np)), ih, carry_shift(kp, Nat.mul(d, 1n+kp), np))
    case 1n+np 1n+mp:
      +ih = go_value(np, mp, d, 1n+r, kp, Equal.trans(Nat, Nat.add(mp, 1n+r), 1n+Nat.add(mp, r), kp, add_succ_r(mp, r), inv))
      %Equal.sym(Nat, Nat.add(r, 1n+np), 1n+Nat.add(r, np), add_succ_r(r, np)) : {Nat.add(Nat.mul(Pair.fst(Nat, Nat, Nat.divmod.go(np, mp, d, 1n+r)), 1n+kp), Pair.snd(Nat, Nat, Nat.divmod.go(np, mp, d, 1n+r))) == Nat.add(Nat.mul(d, 1n+kp), _) : Nat}
      ih

law go_bound:
  for +n: Nat
  for +m: Nat
  for +d: Nat
  for +r: Nat
  for +kp: Nat
  for +inv: {Nat.add(m, r) == kp : Nat}
  {Nat.is_lt(Pair.snd(Nat, Nat, Nat.divmod.go(n, m, d, r)), 1n+kp) == True{} : Bool}

def go_bound(n, m, d, r, kp, inv):
  match n m:
    case 0n m:
      %inv : {Nat.is_lt(r, 1n+_) == True{} : Bool}
      lt_succ_of_le(r, Nat.add(m, r), le_add_l(r, m))
    case 1n+np 0n:
      go_bound(np, r, 1n+d, 0n, kp, Equal.trans(Nat, Nat.add(r, 0n), r, kp, add_zero_r(r), inv))
    case 1n+np 1n+mp:
      go_bound(np, mp, d, 1n+r, kp, Equal.trans(Nat, Nat.add(mp, 1n+r), 1n+Nat.add(mp, r), kp, add_succ_r(mp, r), inv))

law div_mod_id:
  for +a: Nat
  for +k: Nat
  for pos: {Nat.is_lt(0n, k) == True{} : Bool}
  {Nat.add(Nat.mul(Nat.div(a, k), k), Nat.mod(a, k)) == a : Nat}

def div_mod_id(a, k, pos):
  match k:
    case 0n:
      absurd({Nat.add(Nat.mul(Nat.div(a, 0n), 0n), Nat.mod(a, 0n)) == a : Nat}, false_true(pos))
    case 1n+kp:
      go_value(a, kp, 0n, 0n, kp, add_zero_r(kp))

law mod_lt:
  for +a: Nat
  for +k: Nat
  for pos: {Nat.is_lt(0n, k) == True{} : Bool}
  {Nat.is_lt(Nat.mod(a, k), k) == True{} : Bool}

def mod_lt(a, k, pos):
  match k:
    case 0n:
      absurd({Nat.is_lt(Nat.mod(a, 0n), 0n) == True{} : Bool}, false_true(pos))
    case 1n+kp:
      go_bound(a, kp, 0n, 0n, kp, add_zero_r(kp))

law go_full:
  for +m: Nat
  for +x: Nat
  for +d: Nat
  for +r: Nat
  {Nat.divmod.go(Nat.add(1n+m, x), m, d, r) == Nat.divmod.go(x, Nat.add(m, r), 1n+d, 0n) : Nat & Nat}

def go_full(m, x, d, r):
  match m:
    case 0n:
      {==}
    case 1n+mp:
      %add_succ_r(mp, r) : {Nat.divmod.go(Nat.add(1n+mp, x), mp, d, 1n+r) == Nat.divmod.go(x, _, 1n+d, 0n) : Nat & Nat}
      go_full(mp, x, d, 1n+r)

law go_part:
  for +n: Nat
  for +m: Nat
  for +d: Nat
  for +r: Nat
  for le: {Nat.is_le(n, m) == True{} : Bool}
  {Nat.divmod.go(n, m, d, r) == (d, Nat.add(n, r)) : Nat & Nat}

def go_part(n, m, d, r, le):
  match n m:
    case 0n m:
      {==}
    case 1n+np 0n:
      absurd({Nat.divmod.go(1n+np, 0n, d, r) == (d, Nat.add(1n+np, r)) : Nat & Nat}, false_true(le))
    case 1n+np 1n+mp:
      %add_succ_r(np, r) : {Nat.divmod.go(np, mp, d, 1n+r) == (d, _) : Nat & Nat}
      go_part(np, mp, d, 1n+r, le)

law go_blocks:
  for +q: Nat
  for +kp: Nat
  for +r: Nat
  for +d: Nat
  for +le: {Nat.is_le(r, kp) == True{} : Bool}
  {Nat.divmod.go(Nat.add(Nat.mul(q, 1n+kp), r), kp, d, 0n) == (Nat.add(q, d), r) : Nat & Nat}

def go_blocks(q, kp, r, d, le):
  match q:
    case 0n:
      %add_zero_r(r) : {Nat.divmod.go(r, kp, d, 0n) == (d, _) : Nat & Nat}
      go_part(r, kp, d, 0n, le)
    case 1n+qp:
      %Equal.sym(Nat, Nat.add(Nat.add(1n+kp, Nat.mul(qp, 1n+kp)), r), Nat.add(1n+kp, Nat.add(Nat.mul(qp, 1n+kp), r)), add_assoc(1n+kp, Nat.mul(qp, 1n+kp), r)) : {Nat.divmod.go(_, kp, d, 0n) == (1n+Nat.add(qp, d), r) : Nat & Nat}
      %Equal.sym(Nat & Nat, Nat.divmod.go(Nat.add(1n+kp, Nat.add(Nat.mul(qp, 1n+kp), r)), kp, d, 0n), Nat.divmod.go(Nat.add(Nat.mul(qp, 1n+kp), r), Nat.add(kp, 0n), 1n+d, 0n), go_full(kp, Nat.add(Nat.mul(qp, 1n+kp), r), d, 0n)) : {_ == (1n+Nat.add(qp, d), r) : Nat & Nat}
      %Equal.sym(Nat, Nat.add(kp, 0n), kp, add_zero_r(kp)) : {Nat.divmod.go(Nat.add(Nat.mul(qp, 1n+kp), r), _, 1n+d, 0n) == (1n+Nat.add(qp, d), r) : Nat & Nat}
      %add_succ_r(qp, d) : {Nat.divmod.go(Nat.add(Nat.mul(qp, 1n+kp), r), kp, 1n+d, 0n) == (_, r) : Nat & Nat}
      go_blocks(qp, kp, r, 1n+d, le)

law dm_unique:
  for +q: Nat
  for +r: Nat
  for +k: Nat
  for lt: {Nat.is_lt(r, k) == True{} : Bool}
  {Nat.divmod(Nat.add(Nat.mul(q, k), r), k) == (q, r) : Nat & Nat}

def dm_unique(q, r, k, lt):
  match k:
    case 0n:
      absurd({Nat.divmod(Nat.add(Nat.mul(q, 0n), r), 0n) == (q, r) : Nat & Nat}, lt_zero(r, lt))
    case 1n+kp:
      %add_zero_r(q) : {Nat.divmod.go(Nat.add(Nat.mul(q, 1n+kp), r), kp, 0n, 0n) == (_, r) : Nat & Nat}
      go_blocks(q, kp, r, 0n, le_of_lt_succ(r, kp, lt))

law div_unique:
  for +q: Nat
  for +r: Nat
  for +k: Nat
  for lt: {Nat.is_lt(r, k) == True{} : Bool}
  {Nat.div(Nat.add(Nat.mul(q, k), r), k) == q : Nat}

def div_unique(q, r, k, lt):
  Equal.cong(Nat & Nat, Nat, p => Pair.fst(Nat, Nat, p), Nat.divmod(Nat.add(Nat.mul(q, k), r), k), (q, r), dm_unique(q, r, k, lt))

law mod_unique:
  for +q: Nat
  for +r: Nat
  for +k: Nat
  for lt: {Nat.is_lt(r, k) == True{} : Bool}
  {Nat.mod(Nat.add(Nat.mul(q, k), r), k) == r : Nat}

def mod_unique(q, r, k, lt):
  Equal.cong(Nat & Nat, Nat, p => Pair.snd(Nat, Nat, p), Nat.divmod(Nat.add(Nat.mul(q, k), r), k), (q, r), dm_unique(q, r, k, lt))

# More order facts.

law not_lt_add:
  for +l: Nat
  for +y: Nat
  {Nat.is_lt(Nat.add(l, y), l) == False{} : Bool}

def not_lt_add(l, y):
  match l:
    case 0n:
      match y:
        case 0n:
          {==}
        case 1n+p:
          {==}
    case 1n+p:
      not_lt_add(p, y)

law sub_zero_r:
  for +a: Nat
  {Nat.sub(a, 0n) == a : Nat}

def sub_zero_r(a):
  match a:
    case 0n:
      {==}
    case 1n+p:
      {==}

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

law lt_add_mono:
  for +k: Nat
  for +x: Nat
  for +y: Nat
  for lt: {Nat.is_lt(x, y) == True{} : Bool}
  {Nat.is_lt(Nat.add(k, x), Nat.add(k, y)) == True{} : Bool}

def lt_add_mono(k, x, y, lt):
  %Equal.sym(Cmp, Nat.cmp(Nat.add(k, x), Nat.add(k, y)), Nat.cmp(x, y), cmp_add_cancel(k, x, y)) : {Cmp.is_lt(_) == True{} : Bool}
  lt

law le_add_mono:
  for +k: Nat
  for +x: Nat
  for +y: Nat
  for le: {Nat.is_le(x, y) == True{} : Bool}
  {Nat.is_le(Nat.add(k, x), Nat.add(k, y)) == True{} : Bool}

def le_add_mono(k, x, y, le):
  %Equal.sym(Cmp, Nat.cmp(Nat.add(k, x), Nat.add(k, y)), Nat.cmp(x, y), cmp_add_cancel(k, x, y)) : {Cmp.is_le(_) == True{} : Bool}
  le

def lt_zero_any(+a: Nat, -c: Nat, ab: {Nat.is_lt(a, 0n) == True{} : Bool}) -> {Nat.is_lt(a, c) == True{} : Bool}:
  absurd({Nat.is_lt(a, c) == True{} : Bool}, lt_zero(a, ab))

law lt_le_trans:
  for +a: Nat
  for +b: Nat
  for +c: Nat
  for ab: {Nat.is_lt(a, b) == True{} : Bool}
  for bc: {Nat.is_le(b, c) == True{} : Bool}
  {Nat.is_lt(a, c) == True{} : Bool}

def lt_le_trans(a, b, c, ab, bc):
  match a b c:
    case a 0n c:
      lt_zero_any(a, c, ab)
    case 0n 1n+q 0n:
      absurd({Nat.is_lt(0n, 0n) == True{} : Bool}, false_true(bc))
    case 0n 1n+q 1n+s:
      {==}
    case 1n+p 1n+q 0n:
      absurd({Nat.is_lt(1n+p, 0n) == True{} : Bool}, false_true(bc))
    case 1n+p 1n+q 1n+s:
      lt_le_trans(p, q, s, ab, bc)

law le_trans:
  for +a: Nat
  for +b: Nat
  for +c: Nat
  for ab: {Nat.is_le(a, b) == True{} : Bool}
  for bc: {Nat.is_le(b, c) == True{} : Bool}
  {Nat.is_le(a, c) == True{} : Bool}

def le_trans(a, b, c, ab, bc):
  match a b c:
    case 0n b c:
      zero_le(c)
    case 1n+p 0n c:
      absurd({Nat.is_le(1n+p, c) == True{} : Bool}, false_true(ab))
    case 1n+p 1n+q 0n:
      absurd({Nat.is_le(1n+p, 0n) == True{} : Bool}, false_true(bc))
    case 1n+p 1n+q 1n+s:
      le_trans(p, q, s, ab, bc)

law lt_add_r:
  for +r: Nat
  for +l: Nat
  for +x: Nat
  for lt: {Nat.is_lt(r, l) == True{} : Bool}
  {Nat.is_lt(r, Nat.add(l, x)) == True{} : Bool}

def lt_add_r(r, l, x, lt):
  match r l:
    case r 0n:
      absurd({Nat.is_lt(r, x) == True{} : Bool}, lt_zero(r, lt))
    case 0n 1n+q:
      {==}
    case 1n+p 1n+q:
      lt_add_r(p, q, x, lt)

law mod_add_mul:
  for +t: Nat
  for +x: Nat
  for +k: Nat
  for +pos: {Nat.is_lt(0n, k) == True{} : Bool}
  {Nat.mod(Nat.add(Nat.mul(t, k), x), k) == Nat.mod(x, k) : Nat}

def mod_add_mul(t, x, k, pos):
  +dx = Nat.div(x, k)
  +mx = Nat.mod(x, k)
  %div_mod_id(x, k, pos) : {Nat.mod(Nat.add(Nat.mul(t, k), _), k) == mx : Nat}
  %add_assoc(Nat.mul(t, k), Nat.mul(dx, k), mx) : {Nat.mod(_, k) == mx : Nat}
  %mul_distrib_r(t, dx, k) : {Nat.mod(Nat.add(_, mx), k) == mx : Nat}
  mod_unique(Nat.add(t, dx), mx, k, mod_lt(x, k, pos))

law mod_mod_mul:
  for +a: Nat
  for +j: Nat
  for +k: Nat
  for +pos: {Nat.is_lt(0n, Nat.mul(j, k)) == True{} : Bool}
  for +kpos: {Nat.is_lt(0n, k) == True{} : Bool}
  {Nat.mod(Nat.mod(a, Nat.mul(j, k)), k) == Nat.mod(a, k) : Nat}

def mod_mod_mul(a, j, k, pos, kpos):
  +jk = Nat.mul(j, k)
  +d = Nat.div(a, jk)
  +m = Nat.mod(a, jk)
  %div_mod_id(a, jk, pos) : {Nat.mod(m, k) == Nat.mod(_, k) : Nat}
  %mul_assoc(d, j, k) : {Nat.mod(m, k) == Nat.mod(Nat.add(_, m), k) : Nat}
  Equal.sym(Nat, Nat.mod(Nat.add(Nat.mul(Nat.mul(d, j), k), m), k), Nat.mod(m, k), mod_add_mul(Nat.mul(d, j), m, k, kpos))

law add_sub_le:
  for +k: Nat
  for +y: Nat
  for le: {Nat.is_le(k, y) == True{} : Bool}
  {Nat.add(k, Nat.sub(y, k)) == y : Nat}

def add_sub_le(k, y, le):
  match k y:
    case 0n 0n:
      {==}
    case 0n 1n+q:
      {==}
    case 1n+p 0n:
      absurd({Nat.add(1n+p, Nat.sub(0n, 1n+p)) == 0n : Nat}, false_true(le))
    case 1n+p 1n+q:
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(p, Nat.sub(q, p)), q, add_sub_le(p, q, le))

law eq_of_is_eq:
  for +a: Nat
  for +b: Nat
  for e: {Nat.is_eq(a, b) == True{} : Bool}
  {a == b : Nat}

def eq_of_is_eq(a, b, e):
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+q:
      absurd({0n == 1n+q : Nat}, false_true(e))
    case 1n+p 0n:
      absurd({1n+p == 0n : Nat}, false_true(e))
    case 1n+p 1n+q:
      Equal.cong(Nat, Nat, x => 1n+x, p, q, eq_of_is_eq(p, q, e))

# m < k and not 1 + m < k: then 1 + m is k.
law succ_eq_of_lt:
  for +m: Nat
  for +k: Nat
  for lt: {Nat.is_lt(m, k) == True{} : Bool}
  for no: {Nat.is_lt(1n+m, k) == False{} : Bool}
  {1n+m == k : Nat}

def succ_eq_of_lt(m, k, lt, no):
  match m k:
    case m 0n:
      absurd({1n+m == 0n : Nat}, lt_zero(m, lt))
    case 0n 1n+q:
      match q:
        case 0n:
          {==}
        case 1n+qq:
          absurd({1n == 2n+qq : Nat}, true_false(no))
    case 1n+p 1n+q:
      Equal.cong(Nat, Nat, x => 1n+x, 1n+p, q, succ_eq_of_lt(p, q, lt, no))

law le_not_lt_eq:
  for +a: Nat
  for +b: Nat
  for le: {Nat.is_le(a, b) == True{} : Bool}
  for no: {Nat.is_lt(a, b) == False{} : Bool}
  {a == b : Nat}

def le_not_lt_eq(a, b, le, no):
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+q:
      absurd({0n == 1n+q : Nat}, true_false(no))
    case 1n+p 0n:
      absurd({1n+p == 0n : Nat}, false_true(le))
    case 1n+p 1n+q:
      Equal.cong(Nat, Nat, x => 1n+x, p, q, le_not_lt_eq(p, q, le, no))

law div_succ_in:
  for +a: Nat
  for +k: Nat
  for +pos: {Nat.is_lt(0n, k) == True{} : Bool}
  for +h: {Nat.is_lt(1n+Nat.mod(a, k), k) == True{} : Bool}
  {Nat.divmod(1n+a, k) == (Nat.div(a, k), 1n+Nat.mod(a, k)) : Nat & Nat}

def div_succ_in(a, k, pos, h):
  +d = Nat.div(a, k)
  +m = Nat.mod(a, k)
  %div_mod_id(a, k, pos) : {Nat.divmod(1n+_, k) == (d, 1n+m) : Nat & Nat}
  %add_succ_r(Nat.mul(d, k), m) : {Nat.divmod(_, k) == (d, 1n+m) : Nat & Nat}
  dm_unique(d, 1n+m, k, h)

law div_succ_wrap:
  for +a: Nat
  for +k: Nat
  for +pos: {Nat.is_lt(0n, k) == True{} : Bool}
  for +h: {Nat.is_lt(1n+Nat.mod(a, k), k) == False{} : Bool}
  {Nat.divmod(1n+a, k) == (1n+Nat.div(a, k), 0n) : Nat & Nat}

def div_succ_wrap(a, k, pos, h):
  +d = Nat.div(a, k)
  +m = Nat.mod(a, k)
  +full = succ_eq_of_lt(m, k, mod_lt(a, k, pos), h)
  %div_mod_id(a, k, pos) : {Nat.divmod(1n+_, k) == (1n+d, 0n) : Nat & Nat}
  %add_succ_r(Nat.mul(d, k), m) : {Nat.divmod(_, k) == (1n+d, 0n) : Nat & Nat}
  %Equal.sym(Nat, 1n+m, k, full) : {Nat.divmod(Nat.add(Nat.mul(d, k), _), k) == (1n+d, 0n) : Nat & Nat}
  %add_comm(k, Nat.mul(d, k)) : {Nat.divmod(_, k) == (1n+d, 0n) : Nat & Nat}
  %add_zero_r(Nat.add(k, Nat.mul(d, k))) : {Nat.divmod(_, k) == (1n+d, 0n) : Nat & Nat}
  dm_unique(1n+d, 0n, k, pos)

law not_lt_le:
  for +a: Nat
  for +b: Nat
  for no: {Nat.is_lt(a, b) == False{} : Bool}
  {Nat.is_le(b, a) == True{} : Bool}

def not_lt_le(a, b, no):
  match a b:
    case a 0n:
      zero_le(a)
    case 0n 1n+q:
      absurd({Nat.is_le(1n+q, 0n) == True{} : Bool}, true_false(no))
    case 1n+p 1n+q:
      not_lt_le(p, q, no)

def lt_le_absurd(+x: Nat, +m: Nat, lt: {Nat.is_lt(x, m) == True{} : Bool}, le: {Nat.is_le(m, x) == True{} : Bool}) -> Empty:
  match x m:
    case x 0n:
      lt_zero(x, lt)
    case 0n 1n+q:
      false_true(le)
    case 1n+p 1n+q:
      lt_le_absurd(p, q, lt, le)

law le_add_self:
  for +a: Nat
  for +b: Nat
  {Nat.is_le(a, Nat.add(a, b)) == True{} : Bool}

def le_add_self(a, b):
  match a:
    case 0n:
      zero_le(b)
    case 1n+p:
      le_add_self(p, b)

law le_mul_mono:
  for +a: Nat
  for +b: Nat
  for +k: Nat
  for le: {Nat.is_le(a, b) == True{} : Bool}
  {Nat.is_le(Nat.mul(a, k), Nat.mul(b, k)) == True{} : Bool}

def le_mul_mono(a, b, k, le):
  match a b:
    case 0n b:
      zero_le(Nat.mul(b, k))
    case 1n+p 0n:
      absurd({Nat.is_le(Nat.mul(1n+p, k), 0n) == True{} : Bool}, false_true(le))
    case 1n+p 1n+q:
      le_add_mono(k, Nat.mul(p, k), Nat.mul(q, k), le_mul_mono(p, q, k, le))

def div_lt_case(+x: Nat, +b: Nat, +k: Nat, +pos: {Nat.is_lt(0n, k) == True{} : Bool}, +lt: {Nat.is_lt(x, Nat.mul(b, k)) == True{} : Bool}, r: Bool, e: {Nat.is_lt(Nat.div(x, k), b) == r : Bool}) -> {Nat.is_lt(Nat.div(x, k), b) == True{} : Bool}:
  match r:
    case True{}:
      e
    case False{}:
      +d = Nat.div(x, k)
      +big = le_mul_mono(b, d, k, not_lt_le(d, b, e))
      +m = Nat.mod(x, k)
      +up0 = le_add_self(Nat.mul(d, k), m)
      +up = Equal.trans(Bool, Nat.is_le(Nat.mul(d, k), x), Nat.is_le(Nat.mul(d, k), Nat.add(Nat.mul(d, k), m)), True{}, Equal.cong(Nat, Bool, z => Nat.is_le(Nat.mul(d, k), z), x, Nat.add(Nat.mul(d, k), m), Equal.sym(Nat, Nat.add(Nat.mul(d, k), m), x, div_mod_id(x, k, pos))), up0)
      absurd({Nat.is_lt(d, b) == True{} : Bool}, lt_le_absurd(x, Nat.mul(b, k), lt, le_trans(Nat.mul(b, k), Nat.mul(d, k), x, big, up)))

law div_lt_of_lt_mul:
  for +x: Nat
  for +b: Nat
  for +k: Nat
  for +pos: {Nat.is_lt(0n, k) == True{} : Bool}
  for lt: {Nat.is_lt(x, Nat.mul(b, k)) == True{} : Bool}
  {Nat.is_lt(Nat.div(x, k), b) == True{} : Bool}

def div_lt_of_lt_mul(x, b, k, pos, lt):
  div_lt_case(x, b, k, pos, lt, Nat.is_lt(Nat.div(x, k), b), {==})

law lt_of_succ_lt:
  for +a: Nat
  for +b: Nat
  for lt: {Nat.is_lt(1n+a, b) == True{} : Bool}
  {Nat.is_lt(a, b) == True{} : Bool}

def lt_of_succ_lt(a, b, lt):
  match a b:
    case a 0n:
      absurd({Nat.is_lt(a, 0n) == True{} : Bool}, false_true(lt))
    case 0n 1n+q:
      {==}
    case 1n+p 1n+q:
      lt_of_succ_lt(p, q, lt)

law sub_succ_l:
  for +k: Nat
  for +y: Nat
  for le: {Nat.is_le(k, y) == True{} : Bool}
  {Nat.sub(1n+y, k) == 1n+Nat.sub(y, k) : Nat}

def sub_succ_l(k, y, le):
  match k y:
    case 0n y:
      %Equal.sym(Nat, Nat.sub(y, 0n), y, sub_zero_r(y)) : {1n+y == 1n+_ : Nat}
      {==}
    case 1n+p 0n:
      absurd({Nat.sub(1n, 1n+p) == 1n+Nat.sub(0n, 1n+p) : Nat}, false_true(le))
    case 1n+p 1n+q:
      sub_succ_l(p, q, le)

law lt_of_succ_le:
  for +a: Nat
  for +b: Nat
  for le: {Nat.is_le(1n+a, b) == True{} : Bool}
  {Nat.is_lt(a, b) == True{} : Bool}

def lt_of_succ_le(a, b, le):
  match a b:
    case a 0n:
      absurd({Nat.is_lt(a, 0n) == True{} : Bool}, false_true(le))
    case 0n 1n+q:
      {==}
    case 1n+p 1n+q:
      lt_of_succ_le(p, q, le)

law succ_le_of_lt:
  for +a: Nat
  for +b: Nat
  for lt: {Nat.is_lt(a, b) == True{} : Bool}
  {Nat.is_le(1n+a, b) == True{} : Bool}

def succ_le_of_lt(a, b, lt):
  match a b:
    case a 0n:
      absurd({Nat.is_le(1n+a, 0n) == True{} : Bool}, lt_zero(a, lt))
    case 0n 1n+q:
      zero_le(q)
    case 1n+p 1n+q:
      succ_le_of_lt(p, q, lt)

law and_left:
  for +a: Bool
  for +b: Bool
  for h: {Bool.and(a, b) == True{} : Bool}
  {a == True{} : Bool}

def and_left(a, b, h):
  match a:
    case True{}:
      {==}
    case False{}:
      absurd({False{} == True{} : Bool}, false_true(h))

law and_right:
  for +a: Bool
  for +b: Bool
  for h: {Bool.and(a, b) == True{} : Bool}
  {b == True{} : Bool}

def and_right(a, b, h):
  match a:
    case True{}:
      h
    case False{}:
      absurd({b == True{} : Bool}, false_true(h))

law le_sub_mono:
  for +a: Nat
  for +b: Nat
  for +k: Nat
  for le: {Nat.is_le(a, b) == True{} : Bool}
  {Nat.is_le(Nat.sub(a, k), Nat.sub(b, k)) == True{} : Bool}

def le_sub_mono(a, b, k, le):
  match a b k:
    case 0n b k:
      zero_le(Nat.sub(b, k))
    case 1n+p 0n k:
      absurd({Nat.is_le(Nat.sub(1n+p, k), Nat.sub(0n, k)) == True{} : Bool}, false_true(le))
    case 1n+p 1n+q 0n:
      le
    case 1n+p 1n+q 1n+j:
      le_sub_mono(p, q, j, le)

law le_add_cancel:
  for +k: Nat
  for +x: Nat
  for +y: Nat
  for le: {Nat.is_le(Nat.add(k, x), Nat.add(k, y)) == True{} : Bool}
  {Nat.is_le(x, y) == True{} : Bool}

def le_add_cancel(k, x, y, le):
  %cmp_add_cancel(k, x, y) : {Cmp.is_le(_) == True{} : Bool}
  le

def le_div_case(+b: Nat, +a: Nat, +k: Nat, +pos: {Nat.is_lt(0n, k) == True{} : Bool}, +le: {Nat.is_le(Nat.mul(b, k), a) == True{} : Bool}, r: Bool, e: {Nat.is_lt(Nat.div(a, k), b) == r : Bool}) -> {Nat.is_le(b, Nat.div(a, k)) == True{} : Bool}:
  match r:
    case False{}:
      not_lt_le(Nat.div(a, k), b, e)
    case True{}:
      +d = Nat.div(a, k)
      +m = Nat.mod(a, k)
      +up0 = lt_add_mono(Nat.mul(d, k), m, k, mod_lt(a, k, pos))
      +up1 = Equal.trans(Bool, Nat.is_lt(a, Nat.add(Nat.mul(d, k), k)), Nat.is_lt(Nat.add(Nat.mul(d, k), m), Nat.add(Nat.mul(d, k), k)), True{}, Equal.cong(Nat, Bool, z => Nat.is_lt(z, Nat.add(Nat.mul(d, k), k)), a, Nat.add(Nat.mul(d, k), m), Equal.sym(Nat, Nat.add(Nat.mul(d, k), m), a, div_mod_id(a, k, pos))), up0)
      +up = Equal.trans(Bool, Nat.is_lt(a, Nat.mul(1n+d, k)), Nat.is_lt(a, Nat.add(Nat.mul(d, k), k)), True{}, Equal.cong(Nat, Bool, z => Nat.is_lt(a, z), Nat.add(k, Nat.mul(d, k)), Nat.add(Nat.mul(d, k), k), add_comm(k, Nat.mul(d, k))), up1)
      +big = le_trans(Nat.mul(1n+d, k), Nat.mul(b, k), a, le_mul_mono(1n+d, b, k, succ_le_of_lt(d, b, e)), le)
      absurd({Nat.is_le(b, d) == True{} : Bool}, lt_le_absurd(a, Nat.mul(1n+d, k), up, big))

law le_div_of_mul_le:
  for +b: Nat
  for +a: Nat
  for +k: Nat
  for +pos: {Nat.is_lt(0n, k) == True{} : Bool}
  for +le: {Nat.is_le(Nat.mul(b, k), a) == True{} : Bool}
  {Nat.is_le(b, Nat.div(a, k)) == True{} : Bool}

def le_div_of_mul_le(b, a, k, pos, le):
  le_div_case(b, a, k, pos, le, Nat.is_lt(Nat.div(a, k), b), {==})

law not_le_lt:
  for +a: Nat
  for +b: Nat
  for no: {Nat.is_le(a, b) == False{} : Bool}
  {Nat.is_lt(b, a) == True{} : Bool}

def not_le_lt(a, b, no):
  match a b:
    case 0n b:
      absurd({Nat.is_lt(b, 0n) == True{} : Bool}, true_false(Equal.trans(Bool, True{}, Nat.is_le(0n, b), False{}, Equal.sym(Bool, Nat.is_le(0n, b), True{}, zero_le(b)), no)))
    case 1n+p 0n:
      {==}
    case 1n+p 1n+q:
      not_le_lt(p, q, no)

def lt_mul_case(+x: Nat, +b: Nat, +k: Nat, +pos: {Nat.is_lt(0n, k) == True{} : Bool}, +h: {Nat.is_lt(Nat.div(x, k), b) == True{} : Bool}, r: Bool, e: {Nat.is_lt(x, Nat.mul(b, k)) == r : Bool}) -> {Nat.is_lt(x, Nat.mul(b, k)) == True{} : Bool}:
  match r:
    case True{}:
      e
    case False{}:
      absurd({Nat.is_lt(x, Nat.mul(b, k)) == True{} : Bool}, lt_le_absurd(Nat.div(x, k), b, h, le_div_of_mul_le(b, x, k, pos, not_lt_le(x, Nat.mul(b, k), e))))

law lt_mul_of_div_lt:
  for +x: Nat
  for +b: Nat
  for +k: Nat
  for +pos: {Nat.is_lt(0n, k) == True{} : Bool}
  for +h: {Nat.is_lt(Nat.div(x, k), b) == True{} : Bool}
  {Nat.is_lt(x, Nat.mul(b, k)) == True{} : Bool}

def lt_mul_of_div_lt(x, b, k, pos, h):
  lt_mul_case(x, b, k, pos, h, Nat.is_lt(x, Nat.mul(b, k)), {==})

def sub_lt_case(+n: Nat, +a: Nat, +m: Nat, +h: {Nat.is_lt(Nat.sub(n, a), m) == True{} : Bool}, r: Bool, e: {Nat.is_le(a, n) == r : Bool}) -> {Nat.is_lt(n, Nat.add(a, m)) == True{} : Bool}:
  match r:
    case True{}:
      +up = lt_add_mono(a, Nat.sub(n, a), m, h)
      Equal.trans(Bool, Nat.is_lt(n, Nat.add(a, m)), Nat.is_lt(Nat.add(a, Nat.sub(n, a)), Nat.add(a, m)), True{}, Equal.cong(Nat, Bool, z => Nat.is_lt(z, Nat.add(a, m)), n, Nat.add(a, Nat.sub(n, a)), Equal.sym(Nat, Nat.add(a, Nat.sub(n, a)), n, add_sub_le(a, n, e))), up)
    case False{}:
      lt_le_trans(n, a, Nat.add(a, m), not_le_lt(a, n, e), le_add_self(a, m))

law lt_of_sub_lt:
  for +n: Nat
  for +a: Nat
  for +m: Nat
  for +h: {Nat.is_lt(Nat.sub(n, a), m) == True{} : Bool}
  {Nat.is_lt(n, Nat.add(a, m)) == True{} : Bool}

def lt_of_sub_lt(n, a, m, h):
  sub_lt_case(n, a, m, h, Nat.is_le(a, n), {==})
