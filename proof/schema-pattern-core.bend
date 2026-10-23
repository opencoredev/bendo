# The two facts the derivative matcher rests on: a pattern accepts the empty
# string exactly when `nullable` says so, and it accepts c followed by t
# exactly when one of its derivatives by c accepts t. Both are stated against
# the split-based specification (src/data/schema-spec.bend).
import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-empty.bend as Empty
import ./schema-pattern-split.bend as Split
import ./schema-pattern-cat.bend as Cat
import ./schema-pattern-strings.bend as W

# Some pattern in the list accepts w, per the specification.
def any_matches(ps: List<&2, P.Pattern>, +w: String) -> Bool:
  Split.any_matches(ps, w)

def nullable_equiv(+p: P.Pattern) -> {P.nullable(p) == Spec.matches(p, "") : Bool}:
  Empty.nullable_equiv(p)

# Character equality is symmetric even though String.order visits the
# literal's head before the input head.
def cmp_fin_eq(+a: Bool, +b: Bool, +c: Cmp) -> {Cmp.is_eq(Word.cmp.fin(a, b, c)) == (Cmp.is_eq(c) && Cmp.is_eq(Bool.cmp(a, b))) : Bool}:
  match c:
    case LT{}: {==}
    case GT{}: {==}
    case EQ{}: {==}

def bool_eq_comm(+a: Bool, +b: Bool) -> {Cmp.is_eq(Bool.cmp(a, b)) == Cmp.is_eq(Bool.cmp(b, a)) : Bool}:
  match a b:
    case True{} True{}: {==}
    case True{} False{}: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def word_eq_comm(+n: Nat, +a: Word(n), +b: Word(n)) -> {Cmp.is_eq(Word.cmp(n, a, b)) == Cmp.is_eq(Word.cmp(n, b, a)) : Bool}:
  match n:
    case 0n: {==}
    case 1n+k:
      match a b:
        case WCon{ah, at} WCon{bh, bt}:
          %Equal.sym(Bool, Cmp.is_eq(Word.cmp.fin(bh, ah, Word.cmp(k, bt, at))), (Cmp.is_eq(Word.cmp(k, bt, at)) && Cmp.is_eq(Bool.cmp(bh, ah))), cmp_fin_eq(bh, ah, Word.cmp(k, bt, at))) : {Cmp.is_eq(Word.cmp(1n+k, WCon{ah, at}, WCon{bh, bt})) == _ : Bool}
          %word_eq_comm(k, at, bt) : {Cmp.is_eq(Word.cmp(1n+k, WCon{ah, at}, WCon{bh, bt})) == (_ && Cmp.is_eq(Bool.cmp(bh, ah))) : Bool}
          %bool_eq_comm(ah, bh) : {Cmp.is_eq(Word.cmp(1n+k, WCon{ah, at}, WCon{bh, bt})) == (Cmp.is_eq(Word.cmp(k, at, bt)) && _) : Bool}
          cmp_fin_eq(ah, bh, Word.cmp(k, at, bt))

def u32_eq_comm(+a: U32, +b: U32) -> {U32.is_eq(a, b) == U32.is_eq(b, a) : Bool}:
  match a b:
    case U32{x} U32{y}: word_eq_comm(32n, x, y)

def string_order_eq(+o: Cmp, +a: String, +b: String) -> {Cmp.is_eq(String.order.go(a, b, o)) == (Cmp.is_eq(o) && String.eq(a, b)) : Bool}:
  match o:
    case LT{}:
      match a b:
        case SNil{} SNil{}: {==}
        case SNil{} SCon{Chr{c}, t}: {==}
        case SCon{Chr{c}, t} SNil{}: {==}
        case SCon{Chr{c}, t} SCon{Chr{d}, u}: {==}
    case EQ{}: {==}
    case GT{}:
      match a b:
        case SNil{} SNil{}: {==}
        case SNil{} SCon{Chr{c}, t}: {==}
        case SCon{Chr{c}, t} SNil{}: {==}
        case SCon{Chr{c}, t} SCon{Chr{d}, u}: {==}

def or_false(+a: Bool) -> {a == (a || False{}) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def literal_any(+hit: Bool, +s: String, +t: String) -> {(hit && String.eq(s, t)) == any_matches(P.literal_step(hit, s), t) : Bool}:
  match hit:
    case False{}: {==}
    case True{}: or_false(String.eq(s, t))

def literal_derive(+c: U32, +d: U32, +s: String, +t: String) -> {Spec.matches(P.Literal{SCon{Chr{d}, s}}, SCon{Chr{c}, t}) == any_matches(P.derive(c, P.Literal{SCon{Chr{d}, s}}), t) : Bool}:
  %literal_any(U32.is_eq(c, d), s, t) : {Spec.matches(P.Literal{SCon{Chr{d}, s}}, SCon{Chr{c}, t}) == _ : Bool}
  %u32_eq_comm(d, c) : {Spec.matches(P.Literal{SCon{Chr{d}, s}}, SCon{Chr{c}, t}) == (_ && String.eq(s, t)) : Bool}
  string_order_eq(U32.cmp(d, c), s, t)

def or_assoc(+a: Bool, -b: Bool, -c: Bool) -> {((a || b) || c) == (a || (b || c)) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def ranges_equiv(+rs: List<&2, P.Range>, +c: U32, +found: Bool) -> {P.in_ranges(rs, c, found) == (found || Spec.in_class(rs, c)) : Bool}:
  match rs:
    case Nil{}: or_false(found)
    case P.Range{lo, hi} <> t:
      %or_assoc(found, Spec.within(c, lo, hi), Spec.in_class(t, c)) : {P.in_ranges(P.Range{lo, hi} <> t, c, found) == _ : Bool}
      ranges_equiv(t, c, found || Spec.within(c, lo, hi))

def class_any(+hit: Bool, +t: String) -> {(hit && String.is_empty(t)) == any_matches(P.class_step(hit), t) : Bool}:
  match hit:
    case False{}: {==}
    case True{}:
      match t:
        case SNil{}: {==}
        case SCon{Chr{c}, u}: {==}

def and_false(+a: Bool) -> {(a && False{}) == False{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def class_one(+rs: List<&2, P.Range>, +c: U32, +t: String) -> {Spec.one(rs, SCon{Chr{c}, t}) == (Spec.in_class(rs, c) && String.is_empty(t)) : Bool}:
  match t:
    case SNil{}: Equal.sym(Bool, (Spec.in_class(rs, c) && True{}), Spec.in_class(rs, c), Empty.and_true(Spec.in_class(rs, c)))
    case SCon{h, u}: Equal.sym(Bool, (Spec.in_class(rs, c) && False{}), False{}, and_false(Spec.in_class(rs, c)))

# Cat carries its split iteration inside the structural pattern induction.
def Claim(+p: P.Pattern, +j: Nat, +c: U32, +t: String) -> Type:
  match p:
    case P.Cat{a, b}: Cat.Positive(a, b, j, c, t) & {Spec.matches(b, SCon{Chr{c}, t}) == any_matches(P.derive(c, b), t) : Bool}
    case _: {Spec.matches(p, SCon{Chr{c}, t}) == any_matches(P.derive(c, p), t) : Bool}

def finish(+p: P.Pattern, +c: U32, +t: String, e: Claim(p, Spec.length(t), c, t)) -> {Spec.matches(p, SCon{Chr{c}, t}) == any_matches(P.derive(c, p), t) : Bool}:
  match p:
    case P.Literal{x}: e
    case P.Class{rs}: e
    case P.Cat{a, b}:
      (ep, eb) = e
      Cat.complete(a, b, c, t, ep, eb)
    case P.Repeat{r, m, n}: e

def cat_next(+a: P.Pattern, +b: P.Pattern, +i: Nat, +c: U32, +t: String, +ej: {Nat.is_le(1n+i, Spec.length(t)) == True{} : Bool}, e: Claim(P.Cat{a, b}, i, c, t), eh: {Spec.matches(a, SCon{Chr{c}, String.take(t, 1n+i)}) == any_matches(P.derive(c, a), String.take(t, 1n+i)) : Bool}) -> Claim(P.Cat{a, b}, 1n+i, c, t):
  (ep, eb) = e
  (Cat.positive_next(a, b, i, c, t, ej, eh, ep), eb)

def derive_go(+p: P.Pattern, +j: Nat, +c: U32, +t: String, +ej: {Nat.is_le(j, Spec.length(t)) == True{} : Bool}) -> Claim(p, j, c, t):
  match p:
    case P.Literal{SNil{}}: {==}
    case P.Literal{SCon{Chr{d}, s}}: literal_derive(c, d, s, t)
    case P.Class{rs}:
      %Equal.sym(Bool, P.in_ranges(rs, c, False{}), Spec.in_class(rs, c), ranges_equiv(rs, c, False{})) : {Spec.matches(P.Class{rs}, SCon{Chr{c}, t}) == any_matches(P.class_step(_), t) : Bool}
      %class_any(Spec.in_class(rs, c), t) : {Spec.matches(P.Class{rs}, SCon{Chr{c}, t}) == _ : Bool}
      class_one(rs, c, t)
    case P.Cat{a, b}:
      match j:
        case 0n:
          (Cat.positive_zero(a, b, c, t, finish(a, c, "", derive_go(a, 0n, c, "", {==}))), finish(b, c, t, derive_go(b, Spec.length(t), c, t, W.le_self(Spec.length(t)))))
        case 1n+i:
          cat_next(a, b, i, c, t, ej, derive_go(p, i, c, t, W.le_previous(i, Spec.length(t), ej)), finish(a, c, String.take(t, 1n+i), derive_go(a, Spec.length(String.take(t, 1n+i)), c, String.take(t, 1n+i), W.le_self(Spec.length(String.take(t, 1n+i))))))
    case P.Repeat{r, m, n}: ?TODO

def derive_equiv(+c: U32, +p: P.Pattern, +t: String) -> {Spec.matches(p, SCon{Chr{c}, t}) == any_matches(P.derive(c, p), t) : Bool}:
  finish(p, c, t, derive_go(p, Spec.length(t), c, t, W.le_self(Spec.length(t))))
