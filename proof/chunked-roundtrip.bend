# The chunk decoder reads back every chunk the encoder writes.
import Base
import ../src/http/chunked.bend as C
import ../src/http/bytes.bend as B
import ../src/router/codec-bits.bend as Bits
import ../src/router/equality-proofs.bend as Eq
import ./chunked.bend as P
import ./chunked-arith.bend as A

# Multiplying by sixteen shifts four zero bits in from the bottom.
law mul16_shift:
  for +w: Word(32n)
  {(16 * U32{w} : U32) == U32{Word.add(32n, Word.zero(32n), Word.shl(32n, Word.shl(32n, Word.shl(32n, Word.shl(32n, w)))))} : U32}

def mul16_shift(w):
  {==}

law add_zero_l:
  for +n: Nat
  for +w: Word(n)
  {Word.add(n, Word.zero(n), w) == w : Word(n)}

def add_zero_l(n, w):
  Equal.trans(Word(n), Word.add(n, Word.zero(n), w), Word.add(n, w, Word.zero(n)), w, Word.add_comm(n, Word.zero(n), w), P.adc_zero(n, w))

law shift_quotient:
  for +hi: Word(28n)
  {Word.shl(32n, Word.shl(32n, Word.shl(32n, Word.shl(32n, P.quotient_word(28n, hi))))) == Bits.cat(4n, 28n, Word.zero(4n), hi) : Word(32n)}

def shift_quotient(hi):
  match hi:
    case WCon{+h0, WCon{+h1, WCon{+h2, WCon{+h3, WCon{+h4, WCon{+h5, WCon{+h6, WCon{+h7, WCon{+h8, WCon{+h9, WCon{+h10, WCon{+h11, WCon{+h12, WCon{+h13, WCon{+h14, WCon{+h15, WCon{+h16, WCon{+h17, WCon{+h18, WCon{+h19, WCon{+h20, WCon{+h21, WCon{+h22, WCon{+h23, WCon{+h24, WCon{+h25, WCon{+h26, WCon{+h27, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}

law mul16_quotient:
  for +hi: Word(28n)
  {(16 * U32{P.quotient_word(28n, hi)} : U32) == U32{Bits.cat(4n, 28n, Word.zero(4n), hi)} : U32}

def mul16_quotient(hi):
  +x = Word.shl(32n, Word.shl(32n, Word.shl(32n, Word.shl(32n, P.quotient_word(28n, hi)))))
  %Equal.sym(Word(32n), Word.add(32n, Word.zero(32n), x), x, add_zero_l(32n, x)) : {U32{_} == U32{Bits.cat(4n, 28n, Word.zero(4n), hi)} : U32}
  Equal.cong(Word(32n), U32, w => U32{w}, x, Bits.cat(4n, 28n, Word.zero(4n), hi), shift_quotient(hi))

law shift_digit:
  for +lo: Word(4n)
  for +hi: Word(28n)
  {(16 * U32{P.quotient_word(28n, hi)} + P.nibble(lo) : U32) == U32{Bits.cat(4n, 28n, lo, hi)} : U32}

def shift_digit(lo, hi):
  %Equal.sym(U32, (16 * U32{P.quotient_word(28n, hi)} : U32), U32{Bits.cat(4n, 28n, Word.zero(4n), hi)}, mul16_quotient(hi)) : {(_ + P.nibble(lo) : U32) == U32{Bits.cat(4n, 28n, lo, hi)} : U32}
  P.add_low_nibble(lo, hi)

# Eight quotient steps exhaust every 32-bit size.
def done(fuel: Nat, n: U32) -> Bool:
  match fuel n:
    case 0n n:
      U32.is_eq(n, 0)
    case 1n+p U32{WCon{a, WCon{b, WCon{c, WCon{d, hi}}}}}:
      done(p, U32{P.quotient_word(28n, hi)})

law done_eight:
  for +n: U32
  {done(8n, n) == True{} : Bool}

def done_eight(n):
  match n:
    case U32{WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WCon{+b6, WCon{+b7, WCon{+b8, WCon{+b9, WCon{+b10, WCon{+b11, WCon{+b12, WCon{+b13, WCon{+b14, WCon{+b15, WCon{+b16, WCon{+b17, WCon{+b18, WCon{+b19, WCon{+b20, WCon{+b21, WCon{+b22, WCon{+b23, WCon{+b24, WCon{+b25, WCon{+b26, WCon{+b27, WCon{+b28, WCon{+b29, WCon{+b30, WCon{+b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}

def zero_value(+n: U32, +acc: List<&2, Word(4n)>, zero: {U32.is_eq(n, 0) == True{} : Bool}) ->
    {P.hex_value(acc, 0) == P.hex_value(acc, n) : U32}:
  %Eq.u32_cmp_sound(n, 0, zero) : {P.hex_value(acc, _) == P.hex_value(acc, n) : U32}
  {==}

def value_case(+p: Nat, +lo: Word(4n), +hi: Word(28n), +acc: List<&2, Word(4n)>, zero: Bool,
    isz: {U32.is_eq(U32{Bits.cat(4n, 28n, lo, hi)}, 0) == zero : Bool},
    step: {P.hex_value(P.hex_digits(p, U32{P.quotient_word(28n, hi)}, lo <> acc), 0) == P.hex_value(acc, U32{Bits.cat(4n, 28n, lo, hi)}) : U32}) ->
    {P.hex_value(C.branch(List<&2, Word(4n)>, zero, u => acc, u => P.hex_digits(p, U32{P.quotient_word(28n, hi)}, lo <> acc)), 0) == P.hex_value(acc, U32{Bits.cat(4n, 28n, lo, hi)}) : U32}:
  match zero:
    case True{}:
      zero_value(U32{Bits.cat(4n, 28n, lo, hi)}, acc, isz)
    case False{}:
      step

# The structural digits denote the encoded size.
law hex_digits_value:
  for +fuel: Nat
  for +n: U32
  for +acc: List<&2, Word(4n)>
  for fin: {done(fuel, n) == True{} : Bool}
  {P.hex_value(P.hex_digits(fuel, n, acc), 0) == P.hex_value(acc, n) : U32}

def hex_digits_value(fuel, n, acc, fin):
  match fuel n:
    case 0n n:
      zero_value(n, acc, fin)
    case 1n+p U32{WCon{+a, WCon{+b, WCon{+c, WCon{+d, +hi}}}}}:
      +lo = {WCon{a, WCon{b, WCon{c, WCon{d, WNil{}}}}} : Word(4n)}
      +q = {U32{P.quotient_word(28n, hi)} : U32}
      step = Equal.trans(U32, P.hex_value(P.hex_digits(p, q, lo <> acc), 0), P.hex_value(lo <> acc, q), P.hex_value(acc, U32{Bits.cat(4n, 28n, lo, hi)}),
        hex_digits_value(p, q, lo <> acc, fin),
        Equal.cong(U32, U32, x => P.hex_value(acc, x), (16 * q + P.nibble(lo) : U32), U32{Bits.cat(4n, 28n, lo, hi)}, shift_digit(lo, hi)))
      value_case(p, lo, hi, acc, U32.is_eq(U32{Bits.cat(4n, 28n, lo, hi)}, 0), {==}, step)

def zero_fits(+n: U32, +acc: List<&2, Word(4n)>, zero: {U32.is_eq(n, 0) == True{} : Bool}) ->
    {P.hex_fits(acc, 0) == P.hex_fits(acc, n) : Bool}:
  %Eq.u32_cmp_sound(n, 0, zero) : {P.hex_fits(acc, _) == P.hex_fits(acc, n) : Bool}
  {==}

def fits_case(+p: Nat, +lo: Word(4n), +hi: Word(28n), +acc: List<&2, Word(4n)>, zero: Bool,
    isz: {U32.is_eq(U32{Bits.cat(4n, 28n, lo, hi)}, 0) == zero : Bool},
    step: {P.hex_fits(P.hex_digits(p, U32{P.quotient_word(28n, hi)}, lo <> acc), 0) == P.hex_fits(acc, U32{Bits.cat(4n, 28n, lo, hi)}) : Bool}) ->
    {P.hex_fits(C.branch(List<&2, Word(4n)>, zero, u => acc, u => P.hex_digits(p, U32{P.quotient_word(28n, hi)}, lo <> acc)), 0) == P.hex_fits(acc, U32{Bits.cat(4n, 28n, lo, hi)}) : Bool}:
  match zero:
    case True{}:
      zero_fits(U32{Bits.cat(4n, 28n, lo, hi)}, acc, isz)
    case False{}:
      step

def fits_shift(+lo: Word(4n), +hi: Word(28n), +acc: List<&2, Word(4n)>) ->
    {P.hex_fits(lo <> acc, U32{P.quotient_word(28n, hi)}) == P.hex_fits(acc, U32{Bits.cat(4n, 28n, lo, hi)}) : Bool}:
  +q = {U32{P.quotient_word(28n, hi)} : U32}
  %Equal.sym(Bool, (q <= 268435455 : U32), True{}, P.quotient_fits(hi)) : {_ && P.hex_fits(acc, (16 * q + P.nibble(lo) : U32)) == P.hex_fits(acc, U32{Bits.cat(4n, 28n, lo, hi)}) : Bool}
  Equal.cong(U32, Bool, x => P.hex_fits(acc, x), (16 * q + P.nibble(lo) : U32), U32{Bits.cat(4n, 28n, lo, hi)}, shift_digit(lo, hi))

# No prefix of the structural digits overflows the decoder's accumulator.
law hex_digits_fits:
  for +fuel: Nat
  for +n: U32
  for +acc: List<&2, Word(4n)>
  for fin: {done(fuel, n) == True{} : Bool}
  {P.hex_fits(P.hex_digits(fuel, n, acc), 0) == P.hex_fits(acc, n) : Bool}

def hex_digits_fits(fuel, n, acc, fin):
  match fuel n:
    case 0n n:
      zero_fits(n, acc, fin)
    case 1n+p U32{WCon{+a, WCon{+b, WCon{+c, WCon{+d, +hi}}}}}:
      +lo = {WCon{a, WCon{b, WCon{c, WCon{d, WNil{}}}}} : Word(4n)}
      +q = {U32{P.quotient_word(28n, hi)} : U32}
      step = Equal.trans(Bool, P.hex_fits(P.hex_digits(p, q, lo <> acc), 0), P.hex_fits(lo <> acc, q), P.hex_fits(acc, U32{Bits.cat(4n, 28n, lo, hi)}),
        hex_digits_fits(p, q, lo <> acc, fin), fits_shift(lo, hi, acc))
      fits_case(p, lo, hi, acc, U32.is_eq(U32{Bits.cat(4n, 28n, lo, hi)}, 0), {==}, step)

def seen_case(+p: Nat, +lo: Word(4n), +hi: Word(28n), +d: Word(4n), +acc: List<&2, Word(4n)>, +s: Bool, zero: Bool,
    step: {P.digits_seen(P.hex_digits(p, U32{P.quotient_word(28n, hi)}, lo <> d <> acc), s) == True{} : Bool}) ->
    {P.digits_seen(C.branch(List<&2, Word(4n)>, zero, u => d <> acc, u => P.hex_digits(p, U32{P.quotient_word(28n, hi)}, lo <> d <> acc)), s) == True{} : Bool}:
  match zero:
    case True{}:
      {==}
    case False{}:
      step

law hex_digits_seen:
  for +fuel: Nat
  for +n: U32
  for +d: Word(4n)
  for +acc: List<&2, Word(4n)>
  for +s: Bool
  {P.digits_seen(P.hex_digits(fuel, n, d <> acc), s) == True{} : Bool}

def hex_digits_seen(fuel, n, d, acc, s):
  match fuel n:
    case 0n n:
      {==}
    case 1n+p U32{WCon{+a, WCon{+b, WCon{+c, WCon{+e, +hi}}}}}:
      +lo = {WCon{a, WCon{b, WCon{c, WCon{e, WNil{}}}}} : Word(4n)}
      seen_case(p, lo, hi, d, acc, s, U32.is_eq(U32{Bits.cat(4n, 28n, lo, hi)}, 0), hex_digits_seen(p, U32{P.quotient_word(28n, hi)}, lo, d <> acc, s))

# A nonzero size writes at least one digit.
law hex_digits_nonzero:
  for +p: Nat
  for +n: U32
  for nz: {U32.is_eq(n, 0) == False{} : Bool}
  {P.digits_seen(P.hex_digits(1n+p, n, []), False{}) == True{} : Bool}

def hex_digits_nonzero(p, n, nz):
  match n:
    case U32{WCon{+a, WCon{+b, WCon{+c, WCon{+d, +hi}}}}}:
      +lo = {WCon{a, WCon{b, WCon{c, WCon{d, WNil{}}}}} : Word(4n)}
      %Equal.sym(Bool, U32.is_eq(U32{Bits.cat(4n, 28n, lo, hi)}, 0), False{}, nz) : {P.digits_seen(C.branch(List<&2, Word(4n)>, _, u => [], u => P.hex_digits(p, U32{P.quotient_word(28n, hi)}, lo <> [])), False{}) == True{} : Bool}
      hex_digits_seen(p, U32{P.quotient_word(28n, hi)}, lo, [], False{})

def length_case(+p: Nat, +lo: Word(4n), +hi: Word(28n), +acc: List<&2, Word(4n)>, zero: Bool,
    step: {Nat.is_le(List.length(&2, Word(4n), P.hex_digits(p, U32{P.quotient_word(28n, hi)}, lo <> acc)), Nat.add(p, 1n+List.length(&2, Word(4n), acc))) == True{} : Bool}) ->
    {Nat.is_le(List.length(&2, Word(4n), C.branch(List<&2, Word(4n)>, zero, u => acc, u => P.hex_digits(p, U32{P.quotient_word(28n, hi)}, lo <> acc))), 1n+Nat.add(p, List.length(&2, Word(4n), acc))) == True{} : Bool}:
  match zero:
    case True{}:
      A.le_succ_r(List.length(&2, Word(4n), acc), Nat.add(p, List.length(&2, Word(4n), acc)), A.le_add_l(List.length(&2, Word(4n), acc), p))
    case False{}:
      %A.add_succ_r(p, List.length(&2, Word(4n), acc)) : {Nat.is_le(List.length(&2, Word(4n), P.hex_digits(p, U32{P.quotient_word(28n, hi)}, lo <> acc)), _) == True{} : Bool}
      step

# The fuel bounds the number of digits.
law hex_digits_length:
  for +fuel: Nat
  for +n: U32
  for +acc: List<&2, Word(4n)>
  {Nat.is_le(List.length(&2, Word(4n), P.hex_digits(fuel, n, acc)), Nat.add(fuel, List.length(&2, Word(4n), acc))) == True{} : Bool}

def hex_digits_length(fuel, n, acc):
  match fuel n:
    case 0n n:
      A.le_refl(List.length(&2, Word(4n), acc))
    case 1n+p U32{WCon{+a, WCon{+b, WCon{+c, WCon{+d, +hi}}}}}:
      +lo = {WCon{a, WCon{b, WCon{c, WCon{d, WNil{}}}}} : Word(4n)}
      length_case(p, lo, hi, acc, U32.is_eq(U32{Bits.cat(4n, 28n, lo, hi)}, 0), hex_digits_length(p, U32{P.quotient_word(28n, hi)}, lo <> acc))
