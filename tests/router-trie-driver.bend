import Base
import ../src/router/spec.bend as S
import ../src/router/trie.bend as T
import ../src/router/router.bend as R
import ../src/router/pattern.bend as P
import ../src/router/encoding.bend as E

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
    case Nil{}:
      Nil{}
    case source <> rest:
      S.Registration{source, (1000 + index * 17 : U32)} <> registrations(rest, (index + 1 : U32))

def run_table(+path: String, built: Result<&2, &2, S.BuildError, S.Table(U32)>) -> IO(Unit):
  match built:
    case Fail{S.BuildError{index, source, error}}:
      IO.die(Unit, 1, "invalid registration " ++ Nat.show(index) ++ ": " ++ P.error_message(error))
    case Done{+table}:
      +trie = T.build_trie(U32, table)
      +prepared = R.prepare(U32, table)
      IO.print(hit_text(S.route(U32, table, path)) ++ "\t" ++ hit_text(T.trie_route(U32, trie, path)) ++ "\t" ++ hit_text(R.route(U32, R.default_kind(), prepared, path)) ++ "\t" ++ hit_text(R.route(U32, R.Trie{}, prepared, path)))

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
    case Some{path <> sources}:
      run_table(path, S.build_table(U32, registrations(sources, 0)))
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

def kind_text(kind: R.RouterKind) -> String:
  match kind:
    case R.Spec{}:
      "default=Spec"
    case R.Trie{}:
      "default=Trie"

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
        IO.print(kind_text(R.default_kind()))
        run_lines(String.lines(text))
    case _:
      IO.die(Unit, 1, "expected case-file argument")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    read_cases(args)
