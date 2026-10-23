# Compositional scanner lemmas for the incremental chunk decoder.
import Base
import ../src/http/chunked.bend as C
import ../src/http/bytes.bend as B
import ../src/http/request.bend as R
import ../src/router/codec-bits.bend as Bits

# Resume a feed result, retaining bytes already left after a terminal state.
def resume(+xs: List<&2, U32>, pair: C.State & C.DecodeResult) -> C.State & C.DecodeResult:
  match pair:
    case (s, C.NeedMore{}):
      C.feed(xs, s)
    case (s, C.Decoded{body, hs, rest}):
      (s, C.Decoded{body, hs, B.append(rest, xs)})
    case (s, C.Error{status}):
      (s, C.Error{status})

law terminal_suffix:
  for +body: List<&2, U32>
  for +hs: List<&2, R.Header>
  for +suffix: List<&2, U32>
  {C.feed(suffix, C.Complete{body, hs}) == (C.Complete{body, hs}, C.Decoded{body, hs, suffix}) : C.State & C.DecodeResult}

def terminal_suffix(body, hs, suffix):
  match suffix:
    case Nil{}:
      {==}
    case c <> t:
      {==}

law failed_suffix:
  for +status: U32
  for +suffix: List<&2, U32>
  {C.feed(suffix, C.Failed{status}) == (C.Failed{status}, C.Error{status}) : C.State & C.DecodeResult}

def failed_suffix(status, suffix):
  match suffix:
    case Nil{}:
      {==}
    case c <> t:
      {==}

law feed_append:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for +s: C.State
  {C.feed(B.append(xs, ys), s) == resume(ys, C.feed(xs, s)) : C.State & C.DecodeResult}

def feed_append(xs, ys, s):
  match xs s:
    case Nil{} C.Size{budget, body, line, count, cr}:
      {==}
    case Nil{} C.Payload{budget, body, left}:
      {==}
    case Nil{} C.DataCR{budget, body}:
      {==}
    case Nil{} C.DataLF{budget, body}:
      {==}
    case Nil{} C.Trailers{body, hs, line, count, cr}:
      {==}
    case Nil{} C.Complete{body, hs}:
      terminal_suffix(body, hs, ys)
    case Nil{} C.Failed{status}:
      failed_suffix(status, ys)
    case c <> t C.Complete{body, hs}:
      {==}
    case c <> t C.Failed{status}:
      {==}
    case c <> t C.Size{budget, body, line, count, cr}:
      feed_append(t, ys, C.advance(C.Size{budget, body, line, count, cr}, c))
    case c <> t C.Payload{budget, body, left}:
      feed_append(t, ys, C.advance(C.Payload{budget, body, left}, c))
    case c <> t C.DataCR{budget, body}:
      feed_append(t, ys, C.advance(C.DataCR{budget, body}, c))
    case c <> t C.DataLF{budget, body}:
      feed_append(t, ys, C.advance(C.DataLF{budget, body}, c))
    case c <> t C.Trailers{body, hs, line, count, cr}:
      feed_append(t, ys, C.advance(C.Trailers{body, hs, line, count, cr}, c))

law scan_terminal:
  for +budget: U32
  for +acc: List<&2, U32>
  for +suffix: List<&2, U32>
  {C.feed(48 <> 13 <> 10 <> 13 <> 10 <> suffix, C.Size{budget, acc, [], 0, False{}}) == (C.Complete{List.reverse(&2, U32, acc), []}, C.Decoded{List.reverse(&2, U32, acc), [], suffix}) : C.State & C.DecodeResult}

def scan_terminal(budget, acc, suffix):
  terminal_suffix(List.reverse(&2, U32, acc), [], suffix)

law scan_single_payload:
  for +budget: U32
  for +acc: List<&2, U32>
  for +c: U32
  for +suffix: List<&2, U32>
  for octet: {(c <= 255 : U32) == True{} : Bool}
  {C.feed(c <> 13 <> 10 <> suffix, C.Payload{budget, acc, 1}) == C.feed(suffix, C.Size{budget, c <> acc, [], 0, False{}}) : C.State & C.DecodeResult}

def scan_single_payload(budget, acc, c, suffix, octet):
  %Equal.sym(Bool, (c <= 255 : U32), True{}, octet) : {C.feed(13 <> 10 <> suffix, C.branch(C.State, _, u => C.data_left(budget, acc, 1, c), u => C.Failed{400})) == C.feed(suffix, C.Size{budget, c <> acc, [], 0, False{}}) : C.State & C.DecodeResult}
  {==}

law scan_single_chunk:
  for +budget: U32
  for +acc: List<&2, U32>
  for +c: U32
  for +suffix: List<&2, U32>
  for enough: {(1 <= budget : U32) == True{} : Bool}
  for octet: {(c <= 255 : U32) == True{} : Bool}
  {C.feed(49 <> 13 <> 10 <> c <> 13 <> 10 <> suffix, C.Size{budget, acc, [], 0, False{}}) == C.feed(suffix, C.Size{(budget - 1 : U32), c <> acc, [], 0, False{}}) : C.State & C.DecodeResult}

def scan_single_chunk(budget, acc, c, suffix, enough, octet):
  %Equal.sym(Bool, (1 <= budget : U32), True{}, enough) : {C.feed(c <> 13 <> 10 <> suffix, Bool.pick(C.State, _, C.Payload{(budget - 1 : U32), acc, 1}, C.Failed{413})) == C.feed(suffix, C.Size{(budget - 1 : U32), c <> acc, [], 0, False{}}) : C.State & C.DecodeResult}
  scan_single_payload((budget - 1 : U32), acc, c, suffix, octet)

law octets_append:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  {C.octets(B.append(xs, ys)) == C.octets(xs) && C.octets(ys) : Bool}

law and_assoc:
  for +a: Bool
  for +b: Bool
  for +c: Bool
  {a && (b && c) == (a && b) && c : Bool}

def and_assoc(a, b, c):
  match a:
    case False{}:
      {==}
    case True{}:
      {==}

def octets_append(xs, ys):
  match xs:
    case Nil{}:
      {==}
    case c <> t:
      %Equal.sym(Bool, C.octets(B.append(t, ys)), C.octets(t) && C.octets(ys), octets_append(t, ys)) : {(c <= 255 : U32) && _ == C.octets(c <> t) && C.octets(ys) : Bool}
      and_assoc((c <= 255 : U32), C.octets(t), C.octets(ys))

# Four bits represent a digit without an arithmetic range hypothesis.
def nibble(bits: Word(4n)) -> U32:
  U32{Bits.pad(4n, 28n, bits)}

law hex_nibble_valid:
  for +bits: Word(4n)
  {B.hex(C.hex_char(nibble(bits))) == True{} : Bool}

def hex_nibble_valid(bits):
  match bits:
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

law hex_nibble_inverse:
  for +bits: Word(4n)
  {C.hex_digit(C.hex_char(nibble(bits))) == nibble(bits) : U32}

def hex_nibble_inverse(bits):
  match bits:
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

def hex_bytes(ds: List<&2, Word(4n)>) -> List<&2, U32>:
  match ds:
    case Nil{}:
      []
    case d <> t:
      C.hex_char(nibble(d)) <> hex_bytes(t)

def hex_value(ds: List<&2, Word(4n)>, acc: U32) -> U32:
  match ds:
    case Nil{}:
      acc
    case d <> t:
      hex_value(t, (acc * 16 + nibble(d) : U32))

# The representation fits U32 exactly when every prefix can accept a digit.
# This tests only arithmetic, independently of the parser.
def hex_fits(ds: List<&2, Word(4n)>, +acc: U32) -> Bool:
  match ds:
    case Nil{}:
      True{}
    case d <> t:
      (acc <= 268435455 : U32) && hex_fits(t, (acc * 16 + nibble(d) : U32))

def digits_seen(ds: List<&2, Word(4n)>, seen: Bool) -> Bool:
  match ds:
    case Nil{}:
      seen
    case d <> t:
      True{}

law digits_seen_true:
  for +ds: List<&2, Word(4n)>
  {digits_seen(ds, True{}) == True{} : Bool}

def digits_seen_true(ds):
  match ds:
    case Nil{}:
      {==}
    case d <> t:
      {==}

# Equality witnesses extract the arithmetic range check for each digit.
def both_left(+a: Bool, +b: Bool, yes: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      yes

def both_right(+a: Bool, +b: Bool, yes: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}:
      yes
    case False{}:
      Bits.absurd({b == True{} : Bool}, Bits.false_true(yes))

law parse_hex_digits:
  for +ds: List<&2, Word(4n)>
  for +acc: U32
  for +seen: Bool
  for safe: {hex_fits(ds, acc) == True{} : Bool}
  {C.size_digits(hex_bytes(ds), acc, seen) == C.size_result(hex_value(ds, acc), digits_seen(ds, seen)) : Maybe<&2, U32>}

def parse_hex_digits(ds, acc, seen, safe):
  match ds:
    case Nil{}:
      {==}
    case d <> t:
      +safe = safe
      fits = both_left((acc <= 268435455 : U32), hex_fits(t, (acc * 16 + nibble(d) : U32)), safe)
      tail = both_right((acc <= 268435455 : U32), hex_fits(t, (acc * 16 + nibble(d) : U32)), safe)
      %Equal.sym(Bool, B.hex(C.hex_char(nibble(d))), True{}, hex_nibble_valid(d)) : {C.branch(Maybe<&2, U32>, _, u => C.branch(Maybe<&2, U32>, (acc <= 268435455 : U32), u => C.size_digits(hex_bytes(t), (acc * 16 + C.hex_digit(C.hex_char(nibble(d))) : U32), True{}), u => None{}), u => C.size_result(acc, seen && C.ext_valid(C.hex_char(nibble(d)) <> hex_bytes(t), C.Semi{}))) == C.size_result(hex_value(d <> t, acc), True{}) : Maybe<&2, U32>}
      %Equal.sym(Bool, (acc <= 268435455 : U32), True{}, fits) : {C.branch(Maybe<&2, U32>, _, u => C.size_digits(hex_bytes(t), (acc * 16 + C.hex_digit(C.hex_char(nibble(d))) : U32), True{}), u => None{}) == C.size_result(hex_value(d <> t, acc), True{}) : Maybe<&2, U32>}
      %Equal.sym(U32, C.hex_digit(C.hex_char(nibble(d))), nibble(d), hex_nibble_inverse(d)) : {C.size_digits(hex_bytes(t), (acc * 16 + _ : U32), True{}) == C.size_result(hex_value(d <> t, acc), True{}) : Maybe<&2, U32>}
      %digits_seen_true(t) : {C.size_digits(hex_bytes(t), (acc * 16 + nibble(d) : U32), True{}) == C.size_result(hex_value(t, (acc * 16 + nibble(d) : U32)), _) : Maybe<&2, U32>}
      parse_hex_digits(t, (acc * 16 + nibble(d) : U32), True{}, tail)

# The encoder's accumulator is a genuine suffix, including at fuel exhaustion.
def hex_append_case(+fuel: Nat, +n: U32, +xs: List<&2, U32>, +ys: List<&2, U32>, zero: Bool,
    step: {C.hex_go(fuel, (n / 16 : U32), C.hex_char((n % 16 : U32)) <> B.append(xs, ys)) == B.append(C.hex_go(fuel, (n / 16 : U32), C.hex_char((n % 16 : U32)) <> xs), ys) : List<&2, U32>}) ->
    {C.branch(List<&2, U32>, zero, u => B.append(xs, ys), u => C.hex_go(fuel, (n / 16 : U32), C.hex_char((n % 16 : U32)) <> B.append(xs, ys))) == B.append(C.branch(List<&2, U32>, zero, u => xs, u => C.hex_go(fuel, (n / 16 : U32), C.hex_char((n % 16 : U32)) <> xs)), ys) : List<&2, U32>}:
  match zero:
    case True{}:
      {==}
    case False{}:
      step

law hex_go_append:
  for +fuel: Nat
  for +n: U32
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  {C.hex_go(fuel, n, B.append(xs, ys)) == B.append(C.hex_go(fuel, n, xs), ys) : List<&2, U32>}

def hex_go_append(fuel, n, xs, ys):
  match fuel:
    case 0n:
      {==}
    case 1n+p:
      hex_append_case(p, n, xs, ys, U32.is_eq(n, 0), hex_go_append(p, (n / 16 : U32), C.hex_char((n % 16 : U32)) <> xs, ys))
