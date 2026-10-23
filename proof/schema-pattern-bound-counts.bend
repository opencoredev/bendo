# Nonempty factors consume at least one scalar each.
import Base
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-bound-length.bend as L

def power_short(+j: Nat, +k: Nat, +w: String, +l: Spec.Lang, +e: {Nat.is_lt(String.length(w), j) == True{} : Bool}) -> {Spec.mem(Spec.power(Spec.LNonEmpty{l}, j), k, w) == False{} : Bool}:
  match j:
    case 0n:
      match w:
        case SNil{}: L.absurd({Spec.mem(Spec.LEmpty{}, k, "") == False{} : Bool}, L.false_true(e))
        case SCon{h, t}: L.absurd({Spec.mem(Spec.LEmpty{}, k, SCon{h, t}) == False{} : Bool}, L.false_true(e))
    case 1n+i:
      match k:
        case 0n: {==}
        case 1n+q:
          match w:
            case SNil{}: power_short(1n+i, q, "", l, e)
            case SCon{h, t}:
              %Equal.sym(Bool, Spec.mem(Spec.power(Spec.LNonEmpty{l}, 1n+i), q, SCon{h, t}), False{}, power_short(1n+i, q, SCon{h, t}, l, e)) : {((Spec.mem(Spec.LNonEmpty{l}, 1n+q, String.take(SCon{h, t}, 1n+q)) && Spec.mem(Spec.power(Spec.LNonEmpty{l}, i), Spec.length(String.drop(t, q)), String.drop(t, q))) || _) == False{} : Bool}
              %Equal.sym(Bool, Spec.mem(Spec.power(Spec.LNonEmpty{l}, i), Spec.length(String.drop(t, q)), String.drop(t, q)), False{}, power_short(i, Spec.length(String.drop(t, q)), String.drop(t, q), l, L.lt_of_le_lt(String.length(String.drop(t, q)), String.length(t), i, L.drop_le(t, q), e))) : {((Spec.mem(Spec.LNonEmpty{l}, 1n+q, String.take(SCon{h, t}, 1n+q)) && _) || False{}) == False{} : Bool}
              L.and_false_or(Spec.mem(Spec.LNonEmpty{l}, 1n+q, String.take(SCon{h, t}, 1n+q)))

def pick_mem(+b: Bool, +l: Spec.Lang, +k: Nat, +w: String) -> {Spec.mem(Bool.pick(Spec.Lang, b, l, Spec.LNone{}), k, w) == (b && Spec.mem(l, k, w)) : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

# Once the bound covers the word, adding one further count adds no matches.
def counts_step(+l: Spec.Lang, +m: Nat, +n: Nat, +k: Nat, +w: String, +e: {Nat.is_le(String.length(w), n) == True{} : Bool}) -> {Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, 1n+n), k, w) == Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, n), k, w) : Bool}:
  %L.or_false(Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, n), k, w)) : {Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, 1n+n), k, w) == _ : Bool}
  %L.and_false(Nat.is_le(m, 1n+n)) : {Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, 1n+n), k, w) == (Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, n), k, w) || _) : Bool}
  %power_short(1n+n, k, w, l, L.lt_succ_of_le(String.length(w), n, e)) : {Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, 1n+n), k, w) == (Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, n), k, w) || (Nat.is_le(m, 1n+n) && _)) : Bool}
  %pick_mem(Nat.is_le(m, 1n+n), Spec.power(Spec.LNonEmpty{l}, 1n+n), k, w) : {Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, 1n+n), k, w) == (Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, n), k, w) || _) : Bool}
  {==}

# Extra counts above the word length are semantically inert.
def counts_extra(+extra: Nat, +l: Spec.Lang, +m: Nat, +k: Nat, +w: String) -> {Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, Nat.add(extra, String.length(w))), k, w) == Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, String.length(w)), k, w) : Bool}:
  match extra:
    case 0n: {==}
    case 1n+i:
      Equal.trans(Bool, Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, 1n+Nat.add(i, String.length(w))), k, w), Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, Nat.add(i, String.length(w))), k, w), Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, String.length(w)), k, w), counts_step(l, m, Nat.add(i, String.length(w)), k, w, L.le_extra(i, String.length(w))), counts_extra(i, l, m, k, w))

def counts_at_length(+n: Nat, +l: Spec.Lang, +m: Nat, +k: Nat, +w: String, +e: {Nat.is_le(String.length(w), n) == True{} : Bool}) -> {Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, n), k, w) == Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, String.length(w)), k, w) : Bool}:
  %Equal.sym(Nat, n, Nat.add(Nat.sub(n, String.length(w)), String.length(w)), L.decompose(String.length(w), n, e)) : {Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, _), k, w) == Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, String.length(w)), k, w) : Bool}
  counts_extra(Nat.sub(n, String.length(w)), l, m, k, w)

def counts_bound(+l: Spec.Lang, +m: Nat, +b1: Nat, +b2: Nat, +k: Nat, +w: String, e1: {Nat.is_le(String.length(w), b1) == True{} : Bool}, e2: {Nat.is_le(String.length(w), b2) == True{} : Bool}) -> {Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, b1), k, w) == Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, b2), k, w) : Bool}:
  Equal.trans(Bool, Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, b1), k, w), Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, String.length(w)), k, w), Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, b2), k, w), counts_at_length(b1, l, m, k, w, e1), Equal.sym(Bool, Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, b2), k, w), Spec.mem(Spec.counts(Spec.LNonEmpty{l}, m, String.length(w)), k, w), counts_at_length(b2, l, m, k, w, e2)))
