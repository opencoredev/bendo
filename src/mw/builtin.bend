# Runs a built-in middleware. Server-Timing reads the store actor (@unsafe)
# and JWT reads the wall clock (a foreign effect), so their arms are plugged
# into Core.dispatch_with here rather than in the pure table.
import Base
import ../app/context.bend as C
import ../http/response.bend as Response
import ./builtin_core.bend as Core
import ./server_timing.bend as Timing
import ./jwt.bend as JwtAuth

def dispatch(-Vars: Data, id: Core.Builtin, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  Core.dispatch_with(~Timing.middleware, ~JwtAuth.middleware, Vars, id, c, next)
