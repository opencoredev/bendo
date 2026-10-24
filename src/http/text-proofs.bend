# Text's tail-recursive helpers equal Base's recursive ones (BND-84).
# This module deliberately does not import LAWS.
import Base
import ./text.bend as T

def string_append_nil(+s: String) -> {String.append(s, "") == s : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{h, t}:
      Equal.cong(String, String, x => SCon{h, x}, String.append(t, ""), t, string_append_nil(t))

def string_append_assoc(+a: String, +b: String, +c: String) -> {String.append(String.append(a, b), c) == String.append(a, String.append(b, c)) : String}:
  match a:
    case SNil{}:
      {==}
    case SCon{h, t}:
      Equal.cong(String, String, x => SCon{h, x}, String.append(String.append(t, b), c), String.append(t, String.append(b, c)), string_append_assoc(t, b, c))

def list_append_nil(-A: Data, +xs: List<&2, A>) -> {List.append(&2, A, xs, []) == xs : List<&2, A>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      Equal.cong(List<&2, A>, List<&2, A>, x => h <> x, List.append(&2, A, t, []), t, list_append_nil(A, t))

# Reversing onto an accumulator twice appends.
def reverse_onto(+a: String, +r: String, +b: String) -> {String.reverse.go(String.reverse.go(a, r), b) == String.reverse.go(r, String.append(a, b)) : String}:
  match a:
    case SNil{}:
      {==}
    case SCon{h, t}:
      reverse_onto(t, SCon{h, r}, b)

def bytes_reverse_onto(+xs: List<&2, U32>, +r: List<&2, U32>, +ys: List<&2, U32>) -> {List.reverse.go(&2, U32, List.reverse.go(&2, U32, xs, r), ys) == List.reverse.go(&2, U32, r, List.append(&2, U32, xs, ys)) : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      bytes_reverse_onto(t, h <> r, ys)

def bytes_append_equiv(+xs: List<&2, U32>, +ys: List<&2, U32>) -> {T.bytes_append(xs, ys) == List.append(&2, U32, xs, ys) : List<&2, U32>}:
  bytes_reverse_onto(xs, [], ys)

def lower_reverse(+s: String, +r: String, +acc: String) -> {T.lower_go(String.reverse.go(s, r), acc) == T.lower_go(r, String.append(String.to_lower(s), acc)) : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{h, t}:
      lower_reverse(t, SCon{h, r}, acc)

def lower_go_equiv(+s: String, +acc: String) -> {T.lower_go(String.reverse(s), acc) == String.append(String.to_lower(s), acc) : String}:
  lower_reverse(s, "", acc)

def lower_equiv(+s: String) -> {T.lower(s) == String.to_lower(s) : String}:
  Equal.trans(String, T.lower(s), String.append(String.to_lower(s), ""), String.to_lower(s), lower_reverse(s, "", ""), string_append_nil(String.to_lower(s)))

def upper_reverse(+s: String, +r: String, +acc: String) -> {T.upper_go(String.reverse.go(s, r), acc) == T.upper_go(r, String.append(String.to_upper(s), acc)) : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{h, t}:
      upper_reverse(t, SCon{h, r}, acc)

def upper_go_equiv(+s: String, +acc: String) -> {T.upper_go(String.reverse(s), acc) == String.append(String.to_upper(s), acc) : String}:
  upper_reverse(s, "", acc)

def upper_equiv(+s: String) -> {T.upper(s) == String.to_upper(s) : String}:
  Equal.trans(String, T.upper(s), String.append(String.to_upper(s), ""), String.to_upper(s), upper_reverse(s, "", ""), string_append_nil(String.to_upper(s)))

# ---- split ----

# Prefix the first part of a split with p.
def glue(p: String, parts: List<&2, String>) -> List<&2, String>:
  match parts:
    case Nil{}:
      [p]
    case q <> qs:
      String.append(p, q) <> qs

# A part reversed onto [h] is the part followed by h.
def reverse_snoc(+s: String, +acc: String, +b: String) -> {String.reverse.go(s, String.append(acc, b)) == String.append(String.reverse.go(s, acc), b) : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{h, t}:
      reverse_snoc(t, SCon{h, acc}, b)

def glue_push(h: Char, +parts: List<&2, String>) -> {glue("", String.split.push(h, parts)) == String.split.push(h, parts) : List<&2, String>}:
  match parts:
    case Nil{}:
      {==}
    case q <> qs:
      {==}

def glue_snoc(+rc: String, +h: Char, +parts: List<&2, String>) -> {glue(String.append(rc, SCon{h, SNil{}}), parts) == glue(rc, String.split.push(h, parts)) : List<&2, String>}:
  match parts:
    case Nil{}:
      {==}
    case q <> qs:
      Equal.cong(String, List<&2, String>, x => x <> qs, String.append(String.append(rc, SCon{h, SNil{}}), q), String.append(rc, SCon{h, q}), string_append_assoc(rc, SCon{h, SNil{}}, q))

def glue_empty_fin(+h: Char, +parts: List<&2, String>, cut: Bool) -> {glue("", String.split.fin(h, parts, cut)) == String.split.fin(h, parts, cut) : List<&2, String>}:
  match cut:
    case True{}:
      {==}
    case False{}:
      glue_push(h, parts)

def glue_empty_split(+t: String, +sep: Char) -> {glue("", String.split(t, sep)) == String.split(t, sep) : List<&2, String>}:
  match t:
    case SNil{}:
      {==}
    case SCon{h, u}:
      glue_empty_fin(h, String.split(u, sep), Char.is_eq(h, sep))

def rev_cons_snoc(+cur: String, h: Char) -> {String.reverse(SCon{h, cur}) == String.append(String.reverse(cur), SCon{h, SNil{}}) : String}:
  reverse_snoc(cur, "", SCon{h, SNil{}})

def split_case(+h: Char, +cur: String, +ps: List<&2, String>, +sep: Char, +t: String, cut: Bool, ih_cut: {T.split_go(t, sep, T.Split{"", String.reverse(cur) <> ps}) == List.reverse.go(&2, String, String.reverse(cur) <> ps, glue("", String.split(t, sep))) : List<&2, String>}, ih_keep: {T.split_go(t, sep, T.Split{SCon{h, cur}, ps}) == List.reverse.go(&2, String, ps, glue(String.reverse(SCon{h, cur}), String.split(t, sep))) : List<&2, String>}) -> {T.split_go(t, sep, T.split_step(h, T.Split{cur, ps}, cut)) == List.reverse.go(&2, String, ps, glue(String.reverse(cur), String.split.fin(h, String.split(t, sep), cut))) : List<&2, String>}:
  match cut:
    case True{}:
      +rc = String.reverse(cur)
      %Equal.sym(String, String.append(rc, ""), rc, string_append_nil(rc)) : {T.split_go(t, sep, T.Split{"", rc <> ps}) == List.reverse.go(&2, String, ps, _ <> String.split(t, sep)) : List<&2, String>}
      %glue_empty_split(t, sep) : {T.split_go(t, sep, T.Split{"", rc <> ps}) == List.reverse.go(&2, String, ps, rc <> _) : List<&2, String>}
      ih_cut
    case False{}:
      %glue_snoc(String.reverse(cur), h, String.split(t, sep)) : {T.split_go(t, sep, T.Split{SCon{h, cur}, ps}) == List.reverse.go(&2, String, ps, _) : List<&2, String>}
      %rev_cons_snoc(cur, h) : {T.split_go(t, sep, T.Split{SCon{h, cur}, ps}) == List.reverse.go(&2, String, ps, glue(_, String.split(t, sep))) : List<&2, String>}
      ih_keep

# The loop state (cur, ps) stands for the finished parts reversed in ps,
# followed by the reversed cur glued onto the parts of the remaining input.
def split_go_equiv(+s: String, +sep: Char, +cur: String, +ps: List<&2, String>) -> {T.split_go(s, sep, T.Split{cur, ps}) == List.reverse.go(&2, String, ps, glue(String.reverse(cur), String.split(s, sep))) : List<&2, String>}:
  match s:
    case SNil{}:
      Equal.cong(String, List<&2, String>, x => List.reverse.go(&2, String, ps, [x]), String.reverse(cur), String.append(String.reverse(cur), ""), Equal.sym(String, String.append(String.reverse(cur), ""), String.reverse(cur), string_append_nil(String.reverse(cur))))
    case SCon{h, t}:
      split_case(h, cur, ps, sep, t, Char.is_eq(h, sep), split_go_equiv(t, sep, "", String.reverse(cur) <> ps), split_go_equiv(t, sep, SCon{h, cur}, ps))

def split_equiv(+s: String, +sep: Char) -> {T.split(s, sep) == String.split(s, sep) : List<&2, String>}:
  Equal.trans(List<&2, String>, T.split(s, sep), glue("", String.split(s, sep)), String.split(s, sep), split_go_equiv(s, sep, "", []), glue_empty_split(s, sep))
