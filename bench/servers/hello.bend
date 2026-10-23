import Base
import ../../src/http.bend as Http
import ../../src/serve.bend as Serve
import ../../src/http/request.bend as R
import ../../src/http/bytes.bend as Bytes

def app(req: R.Req, body: List<&2, U32>) -> List<&2, U32>:
  Bytes.encode(Http.text("Hello, world!"))

def main() -> IO(Unit):
  Serve.serve(~app, 8787)
