import Base
import ./signed-cookie-spec.bend as Spec
import ../src/crypto/compare.bend as C

def zero(n: Nat, w: Word(n)) -> Bool:
  match n w:
    case 0n WNil{}: True{}
    case 1n+p WCon{b, t}: Bool.not(b) && zero(p, t)

def assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a && b) && c == a && (b && c) : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def and_false(+a: Bool) -> {a && False{} == False{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def cmp_fin(+a: Bool, +c: Cmp) -> {Cmp.is_eq(Word.cmp.fin(a, False{}, c)) == Bool.not(a) && Cmp.is_eq(c) : Bool}:
  match a c:
    case False{} EQ{}: {==}
    case False{} LT{}: {==}
    case False{} GT{}: {==}
    case True{} EQ{}: {==}
    case True{} LT{}: {==}
    case True{} GT{}: {==}

def zero_cmp(+n: Nat, +w: Word(n)) -> {Cmp.is_eq(Word.cmp(n, w, Word.zero(n))) == zero(n, w) : Bool}:
  match n w:
    case 0n WNil{}: {==}
    case 1n+p WCon{+b, +t}:
      Equal.trans(Bool, Cmp.is_eq(Word.cmp.fin(b, False{}, Word.cmp(p, t, Word.zero(p)))), Bool.not(b) && Cmp.is_eq(Word.cmp(p, t, Word.zero(p))), Bool.not(b) && zero(p, t), cmp_fin(b, Word.cmp(p, t, Word.zero(p))), Equal.cong(Bool, Bool, x => Bool.not(b) && x, Cmp.is_eq(Word.cmp(p, t, Word.zero(p))), zero(p, t), zero_cmp(p, t)))

def combine(+d: Bool, +a: Bool, +b: Bool, +dt: Bool, +eq: Bool) -> {Bool.not(Bool.or(d, Bool.xor(a, b))) && (dt && eq) == (Bool.not(d) && dt) && (Spec.bit_equal(a, b) && eq) : Bool}:
  match d a b:
    case False{} False{} False{}: {==}
    case False{} True{} True{}: {==}
    case False{} False{} True{}: Equal.sym(Bool, dt && False{}, False{}, and_false(dt))
    case False{} True{} False{}: Equal.sym(Bool, dt && False{}, False{}, and_false(dt))
    case True{} _ _: {==}

def bits(+n: Nat, +d: Word(n), +a: Word(n), +b: Word(n)) -> {zero(n, Word.or(n, d, Word.xor(n, a, b))) == zero(n, d) && Spec.word_equal(n, a, b) : Bool}:
  match n d a b:
    case 0n WNil{} WNil{} WNil{}: {==}
    case 1n+p WCon{+dh, +dt} WCon{+ah, +at} WCon{+bh, +bt}:
      Equal.trans(Bool, Bool.not(Bool.or(dh, Bool.xor(ah, bh))) && zero(p, Word.or(p, dt, Word.xor(p, at, bt))), Bool.not(Bool.or(dh, Bool.xor(ah, bh))) && (zero(p, dt) && Spec.word_equal(p, at, bt)), (Bool.not(dh) && zero(p, dt)) && (Spec.bit_equal(ah, bh) && Spec.word_equal(p, at, bt)), Equal.cong(Bool, Bool, x => Bool.not(Bool.or(dh, Bool.xor(ah, bh))) && x, zero(p, Word.or(p, dt, Word.xor(p, at, bt))), zero(p, dt) && Spec.word_equal(p, at, bt), bits(p, dt, at, bt)), combine(dh, ah, bh, zero(p, dt), Spec.word_equal(p, at, bt)))

def z(d: U32) -> Bool:
  match d:
    case U32{w}: zero(32n, w)

def z_or_one(+d: U32) -> {z(U32.or(d, 1)) == False{} : Bool}:
  match d:
    case U32{WCon{b, t}}:
      match b:
        case False{}: {==}
        case True{}: {==}

def z_bits(+d: U32, +a: U32, +b: U32) -> {z(U32.or(d, U32.xor(a, b))) == z(d) && Spec.u32_equal(a, b) : Bool}:
  match d a b:
    case U32{dw} U32{aw} U32{bw}: bits(32n, dw, aw, bw)

def true_right(+a: Bool) -> {a && True{} == a : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def acc(+xs: List<&2, U32>, +ys: List<&2, U32>, +d: U32) -> {C.compare_go(xs, ys, d) == z(d) && Spec.bytes_equal(xs, ys) : Bool}:
  match xs ys:
    case Nil{} Nil{}:
      match d:
        case U32{w}:
          Equal.trans(Bool, U32.is_zero(U32{w}), zero(32n, w), zero(32n, w) && True{}, zero_cmp(32n, w), Equal.sym(Bool, zero(32n, w) && True{}, zero(32n, w), true_right(zero(32n, w))))
    case +x <> +xt Nil{}:
      Equal.trans(Bool, C.compare_go(xt, [], U32.or(d, 1)), z(U32.or(d, 1)) && Spec.bytes_equal(xt, []), z(d) && False{}, acc(xt, [], U32.or(d, 1)), Equal.trans(Bool, z(U32.or(d, 1)) && Spec.bytes_equal(xt, []), False{}, z(d) && False{}, Equal.cong(Bool, Bool, q => q && Spec.bytes_equal(xt, []), z(U32.or(d, 1)), False{}, z_or_one(d)), Equal.sym(Bool, z(d) && False{}, False{}, and_false(z(d)))))
    case Nil{} +y <> +yt:
      Equal.trans(Bool, C.compare_go([], yt, U32.or(d, 1)), z(U32.or(d, 1)) && Spec.bytes_equal([], yt), z(d) && False{}, acc([], yt, U32.or(d, 1)), Equal.trans(Bool, z(U32.or(d, 1)) && Spec.bytes_equal([], yt), False{}, z(d) && False{}, Equal.cong(Bool, Bool, q => q && Spec.bytes_equal([], yt), z(U32.or(d, 1)), False{}, z_or_one(d)), Equal.sym(Bool, z(d) && False{}, False{}, and_false(z(d)))))
    case U32{+a} <> +xt U32{+b} <> +yt:
      Equal.trans(Bool, C.compare_go(xt, yt, U32.or(d, U32.xor(U32{a}, U32{b}))), z(U32.or(d, U32.xor(U32{a}, U32{b}))) && Spec.bytes_equal(xt, yt), z(d) && (Spec.word_equal(32n, a, b) && Spec.bytes_equal(xt, yt)), acc(xt, yt, U32.or(d, U32.xor(U32{a}, U32{b}))), Equal.trans(Bool, z(U32.or(d, U32.xor(U32{a}, U32{b}))) && Spec.bytes_equal(xt, yt), (z(d) && Spec.word_equal(32n, a, b)) && Spec.bytes_equal(xt, yt), z(d) && (Spec.word_equal(32n, a, b) && Spec.bytes_equal(xt, yt)), Equal.cong(Bool, Bool, q => q && Spec.bytes_equal(xt, yt), z(U32.or(d, U32.xor(U32{a}, U32{b}))), z(d) && Spec.word_equal(32n, a, b), z_bits(d, U32{a}, U32{b})), assoc(z(d), Spec.word_equal(32n, a, b), Spec.bytes_equal(xt, yt))))

def equal(+xs: List<&2, U32>, +ys: List<&2, U32>) -> {C.ct_equal(xs, ys) == Spec.bytes_equal(xs, ys) : Bool}:
  acc(xs, ys, 0)
