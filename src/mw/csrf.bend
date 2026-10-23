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

# At most one field line.
def lone(values: List<&2, List<&2, U32>>) -> Bool:
  match values:
    case Nil{}: True{}
    case v <> Nil{}: True{}
    case _: False{}

def single(-Vars: Data, +c: C.Ctx<Vars>, name: String) -> Bool:
  lone(C.header_bytes(Vars, c, name))

# A source header read only when none of the source headers repeats.
def source(-Vars: Data, +c: C.Ctx<Vars>, name: String, alone: Bool) -> Maybe<&2, String>:
  match alone:
    case True{}: header(Vars, c, name)
    case False{}: None{}

# Two Origin, Referer or Sec-Fetch-Site fields disagree about who sent the
# request, so the decision sees none of them: an inspected request then has no
# trusted source and fails, and Referer cannot stand in for a repeated Origin.
def middleware(-Vars: Data, policy: Policy.Policy, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  +alone = single(Vars, c, "origin") && single(Vars, c, "referer") && single(Vars, c, "sec-fetch-site")
  decided(Vars, c, next, Policy.decide(policy, C.method(Vars, c), header(Vars, c, "content-type"), source(Vars, c, "sec-fetch-site", alone), source(Vars, c, "origin", alone), source(Vars, c, "referer", alone), header(Vars, c, "host")))
