import Base
import ../../../src/serve.bend as Serve
import ../../../src/http/request.bend as R
import ../../../src/http/bytes.bend as Bytes

def app(req: R.Req, body: List<&2, U32>) -> List<&2, U32>:
  +bytes = body
  Bytes.append(Bytes.encode("HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: " ++ Nat.show(List.length(&2, U32, bytes)) ++ "\r\n\r\n"), bytes)

def main() -> IO(Unit):
  do IO<Unit>:
    env : Result<&1, &1, U32 & String, String> <- IO.get_env("BODY_LIMIT")
    limit : U32 = Serve.port_or(env, 1048576)
    Serve.serve_config(~app, Serve.Config{8788, limit})
