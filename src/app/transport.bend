# Choose how the connection sends the final response: buffered, streamed, or
# as a 101 handing the socket to a WebSocket session. Runs after every hook,
# middleware and finalizer, against the request as it arrived on the wire.
import Base
import ../stream.bend as Stream
import ../http/stream_types.bend as T
import ../http/stream_response.bend as StreamResponse
import ../http/websocket.bend as WebSocket
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/write_response.bend as Write
import ./context.bend as Context
import ./errors.bend as Errors
import ./observability.bend as Obs
import ../http/bytes.bend as Bytes

def streamed(selected: Response.Res & Maybe<&1, T.Plan>) -> Response.Res & T.Transport:
  match selected:
    case (res, None{}): (res, T.Buffered{})
    case (res, Some{plan}): (res, T.Streamed{plan})

def version_field(-Vars: Data, c: Context.Ctx<Vars>, status: U32) -> Context.Ctx<Vars>:
  match status:
    case 426: Context.header(Vars, c, "sec-websocket-version", "13")
    case _: c

# A refused handshake answers with the ordinary error format. A 426 names the
# one version Bendo speaks (RFC 6455 section 4.4).
def refusal(-Vars: Data, +c: Context.Ctx<Vars>, +status: U32) -> Response.Res:
  Context.error(Vars, version_field(Vars, c, status), Errors.http_error(status, WebSocket.reason(status)))

def normalized(+method: Request.Method, +res: Response.Res) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{status, Write.response_headers(method, res), Write.payload(method, res), rep}

def final_field(h: Request.Header) -> Bool:
  Request.Header{name, value} = h
  +folded = Bytes.fold(name)
  Bool.not(WebSocket.owned(folded) || String.eq(folded, Stream.marker()) || String.eq(folded, "content-type"))

# The wire request disagrees with the handler's (a rewrite changed its
# method). Refuse it here, after finalization, keeping the fields middleware
# and finalizers added (security, CORS, request ID, timing, Date) and dropping
# only the handshake's own fields and the old body's framing and type.
def wire_refusal(+req: Request.Req, res: Response.Res, status: U32) -> Response.Res:
  Request.Req{+method, path, query, version, hs} = req
  Response.Res{code, fields, body, rep} = res
  normalized(method, refusal(Unit, Context.Ctx{req, [], [], [], 200, List.filter(~Request.Header, ~final_field, fields), None{}, Obs.empty()}, status))

# Keep every middleware and finalizer field except those the handshake owns,
# then put the computed handshake first. A 101 has no body or framing.
def rebuilt(res: Response.Res, accept: String, protocol: Maybe<&2, String>) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{101, List.append(&2, Request.Header, WebSocket.handshake(accept, protocol), List.filter(~Request.Header, ~WebSocket.kept, List.filter(~Request.Header, ~Stream.keep, hs))), [], None{}}

def decided(+req: Request.Req, res: Response.Res, session: T.Session, decision: WebSocket.Decision) -> IO(Response.Res & T.Transport):
  match decision:
    case WebSocket.Accept{accept, protocol}: IO.pure(Response.Res & T.Transport, (rebuilt(res, accept, protocol), T.Upgraded{session}))
    case WebSocket.Refuse{status}:
      do IO<Response.Res & T.Transport>:
        Stream.abort(session)
        return (wire_refusal(req, res, status), T.Buffered{})

def unswitched(res: Response.Res) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{status, List.filter(~Request.Header, ~WebSocket.handshake_field, hs), body, rep}

# Middleware replaced the response (marker gone) or kept the marker but
# changed the status (a 403 or 500 from a hook): keep that response, without
# the handshake's fields, and abort the session.
def kept_response(res: Response.Res, marked: Bool) -> Response.Res:
  match marked:
    case True{}: unswitched(Stream.strip(res))
    case False{}: Stream.strip(res)

# Upgrade only when the response still carries this registration's marker and
# is still a 101; then re-decide against the request as it arrived.
def upgrade(+req: Request.Req, res: Response.Res, config: WebSocket.Config, session: T.Session, marked: Bool, switching: Bool) -> IO(Response.Res & T.Transport):
  match marked switching:
    case True{} True{}: decided(req, res, session, WebSocket.decide(config, req))
    case marked _:
      do IO<Response.Res & T.Transport>:
        Stream.abort(session)
        return (kept_response(res, marked), T.Buffered{})

def upgrade_marked(+req: Request.Req, +res: Response.Res, +id: String, config: WebSocket.Config, session: T.Session) -> IO(Response.Res & T.Transport):
  match res:
    case Response.Res{+code, hs, body, rep}: upgrade(req, res, config, session, Stream.marked(hs, id), U32.is_eq(code, 101))

def stream_selected(+req: Request.Req, +res: Response.Res, id: String, plan: T.Plan) -> IO(Response.Res & T.Transport):
  do IO<Response.Res & T.Transport>:
    selected : Response.Res & Maybe<&1, T.Plan> <- StreamResponse.select(req, res, Some{T.Registration{id, plan}})
    return streamed(selected)

def select(+req: Request.Req, +res: Response.Res, registration: Maybe<&1, T.Registration>) -> IO(Response.Res & T.Transport):
  match registration:
    case None{}: IO.pure(Response.Res & T.Transport, (Stream.strip(res), T.Buffered{}))
    case Some{T.Registration{id, plan}}: stream_selected(req, res, id, plan)
    case Some{T.Upgrade{id, config, session}}: upgrade_marked(req, res, id, config, session)

# Network-free handlers cannot hand off a socket or stream a body.
def network(selected: Response.Res & T.Transport, enabled: Bool) -> IO(Response.Res & T.Transport):
  match selected enabled:
    case (res, transport) True{}: IO.pure(Response.Res & T.Transport, (res, transport))
    case (res, T.Buffered{}) False{}: IO.pure(Response.Res & T.Transport, (res, T.Buffered{}))
    case (res, T.Streamed{plan}) False{}:
      do IO<Response.Res & T.Transport>:
        Stream.cancel(plan)
        return (StreamResponse.unsupported(res, 500), T.Buffered{})
    case (res, T.Upgraded{session}) False{}:
      do IO<Response.Res & T.Transport>:
        Stream.abort(session)
        return (StreamResponse.unsupported(unswitched(res), 500), T.Buffered{})
