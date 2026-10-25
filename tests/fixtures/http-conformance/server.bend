# Conformance server for BND-13: fixed text, byte echo and a header summary.
import Base
import ../../../src/main.bend as B
import ../../../src/app/config.bend as Config
import ../../../src/app/context.bend as C
import ../../../src/http/request.bend as R
import ../../../src/http/response.bend as Response
import ../../../src/http/bytes.bend as Bytes
import ../../../src/router/methods.bend as Methods
import ../../../src/router/router.bend as Router

type Tag is Data:
  Plain{}
  Echo{}
  Summary{}

def count(r: R.Req) -> String:
  R.Req{m, path, q, v, hs} = r
  Nat.show(List.length(&2, R.Header, hs))

def reply(tag: Tag, +c: B.Ctx) -> B.Res:
  match tag:
    case Plain{}: Response.text(200, "conformance")
    case Echo{}: Response.body(200, [], B.raw_body(c))
    case Summary{}:
      Response.body(200, [R.Header{"x-header-count", Bytes.encode(count(C.request(Unit, c)))}], B.raw_body(c))

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  +c = ctx
  IO.pure(B.Res, reply(tag, c))

# Small limits keep the 431, 413 and 408 cases fast: 16 KiB body, 8 KiB head,
# 500 ms idle and 700 ms head/body deadlines.
def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}:
      B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, Config.Config{"127.0.0.1", 8787, 16384, 8192, 500, 700, 700, 30000, 100, True{}, Router.Spec{}, Config.Development{}, 1})
    case Fail{e}: IO.die(Unit, 1, "invalid routes")

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/", Plain{}), B.get(Tag, "/text", Plain{}), B.post(Tag, "/echo", Echo{}), B.post(Tag, "/chunked", Echo{}), B.post(Tag, "/summary", Summary{})]))
