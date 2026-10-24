import Base
import ../app/context.bend as C
import ../app/errors.bend as Errors
import ../http/response.bend as R

def answered(-Vars: Data, c: C.Ctx<Vars>, result: Maybe<&1, R.Res>) -> R.Res:
  match result:
    case Some{res}: res
    case None{}: C.error(Vars, c, Errors.HttpError{504, "Gateway Timeout", True{}})

# The loser keeps running. In particular, its store writes can still commit.
def middleware(-Vars: Data, ms: U32, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(R.Res)) -> IO(R.Res):
  do IO<R.Res>:
    result : Maybe<&1, R.Res> <- IO.within(R.Res, ms, next(c))
    return answered(Vars, c, result)
