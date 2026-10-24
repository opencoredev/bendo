import Base
import ../http/write_response.bend as Write
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

def applied(res: R.Res, policy: Policy, informational: Bool) -> R.Res:
  match informational:
    case True{}: res
    case False{}: Common.header(res, "cache-control", value(policy))

def decorate(+res: R.Res, policy: Policy) -> R.Res:
  R.Res{status, hs, body, rep} = res
  applied(res, policy, Write.informational(status))

def middleware(-Vars: Data, policy: Policy, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(R.Res)) -> IO(R.Res):
  do IO<R.Res>:
    res : R.Res <- next(c)
    return decorate(res, policy)
