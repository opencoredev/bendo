# String accumulator identities shared by JSON continuation proofs.
import Base

def append_nil(+s: String) -> {s ++ "" == s : String}:
  match s:
    case SNil{}: {==}
    case SCon{h, t}:
      %append_nil(t) : {SCon{h, t ++ ""} == SCon{h, _} : String}
      {==}

def append_assoc(+a: String, +b: String, +c: String) -> {(a ++ b) ++ c == a ++ (b ++ c) : String}:
  match a:
    case SNil{}: {==}
    case SCon{h, t}:
      %append_assoc(t, b, c) : {SCon{h, (t ++ b) ++ c} == SCon{h, _} : String}
      {==}

def reverse_go_twice(+s: String, +rev: String, +tail: String) -> {String.reverse.go(String.reverse.go(s, rev), tail) == String.reverse.go(rev, s ++ tail) : String}:
  match s:
    case SNil{}: {==}
    case SCon{h, t}: reverse_go_twice(t, SCon{h, rev}, tail)

def reverse_go_inverse(+s: String, +rev: String) -> {String.reverse(String.reverse.go(s, rev)) == String.reverse.go(rev, s) : String}:
  %append_nil(s) : {String.reverse(String.reverse.go(s, rev)) == String.reverse.go(rev, _) : String}
  reverse_go_twice(s, rev, "")

def reverse_twice(+s: String) -> {String.reverse(String.reverse(s)) == s : String}:
  reverse_go_inverse(s, "")
