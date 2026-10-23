# The tail-recursive runtime parser agrees with the independent specification.
import Base
import ../src/data/decimal-parts.bend as D
import ../src/data/schema-spec.bend as Spec
import ../src/data/json.bend as J
import ./chunked-arith.bend as N
import ./crypto-support.bend as R

def convert(p: Spec.Parts) -> D.Parts:
  Spec.Parts{n, d, s, en, e} = p
  D.Parts{n, d, s, en, e}

def convert_exponent(e: Spec.Exponent) -> D.Exponent:
  Spec.Exponent{n, d} = e
  D.Exponent{n, d}

def scan_shape(+c: U32, +t: String, +rev: String, +b: Bool, ih: {D.scan_go(t, SCon{Chr{c}, rev}, D.head_digit(t)) == (String.reverse.go(SCon{Chr{c}, rev}, Spec.take_digits(t)), Spec.skip_digits(t)) : String & String}) -> {D.scan_go(SCon{Chr{c}, t}, rev, b) == (String.reverse.go(rev, Bool.pick(String, b, SCon{Chr{c}, Spec.take_digits(t)}, "")), Bool.pick(String, b, Spec.skip_digits(t), SCon{Chr{c}, t})) : String & String}:
  match b:
    case False{}: {==}
    case True{}: ih

def scan_go(+s: String, +rev: String) -> {D.scan_go(s, rev, D.head_digit(s)) == (String.reverse.go(rev, Spec.take_digits(s)), Spec.skip_digits(s)) : String & String}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: scan_shape(c, t, rev, J.digit(c), scan_go(t, SCon{Chr{c}, rev}))

def scan(+s: String) -> {D.scan(s) == (Spec.take_digits(s), Spec.skip_digits(s)) : String & String}:
  scan_go(s, "")

def exponent_pick(+b: Bool, +a: Spec.Exponent, +c: Spec.Exponent) -> {Bool.pick(D.Exponent, b, convert_exponent(a), convert_exponent(c)) == convert_exponent(Bool.pick(Spec.Exponent, b, a, c)) : D.Exponent}:
  match b:
    case False{}: {==}
    case True{}: {==}

def signed_exponent(+s: String) -> {D.signed_exponent(s) == convert_exponent(Spec.signed_exponent(s)) : D.Exponent}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(D.Exponent, Bool.pick(D.Exponent, U32.is_eq(c, 43), D.Exponent{False{}, t}, D.Exponent{False{}, SCon{Chr{c}, t}}), convert_exponent(Bool.pick(Spec.Exponent, U32.is_eq(c, 43), Spec.Exponent{False{}, t}, Spec.Exponent{False{}, SCon{Chr{c}, t}})), exponent_pick(U32.is_eq(c, 43), Spec.Exponent{False{}, t}, Spec.Exponent{False{}, SCon{Chr{c}, t}})) : {Bool.pick(D.Exponent, U32.is_eq(c, 45), D.Exponent{True{}, t}, _) == convert_exponent(Spec.signed_exponent(SCon{Chr{c}, t})) : D.Exponent}
      exponent_pick(U32.is_eq(c, 45), Spec.Exponent{True{}, t}, Bool.pick(Spec.Exponent, U32.is_eq(c, 43), Spec.Exponent{False{}, t}, Spec.Exponent{False{}, SCon{Chr{c}, t}}))

def exponent(+s: String) -> {D.exponent(s) == convert_exponent(Spec.exponent(s)) : D.Exponent}:
  match s:
    case SNil{}: {==}
    case SCon{c, t}: signed_exponent(t)

def length_go(+s: String, +n: Nat) -> {D.length_go(s, n) == Nat.add(Spec.length(s), n) : Nat}:
  match s:
    case SNil{}: {==}
    case SCon{h, +t}:
      Equal.trans(Nat, D.length_go(t, 1n+n), Nat.add(Spec.length(t), 1n+n), 1n+Nat.add(Spec.length(t), n), length_go(t, 1n+n), N.add_succ_r(Spec.length(t), n))

def length(+s: String) -> {D.length_go(s, 0n) == Spec.length(s) : Nat}:
  Equal.trans(Nat, D.length_go(s, 0n), Nat.add(Spec.length(s), 0n), Spec.length(s), length_go(s, 0n), N.add_zero_r(Spec.length(s)))

def assemble(+negative: Bool, +whole: String, +frac: String, e: Spec.Exponent) -> {D.assemble(negative, whole, frac, convert_exponent(e)) == convert(Spec.assemble(negative, whole, frac, e)) : D.Parts}:
  match e:
    case Spec.Exponent{en, x}:
      %Equal.sym(String, String.reverse.go(String.reverse(whole), frac), whole ++ frac, R.reverse_twice(whole, "", frac)) : {D.Parts{negative, _, D.length_go(frac, 0n), en, x} == D.Parts{negative, whole ++ frac, Spec.length(frac), en, x} : D.Parts}
      Equal.cong(Nat, D.Parts, s => D.Parts{negative, whole ++ frac, s, en, x}, D.length_go(frac, 0n), Spec.length(frac), length(frac))

def assemble_exponent(+negative: Bool, +whole: String, +frac: String, +rest: String) -> {D.assemble(negative, whole, frac, D.exponent(rest)) == convert(Spec.assemble(negative, whole, frac, Spec.exponent(rest))) : D.Parts}:
  %Equal.sym(D.Exponent, D.exponent(rest), convert_exponent(Spec.exponent(rest)), exponent(rest)) : {D.assemble(negative, whole, frac, _) == convert(Spec.assemble(negative, whole, frac, Spec.exponent(rest))) : D.Parts}
  assemble(negative, whole, frac, Spec.exponent(rest))

def fraction(+negative: Bool, +whole: String, +s: String) -> {D.fraction(negative, whole, D.scan(s)) == convert(Spec.assemble(negative, whole, Spec.take_digits(s), Spec.exponent(Spec.skip_digits(s)))) : D.Parts}:
  %Equal.sym(String & String, D.scan(s), (Spec.take_digits(s), Spec.skip_digits(s)), scan(s)) : {D.fraction(negative, whole, _) == convert(Spec.assemble(negative, whole, Spec.take_digits(s), Spec.exponent(Spec.skip_digits(s)))) : D.Parts}
  assemble_exponent(negative, whole, Spec.take_digits(s), Spec.skip_digits(s))

# Generalize the dot test, keeping character bits symbolic.
def after_shape(+negative: Bool, +whole: String, +c: U32, +t: String, +b: Bool) -> {D.after_whole(negative, whole, SCon{Chr{c}, t}, b) == convert(Spec.assemble(negative, whole, Bool.pick(String, b, Spec.take_digits(t), ""), Spec.exponent(Bool.pick(String, b, Spec.skip_digits(t), SCon{Chr{c}, t})))) : D.Parts}:
  match b:
    case False{}: assemble_exponent(negative, whole, "", SCon{Chr{c}, t})
    case True{}: fraction(negative, whole, t)

def after_whole(+negative: Bool, +whole: String, +rest: String) -> {D.after_whole(negative, whole, rest, D.head_dot(rest)) == convert(Spec.assemble(negative, whole, Spec.fraction_digits(rest), Spec.exponent(Spec.after_fraction(rest)))) : D.Parts}:
  match rest:
    case SNil{}: assemble_exponent(negative, whole, "", "")
    case SCon{Chr{+c}, +t}: after_shape(negative, whole, c, t, U32.is_eq(c, 46))

def unsigned(+negative: Bool, +s: String) -> {D.unsigned(negative, s) == convert(Spec.unsigned_parts(negative, s)) : D.Parts}:
  %Equal.sym(String & String, D.scan(s), (Spec.take_digits(s), Spec.skip_digits(s)), scan(s)) : {D.unsigned_done(negative, _) == convert(Spec.unsigned_parts(negative, s)) : D.Parts}
  after_whole(negative, Spec.take_digits(s), Spec.skip_digits(s))

def parts_pick(+b: Bool, +a: Spec.Parts, +c: Spec.Parts) -> {Bool.pick(D.Parts, b, convert(a), convert(c)) == convert(Bool.pick(Spec.Parts, b, a, c)) : D.Parts}:
  match b:
    case False{}: {==}
    case True{}: {==}

def parts_shape(+c: U32, +t: String, +b: Bool) -> {Bool.pick(D.Parts, b, D.unsigned(True{}, t), D.unsigned(False{}, SCon{Chr{c}, t})) == convert(Bool.pick(Spec.Parts, b, Spec.unsigned_parts(True{}, t), Spec.unsigned_parts(False{}, SCon{Chr{c}, t}))) : D.Parts}:
  match b:
    case False{}: unsigned(False{}, SCon{Chr{c}, t})
    case True{}: unsigned(True{}, t)

# No validity hypothesis: even malformed strings have identical decompositions.
def parts(+s: String) -> {D.parts(s) == convert(Spec.parts(s)) : D.Parts}:
  match s:
    case SNil{}: unsigned(False{}, "")
    case SCon{Chr{+c}, +t}: parts_shape(c, t, U32.is_eq(c, 45))
