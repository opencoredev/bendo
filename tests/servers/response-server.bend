import Base
import ../../src/http/bytes.bend as Bytes
import ../../src/http/request.bend as Request
import ../../src/http/parse.bend as Parse
import ../../src/http/response.bend as Response
import ../../src/http/write_response.bend as Write

def route(path: String) -> Response.Res:
  match path:
    case "/101":
      Response.body(101, [Request.Header{"upgrade", Bytes.encode("websocket")}, Request.Header{"connection", Bytes.encode("Upgrade")}], Response.utf8("discard me"))
    case "/200":
      Response.text(200, "hé 🌍")
    case "/204":
      Response.text(204, "discard me")
    case "/205":
      Response.text(205, "discard me")
    case "/304":
      Response.not_modified([], None{})
    case "/304-known":
      Response.not_modified([], Some{Response.utf8("hé 🌍")})
    case "/binary":
      Response.body(200, [], [0, 255, 128, 13, 10, 13, 10, 42])
    case "/framing":
      Response.body(200, [Request.Header{"content-length", Bytes.encode("999")}, Request.Header{"transfer-encoding", Bytes.encode("chunked")}, Request.Header{"x-tag", Bytes.encode("one")}, Request.Header{"x-tag", Bytes.encode("two")}], [120])
    case "/invalid":
      Response.body(200, [Request.Header{"x-bad", [13, 10, 13, 10]}], [])
    case _:
      Response.text(404, "Not Found")

def respond(parsed: Request.ParseResult) -> List<&2, U32>:
  match parsed:
    case Request.Parsed{Request.Req{m, p, q, v, hs}, rest}:
      Write.write(m, route(p))
    case _:
      Write.write(Request.Get{}, Response.body(400, [], []))

def sent(m: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

def finished(s: Socket, result: Request.ParseResult) -> IO(Unit):
  do IO<Unit>:
    out : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send_bytes(s, respond(result))
    sent(out)

def received(m: Socket & Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, state: Parse.State) -> Socket & (Parse.State & Request.ParseResult):
  (sock, r) = m
  match r:
    case Done{Some{bytes}}:
      (sock, Parse.feed(bytes, state))
    case _:
      (sock, (state, Request.Rejected{Request.InvalidRequestLine{}}))

def talk(fuel: Nat, m: Socket & (Parse.State & Request.ParseResult)) -> IO(Unit):
  match fuel:
    case 0n:
      (sock, step) = m
      Socket.close(sock)
    case 1n+f:
      (sock, step) = m
      (state, result) = step
      match result:
        case Request.NeedMore{}:
          do IO<Unit>:
            m : Socket & Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>> <- TCP.recv_bytes(sock, 65536)
            talk(f, received(m, state))
        case _:
          finished(sock, result)

def read(s: Socket) -> IO(Unit):
  talk(128n, (s, (Parse.initial(), Request.NeedMore{})))

def conn(m: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    IO.spawn(Unit, read(s))
    return l

@unsafe
def loop(l: Listener) -> IO(Unit):
  do IO<Unit>:
    m : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- conn(m)
    loop(l2)

def port_read(m: Maybe<&2, U32>) -> U32:
  match m:
    case Some{p}:
      p
    case None{}:
      18789

def port_or(r: Result<&1, &1, U32 & String, String>, fallback: U32) -> U32:
  match r:
    case Done{s}:
      port_read(U32.read(s))
    case Fail{e}:
      fallback

def main() -> IO(Unit):
  do IO<Unit>:
    env : Result<&1, &1, U32 & String, String> <- IO.get_env("PORT")
    port : U32 = port_or(env, 18789)
    listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    loop(listener)
