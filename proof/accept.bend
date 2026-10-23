# BND-25: Errors.accepts_json equals the independent Accept policy in
# proof/accept-spec.bend, for every field.
import Base
import ../src/app/errors.bend as Errors
import ../src/app/context.bend as C
import ../src/http/request.bend as Request
import ../src/http/bytes.bend as Bytes
import ./accept-spec.bend as A

def and_false(a: Bool) -> {a && False{} == False{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def or_false(a: Bool) -> {a || False{} == a : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def or_false_left(a: Bool, b: Bool) -> {(a || False{}) || b == a || b : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def or_true_left(a: Bool, b: Bool) -> {(a || True{}) || b == a || True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

# The quote-aware splitter. Errors.split_go keeps the current piece and the
# finished pieces reversed; glue says what that state stands for.

def glue(parts: List<&2, String>, part: String, xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case h <> t: List.reverse.go(&2, String, parts, String.reverse.go(part, h) <> t)

def glue_state(st: Errors.Split, t: String, d: Char) -> List<&2, String>:
  match st:
    case Errors.Split{q, e, part, parts}: glue(parts, part, A.segments(t, d, q, e))

def extend_glue(+parts: List<&2, String>, +part: String, +c: Char, xs: List<&2, String>) -> {glue(parts, SCon{c, part}, xs) == glue(parts, part, A.extend(c, xs)) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case h <> t: {==}

def start_glue(+parts: List<&2, String>, +part: String, xs: List<&2, String>) -> {glue(String.reverse(part) <> parts, "", xs) == glue(parts, part, A.start(xs)) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case h <> t: {==}

def glue_nil(xs: List<&2, String>) -> {glue([], "", xs) == xs : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case h <> t: {==}

def end_spec(q: Bool, e: Bool, +part: String, +parts: List<&2, String>) -> {Errors.split_end(Errors.Split{q, e, part, parts}) == glue(parts, part, A.finish(q)) : List<&2, String>}:
  match q:
    case True{}: {==}
    case False{}: {==}

def step_bools(q: Bool, e: Bool, bq: Bool, be: Bool, bc: Bool, +c: Char, +part: String, +parts: List<&2, String>, +t: String, +d: Char) -> {glue_state(Errors.split_char(q, e, Errors.skind(bq, be, bc), c, part, parts), t, d) == glue(parts, part, A.apply(A.starts(q, A.skind(bq, be, bc)), c, A.segments(t, d, A.next_quoted(q, e, A.skind(bq, be, bc)), A.next_escaped(q, e, A.skind(bq, be, bc))))) : List<&2, String>}:
  match q e bq be bc:
    case True{} True{} True{} True{} True{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case True{} True{} True{} True{} False{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case True{} True{} True{} False{} True{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case True{} True{} True{} False{} False{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case True{} True{} False{} True{} True{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case True{} True{} False{} True{} False{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case True{} True{} False{} False{} True{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case True{} True{} False{} False{} False{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case True{} False{} True{} True{} True{}: extend_glue(parts, part, c, A.segments(t, d, False{}, False{}))
    case True{} False{} True{} True{} False{}: extend_glue(parts, part, c, A.segments(t, d, False{}, False{}))
    case True{} False{} True{} False{} True{}: extend_glue(parts, part, c, A.segments(t, d, False{}, False{}))
    case True{} False{} True{} False{} False{}: extend_glue(parts, part, c, A.segments(t, d, False{}, False{}))
    case True{} False{} False{} True{} True{}: extend_glue(parts, part, c, A.segments(t, d, True{}, True{}))
    case True{} False{} False{} True{} False{}: extend_glue(parts, part, c, A.segments(t, d, True{}, True{}))
    case True{} False{} False{} False{} True{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case True{} False{} False{} False{} False{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case False{} True{} True{} True{} True{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case False{} True{} True{} True{} False{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case False{} True{} True{} False{} True{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case False{} True{} True{} False{} False{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case False{} True{} False{} True{} True{}: extend_glue(parts, part, c, A.segments(t, d, False{}, False{}))
    case False{} True{} False{} True{} False{}: extend_glue(parts, part, c, A.segments(t, d, False{}, False{}))
    case False{} True{} False{} False{} True{}: start_glue(parts, part, A.segments(t, d, False{}, False{}))
    case False{} True{} False{} False{} False{}: extend_glue(parts, part, c, A.segments(t, d, False{}, False{}))
    case False{} False{} True{} True{} True{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case False{} False{} True{} True{} False{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case False{} False{} True{} False{} True{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case False{} False{} True{} False{} False{}: extend_glue(parts, part, c, A.segments(t, d, True{}, False{}))
    case False{} False{} False{} True{} True{}: extend_glue(parts, part, c, A.segments(t, d, False{}, False{}))
    case False{} False{} False{} True{} False{}: extend_glue(parts, part, c, A.segments(t, d, False{}, False{}))
    case False{} False{} False{} False{} True{}: start_glue(parts, part, A.segments(t, d, False{}, False{}))
    case False{} False{} False{} False{} False{}: extend_glue(parts, part, c, A.segments(t, d, False{}, False{}))

def step_class(+c: Char, +d: Char, +q: Bool, +e: Bool, +part: String, +parts: List<&2, String>, +t: String) -> {glue_state(Errors.split_char(q, e, Errors.schar(c, d), c, part, parts), t, d) == glue_state(Errors.Split{q, e, part, parts}, SCon{c, t}, d) : List<&2, String>}:
  match c d:
    case Chr{+x} Chr{+y}: step_bools(q, e, U32.is_eq(x, 34), U32.is_eq(x, 92), U32.is_eq(x, y), Chr{x}, part, parts, t, Chr{y})

def split_go_spec(+s: String, +d: Char, +st: Errors.Split) -> {Errors.split_go(s, d, st) == glue_state(st, s, d) : List<&2, String>}:
  match s:
    case SNil{}:
      match st:
        case Errors.Split{+q, +e, +part, +parts}: end_spec(q, e, part, parts)
    case SCon{+c, t}:
      match st:
        case Errors.Split{+q, +e, +part, +parts}:
          Equal.trans(List<&2, String>, Errors.split_go(t, d, Errors.split_char(q, e, Errors.schar(c, d), c, part, parts)), glue_state(Errors.split_char(q, e, Errors.schar(c, d), c, part, parts), t, d), glue_state(Errors.Split{q, e, part, parts}, SCon{c, t}, d), split_go_spec(t, d, Errors.split_char(q, e, Errors.schar(c, d), c, part, parts)), step_class(c, d, q, e, part, parts, t))

def split_spec(+s: String, +d: Char) -> {Errors.split(s, d) == A.pieces(s, d) : List<&2, String>}:
  Equal.trans(List<&2, String>, Errors.split(s, d), glue([], "", A.segments(s, d, False{}, False{})), A.pieces(s, d), split_go_spec(s, d, Errors.Split{False{}, False{}, "", []}), glue_nil(A.segments(s, d, False{}, False{})))

# Quality values.

def zeros_step(z: Bool, o: Bool, g: Bool, dt: Bool, +t: String, +m: Nat, ih: {Errors.zeros(t, m) == A.at_most(t, m) && A.digits(t, True{}) : Bool}) -> {Errors.q_zero(Errors.qkind(z, o, g, dt)) && Errors.zeros(t, m) == A.at_most(t, m) && (A.digit_ok(A.qkind(z, o, g, dt), True{}) && A.digits(t, True{})) : Bool}:
  match z o g dt:
    case True{} True{} True{} True{}: ih
    case True{} True{} True{} False{}: ih
    case True{} True{} False{} True{}: ih
    case True{} True{} False{} False{}: ih
    case True{} False{} True{} True{}: ih
    case True{} False{} True{} False{}: ih
    case True{} False{} False{} True{}: ih
    case True{} False{} False{} False{}: ih
    case False{} True{} True{} True{}: Equal.sym(Bool, A.at_most(t, m) && False{}, False{}, and_false(A.at_most(t, m)))
    case False{} True{} True{} False{}: Equal.sym(Bool, A.at_most(t, m) && False{}, False{}, and_false(A.at_most(t, m)))
    case False{} True{} False{} True{}: Equal.sym(Bool, A.at_most(t, m) && False{}, False{}, and_false(A.at_most(t, m)))
    case False{} True{} False{} False{}: Equal.sym(Bool, A.at_most(t, m) && False{}, False{}, and_false(A.at_most(t, m)))
    case False{} False{} True{} True{}: Equal.sym(Bool, A.at_most(t, m) && False{}, False{}, and_false(A.at_most(t, m)))
    case False{} False{} True{} False{}: Equal.sym(Bool, A.at_most(t, m) && False{}, False{}, and_false(A.at_most(t, m)))
    case False{} False{} False{} True{}: Equal.sym(Bool, A.at_most(t, m) && False{}, False{}, and_false(A.at_most(t, m)))
    case False{} False{} False{} False{}: Equal.sym(Bool, A.at_most(t, m) && False{}, False{}, and_false(A.at_most(t, m)))

def zeros_spec(+xs: String, +n: Nat) -> {Errors.zeros(xs, n) == A.at_most(xs, n) && A.digits(xs, True{}) : Bool}:
  match xs n:
    case SNil{} 0n: {==}
    case SNil{} 1n+m: {==}
    case SCon{Chr{+c}, t} 0n: {==}
    case SCon{Chr{+c}, t} 1n+m: zeros_step(U32.is_eq(c, 48), U32.is_eq(c, 49), (c >= 48 : U32) && (c <= 57 : U32), U32.is_eq(c, 46), t, m, zeros_spec(t, m))

def frac_step(z: Bool, o: Bool, g: Bool, dt: Bool, +t: String, +m: Nat, +p: Bool, ih: {Errors.fraction(t, m, p || Errors.q_positive(Errors.qkind(z, o, g, dt))) == (A.at_most(t, m) && A.digits(t, False{})) && ((p || Errors.q_positive(Errors.qkind(z, o, g, dt))) || A.any_nonzero(t)) : Bool}) -> {Errors.q_digit(Errors.qkind(z, o, g, dt)) && Errors.fraction(t, m, p || Errors.q_positive(Errors.qkind(z, o, g, dt))) == (A.at_most(t, m) && (A.digit_ok(A.qkind(z, o, g, dt), False{}) && A.digits(t, False{}))) && (p || (A.nonzero(A.qkind(z, o, g, dt)) || A.any_nonzero(t))) : Bool}:
  match z o g dt:
    case True{} True{} True{} True{}: Equal.trans(Bool, Errors.fraction(t, m, p || False{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || False{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || A.any_nonzero(t)), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || False{}) || A.any_nonzero(t), p || A.any_nonzero(t), or_false_left(p, A.any_nonzero(t))))
    case True{} True{} True{} False{}: Equal.trans(Bool, Errors.fraction(t, m, p || False{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || False{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || A.any_nonzero(t)), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || False{}) || A.any_nonzero(t), p || A.any_nonzero(t), or_false_left(p, A.any_nonzero(t))))
    case True{} True{} False{} True{}: Equal.trans(Bool, Errors.fraction(t, m, p || False{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || False{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || A.any_nonzero(t)), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || False{}) || A.any_nonzero(t), p || A.any_nonzero(t), or_false_left(p, A.any_nonzero(t))))
    case True{} True{} False{} False{}: Equal.trans(Bool, Errors.fraction(t, m, p || False{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || False{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || A.any_nonzero(t)), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || False{}) || A.any_nonzero(t), p || A.any_nonzero(t), or_false_left(p, A.any_nonzero(t))))
    case True{} False{} True{} True{}: Equal.trans(Bool, Errors.fraction(t, m, p || False{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || False{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || A.any_nonzero(t)), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || False{}) || A.any_nonzero(t), p || A.any_nonzero(t), or_false_left(p, A.any_nonzero(t))))
    case True{} False{} True{} False{}: Equal.trans(Bool, Errors.fraction(t, m, p || False{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || False{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || A.any_nonzero(t)), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || False{}) || A.any_nonzero(t), p || A.any_nonzero(t), or_false_left(p, A.any_nonzero(t))))
    case True{} False{} False{} True{}: Equal.trans(Bool, Errors.fraction(t, m, p || False{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || False{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || A.any_nonzero(t)), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || False{}) || A.any_nonzero(t), p || A.any_nonzero(t), or_false_left(p, A.any_nonzero(t))))
    case True{} False{} False{} False{}: Equal.trans(Bool, Errors.fraction(t, m, p || False{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || False{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || A.any_nonzero(t)), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || False{}) || A.any_nonzero(t), p || A.any_nonzero(t), or_false_left(p, A.any_nonzero(t))))
    case False{} True{} True{} True{}: Equal.trans(Bool, Errors.fraction(t, m, p || True{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || True{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || True{}), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || True{}) || A.any_nonzero(t), p || True{}, or_true_left(p, A.any_nonzero(t))))
    case False{} True{} True{} False{}: Equal.trans(Bool, Errors.fraction(t, m, p || True{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || True{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || True{}), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || True{}) || A.any_nonzero(t), p || True{}, or_true_left(p, A.any_nonzero(t))))
    case False{} True{} False{} True{}: Equal.trans(Bool, Errors.fraction(t, m, p || True{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || True{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || True{}), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || True{}) || A.any_nonzero(t), p || True{}, or_true_left(p, A.any_nonzero(t))))
    case False{} True{} False{} False{}: Equal.trans(Bool, Errors.fraction(t, m, p || True{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || True{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || True{}), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || True{}) || A.any_nonzero(t), p || True{}, or_true_left(p, A.any_nonzero(t))))
    case False{} False{} True{} True{}: Equal.trans(Bool, Errors.fraction(t, m, p || True{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || True{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || True{}), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || True{}) || A.any_nonzero(t), p || True{}, or_true_left(p, A.any_nonzero(t))))
    case False{} False{} True{} False{}: Equal.trans(Bool, Errors.fraction(t, m, p || True{}), (A.at_most(t, m) && A.digits(t, False{})) && ((p || True{}) || A.any_nonzero(t)), (A.at_most(t, m) && A.digits(t, False{})) && (p || True{}), ih, Equal.cong(Bool, Bool, x => (A.at_most(t, m) && A.digits(t, False{})) && x, (p || True{}) || A.any_nonzero(t), p || True{}, or_true_left(p, A.any_nonzero(t))))
    case False{} False{} False{} True{}: Equal.sym(Bool, (A.at_most(t, m) && False{}) && (p || (False{} || A.any_nonzero(t))), False{}, Equal.cong(Bool, Bool, y => y && (p || (False{} || A.any_nonzero(t))), A.at_most(t, m) && False{}, False{}, and_false(A.at_most(t, m))))
    case False{} False{} False{} False{}: Equal.sym(Bool, (A.at_most(t, m) && False{}) && (p || (False{} || A.any_nonzero(t))), False{}, Equal.cong(Bool, Bool, y => y && (p || (False{} || A.any_nonzero(t))), A.at_most(t, m) && False{}, False{}, and_false(A.at_most(t, m))))

def fraction_spec(+xs: String, +n: Nat, +p: Bool) -> {Errors.fraction(xs, n, p) == (A.at_most(xs, n) && A.digits(xs, False{})) && (p || A.any_nonzero(xs)) : Bool}:
  match xs n:
    case SNil{} 0n: Equal.sym(Bool, p || False{}, p, or_false(p))
    case SNil{} 1n+m: Equal.sym(Bool, p || False{}, p, or_false(p))
    case SCon{Chr{+c}, t} 0n: {==}
    case SCon{Chr{+c}, t} 1n+m: frac_step(U32.is_eq(c, 48), U32.is_eq(c, 49), (c >= 48 : U32) && (c <= 57 : U32), U32.is_eq(c, 46), t, m, p, fraction_spec(t, m, p || Errors.q_positive(Errors.qchar(c))))

def one_dot(z: Bool, o: Bool, g: Bool, dt: Bool, +u: String) -> {Errors.q_dot(Errors.qkind(z, o, g, dt)) && Errors.zeros(u, 3n) == (A.is_dot(A.qkind(z, o, g, dt)) && A.at_most(u, 3n)) && A.digits(u, True{}) : Bool}:
  match z o g dt:
    case True{} True{} True{} True{}: {==}
    case True{} True{} True{} False{}: {==}
    case True{} True{} False{} True{}: {==}
    case True{} True{} False{} False{}: {==}
    case True{} False{} True{} True{}: {==}
    case True{} False{} True{} False{}: {==}
    case True{} False{} False{} True{}: {==}
    case True{} False{} False{} False{}: {==}
    case False{} True{} True{} True{}: {==}
    case False{} True{} True{} False{}: {==}
    case False{} True{} False{} True{}: {==}
    case False{} True{} False{} False{}: {==}
    case False{} False{} True{} True{}: {==}
    case False{} False{} True{} False{}: {==}
    case False{} False{} False{} True{}: zeros_spec(u, 3n)
    case False{} False{} False{} False{}: {==}

def zero_dot(z: Bool, o: Bool, g: Bool, dt: Bool, +u: String) -> {Errors.q_dot(Errors.qkind(z, o, g, dt)) && Errors.fraction(u, 3n, False{}) == ((A.is_dot(A.qkind(z, o, g, dt)) && A.at_most(u, 3n)) && A.digits(u, False{})) && (A.nonzero(A.qkind(z, o, g, dt)) || A.any_nonzero(u)) : Bool}:
  match z o g dt:
    case True{} True{} True{} True{}: {==}
    case True{} True{} True{} False{}: {==}
    case True{} True{} False{} True{}: {==}
    case True{} True{} False{} False{}: {==}
    case True{} False{} True{} True{}: {==}
    case True{} False{} True{} False{}: {==}
    case True{} False{} False{} True{}: {==}
    case True{} False{} False{} False{}: {==}
    case False{} True{} True{} True{}: {==}
    case False{} True{} True{} False{}: {==}
    case False{} True{} False{} True{}: {==}
    case False{} True{} False{} False{}: {==}
    case False{} False{} True{} True{}: {==}
    case False{} False{} True{} False{}: {==}
    case False{} False{} False{} True{}: fraction_spec(u, 3n, False{})
    case False{} False{} False{} False{}: {==}

def one_tail(+t: String) -> {Errors.quality_tail(Errors.QOne{}, t) == A.qvalue_lead(A.AOne{}, t) : Bool}:
  match t:
    case SNil{}: {==}
    case SCon{Chr{+c}, u}: one_dot(U32.is_eq(c, 48), U32.is_eq(c, 49), (c >= 48 : U32) && (c <= 57 : U32), U32.is_eq(c, 46), u)

def zero_tail(+t: String) -> {Errors.quality_tail(Errors.QZero{}, t) == A.qvalue_lead(A.AZero{}, t) : Bool}:
  match t:
    case SNil{}: {==}
    case SCon{Chr{+c}, u}: zero_dot(U32.is_eq(c, 48), U32.is_eq(c, 49), (c >= 48 : U32) && (c <= 57 : U32), U32.is_eq(c, 46), u)

def digit_lead(+t: String) -> {Errors.quality_tail(Errors.QDigit{}, t) == A.qvalue_lead(A.ADigit{}, t) : Bool}:
  match t:
    case SNil{}: {==}
    case SCon{h, u}: {==}

def dot_lead(+t: String) -> {Errors.quality_tail(Errors.QDot{}, t) == A.qvalue_lead(A.ADot{}, t) : Bool}:
  match t:
    case SNil{}: {==}
    case SCon{h, u}: {==}

def other_lead(+t: String) -> {Errors.quality_tail(Errors.QOther{}, t) == A.qvalue_lead(A.AOther{}, t) : Bool}:
  match t:
    case SNil{}: {==}
    case SCon{h, u}: {==}

def lead_step(z: Bool, o: Bool, g: Bool, dt: Bool, +t: String) -> {Errors.quality_tail(Errors.qkind(z, o, g, dt), t) == A.qvalue_lead(A.qkind(z, o, g, dt), t) : Bool}:
  match z o g dt:
    case True{} True{} True{} True{}: zero_tail(t)
    case True{} True{} True{} False{}: zero_tail(t)
    case True{} True{} False{} True{}: zero_tail(t)
    case True{} True{} False{} False{}: zero_tail(t)
    case True{} False{} True{} True{}: zero_tail(t)
    case True{} False{} True{} False{}: zero_tail(t)
    case True{} False{} False{} True{}: zero_tail(t)
    case True{} False{} False{} False{}: zero_tail(t)
    case False{} True{} True{} True{}: one_tail(t)
    case False{} True{} True{} False{}: one_tail(t)
    case False{} True{} False{} True{}: one_tail(t)
    case False{} True{} False{} False{}: one_tail(t)
    case False{} False{} True{} True{}: digit_lead(t)
    case False{} False{} True{} False{}: digit_lead(t)
    case False{} False{} False{} True{}: dot_lead(t)
    case False{} False{} False{} False{}: other_lead(t)

def quality_spec(+s: String) -> {Errors.quality(s) == A.positive_qvalue(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, t}: lead_step(U32.is_eq(c, 48), U32.is_eq(c, 49), (c >= 48 : U32) && (c <= 57 : U32), U32.is_eq(c, 46), t)

# Ranges, parameters and elements.

def parameter_spec(+parts: List<&2, String>) -> {Errors.parameter(parts) == A.parameter(parts) : Bool}:
  match parts:
    case Nil{}: {==}
    case k <> Nil{}: {==}
    case +k <> +v <> Nil{}: Equal.cong(Bool, Bool, x => Bool.not(String.eq(Errors.trim(k), "q")) || x, Errors.quality(Errors.trim(v)), A.positive_qvalue(A.strip(v)), quality_spec(Errors.trim(v)))
    case k <> v <> w <> t: {==}

def parameters_spec(+xs: List<&2, String>) -> {Errors.parameters(xs) == A.parameters(xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case +x <> t:
      %Equal.sym(List<&2, String>, Errors.split(Errors.trim(x), '='), A.pieces(A.strip(x), '='), split_spec(Errors.trim(x), '=')) : {Errors.parameter(_) && Errors.parameters(t) == A.parameters(x <> t) : Bool}
      %Equal.sym(Bool, Errors.parameter(A.pieces(A.strip(x), '=')), A.parameter(A.pieces(A.strip(x), '=')), parameter_spec(A.pieces(A.strip(x), '='))) : {_ && Errors.parameters(t) == A.parameters(x <> t) : Bool}
      Equal.cong(Bool, Bool, y => A.parameter(A.pieces(A.strip(x), '=')) && y, Errors.parameters(t), A.parameters(t), parameters_spec(t))

def media_spec(+parts: List<&2, String>) -> {Errors.media(parts) == A.json_range(parts) : Bool}:
  match parts:
    case Nil{}: {==}
    case +name <> rest: Equal.cong(Bool, Bool, y => String.eq(Errors.trim(name), "application/json") && y, Errors.parameters(rest), A.parameters(rest), parameters_spec(rest))

def tokens_spec(+xs: List<&2, String>) -> {Errors.accepts_json_tokens(xs) == A.any_json(xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case +x <> t:
      %Equal.sym(List<&2, String>, Errors.split(Bytes.fold(x), ';'), A.pieces(Bytes.fold(x), ';'), split_spec(Bytes.fold(x), ';')) : {Errors.media(_) || Errors.accepts_json_tokens(t) == A.any_json(x <> t) : Bool}
      %Equal.sym(Bool, Errors.media(A.pieces(Bytes.fold(x), ';')), A.json_range(A.pieces(Bytes.fold(x), ';')), media_spec(A.pieces(Bytes.fold(x), ';'))) : {_ || Errors.accepts_json_tokens(t) == A.any_json(x <> t) : Bool}
      Equal.cong(Bool, Bool, y => A.json_range(A.pieces(Bytes.fold(x), ';')) || y, Errors.accepts_json_tokens(t), A.any_json(t), tokens_spec(t))

def accepts_spec(+field: Maybe<&2, String>) -> {Errors.accepts_json(field) == A.accepts_json(field) : Bool}:
  match field:
    case None{}: {==}
    case Some{+s}:
      %Equal.sym(List<&2, String>, Errors.split(s, ','), A.pieces(s, ','), split_spec(s, ',')) : {Errors.accepts_json_tokens(_) == A.accepts_json(Some{s}) : Bool}
      tokens_spec(A.pieces(s, ','))

# The field the policy reads.

def values_step(+v: List<&2, U32>, +a: List<&2, List<&2, U32>>, +b: List<&2, List<&2, U32>>, same: Bool, ih: {a == b : List<&2, List<&2, U32>>}) -> {Request.lookup_step(v, a, same) == A.accept_pick(v, b, same) : List<&2, List<&2, U32>>}:
  match same:
    case True{}: Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, x => v <> x, a, b, ih)
    case False{}: ih

def values_spec(+hs: List<&2, Request.Header>) -> {Request.lookup_folded(hs, "accept") == A.accept_values(hs) : List<&2, List<&2, U32>>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+n, +v} <> t:
      values_step(v, Request.lookup_folded(t, "accept"), A.accept_values(t), String.eq(n, "accept"), values_spec(t))

def first_spec(+values: List<&2, List<&2, U32>>) -> {C.first_text(values) == A.first_utf8(values) : Maybe<&2, String>}:
  match values:
    case Nil{}: {==}
    case v <> t: {==}

def field_spec(-Vars: Data, +c: C.Ctx<Vars>) -> {C.request_header(Vars, c, "accept") == A.accept_field(C.request(Vars, c)) : Maybe<&2, String>}:
  match c:
    case C.Ctx{Request.Req{+m, +p, +q, +ver, +hs}, ps, b, pairs, s, out, v, o}:
      %Equal.sym(List<&2, List<&2, U32>>, Request.lookup_folded(hs, "accept"), A.accept_values(hs), values_spec(hs)) : {C.first_text(_) == A.first_utf8(A.accept_values(hs)) : Maybe<&2, String>}
      first_spec(A.accept_values(hs))
