# Bound-aware adapters used by the structural derivative induction.
import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-bound.bend as Bound
import ./schema-pattern-strings.bend as W
import ./schema-pattern-split.bend as S
import ./schema-pattern-nullable.bend as N
import ./schema-pattern-empty.bend as Empty

def length_bound(+w: String, +b: Nat, e: {Nat.is_le(Spec.length(w), b) == True{} : Bool}) -> {Nat.is_le(String.length(w), b) == True{} : Bool}:
  %Equal.sym(Nat, String.length(w), Spec.length(w), W.length_eq(w)) : {Nat.is_le(_, b) == True{} : Bool}
  e

def bound_mem(+p: P.Pattern, +w: String, +k: Nat, +b1: Nat, +b2: Nat, e1: {Nat.is_le(Spec.length(w), b1) == True{} : Bool}, e2: {Nat.is_le(Spec.length(w), b2) == True{} : Bool}) -> {Spec.mem(Spec.lang(p, b1), k, w) == Spec.mem(Spec.lang(p, b2), k, w) : Bool}:
  Bound.bound_adequacy(p, w, k, b1, b2, length_bound(w, b1, e1), length_bound(w, b2, e2))

def normalize(+p: P.Pattern, +bound: Nat, +k: Nat, +w: String, ek: {k == Spec.length(w) : Nat}, eb: {Nat.is_le(Spec.length(w), bound) == True{} : Bool}) -> {Spec.mem(Spec.lang(p, bound), k, w) == Spec.matches(p, w) : Bool}:
  %ek : {Spec.mem(Spec.lang(p, bound), k, w) == Spec.mem(Spec.lang(p, Spec.length(w)), _, w) : Bool}
  bound_mem(p, w, k, bound, Spec.length(w), eb, W.le_self(Spec.length(w)))

def any_normalize(+ps: List<&2, P.Pattern>, +bound: Nat, +k: Nat, +w: String, +ek: {k == Spec.length(w) : Nat}, +eb: {Nat.is_le(Spec.length(w), bound) == True{} : Bool}) -> {S.any_mem(ps, bound, k, w) == S.any_matches(ps, w) : Bool}:
  match ps:
    case Nil{}: {==}
    case p <> t:
      %normalize(p, bound, k, w, ek, eb) : {S.any_mem(p <> t, bound, k, w) == (_ || S.any_matches(t, w)) : Bool}
      %any_normalize(t, bound, k, w, ek, eb) : {S.any_mem(p <> t, bound, k, w) == (Spec.mem(Spec.lang(p, bound), k, w) || _) : Bool}
      {==}

def union_normalize(+ps: List<&2, P.Pattern>, +bound: Nat, +k: Nat, +w: String, +ek: {k == Spec.length(w) : Nat}, +eb: {Nat.is_le(Spec.length(w), bound) == True{} : Bool}) -> {Spec.mem(S.union_lang(ps, bound), k, w) == S.any_matches(ps, w) : Bool}:
  %any_normalize(ps, bound, k, w, ek, eb) : {Spec.mem(S.union_lang(ps, bound), k, w) == _ : Bool}
  S.union_mem(ps, bound, k, w)

def and_cong(+x: Bool, +y: Bool, +u: Bool, +v: Bool, ex: {x == u : Bool}, ey: {y == v : Bool}) -> {(x && y) == (u && v) : Bool}:
  %ex : {(x && y) == (_ && v) : Bool}
  %ey : {(x && y) == (x && _) : Bool}
  {==}

def suffix_bound(+b: P.Pattern, +t: String, +j: Nat) -> {Spec.mem(Spec.lang(b, 1n+Spec.length(t)), Spec.length(String.drop(t, j)), String.drop(t, j)) == Spec.mem(Spec.lang(b, Spec.length(t)), Spec.length(String.drop(t, j)), String.drop(t, j)) : Bool}:
  bound_mem(b, String.drop(t, j), Spec.length(String.drop(t, j)), 1n+Spec.length(t), Spec.length(t), W.le_next(Spec.length(String.drop(t, j)), Spec.length(t), W.suffix_le(t, j)), W.suffix_le(t, j))

def prefix_left(+a: P.Pattern, +j: Nat, +c: U32, +t: String, +ej: {Nat.is_le(j, Spec.length(t)) == True{} : Bool}) -> {Spec.mem(Spec.lang(a, 1n+Spec.length(t)), 1n+j, SCon{Chr{c}, String.take(t, j)}) == Spec.matches(a, SCon{Chr{c}, String.take(t, j)}) : Bool}:
  normalize(a, 1n+Spec.length(t), 1n+j, SCon{Chr{c}, String.take(t, j)}, Equal.cong(Nat, Nat, n => 1n+n, j, Spec.length(String.take(t, j)), Equal.sym(Nat, Spec.length(String.take(t, j)), j, W.prefix_length(t, j, ej))), W.prefix_le(t, j))

def prefix_right(+ds: List<&2, P.Pattern>, +j: Nat, +t: String, +ej: {Nat.is_le(j, Spec.length(t)) == True{} : Bool}) -> {Spec.mem(S.union_lang(ds, Spec.length(t)), j, String.take(t, j)) == S.any_matches(ds, String.take(t, j)) : Bool}:
  union_normalize(ds, Spec.length(t), j, String.take(t, j), Equal.sym(Nat, Spec.length(String.take(t, j)), j, W.prefix_length(t, j, ej)), W.prefix_le(t, j))

# One use of the body induction hypothesis accounts for one positive split.
def prefix_step(+a: P.Pattern, +b: P.Pattern, +j: Nat, +c: U32, +t: String, +ej: {Nat.is_le(j, Spec.length(t)) == True{} : Bool}, eh: {Spec.matches(a, SCon{Chr{c}, String.take(t, j)}) == S.any_matches(P.derive(c, a), String.take(t, j)) : Bool}) -> {(Spec.mem(Spec.lang(a, 1n+Spec.length(t)), 1n+j, SCon{Chr{c}, String.take(t, j)}) && Spec.mem(Spec.lang(b, 1n+Spec.length(t)), Spec.length(String.drop(t, j)), String.drop(t, j))) == (Spec.mem(S.union_lang(P.derive(c, a), Spec.length(t)), j, String.take(t, j)) && Spec.mem(Spec.lang(b, Spec.length(t)), Spec.length(String.drop(t, j)), String.drop(t, j))) : Bool}:
  and_cong(Spec.mem(Spec.lang(a, 1n+Spec.length(t)), 1n+j, SCon{Chr{c}, String.take(t, j)}), Spec.mem(Spec.lang(b, 1n+Spec.length(t)), Spec.length(String.drop(t, j)), String.drop(t, j)), Spec.mem(S.union_lang(P.derive(c, a), Spec.length(t)), j, String.take(t, j)), Spec.mem(Spec.lang(b, Spec.length(t)), Spec.length(String.drop(t, j)), String.drop(t, j)), Equal.trans(Bool, Spec.mem(Spec.lang(a, 1n+Spec.length(t)), 1n+j, SCon{Chr{c}, String.take(t, j)}), Spec.matches(a, SCon{Chr{c}, String.take(t, j)}), Spec.mem(S.union_lang(P.derive(c, a), Spec.length(t)), j, String.take(t, j)), prefix_left(a, j, c, t, ej), Equal.trans(Bool, Spec.matches(a, SCon{Chr{c}, String.take(t, j)}), S.any_matches(P.derive(c, a), String.take(t, j)), Spec.mem(S.union_lang(P.derive(c, a), Spec.length(t)), j, String.take(t, j)), eh, Equal.sym(Bool, Spec.mem(S.union_lang(P.derive(c, a), Spec.length(t)), j, String.take(t, j)), S.any_matches(P.derive(c, a), String.take(t, j)), prefix_right(P.derive(c, a), j, t, ej)))), suffix_bound(b, t, j))

def Positive(+a: P.Pattern, +b: P.Pattern, +j: Nat, +c: U32, +t: String) -> Type:
  {S.positive(Spec.lang(a, 1n+Spec.length(t)), Spec.lang(b, 1n+Spec.length(t)), j, c, t) == Spec.mem(Spec.LCat{S.union_lang(P.derive(c, a), Spec.length(t)), Spec.lang(b, Spec.length(t))}, j, t) : Bool}

def positive_zero(+a: P.Pattern, +b: P.Pattern, +c: U32, +t: String, eh: {Spec.matches(a, SCon{Chr{c}, ""}) == S.any_matches(P.derive(c, a), "") : Bool}) -> Positive(a, b, 0n, c, t):
  match t:
    case SNil{}: prefix_step(a, b, 0n, c, "", W.zero_le(0n), eh)
    case SCon{h, u}: prefix_step(a, b, 0n, c, SCon{h, u}, W.zero_le(1n+Spec.length(u)), eh)

def positive_next(+a: P.Pattern, +b: P.Pattern, +j: Nat, +c: U32, +t: String, +ej: {Nat.is_le(1n+j, Spec.length(t)) == True{} : Bool}, eh: {Spec.matches(a, SCon{Chr{c}, String.take(t, 1n+j)}) == S.any_matches(P.derive(c, a), String.take(t, 1n+j)) : Bool}, et: Positive(a, b, j, c, t)) -> Positive(a, b, 1n+j, c, t):
  %prefix_step(a, b, 1n+j, c, t, ej, eh) : {S.positive(Spec.lang(a, 1n+Spec.length(t)), Spec.lang(b, 1n+Spec.length(t)), 1n+j, c, t) == (_ || Spec.mem(Spec.LCat{S.union_lang(P.derive(c, a), Spec.length(t)), Spec.lang(b, Spec.length(t))}, j, t)) : Bool}
  %et : {S.positive(Spec.lang(a, 1n+Spec.length(t)), Spec.lang(b, 1n+Spec.length(t)), 1n+j, c, t) == ((Spec.mem(Spec.lang(a, 1n+Spec.length(t)), 1n+1n+j, SCon{Chr{c}, String.take(t, 1n+j)}) && Spec.mem(Spec.lang(b, 1n+Spec.length(t)), Spec.length(String.drop(t, 1n+j)), String.drop(t, 1n+j))) || _) : Bool}
  {==}

def cat_step_any(+ds: List<&2, P.Pattern>, +empty: Bool, +rs: List<&2, P.Pattern>, +bound: Nat, +k: Nat, +w: String) -> {S.any_mem(P.cat_step(ds, empty, rs), bound, k, w) == (S.any_mem(ds, bound, k, w) || (empty && S.any_mem(rs, bound, k, w))) : Bool}:
  match empty:
    case True{}: S.append_any(ds, rs, bound, k, w)
    case False{}: Equal.sym(Bool, S.any_mem(ds, bound, k, w) || False{}, S.any_mem(ds, bound, k, w), S.or_zero(S.any_mem(ds, bound, k, w)))

def cat_result(+a: P.Pattern, +b: P.Pattern, +c: U32, +t: String) -> {S.any_matches(P.derive(c, P.Cat{a, b}), t) == (Spec.mem(Spec.LCat{S.union_lang(P.derive(c, a), Spec.length(t)), Spec.lang(b, Spec.length(t))}, Spec.length(t), t) || (P.nullable(a) && S.any_matches(P.derive(c, b), t))) : Bool}:
  %Equal.sym(Bool, Spec.mem(Spec.LCat{S.union_lang(P.derive(c, a), Spec.length(t)), Spec.lang(b, Spec.length(t))}, Spec.length(t), t), S.any_mem(P.behind(P.derive(c, a), b), Spec.length(t), Spec.length(t), t), S.behind_union(P.derive(c, a), b, Spec.length(t), Spec.length(t), t)) : {S.any_matches(P.derive(c, P.Cat{a, b}), t) == (_ || (P.nullable(a) && S.any_matches(P.derive(c, b), t))) : Bool}
  %any_normalize(P.derive(c, b), Spec.length(t), Spec.length(t), t, {==}, W.le_self(Spec.length(t))) : {S.any_matches(P.derive(c, P.Cat{a, b}), t) == (S.any_mem(P.behind(P.derive(c, a), b), Spec.length(t), Spec.length(t), t) || (P.nullable(a) && _)) : Bool}
  %any_normalize(P.derive(c, P.Cat{a, b}), Spec.length(t), Spec.length(t), t, {==}, W.le_self(Spec.length(t))) : {_ == (S.any_mem(P.behind(P.derive(c, a), b), Spec.length(t), Spec.length(t), t) || (P.nullable(a) && S.any_mem(P.derive(c, b), Spec.length(t), Spec.length(t), t))) : Bool}
  cat_step_any(P.behind(P.derive(c, a), b), P.nullable(a), P.derive(c, b), Spec.length(t), Spec.length(t), t)

def cat_original(+a: P.Pattern, +b: P.Pattern, +c: U32, +t: String, ep: Positive(a, b, Spec.length(t), c, t)) -> {Spec.matches(P.Cat{a, b}, SCon{Chr{c}, t}) == (Spec.mem(Spec.LCat{S.union_lang(P.derive(c, a), Spec.length(t)), Spec.lang(b, Spec.length(t))}, Spec.length(t), t) || (P.nullable(a) && Spec.matches(b, SCon{Chr{c}, t}))) : Bool}:
  %ep : {Spec.matches(P.Cat{a, b}, SCon{Chr{c}, t}) == (_ || (P.nullable(a) && Spec.matches(b, SCon{Chr{c}, t}))) : Bool}
  %Equal.sym(Bool, P.nullable(a), Empty.nu(Spec.lang(a, 1n+Spec.length(t))), N.nullable_lang(a, 1n+Spec.length(t))) : {Spec.matches(P.Cat{a, b}, SCon{Chr{c}, t}) == (S.positive(Spec.lang(a, 1n+Spec.length(t)), Spec.lang(b, 1n+Spec.length(t)), Spec.length(t), c, t) || (_ && Spec.matches(b, SCon{Chr{c}, t}))) : Bool}
  S.cat_head(Spec.length(t), Spec.lang(a, 1n+Spec.length(t)), Spec.lang(b, 1n+Spec.length(t)), c, t)

def complete(+a: P.Pattern, +b: P.Pattern, +c: U32, +t: String, ep: Positive(a, b, Spec.length(t), c, t), eb: {Spec.matches(b, SCon{Chr{c}, t}) == S.any_matches(P.derive(c, b), t) : Bool}) -> {Spec.matches(P.Cat{a, b}, SCon{Chr{c}, t}) == S.any_matches(P.derive(c, P.Cat{a, b}), t) : Bool}:
  %Equal.sym(Bool, S.any_matches(P.derive(c, P.Cat{a, b}), t), Spec.mem(Spec.LCat{S.union_lang(P.derive(c, a), Spec.length(t)), Spec.lang(b, Spec.length(t))}, Spec.length(t), t) || (P.nullable(a) && S.any_matches(P.derive(c, b), t)), cat_result(a, b, c, t)) : {Spec.matches(P.Cat{a, b}, SCon{Chr{c}, t}) == _ : Bool}
  %eb : {Spec.matches(P.Cat{a, b}, SCon{Chr{c}, t}) == (Spec.mem(Spec.LCat{S.union_lang(P.derive(c, a), Spec.length(t)), Spec.lang(b, Spec.length(t))}, Spec.length(t), t) || (P.nullable(a) && _)) : Bool}
  cat_original(a, b, c, t, ep)
