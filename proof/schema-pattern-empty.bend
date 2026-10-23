# Empty-word equivalence for the split-based pattern specification.
import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec

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

