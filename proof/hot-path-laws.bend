# BND-68: each hot-path rewrite equals its retained definition for every
# input, so every earlier law about the original carries over unchanged.
import Base
import ../src/data/utf8.bend as Utf8

law hot_utf8_encode_char:
  for +c: U32
  {Utf8.encode_char(c) == Utf8.encode_char_spec(c) : List<&2, U32>}
