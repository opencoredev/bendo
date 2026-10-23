import Base
import ../src/data/utf8.bend as U
import ./utf8.bend as UP

def string_nil(+s: String) -> {s ++ "" == s : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{h, t}:
      Equal.cong(String, String, x => SCon{h, x}, t ++ "", t, string_nil(t))

def reverse_append(+a: String, +b: String, +c: String) -> {String.reverse.go(a ++ b, c) == String.reverse.go(b, String.reverse.go(a, c)) : String}:
  match a:
    case SNil{}:
      {==}
    case SCon{h, t}:
      reverse_append(t, b, SCon{h, c})

def reverse_twice(+a: String, +b: String, +c: String) -> {String.reverse.go(String.reverse.go(a, b), c) == String.reverse.go(b, a ++ c) : String}:
  match a:
    case SNil{}:
      {==}
    case SCon{h, t}:
      reverse_twice(t, SCon{h, b}, c)

def reverse_block(+block: String, +rev: String, +tail: String) -> {String.reverse.go(String.reverse(block) ++ rev, tail) == String.reverse.go(rev, block ++ tail) : String}:
  %Equal.sym(String, String.reverse.go(String.reverse(block) ++ rev, tail), String.reverse.go(rev, String.reverse.go(String.reverse(block), tail)), reverse_append(String.reverse(block), rev, tail)) : {_ == String.reverse.go(rev, block ++ tail) : String}
  Equal.cong(String, String, x => String.reverse.go(rev, x), String.reverse.go(String.reverse(block), tail), block ++ tail, reverse_twice(block, "", tail))

def reverse_last(+block: String, +rev: String) -> {String.reverse(String.reverse(block) ++ rev) == String.reverse.go(rev, block) : String}:
  %Equal.sym(String, String.reverse(String.reverse(block) ++ rev), String.reverse.go(rev, block ++ ""), reverse_block(block, rev, "")) : {_ == String.reverse.go(rev, block) : String}
  Equal.cong(String, String, x => String.reverse.go(rev, x), block ++ "", block, string_nil(block))

def byte_reconstruct(+w: Word(32n), ok: {(U32{w} <= 255 : U32) == True{} : Bool}) -> {U32{U.join(8n, 24n, U.low(8n, 24n, w), Word.zero(24n))} == U32{w} : U32}:
  Equal.cong(Word(32n), U32, x => U32{x}, U.join(8n, 24n, U.low(8n, 24n, w), Word.zero(24n)), w, UP.pad_reconstruct(8n, 24n, w, UP.cmp_le_zero(24n, U.high(8n, 24n, w), UP.high_le(8n, 24n, w, UP.bits(255), ok))))
