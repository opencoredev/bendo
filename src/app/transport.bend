# Choose how the connection sends the final response: buffered, streamed, or
# as a 101 handing the socket to a WebSocket session. Runs after every hook,
# middleware and finalizer, against the request as it arrived on the wire.
import Base
import ./transport_response.bend as Opening
import ../stream.bend as Stream
import ../http/stream_types.bend as T
import ../http/stream_response.bend as StreamResponse
import ../http/websocket.bend as WebSocket
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/stream_marker.bend as Marker
import ../http/date_response.bend as DateResponse
import ../effects/clock.bend as Clock

def streamed(selected: Response.Res & Maybe<&1, T.Plan>) -> Response.Res & T.Transport:
  match selected:
    case (res, None{}): (res, T.Buffered{})
    case (res, Some{plan}): (res, T.Streamed{plan})

def dated_missing(res: Response.Res, needed: Bool) -> IO(Response.Res):
  match needed:
    case False{}: IO.pure(Response.Res, res)
    case True{}:
      do IO<Response.Res>:
        sample : Result<&1, &1, U32 & String, Nat> <- Clock.wall_seconds()
        return Opening.sampled(res, sample)

# A refusal keeps an explicit Date and otherwise is dated here, before the
# access log records it, so a clock failure's 500 is the status logged.
def dated(+res: Response.Res) -> IO(Response.Res):
  Response.Res{status, hs, body, rep} = res
  dated_missing(res, Bool.not(DateResponse.has_date(hs)))

def decided(+req: Request.Req, res: Response.Res, session: T.Session, decision: WebSocket.Decision) -> IO(Response.Res & T.Transport):
  match decision:
    case WebSocket.Accept{accept, protocol}: IO.pure(Response.Res & T.Transport, (Opening.rebuilt(res, accept, protocol), T.Upgraded{session}))
    case WebSocket.Refuse{status}:
      do IO<Response.Res & T.Transport>:
        Stream.abort(session)
        refused : Response.Res <- dated(Opening.wire_refusal(req, res, status))
        return (refused, T.Buffered{})

# Upgrade only when the response still carries this registration's marker and
# is still a 101 (Marker.eligible); then re-decide against the request as it
# arrived.
def upgrade(+req: Request.Req, res: Response.Res, config: WebSocket.Config, session: T.Session, marked: Bool, eligible: Bool) -> IO(Response.Res & T.Transport):
  match eligible:
    case True{}: decided(req, res, session, WebSocket.decide(config, req))
    case False{}:
      do IO<Response.Res & T.Transport>:
        Stream.abort(session)
        return (Opening.kept_response(res, marked), T.Buffered{})

def upgrade_marked(+req: Request.Req, +res: Response.Res, +id: String, config: WebSocket.Config, session: T.Session) -> IO(Response.Res & T.Transport):
  match res:
    case Response.Res{+code, +hs, body, rep}: upgrade(req, res, config, session, Stream.marked(hs, id), Marker.eligible(Marker.UpgradeClaim{id}, code, hs))

def stream_selected(+req: Request.Req, +res: Response.Res, id: String, plan: T.Plan) -> IO(Response.Res & T.Transport):
  do IO<Response.Res & T.Transport>:
    selected : Response.Res & Maybe<&1, T.Plan> <- StreamResponse.select(req, res, Some{T.Registration{id, plan}})
    return streamed(selected)

# The registration's claim, handed back with the registration itself so
# response validation can classify delivery before transport selects.
def claim_pair(+id: String, registration: T.Registration, upgrade: Bool) -> Marker.Claim & Maybe<&1, T.Registration>:
  match upgrade:
    case False{}: (Marker.BodyClaim{id}, Some{registration})
    case True{}: (Marker.UpgradeClaim{id}, Some{registration})

def claimed(registration: Maybe<&1, T.Registration>) -> Marker.Claim & Maybe<&1, T.Registration>:
  match registration:
    case None{}: (Marker.Unclaimed{}, None{})
    case Some{T.Registration{+id, plan}}: claim_pair(id, T.Registration{id, plan}, False{})
    case Some{T.Upgrade{+id, config, session}}: claim_pair(id, T.Upgrade{id, config, session}, True{})

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
        return (StreamResponse.unsupported(Opening.unswitched(res), 500), T.Buffered{})
