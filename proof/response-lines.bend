# String-search facts for independently validated HTTP lines.
import Base
import ../LAWS.bend as Laws
import ./equality.bend as E
import ./line.bend as Line
import ./scanner.bend as Scanner
import ../src/http/bytes.bend as B
import ../src/http/request.bend as R
import ../src/http/response.bend as Response
import ../src/http/write_response.bend as W
import ./support.bend as Support

def value_not_cr_case(+c: U32, ok: {B.value_octet(c) == True{} : Bool}, same: Bool, eq: {U32.is_eq(c, 13) == same : Bool}) -> {same == False{} : Bool}:
  match same:
    case False{}:
      {==}
    case True{}:
      E.absurd({True{} == False{} : Bool}, E.false_true(
        %Laws.u32_eq_sound(c, 13, eq) : {B.value_octet(_) == True{} : Bool}
        ok))

def value_not_cr(+c: U32, ok: {B.value_octet(c) == True{} : Bool}) -> {Char.is_eq(Chr{c}, '\r') == False{} : Bool}:
  value_not_cr_case(c, ok, U32.is_eq(c, 13), {==})

def clear_scan(+s: String, +tail: String, +needle_tail: String, +ok: {B.value(B.encode(s)) == True{} : Bool}) -> {String.contains(s ++ tail, "\r" ++ needle_tail) == String.contains(tail, "\r" ++ needle_tail) : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      %Equal.sym(Bool, Char.is_eq(Chr{c}, '\r'), False{}, value_not_cr(c, Laws.and_left(B.value_octet(c), B.value(B.encode(t)), ok))) : {String.contains.if(t ++ tail, "\r" ++ needle_tail, String.starts_with.go.if(needle_tail, t ++ tail, _)) == String.contains(tail, "\r" ++ needle_tail) : Bool}
      clear_scan(t, tail, needle_tail, Laws.and_right(B.value_octet(c), B.value(B.encode(t)), ok))

def encode_ascii(+xs: List<&2, U32>) -> {B.encode(B.ascii(xs)) == xs : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case c <> t:
      %encode_ascii(t) : {c <> B.encode(B.ascii(t)) == c <> _ : List<&2, U32>}
      {==}

def encode_append(+a: String, +b: String) -> {B.encode(a ++ b) == B.append(B.encode(a), B.encode(b)) : List<&2, U32>}:
  match a:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      %encode_append(t, b) : {c <> B.encode(t ++ b) == c <> _ : List<&2, U32>}
      {==}

def ascii_append(+a: List<&2, U32>, +b: List<&2, U32>) -> {B.ascii(B.append(a, b)) == B.ascii(a) ++ B.ascii(b) : String}:
  match a:
    case Nil{}:
      {==}
    case c <> t:
      %ascii_append(t, b) : {SCon{Chr{c}, B.ascii(B.append(t, b))} == SCon{Chr{c}, _} : String}
      {==}

def header_encode(+h: R.Header) -> {B.encode(W.header_text(h)) == Support.header_content(h) : List<&2, U32>}:
  match h:
    case R.Header{n, v}:
      Equal.trans(List<&2, U32>, B.encode(W.header_text(R.Header{n, v})), B.append(B.encode(n), 58 <> 32 <> B.encode(B.ascii(v))), Support.header_content(R.Header{n, v}), encode_append(n, ": " ++ B.ascii(v)), Equal.cong(List<&2, U32>, List<&2, U32>, xs => B.append(B.encode(n), 58 <> 32 <> xs), B.encode(B.ascii(v)), v, encode_ascii(v)))

def header_clear(+h: R.Header, ok: {B.value(Support.header_content(h)) == True{} : Bool}) -> {B.value(B.encode(W.header_text(h))) == True{} : Bool}:
  %Equal.sym(List<&2, U32>, B.encode(W.header_text(h)), Support.header_content(h), header_encode(h)) : {B.value(_) == True{} : Bool}
  ok

def header_not_blank(+h: R.Header, +tail: String, ok: {B.value(B.encode(W.header_text(h))) == True{} : Bool}) -> {String.starts_with("\r\n" ++ W.header_text(h) ++ tail, "\r\n\r\n") == False{} : Bool}:
  match h:
    case R.Header{SNil{}, v}:
      {==}
    case R.Header{SCon{Chr{c}, n}, v}:
      %Equal.sym(Bool, Char.is_eq(Chr{c}, '\r'), False{}, value_not_cr(c, Laws.and_left(B.value_octet(c), B.value(B.encode(n ++ ": " ++ B.ascii(v))), ok))) : {String.starts_with.go.if("\n", (n ++ ": " ++ B.ascii(v)) ++ tail, _) == False{} : Bool}
      {==}

def header_blank_step(+h: R.Header, +tail: String, +ok: {B.value(B.encode(W.header_text(h))) == True{} : Bool}, absent: {String.contains(tail, "\r\n\r\n") == False{} : Bool}) -> {String.contains("\r\n" ++ W.header_text(h) ++ tail, "\r\n\r\n") == False{} : Bool}:
  %Equal.sym(Bool, String.starts_with("\r\n" ++ W.header_text(h) ++ tail, "\r\n\r\n"), False{}, header_not_blank(h, tail, ok)) : {String.contains.if("\n" ++ W.header_text(h) ++ tail, "\r\n\r\n", _) == False{} : Bool}
  Equal.trans(Bool, String.contains(W.header_text(h) ++ tail, "\r\n\r\n"), String.contains(tail, "\r\n\r\n"), False{}, clear_scan(W.header_text(h), tail, "\n\r\n", ok), absent)

def headers_blank(+hs: List<&2, R.Header>, +ok: {Support.headers_scannable(hs) == True{} : Bool}) -> {String.contains(W.headers_text(hs), "\r\n\r\n") == False{} : Bool}:
  match hs:
    case Nil{}:
      {==}
    case h <> t:
      header_blank_step(h, W.headers_text(t), header_clear(h, Laws.and_left(B.value(Support.header_content(h)), Support.headers_scannable(t), ok)), headers_blank(t, Laws.and_right(B.value(Support.header_content(h)), Support.headers_scannable(t), ok)))

def string_value_append(+a: String, +b: String, left: {B.value(B.encode(a)) == True{} : Bool}, right: {B.value(B.encode(b)) == True{} : Bool}) -> {B.value(B.encode(a ++ b)) == True{} : Bool}:
  %Equal.sym(List<&2, U32>, B.encode(a ++ b), B.append(B.encode(a), B.encode(b)), encode_append(a, b)) : {B.value(_) == True{} : Bool}
  Laws.value_append(B.encode(a), B.encode(b), left, right)

def char_self(+c: U32) -> {Char.is_eq(Chr{c}, Chr{c}) == True{} : Bool}:
  match c:
    case U32{bits}:
      %Laws.word_cmp_self(32n, bits) : {Cmp.is_eq(Word.cmp(32n, bits, bits)) == Cmp.is_eq(_) : Bool}
      {==}

def starts_common(+a: String, +s: String, +p: String, yes: {String.starts_with(s, p) == True{} : Bool}) -> {String.starts_with(a ++ s, a ++ p) == True{} : Bool}:
  match a:
    case SNil{}:
      yes
    case SCon{Chr{c}, t}:
      %Equal.sym(Bool, Char.is_eq(Chr{c}, Chr{c}), True{}, char_self(c)) : {String.starts_with.go.if(t ++ p, t ++ s, _) == True{} : Bool}
      starts_common(t, s, p, yes)

def contains_from_starts(+s: String, +p: String, yes: {String.starts_with(s, p) == True{} : Bool}) -> {String.contains(s, p) == True{} : Bool}:
  match s p:
    case SNil{} SNil{}:
      {==}
    case SNil{} SCon{c, t}:
      yes
    case SCon{c, t} _:
      %Equal.sym(Bool, String.starts_with(SCon{c, t}, p), True{}, yes) : {String.contains.if(t, p, _) == True{} : Bool}
      {==}

def contains_if_true(+t: String, +p: String, here: Bool, yes: {String.contains(t, p) == True{} : Bool}) -> {String.contains.if(t, p, here) == True{} : Bool}:
  match here:
    case False{}:
      yes
    case True{}:
      {==}

def contains_prepend(+a: String, +s: String, +p: String, yes: {String.contains(s, p) == True{} : Bool}) -> {String.contains(a ++ s, p) == True{} : Bool}:
  match a:
    case SNil{}:
      yes
    case SCon{c, t}:
      contains_if_true(t ++ s, p, String.starts_with(SCon{c, t ++ s}, p), contains_prepend(t, s, p, yes))

def headers_end_crlf(+hs: List<&2, R.Header>) -> {String.starts_with(W.headers_text(hs) ++ "\r\n", "\r\n") == True{} : Bool}:
  match hs:
    case Nil{}:
      {==}
    case h <> t:
      {==}

def length_present(+n: Nat, +hs: List<&2, R.Header>) -> {String.contains(W.headers_text(W.length_header(n) <> hs) ++ "\r\n", "\r\ncontent-length: " ++ Nat.show(n) ++ "\r\n") == True{} : Bool}:
  %Equal.sym(String, B.ascii(B.encode(Nat.show(n))), Nat.show(n), Line.ascii_encode(Nat.show(n))) : {String.contains(("\r\ncontent-length: " ++ (_ ++ W.headers_text(hs))) ++ "\r\n", "\r\ncontent-length: " ++ Nat.show(n) ++ "\r\n") == True{} : Bool}
  %Equal.sym(String, ("\r\ncontent-length: " ++ (Nat.show(n) ++ W.headers_text(hs))) ++ "\r\n", "\r\ncontent-length: " ++ ((Nat.show(n) ++ W.headers_text(hs)) ++ "\r\n"), Line.string_assoc("\r\ncontent-length: ", Nat.show(n) ++ W.headers_text(hs), "\r\n")) : {String.contains(_, "\r\ncontent-length: " ++ Nat.show(n) ++ "\r\n") == True{} : Bool}
  %Equal.sym(String, (Nat.show(n) ++ W.headers_text(hs)) ++ "\r\n", Nat.show(n) ++ (W.headers_text(hs) ++ "\r\n"), Line.string_assoc(Nat.show(n), W.headers_text(hs), "\r\n")) : {String.contains("\r\ncontent-length: " ++ _, "\r\ncontent-length: " ++ Nat.show(n) ++ "\r\n") == True{} : Bool}
  contains_from_starts("\r\ncontent-length: " ++ (Nat.show(n) ++ (W.headers_text(hs) ++ "\r\n")), "\r\ncontent-length: " ++ Nat.show(n) ++ "\r\n", starts_common("\r\ncontent-length: ", Nat.show(n) ++ (W.headers_text(hs) ++ "\r\n"), Nat.show(n) ++ "\r\n", starts_common(Nat.show(n), W.headers_text(hs) ++ "\r\n", "\r\n", headers_end_crlf(hs))))

def ascii_prefix_suffix(+method: R.Method, +r: Response.Res) -> {B.ascii(B.append(W.prefix(method, r), [13, 10])) == W.prefix_text(method, r) ++ "\r\n" : String}:
  Equal.trans(String, B.ascii(B.append(W.prefix(method, r), [13, 10])), B.ascii(W.prefix(method, r)) ++ "\r\n", W.prefix_text(method, r) ++ "\r\n", ascii_append(W.prefix(method, r), [13, 10]), Equal.cong(String, String, s => s ++ "\r\n", B.ascii(W.prefix(method, r)), W.prefix_text(method, r), Line.ascii_encode(W.prefix_text(method, r))))
