import Base
import ../../src/router/spec.bend as S
import ../../src/router/router.bend as R
import ../../src/router/methods.bend as M
import ../../src/router/encoding.bend as E
import ../../src/http/request.bend as H

# GET registrations sharing a dynamic first segment. Every index except the
# last is /shared/:value{int}; the last accepts any value.
def sources(fuel: Nat, +index: Nat) -> List<&2, M.Registration(U32)>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+rest:
      +r = rest
      source = E.choose(String, Nat.is_eq(r, 0n), u => "/shared/:value", u => "/shared/:value{int}")
      M.get(U32, source, U32.from_nat(index)) <> sources(r, 1n+index)

def path(+mode: String) -> String:
  E.choose(String, String.eq(mode, "last"), u => "/shared/word", u => (
    E.choose(String, String.eq(mode, "miss"), u => "/shared/1/2", u => "/shared/42")
  ))

def method(+mode: String) -> H.Method:
  E.choose(H.Method, String.eq(mode, "405"), u => H.Post{}, u => (
    E.choose(H.Method, String.eq(mode, "head"), u => H.Head{}, u => H.Get{})
  ))

def head_mark(head: Bool) -> U32:
  match head:
    case True{}:
      1000000
    case False{}:
      0

# Found adds its tag (plus 1,000,000 for HEAD from GET); 405 adds 100,000
# plus the Allow length; 404 adds nothing.
def value(r: M.Resolution<U32>) -> U32:
  match r:
    case M.Found{S.Match{index, tag, ps}, head}:
      (tag + head_mark(head) : U32)
    case M.MethodNotAllowed{allow}:
      (100000 + U32.from_nat(List.length(&2, H.Method, allow)) : U32)
    case M.NotFound{}:
      0

def batch(fuel: Nat, +kind: R.RouterKind, +index: M.Index<U32>, +p: String, +m: H.Method, sum: U32) -> U32:
  match fuel:
    case 0n:
      sum
    case 1n+rest:
      batch(rest, kind, index, p, m, (sum + value(M.resolve_with(U32, kind, index, p, m, M.defaults())) : U32))

def built(result: Result<&2, &2, M.BuildError, M.Valid<U32>>, kind: R.RouterKind, +mode: String, iterations: Nat, start: Nat) -> IO(Unit):
  match result:
    case Fail{e}:
      IO.die(Unit, 1, "benchmark table failed to compile")
    case Done{valid}:
      do IO<Unit>:
        +index : M.Index<U32> = M.prepare(U32, valid)
        prepared : Nat <- IO.now()
        IO.print("prepare_ms=" ++ Nat.show(Nat.sub(prepared, start)))
        +p : String = path(mode)
        +m : H.Method = method(mode)
        begin : Nat <- IO.now()
        sum : U32 = batch(iterations, kind, index, p, m, 0)
        IO.print("checksum=" ++ U32.show(sum))
        end : Nat <- IO.now()
        IO.print("ms=" ++ Nat.show(Nat.sub(end, begin)))

def run_numbers(count: Maybe<&2, Nat>, iterations: Maybe<&2, Nat>, +kind: String, +mode: String) -> IO(Unit):
  match count iterations:
    case Some{+n} Some{i}:
      do IO<Unit>:
        start : Nat <- IO.now()
        built(M.build_table(U32, sources(n, 1n)), E.choose(R.RouterKind, String.eq(kind, "trie"), u => R.Trie{}, u => R.Spec{}), mode, i, start)
    case _ _:
      IO.die(Unit, 1, "invalid numeric arguments")

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case program <> count <> kind <> mode <> iterations <> Nil{}:
      run_numbers(Nat.read(count), Nat.read(iterations), kind, mode)
    case _:
      IO.die(Unit, 1, "expected count, spec|trie, first|last|miss|405|head, iterations")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
