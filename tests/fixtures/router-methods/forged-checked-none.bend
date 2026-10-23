import Base
import ../../../src/router/methods.bend as M
import ../../../src/http/request.bend as R

def main() -> Result<&2, &2, M.BuildError, M.Table(U32)>:
  M.build_methods(U32, 0n, "/a", [R.Extension{"BAD TOKEN"}], 1, None{}, {==}, u => Done{Nil{}})
