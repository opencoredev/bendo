# Peeling one factor from the finite union of repetition powers.
import Base
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-split.bend as S

def cat_none_right(+k: Nat, +l: Spec.Lang, +w: String) -> {Spec.mem(Spec.LCat{l, Spec.LNone{}}, k, w) == False{} : Bool}:
  match k:
    case 0n: S.and_zero(Spec.mem(l, 0n, ""))
    case 1n+j:
      %Equal.sym(Bool, Spec.mem(Spec.LCat{l, Spec.LNone{}}, j, w), False{}, cat_none_right(j, l, w)) : {((Spec.mem(l, 1n+j, String.take(w, 1n+j)) && False{}) || _) == False{} : Bool}
      %Equal.sym(Bool, Spec.mem(l, 1n+j, String.take(w, 1n+j)) && False{}, False{}, S.and_zero(Spec.mem(l, 1n+j, String.take(w, 1n+j)))) : {(_ || False{}) == False{} : Bool}
      {==}

def cat_pick(+hit: Bool, +l: Spec.Lang, +r: Spec.Lang, +k: Nat, +w: String) -> {Spec.mem(Spec.LCat{l, Bool.pick(Spec.Lang, hit, r, Spec.LNone{})}, k, w) == Spec.mem(Bool.pick(Spec.Lang, hit, Spec.LCat{l, r}, Spec.LNone{}), k, w) : Bool}:
  match hit:
    case True{}: {==}
    case False{}: cat_none_right(k, l, w)

def counts_shift(+n: Nat, +m: Nat, +l: Spec.Lang, +k: Nat, +w: String) -> {Spec.mem(Spec.counts(l, 1n+m, 1n+n), k, w) == Spec.mem(Spec.LCat{l, Spec.counts(l, m, n)}, k, w) : Bool}:
  match n:
    case 0n:
      match m:
        case 0n: {==}
        case 1n+i: Equal.sym(Bool, Spec.mem(Spec.LCat{l, Spec.LNone{}}, k, w), False{}, cat_none_right(k, l, w))
    case 1n+j:
      %Equal.sym(Bool, Spec.mem(Spec.LCat{l, Spec.counts(l, m, 1n+j)}, k, w), Spec.mem(Spec.LCat{l, Spec.counts(l, m, j)}, k, w) || Spec.mem(Spec.LCat{l, Bool.pick(Spec.Lang, Nat.is_le(m, 1n+j), Spec.power(l, 1n+j), Spec.LNone{})}, k, w), S.cat_or_right(k, l, Spec.counts(l, m, j), Bool.pick(Spec.Lang, Nat.is_le(m, 1n+j), Spec.power(l, 1n+j), Spec.LNone{}), w)) : {Spec.mem(Spec.counts(l, 1n+m, 1n+1n+j), k, w) == _ : Bool}
      %counts_shift(j, m, l, k, w) : {Spec.mem(Spec.counts(l, 1n+m, 1n+1n+j), k, w) == (_ || Spec.mem(Spec.LCat{l, Bool.pick(Spec.Lang, Nat.is_le(m, 1n+j), Spec.power(l, 1n+j), Spec.LNone{})}, k, w)) : Bool}
      %Equal.sym(Bool, Spec.mem(Spec.LCat{l, Bool.pick(Spec.Lang, Nat.is_le(m, 1n+j), Spec.power(l, 1n+j), Spec.LNone{})}, k, w), Spec.mem(Bool.pick(Spec.Lang, Nat.is_le(m, 1n+j), Spec.power(l, 1n+1n+j), Spec.LNone{}), k, w), cat_pick(Nat.is_le(m, 1n+j), l, Spec.power(l, 1n+j), k, w)) : {Spec.mem(Spec.counts(l, 1n+m, 1n+1n+j), k, w) == (Spec.mem(Spec.counts(l, 1n+m, 1n+j), k, w) || _) : Bool}
      {==}

def zero_le(+n: Nat) -> {Nat.is_le(0n, n) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+i: {==}

def zero_pick(+n: Nat, +l: Spec.Lang) -> {Bool.pick(Spec.Lang, Nat.is_le(0n, n), l, Spec.LNone{}) == l : Spec.Lang}:
  %Equal.sym(Bool, Nat.is_le(0n, n), True{}, zero_le(n)) : {Bool.pick(Spec.Lang, _, l, Spec.LNone{}) == l : Spec.Lang}
  {==}

# Separate the empty power from the positive counts.
def counts_split_zero(+n: Nat, +l: Spec.Lang, +k: Nat, +w: String) -> {Spec.mem(Spec.counts(l, 0n, n), k, w) == (String.is_empty(w) || Spec.mem(Spec.counts(l, 1n, n), k, w)) : Bool}:
  match n:
    case 0n: Equal.sym(Bool, String.is_empty(w) || False{}, String.is_empty(w), S.or_zero(String.is_empty(w)))
    case 1n+j:
      %Equal.sym(Spec.Lang, Bool.pick(Spec.Lang, Nat.is_le(0n, j), Spec.power(l, 1n+j), Spec.LNone{}), Spec.power(l, 1n+j), zero_pick(j, Spec.power(l, 1n+j))) : {Spec.mem(Spec.counts(l, 0n, 1n+j), k, w) == (String.is_empty(w) || (Spec.mem(Spec.counts(l, 1n, j), k, w) || Spec.mem(_, k, w))) : Bool}
      %Equal.sym(Spec.Lang, Bool.pick(Spec.Lang, Nat.is_le(0n, 1n+j), Spec.power(l, 1n+j), Spec.LNone{}), Spec.power(l, 1n+j), zero_pick(1n+j, Spec.power(l, 1n+j))) : {(Spec.mem(Spec.counts(l, 0n, j), k, w) || Spec.mem(_, k, w)) == (String.is_empty(w) || (Spec.mem(Spec.counts(l, 1n, j), k, w) || Spec.mem(Spec.power(l, 1n+j), k, w))) : Bool}
      %Equal.sym(Bool, String.is_empty(w) || (Spec.mem(Spec.counts(l, 1n, j), k, w) || Spec.mem(Spec.power(l, 1n+j), k, w)), (String.is_empty(w) || Spec.mem(Spec.counts(l, 1n, j), k, w)) || Spec.mem(Spec.power(l, 1n+j), k, w), S.or_assoc(String.is_empty(w), Spec.mem(Spec.counts(l, 1n, j), k, w), Spec.mem(Spec.power(l, 1n+j), k, w))) : {(Spec.mem(Spec.counts(l, 0n, j), k, w) || Spec.mem(Spec.power(l, 1n+j), k, w)) == _ : Bool}
      %counts_split_zero(j, l, k, w) : {(Spec.mem(Spec.counts(l, 0n, j), k, w) || Spec.mem(Spec.power(l, 1n+j), k, w)) == (_ || Spec.mem(Spec.power(l, 1n+j), k, w)) : Bool}
      {==}

def pred(n: Nat) -> Nat:
  match n:
    case 0n: 0n
    case 1n+i: i

# On a nonempty input, every accepted count has a first body factor.
def counts_head(+m: Nat, +n: Nat, +l: Spec.Lang, +k: Nat, +c: U32, +t: String) -> {Spec.mem(Spec.counts(l, m, 1n+n), k, SCon{Chr{c}, t}) == Spec.mem(Spec.LCat{l, Spec.counts(l, pred(m), n)}, k, SCon{Chr{c}, t}) : Bool}:
  match m:
    case 0n:
      Equal.trans(Bool, Spec.mem(Spec.counts(l, 0n, 1n+n), k, SCon{Chr{c}, t}), Spec.mem(Spec.counts(l, 1n, 1n+n), k, SCon{Chr{c}, t}), Spec.mem(Spec.LCat{l, Spec.counts(l, 0n, n)}, k, SCon{Chr{c}, t}), counts_split_zero(1n+n, l, k, SCon{Chr{c}, t}), counts_shift(n, 0n, l, k, SCon{Chr{c}, t}))
    case 1n+i: counts_shift(n, i, l, k, SCon{Chr{c}, t})
