# Expected framing from RFC 9110; independent of the writer's policy helpers.
import Base
import ../src/http/bytes.bend as B
import ../src/http/response.bend as Response

def representation_lengths(rep: Maybe<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match rep:
    case None{}:
      []
    case Some{body}:
      [B.encode(Nat.show(List.length(&2, U32, body)))]

def content_lengths(body: List<&2, U32>, reset: Bool) -> List<&2, List<&2, U32>>:
  match reset:
    case True{}:
      [B.encode("0")]
    case False{}:
      [B.encode(Nat.show(List.length(&2, U32, body)))]

def selected_lengths(body: List<&2, U32>, rep: Maybe<&2, List<&2, U32>>, reset: Bool, unmodified: Bool) -> List<&2, List<&2, U32>>:
  match unmodified:
    case True{}:
      representation_lengths(rep)
    case False{}:
      content_lengths(body, reset)

def ordinary_lengths(+status: U32, body: List<&2, U32>, rep: Maybe<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  selected_lengths(body, rep, U32.is_eq(status, 205), U32.is_eq(status, 304))

def permitted_lengths(status: U32, body: List<&2, U32>, rep: Maybe<&2, List<&2, U32>>, forbidden: Bool) -> List<&2, List<&2, U32>>:
  match forbidden:
    case True{}:
      []
    case False{}:
      ordinary_lengths(status, body, rep)

def get_lengths(res: Response.Res) -> List<&2, List<&2, U32>>:
  match res:
    case Response.Res{+status, hs, body, rep}:
      permitted_lengths(status, body, rep, ((status >= 100 : U32) && (status < 200 : U32)) || U32.is_eq(status, 204))
