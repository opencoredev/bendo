# Bridges to an independent response observer; no writer helpers define the spec.
import Base
import ./review-tail.bend as ReviewTail
import ./response-spec.bend as Spec
import ../src/http/bytes.bend as B
import ../src/http/request.bend as R
import ../src/http/parse.bend as P
import ../src/http/write.bend as RequestWrite
import ../src/http/write_response.bend as W
import ../src/http/response.bend as Response
import ../LAWS.bend as Laws
import ./equality.bend as E
import ./headers.bend as Headers
import ./scanner.bend as Scanner
import ./tokens.bend as Tokens
import ./response-lines.bend as Lines
import ./support.bend as Support
import ./response-framing.bend as Framing
import ./bytes-tail.bend as BT

# Structural side condition: there is no delimiter at any earlier offset.
# Unlike split_first, this never searches for or returns a split.
def first_at(+prefix: List<&2, U32>, +suffix: List<&2, U32>) -> Bool:
  match prefix:
    case Nil{}:
      True{}
    case c <> tail:
      Bool.not(Spec.starts_delimiter(c <> List.append(&2, U32, tail, 13 <> 10 <> 13 <> 10 <> suffix))) && first_at(tail, suffix)

def split_at(+prefix: List<&2, U32>, +suffix: List<&2, U32>, +ok: {first_at(prefix, suffix) == True{} : Bool}) -> {Spec.split_first(List.append(&2, U32, prefix, 13 <> 10 <> 13 <> 10 <> suffix)) == Some{(prefix, suffix)} : Maybe<&2, Spec.BytePair()>}:
  match prefix:
    case Nil{}:
      {==}
    case c <> tail:
      +here = Spec.starts_delimiter(c <> List.append(&2, U32, tail, 13 <> 10 <> 13 <> 10 <> suffix))
      no = Tokens.not_true_false(here, Laws.and_left(Bool.not(here), first_at(tail, suffix), ok))
      %Equal.sym(Bool, here, False{}, no) : {Spec.split_step(c, List.append(&2, U32, tail, 13 <> 10 <> 13 <> 10 <> suffix), _, Spec.split_first(List.append(&2, U32, tail, 13 <> 10 <> 13 <> 10 <> suffix))) == Some{(c <> tail, suffix)} : Maybe<&2, Spec.BytePair()>}
      Equal.cong(Maybe<&2, Spec.BytePair()>, Maybe<&2, Spec.BytePair()>, found => Spec.split_push(c, found), Spec.split_first(List.append(&2, U32, tail, 13 <> 10 <> 13 <> 10 <> suffix)), Some{(tail, suffix)}, split_at(tail, suffix, Laws.and_right(Bool.not(here), first_at(tail, suffix), ok)))

# Exact writer split, conditional only on the independently stated first offset.
def writer_split(+m: R.Method, +r: Response.Res, ok: {first_at(W.prefix(m, r), W.payload(m, r)) == True{} : Bool}) -> {Spec.split_first(W.serialize(m, r)) == Some{(W.prefix(m, r), W.payload(m, r))} : Maybe<&2, Spec.BytePair()>}:
  Equal.trans(Maybe<&2, Spec.BytePair()>, Spec.split_first(W.serialize(m, r)), Spec.split_first(List.append(&2, U32, W.prefix(m, r), 13 <> 10 <> 13 <> 10 <> W.payload(m, r))), Some{(W.prefix(m, r), W.payload(m, r))}, Equal.cong(List<&2, U32>, Maybe<&2, Spec.BytePair()>, l => Spec.split_first(l), W.serialize(m, r), List.append(&2, U32, W.prefix(m, r), 13 <> 10 <> 13 <> 10 <> W.payload(m, r)), Equal.trans(List<&2, U32>, W.serialize(m, r), List.append(&2, U32, B.append(W.prefix(m, r), [13, 10, 13, 10]), W.payload(m, r)), List.append(&2, U32, W.prefix(m, r), List.append(&2, U32, [13, 10, 13, 10], W.payload(m, r))), BT.append_equiv(B.append(W.prefix(m, r), [13, 10, 13, 10]), W.payload(m, r)), Equal.trans(List<&2, U32>, List.append(&2, U32, B.append(W.prefix(m, r), [13, 10, 13, 10]), W.payload(m, r)), List.append(&2, U32, List.append(&2, U32, W.prefix(m, r), [13, 10, 13, 10]), W.payload(m, r)), List.append(&2, U32, W.prefix(m, r), List.append(&2, U32, [13, 10, 13, 10], W.payload(m, r))), Equal.cong(List<&2, U32>, List<&2, U32>, l => List.append(&2, U32, l, W.payload(m, r)), B.append(W.prefix(m, r), [13, 10, 13, 10]), List.append(&2, U32, W.prefix(m, r), [13, 10, 13, 10]), BT.append_equiv(W.prefix(m, r), [13, 10, 13, 10])), Scanner.append_assoc_list(W.prefix(m, r), [13, 10, 13, 10], W.payload(m, r))))), split_at(W.prefix(m, r), W.payload(m, r), ok))


def headers_roundtrip(+hs: List<&2, R.Header>, +ok: {R.headers_valid(hs) == True{} : Bool}) -> {Spec.parse_headers(RequestWrite.headers(hs)) == Some{hs} : Maybe<&2, List<&2, R.Header>>}:
  scan = Laws.scan_headers_octets(hs, R.Get{}, "/", None{}, R.Http11{}, [], [], ok, Laws.headers_scannable_valid(hs, ok))
  empty = Equal.trans(List<&2, U32>, B.append(RequestWrite.headers(hs), []), List.append(&2, U32, RequestWrite.headers(hs), []), RequestWrite.headers(hs), BT.append_equiv(RequestWrite.headers(hs), []), Laws.append_nil(U32, RequestWrite.headers(hs)))
  %empty : {Spec.parse_headers(_) == Some{hs} : Maybe<&2, List<&2, R.Header>>}
  %Equal.sym(P.State & R.ParseResult, P.feed(B.append(RequestWrite.headers(hs), []), P.Headers{Spec.request([]), [], False{}}), P.feed([], P.finish(Spec.request(List.reverse(&2, R.Header, hs)))), scan) : {Spec.parsed_headers(P.result(_)) == Some{hs} : Maybe<&2, List<&2, R.Header>>}
  Equal.cong(List<&2, R.Header>, Maybe<&2, List<&2, R.Header>>, xs => Some{xs}, List.reverse(&2, R.Header, List.reverse(&2, R.Header, hs)), hs, Laws.reverse_twice(R.Header, hs))

# The response writer's leading-CRLF convention equals BND-7's trailing-CRLF
# convention once the status line's CRLF and final empty line are accounted for.
# Bytes.encode no longer unfolds on a literal prefix (BND-84).
def encode_crlf(+x: String) -> {B.encode("\r\n" ++ x) == 13 <> 10 <> B.encode(x) : List<&2, U32>}:
  Lines.encode_append("\r\n", x)

def headers_bytes(+hs: List<&2, R.Header>) -> {B.append(B.encode(W.headers_text(hs)), [13, 10, 13, 10]) == 13 <> 10 <> RequestWrite.headers(hs) : List<&2, U32>}:
  match hs:
    case Nil{}:
      {==}
    case +h <> +tail:
      %Equal.sym(List<&2, U32>, RequestWrite.headers(h <> tail), RequestWrite.header(h, RequestWrite.headers(tail)), ReviewTail.write_headers_unfold(h, tail)) : {B.append(B.encode(W.headers_text(h <> tail)), [13, 10, 13, 10]) == 13 <> 10 <> _ : List<&2, U32>}
      Equal.trans(List<&2, U32>, B.append(B.encode("\r\n" ++ W.header_text(h) ++ W.headers_text(tail)), [13, 10, 13, 10]), B.append(13 <> 10 <> B.encode(W.header_text(h) ++ W.headers_text(tail)), [13, 10, 13, 10]), 13 <> 10 <> RequestWrite.header(h, RequestWrite.headers(tail)), Equal.cong(List<&2, U32>, List<&2, U32>, l => B.append(l, [13, 10, 13, 10]), B.encode("\r\n" ++ W.header_text(h) ++ W.headers_text(tail)), 13 <> 10 <> B.encode(W.header_text(h) ++ W.headers_text(tail)), encode_crlf(W.header_text(h) ++ W.headers_text(tail))), Equal.trans(List<&2, U32>, B.append(13 <> 10 <> B.encode(W.header_text(h) ++ W.headers_text(tail)), [13, 10, 13, 10]), 13 <> 10 <> B.append(B.encode(W.header_text(h) ++ W.headers_text(tail)), [13, 10, 13, 10]), 13 <> 10 <> RequestWrite.header(h, RequestWrite.headers(tail)), Scanner.append_cons2(13, 10, B.encode(W.header_text(h) ++ W.headers_text(tail)), [13, 10, 13, 10]), Equal.trans(List<&2, U32>, 13 <> 10 <> B.append(B.encode(W.header_text(h) ++ W.headers_text(tail)), [13, 10, 13, 10]), 13 <> 10 <> B.append(B.append(B.encode(W.header_text(h)), B.encode(W.headers_text(tail))), [13, 10, 13, 10]), 13 <> 10 <> RequestWrite.header(h, RequestWrite.headers(tail)), Equal.cong(List<&2, U32>, List<&2, U32>, l => 13 <> 10 <> B.append(l, [13, 10, 13, 10]), B.encode(W.header_text(h) ++ W.headers_text(tail)), B.append(B.encode(W.header_text(h)), B.encode(W.headers_text(tail))), Lines.encode_append(W.header_text(h), W.headers_text(tail))), Equal.trans(List<&2, U32>, 13 <> 10 <> B.append(B.append(B.encode(W.header_text(h)), B.encode(W.headers_text(tail))), [13, 10, 13, 10]), 13 <> 10 <> B.append(B.encode(W.header_text(h)), B.append(B.encode(W.headers_text(tail)), [13, 10, 13, 10])), 13 <> 10 <> RequestWrite.header(h, RequestWrite.headers(tail)), Equal.cong(List<&2, U32>, List<&2, U32>, l => 13 <> 10 <> l, B.append(B.append(B.encode(W.header_text(h)), B.encode(W.headers_text(tail))), [13, 10, 13, 10]), B.append(B.encode(W.header_text(h)), B.append(B.encode(W.headers_text(tail)), [13, 10, 13, 10])), Laws.append_assoc(B.encode(W.header_text(h)), B.encode(W.headers_text(tail)), [13, 10, 13, 10])), Equal.trans(List<&2, U32>, 13 <> 10 <> B.append(B.encode(W.header_text(h)), B.append(B.encode(W.headers_text(tail)), [13, 10, 13, 10])), 13 <> 10 <> B.append(B.encode(W.header_text(h)), 13 <> 10 <> RequestWrite.headers(tail)), 13 <> 10 <> RequestWrite.header(h, RequestWrite.headers(tail)), Equal.cong(List<&2, U32>, List<&2, U32>, l => 13 <> 10 <> B.append(B.encode(W.header_text(h)), l), B.append(B.encode(W.headers_text(tail)), [13, 10, 13, 10]), 13 <> 10 <> RequestWrite.headers(tail), headers_bytes(tail)), Equal.trans(List<&2, U32>, 13 <> 10 <> B.append(B.encode(W.header_text(h)), 13 <> 10 <> RequestWrite.headers(tail)), 13 <> 10 <> B.append(Support.header_content(h), 13 <> 10 <> RequestWrite.headers(tail)), 13 <> 10 <> RequestWrite.header(h, RequestWrite.headers(tail)), Equal.cong(List<&2, U32>, List<&2, U32>, l => 13 <> 10 <> B.append(l, 13 <> 10 <> RequestWrite.headers(tail)), B.encode(W.header_text(h)), Support.header_content(h), Lines.header_encode(h)), Equal.cong(List<&2, U32>, List<&2, U32>, l => 13 <> 10 <> l, B.append(Support.header_content(h), 13 <> 10 <> RequestWrite.headers(tail)), RequestWrite.header(h, RequestWrite.headers(tail)), Equal.sym(List<&2, U32>, RequestWrite.header(h, RequestWrite.headers(tail)), B.append(Support.header_content(h), 13 <> 10 <> RequestWrite.headers(tail)), Laws.header_bytes(h, RequestWrite.headers(tail))))))))))

# The headers after the status-line CRLF parse to the writer's exact list.
def response_headers_roundtrip(+m: R.Method, +r: Response.Res, +ok: {R.headers_valid(W.response_headers(m, r)) == True{} : Bool}) -> {Spec.parse_headers(RequestWrite.headers(W.response_headers(m, r))) == Some{W.response_headers(m, r)} : Maybe<&2, List<&2, R.Header>>}:
  headers_roundtrip(W.response_headers(m, r), ok)

# Valid line data cannot start a delimiter, even across concatenation boundaries.
def starts_not_cr(+c: U32, +tail: List<&2, U32>, no: {U32.is_eq(c, 13) == False{} : Bool}) -> {Spec.starts_delimiter(c <> tail) == False{} : Bool}:
  %Equal.sym(Bool, U32.is_eq(c, 13), False{}, no) : {_ && Spec.delimiter_tail(tail) == False{} : Bool}
  {==}

def starts_crlf_not_cr(+c: U32, +tail: List<&2, U32>, no: {U32.is_eq(c, 13) == False{} : Bool}) -> {Spec.starts_delimiter(13 <> 10 <> c <> tail) == False{} : Bool}:
  match tail:
    case Nil{}:
      {==}
    case d <> rest:
      %Equal.sym(Bool, U32.is_eq(c, 13), False{}, no) : {_ && U32.is_eq(d, 10) == False{} : Bool}
      {==}

def first_value(+line: List<&2, U32>, +rest: List<&2, U32>, +suffix: List<&2, U32>, +valid: {B.value_spec(line) == True{} : Bool}, ok: {first_at(rest, suffix) == True{} : Bool}) -> {first_at(List.append(&2, U32, line, rest), suffix) == True{} : Bool}:
  match line:
    case Nil{}:
      ok
    case c <> tail:
      no = Lines.value_not_cr(c, Laws.and_left(B.value_octet(c), B.value_spec(tail), valid))
      %Equal.sym(Bool, Spec.starts_delimiter(c <> List.append(&2, U32, List.append(&2, U32, tail, rest), 13 <> 10 <> 13 <> 10 <> suffix)), False{}, starts_not_cr(c, List.append(&2, U32, List.append(&2, U32, tail, rest), 13 <> 10 <> 13 <> 10 <> suffix), no)) : {Bool.not(_) && first_at(List.append(&2, U32, tail, rest), suffix) == True{} : Bool}
      first_value(tail, rest, suffix, Laws.and_right(B.value_octet(c), B.value_spec(tail), valid), ok)

def first_separated(+c: U32, +line: List<&2, U32>, +rest: List<&2, U32>, +suffix: List<&2, U32>, +valid: {B.value_spec(c <> line) == True{} : Bool}, ok: {first_at(rest, suffix) == True{} : Bool}) -> {first_at(13 <> 10 <> List.append(&2, U32, c <> line, rest), suffix) == True{} : Bool}:
  no = Lines.value_not_cr(c, Laws.and_left(B.value_octet(c), B.value_spec(line), valid))
  %Equal.sym(Bool, Spec.starts_delimiter(13 <> 10 <> c <> List.append(&2, U32, List.append(&2, U32, line, rest), 13 <> 10 <> 13 <> 10 <> suffix)), False{}, starts_crlf_not_cr(c, List.append(&2, U32, List.append(&2, U32, line, rest), 13 <> 10 <> 13 <> 10 <> suffix), no)) : {Bool.not(_) && first_at(10 <> List.append(&2, U32, c <> line, rest), suffix) == True{} : Bool}
  first_value(c <> line, rest, suffix, valid, ok)

def first_header_name(+n: String, +v: List<&2, U32>, +rest: List<&2, U32>, +suffix: List<&2, U32>, valid: {B.value_spec(List.append(&2, U32, B.encode_spec(n), 58 <> 32 <> v)) == True{} : Bool}, ok: {first_at(rest, suffix) == True{} : Bool}) -> {first_at(13 <> 10 <> List.append(&2, U32, List.append(&2, U32, B.encode_spec(n), 58 <> 32 <> v), rest), suffix) == True{} : Bool}:
  match n:
    case SNil{}:
      first_separated(58, 32 <> v, rest, suffix, valid, ok)
    case SCon{Chr{c}, t}:
      first_separated(c, List.append(&2, U32, B.encode_spec(t), 58 <> 32 <> v), rest, suffix, valid, ok)

def first_header(+h: R.Header, +rest: List<&2, U32>, +suffix: List<&2, U32>, valid: {B.value(Support.header_content(h)) == True{} : Bool}, ok: {first_at(rest, suffix) == True{} : Bool}) -> {first_at(13 <> 10 <> List.append(&2, U32, Support.header_content(h), rest), suffix) == True{} : Bool}:
  match h:
    case R.Header{n, v}:
      +w = Headers.wire_equiv(n, 58 <> 32 <> v)
      spec = Equal.trans(Bool, B.value_spec(List.append(&2, U32, B.encode_spec(n), 58 <> 32 <> v)), B.value_spec(B.append(B.encode(n), 58 <> 32 <> v)), True{}, Equal.cong(List<&2, U32>, Bool, l => B.value_spec(l), List.append(&2, U32, B.encode_spec(n), 58 <> 32 <> v), B.append(B.encode(n), 58 <> 32 <> v), Equal.sym(List<&2, U32>, B.append(B.encode(n), 58 <> 32 <> v), List.append(&2, U32, B.encode_spec(n), 58 <> 32 <> v), w)), Scanner.value_ok(B.append(B.encode(n), 58 <> 32 <> v), valid))
      %Equal.sym(List<&2, U32>, B.append(B.encode(n), 58 <> 32 <> v), List.append(&2, U32, B.encode_spec(n), 58 <> 32 <> v), w) : {first_at(13 <> 10 <> List.append(&2, U32, _, rest), suffix) == True{} : Bool}
      first_header_name(n, v, rest, suffix, spec, ok)


def first_headers(+hs: List<&2, R.Header>, +suffix: List<&2, U32>, +valid: {Support.headers_scannable(hs) == True{} : Bool}) -> {first_at(B.encode(W.headers_text(hs)), suffix) == True{} : Bool}:
  match hs:
    case Nil{}:
      {==}
    case +h <> +tail:
      %Equal.sym(List<&2, U32>, B.encode("\r\n" ++ W.header_text(h) ++ W.headers_text(tail)), 13 <> 10 <> B.encode(W.header_text(h) ++ W.headers_text(tail)), encode_crlf(W.header_text(h) ++ W.headers_text(tail))) : {first_at(_, suffix) == True{} : Bool}
      %Equal.sym(List<&2, U32>, B.encode(W.header_text(h) ++ W.headers_text(tail)), B.append(B.encode(W.header_text(h)), B.encode(W.headers_text(tail))), Lines.encode_append(W.header_text(h), W.headers_text(tail))) : {first_at(13 <> 10 <> _, suffix) == True{} : Bool}
      %Equal.sym(List<&2, U32>, B.encode(W.header_text(h)), Support.header_content(h), Lines.header_encode(h)) : {first_at(13 <> 10 <> B.append(_, B.encode(W.headers_text(tail))), suffix) == True{} : Bool}
      %Equal.sym(List<&2, U32>, B.append(Support.header_content(h), B.encode(W.headers_text(tail))), List.append(&2, U32, Support.header_content(h), B.encode(W.headers_text(tail))), BT.append_equiv(Support.header_content(h), B.encode(W.headers_text(tail)))) : {first_at(13 <> 10 <> _, suffix) == True{} : Bool}
      first_header(h, B.encode(W.headers_text(tail)), suffix, Laws.and_left(B.value(Support.header_content(h)), Support.headers_scannable(tail), valid), first_headers(tail, suffix, Laws.and_right(B.value(Support.header_content(h)), Support.headers_scannable(tail), valid)))


def writer_first_at(+m: R.Method, +r: Response.Res, +valid: {Response.valid(r) == True{} : Bool}) -> {first_at(W.prefix(m, r), W.payload(m, r)) == True{} : Bool}:
  match r:
    case Response.Res{s, hs, b, rep}:
      +res = {Response.Res{s, hs, b, rep} : Response.Res}
      %Equal.sym(List<&2, U32>, B.encode(W.status_text(s) ++ W.headers_text(W.response_headers(m, res))), B.append(B.encode(W.status_text(s)), B.encode(W.headers_text(W.response_headers(m, res)))), Lines.encode_append(W.status_text(s), W.headers_text(W.response_headers(m, res)))) : {first_at(_, W.payload(m, res)) == True{} : Bool}
      %Equal.sym(List<&2, U32>, B.append(B.encode(W.status_text(s)), B.encode(W.headers_text(W.response_headers(m, res)))), List.append(&2, U32, B.encode(W.status_text(s)), B.encode(W.headers_text(W.response_headers(m, res)))), BT.append_equiv(B.encode(W.status_text(s)), B.encode(W.headers_text(W.response_headers(m, res))))) : {first_at(_, W.payload(m, res)) == True{} : Bool}
      first_value(B.encode(W.status_text(s)), B.encode(W.headers_text(W.response_headers(m, res))), W.payload(m, res), Scanner.value_ok(B.encode(W.status_text(s)), Framing.status_value(s)), first_headers(W.response_headers(m, res), W.payload(m, res), Framing.response_scannable(m, res, valid)))

def split_valid(+m: R.Method, +r: Response.Res, +valid: {Response.valid(r) == True{} : Bool}) -> {Spec.split_first(W.serialize(m, r)) == Some{(W.prefix(m, r), W.payload(m, r))} : Maybe<&2, Spec.BytePair()>}:
  writer_split(m, r, writer_first_at(m, r, valid))

# A data byte cannot be a line ending; the split retains all remaining bytes.
def line_not_cr(+c: U32, +tail: List<&2, U32>, no: {U32.is_eq(c, 13) == False{} : Bool}) -> {Spec.split_line(c <> tail) == Spec.line_push(c, Spec.split_line(tail)) : Maybe<&2, Spec.BytePair()>}:
  match tail:
    case Nil{}:
      {==}
    case +d <> +rest:
      %Equal.sym(Bool, U32.is_eq(c, 13), False{}, no) : {Spec.line_step(c, d <> rest, _ && U32.is_eq(d, 10), Spec.split_line(d <> rest)) == Spec.line_push(c, Spec.split_line(d <> rest)) : Maybe<&2, Spec.BytePair()>}
      {==}

def line_value_list(+line: List<&2, U32>, +tail: List<&2, U32>, +valid: {B.value_spec(line) == True{} : Bool}) -> {Spec.split_line(List.append(&2, U32, line, 13 <> 10 <> tail)) == Some{(line, tail)} : Maybe<&2, Spec.BytePair()>}:
  match line:
    case Nil{}:
      {==}
    case c <> rest:
      no = Lines.value_not_cr(c, Laws.and_left(B.value_octet(c), B.value_spec(rest), valid))
      %Equal.sym(Maybe<&2, Spec.BytePair()>, Spec.split_line(c <> List.append(&2, U32, rest, 13 <> 10 <> tail)), Spec.line_push(c, Spec.split_line(List.append(&2, U32, rest, 13 <> 10 <> tail))), line_not_cr(c, List.append(&2, U32, rest, 13 <> 10 <> tail), no)) : {_ == Some{(c <> rest, tail)} : Maybe<&2, Spec.BytePair()>}
      Equal.cong(Maybe<&2, Spec.BytePair()>, Maybe<&2, Spec.BytePair()>, found => Spec.line_push(c, found), Spec.split_line(List.append(&2, U32, rest, 13 <> 10 <> tail)), Some{(rest, tail)}, line_value_list(rest, tail, Laws.and_right(B.value_octet(c), B.value_spec(rest), valid)))


def line_value(+line: List<&2, U32>, +tail: List<&2, U32>, +valid: {B.value(line) == True{} : Bool}) -> {Spec.split_line(B.append(line, 13 <> 10 <> tail)) == Some{(line, tail)} : Maybe<&2, Spec.BytePair()>}:
  %Equal.sym(List<&2, U32>, B.append(line, 13 <> 10 <> tail), List.append(&2, U32, line, 13 <> 10 <> tail), BT.append_equiv(line, 13 <> 10 <> tail)) : {Spec.split_line(_) == Some{(line, tail)} : Maybe<&2, Spec.BytePair()>}
  line_value_list(line, tail, Scanner.value_ok(line, valid))
def head_bytes(+line: String, +hs: List<&2, R.Header>) -> {B.append(B.encode(line ++ W.headers_text(hs)), [13, 10, 13, 10]) == B.append(B.encode(line), 13 <> 10 <> RequestWrite.headers(hs)) : List<&2, U32>}:
  %Equal.sym(List<&2, U32>, B.encode(line ++ W.headers_text(hs)), B.append(B.encode(line), B.encode(W.headers_text(hs))), Lines.encode_append(line, W.headers_text(hs))) : {B.append(_, [13, 10, 13, 10]) == B.append(B.encode(line), 13 <> 10 <> RequestWrite.headers(hs)) : List<&2, U32>}
  %Equal.sym(List<&2, U32>, B.append(B.append(B.encode(line), B.encode(W.headers_text(hs))), [13, 10, 13, 10]), B.append(B.encode(line), B.append(B.encode(W.headers_text(hs)), [13, 10, 13, 10])), Laws.append_assoc(B.encode(line), B.encode(W.headers_text(hs)), [13, 10, 13, 10])) : {_ == B.append(B.encode(line), 13 <> 10 <> RequestWrite.headers(hs)) : List<&2, U32>}
  Equal.cong(List<&2, U32>, List<&2, U32>, xs => B.append(B.encode(line), xs), B.append(B.encode(W.headers_text(hs)), [13, 10, 13, 10]), 13 <> 10 <> RequestWrite.headers(hs), headers_bytes(hs))

def head_roundtrip(+line: List<&2, U32>, +hs: List<&2, R.Header>, +bytes: {B.value(line) == True{} : Bool}, +status: {Spec.status_valid(line) == True{} : Bool}, +headers: {R.headers_valid(hs) == True{} : Bool}) -> {Spec.parse_head(B.append(line, 13 <> 10 <> RequestWrite.headers(hs))) == Some{Spec.Head{line, hs}} : Maybe<&2, Spec.Head>}:
  %Equal.sym(Maybe<&2, Spec.BytePair()>, Spec.split_line(B.append(line, 13 <> 10 <> RequestWrite.headers(hs))), Some{(line, RequestWrite.headers(hs))}, line_value(line, RequestWrite.headers(hs), bytes)) : {Spec.head_line(_) == Some{Spec.Head{line, hs}} : Maybe<&2, Spec.Head>}
  %Equal.sym(Bool, Spec.status_valid(line), True{}, status) : {Spec.head_valid(line, RequestWrite.headers(hs), _) == Some{Spec.Head{line, hs}} : Maybe<&2, Spec.Head>}
  Equal.cong(Maybe<&2, List<&2, R.Header>>, Maybe<&2, Spec.Head>, found => Spec.head_headers(line, found), Spec.parse_headers(RequestWrite.headers(hs)), Some{hs}, headers_roundtrip(hs, headers))

def response_status(r: Response.Res) -> U32:
  match r:
    case Response.Res{s, hs, b, rep}:
      s

# The parsed header list is exactly response_headers, including order and repeats.
def parse_valid(+m: R.Method, +r: Response.Res, +status: {Spec.status_valid(B.encode(W.status_text(response_status(r)))) == True{} : Bool}, +headers: {R.headers_valid(W.response_headers(m, r)) == True{} : Bool}) -> {Spec.parse_head(W.head(m, r)) == Some{Spec.Head{B.encode(W.status_text(response_status(r))), W.response_headers(m, r)}} : Maybe<&2, Spec.Head>}:
  match r:
    case Response.Res{s, hs, b, rep}:
      +res = {Response.Res{s, hs, b, rep} : Response.Res}
      %Equal.sym(List<&2, U32>, B.append(B.encode(W.status_text(s) ++ W.headers_text(W.response_headers(m, res))), [13, 10, 13, 10]), B.append(B.encode(W.status_text(s)), 13 <> 10 <> RequestWrite.headers(W.response_headers(m, res))), head_bytes(W.status_text(s), W.response_headers(m, res))) : {Spec.parse_head(_) == Some{Spec.Head{B.encode(W.status_text(s)), W.response_headers(m, res)}} : Maybe<&2, Spec.Head>}
      head_roundtrip(B.encode(W.status_text(s)), W.response_headers(m, res), Framing.status_value(s), status, headers)

# Boundary-checked public writer, rather than only its internal serialization.
def split_write_valid(+m: R.Method, +r: Response.Res, +valid: {Response.valid(r) == True{} : Bool}) -> {Spec.split_first(W.write(m, r)) == Some{(W.prefix(m, r), W.payload(m, r))} : Maybe<&2, Spec.BytePair()>}:
  %Equal.sym(Bool, Response.valid(r), True{}, valid) : {Spec.split_first(W.write_valid(m, r, _)) == Some{(W.prefix(m, r), W.payload(m, r))} : Maybe<&2, Spec.BytePair()>}
  split_valid(m, r, valid)

# Only numeric status validity remains as an external premise. Canonical header
# validity follows from the response invariant, not an additional assumption.
def parse_response(+m: R.Method, +r: Response.Res, +valid: {Response.valid(r) == True{} : Bool}, +status: {Spec.status_valid(B.encode(W.status_text(response_status(r)))) == True{} : Bool}) -> {Spec.parse_head(W.head(m, r)) == Some{Spec.Head{B.encode(W.status_text(response_status(r))), W.response_headers(m, r)}} : Maybe<&2, Spec.Head>}:
  parse_valid(m, r, status, Framing.response_valid(m, r, valid))

