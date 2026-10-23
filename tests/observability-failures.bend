# Deterministic error injection without weakening the OS entropy provider.
import Base
import ../src/main.bend as B
import ../src/app/context.bend as C
import ../src/app/observability.bend as Obs
import ../src/app/store.bend as Store
import ../src/mw/request_id.bend as RequestId
import ../src/mw/server_timing.bend as Timing
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response

def context() -> B.Ctx:
  C.create(Request.Req{Request.Get{}, "/", None{}, Request.Http11{}, []}, [], [], [])

def unreachable(c: B.Ctx) -> IO(B.Res):
  IO.die(B.Res, 1, "handler must not run on entropy failure")

def assert(ok: Bool, label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit, 1, label)

def empty_500(res: B.Res, label: String) -> IO(Unit):
  Response.Res{status, headers, body, rep} = res
  assert(U32.is_eq(status, 500) && List.is_empty(&2, Request.Header, headers) && List.is_empty(&2, U32, body), label)

def closed(state: Obs.State, +c: B.Ctx) -> IO(B.Res):
  match state:
    case Obs.State{id, None{}}: IO.die(B.Res, 1, "timing collector missing")
    case Obs.State{id, Some{store}}:
      do IO<B.Res>:
        Timing.close(store)
        late : Bool <- B.timing_mark(Unit, c, "late", 1n)
        assert(Bool.not(late), "late timing write returns false")
        return C.text(Unit, c, "handler response")

def break_collector(+c: B.Ctx) -> IO(B.Res):
  closed(C.observation(Unit, c), c)

def main() -> IO(Unit):
  do IO<Unit>:
    entropy : B.Res <- RequestId.generated(Unit, context(), unreachable, Fail{(5, "injected entropy error")})
    empty_500(entropy, "entropy failure returns empty 500")
    inactive : Bool <- B.timing_mark(Unit, context(), "db", 4n)
    assert(Bool.not(inactive), "inactive timing returns false")
    timing : B.Res <- Timing.middleware(Unit, context(), c => break_collector(c))
    empty_500(timing, "collector read failure returns empty 500")
