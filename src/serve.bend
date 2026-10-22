# The accept loop. The app is a template (~app): Bend cannot copy
# functions, so the handler is inlined at compile time and may run once
# per request. Each connection runs in its own computation (IO.spawn).
# The loop is @unsafe because it runs until the process is killed.
import Base

def sent(m: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

def reply(~app: String -> String, m: Socket & Result<&1, &1, U32 & String, Maybe<&1, String>>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{Some{req}}:
      do IO<Unit>:
        out : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send(s, app(req))
        sent(out)
    case Done{None{}}:
      Socket.close(s)
    case Fail{e}:
      Socket.close(s)

def talk(~app: String -> String, s: Socket) -> IO(Unit):
  do IO<Unit>:
    read : Socket & Result<&1, &1, U32 & String, Maybe<&1, String>> <- TCP.recv(s, 65536)
    reply(~app, read)

def conn(~app: String -> String, m: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    IO.spawn(Unit, talk(~app, s))
    return l

@unsafe
def loop(~app: String -> String, l: Listener) -> IO(Unit):
  do IO<Unit>:
    m  : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- conn(~app, m)
    loop(~app, l2)

def port_read(m: Maybe<&2, U32>, +fallback: U32) -> U32:
  match m:
    case Some{p}:
      p
    case None{}:
      fallback

def port_or(r: Result<&1, &1, U32 & String, String>, +fallback: U32) -> U32:
  match r:
    case Done{s}:
      port_read(U32.read(s), fallback)
    case Fail{e}:
      fallback

# Serves ~app on 127.0.0.1, on $PORT or the given port.
def serve(~app: String -> String, +fallback: U32) -> IO(Unit):
  do IO<Unit>:
    env : Result<&1, &1, U32 & String, String> <- IO.get_env("PORT")
    +port : U32 = port_or(env, fallback)
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    IO.print("bendo listening on http://127.0.0.1:" ++ U32.show(port))
    loop(~app, l)
