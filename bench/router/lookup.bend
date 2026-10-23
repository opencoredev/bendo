import Base
import ../../src/router/spec.bend as S
import ../../src/router/router.bend as R
import ../../src/router/trie.bend as T
import ../../src/router/encoding.bend as E

def pad(s: String) -> String:
  match s:
    case SCon{a, SNil{}}:
      "00" ++ SCon{a, SNil{}}
    case SCon{a, SCon{b, SNil{}}}:
      "0" ++ SCon{a, SCon{b, SNil{}}}
    case _:
      s

def static_path(n: Nat) -> String:
  "/r" ++ pad(Nat.show(n))

def sources(fuel: Nat, +index: Nat, +dynamic: Bool) -> List<&2, S.Registration<U32>>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+rest:
      +r = rest
      source = E.choose(String, dynamic, u => (
        E.choose(String, Nat.is_eq(r, 0n), u => "/shared/:value", u => "/shared/:value{int}")
      ), u => static_path(index))
      S.Registration{source, U32.from_nat(index)} <> sources(r, 1n+index, dynamic)

def paths(fuel: Nat, +count: Nat, +mode: String) -> List<&2, String>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+rest:
      +r = rest
      path = E.choose(String, String.eq(mode, "last"), u => static_path(count), u => (
        E.choose(String, String.eq(mode, "miss"), u => "/r999", u => (
          E.choose(String, String.eq(mode, "first"), u => "/r001", u => (
            E.choose(String, String.eq(mode, "dynamic-first"), u => "/shared/42", u => (
              E.choose(String, String.eq(mode, "dynamic-last"), u => "/shared/word", u => static_path(1n+r))
            ))
          ))
        ))
      ))
      path <> paths(r, count, mode)

def path_weight(xs: List<&2, String>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case h <> t:
      Nat.add(String.length(h), path_weight(t))

def nodes(trie: T.Trie<U32>) -> Nat:
  match trie:
    case T.Tip{}:
      0n
    case T.Fork{char, equal, other}:
      1n+Nat.add(nodes(equal), nodes(other))
    case T.Node{entries, kids, other}:
      1n+Nat.add(List.length(&2, T.Candidate<U32>, entries), Nat.add(nodes(kids), nodes(other)))

def prepared_weight(router: R.Prepared<U32>) -> Nat:
  R.Prepared{table, trie} = router
  Nat.add(List.length(&2, S.Route<U32>, table), nodes(trie))

def value(hit: Maybe<&2, S.Match<U32>>) -> U32:
  match hit:
    case None{}:
      0
    case Some{S.Match{index, tag, ps}}:
      tag

def walk(xs: List<&2, String>, +kind: R.RouterKind, +router: R.Prepared<U32>, sum: U32) -> U32:
  match xs:
    case Nil{}:
      sum
    case path <> rest:
      walk(rest, kind, router, (sum + value(R.route(U32, kind, router, path)) : U32))

def batch(fuel: Nat, +kind: R.RouterKind, +router: R.Prepared<U32>, +xs: List<&2, String>, sum: U32) -> U32:
  match fuel:
    case 0n:
      sum
    case 1n+rest:
      batch(rest, kind, router, xs, walk(xs, kind, router, sum))

def measure(kind: R.RouterKind, router: R.Prepared<U32>, xs: List<&2, String>, cycles: Nat) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    sum : U32 = batch(cycles, kind, router, xs, 0)
    IO.print("checksum=" ++ U32.show(sum))
    end : Nat <- IO.now()
    IO.print("ms=" ++ Nat.show(Nat.sub(end, start)))

def built(result: Result<&2, &2, S.BuildError, S.Table(U32)>, kind: R.RouterKind, +count: Nat, mode: String, cycles: Nat, start: Nat) -> IO(Unit):
  match result:
    case Fail{e}:
      IO.die(Unit, 1, "benchmark table failed to compile")
    case Done{table}:
      do IO<Unit>:
        +router : R.Prepared<U32> = R.prepare(U32, table)
        IO.print("prepared_weight=" ++ Nat.show(prepared_weight(router)))
        end : Nat <- IO.now()
        IO.print("prepare_ms=" ++ Nat.show(Nat.sub(end, start)))
        +xs : List<&2, String> = paths(count, count, mode)
        IO.print("path_weight=" ++ Nat.show(path_weight(xs)))
        measure(kind, router, xs, cycles)

def run_numbers(count: Maybe<&2, Nat>, cycles: Maybe<&2, Nat>, +kind: String, +mode: String) -> IO(Unit):
  match count cycles:
    case Some{+n} Some{c}:
      do IO<Unit>:
        start : Nat <- IO.now()
        built(S.build_table(U32, sources(n, 1n, String.starts_with(mode, "dynamic"))), E.choose(R.RouterKind, String.eq(kind, "trie"), u => R.Trie{}, u => R.Spec{}), n, mode, c, start)
    case _ _:
      IO.die(Unit, 1, "invalid numeric arguments")

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case program <> count <> kind <> mode <> cycles <> Nil{}:
      run_numbers(Nat.read(count), Nat.read(cycles), kind, mode)
    case _:
      IO.die(Unit, 1, "expected count, spec|trie, workload, cycles")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
