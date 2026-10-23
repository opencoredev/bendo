import Base
import ../src/router/pattern.bend as P
import ../src/router/encoding.bend as E

# The CLI protocol percent-encodes every output character, including newlines.
def params_text(ps: P.Params) -> String:
  match ps:
    case Nil{}:
      ""
    case P.Param{name, value} <> t:
      E.encode(name) ++ "=" ++ E.encode(value) ++ "\n" ++ params_text(t)

def match_text(r: Maybe<&2, P.Params>) -> String:
  match r:
    case None{}:
      "none\n"
    case Some{ps}:
      "match\n" ++ params_text(ps)

def read_params(args: List<String>) -> Maybe<&2, P.Params>:
  match args:
    case Nil{}:
      Some{Nil{}}
    case name <> value <> t:
      do Maybe<&2, P.Params>:
        ps : P.Params <- read_params(t)
        return P.Param{name, value} <> ps
    case _:
      None{}

def rejected_fill(r: Maybe<&2, String>) -> String:
  match r:
    case None{}:
      "inadmissible\n"
    case Some{path}:
      "invalid-accepted\n"

def fill_text(+pattern: P.Pattern, ps: Maybe<&2, P.Params>) -> String:
  match ps:
    case None{}:
      "bad-args\n"
    case Some{+values}:
      E.choose(String, P.admissible(pattern, values), u => (
        Maybe.default(&2, String, Maybe.map(&2, String, String, +path => "fill\n" ++ E.encode(path) ++ "\n" ++ match_text(P.match_path(pattern, path)), P.fill(pattern, values)), "fill-failed\n")
      ), u => (rejected_fill(P.fill(pattern, values))))

def run_compiled(r: Result<&2, &2, P.PatternError, P.Pattern>, args: List<String>) -> String:
  match r args:
    case Fail{P.PatternError{kind, segment}} _:
      "error\n" ++ P.error_kind(kind) ++ "\n" ++ E.encode(segment) ++ "\n"
    case Done{pattern} "match" <> path <> Nil{}:
      match_text(P.match_path(pattern, path))
    case Done{pattern} "fill" <> rest:
      fill_text(pattern, read_params(rest))
    case _ _:
      "bad-args\n"

def run(args: List<String>) -> String:
  match args:
    case exe <> source <> rest:
      run_compiled(P.compile(source), rest)
    case _:
      "bad-args\n"

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    IO.print(run(args))
