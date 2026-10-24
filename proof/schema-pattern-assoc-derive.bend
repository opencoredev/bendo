# Canonical derivatives of arbitrary finite specification languages.
import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-empty.bend as E
import ./schema-pattern-split.bend as S
import ./schema-pattern-strings.bend as W

def gate(hit: Bool, l: Spec.Lang) -> Spec.Lang:
  Bool.pick(Spec.Lang, hit, l, Spec.LNone{})

def gate_mem(+hit: Bool, +l: Spec.Lang, +k: Nat, +w: String) -> {(hit && Spec.mem(l, k, w)) == Spec.mem(gate(hit, l), k, w) : Bool}:
  match hit:
    case True{}: {==}
    case False{}: {==}

def d(+l: Spec.Lang, +c: U32) -> Spec.Lang:
  match l:
    case Spec.LNone{}: Spec.LNone{}
    case Spec.LEmpty{}: Spec.LNone{}
    case Spec.LText{SNil{}}: Spec.LNone{}
    case Spec.LText{SCon{Chr{x}, s}}: gate(U32.is_eq(x, c), Spec.LText{s})
    case Spec.LOne{rs}: gate(Spec.in_class(rs, c), Spec.LEmpty{})
    case Spec.LNonEmpty{a}: d(a, c)
    case Spec.LOr{a, b}: Spec.LOr{d(a, c), d(b, c)}
    case Spec.LCat{a, b}: Spec.LOr{Spec.LCat{d(a, c), b}, gate(E.nu(a), d(b, c))}

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


def one_head(+rs: List<&2, P.Range>, +c: U32, +t: String) -> {Spec.one(rs, SCon{Chr{c}, t}) == (Spec.in_class(rs, c) && String.is_empty(t)) : Bool}:
  match t:
    case SNil{}: Equal.sym(Bool, Spec.in_class(rs, c) && True{}, Spec.in_class(rs, c), E.and_true(Spec.in_class(rs, c)))
    case SCon{h, u}: Equal.sym(Bool, Spec.in_class(rs, c) && False{}, False{}, S.and_zero(Spec.in_class(rs, c)))

def Positive(+a: Spec.Lang, +b: Spec.Lang, +j: Nat, +c: U32, +t: String) -> Type:
  {S.positive(a, b, j, c, t) == Spec.mem(Spec.LCat{d(a, c), b}, j, t) : Bool}

def prefix_step(+a: Spec.Lang, +b: Spec.Lang, +j: Nat, +c: U32, +t: String, +ej: {Nat.is_le(j, Spec.length(t)) == True{} : Bool}, eh: {Spec.mem(a, 1n+Spec.length(String.take(t, j)), SCon{Chr{c}, String.take(t, j)}) == Spec.mem(d(a, c), Spec.length(String.take(t, j)), String.take(t, j)) : Bool}) -> {(Spec.mem(a, 1n+j, SCon{Chr{c}, String.take(t, j)}) && Spec.mem(b, Spec.length(String.drop(t, j)), String.drop(t, j))) == (Spec.mem(d(a, c), j, String.take(t, j)) && Spec.mem(b, Spec.length(String.drop(t, j)), String.drop(t, j))) : Bool}:
  %W.prefix_length(t, j, ej) : {(Spec.mem(a, 1n+_, SCon{Chr{c}, String.take(t, j)}) && Spec.mem(b, Spec.length(String.drop(t, j)), String.drop(t, j))) == (Spec.mem(d(a, c), _, String.take(t, j)) && Spec.mem(b, Spec.length(String.drop(t, j)), String.drop(t, j))) : Bool}
  %eh : {(Spec.mem(a, 1n+Spec.length(String.take(t, j)), SCon{Chr{c}, String.take(t, j)}) && Spec.mem(b, Spec.length(String.drop(t, j)), String.drop(t, j))) == (_ && Spec.mem(b, Spec.length(String.drop(t, j)), String.drop(t, j))) : Bool}
  {==}

def positive_zero(+a: Spec.Lang, +b: Spec.Lang, +c: U32, +t: String, eh: {Spec.mem(a, 1n, SCon{Chr{c}, ""}) == Spec.mem(d(a, c), 0n, "") : Bool}) -> Positive(a, b, 0n, c, t):
  match t:
    case SNil{}: prefix_step(a, b, 0n, c, "", W.zero_le(0n), eh)
    case SCon{h, u}: prefix_step(a, b, 0n, c, SCon{h, u}, W.zero_le(1n+Spec.length(u)), eh)

def positive_next(+a: Spec.Lang, +b: Spec.Lang, +j: Nat, +c: U32, +t: String, +ej: {Nat.is_le(1n+j, Spec.length(t)) == True{} : Bool}, eh: {Spec.mem(a, 1n+Spec.length(String.take(t, 1n+j)), SCon{Chr{c}, String.take(t, 1n+j)}) == Spec.mem(d(a, c), Spec.length(String.take(t, 1n+j)), String.take(t, 1n+j)) : Bool}, et: Positive(a, b, j, c, t)) -> Positive(a, b, 1n+j, c, t):
  %prefix_step(a, b, 1n+j, c, t, ej, eh) : {S.positive(a, b, 1n+j, c, t) == (_ || Spec.mem(Spec.LCat{d(a, c), b}, j, t)) : Bool}
  %et : {S.positive(a, b, 1n+j, c, t) == ((Spec.mem(a, 1n+1n+j, SCon{Chr{c}, String.take(t, 1n+j)}) && Spec.mem(b, Spec.length(String.drop(t, 1n+j)), String.drop(t, 1n+j))) || _) : Bool}
  {==}

def Claim(+l: Spec.Lang, +j: Nat, +c: U32, +t: String) -> Type:
  match l:
    case Spec.LCat{a, b}: Positive(a, b, j, c, t) & {Spec.mem(b, 1n+Spec.length(t), SCon{Chr{c}, t}) == Spec.mem(d(b, c), Spec.length(t), t) : Bool}
    case _: {Spec.mem(l, 1n+Spec.length(t), SCon{Chr{c}, t}) == Spec.mem(d(l, c), Spec.length(t), t) : Bool}

def finish(+l: Spec.Lang, +c: U32, +t: String, e: Claim(l, Spec.length(t), c, t)) -> {Spec.mem(l, 1n+Spec.length(t), SCon{Chr{c}, t}) == Spec.mem(d(l, c), Spec.length(t), t) : Bool}:
  match l:
    case Spec.LNone{}: e
    case Spec.LEmpty{}: e
    case Spec.LText{x}: e
    case Spec.LOne{rs}: e
    case Spec.LNonEmpty{a}: e
    case Spec.LOr{a, b}: e
    case Spec.LCat{a, b}:
      (ep, eb) = e
      %gate_mem(E.nu(a), d(b, c), Spec.length(t), t) : {Spec.mem(l, 1n+Spec.length(t), SCon{Chr{c}, t}) == (Spec.mem(Spec.LCat{d(a, c), b}, Spec.length(t), t) || _) : Bool}
      %eb : {Spec.mem(l, 1n+Spec.length(t), SCon{Chr{c}, t}) == (Spec.mem(Spec.LCat{d(a, c), b}, Spec.length(t), t) || (E.nu(a) && _)) : Bool}
      %ep : {Spec.mem(l, 1n+Spec.length(t), SCon{Chr{c}, t}) == (_ || (E.nu(a) && Spec.mem(b, 1n+Spec.length(t), SCon{Chr{c}, t}))) : Bool}
      S.cat_head(Spec.length(t), a, b, c, t)

def cat_next(+a: Spec.Lang, +b: Spec.Lang, +j: Nat, +c: U32, +t: String, +ej: {Nat.is_le(1n+j, Spec.length(t)) == True{} : Bool}, e: Claim(Spec.LCat{a, b}, j, c, t), eh: {Spec.mem(a, 1n+Spec.length(String.take(t, 1n+j)), SCon{Chr{c}, String.take(t, 1n+j)}) == Spec.mem(d(a, c), Spec.length(String.take(t, 1n+j)), String.take(t, 1n+j)) : Bool}) -> Claim(Spec.LCat{a, b}, 1n+j, c, t):
  (ep, eb) = e
  (positive_next(a, b, j, c, t, ej, eh, ep), eb)

def derive_go(+l: Spec.Lang, +j: Nat, +c: U32, +t: String, +ej: {Nat.is_le(j, Spec.length(t)) == True{} : Bool}) -> Claim(l, j, c, t):
  match l:
    case Spec.LNone{}: {==}
    case Spec.LEmpty{}: {==}
    case Spec.LText{SNil{}}: {==}
    case Spec.LText{SCon{Chr{x}, s}}:
      %gate_mem(U32.is_eq(x, c), Spec.LText{s}, Spec.length(t), t) : {Spec.mem(l, 1n+Spec.length(t), SCon{Chr{c}, t}) == _ : Bool}
      string_order_eq(U32.cmp(x, c), s, t)
    case Spec.LOne{rs}:
      %gate_mem(Spec.in_class(rs, c), Spec.LEmpty{}, Spec.length(t), t) : {Spec.one(rs, SCon{Chr{c}, t}) == _ : Bool}
      one_head(rs, c, t)
    case Spec.LNonEmpty{a}: finish(a, c, t, derive_go(a, Spec.length(t), c, t, W.le_self(Spec.length(t))))
    case Spec.LOr{a, b}:
      %finish(a, c, t, derive_go(a, Spec.length(t), c, t, W.le_self(Spec.length(t)))) : {Spec.mem(l, 1n+Spec.length(t), SCon{Chr{c}, t}) == (_ || Spec.mem(d(b, c), Spec.length(t), t)) : Bool}
      %finish(b, c, t, derive_go(b, Spec.length(t), c, t, W.le_self(Spec.length(t)))) : {Spec.mem(l, 1n+Spec.length(t), SCon{Chr{c}, t}) == (Spec.mem(a, 1n+Spec.length(t), SCon{Chr{c}, t}) || _) : Bool}
      {==}
    case Spec.LCat{a, b}:
      match j:
        case 0n: (positive_zero(a, b, c, t, finish(a, c, "", derive_go(a, 0n, c, "", {==}))), finish(b, c, t, derive_go(b, Spec.length(t), c, t, W.le_self(Spec.length(t)))))
        case 1n+i: cat_next(a, b, i, c, t, ej, derive_go(l, i, c, t, W.le_previous(i, Spec.length(t), ej)), finish(a, c, String.take(t, 1n+i), derive_go(a, Spec.length(String.take(t, 1n+i)), c, String.take(t, 1n+i), W.le_self(Spec.length(String.take(t, 1n+i))))))

def derive(+l: Spec.Lang, +c: U32, +t: String) -> {Spec.mem(l, 1n+Spec.length(t), SCon{Chr{c}, t}) == Spec.mem(d(l, c), Spec.length(t), t) : Bool}:
  finish(l, c, t, derive_go(l, Spec.length(t), c, t, W.le_self(Spec.length(t))))
