# Independent byte-level response observations. No response writer is imported.
import Base
import ../src/http/bytes.bend as Bytes
import ../src/http/request.bend as Request
import ../src/http/parse.bend as Parse

def BytePair() -> Data:
  Sigma<&2, &2, List<&2, U32>, _ => List<&2, U32>>

def delimiter() -> List<&2, U32>:
  [13, 10, 13, 10]

def delimiter_tail(xs: List<&2, U32>) -> Bool:
  match xs:
    case a <> b <> c <> tail:
      U32.is_eq(a, 10) && U32.is_eq(b, 13) && U32.is_eq(c, 10)
    case _:
      False{}

def starts_delimiter(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case c <> tail:
      U32.is_eq(c, 13) && delimiter_tail(tail)

def drop_three(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case a <> b <> c <> tail:
      tail
    case _:
      []

def split_push(c: U32, found: Maybe<&2, BytePair()>) -> Maybe<&2, BytePair()>:
  match found:
    case None{}:
      None{}
    case Some{(head, suffix)}:
      Some{(c <> head, suffix)}

def split_step(c: U32, tail: List<&2, U32>, here: Bool, rest: Maybe<&2, BytePair()>) -> Maybe<&2, BytePair()>:
  match here:
    case True{}:
      Some{([], drop_three(tail))}
    case False{}:
      split_push(c, rest)

# The first match wins, including when the payload contains more delimiters.
# The returned head excludes the delimiter; suffix is the untouched payload.
def split_first(xs: List<&2, U32>) -> Maybe<&2, BytePair()>:
  match xs:
    case Nil{}:
      None{}
    case +c <> +tail:
      split_step(c, tail, starts_delimiter(c <> tail), split_first(tail))

def line_push(c: U32, found: Maybe<&2, BytePair()>) -> Maybe<&2, BytePair()>:
  split_push(c, found)

def starts_line(xs: List<&2, U32>) -> Bool:
  match xs:
    case a <> b <> tail:
      U32.is_eq(a, 13) && U32.is_eq(b, 10)
    case _:
      False{}

def drop_one(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      []
    case c <> tail:
      tail

def line_step(c: U32, tail: List<&2, U32>, here: Bool, rest: Maybe<&2, BytePair()>) -> Maybe<&2, BytePair()>:
  match here:
    case True{}:
      Some{([], drop_one(tail))}
    case False{}:
      line_push(c, rest)

def split_line(xs: List<&2, U32>) -> Maybe<&2, BytePair()>:
  match xs:
    case Nil{}:
      None{}
    case +c <> +tail:
      line_step(c, tail, starts_line(c <> tail), split_line(tail))

# A response uses the BND-7 header parser with an otherwise irrelevant request.
def request(hs: List<&2, Request.Header>) -> Request.Req:
  Request.Req{Request.Get{}, "/", None{}, Request.Http11{}, hs}

def parsed_headers(result: Request.ParseResult) -> Maybe<&2, List<&2, Request.Header>>:
  match result:
    case Request.Parsed{Request.Req{m, p, q, v, hs}, Nil{}}:
      Some{hs}
    case _:
      None{}

# Input includes each header's CRLF and the final empty line. Reject suffixes.
def parse_headers(xs: List<&2, U32>) -> Maybe<&2, List<&2, Request.Header>>:
  parsed_headers(Parse.result(Parse.feed(xs, Parse.Headers{request([]), [], False{}})))

def digit(+c: U32) -> Bool:
  (c >= 48 : U32) && (c <= 57 : U32)

def status_valid(xs: List<&2, U32>) -> Bool:
  match xs:
    case 72 <> 84 <> 84 <> 80 <> 47 <> 49 <> 46 <> 49 <> 32 <> +a <> +b <> +c <> 32 <> reason:
      (a >= 49 : U32) && (a <= 53 : U32) && digit(b) && digit(c) && Bytes.value(reason)
    case _:
      False{}

type Head is Data:
  Head{status_line: List<&2, U32>, headers: List<&2, Request.Header>}

def head_headers(line: List<&2, U32>, hs: Maybe<&2, List<&2, Request.Header>>) -> Maybe<&2, Head>:
  match hs:
    case None{}:
      None{}
    case Some{headers}:
      Some{Head{line, headers}}

def head_valid(line: List<&2, U32>, tail: List<&2, U32>, valid: Bool) -> Maybe<&2, Head>:
  match valid:
    case False{}:
      None{}
    case True{}:
      head_headers(line, parse_headers(tail))

def head_line(parts: Maybe<&2, BytePair()>) -> Maybe<&2, Head>:
  match parts:
    case None{}:
      None{}
    case Some{(+line, tail)}:
      head_valid(line, tail, status_valid(line))

# Full head bytes, including CRLFCRLF; this does not parse or trust a body.
def parse_head(xs: List<&2, U32>) -> Maybe<&2, Head>:
  head_line(split_line(xs))

# Request.lookup is BND-7's case-insensitive header_values API in this checkout.
def header_values(head: Head, name: String) -> List<&2, List<&2, U32>>:
  match head:
    case Head{line, hs}:
      Request.lookup(hs, name)

# Numeric status is decoded only after parse_head has checked three decimal digits.
def status_line_code(xs: List<&2, U32>) -> U32:
  match xs:
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> x <> y <> z <> tail:
      ((x - 48) * 100 + (y - 48) * 10 + (z - 48) : U32)
    case _:
      0

def status(head: Head) -> U32:
  match head:
    case Head{line, hs}:
      status_line_code(line)

# These concrete witnesses also exercise rejection and preservation of repeated
# fields. Expected wire bytes and parse results are literal, independent data.
def first_delimiter_example() -> {split_first([65, 13, 10, 13, 10, 0, 255, 13, 10, 13, 10]) == Some{([65], [0, 255, 13, 10, 13, 10])} : Maybe<&2, BytePair()>}:
  {==}

def missing_delimiter_example() -> {split_first([65, 13, 10, 66]) == None{} : Maybe<&2, BytePair()>}:
  {==}

def mixed_case_repeated_example() -> {parse_head(Bytes.encode("HTTP/1.1 200 OK\r\nX-Test: first\r\nx-TEST: second\r\n\r\n")) == Some{Head{Bytes.encode("HTTP/1.1 200 OK"), [Request.Header{"x-test", Bytes.encode("first")}, Request.Header{"x-test", Bytes.encode("second")}]}} : Maybe<&2, Head>}:
  {==}

def lookup_example() -> {header_values(Head{Bytes.encode("HTTP/1.1 200 OK"), [Request.Header{"x-test", Bytes.encode("first")}, Request.Header{"x-test", Bytes.encode("second")}]}, "X-TEST") == [Bytes.encode("first"), Bytes.encode("second")] : List<&2, List<&2, U32>>}:
  {==}

def numeric_status_example() -> {status(Head{Bytes.encode("HTTP/1.1 304 Not Modified"), []}) == 304 : U32}:
  {==}

def malformed_status_example() -> {parse_head(Bytes.encode("HTTP/1.1 2x0 OK\r\n\r\n")) == None{} : Maybe<&2, Head>}:
  {==}

def trailing_bytes_example() -> {parse_head(Bytes.encode("HTTP/1.1 200 OK\r\n\r\nextra")) == None{} : Maybe<&2, Head>}:
  {==}
