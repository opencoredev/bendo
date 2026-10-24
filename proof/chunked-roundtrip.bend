# The chunk decoder reads back every chunk the encoder writes.
import Base
import ../src/http/chunked.bend as C
import ../src/http/bytes.bend as B
import ./bytes-tail.bend as BT
import ./text.bend as TP
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

# List facts.

law append_nil:
  for +xs: List<&2, U32>
  {B.append(xs, []) == xs : List<&2, U32>}

def append_nil(xs):
  Equal.trans(List<&2, U32>, B.append(xs, []), List.append(&2, U32, xs, []), xs, BT.append_equiv(xs, []), TP.list_append_nil(U32, xs))

law append_assoc:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for +zs: List<&2, U32>
  {B.append(B.append(xs, ys), zs) == B.append(xs, B.append(ys, zs)) : List<&2, U32>}

def append_assoc_list(+xs: List<&2, U32>, +ys: List<&2, U32>, +zs: List<&2, U32>) -> {List.append(&2, U32, List.append(&2, U32, xs, ys), zs) == List.append(&2, U32, xs, List.append(&2, U32, ys, zs)) : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      Equal.cong(List<&2, U32>, List<&2, U32>, x => h <> x, List.append(&2, U32, List.append(&2, U32, t, ys), zs), List.append(&2, U32, t, List.append(&2, U32, ys, zs)), append_assoc_list(t, ys, zs))

# Bytes.append is a reversed tail loop (BND-84); the law goes through List.append.
def append_assoc(xs, ys, zs):
  Equal.trans(List<&2, U32>, B.append(B.append(xs, ys), zs), List.append(&2, U32, B.append(xs, ys), zs), B.append(xs, B.append(ys, zs)), BT.append_equiv(B.append(xs, ys), zs), Equal.trans(List<&2, U32>, List.append(&2, U32, B.append(xs, ys), zs), List.append(&2, U32, List.append(&2, U32, xs, ys), zs), B.append(xs, B.append(ys, zs)), Equal.cong(List<&2, U32>, List<&2, U32>, l => List.append(&2, U32, l, zs), B.append(xs, ys), List.append(&2, U32, xs, ys), BT.append_equiv(xs, ys)), Equal.trans(List<&2, U32>, List.append(&2, U32, List.append(&2, U32, xs, ys), zs), List.append(&2, U32, xs, List.append(&2, U32, ys, zs)), B.append(xs, B.append(ys, zs)), append_assoc_list(xs, ys, zs), Equal.trans(List<&2, U32>, List.append(&2, U32, xs, List.append(&2, U32, ys, zs)), List.append(&2, U32, xs, B.append(ys, zs)), B.append(xs, B.append(ys, zs)), Equal.cong(List<&2, U32>, List<&2, U32>, l => List.append(&2, U32, xs, l), List.append(&2, U32, ys, zs), B.append(ys, zs), Equal.sym(List<&2, U32>, B.append(ys, zs), List.append(&2, U32, ys, zs), BT.append_equiv(ys, zs))), Equal.sym(List<&2, U32>, B.append(xs, B.append(ys, zs)), List.append(&2, U32, xs, B.append(ys, zs)), BT.append_equiv(xs, B.append(ys, zs)))))))

law length_append:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  {List.length(&2, U32, B.append(xs, ys)) == Nat.add(List.length(&2, U32, xs), List.length(&2, U32, ys)) : Nat}

def length_append_list(+xs: List<&2, U32>, +ys: List<&2, U32>) -> {List.length(&2, U32, List.append(&2, U32, xs, ys)) == Nat.add(List.length(&2, U32, xs), List.length(&2, U32, ys)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      Equal.cong(Nat, Nat, x => 1n+x, List.length(&2, U32, List.append(&2, U32, t, ys)), Nat.add(List.length(&2, U32, t), List.length(&2, U32, ys)), length_append_list(t, ys))

# The induction runs over List.append; Bytes.append is a reversed tail loop (BND-84).
def length_append(xs, ys):
  %Equal.sym(List<&2, U32>, B.append(xs, ys), List.append(&2, U32, xs, ys), BT.append_equiv(xs, ys)) : {List.length(&2, U32, _) == Nat.add(List.length(&2, U32, xs), List.length(&2, U32, ys)) : Nat}
  length_append_list(xs, ys)

law reverse_go_append:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for +acc: List<&2, U32>
  {List.reverse.go(&2, U32, B.append(xs, ys), acc) == List.reverse.go(&2, U32, ys, List.reverse.go(&2, U32, xs, acc)) : List<&2, U32>}

def reverse_go_append_list(+xs: List<&2, U32>, +ys: List<&2, U32>, +acc: List<&2, U32>) -> {List.reverse.go(&2, U32, List.append(&2, U32, xs, ys), acc) == List.reverse.go(&2, U32, ys, List.reverse.go(&2, U32, xs, acc)) : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      reverse_go_append_list(t, ys, h <> acc)

# The induction runs over List.append; Bytes.append is a reversed tail loop (BND-84).
def reverse_go_append(xs, ys, acc):
  %Equal.sym(List<&2, U32>, B.append(xs, ys), List.append(&2, U32, xs, ys), BT.append_equiv(xs, ys)) : {List.reverse.go(&2, U32, _, acc) == List.reverse.go(&2, U32, ys, List.reverse.go(&2, U32, xs, acc)) : List<&2, U32>}
  reverse_go_append_list(xs, ys, acc)

law reverse_twice:
  for +xs: List<&2, U32>
  for +acc: List<&2, U32>
  for +ys: List<&2, U32>
  {List.reverse.go(&2, U32, List.reverse.go(&2, U32, xs, acc), ys) == List.reverse.go(&2, U32, acc, B.append(xs, ys)) : List<&2, U32>}

def reverse_twice_list(+xs: List<&2, U32>, +acc: List<&2, U32>, +ys: List<&2, U32>) -> {List.reverse.go(&2, U32, List.reverse.go(&2, U32, xs, acc), ys) == List.reverse.go(&2, U32, acc, List.append(&2, U32, xs, ys)) : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      reverse_twice_list(t, h <> acc, ys)

# The induction runs over List.append; Bytes.append is a reversed tail loop (BND-84).
def reverse_twice(xs, acc, ys):
  %Equal.sym(List<&2, U32>, B.append(xs, ys), List.append(&2, U32, xs, ys), BT.append_equiv(xs, ys)) : {List.reverse.go(&2, U32, List.reverse.go(&2, U32, xs, acc), ys) == List.reverse.go(&2, U32, acc, _) : List<&2, U32>}
  reverse_twice_list(xs, acc, ys)

law reverse_reverse:
  for +xs: List<&2, U32>
  {List.reverse(&2, U32, List.reverse(&2, U32, xs)) == xs : List<&2, U32>}

def reverse_reverse(xs):
  Equal.trans(List<&2, U32>, List.reverse(&2, U32, List.reverse(&2, U32, xs)), B.append(xs, []), xs, reverse_twice(xs, [], []), append_nil(xs))

# The size line: hexadecimal digits, CR, LF.

# A line of at most nine octets stays far below the 8192-octet limit.
law small_count:
  for +m: Nat
  for fit: {Nat.is_le(m, 9n) == True{} : Bool}
  {(U32.from_nat(m) < 8192 : U32) == True{} : Bool}

def small_count(m, fit):
  match m:
    case 0n:
      {==}
    case 1n:
      {==}
    case 2n:
      {==}
    case 3n:
      {==}
    case 4n:
      {==}
    case 5n:
      {==}
    case 6n:
      {==}
    case 7n:
      {==}
    case 8n:
      {==}
    case 9n:
      {==}
    case 10n+p:
      Bits.absurd({(U32.from_nat(10n+p) < 8192 : U32) == True{} : Bool}, Bits.false_true(fit))

law small_inc:
  for +m: Nat
  for fit: {Nat.is_le(m, 9n) == True{} : Bool}
  {(U32.from_nat(m) + 1 : U32) == U32.from_nat(1n+m) : U32}

def small_inc(m, fit):
  match m:
    case 0n:
      {==}
    case 1n:
      {==}
    case 2n:
      {==}
    case 3n:
      {==}
    case 4n:
      {==}
    case 5n:
      {==}
    case 6n:
      {==}
    case 7n:
      {==}
    case 8n:
      {==}
    case 9n:
      {==}
    case 10n+p:
      Bits.absurd({(U32.from_nat(10n+p) + 1 : U32) == U32.from_nat(11n+p) : U32}, Bits.false_true(fit))

law size_hex_octet:
  for +d: Word(4n)
  for +budget: U32
  for +body: List<&2, U32>
  for +line: List<&2, U32>
  for +count: U32
  {C.size_octet_inner(budget, body, line, count, False{}, C.hex_char(P.nibble(d))) == C.Size{budget, body, C.hex_char(P.nibble(d)) <> line, count, False{}} : C.State}

def size_hex_octet(d, budget, body, line, count):
  match d:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      {==}

law size_line:
  for +ds: List<&2, Word(4n)>
  for +m: Nat
  for +budget: U32
  for +body: List<&2, U32>
  for +line: List<&2, U32>
  for +rest: List<&2, U32>
  for fit: {Nat.is_le(Nat.add(m, List.length(&2, Word(4n), ds)), 9n) == True{} : Bool}
  {C.feed(B.append(P.hex_bytes(ds), rest), C.Size{budget, body, line, U32.from_nat(m), False{}}) == C.feed(rest, C.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(ds), line), U32.from_nat(Nat.add(m, List.length(&2, Word(4n), ds))), False{}}) : C.State & C.DecodeResult}

def size_line_list(+ds: List<&2, Word(4n)>, +m: Nat, +budget: U32, +body: List<&2, U32>, +line: List<&2, U32>, +rest: List<&2, U32>, fit: {Nat.is_le(Nat.add(m, List.length(&2, Word(4n), ds)), 9n) == True{} : Bool}) -> {C.feed(List.append(&2, U32, P.hex_bytes(ds), rest), C.Size{budget, body, line, U32.from_nat(m), False{}}) == C.feed(rest, C.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(ds), line), U32.from_nat(Nat.add(m, List.length(&2, Word(4n), ds))), False{}}) : C.State & C.DecodeResult}:
  match ds:
    case Nil{}:
      %Equal.sym(Nat, Nat.add(m, 0n), m, A.add_zero_r(m)) : {C.feed(rest, C.Size{budget, body, line, U32.from_nat(m), False{}}) == C.feed(rest, C.Size{budget, body, line, U32.from_nat(_), False{}}) : C.State & C.DecodeResult}
      {==}
    case +d <> +t:
      +fit = fit
      +hc = C.hex_char(P.nibble(d))
      +len = List.length(&2, Word(4n), t)
      fit0 = A.le_add_r(m, 1n+len, 9n, fit)
      +fit0 = fit0
      fit1 = {
        %A.add_succ_r(m, len) : {Nat.is_le(_, 9n) == True{} : Bool}
        fit : {Nat.is_le(1n+Nat.add(m, len), 9n) == True{} : Bool}}
      %Equal.sym(Bool, (U32.from_nat(m) < 8192 : U32), True{}, small_count(m, fit0)) : {C.feed(List.append(&2, U32, P.hex_bytes(t), rest), C.branch(C.State, _, u => C.size_octet_inner(budget, body, line, (U32.from_nat(m) + 1 : U32), False{}, hc), u => C.Failed{400})) == C.feed(rest, C.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(t), hc <> line), U32.from_nat(Nat.add(m, 1n+len)), False{}}) : C.State & C.DecodeResult}
      %Equal.sym(U32, (U32.from_nat(m) + 1 : U32), U32.from_nat(1n+m), small_inc(m, fit0)) : {C.feed(List.append(&2, U32, P.hex_bytes(t), rest), C.size_octet_inner(budget, body, line, _, False{}, hc)) == C.feed(rest, C.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(t), hc <> line), U32.from_nat(Nat.add(m, 1n+len)), False{}}) : C.State & C.DecodeResult}
      %Equal.sym(C.State, C.size_octet_inner(budget, body, line, U32.from_nat(1n+m), False{}, hc), C.Size{budget, body, hc <> line, U32.from_nat(1n+m), False{}}, size_hex_octet(d, budget, body, line, U32.from_nat(1n+m))) : {C.feed(List.append(&2, U32, P.hex_bytes(t), rest), _) == C.feed(rest, C.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(t), hc <> line), U32.from_nat(Nat.add(m, 1n+len)), False{}}) : C.State & C.DecodeResult}
      %Equal.sym(Nat, Nat.add(m, 1n+len), 1n+Nat.add(m, len), A.add_succ_r(m, len)) : {C.feed(List.append(&2, U32, P.hex_bytes(t), rest), C.Size{budget, body, hc <> line, U32.from_nat(1n+m), False{}}) == C.feed(rest, C.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(t), hc <> line), U32.from_nat(_), False{}}) : C.State & C.DecodeResult}
      size_line_list(t, 1n+m, budget, body, hc <> line, rest, fit1)

# The induction runs over List.append; Bytes.append is a reversed tail loop (BND-84).
def size_line(ds, m, budget, body, line, rest, fit):
  %Equal.sym(List<&2, U32>, B.append(P.hex_bytes(ds), rest), List.append(&2, U32, P.hex_bytes(ds), rest), BT.append_equiv(P.hex_bytes(ds), rest)) : {C.feed(_, C.Size{budget, body, line, U32.from_nat(m), False{}}) == C.feed(rest, C.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(ds), line), U32.from_nat(Nat.add(m, List.length(&2, Word(4n), ds))), False{}}) : C.State & C.DecodeResult}
  size_line_list(ds, m, budget, body, line, rest, fit)

law size_line_end:
  for +n: Nat
  for +budget: U32
  for +body: List<&2, U32>
  for +line: List<&2, U32>
  for +rest: List<&2, U32>
  for short: {Nat.is_le(n, 8n) == True{} : Bool}
  {C.feed(13 <> 10 <> rest, C.Size{budget, body, line, U32.from_nat(n), False{}}) == C.feed(rest, C.start_chunk(budget, body, C.size_digits(List.reverse(&2, U32, line), 0, False{}))) : C.State & C.DecodeResult}

def size_line_end(n, budget, body, line, rest, short):
  +short = short
  +fit = A.le_succ_r(n, 8n, short)
  -goal = C.feed(rest, C.start_chunk(budget, body, C.size_digits(List.reverse(&2, U32, line), 0, False{})))
  %Equal.sym(Bool, (U32.from_nat(n) < 8192 : U32), True{}, small_count(n, fit)) : {C.feed(10 <> rest, C.branch(C.State, _, u => C.size_octet_inner(budget, body, line, (U32.from_nat(n) + 1 : U32), False{}, 13), u => C.Failed{400})) == goal : C.State & C.DecodeResult}
  %Equal.sym(U32, (U32.from_nat(n) + 1 : U32), U32.from_nat(1n+n), small_inc(n, fit)) : {C.feed(10 <> rest, C.size_octet_inner(budget, body, line, _, False{}, 13)) == goal : C.State & C.DecodeResult}
  %Equal.sym(Bool, (U32.from_nat(1n+n) < 8192 : U32), True{}, small_count(1n+n, short)) : {C.feed(rest, C.branch(C.State, _, u => C.size_octet_inner(budget, body, line, (U32.from_nat(1n+n) + 1 : U32), True{}, 10), u => C.Failed{400})) == goal : C.State & C.DecodeResult}
  {==}

# Up to eight digits, then CRLF, start a chunk with the parsed size.
law size_header:
  for +ds: List<&2, Word(4n)>
  for +budget: U32
  for +body: List<&2, U32>
  for +rest: List<&2, U32>
  for short: {Nat.is_le(List.length(&2, Word(4n), ds), 8n) == True{} : Bool}
  {C.feed(B.append(P.hex_bytes(ds), 13 <> 10 <> rest), C.Size{budget, body, [], 0, False{}}) == C.feed(rest, C.start_chunk(budget, body, C.size_digits(P.hex_bytes(ds), 0, False{}))) : C.State & C.DecodeResult}

def size_header(ds, budget, body, rest, short):
  +short = short
  +n = List.length(&2, Word(4n), ds)
  +line = List.reverse.go(&2, U32, P.hex_bytes(ds), [])
  Equal.trans(C.State & C.DecodeResult,
    C.feed(B.append(P.hex_bytes(ds), 13 <> 10 <> rest), C.Size{budget, body, [], U32.from_nat(0n), False{}}),
    C.feed(13 <> 10 <> rest, C.Size{budget, body, line, U32.from_nat(n), False{}}),
    C.feed(rest, C.start_chunk(budget, body, C.size_digits(P.hex_bytes(ds), 0, False{}))),
    size_line(ds, 0n, budget, body, [], 13 <> 10 <> rest, A.le_succ_r(n, 8n, short)),
    Equal.trans(C.State & C.DecodeResult,
      C.feed(13 <> 10 <> rest, C.Size{budget, body, line, U32.from_nat(n), False{}}),
      C.feed(rest, C.start_chunk(budget, body, C.size_digits(List.reverse(&2, U32, line), 0, False{}))),
      C.feed(rest, C.start_chunk(budget, body, C.size_digits(P.hex_bytes(ds), 0, False{}))),
      size_line_end(n, budget, body, line, rest, short),
      Equal.cong(List<&2, U32>, C.State & C.DecodeResult, xs => C.feed(rest, C.start_chunk(budget, body, C.size_digits(xs, 0, False{}))), List.reverse(&2, U32, line), P.hex_bytes(ds), reverse_reverse(P.hex_bytes(ds)))))

# The decoder parses the encoder's digits back to the size.
law size_parse:
  for +size: U32
  for nz: {U32.is_eq(size, 0) == False{} : Bool}
  {C.size_digits(P.hex_bytes(P.hex_digits(8n, size, [])), 0, False{}) == Some{size} : Maybe<&2, U32>}

def size_parse(size, nz):
  +ds = P.hex_digits(8n, size, [])
  +fin = done_eight(size)
  Equal.trans(Maybe<&2, U32>, C.size_digits(P.hex_bytes(ds), 0, False{}), C.size_result(P.hex_value(ds, 0), P.digits_seen(ds, False{})), Some{size},
    P.parse_hex_digits(ds, 0, False{}, hex_digits_fits(8n, size, [], fin)),
    %Equal.sym(U32, P.hex_value(ds, 0), size, hex_digits_value(8n, size, [], fin)) : {C.size_result(_, P.digits_seen(ds, False{})) == Some{size} : Maybe<&2, U32>}
    %Equal.sym(Bool, P.digits_seen(ds, False{}), True{}, hex_digits_nonzero(7n, size, nz)) : {C.size_result(size, _) == Some{size} : Maybe<&2, U32>}
    {==})

law start_payload:
  for +budget: U32
  for +body: List<&2, U32>
  for +size: U32
  for nz: {U32.is_eq(size, 0) == False{} : Bool}
  for fits: {(size <= budget : U32) == True{} : Bool}
  {C.start_chunk(budget, body, Some{size}) == C.Payload{(budget - size : U32), body, size} : C.State}

def start_payload(budget, body, size, nz, fits):
  %Equal.sym(Bool, U32.is_eq(size, 0), False{}, nz) : {C.start_size(budget, body, size, _) == C.Payload{(budget - size : U32), body, size} : C.State}
  %Equal.sym(Bool, (size <= budget : U32), True{}, fits) : {Bool.pick(C.State, _, C.Payload{(budget - size : U32), body, size}, C.Failed{413}) == C.Payload{(budget - size : U32), body, size} : C.State}
  {==}

# Payload octets.

law payload_octet:
  for +budget: U32
  for +acc: List<&2, U32>
  for +left: U32
  for +c: U32
  for oct: {(c <= 255 : U32) == True{} : Bool}
  for one: {U32.is_eq(left, 1) == False{} : Bool}
  for zero: {U32.is_eq(left, 0) == False{} : Bool}
  {C.data_octet(budget, acc, left, c) == C.Payload{budget, c <> acc, (left - 1 : U32)} : C.State}

def payload_octet(budget, acc, left, c, oct, one, zero):
  %Equal.sym(Bool, (c <= 255 : U32), True{}, oct) : {C.branch(C.State, _, u => C.data_left(budget, acc, left, c), u => C.Failed{400}) == C.Payload{budget, c <> acc, (left - 1 : U32)} : C.State}
  %Equal.sym(Bool, U32.is_eq(left, 1), False{}, one) : {C.data_next(budget, c <> acc, left, _) == C.Payload{budget, c <> acc, (left - 1 : U32)} : C.State}
  %Equal.sym(Bool, U32.is_eq(left, 0), False{}, zero) : {C.data_rest(budget, c <> acc, left, _) == C.Payload{budget, c <> acc, (left - 1 : U32)} : C.State}
  {==}

law payload_last:
  for +budget: U32
  for +acc: List<&2, U32>
  for +left: U32
  for +c: U32
  for oct: {(c <= 255 : U32) == True{} : Bool}
  for one: {U32.is_eq(left, 1) == True{} : Bool}
  {C.data_octet(budget, acc, left, c) == C.DataCR{budget, c <> acc} : C.State}

def payload_last(budget, acc, left, c, oct, one):
  %Equal.sym(Bool, (c <= 255 : U32), True{}, oct) : {C.branch(C.State, _, u => C.data_left(budget, acc, left, c), u => C.Failed{400}) == C.DataCR{budget, c <> acc} : C.State}
  %Equal.sym(Bool, U32.is_eq(left, 1), True{}, one) : {C.data_next(budget, c <> acc, left, _) == C.DataCR{budget, c <> acc} : C.State}
  {==}

def left_eq(+left: U32, +k: Nat, +n: U32, len: {U32.to_nat(left) == k : Nat}) -> {U32.is_eq(left, n) == Nat.is_eq(k, U32.to_nat(n)) : Bool}:
  %len : {U32.is_eq(left, n) == Nat.is_eq(_, U32.to_nat(n)) : Bool}
  A.u32_nat_eq(left, n)

def one_le(+left: U32, +k: Nat, len: {U32.to_nat(left) == 2n+k : Nat}) -> {(1 <= left : U32) == True{} : Bool}:
  %Equal.sym(Bool, U32.is_le(1, left), Nat.is_le(U32.to_nat(1), U32.to_nat(left)), A.u32_nat_le(1, left)) : {_ == True{} : Bool}
  %Equal.sym(Nat, U32.to_nat(left), 2n+k, len) : {Nat.is_le(U32.to_nat(1), _) == True{} : Bool}
  {==}

# Reading exactly the counted octets, then CRLF, returns to the size line.
law scan_payload:
  for +t: List<&2, U32>
  for +c: U32
  for +budget: U32
  for +acc: List<&2, U32>
  for +left: U32
  for +more: List<&2, U32>
  for oct: {C.octets(c <> t) == True{} : Bool}
  for len: {U32.to_nat(left) == 1n+List.length(&2, U32, t) : Nat}
  {C.feed(c <> B.append(t, 13 <> 10 <> more), C.Payload{budget, acc, left}) == C.feed(more, C.Size{budget, List.reverse.go(&2, U32, c <> t, acc), [], 0, False{}}) : C.State & C.DecodeResult}

def scan_payload_list(+t: List<&2, U32>, +c: U32, +budget: U32, +acc: List<&2, U32>, +left: U32, +more: List<&2, U32>, oct: {C.octets(c <> t) == True{} : Bool}, len: {U32.to_nat(left) == 1n+List.length(&2, U32, t) : Nat}) -> {C.feed(c <> List.append(&2, U32, t, 13 <> 10 <> more), C.Payload{budget, acc, left}) == C.feed(more, C.Size{budget, List.reverse.go(&2, U32, c <> t, acc), [], 0, False{}}) : C.State & C.DecodeResult}:
  match t:
    case Nil{}:
      +oct = oct
      octc = P.both_left((c <= 255 : U32), C.octets([]), oct)
      %Equal.sym(C.State, C.data_octet(budget, acc, left, c), C.DataCR{budget, c <> acc}, payload_last(budget, acc, left, c, octc, left_eq(left, 1n, 1, len))) : {C.feed(13 <> 10 <> more, _) == C.feed(more, C.Size{budget, c <> acc, [], 0, False{}}) : C.State & C.DecodeResult}
      {==}
    case +c2 <> +t2:
      +oct = oct
      +len = len
      +octc = P.both_left((c <= 255 : U32), C.octets(c2 <> t2), oct)
      +octr = P.both_right((c <= 255 : U32), C.octets(c2 <> t2), oct)
      +k = List.length(&2, U32, t2)
      sub = Equal.trans(Nat, 1n+U32.to_nat((left - 1 : U32)), U32.to_nat(left), 2n+k, A.u32_sub_nat(left, 1, one_le(left, k, len)), len)
      len2 = Equal.cong(Nat, Nat, x => A.pred(x), 1n+U32.to_nat((left - 1 : U32)), 2n+k, sub)
      %Equal.sym(C.State, C.data_octet(budget, acc, left, c), C.Payload{budget, c <> acc, (left - 1 : U32)}, payload_octet(budget, acc, left, c, octc, left_eq(left, 2n+k, 1, len), left_eq(left, 2n+k, 0, len))) : {C.feed(c2 <> List.append(&2, U32, t2, 13 <> 10 <> more), _) == C.feed(more, C.Size{budget, List.reverse.go(&2, U32, c2 <> t2, c <> acc), [], 0, False{}}) : C.State & C.DecodeResult}
      scan_payload_list(t2, c2, budget, c <> acc, (left - 1 : U32), more, octr, len2)

# One producer chunk.

# The induction runs over List.append; Bytes.append is a reversed tail loop (BND-84).
def scan_payload(t, c, budget, acc, left, more, oct, len):
  %Equal.sym(List<&2, U32>, B.append(t, 13 <> 10 <> more), List.append(&2, U32, t, 13 <> 10 <> more), BT.append_equiv(t, 13 <> 10 <> more)) : {C.feed(c <> _, C.Payload{budget, acc, left}) == C.feed(more, C.Size{budget, List.reverse.go(&2, U32, c <> t, acc), [], 0, False{}}) : C.State & C.DecodeResult}
  scan_payload_list(t, c, budget, acc, left, more, oct, len)

def size_nonzero(+size: U32, +k: Nat, exact: {U32.to_nat(size) == 1n+k : Nat}) -> {U32.is_eq(size, 0) == False{} : Bool}:
  %Equal.sym(Bool, U32.is_eq(size, 0), Nat.is_eq(U32.to_nat(size), U32.to_nat(0)), A.u32_nat_eq(size, 0)) : {_ == False{} : Bool}
  %Equal.sym(Nat, U32.to_nat(size), 1n+k, exact) : {Nat.is_eq(_, U32.to_nat(0)) == False{} : Bool}
  {==}

def size_fits(+size: U32, +budget: U32, +k: Nat, exact: {U32.to_nat(size) == 1n+k : Nat}, fit: {Nat.is_le(1n+k, U32.to_nat(budget)) == True{} : Bool}) -> {(size <= budget : U32) == True{} : Bool}:
  %Equal.sym(Bool, U32.is_le(size, budget), Nat.is_le(U32.to_nat(size), U32.to_nat(budget)), A.u32_nat_le(size, budget)) : {_ == True{} : Bool}
  %Equal.sym(Nat, U32.to_nat(size), 1n+k, exact) : {Nat.is_le(_, U32.to_nat(budget)) == True{} : Bool}
  fit

# The encoder's chunk returns the decoder to the next size line, its payload
# accumulated and its size charged to the budget.
law chunk_step:
  for +c: U32
  for +tail: List<&2, U32>
  for +more: List<&2, U32>
  for +budget: U32
  for +acc: List<&2, U32>
  for oct: {C.octets(c <> tail) == True{} : Bool}
  for fit: {Nat.is_le(List.length(&2, U32, c <> tail), U32.to_nat(budget)) == True{} : Bool}
  {C.feed(B.append(C.hex_go(8n, U32.from_nat(List.length(&2, U32, c <> tail)), []), 13 <> 10 <> c <> B.append(tail, 13 <> 10 <> more)), C.Size{budget, acc, [], 0, False{}}) == C.feed(more, C.Size{(budget - U32.from_nat(List.length(&2, U32, c <> tail)) : U32), List.reverse.go(&2, U32, c <> tail, acc), [], 0, False{}}) : C.State & C.DecodeResult}

def chunk_step(c, tail, more, budget, acc, oct, fit):
  +fit = fit
  +size = U32.from_nat(List.length(&2, U32, c <> tail))
  +k = List.length(&2, U32, tail)
  +exact = A.from_nat_exact(1n+k, budget, fit)
  +nz = size_nonzero(size, k, exact)
  +ds = P.hex_digits(8n, size, [])
  +x = {c <> B.append(tail, 13 <> 10 <> more) : List<&2, U32>}
  -goal = C.feed(more, C.Size{(budget - size : U32), List.reverse.go(&2, U32, c <> tail, acc), [], 0, False{}})
  %Equal.sym(List<&2, U32>, C.hex_go(8n, size, P.hex_bytes([])), P.hex_bytes(ds), P.hex_go_digits(8n, size, [])) : {C.feed(B.append(_, 13 <> 10 <> x), C.Size{budget, acc, [], 0, False{}}) == goal : C.State & C.DecodeResult}
  %Equal.sym(C.State & C.DecodeResult, C.feed(B.append(P.hex_bytes(ds), 13 <> 10 <> x), C.Size{budget, acc, [], 0, False{}}), C.feed(x, C.start_chunk(budget, acc, C.size_digits(P.hex_bytes(ds), 0, False{}))), size_header(ds, budget, acc, x, hex_digits_length(8n, size, []))) : {_ == goal : C.State & C.DecodeResult}
  %Equal.sym(Maybe<&2, U32>, C.size_digits(P.hex_bytes(ds), 0, False{}), Some{size}, size_parse(size, nz)) : {C.feed(x, C.start_chunk(budget, acc, _)) == goal : C.State & C.DecodeResult}
  %Equal.sym(C.State, C.start_chunk(budget, acc, Some{size}), C.Payload{(budget - size : U32), acc, size}, start_payload(budget, acc, size, nz, size_fits(size, budget, k, exact, fit))) : {C.feed(x, _) == goal : C.State & C.DecodeResult}
  scan_payload(tail, c, (budget - size : U32), acc, size, more, oct, exact)

# Induction over producer chunks.

def done_pair(+rev: List<&2, U32>, +suffix: List<&2, U32>) -> C.State & C.DecodeResult:
  (C.Complete{List.reverse(&2, U32, rev), []}, C.Decoded{List.reverse(&2, U32, rev), [], suffix})

def rest_fit(+k: Nat, +lr: Nat, +total: Nat, +left: Nat, sum: {Nat.add(k, left) == total : Nat}, fit: {Nat.is_le(Nat.add(k, lr), total) == True{} : Bool}) -> {Nat.is_le(lr, left) == True{} : Bool}:
  %A.cmp_add_cancel(k, lr, left) : {Cmp.is_le(_) == True{} : Bool}
  %Equal.sym(Nat, Nat.add(k, left), total, sum) : {Nat.is_le(Nat.add(k, lr), _) == True{} : Bool}
  fit

# Bytes.append no longer unfolds on a cons (BND-84); these restore the step.
def append_cons(+h: U32, +t: List<&2, U32>, +ys: List<&2, U32>) -> {B.append(h <> t, ys) == h <> B.append(t, ys) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, B.append(h <> t, ys), List.append(&2, U32, h <> t, ys), h <> B.append(t, ys), BT.append_equiv(h <> t, ys), Equal.cong(List<&2, U32>, List<&2, U32>, l => h <> l, List.append(&2, U32, t, ys), B.append(t, ys), Equal.sym(List<&2, U32>, B.append(t, ys), List.append(&2, U32, t, ys), BT.append_equiv(t, ys))))

def append_cons2(+a: U32, +b: U32, +t: List<&2, U32>, +ys: List<&2, U32>) -> {B.append(a <> b <> t, ys) == a <> b <> B.append(t, ys) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, B.append(a <> b <> t, ys), List.append(&2, U32, a <> b <> t, ys), a <> b <> B.append(t, ys), BT.append_equiv(a <> b <> t, ys), Equal.cong(List<&2, U32>, List<&2, U32>, l => a <> b <> l, List.append(&2, U32, t, ys), B.append(t, ys), Equal.sym(List<&2, U32>, B.append(t, ys), List.append(&2, U32, t, ys), BT.append_equiv(t, ys))))

def total_fit(+body: List<&2, U32>, +rc: List<&2, U32>, +budget: U32, fit: {Nat.is_le(List.length(&2, U32, List.append(&2, U32, body, rc)), U32.to_nat(budget)) == True{} : Bool}) ->
    {Nat.is_le(Nat.add(List.length(&2, U32, body), List.length(&2, U32, rc)), U32.to_nat(budget)) == True{} : Bool}:
  %length_append_list(body, rc) : {Nat.is_le(_, U32.to_nat(budget)) == True{} : Bool}
  fit

law roundtrip_from:
  for +chunks: List<&2, List<&2, U32>>
  for +budget: U32
  for +acc: List<&2, U32>
  for +suffix: List<&2, U32>
  for oct: {C.octets(List.concat(&2, U32, chunks)) == True{} : Bool}
  for fit: {Nat.is_le(List.length(&2, U32, List.concat(&2, U32, chunks)), U32.to_nat(budget)) == True{} : Bool}
  {C.feed(B.append(C.encode(chunks), suffix), C.Size{budget, acc, [], 0, False{}}) == done_pair(List.reverse.go(&2, U32, List.concat(&2, U32, chunks), acc), suffix) : C.State & C.DecodeResult}

def roundtrip_from(chunks, budget, acc, suffix, oct, fit):
  match chunks:
    case Nil{}:
      P.scan_terminal(budget, acc, suffix)
    case Nil{} <> rest:
      roundtrip_from(rest, budget, acc, suffix, oct, fit)
    case (+c <> +tail) <> +rest:
      +body = {c <> tail : List<&2, U32>}
      +rc = List.concat(&2, U32, rest)
      +e = C.encode(rest)
      +size = U32.from_nat(List.length(&2, U32, body))
      +k = List.length(&2, U32, tail)
      +lr = List.length(&2, U32, rc)
      +both = Equal.trans(Bool, C.octets(body) && C.octets(rc), C.octets(List.append(&2, U32, body, rc)), True{}, Equal.sym(Bool, C.octets(List.append(&2, U32, body, rc)), C.octets(body) && C.octets(rc), P.octets_append_list(body, rc)), oct)
      +total = total_fit(body, rc, budget, fit)
      +fitc = A.le_add_r(1n+k, lr, U32.to_nat(budget), total)
      +exact = A.from_nat_exact(1n+k, budget, fitc)
      sub = A.u32_sub_nat(budget, size, size_fits(size, budget, k, exact, fitc))
      sum = Equal.trans(Nat, Nat.add(1n+k, U32.to_nat((budget - size : U32))), Nat.add(U32.to_nat(size), U32.to_nat((budget - size : U32))), U32.to_nat(budget),
        Equal.cong(Nat, Nat, x => Nat.add(x, U32.to_nat((budget - size : U32))), 1n+k, U32.to_nat(size), Equal.sym(Nat, U32.to_nat(size), 1n+k, exact)), sub)
      fitr = rest_fit(1n+k, lr, U32.to_nat(budget), U32.to_nat((budget - size : U32)), sum, total)
      +h = C.hex_go(8n, size, [])
      -goal = done_pair(List.reverse.go(&2, U32, List.append(&2, U32, body, rc), acc), suffix)
      %Equal.sym(List<&2, U32>, B.append(B.append(h, 13 <> 10 <> B.append(body, 13 <> 10 <> e)), suffix), B.append(h, B.append(13 <> 10 <> B.append(body, 13 <> 10 <> e), suffix)), append_assoc(h, 13 <> 10 <> B.append(body, 13 <> 10 <> e), suffix)) : {C.feed(_, C.Size{budget, acc, [], 0, False{}}) == goal : C.State & C.DecodeResult}
      %Equal.sym(List<&2, U32>, B.append(13 <> 10 <> B.append(body, 13 <> 10 <> e), suffix), 13 <> 10 <> c <> B.append(B.append(tail, 13 <> 10 <> e), suffix), Equal.trans(List<&2, U32>, B.append(13 <> 10 <> B.append(body, 13 <> 10 <> e), suffix), 13 <> 10 <> B.append(B.append(body, 13 <> 10 <> e), suffix), 13 <> 10 <> c <> B.append(B.append(tail, 13 <> 10 <> e), suffix), append_cons2(13, 10, B.append(body, 13 <> 10 <> e), suffix), Equal.trans(List<&2, U32>, 13 <> 10 <> B.append(B.append(body, 13 <> 10 <> e), suffix), 13 <> 10 <> B.append(c <> B.append(tail, 13 <> 10 <> e), suffix), 13 <> 10 <> c <> B.append(B.append(tail, 13 <> 10 <> e), suffix), Equal.cong(List<&2, U32>, List<&2, U32>, l => 13 <> 10 <> B.append(l, suffix), B.append(body, 13 <> 10 <> e), c <> B.append(tail, 13 <> 10 <> e), append_cons(c, tail, 13 <> 10 <> e)), Equal.cong(List<&2, U32>, List<&2, U32>, l => 13 <> 10 <> l, B.append(c <> B.append(tail, 13 <> 10 <> e), suffix), c <> B.append(B.append(tail, 13 <> 10 <> e), suffix), append_cons(c, B.append(tail, 13 <> 10 <> e), suffix))))) : {C.feed(B.append(h, _), C.Size{budget, acc, [], 0, False{}}) == goal : C.State & C.DecodeResult}
      %Equal.sym(List<&2, U32>, B.append(B.append(tail, 13 <> 10 <> e), suffix), B.append(tail, B.append(13 <> 10 <> e, suffix)), append_assoc(tail, 13 <> 10 <> e, suffix)) : {C.feed(B.append(h, 13 <> 10 <> c <> _), C.Size{budget, acc, [], 0, False{}}) == goal : C.State & C.DecodeResult}
      %Equal.sym(List<&2, U32>, B.append(13 <> 10 <> e, suffix), 13 <> 10 <> B.append(e, suffix), append_cons2(13, 10, e, suffix)) : {C.feed(B.append(h, 13 <> 10 <> c <> B.append(tail, _)), C.Size{budget, acc, [], 0, False{}}) == goal : C.State & C.DecodeResult}
      Equal.trans(C.State & C.DecodeResult,
        C.feed(B.append(h, 13 <> 10 <> c <> B.append(tail, 13 <> 10 <> B.append(e, suffix))), C.Size{budget, acc, [], 0, False{}}),
        C.feed(B.append(e, suffix), C.Size{(budget - size : U32), List.reverse.go(&2, U32, body, acc), [], 0, False{}}),
        goal,
        chunk_step(c, tail, B.append(e, suffix), budget, acc, P.both_left(C.octets(body), C.octets(rc), both), fitc),
        Equal.trans(C.State & C.DecodeResult,
          C.feed(B.append(e, suffix), C.Size{(budget - size : U32), List.reverse.go(&2, U32, body, acc), [], 0, False{}}),
          done_pair(List.reverse.go(&2, U32, rc, List.reverse.go(&2, U32, body, acc)), suffix),
          goal,
          roundtrip_from(rest, (budget - size : U32), List.reverse.go(&2, U32, body, acc), suffix, P.both_right(C.octets(body), C.octets(rc), both), fitr),
          Equal.cong(List<&2, U32>, C.State & C.DecodeResult, x => done_pair(x, suffix), List.reverse.go(&2, U32, rc, List.reverse.go(&2, U32, body, acc)), List.reverse.go(&2, U32, List.append(&2, U32, body, rc), acc), Equal.sym(List<&2, U32>, List.reverse.go(&2, U32, List.append(&2, U32, body, rc), acc), List.reverse.go(&2, U32, rc, List.reverse.go(&2, U32, body, acc)), reverse_go_append_list(body, rc, acc)))))

# The BND-8 round trip, for every admissible producer chunking and suffix.
law roundtrip:
  for +chunks: List<&2, List<&2, U32>>
  for +limit: U32
  for +suffix: List<&2, U32>
  for valid: {C.admissible(chunks, limit) == True{} : Bool}
  {C.decode(B.append(C.encode(chunks), suffix), limit) == C.Decoded{List.concat(&2, U32, chunks), [], suffix} : C.DecodeResult}

def roundtrip(chunks, limit, suffix, valid):
  +valid = valid
  +body = List.concat(&2, U32, chunks)
  +fit = Nat.is_le(List.length(&2, U32, body), U32.to_nat(limit))
  run = roundtrip_from(chunks, limit, [], suffix, P.both_left(C.octets(body), fit, valid), P.both_right(C.octets(body), fit, valid))
  Equal.trans(C.DecodeResult,
    C.decode(B.append(C.encode(chunks), suffix), limit),
    C.Decoded{List.reverse(&2, U32, List.reverse(&2, U32, body)), [], suffix},
    C.Decoded{body, [], suffix},
    Equal.cong(C.State & C.DecodeResult, C.DecodeResult, pair => C.result(pair), C.feed(B.append(C.encode(chunks), suffix), C.initial(limit)), done_pair(List.reverse(&2, U32, body), suffix), run),
    Equal.cong(List<&2, U32>, C.DecodeResult, x => C.Decoded{x, [], suffix}, List.reverse(&2, U32, List.reverse(&2, U32, body)), body, reverse_reverse(body)))
