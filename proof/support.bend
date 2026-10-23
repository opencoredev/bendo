# Predicates used only to state proof-support claims.
import Base
import ../src/http/bytes.bend as B
import ../src/http/request.bend as R

def free(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{c}, t}:
      Bool.not(U32.is_eq(c, 32)) && free(t)

def path_clear(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{c}, t}:
      Bool.not(U32.is_eq(c, 63)) && path_clear(t)

def printable_octet(+c: U32) -> Bool:
  (c >= 32 : U32) && (c <= 126 : U32)

def printable(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case +c <> t:
      printable_octet(c) && printable(t)

def header_content(h: R.Header) -> List<&2, U32>:
  match h:
    case R.Header{n, v}:
      B.append(B.encode(n), 58 <> 32 <> v)

def headers_scannable(hs: List<&2, R.Header>) -> Bool:
  match hs:
    case Nil{}:
      True{}
    case +h <> t:
      B.value(header_content(h)) && headers_scannable(t)

# Independent lookup specification: select whole headers first, preserving
# their order, then project their values. No lookup implementation is used.
def select_header(h: R.Header, rest: List<&2, R.Header>, same: Bool) -> List<&2, R.Header>:
  match same:
    case True{}:
      h <> rest
    case False{}:
      rest

def matching_headers(hs: List<&2, R.Header>, +name: String) -> List<&2, R.Header>:
  match hs:
    case Nil{}:
      []
    case R.Header{+n, v} <> t:
      select_header(R.Header{n, v}, matching_headers(t, name), String.eq(n, name))

def header_values(hs: List<&2, R.Header>) -> List<&2, List<&2, U32>>:
  match hs:
    case Nil{}:
      []
    case R.Header{n, v} <> t:
      v <> header_values(t)

def matching_values(hs: List<&2, R.Header>, name: String) -> List<&2, List<&2, U32>>:
  header_values(matching_headers(hs, B.fold(name)))
