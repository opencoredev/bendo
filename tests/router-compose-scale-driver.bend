import Base
import ../src/main.bend as B
import ../src/app/table.bend as T
import ../src/router/methods.bend as M

# Prints the structural size of composed tables, never timings. Each line is
# "<case> <routes> <scoped records> <middleware layers> <ordinal work>", where
# ordinal work sums the route counts the builder walked to number scoped records.
def routes(+n: Nat) -> List<&2, B.Registration(U32)>:
  match n:
    case 0n: []
    case 1n+p: B.get(U32, "/r" ++ Nat.show(p), 0) <> routes(p)

def scoped(layers: List<&2, T.Middleware<U32>>) -> Nat:
  match layers:
    case Nil{}: 0n
    case T.Scoped{from_end, hooks} <> tail: 1n+scoped(tail)
    case _ <> tail: scoped(tail)

def ordinal_work(layers: List<&2, T.Middleware<U32>>) -> Nat:
  match layers:
    case Nil{}: 0n
    case T.Scoped{from_end, hooks} <> tail: Nat.add(from_end, ordinal_work(tail))
    case _ <> tail: ordinal_work(tail)

def census(name: String, +n: Nat, result: Result<&2, &2, M.BuildError, B.Routes(U32)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.print(name ++ " failed")
    case Done{T.Table{sources, compiled, +layers, count}}:
      IO.print(name ++ " " ++ Nat.show(n) ++ " " ++ Nat.show(scoped(layers)) ++ " " ++ Nat.show(List.length(&2, T.Middleware<U32>, layers)) ++ " " ++ Nat.show(ordinal_work(layers)))

def probe(+n: Nat) -> IO(Unit):
  do IO<Unit>:
    census("mount", n, B.routes(U32, B.route(U32, "/m", B.use(U32, 7) <> routes(n))))
    census("group", n, B.routes(U32, B.group(U32, "/g", [], B.use(U32, 7) <> routes(n))))
    census("hooked", n, B.routes(U32, B.group(U32, "/h", [B.hook(U32, T.BeforeHandle{}, 9)], B.use(U32, 7) <> routes(n))))

def main() -> IO(Unit):
  do IO<Unit>:
    probe(5n)
    probe(50n)
