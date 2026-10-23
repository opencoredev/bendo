# Foundational positional facts for runtime decimal coefficients.
import Base
import ../src/data/decimal-coefficient.bend as D
import ../src/data/decimal-natural.bend as N
import ../src/data/schema-spec.bend as Spec
import ./schema-number-natural-cmp.bend as C
import ./schema-number-natural.bend as A
import ./schema-number-natural-valid.bend as V
import ./schema-number-arith.bend as Arith
import ./schema-number-scaled.bend as S
import ./chunked-arith.bend as K
import ./utf8.bend as U

def length(ds: N.Digits) -> Nat:
  match ds:
    case N.End{}: 0n
    case N.Digit{d, t}: 1n+length(t)

def val(ds: N.Digits) -> Nat:
  match ds:
    case N.End{}: 0n
    case N.Digit{d, +t}: Nat.add(Nat.mul(d, Nat.pow(10n, length(t))), val(t))

def runtime_length_go(+ds: N.Digits, +n: Nat) -> {D.length_go(ds, n) == Nat.add(length(ds), n) : Nat}:
  match ds:
    case N.End{}: {==}
    case N.Digit{d, +t}:
      Equal.trans(Nat, D.length_go(t, 1n+n), Nat.add(length(t), 1n+n), 1n+Nat.add(length(t), n), runtime_length_go(t, 1n+n), K.add_succ_r(length(t), n))

def runtime_length(+ds: N.Digits) -> {D.length(ds) == length(ds) : Nat}:
  Equal.trans(Nat, D.length(ds), Nat.add(length(ds), 0n), length(ds), runtime_length_go(ds, 0n), K.add_zero_r(length(ds)))

def finish_value(+ds: N.Digits, +n: Nat) -> {A.finish(ds, n) == Nat.add(Nat.mul(n, Nat.pow(10n, length(ds))), val(ds)) : Nat}:
  match ds:
    case N.End{}:
      Equal.sym(Nat, Nat.add(Nat.mul(n, 1n), 0n), n, Equal.trans(Nat, Nat.add(Nat.mul(n, 1n), 0n), Nat.mul(n, 1n), n, K.add_zero_r(Nat.mul(n, 1n)), Arith.mul_one(n)))
    case N.Digit{+d, +t}:
      %Arith.mul_comm(n, 10n) : {A.finish(t, Nat.add(d, _)) == Nat.add(Nat.mul(n, Nat.pow(10n, 1n+length(t))), Nat.add(Nat.mul(d, Nat.pow(10n, length(t))), val(t))) : Nat}
      %Arith.add_comm(Nat.mul(n, 10n), d) : {A.finish(t, _) == Nat.add(Nat.mul(n, Nat.pow(10n, 1n+length(t))), Nat.add(Nat.mul(d, Nat.pow(10n, length(t))), val(t))) : Nat}
      Equal.trans(Nat, A.finish(t, Nat.add(Nat.mul(n, 10n), d)), Nat.add(Nat.mul(Nat.add(Nat.mul(n, 10n), d), Nat.pow(10n, length(t))), val(t)), Nat.add(Nat.mul(n, Nat.pow(10n, 1n+length(t))), Nat.add(Nat.mul(d, Nat.pow(10n, length(t))), val(t))), finish_value(t, Nat.add(Nat.mul(n, 10n), d)), Arith.positional_step(n, d, Nat.pow(10n, length(t)), val(t)))

def reverse_value(+ds: N.Digits) -> {C.value(N.reverse(ds)) == val(ds) : Nat}:
  Equal.trans(Nat, C.value(N.reverse(ds)), A.finish(ds, 0n), val(ds), A.reverse_value(ds, N.End{}), finish_value(ds, 0n))

def read_go_value(+s: String, +acc: N.Digits) -> {C.value(D.read_go(s, acc)) == Spec.value(s, C.value(acc)) : Nat}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      %Arith.add_comm(Spec.digit_value(c), Nat.mul(C.value(acc), 10n)) : {C.value(D.read_go(t, N.Digit{Spec.digit_value(c), acc})) == Spec.value(t, _) : Nat}
      %Arith.mul_comm(10n, C.value(acc)) : {C.value(D.read_go(t, N.Digit{Spec.digit_value(c), acc})) == Spec.value(t, Nat.add(Spec.digit_value(c), _)) : Nat}
      read_go_value(t, N.Digit{Spec.digit_value(c), acc})

def read_value(+s: String) -> {C.value(D.read(s)) == Spec.value(s, 0n) : Nat}:
  read_go_value(s, N.End{})

def read_go_valid(+s: String, +acc: N.Digits, +e: {Spec.digits(s) == True{} : Bool}, va: C.valid(acc)) -> C.valid(D.read_go(s, acc)):
  match s:
    case SNil{}: va
    case SCon{Chr{+c}, +t}:
      read_go_valid(t, N.Digit{Spec.digit_value(c), acc}, U.and_right(Spec.digit(c), Spec.digits(t), e), (Arith.digit_bound(c, U.and_left(Spec.digit(c), Spec.digits(t), e)), va))

def read_valid(+s: String, e: {Spec.digits(s) == True{} : Bool}) -> C.valid(D.read(s)):
  read_go_valid(s, N.End{}, e, Unit{})

def trim_value(+ds: N.Digits) -> {val(D.trim(ds)) == val(ds) : Nat}:
  match ds:
    case N.End{}: {==}
    case N.Digit{0n, +t}: trim_value(t)
    case N.Digit{1n+d, t}: {==}

def trim_valid(+ds: N.Digits, v: C.valid(ds)) -> C.valid(D.trim(ds)):
  match ds:
    case N.End{}: Unit{}
    case N.Digit{0n, +t}:
      (b, vt) = v
      trim_valid(t, vt)
    case N.Digit{1n+d, t}: v

def coefficient_valid(+s: String, e: {Spec.digits(s) == True{} : Bool}) -> C.valid(D.coefficient(s)):
  trim_valid(N.reverse(D.read(s)), V.reverse(D.read(s), read_valid(s, e)))

def coefficient_reverse_valid(+s: String, e: {Spec.digits(s) == True{} : Bool}) -> C.valid(N.reverse(D.coefficient(s))):
  V.reverse(D.coefficient(s), coefficient_valid(s, e))

def zeros_valid(+n: Nat, +ds: N.Digits, v: C.valid(ds)) -> C.valid(D.zeros(n, ds)):
  match n:
    case 0n: v
    case 1n+k: zeros_valid(k, N.Digit{0n, ds}, ({==}, v))

def zeros_value(+n: Nat, +ds: N.Digits) -> {C.value(D.zeros(n, ds)) == Nat.mul(C.value(ds), Nat.pow(10n, n)) : Nat}:
  match n:
    case 0n: Equal.sym(Nat, Nat.mul(C.value(ds), 1n), C.value(ds), Arith.mul_one(C.value(ds)))
    case 1n+k:
      Equal.trans(Nat, C.value(D.zeros(k, N.Digit{0n, ds})), Nat.mul(Nat.mul(10n, C.value(ds)), Nat.pow(10n, k)), Nat.mul(C.value(ds), Nat.pow(10n, 1n+k)), zeros_value(k, N.Digit{0n, ds}), Equal.trans(Nat, Nat.mul(Nat.mul(10n, C.value(ds)), Nat.pow(10n, k)), Nat.mul(Nat.mul(C.value(ds), 10n), Nat.pow(10n, k)), Nat.mul(C.value(ds), Nat.pow(10n, 1n+k)), Equal.cong(Nat, Nat, x => Nat.mul(x, Nat.pow(10n, k)), Nat.mul(10n, C.value(ds)), Nat.mul(C.value(ds), 10n), Arith.mul_comm(10n, C.value(ds))), Arith.mul_assoc(C.value(ds), 10n, Nat.pow(10n, k))))

def padded(+a: N.Digits, +b: N.Digits, va: C.valid(a), vb: C.valid(b)) -> {D.padded(a, b) == Nat.cmp(Nat.mul(val(a), Nat.pow(10n, D.length(b))), Nat.mul(val(b), Nat.pow(10n, D.length(a)))) : Cmp}:
  %reverse_value(a) : {D.padded(a, b) == Nat.cmp(Nat.mul(_, Nat.pow(10n, D.length(b))), Nat.mul(val(b), Nat.pow(10n, D.length(a)))) : Cmp}
  %reverse_value(b) : {D.padded(a, b) == Nat.cmp(Nat.mul(C.value(N.reverse(a)), Nat.pow(10n, D.length(b))), Nat.mul(_, Nat.pow(10n, D.length(a)))) : Cmp}
  %zeros_value(D.length(b), N.reverse(a)) : {D.padded(a, b) == Nat.cmp(_, Nat.mul(C.value(N.reverse(b)), Nat.pow(10n, D.length(a)))) : Cmp}
  %zeros_value(D.length(a), N.reverse(b)) : {D.padded(a, b) == Nat.cmp(C.value(D.zeros(D.length(b), N.reverse(a))), _) : Cmp}
  C.cmp(D.zeros(D.length(b), N.reverse(a)), D.zeros(D.length(a), N.reverse(b)), zeros_valid(D.length(b), N.reverse(a), V.reverse(a, va)), zeros_valid(D.length(a), N.reverse(b), V.reverse(b, vb)))

def append(a: N.Digits, +b: N.Digits) -> N.Digits:
  match a:
    case N.End{}: b
    case N.Digit{d, t}: N.Digit{d, append(t, b)}

def append_end(+ds: N.Digits) -> {append(ds, N.End{}) == ds : N.Digits}:
  match ds:
    case N.End{}: {==}
    case N.Digit{+d, +t}: Equal.cong(N.Digits, N.Digits, x => N.Digit{d, x}, append(t, N.End{}), t, append_end(t))

def reverse_twice_go(+ds: N.Digits, +acc: N.Digits, +tail: N.Digits) -> {N.reverse_go(N.reverse_go(ds, acc), tail) == N.reverse_go(acc, append(ds, tail)) : N.Digits}:
  match ds:
    case N.End{}: {==}
    case N.Digit{d, t}: reverse_twice_go(t, N.Digit{d, acc}, tail)

def reverse_twice(+ds: N.Digits) -> {N.reverse(N.reverse(ds)) == ds : N.Digits}:
  Equal.trans(N.Digits, N.reverse(N.reverse(ds)), append(ds, N.End{}), ds, reverse_twice_go(ds, N.End{}, N.End{}), append_end(ds))

def coefficient_value(+s: String) -> {val(D.coefficient(s)) == Spec.value(s, 0n) : Nat}:
  Equal.trans(Nat, val(D.coefficient(s)), val(N.reverse(D.read(s))), Spec.value(s, 0n), trim_value(N.reverse(D.read(s))),
    Equal.trans(Nat, val(N.reverse(D.read(s))), C.value(N.reverse(N.reverse(D.read(s)))), Spec.value(s, 0n), Equal.sym(Nat, C.value(N.reverse(N.reverse(D.read(s)))), val(N.reverse(D.read(s))), reverse_value(N.reverse(D.read(s)))),
      Equal.trans(Nat, C.value(N.reverse(N.reverse(D.read(s)))), C.value(D.read(s)), Spec.value(s, 0n), Equal.cong(N.Digits, Nat, x => C.value(x), N.reverse(N.reverse(D.read(s))), D.read(s), reverse_twice(D.read(s))), read_value(s))))

# Strict inequalities are represented as successor-inclusive bounds here.
def upper(+ds: N.Digits, v: C.valid(ds)) -> {Nat.is_le(1n+val(ds), Nat.pow(10n, length(ds))) == True{} : Bool}:
  match ds:
    case N.End{}: {==}
    case N.Digit{+d, +t}:
      (bd, vt) = v
      %K.add_succ_r(Nat.mul(d, Nat.pow(10n, length(t))), val(t)) : {Nat.is_le(_, Nat.pow(10n, 1n+length(t))) == True{} : Bool}
      %Arith.add_comm(Nat.mul(9n, Nat.pow(10n, length(t))), Nat.pow(10n, length(t))) : {Nat.is_le(Nat.add(Nat.mul(d, Nat.pow(10n, length(t))), 1n+val(t)), _) == True{} : Bool}
      V.add_le(Nat.mul(d, Nat.pow(10n, length(t))), 1n+val(t), Nat.mul(9n, Nat.pow(10n, length(t))), Nat.pow(10n, length(t)), S.le_scale(d, 9n, length(t), bd), upper(t, vt))

def lower_head(+d: Nat, +t: N.Digits) -> {Nat.is_le(Nat.pow(10n, length(t)), val(N.Digit{1n+d, t})) == True{} : Bool}:
  %Equal.sym(Nat, Nat.add(Nat.add(Nat.pow(10n, length(t)), Nat.mul(d, Nat.pow(10n, length(t)))), val(t)), Nat.add(Nat.pow(10n, length(t)), Nat.add(Nat.mul(d, Nat.pow(10n, length(t))), val(t))), Arith.add_assoc(Nat.pow(10n, length(t)), Nat.mul(d, Nat.pow(10n, length(t))), val(t))) : {Nat.is_le(Nat.pow(10n, length(t)), _) == True{} : Bool}
  S.le_add(Nat.pow(10n, length(t)), Nat.add(Nat.mul(d, Nat.pow(10n, length(t))), val(t)))

def trimmed(ds: N.Digits) -> Type:
  match ds:
    case N.End{}: Unit
    case N.Digit{0n, t}: Empty
    case N.Digit{1n+d, t}: Unit

def trim_trimmed(+ds: N.Digits) -> trimmed(D.trim(ds)):
  match ds:
    case N.End{}: Unit{}
    case N.Digit{0n, +t}: trim_trimmed(t)
    case N.Digit{1n+d, t}: Unit{}

def sub_zero(+n: Nat) -> {Nat.sub(n, 0n) == n : Nat}:
  match n:
    case 0n: {==}
    case 1n+k: {==}

def lower(+ds: N.Digits, h: trimmed(ds)) -> {Nat.is_le(Nat.pow(10n, Nat.sub(length(ds), 1n)), val(ds)) == Bool.not(D.is_zero(ds)) : Bool}:
  match ds:
    case N.End{}: {==}
    case N.Digit{0n, t}: S.absurd({Nat.is_le(Nat.pow(10n, Nat.sub(length(t), 0n)), val(t)) == True{} : Bool}, h)
    case N.Digit{1n+d, +t}:
      %Equal.sym(Nat, Nat.sub(length(t), 0n), length(t), sub_zero(length(t))) : {Nat.is_le(Nat.pow(10n, _), val(N.Digit{1n+d, t})) == True{} : Bool}
      lower_head(d, t)

def positive_not_zero(+n: Nat, e: {Nat.is_le(1n, n) == True{} : Bool}) -> {Nat.is_eq(n, 0n) == False{} : Bool}:
  match n:
    case 0n: S.absurd({True{} == False{} : Bool}, S.false_true(e))
    case 1n+k: {==}

def head_not_zero(+d: Nat, +t: N.Digits) -> {Nat.is_eq(val(N.Digit{1n+d, t}), 0n) == False{} : Bool}:
  positive_not_zero(val(N.Digit{1n+d, t}), S.le_trans(1n, Nat.pow(10n, length(t)), val(N.Digit{1n+d, t}), S.power_positive(length(t)), lower_head(d, t)))

def trim_zero(+ds: N.Digits) -> {D.is_zero(D.trim(ds)) == Nat.is_eq(val(ds), 0n) : Bool}:
  match ds:
    case N.End{}: {==}
    case N.Digit{0n, +t}: trim_zero(t)
    case N.Digit{1n+d, +t}: Equal.sym(Bool, Nat.is_eq(val(N.Digit{1n+d, t}), 0n), False{}, head_not_zero(d, t))

def coefficient_zero(+s: String) -> {D.is_zero(D.coefficient(s)) == Nat.is_eq(Spec.value(s, 0n), 0n) : Bool}:
  %coefficient_value(s) : {D.is_zero(D.coefficient(s)) == Nat.is_eq(_, 0n) : Bool}
  %Equal.sym(Nat, val(D.trim(N.reverse(D.read(s)))), val(N.reverse(D.read(s))), trim_value(N.reverse(D.read(s)))) : {D.is_zero(D.coefficient(s)) == Nat.is_eq(_, 0n) : Bool}
  trim_zero(N.reverse(D.read(s)))

def upper_lt(+ds: N.Digits, v: C.valid(ds)) -> {Nat.is_lt(val(ds), Nat.pow(10n, length(ds))) == True{} : Bool}:
  Equal.cong(Cmp, Bool, x => Cmp.is_lt(x), Nat.cmp(val(ds), Nat.pow(10n, length(ds))), LT{}, K.succ_le_lt(val(ds), Nat.pow(10n, length(ds)), upper(ds, v)))

def lower_nonempty(+ds: N.Digits, h: trimmed(ds), nz: {D.is_zero(ds) == False{} : Bool}) -> {Nat.is_le(Nat.pow(10n, Nat.sub(length(ds), 1n)), val(ds)) == True{} : Bool}:
  %nz : {Nat.is_le(Nat.pow(10n, Nat.sub(length(ds), 1n)), val(ds)) == Bool.not(_) : Bool}
  lower(ds, h)

def lower_length(+ds: N.Digits, +n: Nat, h: trimmed(ds), nz: {D.is_zero(ds) == False{} : Bool}, len: {length(ds) == 1n+n : Nat}) -> {Nat.is_le(Nat.pow(10n, n), val(ds)) == True{} : Bool}:
  %sub_zero(n) : {Nat.is_le(Nat.pow(10n, _), val(ds)) == True{} : Bool}
  %len : {Nat.is_le(Nat.pow(10n, Nat.sub(_, 1n)), val(ds)) == True{} : Bool}
  lower_nonempty(ds, h, nz)

def upper_length(+ds: N.Digits, +n: Nat, v: C.valid(ds), len: {length(ds) == 1n+n : Nat}) -> {Nat.is_lt(val(ds), Nat.pow(10n, 1n+n)) == True{} : Bool}:
  %len : {Nat.is_lt(val(ds), Nat.pow(10n, _)) == True{} : Bool}
  upper_lt(ds, v)
