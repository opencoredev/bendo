# Scanner reconstruction with arbitrary suffixes and partial line buffers.
import Base
import ../LAWS.bend as Laws
import ./support.bend as Support
import ./equality.bend as E
import ./headers.bend as H
import ../src/http/bytes.bend as B
import ../src/http/request.bend as R
import ../src/http/parse.bend as P
import ../src/http/write.bend as W
import ./bytes-tail.bend as BT

def Laws.advance_request(c, rev, ok):
  %Equal.sym(Bool, Support.printable_octet(c), True{}, ok) : {P.request_octet(_, c, rev) == P.RequestLine{c <> rev, False{}} : P.State}
  {==}

def Laws.advance_header(r, c, rev, ok):
  %Equal.sym(Bool, B.value_octet(c), True{}, ok) : {P.header_octet(_, c, r, rev) == P.Headers{r, c <> rev, False{}} : P.State}
  {==}

# Bytes.append is a reversed tail loop (BND-84); these restate it over List.append.
def append_cons2(+a: U32, +b: U32, +t: List<&2, U32>, +ys: List<&2, U32>) -> {B.append(a <> b <> t, ys) == a <> b <> B.append(t, ys) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, B.append(a <> b <> t, ys), List.append(&2, U32, a <> b <> t, ys), a <> b <> B.append(t, ys), BT.append_equiv(a <> b <> t, ys), Equal.cong(List<&2, U32>, List<&2, U32>, l => a <> b <> l, List.append(&2, U32, t, ys), B.append(t, ys), Equal.sym(List<&2, U32>, B.append(t, ys), List.append(&2, U32, t, ys), BT.append_equiv(t, ys))))

def value_ok(+xs: List<&2, U32>, ok: {B.value(xs) == True{} : Bool}) -> {B.value_spec(xs) == True{} : Bool}:
  Equal.trans(Bool, B.value_spec(xs), B.value(xs), True{}, Equal.sym(Bool, B.value(xs), B.value_spec(xs), BT.value_equiv(xs)), ok)

def tail_ok(+s: String, ok: {B.token_tail(s) == True{} : Bool}) -> {B.token_tail_spec(s) == True{} : Bool}:
  Equal.trans(Bool, B.token_tail_spec(s), B.token_tail(s), True{}, Equal.sym(Bool, B.token_tail(s), B.token_tail_spec(s), BT.token_tail_equiv(s)), ok)

# A valid nonempty token's tail check, over the spec.
def token_spec_ok(+c: U32, +t: String, ok: {B.token(SCon{Chr{c}, t}) == True{} : Bool}) -> {B.token_tail_spec(SCon{Chr{c}, t}) == True{} : Bool}:
  Equal.trans(Bool, B.tchar(c) && B.token_tail_spec(t), B.tchar(c) && B.token_tail(t), True{}, Equal.cong(Bool, Bool, x => B.tchar(c) && x, B.token_tail_spec(t), B.token_tail(t), Equal.sym(Bool, B.token_tail(t), B.token_tail_spec(t), BT.token_tail_equiv(t))), ok)

def scan_request_line_list(+xs: List<&2, U32>, +rev: List<&2, U32>, +tail: List<&2, U32>, +ok: {Support.printable(xs) == True{} : Bool}) -> {P.feed(List.append(&2, U32, xs, 13 <> 10 <> tail), P.RequestLine{rev, False{}}) == P.feed(tail, P.request_line(List.reverse(&2, U32, List.reverse.go(&2, U32, xs, rev)))) : P.State & R.ParseResult}:
  match xs:
    case Nil{}:
      {==}
    case c <> t:
      %Equal.sym(P.State, P.advance(P.RequestLine{rev, False{}}, c), P.RequestLine{c <> rev, False{}}, Laws.advance_request(c, rev, Laws.and_left(Support.printable_octet(c), Support.printable(t), ok))) : {P.feed(List.append(&2, U32, t, 13 <> 10 <> tail), _) == P.feed(tail, P.request_line(List.reverse(&2, U32, List.reverse.go(&2, U32, t, c <> rev)))) : P.State & R.ParseResult}
      scan_request_line_list(t, c <> rev, tail, Laws.and_right(Support.printable_octet(c), Support.printable(t), ok))

def Laws.scan_request_line_acc(xs, rev, tail, ok):
  Equal.trans(P.State & R.ParseResult, P.feed(B.append(xs, 13 <> 10 <> tail), P.RequestLine{rev, False{}}), P.feed(List.append(&2, U32, xs, 13 <> 10 <> tail), P.RequestLine{rev, False{}}), P.feed(tail, P.request_line(List.reverse(&2, U32, List.reverse.go(&2, U32, xs, rev)))), Equal.cong(List<&2, U32>, P.State & R.ParseResult, l => P.feed(l, P.RequestLine{rev, False{}}), B.append(xs, 13 <> 10 <> tail), List.append(&2, U32, xs, 13 <> 10 <> tail), BT.append_equiv(xs, 13 <> 10 <> tail)), scan_request_line_list(xs, rev, tail, ok))


def Laws.scan_request_line(xs, tail, ok):
  %Laws.reverse_twice(U32, xs) : {P.feed(B.append(xs, 13 <> 10 <> tail), P.initial()) == P.feed(tail, P.request_line(_)) : P.State & R.ParseResult}
  Laws.scan_request_line_acc(xs, [], tail, ok)

def scan_header_line_list(+r: R.Req, +xs: List<&2, U32>, +rev: List<&2, U32>, +tail: List<&2, U32>, +ok: {B.value_spec(xs) == True{} : Bool}) -> {P.feed(List.append(&2, U32, xs, 13 <> 10 <> tail), P.Headers{r, rev, False{}}) == P.feed(tail, P.header_line(r, List.reverse(&2, U32, List.reverse.go(&2, U32, xs, rev)))) : P.State & R.ParseResult}:
  match xs:
    case Nil{}:
      {==}
    case c <> t:
      %Equal.sym(P.State, P.advance(P.Headers{r, rev, False{}}, c), P.Headers{r, c <> rev, False{}}, Laws.advance_header(r, c, rev, Laws.and_left(B.value_octet(c), B.value_spec(t), ok))) : {P.feed(List.append(&2, U32, t, 13 <> 10 <> tail), _) == P.feed(tail, P.header_line(r, List.reverse(&2, U32, List.reverse.go(&2, U32, t, c <> rev)))) : P.State & R.ParseResult}
      scan_header_line_list(r, t, c <> rev, tail, Laws.and_right(B.value_octet(c), B.value_spec(t), ok))

def Laws.scan_header_line_acc(r, xs, rev, tail, ok):
  Equal.trans(P.State & R.ParseResult, P.feed(B.append(xs, 13 <> 10 <> tail), P.Headers{r, rev, False{}}), P.feed(List.append(&2, U32, xs, 13 <> 10 <> tail), P.Headers{r, rev, False{}}), P.feed(tail, P.header_line(r, List.reverse(&2, U32, List.reverse.go(&2, U32, xs, rev)))), Equal.cong(List<&2, U32>, P.State & R.ParseResult, l => P.feed(l, P.Headers{r, rev, False{}}), B.append(xs, 13 <> 10 <> tail), List.append(&2, U32, xs, 13 <> 10 <> tail), BT.append_equiv(xs, 13 <> 10 <> tail)), scan_header_line_list(r, xs, rev, tail, value_ok(xs, ok)))


def Laws.scan_header_line(r, xs, tail, ok):
  %Laws.reverse_twice(U32, xs) : {P.feed(B.append(xs, 13 <> 10 <> tail), P.Headers{r, [], False{}}) == P.feed(tail, P.header_line(r, _)) : P.State & R.ParseResult}
  Laws.scan_header_line_acc(r, xs, [], tail, ok)


# This predicate describes only scanner octets; semantic header validity
# remains R.headers_valid and is independently required below.
def append_assoc_list(+xs: List<&2, U32>, +ys: List<&2, U32>, +zs: List<&2, U32>) -> {List.append(&2, U32, List.append(&2, U32, xs, ys), zs) == List.append(&2, U32, xs, List.append(&2, U32, ys, zs)) : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case c <> t:
      %append_assoc_list(t, ys, zs) : {c <> List.append(&2, U32, List.append(&2, U32, t, ys), zs) == c <> _ : List<&2, U32>}
      {==}

def Laws.append_assoc(xs, ys, zs):
  Equal.trans(List<&2, U32>, B.append(B.append(xs, ys), zs), List.append(&2, U32, B.append(xs, ys), zs), B.append(xs, B.append(ys, zs)), BT.append_equiv(B.append(xs, ys), zs), Equal.trans(List<&2, U32>, List.append(&2, U32, B.append(xs, ys), zs), List.append(&2, U32, List.append(&2, U32, xs, ys), zs), B.append(xs, B.append(ys, zs)), Equal.cong(List<&2, U32>, List<&2, U32>, l => List.append(&2, U32, l, zs), B.append(xs, ys), List.append(&2, U32, xs, ys), BT.append_equiv(xs, ys)), Equal.trans(List<&2, U32>, List.append(&2, U32, List.append(&2, U32, xs, ys), zs), List.append(&2, U32, xs, List.append(&2, U32, ys, zs)), B.append(xs, B.append(ys, zs)), append_assoc_list(xs, ys, zs), Equal.trans(List<&2, U32>, List.append(&2, U32, xs, List.append(&2, U32, ys, zs)), List.append(&2, U32, xs, B.append(ys, zs)), B.append(xs, B.append(ys, zs)), Equal.cong(List<&2, U32>, List<&2, U32>, l => List.append(&2, U32, xs, l), List.append(&2, U32, ys, zs), B.append(ys, zs), Equal.sym(List<&2, U32>, B.append(ys, zs), List.append(&2, U32, ys, zs), BT.append_equiv(ys, zs))), Equal.sym(List<&2, U32>, B.append(xs, B.append(ys, zs)), List.append(&2, U32, xs, B.append(ys, zs)), BT.append_equiv(xs, B.append(ys, zs)))))))


def Laws.header_bytes(h, tail):
  match h:
    case R.Header{n, v}:
      Equal.trans(List<&2, U32>, B.append(B.encode(n), 58 <> 32 <> B.append(v, 13 <> 10 <> tail)), B.append(B.encode(n), B.append(58 <> 32 <> v, 13 <> 10 <> tail)), B.append(B.append(B.encode(n), 58 <> 32 <> v), 13 <> 10 <> tail), Equal.cong(List<&2, U32>, List<&2, U32>, l => B.append(B.encode(n), l), 58 <> 32 <> B.append(v, 13 <> 10 <> tail), B.append(58 <> 32 <> v, 13 <> 10 <> tail), Equal.sym(List<&2, U32>, B.append(58 <> 32 <> v, 13 <> 10 <> tail), 58 <> 32 <> B.append(v, 13 <> 10 <> tail), append_cons2(58, 32, v, 13 <> 10 <> tail))), Equal.sym(List<&2, U32>, B.append(B.append(B.encode(n), 58 <> 32 <> v), 13 <> 10 <> tail), B.append(B.encode(n), B.append(58 <> 32 <> v, 13 <> 10 <> tail)), Laws.append_assoc(B.encode(n), 58 <> 32 <> v, 13 <> 10 <> tail)))


def Laws.scan_header_octets(r, h, tail, ok, bytes):
  match h:
    case R.Header{n, v}:
      +content = Support.header_content(R.Header{n, v})
      e1 = Equal.cong(List<&2, U32>, P.State & R.ParseResult, xs => P.feed(xs, P.Headers{r, [], False{}}), W.header(R.Header{n, v}, tail), B.append(content, 13 <> 10 <> tail), Laws.header_bytes(R.Header{n, v}, tail))
      e2 = Laws.scan_header_line(r, content, tail, bytes)
      e3 = Equal.cong(P.State, P.State & R.ParseResult, s => P.feed(tail, s), P.header_line(r, content), P.push_header(r, R.Header{n, v}), Laws.header_fields(r, n, v, ok))
      Equal.trans(P.State & R.ParseResult, P.feed(W.header(R.Header{n, v}, tail), P.Headers{r, [], False{}}), P.feed(B.append(content, 13 <> 10 <> tail), P.Headers{r, [], False{}}), P.feed(tail, P.push_header(r, R.Header{n, v})), e1,
        Equal.trans(P.State & R.ParseResult, P.feed(B.append(content, 13 <> 10 <> tail), P.Headers{r, [], False{}}), P.feed(tail, P.header_line(r, content)), P.feed(tail, P.push_header(r, R.Header{n, v})), e2, e3))

def Laws.header_suffix(h, body, tail):
  match h:
    case R.Header{n, v}:
      Equal.trans(List<&2, U32>, B.append(B.append(B.encode(n), 58 <> 32 <> B.append(v, 13 <> 10 <> body)), tail), B.append(B.encode(n), B.append(58 <> 32 <> B.append(v, 13 <> 10 <> body), tail)), B.append(B.encode(n), 58 <> 32 <> B.append(v, 13 <> 10 <> B.append(body, tail))), Laws.append_assoc(B.encode(n), 58 <> 32 <> B.append(v, 13 <> 10 <> body), tail), Equal.trans(List<&2, U32>, B.append(B.encode(n), B.append(58 <> 32 <> B.append(v, 13 <> 10 <> body), tail)), B.append(B.encode(n), 58 <> 32 <> B.append(B.append(v, 13 <> 10 <> body), tail)), B.append(B.encode(n), 58 <> 32 <> B.append(v, 13 <> 10 <> B.append(body, tail))), Equal.cong(List<&2, U32>, List<&2, U32>, l => B.append(B.encode(n), l), B.append(58 <> 32 <> B.append(v, 13 <> 10 <> body), tail), 58 <> 32 <> B.append(B.append(v, 13 <> 10 <> body), tail), append_cons2(58, 32, B.append(v, 13 <> 10 <> body), tail)), Equal.trans(List<&2, U32>, B.append(B.encode(n), 58 <> 32 <> B.append(B.append(v, 13 <> 10 <> body), tail)), B.append(B.encode(n), 58 <> 32 <> B.append(v, B.append(13 <> 10 <> body, tail))), B.append(B.encode(n), 58 <> 32 <> B.append(v, 13 <> 10 <> B.append(body, tail))), Equal.cong(List<&2, U32>, List<&2, U32>, l => B.append(B.encode(n), 58 <> 32 <> l), B.append(B.append(v, 13 <> 10 <> body), tail), B.append(v, B.append(13 <> 10 <> body, tail)), Laws.append_assoc(v, 13 <> 10 <> body, tail)), Equal.cong(List<&2, U32>, List<&2, U32>, l => B.append(B.encode(n), 58 <> 32 <> B.append(v, l)), B.append(13 <> 10 <> body, tail), 13 <> 10 <> B.append(body, tail), append_cons2(13, 10, body, tail)))))

# Generalized over already accumulated headers and any trailing input.

def Laws.scan_headers_octets(hs, m, p, q, v, acc, tail, ok, bytes):
  match hs:
    case Nil{}:
      {==}
    case h <> t:
      +r = {R.Req{m, p, q, v, acc} : R.Req}
      +suffix = B.append(W.headers(t), tail)
      e1 = Laws.scan_header_octets(r, h, suffix, Laws.and_left(R.header_valid(h), R.headers_valid(t), ok), Laws.and_left(B.value(Support.header_content(h)), Support.headers_scannable(t), bytes))
      e2 = Laws.scan_headers_octets(t, m, p, q, v, h <> acc, tail, Laws.and_right(R.header_valid(h), R.headers_valid(t), ok), Laws.and_right(B.value(Support.header_content(h)), Support.headers_scannable(t), bytes))
      -target = P.feed(tail, P.finish(R.Req{m, p, q, v, List.reverse.go(&2, R.Header, t, h <> acc)}))
      e0 = Equal.cong(List<&2, U32>, P.State & R.ParseResult, xs => P.feed(xs, P.Headers{r, [], False{}}), B.append(W.header(h, W.headers(t)), tail), W.header(h, suffix), Laws.header_suffix(h, W.headers(t), tail))
      Equal.trans(P.State & R.ParseResult, P.feed(B.append(W.header(h, W.headers(t)), tail), P.Headers{r, [], False{}}), P.feed(W.header(h, suffix), P.Headers{r, [], False{}}), target, e0,
        Equal.trans(P.State & R.ParseResult, P.feed(W.header(h, suffix), P.Headers{r, [], False{}}), P.feed(suffix, P.push_header(r, h)), target, e1, e2))

def ascii_embed_7(bits: Word(7n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_7(+bits: Word(7n), ok: {B.tchar(ascii_embed_7(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_7(bits)) == True{} : Bool}:
  match bits:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(0) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(1) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(2) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(3) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(4) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(5) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(6) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(7) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(8) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(9) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(10) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(11) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(12) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(13) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(14) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(15) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(16) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(17) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(18) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(19) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(20) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(21) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(22) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(23) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(24) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(25) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(26) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(27) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(28) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(29) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(30) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(31) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      E.absurd({Support.printable_octet(127) == True{} : Bool}, E.false_true(ok))

def ascii_embed_8(bits: Word(8n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WNil{}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_8(+bits: Word(8n), ok: {B.tchar(ascii_embed_8(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_8(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{True{}, WNil{}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{False{}, WNil{}}}}}}}}}:
      tchar_stage_7(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}, ok)

def ascii_embed_9(bits: Word(9n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WNil{}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_9(+bits: Word(9n), ok: {B.tchar(ascii_embed_9(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_9(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{True{}, WNil{}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{False{}, WNil{}}}}}}}}}}:
      tchar_stage_8(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WNil{}}}}}}}}}, ok)

def ascii_embed_10(bits: Word(10n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WNil{}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_10(+bits: Word(10n), ok: {B.tchar(ascii_embed_10(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_10(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{True{}, WNil{}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{False{}, WNil{}}}}}}}}}}}:
      tchar_stage_9(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WNil{}}}}}}}}}}, ok)

def ascii_embed_11(bits: Word(11n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_11(+bits: Word(11n), ok: {B.tchar(ascii_embed_11(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_11(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{True{}, WNil{}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{False{}, WNil{}}}}}}}}}}}}:
      tchar_stage_10(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WNil{}}}}}}}}}}}, ok)

def ascii_embed_12(bits: Word(12n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WNil{}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_12(+bits: Word(12n), ok: {B.tchar(ascii_embed_12(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_12(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{True{}, WNil{}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{False{}, WNil{}}}}}}}}}}}}}:
      tchar_stage_11(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}, ok)

def ascii_embed_13(bits: Word(13n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WNil{}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_13(+bits: Word(13n), ok: {B.tchar(ascii_embed_13(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_13(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{True{}, WNil{}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{False{}, WNil{}}}}}}}}}}}}}}:
      tchar_stage_12(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WNil{}}}}}}}}}}}}}, ok)

def ascii_embed_14(bits: Word(14n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WNil{}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_14(+bits: Word(14n), ok: {B.tchar(ascii_embed_14(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_14(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{True{}, WNil{}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{False{}, WNil{}}}}}}}}}}}}}}}:
      tchar_stage_13(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WNil{}}}}}}}}}}}}}}, ok)

def ascii_embed_15(bits: Word(15n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WNil{}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_15(+bits: Word(15n), ok: {B.tchar(ascii_embed_15(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_15(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{True{}, WNil{}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{False{}, WNil{}}}}}}}}}}}}}}}}:
      tchar_stage_14(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WNil{}}}}}}}}}}}}}}}, ok)

def ascii_embed_16(bits: Word(16n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_16(+bits: Word(16n), ok: {B.tchar(ascii_embed_16(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_16(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}:
      tchar_stage_15(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WNil{}}}}}}}}}}}}}}}}, ok)

def ascii_embed_17(bits: Word(17n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WNil{}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_17(+bits: Word(17n), ok: {B.tchar(ascii_embed_17(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_17(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}:
      tchar_stage_16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_18(bits: Word(18n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WNil{}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_18(+bits: Word(18n), ok: {B.tchar(ascii_embed_18(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_18(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}:
      tchar_stage_17(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WNil{}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_19(bits: Word(19n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WNil{}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_19(+bits: Word(19n), ok: {B.tchar(ascii_embed_19(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_19(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_18(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WNil{}}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_20(bits: Word(20n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WNil{}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_20(+bits: Word(20n), ok: {B.tchar(ascii_embed_20(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_20(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_19(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WNil{}}}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_21(bits: Word(21n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WNil{}}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_21(+bits: Word(21n), ok: {B.tchar(ascii_embed_21(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_21(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_20(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WNil{}}}}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_22(bits: Word(22n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WNil{}}}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_22(+bits: Word(22n), ok: {B.tchar(ascii_embed_22(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_22(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_21(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WNil{}}}}}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_23(bits: Word(23n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WNil{}}}}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_23(+bits: Word(23n), ok: {B.tchar(ascii_embed_23(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_23(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_22(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WNil{}}}}}}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_24(bits: Word(24n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_24(+bits: Word(24n), ok: {B.tchar(ascii_embed_24(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_24(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_23(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WNil{}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_25(bits: Word(25n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_25(+bits: Word(25n), ok: {B.tchar(ascii_embed_25(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_25(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_24(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_26(bits: Word(26n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_26(+bits: Word(26n), ok: {B.tchar(ascii_embed_26(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_26(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_25(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_27(bits: Word(27n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_27(+bits: Word(27n), ok: {B.tchar(ascii_embed_27(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_27(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_26(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_28(bits: Word(28n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_28(+bits: Word(28n), ok: {B.tchar(ascii_embed_28(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_28(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_27(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_29(bits: Word(29n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_29(+bits: Word(29n), ok: {B.tchar(ascii_embed_29(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_29(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_28(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_30(bits: Word(30n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_30(+bits: Word(30n), ok: {B.tchar(ascii_embed_30(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_30(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_29(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_31(bits: Word(31n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_31(+bits: Word(31n), ok: {B.tchar(ascii_embed_31(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_31(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{True{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_30(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def ascii_embed_32(bits: Word(32n)) -> U32:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def tchar_stage_32(+bits: Word(32n), ok: {B.tchar(ascii_embed_32(bits)) == True{} : Bool}) -> {Support.printable_octet(ascii_embed_32(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({Support.printable_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_31(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def Laws.tchar_printable(c, ok):
  match c:
    case U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      tchar_stage_32(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_7(+bits: Word(7n), ok: {Support.printable_octet(ascii_embed_7(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_7(bits)) == True{} : Bool}:
  match bits:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(0) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(1) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(2) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(3) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(4) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(5) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(6) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(7) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(8) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(9) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(10) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(11) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(12) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(13) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(14) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(15) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(16) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(17) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(18) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(19) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(20) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(21) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(22) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(23) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(24) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(25) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(26) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(27) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(28) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(29) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(30) == True{} : Bool}, E.false_true(ok))
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(31) == True{} : Bool}, E.false_true(ok))
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}:
      E.absurd({B.value_octet(127) == True{} : Bool}, E.false_true(ok))

def printable_value_stage_8(+bits: Word(8n), ok: {Support.printable_octet(ascii_embed_8(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_8(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{True{}, WNil{}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{False{}, WNil{}}}}}}}}}:
      printable_value_stage_7(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}, ok)

def printable_value_stage_9(+bits: Word(9n), ok: {Support.printable_octet(ascii_embed_9(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_9(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{True{}, WNil{}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{False{}, WNil{}}}}}}}}}}:
      printable_value_stage_8(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WNil{}}}}}}}}}, ok)

def printable_value_stage_10(+bits: Word(10n), ok: {Support.printable_octet(ascii_embed_10(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_10(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{True{}, WNil{}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{False{}, WNil{}}}}}}}}}}}:
      printable_value_stage_9(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WNil{}}}}}}}}}}, ok)

def printable_value_stage_11(+bits: Word(11n), ok: {Support.printable_octet(ascii_embed_11(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_11(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{True{}, WNil{}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{False{}, WNil{}}}}}}}}}}}}:
      printable_value_stage_10(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WNil{}}}}}}}}}}}, ok)

def printable_value_stage_12(+bits: Word(12n), ok: {Support.printable_octet(ascii_embed_12(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_12(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{True{}, WNil{}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{False{}, WNil{}}}}}}}}}}}}}:
      printable_value_stage_11(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}, ok)

def printable_value_stage_13(+bits: Word(13n), ok: {Support.printable_octet(ascii_embed_13(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_13(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{True{}, WNil{}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{False{}, WNil{}}}}}}}}}}}}}}:
      printable_value_stage_12(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WNil{}}}}}}}}}}}}}, ok)

def printable_value_stage_14(+bits: Word(14n), ok: {Support.printable_octet(ascii_embed_14(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_14(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{True{}, WNil{}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{False{}, WNil{}}}}}}}}}}}}}}}:
      printable_value_stage_13(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WNil{}}}}}}}}}}}}}}, ok)

def printable_value_stage_15(+bits: Word(15n), ok: {Support.printable_octet(ascii_embed_15(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_15(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{True{}, WNil{}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{False{}, WNil{}}}}}}}}}}}}}}}}:
      printable_value_stage_14(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WNil{}}}}}}}}}}}}}}}, ok)

def printable_value_stage_16(+bits: Word(16n), ok: {Support.printable_octet(ascii_embed_16(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_16(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}:
      printable_value_stage_15(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WNil{}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_17(+bits: Word(17n), ok: {Support.printable_octet(ascii_embed_17(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_17(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}:
      printable_value_stage_16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_18(+bits: Word(18n), ok: {Support.printable_octet(ascii_embed_18(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_18(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_17(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WNil{}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_19(+bits: Word(19n), ok: {Support.printable_octet(ascii_embed_19(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_19(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_18(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WNil{}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_20(+bits: Word(20n), ok: {Support.printable_octet(ascii_embed_20(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_20(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_19(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WNil{}}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_21(+bits: Word(21n), ok: {Support.printable_octet(ascii_embed_21(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_21(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_20(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WNil{}}}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_22(+bits: Word(22n), ok: {Support.printable_octet(ascii_embed_22(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_22(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_21(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WNil{}}}}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_23(+bits: Word(23n), ok: {Support.printable_octet(ascii_embed_23(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_23(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_22(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WNil{}}}}}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_24(+bits: Word(24n), ok: {Support.printable_octet(ascii_embed_24(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_24(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_23(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WNil{}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_25(+bits: Word(25n), ok: {Support.printable_octet(ascii_embed_25(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_25(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_24(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_26(+bits: Word(26n), ok: {Support.printable_octet(ascii_embed_26(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_26(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_25(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_27(+bits: Word(27n), ok: {Support.printable_octet(ascii_embed_27(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_27(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_26(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_28(+bits: Word(28n), ok: {Support.printable_octet(ascii_embed_28(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_28(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_27(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_29(+bits: Word(29n), ok: {Support.printable_octet(ascii_embed_29(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_29(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_28(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_30(+bits: Word(30n), ok: {Support.printable_octet(ascii_embed_30(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_30(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_29(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_31(+bits: Word(31n), ok: {Support.printable_octet(ascii_embed_31(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_31(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{True{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_30(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def printable_value_stage_32(+bits: Word(32n), ok: {Support.printable_octet(ascii_embed_32(bits)) == True{} : Bool}) -> {B.value_octet(ascii_embed_32(bits)) == True{} : Bool}:
  match bits:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({B.value_octet(U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}) == True{} : Bool}, E.false_true(ok))
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_31(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def Laws.printable_value_octet(c, ok):
  match c:
    case U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      printable_value_stage_32(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, ok)

def and_true(a: Bool, b: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}) -> {a && b == True{} : Bool}:
  match a:
    case False{}:
      E.absurd({False{} && b == True{} : Bool}, E.false_true(ea))
    case True{}:
      eb

def value_append_spec(+xs: List<&2, U32>, +ys: List<&2, U32>, +xok: {B.value_spec(xs) == True{} : Bool}, +yok: {B.value_spec(ys) == True{} : Bool}) -> {B.value_spec(List.append(&2, U32, xs, ys)) == True{} : Bool}:
  match xs:
    case Nil{}:
      yok
    case c <> t:
      and_true(B.value_octet(c), B.value_spec(List.append(&2, U32, t, ys)), Laws.and_left(B.value_octet(c), B.value_spec(t), xok), value_append_spec(t, ys, Laws.and_right(B.value_octet(c), B.value_spec(t), xok), yok))

def Laws.value_append(xs, ys, xok, yok):
  Equal.trans(Bool, B.value(B.append(xs, ys)), B.value_spec(B.append(xs, ys)), True{}, BT.value_equiv(B.append(xs, ys)), Equal.trans(Bool, B.value_spec(B.append(xs, ys)), B.value_spec(List.append(&2, U32, xs, ys)), True{}, Equal.cong(List<&2, U32>, Bool, l => B.value_spec(l), B.append(xs, ys), List.append(&2, U32, xs, ys), BT.append_equiv(xs, ys)), value_append_spec(xs, ys, value_ok(xs, xok), value_ok(ys, yok))))


def token_tail_value_spec(+s: String, +ok: {B.token_tail_spec(s) == True{} : Bool}) -> {B.value_spec(B.encode_spec(s)) == True{} : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      and_true(B.value_octet(c), B.value_spec(B.encode_spec(t)), Laws.printable_value_octet(c, Laws.tchar_printable(c, Laws.and_left(B.tchar(c), B.token_tail_spec(t), ok))), token_tail_value_spec(t, Laws.and_right(B.tchar(c), B.token_tail_spec(t), ok)))

def value_encode_spec(+s: String, ok: {B.value_spec(B.encode_spec(s)) == True{} : Bool}) -> {B.value(B.encode(s)) == True{} : Bool}:
  Equal.trans(Bool, B.value(B.encode(s)), B.value_spec(B.encode(s)), True{}, BT.value_equiv(B.encode(s)), Equal.trans(Bool, B.value_spec(B.encode(s)), B.value_spec(B.encode_spec(s)), True{}, Equal.cong(List<&2, U32>, Bool, l => B.value_spec(l), B.encode(s), B.encode_spec(s), BT.encode_equiv(s)), ok))

def Laws.token_tail_value(s, ok):
  value_encode_spec(s, token_tail_value_spec(s, tail_ok(s, ok)))


def Laws.token_value(s, ok):
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      value_encode_spec(SCon{Chr{c}, t}, token_tail_value_spec(SCon{Chr{c}, t}, token_spec_ok(c, t, ok)))

def Laws.header_scannable_valid(h, ok):
  match h:
    case R.Header{n, v}:
      +e4 = Laws.and_left(B.token(n) && String.eq(n, B.fold(n)) && B.value(v) && R.value_start(v), R.value_start(List.reverse(&2, U32, v)), ok)
      +e3 = Laws.and_left(B.token(n) && String.eq(n, B.fold(n)) && B.value(v), R.value_start(v), e4)
      +e2 = Laws.and_left(B.token(n) && String.eq(n, B.fold(n)), B.value(v), e3)
      tok = Laws.and_left(B.token(n), String.eq(n, B.fold(n)), e2)
      val = Laws.and_right(B.token(n) && String.eq(n, B.fold(n)), B.value(v), e3)
      Laws.value_append(B.encode(n), 58 <> 32 <> v, Laws.token_value(n, tok), val)

def Laws.headers_scannable_valid(hs, ok):
  match hs:
    case Nil{}:
      {==}
    case h <> t:
      and_true(B.value(Support.header_content(h)), Support.headers_scannable(t), Laws.header_scannable_valid(h, Laws.and_left(R.header_valid(h), R.headers_valid(t), ok)), Laws.headers_scannable_valid(t, Laws.and_right(R.header_valid(h), R.headers_valid(t), ok)))

def Laws.scan_header(r, h, tail, ok):
  Laws.scan_header_octets(r, h, tail, ok, Laws.header_scannable_valid(h, ok))

def Laws.scan_headers(hs, m, p, q, v, acc, tail, ok):
  Laws.scan_headers_octets(hs, m, p, q, v, acc, tail, ok, Laws.headers_scannable_valid(hs, ok))

def printable_append_list(+xs: List<&2, U32>, +ys: List<&2, U32>, +xok: {Support.printable(xs) == True{} : Bool}, +yok: {Support.printable(ys) == True{} : Bool}) -> {Support.printable(List.append(&2, U32, xs, ys)) == True{} : Bool}:
  match xs:
    case Nil{}:
      yok
    case c <> t:
      and_true(Support.printable_octet(c), Support.printable(List.append(&2, U32, t, ys)), Laws.and_left(Support.printable_octet(c), Support.printable(t), xok), printable_append_list(t, ys, Laws.and_right(Support.printable_octet(c), Support.printable(t), xok), yok))

def Laws.printable_append(xs, ys, xok, yok):
  Equal.trans(Bool, Support.printable(B.append(xs, ys)), Support.printable(List.append(&2, U32, xs, ys)), True{}, Equal.cong(List<&2, U32>, Bool, l => Support.printable(l), B.append(xs, ys), List.append(&2, U32, xs, ys), BT.append_equiv(xs, ys)), printable_append_list(xs, ys, xok, yok))


def token_tail_printable_spec(+s: String, +ok: {B.token_tail_spec(s) == True{} : Bool}) -> {Support.printable(B.encode_spec(s)) == True{} : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      and_true(Support.printable_octet(c), Support.printable(B.encode_spec(t)), Laws.tchar_printable(c, Laws.and_left(B.tchar(c), B.token_tail_spec(t), ok)), token_tail_printable_spec(t, Laws.and_right(B.tchar(c), B.token_tail_spec(t), ok)))

def printable_encode_spec(+s: String, ok: {Support.printable(B.encode_spec(s)) == True{} : Bool}) -> {Support.printable(B.encode(s)) == True{} : Bool}:
  Equal.trans(Bool, Support.printable(B.encode(s)), Support.printable(B.encode_spec(s)), True{}, Equal.cong(List<&2, U32>, Bool, l => Support.printable(l), B.encode(s), B.encode_spec(s), BT.encode_equiv(s)), ok)

def Laws.token_tail_printable(s, ok):
  printable_encode_spec(s, token_tail_printable_spec(s, tail_ok(s, ok)))


def Laws.token_printable(s, ok):
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      printable_encode_spec(SCon{Chr{c}, t}, token_tail_printable_spec(SCon{Chr{c}, t}, token_spec_ok(c, t, ok)))
