# Walking a list of period lengths: index and offset invert before.
import Base
import ../src/http/date.bend as D
import ./date-arith.bend as A

def count(lens: List<&2, Nat>) -> Nat:
  match lens:
    case Nil{}:
      0n
    case l <> t:
      1n+count(t)

def nth(i: Nat, lens: List<&2, Nat>) -> Nat:
  match i lens:
    case _ Nil{}:
      0n
    case 0n l <> t:
      l
    case 1n+j l <> t:
      nth(j, t)

def total(lens: List<&2, Nat>) -> Nat:
  match lens:
    case Nil{}:
      0n
    case l <> t:
      Nat.add(l, total(t))

law index_before:
  for +i: Nat
  for +lens: List<&2, Nat>
  for +r: Nat
  for li: {Nat.is_lt(i, count(lens)) == True{} : Bool}
  for lr: {Nat.is_lt(r, nth(i, lens)) == True{} : Bool}
  {D.index(lens, D.before(i, lens, r)) == i : Nat}

def index_before(i, lens, r, li, lr):
  match i lens:
    case 0n Nil{}:
      A.absurd({D.index([], r) == 0n : Nat}, A.false_true(li))
    case 0n l <> t:
      %Equal.sym(Bool, Nat.is_lt(r, l), True{}, lr) : {D.index_pick(_, D.index(t, Nat.sub(r, l))) == 0n : Nat}
      {==}
    case 1n+j Nil{}:
      A.absurd({D.index([], D.before(1n+j, [], r)) == 1n+j : Nat}, A.lt_zero(1n+j, li))
    case 1n+j l <> t:
      %Equal.sym(Bool, Nat.is_lt(Nat.add(l, D.before(j, t, r)), l), False{}, A.not_lt_add(l, D.before(j, t, r))) : {D.index_pick(_, D.index(t, Nat.sub(Nat.add(l, D.before(j, t, r)), l))) == 1n+j : Nat}
      %Equal.sym(Nat, Nat.sub(Nat.add(l, D.before(j, t, r)), l), D.before(j, t, r), A.sub_add_cancel(l, D.before(j, t, r))) : {D.index_pick(False{}, D.index(t, _)) == 1n+j : Nat}
      Equal.cong(Nat, Nat, x => 1n+x, D.index(t, D.before(j, t, r)), j, index_before(j, t, r, li, lr))

law offset_before:
  for +i: Nat
  for +lens: List<&2, Nat>
  for +r: Nat
  for li: {Nat.is_lt(i, count(lens)) == True{} : Bool}
  for lr: {Nat.is_lt(r, nth(i, lens)) == True{} : Bool}
  {D.offset(lens, D.before(i, lens, r)) == r : Nat}

def offset_before(i, lens, r, li, lr):
  match i lens:
    case 0n Nil{}:
      A.absurd({D.offset([], r) == r : Nat}, A.false_true(li))
    case 0n l <> t:
      %Equal.sym(Bool, Nat.is_lt(r, l), True{}, lr) : {D.offset_pick(r, _, D.offset(t, Nat.sub(r, l))) == r : Nat}
      {==}
    case 1n+j Nil{}:
      A.absurd({D.offset([], D.before(1n+j, [], r)) == r : Nat}, A.lt_zero(1n+j, li))
    case 1n+j l <> t:
      %Equal.sym(Bool, Nat.is_lt(Nat.add(l, D.before(j, t, r)), l), False{}, A.not_lt_add(l, D.before(j, t, r))) : {D.offset_pick(Nat.add(l, D.before(j, t, r)), _, D.offset(t, Nat.sub(Nat.add(l, D.before(j, t, r)), l))) == r : Nat}
      %Equal.sym(Nat, Nat.sub(Nat.add(l, D.before(j, t, r)), l), D.before(j, t, r), A.sub_add_cancel(l, D.before(j, t, r))) : {D.offset_pick(Nat.add(l, D.before(j, t, r)), False{}, D.offset(t, _)) == r : Nat}
      offset_before(j, t, r, li, lr)

law before_lt:
  for +i: Nat
  for +lens: List<&2, Nat>
  for +r: Nat
  for li: {Nat.is_lt(i, count(lens)) == True{} : Bool}
  for lr: {Nat.is_lt(r, nth(i, lens)) == True{} : Bool}
  {Nat.is_lt(D.before(i, lens, r), total(lens)) == True{} : Bool}

def before_lt(i, lens, r, li, lr):
  match i lens:
    case 0n Nil{}:
      A.absurd({Nat.is_lt(r, 0n) == True{} : Bool}, A.false_true(li))
    case 0n l <> t:
      A.lt_add_r(r, l, total(t), lr)
    case 1n+j Nil{}:
      A.absurd({Nat.is_lt(r, 0n) == True{} : Bool}, A.lt_zero(1n+j, li))
    case 1n+j l <> t:
      A.lt_add_mono(l, D.before(j, t, r), total(t), before_lt(j, t, r, li, lr))

law before_succ:
  for +i: Nat
  for +lens: List<&2, Nat>
  for +r: Nat
  {D.before(i, lens, 1n+r) == 1n+D.before(i, lens, r) : Nat}

def before_succ(i, lens, r):
  match i lens:
    case 0n _:
      {==}
    case 1n+j Nil{}:
      {==}
    case 1n+j l <> t:
      %Equal.sym(Nat, D.before(j, t, 1n+r), 1n+D.before(j, t, r), before_succ(j, t, r)) : {Nat.add(l, _) == 1n+Nat.add(l, D.before(j, t, r)) : Nat}
      A.add_succ_r(l, D.before(j, t, r))

law before_next:
  for +i: Nat
  for +lens: List<&2, Nat>
  for li: {Nat.is_lt(i, count(lens)) == True{} : Bool}
  {D.before(1n+i, lens, 0n) == D.before(i, lens, nth(i, lens)) : Nat}

def before_next(i, lens, li):
  match i lens:
    case 0n Nil{}:
      {==}
    case 0n l <> t:
      A.add_zero_r(l)
    case 1n+j Nil{}:
      {==}
    case 1n+j l <> t:
      Equal.cong(Nat, Nat, x => Nat.add(l, x), D.before(1n+j, t, 0n), D.before(j, t, nth(j, t)), before_next(j, t, li))

law nth_rep:
  for +i: Nat
  for +k: Nat
  for +l: Nat
  for lt: {Nat.is_lt(i, k) == True{} : Bool}
  {nth(i, D.rep(k, l)) == l : Nat}

def nth_rep(i, k, l, lt):
  match i k:
    case i 0n:
      A.absurd({nth(i, []) == l : Nat}, A.lt_zero(i, lt))
    case 0n 1n+kp:
      {==}
    case 1n+j 1n+kp:
      nth_rep(j, kp, l, lt)
