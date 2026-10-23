import Base
import ../app/context.bend as C
import ../http/response.bend as R
import ./common.bend as Common

type Policy is Data:
  NoStore{}
  NoCache{}
  Public{max_age: U32, immutable: Bool}
  Private{max_age: U32}

def immutable(yes: Bool) -> String:
  match yes:
    case True{}: ", immutable"
    case False{}: ""

def value(policy: Policy) -> String:
  match policy:
    case NoStore{}: "no-store"
    case NoCache{}: "no-cache"
    case Public{age, forever}: "public, max-age=" ++ U32.show(age) ++ immutable(forever)
    case Private{age}: "private, max-age=" ++ U32.show(age)

def middleware(-Vars: Data, policy: Policy, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(R.Res)) -> IO(R.Res):
  do IO<R.Res>:
    res : R.Res <- next(c)
    return Common.header(res, "cache-control", value(policy))
