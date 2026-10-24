# Constructive decimal formatting safety, independent of the root laws.
import Base
import ../src/http/bytes.bend as Bytes
import ./bytes-tail.bend as BT
import ./equality.bend as E

type DecimalState is Data:
  D0{}
  D1{}
  D2{}
  D3{}
  D4{}
  D5{}
  D6{}
  D7{}
  D8{}
  D9{}

def remaining(s: DecimalState) -> Nat:
  match s:
    case D0{}:
      9n
    case D1{}:
      8n
    case D2{}:
      7n
    case D3{}:
      6n
    case D4{}:
      5n
    case D5{}:
      4n
    case D6{}:
      3n
    case D7{}:
      2n
    case D8{}:
      1n
    case D9{}:
      0n

def remainder(s: DecimalState) -> Nat:
  match s:
    case D0{}:
      0n
    case D1{}:
      1n
    case D2{}:
      2n
    case D3{}:
      3n
    case D4{}:
      4n
    case D5{}:
      5n
    case D6{}:
      6n
    case D7{}:
      7n
    case D8{}:
      8n
    case D9{}:
      9n

def digit(+c: Char) -> Bool:
  match c:
    case Chr{x}:
      Bytes.value_octet(x) && Bool.not(Bytes.ows(x))

def pair_digit(dq: Char & Nat) -> Bool:
  (d, q) = dq
  digit(d)

# The state records m + r = 9; each step advances the remainder modulo ten.
def divmod_digit(+n: Nat, +s: DecimalState, +d: Nat) -> {pair_digit(Nat.show.put(Nat.divmod.go(n, remaining(s), d, remainder(s)))) == True{} : Bool}:
  match n:
    case 0n:
      match s:
        case D0{}:
          {==}
        case D1{}:
          {==}
        case D2{}:
          {==}
        case D3{}:
          {==}
        case D4{}:
          {==}
        case D5{}:
          {==}
        case D6{}:
          {==}
        case D7{}:
          {==}
        case D8{}:
          {==}
        case D9{}:
          {==}
    case 1n+p:
      match s:
        case D0{}:
          divmod_digit(p, D1{}, d)
        case D1{}:
          divmod_digit(p, D2{}, d)
        case D2{}:
          divmod_digit(p, D3{}, d)
        case D3{}:
          divmod_digit(p, D4{}, d)
        case D4{}:
          divmod_digit(p, D5{}, d)
        case D5{}:
          divmod_digit(p, D6{}, d)
        case D6{}:
          divmod_digit(p, D7{}, d)
        case D7{}:
          divmod_digit(p, D8{}, d)
        case D8{}:
          divmod_digit(p, D9{}, d)
        case D9{}:
          divmod_digit(p, D0{}, 1n+d)

def and_left(a: Bool, b: Bool, e: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case False{}:
      e
    case True{}:
      {==}

def and_right(a: Bool, b: Bool, e: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}:
      E.absurd({b == True{} : Bool}, E.false_true(e))
    case True{}:
      e

def value_cons(+d: Char, +s: String, de: {digit(d) == True{} : Bool}, se: {Bytes.value_spec(Bytes.encode_spec(s)) == True{} : Bool}) -> {Bytes.value_spec(Bytes.encode_spec(SCon{d, s})) == True{} : Bool}:
  match d:
    case Chr{x}:
      Equal.trans(Bool, Bytes.value_octet(x) && Bytes.value_spec(Bytes.encode_spec(s)), Bytes.value_spec(Bytes.encode_spec(s)), True{}, Equal.cong(Bool, Bool, b => b && Bytes.value_spec(Bytes.encode_spec(s)), Bytes.value_octet(x), True{}, and_left(Bytes.value_octet(x), Bool.not(Bytes.ows(x)), de)), se)

def fin_value(+g: Nat, +acc: String, dq: Char & Nat, de: {pair_digit(dq) == True{} : Bool}, ae: {Bytes.value_spec(Bytes.encode_spec(acc)) == True{} : Bool}, step: @n:Nat -> @s:String -> {Bytes.value_spec(Bytes.encode_spec(s)) == True{} : Bool} -> {Bytes.value_spec(Bytes.encode_spec(Nat.show.go(g, n, s))) == True{} : Bool}) -> {Bytes.value_spec(Bytes.encode_spec(Nat.show.fin(g, acc, dq))) == True{} : Bool}:
  match dq:
    case (+d, q):
      match q:
        case 0n:
          value_cons(d, acc, de, ae)
        case 1n+p:
          step(1n+p, SCon{d, acc}, value_cons(d, acc, de, ae))

def go_value(+f: Nat, +n: Nat, +acc: String, ae: {Bytes.value_spec(Bytes.encode_spec(acc)) == True{} : Bool}) -> {Bytes.value_spec(Bytes.encode_spec(Nat.show.go(f, n, acc))) == True{} : Bool}:
  match f:
    case 0n:
      ae
    case 1n+g:
      fin_value(g, acc, Nat.show.put(Nat.divmod(n, 10n)), divmod_digit(n, D0{}, 0n), ae, +k => +s => e => go_value(g, k, s, e))

def nat_show_value_spec(+n: Nat) -> {Bytes.value_spec(Bytes.encode_spec(Nat.show(n))) == True{} : Bool}:
  fin_value(n, SNil{}, Nat.show.put(Nat.divmod(n, 10n)), divmod_digit(n, D0{}, 0n), {==}, +k => +s => e => go_value(n, k, s, e))

# Every fin emits a digit before recurring, including when its fuel is zero.

def nat_show_value(+n: Nat) -> {Bytes.value(Bytes.encode(Nat.show(n))) == True{} : Bool}:
  +x = Nat.show(n)
  Equal.trans(Bool, Bytes.value(Bytes.encode(x)), Bytes.value_spec(Bytes.encode_spec(x)), True{}, Equal.trans(Bool, Bytes.value(Bytes.encode(x)), Bytes.value_spec(Bytes.encode(x)), Bytes.value_spec(Bytes.encode_spec(x)), BT.value_equiv(Bytes.encode(x)), Equal.cong(List<&2, U32>, Bool, l => Bytes.value_spec(l), Bytes.encode(x), Bytes.encode_spec(x), BT.encode_equiv(x))), nat_show_value_spec(n))


def fin_nonempty(+g: Nat, +acc: String, dq: Char & Nat, step: @n:Nat -> @s:String -> {String.is_empty(s) == False{} : Bool} -> {String.is_empty(Nat.show.go(g, n, s)) == False{} : Bool}) -> {String.is_empty(Nat.show.fin(g, acc, dq)) == False{} : Bool}:
  match dq:
    case (d, q):
      match q:
        case 0n:
          {==}
        case 1n+p:
          step(1n+p, SCon{d, acc}, {==})

def go_nonempty(+f: Nat, +n: Nat, +acc: String, ae: {String.is_empty(acc) == False{} : Bool}) -> {String.is_empty(Nat.show.go(f, n, acc)) == False{} : Bool}:
  match f:
    case 0n:
      ae
    case 1n+g:
      fin_nonempty(g, acc, Nat.show.put(Nat.divmod(n, 10n)), +k => +s => e => go_nonempty(g, k, s, e))

def nat_show_nonempty(+n: Nat) -> {String.is_empty(Nat.show(n)) == False{} : Bool}:
  fin_nonempty(n, SNil{}, Nat.show.put(Nat.divmod(n, 10n)), +k => +s => e => go_nonempty(n, k, s, e))


def no_ows(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case +c <> t:
      Bool.not(Bytes.ows(c)) && no_ows(t)

def no_ows_cons(+c: U32, +t: List<&2, U32>, yes: {Bool.not(Bytes.ows(c)) == True{} : Bool}, tail: {no_ows(t) == True{} : Bool}) -> {no_ows(c <> t) == True{} : Bool}:
  %Equal.sym(Bool, Bool.not(Bytes.ows(c)), True{}, yes) : {_ && no_ows(t) == True{} : Bool}
  tail

def no_ows_char(+d: Char, +s: String, de: {digit(d) == True{} : Bool}, se: {no_ows(Bytes.encode_spec(s)) == True{} : Bool}) -> {no_ows(Bytes.encode_spec(SCon{d, s})) == True{} : Bool}:
  match d:
    case Chr{x}:
      no_ows_cons(x, Bytes.encode_spec(s), and_right(Bytes.value_octet(x), Bool.not(Bytes.ows(x)), de), se)

def fin_no_ows(+g: Nat, +acc: String, dq: Char & Nat, de: {pair_digit(dq) == True{} : Bool}, ae: {no_ows(Bytes.encode_spec(acc)) == True{} : Bool}, step: @n:Nat -> @s:String -> {no_ows(Bytes.encode_spec(s)) == True{} : Bool} -> {no_ows(Bytes.encode_spec(Nat.show.go(g, n, s))) == True{} : Bool}) -> {no_ows(Bytes.encode_spec(Nat.show.fin(g, acc, dq))) == True{} : Bool}:
  match dq:
    case (+d, q):
      match q:
        case 0n:
          no_ows_char(d, acc, de, ae)
        case 1n+p:
          step(1n+p, SCon{d, acc}, no_ows_char(d, acc, de, ae))

def go_no_ows(+f: Nat, +n: Nat, +acc: String, ae: {no_ows(Bytes.encode_spec(acc)) == True{} : Bool}) -> {no_ows(Bytes.encode_spec(Nat.show.go(f, n, acc))) == True{} : Bool}:
  match f:
    case 0n:
      ae
    case 1n+g:
      fin_no_ows(g, acc, Nat.show.put(Nat.divmod(n, 10n)), divmod_digit(n, D0{}, 0n), ae, +k => +s => e => go_no_ows(g, k, s, e))

def nat_show_no_ows_spec(+n: Nat) -> {no_ows(Bytes.encode_spec(Nat.show(n))) == True{} : Bool}:
  fin_no_ows(n, SNil{}, Nat.show.put(Nat.divmod(n, 10n)), divmod_digit(n, D0{}, 0n), {==}, +k => +s => e => go_no_ows(n, k, s, e))

def nat_show_no_ows(+n: Nat) -> {no_ows(Bytes.encode(Nat.show(n))) == True{} : Bool}:
  +x = Nat.show(n)
  Equal.trans(Bool, no_ows(Bytes.encode(x)), no_ows(Bytes.encode_spec(x)), True{}, Equal.cong(List<&2, U32>, Bool, l => no_ows(l), Bytes.encode(x), Bytes.encode_spec(x), BT.encode_equiv(x)), nat_show_no_ows_spec(n))


def reverse_no_ows(+xs: List<&2, U32>, +acc: List<&2, U32>, +ok: {no_ows(xs) == True{} : Bool}, +ae: {no_ows(acc) == True{} : Bool}) -> {no_ows(List.reverse.go(&2, U32, xs, acc)) == True{} : Bool}:
  match xs:
    case Nil{}:
      ae
    case c <> t:
      reverse_no_ows(t, c <> acc, and_right(Bool.not(Bytes.ows(c)), no_ows(t), ok), no_ows_cons(c, acc, and_left(Bool.not(Bytes.ows(c)), no_ows(t), ok), ae))
