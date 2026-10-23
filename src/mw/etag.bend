import Base
import ../app/context.bend as C
import ../http/request.bend as Request
import ../http/response.bend as R
import ../http/conditional.bend as Conditional
import ./common.bend as Common
import ../http/bytes.bend as Bytes

def method(m: Request.Method) -> Bool:
  match m:
    case Request.Get{}: True{}
    case Request.Head{}: True{}
    case _: False{}

def joined(xs: List<&2, List<&2, U32>>) -> String:
  match xs:
    case Nil{}: ""
    case x <> Nil{}: Bytes.ascii(x)
    case x <> tail: Bytes.ascii(x) ++ "," ++ joined(tail)

def fields(xs: List<&2, List<&2, U32>>) -> Maybe<&2, String>:
  match xs:
    case Nil{}: None{}
    case xs: Some{joined(xs)}

def conditional(res: R.Res, matched: Bool) -> R.Res:
  match matched:
    case True{}: Conditional.not_modified(res)
    case False{}: res

def apply(field: Maybe<&2, String>, res: R.Res, eligible: Bool) -> R.Res:
  match res eligible:
    case res False{}: res
    case R.Res{status, hs, +body, rep} True{}:
      +tag = Conditional.strong(body)
      conditional(Common.header(R.Res{status, hs, body, rep}, "etag", tag), Conditional.matches(field, tag))

def received(-Vars: Data, +c: C.Ctx<Vars>, +res: R.Res) -> R.Res:
  R.Res{status, hs, body, rep} = res
  apply(fields(C.header_bytes(Vars, c, "if-none-match")), res, method(C.method(Vars, c)) && U32.is_eq(status, 200))

def middleware(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(R.Res)) -> IO(R.Res):
  do IO<R.Res>:
    res : R.Res <- next(c)
    return received(Vars, c, res)
