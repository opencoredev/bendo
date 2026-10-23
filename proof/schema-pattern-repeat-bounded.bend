import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-split.bend as S
import ./schema-pattern-cat.bend as Cat
import ./schema-pattern-empty.bend as E
import ./schema-pattern-nullable.bend as N
import ./schema-pattern-strings.bend as W
import ./schema-pattern-repeat-prefix.bend as F
import ./schema-pattern-repeat-algebra.bend as A
import ./schema-pattern-repeat-bounded-head.bend as H

def closed_empty(+ds: List<&2, P.Pattern>, +r: P.Pattern, +m: Nat) -> {P.repeat_empty(ds, r, m, Some{0n}) == [] : List<&2, P.Pattern>}:
  match m:
    case 0n: {==}
    case 1n+i: closed_empty(ds, r, i)

def closed_step(+empty: Bool, +ds: List<&2, P.Pattern>, +r: P.Pattern, +m: Nat) -> {P.repeat_step(empty, ds, r, m, Some{0n}) == [] : List<&2, P.Pattern>}:
  match empty:
    case False{}: {==}
    case True{}: closed_empty(ds, r, m)

def zero_counts(+m: Nat, +l: Spec.Lang, +k: Nat, +c: U32, +t: String) -> {Spec.mem(Spec.counts(l, m, 0n), k, SCon{Chr{c}, t}) == False{} : Bool}:
  match m:
    case 0n: {==}
    case 1n+i: {==}

def once(+r: P.Pattern, +m: Nat, +n: Maybe<&2, Nat>, +c: U32, +t: String) -> {Spec.mem(Spec.LCat{S.union_lang(P.derive(c, r), Spec.length(t)), Spec.lang(P.Repeat{r, m, n}, Spec.length(t))}, Spec.length(t), t) == S.any_matches(P.behind(P.derive(c, r), P.Repeat{r, m, n}), t) : Bool}:
  %Cat.any_normalize(P.behind(P.derive(c, r), P.Repeat{r, m, n}), Spec.length(t), Spec.length(t), t, {==}, W.le_self(Spec.length(t))) : {Spec.mem(Spec.LCat{S.union_lang(P.derive(c, r), Spec.length(t)), Spec.lang(P.Repeat{r, m, n}, Spec.length(t))}, Spec.length(t), t) == _ : Bool}
  S.behind_union(P.derive(c, r), P.Repeat{r, m, n}, Spec.length(t), Spec.length(t), t)

# The body certificate can be reused at every trailing repetition count.
def positive(+r: P.Pattern, +m: Nat, +n: Maybe<&2, Nat>, +c: U32, +t: String, +facts: F.Facts(r, Spec.length(t), c, t)) -> {S.positive(Spec.lang(r, 1n+Spec.length(t)), Spec.lang(P.Repeat{r, m, n}, 1n+Spec.length(t)), Spec.length(t), c, t) == S.any_matches(P.behind(P.derive(c, r), P.Repeat{r, m, n}), t) : Bool}:
  Equal.trans(Bool, S.positive(Spec.lang(r, 1n+Spec.length(t)), Spec.lang(P.Repeat{r, m, n}, 1n+Spec.length(t)), Spec.length(t), c, t), Spec.mem(Spec.LCat{S.union_lang(P.derive(c, r), Spec.length(t)), Spec.lang(P.Repeat{r, m, n}, Spec.length(t))}, Spec.length(t), t), S.any_matches(P.behind(P.derive(c, r), P.Repeat{r, m, n}), t), F.positive(r, P.Repeat{r, m, n}, Spec.length(t), c, t, W.le_self(Spec.length(t)), facts), once(r, m, n, c, t))

def head(+m: Nat, +n: Nat, +r: P.Pattern, +c: U32, +t: String, +facts: F.Facts(r, Spec.length(t), c, t)) -> {Spec.matches(P.Repeat{r, 1n+m, Some{1n+n}}, SCon{Chr{c}, t}) == (S.any_matches(P.behind(P.derive(c, r), P.Repeat{r, m, Some{n}}), t) || (P.nullable(r) && Spec.matches(P.Repeat{r, m, Some{n}}, SCon{Chr{c}, t}))) : Bool}:
  %positive(r, m, Some{n}, c, t, facts) : {Spec.matches(P.Repeat{r, 1n+m, Some{1n+n}}, SCon{Chr{c}, t}) == (_ || (P.nullable(r) && Spec.matches(P.Repeat{r, m, Some{n}}, SCon{Chr{c}, t}))) : Bool}
  %Equal.sym(Bool, P.nullable(r), E.nu(Spec.lang(r, 1n+Spec.length(t))), N.nullable_lang(r, 1n+Spec.length(t))) : {Spec.matches(P.Repeat{r, 1n+m, Some{1n+n}}, SCon{Chr{c}, t}) == (S.positive(Spec.lang(r, 1n+Spec.length(t)), Spec.lang(P.Repeat{r, m, Some{n}}, 1n+Spec.length(t)), Spec.length(t), c, t) || (_ && Spec.matches(P.Repeat{r, m, Some{n}}, SCon{Chr{c}, t}))) : Bool}
  %S.cat_head(Spec.length(t), Spec.lang(r, 1n+Spec.length(t)), Spec.lang(P.Repeat{r, m, Some{n}}, 1n+Spec.length(t)), c, t) : {Spec.matches(P.Repeat{r, 1n+m, Some{1n+n}}, SCon{Chr{c}, t}) == _ : Bool}
  A.counts_head(1n+m, n, Spec.lang(r, 1n+Spec.length(t)), 1n+Spec.length(t), c, t)

def append_matches(+ps: List<&2, P.Pattern>, +qs: List<&2, P.Pattern>, +t: String) -> {S.any_matches(List.append(&2, P.Pattern, ps, qs), t) == (S.any_matches(ps, t) || S.any_matches(qs, t)) : Bool}:
  match ps:
    case Nil{}: {==}
    case p <> rest:
      %S.or_assoc(Spec.matches(p, t), S.any_matches(rest, t), S.any_matches(qs, t)) : {S.any_matches(List.append(&2, P.Pattern, p <> rest, qs), t) == _ : Bool}
      %append_matches(rest, qs, t) : {S.any_matches(List.append(&2, P.Pattern, p <> rest, qs), t) == (Spec.matches(p, t) || _) : Bool}
      {==}

def step_zero(+empty: Bool, +ds: List<&2, P.Pattern>, +r: P.Pattern, +n: Nat) -> {P.repeat_step(empty, ds, r, 0n, Some{1n+n}) == P.behind(ds, P.Repeat{r, 0n, Some{n}}) : List<&2, P.Pattern>}:
  match empty:
    case False{}: {==}
    case True{}: {==}

def step_next(+empty: Bool, +ds: List<&2, P.Pattern>, +r: P.Pattern, +m: Nat, +n: Nat, +t: String) -> {S.any_matches(P.repeat_step(empty, ds, r, 1n+m, Some{1n+n}), t) == (S.any_matches(P.behind(ds, P.Repeat{r, m, Some{n}}), t) || (empty && S.any_matches(P.repeat_step(empty, ds, r, m, Some{n}), t))) : Bool}:
  match empty:
    case False{}: Equal.sym(Bool, S.any_matches(P.behind(ds, P.Repeat{r, m, Some{n}}), t) || False{}, S.any_matches(P.behind(ds, P.Repeat{r, m, Some{n}}), t), S.or_zero(S.any_matches(P.behind(ds, P.Repeat{r, m, Some{n}}), t)))
    case True{}: append_matches(P.behind(ds, P.Repeat{r, m, Some{n}}), P.repeat_empty(ds, r, m, Some{n}), t)

def minimum_zero(+n: Nat, +r: P.Pattern, +c: U32, +t: String, +facts: F.Facts(r, Spec.length(t), c, t), +empty: Bool) -> {Spec.matches(P.Repeat{r, 0n, Some{1n+n}}, SCon{Chr{c}, t}) == S.any_matches(P.repeat_step(empty, P.derive(c, r), r, 0n, Some{1n+n}), t) : Bool}:
  %Equal.sym(List<&2, P.Pattern>, P.repeat_step(empty, P.derive(c, r), r, 0n, Some{1n+n}), P.behind(P.derive(c, r), P.Repeat{r, 0n, Some{n}}), step_zero(empty, P.derive(c, r), r, n)) : {Spec.matches(P.Repeat{r, 0n, Some{1n+n}}, SCon{Chr{c}, t}) == S.any_matches(_, t) : Bool}
  %positive(r, 0n, Some{n}, c, t, facts) : {Spec.matches(P.Repeat{r, 0n, Some{1n+n}}, SCon{Chr{c}, t}) == _ : Bool}
  H.zero_head(n, Spec.lang(r, 1n+Spec.length(t)), c, t)

def bounded(+n: Nat, +m: Nat, +r: P.Pattern, +c: U32, +t: String, +facts: F.Facts(r, Spec.length(t), c, t), +empty: Bool, +en: {P.nullable(r) == empty : Bool}) -> {Spec.matches(P.Repeat{r, m, Some{n}}, SCon{Chr{c}, t}) == S.any_matches(P.repeat_step(empty, P.derive(c, r), r, m, Some{n}), t) : Bool}:
  match n:
    case 0n:
      %Equal.sym(List<&2, P.Pattern>, P.repeat_step(empty, P.derive(c, r), r, m, Some{0n}), [], closed_step(empty, P.derive(c, r), r, m)) : {Spec.matches(P.Repeat{r, m, Some{0n}}, SCon{Chr{c}, t}) == S.any_matches(_, t) : Bool}
      zero_counts(m, Spec.lang(r, 1n+Spec.length(t)), 1n+Spec.length(t), c, t)
    case 1n+i:
      match m:
        case 0n: minimum_zero(i, r, c, t, facts, empty)
        case 1n+j:
          %Equal.sym(Bool, S.any_matches(P.repeat_step(empty, P.derive(c, r), r, 1n+j, Some{1n+i}), t), S.any_matches(P.behind(P.derive(c, r), P.Repeat{r, j, Some{i}}), t) || (empty && S.any_matches(P.repeat_step(empty, P.derive(c, r), r, j, Some{i}), t)), step_next(empty, P.derive(c, r), r, j, i, t)) : {Spec.matches(P.Repeat{r, 1n+j, Some{1n+i}}, SCon{Chr{c}, t}) == _ : Bool}
          %bounded(i, j, r, c, t, facts, empty, en) : {Spec.matches(P.Repeat{r, 1n+j, Some{1n+i}}, SCon{Chr{c}, t}) == (S.any_matches(P.behind(P.derive(c, r), P.Repeat{r, j, Some{i}}), t) || (empty && _)) : Bool}
          %en : {Spec.matches(P.Repeat{r, 1n+j, Some{1n+i}}, SCon{Chr{c}, t}) == (S.any_matches(P.behind(P.derive(c, r), P.Repeat{r, j, Some{i}}), t) || (_ && Spec.matches(P.Repeat{r, j, Some{i}}, SCon{Chr{c}, t}))) : Bool}
          head(j, i, r, c, t, facts)
