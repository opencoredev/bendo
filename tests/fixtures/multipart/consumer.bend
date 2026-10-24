import Base
import ../../../src/http/bytes.bend as Bytes
import ../../../src/data/form.bend as Form
import ../../../src/data/multipart.bend as M

def parse(ct: String, body: List<&2, U32>, limits: M.Limits) -> Result<&2, &2, M.Error, List<&2, M.Part>>:
  Form.parse_body_with_limits(ct, body, limits)

# Retained parser before the proof-translation refactor, for differential tests.
def headers_before(xs: List<&2, U32>, +left: U32, line: List<&2, U32>, state: Result<&2, &2, M.Error, M.Meta>) -> Result<&2, &2, M.Error, M.Head>:
  match xs left line state:
    case _ _ _ Fail{e}:
      Fail{e}
    case 13 <> 10 <> t 0 _ _:
      Fail{M.TooLarge{}}
    case 13 <> 10 <> t 1 _ _:
      Fail{M.TooLarge{}}
    case 13 <> 10 <> t left Nil{} Done{meta}:
      M.header_end(meta, t, (left >= 2 : U32))
    case 13 <> 10 <> 32 <> t left line Done{meta}:
      headers_before(32 <> t, U32.sub(left, 2), line, Done{meta})
    case 13 <> 10 <> 9 <> t left line Done{meta}:
      headers_before(9 <> t, U32.sub(left, 2), line, Done{meta})
    case 13 <> 10 <> t left line Done{meta}:
      headers_before(t, U32.sub(left, 2), [], M.header_line(line, meta, (left >= 2 : U32)))
    case _ 0 _ _:
      Fail{M.TooLarge{}}
    case Nil{} _ _ _:
      Fail{M.Malformed{}}
    case 32 <> t left Nil{} Done{meta}:
      Fail{M.Malformed{}}
    case 9 <> t left Nil{} Done{meta}:
      Fail{M.Malformed{}}
    case +c <> t left line Done{meta}:
      headers_before(t, U32.sub(left, 1), c <> line, M.header_byte(meta, Bytes.value_octet(c)))


def headers_after(xs: List<&2, U32>, left: U32, line: List<&2, U32>, state: Result<&2, &2, M.Error, M.Meta>) -> Result<&2, &2, M.Error, M.Head>:
  M.headers_go(xs, left, line, state)
