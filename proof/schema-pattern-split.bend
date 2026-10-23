# Split algebra for the specification's finite languages.
import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-empty.bend as Empty

def or_zero(+a: Bool) -> {(a || False{}) == a : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def and_zero(+a: Bool) -> {(a && False{}) == False{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def or_assoc(+a: Bool, -b: Bool, -c: Bool) -> {(a || (b || c)) == ((a || b) || c) : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def or_swap(+a: Bool, +b: Bool, +c: Bool, +d: Bool) -> {((a || c) || (b || d)) == ((a || b) || (c || d)) : Bool}:
  match a b c d:
    case True{} _ _ _: {==}
    case False{} True{} True{} _: {==}
    case False{} True{} False{} _: {==}
    case False{} False{} True{} _: {==}
    case False{} False{} False{} _: {==}

def and_or(+a: Bool, +b: Bool, +c: Bool) -> {((a || b) && c) == ((a && c) || (b && c)) : Bool}:
  match a b c:
    case True{} _ True{}: {==}
    case True{} True{} False{}: {==}
    case True{} False{} False{}: {==}
    case False{} _ _: {==}

def or_and(+a: Bool, +b: Bool, +c: Bool) -> {(a && (b || c)) == ((a && b) || (a && c)) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

# Concatenation distributes over union on either side, at every split counter.
def cat_or_left(+k: Nat, +a: Spec.Lang, +b: Spec.Lang, +d: Spec.Lang, +w: String) -> {Spec.mem(Spec.LCat{Spec.LOr{a, b}, d}, k, w) == (Spec.mem(Spec.LCat{a, d}, k, w) || Spec.mem(Spec.LCat{b, d}, k, w)) : Bool}:
  match k:
    case 0n: and_or(Spec.mem(a, 0n, ""), Spec.mem(b, 0n, ""), Spec.mem(d, Spec.length(w), w))
    case 1n+j:
      %or_swap(Spec.mem(a, 1n+j, String.take(w, 1n+j)) && Spec.mem(d, Spec.length(String.drop(w, 1n+j)), String.drop(w, 1n+j)), Spec.mem(Spec.LCat{a, d}, j, w), Spec.mem(b, 1n+j, String.take(w, 1n+j)) && Spec.mem(d, Spec.length(String.drop(w, 1n+j)), String.drop(w, 1n+j)), Spec.mem(Spec.LCat{b, d}, j, w)) : {Spec.mem(Spec.LCat{Spec.LOr{a, b}, d}, 1n+j, w) == _ : Bool}
      %cat_or_left(j, a, b, d, w) : {Spec.mem(Spec.LCat{Spec.LOr{a, b}, d}, 1n+j, w) == (((Spec.mem(a, 1n+j, String.take(w, 1n+j)) && Spec.mem(d, Spec.length(String.drop(w, 1n+j)), String.drop(w, 1n+j))) || (Spec.mem(b, 1n+j, String.take(w, 1n+j)) && Spec.mem(d, Spec.length(String.drop(w, 1n+j)), String.drop(w, 1n+j)))) || _) : Bool}
      %and_or(Spec.mem(a, 1n+j, String.take(w, 1n+j)), Spec.mem(b, 1n+j, String.take(w, 1n+j)), Spec.mem(d, Spec.length(String.drop(w, 1n+j)), String.drop(w, 1n+j))) : {Spec.mem(Spec.LCat{Spec.LOr{a, b}, d}, 1n+j, w) == (_ || Spec.mem(Spec.LCat{Spec.LOr{a, b}, d}, j, w)) : Bool}
      {==}

def cat_or_right(+k: Nat, +a: Spec.Lang, +b: Spec.Lang, +d: Spec.Lang, +w: String) -> {Spec.mem(Spec.LCat{a, Spec.LOr{b, d}}, k, w) == (Spec.mem(Spec.LCat{a, b}, k, w) || Spec.mem(Spec.LCat{a, d}, k, w)) : Bool}:
  match k:
    case 0n: or_and(Spec.mem(a, 0n, ""), Spec.mem(b, Spec.length(w), w), Spec.mem(d, Spec.length(w), w))
    case 1n+j:
      %or_swap(Spec.mem(a, 1n+j, String.take(w, 1n+j)) && Spec.mem(b, Spec.length(String.drop(w, 1n+j)), String.drop(w, 1n+j)), Spec.mem(Spec.LCat{a, b}, j, w), Spec.mem(a, 1n+j, String.take(w, 1n+j)) && Spec.mem(d, Spec.length(String.drop(w, 1n+j)), String.drop(w, 1n+j)), Spec.mem(Spec.LCat{a, d}, j, w)) : {Spec.mem(Spec.LCat{a, Spec.LOr{b, d}}, 1n+j, w) == _ : Bool}
      %cat_or_right(j, a, b, d, w) : {Spec.mem(Spec.LCat{a, Spec.LOr{b, d}}, 1n+j, w) == (((Spec.mem(a, 1n+j, String.take(w, 1n+j)) && Spec.mem(b, Spec.length(String.drop(w, 1n+j)), String.drop(w, 1n+j))) || (Spec.mem(a, 1n+j, String.take(w, 1n+j)) && Spec.mem(d, Spec.length(String.drop(w, 1n+j)), String.drop(w, 1n+j)))) || _) : Bool}
      %or_and(Spec.mem(a, 1n+j, String.take(w, 1n+j)), Spec.mem(b, Spec.length(String.drop(w, 1n+j)), String.drop(w, 1n+j)), Spec.mem(d, Spec.length(String.drop(w, 1n+j)), String.drop(w, 1n+j))) : {Spec.mem(Spec.LCat{a, Spec.LOr{b, d}}, 1n+j, w) == (_ || Spec.mem(Spec.LCat{a, Spec.LOr{b, d}}, j, w)) : Bool}
      {==}

def take_zero(+w: String) -> {String.take(w, 0n) == "" : String}:
  match w:
    case SNil{}: {==}
    case SCon{h, t}: {==}

def drop_zero(+w: String) -> {String.drop(w, 0n) == w : String}:
  match w:
    case SNil{}: {==}
    case SCon{h, t}: {==}

# The positive split points, after consuming the leading character.
def positive(+a: Spec.Lang, +b: Spec.Lang, +j: Nat, +c: U32, +t: String) -> Bool:
  match j:
    case 0n: Spec.mem(a, 1n, SCon{Chr{c}, ""}) && Spec.mem(b, Spec.length(t), t)
    case 1n+i: (Spec.mem(a, 1n+1n+i, SCon{Chr{c}, String.take(t, 1n+i)}) && Spec.mem(b, Spec.length(String.drop(t, 1n+i)), String.drop(t, 1n+i))) || positive(a, b, i, c, t)

def cat_head(+j: Nat, +a: Spec.Lang, +b: Spec.Lang, +c: U32, +t: String) -> {Spec.mem(Spec.LCat{a, b}, 1n+j, SCon{Chr{c}, t}) == (positive(a, b, j, c, t) || (Empty.nu(a) && Spec.mem(b, 1n+Spec.length(t), SCon{Chr{c}, t}))) : Bool}:
  match j:
    case 0n:
      %Empty.mem_empty(a) : {Spec.mem(Spec.LCat{a, b}, 1n, SCon{Chr{c}, t}) == (positive(a, b, 0n, c, t) || (_ && Spec.mem(b, 1n+Spec.length(t), SCon{Chr{c}, t}))) : Bool}
      %take_zero(t) : {Spec.mem(Spec.LCat{a, b}, 1n, SCon{Chr{c}, t}) == ((Spec.mem(a, 1n, SCon{Chr{c}, _}) && Spec.mem(b, Spec.length(t), t)) || (Spec.mem(a, 0n, "") && Spec.mem(b, 1n+Spec.length(t), SCon{Chr{c}, t}))) : Bool}
      %drop_zero(t) : {Spec.mem(Spec.LCat{a, b}, 1n, SCon{Chr{c}, t}) == ((Spec.mem(a, 1n, SCon{Chr{c}, String.take(t, 0n)}) && Spec.mem(b, Spec.length(_), _)) || (Spec.mem(a, 0n, "") && Spec.mem(b, 1n+Spec.length(t), SCon{Chr{c}, t}))) : Bool}
      {==}
    case 1n+i:
      %or_assoc(Spec.mem(a, 1n+1n+i, SCon{Chr{c}, String.take(t, 1n+i)}) && Spec.mem(b, Spec.length(String.drop(t, 1n+i)), String.drop(t, 1n+i)), positive(a, b, i, c, t), Empty.nu(a) && Spec.mem(b, 1n+Spec.length(t), SCon{Chr{c}, t})) : {Spec.mem(Spec.LCat{a, b}, 1n+1n+i, SCon{Chr{c}, t}) == _ : Bool}
      %cat_head(i, a, b, c, t) : {Spec.mem(Spec.LCat{a, b}, 1n+1n+i, SCon{Chr{c}, t}) == ((Spec.mem(a, 1n+1n+i, SCon{Chr{c}, String.take(t, 1n+i)}) && Spec.mem(b, Spec.length(String.drop(t, 1n+i)), String.drop(t, 1n+i))) || _) : Bool}
      {==}

# A derivative set as a finite union, using one ambient word bound.
def union_lang(ps: List<&2, P.Pattern>, +bound: Nat) -> Spec.Lang:
  match ps:
    case Nil{}: Spec.LNone{}
    case p <> t: Spec.LOr{Spec.lang(p, bound), union_lang(t, bound)}

def any_mem(ps: List<&2, P.Pattern>, +bound: Nat, +k: Nat, +w: String) -> Bool:
  match ps:
    case Nil{}: False{}
    case p <> t: Spec.mem(Spec.lang(p, bound), k, w) || any_mem(t, bound, k, w)

def union_mem(+ps: List<&2, P.Pattern>, +bound: Nat, +k: Nat, +w: String) -> {Spec.mem(union_lang(ps, bound), k, w) == any_mem(ps, bound, k, w) : Bool}:
  match ps:
    case Nil{}: {==}
    case p <> t:
      %union_mem(t, bound, k, w) : {Spec.mem(union_lang(p <> t, bound), k, w) == (Spec.mem(Spec.lang(p, bound), k, w) || _) : Bool}
      {==}

def cat_none(+k: Nat, +b: Spec.Lang, +w: String) -> {Spec.mem(Spec.LCat{Spec.LNone{}, b}, k, w) == False{} : Bool}:
  match k:
    case 0n: {==}
    case 1n+j: cat_none(j, b, w)

def behind_union(+ps: List<&2, P.Pattern>, +b: P.Pattern, +bound: Nat, +k: Nat, +w: String) -> {Spec.mem(Spec.LCat{union_lang(ps, bound), Spec.lang(b, bound)}, k, w) == any_mem(P.behind(ps, b), bound, k, w) : Bool}:
  match ps:
    case Nil{}: cat_none(k, Spec.lang(b, bound), w)
    case p <> t:
      %behind_union(t, b, bound, k, w) : {Spec.mem(Spec.LCat{union_lang(p <> t, bound), Spec.lang(b, bound)}, k, w) == (Spec.mem(Spec.LCat{Spec.lang(p, bound), Spec.lang(b, bound)}, k, w) || _) : Bool}
      cat_or_left(k, Spec.lang(p, bound), union_lang(t, bound), Spec.lang(b, bound), w)

# Appending derivative sets is disjunction, independently of their bound.
def append_any(+ps: List<&2, P.Pattern>, +qs: List<&2, P.Pattern>, +bound: Nat, +k: Nat, +w: String) -> {any_mem(List.append(&2, P.Pattern, ps, qs), bound, k, w) == (any_mem(ps, bound, k, w) || any_mem(qs, bound, k, w)) : Bool}:
  match ps:
    case Nil{}: {==}
    case p <> t:
      %or_assoc(Spec.mem(Spec.lang(p, bound), k, w), any_mem(t, bound, k, w), any_mem(qs, bound, k, w)) : {any_mem(List.append(&2, P.Pattern, p <> t, qs), bound, k, w) == _ : Bool}
      %append_any(t, qs, bound, k, w) : {any_mem(List.append(&2, P.Pattern, p <> t, qs), bound, k, w) == (Spec.mem(Spec.lang(p, bound), k, w) || _) : Bool}
      {==}
