import Base
import ./strings.bend as P
import ./common.bend as C

# Byte mode only maps the ASCII response header to bytes.
def ascii(s: String) -> List<&2, U32>:
  match s:
    case SNil{}: Nil{}
    case SCon{Chr{x}, t}: Con{x, ascii(t)}

def close_sent(m: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

def emit(s: Socket, body: String, actual: U32) -> IO(Unit):
  do IO<Unit>:
    header : String = "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: " ++ U32.show(actual) ++ "\r\n\r\n"
    sent : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send(s, header ++ body)
    close_sent(sent)

# One mode-switching shell: receive, parse, and either read again or echo.
# Explicitly unsafe; the parsers above remain pure and terminating.
@unsafe
def connection(s: Socket, acc: String, frame: Maybe<&2, P.Frame>, ready: Bool, +max: U32) -> IO(Unit):
  match frame ready:
    case Some{P.Frame{headers, body, expected, actual}} True{}:
      emit(s, body, actual)
    case _ _:
      do IO<Unit>:
        got : Socket & Result<&1, &1, U32 & String, Maybe<&1, String>> <- TCP.recv(s, max)
        received(got, acc, max)

@unsafe
def received(got: Socket & Result<&1, &1, U32 & String, Maybe<&1, String>>, acc: String, max: U32) -> IO(Unit):
  (next, r) = got
  do IO<Unit>:
    data : Maybe<&1, String> <- IO.pass(Maybe<&1, String>, r)
    on_data(next, acc, data, max)

@unsafe
def on_frame(s: Socket, +acc: String, f: Maybe<&2, P.Frame>, max: U32) -> IO(Unit):
  match f:
    case None{}: connection(s, acc, None{}, False{}, max)
    case Some{P.Frame{+headers, +body, +expected, +actual}}:
      connection(s, acc, Some{P.Frame{headers, body, expected, actual}}, U32.is_ge(actual, expected), max)

@unsafe
def on_data(s: Socket, acc: String, data: Maybe<&1, String>, max: U32) -> IO(Unit):
  match data:
    case None{}: Socket.close(s)
    case Some{chunk}:
      +joined = String.append(acc, chunk)
      on_frame(s, joined, P.parse(joined), max)

@unsafe
def accept_loop(l: Listener, +max: U32) -> IO(Unit):
  do IO<Unit>:
    got : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    accepted(got, max)

@unsafe
def accepted(got: Listener & Result<&1, &1, U32 & String, Socket>, +max: U32) -> IO(Unit):
  (next, r) = got
  do IO<Unit>:
    s : Socket <- IO.pass(Socket, r)
    IO.spawn(Unit, connection(s, SNil{}, None{}, False{}, max))
    accept_loop(next, max)

def env_number(r: Result<&1, &1, U32 & String, String>, fallback: U32) -> U32:
  match r:
    case Done{s}: C.length_or(U32.read(s), fallback)
    case Fail{e}: fallback

def main() -> IO(Unit):
  do IO<Unit>:
    port_env : Result<&1, &1, U32 & String, String> <- IO.get_env("PORT")
    max_env : Result<&1, &1, U32 & String, String> <- IO.get_env("RECV_MAX")
    +max : U32 = env_number(max_env, 65536)
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", env_number(port_env, 18784)))
    IO.print("ready")
    accept_loop(l, max)
