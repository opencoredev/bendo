# CONNECT authority-form is rejected by the request parser today. Exercise the
# transport framing boundary directly so later tunnel support keeps this rule.
import Base
import ../../../src/http/stream_response.bend as StreamResponse
import ../../../src/http/response.bend as Response
import ../../../src/http/request.bend as Request
import ../../../src/http/write_response.bend as Write

def headers(res: Response.Res) -> String:
  Response.Res{status, hs, body, rep} = res
  Write.headers_text(hs)

def main() -> IO(Unit):
  IO.print("connect205:" ++ headers(StreamResponse.frame(Request.Connect{}, Response.body(205, [Request.Header{"content-length", [55]}, Request.Header{"transfer-encoding", [120]}], []), None{}, False{})))
