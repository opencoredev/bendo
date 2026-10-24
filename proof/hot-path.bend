# BND-68: proofs that the hot-path rewrites equal their retained specs.
import Base
import ./hot-path-laws.bend as Laws
import ../src/data/utf8.bend as Utf8
import ./utf8.bend as UP

def Laws.hot_utf8_encode_char(c):
  Equal.sym(List<&2, U32>, Utf8.encode_char_spec(c), Utf8.encode_char(c), UP.encode_char_equiv(c))
