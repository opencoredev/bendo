# BND-84 review: right folds implemented as tail loops over reversed inputs.
import Base
import ../src/http/write.bend as W
import ./review-tail-laws.bend as Laws
import ../src/crypto/jwt.bend as J
import ../src/mw/method_override.bend as M
import ../src/data/multipart.bend as Multipart
import ../src/data/utf8.bend as Utf8
import ../src/http/proxy_headers.bend as H
import ../src/http/upstream.bend as U
import ../src/http/request.bend as R
import ../src/http/bytes.bend as Bytes
import ../src/http/text.bend as T
import ./conn-tail.bend as CT
import ./text.bend as TP
import ./misc-tail.bend as MT

def j_nonzero_onto(xs: String, acc: Bool) -> Bool:
  match xs:
    case SNil{}: acc
    case SCon{+c, t}: Bool.not(Char.is_eq(c, '0')) || j_nonzero_onto(t, acc)

def j_nonzero_base(+xs: String) -> {j_nonzero_onto(xs, False{}) == J.nonzero_spec(xs) : Bool}:
  match xs:
    case SNil{}: {==}
    case SCon{+c, t}: Equal.cong(Bool, Bool, acc => Bool.not(Char.is_eq(c, '0')) || acc, j_nonzero_onto(t, False{}), J.nonzero_spec(t), j_nonzero_base(t))

def j_nonzero_reverse(+xs: String, +r: String, +acc: Bool) -> {J.nonzero_go(String.reverse.go(xs, r), acc) == J.nonzero_go(r, j_nonzero_onto(xs, acc)) : Bool}:
  match xs:
    case SNil{}: {==}
    case SCon{+c, t}: j_nonzero_reverse(t, SCon{c, r}, acc)

def j_nonzero_equiv(+xs: String) -> {J.nonzero(xs) == J.nonzero_spec(xs) : Bool}:
  Equal.trans(Bool, J.nonzero(xs), j_nonzero_onto(xs, False{}), J.nonzero_spec(xs), j_nonzero_reverse(xs, "", False{}), j_nonzero_base(xs))

def Laws.review_j_nonzero(xs): j_nonzero_equiv(xs)

def m_texts_onto(xs: List<&2, List<&2, U32>>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: acc
    case x <> t: M.text(Utf8.decode(x)) <> m_texts_onto(t, acc)

def m_texts_base(+xs: List<&2, List<&2, U32>>) -> {m_texts_onto(xs, []) == M.texts_spec(xs) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case x <> t: Equal.cong(List<&2, String>, List<&2, String>, acc => M.text(Utf8.decode(x)) <> acc, m_texts_onto(t, []), M.texts_spec(t), m_texts_base(t))

def m_texts_reverse(+xs: List<&2, List<&2, U32>>, +r: List<&2, List<&2, U32>>, +acc: List<&2, String>) -> {M.texts_go(List.reverse.go(&2, List<&2, U32>, xs, r), acc) == M.texts_go(r, m_texts_onto(xs, acc)) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case x <> t: m_texts_reverse(t, x <> r, acc)

def m_texts_equiv(+xs: List<&2, List<&2, U32>>) -> {M.texts(xs) == M.texts_spec(xs) : List<&2, String>}:
  Equal.trans(List<&2, String>, M.texts(xs), m_texts_onto(xs, []), M.texts_spec(xs), m_texts_reverse(xs, [], []), m_texts_base(xs))

def Laws.review_m_texts(xs): m_texts_equiv(xs)

def m_field_values_onto(xs: List<&2, Multipart.Part>, +name: String, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: acc
    case Multipart.Field{+k, v} <> t: M.pick(v, m_field_values_onto(t, name, acc), String.eq(k, name))
    case Multipart.File{+k, f, ct, b} <> t: M.pick("?", m_field_values_onto(t, name, acc), String.eq(k, name))

def m_field_values_base(+xs: List<&2, Multipart.Part>, +name: String) -> {m_field_values_onto(xs, name, []) == M.field_values_spec(xs, name) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case Multipart.Field{+k, v} <> t: Equal.cong(List<&2, String>, List<&2, String>, acc => M.pick(v, acc, String.eq(k, name)), m_field_values_onto(t, name, []), M.field_values_spec(t, name), m_field_values_base(t, name))
    case Multipart.File{+k, f, ct, b} <> t: Equal.cong(List<&2, String>, List<&2, String>, acc => M.pick("?", acc, String.eq(k, name)), m_field_values_onto(t, name, []), M.field_values_spec(t, name), m_field_values_base(t, name))

def m_field_values_reverse(+xs: List<&2, Multipart.Part>, +r: List<&2, Multipart.Part>, +name: String, +acc: List<&2, String>) -> {M.field_values_go(List.reverse.go(&2, Multipart.Part, xs, r), name, acc) == M.field_values_go(r, name, m_field_values_onto(xs, name, acc)) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case Multipart.Field{+k, v} <> t: m_field_values_reverse(t, Multipart.Field{k, v} <> r, name, acc)
    case Multipart.File{+k, f, ct, b} <> t: m_field_values_reverse(t, Multipart.File{k, f, ct, b} <> r, name, acc)

def m_field_values_equiv(+xs: List<&2, Multipart.Part>, +name: String) -> {M.field_values(xs, name) == M.field_values_spec(xs, name) : List<&2, String>}:
  Equal.trans(List<&2, String>, M.field_values(xs, name), m_field_values_onto(xs, name, []), M.field_values_spec(xs, name), m_field_values_reverse(xs, [], name, []), m_field_values_base(xs, name))

def Laws.review_m_field_values(xs, name): m_field_values_equiv(xs, name)

def h_named_onto(xs: List<&2, String>, +name: String, acc: Bool) -> Bool:
  match xs:
    case Nil{}: acc
    case n <> t: String.eq(name, n) || h_named_onto(t, name, acc)

def h_named_base(+xs: List<&2, String>, +name: String) -> {h_named_onto(xs, name, False{}) == H.named_spec(name, xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case n <> t: Equal.cong(Bool, Bool, acc => String.eq(name, n) || acc, h_named_onto(t, name, False{}), H.named_spec(name, t), h_named_base(t, name))

def h_named_reverse(+xs: List<&2, String>, +r: List<&2, String>, +name: String, +acc: Bool) -> {H.named_go(List.reverse.go(&2, String, xs, r), name, acc) == H.named_go(r, name, h_named_onto(xs, name, acc)) : Bool}:
  match xs:
    case Nil{}: {==}
    case n <> t: h_named_reverse(t, n <> r, name, acc)

def h_named_equiv(+xs: List<&2, String>, +name: String) -> {H.named(name, xs) == H.named_spec(name, xs) : Bool}:
  Equal.trans(Bool, H.named(name, xs), h_named_onto(xs, name, False{}), H.named_spec(name, xs), h_named_reverse(xs, [], name, False{}), h_named_base(xs, name))

def Laws.review_h_named(xs, name): h_named_equiv(xs, name)

def u_named_onto(xs: List<&2, String>, +name: String, acc: Bool) -> Bool:
  match xs:
    case Nil{}: acc
    case n <> t: String.eq(name, n) || u_named_onto(t, name, acc)

def u_named_base(+xs: List<&2, String>, +name: String) -> {u_named_onto(xs, name, False{}) == U.named_spec(name, xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case n <> t: Equal.cong(Bool, Bool, acc => String.eq(name, n) || acc, u_named_onto(t, name, False{}), U.named_spec(name, t), u_named_base(t, name))

def u_named_reverse(+xs: List<&2, String>, +r: List<&2, String>, +name: String, +acc: Bool) -> {U.named_go(List.reverse.go(&2, String, xs, r), name, acc) == U.named_go(r, name, u_named_onto(xs, name, acc)) : Bool}:
  match xs:
    case Nil{}: {==}
    case n <> t: u_named_reverse(t, n <> r, name, acc)

def u_named_equiv(+xs: List<&2, String>, +name: String) -> {U.named(name, xs) == U.named_spec(name, xs) : Bool}:
  Equal.trans(Bool, U.named(name, xs), u_named_onto(xs, name, False{}), U.named_spec(name, xs), u_named_reverse(xs, [], name, False{}), u_named_base(xs, name))

def Laws.review_u_named(xs, name): u_named_equiv(xs, name)

def h_strip_trail_onto(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: acc
    case +c <> t: H.trail_pick(c, H.blank(c), h_strip_trail_onto(t, acc))

def h_strip_trail_base(+xs: List<&2, U32>) -> {h_strip_trail_onto(xs, []) == H.strip_trail_spec(xs) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +c <> t: Equal.cong(List<&2, U32>, List<&2, U32>, acc => H.trail_pick(c, H.blank(c), acc), h_strip_trail_onto(t, []), H.strip_trail_spec(t), h_strip_trail_base(t))

def h_strip_trail_reverse(+xs: List<&2, U32>, +r: List<&2, U32>, +acc: List<&2, U32>) -> {H.strip_trail_go(List.reverse.go(&2, U32, xs, r), acc) == H.strip_trail_go(r, h_strip_trail_onto(xs, acc)) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +c <> t: h_strip_trail_reverse(t, c <> r, acc)

def h_strip_trail_equiv(+xs: List<&2, U32>) -> {H.strip_trail(xs) == H.strip_trail_spec(xs) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, H.strip_trail(xs), h_strip_trail_onto(xs, []), H.strip_trail_spec(xs), h_strip_trail_reverse(xs, [], []), h_strip_trail_base(xs))

def Laws.review_h_strip_trail(xs): h_strip_trail_equiv(xs)

def h_commas_onto(xs: List<&2, U32>, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}: acc
    case +c <> t: H.comma_pick(c, h_commas_onto(t, acc), U32.is_eq(c, 44))

def h_commas_base(+xs: List<&2, U32>) -> {h_commas_onto(xs, [[]]) == H.commas_spec(xs) : List<&2, List<&2, U32>>}:
  match xs:
    case Nil{}: {==}
    case +c <> t: Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, acc => H.comma_pick(c, acc, U32.is_eq(c, 44)), h_commas_onto(t, [[]]), H.commas_spec(t), h_commas_base(t))

def h_commas_reverse(+xs: List<&2, U32>, +r: List<&2, U32>, +acc: List<&2, List<&2, U32>>) -> {H.commas_go(List.reverse.go(&2, U32, xs, r), acc) == H.commas_go(r, h_commas_onto(xs, acc)) : List<&2, List<&2, U32>>}:
  match xs:
    case Nil{}: {==}
    case +c <> t: h_commas_reverse(t, c <> r, acc)

def h_commas_equiv(+xs: List<&2, U32>) -> {H.commas(xs) == H.commas_spec(xs) : List<&2, List<&2, U32>>}:
  Equal.trans(List<&2, List<&2, U32>>, H.commas(xs), h_commas_onto(xs, [[]]), H.commas_spec(xs), h_commas_reverse(xs, [], [[]]), h_commas_base(xs))

def Laws.review_h_commas(xs): h_commas_equiv(xs)

def h_token_names_onto(xs: List<&2, List<&2, U32>>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: acc
    case +p <> t: H.name_pick(Bytes.fold(Bytes.ascii(H.strip_trail(H.strip_lead(p)))), h_token_names_onto(t, acc), String.is_empty(Bytes.fold(Bytes.ascii(H.strip_trail(H.strip_lead(p))))))

def h_token_names_base(+xs: List<&2, List<&2, U32>>) -> {h_token_names_onto(xs, []) == H.token_names_spec(xs) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case +p <> t: Equal.cong(List<&2, String>, List<&2, String>, acc => H.name_pick(Bytes.fold(Bytes.ascii(H.strip_trail(H.strip_lead(p)))), acc, String.is_empty(Bytes.fold(Bytes.ascii(H.strip_trail(H.strip_lead(p)))))), h_token_names_onto(t, []), H.token_names_spec(t), h_token_names_base(t))

def h_token_names_reverse(+xs: List<&2, List<&2, U32>>, +r: List<&2, List<&2, U32>>, +acc: List<&2, String>) -> {H.token_names_go(List.reverse.go(&2, List<&2, U32>, xs, r), acc) == H.token_names_go(r, h_token_names_onto(xs, acc)) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case +p <> t: h_token_names_reverse(t, p <> r, acc)

def h_token_names_equiv(+xs: List<&2, List<&2, U32>>) -> {H.token_names(xs) == H.token_names_spec(xs) : List<&2, String>}:
  Equal.trans(List<&2, String>, H.token_names(xs), h_token_names_onto(xs, []), H.token_names_spec(xs), h_token_names_reverse(xs, [], []), h_token_names_base(xs))

def Laws.review_h_token_names(xs): h_token_names_equiv(xs)

def h_listed_onto(xs: List<&2, R.Header>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: acc
    case R.Header{+name, value} <> t: H.listed_pick(value, h_listed_onto(t, acc), String.eq(Bytes.fold(name), "connection"))

def h_listed_base(+xs: List<&2, R.Header>) -> {h_listed_onto(xs, []) == H.listed_spec(xs) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case R.Header{+name, value} <> t: Equal.cong(List<&2, String>, List<&2, String>, acc => H.listed_pick(value, acc, String.eq(Bytes.fold(name), "connection")), h_listed_onto(t, []), H.listed_spec(t), h_listed_base(t))

def h_listed_reverse(+xs: List<&2, R.Header>, +r: List<&2, R.Header>, +acc: List<&2, String>) -> {H.listed_go(List.reverse.go(&2, R.Header, xs, r), acc) == H.listed_go(r, h_listed_onto(xs, acc)) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case R.Header{+name, value} <> t: h_listed_reverse(t, R.Header{name, value} <> r, acc)

def h_listed_equiv(+xs: List<&2, R.Header>) -> {H.listed(xs) == H.listed_spec(xs) : List<&2, String>}:
  Equal.trans(List<&2, String>, H.listed(xs), h_listed_onto(xs, []), H.listed_spec(xs), h_listed_reverse(xs, [], []), h_listed_base(xs))

def Laws.review_h_listed(xs): h_listed_equiv(xs)

def h_keep_all_onto(xs: List<&2, R.Header>, +tokens: List<&2, String>, acc: List<&2, R.Header>) -> List<&2, R.Header>:
  match xs:
    case Nil{}: acc
    case +h <> t: H.keep_pick(h, h_keep_all_onto(t, tokens, acc), H.keep(tokens, h))

def h_keep_all_base(+xs: List<&2, R.Header>, +tokens: List<&2, String>) -> {h_keep_all_onto(xs, tokens, []) == H.keep_all_spec(tokens, xs) : List<&2, R.Header>}:
  match xs:
    case Nil{}: {==}
    case +h <> t: Equal.cong(List<&2, R.Header>, List<&2, R.Header>, acc => H.keep_pick(h, acc, H.keep(tokens, h)), h_keep_all_onto(t, tokens, []), H.keep_all_spec(tokens, t), h_keep_all_base(t, tokens))

def h_keep_all_reverse(+xs: List<&2, R.Header>, +r: List<&2, R.Header>, +tokens: List<&2, String>, +acc: List<&2, R.Header>) -> {H.keep_all_go(List.reverse.go(&2, R.Header, xs, r), tokens, acc) == H.keep_all_go(r, tokens, h_keep_all_onto(xs, tokens, acc)) : List<&2, R.Header>}:
  match xs:
    case Nil{}: {==}
    case +h <> t: h_keep_all_reverse(t, h <> r, tokens, acc)

def h_keep_all_equiv(+xs: List<&2, R.Header>, +tokens: List<&2, String>) -> {H.keep_all(tokens, xs) == H.keep_all_spec(tokens, xs) : List<&2, R.Header>}:
  Equal.trans(List<&2, R.Header>, H.keep_all(tokens, xs), h_keep_all_onto(xs, tokens, []), H.keep_all_spec(tokens, xs), h_keep_all_reverse(xs, [], tokens, []), h_keep_all_base(xs, tokens))

def Laws.review_h_keep_all(xs, tokens): h_keep_all_equiv(xs, tokens)

def u_without_onto(xs: List<&2, R.Header>, +names: List<&2, String>, acc: List<&2, R.Header>) -> List<&2, R.Header>:
  match xs:
    case Nil{}: acc
    case R.Header{+n, v} <> t: U.keep_pick(R.Header{n, v}, u_without_onto(t, names, acc), Bool.not(U.named(Bytes.fold(n), names)))

def u_without_base(+xs: List<&2, R.Header>, +names: List<&2, String>) -> {u_without_onto(xs, names, []) == U.without_spec(names, xs) : List<&2, R.Header>}:
  match xs:
    case Nil{}: {==}
    case R.Header{+n, v} <> t: Equal.cong(List<&2, R.Header>, List<&2, R.Header>, acc => U.keep_pick(R.Header{n, v}, acc, Bool.not(U.named(Bytes.fold(n), names))), u_without_onto(t, names, []), U.without_spec(names, t), u_without_base(t, names))

def u_without_reverse(+xs: List<&2, R.Header>, +r: List<&2, R.Header>, +names: List<&2, String>, +acc: List<&2, R.Header>) -> {U.without_go(List.reverse.go(&2, R.Header, xs, r), names, acc) == U.without_go(r, names, u_without_onto(xs, names, acc)) : List<&2, R.Header>}:
  match xs:
    case Nil{}: {==}
    case R.Header{+n, v} <> t: u_without_reverse(t, R.Header{n, v} <> r, names, acc)

def u_without_equiv(+xs: List<&2, R.Header>, +names: List<&2, String>) -> {U.without(names, xs) == U.without_spec(names, xs) : List<&2, R.Header>}:
  Equal.trans(List<&2, R.Header>, U.without(names, xs), u_without_onto(xs, names, []), U.without_spec(names, xs), u_without_reverse(xs, [], names, []), u_without_base(xs, names))

def Laws.review_u_without(xs, names): u_without_equiv(xs, names)

def u_ascii_values_onto(xs: List<&2, List<&2, U32>>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: acc
    case v <> t: Bytes.ascii(v) <> u_ascii_values_onto(t, acc)

def u_ascii_values_base(+xs: List<&2, List<&2, U32>>) -> {u_ascii_values_onto(xs, []) == U.ascii_values_spec(xs) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case v <> t: Equal.cong(List<&2, String>, List<&2, String>, acc => Bytes.ascii(v) <> acc, u_ascii_values_onto(t, []), U.ascii_values_spec(t), u_ascii_values_base(t))

def u_ascii_values_reverse(+xs: List<&2, List<&2, U32>>, +r: List<&2, List<&2, U32>>, +acc: List<&2, String>) -> {U.ascii_values_go(List.reverse.go(&2, List<&2, U32>, xs, r), acc) == U.ascii_values_go(r, u_ascii_values_onto(xs, acc)) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case v <> t: u_ascii_values_reverse(t, v <> r, acc)

def u_ascii_values_equiv(+xs: List<&2, List<&2, U32>>) -> {U.ascii_values(xs) == U.ascii_values_spec(xs) : List<&2, String>}:
  Equal.trans(List<&2, String>, U.ascii_values(xs), u_ascii_values_onto(xs, []), U.ascii_values_spec(xs), u_ascii_values_reverse(xs, [], []), u_ascii_values_base(xs))

def Laws.review_u_ascii_values(xs): u_ascii_values_equiv(xs)

def u_quote_chars_onto(xs: String, acc: String) -> String:
  match xs:
    case SNil{}: acc
    case SCon{c, t}: U.quote_step(c, u_quote_chars_onto(t, acc))

def quote_spec_step(+c: Char, +t: String) -> {U.quote_step(c, U.quote_chars_spec(t)) == U.quote_chars_spec(SCon{c, t}) : String}:
  match c:
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{False{}, bits}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, bits}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, bits}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, bits}}}}}}}}}: {==}
    case Chr{92}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, bits}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, bits}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, bits}}}}}}}}: {==}
    case Chr{34}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, bits}}}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, bits}}}}}}: {==}
    case Chr{U32{WCon{False{}, WCon{True{}, WCon{True{}, bits}}}}}: {==}
    case Chr{U32{WCon{True{}, bits}}}: {==}

def u_quote_chars_base(+xs: String) -> {u_quote_chars_onto(xs, "") == U.quote_chars_spec(xs) : String}:
  match xs:
    case SNil{}: {==}
    case SCon{+c, +t}:
      Equal.trans(String, U.quote_step(c, u_quote_chars_onto(t, "")), U.quote_step(c, U.quote_chars_spec(t)), U.quote_chars_spec(SCon{c, t}), Equal.cong(String, String, acc => U.quote_step(c, acc), u_quote_chars_onto(t, ""), U.quote_chars_spec(t), u_quote_chars_base(t)), quote_spec_step(c, t))

def u_quote_chars_reverse(+xs: String, +r: String, +acc: String) -> {U.quote_chars_go(String.reverse.go(xs, r), acc) == U.quote_chars_go(r, u_quote_chars_onto(xs, acc)) : String}:
  match xs:
    case SNil{}: {==}
    case SCon{c, t}: u_quote_chars_reverse(t, SCon{c, r}, acc)

def u_quote_chars_equiv(+xs: String) -> {U.quote_chars(xs) == U.quote_chars_spec(xs) : String}:
  Equal.trans(String, U.quote_chars(xs), u_quote_chars_onto(xs, ""), U.quote_chars_spec(xs), u_quote_chars_reverse(xs, "", ""), u_quote_chars_base(xs))

def Laws.review_u_quote_chars(xs): u_quote_chars_equiv(xs)

def u_sane_all_onto(xs: List<&2, R.Header>, acc: List<&2, R.Header>) -> List<&2, R.Header>:
  match xs:
    case Nil{}: acc
    case +h <> t: U.keep_pick(h, u_sane_all_onto(t, acc), U.sane(h))

def u_sane_all_base(+xs: List<&2, R.Header>) -> {u_sane_all_onto(xs, []) == U.sane_all_spec(xs) : List<&2, R.Header>}:
  match xs:
    case Nil{}: {==}
    case +h <> t: Equal.cong(List<&2, R.Header>, List<&2, R.Header>, acc => U.keep_pick(h, acc, U.sane(h)), u_sane_all_onto(t, []), U.sane_all_spec(t), u_sane_all_base(t))

def u_sane_all_reverse(+xs: List<&2, R.Header>, +r: List<&2, R.Header>, +acc: List<&2, R.Header>) -> {U.sane_all_go(List.reverse.go(&2, R.Header, xs, r), acc) == U.sane_all_go(r, u_sane_all_onto(xs, acc)) : List<&2, R.Header>}:
  match xs:
    case Nil{}: {==}
    case +h <> t: u_sane_all_reverse(t, h <> r, acc)

def u_sane_all_equiv(+xs: List<&2, R.Header>) -> {U.sane_all(xs) == U.sane_all_spec(xs) : List<&2, R.Header>}:
  Equal.trans(List<&2, R.Header>, U.sane_all(xs), u_sane_all_onto(xs, []), U.sane_all_spec(xs), u_sane_all_reverse(xs, [], []), u_sane_all_base(xs))

def Laws.review_u_sane_all(xs): u_sane_all_equiv(xs)

def u_lengths_onto(xs: List<&2, List<&2, U32>>, acc: List<&2, Maybe<&2, U32>>) -> List<&2, Maybe<&2, U32>>:
  match xs:
    case Nil{}: acc
    case +p <> t: U.list_digits(Bytes.trim(p)) <> u_lengths_onto(t, acc)

def u_lengths_base(+xs: List<&2, List<&2, U32>>) -> {u_lengths_onto(xs, []) == U.lengths_spec(xs) : List<&2, Maybe<&2, U32>>}:
  match xs:
    case Nil{}: {==}
    case +p <> t: Equal.cong(List<&2, Maybe<&2, U32>>, List<&2, Maybe<&2, U32>>, acc => U.list_digits(Bytes.trim(p)) <> acc, u_lengths_onto(t, []), U.lengths_spec(t), u_lengths_base(t))

def u_lengths_reverse(+xs: List<&2, List<&2, U32>>, +r: List<&2, List<&2, U32>>, +acc: List<&2, Maybe<&2, U32>>) -> {U.lengths_go(List.reverse.go(&2, List<&2, U32>, xs, r), acc) == U.lengths_go(r, u_lengths_onto(xs, acc)) : List<&2, Maybe<&2, U32>>}:
  match xs:
    case Nil{}: {==}
    case +p <> t: u_lengths_reverse(t, p <> r, acc)

def u_lengths_equiv(+xs: List<&2, List<&2, U32>>) -> {U.lengths(xs) == U.lengths_spec(xs) : List<&2, Maybe<&2, U32>>}:
  Equal.trans(List<&2, Maybe<&2, U32>>, U.lengths(xs), u_lengths_onto(xs, []), U.lengths_spec(xs), u_lengths_reverse(xs, [], []), u_lengths_base(xs))

def Laws.review_u_lengths(xs): u_lengths_equiv(xs)

def u_same_length_onto(xs: List<&2, Maybe<&2, U32>>, +n: U32, acc: Bool) -> Bool:
  match xs:
    case Nil{}: acc
    case None{} <> t: False{}
    case Some{m} <> t: U32.is_eq(n, m) && u_same_length_onto(t, n, acc)

def u_same_length_base(+xs: List<&2, Maybe<&2, U32>>, +n: U32) -> {u_same_length_onto(xs, n, True{}) == U.same_length_spec(n, xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case None{} <> t: Equal.cong(Bool, Bool, acc => False{}, u_same_length_onto(t, n, True{}), U.same_length_spec(n, t), u_same_length_base(t, n))
    case Some{m} <> t: Equal.cong(Bool, Bool, acc => U32.is_eq(n, m) && acc, u_same_length_onto(t, n, True{}), U.same_length_spec(n, t), u_same_length_base(t, n))

def u_same_length_reverse(+xs: List<&2, Maybe<&2, U32>>, +r: List<&2, Maybe<&2, U32>>, +n: U32, +acc: Bool) -> {U.same_length_go(List.reverse.go(&2, Maybe<&2, U32>, xs, r), n, acc) == U.same_length_go(r, n, u_same_length_onto(xs, n, acc)) : Bool}:
  match xs:
    case Nil{}: {==}
    case None{} <> t: u_same_length_reverse(t, None{} <> r, n, acc)
    case Some{m} <> t: u_same_length_reverse(t, Some{m} <> r, n, acc)

def u_same_length_equiv(+xs: List<&2, Maybe<&2, U32>>, +n: U32) -> {U.same_length(n, xs) == U.same_length_spec(n, xs) : Bool}:
  Equal.trans(Bool, U.same_length(n, xs), u_same_length_onto(xs, n, True{}), U.same_length_spec(n, xs), u_same_length_reverse(xs, [], n, True{}), u_same_length_base(xs, n))

def Laws.review_u_same_length(xs, n): u_same_length_equiv(xs, n)

def u_all_values_onto(xs: List<&2, List<&2, U32>>, acc: List<&2, Maybe<&2, U32>>) -> List<&2, Maybe<&2, U32>>:
  match xs:
    case Nil{}: acc
    case v <> t: List.append(&2, Maybe<&2, U32>, U.lengths(H.commas(v)), u_all_values_onto(t, acc))

def u_all_values_base(+xs: List<&2, List<&2, U32>>) -> {u_all_values_onto(xs, []) == U.all_values_spec(xs) : List<&2, Maybe<&2, U32>>}:
  match xs:
    case Nil{}: {==}
    case v <> t: Equal.cong(List<&2, Maybe<&2, U32>>, List<&2, Maybe<&2, U32>>, acc => List.append(&2, Maybe<&2, U32>, U.lengths(H.commas(v)), acc), u_all_values_onto(t, []), U.all_values_spec(t), u_all_values_base(t))

def u_all_values_reverse(+xs: List<&2, List<&2, U32>>, +r: List<&2, List<&2, U32>>, +acc: List<&2, Maybe<&2, U32>>) -> {U.all_values_go(List.reverse.go(&2, List<&2, U32>, xs, r), acc) == U.all_values_go(r, u_all_values_onto(xs, acc)) : List<&2, Maybe<&2, U32>>}:
  match xs:
    case Nil{}: {==}
    case v <> t:
      %CT.list_append_equiv(Maybe<&2, U32>, U.lengths(H.commas(v)), u_all_values_onto(t, acc)) : {U.all_values_go(List.reverse.go(&2, List<&2, U32>, t, v <> r), acc) == U.all_values_go(r, _) : List<&2, Maybe<&2, U32>>}
      u_all_values_reverse(t, v <> r, acc)

def u_all_values_equiv(+xs: List<&2, List<&2, U32>>) -> {U.all_values(xs) == U.all_values_spec(xs) : List<&2, Maybe<&2, U32>>}:
  Equal.trans(List<&2, Maybe<&2, U32>>, U.all_values(xs), u_all_values_onto(xs, []), U.all_values_spec(xs), u_all_values_reverse(xs, [], []), u_all_values_base(xs))

def Laws.review_u_all_values(xs): u_all_values_equiv(xs)

def u_coding_onto(xs: List<&2, List<&2, U32>>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: acc
    case v <> t: List.append(&2, String, H.token_names(H.commas(v)), u_coding_onto(t, acc))

def u_coding_base(+xs: List<&2, List<&2, U32>>) -> {u_coding_onto(xs, []) == U.coding_spec(xs) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case v <> t: Equal.cong(List<&2, String>, List<&2, String>, acc => List.append(&2, String, H.token_names(H.commas(v)), acc), u_coding_onto(t, []), U.coding_spec(t), u_coding_base(t))

def u_coding_reverse(+xs: List<&2, List<&2, U32>>, +r: List<&2, List<&2, U32>>, +acc: List<&2, String>) -> {U.coding_go(List.reverse.go(&2, List<&2, U32>, xs, r), acc) == U.coding_go(r, u_coding_onto(xs, acc)) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case v <> t:
      %CT.list_append_equiv(String, H.token_names(H.commas(v)), u_coding_onto(t, acc)) : {U.coding_go(List.reverse.go(&2, List<&2, U32>, t, v <> r), acc) == U.coding_go(r, _) : List<&2, String>}
      u_coding_reverse(t, v <> r, acc)

def u_coding_equiv(+xs: List<&2, List<&2, U32>>) -> {U.coding(xs) == U.coding_spec(xs) : List<&2, String>}:
  Equal.trans(List<&2, String>, U.coding(xs), u_coding_onto(xs, []), U.coding_spec(xs), u_coding_reverse(xs, [], []), u_coding_base(xs))

def Laws.review_u_coding(xs): u_coding_equiv(xs)

def h_lead_reverse(+xs: List<&2, U32>, +r: List<&2, U32>, +ys: List<&2, U32>) -> {H.strip_lead_go(List.reverse.go(&2, U32, xs, r), H.Lead{ys, H.strip_lead_spec(ys)}) == H.strip_lead_go(r, H.Lead{List.append(&2, U32, xs, ys), H.strip_lead_spec(List.append(&2, U32, xs, ys))}) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +c <> t: h_lead_reverse(t, c <> r, ys)

def h_strip_lead_equiv(+xs: List<&2, U32>) -> {H.strip_lead(xs) == H.strip_lead_spec(xs) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, H.strip_lead(xs), H.strip_lead_spec(List.append(&2, U32, xs, [])), H.strip_lead_spec(xs), h_lead_reverse(xs, [], []), Equal.cong(List<&2, U32>, List<&2, U32>, x => H.strip_lead_spec(x), List.append(&2, U32, xs, []), xs, TP.list_append_nil(U32, xs)))


def Laws.review_h_strip_lead(xs): h_strip_lead_equiv(xs)

def h_listed_pick_equiv(+v: List<&2, U32>, +rest: List<&2, String>, on: Bool) -> {H.listed_pick(v, rest, on) == H.listed_pick_spec(v, rest, on) : List<&2, String>}:
  match on:
    case False{}: {==}
    case True{}: CT.list_append_equiv(String, H.token_names(H.commas(v)), rest)

def Laws.review_h_listed_pick(v, rest, on): h_listed_pick_equiv(v, rest, on)

def chain_equiv(+xs: List<&2, String>, mine: Maybe<&2, String>) -> {U.chain(xs, mine) == U.chain_spec(xs, mine) : Maybe<&2, String>}:
  match xs mine:
    case Nil{} None{}: {==}
    case h <> t None{}: Equal.cong(String, Maybe<&2, String>, s => Some{s}, T.join(h <> t, ", "), String.join(h <> t, ", "), MT.join_equiv(h <> t, ", "))
    case xs Some{+m}:
      %Equal.sym(List<&2, String>, T.list_append(String, xs, [m]), List.append(&2, String, xs, [m]), CT.list_append_equiv(String, xs, [m])) : {Some{T.join(_, ", ")} == U.chain_spec(xs, Some{m}) : Maybe<&2, String>}
      Equal.cong(String, Maybe<&2, String>, s => Some{s}, T.join(List.append(&2, String, xs, [m]), ", "), String.join(List.append(&2, String, xs, [m]), ", "), MT.join_equiv(List.append(&2, String, xs, [m]), ", "))

def Laws.review_u_chain(xs, mine): chain_equiv(xs, mine)

def concat_onto(-A: Data, xs: List<&2, List<&2, A>>, acc: List<&2, A>) -> List<&2, A>:
  match xs:
    case Nil{}: acc
    case h <> t: List.append(&2, A, h, concat_onto(A, t, acc))

def concat_base(-A: Data, +xs: List<&2, List<&2, A>>) -> {concat_onto(A, xs, []) == List.concat(&2, A, xs) : List<&2, A>}:
  match xs:
    case Nil{}: {==}
    case h <> t: Equal.cong(List<&2, A>, List<&2, A>, acc => List.append(&2, A, h, acc), concat_onto(A, t, []), List.concat(&2, A, t), concat_base(A, t))

def concat_reverse(-A: Data, +xs: List<&2, List<&2, A>>, +r: List<&2, List<&2, A>>, +acc: List<&2, A>) -> {T.concat_go(A, List.reverse.go(&2, List<&2, A>, xs, r), acc) == T.concat_go(A, r, concat_onto(A, xs, acc)) : List<&2, A>}:
  match xs:
    case Nil{}: {==}
    case h <> t:
      %CT.list_append_equiv(A, h, concat_onto(A, t, acc)) : {T.concat_go(A, List.reverse.go(&2, List<&2, A>, t, h <> r), acc) == T.concat_go(A, r, _) : List<&2, A>}
      concat_reverse(A, t, h <> r, acc)

def concat_equiv(-A: Data, +xs: List<&2, List<&2, A>>) -> {T.concat(A, xs) == List.concat(&2, A, xs) : List<&2, A>}:
  Equal.trans(List<&2, A>, T.concat(A, xs), concat_onto(A, xs, []), List.concat(&2, A, xs), concat_reverse(A, xs, [], []), concat_base(A, xs))

def Laws.review_text_concat(A, xs): concat_equiv(A, xs)

def named_unfold(+name: String, +n: String, +t: List<&2, String>) -> {H.named(name, n <> t) == String.eq(name, n) || H.named(name, t) : Bool}:
  Equal.trans(Bool, H.named(name, n <> t), H.named_spec(name, n <> t), String.eq(name, n) || H.named(name, t), h_named_equiv(n <> t, name), Equal.cong(Bool, Bool, acc => String.eq(name, n) || acc, H.named_spec(name, t), H.named(name, t), Equal.sym(Bool, H.named(name, t), H.named_spec(name, t), h_named_equiv(t, name))))

def commas_unfold(+c: U32, +t: List<&2, U32>) -> {H.commas(c <> t) == H.comma_pick(c, H.commas(t), U32.is_eq(c, 44)) : List<&2, List<&2, U32>>}:
  Equal.trans(List<&2, List<&2, U32>>, H.commas(c <> t), H.commas_spec(c <> t), H.comma_pick(c, H.commas(t), U32.is_eq(c, 44)), h_commas_equiv(c <> t), Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, acc => H.comma_pick(c, acc, U32.is_eq(c, 44)), H.commas_spec(t), H.commas(t), Equal.sym(List<&2, List<&2, U32>>, H.commas(t), H.commas_spec(t), h_commas_equiv(t))))

def strip_lead_unfold(+c: U32, +t: List<&2, U32>) -> {H.strip_lead(c <> t) == H.lead_pick(c, t, H.strip_lead(t), H.blank(c)) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, H.strip_lead(c <> t), H.strip_lead_spec(c <> t), H.lead_pick(c, t, H.strip_lead(t), H.blank(c)), h_strip_lead_equiv(c <> t), Equal.cong(List<&2, U32>, List<&2, U32>, acc => H.lead_pick(c, t, acc, H.blank(c)), H.strip_lead_spec(t), H.strip_lead(t), Equal.sym(List<&2, U32>, H.strip_lead(t), H.strip_lead_spec(t), h_strip_lead_equiv(t))))

def strip_trail_unfold(+c: U32, +t: List<&2, U32>) -> {H.strip_trail(c <> t) == H.trail_pick(c, H.blank(c), H.strip_trail(t)) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, H.strip_trail(c <> t), H.strip_trail_spec(c <> t), H.trail_pick(c, H.blank(c), H.strip_trail(t)), h_strip_trail_equiv(c <> t), Equal.cong(List<&2, U32>, List<&2, U32>, acc => H.trail_pick(c, H.blank(c), acc), H.strip_trail_spec(t), H.strip_trail(t), Equal.sym(List<&2, U32>, H.strip_trail(t), H.strip_trail_spec(t), h_strip_trail_equiv(t))))

def token_names_unfold(+p: List<&2, U32>, +t: List<&2, List<&2, U32>>) -> {H.token_names(p <> t) == H.name_pick(Bytes.fold(Bytes.ascii(H.strip_trail(H.strip_lead(p)))), H.token_names(t), String.is_empty(Bytes.fold(Bytes.ascii(H.strip_trail(H.strip_lead(p)))))) : List<&2, String>}:
  Equal.trans(List<&2, String>, H.token_names(p <> t), H.token_names_spec(p <> t), H.name_pick(Bytes.fold(Bytes.ascii(H.strip_trail(H.strip_lead(p)))), H.token_names(t), String.is_empty(Bytes.fold(Bytes.ascii(H.strip_trail(H.strip_lead(p)))))), h_token_names_equiv(p <> t), Equal.cong(List<&2, String>, List<&2, String>, acc => H.name_pick(Bytes.fold(Bytes.ascii(H.strip_trail(H.strip_lead(p)))), acc, String.is_empty(Bytes.fold(Bytes.ascii(H.strip_trail(H.strip_lead(p)))))), H.token_names_spec(t), H.token_names(t), Equal.sym(List<&2, String>, H.token_names(t), H.token_names_spec(t), h_token_names_equiv(t))))

def listed_unfold(+name: String, +value: List<&2, U32>, +t: List<&2, R.Header>) -> {H.listed(R.Header{name, value} <> t) == H.listed_pick(value, H.listed(t), String.eq(Bytes.fold(name), "connection")) : List<&2, String>}:
  Equal.trans(List<&2, String>, H.listed(R.Header{name, value} <> t), H.listed_spec(R.Header{name, value} <> t), H.listed_pick(value, H.listed(t), String.eq(Bytes.fold(name), "connection")), h_listed_equiv(R.Header{name, value} <> t), Equal.cong(List<&2, String>, List<&2, String>, acc => H.listed_pick(value, acc, String.eq(Bytes.fold(name), "connection")), H.listed_spec(t), H.listed(t), Equal.sym(List<&2, String>, H.listed(t), H.listed_spec(t), h_listed_equiv(t))))

def keep_all_unfold(+tokens: List<&2, String>, +h: R.Header, +t: List<&2, R.Header>) -> {H.keep_all(tokens, h <> t) == H.keep_pick(h, H.keep_all(tokens, t), H.keep(tokens, h)) : List<&2, R.Header>}:
  Equal.trans(List<&2, R.Header>, H.keep_all(tokens, h <> t), H.keep_all_spec(tokens, h <> t), H.keep_pick(h, H.keep_all(tokens, t), H.keep(tokens, h)), h_keep_all_equiv(h <> t, tokens), Equal.cong(List<&2, R.Header>, List<&2, R.Header>, acc => H.keep_pick(h, acc, H.keep(tokens, h)), H.keep_all_spec(tokens, t), H.keep_all(tokens, t), Equal.sym(List<&2, R.Header>, H.keep_all(tokens, t), H.keep_all_spec(tokens, t), h_keep_all_equiv(t, tokens))))

def write_headers_onto(xs: List<&2, R.Header>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: acc
    case h <> t: W.header(h, write_headers_onto(t, acc))

def write_headers_base(+xs: List<&2, R.Header>) -> {write_headers_onto(xs, [13, 10]) == W.headers_spec(xs) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case h <> t: Equal.cong(List<&2, U32>, List<&2, U32>, acc => W.header(h, acc), write_headers_onto(t, [13, 10]), W.headers_spec(t), write_headers_base(t))

def write_headers_reverse(+xs: List<&2, R.Header>, +r: List<&2, R.Header>, +acc: List<&2, U32>) -> {W.headers_go(List.reverse.go(&2, R.Header, xs, r), acc) == W.headers_go(r, write_headers_onto(xs, acc)) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case h <> t: write_headers_reverse(t, h <> r, acc)

def write_headers_equiv(+xs: List<&2, R.Header>) -> {W.headers(xs) == W.headers_spec(xs) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, W.headers(xs), write_headers_onto(xs, [13, 10]), W.headers_spec(xs), write_headers_reverse(xs, [], [13, 10]), write_headers_base(xs))

def Laws.review_write_headers(xs): write_headers_equiv(xs)

def write_headers_unfold(+h: R.Header, +t: List<&2, R.Header>) -> {W.headers(h <> t) == W.header(h, W.headers(t)) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, W.headers(h <> t), W.headers_spec(h <> t), W.header(h, W.headers(t)), write_headers_equiv(h <> t), Equal.cong(List<&2, U32>, List<&2, U32>, acc => W.header(h, acc), W.headers_spec(t), W.headers(t), Equal.sym(List<&2, U32>, W.headers(t), W.headers_spec(t), write_headers_equiv(t))))

def take_onto(+s: String, +n: Nat, +acc: String) -> {T.take_go(s, n, acc) == String.reverse.go(acc, String.take(s, n)) : String}:
  match s n:
    case SNil{} _: {==}
    case SCon{h, t} 0n: {==}
    case SCon{h, t} 1n+p: take_onto(t, p, SCon{h, acc})

def Laws.review_text_take(s, n): take_onto(s, n, "")

def zeros_cons(+n: Nat, +acc: String) -> {J.zeros_go(n, SCon{'0', acc}) == SCon{'0', J.zeros_go(n, acc)} : String}:
  match n:
    case 0n: {==}
    case 1n+p: zeros_cons(p, SCon{'0', acc})

def zeros_equiv(+n: Nat) -> {J.zeros(n) == J.zeros_spec(n) : String}:
  match n:
    case 0n: {==}
    case 1n+p:
      Equal.trans(String, J.zeros_go(p, "0"), SCon{'0', J.zeros_go(p, "")}, SCon{'0', J.zeros_spec(p)}, zeros_cons(p, ""), Equal.cong(String, String, s => SCon{'0', s}, J.zeros_go(p, ""), J.zeros_spec(p), zeros_equiv(p)))

def Laws.review_j_zeros(n): zeros_equiv(n)
