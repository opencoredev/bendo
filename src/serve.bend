# Connection IO shell. Pure parsing, deadlines and persistence policy live
# in http/connection.bend. Each socket is owned by one spawned computation.
import Base
import ./http/request.bend as R
import ./http/connection.bend as Connection
import ./http/parse.bend as Parse
import ./router/router.bend as Router
import ./app/config.bend as Config
import ./app/manifest.bend as Manifest
import ./app/table.bend as Table
import ./app/handle.bend as Handle
import ./http/response.bend as Response
import ./http/write_response.bend as Write
import ./http/bytes.bend as Bytes

type Config is Data:
  Config{port: U32, body_limit: U32}

def defaults(port: U32) -> Config:
  Config{port, 1048576}

# Compatibility helper used by low-level consumers that own their wire output.
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

def reject(s: Socket, status: U32) -> IO(Unit):
  do IO<Unit>:
    out : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send_bytes(s, Write.write(R.Get{}, Response.body(status, Connection.headers([], True{}), [])))
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

type Reply is Data:
  Reply{bytes: List<&2, U32>, close: Bool}

type ConnectionEvent is Type:
  Tick{socket: Socket, state: Connection.State}
  Work{socket: Socket, state: Connection.State, action: Connection.Action}
  Fed{socket: Socket, pair: Connection.State & Bool}
  Read{read: Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit>, state: Connection.State}
  Replied{socket: Socket, state: Connection.State, rest: List<&2, U32>, reply: Reply}
  Sent{sent: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>, state: Connection.State, rest: List<&2, U32>, close: Bool}

def closing(+req: R.Req, state: Connection.State, config: Config.Config) -> Bool:
  Connection.State{input, count, phase, at} = state
  Connection.closing(req, count, config)

@unsafe
def talk(~Env: Data, ~app: R.Req -> List<&2, U32> -> Env -> Bool -> IO(Reply), event: ConnectionEvent, +env: Env, +config: Config.Config) -> IO(Unit):
  match event:
    case Tick{s, +state}:
      do IO<Unit>:
        now : Nat <- IO.now()
        talk(~Env, ~app, Work{s, state, Connection.action(state, now)}, env, config)
    case Work{s, +state, Connection.Respond{+req, body, rest}}:
      do IO<Unit>:
        reply : Reply <- app(req, body, env, closing(req, state, config))
        talk(~Env, ~app, Replied{s, state, rest, reply}, env, config)
    case Replied{s, state, rest, Reply{bytes, close}}:
      do IO<Unit>:
        out : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send_bytes(s, bytes)
        talk(~Env, ~app, Sent{out, state, rest, close}, env, config)
    case Work{s, state, Connection.Reject{status}}:
      reject(s, status)
    case Work{s, state, Connection.Stop{}}:
      Socket.close(s)
    case Work{s, state, Connection.Read{ms}}:
      IO.bind(Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit>, Unit, TCP.try_recv_bytes(s, 4096, ms), read => talk(~Env, ~app, Read{read, state}, env, config))
    case Read{(s, Ready{Done{Some{xs}}}), state}:
      do IO<Unit>:
        now : Nat <- IO.now()
        talk(~Env, ~app, Fed{s, Connection.feed(xs, state, now, config)}, env, config)
    case Fed{s, (next, send)}:
      IO.bind(Socket, Unit, interim(s, send), sock => talk(~Env, ~app, Tick{sock, next}, env, config))
    case Read{(s, Ready{Done{None{}}}), +state}:
      talk(~Env, ~app, Work{s, state, Connection.eof(state)}, env, config)
    case Read{(s, Ready{Fail{e}}), state}:
      Socket.close(s)
    case Read{(s, Wait{u}), state}:
      talk(~Env, ~app, Tick{s, state}, env, config)
    case Sent{(s, Done{u}), state, rest, False{}}:
      do IO<Unit>:
        now : Nat <- IO.now()
        talk(~Env, ~app, Fed{s, Connection.next(state, rest, now, config)}, env, config)
    case Sent{(s, result), state, rest, close}:
      rejected((s, result))

def conn(~Env: Data, ~app: R.Req -> List<&2, U32> -> Env -> Bool -> IO(Reply), m: Listener & Result<&1, &1, U32 & String, Socket>, +env: Env, +config: Config.Config) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    now : Nat <- IO.now()
    IO.spawn(Unit, talk(~Env, ~app, Tick{s, Connection.initial(now, config)}, env, config))
    return l

@unsafe
def loop(~Env: Data, ~app: R.Req -> List<&2, U32> -> Env -> Bool -> IO(Reply), l: Listener, +env: Env, +config: Config.Config) -> IO(Unit):
  do IO<Unit>:
    m : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- conn(~Env, ~app, m, env, config)
    loop(~Env, ~app, l2, env, config)

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

# Legacy byte handlers remain single-request. Preserve their framing and
# payload, replacing every Connection field before sending the final close.
def legacy_keep(line: List<&2, U32>, rev: List<&2, U32>, remove: Bool) -> List<&2, U32>:
  match remove:
    case True{}: rev
    case False{}: Bytes.append([10, 13], Bytes.append(List.reverse(&2, U32, line), rev))

def legacy_line(line: List<&2, U32>, rev: List<&2, U32>, field: Parse.Field) -> List<&2, U32>:
  match field:
    case Parse.Field{n, v}:
      remove = String.eq(Bytes.fold(n), "connection")
      legacy_keep(line, rev, remove)
    case Parse.MissingColon{}:
      Bytes.append([10, 13], Bytes.append(List.reverse(&2, U32, line), rev))

# Countdown bounds the trusted legacy response head; body octets are untouched.
def legacy_scan(fuel: Nat, xs: List<&2, U32>, line: List<&2, U32>, rev: List<&2, U32>) -> List<&2, U32>:
  match fuel xs line:
    case 1n+n 13 <> 10 <> rest Nil{}:
      Bytes.append(List.reverse(&2, U32, rev), Bytes.append(Bytes.encode("connection: close\r\n\r\n"), rest))
    case 1n+n 13 <> 10 <> rest line:
      +forward = List.reverse(&2, U32, line)
      legacy_scan(n, rest, [], legacy_line(forward, rev, Parse.field(forward)))
    case 1n+n c <> t line:
      legacy_scan(n, t, c <> line, rev)
    case _ _ _:
      Write.write(R.Get{}, Response.body(500, Connection.headers([], True{}), []))

def legacy(~app: R.Req -> List<&2, U32> -> List<&2, U32>, req: R.Req, body: List<&2, U32>, env: Unit, close: Bool) -> IO(Reply):
  IO.pure(Reply, Reply{legacy_scan(65536n, app(req, body), [], []), True{}})

def serve_config(~app: R.Req -> List<&2, U32> -> List<&2, U32>, config: Config) -> IO(Unit):
  Config{fallback, +limit} = config
  do IO<Unit>:
    env : Result<&1, &1, U32 & String, String> <- IO.get_env("PORT")
    +port : U32 = port_or(env, fallback)
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    IO.print("bendo listening on http://127.0.0.1:" ++ U32.show(port))
    loop(~Unit, ~(req => body => env => close => legacy(~app, req, body, env, close)), l, Unit{}, Config.Config{"127.0.0.1", port, limit, 65536, 5000, 10000, 30000, 1, False{}, Router.Spec{}})

def serve(~app: R.Req -> List<&2, U32> -> List<&2, U32>, port: U32) -> IO(Unit):
  serve_config(~app, defaults(port))

# Responses from Handle already carry method-aware framing and no HEAD body.
def encoded(res: Response.Res) -> List<&2, U32>:
  Response.Res{status, headers, body, rep} = res
  Bytes.append(Bytes.encode(Write.status_text(status) ++ Write.headers_text(headers) ++ "\r\n\r\n"), body)

type State<-Tag: Data, -Env: Data> is Data:
  State{table: Table.Table<Tag>, env: Env}

# Handle returns a normalized response, including HEAD's representation length.
# Do not re-run the writer on its already stripped HEAD payload.
def prepared(res: Response.Res, +close: Bool) -> Reply:
  Response.Res{status, hs, body, rep} = res
  Reply{encoded(Response.Res{status, Connection.headers(hs, close), body, rep}), close}

def prepare(+res: Response.Res, close: Bool) -> Reply:
  prepared(res, Connection.response_closing(res, close))

def respond(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), req: R.Req, body: List<&2, U32>, state: State<Tag, Env>, close: Bool) -> IO(Reply):
  State{table, env} = state
  do IO<Reply>:
    res : Response.Res <- Handle.handle(~Tag, ~Env, ~dispatch, table, env, req, body)
    return prepare(res, close)

def startup(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), +table: Table.Table<Tag>, env: Env, +config: Config.Config, manifest: Bool) -> IO(Unit):
  match config manifest:
    case _ True{}:
      do IO<Unit>:
        IO.print(Manifest.json(Tag, table))
        IO.exit(0)
    case Config.Config{+host, +fallback, +limit, header_limit, idle, head, body, max_requests, keep_alive, router} False{}:
      do IO<Unit>:
        port_env : Result<&1, &1, U32 & String, String> <- IO.get_env("PORT")
        +port : U32 = Config.port_env(port_env, fallback)
        listener : Listener <- IO.try(Listener, TCP.listen(host, port))
        IO.print("bendo listening on http://" ++ host ++ ":" ++ U32.show(port))
        loop(~State<Tag, Env>, ~(req => body => state => close => respond(~Tag, ~Env, ~dispatch, req, body, state, close)), listener, State{table, env}, config)

def run(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    startup(~Tag, ~Env, ~dispatch, table, env, config, Manifest.argv(args))
