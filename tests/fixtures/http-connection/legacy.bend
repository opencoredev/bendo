import Base
import ../../../src/serve.bend as Serve
import ../../../src/http/request.bend as R
import ../../../src/http/bytes.bend as Bytes

def app(req: R.Req, body: List<&2, U32>) -> List<&2, U32>:
  Bytes.append(Bytes.encode("HTTP/1.1 200 Custom\r\nCoNnEcTiOn: keep-alive\r\nX-Custom: untouched\r\nX-Dup: one\r\nconnection: upgrade, keep-alive\r\nX-Dup: two\r\nContent-Length: 7\r\n\r\n"), [0, 255, 13, 10, 13, 10, 42])

def main() -> IO(Unit):
  Serve.serve(~app, 8787)
