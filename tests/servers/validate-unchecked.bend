# BND-36: the plain entrypoints link no schema decoder, so they must not
# ignore schemas. B.handle answers a schema route 500; B.serve refuses to start.
import Base
import ../../src/main.bend as B
import ../../src/data/schema.bend as S
import ../../src/http/request.bend as Request
import ../../src/http/response.bend as R
import ../../src/http/bytes.bend as Bytes

type Tag is Data:
  Item{}

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, B.text(ctx, "handler ran"))

def query() -> S.Schema:
  S.ObjectSchema{[S.Field{"q", S.StringSchema{1n, None{}, None{}, S.Plain{}}, S.Required{}}], S.Strip{}}

def shown(res: R.Res) -> String:
  R.Res{code, hs, body, rep} = res
  U32.show(code) ++ " " ++ Bytes.ascii(body)

def ready(result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "bad table")
    case Done{+table}:
      do IO<Unit>:
        res : B.Res <- B.handle(~Tag, ~Unit, ~dispatch, table, Unit{}, Request.Req{Request.Get{}, "/items", Some{"q=x"}, Request.Http11{}, []}, [])
        IO.print("handle " ++ shown(res))
        B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.with_schemas(Tag, B.get(Tag, "/items", Item{}), B.schemas([B.query_schema(query())]))]))
