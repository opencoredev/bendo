# CSRF protection by origin check, following Hono's csrf middleware. The
# decision itself is pure and lives in csrf_policy.bend.
import Base
import ../app/context.bend as C
import ../http/response.bend as Response
import ./csrf_policy.bend as Policy

def decided(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), ok: Bool) -> IO(Response.Res):
  match ok:
    case True{}: next(c)
    case False{}: IO.pure(Response.Res, Response.text(403, "Forbidden"))

def header(-Vars: Data, +c: C.Ctx<Vars>, name: String) -> Maybe<&2, String>:
  C.request_header(Vars, c, name)

def middleware(-Vars: Data, policy: Policy.Policy, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  decided(Vars, c, next, Policy.decide(policy, C.method(Vars, c), header(Vars, c, "content-type"), header(Vars, c, "sec-fetch-site"), header(Vars, c, "origin"), header(Vars, c, "referer"), header(Vars, c, "host")))
