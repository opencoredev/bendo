# Concatenation associativity with the complete, canonical split bound.
import Base
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-empty.bend as E
import ./schema-pattern-split.bend as S
import ./schema-pattern-assoc-derive.bend as D

def cat_gate_left(+hit: Bool, +a: Spec.Lang, +b: Spec.Lang, +k: Nat, +w: String) -> {Spec.mem(Spec.LCat{D.gate(hit, a), b}, k, w) == (hit && Spec.mem(Spec.LCat{a, b}, k, w)) : Bool}:
  match hit:
    case True{}: {==}
    case False{}: S.cat_none(k, b, w)

def left_expand(+a: Spec.Lang, +b: Spec.Lang, +c: Spec.Lang, +h: U32, +k: Nat, +w: String) -> {Spec.mem(D.d(Spec.LCat{Spec.LCat{a, b}, c}, h), k, w) == ((Spec.mem(Spec.LCat{Spec.LCat{D.d(a, h), b}, c}, k, w) || (E.nu(a) && Spec.mem(Spec.LCat{D.d(b, h), c}, k, w))) || ((E.nu(a) && E.nu(b)) && Spec.mem(D.d(c, h), k, w))) : Bool}:
  %Equal.sym(Bool, Spec.mem(Spec.LCat{Spec.LOr{Spec.LCat{D.d(a, h), b}, D.gate(E.nu(a), D.d(b, h))}, c}, k, w), (Spec.mem(Spec.LCat{Spec.LCat{D.d(a, h), b}, c}, k, w) || Spec.mem(Spec.LCat{D.gate(E.nu(a), D.d(b, h)), c}, k, w)), S.cat_or_left(k, Spec.LCat{D.d(a, h), b}, D.gate(E.nu(a), D.d(b, h)), c, w)) : {(_ || Spec.mem(D.gate((E.nu(a) && E.nu(b)), D.d(c, h)), k, w)) == ((Spec.mem(Spec.LCat{Spec.LCat{D.d(a, h), b}, c}, k, w) || (E.nu(a) && Spec.mem(Spec.LCat{D.d(b, h), c}, k, w))) || ((E.nu(a) && E.nu(b)) && Spec.mem(D.d(c, h), k, w))) : Bool}
  %Equal.sym(Bool, Spec.mem(Spec.LCat{D.gate(E.nu(a), D.d(b, h)), c}, k, w), (E.nu(a) && Spec.mem(Spec.LCat{D.d(b, h), c}, k, w)), cat_gate_left(E.nu(a), D.d(b, h), c, k, w)) : {((Spec.mem(Spec.LCat{Spec.LCat{D.d(a, h), b}, c}, k, w) || _) || Spec.mem(D.gate((E.nu(a) && E.nu(b)), D.d(c, h)), k, w)) == ((Spec.mem(Spec.LCat{Spec.LCat{D.d(a, h), b}, c}, k, w) || (E.nu(a) && Spec.mem(Spec.LCat{D.d(b, h), c}, k, w))) || ((E.nu(a) && E.nu(b)) && Spec.mem(D.d(c, h), k, w))) : Bool}
  %D.gate_mem((E.nu(a) && E.nu(b)), D.d(c, h), k, w) : {((Spec.mem(Spec.LCat{Spec.LCat{D.d(a, h), b}, c}, k, w) || (E.nu(a) && Spec.mem(Spec.LCat{D.d(b, h), c}, k, w))) || _) == ((Spec.mem(Spec.LCat{Spec.LCat{D.d(a, h), b}, c}, k, w) || (E.nu(a) && Spec.mem(Spec.LCat{D.d(b, h), c}, k, w))) || ((E.nu(a) && E.nu(b)) && Spec.mem(D.d(c, h), k, w))) : Bool}
  {==}

def right_expand(+a: Spec.Lang, +b: Spec.Lang, +c: Spec.Lang, +h: U32, +k: Nat, +w: String) -> {Spec.mem(D.d(Spec.LCat{a, Spec.LCat{b, c}}, h), k, w) == (Spec.mem(Spec.LCat{D.d(a, h), Spec.LCat{b, c}}, k, w) || (E.nu(a) && (Spec.mem(Spec.LCat{D.d(b, h), c}, k, w) || (E.nu(b) && Spec.mem(D.d(c, h), k, w))))) : Bool}:
  %D.gate_mem(E.nu(a), D.d(Spec.LCat{b, c}, h), k, w) : {(Spec.mem(Spec.LCat{D.d(a, h), Spec.LCat{b, c}}, k, w) || _) == (Spec.mem(Spec.LCat{D.d(a, h), Spec.LCat{b, c}}, k, w) || (E.nu(a) && (Spec.mem(Spec.LCat{D.d(b, h), c}, k, w) || (E.nu(b) && Spec.mem(D.d(c, h), k, w))))) : Bool}
  %D.gate_mem(E.nu(b), D.d(c, h), k, w) : {(Spec.mem(Spec.LCat{D.d(a, h), Spec.LCat{b, c}}, k, w) || (E.nu(a) && (Spec.mem(Spec.LCat{D.d(b, h), c}, k, w) || _))) == (Spec.mem(Spec.LCat{D.d(a, h), Spec.LCat{b, c}}, k, w) || (E.nu(a) && (Spec.mem(Spec.LCat{D.d(b, h), c}, k, w) || (E.nu(b) && Spec.mem(D.d(c, h), k, w))))) : Bool}
  {==}

def boolean_assoc(+x: Bool, +y: Bool, +z: Bool, +a: Bool, +b: Bool) -> {((x || (a && y)) || ((a && b) && z)) == (x || (a && (y || (b && z)))) : Bool}:
  match x a b:
    case False{} False{} False{}: {==}
    case False{} False{} True{}: {==}
    case False{} True{} False{}: {==}
    case False{} True{} True{}: {==}
    case True{} False{} False{}: {==}
    case True{} False{} True{}: {==}
    case True{} True{} False{}: {==}
    case True{} True{} True{}: {==}

def derivative_assoc(+a: Spec.Lang, +b: Spec.Lang, +c: Spec.Lang, +h: U32, +k: Nat, +w: String, ih: {Spec.mem(Spec.LCat{Spec.LCat{D.d(a, h), b}, c}, k, w) == Spec.mem(Spec.LCat{D.d(a, h), Spec.LCat{b, c}}, k, w) : Bool}) -> {Spec.mem(D.d(Spec.LCat{Spec.LCat{a, b}, c}, h), k, w) == Spec.mem(D.d(Spec.LCat{a, Spec.LCat{b, c}}, h), k, w) : Bool}:
  %Equal.sym(Bool, Spec.mem(D.d(Spec.LCat{a, Spec.LCat{b, c}}, h), k, w), (Spec.mem(Spec.LCat{D.d(a, h), Spec.LCat{b, c}}, k, w) || (E.nu(a) && (Spec.mem(Spec.LCat{D.d(b, h), c}, k, w) || (E.nu(b) && Spec.mem(D.d(c, h), k, w))))), right_expand(a, b, c, h, k, w)) : {Spec.mem(D.d(Spec.LCat{Spec.LCat{a, b}, c}, h), k, w) == _ : Bool}
  %ih : {Spec.mem(D.d(Spec.LCat{Spec.LCat{a, b}, c}, h), k, w) == (_ || (E.nu(a) && (Spec.mem(Spec.LCat{D.d(b, h), c}, k, w) || (E.nu(b) && Spec.mem(D.d(c, h), k, w))))) : Bool}
  %boolean_assoc(Spec.mem(Spec.LCat{Spec.LCat{D.d(a, h), b}, c}, k, w), Spec.mem(Spec.LCat{D.d(b, h), c}, k, w), Spec.mem(D.d(c, h), k, w), E.nu(a), E.nu(b)) : {Spec.mem(D.d(Spec.LCat{Spec.LCat{a, b}, c}, h), k, w) == _ : Bool}
  left_expand(a, b, c, h, k, w)

def and_assoc(+a: Bool, +b: Bool, +c: Bool) -> {((a && b) && c) == (a && (b && c)) : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def assoc(+w: String, +a: Spec.Lang, +b: Spec.Lang, +c: Spec.Lang) -> {Spec.mem(Spec.LCat{Spec.LCat{a, b}, c}, Spec.length(w), w) == Spec.mem(Spec.LCat{a, Spec.LCat{b, c}}, Spec.length(w), w) : Bool}:
  match w:
    case SNil{}:
      %Equal.sym(Bool, Spec.mem(Spec.LCat{a, Spec.LCat{b, c}}, 0n, ""), E.nu(Spec.LCat{a, Spec.LCat{b, c}}), E.mem_empty(Spec.LCat{a, Spec.LCat{b, c}})) : {Spec.mem(Spec.LCat{Spec.LCat{a, b}, c}, 0n, "") == _ : Bool}
      %and_assoc(E.nu(a), E.nu(b), E.nu(c)) : {Spec.mem(Spec.LCat{Spec.LCat{a, b}, c}, 0n, "") == _ : Bool}
      E.mem_empty(Spec.LCat{Spec.LCat{a, b}, c})
    case SCon{Chr{h}, t}:
      %Equal.sym(Bool, Spec.mem(Spec.LCat{a, Spec.LCat{b, c}}, 1n+Spec.length(t), SCon{Chr{h}, t}), Spec.mem(D.d(Spec.LCat{a, Spec.LCat{b, c}}, h), Spec.length(t), t), D.derive(Spec.LCat{a, Spec.LCat{b, c}}, h, t)) : {Spec.mem(Spec.LCat{Spec.LCat{a, b}, c}, 1n+Spec.length(t), SCon{Chr{h}, t}) == _ : Bool}
      %derivative_assoc(a, b, c, h, Spec.length(t), t, assoc(t, D.d(a, h), b, c)) : {Spec.mem(Spec.LCat{Spec.LCat{a, b}, c}, 1n+Spec.length(t), SCon{Chr{h}, t}) == _ : Bool}
      D.derive(Spec.LCat{Spec.LCat{a, b}, c}, h, t)
