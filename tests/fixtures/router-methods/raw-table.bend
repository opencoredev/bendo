import Base
import ../../../src/router/methods.bend as M
import ../../../src/router/spec.bend as S
import ../../../src/router/pattern.bend as P
import ../../../src/http/request.bend as R

def main() -> M.Resolution<U32>:
  M.resolve(U32, [S.Route{P.Pattern{[P.Static{"a"}]}, M.Binding{M.OnlyMethods{[R.Extension{"BAD TOKEN"}]}, 1}}], "/a", R.Post{}, M.defaults())
