# Hello from Bendo. Run: bend examples/hello/main.bend -o hello && ./hello
import Base
import ../../src/http.bend as Http
import ../../src/http/request.bend as R
import ../../src/http/bytes.bend as Bytes
import ../../src/serve.bend as Serve

def app(req: R.Req, body: List<&2, U32>) -> List<&2, U32>:
  Bytes.encode(Http.text("Hello from Bendo! You asked for " ++ R.target(req)))

def main() -> IO(Unit):
  Serve.serve(~app, 8787)
