import Base
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
