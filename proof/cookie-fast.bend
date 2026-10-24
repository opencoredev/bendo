import Base
import ../src/data/cookie.bend as C
import ../src/http/bytes.bend as B
import ./bytes-tail.bend as BT

def and_assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a && b) && c == a && (b && c) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def valid_acc(+s: String, +acc: Bool) -> {C.value_valid_go(s, acc) == acc && C.value_valid(s) : Bool}:
  match s:
    case SNil{}:
      match acc:
        case True{}: {==}
        case False{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Bool, C.value_valid_go(t, acc && C.octet(c)), (acc && C.octet(c)) && C.value_valid(t), valid_acc(t, acc && C.octet(c))) : {_ == acc && (C.octet(c) && C.value_valid(t)) : Bool}
      and_assoc(acc, C.octet(c), C.value_valid(t))

def valid_fast(+s: String) -> {C.value_valid_fast(s) == C.value_valid(s) : Bool}:
  valid_acc(s, True{})

def name_acc_inner(+s: String, +acc: Bool) -> {C.name_valid_go(s, acc) == acc && B.token_tail_spec(s) : Bool}:
  match s:
    case SNil{}:
      match acc:
        case True{}: {==}
        case False{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Bool, C.name_valid_go(t, acc && B.tchar(c)), (acc && B.tchar(c)) && B.token_tail_spec(t), name_acc_inner(t, acc && B.tchar(c))) : {_ == acc && (B.tchar(c) && B.token_tail_spec(t)) : Bool}
      and_assoc(acc, B.tchar(c), B.token_tail_spec(t))

def name_acc(+s: String, +acc: Bool) -> {C.name_valid_go(s, acc) == acc && B.token_tail(s) : Bool}:
  Equal.trans(Bool, C.name_valid_go(s, acc), acc && B.token_tail_spec(s), acc && B.token_tail(s), name_acc_inner(s, acc), Equal.cong(Bool, Bool, x => acc && x, B.token_tail_spec(s), B.token_tail(s), Equal.sym(Bool, B.token_tail(s), B.token_tail_spec(s), BT.token_tail_equiv(s))))

def name_fast(+s: String) -> {C.name_valid_fast(s) == C.name_valid(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: name_acc(t, B.tchar(c))

def attribute_group(+ok: Bool, +a: Bool, +b: Bool, +c: Bool, +tail: Bool) -> {((ok && a && b && c) && tail) == ok && (a && b && c && tail) : Bool}:
  match ok:
    case True{}: {==}
    case False{}: {==}

def attribute_acc(+s: String, +ok: Bool) -> {C.attribute_go(s, ok) == ok && C.attribute(s) : Bool}:
  match s:
    case SNil{}:
      match ok:
        case True{}: {==}
        case False{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Bool, C.attribute_go(t, ok && (c >= 32 : U32) && (c <= 126 : U32) && U32.is_ne(c, 59)), (ok && (c >= 32 : U32) && (c <= 126 : U32) && U32.is_ne(c, 59)) && C.attribute(t), attribute_acc(t, ok && (c >= 32 : U32) && (c <= 126 : U32) && U32.is_ne(c, 59))) : {_ == ok && C.attribute(SCon{Chr{c}, t}) : Bool}
      attribute_group(ok, (c >= 32 : U32), (c <= 126 : U32), U32.is_ne(c, 59), C.attribute(t))

def attribute_fast(+s: String) -> {C.attribute_fast(s) == C.attribute(s) : Bool}:
  attribute_acc(s, True{})

def path_char_fast(c: U32, +t: String) -> {C.path_body_fast(SCon{Chr{c}, t}) == C.path_body(SCon{Chr{c}, t}) : Bool}:
  match c:
    case U32{WCon{False{}, _}}: {==}
    case U32{WCon{True{}, WCon{False{}, _}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{False{}, _}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, _}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, _}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, _}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, _}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, _}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, _}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: attribute_fast(t)

def path_body_fast(+s: String) -> {C.path_body_fast(s) == C.path_body(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, +t}: path_char_fast(c, t)

def path_fast(+s: String) -> {C.path_valid_fast(s) == C.path_valid(s) : Bool}:
  Equal.cong(Bool, Bool, x => x && Bool.not(String.ends_with(s, " ")), C.path_body_fast(s), C.path_body(s), path_body_fast(s))

def domain_chars_acc(+s: String, +ok: Bool) -> {C.domain_chars_go(s, ok) == ok && C.domain_chars(s) : Bool}:
  match s:
    case SNil{}:
      match ok:
        case True{}: {==}
        case False{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Bool, C.domain_chars_go(t, ok && (((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || U32.is_eq(c, 45))), (ok && (((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || U32.is_eq(c, 45))) && C.domain_chars(t), domain_chars_acc(t, ok && (((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || U32.is_eq(c, 45)))) : {_ == ok && ((((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || U32.is_eq(c, 45)) && C.domain_chars(t)) : Bool}
      and_assoc(ok, (((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || U32.is_eq(c, 45)), C.domain_chars(t))

def domain_chars_fast(+s: String) -> {C.domain_chars_fast(s) == C.domain_chars(s) : Bool}:
  domain_chars_acc(s, True{})

def add_succ(+a: Nat, +b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n: {==}
    case 1n+p:
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(p, 1n+b), 1n+Nat.add(p, b), add_succ(p, b))

def add_zero(+a: Nat) -> {Nat.add(a, 0n) == a : Nat}:
  match a:
    case 0n: {==}
    case 1n+p:
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(p, 0n), p, add_zero(p))

def length_acc(+s: String, +n: Nat) -> {C.length_go(s, n) == Nat.add(String.length(s), n) : Nat}:
  match s:
    case SNil{}: {==}
    case SCon{h, +t}:
      Equal.trans(Nat, C.length_go(t, 1n+n), Nat.add(String.length(t), 1n+n), 1n+Nat.add(String.length(t), n), length_acc(t, 1n+n), add_succ(String.length(t), n))

def length_fast(+s: String) -> {C.length_fast(s) == String.length(s) : Nat}:
  Equal.trans(Nat, C.length_fast(s), Nat.add(String.length(s), 0n), String.length(s), length_acc(s, 0n), add_zero(String.length(s)))

def label_fast(+s: String) -> {C.label_valid_fast(s) == C.label_valid(s) : Bool}:
  %Equal.sym(Nat, C.length_fast(s), String.length(s), length_fast(s)) : {Bool.not(String.is_empty(s)) && Bool.not(String.starts_with(s, "-")) && Bool.not(String.ends_with(s, "-")) && (_ <= 63n : Nat) && C.domain_chars_fast(s) == C.label_valid(s) : Bool}
  Equal.cong(Bool, Bool, x => Bool.not(String.is_empty(s)) && Bool.not(String.starts_with(s, "-")) && Bool.not(String.ends_with(s, "-")) && (String.length(s) <= 63n : Nat) && x, C.domain_chars_fast(s), C.domain_chars(s), domain_chars_fast(s))

def labels_acc(+xs: List<&2, String>, +ok: Bool) -> {C.labels_valid_go(xs, ok) == ok && C.labels_valid(xs) : Bool}:
  match xs:
    case Nil{}:
      match ok:
        case True{}: {==}
        case False{}: {==}
    case +h <> +t:
      %Equal.sym(Bool, C.label_valid_fast(h), C.label_valid(h), label_fast(h)) : {C.labels_valid_go(t, ok && _) == ok && (C.label_valid(h) && C.labels_valid(t)) : Bool}
      Equal.trans(Bool, C.labels_valid_go(t, ok && C.label_valid(h)), (ok && C.label_valid(h)) && C.labels_valid(t), ok && (C.label_valid(h) && C.labels_valid(t)), labels_acc(t, ok && C.label_valid(h)), and_assoc(ok, C.label_valid(h), C.labels_valid(t)))

def labels_fast(+xs: List<&2, String>) -> {C.labels_valid_fast(xs) == C.labels_valid(xs) : Bool}:
  labels_acc(xs, True{})

def parts_onto(s: String, acc: List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}: acc
    case SCon{+h, t}: String.split.fin(h, parts_onto(t, acc), Char.is_eq(h, '.'))

def parts_reverse(+s: String, +rev: String, +acc: List<&2, String>) -> {C.domain_parts_go(String.reverse.go(s, rev), acc) == C.domain_parts_go(rev, parts_onto(s, acc)) : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{+h, +t}: parts_reverse(t, SCon{h, rev}, acc)

def parts_base(+s: String) -> {parts_onto(s, [""]) == String.split(s, '.') : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{+h, +t}:
      Equal.cong(List<&2, String>, List<&2, String>, xs => String.split.fin(h, xs, Char.is_eq(h, '.')), parts_onto(t, [""]), String.split(t, '.'), parts_base(t))

def parts_fast(+s: String) -> {C.domain_parts(s) == String.split(s, '.') : List<&2, String>}:
  Equal.trans(List<&2, String>, C.domain_parts(s), parts_onto(s, [""]), String.split(s, '.'), parts_reverse(s, "", [""]), parts_base(s))

def domain_fast(+s: String) -> {C.domain_valid_fast(s) == C.domain_valid(s) : Bool}:
  %Equal.sym(Nat, C.length_fast(s), String.length(s), length_fast(s)) : {(_ <= 254n : Nat) && C.labels_valid_fast(C.domain_parts(C.domain_body(s))) == C.domain_valid(s) : Bool}
  %Equal.sym(List<&2, String>, C.domain_parts(C.domain_body(s)), String.split(C.domain_body(s), '.'), parts_fast(C.domain_body(s))) : {(String.length(s) <= 254n : Nat) && C.labels_valid_fast(_) == C.domain_valid(s) : Bool}
  Equal.cong(Bool, Bool, x => (String.length(s) <= 254n : Nat) && x, C.labels_valid_fast(String.split(C.domain_body(s), '.')), C.labels_valid(String.split(C.domain_body(s), '.')), labels_fast(String.split(C.domain_body(s), '.')))

def path_option_fast(+s: Maybe<&2, String>) -> {C.optional_valid(~C.path_valid_fast, s) == C.optional_valid(~C.path_valid, s) : Bool}:
  match s:
    case None{}: {==}
    case Some{+value}: path_fast(value)

def domain_option_fast(+s: Maybe<&2, String>) -> {C.optional_valid(~C.domain_valid_fast, s) == C.optional_valid(~C.domain_valid, s) : Bool}:
  match s:
    case None{}: {==}
    case Some{+value}: domain_fast(value)
