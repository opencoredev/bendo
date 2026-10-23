# Safety of generated and application response lines.
import Base
import ../LAWS.bend as Laws
import ../src/http/bytes.bend as B
import ../src/http/request.bend as R
import ../src/http/response.bend as Response
import ../src/http/write_response.bend as W
import ./response-decimal.bend as Decimal
import ./response-reason.bend as Reason
import ./response-lines.bend as Lines
import ./tokens.bend as Tokens
import ./scanner.bend as Scanner
import ./support.bend as Support

def filtered_step(+h: R.Header, +rest: List<&2, R.Header>, keep: Bool, hok: {B.value(Support.header_content(h)) == True{} : Bool}, tok: {Support.headers_scannable(rest) == True{} : Bool}) -> {Support.headers_scannable(List.filter.put(R.Header, h, rest, keep)) == True{} : Bool}:
  match keep:
    case False{}:
      tok
    case True{}:
      Scanner.and_true(B.value(Support.header_content(h)), Support.headers_scannable(rest), hok, tok)

def filtered_scannable(+hs: List<&2, R.Header>, +ok: {R.headers_valid(hs) == True{} : Bool}) -> {Support.headers_scannable(W.headers(hs)) == True{} : Bool}:
  match hs:
    case Nil{}:
      {==}
    case h <> t:
      filtered_step(h, W.headers(t), W.user_header(h), Laws.header_scannable_valid(h, Laws.and_left(R.header_valid(h), R.headers_valid(t), ok)), filtered_scannable(t, Laws.and_right(R.header_valid(h), R.headers_valid(t), ok)))

def length_scannable(+n: Nat, +hs: List<&2, R.Header>, ok: {Support.headers_scannable(hs) == True{} : Bool}) -> {Support.headers_scannable(W.length_header(n) <> hs) == True{} : Bool}:
  Scanner.and_true(B.value(Support.header_content(W.length_header(n))), Support.headers_scannable(hs), Decimal.nat_show_value(n), ok)

def representation_scannable(+rep: Maybe<&2, List<&2, U32>>, +hs: List<&2, R.Header>, ok: {Support.headers_scannable(hs) == True{} : Bool}) -> {Support.headers_scannable(W.representation_length(rep, hs)) == True{} : Bool}:
  match rep:
    case None{}:
      ok
    case Some{b}:
      length_scannable(Response.length(b), hs, ok)

def reset_scannable(+b: List<&2, U32>, +hs: List<&2, R.Header>, reset: Bool, ok: {Support.headers_scannable(hs) == True{} : Bool}) -> {Support.headers_scannable(W.reset_headers(b, hs, reset)) == True{} : Bool}:
  match reset:
    case True{}:
      length_scannable(0n, hs, ok)
    case False{}:
      length_scannable(Response.length(b), hs, ok)

def modified_scannable(+b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +hs: List<&2, R.Header>, reset: Bool, unmodified: Bool, ok: {Support.headers_scannable(hs) == True{} : Bool}) -> {Support.headers_scannable(W.modified_headers(b, rep, hs, reset, unmodified)) == True{} : Bool}:
  match unmodified:
    case True{}:
      representation_scannable(rep, hs, ok)
    case False{}:
      reset_scannable(b, hs, reset, ok)

def framing_scannable(+s: U32, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +hs: List<&2, R.Header>, none: Bool, ok: {Support.headers_scannable(hs) == True{} : Bool}) -> {Support.headers_scannable(W.framing_headers(s, b, rep, hs, none)) == True{} : Bool}:
  match none:
    case True{}:
      ok
    case False{}:
      modified_scannable(b, rep, hs, U32.is_eq(s, 205), U32.is_eq(s, 304), ok)

def valid_headers(+s: U32, +hs: List<&2, R.Header>, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, ok: {Response.valid(Response.Res{s, hs, b, rep}) == True{} : Bool}) -> {R.headers_valid(hs) == True{} : Bool}:
  a = Laws.and_left((s >= 100 : U32) && (s <= 599 : U32) && R.headers_valid(hs) && Response.octets(b), Response.representation_valid(rep), ok)
  bvalid = Laws.and_left((s >= 100 : U32) && (s <= 599 : U32) && R.headers_valid(hs), Response.octets(b), a)
  Laws.and_right((s >= 100 : U32) && (s <= 599 : U32), R.headers_valid(hs), bvalid)

def response_scannable(+method: R.Method, +r: Response.Res, valid: {Response.valid(r) == True{} : Bool}) -> {Support.headers_scannable(W.response_headers(method, r)) == True{} : Bool}:
  match r:
    case Response.Res{s, hs, b, rep}:
      framing_scannable(s, b, rep, W.headers(hs), W.forbidden(s) || W.tunnel(method, s), filtered_scannable(hs, valid_headers(s, hs, b, rep, valid)))

# Body-allowing statuses select the body length, regardless of method HEAD.
def body_headers(+method: R.Method, +s: U32, +hs: List<&2, R.Header>, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +allowed: {W.allows_body(s) == True{} : Bool}, not_tunnel: {W.tunnel(method, s) == False{} : Bool}) -> {W.response_headers(method, Response.Res{s, hs, b, rep}) == W.length_header(Response.length(b)) <> W.headers(hs) : List<&2, R.Header>}:
  +all = Tokens.not_true_false(W.forbidden(s) || U32.is_eq(s, 205) || U32.is_eq(s, 304), allowed)
  +first = Tokens.or_false_left(W.forbidden(s) || U32.is_eq(s, 205), U32.is_eq(s, 304), all)
  +forbidden_false = Tokens.or_false_left(W.forbidden(s), U32.is_eq(s, 205), first)
  reset_false = Tokens.or_false_right(W.forbidden(s), U32.is_eq(s, 205), first)
  modified_false = Tokens.or_false_right(W.forbidden(s) || U32.is_eq(s, 205), U32.is_eq(s, 304), all)
  %Equal.sym(Bool, W.forbidden(s), False{}, forbidden_false) : {W.framing_headers(s, b, rep, W.headers(hs), _ || W.tunnel(method, s)) == W.length_header(Response.length(b)) <> W.headers(hs) : List<&2, R.Header>}
  %Equal.sym(Bool, W.tunnel(method, s), False{}, not_tunnel) : {W.framing_headers(s, b, rep, W.headers(hs), _) == W.length_header(Response.length(b)) <> W.headers(hs) : List<&2, R.Header>}
  %Equal.sym(Bool, U32.is_eq(s, 304), False{}, modified_false) : {W.modified_headers(b, rep, W.headers(hs), U32.is_eq(s, 205), _) == W.length_header(Response.length(b)) <> W.headers(hs) : List<&2, R.Header>}
  %Equal.sym(Bool, U32.is_eq(s, 205), False{}, reset_false) : {W.reset_headers(b, W.headers(hs), _) == W.length_header(Response.length(b)) <> W.headers(hs) : List<&2, R.Header>}
  {==}

def forbidden_headers(+method: R.Method, +s: U32, +hs: List<&2, R.Header>, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, forbidden: {W.forbidden(s) == True{} : Bool}) -> {W.response_headers(method, Response.Res{s, hs, b, rep}) == W.headers(hs) : List<&2, R.Header>}:
  %Equal.sym(Bool, W.forbidden(s), True{}, forbidden) : {W.framing_headers(s, b, rep, W.headers(hs), _ || W.tunnel(method, s)) == W.headers(hs) : List<&2, R.Header>}
  {==}

def status_value(+status: U32) -> {B.value(B.encode(W.status_text(status))) == True{} : Bool}:
  Lines.string_value_append("HTTP/1.1 ", Nat.show(U32.to_nat(status)) ++ " " ++ Response.reason(status), {==}, Lines.string_value_append(Nat.show(U32.to_nat(status)), " " ++ Response.reason(status), Decimal.nat_show_value(U32.to_nat(status)), Reason.reason_value(status)))

# The parser's canonical field predicate also holds for generated lengths.
def no_ows_start(+xs: List<&2, U32>, ok: {Decimal.no_ows(xs) == True{} : Bool}) -> {R.value_start(xs) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case c <> t:
      Laws.and_left(Bool.not(B.ows(c)), Decimal.no_ows(t), ok)

def length_valid(+n: Nat) -> {R.header_valid(W.length_header(n)) == True{} : Bool}:
  +v = B.encode(Nat.show(n))
  +no_ows = Decimal.nat_show_no_ows(n)
  +value = Decimal.nat_show_value(n)
  +start = no_ows_start(v, no_ows)
  +end = no_ows_start(List.reverse(&2, U32, v), Decimal.reverse_no_ows(v, [], no_ows, {==}))
  Scanner.and_true(B.value(v) && R.value_start(v), R.value_start(List.reverse(&2, U32, v)), Scanner.and_true(B.value(v), R.value_start(v), value, start), end)

def filtered_valid_step(+h: R.Header, +rest: List<&2, R.Header>, keep: Bool, hok: {R.header_valid(h) == True{} : Bool}, tok: {R.headers_valid(rest) == True{} : Bool}) -> {R.headers_valid(List.filter.put(R.Header, h, rest, keep)) == True{} : Bool}:
  match keep:
    case False{}:
      tok
    case True{}:
      Scanner.and_true(R.header_valid(h), R.headers_valid(rest), hok, tok)

def filtered_valid(+hs: List<&2, R.Header>, +ok: {R.headers_valid(hs) == True{} : Bool}) -> {R.headers_valid(W.headers(hs)) == True{} : Bool}:
  match hs:
    case Nil{}:
      {==}
    case h <> t:
      filtered_valid_step(h, W.headers(t), W.user_header(h), Laws.and_left(R.header_valid(h), R.headers_valid(t), ok), filtered_valid(t, Laws.and_right(R.header_valid(h), R.headers_valid(t), ok)))

def length_headers_valid(+n: Nat, +hs: List<&2, R.Header>, ok: {R.headers_valid(hs) == True{} : Bool}) -> {R.headers_valid(W.length_header(n) <> hs) == True{} : Bool}:
  Scanner.and_true(R.header_valid(W.length_header(n)), R.headers_valid(hs), length_valid(n), ok)

def rep_valid(+rep: Maybe<&2, List<&2, U32>>, +hs: List<&2, R.Header>, ok: {R.headers_valid(hs) == True{} : Bool}) -> {R.headers_valid(W.representation_length(rep, hs)) == True{} : Bool}:
  match rep:
    case None{}:
      ok
    case Some{b}:
      length_headers_valid(Response.length(b), hs, ok)

def reset_valid(+b: List<&2, U32>, +hs: List<&2, R.Header>, reset: Bool, ok: {R.headers_valid(hs) == True{} : Bool}) -> {R.headers_valid(W.reset_headers(b, hs, reset)) == True{} : Bool}:
  match reset:
    case True{}:
      length_headers_valid(0n, hs, ok)
    case False{}:
      length_headers_valid(Response.length(b), hs, ok)

def modified_valid(+b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +hs: List<&2, R.Header>, reset: Bool, unmodified: Bool, ok: {R.headers_valid(hs) == True{} : Bool}) -> {R.headers_valid(W.modified_headers(b, rep, hs, reset, unmodified)) == True{} : Bool}:
  match unmodified:
    case True{}:
      rep_valid(rep, hs, ok)
    case False{}:
      reset_valid(b, hs, reset, ok)

def framing_valid(+s: U32, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +hs: List<&2, R.Header>, none: Bool, ok: {R.headers_valid(hs) == True{} : Bool}) -> {R.headers_valid(W.framing_headers(s, b, rep, hs, none)) == True{} : Bool}:
  match none:
    case True{}:
      ok
    case False{}:
      modified_valid(b, rep, hs, U32.is_eq(s, 205), U32.is_eq(s, 304), ok)

def response_valid(+method: R.Method, +r: Response.Res, valid: {Response.valid(r) == True{} : Bool}) -> {R.headers_valid(W.response_headers(method, r)) == True{} : Bool}:
  match r:
    case Response.Res{s, hs, b, rep}:
      framing_valid(s, b, rep, W.headers(hs), W.forbidden(s) || W.tunnel(method, s), filtered_valid(hs, valid_headers(s, hs, b, rep, valid)))
