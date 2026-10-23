# BND-43: Compare.ct_equal agrees with element-wise U32 equality.
import Base
import ../src/crypto/compare.bend as Compare
import ./crypto-compare-spec.bend as Spec

def and_true(+b: Bool) -> {b && True{} == b : Bool}:
  match b:
    case False{}:
      {==}
    case True{}:
      {==}

def and_assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a && b) && c == a && (b && c) : Bool}:
  match a:
    case False{}:
      {==}
    case True{}:
      {==}

def and_false(+z: Bool, +e: Bool) -> {(z && False{}) && e == z && False{} : Bool}:
  match z:
    case False{}:
      {==}
    case True{}:
      {==}

def fin_eq(+a: Bool, +b: Bool, +t: Cmp) -> {Cmp.is_eq(Word.cmp.fin(a, b, t)) == Cmp.is_eq(t) && Cmp.is_eq(Bool.cmp(a, b)) : Bool}:
  match t:
    case LT{}:
      {==}
    case EQ{}:
      {==}
    case GT{}:
      {==}

def or_bits(+x: Bool, +y: Bool, +a: Bool, +b: Bool) -> {(x && y) && Cmp.is_eq(Bool.cmp(Bool.or(a, b), False{})) == (x && Cmp.is_eq(Bool.cmp(a, False{}))) && (y && Cmp.is_eq(Bool.cmp(b, False{}))) : Bool}:
  match x y a b:
    case False{} _ _ _:
      {==}
    case True{} False{} False{} False{}:
      {==}
    case True{} False{} False{} True{}:
      {==}
    case True{} False{} True{} False{}:
      {==}
    case True{} False{} True{} True{}:
      {==}
    case True{} True{} False{} False{}:
      {==}
    case True{} True{} False{} True{}:
      {==}
    case True{} True{} True{} False{}:
      {==}
    case True{} True{} True{} True{}:
      {==}

def xor_bits(+a: Bool, +b: Bool) -> {Cmp.is_eq(Bool.cmp(Bool.xor(a, b), False{})) == Cmp.is_eq(Bool.cmp(a, b)) : Bool}:
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def or_step(+a: Bool, +b: Bool, +t: Cmp, +l: Cmp, +r: Cmp, ih: {Cmp.is_eq(t) == Cmp.is_eq(l) && Cmp.is_eq(r) : Bool}) -> {Cmp.is_eq(Word.cmp.fin(Bool.or(a, b), False{}, t)) == Cmp.is_eq(Word.cmp.fin(a, False{}, l)) && Cmp.is_eq(Word.cmp.fin(b, False{}, r)) : Bool}:
  +na = Cmp.is_eq(Bool.cmp(a, False{}))
  +nb = Cmp.is_eq(Bool.cmp(b, False{}))
  +no = Cmp.is_eq(Bool.cmp(Bool.or(a, b), False{}))
  +il = Cmp.is_eq(l)
  +ir = Cmp.is_eq(r)
  Equal.trans(Bool, Cmp.is_eq(Word.cmp.fin(Bool.or(a, b), False{}, t)), Cmp.is_eq(t) && no, Cmp.is_eq(Word.cmp.fin(a, False{}, l)) && Cmp.is_eq(Word.cmp.fin(b, False{}, r)),
    fin_eq(Bool.or(a, b), False{}, t),
    Equal.trans(Bool, Cmp.is_eq(t) && no, (il && ir) && no, Cmp.is_eq(Word.cmp.fin(a, False{}, l)) && Cmp.is_eq(Word.cmp.fin(b, False{}, r)),
      Equal.cong(Bool, Bool, v => v && no, Cmp.is_eq(t), il && ir, ih),
      Equal.trans(Bool, (il && ir) && no, (il && na) && (ir && nb), Cmp.is_eq(Word.cmp.fin(a, False{}, l)) && Cmp.is_eq(Word.cmp.fin(b, False{}, r)),
        or_bits(il, ir, a, b),
        Equal.trans(Bool, (il && na) && (ir && nb), Cmp.is_eq(Word.cmp.fin(a, False{}, l)) && (ir && nb), Cmp.is_eq(Word.cmp.fin(a, False{}, l)) && Cmp.is_eq(Word.cmp.fin(b, False{}, r)),
          Equal.cong(Bool, Bool, v => v && (ir && nb), il && na, Cmp.is_eq(Word.cmp.fin(a, False{}, l)), Equal.sym(Bool, Cmp.is_eq(Word.cmp.fin(a, False{}, l)), il && na, fin_eq(a, False{}, l))),
          Equal.cong(Bool, Bool, v => Cmp.is_eq(Word.cmp.fin(a, False{}, l)) && v, ir && nb, Cmp.is_eq(Word.cmp.fin(b, False{}, r)), Equal.sym(Bool, Cmp.is_eq(Word.cmp.fin(b, False{}, r)), ir && nb, fin_eq(b, False{}, r)))))))

def zero_or(+n: Nat, +a: Word(n), +b: Word(n)) -> {Cmp.is_eq(Word.cmp(n, Word.or(n, a, b), Word.zero(n))) == Cmp.is_eq(Word.cmp(n, a, Word.zero(n))) && Cmp.is_eq(Word.cmp(n, b, Word.zero(n))) : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match a b:
        case WCon{+ab, +at} WCon{+bb, +bt}:
          or_step(ab, bb, Word.cmp(p, Word.or(p, at, bt), Word.zero(p)), Word.cmp(p, at, Word.zero(p)), Word.cmp(p, bt, Word.zero(p)), zero_or(p, at, bt))

def xor_step(+a: Bool, +b: Bool, +t: Cmp, +c: Cmp, ih: {Cmp.is_eq(t) == Cmp.is_eq(c) : Bool}) -> {Cmp.is_eq(Word.cmp.fin(Bool.xor(a, b), False{}, t)) == Cmp.is_eq(Word.cmp.fin(a, b, c)) : Bool}:
  +nx = Cmp.is_eq(Bool.cmp(Bool.xor(a, b), False{}))
  +e = Cmp.is_eq(Bool.cmp(a, b))
  Equal.trans(Bool, Cmp.is_eq(Word.cmp.fin(Bool.xor(a, b), False{}, t)), Cmp.is_eq(t) && nx, Cmp.is_eq(Word.cmp.fin(a, b, c)),
    fin_eq(Bool.xor(a, b), False{}, t),
    Equal.trans(Bool, Cmp.is_eq(t) && nx, Cmp.is_eq(c) && nx, Cmp.is_eq(Word.cmp.fin(a, b, c)),
      Equal.cong(Bool, Bool, v => v && nx, Cmp.is_eq(t), Cmp.is_eq(c), ih),
      Equal.trans(Bool, Cmp.is_eq(c) && nx, Cmp.is_eq(c) && e, Cmp.is_eq(Word.cmp.fin(a, b, c)),
        Equal.cong(Bool, Bool, v => Cmp.is_eq(c) && v, nx, e, xor_bits(a, b)),
        Equal.sym(Bool, Cmp.is_eq(Word.cmp.fin(a, b, c)), Cmp.is_eq(c) && e, fin_eq(a, b, c)))))

def zero_xor(+n: Nat, +a: Word(n), +b: Word(n)) -> {Cmp.is_eq(Word.cmp(n, Word.xor(n, a, b), Word.zero(n))) == Cmp.is_eq(Word.cmp(n, a, b)) : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match a b:
        case WCon{+ab, +at} WCon{+bb, +bt}:
          xor_step(ab, bb, Word.cmp(p, Word.xor(p, at, bt), Word.zero(p)), Word.cmp(p, at, bt), zero_xor(p, at, bt))

def u32_or(+a: U32, +b: U32) -> {U32.is_zero(U32.or(a, b)) == U32.is_zero(a) && U32.is_zero(b) : Bool}:
  match a b:
    case U32{+x} U32{+y}:
      zero_or(32n, x, y)

def u32_xor(+a: U32, +b: U32) -> {U32.is_zero(U32.xor(a, b)) == U32.is_eq(a, b) : Bool}:
  match a b:
    case U32{+x} U32{+y}:
      zero_xor(32n, x, y)

def cons_step(+d: U32, +x: U32, +y: U32, +rest: Bool) -> {U32.is_zero(U32.or(d, U32.xor(x, y))) && rest == U32.is_zero(d) && (U32.is_eq(x, y) && rest) : Bool}:
  +z = U32.is_zero(d)
  Equal.trans(Bool, U32.is_zero(U32.or(d, U32.xor(x, y))) && rest, (z && U32.is_zero(U32.xor(x, y))) && rest, z && (U32.is_eq(x, y) && rest),
    Equal.cong(Bool, Bool, v => v && rest, U32.is_zero(U32.or(d, U32.xor(x, y))), z && U32.is_zero(U32.xor(x, y)), u32_or(d, U32.xor(x, y))),
    Equal.trans(Bool, (z && U32.is_zero(U32.xor(x, y))) && rest, (z && U32.is_eq(x, y)) && rest, z && (U32.is_eq(x, y) && rest),
      Equal.cong(Bool, Bool, v => (z && v) && rest, U32.is_zero(U32.xor(x, y)), U32.is_eq(x, y), u32_xor(x, y)),
      and_assoc(z, U32.is_eq(x, y), rest)))

def short_step(+d: U32, +rest: Bool) -> {U32.is_zero(U32.or(d, 1)) && rest == U32.is_zero(d) && False{} : Bool}:
  +z = U32.is_zero(d)
  Equal.trans(Bool, U32.is_zero(U32.or(d, 1)) && rest, (z && False{}) && rest, z && False{},
    Equal.cong(Bool, Bool, v => v && rest, U32.is_zero(U32.or(d, 1)), z && False{}, u32_or(d, 1)),
    and_false(z, rest))

def compare_go(+xs: List<&2, U32>, +ys: List<&2, U32>, +d: U32) -> {Compare.compare_go(xs, ys, d) == U32.is_zero(d) && Spec.equal(xs, ys) : Bool}:
  match xs ys:
    case Nil{} Nil{}:
      Equal.sym(Bool, U32.is_zero(d) && True{}, U32.is_zero(d), and_true(U32.is_zero(d)))
    case +x <> +xt +y <> +yt:
      Equal.trans(Bool, Compare.compare_go(xt, yt, U32.or(d, U32.xor(x, y))), U32.is_zero(U32.or(d, U32.xor(x, y))) && Spec.equal(xt, yt), U32.is_zero(d) && (U32.is_eq(x, y) && Spec.equal(xt, yt)),
        compare_go(xt, yt, U32.or(d, U32.xor(x, y))),
        cons_step(d, x, y, Spec.equal(xt, yt)))
    case +x <> +xt Nil{}:
      Equal.trans(Bool, Compare.compare_go(xt, [], U32.or(d, 1)), U32.is_zero(U32.or(d, 1)) && Spec.equal(xt, []), U32.is_zero(d) && False{},
        compare_go(xt, [], U32.or(d, 1)),
        short_step(d, Spec.equal(xt, [])))
    case Nil{} +y <> +yt:
      Equal.trans(Bool, Compare.compare_go([], yt, U32.or(d, 1)), U32.is_zero(U32.or(d, 1)) && Spec.equal([], yt), U32.is_zero(d) && False{},
        compare_go([], yt, U32.or(d, 1)),
        short_step(d, Spec.equal([], yt)))

def ct_equal(+xs: List<&2, U32>, +ys: List<&2, U32>) -> {Compare.ct_equal(xs, ys) == Spec.equal(xs, ys) : Bool}:
  compare_go(xs, ys, 0)

def bool_self(+h: Bool, +r: Bool, ih: {r == True{} : Bool}) -> {r && Cmp.is_eq(Bool.cmp(h, h)) == True{} : Bool}:
  match h:
    case False{}:
      Equal.trans(Bool, r && True{}, r, True{}, and_true(r), ih)
    case True{}:
      Equal.trans(Bool, r && True{}, r, True{}, and_true(r), ih)

def word_self(+n: Nat, +a: Word(n)) -> {Cmp.is_eq(Word.cmp(n, a, a)) == True{} : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match a:
        case WCon{+h, +t}:
          Equal.trans(Bool, Cmp.is_eq(Word.cmp.fin(h, h, Word.cmp(p, t, t))), Cmp.is_eq(Word.cmp(p, t, t)) && Cmp.is_eq(Bool.cmp(h, h)), True{},
            fin_eq(h, h, Word.cmp(p, t, t)),
            bool_self(h, Cmp.is_eq(Word.cmp(p, t, t)), word_self(p, t)))

def equal_self(+xs: List<&2, U32>) -> {Spec.equal(xs, xs) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case U32{+w} <> +t:
      Equal.trans(Bool, U32.is_eq(U32{w}, U32{w}) && Spec.equal(t, t), True{} && Spec.equal(t, t), True{},
        Equal.cong(Bool, Bool, v => v && Spec.equal(t, t), U32.is_eq(U32{w}, U32{w}), True{}, word_self(32n, w)),
        equal_self(t))
