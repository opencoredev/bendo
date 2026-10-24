# Connection IO shell. Pure parsing, deadlines and persistence policy live
# in http/connection.bend. Each socket is owned by one spawned computation.
import Base
import ./effects/peer.bend as Peer
import ./effects/shutdown_write.bend as Shutdown
import ./net/conn_info.bend as Conn
import ./stream.bend as Stream
import ./http/stream_types.bend as StreamTypes
import ./http/request.bend as R
import ./http/connection.bend as Connection
import ./http/parse.bend as Parse
import ./router/router.bend as Router
import ./app/config.bend as Config
import ./app/manifest.bend as Manifest
import ./app/table.bend as Table
import ./app/handle.bend as Handle
import ./app/validate.bend as Validate
import ./app/context.bend as Context
import ./app/errors.bend as Errors
import ./app/body-policy.bend as BodyPolicy
import ./http/response.bend as Response
import ./http/write_response.bend as Write
import ./http/bytes.bend as Bytes
import ./http/date_wire.bend as DateWire

type Config is Data:
  Config{port: U32, body_limit: U32}

def defaults(port: U32) -> Config:
  Config{port, 1048576}

# Compatibility helper used by low-level consumers that own their wire output.
def sent(m: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

# Lingering close (0009). Shutdown.shutdown_write has already sent the FIN, so
# the peer sees EOF right after the response; the drain only keeps unread
# request bytes from turning close into an RST. Keep the affine socket in this
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
        sock : Socket <- Shutdown.shutdown_write(s)
        now : Nat <- IO.now()
        drain(Drain{sock}, 4194304, Nat.add(now, 1000n))
    case Fail{e}:
      Socket.close(s)

def reject(s: Socket, status: U32) -> IO(Unit):
  do IO<Unit>:
    bytes : List<&2, U32> <- DateWire.ensure(Write.write(R.Get{}, Response.body(status, Connection.headers([], True{}), [])))
    out : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send_bytes(s, bytes)
    rejected(out)

def reject_body(s: Socket, +req: R.Req) -> IO(Unit):
  +ctx = Context.create(req, [], [], [])
  method = Context.method(Unit, ctx)
  res = Context.error(Unit, Context.header(Unit, ctx, "connection", "close"), Errors.http_error(413, "Content Too Large"))
  do IO<Unit>:
    bytes : List<&2, U32> <- DateWire.ensure(Write.write(method, res))
    out : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send_bytes(s, bytes)
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

type Reply is Type:
  Reply{bytes: List<&2, U32>, close: Bool, after: IO(Unit)}
  Streaming{bytes: List<&2, U32>, close: Bool, plan: StreamTypes.Plan, after: IO(Unit)}
  # An accepted 101. It never takes Connection.response_closing's close.
  Upgrading{bytes: List<&2, U32>, session: StreamTypes.Session, after: IO(Unit)}

type ConnectionEvent is Type:
  Tick{socket: Socket, state: Connection.State}
  Work{socket: Socket, state: Connection.State, action: Connection.Action}
  Fed{socket: Socket, pair: Connection.State & Bool}
  Read{read: Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit>, state: Connection.State}
  Replied{socket: Socket, state: Connection.State, rest: List<&2, U32>, reply: Reply}
  StreamHead{result: Socket & Bool, state: Connection.State, rest: List<&2, U32>, close: Bool, plan: StreamTypes.Plan, after: IO(Unit)}
  UpgradeHead{result: Socket & Bool, rest: List<&2, U32>, action: StreamTypes.Handoff -> IO(Unit), after: IO(Unit)}
  StreamBody{outcome: StreamTypes.Outcome, state: Connection.State, rest: List<&2, U32>, close: Bool}
  Sent{sent: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>, state: Connection.State, rest: List<&2, U32>, close: Bool}

def closing(+req: R.Req, state: Connection.State, config: Config.Config) -> Bool:
  Connection.State{input, count, phase, at} = state
  Connection.closing(req, count, config)

@unsafe
def talk(~Env: Data, ~select: R.Req -> Env -> U32, ~app: R.Req -> List<&2, U32> -> Env -> Bool -> Maybe<&2, Conn.ConnInfo> -> IO(Reply), event: ConnectionEvent, +env: Env, +config: Config.Config, +peer: Maybe<&2, Conn.ConnInfo>) -> IO(Unit):
  match event:
    case Tick{s, +state}:
      do IO<Unit>:
        now : Nat <- IO.now()
        talk(~Env, ~select, ~app, Work{s, state, Connection.action(state, now)}, env, config, peer)
    case Work{s, +state, Connection.Respond{+req, body, rest}}:
      do IO<Unit>:
        reply : Reply <- app(req, body, env, closing(req, state, config), peer)
        talk(~Env, ~select, ~app, Replied{s, state, rest, reply}, env, config, peer)
    case Replied{s, state, rest, Reply{bytes, close, after}}:
      do IO<Unit>:
        dated : List<&2, U32> <- DateWire.ensure(bytes)
        out : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send_bytes(s, dated)
        after
        talk(~Env, ~select, ~app, Sent{out, state, rest, close}, env, config, peer)
    case Replied{s, state, rest, Streaming{bytes, close, StreamTypes.Plan{+timeout, action}, after}}:
      do IO<Unit>:
        dated : List<&2, U32> <- DateWire.ensure(bytes)
        result : Socket & Bool <- Stream.send(s, dated, timeout)
        talk(~Env, ~select, ~app, StreamHead{result, state, rest, close, StreamTypes.Plan{timeout, action}, after}, env, config, peer)
    case StreamHead{(s, True{}), state, rest, close, StreamTypes.Plan{timeout, action}, after}:
      do IO<Unit>:
        result : StreamTypes.Outcome <- action(StreamTypes.Start{s})
        after
        talk(~Env, ~select, ~app, StreamBody{result, state, rest, close}, env, config, peer)
    case StreamHead{(s, False{}), state, rest, close, plan, after}:
      do IO<Unit>:
        Stream.cancel(plan)
        after
        Socket.close(s)
    # After the 101, HTTP parsing stops: the session owns the socket and the
    # octets already read past the handshake.
    case Replied{s, state, rest, Upgrading{bytes, StreamTypes.Session{+timeout, action}, after}}:
      do IO<Unit>:
        dated : List<&2, U32> <- DateWire.ensure(bytes)
        result : Socket & Bool <- Stream.send(s, dated, timeout)
        talk(~Env, ~select, ~app, UpgradeHead{result, rest, action, after}, env, config, peer)
    case UpgradeHead{(s, True{}), rest, action, after}:
      do IO<Unit>:
        after
        action(StreamTypes.Open{s, rest})
    case UpgradeHead{(s, False{}), rest, action, after}:
      do IO<Unit>:
        action(StreamTypes.Abort{})
        after
        Socket.close(s)
    case StreamBody{StreamTypes.Written{s, True{}}, state, rest, close}:
      talk(~Env, ~select, ~app, Sent{(s, Done{Unit{}}), state, rest, close}, env, config, peer)
    case StreamBody{StreamTypes.Written{s, False{}}, state, rest, close}:
      Socket.close(s)
    case StreamBody{StreamTypes.Cancelled{}, state, rest, close}:
      IO.pure(Unit, Unit{})
    case Work{s, state, Connection.BodyRejected{req}}:
      reject_body(s, req)
    case Work{s, state, Connection.Reject{status}}:
      reject(s, status)
    case Work{s, state, Connection.Stop{}}:
      Socket.close(s)
    case Work{s, state, Connection.Read{ms}}:
      IO.bind(Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit>, Unit, TCP.try_recv_bytes(s, 4096, ms), read => talk(~Env, ~select, ~app, Read{read, state}, env, config, peer))
    case Read{(s, Ready{Done{Some{xs}}}), state}:
      do IO<Unit>:
        now : Nat <- IO.now()
        talk(~Env, ~select, ~app, Fed{s, Connection.feed_policy(~Env, ~select, env, xs, state, now, config)}, env, config, peer)
    case Fed{s, (next, send)}:
      IO.bind(Socket, Unit, interim(s, send), sock => talk(~Env, ~select, ~app, Tick{sock, next}, env, config, peer))
    case Read{(s, Ready{Done{None{}}}), +state}:
      talk(~Env, ~select, ~app, Work{s, state, Connection.eof(state)}, env, config, peer)
    case Read{(s, Ready{Fail{e}}), state}:
      Socket.close(s)
    case Read{(s, Wait{u}), state}:
      talk(~Env, ~select, ~app, Tick{s, state}, env, config, peer)
    case Sent{(s, Done{u}), state, rest, False{}}:
      do IO<Unit>:
        now : Nat <- IO.now()
        talk(~Env, ~select, ~app, Fed{s, Connection.next_policy(~Env, ~select, env, state, rest, now, config)}, env, config, peer)
    case Sent{(s, result), state, rest, close}:
      rejected((s, result))

def peer_of(result: Result<&1, &1, U32 & String, String & U32>) -> Maybe<&2, Conn.ConnInfo>:
  match result:
    case Done{(host, port)}: Conn.from_peer(host, port)
    case Fail{e}: None{}

# The peer is looked up once per connection and shared by its requests.
def started(~Env: Data, ~select: R.Req -> Env -> U32, ~app: R.Req -> List<&2, U32> -> Env -> Bool -> Maybe<&2, Conn.ConnInfo> -> IO(Reply), got: Socket & Result<&1, &1, U32 & String, String & U32>, now: Nat, +env: Env, +config: Config.Config) -> IO(Unit):
  (s, result) = got
  talk(~Env, ~select, ~app, Tick{s, Connection.initial(now, config)}, env, config, peer_of(result))

def conn(~Env: Data, ~select: R.Req -> Env -> U32, ~app: R.Req -> List<&2, U32> -> Env -> Bool -> Maybe<&2, Conn.ConnInfo> -> IO(Reply), m: Listener & Result<&1, &1, U32 & String, Socket>, +env: Env, +config: Config.Config) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    got : Socket & Result<&1, &1, U32 & String, String & U32> <- Peer.peer_address(s)
    now : Nat <- IO.now()
    IO.spawn(Unit, started(~Env, ~select, ~app, got, now, env, config))
    return l

@unsafe
def loop(~Env: Data, ~select: R.Req -> Env -> U32, ~app: R.Req -> List<&2, U32> -> Env -> Bool -> Maybe<&2, Conn.ConnInfo> -> IO(Reply), l: Listener, +env: Env, +config: Config.Config) -> IO(Unit):
  do IO<Unit>:
    m : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- conn(~Env, ~select, ~app, m, env, config)
    loop(~Env, ~select, ~app, l2, env, config)

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

def legacy(~app: R.Req -> List<&2, U32> -> List<&2, U32>, req: R.Req, body: List<&2, U32>, env: U32, close: Bool, peer: Maybe<&2, Conn.ConnInfo>) -> IO(Reply):
  IO.pure(Reply, Reply{legacy_scan(65536n, app(req, body), [], []), True{}, IO.pure(Unit, Unit{})})

def serve_config(~app: R.Req -> List<&2, U32> -> List<&2, U32>, config: Config) -> IO(Unit):
  Config{fallback, +limit} = config
  do IO<Unit>:
    env : Result<&1, &1, U32 & String, String> <- IO.get_env("PORT")
    +port : U32 = port_or(env, fallback)
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    IO.print("bendo listening on http://127.0.0.1:" ++ U32.show(port))
    loop(~U32, ~(req => env => env), ~(req => body => env => close => peer => legacy(~app, req, body, env, close, peer)), l, limit, Config.Config{"127.0.0.1", port, limit, 65536, 5000, 10000, 30000, 1, False{}, Router.Spec{}, Config.Development{}})

def serve(~app: R.Req -> List<&2, U32> -> List<&2, U32>, port: U32) -> IO(Unit):
  serve_config(~app, defaults(port))

# Responses from Handle already carry method-aware framing and no HEAD body.
def encoded(res: Response.Res) -> List<&2, U32>:
  Response.Res{status, headers, body, rep} = res
  Bytes.append(Bytes.encode(Write.status_text(status) ++ Write.headers_text(headers) ++ "\r\n\r\n"), body)

type State<-Tag: Data, -Env: Data> is Data:
  State{table: Table.Table<Tag>, env: Env, router: Router.RouterKind, body_limit: U32, mode: Config.Mode, validates: Bool}

def selected_limit(~Tag: Data, ~Env: Data, ~select: Tag -> Maybe<&2, U32>, req: R.Req, state: State<Tag, Env>) -> U32:
  State{table, env, router, limit, mode, validates} = state
  BodyPolicy.for_request(~Tag, ~select, req, table, router, limit)

# Handle returns a normalized response, including HEAD's representation length.
# Do not re-run the writer on its already stripped HEAD payload.
def prepared(res: Response.Res, +close: Bool, after: IO(Unit)) -> Reply:
  Response.Res{status, hs, body, rep} = res
  Reply{encoded(Response.Res{status, Connection.headers(hs, close), body, rep}), close, after}

def prepare(+res: Response.Res, close: Bool, after: IO(Unit)) -> Reply:
  prepared(res, Connection.response_closing(res, close), after)

def prepare_pending(result: Response.Res & IO(Unit), close: Bool) -> Reply:
  (res, after) = result
  prepare(res, close, after)

def prepare_stream(+res: Response.Res, close: Bool, stream: StreamTypes.Transport, after: IO(Unit)) -> Reply:
  match res stream:
    case res StreamTypes.Buffered{}: prepare(res, close, after)
    case res StreamTypes.Upgraded{session}: Upgrading{encoded(res), session, after}
    case Response.Res{status, hs, body, rep} StreamTypes.Streamed{plan}:
      +closing = Connection.response_closing(res, close)
      Streaming{encoded(Response.Res{status, Connection.headers(hs, closing), body, rep}), closing, plan, after}

def prepare_transport(result: Response.Res & (StreamTypes.Transport & IO(Unit)), close: Bool) -> Reply:
  (res, (stream, after)) = result
  prepare_stream(res, close, stream, after)

def respond_with(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), req: R.Req, body: List<&2, U32>, state: State<Tag, Env>, close: Bool, peer: Maybe<&2, Conn.ConnInfo>) -> IO(Reply):
  State{table, env, router, limit, mode, validates} = state
  do IO<Reply>:
    result : Response.Res & (StreamTypes.Transport & IO(Unit)) <- Handle.transport_routed(~validator, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, router, mode, table, env, req, body, peer, validates)
    return prepare_transport(result, close)

# BND-96: the plain entrypoints serve only tables without route schemas, so
# they route every request through Handle.transport_plain.
def respond_plain(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), req: R.Req, body: List<&2, U32>, state: State<Tag, Env>, close: Bool, peer: Maybe<&2, Conn.ConnInfo>) -> IO(Reply):
  State{table, env, router, limit, mode, validates} = state
  do IO<Reply>:
    result : Response.Res & (StreamTypes.Transport & IO(Unit)) <- Handle.transport_plain(~Validate.skip, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, router, table, env, req, body, peer)
    return prepare_transport(result, close)

# A validator that decodes nothing must not serve a table with schemas.
def admitted_table(answer: Validate.Answer, declared: Bool) -> IO(Unit):
  match answer declared:
    case Validate.Enabled{False{}} True{}: IO.die(Unit, 1, "bendo: this table declares route schemas; serve it with the entrypoints in src/validated.bend (docs/validation.md)")
    case _ _: IO.pure(Unit, Unit{})

def startup_serving(~validator: Validate.Job -> Validate.Answer, ~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ~Env: Data, ~respond: R.Req -> List<&2, U32> -> State<Tag, Env> -> Bool -> Maybe<&2, Conn.ConnInfo> -> IO(Reply), +table: Table.Table<Tag>, env: Env, +config: Config.Config, manifest: Bool) -> IO(Unit):
  match config manifest:
    case _ True{}:
      do IO<Unit>:
        IO.print(Manifest.json(Tag, table))
        IO.exit(0)
    case Config.Config{+host, +fallback, +limit, header_limit, idle, head, body, max_requests, keep_alive, router, mode} False{}:
      do IO<Unit>:
        # Computed once: requests to a table without schemas skip every lookup (BND-96).
        +validates : Bool = Table.declares_schemas(Tag, Table.layers(Tag, table))
        admitted_table(validator(Validate.Probe{}), validates)
        port_env : Result<&1, &1, U32 & String, String> <- IO.get_env("PORT")
        +port : U32 = Config.port_env(port_env, fallback)
        mode_env : Result<&1, &1, U32 & String, String> <- IO.get_env("BENDO_ENV")
        listener : Listener <- IO.try(Listener, TCP.listen(host, port))
        IO.print("bendo listening on http://" ++ host ++ ":" ++ U32.show(port))
        loop(~State<Tag, Env>, ~(req => state => selected_limit(~Tag, ~Env, ~select, req, state)), ~respond, listener, State{table, env, router, limit, Config.mode_env(mode_env, mode), validates}, config)

def startup_limits_with(~validator: Validate.Job -> Validate.Answer, ~Vars: Data, ~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config, manifest: Bool) -> IO(Unit):
  startup_serving(~validator, ~Tag, ~select, ~Env, ~(req => body => state => close => peer => respond_with(~validator, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, req, body, state, close, peer)), table, env, config, manifest)

# The plain entrypoints: no schema decoder, and no table with schemas (BND-96).
def startup_plain(~Vars: Data, ~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config, manifest: Bool) -> IO(Unit):
  startup_serving(~Validate.skip, ~Tag, ~select, ~Env, ~(req => body => state => close => peer => respond_plain(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, req, body, state, close, peer)), table, env, config, manifest)

def startup_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config, manifest: Bool) -> IO(Unit):
  startup_plain(~Vars, ~Tag, ~(tag => None{}), ~Env, ~dispatch, ~middleware, table, env, config, manifest)

def run_limits_with(~Vars: Data, ~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    startup_plain(~Vars, ~Tag, ~select, ~Env, ~dispatch, ~middleware, table, env, config, Manifest.argv(args))

def run_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  run_limits_with(~Vars, ~Tag, ~(tag => None{}), ~Env, ~dispatch, ~middleware, table, env, config)

# Compatibility entrypoint for apps without middleware.
def run(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  run_with(~Unit, ~Tag, ~Env, ~dispatch, ~(tag => ctx => env => next => Handle.unconfigured(Tag, Env, tag, ctx, env, next)), table, env, config)
