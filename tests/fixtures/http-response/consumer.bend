import Base
import ../../../proof/response-spec.bend as Spec
import ../../../src/http/request.bend as Request
import ../../../src/http/response.bend as Response
import ../../../src/http/write_response.bend as Write

def text(status: U32, s: String) -> Response.Res:
  Response.text(status, s)

def write(method: Request.Method, r: Response.Res) -> List<&2, U32>:
  Write.write(method, r)

def checked(method: Request.Method, r: Response.Res) -> Result<&2, &2, Write.WriteError, List<&2, U32>>:
  Write.checked(method, r)

def utf8(s: String) -> List<&2, U32>:
  Response.utf8(s)

# Exercise the independent law observers through their JavaScript artifact.

def split_first(xs: List<&2, U32>) -> Maybe<&2, Spec.BytePair()>:
  Spec.split_first(xs)

def parse_head(xs: List<&2, U32>) -> Maybe<&2, Spec.Head>:
  Spec.parse_head(xs)

def header_values(h: Spec.Head, n: String) -> List<&2, List<&2, U32>>:
  Spec.header_values(h, n)
