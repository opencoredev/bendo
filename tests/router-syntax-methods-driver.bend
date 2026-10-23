import Base
import ../src/router/methods.bend as M
import ../src/router/router.bend as Router
import ../src/router/spec.bend as S
import ../src/router/pattern.bend as P
import ../src/router/encoding.bend as E
import ../src/http/request.bend as R

def params(ps: P.Params) -> String:
  match ps:
    case Nil{}: ""
    case P.Param{name, value} <> rest:
      "|" ++ E.encode(name) ++ "=" ++ E.encode(value) ++ params(rest)

def result(r: M.Resolution<Nat>) -> String:
  match r:
    case M.Found{S.Match{i, tag, ps}, fallback}: "found" ++ params(ps)
    case M.NotFound{}: "404"
    case M.MethodNotAllowed{allow}: "405:" ++ M.allow_text(allow)

def registration(+source: String, all: String) -> M.Registration(Nat):
  match all:
    case "all": M.all(Nat, source, 0n)
    case _: M.get(Nat, source, 0n)

def run_built(built: Result<&2, &2, M.BuildError, M.Valid<Nat>>, +path: String, +method: R.Method, +opts: M.Options) -> String:
  match built:
    case Fail{error}: "error"
    case Done{valid}:
      +index = M.prepare(Nat, valid)
      result(M.resolve_with(Nat, Router.Spec{}, index, path, method, opts)) ++ "\t" ++ result(M.resolve_with(Nat, Router.Trie{}, index, path, method, opts))

def run(args: List<String>) -> String:
  match args:
    case exe <> source <> path <> method <> strict <> sensitive <> all <> Nil{}:
      run_built(M.build_table(Nat, [registration(source, all)]), path, R.method(method), M.Options{String.eq(strict, "true"), String.eq(sensitive, "true")})
    case _: "bad-args"

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    IO.print(run(args))
