# Full network-free request path, including both scope-identity selections.
# The table's schema flag and hook index are prepared once, as serving does.
# Shapes: plain routes (BND-24), or every route inside one group or one guard
# with a before-handle hook, so each route adds a Scoped layer (BND-82).
import Base
import ../../src/app/handle.bend as Handle
import ../../src/app/table.bend as T
import ../../src/app/scopes.bend as Scopes
import ../../src/app/validate.bend as Validate
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

# The scoped hook passes every request on, so it costs selection and one call.
def middleware(tag: Unit, ctx: Handle.Ctx, env: Unit, next: Handle.Ctx -> IO(Response.Res)) -> IO(Response.Res):
  next(ctx)

def checked(res: Response.Res) -> U32:
  Response.Res{status, hs, body, rep} = res
  status

def batch(fuel: Nat, +table: T.Table<Unit>, +hooks: T.HookIndex<Unit>, +hit: String, sum: U32) -> IO(U32):
  match fuel:
    case 0n: IO.pure(U32, sum)
    case 1n+rest:
      +rest = rest
      do IO<U32>:
        res : Response.Res <- Handle.handle_prepared(~Validate.skip, ~Unit, ~Unit, ~Unit, ~dispatch, ~middleware, False{}, table, hooks, Unit{}, Request.Req{Request.Get{}, hit, None{}, Request.Http11{}, []}, [])
        batch(rest, table, hooks, hit, (sum + checked(res) : U32))

def built(result: Result<&2, &2, M.BuildError, T.Table<Unit>>, +hit: String, iterations: Nat) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "invalid benchmark table")
    case Done{+table}:
      +hooks = T.index(Unit, T.layers(Unit, table))
      do IO<Unit>:
        warm : U32 <- batch(10n, table, hooks, hit, 0)
        begin : Nat <- IO.now()
        sum : U32 <- batch(iterations, table, hooks, hit, 0)
        end : Nat <- IO.now()
        IO.print("checksum=" ++ U32.show(sum))
        IO.print("ms=" ++ Nat.show(Nat.sub(end, begin)))

def scoped_hook() -> List<&2, T.HookSpec<Unit>>:
  [T.HookSpec{T.BeforeHandle{}, Unit{}}]

def routes(+n: Nat) -> List<&2, T.Entry<Unit>>:
  T.Route{M.get(Unit, "/hit", Unit{})} <> extra(Nat.sub(n, 1n))

def shaped(shape: String, +n: Nat, i: Nat) -> IO(Unit):
  match shape:
    case "plain": built(T.build(Unit, routes(n)), "/hit", i)
    case "group": built(T.build(Unit, Scopes.group(Unit, "/g", scoped_hook(), routes(n))), "/g/hit", i)
    case "guard": built(T.build(Unit, Scopes.guard(Unit, T.GuardOptions{scoped_hook(), T.NoSchemas{}}, routes(n))), "/hit", i)
    case _: IO.die(Unit, 1, "shape must be plain, group or guard")

def run(count: Maybe<&2, Nat>, iterations: Maybe<&2, Nat>, shape: String) -> IO(Unit):
  match count iterations:
    case Some{n} Some{i}: shaped(shape, n, i)
    case _ _: IO.die(Unit, 1, "invalid arguments")

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case program <> count <> iterations <> Nil{}: run(Nat.read(count), Nat.read(iterations), "plain")
    case program <> count <> iterations <> shape <> Nil{}: run(Nat.read(count), Nat.read(iterations), shape)
    case _: IO.die(Unit, 1, "expected route count, iterations and an optional shape")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
