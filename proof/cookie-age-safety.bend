# Max-Age formatting cannot introduce an attribute or header delimiter.
import Base
import ../src/data/cookie.bend as C
import ./cookie-serialization-spec.bend as Spec
import ./response-decimal.bend as D
import ./equality.bend as E

def char_ok(c: Char) -> Bool:
  match c:
    case Chr{+n}: U32.is_ne(n, 59) && U32.is_ne(n, 13) && U32.is_ne(n, 10)

def pair_ok(dq: Char & Nat) -> Bool:
  (d, q) = dq
  char_ok(d)

def divmod_ok(+n: Nat, +s: D.DecimalState, +d: Nat) -> {pair_ok(Nat.show.put(Nat.divmod.go(n, D.remaining(s), d, D.remainder(s)))) == True{} : Bool}:
  match n:
    case 0n:
      match s:
        case D.D0{}:
          {==}
        case D.D1{}:
          {==}
        case D.D2{}:
          {==}
        case D.D3{}:
          {==}
        case D.D4{}:
          {==}
        case D.D5{}:
          {==}
        case D.D6{}:
          {==}
        case D.D7{}:
          {==}
        case D.D8{}:
          {==}
        case D.D9{}:
          {==}
    case 1n+p:
      match s:
        case D.D0{}:
          divmod_ok(p, D.D1{}, d)
        case D.D1{}:
          divmod_ok(p, D.D2{}, d)
        case D.D2{}:
          divmod_ok(p, D.D3{}, d)
        case D.D3{}:
          divmod_ok(p, D.D4{}, d)
        case D.D4{}:
          divmod_ok(p, D.D5{}, d)
        case D.D5{}:
          divmod_ok(p, D.D6{}, d)
        case D.D6{}:
          divmod_ok(p, D.D7{}, d)
        case D.D7{}:
          divmod_ok(p, D.D8{}, d)
        case D.D8{}:
          divmod_ok(p, D.D9{}, d)
        case D.D9{}:
          divmod_ok(p, D.D0{}, 1n+d)


def exclude(~valid: U32 -> Bool, +c: U32, +k: U32, ok: {valid(c) == True{} : Bool}, bad: {valid(k) == False{} : Bool}, same: {c == k : U32}) -> Empty:
  E.false_true(Equal.trans(Bool, False{}, valid(k), True{}, Equal.sym(Bool, valid(k), False{}, bad), Equal.trans(Bool, valid(k), valid(c), True{}, Equal.sym(Bool, valid(c), valid(k), Equal.cong(U32, Bool, x => valid(x), c, k, same)), ok)))

def cons_safe(+c: Char, +s: String, +ok: {char_ok(c) == True{} : Bool}, tail: Spec.no_delimiters(s)) -> Spec.no_delimiters(SCon{c, s}):
  match c:
    case Chr{+n}:
      +first = D.and_left(U32.is_ne(n, 59), U32.is_ne(n, 13), D.and_left(U32.is_ne(n, 59) && U32.is_ne(n, 13), U32.is_ne(n, 10), ok))
      +second = D.and_right(U32.is_ne(n, 59), U32.is_ne(n, 13), D.and_left(U32.is_ne(n, 59) && U32.is_ne(n, 13), U32.is_ne(n, 10), ok))
      third = D.and_right(U32.is_ne(n, 59) && U32.is_ne(n, 13), U32.is_ne(n, 10), ok)
      (same => exclude(~(x => U32.is_ne(x, 59)), n, 59, first, {==}, same), (same => exclude(~(x => U32.is_ne(x, 13)), n, 13, second, {==}, same), (same => exclude(~(x => U32.is_ne(x, 10)), n, 10, third, {==}, same), tail)))

def fin_safe(+g: Nat, +acc: String, dq: Char & Nat, de: {pair_ok(dq) == True{} : Bool}, ae: Spec.no_delimiters(acc), step: @n:Nat -> @s:String -> Spec.no_delimiters(s) -> Spec.no_delimiters(Nat.show.go(g, n, s))) -> Spec.no_delimiters(Nat.show.fin(g, acc, dq)):
  match dq:
    case (+d, q):
      match q:
        case 0n: cons_safe(d, acc, de, ae)
        case 1n+p: step(1n+p, SCon{d, acc}, cons_safe(d, acc, de, ae))

def go_safe(+f: Nat, +n: Nat, +acc: String, ae: Spec.no_delimiters(acc)) -> Spec.no_delimiters(Nat.show.go(f, n, acc)):
  match f:
    case 0n: ae
    case 1n+g:
      fin_safe(g, acc, Nat.show.put(Nat.divmod(n, 10n)), divmod_ok(n, D.D0{}, 0n), ae, +k => +s => e => go_safe(g, k, s, e))

def nat_safe(+n: Nat) -> Spec.no_delimiters(Nat.show(n)):
  fin_safe(n, "", Nat.show.put(Nat.divmod(n, 10n)), divmod_ok(n, D.D0{}, 0n), Unit{}, +k => +s => e => go_safe(n, k, s, e))

def age_safe(+age: C.MaxAge) -> Spec.no_delimiters(Spec.age_text(age)):
  match age:
    case C.Seconds{+n}: nat_safe(n)
    case C.NegativeSeconds{+n}: cons_safe('-', Nat.show(n), {==}, nat_safe(n))
