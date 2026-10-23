import Base
import ../src/data/schema-spec.bend as Spec
import ./schema-number-grammar.bend as Grammar
import ./utf8.bend as UP
import ./chunked-arith.bend as A

# Both digit strings are valid, including the empty implicit exponent.
def valid(p: Spec.Parts) -> Type:
  match p:
    case Spec.Parts{n, d, k, en, x}: {Spec.digits(d) == True{} : Bool} & {Spec.digits(x) == True{} : Bool}

def exponent_valid(e: Spec.Exponent) -> Type:
  match e:
    case Spec.Exponent{n, x}: {Spec.digits(x) == True{} : Bool}

def and_intro(+a: Bool, +b: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}) -> {a && b == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, ea) : {_ && b == True{} : Bool}
  eb

def pick_true(-T: Data, +a: T, +b: T, +c: Bool, e: {c == True{} : Bool}) -> {Bool.pick(T, c, a, b) == a : T}:
  %Equal.sym(Bool, c, True{}, e) : {Bool.pick(T, _, a, b) == a : T}
  {==}

def pick_false(-T: Data, +a: T, +b: T, +c: Bool, e: {c == False{} : Bool}) -> {Bool.pick(T, c, a, b) == b : T}:
  %Equal.sym(Bool, c, False{}, e) : {Bool.pick(T, _, a, b) == b : T}
  {==}

def take_step(+c: U32, +t: String, +b: Bool, eb: {Spec.digit(c) == b : Bool}, ih: {Spec.digits(Spec.take_digits(t)) == True{} : Bool}) -> {Spec.digits(Bool.pick(String, b, SCon{Chr{c}, Spec.take_digits(t)}, "")) == True{} : Bool}:
  match b:
    case False{}: {==}
    case True{}: and_intro(Spec.digit(c), Spec.digits(Spec.take_digits(t)), eb, ih)

def take_digits_valid(+s: String) -> {Spec.digits(Spec.take_digits(s)) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: take_step(c, t, Spec.digit(c), {==}, take_digits_valid(t))

def append_valid(+s: String, +t: String, +es: {Spec.digits(s) == True{} : Bool}, et: {Spec.digits(t) == True{} : Bool}) -> {Spec.digits(s ++ t) == True{} : Bool}:
  match s:
    case SNil{}: et
    case SCon{Chr{+c}, +rest}:
      and_intro(Spec.digit(c), Spec.digits(rest ++ t), UP.and_left(Spec.digit(c), Spec.digits(rest), es), append_valid(rest, t, UP.and_right(Spec.digit(c), Spec.digits(rest), es), et))

def fraction_digits_step(+t: String, b: Bool) -> {Spec.digits(Bool.pick(String, b, Spec.take_digits(t), "")) == True{} : Bool}:
  match b:
    case False{}: {==}
    case True{}: take_digits_valid(t)

def fraction_digits_valid(+s: String) -> {Spec.digits(Spec.fraction_digits(s)) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, +t}: fraction_digits_step(t, Spec.same(c, 46))

# Turn the Boolean comparison used by the specification into an equality.
def cmp_tail(a: Bool, b: Bool, c: Cmp, e: {Cmp.is_eq(Word.cmp.fin(a, b, c)) == True{} : Bool}) -> {Cmp.is_eq(c) == True{} : Bool}:
  match c:
    case LT{}: e
    case EQ{}: {==}
    case GT{}: e

def cmp_self(n: Nat, +a: Word(n)) -> {Word.cmp(n, a, a) == EQ{} : Cmp}:
  match n a:
    case 0n WNil{}: {==}
    case 1n+p WCon{+h, +t}:
      match h:
        case False{}:
          %Equal.sym(Cmp, Word.cmp(p, t, t), EQ{}, cmp_self(p, t)) : {Word.cmp.fin(False{}, False{}, _) == EQ{} : Cmp}
          {==}
        case True{}:
          %Equal.sym(Cmp, Word.cmp(p, t, t), EQ{}, cmp_self(p, t)) : {Word.cmp.fin(True{}, True{}, _) == EQ{} : Cmp}
          {==}

def same_head(+n: Nat, a: Bool, b: Bool, +t: Word(n), e: {Cmp.is_eq(Bool.cmp(a, b)) == True{} : Bool}) -> {WCon{a, t} == WCon{b, t} : Word(1n+n)}:
  match a b:
    case False{} False{}: {==}
    case True{} True{}: {==}
    case False{} True{}: Grammar.impossible({WCon{False{}, t} == WCon{True{}, t} : Word(1n+n)}, Grammar.false_true(e))
    case True{} False{}: Grammar.impossible({WCon{True{}, t} == WCon{False{}, t} : Word(1n+n)}, Grammar.false_true(e))

def same_step(+n: Nat, +a: Bool, +b: Bool, +s: Word(n), +t: Word(n), st: {s == t : Word(n)}) -> {Cmp.is_eq(Word.cmp.fin(a, b, Word.cmp(n, s, t))) == True{} : Bool} -> {WCon{a, s} == WCon{b, t} : Word(1n+n)}:
  %st : {Cmp.is_eq(Word.cmp.fin(a, b, Word.cmp(n, s, _))) == True{} : Bool} -> {WCon{a, s} == WCon{b, _} : Word(1n+n)}
  %Equal.sym(Cmp, Word.cmp(n, s, s), EQ{}, cmp_self(n, s)) : {Cmp.is_eq(Word.cmp.fin(a, b, _)) == True{} : Bool} -> {WCon{a, s} == WCon{b, s} : Word(1n+n)}
  e => same_head(n, a, b, s, e)

def word_same(+n: Nat, +s: Word(n), +t: Word(n), +e: {Cmp.is_eq(Word.cmp(n, s, t)) == True{} : Bool}) -> {s == t : Word(n)}:
  match n s t:
    case 0n WNil{} WNil{}: {==}
    case 1n+p WCon{+a, +x} WCon{+b, +y}: same_step(p, a, b, x, y, word_same(p, x, y, cmp_tail(a, b, Word.cmp(p, x, y), e)), e)

def same_sound(+c: U32, +k: U32, e: {Spec.same(c, k) == True{} : Bool}) -> {c == k : U32}:
  match c k:
    case U32{+s} U32{+t}: Equal.cong(Word(32n), U32, w => U32{w}, s, t, word_same(32n, s, t, e))

# A recognized separator stops the digit scanner.
def stop_at(+c: U32, +k: U32, +t: String, e: {Spec.same(c, k) == True{} : Bool}, no: {Spec.digit(k) == False{} : Bool}) -> {Spec.skip_digits(SCon{Chr{c}, t}) == SCon{Chr{c}, t} : String}:
  %Equal.sym(U32, c, k, same_sound(c, k, e)) : {Spec.skip_digits(SCon{Chr{_}, t}) == SCon{Chr{_}, t} : String}
  pick_false(String, Spec.skip_digits(t), SCon{Chr{k}, t}, Spec.digit(k), no)

def optional_stop_step(+c: U32, +t: String, +b: Bool, eb: {Spec.same(c, 101) == b : Bool}, e: {(b || Spec.same(c, 69)) && Spec.exponent_body(t) == True{} : Bool}) -> {Spec.skip_digits(SCon{Chr{c}, t}) == SCon{Chr{c}, t} : String}:
  match b:
    case True{}: stop_at(c, 101, t, eb, {==})
    case False{}: stop_at(c, 69, t, UP.and_left(Spec.same(c, 69), Spec.exponent_body(t), e), {==})

def optional_stop(+s: String, e: {Spec.optional_exponent(s) == True{} : Bool}) -> {Spec.skip_digits(s) == s : String}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: optional_stop_step(c, t, Spec.same(c, 101), {==}, e)

def after_int_stop_step(+c: U32, +t: String, +b: Bool, eb: {Spec.same(c, 46) == b : Bool}, e: {Bool.pick(Bool, b, Spec.fraction(t), Spec.optional_exponent(SCon{Chr{c}, t})) == True{} : Bool}) -> {Spec.skip_digits(SCon{Chr{c}, t}) == SCon{Chr{c}, t} : String}:
  match b:
    case True{}: stop_at(c, 46, t, eb, {==})
    case False{}: optional_stop(SCon{Chr{c}, t}, e)

def after_int_stop(+s: String, e: {Spec.after_int(s) == True{} : Bool}) -> {Spec.skip_digits(s) == s : String}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: after_int_stop_step(c, t, Spec.same(c, 46), {==}, e)

# Moving from the lower bound 49 to 48 preserves a nonzero digit.
def ge_predecessor(+n: Nat, k: Nat, e: {Cmp.is_ge(Nat.cmp(n, 1n+k)) == True{} : Bool}) -> {Cmp.is_ge(Nat.cmp(n, k)) == True{} : Bool}:
  match n k:
    case 0n 0n: {==}
    case 0n 1n+j: e
    case 1n+i 0n: {==}
    case 1n+i 1n+j: ge_predecessor(i, j, e)

def nonzero_digit(+c: U32, +e: {Spec.within(c, 49, 57) == True{} : Bool}) -> {Spec.digit(c) == True{} : Bool}:
  lo = UP.and_left(U32.is_ge(c, 49), U32.is_le(c, 57), e)
  lo_nat = Equal.trans(Bool, Cmp.is_ge(Nat.cmp(U32.to_nat(c), 49n)), U32.is_ge(c, 49), True{}, Equal.sym(Bool, U32.is_ge(c, 49), Cmp.is_ge(Nat.cmp(U32.to_nat(c), 49n)), Equal.cong(Cmp, Bool, x => Cmp.is_ge(x), U32.cmp(c, 49), Nat.cmp(U32.to_nat(c), 49n), A.u32_nat_cmp(c, 49))), lo)
  lower = ge_predecessor(U32.to_nat(c), 48n, lo_nat)
  lower_word = Equal.trans(Bool, U32.is_ge(c, 48), Cmp.is_ge(Nat.cmp(U32.to_nat(c), 48n)), True{}, Equal.cong(Cmp, Bool, x => Cmp.is_ge(x), U32.cmp(c, 48), Nat.cmp(U32.to_nat(c), 48n), A.u32_nat_cmp(c, 48)), lower)
  and_intro(U32.is_ge(c, 48), U32.is_le(c, 57), lower_word, UP.and_right(U32.is_ge(c, 49), U32.is_le(c, 57), e))

def exponent_digits_valid(+s: String, e: {Spec.exponent_digits(s) == True{} : Bool}) -> {Spec.digits(s) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: e

def signed_exponent_step(+c: U32, +t: String, +minus: Bool, +plus: Bool, e: {Bool.pick(Bool, minus || plus, Spec.exponent_digits(t), Spec.exponent_digits(SCon{Chr{c}, t})) == True{} : Bool}) -> exponent_valid(Bool.pick(Spec.Exponent, minus, Spec.Exponent{True{}, t}, Bool.pick(Spec.Exponent, plus, Spec.Exponent{False{}, t}, Spec.Exponent{False{}, SCon{Chr{c}, t}}))):
  match minus plus:
    case True{} plus: exponent_digits_valid(t, e)
    case False{} True{}: exponent_digits_valid(t, e)
    case False{} False{}: exponent_digits_valid(SCon{Chr{c}, t}, e)

def signed_exponent_valid(+s: String, e: {Spec.exponent_body(s) == True{} : Bool}) -> exponent_valid(Spec.signed_exponent(s)):
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: signed_exponent_step(c, t, Spec.same(c, 45), Spec.same(c, 43), e)

def exponent_valid_from_optional(+s: String, e: {Spec.optional_exponent(s) == True{} : Bool}) -> exponent_valid(Spec.exponent(s)):
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: signed_exponent_valid(t, UP.and_right(Spec.same(c, 101) || Spec.same(c, 69), Spec.exponent_body(t), e))

def skip_head(+c: U32, +t: String, e: {Spec.digit(c) == True{} : Bool}) -> {Spec.skip_digits(SCon{Chr{c}, t}) == Spec.skip_digits(t) : String}:
  pick_true(String, Spec.skip_digits(t), SCon{Chr{c}, t}, Spec.digit(c), e)

def fraction_skip(+s: String, +e: {Spec.fraction(s) == True{} : Bool}) -> {Spec.optional_exponent(Spec.skip_digits(s)) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(String, Spec.skip_digits(SCon{Chr{c}, t}), Spec.skip_digits(t), skip_head(c, t, UP.and_left(Spec.digit(c), Spec.optional_exponent(Spec.skip_digits(t)), e))) : {Spec.optional_exponent(_) == True{} : Bool}
      UP.and_right(Spec.digit(c), Spec.optional_exponent(Spec.skip_digits(t)), e)

def after_fraction_step(+c: U32, +t: String, +dot: Bool, e: {Bool.pick(Bool, dot, Spec.fraction(t), Spec.optional_exponent(SCon{Chr{c}, t})) == True{} : Bool}) -> {Spec.optional_exponent(Bool.pick(String, dot, Spec.skip_digits(t), SCon{Chr{c}, t})) == True{} : Bool}:
  match dot:
    case True{}: fraction_skip(t, e)
    case False{}: e

def after_fraction_valid(+s: String, e: {Spec.after_int(s) == True{} : Bool}) -> {Spec.optional_exponent(Spec.after_fraction(s)) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: after_fraction_step(c, t, Spec.same(c, 46), e)

def zero_digit(+c: U32, e: {Spec.same(c, 48) == True{} : Bool}) -> {Spec.digit(c) == True{} : Bool}:
  Equal.trans(Bool, Spec.digit(c), Spec.digit(48), True{}, Equal.cong(U32, Bool, x => Spec.digit(x), c, 48, same_sound(c, 48, e)), {==})

def unsigned_rest_step(+c: U32, +t: String, +zero: Bool, ez: {Spec.same(c, 48) == zero : Bool}, +e: {Bool.pick(Bool, zero, Spec.after_int(t), Spec.within(c, 49, 57) && Spec.after_int(Spec.skip_digits(t))) == True{} : Bool}) -> {Spec.after_int(Spec.skip_digits(SCon{Chr{c}, t})) == True{} : Bool}:
  match zero:
    case True{}:
      %Equal.sym(String, Spec.skip_digits(SCon{Chr{c}, t}), Spec.skip_digits(t), skip_head(c, t, zero_digit(c, ez))) : {Spec.after_int(_) == True{} : Bool}
      %Equal.sym(String, Spec.skip_digits(t), t, after_int_stop(t, e)) : {Spec.after_int(_) == True{} : Bool}
      e
    case False{}:
      %Equal.sym(String, Spec.skip_digits(SCon{Chr{c}, t}), Spec.skip_digits(t), skip_head(c, t, nonzero_digit(c, UP.and_left(Spec.within(c, 49, 57), Spec.after_int(Spec.skip_digits(t)), e)))) : {Spec.after_int(_) == True{} : Bool}
      UP.and_right(Spec.within(c, 49, 57), Spec.after_int(Spec.skip_digits(t)), e)

def unsigned_rest_valid(+s: String, e: {Spec.unsigned(s) == True{} : Bool}) -> {Spec.after_int(Spec.skip_digits(s)) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: unsigned_rest_step(c, t, Spec.same(c, 48), {==}, e)

def assemble_valid(+negative: Bool, +whole: String, +frac: String, +x: Spec.Exponent, ew: {Spec.digits(whole) == True{} : Bool}, ef: {Spec.digits(frac) == True{} : Bool}, ex: exponent_valid(x)) -> valid(Spec.assemble(negative, whole, frac, x)):
  match x:
    case Spec.Exponent{en, digits}: (append_valid(whole, frac, ew, ef), ex)

def unsigned_parts_valid(+negative: Bool, +s: String, e: {Spec.unsigned(s) == True{} : Bool}) -> valid(Spec.unsigned_parts(negative, s)):
  assemble_valid(negative, Spec.take_digits(s), Spec.fraction_digits(Spec.skip_digits(s)), Spec.exponent(Spec.after_fraction(Spec.skip_digits(s))), take_digits_valid(s), fraction_digits_valid(Spec.skip_digits(s)), exponent_valid_from_optional(Spec.after_fraction(Spec.skip_digits(s)), after_fraction_valid(Spec.skip_digits(s), unsigned_rest_valid(s, e))))

def parts_step(+c: U32, +t: String, +minus: Bool, e: {Bool.pick(Bool, minus, Spec.unsigned(t), Spec.unsigned(SCon{Chr{c}, t})) == True{} : Bool}) -> valid(Bool.pick(Spec.Parts, minus, Spec.unsigned_parts(True{}, t), Spec.unsigned_parts(False{}, SCon{Chr{c}, t}))):
  match minus:
    case True{}: unsigned_parts_valid(True{}, t, e)
    case False{}: unsigned_parts_valid(False{}, SCon{Chr{c}, t}, e)

def parts(+s: String, e: {Spec.number(s) == True{} : Bool}) -> valid(Spec.parts(s)):
  match s:
    case SNil{}: ({==}, {==})
    case SCon{Chr{+c}, +t}: parts_step(c, t, Spec.same(c, 45), e)
