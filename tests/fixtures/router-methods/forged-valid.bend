import Base
import ../../../src/router/methods.bend as M
import ../../../src/router/spec.bend as S
import ../../../src/router/pattern.bend as P
import ../../../src/http/request.bend as R

def main() -> M.Valid<U32>:
  M.Valid{[S.Route{P.Pattern{[P.Static{"a"}]}, M.Binding{[R.Extension{"BAD TOKEN"}], 1}}], {==}}
