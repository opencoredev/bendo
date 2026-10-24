# BND-49: Bendo's SSE wire satisfies the independent event-stream parser.
import Base
import ./hot-path.bend as HP
import ../src/http/sse.bend as Sse
import ./sse-spec.bend as Spec
import ./sse-model.bend as Model
import ./date-arith.bend as A
import ../src/data/utf8.bend as Utf8
import ../src/http/response.bend as Response
import ./response-runtime.bend as ResponseRuntime

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  A.false_true(e)

def absurd(-A: Type, e: Empty) -> A:
  match e:

def append_nil(-T: Data, +xs: List<&2, T>) -> {List.append(&2, T, xs, []) == xs : List<&2, T>}:
  match xs:
    case Nil{}: {==}
    case +h <> +t:
      Equal.cong(List<&2, T>, List<&2, T>, rest => h <> rest, List.append(&2, T, t, []), t, append_nil(T, t))

def append_assoc(-T: Data, +xs: List<&2, T>, +ys: List<&2, T>, +zs: List<&2, T>) -> {List.append(&2, T, List.append(&2, T, xs, ys), zs) == List.append(&2, T, xs, List.append(&2, T, ys, zs)) : List<&2, T>}:
  match xs:
    case Nil{}: {==}
    case +h <> +t:
      Equal.cong(List<&2, T>, List<&2, T>, rest => h <> rest, List.append(&2, T, List.append(&2, T, t, ys), zs), List.append(&2, T, t, List.append(&2, T, ys, zs)), append_assoc(T, t, ys, zs))

def run_append(+xs: List<&2, U32>, +ys: List<&2, U32>, +s: Spec.State) -> {Spec.run(List.append(&2, U32, xs, ys), s) == Spec.run(ys, Spec.run(xs, s)) : Spec.State}:
  match xs:
    case Nil{}: {==}
    case +c <> +t: run_append(t, ys, Spec.step(s, c))

# Facts about one octet of a single-line value.
def line_lf(+a: Bool, +b: Bool, +r: Bool, ok: {Bool.not(a || b) && r == True{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case True{}: absurd({True{} == False{} : Bool}, false_true(ok))
    case False{}: {==}

def line_cr(+a: Bool, +b: Bool, +r: Bool, ok: {Bool.not(a || b) && r == True{} : Bool}) -> {b == False{} : Bool}:
  match a b:
    case True{} b: absurd({b == False{} : Bool}, false_true(ok))
    case False{} True{}: absurd({True{} == False{} : Bool}, false_true(ok))
    case False{} False{}: {==}

def line_rest(+a: Bool, +b: Bool, +r: Bool, ok: {Bool.not(a || b) && r == True{} : Bool}) -> {r == True{} : Bool}:
  match a b:
    case True{} b: absurd({r == True{} : Bool}, false_true(ok))
    case False{} True{}: absurd({r == True{} : Bool}, false_true(ok))
    case False{} False{}: ok

# A non-terminator octet goes to the line grammar.
def step_octet(+s: Spec.State, +c: U32, cr: {U32.is_eq(c, 13) == False{} : Bool}, lf: {U32.is_eq(c, 10) == False{} : Bool}) -> {Spec.step(s, c) == Spec.octet(s, c) : Spec.State}:
  %Equal.sym(Bool, U32.is_eq(c, 13), False{}, cr) : {Spec.classify(s, c, _, U32.is_eq(c, 10)) == Spec.octet(s, c) : Spec.State}
  %Equal.sym(Bool, U32.is_eq(c, 10), False{}, lf) : {Spec.classify(s, c, False{}, _) == Spec.octet(s, c) : Spec.State}
  {==}

# A single-line value accumulates unchanged until its line ends.
def value_run(+xs: List<&2, U32>, +b: Spec.Buffers, +name: List<&2, U32>, +v: List<&2, U32>, +ok: {Model.one_line(xs) == True{} : Bool}) -> {Spec.run(xs, Spec.Value{b, name, v}) == Spec.Value{b, name, List.append(&2, U32, v, xs)} : Spec.State}:
  match xs:
    case Nil{}:
      %Equal.sym(List<&2, U32>, List.append(&2, U32, v, []), v, append_nil(U32, v)) : {Spec.Value{b, name, v} == Spec.Value{b, name, _} : Spec.State}
      {==}
    case +c <> +t:
      +lf = line_lf(U32.is_eq(c, 10), U32.is_eq(c, 13), Model.one_line(t), ok)
      +cr = line_cr(U32.is_eq(c, 10), U32.is_eq(c, 13), Model.one_line(t), ok)
      +rest = line_rest(U32.is_eq(c, 10), U32.is_eq(c, 13), Model.one_line(t), ok)
      %Equal.sym(Spec.State, Spec.step(Spec.Value{b, name, v}, c), Spec.octet(Spec.Value{b, name, v}, c), step_octet(Spec.Value{b, name, v}, c, cr, lf)) : {Spec.run(t, _) == Spec.Value{b, name, List.append(&2, U32, v, c <> t)} : Spec.State}
      %Equal.sym(Spec.State, Spec.run(t, Spec.Value{b, name, List.append(&2, U32, v, [c])}), Spec.Value{b, name, List.append(&2, U32, List.append(&2, U32, v, [c]), t)}, value_run(t, b, name, List.append(&2, U32, v, [c]), rest)) : {_ == Spec.Value{b, name, List.append(&2, U32, v, c <> t)} : Spec.State}
      %Equal.sym(List<&2, U32>, List.append(&2, U32, List.append(&2, U32, v, [c]), t), List.append(&2, U32, v, c <> t), append_assoc(U32, v, [c], t)) : {Spec.Value{b, name, _} == Spec.Value{b, name, List.append(&2, U32, v, c <> t)} : Spec.State}
      {==}

# A comment line's text is skipped.
def skip_run(+xs: List<&2, U32>, +b: Spec.Buffers, +ok: {Model.one_line(xs) == True{} : Bool}) -> {Spec.run(xs, Spec.Skip{b}) == Spec.Skip{b} : Spec.State}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      +lf = line_lf(U32.is_eq(c, 10), U32.is_eq(c, 13), Model.one_line(t), ok)
      +cr = line_cr(U32.is_eq(c, 10), U32.is_eq(c, 13), Model.one_line(t), ok)
      +rest = line_rest(U32.is_eq(c, 10), U32.is_eq(c, 13), Model.one_line(t), ok)
      %Equal.sym(Spec.State, Spec.step(Spec.Skip{b}, c), Spec.octet(Spec.Skip{b}, c), step_octet(Spec.Skip{b}, c, cr, lf)) : {Spec.run(t, _) == Spec.Skip{b} : Spec.State}
      skip_run(t, b, rest)

# A heartbeat comment, written at a line start, changes nothing.
def comment_ignored(+b: Spec.Buffers, +text: List<&2, U32>, +rest: List<&2, U32>, +ok: {Model.one_line(text) == True{} : Bool}) -> {Spec.run(List.append(&2, U32, Sse.render(Sse.Comment{text}), rest), Spec.Begin{b}) == Spec.run(rest, Spec.Begin{b}) : Spec.State}:
  %Equal.sym(Spec.State, Spec.run(List.append(&2, U32, List.append(&2, U32, text, [10]), rest), Spec.Skip{b}), Spec.run(rest, Spec.run(List.append(&2, U32, text, [10]), Spec.Skip{b})), run_append(List.append(&2, U32, text, [10]), rest, Spec.Skip{b})) : {_ == Spec.run(rest, Spec.Begin{b}) : Spec.State}
  %Equal.sym(Spec.State, Spec.run(List.append(&2, U32, text, [10]), Spec.Skip{b}), Spec.run([10], Spec.run(text, Spec.Skip{b})), run_append(text, [10], Spec.Skip{b})) : {Spec.run(rest, _) == Spec.run(rest, Spec.Begin{b}) : Spec.State}
  %Equal.sym(Spec.State, Spec.run(text, Spec.Skip{b}), Spec.Skip{b}, skip_run(text, b, ok)) : {Spec.run(rest, Spec.run([10], _)) == Spec.run(rest, Spec.Begin{b}) : Spec.State}
  {==}

def data_buffer(+D: List<&2, U32>, +v: List<&2, U32>, +n: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, D, List.append(&2, U32, List.append(&2, U32, v, n), [10]))

# A data line break: the old line is stored, a new value starts empty.
def break_assoc(+D: List<&2, U32>, +v: List<&2, U32>, +n: List<&2, U32>) -> {List.append(&2, U32, List.append(&2, U32, D, List.append(&2, U32, v, [10])), List.append(&2, U32, n, [10])) == data_buffer(D, v, 10 <> n) : List<&2, U32>}:
  %Equal.sym(List<&2, U32>, List.append(&2, U32, List.append(&2, U32, v, 10 <> n), [10]), List.append(&2, U32, v, List.append(&2, U32, 10 <> n, [10])), append_assoc(U32, v, 10 <> n, [10])) : {List.append(&2, U32, List.append(&2, U32, D, List.append(&2, U32, v, [10])), List.append(&2, U32, n, [10])) == List.append(&2, U32, D, _) : List<&2, U32>}
  %append_assoc(U32, v, [10], List.append(&2, U32, n, [10])) : {List.append(&2, U32, List.append(&2, U32, D, List.append(&2, U32, v, [10])), List.append(&2, U32, n, [10])) == List.append(&2, U32, D, _) : List<&2, U32>}
  append_assoc(U32, D, List.append(&2, U32, v, [10]), List.append(&2, U32, n, [10]))

def data_case(+c: U32, +t: List<&2, U32>, +x10: Bool, +x13: Bool, +cr: Bool, e10: {U32.is_eq(c, 10) == x10 : Bool}, e13: {U32.is_eq(c, 13) == x13 : Bool}, +T: List<&2, U32>, +D: List<&2, U32>, +L: List<&2, U32>, +O: List<&2, Spec.Observed>, +v: List<&2, U32>, ih: @D2: List<&2, U32> -> @v2: List<&2, U32> -> {Spec.run(List.append(&2, U32, Sse.data_lines(t, x13), [10]), Spec.Value{Spec.Buffers{T, D2, L, O}, [100, 97, 116, 97], v2}) == Spec.Begin{Spec.Buffers{T, data_buffer(D2, v2, Spec.newlines(t, x13)), L, O}} : Spec.State}) -> {Spec.run(List.append(&2, U32, List.append(&2, U32, Sse.data_octet(c, x10, x13, cr), Sse.data_lines(t, x13)), [10]), Spec.Value{Spec.Buffers{T, D, L, O}, [100, 97, 116, 97], v}) == Spec.Begin{Spec.Buffers{T, data_buffer(D, v, List.append(&2, U32, Spec.newline_octet(c, x10, x13, cr), Spec.newlines(t, x13))), L, O}} : Spec.State}:
  match x10:
    case True{}:
      match cr:
        case True{}: ih(D, v)
        case False{}:
          %break_assoc(D, v, Spec.newlines(t, x13)) : {Spec.run(List.append(&2, U32, List.append(&2, U32, Sse.data_break(), Sse.data_lines(t, x13)), [10]), Spec.Value{Spec.Buffers{T, D, L, O}, [100, 97, 116, 97], v}) == Spec.Begin{Spec.Buffers{T, _, L, O}} : Spec.State}
          ih(List.append(&2, U32, D, List.append(&2, U32, v, [10])), [])
    case False{}:
      match x13:
        case True{}:
          %break_assoc(D, v, Spec.newlines(t, True{})) : {Spec.run(List.append(&2, U32, List.append(&2, U32, Sse.data_break(), Sse.data_lines(t, True{})), [10]), Spec.Value{Spec.Buffers{T, D, L, O}, [100, 97, 116, 97], v}) == Spec.Begin{Spec.Buffers{T, _, L, O}} : Spec.State}
          ih(List.append(&2, U32, D, List.append(&2, U32, v, [10])), [])
        case False{}:
          +V = {Spec.Value{Spec.Buffers{T, D, L, O}, [100, 97, 116, 97], v} : Spec.State}
          %Equal.sym(Spec.State, Spec.step(V, c), Spec.octet(V, c), step_octet(V, c, e13, e10)) : {Spec.run(List.append(&2, U32, Sse.data_lines(t, False{}), [10]), _) == Spec.Begin{Spec.Buffers{T, data_buffer(D, v, c <> Spec.newlines(t, False{})), L, O}} : Spec.State}
          %append_assoc(U32, v, [c], Spec.newlines(t, False{})) : {Spec.run(List.append(&2, U32, Sse.data_lines(t, False{}), [10]), Spec.Value{Spec.Buffers{T, D, L, O}, [100, 97, 116, 97], List.append(&2, U32, v, [c])}) == Spec.Begin{Spec.Buffers{T, List.append(&2, U32, D, List.append(&2, U32, _, [10])), L, O}} : Spec.State}
          ih(D, List.append(&2, U32, v, [c]))

# Data lines: every CR, LF and CRLF in the value becomes one stored LF.
def data_run(+d: List<&2, U32>, +cr: Bool, +T: List<&2, U32>, +D: List<&2, U32>, +L: List<&2, U32>, +O: List<&2, Spec.Observed>, +v: List<&2, U32>) -> {Spec.run(List.append(&2, U32, Sse.data_lines(d, cr), [10]), Spec.Value{Spec.Buffers{T, D, L, O}, [100, 97, 116, 97], v}) == Spec.Begin{Spec.Buffers{T, data_buffer(D, v, Spec.newlines(d, cr)), L, O}} : Spec.State}:
  match d:
    case Nil{}:
      %Equal.sym(List<&2, U32>, List.append(&2, U32, v, []), v, append_nil(U32, v)) : {Spec.run([10], Spec.Value{Spec.Buffers{T, D, L, O}, [100, 97, 116, 97], v}) == Spec.Begin{Spec.Buffers{T, List.append(&2, U32, D, List.append(&2, U32, _, [10])), L, O}} : Spec.State}
      {==}
    case +c <> +t:
      data_case(c, t, U32.is_eq(c, 10), U32.is_eq(c, 13), cr, {==}, {==}, T, D, L, O, v, D2 => v2 => data_run(t, U32.is_eq(c, 13), T, D2, L, O, v2))

# Every rendered digit is an ASCII digit, so never a line break.
def digit_line(+k: Nat) -> {Model.one_line([Sse.digit(k)]) == True{} : Bool}:
  match k:
    case 0n: {==}
    case 1n+kx:
      match kx:
        case 0n: {==}
        case 1n+kxx:
          match kxx:
            case 0n: {==}
            case 1n+kxxx:
              match kxxx:
                case 0n: {==}
                case 1n+kxxxx:
                  match kxxxx:
                    case 0n: {==}
                    case 1n+kxxxxx:
                      match kxxxxx:
                        case 0n: {==}
                        case 1n+kxxxxxx:
                          match kxxxxxx:
                            case 0n: {==}
                            case 1n+kxxxxxxx:
                              match kxxxxxxx:
                                case 0n: {==}
                                case 1n+kxxxxxxxx:
                                  match kxxxxxxxx:
                                    case 0n: {==}
                                    case 1n+kxxxxxxxxx:
                                      match kxxxxxxxxx:
                                        case 0n: {==}
                                        case 1n+kxxxxxxxxxx: {==}

def digit_ascii(+k: Nat) -> {Spec.ascii_digit(Sse.digit(k)) == True{} : Bool}:
  match k:
    case 0n: {==}
    case 1n+kx:
      match kx:
        case 0n: {==}
        case 1n+kxx:
          match kxx:
            case 0n: {==}
            case 1n+kxxx:
              match kxxx:
                case 0n: {==}
                case 1n+kxxxx:
                  match kxxxx:
                    case 0n: {==}
                    case 1n+kxxxxx:
                      match kxxxxx:
                        case 0n: {==}
                        case 1n+kxxxxxx:
                          match kxxxxxx:
                            case 0n: {==}
                            case 1n+kxxxxxxx:
                              match kxxxxxxx:
                                case 0n: {==}
                                case 1n+kxxxxxxxx:
                                  match kxxxxxxxx:
                                    case 0n: {==}
                                    case 1n+kxxxxxxxxx:
                                      match kxxxxxxxxx:
                                        case 0n: {==}
                                        case 1n+kxxxxxxxxxx: {==}

# Below ten, the digit's value is the number itself.
def digit_value(+k: Nat, lt: {Nat.is_lt(k, 10n) == True{} : Bool}) -> {U32.to_nat((Sse.digit(k) - 48 : U32)) == k : Nat}:
  match k:
    case 0n: {==}
    case 1n+kx:
      match kx:
        case 0n: {==}
        case 1n+kxx:
          match kxx:
            case 0n: {==}
            case 1n+kxxx:
              match kxxx:
                case 0n: {==}
                case 1n+kxxxx:
                  match kxxxx:
                    case 0n: {==}
                    case 1n+kxxxxx:
                      match kxxxxx:
                        case 0n: {==}
                        case 1n+kxxxxxx:
                          match kxxxxxx:
                            case 0n: {==}
                            case 1n+kxxxxxxx:
                              match kxxxxxxx:
                                case 0n: {==}
                                case 1n+kxxxxxxxx:
                                  match kxxxxxxxx:
                                    case 0n: {==}
                                    case 1n+kxxxxxxxxx:
                                      match kxxxxxxxxx:
                                        case 0n: {==}
                                        case 1n+kxxxxxxxxxx: absurd({U32.to_nat((Sse.digit(1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+kxxxxxxxxxx) - 48 : U32)) == 1n+1n+1n+1n+1n+1n+1n+1n+1n+1n+kxxxxxxxxxx : Nat}, A.lt_zero(kxxxxxxxxxx, lt))

def and_left(+a: Bool, +b: Bool, ok: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case False{}: ok
    case True{}: {==}

def and_right(+a: Bool, +b: Bool, ok: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}: absurd({b == True{} : Bool}, false_true(ok))
    case True{}: ok

def line_append(+xs: List<&2, U32>, +ys: List<&2, U32>, +hx: {Model.one_line(xs) == True{} : Bool}, +hy: {Model.one_line(ys) == True{} : Bool}) -> {Model.one_line(List.append(&2, U32, xs, ys)) == True{} : Bool}:
  match xs:
    case Nil{}: hy
    case +c <> +t:
      +lf = line_lf(U32.is_eq(c, 10), U32.is_eq(c, 13), Model.one_line(t), hx)
      +cr = line_cr(U32.is_eq(c, 10), U32.is_eq(c, 13), Model.one_line(t), hx)
      +rest = line_rest(U32.is_eq(c, 10), U32.is_eq(c, 13), Model.one_line(t), hx)
      %Equal.sym(Bool, U32.is_eq(c, 10), False{}, lf) : {Bool.not(_ || U32.is_eq(c, 13)) && Model.one_line(List.append(&2, U32, t, ys)) == True{} : Bool}
      %Equal.sym(Bool, U32.is_eq(c, 13), False{}, cr) : {Bool.not(False{} || _) && Model.one_line(List.append(&2, U32, t, ys)) == True{} : Bool}
      line_append(t, ys, rest, hy)

def all_digits_append(+xs: List<&2, U32>, +ys: List<&2, U32>, +hx: {Spec.all_digits(xs) == True{} : Bool}, +hy: {Spec.all_digits(ys) == True{} : Bool}) -> {Spec.all_digits(List.append(&2, U32, xs, ys)) == True{} : Bool}:
  match xs:
    case Nil{}: hy
    case +c <> +t:
      %Equal.sym(Bool, Spec.ascii_digit(c), True{}, and_left(Spec.ascii_digit(c), Spec.all_digits(t), hx)) : {_ && Spec.all_digits(List.append(&2, U32, t, ys)) == True{} : Bool}
      all_digits_append(t, ys, and_right(Spec.ascii_digit(c), Spec.all_digits(t), hx), hy)

def digit_all(+k: Nat) -> {Spec.all_digits([Sse.digit(k)]) == True{} : Bool}:
  %Equal.sym(Bool, Spec.ascii_digit(Sse.digit(k)), True{}, digit_ascii(k)) : {_ && True{} == True{} : Bool}
  {==}

def digits_snoc(+xs: List<&2, U32>, +k: Nat, +hx: {Spec.digits(xs) == True{} : Bool}) -> {Spec.digits(List.append(&2, U32, xs, [Sse.digit(k)])) == True{} : Bool}:
  match xs:
    case Nil{}: absurd({Spec.digits([Sse.digit(k)]) == True{} : Bool}, false_true(hx))
    case +c <> +t:
      %Equal.sym(Bool, Spec.ascii_digit(c), True{}, and_left(Spec.ascii_digit(c), Spec.all_digits(t), hx)) : {_ && Spec.all_digits(List.append(&2, U32, t, [Sse.digit(k)])) == True{} : Bool}
      all_digits_append(t, [Sse.digit(k)], and_right(Spec.ascii_digit(c), Spec.all_digits(t), hx), digit_all(k))

def digits_line_case(+f: Nat, +k: Nat, +x: Bool, e: {Nat.is_lt(k, 10n) == x : Bool}, ih: {Model.one_line(Sse.nat_digits(f, Nat.div(k, 10n))) == True{} : Bool}) -> {Model.one_line(Sse.nat_digits(1n+f, k)) == True{} : Bool}:
  match x:
    case True{}:
      %Equal.sym(Bool, Nat.is_lt(k, 10n), True{}, e) : {Model.one_line(Sse.branch(List<&2, U32>, _, u => [Sse.digit(k)], u => List.append(&2, U32, Sse.nat_digits(f, Nat.div(k, 10n)), [Sse.digit(Nat.mod(k, 10n))]))) == True{} : Bool}
      digit_line(k)
    case False{}:
      %Equal.sym(Bool, Nat.is_lt(k, 10n), False{}, e) : {Model.one_line(Sse.branch(List<&2, U32>, _, u => [Sse.digit(k)], u => List.append(&2, U32, Sse.nat_digits(f, Nat.div(k, 10n)), [Sse.digit(Nat.mod(k, 10n))]))) == True{} : Bool}
      line_append(Sse.nat_digits(f, Nat.div(k, 10n)), [Sse.digit(Nat.mod(k, 10n))], ih, digit_line(Nat.mod(k, 10n)))

def digits_line(+fuel: Nat, +k: Nat) -> {Model.one_line(Sse.nat_digits(fuel, k)) == True{} : Bool}:
  match fuel:
    case 0n: digit_line(k)
    case 1n+f: digits_line_case(f, k, Nat.is_lt(k, 10n), {==}, digits_line(f, Nat.div(k, 10n)))

def digits_valid_case(+f: Nat, +k: Nat, +x: Bool, e: {Nat.is_lt(k, 10n) == x : Bool}, ih: {Spec.digits(Sse.nat_digits(f, Nat.div(k, 10n))) == True{} : Bool}) -> {Spec.digits(Sse.nat_digits(1n+f, k)) == True{} : Bool}:
  match x:
    case True{}:
      %Equal.sym(Bool, Nat.is_lt(k, 10n), True{}, e) : {Spec.digits(Sse.branch(List<&2, U32>, _, u => [Sse.digit(k)], u => List.append(&2, U32, Sse.nat_digits(f, Nat.div(k, 10n)), [Sse.digit(Nat.mod(k, 10n))]))) == True{} : Bool}
      digit_all(k)
    case False{}:
      %Equal.sym(Bool, Nat.is_lt(k, 10n), False{}, e) : {Spec.digits(Sse.branch(List<&2, U32>, _, u => [Sse.digit(k)], u => List.append(&2, U32, Sse.nat_digits(f, Nat.div(k, 10n)), [Sse.digit(Nat.mod(k, 10n))]))) == True{} : Bool}
      digits_snoc(Sse.nat_digits(f, Nat.div(k, 10n)), Nat.mod(k, 10n), ih)

def digits_valid(+fuel: Nat, +k: Nat) -> {Spec.digits(Sse.nat_digits(fuel, k)) == True{} : Bool}:
  match fuel:
    case 0n: digit_all(k)
    case 1n+f: digits_valid_case(f, k, Nat.is_lt(k, 10n), {==}, digits_valid(f, Nat.div(k, 10n)))

def value_append(+xs: List<&2, U32>, +ys: List<&2, U32>, +acc: Nat) -> {Spec.decimal_value(List.append(&2, U32, xs, ys), acc) == Spec.decimal_value(ys, Spec.decimal_value(xs, acc)) : Nat}:
  match xs:
    case Nil{}: {==}
    case +c <> +t: value_append(t, ys, Nat.add(Nat.mul(acc, 10n), U32.to_nat((c - 48 : U32))))

def le_mul10(+f: Nat) -> {Nat.is_le(f, Nat.mul(f, 10n)) == True{} : Bool}:
  match f:
    case 0n: {==}
    case 1n+p: A.le_succ_r(p, 1n+1n+1n+1n+1n+1n+1n+1n+Nat.mul(p, 10n), A.le_succ_r(p, 1n+1n+1n+1n+1n+1n+1n+Nat.mul(p, 10n), A.le_succ_r(p, 1n+1n+1n+1n+1n+1n+Nat.mul(p, 10n), A.le_succ_r(p, 1n+1n+1n+1n+1n+Nat.mul(p, 10n), A.le_succ_r(p, 1n+1n+1n+1n+Nat.mul(p, 10n), A.le_succ_r(p, 1n+1n+1n+Nat.mul(p, 10n), A.le_succ_r(p, 1n+1n+Nat.mul(p, 10n), A.le_succ_r(p, 1n+Nat.mul(p, 10n), A.le_succ_r(p, Nat.mul(p, 10n), le_mul10(p))))))))))

def div_bound(+k: Nat, +f: Nat, +le: {Nat.is_le(k, 1n+f) == True{} : Bool}) -> {Nat.is_le(Nat.div(k, 10n), f) == True{} : Bool}:
  +wide = {A.le_succ_r(f, 1n+1n+1n+1n+1n+1n+1n+Nat.mul(f, 10n), A.le_succ_r(f, 1n+1n+1n+1n+1n+1n+Nat.mul(f, 10n), A.le_succ_r(f, 1n+1n+1n+1n+1n+Nat.mul(f, 10n), A.le_succ_r(f, 1n+1n+1n+1n+Nat.mul(f, 10n), A.le_succ_r(f, 1n+1n+1n+Nat.mul(f, 10n), A.le_succ_r(f, 1n+1n+Nat.mul(f, 10n), A.le_succ_r(f, 1n+Nat.mul(f, 10n), A.le_succ_r(f, Nat.mul(f, 10n), le_mul10(f))))))))) : {Nat.is_le(1n+1n+f, Nat.mul(1n+f, 10n)) == True{} : Bool}}
  +lt = A.lt_le_trans(k, 1n+1n+f, Nat.mul(1n+f, 10n), A.lt_succ_of_le(k, 1n+f, le), wide)
  A.le_of_lt_succ(Nat.div(k, 10n), f, A.div_lt_of_lt_mul(k, 1n+f, 10n, {==}, lt))

def value_case(+f: Nat, +k: Nat, +x: Bool, +e: {Nat.is_lt(k, 10n) == x : Bool}, +le: {Nat.is_le(k, 1n+f) == True{} : Bool}, ih: @h: {Nat.is_le(Nat.div(k, 10n), f) == True{} : Bool} -> {Spec.decimal_value(Sse.nat_digits(f, Nat.div(k, 10n)), 0n) == Nat.div(k, 10n) : Nat}) -> {Spec.decimal_value(Sse.nat_digits(1n+f, k), 0n) == k : Nat}:
  match x:
    case True{}:
      %Equal.sym(Bool, Nat.is_lt(k, 10n), True{}, e) : {Spec.decimal_value(Sse.branch(List<&2, U32>, _, u => [Sse.digit(k)], u => List.append(&2, U32, Sse.nat_digits(f, Nat.div(k, 10n)), [Sse.digit(Nat.mod(k, 10n))])), 0n) == k : Nat}
      digit_value(k, e)
    case False{}:
      +n = Sse.nat_digits(f, Nat.div(k, 10n))
      +d = Sse.digit(Nat.mod(k, 10n))
      %Equal.sym(Bool, Nat.is_lt(k, 10n), False{}, e) : {Spec.decimal_value(Sse.branch(List<&2, U32>, _, u => [Sse.digit(k)], u => List.append(&2, U32, Sse.nat_digits(f, Nat.div(k, 10n)), [Sse.digit(Nat.mod(k, 10n))])), 0n) == k : Nat}
      %Equal.sym(Nat, Spec.decimal_value(List.append(&2, U32, n, [d]), 0n), Spec.decimal_value([d], Spec.decimal_value(n, 0n)), value_append(n, [d], 0n)) : {_ == k : Nat}
      %Equal.sym(Nat, Spec.decimal_value(n, 0n), Nat.div(k, 10n), ih(div_bound(k, f, le))) : {Nat.add(Nat.mul(_, 10n), U32.to_nat((d - 48 : U32))) == k : Nat}
      %Equal.sym(Nat, U32.to_nat((d - 48 : U32)), Nat.mod(k, 10n), digit_value(Nat.mod(k, 10n), A.mod_lt(k, 10n, {==}))) : {Nat.add(Nat.mul(Nat.div(k, 10n), 10n), _) == k : Nat}
      A.div_mod_id(k, 10n, {==})

def value_digits(+fuel: Nat, +k: Nat, +le: {Nat.is_le(k, fuel) == True{} : Bool}) -> {Spec.decimal_value(Sse.nat_digits(fuel, k), 0n) == k : Nat}:
  match fuel:
    case 0n:
      match k:
        case 0n: {==}
        case 1n+p: absurd({Spec.decimal_value(Sse.nat_digits(0n, 1n+p), 0n) == 1n+p : Nat}, false_true(le))
    case 1n+f: value_case(f, k, Nat.is_lt(k, 10n), {==}, le, h => value_digits(f, Nat.div(k, 10n), h))

# The rendered retry digits are one line of ASCII digits worth exactly n.
def retry_one_line(+n: U32) -> {Model.one_line(Sse.decimal(n)) == True{} : Bool}:
  digits_line(U32.to_nat(n), U32.to_nat(n))

def retry_digits(+n: U32) -> {Spec.digits(Sse.decimal(n)) == True{} : Bool}:
  digits_valid(U32.to_nat(n), U32.to_nat(n))

def retry_value(+n: U32) -> {Spec.decimal_value(Sse.decimal(n), 0n) == U32.to_nat(n) : Nat}:
  value_digits(U32.to_nat(n), U32.to_nat(n), A.le_refl(U32.to_nat(n)))

def seq(+xs: List<&2, U32>, +ys: List<&2, U32>, +s: Spec.State, +mid: Spec.State, +end: Spec.State, h1: {Spec.run(xs, s) == mid : Spec.State}, h2: {Spec.run(ys, mid) == end : Spec.State}) -> {Spec.run(List.append(&2, U32, xs, ys), s) == end : Spec.State}:
  %Equal.sym(Spec.State, Spec.run(List.append(&2, U32, xs, ys), s), Spec.run(ys, Spec.run(xs, s)), run_append(xs, ys, s)) : {_ == end : Spec.State}
  %Equal.sym(Spec.State, Spec.run(xs, s), mid, h1) : {Spec.run(ys, _) == end : Spec.State}
  h2

# One single-line field from a line start: the parser sees exactly its value.
def field_run(+value: List<&2, U32>, +b: Spec.Buffers, +name: List<&2, U32>, +ok: {Model.one_line(value) == True{} : Bool}) -> {Spec.run(List.append(&2, U32, value, [10]), Spec.Value{b, name, []}) == Spec.Begin{Spec.field(b, name, value)} : Spec.State}:
  %Equal.sym(Spec.State, Spec.run(List.append(&2, U32, value, [10]), Spec.Value{b, name, []}), Spec.run([10], Spec.run(value, Spec.Value{b, name, []})), run_append(value, [10], Spec.Value{b, name, []})) : {_ == Spec.Begin{Spec.field(b, name, value)} : Spec.State}
  %Equal.sym(Spec.State, Spec.run(value, Spec.Value{b, name, []}), Spec.Value{b, name, value}, value_run(value, b, name, [], ok)) : {Spec.run([10], _) == Spec.Begin{Spec.field(b, name, value)} : Spec.State}
  {==}

def event_run(+event: Maybe<&2, List<&2, U32>>, +ok: {Model.event_ok(event) == True{} : Bool}, +D: List<&2, U32>, +L: List<&2, U32>, +O: List<&2, Spec.Observed>) -> {Spec.run(Sse.event_line(event), Spec.Begin{Spec.Buffers{[], D, L, O}}) == Spec.Begin{Spec.Buffers{Model.kind(event), D, L, O}} : Spec.State}:
  match event:
    case None{}: {==}
    case Some{+name}: field_run(name, Spec.Buffers{[], D, L, O}, [101, 118, 101, 110, 116], and_left(Model.one_line(name), Model.utf8_ok(name), ok))

def data_line_run(+data: List<&2, U32>, +T: List<&2, U32>, +L: List<&2, U32>, +O: List<&2, Spec.Observed>) -> {Spec.run(Sse.data_line(data), Spec.Begin{Spec.Buffers{T, [], L, O}}) == Spec.Begin{Spec.Buffers{T, List.append(&2, U32, Spec.newlines(data, False{}), [10]), L, O}} : Spec.State}:
  data_run(data, False{}, T, [], L, O, [])

def not_true(+a: Bool, ok: {Bool.not(a) == True{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: absurd({True{} == False{} : Bool}, false_true(ok))

def id_run(+id: Maybe<&2, List<&2, U32>>, +ok: {Model.id_ok(id) == True{} : Bool}, +T: List<&2, U32>, +D: List<&2, U32>, +L: List<&2, U32>, +O: List<&2, Spec.Observed>) -> {Spec.run(Sse.id_line(id), Spec.Begin{Spec.Buffers{T, D, L, O}}) == Spec.Begin{Spec.Buffers{T, D, Model.next_id(L, id), O}} : Spec.State}:
  match id:
    case None{}: {==}
    case Some{+value}:
      +text = and_left(Model.one_line(value) && Bool.not(Spec.has_nul(value)), Model.utf8_ok(value), ok)
      +line = and_left(Model.one_line(value), Bool.not(Spec.has_nul(value)), text)
      +nul = not_true(Spec.has_nul(value), and_right(Model.one_line(value), Bool.not(Spec.has_nul(value)), text))
      %Equal.sym(Spec.State, Spec.run(List.append(&2, U32, value, [10]), Spec.Value{Spec.Buffers{T, D, L, O}, [105, 100], []}), Spec.Begin{Spec.field(Spec.Buffers{T, D, L, O}, [105, 100], value)}, field_run(value, Spec.Buffers{T, D, L, O}, [105, 100], line)) : {_ == Spec.Begin{Spec.Buffers{T, D, value, O}} : Spec.State}
      %Equal.sym(Bool, Spec.has_nul(value), False{}, nul) : {Spec.Begin{Spec.set_id(_, Spec.Buffers{T, D, L, O}, value)} == Spec.Begin{Spec.Buffers{T, D, value, O}} : Spec.State}
      {==}

def retry_run(+retry: Maybe<&2, U32>, +T: List<&2, U32>, +D: List<&2, U32>, +L: List<&2, U32>, +O: List<&2, Spec.Observed>) -> {Spec.run(Sse.retry_line(retry), Spec.Begin{Spec.Buffers{T, D, L, O}}) == Spec.Begin{Spec.Buffers{T, D, L, List.append(&2, Spec.Observed, O, Model.reconnect(retry))}} : Spec.State}:
  match retry:
    case None{}:
      %Equal.sym(List<&2, Spec.Observed>, List.append(&2, Spec.Observed, O, []), O, append_nil(Spec.Observed, O)) : {Spec.Begin{Spec.Buffers{T, D, L, O}} == Spec.Begin{Spec.Buffers{T, D, L, _}} : Spec.State}
      {==}
    case Some{+ms}:
      +b = {Spec.Buffers{T, D, L, O} : Spec.Buffers}
      %Equal.sym(Spec.State, Spec.run(List.append(&2, U32, Sse.decimal(ms), [10]), Spec.Value{b, [114, 101, 116, 114, 121], []}), Spec.Begin{Spec.field(b, [114, 101, 116, 114, 121], Sse.decimal(ms))}, field_run(Sse.decimal(ms), b, [114, 101, 116, 114, 121], retry_one_line(ms))) : {_ == Spec.Begin{Spec.Buffers{T, D, L, List.append(&2, Spec.Observed, O, [Spec.Reconnect{U32.to_nat(ms)}])}} : Spec.State}
      %Equal.sym(Bool, Spec.digits(Sse.decimal(ms)), True{}, retry_digits(ms)) : {Spec.Begin{Spec.set_retry(_, b, Sse.decimal(ms))} == Spec.Begin{Spec.Buffers{T, D, L, List.append(&2, Spec.Observed, O, [Spec.Reconnect{U32.to_nat(ms)}])}} : Spec.State}
      %retry_value(ms) : {Spec.Begin{Spec.Buffers{T, D, L, List.append(&2, Spec.Observed, O, [Spec.Reconnect{Spec.decimal_value(Sse.decimal(ms), 0n)}])}} == Spec.Begin{Spec.Buffers{T, D, L, List.append(&2, Spec.Observed, O, [Spec.Reconnect{_}])}} : Spec.State}
      {==}

# Dispatch: one final LF is removed from the stored data.
def drop_lf_app(+xs: List<&2, U32>) -> {Spec.drop_lf(List.append(&2, U32, xs, [10])) == xs : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +h <> +t:
      match t:
        case Nil{}: {==}
        case +h2 <> +t2:
          Equal.cong(List<&2, U32>, List<&2, U32>, rest => h <> rest, Spec.drop_lf(List.append(&2, U32, h2 <> t2, [10])), h2 <> t2, drop_lf_app(h2 <> t2))

def deliver_lf(+T: List<&2, U32>, +n: List<&2, U32>, +L: List<&2, U32>, +O: List<&2, Spec.Observed>) -> {Spec.deliver(T, List.append(&2, U32, n, [10]), L, O) == Spec.Buffers{[], [], L, List.append(&2, Spec.Observed, O, [Spec.Dispatched{Spec.event_type(T), n, L}])} : Spec.Buffers}:
  match n:
    case Nil{}: {==}
    case +h <> +t:
      %Equal.sym(List<&2, U32>, Spec.drop_lf(List.append(&2, U32, h <> t, [10])), h <> t, drop_lf_app(h <> t)) : {Spec.Buffers{[], [], L, List.append(&2, Spec.Observed, O, [Spec.Dispatched{Spec.event_type(T), _, L}])} == Spec.Buffers{[], [], L, List.append(&2, Spec.Observed, O, [Spec.Dispatched{Spec.event_type(T), h <> t, L}])} : Spec.Buffers}
      {==}

def dispatch_run(+K: List<&2, U32>, +n: List<&2, U32>, +L: List<&2, U32>, +O: List<&2, Spec.Observed>, +R: List<&2, Spec.Observed>) -> {Spec.run([10], Spec.Begin{Spec.Buffers{K, List.append(&2, U32, n, [10]), L, List.append(&2, Spec.Observed, O, R)}}) == Spec.Begin{Spec.Buffers{[], [], L, List.append(&2, Spec.Observed, O, List.append(&2, Spec.Observed, R, [Spec.Dispatched{Spec.event_type(K), n, L}]))}} : Spec.State}:
  +E = {Spec.Dispatched{Spec.event_type(K), n, L} : Spec.Observed}
  Equal.trans(Spec.State, Spec.Begin{Spec.deliver(K, List.append(&2, U32, n, [10]), L, List.append(&2, Spec.Observed, O, R))}, Spec.Begin{Spec.Buffers{[], [], L, List.append(&2, Spec.Observed, List.append(&2, Spec.Observed, O, R), [E])}}, Spec.Begin{Spec.Buffers{[], [], L, List.append(&2, Spec.Observed, O, List.append(&2, Spec.Observed, R, [E]))}}, Equal.cong(Spec.Buffers, Spec.State, b => Spec.Begin{b}, Spec.deliver(K, List.append(&2, U32, n, [10]), L, List.append(&2, Spec.Observed, O, R)), Spec.Buffers{[], [], L, List.append(&2, Spec.Observed, List.append(&2, Spec.Observed, O, R), [E])}, deliver_lf(K, n, L, List.append(&2, Spec.Observed, O, R))), Equal.cong(List<&2, Spec.Observed>, Spec.State, o => Spec.Begin{Spec.Buffers{[], [], L, o}}, List.append(&2, Spec.Observed, List.append(&2, Spec.Observed, O, R), [E]), List.append(&2, Spec.Observed, O, List.append(&2, Spec.Observed, R, [E])), append_assoc(Spec.Observed, O, R, [E])))

def comment_run(+b: Spec.Buffers, +text: List<&2, U32>, +ok: {Model.one_line(text) == True{} : Bool}) -> {Spec.run(Sse.render(Sse.Comment{text}), Spec.Begin{b}) == Spec.Begin{b} : Spec.State}:
  seq(text, [10], Spec.Skip{b}, Spec.Skip{b}, Spec.Begin{b}, skip_run(text, b, ok), {==})

# One admissible frame from a fresh line start.
def frame_run(+f: Sse.Frame, +ok: {Model.frame_ok(f) == True{} : Bool}, +L: List<&2, U32>, +O: List<&2, Spec.Observed>) -> {Spec.run(Sse.render(f), Spec.Begin{Spec.Buffers{[], [], L, O}}) == Spec.Begin{Spec.Buffers{[], [], Model.after(L, f), List.append(&2, Spec.Observed, O, Model.frame_events(L, f))}} : Spec.State}:
  match f:
    case Sse.Message{+e, +d, +i, +r}:
      +fields = and_left(Model.event_ok(e) && Model.id_ok(i), Model.utf8_ok(d), ok)
      +ev = and_left(Model.event_ok(e), Model.id_ok(i), fields)
      +io = and_right(Model.event_ok(e), Model.id_ok(i), fields)
      +K = Model.kind(e)
      +n = Spec.newlines(d, False{})
      +L2 = Model.next_id(L, i)
      +R = Model.reconnect(r)
      +DB = List.append(&2, U32, n, [10])
      +S1 = {Spec.Begin{Spec.Buffers{K, [], L, O}} : Spec.State}
      +S2 = {Spec.Begin{Spec.Buffers{K, DB, L, O}} : Spec.State}
      +S3 = {Spec.Begin{Spec.Buffers{K, DB, L2, O}} : Spec.State}
      +S4 = {Spec.Begin{Spec.Buffers{K, DB, L2, List.append(&2, Spec.Observed, O, R)}} : Spec.State}
      +END = {Spec.Begin{Spec.Buffers{[], [], L2, List.append(&2, Spec.Observed, O, List.append(&2, Spec.Observed, R, [Spec.Dispatched{Spec.event_type(K), n, L2}]))}} : Spec.State}
      +RL = List.append(&2, U32, Sse.retry_line(r), [10])
      +IL = List.append(&2, U32, Sse.id_line(i), RL)
      +DL = List.append(&2, U32, Sse.data_line(d), IL)
      seq(Sse.event_line(e), DL, Spec.Begin{Spec.Buffers{[], [], L, O}}, S1, END, event_run(e, ev, [], L, O), seq(Sse.data_line(d), IL, S1, S2, END, data_line_run(d, K, L, O), seq(Sse.id_line(i), RL, S2, S3, END, id_run(i, io, K, DB, L, O), seq(Sse.retry_line(r), [10], S3, S4, END, retry_run(r, K, DB, L2, O), dispatch_run(K, n, L2, O, R)))))
    case Sse.Comment{+text}:
      %Equal.sym(List<&2, Spec.Observed>, List.append(&2, Spec.Observed, O, []), O, append_nil(Spec.Observed, O)) : {Spec.run(Sse.render(Sse.Comment{text}), Spec.Begin{Spec.Buffers{[], [], L, O}}) == Spec.Begin{Spec.Buffers{[], [], L, _}} : Spec.State}
      comment_run(Spec.Buffers{[], [], L, O}, text, and_left(Model.one_line(text), Model.utf8_ok(text), ok))

def final(frames: List<&2, Sse.Frame>, +last: List<&2, U32>) -> List<&2, U32>:
  match frames:
    case Nil{}: last
    case +f <> rest: final(rest, Model.after(last, f))

def wire_run(+frames: List<&2, Sse.Frame>, +ok: {Model.admissible(frames) == True{} : Bool}, +L: List<&2, U32>, +O: List<&2, Spec.Observed>) -> {Spec.run(Sse.wire(frames), Spec.Begin{Spec.Buffers{[], [], L, O}}) == Spec.Begin{Spec.Buffers{[], [], final(frames, L), List.append(&2, Spec.Observed, O, Model.observe(frames, L))}} : Spec.State}:
  match frames:
    case Nil{}:
      %Equal.sym(List<&2, Spec.Observed>, List.append(&2, Spec.Observed, O, []), O, append_nil(Spec.Observed, O)) : {Spec.Begin{Spec.Buffers{[], [], L, O}} == Spec.Begin{Spec.Buffers{[], [], L, _}} : Spec.State}
      {==}
    case +f <> +rest:
      +fo = and_left(Model.frame_ok(f), Model.admissible(rest), ok)
      +ro = and_right(Model.frame_ok(f), Model.admissible(rest), ok)
      +FE = Model.frame_events(L, f)
      +A2 = Model.after(L, f)
      +OB = Model.observe(rest, A2)
      Equal.trans(Spec.State, Spec.run(List.append(&2, U32, Sse.render(f), Sse.wire(rest)), Spec.Begin{Spec.Buffers{[], [], L, O}}), Spec.Begin{Spec.Buffers{[], [], final(rest, A2), List.append(&2, Spec.Observed, List.append(&2, Spec.Observed, O, FE), OB)}}, Spec.Begin{Spec.Buffers{[], [], final(rest, A2), List.append(&2, Spec.Observed, O, List.append(&2, Spec.Observed, FE, OB))}}, seq(Sse.render(f), Sse.wire(rest), Spec.Begin{Spec.Buffers{[], [], L, O}}, Spec.Begin{Spec.Buffers{[], [], A2, List.append(&2, Spec.Observed, O, FE)}}, Spec.Begin{Spec.Buffers{[], [], final(rest, A2), List.append(&2, Spec.Observed, List.append(&2, Spec.Observed, O, FE), OB)}}, frame_run(f, fo, L, O), wire_run(rest, ro, A2, List.append(&2, Spec.Observed, O, FE))), Equal.cong(List<&2, Spec.Observed>, Spec.State, o => Spec.Begin{Spec.Buffers{[], [], final(rest, A2), o}}, List.append(&2, Spec.Observed, List.append(&2, Spec.Observed, O, FE), OB), List.append(&2, Spec.Observed, O, List.append(&2, Spec.Observed, FE, OB)), append_assoc(Spec.Observed, O, FE, OB)))

# Every frame starts with an ASCII field name or colon, never a BOM.
def bom_free(+frames: List<&2, Sse.Frame>) -> {Spec.strip_bom(Sse.wire(frames)) == Sse.wire(frames) : List<&2, U32>}:
  match frames:
    case Nil{}: {==}
    case Sse.Message{None{}, d, i, r} <> rest: {==}
    case Sse.Message{Some{n}, d, i, r} <> rest: {==}
    case Sse.Comment{t} <> rest: {==}

def roundtrip(+frames: List<&2, Sse.Frame>, +ok: {Model.admissible(frames) == True{} : Bool}) -> {Spec.parse(Sse.wire(frames)) == Model.observe(frames, []) : List<&2, Spec.Observed>}:
  %Equal.sym(List<&2, U32>, Spec.strip_bom(Sse.wire(frames)), Sse.wire(frames), bom_free(frames)) : {Spec.observed(Spec.buffers(Spec.run(_, Spec.initial()))) == Model.observe(frames, []) : List<&2, Spec.Observed>}
  %Equal.sym(Spec.State, Spec.run(Sse.wire(frames), Spec.Begin{Spec.Buffers{[], [], [], []}}), Spec.Begin{Spec.Buffers{[], [], final(frames, []), List.append(&2, Spec.Observed, [], Model.observe(frames, []))}}, wire_run(frames, ok, [], [])) : {Spec.observed(Spec.buffers(_)) == Model.observe(frames, []) : List<&2, Spec.Observed>}
  {==}

# The runtime's injection check is exactly the model's admissibility.
def line2(+a: Bool, +b: Bool, +r: Bool) -> {Bool.not(a) && Bool.not(b) && r == Bool.not(a || b) && r : Bool}:
  match a b:
    case True{} b: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def safe_line(+xs: List<&2, U32>) -> {Sse.line_safe(xs) == Model.one_line(xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      %safe_line(t) : {Bool.not(U32.is_eq(c, 10)) && Bool.not(U32.is_eq(c, 13)) && Sse.line_safe(t) == Bool.not(U32.is_eq(c, 10) || U32.is_eq(c, 13)) && _ : Bool}
      line2(U32.is_eq(c, 10), U32.is_eq(c, 13), Sse.line_safe(t))

def id5(+a: Bool, +b: Bool, +z: Bool, +o: Bool, +h: Bool) -> {Bool.not(a) && Bool.not(b) && Bool.not(z) && (o && Bool.not(h)) == (Bool.not(a || b) && o) && Bool.not(z || h) : Bool}:
  match a b z o h:
    case True{} True{} True{} True{} True{}: {==}
    case True{} True{} True{} True{} False{}: {==}
    case True{} True{} True{} False{} True{}: {==}
    case True{} True{} True{} False{} False{}: {==}
    case True{} True{} False{} True{} True{}: {==}
    case True{} True{} False{} True{} False{}: {==}
    case True{} True{} False{} False{} True{}: {==}
    case True{} True{} False{} False{} False{}: {==}
    case True{} False{} True{} True{} True{}: {==}
    case True{} False{} True{} True{} False{}: {==}
    case True{} False{} True{} False{} True{}: {==}
    case True{} False{} True{} False{} False{}: {==}
    case True{} False{} False{} True{} True{}: {==}
    case True{} False{} False{} True{} False{}: {==}
    case True{} False{} False{} False{} True{}: {==}
    case True{} False{} False{} False{} False{}: {==}
    case False{} True{} True{} True{} True{}: {==}
    case False{} True{} True{} True{} False{}: {==}
    case False{} True{} True{} False{} True{}: {==}
    case False{} True{} True{} False{} False{}: {==}
    case False{} True{} False{} True{} True{}: {==}
    case False{} True{} False{} True{} False{}: {==}
    case False{} True{} False{} False{} True{}: {==}
    case False{} True{} False{} False{} False{}: {==}
    case False{} False{} True{} True{} True{}: {==}
    case False{} False{} True{} True{} False{}: {==}
    case False{} False{} True{} False{} True{}: {==}
    case False{} False{} True{} False{} False{}: {==}
    case False{} False{} False{} True{} True{}: {==}
    case False{} False{} False{} True{} False{}: {==}
    case False{} False{} False{} False{} True{}: {==}
    case False{} False{} False{} False{} False{}: {==}

def safe_id(+xs: List<&2, U32>) -> {Sse.id_safe(xs) == Model.one_line(xs) && Bool.not(Spec.has_nul(xs)) : Bool}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      %Equal.sym(Bool, Sse.id_safe(t), Model.one_line(t) && Bool.not(Spec.has_nul(t)), safe_id(t)) : {Bool.not(U32.is_eq(c, 10)) && Bool.not(U32.is_eq(c, 13)) && Bool.not(U32.is_eq(c, 0)) && _ == (Bool.not(U32.is_eq(c, 10) || U32.is_eq(c, 13)) && Model.one_line(t)) && Bool.not(U32.is_eq(c, 0) || Spec.has_nul(t)) : Bool}
      id5(U32.is_eq(c, 10), U32.is_eq(c, 13), U32.is_eq(c, 0), Model.one_line(t), Spec.has_nul(t))

def same_same(+xs: List<&2, U32>, +ys: List<&2, U32>) -> {Sse.same(xs, ys) == Spec.same(xs, ys) : Bool}:
  match xs ys:
    case Nil{} Nil{}: {==}
    case Nil{} +b <> +t: {==}
    case +a <> +s Nil{}: {==}
    case +a <> +s +b <> +t:
      %same_same(s, t) : {U32.is_eq(a, b) && Sse.same(s, t) == U32.is_eq(a, b) && _ : Bool}
      {==}

def canonical_same(+m: Maybe<&2, String>, +xs: List<&2, U32>) -> {Sse.canonical(m, xs) == Model.scalars_of(m, xs) : Bool}:
  match m:
    case None{}: {==}
    case Some{+s}:
      %same_same(Utf8.encode(s), xs) : {Utf8.valid(s) && Sse.same(Utf8.encode(s), xs) == Utf8.valid(s) && _ : Bool}
      {==}

def utf8_same(+xs: List<&2, U32>) -> {Sse.utf8_text(xs) == Model.utf8_ok(xs) : Bool}:
  canonical_same(Utf8.decode(xs), xs)

def safe_event(+e: Maybe<&2, List<&2, U32>>) -> {Sse.event_safe(e) == Model.event_ok(e) : Bool}:
  match e:
    case None{}: {==}
    case Some{+n}:
      %safe_line(n) : {Sse.line_safe(n) && Sse.utf8_text(n) == _ && Model.utf8_ok(n) : Bool}
      %utf8_same(n) : {Sse.line_safe(n) && Sse.utf8_text(n) == Sse.line_safe(n) && _ : Bool}
      {==}

def safe_id_field(+i: Maybe<&2, List<&2, U32>>) -> {Sse.id_field_safe(i) == Model.id_ok(i) : Bool}:
  match i:
    case None{}: {==}
    case Some{+v}:
      %safe_id(v) : {Sse.id_safe(v) && Sse.utf8_text(v) == _ && Model.utf8_ok(v) : Bool}
      %utf8_same(v) : {Sse.id_safe(v) && Sse.utf8_text(v) == Sse.id_safe(v) && _ : Bool}
      {==}

def valid_ok(+f: Sse.Frame) -> {Sse.valid(f) == Model.frame_ok(f) : Bool}:
  match f:
    case Sse.Message{+e, +d, +i, r}:
      %safe_event(e) : {Sse.event_safe(e) && Sse.id_field_safe(i) && Sse.utf8_text(d) == _ && Model.id_ok(i) && Model.utf8_ok(d) : Bool}
      %safe_id_field(i) : {Sse.event_safe(e) && Sse.id_field_safe(i) && Sse.utf8_text(d) == Sse.event_safe(e) && _ && Model.utf8_ok(d) : Bool}
      %utf8_same(d) : {Sse.event_safe(e) && Sse.id_field_safe(i) && Sse.utf8_text(d) == Sse.event_safe(e) && Sse.id_field_safe(i) && _ : Bool}
      {==}
    case Sse.Comment{+text}:
      %safe_line(text) : {Sse.line_safe(text) && Sse.utf8_text(text) == _ && Model.utf8_ok(text) : Bool}
      %utf8_same(text) : {Sse.line_safe(text) && Sse.utf8_text(text) == Sse.line_safe(text) && _ : Bool}
      {==}

def checked_guarded(+f: Sse.Frame, +x: Bool) -> {Sse.checked(f, x) == Model.guarded(f, x) : Maybe<&2, List<&2, U32>>}:
  match x:
    case True{}: {==}
    case False{}: {==}

def encode_guard(+f: Sse.Frame) -> {Sse.encode(f) == Model.guard(f) : Maybe<&2, List<&2, U32>>}:
  %valid_ok(f) : {Sse.checked(f, Sse.valid(f)) == Model.guarded(f, _) : Maybe<&2, List<&2, U32>>}
  checked_guarded(f, Sse.valid(f))

def none_type(m: Maybe<&2, List<&2, U32>>) -> Type:
  match m:
    case None{}: Unit
    case Some{x}: Empty

def none_some(+bytes: List<&2, U32>, e: {None{} == Some{bytes} : Maybe<&2, List<&2, U32>>}) -> Empty:
  %e : none_type(_)
  Unit{}

def unwrap(m: Maybe<&2, List<&2, U32>>) -> List<&2, U32>:
  match m:
    case None{}: []
    case Some{x}: x

def single(+f: Sse.Frame, +e: {Model.frame_ok(f) == True{} : Bool}) -> {Model.admissible([f]) == True{} : Bool}:
  %Equal.sym(Bool, Model.frame_ok(f), True{}, e) : {_ && True{} == True{} : Bool}
  {==}

def sent_case(+f: Sse.Frame, +bytes: List<&2, U32>, +x: Bool, +e: {Model.frame_ok(f) == x : Bool}, +sent: {Model.guarded(f, x) == Some{bytes} : Maybe<&2, List<&2, U32>>}) -> {Spec.parse(bytes) == Model.observe([f], []) : List<&2, Spec.Observed>}:
  match x:
    case False{}: absurd({Spec.parse(bytes) == Model.observe([f], []) : List<&2, Spec.Observed>}, none_some(bytes, sent))
    case True{}:
      +same = Equal.cong(Maybe<&2, List<&2, U32>>, List<&2, U32>, m => unwrap(m), Some{Sse.render(f)}, Some{bytes}, sent)
      %same : {Spec.parse(_) == Model.observe([f], []) : List<&2, Spec.Observed>}
      %append_nil(U32, Sse.render(f)) : {Spec.parse(_) == Model.observe([f], []) : List<&2, Spec.Observed>}
      roundtrip([f], single(f, e))

# Whatever the runtime sends for any frame parses as exactly that frame.
def sent_frame(+f: Sse.Frame, +bytes: List<&2, U32>, +sent: {Sse.encode(f) == Some{bytes} : Maybe<&2, List<&2, U32>>}) -> {Spec.parse(bytes) == Model.observe([f], []) : List<&2, Spec.Observed>}:
  sent_case(f, bytes, Model.frame_ok(f), {==}, Equal.trans(Maybe<&2, List<&2, U32>>, Model.guard(f), Sse.encode(f), Some{bytes}, Equal.sym(Maybe<&2, List<&2, U32>>, Sse.encode(f), Model.guard(f), encode_guard(f)), sent))

def word_cmp_refl(+n: Nat, +w: Word(n)) -> {Word.cmp(n, w, w) == EQ{} : Cmp}:
  match n w:
    case 0n WNil{}: {==}
    case 1n+p WCon{+b, +t}:
      match b:
        case False{}:
          %Equal.sym(Cmp, Word.cmp(p, t, t), EQ{}, word_cmp_refl(p, t)) : {Word.cmp.fin(False{}, False{}, _) == EQ{} : Cmp}
          {==}
        case True{}:
          %Equal.sym(Cmp, Word.cmp(p, t, t), EQ{}, word_cmp_refl(p, t)) : {Word.cmp.fin(True{}, True{}, _) == EQ{} : Cmp}
          {==}

def u32_refl(+a: U32) -> {U32.is_eq(a, a) == True{} : Bool}:
  match a:
    case U32{+w}:
      %Equal.sym(Cmp, Word.cmp(32n, w, w), EQ{}, word_cmp_refl(32n, w)) : {Cmp.is_eq(_) == True{} : Bool}
      {==}

def same_refl(+xs: List<&2, U32>) -> {Spec.same(xs, xs) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      %Equal.sym(Bool, U32.is_eq(c, c), True{}, u32_refl(c)) : {_ && Spec.same(t, t) == True{} : Bool}
      same_refl(t)

# Text frames built from Strings of Unicode scalar values pass the UTF-8 check.
def text_utf8(+s: String, +ok: {Utf8.valid(s) == True{} : Bool}) -> {Model.utf8_ok(Response.utf8(s)) == True{} : Bool}:
  %Equal.sym(Maybe<&2, String>, Utf8.decode(Response.utf8(s)), Some{s}, ResponseRuntime.utf8(s, ok)) : {Model.scalars_of(_, Response.utf8(s)) == True{} : Bool}
  %HP.utf8_spec_equiv(s) : {Model.scalars_of(Some{s}, _) == True{} : Bool}
  %Equal.sym(Bool, Utf8.valid(s), True{}, ok) : {_ && Spec.same(Utf8.encode(s), Response.utf8_spec(s)) == True{} : Bool}
  %Equal.sym(String, Response.scalars(s), s, ResponseRuntime.scalars(s, ok)) : {True{} && Spec.same(Utf8.encode(s), Utf8.encode(_)) == True{} : Bool}
  same_refl(Utf8.encode(s))
