import Base
import ../src/main.bend as B
import ../src/app/manifest.bend as Manifest
import ../src/router/methods.bend as M
import ../src/router/pattern.bend as P
import ../src/http/request.bend as R
import ../src/app/table.bend as T
import ../src/app/scopes.bend as Scopes

def built(result: Result<&2, &2, M.BuildError, B.Routes(U32)>) -> IO(Unit):
  match result:
    case Fail{M.InvalidPattern{index, source, P.PatternError{kind, segment}}}:
      IO.print(Nat.show(index) ++ ":" ++ source ++ ":" ++ P.error_kind(kind))
    case Fail{M.InvalidMethod{index, source, token}}: IO.print("invalid method")
    case Done{table}: IO.print(Manifest.json(U32, table))

def resolution(result: M.Resolution<U32>) -> IO(Unit):
  match result:
    case M.Found{hit, fallback}: IO.print("found")
    case M.NotFound{}: IO.print("missing")
    case M.MethodNotAllowed{allow}: IO.print("wrong method")

def resolved(result: Result<&2, &2, M.BuildError, B.Routes(U32)>, path: String) -> IO(Unit):
  match result:
    case Fail{e}: IO.print("build failed")
    case Done{T.Table{sources, compiled, layers, count}}:
      resolution(M.resolve(U32, M.index_valid(U32, compiled), path, R.Get{}, M.defaults()))

def main() -> IO(Unit):
  do IO<Unit>:
    built(B.routes(U32, B.route(U32, "bad", [B.get(U32, "/x", 0)])))
    built(B.routes(U32, B.base_path(U32, "/:id", [B.get(U32, "/:id", 0)])))
    built(B.routes(U32, B.group(U32, "/:tenant?", [], [B.get(U32, "/required", 0)])))
    built(B.routes(U32, B.route(U32, "/api", [B.use_path(U32, "/:bad{unknown}", 0), B.get(U32, "/ok", 0)])))
    built(B.routes(U32, B.route(U32, "/api", [
      B.on(U32, [R.Get{}, R.Post{}, R.Get{}], "/:id?", 0),
      B.all(U32, "/files/*tail", 0),
      B.get(U32, "/:span{.+}/end", 0),
      B.get(U32, "/a/*/b/assets*", 0),
      B.get(U32, "/same", 1), B.get(U32, "/same", 2)])))
    resolved(B.routes(U32, [B.get(U32, "/:id?", 0)]), "/")
    resolved(B.routes(U32, B.route(U32, "/api", [B.get(U32, "/:id?", 0)])), "/api")
    resolved(B.routes(U32, B.route(U32, "/api", [B.get(U32, "/:id?", 0)])), "/api/")
    IO.print(Scopes.prefix_path("/a//", Scopes.prefix_path("", "/x")))
    IO.print(Scopes.prefix_path(Scopes.prefix_path("/a//", ""), "/x"))
