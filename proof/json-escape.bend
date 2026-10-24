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

def push_digit(acc: U32, w: Word(4n)) -> U32:
  ((acc << 4n : U32) + nibble_value(w) : U32)

def pack16(a: Word(4n), b: Word(4n), c: Word(4n), d: Word(4n)) -> Word(16n):
  U.join(4n, 12n, d, U.join(4n, 8n, c, U.join(4n, 4n, b, a)))

# Four symbolic nibbles cover all 65,536 UTF-16 code units.
def fold_digits(+a: Word(4n), +b: Word(4n), +c: Word(4n), +d: Word(4n)) -> {push_digit(push_digit(push_digit(push_digit(0, a), b), c), d) == code16(pack16(a, b, c, d)) : U32}:
  match a b c d:
    case WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}} WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}} WCon{c0, WCon{c1, WCon{c2, WCon{c3, WNil{}}}}} WCon{d0, WCon{d1, WCon{d2, WCon{d3, WNil{}}}}}:
      %Equal.sym(U32, push_digit(0, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}), U32{U.join(4n, 28n, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, Word.zero(28n))}, prepend_nibble(Word.zero(28n), WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})) : {push_digit(push_digit(push_digit(_, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}), WCon{c0, WCon{c1, WCon{c2, WCon{c3, WNil{}}}}}), WCon{d0, WCon{d1, WCon{d2, WCon{d3, WNil{}}}}}) == code16(pack16(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WNil{}}}}}, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WNil{}}}}})) : U32}
      %Equal.sym(U32, push_digit(U32{U.join(4n, 28n, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, Word.zero(28n))}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}), U32{U.join(4n, 28n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}, U.join(4n, 24n, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, Word.zero(24n)))}, prepend_nibble(U.join(4n, 24n, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, Word.zero(24n)), WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}})) : {push_digit(push_digit(_, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WNil{}}}}}), WCon{d0, WCon{d1, WCon{d2, WCon{d3, WNil{}}}}}) == code16(pack16(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WNil{}}}}}, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WNil{}}}}})) : U32}
      %Equal.sym(U32, push_digit(U32{U.join(4n, 28n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}, U.join(4n, 24n, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, Word.zero(24n)))}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WNil{}}}}}), U32{U.join(4n, 28n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WNil{}}}}}, U.join(4n, 24n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}, U.join(4n, 20n, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, Word.zero(20n))))}, prepend_nibble(U.join(4n, 24n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}, U.join(4n, 20n, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, Word.zero(20n))), WCon{c0, WCon{c1, WCon{c2, WCon{c3, WNil{}}}}})) : {push_digit(_, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WNil{}}}}}) == code16(pack16(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WNil{}}}}}, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WNil{}}}}})) : U32}
      %Equal.sym(U32, push_digit(U32{U.join(4n, 28n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WNil{}}}}}, U.join(4n, 24n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}, U.join(4n, 20n, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, Word.zero(20n))))}, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WNil{}}}}}), U32{U.join(4n, 28n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WNil{}}}}}, U.join(4n, 24n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WNil{}}}}}, U.join(4n, 20n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}, U.join(4n, 16n, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, Word.zero(16n)))))}, prepend_nibble(U.join(4n, 24n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WNil{}}}}}, U.join(4n, 20n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}, U.join(4n, 16n, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, Word.zero(16n)))), WCon{d0, WCon{d1, WCon{d2, WCon{d3, WNil{}}}}})) : {_ == code16(pack16(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WNil{}}}}}, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WNil{}}}}})) : U32}
      {==}

def digits4(+a: Word(4n), +b: Word(4n), +c: Word(4n), +d: Word(4n)) -> String:
  SCon{J.nibble(nibble_value(a)), SCon{J.nibble(nibble_value(b)), SCon{J.nibble(nibble_value(c)), SCon{J.nibble(nibble_value(d)), ""}}}}

# Four digits consume four transitions; finishing MHex{0,...} is separate.
def four_digits(+a: Word(4n), +b: Word(4n), +c: Word(4n), +d: Word(4n), +high: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +fuel: Nat) -> {J.parse_go(4n+fuel, J.Machine{J.MHex{4n, 0, high, rev, key}, digits4(a, b, c, d) ++ suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.MHex{0n, code16(pack16(a, b, c, d)), high, rev, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(Result<&2, &2, J.Error, J.Json>, J.parse_go(4n+fuel, J.Machine{J.MHex{4n, 0, high, rev, key}, SCon{J.nibble(nibble_value(a)), SCon{J.nibble(nibble_value(b)), SCon{J.nibble(nibble_value(c)), SCon{J.nibble(nibble_value(d)), suffix}}}}, stack, depth}), J.parse_go(3n+fuel, J.Machine{J.MHex{3n, push_digit(0, a), high, rev, key}, SCon{J.nibble(nibble_value(b)), SCon{J.nibble(nibble_value(c)), SCon{J.nibble(nibble_value(d)), suffix}}}, stack, depth}), hex_parse_digit(a, 3n, 0, high, rev, key, SCon{J.nibble(nibble_value(b)), SCon{J.nibble(nibble_value(c)), SCon{J.nibble(nibble_value(d)), suffix}}}, stack, depth, 3n+fuel)) : {_ == J.parse_go(fuel, J.Machine{J.MHex{0n, code16(pack16(a, b, c, d)), high, rev, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Result<&2, &2, J.Error, J.Json>, J.parse_go(3n+fuel, J.Machine{J.MHex{3n, push_digit(0, a), high, rev, key}, SCon{J.nibble(nibble_value(b)), SCon{J.nibble(nibble_value(c)), SCon{J.nibble(nibble_value(d)), suffix}}}, stack, depth}), J.parse_go(2n+fuel, J.Machine{J.MHex{2n, push_digit(push_digit(0, a), b), high, rev, key}, SCon{J.nibble(nibble_value(c)), SCon{J.nibble(nibble_value(d)), suffix}}, stack, depth}), hex_parse_digit(b, 2n, push_digit(0, a), high, rev, key, SCon{J.nibble(nibble_value(c)), SCon{J.nibble(nibble_value(d)), suffix}}, stack, depth, 2n+fuel)) : {_ == J.parse_go(fuel, J.Machine{J.MHex{0n, code16(pack16(a, b, c, d)), high, rev, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Result<&2, &2, J.Error, J.Json>, J.parse_go(2n+fuel, J.Machine{J.MHex{2n, push_digit(push_digit(0, a), b), high, rev, key}, SCon{J.nibble(nibble_value(c)), SCon{J.nibble(nibble_value(d)), suffix}}, stack, depth}), J.parse_go(1n+fuel, J.Machine{J.MHex{1n, push_digit(push_digit(push_digit(0, a), b), c), high, rev, key}, SCon{J.nibble(nibble_value(d)), suffix}, stack, depth}), hex_parse_digit(c, 1n, push_digit(push_digit(0, a), b), high, rev, key, SCon{J.nibble(nibble_value(d)), suffix}, stack, depth, 1n+fuel)) : {_ == J.parse_go(fuel, J.Machine{J.MHex{0n, code16(pack16(a, b, c, d)), high, rev, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Result<&2, &2, J.Error, J.Json>, J.parse_go(1n+fuel, J.Machine{J.MHex{1n, push_digit(push_digit(push_digit(0, a), b), c), high, rev, key}, SCon{J.nibble(nibble_value(d)), suffix}, stack, depth}), J.parse_go(0n+fuel, J.Machine{J.MHex{0n, push_digit(push_digit(push_digit(push_digit(0, a), b), c), d), high, rev, key}, suffix, stack, depth}), hex_parse_digit(d, 0n, push_digit(push_digit(push_digit(0, a), b), c), high, rev, key, suffix, stack, depth, 0n+fuel)) : {_ == J.parse_go(fuel, J.Machine{J.MHex{0n, code16(pack16(a, b, c, d)), high, rev, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  Equal.cong(U32, Result<&2, &2, J.Error, J.Json>, code => J.parse_go(fuel, J.Machine{J.MHex{0n, code, high, rev, key}, suffix, stack, depth}), push_digit(push_digit(push_digit(push_digit(0, a), b), c), d), code16(pack16(a, b, c, d)), fold_digits(a, b, c, d))

def pack_split(+w: Word(16n)) -> {pack16(top4(w), mid4(w), next4(w), last4(w)) == w : Word(16n)}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}: {==}

def hex4_continuation(+w: Word(16n), +high: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +fuel: Nat) -> {J.parse_go(4n+fuel, J.Machine{J.MHex{4n, 0, high, rev, key}, hex_digits(w) ++ suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.MHex{0n, code16(w), high, rev, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  %pack_split(w) : {J.parse_go(4n+fuel, J.Machine{J.MHex{4n, 0, high, rev, key}, hex_digits(w) ++ suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.MHex{0n, code16(_), high, rev, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  four_digits(top4(w), mid4(w), next4(w), last4(w), high, rev, key, suffix, stack, depth, fuel)

# Unsigned comparison at the extremes, without arithmetic axioms.
def cmp_ge_false(+bit: Bool, +order: Cmp, good: {Cmp.is_ge(order) == True{} : Bool}) -> {Cmp.is_ge(Word.cmp.fin(bit, False{}, order)) == True{} : Bool}:
  match bit order:
    case False{} LT{}: good
    case True{} LT{}: good
    case False{} EQ{}: {==}
    case True{} EQ{}: {==}
    case _ GT{}: {==}

def cmp_ge_zero(+n: Nat, +w: Word(n)) -> {Cmp.is_ge(Word.cmp(n, w, Word.zero(n))) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+p:
      match w:
        case WCon{h, t}: cmp_ge_false(h, Word.cmp(p, t, Word.zero(p)), cmp_ge_zero(p, t))

def ones(n: Nat) -> Word(n):
  match n:
    case 0n: WNil{}
    case 1n+p: WCon{True{}, ones(p)}

def cmp_le_true(+bit: Bool, +order: Cmp, good: {Cmp.is_le(order) == True{} : Bool}) -> {Cmp.is_le(Word.cmp.fin(bit, True{}, order)) == True{} : Bool}:
  match bit order:
    case _ LT{}: {==}
    case False{} EQ{}: {==}
    case True{} EQ{}: {==}
    case False{} GT{}: good
    case True{} GT{}: good

def cmp_le_ones(+n: Nat, +w: Word(n)) -> {Cmp.is_le(Word.cmp(n, w, ones(n))) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+p:
      match w:
        case WCon{h, t}: cmp_le_true(h, Word.cmp(p, t, ones(p)), cmp_le_ones(p, t))

def surrogate16(+w: Word(11n)) -> Word(16n):
  U.join(11n, 5n, w, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}})

def surrogate_invalid(+w: Word(11n)) -> {U.scalar(code16(surrogate16(w))) == False{} : Bool}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}:
      %Equal.sym(Bool, Cmp.is_ge(Word.cmp(11n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}, Word.zero(11n))), True{}, cmp_ge_zero(11n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}})) : {Bool.not(_ && Cmp.is_le(Word.cmp(11n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}, ones(11n)))) == False{} : Bool}
      %Equal.sym(Bool, Cmp.is_le(Word.cmp(11n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}, ones(11n))), True{}, cmp_le_ones(11n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}})) : {Bool.not(_) == False{} : Bool}
      {==}

def unicode_bmp(+w: Word(16n), +rev: String, +key: Bool, +valid: {U.scalar(code16(w)) == True{} : Bool}) -> {J.unicode_done(code16(w), 0, rev, key) == J.MText{SCon{Chr{code16(w)}, rev}, key} : J.Mode}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}:
      %Equal.sym(Bool, U.scalar(code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{False{}, WNil{}}}}}}}}}}}}}}}}})), True{}, valid) : {J.ordinary(code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}), rev, key, _) == J.MText{SCon{Chr{code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{False{}, WNil{}}}}}}}}}}}}}}}}})}, rev}, key} : J.Mode}
      {==}
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}:
      %Equal.sym(Bool, U.scalar(code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}})), True{}, valid) : {J.ordinary(code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}), rev, key, _) == J.MText{SCon{Chr{code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}})}, rev}, key} : J.Mode}
      {==}
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}:
      %Equal.sym(Bool, U.scalar(code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}})), True{}, valid) : {J.ordinary(code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}), rev, key, _) == J.MText{SCon{Chr{code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}})}, rev}, key} : J.Mode}
      {==}
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}:
      %Equal.sym(Bool, U.scalar(code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}})), True{}, valid) : {J.ordinary(code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}), rev, key, _) == J.MText{SCon{Chr{code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}})}, rev}, key} : J.Mode}
      {==}
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}:
      %Equal.sym(Bool, U.scalar(code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}})), True{}, valid) : {J.ordinary(code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}), rev, key, _) == J.MText{SCon{Chr{code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}})}, rev}, key} : J.Mode}
      {==}
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}:
      P.absurd({J.unicode_done(code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}), 0, rev, key) == J.MText{SCon{Chr{code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}})}, rev}, key} : J.Mode}, P.false_true(Equal.trans(Bool, False{}, U.scalar(code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}})), True{}, Equal.sym(Bool, U.scalar(code16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}})), False{}, surrogate_invalid(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}})), valid)))

def hex_complete(+c: U32, +high: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +fuel: Nat) -> {J.parse_go(1n+fuel, J.Machine{J.MHex{0n, c, high, rev, key}, suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.unicode_done(c, high, rev, key), suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  match suffix:
    case SNil{}: {==}
    case SCon{Chr{b}, t}: {==}

# Decode the exact writer spelling, including both non-consuming hex
# completion and an arbitrary continuation after the escape.
law bmp_escape:
  for +w: Word(16n)
  for +rev: String
  for +key: Bool
  for +suffix: String
  for +stack: List<&2, J.Frame>
  for +depth: Nat
  for +fuel: Nat
  for +valid: {U.scalar(code16(w)) == True{} : Bool}
  {J.parse_go(7n+fuel, J.Machine{J.MText{rev, key}, J.hex4(code16(w)) ++ suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.MText{SCon{Chr{code16(w)}, rev}, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}

def bmp_escape(w, rev, key, suffix, stack, depth, fuel, valid):
  %Equal.sym(String, J.hex4(code16(w)), "\\u" ++ hex_digits(w), hex4_shape(w)) : {J.parse_go(7n+fuel, J.Machine{J.MText{rev, key}, _ ++ suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.MText{SCon{Chr{code16(w)}, rev}, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Result<&2, &2, J.Error, J.Json>, J.parse_go(5n+fuel, J.Machine{J.MHex{4n, 0, 0, rev, key}, hex_digits(w) ++ suffix, stack, depth}), J.parse_go(1n+fuel, J.Machine{J.MHex{0n, code16(w), 0, rev, key}, suffix, stack, depth}), hex4_continuation(w, 0, rev, key, suffix, stack, depth, 1n+fuel)) : {_ == J.parse_go(fuel, J.Machine{J.MText{SCon{Chr{code16(w)}, rev}, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Result<&2, &2, J.Error, J.Json>, J.parse_go(1n+fuel, J.Machine{J.MHex{0n, code16(w), 0, rev, key}, suffix, stack, depth}), J.parse_go(fuel, J.Machine{J.unicode_done(code16(w), 0, rev, key), suffix, stack, depth}), hex_complete(code16(w), 0, rev, key, suffix, stack, depth, fuel)) : {_ == J.parse_go(fuel, J.Machine{J.MText{SCon{Chr{code16(w)}, rev}, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  Equal.cong(J.Mode, Result<&2, &2, J.Error, J.Json>, m => J.parse_go(fuel, J.Machine{m, suffix, stack, depth}), J.unicode_done(code16(w), 0, rev, key), J.MText{SCon{Chr{code16(w)}, rev}, key}, unicode_bmp(w, rev, key, valid))

# Any U32 satisfying the BMP bound has precisely this structural form.
def bmp_reconstruct(+w: Word(32n), bounded: {(U32{w} <= 65535 : U32) == True{} : Bool}) -> {code16(U.low(16n, 16n, w)) == U32{w} : U32}:
  Equal.cong(Word(32n), U32, x => U32{x}, U.join(16n, 16n, U.low(16n, 16n, w), Word.zero(16n)), w, P.pad_reconstruct(16n, 16n, w, P.cmp_le_zero(16n, U.high(16n, 16n, w), P.high_le(16n, 16n, w, P.bits(65535), bounded))))

def bmp_escape_u32(+c: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +fuel: Nat, +bounded: {(c <= 65535 : U32) == True{} : Bool}, +valid: {U.scalar(c) == True{} : Bool}) -> {J.parse_go(7n+fuel, J.Machine{J.MText{rev, key}, J.hex4(c) ++ suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  match c:
    case U32{w}:
      +same = bmp_reconstruct(w, bounded)
      +good = Equal.trans(Bool, U.scalar(code16(U.low(16n, 16n, w))), U.scalar(U32{w}), True{}, Equal.cong(U32, Bool, c => U.scalar(c), code16(U.low(16n, 16n, w)), U32{w}, same), valid)
      %same : {J.parse_go(7n+fuel, J.Machine{J.MText{rev, key}, J.hex4(_) ++ suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.MText{SCon{Chr{_}, rev}, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
      bmp_escape(U.low(16n, 16n, w), rev, key, suffix, stack, depth, fuel, good)

type Short is Data:
  Quote{}
  Backslash{}
  Backspace{}
  FormFeed{}
  Newline{}
  Return{}
  Tab{}

def short_code(s: Short) -> U32:
  match s:
    case Quote{}: 34
    case Backslash{}: 92
    case Backspace{}: 8
    case FormFeed{}: 12
    case Newline{}: 10
    case Return{}: 13
    case Tab{}: 9

law short_escape:
  for +kind: Short
  for +ascii: Bool
  for +rev: String
  for +key: Bool
  for +suffix: String
  for +stack: List<&2, J.Frame>
  for +depth: Nat
  for +fuel: Nat
  {J.parse_go(2n+fuel, J.Machine{J.MText{rev, key}, J.escape_char(short_code(kind), ascii) ++ suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.MText{SCon{Chr{short_code(kind)}, rev}, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}

def short_escape(kind, ascii, rev, key, suffix, stack, depth, fuel):
  match kind:
    case Quote{}: {==}
    case Backslash{}: {==}
    case Backspace{}: {==}
    case FormFeed{}: {==}
    case Newline{}: {==}
    case Return{}: {==}
    case Tab{}: {==}

# Match only the bit prefixes that distinguish quote and backslash. There
# are 63 leaves, rather than enumerating the full U32 domain.
def ordinary_token(+c: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +quote: {U32.is_eq(c, 34) == False{} : Bool}, +slash: {U32.is_eq(c, 92) == False{} : Bool}) -> {J.token(J.MText{rev, key}, SCon{Chr{c}, suffix}, stack, depth) == J.Machine{J.ordinary(c, rev, key, (c >= 32 : U32) && U.scalar(c)), suffix, stack, depth} : J.Machine}:
  match c:
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, t}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, t}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, t}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, t}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      P.absurd({J.token(J.MText{rev, key}, SCon{Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, suffix}, stack, depth) == J.Machine{J.ordinary(U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, rev, key, (U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} >= 32 : U32) && U.scalar(U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}})), suffix, stack, depth} : J.Machine}, P.false_true(Equal.sym(Bool, True{}, False{}, slash)))
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, t}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, t}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, t}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      P.absurd({J.token(J.MText{rev, key}, SCon{Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, suffix}, stack, depth) == J.Machine{J.ordinary(U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, rev, key, (U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} >= 32 : U32) && U.scalar(U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}})), suffix, stack, depth} : J.Machine}, P.false_true(Equal.sym(Bool, True{}, False{}, quote)))
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, t}}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, t}}}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, t}}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, t}}}}}: {==}
    case U32{WCon{False{}, WCon{True{}, WCon{True{}, t}}}}: {==}
    case U32{WCon{True{}, t}}: {==}
# The ordinary-text transition is usable independently of the writer's
# classification, and does not need a BMP bound.
def ordinary_text(+c: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +fuel: Nat, +quote: {U32.is_eq(c, 34) == False{} : Bool}, +slash: {U32.is_eq(c, 92) == False{} : Bool}, +printable: {(c >= 32 : U32) == True{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}) -> {J.parse_go(1n+fuel, J.Machine{J.MText{rev, key}, SCon{Chr{c}, suffix}, stack, depth}) == J.parse_go(fuel, J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(J.Machine, J.token(J.MText{rev, key}, SCon{Chr{c}, suffix}, stack, depth), J.Machine{J.ordinary(c, rev, key, (c >= 32 : U32) && U.scalar(c)), suffix, stack, depth}, ordinary_token(c, rev, key, suffix, stack, depth, quote, slash)) : {J.parse_go(fuel, _) == J.parse_go(fuel, J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Bool, (c >= 32 : U32), True{}, printable) : {J.parse_go(fuel, J.Machine{J.ordinary(c, rev, key, _ && U.scalar(c)), suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Bool, U.scalar(c), True{}, scalar) : {J.parse_go(fuel, J.Machine{J.ordinary(c, rev, key, _), suffix, stack, depth}) == J.parse_go(fuel, J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) : Result<&2, &2, J.Error, J.Json>}
  {==}

# Hexadecimal spelling contains only scalar ASCII, even when the code unit
# being spelled is a surrogate. This is independent of parse admissibility.
def nibble_scalar_evidence(+w: Word(4n), evidence: {B.hex(code(J.nibble(nibble_value(w)))) == True{} : Bool} & {J.unhex(code(J.nibble(nibble_value(w))), J.digit(code(J.nibble(nibble_value(w))))) == nibble_value(w) : U32} & {U.scalar(code(J.nibble(nibble_value(w)))) == True{} : Bool}) -> {U.scalar(code(J.nibble(nibble_value(w)))) == True{} : Bool}:
  (hex, inverse, scalar) = evidence
  scalar

def nibble_scalar(+w: Word(4n)) -> {U.scalar(code(J.nibble(nibble_value(w)))) == True{} : Bool}:
  nibble_scalar_evidence(w, nibble_inverse(w))

def valid_cons(+char: Char, +tail: String, head: {U.scalar(code(char)) == True{} : Bool}, rest: {U.valid_spec(tail) == True{} : Bool}) -> {U.valid_spec(SCon{char, tail}) == True{} : Bool}:
  match char:
    case Chr{c}:
      %Equal.sym(Bool, U.scalar(c), True{}, head) : {_ && U.valid_spec(tail) == True{} : Bool}
      rest

def hex_digits_valid(+w: Word(16n)) -> {U.valid_spec(hex_digits(w)) == True{} : Bool}:
  valid_cons(J.nibble(nibble_value(top4(w))), SCon{J.nibble(nibble_value(mid4(w))), SCon{J.nibble(nibble_value(next4(w))), SCon{J.nibble(nibble_value(last4(w))), ""}}}, nibble_scalar(top4(w)), valid_cons(J.nibble(nibble_value(mid4(w))), SCon{J.nibble(nibble_value(next4(w))), SCon{J.nibble(nibble_value(last4(w))), ""}}, nibble_scalar(mid4(w)), valid_cons(J.nibble(nibble_value(next4(w))), SCon{J.nibble(nibble_value(last4(w))), ""}, nibble_scalar(next4(w)), valid_cons(J.nibble(nibble_value(last4(w))), "", nibble_scalar(last4(w)), {==}))))

law hex4_valid:
  for +w: Word(16n)
  {U.valid_spec(J.hex4(code16(w))) == True{} : Bool}

def hex4_valid(w):
  %Equal.sym(String, J.hex4(code16(w)), "\\u" ++ hex_digits(w), hex4_shape(w)) : {U.valid_spec(_) == True{} : Bool}
  hex_digits_valid(w)
