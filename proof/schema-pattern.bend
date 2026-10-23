# The derivative matcher agrees with the split-based regular-language
# specification (src/data/schema-spec.bend). The scan, the derivative sets and
# their deduplication are handled here; the two semantic facts they rest on
# are in ./schema-pattern-core.bend.
import Base
import ../LAWS.bend as Laws
import ./equality.bend as E
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec
import ./schema-text.bend as TP
import ./schema-pattern-core.bend as Core

# Validity.

def ranges_go(+rs: List<&2, P.Range>, +ok: Bool) -> {P.ranges_valid(rs, ok) == (ok && Spec.ascii_ranges(rs)) : Bool}:
  match rs ok:
    case Nil{} True{}: {==}
    case Nil{} False{}: {==}
    case P.Range{lo, hi} <> t True{}: ranges_go(t, (lo <= hi : U32) && (hi <= 127 : U32))
    case P.Range{lo, hi} <> t False{}: ranges_go(t, False{})

def at_most_equiv(+n: Maybe<&2, Nat>, -m: Nat) -> {P.at_most(n, m) == Spec.at_most(n, m) : Bool}:
  match n:
    case None{}: {==}
    case Some{k}: {==}

def valid_equiv(+p: P.Pattern) -> {P.valid(p) == Spec.pattern_ok(p) : Bool}:
  match p:
    case P.Literal{x}: TP.scalars_equiv(x)
    case P.Class{rs}: ranges_go(rs, True{})
    case P.Cat{a, b}:
      %valid_equiv(a) : {P.valid(P.Cat{a, b}) == (_ && Spec.pattern_ok(b)) : Bool}
      %valid_equiv(b) : {P.valid(P.Cat{a, b}) == (P.valid(a) && _) : Bool}
      {==}
    case P.Repeat{r, m, n}:
      %valid_equiv(r) : {P.valid(P.Repeat{r, m, n}) == (_ && Spec.at_most(n, m)) : Bool}
      %at_most_equiv(n, m) : {P.valid(P.Repeat{r, m, n}) == (P.valid(r) && _) : Bool}
      {==}

# Structural equality is sound.

def nat_eq_sound(+a: Nat, +b: Nat, e: {Nat.is_eq(a, b) == True{} : Bool}) -> {a == b : Nat}:
  match a b:
    case 0n 0n: {==}
    case 0n 1n+q: E.absurd({0n == 1n+q : Nat}, E.false_true(e))
    case 1n+p 0n: E.absurd({1n+p == 0n : Nat}, E.false_true(e))
    case 1n+p 1n+q: Equal.cong(Nat, Nat, x => 1n+x, p, q, nat_eq_sound(p, q, e))

def and_l(+a: Bool, -b: Bool, e: {(a && b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: e

def and_r(+a: Bool, -b: Bool, e: {(a && b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}: e
    case False{}: E.absurd({b == True{} : Bool}, E.false_true(e))

def ranges_sound(+a: List<&2, P.Range>, +b: List<&2, P.Range>, +e: {P.ranges_same(a, b) == True{} : Bool}) -> {a == b : List<&2, P.Range>}:
  match a b:
    case Nil{} Nil{}: {==}
    case Nil{} h <> t: E.absurd({Nil{} == h <> t : List<&2, P.Range>}, E.false_true(e))
    case h <> t Nil{}: E.absurd({h <> t == Nil{} : List<&2, P.Range>}, E.false_true(e))
    case P.Range{x, y} <> s P.Range{u, v} <> t:
      %Laws.u32_eq_sound(x, u, and_l(U32.is_eq(x, u), U32.is_eq(y, v), and_l(U32.is_eq(x, u) && U32.is_eq(y, v), P.ranges_same(s, t), e))) : {P.Range{x, y} <> s == P.Range{_, v} <> t : List<&2, P.Range>}
      %Laws.u32_eq_sound(y, v, and_r(U32.is_eq(x, u), U32.is_eq(y, v), and_l(U32.is_eq(x, u) && U32.is_eq(y, v), P.ranges_same(s, t), e))) : {P.Range{x, y} <> s == P.Range{x, _} <> t : List<&2, P.Range>}
      %ranges_sound(s, t, and_r(U32.is_eq(x, u) && U32.is_eq(y, v), P.ranges_same(s, t), e)) : {P.Range{x, y} <> s == P.Range{x, y} <> _ : List<&2, P.Range>}
      {==}

def max_sound(+a: Maybe<&2, Nat>, +b: Maybe<&2, Nat>, e: {P.max_same(a, b) == True{} : Bool}) -> {a == b : Maybe<&2, Nat>}:
  match a b:
    case None{} None{}: {==}
    case None{} Some{y}: E.absurd({None{} == Some{y} : Maybe<&2, Nat>}, E.false_true(e))
    case Some{x} None{}: E.absurd({Some{x} == None{} : Maybe<&2, Nat>}, E.false_true(e))
    case Some{x} Some{y}: Equal.cong(Nat, Maybe<&2, Nat>, z => Some{z}, x, y, nat_eq_sound(x, y, e))

def same_sound(+p: P.Pattern, +q: P.Pattern, +e: {P.same(p, q) == True{} : Bool}) -> {p == q : P.Pattern}:
  match p q:
    case P.Literal{x} P.Literal{y}: Equal.cong(String, P.Pattern, z => P.Literal{z}, x, y, Laws.string_eq_sound(x, y, e))
    case P.Class{x} P.Class{y}: Equal.cong(List<&2, P.Range>, P.Pattern, z => P.Class{z}, x, y, ranges_sound(x, y, e))
    case P.Cat{a, b} P.Cat{c, d}:
      %same_sound(a, c, and_l(P.same(a, c), P.same(b, d), e)) : {P.Cat{a, b} == P.Cat{_, d} : P.Pattern}
      %same_sound(b, d, and_r(P.same(a, c), P.same(b, d), e)) : {P.Cat{a, b} == P.Cat{a, _} : P.Pattern}
      {==}
    case P.Repeat{r, m, n} P.Repeat{s, k, l}:
      %same_sound(r, s, and_l(P.same(r, s), Nat.is_eq(m, k), and_l(P.same(r, s) && Nat.is_eq(m, k), P.max_same(n, l), e))) : {P.Repeat{r, m, n} == P.Repeat{_, k, l} : P.Pattern}
      %nat_eq_sound(m, k, and_r(P.same(r, s), Nat.is_eq(m, k), and_l(P.same(r, s) && Nat.is_eq(m, k), P.max_same(n, l), e))) : {P.Repeat{r, m, n} == P.Repeat{r, _, l} : P.Pattern}
      %max_sound(n, l, and_r(P.same(r, s) && Nat.is_eq(m, k), P.max_same(n, l), e)) : {P.Repeat{r, m, n} == P.Repeat{r, m, _} : P.Pattern}
      {==}
    case P.Literal{x} P.Class{y}: E.absurd({P.Literal{x} == P.Class{y} : P.Pattern}, E.false_true(e))
    case P.Literal{x} P.Cat{c, d}: E.absurd({P.Literal{x} == P.Cat{c, d} : P.Pattern}, E.false_true(e))
    case P.Literal{x} P.Repeat{s, k, l}: E.absurd({P.Literal{x} == P.Repeat{s, k, l} : P.Pattern}, E.false_true(e))
    case P.Class{x} P.Literal{y}: E.absurd({P.Class{x} == P.Literal{y} : P.Pattern}, E.false_true(e))
    case P.Class{x} P.Cat{c, d}: E.absurd({P.Class{x} == P.Cat{c, d} : P.Pattern}, E.false_true(e))
    case P.Class{x} P.Repeat{s, k, l}: E.absurd({P.Class{x} == P.Repeat{s, k, l} : P.Pattern}, E.false_true(e))
    case P.Cat{a, b} P.Literal{y}: E.absurd({P.Cat{a, b} == P.Literal{y} : P.Pattern}, E.false_true(e))
    case P.Cat{a, b} P.Class{y}: E.absurd({P.Cat{a, b} == P.Class{y} : P.Pattern}, E.false_true(e))
    case P.Cat{a, b} P.Repeat{s, k, l}: E.absurd({P.Cat{a, b} == P.Repeat{s, k, l} : P.Pattern}, E.false_true(e))
    case P.Repeat{r, m, n} P.Literal{y}: E.absurd({P.Repeat{r, m, n} == P.Literal{y} : P.Pattern}, E.false_true(e))
    case P.Repeat{r, m, n} P.Class{y}: E.absurd({P.Repeat{r, m, n} == P.Class{y} : P.Pattern}, E.false_true(e))
    case P.Repeat{r, m, n} P.Cat{c, d}: E.absurd({P.Repeat{r, m, n} == P.Cat{c, d} : P.Pattern}, E.false_true(e))

# Boolean bookkeeping.

def or_false(+a: Bool) -> {a == (a || False{}) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def or_assoc(+a: Bool, -b: Bool, -c: Bool) -> {((a || b) || c) == (a || (b || c)) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def or_comm(+a: Bool, +b: Bool) -> {(a || b) == (b || a) : Bool}:
  match a b:
    case True{} True{}: {==}
    case True{} False{}: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def or_again(+a: Bool, +b: Bool) -> {((a || b) || a) == (a || b) : Bool}:
  match a b:
    case True{} _: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

# Deduplication keeps the accepted language.

def contains(ps: List<&2, P.Pattern>, +q: P.Pattern) -> Bool:
  match ps:
    case Nil{}: False{}
    case p <> t: P.same(p, q) || contains(t, q)

def member_contains(+ps: List<&2, P.Pattern>, +q: P.Pattern, +found: Bool) -> {P.member(ps, q, found) == (found || contains(ps, q)) : Bool}:
  match ps:
    case Nil{}: or_false(found)
    case p <> t:
      %or_assoc(found, P.same(p, q), contains(t, q)) : {P.member(p <> t, q, found) == _ : Bool}
      member_contains(t, q, found || P.same(p, q))

def absorb_hit(+p: P.Pattern, +t: List<&2, P.Pattern>, +q: P.Pattern, +w: String, eb: {P.same(p, q) == True{} : Bool}) -> {((Spec.matches(p, w) || Core.any_matches(t, w)) || Spec.matches(q, w)) == (Spec.matches(p, w) || Core.any_matches(t, w)) : Bool}:
  %same_sound(p, q, eb) : {((Spec.matches(p, w) || Core.any_matches(t, w)) || Spec.matches(_, w)) == (Spec.matches(p, w) || Core.any_matches(t, w)) : Bool}
  or_again(Spec.matches(p, w), Core.any_matches(t, w))

# A pattern already in the set adds nothing to the accepted language.
def absorb(+t: List<&2, P.Pattern>, +p: P.Pattern, +q: P.Pattern, +w: String, b: Bool) -> {P.same(p, q) == b : Bool} -> {(b || contains(t, q)) == True{} : Bool} -> {((Spec.matches(p, w) || Core.any_matches(t, w)) || Spec.matches(q, w)) == (Spec.matches(p, w) || Core.any_matches(t, w)) : Bool}:
  match t b:
    case Nil{} True{}: eb => e => absorb_hit(p, [], q, w, eb)
    case Nil{} False{}: eb => e => E.absurd({((Spec.matches(p, w) || False{}) || Spec.matches(q, w)) == (Spec.matches(p, w) || False{}) : Bool}, E.false_true(e))
    case h <> u True{}: eb => e => absorb_hit(p, h <> u, q, w, eb)
    case h <> u False{}: eb => e =>
      %Equal.sym(Bool, ((Spec.matches(p, w) || Core.any_matches(h <> u, w)) || Spec.matches(q, w)), (Spec.matches(p, w) || (Core.any_matches(h <> u, w) || Spec.matches(q, w))), or_assoc(Spec.matches(p, w), Core.any_matches(h <> u, w), Spec.matches(q, w))) : {_ == (Spec.matches(p, w) || Core.any_matches(h <> u, w)) : Bool}
      %Equal.sym(Bool, (Core.any_matches(h <> u, w) || Spec.matches(q, w)), Core.any_matches(h <> u, w), absorb(u, h, q, w, P.same(h, q))({==})(e)) : {(Spec.matches(p, w) || _) == (Spec.matches(p, w) || Core.any_matches(h <> u, w)) : Bool}
      {==}

def contained(+acc: List<&2, P.Pattern>, +q: P.Pattern, +w: String, e: {contains(acc, q) == True{} : Bool}) -> {Core.any_matches(acc, w) == (Core.any_matches(acc, w) || Spec.matches(q, w)) : Bool}:
  match acc:
    case Nil{}: E.absurd({False{} == (False{} || Spec.matches(q, w)) : Bool}, E.false_true(e))
    case p <> t: Equal.sym(Bool, ((Spec.matches(p, w) || Core.any_matches(t, w)) || Spec.matches(q, w)), (Spec.matches(p, w) || Core.any_matches(t, w)), absorb(t, p, q, w, P.same(p, q))({==})(e))

def insert_any(b: Bool, +q: P.Pattern, +acc: List<&2, P.Pattern>, +w: String) -> {P.member(acc, q, False{}) == b : Bool} -> {Core.any_matches(P.insert(b, q, acc), w) == (Core.any_matches(acc, w) || Spec.matches(q, w)) : Bool}:
  match b:
    case True{}: e => contained(acc, q, w, Equal.trans(Bool, contains(acc, q), P.member(acc, q, False{}), True{}, Equal.sym(Bool, P.member(acc, q, False{}), contains(acc, q), member_contains(acc, q, False{})), e))
    case False{}: e => or_comm(Spec.matches(q, w), Core.any_matches(acc, w))

def add_all_any(+xs: List<&2, P.Pattern>, +acc: List<&2, P.Pattern>, +w: String) -> {Core.any_matches(P.add_all(xs, acc), w) == (Core.any_matches(acc, w) || Core.any_matches(xs, w)) : Bool}:
  match xs:
    case Nil{}: or_false(Core.any_matches(acc, w))
    case q <> t:
      %or_assoc(Core.any_matches(acc, w), Spec.matches(q, w), Core.any_matches(t, w)) : {Core.any_matches(P.add_all(q <> t, acc), w) == _ : Bool}
      %insert_any(P.member(acc, q, False{}), q, acc, w)({==}) : {Core.any_matches(P.add_all(q <> t, acc), w) == (_ || Core.any_matches(t, w)) : Bool}
      add_all_any(t, P.insert(P.member(acc, q, False{}), q, acc), w)

def step_any(+ps: List<&2, P.Pattern>, +c: U32, +acc: List<&2, P.Pattern>, +t: String) -> {Core.any_matches(P.step(ps, c, acc), t) == (Core.any_matches(acc, t) || Core.any_matches(ps, SCon{Chr{c}, t})) : Bool}:
  match ps:
    case Nil{}: or_false(Core.any_matches(acc, t))
    case q <> rest:
      %Equal.sym(Bool, Spec.matches(q, SCon{Chr{c}, t}), Core.any_matches(P.derive(c, q), t), Core.derive_equiv(c, q, t)) : {Core.any_matches(P.step(q <> rest, c, acc), t) == (Core.any_matches(acc, t) || (_ || Core.any_matches(rest, SCon{Chr{c}, t}))) : Bool}
      %or_assoc(Core.any_matches(acc, t), Core.any_matches(P.derive(c, q), t), Core.any_matches(rest, SCon{Chr{c}, t})) : {Core.any_matches(P.step(q <> rest, c, acc), t) == _ : Bool}
      %add_all_any(P.derive(c, q), acc, t) : {Core.any_matches(P.step(q <> rest, c, acc), t) == (_ || Core.any_matches(rest, SCon{Chr{c}, t})) : Bool}
      step_any(rest, c, P.add_all(P.derive(c, q), acc), t)

def nullable_any(+ps: List<&2, P.Pattern>, +found: Bool) -> {P.any_nullable(ps, found) == (found || Core.any_matches(ps, "")) : Bool}:
  match ps:
    case Nil{}: or_false(found)
    case p <> t:
      %Core.nullable_equiv(p) : {P.any_nullable(p <> t, found) == (found || (_ || Core.any_matches(t, ""))) : Bool}
      %or_assoc(found, P.nullable(p), Core.any_matches(t, "")) : {P.any_nullable(p <> t, found) == _ : Bool}
      nullable_any(t, found || P.nullable(p))

def run_any(+w: String, +ps: List<&2, P.Pattern>) -> {P.run(w, ps) == Core.any_matches(ps, w) : Bool}:
  match w:
    case SNil{}: nullable_any(ps, False{})
    case SCon{Chr{c}, t}: Equal.trans(Bool, P.run(t, P.step(ps, c, [])), Core.any_matches(P.step(ps, c, []), t), Core.any_matches(ps, SCon{Chr{c}, t}), run_any(t, P.step(ps, c, [])), step_any(ps, c, [], t))

def matches_equiv(+p: P.Pattern, +s: String) -> {P.matches(p, s) == Spec.matches(p, s) : Bool}:
  %Equal.sym(Bool, Spec.matches(p, s), (Spec.matches(p, s) || False{}), or_false(Spec.matches(p, s))) : {P.matches(p, s) == _ : Bool}
  run_any(s, [p])
