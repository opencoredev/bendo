import Base
import ./common.bend as C

type Frame is Data:
  Frame{headers: String, body: String, expected: U32, actual: U32}

def finish(+body: String, +headers: String) -> Frame:
  Frame{headers, body, C.content_length(String.lines(headers)), C.utf8_size(body)}

# A single recursive def switches from scanning to finishing on the next call.
def scan(xs: String, done: Bool, +state: U32, acc: String) -> Maybe<&2, Frame>:
  match xs done:
    case rest True{}:
      Some{finish(rest, String.reverse(acc))}
    case SNil{} False{}: None{}
    case SCon{Chr{+h}, t} False{}:
      scan(t, Bool.and(U32.is_eq(state, 854541), U32.is_eq(h, 10)), ((state * 256 + h) .&. 16777215 : U32), SCon{Chr{h}, acc})

def parse(xs: String) -> Maybe<&2, Frame>:
  scan(xs, False{}, 0, SNil{})
