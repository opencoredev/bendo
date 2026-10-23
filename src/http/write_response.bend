# Pure buffered HTTP/1.1 writer; no connection policy or streaming yet.
import Base
import ./bytes.bend as Bytes
import ./request.bend as Request
import ./response.bend as Response

def informational(+status: U32) -> Bool:
  (status >= 100 : U32) && (status < 200 : U32)

def forbidden(+status: U32) -> Bool:
  informational(status) || U32.is_eq(status, 204)

def allows_body(+status: U32) -> Bool:
  Bool.not(forbidden(status) || U32.is_eq(status, 205) || U32.is_eq(status, 304))

def tunnel(method: Request.Method, +status: U32) -> Bool:
  match method:
    case Request.Connect{}:
      (status >= 200 : U32) && (status < 300 : U32)
    case _:
      False{}

def is_head(method: Request.Method) -> Bool:
  match method:
    case Request.Head{}:
      True{}
    case _:
      False{}

def user_header(h: Request.Header) -> Bool:
  match h:
    case Request.Header{+n, v}:
      Bool.not(String.eq(n, "content-length") || String.eq(n, "transfer-encoding"))

def headers(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  List.filter(~Request.Header, ~user_header, hs)

def length_header(n: Nat) -> Request.Header:
  Request.Header{"content-length", Bytes.encode(Nat.show(n))}

def representation_length(rep: Maybe<&2, List<&2, U32>>, hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match rep:
    case None{}:
      hs
    case Some{b}:
      length_header(Response.length(b)) <> hs

def reset_headers(body: List<&2, U32>, hs: List<&2, Request.Header>, reset: Bool) -> List<&2, Request.Header>:
  match reset:
    case True{}:
      length_header(0n) <> hs
    case False{}:
      length_header(Response.length(body)) <> hs

def modified_headers(body: List<&2, U32>, rep: Maybe<&2, List<&2, U32>>, hs: List<&2, Request.Header>, reset: Bool, unmodified: Bool) -> List<&2, Request.Header>:
  match unmodified:
    case True{}:
      representation_length(rep, hs)
    case False{}:
      reset_headers(body, hs, reset)

def normal_headers(+status: U32, body: List<&2, U32>, rep: Maybe<&2, List<&2, U32>>, hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  modified_headers(body, rep, hs, U32.is_eq(status, 205), U32.is_eq(status, 304))

def framing_headers(status: U32, body: List<&2, U32>, rep: Maybe<&2, List<&2, U32>>, hs: List<&2, Request.Header>, none: Bool) -> List<&2, Request.Header>:
  match none:
    case True{}:
      hs
    case False{}:
      normal_headers(status, body, rep, hs)

def response_headers(+method: Request.Method, r: Response.Res) -> List<&2, Request.Header>:
  match r:
    case Response.Res{+s, hs, b, rep}:
      framing_headers(s, b, rep, headers(hs), forbidden(s) || tunnel(method, s))

# Render complete lines before encoding the head; body bytes stay untouched.
def status_text(+status: U32) -> String:
  "HTTP/1.1 " ++ Nat.show(U32.to_nat(status)) ++ " " ++ Response.reason(status)

def header_text(h: Request.Header) -> String:
  match h:
    case Request.Header{n, v}:
      n ++ ": " ++ Bytes.ascii(v)

def headers_text(hs: List<&2, Request.Header>) -> String:
  match hs:
    case Nil{}:
      ""
    case h <> t:
      "\r\n" ++ header_text(h) ++ headers_text(t)

# Content before the terminating CRLFCRLF, with neither trailing CRLF.
def prefix_text(+method: Request.Method, +r: Response.Res) -> String:
  match r:
    case Response.Res{s, hs, b, rep}:
      status_text(s) ++ headers_text(response_headers(method, r))

def prefix(method: Request.Method, r: Response.Res) -> List<&2, U32>:
  Bytes.encode(prefix_text(method, r))

def head(method: Request.Method, r: Response.Res) -> List<&2, U32>:
  Bytes.append(prefix(method, r), [13, 10, 13, 10])

def emitted_body(body: List<&2, U32>, none: Bool) -> List<&2, U32>:
  match none:
    case True{}:
      []
    case False{}:
      body

def payload(+method: Request.Method, r: Response.Res) -> List<&2, U32>:
  match r:
    case Response.Res{+s, hs, b, rep}:
      emitted_body(b, is_head(method) || Bool.not(allows_body(s)) || tunnel(method, s))

def serialize(+method: Request.Method, +r: Response.Res) -> List<&2, U32>:
  Bytes.append(head(method, r), payload(method, r))

type WriteError is Data:
  InvalidResponse{}

# Raw constructors remain available, so validate at this serialization boundary.
def checked_valid(method: Request.Method, r: Response.Res, valid: Bool) -> Result<&2, &2, WriteError, List<&2, U32>>:
  match valid:
    case False{}:
      Fail{InvalidResponse{}}
    case True{}:
      Done{serialize(method, r)}

def checked(method: Request.Method, +r: Response.Res) -> Result<&2, &2, WriteError, List<&2, U32>>:
  checked_valid(method, r, Response.valid(r))

# Convenience writer: invalid input becomes a method-aware empty 500 response.
def write_valid(+method: Request.Method, r: Response.Res, valid: Bool) -> List<&2, U32>:
  match valid:
    case False{}:
      serialize(method, Response.body(500, [], []))
    case True{}:
      serialize(method, r)

def write(method: Request.Method, +r: Response.Res) -> List<&2, U32>:
  write_valid(method, r, Response.valid(r))
