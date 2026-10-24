import Base
import ../../../src/main.bend as B
import ../../../src/app/config.bend as Config
import ../../../src/http/request.bend as R
import ../../../src/http/response.bend as Response
import ../../../src/http/bytes.bend as Bytes
import ../../../src/router/methods.bend as Methods
import ../../../src/router/router.bend as Router

type Tag is Data:
  Echo{}

def reply(path: String, body: List<&2, U32>) -> Response.Res:
  match path:
    case "/close": Response.body(200, [R.Header{"connection", Bytes.encode("keep-alive, CLOSE")}], Bytes.encode("close"))
    case "/bad": Response.text(413, "too large")
    case "/upgrade": Response.body(101, [], [])
    case p:
      match body:
        case Nil{}: Response.text(200, p)
        case c <> t: Response.body(200, [], c <> t)

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  +c = ctx
  IO.pure(B.Res, reply(B.path(c), B.raw_body(c)))

def configured(mode: Result<&1, &1, U32 & String, String>) -> Config.Config:
  match mode:
    case Done{"short"}: Config.Config{"127.0.0.1", 8787, 8, 128, 150, 350, 350, 3, True{}, Router.Spec{}}
    case Done{"zero"}: Config.Config{"127.0.0.1", 8787, 8, 65536, 150, 350, 350, 0, True{}, Router.Spec{}}
    case Done{"disabled"}: Config.Config{"127.0.0.1", 8787, 8, 65536, 150, 350, 350, 100, False{}, Router.Spec{}}
    case _: Config.Config{"127.0.0.1", 8787, 8, 65536, 2000, 1000, 1000, 100, True{}, Router.Spec{}}

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>, config: Config.Config) -> IO(Unit):
  match result:
    case Done{table}: B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, config)
    case Fail{e}: IO.die(Unit, 1, "invalid routes")

def main() -> IO(Unit):
  do IO<Unit>:
    mode : Result<&1, &1, U32 & String, String> <- IO.get_env("CONNECTION_MODE")
    ready(B.routes(Tag, [B.all(Tag, "/*", Echo{})]), configured(mode))
