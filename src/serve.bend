# One request per connection until BND-11 adds keep-alive. Pure input
# state lives in http/body.bend; this shell only reads, writes and closes.
import Base
import ./http/request.bend as R
import ./http/body.bend as Body

type Config is Data:
  Config{port: U32, body_limit: U32}

def defaults(port: U32) -> Config:
  Config{port, 1048576}

def sent(m: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

# Base TCP has no write-side shutdown. Keep the affine socket in this
# computation: IO.within would leave its losing receive alive after timeout.
type DrainEvent is Type:
  Drain{socket: Socket}
  Timed{socket: Socket, remaining: Nat}
  Polled{read: Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit>}

@unsafe
def drain(event: DrainEvent, +left: U32, +deadline: Nat) -> IO(Unit):
  match event:
    case Drain{s}:
      match left:
        case 0:
          Socket.close(s)
        case _:
          do IO<Unit>:
            now : Nat <- IO.now()
            drain(Timed{s, Nat.sub(deadline, now)}, left, deadline)
    case Timed{s, 0n}:
      Socket.close(s)
    case Timed{s, 1n+remaining}:
      do IO<Unit>:
        read : Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit> <- TCP.try_recv_bytes(s, U32.min(left, 4096), U32.from_nat(1n+remaining))
        drain(Polled{read}, left, deadline)
    case Polled{(s, Ready{Done{Some{xs}}})}:
      drain(Drain{s}, U32.sub(left, U32.from_nat(List.length(&2, U32, xs))), deadline)
    case Polled{(s, _)}:
      Socket.close(s)

def rejected(m: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>) -> IO(Unit):
  (s, result) = m
  match result:
    case Done{u}:
      do IO<Unit>:
        now : Nat <- IO.now()
        drain(Drain{s}, 4194304, Nat.add(now, 1000n))
    case Fail{e}:
      Socket.close(s)

def status_text(status: U32) -> String:
  match status:
    case 413:
      "413 Content Too Large"
    case 417:
      "417 Expectation Failed"
    case _:
      "400 Bad Request"

def reject(s: Socket, status: U32) -> IO(Unit):
  do IO<Unit>:
    out : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send(s, "HTTP/1.1 " ++ status_text(status) ++ "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
    rejected(out)

def continue_result(m: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>) -> IO(Socket):
  (s, r) = m
  do IO<Socket>:
    # Leave failures to the next receive; the socket is always owned/closed.
    return s

def interim(s: Socket, send: Bool) -> IO(Socket):
  match send:
    case False{}:
      IO.pure(Socket, s)
    case True{}:
      do IO<Socket>:
        out : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send(s, "HTTP/1.1 100 Continue\r\n\r\n")
        continue_result(out)

type ConnectionEvent is Type:
  Work{socket: Socket, state: Body.State}
  Fed{socket: Socket, pair: Body.State & Bool}
  Read{read: Socket & Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, state: Body.State}

@unsafe
def talk(~app: R.Req -> List<&2, U32> -> List<&2, U32>, event: ConnectionEvent, +limit: U32) -> IO(Unit):
  match event:
    case Work{s, Body.Complete{req, body, trailers, rest}}:
      do IO<Unit>:
        out : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send_bytes(s, app(req, body))
        sent(out)
    case Work{s, Body.Bad{status}}:
      reject(s, status)
    case Work{s, state}:
      IO.bind(Socket & Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit, TCP.recv_bytes(s, 4096), read => talk(~app, Read{read, state}, limit))
    case Read{(sock, Done{Some{xs}}), state}:
      talk(~app, Fed{sock, Body.feed(xs, state, limit)}, limit)
    case Fed{sock, (next, send)}:
      IO.bind(Socket, Unit, interim(sock, send), s => talk(~app, Work{s, next}, limit))
    case Read{(sock, Done{None{}}), state}:
      reject(sock, 400)
    case Read{(sock, Fail{e}), state}:
      Socket.close(sock)

def conn(~app: R.Req -> List<&2, U32> -> List<&2, U32>, m: Listener & Result<&1, &1, U32 & String, Socket>, limit: U32) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    IO.spawn(Unit, talk(~app, Work{s, Body.initial()}, limit))
    return l

@unsafe
def loop(~app: R.Req -> List<&2, U32> -> List<&2, U32>, l: Listener, +limit: U32) -> IO(Unit):
  do IO<Unit>:
    m : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- conn(~app, m, limit)
    loop(~app, l2, limit)

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

# Temporary config/handler surface; BND-12 adds the full server config,
# BND-11 the response writer/keep-alive, BND-21 body accessors on context.
def serve_config(~app: R.Req -> List<&2, U32> -> List<&2, U32>, config: Config) -> IO(Unit):
  Config{fallback, +limit} = config
  do IO<Unit>:
    env : Result<&1, &1, U32 & String, String> <- IO.get_env("PORT")
    +port : U32 = port_or(env, fallback)
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    IO.print("bendo listening on http://127.0.0.1:" ++ U32.show(port))
    loop(~app, l, limit)

def serve(~app: R.Req -> List<&2, U32> -> List<&2, U32>, port: U32) -> IO(Unit):
  serve_config(~app, defaults(port))
