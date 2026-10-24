# The stream writer satisfies an independent RFC 9112 grammar parser.
import Base
import ./stream-rfc-spec.bend as S
import ../src/http/chunked.bend as C
import ../src/http/bytes.bend as B
import ./bytes-tail.bend as BT
import ../src/http/stream_framing.bend as Stream
import ./chunked.bend as P
import ./chunked-roundtrip.bend as Q
import ./chunked-arith.bend as A
import ./stream.bend as Incremental

def digit_ok(+d: Word(4n)) -> {S.hex(C.hex_char(P.nibble(d))) == True{} : Bool}:
  match d:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}: {==}

def digit_value(+d: Word(4n)) -> {S.hex_digit(C.hex_char(P.nibble(d))) == P.nibble(d) : U32}:
  match d:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}: {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}: {==}

def parse_hex_digits(+ds: List<&2, Word(4n)>, +acc: U32, +seen: Bool, fits: {P.hex_fits(ds, acc) == True{} : Bool}) -> {S.size_digits(P.hex_bytes(ds), acc, seen) == S.size_result(P.hex_value(ds, acc), P.digits_seen(ds, seen)) : Maybe<&2, U32>}:
  match ds:
    case Nil{}: {==}
    case +d <> +t:
      +fits = fits
      fit = P.both_left((acc <= 268435455 : U32), P.hex_fits(t, (16 * acc + P.nibble(d) : U32)), fits)
      tail = P.both_right((acc <= 268435455 : U32), P.hex_fits(t, (16 * acc + P.nibble(d) : U32)), fits)
      %Equal.sym(Bool, S.hex(C.hex_char(P.nibble(d))), True{}, digit_ok(d)) : {S.branch(Maybe<&2, U32>, _, u => S.branch(Maybe<&2, U32>, (acc <= 268435455 : U32), u => S.size_digits(P.hex_bytes(t), (16 * acc + S.hex_digit(C.hex_char(P.nibble(d))) : U32), True{}), u => None{}), u => None{}) == S.size_result(P.hex_value(d <> t, acc), True{}) : Maybe<&2, U32>}
      %Equal.sym(Bool, (acc <= 268435455 : U32), True{}, fit) : {S.branch(Maybe<&2, U32>, _, u => S.size_digits(P.hex_bytes(t), (16 * acc + S.hex_digit(C.hex_char(P.nibble(d))) : U32), True{}), u => None{}) == S.size_result(P.hex_value(d <> t, acc), True{}) : Maybe<&2, U32>}
      %Equal.sym(U32, S.hex_digit(C.hex_char(P.nibble(d))), P.nibble(d), digit_value(d)) : {S.size_digits(P.hex_bytes(t), (16 * acc + _ : U32), True{}) == S.size_result(P.hex_value(d <> t, acc), True{}) : Maybe<&2, U32>}
      %P.digits_seen_true(t) : {S.size_digits(P.hex_bytes(t), (16 * acc + P.nibble(d) : U32), True{}) == S.size_result(P.hex_value(t, (16 * acc + P.nibble(d) : U32)), _) : Maybe<&2, U32>}
      parse_hex_digits(t, (16 * acc + P.nibble(d) : U32), True{}, tail)

def terminal_suffix(+body: List<&2, U32>, +suffix: List<&2, U32>) -> {S.feed(suffix, S.Complete{body}) == (S.Complete{body}, S.Decoded{body, suffix}) : S.State & S.DecodeResult}:
  match suffix:
    case Nil{}: {==}
    case c <> t: {==}

def scan_terminal(+budget: U32, +acc: List<&2, U32>, +suffix: List<&2, U32>) -> {S.feed(48 <> 13 <> 10 <> 13 <> 10 <> suffix, S.Size{budget, acc, [], 0, False{}}) == (S.Complete{List.reverse(&2, U32, acc)}, S.Decoded{List.reverse(&2, U32, acc), suffix}) : S.State & S.DecodeResult}:
  terminal_suffix(List.reverse(&2, U32, acc), suffix)

law size_hex_octet:
  for +d: Word(4n)
  for +budget: U32
  for +body: List<&2, U32>
  for +line: List<&2, U32>
  for +count: U32
  {S.size_octet_inner(budget, body, line, count, False{}, C.hex_char(P.nibble(d))) == S.Size{budget, body, C.hex_char(P.nibble(d)) <> line, count, False{}} : S.State}

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
  {S.feed(B.append(P.hex_bytes(ds), rest), S.Size{budget, body, line, U32.from_nat(m), False{}}) == S.feed(rest, S.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(ds), line), U32.from_nat(Nat.add(m, List.length(&2, Word(4n), ds))), False{}}) : S.State & S.DecodeResult}

def size_line_list(+ds: List<&2, Word(4n)>, +m: Nat, +budget: U32, +body: List<&2, U32>, +line: List<&2, U32>, +rest: List<&2, U32>, fit: {Nat.is_le(Nat.add(m, List.length(&2, Word(4n), ds)), 9n) == True{} : Bool}) -> {S.feed(List.append(&2, U32, P.hex_bytes(ds), rest), S.Size{budget, body, line, U32.from_nat(m), False{}}) == S.feed(rest, S.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(ds), line), U32.from_nat(Nat.add(m, List.length(&2, Word(4n), ds))), False{}}) : S.State & S.DecodeResult}:
  match ds:
    case Nil{}:
      %Equal.sym(Nat, Nat.add(m, 0n), m, A.add_zero_r(m)) : {S.feed(rest, S.Size{budget, body, line, U32.from_nat(m), False{}}) == S.feed(rest, S.Size{budget, body, line, U32.from_nat(_), False{}}) : S.State & S.DecodeResult}
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
      %Equal.sym(Bool, (U32.from_nat(m) < 8192 : U32), True{}, Q.small_count(m, fit0)) : {S.feed(List.append(&2, U32, P.hex_bytes(t), rest), S.branch(S.State, _, u => S.size_octet_inner(budget, body, line, (U32.from_nat(m) + 1 : U32), False{}, hc), u => S.Failed{400})) == S.feed(rest, S.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(t), hc <> line), U32.from_nat(Nat.add(m, 1n+len)), False{}}) : S.State & S.DecodeResult}
      %Equal.sym(U32, (U32.from_nat(m) + 1 : U32), U32.from_nat(1n+m), Q.small_inc(m, fit0)) : {S.feed(List.append(&2, U32, P.hex_bytes(t), rest), S.size_octet_inner(budget, body, line, _, False{}, hc)) == S.feed(rest, S.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(t), hc <> line), U32.from_nat(Nat.add(m, 1n+len)), False{}}) : S.State & S.DecodeResult}
      %Equal.sym(S.State, S.size_octet_inner(budget, body, line, U32.from_nat(1n+m), False{}, hc), S.Size{budget, body, hc <> line, U32.from_nat(1n+m), False{}}, size_hex_octet(d, budget, body, line, U32.from_nat(1n+m))) : {S.feed(List.append(&2, U32, P.hex_bytes(t), rest), _) == S.feed(rest, S.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(t), hc <> line), U32.from_nat(Nat.add(m, 1n+len)), False{}}) : S.State & S.DecodeResult}
      %Equal.sym(Nat, Nat.add(m, 1n+len), 1n+Nat.add(m, len), A.add_succ_r(m, len)) : {S.feed(List.append(&2, U32, P.hex_bytes(t), rest), S.Size{budget, body, hc <> line, U32.from_nat(1n+m), False{}}) == S.feed(rest, S.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(t), hc <> line), U32.from_nat(_), False{}}) : S.State & S.DecodeResult}
      size_line_list(t, 1n+m, budget, body, hc <> line, rest, fit1)

# The induction runs over List.append; Bytes.append is a reversed tail loop (BND-84).
def size_line(ds, m, budget, body, line, rest, fit):
  %Equal.sym(List<&2, U32>, B.append(P.hex_bytes(ds), rest), List.append(&2, U32, P.hex_bytes(ds), rest), BT.append_equiv(P.hex_bytes(ds), rest)) : {S.feed(_, S.Size{budget, body, line, U32.from_nat(m), False{}}) == S.feed(rest, S.Size{budget, body, List.reverse.go(&2, U32, P.hex_bytes(ds), line), U32.from_nat(Nat.add(m, List.length(&2, Word(4n), ds))), False{}}) : S.State & S.DecodeResult}
  size_line_list(ds, m, budget, body, line, rest, fit)

law size_line_end:
  for +n: Nat
  for +budget: U32
  for +body: List<&2, U32>
  for +line: List<&2, U32>
  for +rest: List<&2, U32>
  for short: {Nat.is_le(n, 8n) == True{} : Bool}
  {S.feed(13 <> 10 <> rest, S.Size{budget, body, line, U32.from_nat(n), False{}}) == S.feed(rest, S.start_chunk(budget, body, S.size_digits(List.reverse(&2, U32, line), 0, False{}))) : S.State & S.DecodeResult}

def size_line_end(n, budget, body, line, rest, short):
  +short = short
  +fit = A.le_succ_r(n, 8n, short)
  -goal = S.feed(rest, S.start_chunk(budget, body, S.size_digits(List.reverse(&2, U32, line), 0, False{})))
  %Equal.sym(Bool, (U32.from_nat(n) < 8192 : U32), True{}, Q.small_count(n, fit)) : {S.feed(10 <> rest, S.branch(S.State, _, u => S.size_octet_inner(budget, body, line, (U32.from_nat(n) + 1 : U32), False{}, 13), u => S.Failed{400})) == goal : S.State & S.DecodeResult}
  %Equal.sym(U32, (U32.from_nat(n) + 1 : U32), U32.from_nat(1n+n), Q.small_inc(n, fit)) : {S.feed(10 <> rest, S.size_octet_inner(budget, body, line, _, False{}, 13)) == goal : S.State & S.DecodeResult}
  %Equal.sym(Bool, (U32.from_nat(1n+n) < 8192 : U32), True{}, Q.small_count(1n+n, short)) : {S.feed(rest, S.branch(S.State, _, u => S.size_octet_inner(budget, body, line, (U32.from_nat(1n+n) + 1 : U32), True{}, 10), u => S.Failed{400})) == goal : S.State & S.DecodeResult}
  {==}

# Up to eight digits, then CRLF, start a chunk with the parsed size.
law size_header:
  for +ds: List<&2, Word(4n)>
  for +budget: U32
  for +body: List<&2, U32>
  for +rest: List<&2, U32>
  for short: {Nat.is_le(List.length(&2, Word(4n), ds), 8n) == True{} : Bool}
  {S.feed(B.append(P.hex_bytes(ds), 13 <> 10 <> rest), S.Size{budget, body, [], 0, False{}}) == S.feed(rest, S.start_chunk(budget, body, S.size_digits(P.hex_bytes(ds), 0, False{}))) : S.State & S.DecodeResult}

def size_header(ds, budget, body, rest, short):
  +short = short
  +n = List.length(&2, Word(4n), ds)
  +line = List.reverse.go(&2, U32, P.hex_bytes(ds), [])
  Equal.trans(S.State & S.DecodeResult,
    S.feed(B.append(P.hex_bytes(ds), 13 <> 10 <> rest), S.Size{budget, body, [], U32.from_nat(0n), False{}}),
    S.feed(13 <> 10 <> rest, S.Size{budget, body, line, U32.from_nat(n), False{}}),
    S.feed(rest, S.start_chunk(budget, body, S.size_digits(P.hex_bytes(ds), 0, False{}))),
    size_line(ds, 0n, budget, body, [], 13 <> 10 <> rest, A.le_succ_r(n, 8n, short)),
    Equal.trans(S.State & S.DecodeResult,
      S.feed(13 <> 10 <> rest, S.Size{budget, body, line, U32.from_nat(n), False{}}),
      S.feed(rest, S.start_chunk(budget, body, S.size_digits(List.reverse(&2, U32, line), 0, False{}))),
      S.feed(rest, S.start_chunk(budget, body, S.size_digits(P.hex_bytes(ds), 0, False{}))),
      size_line_end(n, budget, body, line, rest, short),
      Equal.cong(List<&2, U32>, S.State & S.DecodeResult, xs => S.feed(rest, S.start_chunk(budget, body, S.size_digits(xs, 0, False{}))), List.reverse(&2, U32, line), P.hex_bytes(ds), Q.reverse_reverse(P.hex_bytes(ds)))))

# The decoder parses the encoder's digits back to the size.
law size_parse:
  for +size: U32
  for nz: {U32.is_eq(size, 0) == False{} : Bool}
  {S.size_digits(P.hex_bytes(P.hex_digits(8n, size, [])), 0, False{}) == Some{size} : Maybe<&2, U32>}

def size_parse(size, nz):
  +ds = P.hex_digits(8n, size, [])
  +fin = Q.done_eight(size)
  Equal.trans(Maybe<&2, U32>, S.size_digits(P.hex_bytes(ds), 0, False{}), S.size_result(P.hex_value(ds, 0), P.digits_seen(ds, False{})), Some{size},
    parse_hex_digits(ds, 0, False{}, Q.hex_digits_fits(8n, size, [], fin)),
    %Equal.sym(U32, P.hex_value(ds, 0), size, Q.hex_digits_value(8n, size, [], fin)) : {S.size_result(_, P.digits_seen(ds, False{})) == Some{size} : Maybe<&2, U32>}
    %Equal.sym(Bool, P.digits_seen(ds, False{}), True{}, Q.hex_digits_nonzero(7n, size, nz)) : {S.size_result(size, _) == Some{size} : Maybe<&2, U32>}
    {==})

law start_payload:
  for +budget: U32
  for +body: List<&2, U32>
  for +size: U32
  for nz: {U32.is_eq(size, 0) == False{} : Bool}
  for fits: {(size <= budget : U32) == True{} : Bool}
  {S.start_chunk(budget, body, Some{size}) == S.Payload{(budget - size : U32), body, size} : S.State}

def start_payload(budget, body, size, nz, fits):
  %Equal.sym(Bool, U32.is_eq(size, 0), False{}, nz) : {S.start_size(budget, body, size, _) == S.Payload{(budget - size : U32), body, size} : S.State}
  %Equal.sym(Bool, (size <= budget : U32), True{}, fits) : {Bool.pick(S.State, _, S.Payload{(budget - size : U32), body, size}, S.Failed{413}) == S.Payload{(budget - size : U32), body, size} : S.State}
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
  {S.data_octet(budget, acc, left, c) == S.Payload{budget, c <> acc, (left - 1 : U32)} : S.State}

def payload_octet(budget, acc, left, c, oct, one, zero):
  %Equal.sym(Bool, (c <= 255 : U32), True{}, oct) : {S.branch(S.State, _, u => S.data_left(budget, acc, left, c), u => S.Failed{400}) == S.Payload{budget, c <> acc, (left - 1 : U32)} : S.State}
  %Equal.sym(Bool, U32.is_eq(left, 1), False{}, one) : {S.data_next(budget, c <> acc, left, _) == S.Payload{budget, c <> acc, (left - 1 : U32)} : S.State}
  %Equal.sym(Bool, U32.is_eq(left, 0), False{}, zero) : {S.data_rest(budget, c <> acc, left, _) == S.Payload{budget, c <> acc, (left - 1 : U32)} : S.State}
  {==}

law payload_last:
  for +budget: U32
  for +acc: List<&2, U32>
  for +left: U32
  for +c: U32
  for oct: {(c <= 255 : U32) == True{} : Bool}
  for one: {U32.is_eq(left, 1) == True{} : Bool}
  {S.data_octet(budget, acc, left, c) == S.DataCR{budget, c <> acc} : S.State}

def payload_last(budget, acc, left, c, oct, one):
  %Equal.sym(Bool, (c <= 255 : U32), True{}, oct) : {S.branch(S.State, _, u => S.data_left(budget, acc, left, c), u => S.Failed{400}) == S.DataCR{budget, c <> acc} : S.State}
  %Equal.sym(Bool, U32.is_eq(left, 1), True{}, one) : {S.data_next(budget, c <> acc, left, _) == S.DataCR{budget, c <> acc} : S.State}
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
  {S.feed(c <> B.append(t, 13 <> 10 <> more), S.Payload{budget, acc, left}) == S.feed(more, S.Size{budget, List.reverse.go(&2, U32, c <> t, acc), [], 0, False{}}) : S.State & S.DecodeResult}

def scan_payload_list(+t: List<&2, U32>, +c: U32, +budget: U32, +acc: List<&2, U32>, +left: U32, +more: List<&2, U32>, oct: {C.octets(c <> t) == True{} : Bool}, len: {U32.to_nat(left) == 1n+List.length(&2, U32, t) : Nat}) -> {S.feed(c <> List.append(&2, U32, t, 13 <> 10 <> more), S.Payload{budget, acc, left}) == S.feed(more, S.Size{budget, List.reverse.go(&2, U32, c <> t, acc), [], 0, False{}}) : S.State & S.DecodeResult}:
  match t:
    case Nil{}:
      +oct = oct
      octc = P.both_left((c <= 255 : U32), C.octets([]), oct)
      %Equal.sym(S.State, S.data_octet(budget, acc, left, c), S.DataCR{budget, c <> acc}, payload_last(budget, acc, left, c, octc, left_eq(left, 1n, 1, len))) : {S.feed(13 <> 10 <> more, _) == S.feed(more, S.Size{budget, c <> acc, [], 0, False{}}) : S.State & S.DecodeResult}
      {==}
    case +c2 <> +t2:
      +oct = oct
      +len = len
      +octc = P.both_left((c <= 255 : U32), C.octets(c2 <> t2), oct)
      +octr = P.both_right((c <= 255 : U32), C.octets(c2 <> t2), oct)
      +k = List.length(&2, U32, t2)
      sub = Equal.trans(Nat, 1n+U32.to_nat((left - 1 : U32)), U32.to_nat(left), 2n+k, A.u32_sub_nat(left, 1, one_le(left, k, len)), len)
      len2 = Equal.cong(Nat, Nat, x => A.pred(x), 1n+U32.to_nat((left - 1 : U32)), 2n+k, sub)
      %Equal.sym(S.State, S.data_octet(budget, acc, left, c), S.Payload{budget, c <> acc, (left - 1 : U32)}, payload_octet(budget, acc, left, c, octc, left_eq(left, 2n+k, 1, len), left_eq(left, 2n+k, 0, len))) : {S.feed(c2 <> List.append(&2, U32, t2, 13 <> 10 <> more), _) == S.feed(more, S.Size{budget, List.reverse.go(&2, U32, c2 <> t2, c <> acc), [], 0, False{}}) : S.State & S.DecodeResult}
      scan_payload_list(t2, c2, budget, c <> acc, (left - 1 : U32), more, octr, len2)

# One producer chunk.

# The induction runs over List.append; Bytes.append is a reversed tail loop (BND-84).
def scan_payload(t, c, budget, acc, left, more, oct, len):
  %Equal.sym(List<&2, U32>, B.append(t, 13 <> 10 <> more), List.append(&2, U32, t, 13 <> 10 <> more), BT.append_equiv(t, 13 <> 10 <> more)) : {S.feed(c <> _, S.Payload{budget, acc, left}) == S.feed(more, S.Size{budget, List.reverse.go(&2, U32, c <> t, acc), [], 0, False{}}) : S.State & S.DecodeResult}
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
  {S.feed(B.append(C.hex_go(8n, U32.from_nat(List.length(&2, U32, c <> tail)), []), 13 <> 10 <> c <> B.append(tail, 13 <> 10 <> more)), S.Size{budget, acc, [], 0, False{}}) == S.feed(more, S.Size{(budget - U32.from_nat(List.length(&2, U32, c <> tail)) : U32), List.reverse.go(&2, U32, c <> tail, acc), [], 0, False{}}) : S.State & S.DecodeResult}

def chunk_step(c, tail, more, budget, acc, oct, fit):
  +fit = fit
  +size = U32.from_nat(List.length(&2, U32, c <> tail))
  +k = List.length(&2, U32, tail)
  +exact = A.from_nat_exact(1n+k, budget, fit)
  +nz = size_nonzero(size, k, exact)
  +ds = P.hex_digits(8n, size, [])
  +x = {c <> B.append(tail, 13 <> 10 <> more) : List<&2, U32>}
  -goal = S.feed(more, S.Size{(budget - size : U32), List.reverse.go(&2, U32, c <> tail, acc), [], 0, False{}})
  %Equal.sym(List<&2, U32>, C.hex_go(8n, size, P.hex_bytes([])), P.hex_bytes(ds), P.hex_go_digits(8n, size, [])) : {S.feed(B.append(_, 13 <> 10 <> x), S.Size{budget, acc, [], 0, False{}}) == goal : S.State & S.DecodeResult}
  %Equal.sym(S.State & S.DecodeResult, S.feed(B.append(P.hex_bytes(ds), 13 <> 10 <> x), S.Size{budget, acc, [], 0, False{}}), S.feed(x, S.start_chunk(budget, acc, S.size_digits(P.hex_bytes(ds), 0, False{}))), size_header(ds, budget, acc, x, Q.hex_digits_length(8n, size, []))) : {_ == goal : S.State & S.DecodeResult}
  %Equal.sym(Maybe<&2, U32>, S.size_digits(P.hex_bytes(ds), 0, False{}), Some{size}, size_parse(size, nz)) : {S.feed(x, S.start_chunk(budget, acc, _)) == goal : S.State & S.DecodeResult}
  %Equal.sym(S.State, S.start_chunk(budget, acc, Some{size}), S.Payload{(budget - size : U32), acc, size}, start_payload(budget, acc, size, nz, size_fits(size, budget, k, exact, fit))) : {S.feed(x, _) == goal : S.State & S.DecodeResult}
  scan_payload(tail, c, (budget - size : U32), acc, size, more, oct, exact)

# Induction over producer chunks.

def done_pair(+rev: List<&2, U32>, +suffix: List<&2, U32>) -> S.State & S.DecodeResult:
  (S.Complete{List.reverse(&2, U32, rev)}, S.Decoded{List.reverse(&2, U32, rev), suffix})

def rest_fit(+k: Nat, +lr: Nat, +total: Nat, +left: Nat, sum: {Nat.add(k, left) == total : Nat}, fit: {Nat.is_le(Nat.add(k, lr), total) == True{} : Bool}) -> {Nat.is_le(lr, left) == True{} : Bool}:
  %A.cmp_add_cancel(k, lr, left) : {Cmp.is_le(_) == True{} : Bool}
  %Equal.sym(Nat, Nat.add(k, left), total, sum) : {Nat.is_le(Nat.add(k, lr), _) == True{} : Bool}
  fit

def total_fit(+body: List<&2, U32>, +rc: List<&2, U32>, +budget: U32, fit: {Nat.is_le(List.length(&2, U32, List.append(&2, U32, body, rc)), U32.to_nat(budget)) == True{} : Bool}) ->
    {Nat.is_le(Nat.add(List.length(&2, U32, body), List.length(&2, U32, rc)), U32.to_nat(budget)) == True{} : Bool}:
  %Q.length_append_list(body, rc) : {Nat.is_le(_, U32.to_nat(budget)) == True{} : Bool}
  fit

law roundtrip_from:
  for +chunks: List<&2, List<&2, U32>>
  for +budget: U32
  for +acc: List<&2, U32>
  for +suffix: List<&2, U32>
  for oct: {C.octets(List.concat(&2, U32, chunks)) == True{} : Bool}
  for fit: {Nat.is_le(List.length(&2, U32, List.concat(&2, U32, chunks)), U32.to_nat(budget)) == True{} : Bool}
  {S.feed(B.append(C.encode(chunks), suffix), S.Size{budget, acc, [], 0, False{}}) == done_pair(List.reverse.go(&2, U32, List.concat(&2, U32, chunks), acc), suffix) : S.State & S.DecodeResult}

def roundtrip_from(chunks, budget, acc, suffix, oct, fit):
  match chunks:
    case Nil{}:
      scan_terminal(budget, acc, suffix)
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
      %Equal.sym(List<&2, U32>, B.append(B.append(h, 13 <> 10 <> B.append(body, 13 <> 10 <> e)), suffix), B.append(h, B.append(13 <> 10 <> B.append(body, 13 <> 10 <> e), suffix)), Q.append_assoc(h, 13 <> 10 <> B.append(body, 13 <> 10 <> e), suffix)) : {S.feed(_, S.Size{budget, acc, [], 0, False{}}) == goal : S.State & S.DecodeResult}
      %Equal.sym(List<&2, U32>, B.append(13 <> 10 <> B.append(body, 13 <> 10 <> e), suffix), 13 <> 10 <> c <> B.append(B.append(tail, 13 <> 10 <> e), suffix), Equal.trans(List<&2, U32>, B.append(13 <> 10 <> B.append(body, 13 <> 10 <> e), suffix), 13 <> 10 <> B.append(B.append(body, 13 <> 10 <> e), suffix), 13 <> 10 <> c <> B.append(B.append(tail, 13 <> 10 <> e), suffix), Q.append_cons2(13, 10, B.append(body, 13 <> 10 <> e), suffix), Equal.trans(List<&2, U32>, 13 <> 10 <> B.append(B.append(body, 13 <> 10 <> e), suffix), 13 <> 10 <> B.append(c <> B.append(tail, 13 <> 10 <> e), suffix), 13 <> 10 <> c <> B.append(B.append(tail, 13 <> 10 <> e), suffix), Equal.cong(List<&2, U32>, List<&2, U32>, l => 13 <> 10 <> B.append(l, suffix), B.append(body, 13 <> 10 <> e), c <> B.append(tail, 13 <> 10 <> e), Q.append_cons(c, tail, 13 <> 10 <> e)), Equal.cong(List<&2, U32>, List<&2, U32>, l => 13 <> 10 <> l, B.append(c <> B.append(tail, 13 <> 10 <> e), suffix), c <> B.append(B.append(tail, 13 <> 10 <> e), suffix), Q.append_cons(c, B.append(tail, 13 <> 10 <> e), suffix))))) : {S.feed(B.append(h, _), S.Size{budget, acc, [], 0, False{}}) == goal : S.State & S.DecodeResult}
      %Equal.sym(List<&2, U32>, B.append(B.append(tail, 13 <> 10 <> e), suffix), B.append(tail, B.append(13 <> 10 <> e, suffix)), Q.append_assoc(tail, 13 <> 10 <> e, suffix)) : {S.feed(B.append(h, 13 <> 10 <> c <> _), S.Size{budget, acc, [], 0, False{}}) == goal : S.State & S.DecodeResult}
      %Equal.sym(List<&2, U32>, B.append(13 <> 10 <> e, suffix), 13 <> 10 <> B.append(e, suffix), Q.append_cons2(13, 10, e, suffix)) : {S.feed(B.append(h, 13 <> 10 <> c <> B.append(tail, _)), S.Size{budget, acc, [], 0, False{}}) == goal : S.State & S.DecodeResult}
      Equal.trans(S.State & S.DecodeResult,
        S.feed(B.append(h, 13 <> 10 <> c <> B.append(tail, 13 <> 10 <> B.append(e, suffix))), S.Size{budget, acc, [], 0, False{}}),
        S.feed(B.append(e, suffix), S.Size{(budget - size : U32), List.reverse.go(&2, U32, body, acc), [], 0, False{}}),
        goal,
        chunk_step(c, tail, B.append(e, suffix), budget, acc, P.both_left(C.octets(body), C.octets(rc), both), fitc),
        Equal.trans(S.State & S.DecodeResult,
          S.feed(B.append(e, suffix), S.Size{(budget - size : U32), List.reverse.go(&2, U32, body, acc), [], 0, False{}}),
          done_pair(List.reverse.go(&2, U32, rc, List.reverse.go(&2, U32, body, acc)), suffix),
          goal,
          roundtrip_from(rest, (budget - size : U32), List.reverse.go(&2, U32, body, acc), suffix, P.both_right(C.octets(body), C.octets(rc), both), fitr),
          Equal.cong(List<&2, U32>, S.State & S.DecodeResult, x => done_pair(x, suffix), List.reverse.go(&2, U32, rc, List.reverse.go(&2, U32, body, acc)), List.reverse.go(&2, U32, List.append(&2, U32, body, rc), acc), Equal.sym(List<&2, U32>, List.reverse.go(&2, U32, List.append(&2, U32, body, rc), acc), List.reverse.go(&2, U32, rc, List.reverse.go(&2, U32, body, acc)), Q.reverse_go_append_list(body, rc, acc)))))

# The independent grammar parser reads every admissible partition and suffix.
law roundtrip:
  for +chunks: List<&2, List<&2, U32>>
  for +limit: U32
  for +suffix: List<&2, U32>
  for valid: {C.admissible(chunks, limit) == True{} : Bool}
  {S.parse(B.append(C.encode(chunks), suffix), limit) == S.Decoded{List.concat(&2, U32, chunks), suffix} : S.DecodeResult}

def roundtrip(chunks, limit, suffix, valid):
  +valid = valid
  +body = List.concat(&2, U32, chunks)
  +fit = Nat.is_le(List.length(&2, U32, body), U32.to_nat(limit))
  run = roundtrip_from(chunks, limit, [], suffix, P.both_left(C.octets(body), fit, valid), P.both_right(C.octets(body), fit, valid))
  Equal.trans(S.DecodeResult,
    S.parse(B.append(C.encode(chunks), suffix), limit),
    S.Decoded{List.reverse(&2, U32, List.reverse(&2, U32, body)), suffix},
    S.Decoded{body, suffix},
    Equal.cong(S.State & S.DecodeResult, S.DecodeResult, pair => S.result(pair), S.feed(B.append(C.encode(chunks), suffix), S.Size{limit, [], [], 0, False{}}), done_pair(List.reverse(&2, U32, body), suffix), run),
    Equal.cong(List<&2, U32>, S.DecodeResult, x => S.Decoded{x, suffix}, List.reverse(&2, U32, List.reverse(&2, U32, body)), body, Q.reverse_reverse(body)))

def wire_roundtrip(+chunks: List<&2, List<&2, U32>>, +limit: U32, +suffix: List<&2, U32>, valid: {C.admissible(chunks, limit) == True{} : Bool}) -> {S.parse(B.append(Stream.wire(chunks), suffix), limit) == S.Decoded{List.concat(&2, U32, chunks), suffix} : S.DecodeResult}:
  Equal.trans(S.DecodeResult, S.parse(B.append(Stream.wire(chunks), suffix), limit), S.parse(B.append(C.encode(chunks), suffix), limit), S.Decoded{List.concat(&2, U32, chunks), suffix}, Equal.cong(List<&2, U32>, S.DecodeResult, wire => S.parse(B.append(wire, suffix), limit), Stream.wire(chunks), C.encode(chunks), Incremental.canonical(chunks)), roundtrip(chunks, limit, suffix, valid))

def last_chunk(+limit: U32, +suffix: List<&2, U32>) -> {S.parse(48 <> 13 <> 10 <> 13 <> 10 <> suffix, limit) == S.Decoded{[], suffix} : S.DecodeResult}:
  Equal.cong(S.State & S.DecodeResult, S.DecodeResult, pair => S.result(pair), S.feed(48 <> 13 <> 10 <> 13 <> 10 <> suffix, S.Size{limit, [], [], 0, False{}}), (S.Complete{[]}, S.Decoded{[], suffix}), scan_terminal(limit, [], suffix))
