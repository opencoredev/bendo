# The automaton's arcs are the derivatives: firing a pattern's linear form by
# a scalar gives exactly `P.derive`, list for list. So a pattern accepts c·t
# exactly when one of its arcs reads c and leaves a residual accepting t.
import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-pattern-automaton.bend as A
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-core.bend as Core

def keep(h: Bool, d: P.Pattern, rest: List<&2, P.Pattern>) -> List<&2, P.Pattern>:
  match h:
    case True{}: d <> rest
    case False{}: rest

# The residuals of the arcs that read c, in order.
def fire(xs: List<&2, A.Arc>, +c: U32) -> List<&2, P.Pattern>:
  match xs:
    case Nil{}: []
    case A.Arc{a, d} <> t: keep(A.hit(a, c), d, fire(t, c))

def keep_append(+h: Bool, -d: P.Pattern, -xs: List<&2, P.Pattern>, -ys: List<&2, P.Pattern>) -> {keep(h, d, List.append(&2, P.Pattern, xs, ys)) == List.append(&2, P.Pattern, keep(h, d, xs), ys) : List<&2, P.Pattern>}:
  match h:
    case True{}: {==}
    case False{}: {==}

def fire_append(+xs: List<&2, A.Arc>, +ys: List<&2, A.Arc>, +c: U32) -> {fire(List.append(&2, A.Arc, xs, ys), c) == List.append(&2, P.Pattern, fire(xs, c), fire(ys, c)) : List<&2, P.Pattern>}:
  match xs:
    case Nil{}: {==}
    case A.Arc{a, d} <> t:
      %keep_append(A.hit(a, c), d, fire(t, c), fire(ys, c)) : {keep(A.hit(a, c), d, fire(List.append(&2, A.Arc, t, ys), c)) == _ : List<&2, P.Pattern>}
      %fire_append(t, ys, c) : {keep(A.hit(a, c), d, fire(List.append(&2, A.Arc, t, ys), c)) == keep(A.hit(a, c), d, _) : List<&2, P.Pattern>}
      {==}

def keep_behind(+h: Bool, -d: P.Pattern, -xs: List<&2, P.Pattern>, -rest: P.Pattern) -> {keep(h, P.Cat{d, rest}, P.behind(xs, rest)) == P.behind(keep(h, d, xs), rest) : List<&2, P.Pattern>}:
  match h:
    case True{}: {==}
    case False{}: {==}

def fire_behind(+xs: List<&2, A.Arc>, +rest: P.Pattern, +c: U32) -> {fire(A.behind(xs, rest), c) == P.behind(fire(xs, c), rest) : List<&2, P.Pattern>}:
  match xs:
    case Nil{}: {==}
    case A.Arc{a, d} <> t:
      %keep_behind(A.hit(a, c), d, fire(t, c), rest) : {keep(A.hit(a, c), P.Cat{d, rest}, fire(A.behind(t, rest), c)) == _ : List<&2, P.Pattern>}
      %fire_behind(t, rest, c) : {keep(A.hit(a, c), P.Cat{d, rest}, fire(A.behind(t, rest), c)) == keep(A.hit(a, c), P.Cat{d, rest}, _) : List<&2, P.Pattern>}
      {==}

def fire_cat(+left: List<&2, A.Arc>, +e: Bool, +right: List<&2, A.Arc>, +c: U32) -> {fire(A.cat_arcs(left, e, right), c) == P.cat_step(fire(left, c), e, fire(right, c)) : List<&2, P.Pattern>}:
  match e:
    case True{}: fire_append(left, right, c)
    case False{}: {==}

def fire_once(+go: Bool, +xs: List<&2, A.Arc>, +r: P.Pattern, +m: Nat, +n: Maybe<&2, Nat>, +c: U32) -> {fire(A.repeat_once(go, xs, r, m, n), c) == P.repeat_once(go, fire(xs, c), r, m, n) : List<&2, P.Pattern>}:
  match go:
    case True{}: fire_behind(xs, P.Repeat{r, P.pred(m), P.less(n)}, c)
    case False{}: {==}

def fire_empty(+xs: List<&2, A.Arc>, +r: P.Pattern, +m: Nat, +n: Maybe<&2, Nat>, +c: U32) -> {fire(A.repeat_empty(xs, r, m, n), c) == P.repeat_empty(fire(xs, c), r, m, n) : List<&2, P.Pattern>}:
  match m:
    case 0n: fire_once(P.open(n), xs, r, 0n, n, c)
    case 1n+k:
      %fire_empty(xs, r, k, P.less(n), c) : {fire(A.repeat_empty(xs, r, 1n+k, n), c) == List.append(&2, P.Pattern, P.repeat_once(P.open(n), fire(xs, c), r, 1n+k, n), _) : List<&2, P.Pattern>}
      %fire_once(P.open(n), xs, r, 1n+k, n, c) : {fire(A.repeat_empty(xs, r, 1n+k, n), c) == List.append(&2, P.Pattern, _, fire(A.repeat_empty(xs, r, k, P.less(n)), c)) : List<&2, P.Pattern>}
      %fire_append(A.repeat_once(P.open(n), xs, r, 1n+k, n), A.repeat_empty(xs, r, k, P.less(n)), c) : {fire(A.repeat_empty(xs, r, 1n+k, n), c) == _ : List<&2, P.Pattern>}
      {==}

def fire_repeat(+e: Bool, +xs: List<&2, A.Arc>, +r: P.Pattern, +m: Nat, +n: Maybe<&2, Nat>, +c: U32) -> {fire(A.repeat_arcs(e, xs, r, m, n), c) == P.repeat_step(e, fire(xs, c), r, m, n) : List<&2, P.Pattern>}:
  match e:
    case True{}: fire_empty(xs, r, m, n, c)
    case False{}: fire_once(P.open(n), xs, r, m, n, c)

def keep_class(+h: Bool) -> {keep(h, P.Literal{""}, []) == P.class_step(h) : List<&2, P.Pattern>}:
  match h:
    case True{}: {==}
    case False{}: {==}

def keep_literal(+h: Bool, -t: String) -> {keep(h, P.Literal{t}, []) == P.literal_step(h, t) : List<&2, P.Pattern>}:
  match h:
    case True{}: {==}
    case False{}: {==}

def fire_linear(+c: U32, +p: P.Pattern) -> {fire(A.linear(p), c) == P.derive(c, p) : List<&2, P.Pattern>}:
  match p:
    case P.Literal{SNil{}}: {==}
    case P.Literal{SCon{Chr{d}, t}}: keep_literal(U32.is_eq(c, d), t)
    case P.Class{rs}: keep_class(P.in_ranges(rs, c, False{}))
    case P.Cat{a, b}:
      %fire_linear(c, a) : {fire(A.linear(P.Cat{a, b}), c) == P.cat_step(P.behind(_, b), P.nullable(a), P.derive(c, b)) : List<&2, P.Pattern>}
      %fire_linear(c, b) : {fire(A.linear(P.Cat{a, b}), c) == P.cat_step(P.behind(fire(A.linear(a), c), b), P.nullable(a), _) : List<&2, P.Pattern>}
      %fire_behind(A.linear(a), b, c) : {fire(A.linear(P.Cat{a, b}), c) == P.cat_step(_, P.nullable(a), fire(A.linear(b), c)) : List<&2, P.Pattern>}
      %fire_cat(A.behind(A.linear(a), b), P.nullable(a), A.linear(b), c) : {fire(A.linear(P.Cat{a, b}), c) == _ : List<&2, P.Pattern>}
      {==}
    case P.Repeat{r, m, n}:
      %fire_linear(c, r) : {fire(A.linear(P.Repeat{r, m, n}), c) == P.repeat_step(P.nullable(r), _, r, m, n) : List<&2, P.Pattern>}
      %fire_repeat(P.nullable(r), A.linear(r), r, m, n, c) : {fire(A.linear(P.Repeat{r, m, n}), c) == _ : List<&2, P.Pattern>}
      {==}

# Some arc reads c and leaves a residual that accepts t.
def arcs_lang(xs: List<&2, A.Arc>, +c: U32, +t: String) -> Bool:
  match xs:
    case Nil{}: False{}
    case A.Arc{a, d} <> r: (A.hit(a, c) && Spec.matches(d, t)) || arcs_lang(r, c, t)

def keep_any(+h: Bool, +d: P.Pattern, -rest: List<&2, P.Pattern>, +t: String) -> {Core.any_matches(keep(h, d, rest), t) == ((h && Spec.matches(d, t)) || Core.any_matches(rest, t)) : Bool}:
  match h:
    case True{}: {==}
    case False{}: {==}

def fire_any(+xs: List<&2, A.Arc>, +c: U32, +t: String) -> {Core.any_matches(fire(xs, c), t) == arcs_lang(xs, c, t) : Bool}:
  match xs:
    case Nil{}: {==}
    case A.Arc{a, d} <> r:
      %fire_any(r, c, t) : {Core.any_matches(fire(A.Arc{a, d} <> r, c), t) == ((A.hit(a, c) && Spec.matches(d, t)) || _) : Bool}
      %keep_any(A.hit(a, c), d, fire(r, c), t) : {Core.any_matches(fire(A.Arc{a, d} <> r, c), t) == _ : Bool}
      {==}

# The fact the automaton rests on.
def arcs_equiv(+p: P.Pattern, +c: U32, +t: String) -> {Spec.matches(p, SCon{Chr{c}, t}) == arcs_lang(A.linear(p), c, t) : Bool}:
  %fire_any(A.linear(p), c, t) : {Spec.matches(p, SCon{Chr{c}, t}) == _ : Bool}
  %Equal.sym(List<&2, P.Pattern>, fire(A.linear(p), c), P.derive(c, p), fire_linear(c, p)) : {Spec.matches(p, SCon{Chr{c}, t}) == Core.any_matches(_, t) : Bool}
  Core.derive_equiv(c, p, t)
