# Strict RFC 9112 line endings. Origin-form and OPTIONS * only; other
# target forms are explicitly unsupported. See decision 0003.
import Base
import ./bytes.bend as Bytes
import ./request.bend as R

type State is Data:
  RequestLine{reverse: List<&2, U32>, cr: Bool}
  Headers{request: R.Req, reverse: List<&2, U32>, cr: Bool}
  Complete{request: R.Req}
  Bad{error: R.ParseError}

def finish(r: R.Req) -> State:
  match r:
    case R.Req{m, p, q, v, hs}:
      Complete{R.Req{m, p, q, v, List.reverse(&2, R.Header, hs)}}

def start_headers(m: R.Method, parts: String & Maybe<&2, String>, v: R.Version) -> State:
  (p, q) = parts
  Headers{R.Req{m, p, q, v, []}, [], False{}}

def version(m: R.Method, t: String, v: String) -> State:
  match v:
    case "HTTP/1.0":
      start_headers(m, Bytes.split_target(t), R.Http10{})
    case "HTTP/1.1":
      start_headers(m, Bytes.split_target(t), R.Http11{})
    case _:
      Bad{R.InvalidVersion{}}

def validated_target(m: R.Method, t: String, v: String, ok: Bool) -> State:
  match ok:
    case False{}:
      Bad{R.InvalidTarget{}}
    case True{}:
      version(m, t, v)

def supported_target(+m: R.Method, +t: String, v: String, parts: String & Maybe<&2, String>) -> State:
  (p, q) = parts
  validated_target(m, t, v, R.target_valid(m, p, q))

def target_form(+m: R.Method, +t: String, v: String) -> State:
  match m t:
    case R.Connect{} _:
      Bad{R.UnsupportedTarget{}}
    case _ SCon{Chr{47}, rest}:
      supported_target(m, t, v, Bytes.split_target(t))
    case R.Options{} "*":
      version(m, t, v)
    case _ _:
      Bad{R.UnsupportedTarget{}}

def valid_method(m: String, t: String, v: String, ok: Bool) -> State:
  match ok:
    case False{}:
      Bad{R.InvalidMethod{}}
    case True{}:
      target_form(R.method(m), t, v)

def request_line_parts(parts: List<&2, String>) -> State:
  match parts:
    case +m <> t <> v <> Nil{}:
      valid_method(m, t, v, Bytes.token(m))
    case _:
      Bad{R.InvalidRequestLine{}}

def request_line(line: List<&2, U32>) -> State:
  request_line_parts(String.split(Bytes.ascii(line), ' '))

def push_header(r: R.Req, h: R.Header) -> State:
  match r:
    case R.Req{m, p, q, v, hs}:
      Headers{R.Req{m, p, q, v, h <> hs}, [], False{}}

def header_value(r: R.Req, n: String, value: List<&2, U32>, ok: Bool) -> State:
  match ok:
    case False{}:
      Bad{R.InvalidHeaderValue{}}
    case True{}:
      push_header(r, R.Header{Bytes.fold(n), Bytes.trim(value)})

def header_name(r: R.Req, n: String, +value: List<&2, U32>, ok: Bool) -> State:
  match ok:
    case False{}:
      Bad{R.InvalidHeaderName{}}
    case True{}:
      header_value(r, n, value, Bytes.value(value))

# Split at the first colon only. A missing colon is distinct from an
# empty value; whitespace before the colon fails token validation.
type Field is Data:
  MissingColon{}
  Field{name: String, value: List<&2, U32>}

def field_push(c: U32, f: Field) -> Field:
  match f:
    case MissingColon{}:
      MissingColon{}
    case Field{n, v}:
      Field{SCon{Chr{c}, n}, v}

def field(xs: List<&2, U32>) -> Field:
  match xs:
    case Nil{}:
      MissingColon{}
    case 58 <> t:
      Field{"", t}
    case c <> t:
      field_push(c, field(t))

def header_field(r: R.Req, f: Field) -> State:
  match f:
    case MissingColon{}:
      Bad{R.InvalidHeaderName{}}
    case Field{+n, v}:
      header_name(r, n, v, Bytes.token(n))

def header_line(r: R.Req, line: List<&2, U32>) -> State:
  match line:
    case Nil{}:
      finish(r)
    case 32 <> t:
      Bad{R.ObsFold{}}
    case 9 <> t:
      Bad{R.ObsFold{}}
    case c <> t:
      header_field(r, field(c <> t))

def ordinary_request(c: U32, rev: List<&2, U32>, ok: Bool) -> State:
  match ok:
    case False{}:
      Bad{R.InvalidOctet{}}
    case True{}:
      RequestLine{c <> rev, False{}}

def ordinary_header(r: R.Req, c: U32, rev: List<&2, U32>, ok: Bool) -> State:
  match ok:
    case False{}:
      Bad{R.InvalidOctet{}}
    case True{}:
      Headers{r, c <> rev, False{}}

# Valid data bytes take the direct path; controls retain strict CRLF handling.
def request_octet(ok: Bool, c: U32, rev: List<&2, U32>) -> State:
  match ok c:
    case True{} c:
      RequestLine{c <> rev, False{}}
    case False{} 13:
      RequestLine{rev, True{}}
    case False{} 10:
      Bad{R.InvalidLineEnding{}}
    case False{} _:
      Bad{R.InvalidOctet{}}

def header_octet(ok: Bool, c: U32, r: R.Req, rev: List<&2, U32>) -> State:
  match ok c:
    case True{} c:
      Headers{r, c <> rev, False{}}
    case False{} 13:
      Headers{r, rev, True{}}
    case False{} 10:
      Bad{R.InvalidLineEnding{}}
    case False{} _:
      Bad{R.InvalidOctet{}}

def advance(s: State, +c: U32) -> State:
  match s c:
    case RequestLine{rev, True{}} 10:
      request_line(List.reverse(&2, U32, rev))
    case Headers{r, rev, True{}} 10:
      header_line(r, List.reverse(&2, U32, rev))
    case RequestLine{rev, True{}} _:
      Bad{R.InvalidLineEnding{}}
    case Headers{r, rev, True{}} _:
      Bad{R.InvalidLineEnding{}}
    case RequestLine{rev, False{}} c:
      request_octet((c >= 32 : U32) && (c <= 126 : U32), c, rev)
    case Headers{r, rev, False{}} c:
      header_octet(Bytes.value_octet(c), c, r, rev)
    case Complete{r} _:
      Complete{r}
    case Bad{e} _:
      Bad{e}

# Retain State and feed only new bytes for incremental reads. NeedMore
# means the state can still accept more bytes; terminal errors stay terminal.
def feed(xs: List<&2, U32>, s: State) -> State & R.ParseResult:
  match xs s:
    case xs Complete{+r}:
      (Complete{r}, R.Parsed{r, xs})
    case _ Bad{+e}:
      (Bad{e}, R.Rejected{e})
    case Nil{} s:
      (s, R.NeedMore{})
    case c <> t s:
      feed(t, advance(s, c))

def result(pair: State & R.ParseResult) -> R.ParseResult:
  (s, r) = pair
  r

def initial() -> State:
  RequestLine{[], False{}}

def parse(xs: List<&2, U32>) -> R.ParseResult:
  result(feed(xs, initial()))
