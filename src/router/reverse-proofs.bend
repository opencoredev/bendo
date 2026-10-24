# Lemmas for loops that build their output reversed and flip it once at the
# end (BND-84). Those loops are tail calls, so request-sized input cannot
# exhaust the JavaScript stack; these lemmas tie them to the recursive specs.
import Base

# Reversing onto an accumulator twice appends.
def string_onto(+a: String, +r: String, +b: String) -> {String.reverse.go(String.reverse.go(a, r), b) == String.reverse.go(r, String.append(a, b)) : String}:
  match a:
    case SNil{}:
      {==}
    case SCon{h, t}:
      string_onto(t, SCon{h, r}, b)

def string_append_onto(+a: String, +b: String, +r: String) -> {String.reverse.go(String.append(a, b), r) == String.reverse.go(b, String.reverse.go(a, r)) : String}:
  match a:
    case SNil{}:
      {==}
    case SCon{h, t}:
      string_append_onto(t, b, SCon{h, r})

def list_onto(-A: Data, +xs: List<&2, A>, +r: List<&2, A>, +ys: List<&2, A>) -> {List.reverse.go(&2, A, List.reverse.go(&2, A, xs, r), ys) == List.reverse.go(&2, A, r, List.append(&2, A, xs, ys)) : List<&2, A>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      list_onto(A, t, h <> r, ys)

def list_append_nil(-A: Data, +xs: List<&2, A>) -> {List.append(&2, A, xs, []) == xs : List<&2, A>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      Equal.cong(List<&2, A>, List<&2, A>, x => h <> x, List.append(&2, A, t, []), t, list_append_nil(A, t))

def list_twice(-A: Data, +xs: List<&2, A>) -> {List.reverse(&2, A, List.reverse(&2, A, xs)) == xs : List<&2, A>}:
  Equal.trans(List<&2, A>, List.reverse(&2, A, List.reverse(&2, A, xs)), List.append(&2, A, xs, []), xs, list_onto(A, xs, [], []), list_append_nil(A, xs))

def string_append_nil(+s: String) -> {String.append(s, "") == s : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{h, t}:
      Equal.cong(String, String, x => SCon{h, x}, String.append(t, ""), t, string_append_nil(t))

def string_twice(+s: String) -> {String.reverse(String.reverse(s)) == s : String}:
  Equal.trans(String, String.reverse(String.reverse(s)), String.append(s, ""), s, string_onto(s, "", ""), string_append_nil(s))
