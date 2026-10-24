# Thin IO shell for the proxy (BND-47); docs/proxy.md. One upstream
# connection per request, no pool. The request body is the one the server
# already buffered under its body limit; the response body streams through
# B.stream with one bounded receive per pull. Every path closes the upstream
# socket exactly once: the error paths here, or the stream's cleanup.
import Base
import ./stream.bend as Stream
import ./http/stream_types.bend as StreamTypes
import ./http/upstream.bend as U
import ./http/request.bend as Request
import ./http/response.bend as Response
import ./http/bytes.bend as Bytes
import ./app/context.bend as Context
import ./app/observability.bend as Observation
import ./effects/upstream_connect.bend as Connect
import ./http/write_response.bend as WriteResponse

def Options() -> Data: U.Options
def options(upstream: String) -> U.Options: U.defaults(upstream)
def preserve_host(o: U.Options, on: Bool) -> U.Options: U.with_preserve_host(o, on)
def trust_forwarded(o: U.Options, on: Bool) -> U.Options: U.with_trust(o, on)
def forwarded(o: U.Options, on: Bool) -> U.Options: U.with_forwarded(o, on)
def rewrite(o: U.Options, from: String, to: String) -> U.Options: U.with_rewrite(o, from, to)
def timeouts(o: U.Options, connect: U32, send: U32, head: U32, read: U32) -> U.Options: U.with_timeouts(o, connect, send, head, read)
def stream_config(o: U.Options, config: StreamTypes.Config) -> U.Options: U.with_stream(o, config)

def bad_gateway() -> String: "Bad Gateway: upstream connection failed"
def bad_response() -> String: "Bad Gateway: invalid upstream response"
def gateway_timeout() -> String: "Gateway Timeout: upstream did not answer in time"

def fail(-Vars: Data, c: Context.Ctx<Vars>, code: U32, message: String) -> IO(Response.Res):
  IO.pure(Response.Res, Context.text(Vars, Context.status(Vars, c, code), message))

def close_fail(-Vars: Data, s: Socket, c: Context.Ctx<Vars>, code: U32, message: String) -> IO(Response.Res):
  do IO<Response.Res>:
    Socket.close(s)
    fail(Vars, c, code, message)

# ---------------------------------------------------------------- body pump

type Pump is Type:
  Pump{socket: Socket, body: U.Body, pending: List<&2, U32>, read_ms: U32, max: U32}

def cleanup(p: Pump) -> IO(Unit):
  Pump{s, body, pending, ms, max} = p
  Socket.close(s)

def fed_rest(s: Socket, result: U.Fed, rest: List<&2, U32>, ms: U32, max: U32) -> StreamTypes.Step<Pump>:
  match result:
    case U.Broken{}: StreamTypes.Failed{Pump{s, U.Finished{}, [], ms, max}}
    case U.Fed{bytes, body}: StreamTypes.Chunk{bytes, Pump{s, body, rest, ms, max}}

def fed(s: Socket, result: U.Fed, ms: U32, max: U32) -> StreamTypes.Step<Pump>:
  fed_rest(s, result, [], ms, max)

# Decoding never grows its input, so feeding at most `max` octets keeps every
# chunk within the stream's configured maximum.
def split_feed(s: Socket, body: U.Body, parts: List<&2, U32> & Nat, rest: List<&2, U32>, ms: U32, max: U32) -> StreamTypes.Step<Pump>:
  (head, unused) = parts
  fed_rest(s, U.feed(body, head), rest, ms, max)

def pending_step(s: Socket, body: U.Body, +pending: List<&2, U32>, ms: U32, +max: U32) -> StreamTypes.Step<Pump>:
  split_feed(s, body, U.take_go(pending, U32.to_nat(max), []), List.drop(&2, U32, pending, U32.to_nat(max)), ms, max)

def eof(s: Socket, +body: U.Body, ms: U32, max: U32, clean: Bool) -> StreamTypes.Step<Pump>:
  match clean:
    case True{}: StreamTypes.End{Pump{s, body, [], ms, max}}
    case False{}: StreamTypes.Failed{Pump{s, body, [], ms, max}}

# A receive error, a read timeout or EOF inside a framed body aborts the
# client stream: the status is already sent, so it ends without a last chunk.
def received(+body: U.Body, ms: U32, max: U32, got: Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit>) -> StreamTypes.Step<Pump>:
  match got:
    case (s, Wait{u}): StreamTypes.Failed{Pump{s, body, [], ms, max}}
    case (s, Ready{Fail{e}}): StreamTypes.Failed{Pump{s, body, [], ms, max}}
    case (s, Ready{Done{None{}}}): eof(s, body, ms, max, U.at_eof(body))
    case (s, Ready{Done{Some{bytes}}}): fed(s, U.feed(body, bytes), ms, max)

def receive(s: Socket, body: U.Body, +ms: U32, +max: U32, finished: Bool) -> IO(StreamTypes.Step<Pump>):
  match finished:
    case True{}: IO.pure(StreamTypes.Step<Pump>, StreamTypes.End{Pump{s, body, [], ms, max}})
    case False{}:
      do IO<StreamTypes.Step<Pump>>:
        got : Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit> <- TCP.try_recv_bytes(s, max, ms)
        return received(body, ms, max, got)

def step(p: Pump) -> IO(StreamTypes.Step<Pump>):
  match p:
    case Pump{s, +body, Nil{}, ms, max}: receive(s, body, ms, max, U.done(body))
    case Pump{s, body, x <> xs, ms, max}: IO.pure(StreamTypes.Step<Pump>, pending_step(s, body, x <> xs, ms, max))

# ---------------------------------------------------------------- response

def bytes_headers(-Vars: Data, c: Context.Ctx<Vars>, code: U32, extra: List<&2, Request.Header>) -> Context.Ctx<Vars>:
  Context.Ctx{r, p, b, q, s, hs, v, o} = c
  Context.Ctx{r, p, b, q, code, List.append(&2, Request.Header, hs, extra), v, o}

def respond(-Vars: Data, s: Socket, +c: Context.Ctx<Vars>, +o: U.Options, +status: U32, hs: List<&2, Request.Header>, rest: List<&2, U32>, framing: U.Framing) -> IO(Response.Res):
  U.Options{url, preserve, trust, fwd, rule, cms, sms, hms, rms, config} = o
  StreamTypes.Config{wt, +max} = config
  +ready = bytes_headers(Vars, c, status, U.response_headers(hs))
  Stream.register(Observation.stream(Context.observation(Vars, ready)), Context.body(Vars, ready, [], None{}), Stream.plan(~Pump, ~step, ~cleanup, Pump{s, U.start(framing), rest, U32.max(rms, 1), U32.max(U32.min(max, 65536), 1)}, StreamTypes.Config{wt, max}))

def framed(-Vars: Data, s: Socket, +c: Context.Ctx<Vars>, +o: U.Options, +status: U32, hs: List<&2, Request.Header>, rest: List<&2, U32>, framing: U.Framing) -> IO(Response.Res):
  match framing:
    case U.Invalid{}: close_fail(Vars, s, c, 502, bad_response())
    case f: respond(Vars, s, c, o, status, hs, rest, f)

# ---------------------------------------------------------------- head

type HeadEvent is Type:
  Reading{socket: Socket, state: U.Head}
  Timed{socket: Socket, state: U.Head, left: Nat}
  Got{result: Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit>, state: U.Head}
  Parsed{socket: Socket, result: U.HeadResult}

# The whole head shares one absolute deadline; progress never extends it.
@unsafe
def read_head(-Vars: Data, event: HeadEvent, +c: Context.Ctx<Vars>, +o: U.Options, +head_request: Bool, +deadline: Nat) -> IO(Response.Res):
  match event:
    case Reading{s, state}:
      do IO<Response.Res>:
        now : Nat <- IO.now()
        read_head(Vars, Timed{s, state, Nat.sub(deadline, now)}, c, o, head_request, deadline)
    case Timed{s, state, 0n}: close_fail(Vars, s, c, 504, gateway_timeout())
    case Timed{s, state, 1n+left}:
      do IO<Response.Res>:
        got : Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit> <- TCP.try_recv_bytes(s, 65536, U32.from_nat(Nat.min(1n+left, 4294967295n)))
        read_head(Vars, Got{got, state}, c, o, head_request, deadline)
    case Got{(s, Wait{u}), state}: close_fail(Vars, s, c, 504, gateway_timeout())
    case Got{(s, Ready{Fail{e}}), state}: close_fail(Vars, s, c, 502, bad_response())
    case Got{(s, Ready{Done{None{}}}), state}: close_fail(Vars, s, c, 502, bad_response())
    case Got{(s, Ready{Done{Some{bytes}}}), state}: read_head(Vars, Parsed{s, U.head_feed(bytes, state)}, c, o, head_request, deadline)
    case Parsed{s, U.More{state}}: read_head(Vars, Reading{s, state}, c, o, head_request, deadline)
    case Parsed{s, U.Malformed{}}: close_fail(Vars, s, c, 502, bad_response())
    case Parsed{s, U.Got{+status, version, +hs, rest}}: framed(Vars, s, c, o, status, hs, rest, U.framing(head_request, status, version, hs))

def head_ms(o: U.Options) -> U32:
  U.Options{url, preserve, trust, fwd, rule, cms, sms, hms, rms, config} = o
  hms

def send_ms(o: U.Options) -> U32:
  U.Options{url, preserve, trust, fwd, rule, cms, sms, hms, rms, config} = o
  sms

def connect_ms(o: U.Options) -> U32:
  U.Options{url, preserve, trust, fwd, rule, cms, sms, hms, rms, config} = o
  cms

def rule(o: U.Options) -> U.Rewrite:
  U.Options{url, preserve, trust, fwd, r, cms, sms, hms, rms, config} = o
  r

def up_base(u: U.Upstream) -> String:
  U.Upstream{host, port, authority, base} = u
  base

def req_path(r: Request.Req) -> String:
  Request.Req{method, path, query, version, hs} = r
  path

def req_query(r: Request.Req) -> Maybe<&2, String>:
  Request.Req{method, path, query, version, hs} = r
  query

def upstream_url(o: U.Options) -> String:
  U.Options{url, preserve, trust, fwd, rule, cms, sms, hms, rms, config} = o
  url

# A failed send is a timeout when its budget ran out, a 502 otherwise.
def send_failed(-Vars: Data, s: Socket, c: Context.Ctx<Vars>, late: Bool) -> IO(Response.Res):
  match late:
    case True{}: close_fail(Vars, s, c, 504, gateway_timeout())
    case False{}: close_fail(Vars, s, c, 502, bad_gateway())

def connect_failed(-Vars: Data, c: Context.Ctx<Vars>, late: Bool) -> IO(Response.Res):
  match late:
    case True{}: fail(Vars, c, 504, gateway_timeout())
    case False{}: fail(Vars, c, 502, bad_gateway())

def sent(-Vars: Data, result: Socket & Bool, +c: Context.Ctx<Vars>, +o: U.Options, +head_request: Bool, +now: Nat, started: Nat) -> IO(Response.Res):
  match result:
    case (s, True{}):
      read_head(Vars, Reading{s, U.head_initial()}, c, o, head_request, Nat.add(now, U32.to_nat(head_ms(o))))
    case (s, False{}):
      send_failed(Vars, s, c, Nat.is_le(Nat.add(started, U32.to_nat(send_ms(o))), now))

def send(-Vars: Data, s: Socket, bytes: List<&2, U32>, +c: Context.Ctx<Vars>, +o: U.Options, +head_request: Bool) -> IO(Response.Res):
  do IO<Response.Res>:
    started : Nat <- IO.now()
    result : Socket & Bool <- Stream.send(s, bytes, send_ms(o))
    now : Nat <- IO.now()
    sent(Vars, result, c, o, head_request, now, started)

# ETIMEDOUT from the connect effect is the connect budget running out.
def connected(-Vars: Data, result: Result<&1, &1, U32 & String, Socket>, bytes: List<&2, U32>, +c: Context.Ctx<Vars>, +o: U.Options, +head_request: Bool) -> IO(Response.Res):
  match result:
    case Done{s}: send(Vars, s, bytes, c, o, head_request)
    case Fail{(code, message)}: connect_failed(Vars, c, U32.is_eq(code, 110))

def dial(-Vars: Data, up: U.Upstream, bytes: List<&2, U32>, +c: Context.Ctx<Vars>, +o: U.Options, +head_request: Bool) -> IO(Response.Res):
  U.Upstream{host, port, authority, base} = up
  do IO<Response.Res>:
    result : Result<&1, &1, U32 & String, Socket> <- Connect.upstream_connect(host, port, U32.max(connect_ms(o), 1))
    connected(Vars, result, bytes, c, o, head_request)

def targeted(-Vars: Data, +up: U.Upstream, target: Maybe<&2, String>, +c: Context.Ctx<Vars>, +o: U.Options, +req: Request.Req) -> IO(Response.Res):
  match target:
    case None{}: fail(Vars, c, 500, "Proxy rewrite produced an invalid target")
    case Some{t}:
      Request.Req{+method, path, query, version, +hs} = req
      +body = Context.raw_body(Vars, c)
      dial(Vars, up, Bytes.append(U.head_bytes(method, t, U.request_headers(o, up, hs, Context.conn_info(Vars, c), List.length(&2, U32, body))), body), c, o, WriteResponse.is_head(method))

def located(-Vars: Data, up: Maybe<&2, U.Upstream>, +c: Context.Ctx<Vars>, +o: U.Options) -> IO(Response.Res):
  match up:
    case None{}: fail(Vars, c, 500, "Proxy upstream misconfigured")
    case Some{+u}:
      +req = Context.request(Vars, c)
      targeted(Vars, u, U.target(req_path(req), up_base(u), rule(o), req_query(req)), c, o, req)

def allowed(-Vars: Data, +c: Context.Ctx<Vars>, +o: U.Options, connect: Bool) -> IO(Response.Res):
  match connect:
    case True{}: fail(Vars, c, 501, "Not Implemented: CONNECT is not proxied")
    case False{}: located(Vars, U.parse_url(upstream_url(o)), c, o)

# Forward the request in `c` to the upstream and stream its answer back.
def proxy(-Vars: Data, +c: Context.Ctx<Vars>, +o: U.Options) -> IO(Response.Res):
  allowed(Vars, c, o, String.eq(Request.method_text(Context.method(Vars, c)), "CONNECT"))
