# Escape inversion over the actual JSON parser state machine.
import Base
import ../src/data/json.bend as J
import ../src/data/utf8.bend as U
import ../src/http/bytes.bend as B
import ./utf8.bend as P

def code(c: Char) -> U32:
  match c:
    case Chr{n}: n

def nibble_value(w: Word(4n)) -> U32:
  U32{U.join(4n, 28n, w, Word.zero(28n))}

# Exhaust all sixteen digits, rather than assuming arithmetic about ASCII.
law nibble_inverse:
  for +w: Word(4n)
  {B.hex(code(J.nibble(nibble_value(w)))) == True{} : Bool} &
  {J.unhex(code(J.nibble(nibble_value(w))), J.digit(code(J.nibble(nibble_value(w))))) == nibble_value(w) : U32} &
  {U.scalar(code(J.nibble(nibble_value(w)))) == True{} : Bool}

def nibble_inverse(w):
  match w:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}: ({==}, {==}, {==})
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}: ({==}, {==}, {==})

# One hexadecimal digit, with arbitrary partially decoded code and high
# surrogate. The suffix, stack, key mode and residual fuel remain untouched.
def hex_character(+char: Char, +value: U32, +left: Nat, +acc: U32, +high: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, hex: {B.hex(code(char)) == True{} : Bool}, inverse: {J.unhex(code(char), J.digit(code(char))) == value : U32}) -> {J.step(J.Machine{J.MHex{1n+left, acc, high, rev, key}, SCon{char, suffix}, stack, depth}) == J.Machine{J.MHex{left, ((acc << 4n : U32) + value : U32), high, rev, key}, suffix, stack, depth} : J.Machine}:
  match char:
    case Chr{n}:
      %Equal.sym(Bool, B.hex(n), True{}, hex) : {J.Machine{J.hex_step(left, acc, high, rev, key, n, _), suffix, stack, depth} == J.Machine{J.MHex{left, ((acc << 4n : U32) + value : U32), high, rev, key}, suffix, stack, depth} : J.Machine}
      %Equal.sym(U32, J.unhex(n, J.digit(n)), value, inverse) : {J.Machine{J.MHex{left, ((acc << 4n : U32) + _ : U32), high, rev, key}, suffix, stack, depth} == J.Machine{J.MHex{left, ((acc << 4n : U32) + value : U32), high, rev, key}, suffix, stack, depth} : J.Machine}
      {==}

def hex_digit_evidence(+w: Word(4n), +left: Nat, +acc: U32, +high: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, evidence: {B.hex(code(J.nibble(nibble_value(w)))) == True{} : Bool} & {J.unhex(code(J.nibble(nibble_value(w))), J.digit(code(J.nibble(nibble_value(w))))) == nibble_value(w) : U32} & {U.scalar(code(J.nibble(nibble_value(w)))) == True{} : Bool}) -> {J.step(J.Machine{J.MHex{1n+left, acc, high, rev, key}, SCon{J.nibble(nibble_value(w)), suffix}, stack, depth}) == J.Machine{J.MHex{left, ((acc << 4n : U32) + nibble_value(w) : U32), high, rev, key}, suffix, stack, depth} : J.Machine}:
  (hex, inverse, scalar) = evidence
  hex_character(J.nibble(nibble_value(w)), nibble_value(w), left, acc, high, rev, key, suffix, stack, depth, hex, inverse)

def hex_digit(+w: Word(4n), +left: Nat, +acc: U32, +high: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat) -> {J.step(J.Machine{J.MHex{1n+left, acc, high, rev, key}, SCon{J.nibble(nibble_value(w)), suffix}, stack, depth}) == J.Machine{J.MHex{left, ((acc << 4n : U32) + nibble_value(w) : U32), high, rev, key}, suffix, stack, depth} : J.Machine}:
  hex_digit_evidence(w, left, acc, high, rev, key, suffix, stack, depth, nibble_inverse(w))

# Bit-level arithmetic shared by the four-digit reconstruction.
def and_zero(+n: Nat, +w: Word(n)) -> {Word.and(n, w, Word.zero(n)) == Word.zero(n) : Word(n)}:
  match n:
    case 0n:
      match w:
        case WNil{}: {==}
    case 1n+p:
      match w:
        case WCon{False{}, t}:
          %and_zero(p, t) : {WCon{False{}, Word.and(p, t, Word.zero(p))} == WCon{False{}, _} : Word(1n+p)}
          {==}
        case WCon{True{}, t}:
          %and_zero(p, t) : {WCon{False{}, Word.and(p, t, Word.zero(p))} == WCon{False{}, _} : Word(1n+p)}
          {==}

def and_one(+b: Bool) -> {b && True{} == b : Bool}:
  match b:
    case False{}: {==}
    case True{}: {==}

def mask4(+w: Word(32n)) -> {(U32{w} .&. 15 : U32) == nibble_value(U.low(4n, 28n, w)) : U32}:
  match w:
    case WCon{a, WCon{b, WCon{c, WCon{d, t}}}}:
      %Equal.sym(Word(28n), Word.and(28n, t, Word.zero(28n)), Word.zero(28n), and_zero(28n, t)) : {U32{WCon{a && True{}, WCon{b && True{}, WCon{c && True{}, WCon{d && True{}, _}}}}} == U32{WCon{a, WCon{b, WCon{c, WCon{d, Word.zero(28n)}}}}} : U32}
      %Equal.sym(Bool, a && True{}, a, and_one(a)) : {U32{WCon{_, WCon{b && True{}, WCon{c && True{}, WCon{d && True{}, Word.zero(28n)}}}}} == U32{WCon{a, WCon{b, WCon{c, WCon{d, Word.zero(28n)}}}}} : U32}
      %Equal.sym(Bool, b && True{}, b, and_one(b)) : {U32{WCon{a, WCon{_, WCon{c && True{}, WCon{d && True{}, Word.zero(28n)}}}}} == U32{WCon{a, WCon{b, WCon{c, WCon{d, Word.zero(28n)}}}}} : U32}
      %Equal.sym(Bool, c && True{}, c, and_one(c)) : {U32{WCon{a, WCon{b, WCon{_, WCon{d && True{}, Word.zero(28n)}}}}} == U32{WCon{a, WCon{b, WCon{c, WCon{d, Word.zero(28n)}}}}} : U32}
      %Equal.sym(Bool, d && True{}, d, and_one(d)) : {U32{WCon{a, WCon{b, WCon{c, WCon{_, Word.zero(28n)}}}}} == U32{WCon{a, WCon{b, WCon{c, WCon{d, Word.zero(28n)}}}}} : U32}
      {==}

def code16(w: Word(16n)) -> U32:
  U32{U.join(16n, 16n, w, Word.zero(16n))}

def top4(w: Word(16n)) -> Word(4n):
  U.high(12n, 4n, w)

def mid4(w: Word(16n)) -> Word(4n):
  U.low(4n, 4n, U.high(8n, 8n, w))

def next4(w: Word(16n)) -> Word(4n):
  U.low(4n, 8n, U.high(4n, 12n, w))

def last4(w: Word(16n)) -> Word(4n):
  U.low(4n, 12n, w)

def hex_digits(+w: Word(16n)) -> String:
  SCon{J.nibble(nibble_value(top4(w))), SCon{J.nibble(nibble_value(mid4(w))), SCon{J.nibble(nibble_value(next4(w))), SCon{J.nibble(nibble_value(last4(w))), ""}}}}

def shift12(+w: Word(16n)) -> {(code16(w) >> 12n : U32) == nibble_value(top4(w)) : U32}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}: {==}

def low_shift8(+w: Word(16n)) -> {U.low(4n, 28n, P.bits((code16(w) >> 8n : U32))) == mid4(w) : Word(4n)}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}: {==}

def low_shift4(+w: Word(16n)) -> {U.low(4n, 28n, P.bits((code16(w) >> 4n : U32))) == next4(w) : Word(4n)}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}: {==}

def low_shift0(+w: Word(16n)) -> {U.low(4n, 28n, P.bits(code16(w))) == last4(w) : Word(4n)}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}: {==}

def hex_spelling(a: U32, b: U32, c: U32, d: U32) -> String:
  SCon{Chr{92}, SCon{'u', SCon{J.nibble(a), SCon{J.nibble(b), SCon{J.nibble(c), SCon{J.nibble(d), ""}}}}}}

def hex4_shape(+w: Word(16n)) -> {J.hex4(code16(w)) == "\\u" ++ hex_digits(w) : String}:
  %Equal.sym(U32, (code16(w) >> 12n : U32), nibble_value(top4(w)), shift12(w)) : {hex_spelling(_, ((code16(w) >> 8n : U32) .&. 15 : U32), ((code16(w) >> 4n : U32) .&. 15 : U32), (code16(w) .&. 15 : U32)) == "\\u" ++ hex_digits(w) : String}
  %Equal.sym(U32, ((code16(w) >> 8n : U32) .&. 15 : U32), nibble_value(mid4(w)), Equal.trans(U32, ((code16(w) >> 8n : U32) .&. 15 : U32), nibble_value(U.low(4n, 28n, P.bits((code16(w) >> 8n : U32)))), nibble_value(mid4(w)), mask4(P.bits((code16(w) >> 8n : U32))), Equal.cong(Word(4n), U32, nibble_value, U.low(4n, 28n, P.bits((code16(w) >> 8n : U32))), mid4(w), low_shift8(w)))) : {hex_spelling(nibble_value(top4(w)), _, ((code16(w) >> 4n : U32) .&. 15 : U32), (code16(w) .&. 15 : U32)) == "\\u" ++ hex_digits(w) : String}
  %Equal.sym(U32, ((code16(w) >> 4n : U32) .&. 15 : U32), nibble_value(next4(w)), Equal.trans(U32, ((code16(w) >> 4n : U32) .&. 15 : U32), nibble_value(U.low(4n, 28n, P.bits((code16(w) >> 4n : U32)))), nibble_value(next4(w)), mask4(P.bits((code16(w) >> 4n : U32))), Equal.cong(Word(4n), U32, nibble_value, U.low(4n, 28n, P.bits((code16(w) >> 4n : U32))), next4(w), low_shift4(w)))) : {hex_spelling(nibble_value(top4(w)), nibble_value(mid4(w)), _, (code16(w) .&. 15 : U32)) == "\\u" ++ hex_digits(w) : String}
  %Equal.sym(U32, (code16(w) .&. 15 : U32), nibble_value(last4(w)), Equal.trans(U32, (code16(w) .&. 15 : U32), nibble_value(U.low(4n, 28n, P.bits(code16(w)))), nibble_value(last4(w)), mask4(P.bits(code16(w))), Equal.cong(Word(4n), U32, nibble_value, U.low(4n, 28n, P.bits(code16(w))), last4(w), low_shift0(w)))) : {hex_spelling(nibble_value(top4(w)), nibble_value(mid4(w)), nibble_value(next4(w)), _) == "\\u" ++ hex_digits(w) : String}
  {==}

def hex_parse_digit(+w: Word(4n), +left: Nat, +acc: U32, +high: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +fuel: Nat) -> {J.parse_go(1n+fuel, J.Machine{J.MHex{1n+left, acc, high, rev, key}, SCon{J.nibble(nibble_value(w)), suffix}, stack, depth}) == J.parse_go(fuel, J.Machine{J.MHex{left, ((acc << 4n : U32) + nibble_value(w) : U32), high, rev, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  Equal.cong(J.Machine, Result<&2, &2, J.Error, J.Json>, m => J.parse_go(fuel, m), J.step(J.Machine{J.MHex{1n+left, acc, high, rev, key}, SCon{J.nibble(nibble_value(w)), suffix}, stack, depth}), J.Machine{J.MHex{left, ((acc << 4n : U32) + nibble_value(w) : U32), high, rev, key}, suffix, stack, depth}, hex_digit(w, left, acc, high, rev, key, suffix, stack, depth))

def adc_zero(+n: Nat, +w: Word(n)) -> {Word.adc(n, w, Word.zero(n), False{}, False{}) == w : Word(n)}:
  match n:
    case 0n:
      match w:
        case WNil{}: {==}
    case 1n+p:
      match w:
        case WCon{False{}, t}:
          %adc_zero(p, t) : {WCon{False{}, Word.adc(p, t, Word.zero(p), False{}, False{})} == WCon{False{}, _} : Word(1n+p)}
          {==}
        case WCon{True{}, t}:
          %adc_zero(p, t) : {WCon{True{}, Word.adc(p, t, Word.zero(p), False{}, False{})} == WCon{True{}, _} : Word(1n+p)}
          {==}

def prepend_nibble(+prefix: Word(28n), +w: Word(4n)) -> {(U32{U.join(4n, 28n, Word.zero(4n), prefix)} + nibble_value(w) : U32) == U32{U.join(4n, 28n, w, prefix)} : U32}:
  match w:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      Equal.cong(Word(28n), U32, t => U32{U.join(4n, 28n, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}, t)}, Word.adc(28n, prefix, Word.zero(28n), False{}, False{}), prefix, adc_zero(28n, prefix))
