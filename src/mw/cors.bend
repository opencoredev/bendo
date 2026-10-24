# CORS shell. The request-derived policy is pure in cors_request.bend and is
# retained for application after lifecycle response replacement/validation.
import Base
import ../app/context.bend as C
import ../app/observability.bend as Obs
import ../http/response.bend as Response
import ./cors_policy.bend as P
import ./cors_request.bend as RequestPolicy
import ./response_policy.bend as Policy

def actual(config: P.Config, g: Maybe<&2, P.Grant>, res: Response.Res) -> Response.Res:
  Policy.apply(RequestPolicy.chosen(config, g, None{}, False{}), res)

def answer(config: P.Config, g: Maybe<&2, P.Grant>, requested: Maybe<&2, String>) -> Response.Res:
  Policy.apply(RequestPolicy.chosen(config, g, requested, True{}), Response.body(204, [], []))

def respond(-Vars: Data, +config: P.Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), +g: Maybe<&2, P.Grant>, preflight: Bool) -> IO(Response.Res):
  match preflight:
    case True{}: IO.pure(Response.Res, answer(config, g, RequestPolicy.requested(C.request(Vars, c))))
    case False{}:
      do IO<Response.Res>:
        res : Response.Res <- next(c)
        return actual(config, g, res)

# respond, given the request's retained policy. An actual request's policy
# ignores the requested headers, so applying it equals `actual` (law
# hot_cors_actual).
def respond_with(-Vars: Data, +config: P.Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), +g: Maybe<&2, P.Grant>, +ready: Policy.Policy, preflight: Bool) -> IO(Response.Res):
  match preflight:
    case True{}: IO.pure(Response.Res, answer(config, g, RequestPolicy.requested(C.request(Vars, c))))
    case False{}:
      do IO<Response.Res>:
        res : Response.Res <- next(c)
        return Policy.apply(ready, res)

# The middleware as it ran before BND-68. Law hot_cors_middleware equates it
# with middleware below.
def middleware_spec(-Vars: Data, +config: P.Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  +req = C.request(Vars, c)
  do IO<Response.Res>:
    res : Response.Res <- respond(Vars, config, c, next, RequestPolicy.grant(config, req), RequestPolicy.preflight(req))
    Obs.retain(C.observation(Vars, c), RequestPolicy.policy(config, req))
    return res

# A preflight is answered here with 204 and never reaches the application.
# Every other request, including other OPTIONS requests, calls next. The
# grant, preflight test and policy are each derived once per request.
def middleware(-Vars: Data, +config: P.Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  +req = C.request(Vars, c)
  +g = RequestPolicy.grant(config, req)
  +preflight = RequestPolicy.preflight(req)
  +ready = RequestPolicy.chosen(config, g, RequestPolicy.requested(req), preflight)
  do IO<Response.Res>:
    res : Response.Res <- respond_with(Vars, config, c, next, g, ready, preflight)
    Obs.retain(C.observation(Vars, c), ready)
    return res
