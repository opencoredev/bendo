# Buffered responses. Bodies and representation witnesses contain octets.
import Base
import ./bytes.bend as Bytes
import ./request.bend as Request

type Res is Data:
  Res{status: U32, headers: List<&2, Request.Header>, body: List<&2, U32>, representation: Maybe<&2, List<&2, U32>>}

# Replace non-scalar Char values, as UTF-8 encoders do for malformed text.
def scalar_valid(c: U32, valid: Bool) -> U32:
  match valid:
    case True{}:
      c
    case False{}:
      65533

def scalar(+c: U32) -> U32:
  scalar_valid(c, (c <= 1114111 : U32) && Bool.not((c >= 55296 : U32) && (c <= 57343 : U32)))

def utf8_four(+c: U32, tail: List<&2, U32>, short: Bool) -> List<&2, U32>:
  match short:
    case True{}:
      (224 + (c / 4096) : U32) <> (128 + ((c / 64) % 64) : U32) <> (128 + (c % 64) : U32) <> tail
    case False{}:
      (240 + (c / 262144) : U32) <> (128 + ((c / 4096) % 64) : U32) <> (128 + ((c / 64) % 64) : U32) <> (128 + (c % 64) : U32) <> tail

def utf8_three(+c: U32, tail: List<&2, U32>, short: Bool) -> List<&2, U32>:
  match short:
    case True{}:
      (192 + (c / 64) : U32) <> (128 + (c % 64) : U32) <> tail
    case False{}:
      utf8_four(c, tail, (c < 65536 : U32))

def utf8_one(+c: U32, tail: List<&2, U32>, ascii: Bool) -> List<&2, U32>:
  match ascii:
    case True{}:
      c <> tail
    case False{}:
      utf8_three(c, tail, (c < 2048 : U32))

def utf8_char(+c: U32, tail: List<&2, U32>) -> List<&2, U32>:
  utf8_one(c, tail, (c < 128 : U32))

def utf8(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      []
    case SCon{Chr{c}, t}:
      utf8_char(scalar(c), utf8(t))

def octets(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case c <> t:
      (c <= 255 : U32) && octets(t)

def representation_valid(r: Maybe<&2, List<&2, U32>>) -> Bool:
  match r:
    case None{}:
      True{}
    case Some{xs}:
      octets(xs)

def valid(r: Res) -> Bool:
  match r:
    case Res{+s, hs, b, rep}:
      (s >= 100 : U32) && (s <= 599 : U32) && Request.headers_valid(hs) && octets(b) && representation_valid(rep)

def body(status: U32, headers: List<&2, Request.Header>, bytes: List<&2, U32>) -> Res:
  Res{status, headers, bytes, None{}}

def text(status: U32, s: String) -> Res:
  body(status, [Request.Header{"content-type", Bytes.encode("text/plain; charset=utf-8")}], utf8(s))

# The witness is the exact selected representation a matching GET would send.
def not_modified(headers: List<&2, Request.Header>, representation: Maybe<&2, List<&2, U32>>) -> Res:
  Res{304, headers, [], representation}

# IANA HTTP status code registry, consulted 2026-10-22. Registry lifecycle
# annotations are not part of a reason phrase. Unassigned codes use "".
def reason(status: U32) -> String:
  match status:
    case 100:
      "Continue"
    case 101:
      "Switching Protocols"
    case 102:
      "Processing"
    case 103:
      "Early Hints"
    case 104:
      "Upload Resumption Supported"
    case 200:
      "OK"
    case 201:
      "Created"
    case 202:
      "Accepted"
    case 203:
      "Non-Authoritative Information"
    case 204:
      "No Content"
    case 205:
      "Reset Content"
    case 206:
      "Partial Content"
    case 207:
      "Multi-Status"
    case 208:
      "Already Reported"
    case 226:
      "IM Used"
    case 300:
      "Multiple Choices"
    case 301:
      "Moved Permanently"
    case 302:
      "Found"
    case 303:
      "See Other"
    case 304:
      "Not Modified"
    case 305:
      "Use Proxy"
    case 307:
      "Temporary Redirect"
    case 308:
      "Permanent Redirect"
    case 400:
      "Bad Request"
    case 401:
      "Unauthorized"
    case 402:
      "Payment Required"
    case 403:
      "Forbidden"
    case 404:
      "Not Found"
    case 405:
      "Method Not Allowed"
    case 406:
      "Not Acceptable"
    case 407:
      "Proxy Authentication Required"
    case 408:
      "Request Timeout"
    case 409:
      "Conflict"
    case 410:
      "Gone"
    case 411:
      "Length Required"
    case 412:
      "Precondition Failed"
    case 413:
      "Content Too Large"
    case 414:
      "URI Too Long"
    case 415:
      "Unsupported Media Type"
    case 416:
      "Range Not Satisfiable"
    case 417:
      "Expectation Failed"
    case 421:
      "Misdirected Request"
    case 422:
      "Unprocessable Content"
    case 423:
      "Locked"
    case 424:
      "Failed Dependency"
    case 425:
      "Too Early"
    case 426:
      "Upgrade Required"
    case 428:
      "Precondition Required"
    case 429:
      "Too Many Requests"
    case 431:
      "Request Header Fields Too Large"
    case 451:
      "Unavailable For Legal Reasons"
    case 500:
      "Internal Server Error"
    case 501:
      "Not Implemented"
    case 502:
      "Bad Gateway"
    case 503:
      "Service Unavailable"
    case 504:
      "Gateway Timeout"
    case 505:
      "HTTP Version Not Supported"
    case 506:
      "Variant Also Negotiates"
    case 507:
      "Insufficient Storage"
    case 508:
      "Loop Detected"
    case 510:
      "Not Extended"
    case 511:
      "Network Authentication Required"
    case _:
      ""
