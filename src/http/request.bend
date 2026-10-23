import Base
import ./bytes.bend as Bytes

type Method is Data:
  Get{}
  Head{}
  Post{}
  Put{}
  Delete{}
  Connect{}
  Options{}
  Trace{}
  Patch{}
  Extension{token: String}

def method(s: String) -> Method:
  match s:
    case "GET":
      Get{}
    case "HEAD":
      Head{}
    case "POST":
      Post{}
    case "PUT":
      Put{}
    case "DELETE":
      Delete{}
    case "CONNECT":
      Connect{}
    case "OPTIONS":
      Options{}
    case "TRACE":
      Trace{}
    case "PATCH":
      Patch{}
    case x:
      Extension{x}

def method_text(m: Method) -> String:
  match m:
    case Get{}:
      "GET"
    case Head{}:
      "HEAD"
    case Post{}:
      "POST"
    case Put{}:
      "PUT"
    case Delete{}:
      "DELETE"
    case Connect{}:
      "CONNECT"
    case Options{}:
      "OPTIONS"
    case Trace{}:
      "TRACE"
    case Patch{}:
      "PATCH"
    case Extension{s}:
      s

type Version is Data:
  Http10{}
  Http11{}

type Header is Data:
  Header{name: String, value: List<&2, U32>}

# Body framing belongs to BND-8. Parsed returns all remaining octets separately.
type Req is Data:
  Req{method: Method, path: String, query: Maybe<&2, String>, version: Version, headers: List<&2, Header>}

type ParseError is Data:
  InvalidOctet{}
  InvalidLineEnding{}
  InvalidRequestLine{}
  InvalidMethod{}
  InvalidTarget{}
  UnsupportedTarget{}
  InvalidVersion{}
  InvalidHeaderName{}
  InvalidHeaderValue{}
  ObsFold{}

type ParseResult is Data:
  NeedMore{}
  Rejected{error: ParseError}
  Parsed{req: Req, rest: List<&2, U32>}

def query_text(q: Maybe<&2, String>) -> String:
  match q:
    case None{}:
      ""
    case Some{s}:
      "?" ++ s

def target(r: Req) -> String:
  match r:
    case Req{m, p, q, v, hs}:
      p ++ query_text(q)

def version_text(v: Version) -> String:
  match v:
    case Http10{}:
      "HTTP/1.0"
    case Http11{}:
      "HTTP/1.1"

def lookup_step(value: List<&2, U32>, rest: List<&2, List<&2, U32>>, same: Bool) -> List<&2, List<&2, U32>>:
  match same:
    case True{}:
      value <> rest
    case False{}:
      rest

def lookup_folded(hs: List<&2, Header>, +name: String) -> List<&2, List<&2, U32>>:
  match hs:
    case Nil{}:
      []
    case Header{n, v} <> t:
      lookup_step(v, lookup_folded(t, name), String.eq(n, name))

# Every matching value, in arrival order. Never combine repeated fields.
def lookup(hs: List<&2, Header>, name: String) -> List<&2, List<&2, U32>>:
  lookup_folded(hs, Bytes.fold(name))

def query_valid(q: Maybe<&2, String>) -> Bool:
  match q:
    case None{}:
      True{}
    case Some{s}:
      Bytes.uri(s, True{})

def target_valid(m: Method, p: String, q: Maybe<&2, String>) -> Bool:
  match m p q:
    case Options{} "*" None{}:
      True{}
    case Connect{} _ _:
      False{}
    case _ SCon{Chr{47}, t} q:
      Bytes.uri(t, False{}) && query_valid(q)
    case _ _ _:
      False{}

def extension_valid(+s: String) -> Bool:
  Bytes.token(s) && Bool.not(String.eq(s, "GET") || String.eq(s, "HEAD") || String.eq(s, "POST") || String.eq(s, "PUT") || String.eq(s, "DELETE") || String.eq(s, "CONNECT") || String.eq(s, "OPTIONS") || String.eq(s, "TRACE") || String.eq(s, "PATCH"))

def method_valid(m: Method) -> Bool:
  match m:
    case Extension{+s}:
      extension_valid(s)
    case _:
      True{}

def value_start(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case c <> t:
      Bool.not(Bytes.ows(c))

def header_valid(h: Header) -> Bool:
  match h:
    case Header{+n, +v}:
      Bytes.token(n) && String.eq(n, Bytes.fold(n)) && Bytes.value(v) && value_start(v) && value_start(List.reverse(&2, U32, v))

def headers_valid(hs: List<&2, Header>) -> Bool:
  match hs:
    case Nil{}:
      True{}
    case h <> t:
      header_valid(h) && headers_valid(t)

# Independent structural predicate, with no invocation of parse or write.
def well_formed(r: Req) -> Bool:
  match r:
    case Req{+m, p, q, v, hs}:
      method_valid(m) && target_valid(m, p, q) && headers_valid(hs)
