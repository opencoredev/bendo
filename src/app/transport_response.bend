# Pure construction and rebuilding of opening-handshake responses.
import Base
import ../http/stream_marker.bend as Stream
import ../http/websocket.bend as WebSocket
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/write_response.bend as Write
import ./context.bend as Context
import ./errors.bend as Errors
import ./observability.bend as Obs
import ../http/bytes.bend as Bytes

def opening_context(-Vars: Data, c: Context.Ctx<Vars>, opening: Response.Res) -> Context.Ctx<Vars>:
  Context.Ctx{req, ps, body, pairs, code, hs, vars, obs} = c
  Response.Res{status, fields, payload, rep} = opening
  Context.Ctx{req, ps, body, pairs, status, List.append(&2, Request.Header, fields, List.filter(~Request.Header, ~WebSocket.kept, hs)), vars, obs}

def version_field(-Vars: Data, c: Context.Ctx<Vars>, status: U32) -> Context.Ctx<Vars>:
  opening_context(Vars, c, WebSocket.response(WebSocket.Refuse{status}))

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
def opening_with(opening: Response.Res, hs: List<&2, Request.Header>) -> Response.Res:
  Response.Res{code, fields, payload, representation} = opening
  Response.Res{code, List.append(&2, Request.Header, fields, hs), payload, representation}

def rebuilt(res: Response.Res, accept: String, protocol: Maybe<&2, String>) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  opening_with(WebSocket.response(WebSocket.Accept{accept, protocol}), List.filter(~Request.Header, ~WebSocket.kept, List.filter(~Request.Header, ~Stream.keep, hs)))

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
