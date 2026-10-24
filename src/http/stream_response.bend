# Response selection after all middleware and final-step headers.
import Base
import ../stream.bend as Stream
import ./stream_types.bend as T
import ./request.bend as Request
import ./response.bend as Response
import ./write_response.bend as Write
import ./bytes.bend as Bytes
import ./stream_marker.bend as Marker

def frame(+method: Request.Method, res: Response.Res, body: Bool) -> Response.Res:
  match res body:
    case Response.Res{status, hs, bytes, rep} True{}:
      Response.Res{status, Request.Header{"transfer-encoding", Bytes.encode("chunked")} <> Write.headers(hs), [], None{}}
    case Response.Res{+status, hs, bytes, rep} False{}:
      Response.Res{status, Write.framing_headers(status, [], None{}, Write.headers(hs), Bool.not(U32.is_eq(status, 205)) || Write.tunnel(method, status)), [], None{}}

def body_allowed(req: Request.Req, res: Response.Res, plan: T.Plan, body: Bool) -> IO(Response.Res & Maybe<&1, T.Plan>):
  match req body:
    case Request.Req{method, path, query, version, hs} True{}: IO.pure(Response.Res & Maybe<&1, T.Plan>, (frame(method, Stream.strip(res), True{}), Some{plan}))
    case Request.Req{method, path, query, version, hs} False{}:
      do IO<Response.Res & Maybe<&1, T.Plan>>:
        Stream.cancel(plan)
        return (frame(method, Stream.strip(res), False{}), None{})

def unsupported(res: Response.Res, code: U32) -> Response.Res:
  Response.Res{old, hs, body, rep} = res
  Response.Res{code, Write.length_header(0n) <> Write.headers(List.filter(~Request.Header, ~Stream.keep, hs)), [], None{}}

def version_allowed(req: Request.Req, res: Response.Res, plan: T.Plan, version: Request.Version, suppress: Bool) -> IO(Response.Res & Maybe<&1, T.Plan>):
  match version:
    case Request.Http10{}:
      do IO<Response.Res & Maybe<&1, T.Plan>>:
        Stream.cancel(plan)
        return (unsupported(res, 505), None{})
    case Request.Http11{}: body_allowed(req, res, plan, Bool.not(suppress))

def allowed(+req: Request.Req, res: Response.Res, plan: T.Plan, matched: Bool) -> IO(Response.Res & Maybe<&1, T.Plan>):
  match req res matched:
    case req res False{}:
      do IO<Response.Res & Maybe<&1, T.Plan>>:
        Stream.cancel(plan)
        return (Stream.strip(res), None{})
    case Request.Req{+method, path, query, version, hs} Response.Res{+code, headers, bytes, rep} True{}:
      version_allowed(req, res, plan, version, Write.is_head(method) || Bool.not(Write.allows_body(code)) || Write.tunnel(method, code))


def select(req: Request.Req, +res: Response.Res, selected: Maybe<&1, T.Registration>) -> IO(Response.Res & Maybe<&1, T.Plan>):
  match res selected:
    case res None{}: IO.pure(Response.Res & Maybe<&1, T.Plan>, (Stream.strip(res), None{}))
    case Response.Res{+code, hs, bytes, rep} Some{T.Registration{id, plan}}:
      allowed(req, res, plan, Marker.eligible(Marker.BodyClaim{id}, code, hs))
    case res Some{T.Upgrade{id, config, session}}:
      do IO<Response.Res & Maybe<&1, T.Plan>>:
        Stream.abort(session)
        return (Stream.strip(res), None{})

# Network-free handlers cannot consume an affine transport response.
def network(selected: Response.Res & Maybe<&1, T.Plan>, enabled: Bool) -> IO(Response.Res & Maybe<&1, T.Plan>):
  match selected enabled:
    case (res, stream) True{}: IO.pure(Response.Res & Maybe<&1, T.Plan>, (res, stream))
    case (res, None{}) False{}: IO.pure(Response.Res & Maybe<&1, T.Plan>, (res, None{}))
    case (res, Some{plan}) False{}:
      do IO<Response.Res & Maybe<&1, T.Plan>>:
        Stream.cancel(plan)
        return (unsupported(res, 500), None{})
