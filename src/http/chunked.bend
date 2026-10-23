# Incremental RFC 9112 chunked framing. All buffers contain octets.
import Base
import ./bytes.bend as Bytes
import ./request.bend as Request
import ./parse.bend as Parse

type DecodeResult is Data:
  NeedMore{}
  Decoded{body: List<&2, U32>, trailers: List<&2, Request.Header>, rest: List<&2, U32>}
  Error{status: U32}

type State is Data:
  Size{budget: U32, body: List<&2, U32>, line: List<&2, U32>, count: U32, cr: Bool}
  Payload{budget: U32, body: List<&2, U32>, left: U32}
  DataCR{budget: U32, body: List<&2, U32>}
  DataLF{budget: U32, body: List<&2, U32>}
  Trailers{body: List<&2, U32>, headers: List<&2, Request.Header>, line: List<&2, U32>, count: U32, cr: Bool}
  Complete{body: List<&2, U32>, trailers: List<&2, Request.Header>}
  Failed{status: U32}

def initial(limit: U32) -> State:
  Size{limit, [], [], 0, False{}}

# These modes implement BWS ';' BWS token [ BWS '=' BWS (token / quoted-string) ].
type Extension is Data:
  Semi{}
  NameStart{}
  Name{}
  NameSpace{}
  ValueStart{}
  Token{}
  Quoted{}
  Escaped{}
  QuotedEnd{}
  ValueSpace{}
  Invalid{}

def choose_ext(ok: Bool, yes: Extension) -> Extension:
  match ok:
    case True{}:
      yes
    case False{}:
      Invalid{}

def ext_step(mode: Extension, +c: U32) -> Extension:
  match mode c:
    case Semi{} 59:
      NameStart{}
    case Semi{} c:
      choose_ext(Bytes.ows(c), Semi{})
    case NameStart{} 9:
      NameStart{}
    case NameStart{} 32:
      NameStart{}
    case NameStart{} c:
      choose_ext(Bytes.tchar(c), Name{})
    case Name{} 59:
      NameStart{}
    case Name{} 61:
      ValueStart{}
    case Name{} 9:
      NameSpace{}
    case Name{} 32:
      NameSpace{}
    case Name{} c:
      choose_ext(Bytes.tchar(c), Name{})
    case NameSpace{} 59:
      NameStart{}
    case NameSpace{} 61:
      ValueStart{}
    case NameSpace{} c:
      choose_ext(Bytes.ows(c), NameSpace{})
    case ValueStart{} 9:
      ValueStart{}
    case ValueStart{} 32:
      ValueStart{}
    case ValueStart{} 34:
      Quoted{}
    case ValueStart{} c:
      choose_ext(Bytes.tchar(c), Token{})
    case Token{} 59:
      NameStart{}
    case Token{} 9:
      ValueSpace{}
    case Token{} 32:
      ValueSpace{}
    case Token{} c:
      choose_ext(Bytes.tchar(c), Token{})
    case Quoted{} 34:
      QuotedEnd{}
    case Quoted{} 92:
      Escaped{}
    case Quoted{} c:
      choose_ext(Bytes.value_octet(c), Quoted{})
    case Escaped{} c:
      choose_ext(Bytes.value_octet(c), Quoted{})
    case QuotedEnd{} 59:
      NameStart{}
    case QuotedEnd{} c:
      choose_ext(Bytes.ows(c), ValueSpace{})
    case ValueSpace{} 59:
      NameStart{}
    case ValueSpace{} c:
      choose_ext(Bytes.ows(c), ValueSpace{})
    case Invalid{} _:
      Invalid{}

def ext_valid(xs: List<&2, U32>, mode: Extension) -> Bool:
  match xs mode:
    case Nil{} Name{}:
      True{}
    case Nil{} Token{}:
      True{}
    case Nil{} QuotedEnd{}:
      True{}
    case Nil{} _:
      False{}
    case _ Invalid{}:
      False{}
    case c <> t mode:
      ext_valid(t, ext_step(mode, c))

def hex_digit(+c: U32) -> U32:
  Bool.pick(U32, (c <= 57 : U32), (c - 48 : U32), Bool.pick(U32, (c <= 70 : U32), (c - 55 : U32), (c - 87 : U32)))

def branch(-A: Type, ok: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match ok:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def size_result(n: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      Some{n}
    case False{}:
      None{}

# U32 overflow is checked before multiplication. A line can contain leading zeros.
def size_digits(xs: List<&2, U32>, +n: U32, seen: Bool) -> Maybe<&2, U32>:
  match xs:
    case Nil{}:
      size_result(n, seen)
    case +c <> +t:
      branch(Maybe<&2, U32>, Bytes.hex(c),
        u => branch(Maybe<&2, U32>, (n <= 268435455 : U32),
          u => size_digits(t, (16 * n + hex_digit(c) : U32), True{}),
          u => None{}),
        u => size_result(n, seen && ext_valid(c <> t, Semi{})))

# Compare sizes with U32.is_eq rather than literal patterns, so proofs can
# read a symbolic size through its numeric value.
def start_size(+budget: U32, body: List<&2, U32>, +n: U32, zero: Bool) -> State:
  match zero:
    case True{}:
      Trailers{body, [], [], 0, False{}}
    case False{}:
      Bool.pick(State, (n <= budget : U32), Payload{(budget - n : U32), body, n}, Failed{413})

def start_chunk(+budget: U32, body: List<&2, U32>, size: Maybe<&2, U32>) -> State:
  match size:
    case None{}:
      Failed{400}
    case Some{+n}:
      start_size(budget, body, n, U32.is_eq(n, 0))

# RFC 9110 6.5.1 and RFC 9112 7.1.2: reject fields used before the body
# for framing, routing, authentication, request/response control or decoding.
def name_in(+name: String, names: List<&2, String>) -> Bool:
  match names:
    case Nil{}:
      False{}
    case n <> rest:
      String.eq(name, n) || name_in(name, rest)

def forbidden(name: String) -> Bool:
  name_in(name, [
    "content-length", "transfer-encoding", "host", "connection",
    "keep-alive", "proxy-connection", "trailer", "te",
    "upgrade", "expect", "authorization", "proxy-authorization",
    "proxy-authenticate", "www-authenticate", "cookie", "set-cookie",
    "content-encoding", "content-type", "content-range", "content-location",
    "content-language", "content-disposition", "range", "cache-control",
    "max-forwards", "pragma", "age", "expires",
    "date", "location", "retry-after", "vary",
    "warning", "accept", "accept-encoding", "accept-language",
    "accept-charset", "if-match", "if-none-match", "if-modified-since",
    "if-unmodified-since", "if-range"])

def trailer_field(body: List<&2, U32>, hs: List<&2, Request.Header>, count: U32, field: Parse.Field) -> State:
  match field:
    case Parse.MissingColon{}:
      Failed{400}
    case Parse.Field{+n, +v}:
      Bool.pick(State, Bytes.token(n) && Bytes.value(v) && Bool.not(forbidden(Bytes.fold(n))), Trailers{body, Request.Header{Bytes.fold(n), Bytes.trim(v)} <> hs, [], count, False{}}, Failed{400})

def trailer_line(body: List<&2, U32>, hs: List<&2, Request.Header>, count: U32, line: List<&2, U32>) -> State:
  match line:
    case Nil{}:
      Complete{List.reverse(&2, U32, body), List.reverse(&2, Request.Header, hs)}
    case c <> t:
      trailer_field(body, hs, count, Parse.field(c <> t))

# Count the complete size/extension line and total trailer section, CRLF included.
def size_octet_inner(budget: U32, body: List<&2, U32>, line: List<&2, U32>, count: U32, cr: Bool, +c: U32) -> State:
  match cr c:
    case True{} 10:
      start_chunk(budget, body, size_digits(List.reverse(&2, U32, line), 0, False{}))
    case True{} _:
      Failed{400}
    case False{} 13:
      Size{budget, body, line, count, True{}}
    case False{} c:
      Bool.pick(State, Bytes.value_octet(c), Size{budget, body, c <> line, count, False{}}, Failed{400})

def size_octet(budget: U32, body: List<&2, U32>, line: List<&2, U32>, +count: U32, cr: Bool, c: U32) -> State:
  branch(State, (count < 8192 : U32), u => size_octet_inner(budget, body, line, (count + 1 : U32), cr, c), u => Failed{400})

def trailer_octet_inner(body: List<&2, U32>, hs: List<&2, Request.Header>, line: List<&2, U32>, count: U32, cr: Bool, +c: U32) -> State:
  match cr c:
    case True{} 10:
      trailer_line(body, hs, count, List.reverse(&2, U32, line))
    case True{} _:
      Failed{400}
    case False{} 13:
      Trailers{body, hs, line, count, True{}}
    case False{} c:
      Bool.pick(State, Bytes.value_octet(c), Trailers{body, hs, c <> line, count, False{}}, Failed{400})

def trailer_octet(body: List<&2, U32>, hs: List<&2, Request.Header>, line: List<&2, U32>, +count: U32, cr: Bool, c: U32) -> State:
  branch(State, (count < 8192 : U32), u => trailer_octet_inner(body, hs, line, (count + 1 : U32), cr, c), u => Failed{400})

def data_rest(budget: U32, body: List<&2, U32>, +left: U32, zero: Bool) -> State:
  match zero:
    case True{}:
      Failed{400}
    case False{}:
      Payload{budget, body, (left - 1 : U32)}

def data_next(budget: U32, body: List<&2, U32>, +left: U32, last: Bool) -> State:
  match last:
    case True{}:
      DataCR{budget, body}
    case False{}:
      data_rest(budget, body, left, U32.is_eq(left, 0))

def data_left(budget: U32, body: List<&2, U32>, +left: U32, c: U32) -> State:
  data_next(budget, c <> body, left, U32.is_eq(left, 1))

def data_octet(budget: U32, body: List<&2, U32>, left: U32, +c: U32) -> State:
  branch(State, (c <= 255 : U32), u => data_left(budget, body, left, c), u => Failed{400})

def advance(s: State, c: U32) -> State:
  match s c:
    case Size{budget, body, line, count, cr} c:
      size_octet(budget, body, line, count, cr, c)
    case Payload{budget, body, left} c:
      data_octet(budget, body, left, c)
    case DataCR{budget, body} 13:
      DataLF{budget, body}
    case DataLF{budget, body} 10:
      Size{budget, body, [], 0, False{}}
    case DataCR{budget, body} _:
      Failed{400}
    case DataLF{budget, body} _:
      Failed{400}
    case Trailers{body, hs, line, count, cr} c:
      trailer_octet(body, hs, line, count, cr, c)
    case Complete{body, hs} _:
      Complete{body, hs}
    case Failed{status} _:
      Failed{status}

# Feed only newly received bytes. Terminal success leaves the suffix untouched.
def feed(xs: List<&2, U32>, s: State) -> State & DecodeResult:
  match xs s:
    case xs Complete{+body, +hs}:
      (Complete{body, hs}, Decoded{body, hs, xs})
    case _ Failed{+status}:
      (Failed{status}, Error{status})
    case Nil{} s:
      (s, NeedMore{})
    case c <> t s:
      feed(t, advance(s, c))

def result(pair: State & DecodeResult) -> DecodeResult:
  (s, r) = pair
  r

def decode(xs: List<&2, U32>, limit: U32) -> DecodeResult:
  result(feed(xs, initial(limit)))

# Canonical encoder. Empty producer chunks emit no wire chunk: only the final
# zero chunk terminates a message. The caller must use admissible below.
def hex_char(+n: U32) -> U32:
  Bool.pick(U32, (n < 10 : U32), (48 + n : U32), (87 + n : U32))

def hex_go(fuel: Nat, +n: U32, +acc: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      acc
    case 1n+p:
      branch(List<&2, U32>, U32.is_eq(n, 0), u => acc,
        u => hex_go(p, (n / 16 : U32), hex_char((n % 16 : U32)) <> acc))

def encode_chunk(xs: List<&2, U32>, tail: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      tail
    case +h <> +t:
      +body = {h <> t : List<&2, U32>}
      Bytes.append(hex_go(8n, U32.from_nat(List.length(&2, U32, body)), []), 13 <> 10 <> Bytes.append(body, 13 <> 10 <> tail))

def encode(chunks: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match chunks:
    case Nil{}:
      [48, 13, 10, 13, 10]
    case chunk <> rest:
      encode_chunk(chunk, encode(rest))

def octets(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case c <> t:
      (c <= 255 : U32) && octets(t)

# Independent input predicate: arbitrary octets and any partition into producer
# chunks, with total decoded length within the configured U32 body budget.
def admissible(+chunks: List<&2, List<&2, U32>>, limit: U32) -> Bool:
  +body = List.concat(&2, U32, chunks)
  octets(body) && Nat.is_le(List.length(&2, U32, body), U32.to_nat(limit))
