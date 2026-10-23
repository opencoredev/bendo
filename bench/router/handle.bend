# Full network-free request path, including both scope-identity selections.
import Base
import ../../src/app/handle.bend as Handle
import ../../src/app/table.bend as T
import ../../src/app/context.bend as C
import ../../src/router/methods.bend as M
import ../../src/http/request.bend as Request
import ../../src/http/response.bend as Response

# The hit is always the first registration. Extra static routes exercise table
# size without changing path length, selected index, hooks, or response work.
def extra(fuel: Nat) -> List<&2, T.Entry<Unit>>:
  match fuel:
    case 0n: []
    case 1n+rest:
      +rest = rest
      T.Route{M.get(Unit, "/r" ++ Nat.show(rest), Unit{})} <> extra(rest)

def dispatch(tag: Unit, ctx: Handle.Ctx, env: Unit) -> IO(Response.Res):
  IO.pure(Response.Res, Response.text(200, "hit"))

def checked(res: Response.Res) -> U32:
  Response.Res{status, hs, body, rep} = res
  status

def batch(fuel: Nat, +table: T.Table<Unit>, sum: U32) -> IO(U32):
  match fuel:
    case 0n: IO.pure(U32, sum)
    case 1n+rest:
      +rest = rest
      do IO<U32>:
        res : Response.Res <- Handle.handle(~Unit, ~Unit, ~dispatch, table, Unit{}, Request.Req{Request.Get{}, "/hit", None{}, Request.Http11{}, []}, [])
        batch(rest, table, (sum + checked(res) : U32))

def built(result: Result<&2, &2, M.BuildError, T.Table<Unit>>, iterations: Nat) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "invalid benchmark table")
    case Done{+table}:
      do IO<Unit>:
        warm : U32 <- batch(10n, table, 0)
        begin : Nat <- IO.now()
        sum : U32 <- batch(iterations, table, 0)
        end : Nat <- IO.now()
        IO.print("checksum=" ++ U32.show(sum))
        IO.print("ms=" ++ Nat.show(Nat.sub(end, begin)))

def run(count: Maybe<&2, Nat>, iterations: Maybe<&2, Nat>) -> IO(Unit):
  match count iterations:
    case Some{n} Some{i}:
      built(T.build(Unit, T.Route{M.get(Unit, "/hit", Unit{})} <> extra(Nat.sub(n, 1n))), i)
    case _ _: IO.die(Unit, 1, "invalid arguments")

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case program <> count <> iterations <> Nil{}: run(Nat.read(count), Nat.read(iterations))
    case _: IO.die(Unit, 1, "expected route count and iterations")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
