# Body bytes are supplied separately from Req until the connection layer owns
# a complete request body. These helpers are pure and do not inspect a context.
import Base
import ./json.bend as Json
import ./utf8.bend as Utf8
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes

def req_json(body: List<&2, U32>) -> Result<&2, &2, Json.Error, Json.Json>:
  Json.parse(body)

def response(status: U32, written: Result<&2, &2, Json.Error, String>) -> Result<&2, &2, Json.Error, Response.Res>:
  match written:
    case Fail{e}: Fail{e}
    case Done{s}: Done{Response.body(status, [Request.Header{"content-type", Bytes.encode("application/json; charset=utf-8")}], Utf8.encode(s))}

def json(status: U32, value: Json.Json) -> Result<&2, &2, Json.Error, Response.Res>:
  response(status, Json.stringify(value))
