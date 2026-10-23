# Date at the network-free return boundary, after response normalization.
import Base
import ../effects/clock.bend as Clock
import ./date.bend as Date
import ./response.bend as Response
import ./request.bend as Request
import ./bytes.bend as Bytes

def has_date(hs: List<&2, Request.Header>) -> Bool:
  match hs:
    case Nil{}: False{}
    case Request.Header{n, v} <> tail:
      String.eq(Bytes.fold(n), "date") || has_date(tail)

def unavailable(res: Response.Res, server_error: Bool) -> Response.Res:
  match server_error:
    case True{}: res
    case False{}: Response.body(500, [Request.Header{"content-length", [48]}], [])

# Preserve application Date fields. A missing clock turns a non-5xx response
# into an empty 500, for which RFC 9110 permits omission of Date.
def sampled(sample: Result<&1, &1, U32 & String, Nat>, res: Response.Res) -> Response.Res:
  match sample:
    case Done{s}:
      Response.Res{status, hs, body, rep} = res
      Response.Res{status, Request.Header{"date", Bytes.encode(Date.format_imf(s))} <> hs, body, rep}
    case Fail{error}:
      Response.Res{+status, hs, body, rep} = res
      unavailable(Response.Res{status, hs, body, rep}, U32.is_ge(status, 500))

def ensure_missing(res: Response.Res, needed: Bool) -> IO(Response.Res):
  match needed:
    case False{}: IO.pure(Response.Res, res)
    case True{}:
      do IO<Response.Res>:
        sample : Result<&1, &1, U32 & String, Nat> <- Clock.wall_seconds()
        return sampled(sample, res)

def ensure(+res: Response.Res) -> IO(Response.Res):
  Response.Res{+status, hs, body, rep} = res
  ensure_missing(res, U32.is_ge(status, 200) && Bool.not(has_date(hs)))
