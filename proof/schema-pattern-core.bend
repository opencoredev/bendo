# The two facts the derivative matcher rests on: a pattern accepts the empty
# string exactly when `nullable` says so, and it accepts c followed by t
# exactly when one of its derivatives by c accepts t. Both are stated against
# the split-based specification (src/data/schema-spec.bend).
import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec

# Some pattern in the list accepts w, per the specification.
def any_matches(ps: List<&2, P.Pattern>, +w: String) -> Bool:
  match ps:
    case Nil{}: False{}
    case p <> t: Spec.matches(p, w) || any_matches(t, w)

# Empty-word semantics do not depend on a split counter or a word bound.
def nu(l: Spec.Lang) -> Bool:
  match l:
    case Spec.LNone{}: False{}
    case Spec.LEmpty{}: True{}
    case Spec.LText{x}: String.is_empty(x)
    case Spec.LOne{rs}: False{}
    case Spec.LNonEmpty{a}: False{}
    case Spec.LCat{a, b}: nu(a) && nu(b)
    case Spec.LOr{a, b}: nu(a) || nu(b)

def text_empty(+s: String) -> {String.eq(s, "") == String.is_empty(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: {==}

def mem_empty(+l: Spec.Lang) -> {Spec.mem(l, 0n, "") == nu(l) : Bool}:
  match l:
    case Spec.LNone{}: {==}
    case Spec.LEmpty{}: {==}
    case Spec.LText{x}: text_empty(x)
    case Spec.LOne{rs}: {==}
    case Spec.LNonEmpty{a}: {==}
    case Spec.LCat{a, b}:
      %mem_empty(a) : {Spec.mem(Spec.LCat{a, b}, 0n, "") == (_ && nu(b)) : Bool}
      %mem_empty(b) : {Spec.mem(Spec.LCat{a, b}, 0n, "") == (Spec.mem(a, 0n, "") && _) : Bool}
      {==}
    case Spec.LOr{a, b}:
      %mem_empty(a) : {Spec.mem(Spec.LOr{a, b}, 0n, "") == (_ || nu(b)) : Bool}
      %mem_empty(b) : {Spec.mem(Spec.LOr{a, b}, 0n, "") == (Spec.mem(a, 0n, "") || _) : Bool}
      {==}

def and_self(+b: Bool) -> {(b && b) == b : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def and_true(+b: Bool) -> {(b && True{}) == b : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def power_nu(+l: Spec.Lang, +j: Nat) -> {nu(Spec.power(l, j)) == (Nat.is_eq(j, 0n) || nu(l)) : Bool}:
  match j:
    case 0n: {==}
    case 1n+0n: and_true(nu(l))
    case 1n+1n+i:
      %Equal.sym(Bool, nu(Spec.power(l, 1n+i)), nu(l), power_nu(l, 1n+i)) : {(nu(l) && _) == nu(l) : Bool}
      and_self(nu(l))

def pick_nu(+b: Bool, +l: Spec.Lang) -> {nu(Bool.pick(Spec.Lang, b, l, Spec.LNone{})) == (b && nu(l)) : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def le_step(+m: Nat, +n: Nat) -> {(Nat.is_le(m, n) || Nat.is_le(m, 1n+n)) == Nat.is_le(m, 1n+n) : Bool}:
  match m n:
    case 0n 0n: {==}
    case 0n 1n+j: {==}
    case 1n+k 0n: {==}
    case 1n+k 1n+j: le_step(k, j)

def counts_join(+a: Bool, +b: Bool, +x: Bool) -> {((a && x) || (b && x)) == ((a || b) && x) : Bool}:
  match a b x:
    case True{} _ True{}: {==}
    case True{} True{} False{}: {==}
    case True{} False{} False{}: {==}
    case False{} True{} _: {==}
    case False{} False{} _: {==}

def counts_bool(+m: Nat, +k: Nat, +x: Bool) -> {((Nat.is_le(m, k) && (Nat.is_eq(m, 0n) || x)) || (Nat.is_le(m, 1n+k) && x)) == (Nat.is_le(m, 1n+k) && (Nat.is_eq(m, 0n) || x)) : Bool}:
  match m:
    case 0n:
      match k:
        case 0n: {==}
        case 1n+j: {==}
    case 1n+j:
      %le_step(1n+j, k) : {((Nat.is_le(1n+j, k) && x) || (Nat.is_le(1n+j, 1n+k) && x)) == (_ && x) : Bool}
      counts_join(Nat.is_le(1n+j, k), Nat.is_le(1n+j, 1n+k), x)

def counts_nu(+n: Nat, +m: Nat, +l: Spec.Lang) -> {nu(Spec.counts(l, m, n)) == (Nat.is_le(m, n) && (Nat.is_eq(m, 0n) || nu(l))) : Bool}:
  match n:
    case 0n:
      match m:
        case 0n: {==}
        case 1n+k: {==}
    case 1n+k:
      %counts_bool(m, k, nu(l)) : {nu(Spec.counts(l, m, 1n+k)) == _ : Bool}
      %counts_nu(k, m, l) : {nu(Spec.counts(l, m, 1n+k)) == (_ || (Nat.is_le(m, 1n+k) && nu(l))) : Bool}
      %power_nu(l, 1n+k) : {nu(Spec.counts(l, m, 1n+k)) == (nu(Spec.counts(l, m, k)) || (Nat.is_le(m, 1n+k) && _)) : Bool}
      %pick_nu(Nat.is_le(m, 1n+k), Spec.power(l, 1n+k)) : {nu(Spec.counts(l, m, 1n+k)) == (nu(Spec.counts(l, m, k)) || _) : Bool}
      {==}

def repeat_nu_zero(+l: Spec.Lang, +m: Nat, +n: Maybe<&2, Nat>) -> {nu(Spec.repeat(l, m, n, 0n)) == (P.at_most(n, m) && (Nat.is_eq(m, 0n) || nu(l))) : Bool}:
  match n:
    case Some{k}: counts_nu(k, m, l)
    case None{}:
      %power_nu(l, m) : {(nu(Spec.power(l, m)) && True{}) == _ : Bool}
      and_true(nu(Spec.power(l, m)))

def nullable_lang(+p: P.Pattern) -> {P.nullable(p) == nu(Spec.lang(p, 0n)) : Bool}:
  match p:
    case P.Literal{x}: {==}
    case P.Class{rs}: {==}
    case P.Cat{a, b}:
      %nullable_lang(a) : {P.nullable(P.Cat{a, b}) == (_ && nu(Spec.lang(b, 0n))) : Bool}
      %nullable_lang(b) : {P.nullable(P.Cat{a, b}) == (P.nullable(a) && _) : Bool}
      {==}
    case P.Repeat{r, m, n}:
      %Equal.sym(Bool, nu(Spec.repeat(Spec.lang(r, 0n), m, n, 0n)), (P.at_most(n, m) && (Nat.is_eq(m, 0n) || nu(Spec.lang(r, 0n)))), repeat_nu_zero(Spec.lang(r, 0n), m, n)) : {P.nullable(P.Repeat{r, m, n}) == _ : Bool}
      %nullable_lang(r) : {P.nullable(P.Repeat{r, m, n}) == (P.at_most(n, m) && (Nat.is_eq(m, 0n) || _)) : Bool}
      {==}

def nullable_equiv(+p: P.Pattern) -> {P.nullable(p) == Spec.matches(p, "") : Bool}:
  Equal.trans(Bool, P.nullable(p), nu(Spec.lang(p, 0n)), Spec.matches(p, ""), nullable_lang(p), Equal.sym(Bool, Spec.matches(p, ""), nu(Spec.lang(p, 0n)), mem_empty(Spec.lang(p, 0n))))

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
    case SNil{}: Equal.sym(Bool, (Spec.in_class(rs, c) && True{}), Spec.in_class(rs, c), and_true(Spec.in_class(rs, c)))
    case SCon{h, u}: Equal.sym(Bool, (Spec.in_class(rs, c) && False{}), False{}, and_false(Spec.in_class(rs, c)))

def derive_equiv(+c: U32, +p: P.Pattern, +t: String) -> {Spec.matches(p, SCon{Chr{c}, t}) == any_matches(P.derive(c, p), t) : Bool}:
  match p:
    case P.Literal{SNil{}}: {==}
    case P.Literal{SCon{Chr{d}, s}}: literal_derive(c, d, s, t)
    case P.Class{rs}:
      %Equal.sym(Bool, P.in_ranges(rs, c, False{}), Spec.in_class(rs, c), ranges_equiv(rs, c, False{})) : {Spec.matches(P.Class{rs}, SCon{Chr{c}, t}) == any_matches(P.class_step(_), t) : Bool}
      %class_any(Spec.in_class(rs, c), t) : {Spec.matches(P.Class{rs}, SCon{Chr{c}, t}) == _ : Bool}
      class_one(rs, c, t)
    case P.Cat{a, b}: ?TODO
    case P.Repeat{r, m, n}: ?TODO
