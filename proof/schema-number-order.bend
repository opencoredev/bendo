# Assemble the parser, decimal sums and coefficient bounds into exact order.
import Base
import ../src/data/decimal.bend as D
import ../src/data/decimal-natural.bend as N
import ../src/data/decimal-coefficient.bend as Co
import ../src/data/decimal-parts.bend as DP
import ../src/data/schema-spec.bend as Spec
import ./schema-number-parts.bend as P
import ./schema-number-coefficient.bend as K
import ./schema-number-rank.bend as R
import ./schema-number-scaled.bend as S
import ./schema-number-parts-valid.bend as PV
import ./chunked-arith.bend as A

def lower(ds: N.Digits) -> Data:
  {Nat.is_le(Nat.pow(10n, Nat.sub(K.length(ds), 1n)), K.val(ds)) == Bool.not(Co.is_zero(ds)) : Bool}

def upper(ds: N.Digits) -> Data:
  {Nat.is_le(1n+K.val(ds), Nat.pow(10n, K.length(ds))) == True{} : Bool}

def sub_zero(+n: Nat) -> {Nat.sub(n, 0n) == n : Nat}:
  match n:
    case 0n: {==}
    case 1n+k: {==}

def lower_length(+d: Nat, +t: N.Digits, e: lower(N.Digit{d, t})) -> {Nat.is_le(Nat.pow(10n, K.length(t)), K.val(N.Digit{d, t})) == True{} : Bool}:
  %sub_zero(K.length(t)) : {Nat.is_le(Nat.pow(10n, _), K.val(N.Digit{d, t})) == True{} : Bool}
  e

def positive_nat(+n: Nat, e: {Nat.is_le(1n, n) == True{} : Bool}) -> {Nat.cmp(0n, n) == LT{} : Cmp}:
  match n:
    case 0n: S.absurd({EQ{} == LT{} : Cmp}, S.false_true(e))
    case 1n+k: {==}

def negative_nat(+n: Nat, e: {Nat.is_le(1n, n) == True{} : Bool}) -> {Nat.cmp(n, 0n) == GT{} : Cmp}:
  match n:
    case 0n: S.absurd({EQ{} == GT{} : Cmp}, S.false_true(e))
    case 1n+k: {==}

def lower_positive(+v: Nat, +n: Nat, +s: Nat, e: {Nat.is_le(Nat.pow(10n, n), v) == True{} : Bool}) -> {Nat.is_le(1n, Nat.mul(v, Nat.pow(10n, s))) == True{} : Bool}:
  S.le_trans(1n, Nat.pow(10n, Nat.add(n, s)), Nat.mul(v, Nat.pow(10n, s)), S.power_positive(Nat.add(n, s)), S.scaled_lower(v, n, s, e))

def upper_lt(+v: Nat, +n: Nat, e: {Nat.is_le(1n+v, Nat.pow(10n, n)) == True{} : Bool}) -> {Nat.is_lt(v, Nat.pow(10n, n)) == True{} : Bool}:
  Equal.cong(Cmp, Bool, c => Cmp.is_lt(c), Nat.cmp(v, Nat.pow(10n, n)), LT{}, A.succ_le_lt(v, Nat.pow(10n, n), e))

def choose(+c: Cmp, +d: Cmp) -> {N.choose(c, d) == S.choose(c, d) : Cmp}:
  match c:
    case LT{}: {==}
    case EQ{}: {==}
    case GT{}: {==}

def positive_values(+a: Spec.Parts, +b: Spec.Parts, +x: N.Digits, +y: N.Digits,
    +ea: R.exponent_valid(a), +eb: R.exponent_valid(b), lx: lower(x), ly: lower(y), ux: upper(x), uy: upper(y),
    pad: {Co.padded(x, y) == Nat.cmp(Nat.mul(K.val(x), Nat.pow(10n, Co.length(y))), Nat.mul(K.val(y), Nat.pow(10n, Co.length(x)))) : Cmp}) ->
    {D.positive(P.convert(a), P.convert(b), x, y) == Nat.cmp(Nat.mul(K.val(x), Nat.pow(10n, R.shift(a, b))), Nat.mul(K.val(y), Nat.pow(10n, R.shift(b, a)))) : Cmp}:
  match x y:
    case N.End{} N.End{}: {==}
    case N.End{} N.Digit{+e, +u}:
      Equal.sym(Cmp, Nat.cmp(0n, Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, R.shift(b, a)))), LT{}, positive_nat(Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, R.shift(b, a))), lower_positive(K.val(N.Digit{e, u}), K.length(u), R.shift(b, a), lower_length(e, u, ly))))
    case N.Digit{+d, +t} N.End{}:
      Equal.sym(Cmp, Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, R.shift(a, b))), 0n), GT{}, negative_nat(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, R.shift(a, b))), lower_positive(K.val(N.Digit{d, t}), K.length(t), R.shift(a, b), lower_length(d, t, lx))))
    case N.Digit{+d, +t} N.Digit{+e, +u}:
      %Equal.sym(Cmp, N.cmp(D.rank(P.convert(a), P.convert(b), N.Digit{d, t}), D.rank(P.convert(b), P.convert(a), N.Digit{e, u})), Nat.cmp(Nat.add(Co.length(N.Digit{d, t}), R.shift(a, b)), Nat.add(Co.length(N.Digit{e, u}), R.shift(b, a))), R.rank_cmp(a, b, N.Digit{d, t}, N.Digit{e, u}, ea, eb)) : {N.choose(_, Co.padded(N.Digit{d, t}, N.Digit{e, u})) == Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, R.shift(a, b))), Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, R.shift(b, a)))) : Cmp}
      %Equal.sym(Cmp, Co.padded(N.Digit{d, t}, N.Digit{e, u}), Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, Co.length(N.Digit{e, u}))), Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, Co.length(N.Digit{d, t})))), pad) : {N.choose(Nat.cmp(Nat.add(Co.length(N.Digit{d, t}), R.shift(a, b)), Nat.add(Co.length(N.Digit{e, u}), R.shift(b, a))), _) == Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, R.shift(a, b))), Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, R.shift(b, a)))) : Cmp}
      %Equal.sym(Nat, Co.length(N.Digit{d, t}), K.length(N.Digit{d, t}), K.runtime_length(N.Digit{d, t})) : {N.choose(Nat.cmp(Nat.add(_, R.shift(a, b)), Nat.add(Co.length(N.Digit{e, u}), R.shift(b, a))), Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, Co.length(N.Digit{e, u}))), Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, _)))) == Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, R.shift(a, b))), Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, R.shift(b, a)))) : Cmp}
      %Equal.sym(Nat, Co.length(N.Digit{e, u}), K.length(N.Digit{e, u}), K.runtime_length(N.Digit{e, u})) : {N.choose(Nat.cmp(Nat.add(K.length(N.Digit{d, t}), R.shift(a, b)), Nat.add(_, R.shift(b, a))), Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, _)), Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, K.length(N.Digit{d, t}))))) == Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, R.shift(a, b))), Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, R.shift(b, a)))) : Cmp}
      Equal.trans(Cmp,
        N.choose(Nat.cmp(Nat.add(1n+K.length(t), R.shift(a, b)), Nat.add(1n+K.length(u), R.shift(b, a))), Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, 1n+K.length(u))), Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, 1n+K.length(t))))),
        S.choose(Nat.cmp(Nat.add(1n+K.length(t), R.shift(a, b)), Nat.add(1n+K.length(u), R.shift(b, a))), Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, 1n+K.length(u))), Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, 1n+K.length(t))))),
        Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, R.shift(a, b))), Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, R.shift(b, a)))),
        choose(Nat.cmp(Nat.add(1n+K.length(t), R.shift(a, b)), Nat.add(1n+K.length(u), R.shift(b, a))), Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, 1n+K.length(u))), Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, 1n+K.length(t))))),
        Equal.sym(Cmp,
          Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, R.shift(a, b))), Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, R.shift(b, a)))),
          S.choose(Nat.cmp(Nat.add(1n+K.length(t), R.shift(a, b)), Nat.add(1n+K.length(u), R.shift(b, a))), Nat.cmp(Nat.mul(K.val(N.Digit{d, t}), Nat.pow(10n, 1n+K.length(u))), Nat.mul(K.val(N.Digit{e, u}), Nat.pow(10n, 1n+K.length(t))))),
          S.scaled_coefficients(K.val(N.Digit{d, t}), K.val(N.Digit{e, u}), K.length(t), K.length(u), R.shift(a, b), R.shift(b, a), lower_length(d, t, lx), upper_lt(K.val(N.Digit{d, t}), 1n+K.length(t), ux), lower_length(e, u, ly), upper_lt(K.val(N.Digit{e, u}), 1n+K.length(u), uy))))

def magnitude_values(+a: Spec.Parts, +b: Spec.Parts, +x: N.Digits, +y: N.Digits, ax: {K.val(x) == Spec.magnitude(a) : Nat}, by: {K.val(y) == Spec.magnitude(b) : Nat}) -> {Nat.cmp(Nat.mul(K.val(x), Nat.pow(10n, R.shift(a, b))), Nat.mul(K.val(y), Nat.pow(10n, R.shift(b, a)))) == Spec.magnitude_cmp(a, b) : Cmp}:
  %ax : {Nat.cmp(Nat.mul(K.val(x), Nat.pow(10n, R.shift(a, b))), Nat.mul(K.val(y), Nat.pow(10n, R.shift(b, a)))) == Nat.cmp(Nat.mul(_, Nat.pow(10n, R.shift(a, b))), Nat.mul(Spec.magnitude(b), Nat.pow(10n, R.shift(b, a)))) : Cmp}
  %by : {Nat.cmp(Nat.mul(K.val(x), Nat.pow(10n, R.shift(a, b))), Nat.mul(K.val(y), Nat.pow(10n, R.shift(b, a)))) == Nat.cmp(Nat.mul(K.val(x), Nat.pow(10n, R.shift(a, b))), Nat.mul(_, Nat.pow(10n, R.shift(b, a)))) : Cmp}
  {==}

def positive_exact(+a: Spec.Parts, +b: Spec.Parts, +x: N.Digits, +y: N.Digits,
    ea: R.exponent_valid(a), eb: R.exponent_valid(b), lx: lower(x), ly: lower(y), ux: upper(x), uy: upper(y),
    pad: {Co.padded(x, y) == Nat.cmp(Nat.mul(K.val(x), Nat.pow(10n, Co.length(y))), Nat.mul(K.val(y), Nat.pow(10n, Co.length(x)))) : Cmp},
    ax: {K.val(x) == Spec.magnitude(a) : Nat}, by: {K.val(y) == Spec.magnitude(b) : Nat}) -> {D.positive(P.convert(a), P.convert(b), x, y) == Spec.magnitude_cmp(a, b) : Cmp}:
  Equal.trans(Cmp,
    D.positive(P.convert(a), P.convert(b), x, y),
    Nat.cmp(Nat.mul(K.val(x), Nat.pow(10n, R.shift(a, b))), Nat.mul(K.val(y), Nat.pow(10n, R.shift(b, a)))),
    Spec.magnitude_cmp(a, b), positive_values(a, b, x, y, ea, eb, lx, ly, ux, uy, pad), magnitude_values(a, b, x, y, ax, by))

def coefficient(p: Spec.Parts) -> N.Digits:
  Spec.Parts{n, d, f, en, x} = p
  Co.coefficient(d)

def negative(+p: Spec.Parts) -> {D.negative(P.convert(p), coefficient(p)) == Spec.below_zero(p) : Bool}:
  match p:
    case Spec.Parts{+n, +d, f, en, x}:
      Equal.cong(Bool, Bool, b => n && Bool.not(b), Co.is_zero(Co.coefficient(d)), Nat.is_eq(Spec.value(d, 0n), 0n), K.coefficient_zero(d))

def positive_parts(+a: Spec.Parts, +b: Spec.Parts, va: PV.valid(a), vb: PV.valid(b)) -> {D.positive(P.convert(a), P.convert(b), coefficient(a), coefficient(b)) == Spec.magnitude_cmp(a, b) : Cmp}:
  match a b:
    case Spec.Parts{na, +da, fa, ena, xa} Spec.Parts{nb, +db, fb, enb, xb}:
      (ed, exa) = va
      (ee, exb) = vb
      +eda = ed
      +edb = ee
      +x = Co.coefficient(da)
      +y = Co.coefficient(db)
      positive_exact(a, b, x, y, exa, exb,
        K.lower(x, K.trim_trimmed(N.reverse(Co.read(da)))), K.lower(y, K.trim_trimmed(N.reverse(Co.read(db)))),
        K.upper(x, K.coefficient_valid(da, eda)), K.upper(y, K.coefficient_valid(db, edb)),
        K.padded(x, y, K.coefficient_valid(da, eda), K.coefficient_valid(db, edb)),
        K.coefficient_value(da), K.coefficient_value(db))

def signed(+a: Spec.Parts, +b: Spec.Parts, +x: N.Digits, +y: N.Digits, sa: Bool, sb: Bool,
    pos: {D.positive(P.convert(a), P.convert(b), x, y) == Spec.magnitude_cmp(a, b) : Cmp},
    neg: {D.positive(P.convert(b), P.convert(a), y, x) == Spec.magnitude_cmp(b, a) : Cmp}) ->
    {D.order_go(P.convert(a), P.convert(b), x, y, sa, sb) == Spec.signed_cmp(a, b, sa, sb) : Cmp}:
  match sa sb:
    case False{} False{}: pos
    case True{} True{}: neg
    case True{} False{}: {==}
    case False{} True{}: {==}

def normalized(+a: Spec.Parts, +b: Spec.Parts, va: PV.valid(a), vb: PV.valid(b)) -> {D.normalized_order(P.convert(a), P.convert(b)) == Spec.signed_cmp(a, b, Spec.below_zero(a), Spec.below_zero(b)) : Cmp}:
  match a b:
    case Spec.Parts{na, da, fa, ena, xa} Spec.Parts{nb, db, fb, enb, xb}:
      (ed, ex) = va
      (ee, ey) = vb
      +eda = ed
      +exa = ex
      +edb = ee
      +exb = ey
      %negative(a) : {D.coefficient_order(P.convert(a), P.convert(b), coefficient(a), coefficient(b)) == Spec.signed_cmp(a, b, _, Spec.below_zero(b)) : Cmp}
      %negative(b) : {D.coefficient_order(P.convert(a), P.convert(b), coefficient(a), coefficient(b)) == Spec.signed_cmp(a, b, D.negative(P.convert(a), coefficient(a)), _) : Cmp}
      signed(a, b, coefficient(a), coefficient(b), D.negative(P.convert(a), coefficient(a)), D.negative(P.convert(b), coefficient(b)), positive_parts(a, b, (eda, exa), (edb, exb)), positive_parts(b, a, (edb, exb), (eda, exa)))

def order(+a: String, +b: String, va: {Spec.number(a) == True{} : Bool}, vb: {Spec.number(b) == True{} : Bool}) -> {D.order(a, b) == Spec.order(a, b) : Cmp}:
  %Equal.sym(DP.Parts, DP.parts(a), P.convert(Spec.parts(a)), P.parts(a)) : {D.normalized_order(_, DP.parts(b)) == Spec.order(a, b) : Cmp}
  %Equal.sym(DP.Parts, DP.parts(b), P.convert(Spec.parts(b)), P.parts(b)) : {D.normalized_order(P.convert(Spec.parts(a)), _) == Spec.order(a, b) : Cmp}
  normalized(Spec.parts(a), Spec.parts(b), PV.parts(a, va), PV.parts(b, vb))
