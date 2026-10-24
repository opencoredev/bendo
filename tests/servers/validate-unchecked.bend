# BND-36: the plain entrypoints link no schema decoder, so they must not
# ignore schemas. B.handle answers a schema route 500, a route with only a
# response schema included, before its handler runs; B.serve refuses to start.
import Base
import ../../src/main.bend as B
import ../../src/data/schema.bend as S
import ../../src/http/request.bend as Request
import ../../src/http/response.bend as R
import ../../src/http/bytes.bend as Bytes

type Tag is Data:
  Item{}
  Report{}

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  match tag:
    case Item{}: IO.pure(B.Res, B.text(ctx, "handler ran"))
    case Report{}: IO.die(B.Res, 1, "report handler ran")

def report() -> S.Schema:
  S.ObjectSchema{[S.Field{"count", S.IntegerSchema{None{}, None{}}, S.Required{}}], S.Strict{}}

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
        reported : B.Res <- B.handle(~Tag, ~Unit, ~dispatch, table, Unit{}, Request.Req{Request.Get{}, "/report", None{}, Request.Http11{}, []}, [])
        IO.print("response-only " ++ shown(reported))
        B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.with_schemas(Tag, B.get(Tag, "/items", Item{}), B.schemas([B.query_schema(query())])), B.with_schemas(Tag, B.get(Tag, "/report", Report{}), B.schemas([B.response_schema(report())]))]))
