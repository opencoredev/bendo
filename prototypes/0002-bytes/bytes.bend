import Base
import ./common.bend as C

def to_chars(xs: List<&2, U32>) -> List<&2, Char>:
  match xs:
    case Nil{}: Nil{}
    case Con{h, t}: Con{Chr{h}, to_chars(t)}

type Frame is Data:
  Frame{headers: String, body: List<&2, U32>, expected: U32, actual: U32}

def finish(+body: List<&2, U32>, +headers: String) -> Frame:
  Frame{headers, body, C.content_length(String.lines(headers)), U32.from_nat(List.length(&2, U32, body))}

# A single recursive def switches from scanning to finishing on the next call.
def scan(xs: List<&2, U32>, done: Bool, +state: U32, acc: List<&2, U32>) -> Maybe<&2, Frame>:
  match xs done:
    case rest True{}:
      Some{finish(rest, String.from_list(to_chars(List.reverse(&2, U32, acc))))}
    case Nil{} False{}: None{}
    case Con{+h, t} False{}:
      scan(t, Bool.and(U32.is_eq(state, 854541), U32.is_eq(h, 10)), ((state * 256 + h) .&. 16777215 : U32), Con{h, acc})

def parse(xs: List<&2, U32>) -> Maybe<&2, Frame>:
  scan(xs, False{}, 0, Nil{})
