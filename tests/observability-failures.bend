# Deterministic error injection without weakening the OS entropy provider.
import Base
import ../src/data/utf8.bend as Utf8
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
    case Obs.State{id, None{}, finalized, stream}: IO.die(B.Res, 1, "timing collector missing")
    case Obs.State{id, Some{store}, finalized, stream}:
      do IO<B.Res>:
        Timing.close(store)
        late : Bool <- B.timing_mark(Unit, c, "late", 1n)
        assert(Bool.not(late), "late timing write returns false")
        return C.text(Unit, c, "handler response")

def break_collector(+c: B.Ctx) -> IO(B.Res):
  closed(C.observation(Unit, c), c)

def explicit_text(value: Maybe<&2, String>) -> Bool:
  match value:
    case Some{text}: String.eq(text, "explicit")
    case None{}: False{}

def single_id(res: B.Res) -> Bool:
  Response.Res{code, headers, body, rep} = res
  match headers:
    case Request.Header{name, value} <> Nil{}:
      String.eq(name, "x-request-id") && explicit_text(Utf8.decode(value))
    case _: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    mixed : B.Res <- Obs.finalize(Obs.with_id(Obs.empty(), "retained"), Response.body(200, [Request.Header{"X-Request-ID", Response.utf8("explicit")}, Request.Header{"x-request-id", Response.utf8("duplicate")}], []))
    assert(single_id(mixed), "mixed-case explicit ID wins without duplicates")
    entropy : B.Res <- RequestId.generated(Unit, context(), unreachable, Fail{(5, "injected entropy error")})
    empty_500(entropy, "entropy failure returns empty 500")
    inactive : Bool <- B.timing_mark(Unit, context(), "db", 4n)
    assert(Bool.not(inactive), "inactive timing returns false")
    timing : B.Res <- Timing.middleware(Unit, context(), c => break_collector(c))
    empty_500(timing, "collector read failure returns empty 500")
