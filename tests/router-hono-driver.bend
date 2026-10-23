import Base
import ../src/router/spec.bend as S
import ../src/router/router.bend as R
import ../src/router/pattern.bend as P
import ../src/router/encoding.bend as E
import ../src/router/methods.bend as M
import ../src/http/request.bend as Q

def params_text(ps: P.Params) -> String:
  match ps:
    case Nil{}:
      ""
    case P.Param{name, value} <> rest:
      "|" ++ E.encode(name) ++ "=" ++ E.encode(value) ++ params_text(rest)

def hit_text(hit: Maybe<&2, S.Match<U32>>) -> String:
  match hit:
    case None{}:
      "none"
    case Some{S.Match{index, tag, ps}}:
      Nat.show(index) ++ ":" ++ U32.show(tag) ++ params_text(ps)

def registrations(xs: List<&2, String>, +index: U32) -> List<&2, S.Registration<U32>>:
  match xs:
    case method <> source <> rest:
      S.Registration{source, index} <> registrations(rest, (index + 1 : U32))
    case _:
      Nil{}

def method_entries(xs: List<&2, String>, +index: U32) -> List<&2, M.Registration(U32)>:
  match xs:
    case +method <> +source <> rest:
      E.choose(M.Registration(U32), String.eq(method, "ALL"), u => M.all(U32, source, index), u => M.on(U32, [Q.method(method)], source, index)) <> method_entries(rest, (index + 1 : U32))
    case _:
      Nil{}

def resolution_text(result: M.Resolution<U32>) -> String:
  match result:
    case M.Found{hit, head_from_get}:
      hit_text(Some{hit}) ++ ";head_from_get=" ++ E.choose(String, head_from_get, u => "true", u => "false")
    case M.NotFound{}:
      "none"
    case M.MethodNotAllowed{allow}:
      "allow:" ++ M.allow_text(allow)

def method_text(+path: String, method: String, built: Result<&2, &2, M.BuildError, M.Valid<U32>>) -> String:
  match built:
    case Fail{M.InvalidPattern{index, source, P.PatternError{kind, segment}}}:
      "error:" ++ Nat.show(index) ++ ":" ++ P.error_kind(kind)
    case Fail{M.InvalidMethod{index, source, token}}:
      "method-error:" ++ Nat.show(index)
    case Done{+table}:
      resolution_text(M.resolve_with(U32, R.default_kind(), M.prepare(U32, table), path, Q.method(method), M.defaults()))

def run_table(+path: String, +method: String, +sources: List<&2, String>, built: Result<&2, &2, S.BuildError, S.Table(U32)>) -> IO(Unit):
  match built:
    case Fail{S.BuildError{index, source, P.PatternError{kind, segment}}}:
      +error = "error:" ++ Nat.show(index) ++ ":" ++ P.error_kind(kind)
      IO.print(error ++ "\t" ++ error ++ "\t" ++ method_text(path, method, M.build_table(U32, method_entries(sources, 0))))
    case Done{+table}:
      +prepared = R.prepare(U32, table)
      IO.print(hit_text(R.route(U32, R.Spec{}, prepared, path)) ++ "\t" ++ hit_text(R.route(U32, R.Trie{}, prepared, path)) ++ "\t" ++ method_text(path, method, M.build_table(U32, method_entries(sources, 0))))

def decoded_fields(xs: List<&2, String>) -> Maybe<&2, List<&2, String>>:
  match xs:
    case Nil{}:
      Some{Nil{}}
    case h <> t:
      do Maybe<&2, List<&2, String>>:
        value : String <- E.decode(h)
        tail : List<&2, String> <- decoded_fields(t)
        return value <> tail

def run_fields(fields: Maybe<&2, List<&2, String>>) -> IO(Unit):
  match fields:
    case Some{+path <> +method <> +sources}:
      run_table(path, method, sources, S.build_table(U32, registrations(sources, 0)))
    case _:
      IO.die(Unit, 1, "invalid test transport")

def run_lines(lines: List<&2, String>) -> IO(Unit):
  match lines:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case line <> rest:
      do IO<Unit>:
        run_fields(decoded_fields(String.split(line, '\t')))
        run_lines(rest)

def read_contents(read: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  (f, contents) = read
  do IO<String>:
    File.close(f)
    IO.pass(String, contents)

def read_cases(args: List<String>) -> IO(Unit):
  match args:
    case program <> file <> Nil{}:
      do IO<Unit>:
        f : File <- IO.try(File, File.open(file, "r"))
        read : File & Result<&1, &1, U32 & String, String> <- File.read(f, 33554432)
        text : String <- read_contents(read)
        run_lines(String.lines(text))
    case _:
      IO.die(Unit, 1, "expected case-file argument")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    read_cases(args)
