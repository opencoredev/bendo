import Base
import ./cookie-ows-laws.bend as Laws
import ./cookie-ows-spec.bend as Spec
import ./cookies.bend as P
import ./crypto-support.bend as S
import ./equality.bend as E
import ../src/data/cookie.bend as C
import ../src/http/bytes.bend as B

# Local projections keep the law module independent of LAWS.bend.
def left(a: Bool, b: Bool, ok: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: E.absurd({False{} == True{} : Bool}, E.false_true(ok))

def right(a: Bool, b: Bool, ok: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}: ok
    case False{}: E.absurd({b == True{} : Bool}, E.false_true(ok))

def strip_prefix(+p: Spec.Padding, +s: String) -> {C.trim_start(Spec.prefix(p, s)) == C.trim_start(s) : String}:
  match p:
    case Spec.Empty{}: {==}
    case Spec.Space{+t}: strip_prefix(t, s)
    case Spec.Tab{+t}: strip_prefix(t, s)

def strip_reversed(+p: Spec.Padding, +acc: String) -> {C.trim_start(String.reverse.go(Spec.prefix(p, ""), acc)) == C.trim_start(acc) : String}:
  match p:
    case Spec.Empty{}: {==}
    case Spec.Space{+t}:
      %Equal.sym(String, C.trim_start(String.reverse.go(Spec.prefix(t, ""), SCon{' ', acc})), C.trim_start(SCon{' ', acc}), strip_reversed(t, SCon{' ', acc})) : {_ == C.trim_start(acc) : String}
      {==}
    case Spec.Tab{+t}:
      %Equal.sym(String, C.trim_start(String.reverse.go(Spec.prefix(t, ""), SCon{'\t', acc})), C.trim_start(SCon{'\t', acc}), strip_reversed(t, SCon{'\t', acc})) : {_ == C.trim_start(acc) : String}
      {==}

def trim_suffix(+s: String, +p: Spec.Padding, +ok: {P.clean(s) == True{} : Bool}, +start: {C.trim_start(s ++ Spec.prefix(p, "")) == s ++ Spec.prefix(p, "") : String}) -> {C.trim(s ++ Spec.prefix(p, "")) == s : String}:
  %Equal.sym(String, C.trim_start(s ++ Spec.prefix(p, "")), s ++ Spec.prefix(p, ""), start) : {String.reverse(C.trim_start(String.reverse(_))) == s : String}
  %Equal.sym(String, String.reverse(s ++ Spec.prefix(p, "")), String.reverse.go(Spec.prefix(p, ""), String.reverse(s)), S.reverse_append(s, Spec.prefix(p, ""), "")) : {String.reverse(C.trim_start(_)) == s : String}
  %Equal.sym(String, C.trim_start(String.reverse.go(Spec.prefix(p, ""), String.reverse(s))), C.trim_start(String.reverse(s)), strip_reversed(p, String.reverse(s))) : {String.reverse(_) == s : String}
  %Equal.sym(String, C.trim_start(String.reverse(s)), String.reverse(s), P.trim_start_identity(String.reverse(s), P.clean_reverse(s, "", ok, {==}))) : {String.reverse(_) == s : String}
  Equal.trans(String, String.reverse(String.reverse(s)), s ++ "", s, S.reverse_twice(s, "", ""), S.string_nil(s))

def trim_pair_suffix(+name: String, +value: String, +after: Spec.Padding, +nv: {C.name_valid(name) == True{} : Bool}, +vv: {C.value_valid(value) == True{} : Bool}) -> {C.trim(C.serialize_pair(name, value) ++ Spec.prefix(after, "")) == C.serialize_pair(name, value) : String}:
  match name:
    case SNil{}:
      E.absurd({C.trim(C.serialize_pair("", value) ++ Spec.prefix(after, "")) == C.serialize_pair("", value) : String}, E.false_true(nv))
    case SCon{Chr{+c}, +t}:
      trim_suffix(C.serialize_pair(SCon{Chr{c}, t}, value), after, P.pair_clean(SCon{Chr{c}, t}, value, nv, vv), P.head_trim(c, (t ++ "=" ++ value) ++ Spec.prefix(after, ""), P.clean_head(c, (t ++ "=" ++ value) ++ Spec.prefix(after, ""), P.token_clean(c, left(B.tchar(c), B.token_tail(t), nv)))))

def trim_padded_pair(+before: Spec.Padding, +name: String, +value: String, +after: Spec.Padding, +nv: {C.name_valid(name) == True{} : Bool}, +vv: {C.value_valid(value) == True{} : Bool}) -> {C.trim(Spec.pair(Spec.PaddedEntry{before, name, value, after})) == C.serialize_pair(name, value) : String}:
  %Equal.sym(String, C.trim_start(Spec.prefix(before, C.serialize_pair(name, value) ++ Spec.prefix(after, ""))), C.trim_start(C.serialize_pair(name, value) ++ Spec.prefix(after, "")), strip_prefix(before, C.serialize_pair(name, value) ++ Spec.prefix(after, ""))) : {String.reverse(C.trim_start(String.reverse(_))) == C.serialize_pair(name, value) : String}
  trim_pair_suffix(name, value, after, nv, vv)

def free(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, t}: Bool.not(U32.is_eq(c, 59)) && free(t)

def free_clean(+s: String, +ok: {P.clean(s) == True{} : Bool}) -> {free(s) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      P.and_true(Bool.not(U32.is_eq(c, 59)), free(t), Equal.cong(Bool, Bool, x => Bool.not(x), U32.is_eq(c, 59), False{}, P.clean_semicolon(c, left(P.clean_char(c), P.clean(t), ok))), free_clean(t, right(P.clean_char(c), P.clean(t), ok)))

def free_prefix(+p: Spec.Padding, +s: String, +ok: {free(s) == True{} : Bool}) -> {free(Spec.prefix(p, s)) == True{} : Bool}:
  match p:
    case Spec.Empty{}: ok
    case Spec.Space{+t}: free_prefix(t, s, ok)
    case Spec.Tab{+t}: free_prefix(t, s, ok)

def free_append(+a: String, +b: String, +oka: {free(a) == True{} : Bool}, +okb: {free(b) == True{} : Bool}) -> {free(a ++ b) == True{} : Bool}:
  match a:
    case SNil{}: okb
    case SCon{Chr{+c}, +t}:
      P.and_true(Bool.not(U32.is_eq(c, 59)), free(t ++ b), left(Bool.not(U32.is_eq(c, 59)), free(t), oka), free_append(t, b, right(Bool.not(U32.is_eq(c, 59)), free(t), oka), okb))

def free_pair(+before: Spec.Padding, +name: String, +value: String, +after: Spec.Padding, +nv: {C.name_valid(name) == True{} : Bool}, +vv: {C.value_valid(value) == True{} : Bool}) -> {free(Spec.pair(Spec.PaddedEntry{before, name, value, after})) == True{} : Bool}:
  free_prefix(before, C.serialize_pair(name, value) ++ Spec.prefix(after, ""), free_append(C.serialize_pair(name, value), Spec.prefix(after, ""), free_clean(C.serialize_pair(name, value), P.pair_clean(name, value, nv, vv)), free_prefix(after, "", {==})))

def split_single(+s: String, +ok: {free(s) == True{} : Bool}) -> {String.split(s, ';') == [s] : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Bool, U32.is_eq(c, 59), False{}, P.not_false(U32.is_eq(c, 59), left(Bool.not(U32.is_eq(c, 59)), free(t), ok))) : {String.split.fin(Chr{c}, String.split(t, ';'), _) == [SCon{Chr{c}, t}] : List<&2, String>}
      %Equal.sym(List<&2, String>, String.split(t, ';'), [t], split_single(t, right(Bool.not(U32.is_eq(c, 59)), free(t), ok))) : {String.split.push(Chr{c}, _) == [SCon{Chr{c}, t}] : List<&2, String>}
      {==}

def split_delimited(+s: String, +tail: String, +ok: {free(s) == True{} : Bool}) -> {String.split(s ++ ";" ++ tail, ';') == s <> String.split(tail, ';') : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Bool, U32.is_eq(c, 59), False{}, P.not_false(U32.is_eq(c, 59), left(Bool.not(U32.is_eq(c, 59)), free(t), ok))) : {String.split.fin(Chr{c}, String.split(t ++ ";" ++ tail, ';'), _) == SCon{Chr{c}, t} <> String.split(tail, ';') : List<&2, String>}
      %Equal.sym(List<&2, String>, String.split(t ++ ";" ++ tail, ';'), t <> String.split(tail, ';'), split_delimited(t, tail, right(Bool.not(U32.is_eq(c, 59)), free(t), ok))) : {String.split.push(Chr{c}, _) == SCon{Chr{c}, t} <> String.split(tail, ';') : List<&2, String>}
      {==}

def padded_parse_pair(+before: Spec.Padding, +name: String, +value: String, +after: Spec.Padding, +nv: {C.name_valid(name) == True{} : Bool}, +vv: {C.value_valid(value) == True{} : Bool}) -> {C.parse_pair(Spec.pair(Spec.PaddedEntry{before, name, value, after})) == Some{C.Entry{name, value}} : Maybe<&2, C.Entry>}:
  %Equal.sym(String, C.trim(Spec.pair(Spec.PaddedEntry{before, name, value, after})), C.serialize_pair(name, value), trim_padded_pair(before, name, value, after, nv, vv)) : {C.pair_parts(C.split(_, '=')) == Some{C.Entry{name, value}} : Maybe<&2, C.Entry>}
  %P.trim_identity(C.serialize_pair(name, value), P.pair_clean(name, value, nv, vv)) : {C.pair_parts(C.split(_, '=')) == Some{C.Entry{name, value}} : Maybe<&2, C.Entry>}
  P.parse_pair(name, value, nv, vv)

def parse_single(+s: String, +entry: C.Entry, +ok: {free(s) == True{} : Bool}, +parsed: {C.parse_pair(s) == Some{entry} : Maybe<&2, C.Entry>}) -> {C.parse(s) == [entry] : List<&2, C.Entry>}:
  %Equal.sym(List<&2, C.Entry>, C.parse(s), P.parts_reference(String.split(s, ';')), P.parse_reference(s)) : {_ == [entry] : List<&2, C.Entry>}
  %Equal.sym(List<&2, String>, String.split(s, ';'), [s], split_single(s, ok)) : {P.parts_reference(_) == [entry] : List<&2, C.Entry>}
  %Equal.sym(Maybe<&2, C.Entry>, C.parse_pair(s), Some{entry}, parsed) : {C.keep(_, []) == [entry] : List<&2, C.Entry>}
  {==}

def parse_cons(+s: String, +tail: String, +entry: C.Entry, +ok: {free(s) == True{} : Bool}, +parsed: {C.parse_pair(s) == Some{entry} : Maybe<&2, C.Entry>}) -> {C.parse(s ++ ";" ++ tail) == entry <> C.parse(tail) : List<&2, C.Entry>}:
  %Equal.sym(List<&2, C.Entry>, C.parse(s ++ ";" ++ tail), P.parts_reference(String.split(s ++ ";" ++ tail, ';')), P.parse_reference(s ++ ";" ++ tail)) : {_ == entry <> C.parse(tail) : List<&2, C.Entry>}
  %Equal.sym(List<&2, C.Entry>, C.parse(tail), P.parts_reference(String.split(tail, ';')), P.parse_reference(tail)) : {P.parts_reference(String.split(s ++ ";" ++ tail, ';')) == entry <> _ : List<&2, C.Entry>}
  %Equal.sym(List<&2, String>, String.split(s ++ ";" ++ tail, ';'), s <> String.split(tail, ';'), split_delimited(s, tail, ok)) : {P.parts_reference(_) == entry <> P.parts_reference(String.split(tail, ';')) : List<&2, C.Entry>}
  %Equal.sym(Maybe<&2, C.Entry>, C.parse_pair(s), Some{entry}, parsed) : {C.keep(_, P.parts_reference(String.split(tail, ';'))) == entry <> P.parts_reference(String.split(tail, ';')) : List<&2, C.Entry>}
  {==}

def joined_padded(+xs: List<&2, Spec.PaddedEntry>, +before: Spec.Padding, +name: String, +value: String, +after: Spec.Padding, +nv: {C.name_valid(name) == True{} : Bool}, +vv: {C.value_valid(value) == True{} : Bool}, +ok: {Spec.padded_valid(xs) == True{} : Bool}) -> {C.parse(String.join.go(Spec.padded_pairs(xs), Spec.pair(Spec.PaddedEntry{before, name, value, after}), ";")) == C.Entry{name, value} <> Spec.unpad(xs) : List<&2, C.Entry>}:
  match xs:
    case Nil{}:
      parse_single(Spec.pair(Spec.PaddedEntry{before, name, value, after}), C.Entry{name, value}, free_pair(before, name, value, after, nv, vv), padded_parse_pair(before, name, value, after, nv, vv))
    case Spec.PaddedEntry{+pre, +k, +v, +post} <> +t:
      %Equal.sym(List<&2, C.Entry>, C.parse(Spec.pair(Spec.PaddedEntry{before, name, value, after}) ++ ";" ++ String.join.go(Spec.padded_pairs(t), Spec.pair(Spec.PaddedEntry{pre, k, v, post}), ";")), C.Entry{name, value} <> C.parse(String.join.go(Spec.padded_pairs(t), Spec.pair(Spec.PaddedEntry{pre, k, v, post}), ";")), parse_cons(Spec.pair(Spec.PaddedEntry{before, name, value, after}), String.join.go(Spec.padded_pairs(t), Spec.pair(Spec.PaddedEntry{pre, k, v, post}), ";"), C.Entry{name, value}, free_pair(before, name, value, after, nv, vv), padded_parse_pair(before, name, value, after, nv, vv))) : {_ == C.Entry{name, value} <> C.Entry{k, v} <> Spec.unpad(t) : List<&2, C.Entry>}
      Equal.cong(List<&2, C.Entry>, List<&2, C.Entry>, rest => C.Entry{name, value} <> rest, C.parse(String.join.go(Spec.padded_pairs(t), Spec.pair(Spec.PaddedEntry{pre, k, v, post}), ";")), C.Entry{k, v} <> Spec.unpad(t), joined_padded(t, pre, k, v, post, left(C.name_valid(k), C.value_valid(v), left(C.name_valid(k) && C.value_valid(v), Spec.padded_valid(t), ok)), right(C.name_valid(k), C.value_valid(v), left(C.name_valid(k) && C.value_valid(v), Spec.padded_valid(t), ok)), right(C.name_valid(k) && C.value_valid(v), Spec.padded_valid(t), ok)))

def Laws.cookies_per_pair_ows_roundtrip(entries, valid):
  match entries:
    case Nil{}: {==}
    case Spec.PaddedEntry{+before, +name, +value, +after} <> +t:
      +ok = valid
      joined_padded(t, before, name, value, after, left(C.name_valid(name), C.value_valid(value), left(C.name_valid(name) && C.value_valid(value), Spec.padded_valid(t), ok)), right(C.name_valid(name), C.value_valid(value), left(C.name_valid(name) && C.value_valid(value), Spec.padded_valid(t), ok)), right(C.name_valid(name) && C.value_valid(value), Spec.padded_valid(t), ok))

def plain_parse_pair(+before: Spec.Padding, +name: String, +value: String, +nv: {C.name_valid(name) == True{} : Bool}, +vv: {C.value_valid(value) == True{} : Bool}) -> {C.parse_pair(Spec.prefix(before, C.serialize_pair(name, value))) == Some{C.Entry{name, value}} : Maybe<&2, C.Entry>}:
  %Equal.sym(String, C.trim_start(Spec.prefix(before, C.serialize_pair(name, value))), C.trim_start(C.serialize_pair(name, value)), strip_prefix(before, C.serialize_pair(name, value))) : {C.pair_parts(C.split(String.reverse(C.trim_start(String.reverse(_))), '=')) == Some{C.Entry{name, value}} : Maybe<&2, C.Entry>}
  P.parse_pair(name, value, nv, vv)

def space_join(+xs: List<&2, String>, +head: String, +sep: String) -> {String.join.go(xs, " " ++ head, sep) == " " ++ String.join.go(xs, head, sep) : String}:
  match xs:
    case Nil{}: {==}
    case h <> t: {==}

def joined_semispace(+xs: List<&2, C.Entry>, +before: Spec.Padding, +name: String, +value: String, +nv: {C.name_valid(name) == True{} : Bool}, +vv: {C.value_valid(value) == True{} : Bool}, +ok: {Spec.entries_valid(xs) == True{} : Bool}) -> {C.parse(String.join.go(Spec.pairs(xs), Spec.prefix(before, C.serialize_pair(name, value)), "; ")) == C.Entry{name, value} <> xs : List<&2, C.Entry>}:
  match xs:
    case Nil{}:
      parse_single(Spec.prefix(before, C.serialize_pair(name, value)), C.Entry{name, value}, free_prefix(before, C.serialize_pair(name, value), free_clean(C.serialize_pair(name, value), P.pair_clean(name, value, nv, vv))), plain_parse_pair(before, name, value, nv, vv))
    case C.Entry{+k, +v} <> +t:
      %Equal.sym(List<&2, C.Entry>, C.parse(Spec.prefix(before, C.serialize_pair(name, value)) ++ ";" ++ " " ++ String.join.go(Spec.pairs(t), C.serialize_pair(k, v), "; ")), C.Entry{name, value} <> C.parse(" " ++ String.join.go(Spec.pairs(t), C.serialize_pair(k, v), "; ")), parse_cons(Spec.prefix(before, C.serialize_pair(name, value)), " " ++ String.join.go(Spec.pairs(t), C.serialize_pair(k, v), "; "), C.Entry{name, value}, free_prefix(before, C.serialize_pair(name, value), free_clean(C.serialize_pair(name, value), P.pair_clean(name, value, nv, vv))), plain_parse_pair(before, name, value, nv, vv))) : {_ == C.Entry{name, value} <> C.Entry{k, v} <> t : List<&2, C.Entry>}
      %space_join(Spec.pairs(t), C.serialize_pair(k, v), "; ") : {C.Entry{name, value} <> C.parse(_) == C.Entry{name, value} <> C.Entry{k, v} <> t : List<&2, C.Entry>}
      Equal.cong(List<&2, C.Entry>, List<&2, C.Entry>, rest => C.Entry{name, value} <> rest, C.parse(String.join.go(Spec.pairs(t), " " ++ C.serialize_pair(k, v), "; ")), C.Entry{k, v} <> t, joined_semispace(t, Spec.Space{Spec.Empty{}}, k, v, left(C.name_valid(k), C.value_valid(v), left(C.name_valid(k) && C.value_valid(v), Spec.entries_valid(t), ok)), right(C.name_valid(k), C.value_valid(v), left(C.name_valid(k) && C.value_valid(v), Spec.entries_valid(t), ok)), right(C.name_valid(k) && C.value_valid(v), Spec.entries_valid(t), ok)))

def Laws.cookies_semispace_ordered_list_roundtrip(entries, valid):
  match entries:
    case Nil{}: {==}
    case C.Entry{+name, +value} <> +t:
      +ok = valid
      joined_semispace(t, Spec.Empty{}, name, value, left(C.name_valid(name), C.value_valid(value), left(C.name_valid(name) && C.value_valid(value), Spec.entries_valid(t), ok)), right(C.name_valid(name), C.value_valid(value), left(C.name_valid(name) && C.value_valid(value), Spec.entries_valid(t), ok)), right(C.name_valid(name) && C.value_valid(value), Spec.entries_valid(t), ok))
