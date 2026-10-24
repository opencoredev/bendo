# Trailing-slash redirects, following Hono's trimTrailingSlash and
# appendTrailingSlash. Targets are computed in trailing_slash_policy.bend.
import Base
import ../app/context.bend as C
import ../http/request.bend as Request
import ../http/response.bend as Response
import ./trailing_slash_policy.bend as P

# always: redirect before calling next instead of only when the answer is 404.
type Config is Data:
  Config{mode: P.Mode, always: Bool}

def moved(loc: String) -> Response.Res:
  Response.body(301, [Request.Header{"location", Response.utf8(loc)}], [])

def missing(res: Response.Res, not_found: Bool, target: Maybe<&2, String>) -> Response.Res:
  match not_found target:
    case True{} Some{loc}: moved(loc)
    case _ _: res

def status(+res: Response.Res) -> U32:
  match res:
    case Response.Res{s, hs, b, rep}: s

def after(res: Response.Res, target: Maybe<&2, String>) -> Response.Res:
  +r = res
  missing(r, U32.is_eq(status(r), 404), target)

def early(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), target: Maybe<&2, String>) -> IO(Response.Res):
  match target:
    case None{}: next(c)
    case Some{loc}: IO.pure(Response.Res, moved(loc))

def run(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), target: Maybe<&2, String>, always: Bool) -> IO(Response.Res):
  match always:
    case True{}: early(Vars, c, next, target)
    case False{}:
      do IO<Response.Res>:
        res : Response.Res <- next(c)
        return after(res, target)

def query(r: Request.Req) -> Maybe<&2, String>:
  match r:
    case Request.Req{m, p, q, v, hs}: q

# Only GET and HEAD are redirected, with 301 like Hono.
def middleware(-Vars: Data, config: Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  match config:
    case Config{mode, always}:
      run(Vars, c, next, P.target(mode, C.method(Vars, c), C.path(Vars, c), query(C.request(Vars, c))), always)
