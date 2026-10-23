import Base
import ../../../src/main.bend as B
import ../../../src/app/config.bend as Config
import ../../../src/app/handle.bend as Context
import ../../../src/http/request.bend as R
import ../../../src/http/bytes.bend as Bytes
import ../../../src/router/methods.bend as Methods
import ../../../src/router/router.bend as Router

type Tag is Data:
  Plain{}
  Echo{}
  Summary{}

def reply(tag: Tag, headers: List<&2, R.Header>, body: List<&2, U32>) -> B.Res:
  match tag:
    case Plain{}: B.text(200, "conformance")
    case Echo{}: B.body(200, [], body)
    case Summary{}:
      B.body(200, [R.Header{"x-header-count", Bytes.encode(Nat.show(List.length(&2, R.Header, headers)))}], body)

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  Context.Ctx{R.Req{m, path, q, v, hs}, params, body} = ctx
  IO.pure(B.Res, reply(tag, hs, body))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}:
      B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, Config.Config{"127.0.0.1", 8787, 16384, 8192, 500, 700, 700, 100, True{}, Router.Spec{}})
    case Fail{e}: IO.die(Unit, 1, "invalid routes")

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/", Plain{}), B.get(Tag, "/text", Plain{}), B.post(Tag, "/echo", Echo{}), B.post(Tag, "/chunked", Echo{}), B.post(Tag, "/summary", Summary{})]))
