import Base
import ../app/context.bend as C
import ../app/errors.bend as Errors
import ../http/response.bend as R

def accepts(length: Nat, limit: Nat) -> Bool:
  Nat.is_le(length, limit)

def checked(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(R.Res), ok: Bool) -> IO(R.Res):
  match ok:
    case True{}: next(c)
    case False{}: IO.pure(R.Res, C.error(Vars, c, Errors.http_error(413, "Content Too Large")))

# Network-free/rewrite check. serve_limits_with also enforces it during framing.
def middleware(-Vars: Data, limit: U32, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(R.Res)) -> IO(R.Res):
  checked(Vars, c, next, accepts(R.length(C.raw_body(Vars, c)), U32.to_nat(limit)))
