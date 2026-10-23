import Base
import ../src/router/methods.bend as M
import ../src/router/spec.bend as S
import ../src/router/pattern.bend as P
import ../src/http/request.bend as R

type Tag is Data:
  First{}
  Later{}

def label(tag: Tag) -> String:
  match tag:
    case First{}:
      "first"
    case Later{}:
      "later"

def result(result: M.Resolution<Tag>) -> String:
  match result:
    case M.Found{S.Match{i, tag, ps}, True{}}:
      label(tag) ++ ":" ++ Nat.show(i) ++ ":fallback"
    case M.Found{S.Match{i, tag, ps}, False{}}:
      label(tag) ++ ":" ++ Nat.show(i) ++ ":direct"
    case M.MethodNotAllowed{allow}:
      "405:" ++ M.allow_text(allow)
    case M.NotFound{}:
      "404"

def show(table: M.Valid<Tag>, path: String, method: R.Method) -> IO(Unit):
  IO.print(result(M.resolve(Tag, table, path, method, M.defaults())))

def built(r: Result<&2, &2, M.BuildError, M.Valid<Tag>>) -> IO(Unit):
  match r:
    case Fail{M.InvalidPattern{i, source, error}}:
      IO.print(Nat.show(i) ++ ":" ++ source ++ ":" ++ P.error_message(error))
    case Fail{M.InvalidMethod{i, source, token}}:
      IO.print(Nat.show(i) ++ ":" ++ source ++ ":InvalidMethod:" ++ token)
    case Done{+table}:
      do IO<Unit>:
        show(table, "/all", R.Connect{})
        show(table, "/priority", R.Get{})
        show(table, "/priority", R.Head{})
        show(table, "/fallback", R.Head{})
        show(table, "/head-only", R.Get{})
        show(table, "/all", R.Head{})
        show(table, "/all", R.Extension{"PROPFIND"})

def constructed(result: Result<&2, &2, M.BuildError, M.Valid<Tag>>) -> IO(Unit):
  match result:
    case Fail{M.InvalidMethod{i, source, token}}:
      IO.print(Nat.show(i) ++ ":" ++ source ++ ":InvalidMethod:" ++ token)
    case Fail{M.InvalidPattern{i, source, error}}:
      IO.print(Nat.show(i) ++ ":" ++ source ++ ":" ++ P.error_message(error))
    case Done{+table}:
      do IO<Unit>:
        show(table, "/a", R.Get{})
        show(table, "/a", R.Head{})
        show(table, "/a", R.Post{})
        show(table, "/a", R.Extension{"get"})

def construction(entries: List<&2, M.Registration(Tag)>) -> IO(Unit):
  constructed(M.build_table(Tag, entries))

def main() -> IO(Unit):
  do IO<Unit>:
    built(M.build_table(Tag, [
      M.all(Tag, "/all", First{}),
      M.get(Tag, "/priority", First{}),
      M.get(Tag, "/priority", Later{}),
      M.head(Tag, "/priority", Later{}),
      M.get(Tag, "/fallback", First{}),
      M.head(Tag, "/head-only", First{})
    ]))
    built(M.build_table(Tag, [M.get(Tag, "/ok", First{}), M.post(Tag, "bad", Later{}), M.get(Tag, "/later", Later{})]))
    show(M.Valid{[S.Route{P.Pattern{[P.Static{"a"}]}, M.Binding{[R.Get{}], First{}}}], {==}}, "/a", R.Post{})
    construction([M.get(Tag, "/a", First{})])
    construction([M.on(Tag, [R.Extension{"GET"}], "/a", First{})])
    construction([M.on(Tag, [R.Extension{"get"}], "/a", First{})])
    construction([M.get(Tag, "/ok", First{}), M.on(Tag, [R.Extension{""}], "/a", Later{}), M.get(Tag, "/later", Later{})])
    construction([M.get(Tag, "/ok", First{}), M.on(Tag, [R.Extension{"BAD TOKEN"}], "/a", Later{})])
    construction([M.on(Tag, [R.Extension{"GET"}, R.Get{}, R.Extension{"get"}, R.Extension{"get"}], "/a", First{})])
    construction([M.on(Tag, [R.Extension{"BAD TOKEN"}], "/a", First{}), M.get(Tag, "bad", Later{})])
