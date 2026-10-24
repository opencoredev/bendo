# Compatibility names for the text equivalences used by the law modules.
# The canonical proofs live under src/ so scaffolded applications copy them.
import Base
import ../src/http/text.bend as T
import ../src/http/text-proofs.bend as Core

def string_append_nil(+s: String) -> {String.append(s, "") == s : String}:
  Core.string_append_nil(s)

def string_append_assoc(+a: String, +b: String, +c: String) -> {String.append(String.append(a, b), c) == String.append(a, String.append(b, c)) : String}:
  Core.string_append_assoc(a, b, c)

def list_append_nil(-A: Data, +xs: List<&2, A>) -> {List.append(&2, A, xs, []) == xs : List<&2, A>}:
  Core.list_append_nil(A, xs)

def reverse_onto(+a: String, +r: String, +b: String) -> {String.reverse.go(String.reverse.go(a, r), b) == String.reverse.go(r, String.append(a, b)) : String}:
  Core.reverse_onto(a, r, b)

def bytes_reverse_onto(+xs: List<&2, U32>, +r: List<&2, U32>, +ys: List<&2, U32>) -> {List.reverse.go(&2, U32, List.reverse.go(&2, U32, xs, r), ys) == List.reverse.go(&2, U32, r, List.append(&2, U32, xs, ys)) : List<&2, U32>}:
  Core.bytes_reverse_onto(xs, r, ys)

def bytes_append_equiv(+xs: List<&2, U32>, +ys: List<&2, U32>) -> {T.bytes_append(xs, ys) == List.append(&2, U32, xs, ys) : List<&2, U32>}:
  Core.bytes_append_equiv(xs, ys)

def lower_reverse(+s: String, +r: String, +acc: String) -> {T.lower_go(String.reverse.go(s, r), acc) == T.lower_go(r, String.append(String.to_lower(s), acc)) : String}:
  Core.lower_reverse(s, r, acc)

def lower_go_equiv(+s: String, +acc: String) -> {T.lower_go(String.reverse(s), acc) == String.append(String.to_lower(s), acc) : String}:
  Core.lower_go_equiv(s, acc)

def lower_equiv(+s: String) -> {T.lower(s) == String.to_lower(s) : String}:
  Core.lower_equiv(s)

def upper_reverse(+s: String, +r: String, +acc: String) -> {T.upper_go(String.reverse.go(s, r), acc) == T.upper_go(r, String.append(String.to_upper(s), acc)) : String}:
  Core.upper_reverse(s, r, acc)

def upper_go_equiv(+s: String, +acc: String) -> {T.upper_go(String.reverse(s), acc) == String.append(String.to_upper(s), acc) : String}:
  Core.upper_go_equiv(s, acc)

def upper_equiv(+s: String) -> {T.upper(s) == String.to_upper(s) : String}:
  Core.upper_equiv(s)

def glue(p: String, parts: List<&2, String>) -> List<&2, String>:
  Core.glue(p, parts)

def reverse_snoc(+s: String, +acc: String, +b: String) -> {String.reverse.go(s, String.append(acc, b)) == String.append(String.reverse.go(s, acc), b) : String}:
  Core.reverse_snoc(s, acc, b)

def glue_push(h: Char, +parts: List<&2, String>) -> {glue("", String.split.push(h, parts)) == String.split.push(h, parts) : List<&2, String>}:
  Core.glue_push(h, parts)

def glue_snoc(+rc: String, +h: Char, +parts: List<&2, String>) -> {glue(String.append(rc, SCon{h, SNil{}}), parts) == glue(rc, String.split.push(h, parts)) : List<&2, String>}:
  Core.glue_snoc(rc, h, parts)

def glue_empty_fin(+h: Char, +parts: List<&2, String>, cut: Bool) -> {glue("", String.split.fin(h, parts, cut)) == String.split.fin(h, parts, cut) : List<&2, String>}:
  Core.glue_empty_fin(h, parts, cut)

def glue_empty_split(+t: String, +sep: Char) -> {glue("", String.split(t, sep)) == String.split(t, sep) : List<&2, String>}:
  Core.glue_empty_split(t, sep)

def rev_cons_snoc(+cur: String, h: Char) -> {String.reverse(SCon{h, cur}) == String.append(String.reverse(cur), SCon{h, SNil{}}) : String}:
  Core.rev_cons_snoc(cur, h)

def split_case(+h: Char, +cur: String, +ps: List<&2, String>, +sep: Char, +t: String, cut: Bool, ih_cut: {T.split_go(t, sep, T.Split{"", String.reverse(cur) <> ps}) == List.reverse.go(&2, String, String.reverse(cur) <> ps, glue("", String.split(t, sep))) : List<&2, String>}, ih_keep: {T.split_go(t, sep, T.Split{SCon{h, cur}, ps}) == List.reverse.go(&2, String, ps, glue(String.reverse(SCon{h, cur}), String.split(t, sep))) : List<&2, String>}) -> {T.split_go(t, sep, T.split_step(h, T.Split{cur, ps}, cut)) == List.reverse.go(&2, String, ps, glue(String.reverse(cur), String.split.fin(h, String.split(t, sep), cut))) : List<&2, String>}:
  Core.split_case(h, cur, ps, sep, t, cut, ih_cut, ih_keep)

def split_go_equiv(+s: String, +sep: Char, +cur: String, +ps: List<&2, String>) -> {T.split_go(s, sep, T.Split{cur, ps}) == List.reverse.go(&2, String, ps, glue(String.reverse(cur), String.split(s, sep))) : List<&2, String>}:
  Core.split_go_equiv(s, sep, cur, ps)

def split_equiv(+s: String, +sep: Char) -> {T.split(s, sep) == String.split(s, sep) : List<&2, String>}:
  Core.split_equiv(s, sep)
