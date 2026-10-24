# Pure case-insensitive field replacement, shared by retained policies.
import Base
import ../http/request.bend as Request
import ../http/bytes.bend as Bytes

def keep(h: Request.Header, tail: List<&2, Request.Header>, same: Bool) -> List<&2, Request.Header>:
  match same:
    case True{}: tail
    case False{}: h <> tail

def without(hs: List<&2, Request.Header>, +name: String) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+k, v} <> t:
      keep(Request.Header{k, v}, without(t, name), String.eq(Bytes.fold(k), name))

def value(v: List<&2, U32>, rest: List<&2, List<&2, U32>>, same: Bool) -> List<&2, List<&2, U32>>:
  match same:
    case True{}: v <> rest
    case False{}: rest

# Every matching field value in original order, ignoring ASCII name case.
def values(hs: List<&2, Request.Header>, +name: String) -> List<&2, List<&2, U32>>:
  match hs:
    case Nil{}: []
    case Request.Header{k, v} <> t: value(v, values(t, name), String.eq(Bytes.fold(k), name))
