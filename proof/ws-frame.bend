# Proofs of the BND-51 frame laws. Does not import LAWS.bend.
import Base
import ./ws-frame-laws.bend as L
import ./ws-frame-spec.bend as S
import ./utf8.bend as UP
import ./chunked-arith.bend as A
import ./crypto-octets.bend as OP
import ../src/ws/frame.bend as F

# Lists.

def length_append(+xs: List<&2, U32>, +ys: List<&2, U32>) -> {List.length(&2, U32, List.append(&2, U32, xs, ys)) == Nat.add(List.length(&2, U32, xs), List.length(&2, U32, ys)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      Equal.cong(Nat, Nat, n => 1n+n, List.length(&2, U32, List.append(&2, U32, t, ys)), Nat.add(List.length(&2, U32, t), List.length(&2, U32, ys)), length_append(t, ys))

def reverse_twice(+ys: List<&2, U32>, +acc: List<&2, U32>, +tail: List<&2, U32>) -> {List.reverse.go(&2, U32, List.reverse.go(&2, U32, ys, acc), tail) == List.reverse.go(&2, U32, acc, List.append(&2, U32, ys, tail)) : List<&2, U32>}:
  match ys:
    case Nil{}:
      {==}
    case h <> t:
      reverse_twice(t, h <> acc, tail)

def reverse_reverse(+ys: List<&2, U32>) -> {List.reverse(&2, U32, List.reverse(&2, U32, ys)) == ys : List<&2, U32>}:
  Equal.trans(List<&2, U32>, List.reverse(&2, U32, List.reverse(&2, U32, ys)), List.append(&2, U32, ys, []), ys, reverse_twice(ys, [], []), UP.append_nil(U32, ys))

def count_length(+xs: List<&2, U32>, +n: Nat) -> {F.count(xs, n) == Nat.add(List.length(&2, U32, xs), n) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      Equal.trans(Nat, F.count(t, 1n+n), Nat.add(List.length(&2, U32, t), 1n+n), 1n+Nat.add(List.length(&2, U32, t), n), count_length(t, 1n+n), A.add_succ_r(List.length(&2, U32, t), n))

def length_eq(+xs: List<&2, U32>) -> {F.length(xs) == List.length(&2, U32, xs) : Nat}:
  Equal.trans(Nat, F.count(xs, 0n), Nat.add(List.length(&2, U32, xs), 0n), List.length(&2, U32, xs), count_length(xs, 0n), A.add_zero_r(List.length(&2, U32, xs)))

# Masking.

def bool_xor_twice(+a: Bool, +b: Bool) -> {Bool.xor(Bool.xor(a, b), b) == a : Bool}:
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def word_xor_twice(+n: Nat, +x: Word(n), +k: Word(n)) -> {Word.xor(n, Word.xor(n, x, k), k) == x : Word(n)}:
  match n:
    case 0n:
      match x k:
        case WNil{} WNil{}:
          {==}
    case 1n+p:
      match x k:
        case WCon{a, xt} WCon{b, kt}:
          %Equal.sym(Word(p), Word.xor(p, Word.xor(p, xt, kt), kt), xt, word_xor_twice(p, xt, kt)) : {WCon{Bool.xor(Bool.xor(a, b), b), _} == WCon{a, xt} : Word(1n+p)}
          %Equal.sym(Bool, Bool.xor(Bool.xor(a, b), b), a, bool_xor_twice(a, b)) : {WCon{_, xt} == WCon{a, xt} : Word(1n+p)}
          {==}

def xor_twice(+x: U32, +k: U32) -> {U32.xor(U32.xor(x, k), k) == x : U32}:
  match x k:
    case U32{xw} U32{kw}:
      Equal.cong(Word(32n), U32, w => U32{w}, Word.xor(32n, Word.xor(32n, xw, kw), kw), xw, word_xor_twice(32n, xw, kw))

def mask_go_spec(+xs: List<&2, U32>, +a: U32, +b: U32, +c: U32, +d: U32, +acc: List<&2, U32>) -> {F.mask_go(xs, a, b, c, d, acc) == List.reverse.go(&2, U32, S.mask(xs, F.MaskKey{a, b, c, d}), acc) : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      mask_go_spec(t, b, c, d, a, U32.xor(x, a) <> acc)

def L.ws_mask_spec(k, xs):
  match k:
    case F.MaskKey{a, b, c, d}:
      Equal.trans(List<&2, U32>, List.reverse(&2, U32, F.mask_go(xs, a, b, c, d, [])), List.reverse(&2, U32, List.reverse(&2, U32, S.mask(xs, F.MaskKey{a, b, c, d}))), S.mask(xs, F.MaskKey{a, b, c, d}), Equal.cong(List<&2, U32>, List<&2, U32>, m => List.reverse(&2, U32, m), F.mask_go(xs, a, b, c, d, []), List.reverse(&2, U32, S.mask(xs, F.MaskKey{a, b, c, d})), mask_go_spec(xs, a, b, c, d, [])), reverse_reverse(S.mask(xs, F.MaskKey{a, b, c, d})))

def spec_twice(+xs: List<&2, U32>, +k: F.Key) -> {S.mask(S.mask(xs, k), k) == xs : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      match k:
        case F.MaskKey{a, b, c, d}:
          %Equal.sym(List<&2, U32>, S.mask(S.mask(t, F.MaskKey{b, c, d, a}), F.MaskKey{b, c, d, a}), t, spec_twice(t, F.MaskKey{b, c, d, a})) : {U32.xor(U32.xor(x, a), a) <> _ == x <> t : List<&2, U32>}
          %Equal.sym(U32, U32.xor(U32.xor(x, a), a), x, xor_twice(x, a)) : {_ <> t == x <> t : List<&2, U32>}
          {==}

def L.ws_mask_involution(k, xs):
  %Equal.sym(List<&2, U32>, F.mask(k, F.mask(k, xs)), S.mask(F.mask(k, xs), k), L.ws_mask_spec(k, F.mask(k, xs))) : {_ == xs : List<&2, U32>}
  %Equal.sym(List<&2, U32>, F.mask(k, xs), S.mask(xs, k), L.ws_mask_spec(k, xs)) : {S.mask(_, k) == xs : List<&2, U32>}
  spec_twice(xs, k)

def spec_length(+xs: List<&2, U32>, +k: F.Key) -> {List.length(&2, U32, S.mask(xs, k)) == List.length(&2, U32, xs) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case x <> t:
      match k:
        case F.MaskKey{a, b, c, d}:
          Equal.cong(Nat, Nat, n => 1n+n, List.length(&2, U32, S.mask(t, F.MaskKey{b, c, d, a})), List.length(&2, U32, t), spec_length(t, F.MaskKey{b, c, d, a}))

def mask_length(+k: F.Key, +xs: List<&2, U32>) -> {List.length(&2, U32, F.mask(k, xs)) == List.length(&2, U32, xs) : Nat}:
  %Equal.sym(List<&2, U32>, F.mask(k, xs), S.mask(xs, k), L.ws_mask_spec(k, xs)) : {List.length(&2, U32, _) == List.length(&2, U32, xs) : Nat}
  spec_length(xs, k)

# Sizes.

def length_bytes_size(+m: Bool, +w: Word(32n), +s: Bool, +md: Bool) -> {List.length(&2, U32, F.length_bytes(m, w, s, md)) == 1n+S.extra_of(s, md) : Nat}:
  match s md:
    case True{} _:
      {==}
    case False{} True{}:
      {==}
    case False{} False{}:
      {==}

def header_size(+k: Maybe<&2, F.Key>, +u: U32) -> {List.length(&2, U32, F.header_with(k, u)) == 1n+S.extra_of(U32.is_le(u, 125), U32.is_le(u, 65535)) : Nat}:
  match u:
    case U32{w}:
      length_bytes_size(F.is_masked(k), w, U32.is_le(U32{w}, 125), U32.is_le(U32{w}, 65535))

def body_size(+k: Maybe<&2, F.Key>, +p: List<&2, U32>) -> {List.length(&2, U32, F.body_bytes(k, p)) == Nat.add(S.key_size(F.is_masked(k)), List.length(&2, U32, p)) : Nat}:
  match k:
    case None{}:
      {==}
    case Some{F.MaskKey{a, b, c, d}}:
      Equal.cong(Nat, Nat, n => 4n+n, List.length(&2, U32, F.mask(F.MaskKey{a, b, c, d}, p)), List.length(&2, U32, p), mask_length(F.MaskKey{a, b, c, d}, p))

# Below a U32 cap, comparing the converted length as a U32 is comparing the
# length itself.
def bridge(+n: Nat, +max: U32, +fits: {Nat.is_le(n, U32.to_nat(max)) == True{} : Bool}, +c: U32) -> {U32.is_le(U32.from_nat(n), c) == Nat.is_le(n, U32.to_nat(c)) : Bool}:
  Equal.trans(Bool, U32.is_le(U32.from_nat(n), c), Nat.is_le(U32.to_nat(U32.from_nat(n)), U32.to_nat(c)), Nat.is_le(n, U32.to_nat(c)), A.u32_nat_le(U32.from_nat(n), c), Equal.cong(Nat, Bool, x => Nat.is_le(x, U32.to_nat(c)), U32.to_nat(U32.from_nat(n)), n, A.from_nat_exact(n, max, fits)))

def size_raw(+fin: Bool, +op: F.Opcode, +payload: List<&2, U32>, +k: Maybe<&2, F.Key>) -> {List.length(&2, U32, F.encode_raw(F.Frame{fin, op, payload}, k)) == Nat.add(2n, Nat.add(S.extra_of(U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 125), U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 65535)), Nat.add(S.key_size(F.is_masked(k)), List.length(&2, U32, payload)))) : Nat}:
  %Equal.sym(Nat, List.length(&2, U32, List.append(&2, U32, F.header_with(k, U32.from_nat(F.length(payload))), F.body_bytes(k, payload))), Nat.add(List.length(&2, U32, F.header_with(k, U32.from_nat(F.length(payload)))), List.length(&2, U32, F.body_bytes(k, payload))), length_append(F.header_with(k, U32.from_nat(F.length(payload))), F.body_bytes(k, payload))) : {1n+_ == Nat.add(2n, Nat.add(S.extra_of(U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 125), U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 65535)), Nat.add(S.key_size(F.is_masked(k)), List.length(&2, U32, payload)))) : Nat}
  %Equal.sym(Nat, List.length(&2, U32, F.header_with(k, U32.from_nat(F.length(payload)))), 1n+S.extra_of(U32.is_le(U32.from_nat(F.length(payload)), 125), U32.is_le(U32.from_nat(F.length(payload)), 65535)), header_size(k, U32.from_nat(F.length(payload)))) : {1n+Nat.add(_, List.length(&2, U32, F.body_bytes(k, payload))) == Nat.add(2n, Nat.add(S.extra_of(U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 125), U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 65535)), Nat.add(S.key_size(F.is_masked(k)), List.length(&2, U32, payload)))) : Nat}
  %Equal.sym(Nat, List.length(&2, U32, F.body_bytes(k, payload)), Nat.add(S.key_size(F.is_masked(k)), List.length(&2, U32, payload)), body_size(k, payload)) : {1n+Nat.add(1n+S.extra_of(U32.is_le(U32.from_nat(F.length(payload)), 125), U32.is_le(U32.from_nat(F.length(payload)), 65535)), _) == Nat.add(2n, Nat.add(S.extra_of(U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 125), U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 65535)), Nat.add(S.key_size(F.is_masked(k)), List.length(&2, U32, payload)))) : Nat}
  %Equal.sym(Nat, F.length(payload), List.length(&2, U32, payload), length_eq(payload)) : {1n+Nat.add(1n+S.extra_of(U32.is_le(U32.from_nat(_), 125), U32.is_le(U32.from_nat(_), 65535)), Nat.add(S.key_size(F.is_masked(k)), List.length(&2, U32, payload))) == Nat.add(2n, Nat.add(S.extra_of(U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 125), U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 65535)), Nat.add(S.key_size(F.is_masked(k)), List.length(&2, U32, payload)))) : Nat}
  {==}

def L.ws_encode_minimal(max, fin, op, payload, k, fits):
  Equal.trans(Nat, List.length(&2, U32, F.encode_raw(F.Frame{fin, op, payload}, k)), Nat.add(2n, Nat.add(S.extra_of(U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 125), U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 65535)), Nat.add(S.key_size(F.is_masked(k)), List.length(&2, U32, payload)))), Nat.add(2n, Nat.add(S.extra_of(Nat.is_le(List.length(&2, U32, payload), 125n), U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 65535)), Nat.add(S.key_size(F.is_masked(k)), List.length(&2, U32, payload)))), size_raw(fin, op, payload, k), Equal.cong(Bool, Nat, x => Nat.add(2n, Nat.add(S.extra_of(x, U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 65535)), Nat.add(S.key_size(F.is_masked(k)), List.length(&2, U32, payload)))), U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 125), Nat.is_le(List.length(&2, U32, payload), 125n), bridge(List.length(&2, U32, payload), max, fits, 125)))

def L.ws_length_threshold_exact(n, max, fits):
  bridge(n, max, fits, 65535)

def L.ws_length_exact(n, max, fits):
  A.from_nat_exact(n, max, fits)

# Validity.

def octets_acc(+xs: List<&2, U32>, +ok: Bool) -> {F.octets(xs, ok) == ok && S.octets(xs) : Bool}:
  match xs:
    case Nil{}:
      Equal.sym(Bool, ok && True{}, ok, OP.and_true(ok))
    case x <> t:
      Equal.trans(Bool, F.octets(t, ok && F.is_octet(x)), (ok && F.is_octet(x)) && S.octets(t), ok && (F.is_octet(x) && S.octets(t)), octets_acc(t, ok && F.is_octet(x)), OP.and_assoc(ok, F.is_octet(x), S.octets(t)))

def control_same(+op: F.Opcode, +fin: Bool, +n: Nat) -> {F.control_ok(F.is_control(op), fin, n) == S.control_valid(op, fin, n) : Bool}:
  match op:
    case F.OpContinue{}:
      {==}
    case F.OpText{}:
      {==}
    case F.OpBinary{}:
      {==}
    case F.OpClose{}:
      {==}
    case F.OpPing{}:
      {==}
    case F.OpPong{}:
      {==}

def key_same(+k: Maybe<&2, F.Key>) -> {F.key_ok(k) == S.key_valid(k) : Bool}:
  match k:
    case None{}:
      {==}
    case Some{F.MaskKey{a, b, c, d}}:
      {==}

def L.ws_encode_valid(max, f, k):
  match f:
    case F.Frame{fin, op, payload}:
      %Equal.sym(Nat, F.length(payload), List.length(&2, U32, payload), length_eq(payload)) : {F.control_ok(F.is_control(op), fin, _) && Nat.is_le(_, U32.to_nat(max)) && F.key_ok(k) && F.octets(payload, True{}) == S.valid(max, F.Frame{fin, op, payload}, k) : Bool}
      %Equal.sym(Bool, F.octets(payload, True{}), S.octets(payload), octets_acc(payload, True{})) : {F.control_ok(F.is_control(op), fin, List.length(&2, U32, payload)) && Nat.is_le(List.length(&2, U32, payload), U32.to_nat(max)) && F.key_ok(k) && _ == S.valid(max, F.Frame{fin, op, payload}, k) : Bool}
      %Equal.sym(Bool, F.control_ok(F.is_control(op), fin, List.length(&2, U32, payload)), S.control_valid(op, fin, List.length(&2, U32, payload)), control_same(op, fin, List.length(&2, U32, payload))) : {_ && Nat.is_le(List.length(&2, U32, payload), U32.to_nat(max)) && F.key_ok(k) && S.octets(payload) == S.valid(max, F.Frame{fin, op, payload}, k) : Bool}
      %Equal.sym(Bool, F.key_ok(k), S.key_valid(k), key_same(k)) : {S.control_valid(op, fin, List.length(&2, U32, payload)) && Nat.is_le(List.length(&2, U32, payload), U32.to_nat(max)) && _ && S.octets(payload) == S.valid(max, F.Frame{fin, op, payload}, k) : Bool}
      {==}

# The encoder.

def L.ws_encode_accepts(max, f, k, ok):
  %Equal.sym(Bool, F.valid(max, f, k), S.valid(max, f, k), L.ws_encode_valid(max, f, k)) : {F.encode_if(_, f, k) == Some{F.encode_raw(f, k)} : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Bool, S.valid(max, f, k), True{}, ok) : {F.encode_if(_, f, k) == Some{F.encode_raw(f, k)} : Maybe<&2, List<&2, U32>>}
  {==}

def L.ws_encode_refuses(max, f, k, bad):
  %Equal.sym(Bool, F.valid(max, f, k), S.valid(max, f, k), L.ws_encode_valid(max, f, k)) : {F.encode_if(_, f, k) == None{} : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Bool, S.valid(max, f, k), False{}, bad) : {F.encode_if(_, f, k) == None{} : Maybe<&2, List<&2, U32>>}
  {==}

# Header bytes, against the spec's shifts and masks.

def first_eq(+fin: Bool, +op: F.Opcode) -> {F.first_byte(fin, op) == U32.or(U32.shln(Bool.to_u32(fin), 7n), S.opcode_value(op)) : U32}:
  match fin op:
    case False{} F.OpContinue{}:
      {==}
    case False{} F.OpText{}:
      {==}
    case False{} F.OpBinary{}:
      {==}
    case False{} F.OpClose{}:
      {==}
    case False{} F.OpPing{}:
      {==}
    case False{} F.OpPong{}:
      {==}
    case True{} F.OpContinue{}:
      {==}
    case True{} F.OpText{}:
      {==}
    case True{} F.OpBinary{}:
      {==}
    case True{} F.OpClose{}:
      {==}
    case True{} F.OpPing{}:
      {==}
    case True{} F.OpPong{}:
      {==}

def short_m(+m: Bool, +l0: Bool, +l1: Bool, +l2: Bool, +l3: Bool, +l4: Bool, +l5: Bool, +l6: Bool) -> {[F.second_byte(WCon{l0, WCon{l1, WCon{l2, WCon{l3, WCon{l4, WCon{l5, WCon{l6, WNil{}}}}}}}}, m)] == [U32.or(U32.shln(Bool.to_u32(m), 7n), U32{WCon{l0, WCon{l1, WCon{l2, WCon{l3, WCon{l4, WCon{l5, WCon{l6, Word.zero(25n)}}}}}}}})] : List<&2, U32>}:
  match m:
    case False{}:
      {==}
    case True{}:
      {==}

def short_bits(+m: Bool, +l0: Bool, +l1: Bool, +l2: Bool, +l3: Bool, +l4: Bool, +l5: Bool, +l6: Bool, +hi: Word(25n), hz: {hi == Word.zero(25n) : Word(25n)}) -> {[F.second_byte(WCon{l0, WCon{l1, WCon{l2, WCon{l3, WCon{l4, WCon{l5, WCon{l6, WNil{}}}}}}}}, m)] == [U32.or(U32.shln(Bool.to_u32(m), 7n), U32{WCon{l0, WCon{l1, WCon{l2, WCon{l3, WCon{l4, WCon{l5, WCon{l6, hi}}}}}}}})] : List<&2, U32>}:
  %Equal.sym(Word(25n), hi, Word.zero(25n), hz) : {[F.second_byte(WCon{l0, WCon{l1, WCon{l2, WCon{l3, WCon{l4, WCon{l5, WCon{l6, WNil{}}}}}}}}, m)] == [U32.or(U32.shln(Bool.to_u32(m), 7n), U32{WCon{l0, WCon{l1, WCon{l2, WCon{l3, WCon{l4, WCon{l5, WCon{l6, _}}}}}}}})] : List<&2, U32>}
  short_m(m, l0, l1, l2, l3, l4, l5, l6)

def medium_bytes(+m: Bool, +w: Word(32n)) -> {F.length_bytes(m, w, False{}, True{}) == S.length_field(U32.shln(Bool.to_u32(m), 7n), U32{w}, False{}, True{}) : List<&2, U32>}:
  match m:
    case False{}:
      match w:
        case WCon{n0, WCon{n1, WCon{n2, WCon{n3, WCon{n4, WCon{n5, WCon{n6, WCon{n7, WCon{n8, WCon{n9, WCon{n10, WCon{n11, WCon{n12, WCon{n13, WCon{n14, WCon{n15, WCon{n16, WCon{n17, WCon{n18, WCon{n19, WCon{n20, WCon{n21, WCon{n22, WCon{n23, WCon{n24, WCon{n25, WCon{n26, WCon{n27, WCon{n28, WCon{n29, WCon{n30, WCon{n31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
          {==}
    case True{}:
      match w:
        case WCon{n0, WCon{n1, WCon{n2, WCon{n3, WCon{n4, WCon{n5, WCon{n6, WCon{n7, WCon{n8, WCon{n9, WCon{n10, WCon{n11, WCon{n12, WCon{n13, WCon{n14, WCon{n15, WCon{n16, WCon{n17, WCon{n18, WCon{n19, WCon{n20, WCon{n21, WCon{n22, WCon{n23, WCon{n24, WCon{n25, WCon{n26, WCon{n27, WCon{n28, WCon{n29, WCon{n30, WCon{n31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
          {==}

def long_bytes(+m: Bool, +w: Word(32n)) -> {F.length_bytes(m, w, False{}, False{}) == S.length_field(U32.shln(Bool.to_u32(m), 7n), U32{w}, False{}, False{}) : List<&2, U32>}:
  match m:
    case False{}:
      match w:
        case WCon{n0, WCon{n1, WCon{n2, WCon{n3, WCon{n4, WCon{n5, WCon{n6, WCon{n7, WCon{n8, WCon{n9, WCon{n10, WCon{n11, WCon{n12, WCon{n13, WCon{n14, WCon{n15, WCon{n16, WCon{n17, WCon{n18, WCon{n19, WCon{n20, WCon{n21, WCon{n22, WCon{n23, WCon{n24, WCon{n25, WCon{n26, WCon{n27, WCon{n28, WCon{n29, WCon{n30, WCon{n31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
          {==}
    case True{}:
      match w:
        case WCon{n0, WCon{n1, WCon{n2, WCon{n3, WCon{n4, WCon{n5, WCon{n6, WCon{n7, WCon{n8, WCon{n9, WCon{n10, WCon{n11, WCon{n12, WCon{n13, WCon{n14, WCon{n15, WCon{n16, WCon{n17, WCon{n18, WCon{n19, WCon{n20, WCon{n21, WCon{n22, WCon{n23, WCon{n24, WCon{n25, WCon{n26, WCon{n27, WCon{n28, WCon{n29, WCon{n30, WCon{n31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
          {==}

def short_lb(+m: Bool, +w: Word(32n), es: {U32.is_le(U32{w}, 125) == True{} : Bool}, md: Bool) -> {F.length_bytes(m, w, True{}, md) == S.length_field(U32.shln(Bool.to_u32(m), 7n), U32{w}, True{}, md) : List<&2, U32>}:
  match w:
    case WCon{l0, WCon{l1, WCon{l2, WCon{l3, WCon{l4, WCon{l5, WCon{l6, hi}}}}}}}:
      short_bits(m, l0, l1, l2, l3, l4, l5, l6, hi, UP.cmp_le_zero(25n, hi, UP.high_le(7n, 25n, WCon{l0, WCon{l1, WCon{l2, WCon{l3, WCon{l4, WCon{l5, WCon{l6, hi}}}}}}}, UP.bits(125), es)))

def lb_go(+m: Bool, +w: Word(32n), s: Bool, es: {U32.is_le(U32{w}, 125) == s : Bool}, md: Bool) -> {F.length_bytes(m, w, s, md) == S.length_field(U32.shln(Bool.to_u32(m), 7n), U32{w}, s, md) : List<&2, U32>}:
  match s:
    case True{}:
      short_lb(m, w, es, md)
    case False{}:
      match md:
        case True{}:
          medium_bytes(m, w)
        case False{}:
          long_bytes(m, w)

def hdr_eq(+k: Maybe<&2, F.Key>, +u: U32) -> {F.header_with(k, u) == S.length_field(U32.shln(Bool.to_u32(S.has_key(k)), 7n), u, U32.is_le(u, 125), U32.is_le(u, 65535)) : List<&2, U32>}:
  match k:
    case None{}:
      match u:
        case U32{w}:
          lb_go(False{}, w, U32.is_le(U32{w}, 125), {==}, U32.is_le(U32{w}, 65535))
    case Some{key}:
      match u:
        case U32{w}:
          lb_go(True{}, w, U32.is_le(U32{w}, 125), {==}, U32.is_le(U32{w}, 65535))

def body_eq(+k: Maybe<&2, F.Key>, +p: List<&2, U32>) -> {F.body_bytes(k, p) == List.append(&2, U32, S.key_bytes(k), S.payload_bytes(p, k)) : List<&2, U32>}:
  match k:
    case None{}:
      {==}
    case Some{F.MaskKey{+a, +b, +c, +d}}:
      Equal.cong(List<&2, U32>, List<&2, U32>, x => a <> b <> c <> d <> x, F.mask(F.MaskKey{a, b, c, d}, p), S.mask(p, F.MaskKey{a, b, c, d}), L.ws_mask_spec(F.MaskKey{a, b, c, d}, p))

def bytes_u(+fin: Bool, +op: F.Opcode, +payload: List<&2, U32>, +k: Maybe<&2, F.Key>, +u: U32) -> {F.first_byte(fin, op) <> List.append(&2, U32, F.header_with(k, u), F.body_bytes(k, payload)) == U32.or(U32.shln(Bool.to_u32(fin), 7n), S.opcode_value(op)) <> List.append(&2, U32, List.append(&2, U32, S.length_field(U32.shln(Bool.to_u32(S.has_key(k)), 7n), u, U32.is_le(u, 125), U32.is_le(u, 65535)), S.key_bytes(k)), S.payload_bytes(payload, k)) : List<&2, U32>}:
  %Equal.sym(List<&2, U32>, List.append(&2, U32, List.append(&2, U32, S.length_field(U32.shln(Bool.to_u32(S.has_key(k)), 7n), u, U32.is_le(u, 125), U32.is_le(u, 65535)), S.key_bytes(k)), S.payload_bytes(payload, k)), List.append(&2, U32, S.length_field(U32.shln(Bool.to_u32(S.has_key(k)), 7n), u, U32.is_le(u, 125), U32.is_le(u, 65535)), List.append(&2, U32, S.key_bytes(k), S.payload_bytes(payload, k))), UP.append_assoc(U32, S.length_field(U32.shln(Bool.to_u32(S.has_key(k)), 7n), u, U32.is_le(u, 125), U32.is_le(u, 65535)), S.key_bytes(k), S.payload_bytes(payload, k))) : {F.first_byte(fin, op) <> List.append(&2, U32, F.header_with(k, u), F.body_bytes(k, payload)) == U32.or(U32.shln(Bool.to_u32(fin), 7n), S.opcode_value(op)) <> _ : List<&2, U32>}
  %Equal.sym(U32, F.first_byte(fin, op), U32.or(U32.shln(Bool.to_u32(fin), 7n), S.opcode_value(op)), first_eq(fin, op)) : {_ <> List.append(&2, U32, F.header_with(k, u), F.body_bytes(k, payload)) == U32.or(U32.shln(Bool.to_u32(fin), 7n), S.opcode_value(op)) <> List.append(&2, U32, S.length_field(U32.shln(Bool.to_u32(S.has_key(k)), 7n), u, U32.is_le(u, 125), U32.is_le(u, 65535)), List.append(&2, U32, S.key_bytes(k), S.payload_bytes(payload, k))) : List<&2, U32>}
  %Equal.sym(List<&2, U32>, F.header_with(k, u), S.length_field(U32.shln(Bool.to_u32(S.has_key(k)), 7n), u, U32.is_le(u, 125), U32.is_le(u, 65535)), hdr_eq(k, u)) : {U32.or(U32.shln(Bool.to_u32(fin), 7n), S.opcode_value(op)) <> List.append(&2, U32, _, F.body_bytes(k, payload)) == U32.or(U32.shln(Bool.to_u32(fin), 7n), S.opcode_value(op)) <> List.append(&2, U32, S.length_field(U32.shln(Bool.to_u32(S.has_key(k)), 7n), u, U32.is_le(u, 125), U32.is_le(u, 65535)), List.append(&2, U32, S.key_bytes(k), S.payload_bytes(payload, k))) : List<&2, U32>}
  %Equal.sym(List<&2, U32>, F.body_bytes(k, payload), List.append(&2, U32, S.key_bytes(k), S.payload_bytes(payload, k)), body_eq(k, payload)) : {U32.or(U32.shln(Bool.to_u32(fin), 7n), S.opcode_value(op)) <> List.append(&2, U32, S.length_field(U32.shln(Bool.to_u32(S.has_key(k)), 7n), u, U32.is_le(u, 125), U32.is_le(u, 65535)), _) == U32.or(U32.shln(Bool.to_u32(fin), 7n), S.opcode_value(op)) <> List.append(&2, U32, S.length_field(U32.shln(Bool.to_u32(S.has_key(k)), 7n), u, U32.is_le(u, 125), U32.is_le(u, 65535)), List.append(&2, U32, S.key_bytes(k), S.payload_bytes(payload, k))) : List<&2, U32>}
  {==}

def L.ws_encode_bytes(max, fin, op, payload, k, fits):
  %bridge(List.length(&2, U32, payload), max, fits, 125) : {F.encode_raw(F.Frame{fin, op, payload}, k) == U32.or(U32.shln(Bool.to_u32(fin), 7n), S.opcode_value(op)) <> List.append(&2, U32, List.append(&2, U32, S.length_field(U32.shln(Bool.to_u32(S.has_key(k)), 7n), U32.from_nat(List.length(&2, U32, payload)), _, U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 65535)), S.key_bytes(k)), S.payload_bytes(payload, k)) : List<&2, U32>}
  %Equal.sym(Nat, F.length(payload), List.length(&2, U32, payload), length_eq(payload)) : {F.first_byte(fin, op) <> List.append(&2, U32, F.header_with(k, U32.from_nat(_)), F.body_bytes(k, payload)) == U32.or(U32.shln(Bool.to_u32(fin), 7n), S.opcode_value(op)) <> List.append(&2, U32, List.append(&2, U32, S.length_field(U32.shln(Bool.to_u32(S.has_key(k)), 7n), U32.from_nat(List.length(&2, U32, payload)), U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 125), U32.is_le(U32.from_nat(List.length(&2, U32, payload)), 65535)), S.key_bytes(k)), S.payload_bytes(payload, k)) : List<&2, U32>}
  bytes_u(fin, op, payload, k, U32.from_nat(List.length(&2, U32, payload)))

