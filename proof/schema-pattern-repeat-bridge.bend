import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-split.bend as S
import ./schema-pattern-cat.bend as Cat
import ./schema-pattern-empty.bend as E
import ./schema-pattern-nullable.bend as N
import ./schema-pattern-repeat-prefix.bend as F
import ./schema-pattern-repeat-bounded.bend as B
import ./schema-pattern-repeat-unbounded.bend as U

def step_zero(+empty: Bool, +ds: List<&2, P.Pattern>, +r: P.Pattern) -> {P.repeat_step(empty, ds, r, 0n, None{}) == P.behind(ds, P.Repeat{r, 0n, None{}}) : List<&2, P.Pattern>}:
  match empty:
    case False{}: {==}
    case True{}: {==}

def step_next(+empty: Bool, +ds: List<&2, P.Pattern>, +r: P.Pattern, +m: Nat, +t: String) -> {S.any_matches(P.repeat_step(empty, ds, r, 1n+m, None{}), t) == (S.any_matches(P.behind(ds, P.Repeat{r, m, None{}}), t) || (empty && S.any_matches(P.repeat_step(empty, ds, r, m, None{}), t))) : Bool}:
  match empty:
    case False{}: Equal.sym(Bool, S.any_matches(P.behind(ds, P.Repeat{r, m, None{}}), t) || False{}, S.any_matches(P.behind(ds, P.Repeat{r, m, None{}}), t), S.or_zero(S.any_matches(P.behind(ds, P.Repeat{r, m, None{}}), t)))
    case True{}: B.append_matches(P.behind(ds, P.Repeat{r, m, None{}}), P.repeat_empty(ds, r, m, None{}), t)

def minimum_zero(+r: P.Pattern, +c: U32, +t: String, +facts: F.Facts(r, Spec.length(t), c, t), +empty: Bool) -> {Spec.matches(P.Repeat{r, 0n, None{}}, SCon{Chr{c}, t}) == S.any_matches(P.repeat_step(empty, P.derive(c, r), r, 0n, None{}), t) : Bool}:
  %Equal.sym(List<&2, P.Pattern>, P.repeat_step(empty, P.derive(c, r), r, 0n, None{}), P.behind(P.derive(c, r), P.Repeat{r, 0n, None{}}), step_zero(empty, P.derive(c, r), r)) : {Spec.matches(P.Repeat{r, 0n, None{}}, SCon{Chr{c}, t}) == S.any_matches(_, t) : Bool}
  %B.positive(r, 0n, None{}, c, t, facts) : {Spec.matches(P.Repeat{r, 0n, None{}}, SCon{Chr{c}, t}) == _ : Bool}
  U.star_head(Spec.lang(r, 1n+Spec.length(t)), c, t)

# Reassociation is supplied independently of the structural pattern induction.
def head(+m: Nat, +r: P.Pattern, +c: U32, +t: String, +facts: F.Facts(r, Spec.length(t), c, t), reassoc: {Spec.mem(Spec.repeat(Spec.lang(r, 1n+Spec.length(t)), 1n+m, None{}, 1n+Spec.length(t)), 1n+Spec.length(t), SCon{Chr{c}, t}) == Spec.mem(Spec.LCat{Spec.lang(r, 1n+Spec.length(t)), Spec.repeat(Spec.lang(r, 1n+Spec.length(t)), m, None{}, 1n+Spec.length(t))}, 1n+Spec.length(t), SCon{Chr{c}, t}) : Bool}) -> {Spec.matches(P.Repeat{r, 1n+m, None{}}, SCon{Chr{c}, t}) == (S.any_matches(P.behind(P.derive(c, r), P.Repeat{r, m, None{}}), t) || (P.nullable(r) && Spec.matches(P.Repeat{r, m, None{}}, SCon{Chr{c}, t}))) : Bool}:
  %B.positive(r, m, None{}, c, t, facts) : {Spec.matches(P.Repeat{r, 1n+m, None{}}, SCon{Chr{c}, t}) == (_ || (P.nullable(r) && Spec.matches(P.Repeat{r, m, None{}}, SCon{Chr{c}, t}))) : Bool}
  %Equal.sym(Bool, P.nullable(r), E.nu(Spec.lang(r, 1n+Spec.length(t))), N.nullable_lang(r, 1n+Spec.length(t))) : {Spec.matches(P.Repeat{r, 1n+m, None{}}, SCon{Chr{c}, t}) == (S.positive(Spec.lang(r, 1n+Spec.length(t)), Spec.lang(P.Repeat{r, m, None{}}, 1n+Spec.length(t)), Spec.length(t), c, t) || (_ && Spec.matches(P.Repeat{r, m, None{}}, SCon{Chr{c}, t}))) : Bool}
  %S.cat_head(Spec.length(t), Spec.lang(r, 1n+Spec.length(t)), Spec.lang(P.Repeat{r, m, None{}}, 1n+Spec.length(t)), c, t) : {Spec.matches(P.Repeat{r, 1n+m, None{}}, SCon{Chr{c}, t}) == _ : Bool}
  reassoc

def next(+m: Nat, +r: P.Pattern, +c: U32, +t: String, +empty: Bool, en: {P.nullable(r) == empty : Bool}, ehead: {Spec.matches(P.Repeat{r, 1n+m, None{}}, SCon{Chr{c}, t}) == (S.any_matches(P.behind(P.derive(c, r), P.Repeat{r, m, None{}}), t) || (P.nullable(r) && Spec.matches(P.Repeat{r, m, None{}}, SCon{Chr{c}, t}))) : Bool}, etail: {Spec.matches(P.Repeat{r, m, None{}}, SCon{Chr{c}, t}) == S.any_matches(P.repeat_step(empty, P.derive(c, r), r, m, None{}), t) : Bool}) -> {Spec.matches(P.Repeat{r, 1n+m, None{}}, SCon{Chr{c}, t}) == S.any_matches(P.repeat_step(empty, P.derive(c, r), r, 1n+m, None{}), t) : Bool}:
  %Equal.sym(Bool, S.any_matches(P.repeat_step(empty, P.derive(c, r), r, 1n+m, None{}), t), S.any_matches(P.behind(P.derive(c, r), P.Repeat{r, m, None{}}), t) || (empty && S.any_matches(P.repeat_step(empty, P.derive(c, r), r, m, None{}), t)), step_next(empty, P.derive(c, r), r, m, t)) : {Spec.matches(P.Repeat{r, 1n+m, None{}}, SCon{Chr{c}, t}) == _ : Bool}
  %etail : {Spec.matches(P.Repeat{r, 1n+m, None{}}, SCon{Chr{c}, t}) == (S.any_matches(P.behind(P.derive(c, r), P.Repeat{r, m, None{}}), t) || (empty && _)) : Bool}
  %en : {Spec.matches(P.Repeat{r, 1n+m, None{}}, SCon{Chr{c}, t}) == (S.any_matches(P.behind(P.derive(c, r), P.Repeat{r, m, None{}}), t) || (_ && Spec.matches(P.Repeat{r, m, None{}}, SCon{Chr{c}, t}))) : Bool}
  ehead
