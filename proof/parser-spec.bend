# BND-92: proofs of the parser specification laws.
import Base
import ../src/http/bytes.bend as Bytes
import ./bytes-tail.bend as BT
import ./fold-spec.bend as FoldSpec
import ./fold-chars.bend as FoldChars
import ../src/data/urlencoded.bend as Url
import ../src/data/utf8.bend as Utf8
import ./query-spec.bend as QSpec
import ./query-split.bend as Split
import ./url-percent-form.bend as FormPercent
import ./parser-spec-laws.bend as Laws

# ---- Bytes.fold ----

def lower_table(+s: String) -> {String.to_lower(s) == FoldSpec.fold(s) : String}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, t}:
      %FoldChars.char(c) : {SCon{Char.to_lower(Chr{c}), String.to_lower(t)} == SCon{_, FoldSpec.fold(t)} : String}
      Equal.cong(String, String, r => SCon{Char.to_lower(Chr{c}), r}, String.to_lower(t), FoldSpec.fold(t), lower_table(t))

def Laws.fold_matches_letter_table(s):
  Equal.trans(String, Bytes.fold(s), String.to_lower(s), FoldSpec.fold(s), BT.fold_equiv(s), lower_table(s))

# ---- the raw query parser ----

def utf8_same(+m: Maybe<&2, String>) -> {Url.utf8_result(m) == QSpec.utf8(m) : Result<&2, &2, Url.Error, String>}:
  match m:
    case None{}: {==}
    case Some{s}: {==}

def text_same(+r: Result<&2, &2, Url.Error, List<&2, U32>>) -> {Url.decode_result(r) == QSpec.text(r) : Result<&2, &2, Url.Error, String>}:
  match r:
    case Fail{e}: {==}
    case Done{os}: utf8_same(Utf8.decode(os))

# A form name or value decodes as the spec's text.
def decode_same(+xs: List<&2, U32>) -> {Url.decode_bytes(xs, True{}) == QSpec.text(QSpec.unpercent(xs)) : Result<&2, &2, Url.Error, String>}:
  %Equal.sym(Result<&2, &2, Url.Error, List<&2, U32>>, Url.percent_decode(xs, True{}), QSpec.unpercent(xs), FormPercent.percent(xs)) : {Url.decode_result(_) == QSpec.text(QSpec.unpercent(xs)) : Result<&2, &2, Url.Error, String>}
  text_same(QSpec.unpercent(xs))

# The implementation's entries so far, reversed, in front of the spec's.
def prepend(rev: List<&2, Url.Entry>, r: Result<&2, &2, Url.Error, List<&2, Url.Entry>>) -> Result<&2, &2, Url.Error, List<&2, Url.Entry>>:
  match r:
    case Fail{e}: Fail{e}
    case Done{es}: Done{List.reverse.go(&2, Url.Entry, rev, es)}

def prepend_nil(+r: Result<&2, &2, Url.Error, List<&2, Url.Entry>>) -> {prepend([], r) == r : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}:
  match r:
    case Fail{e}: {==}
    case Done{es}: {==}

def entry_shift(+e: Url.Entry, +rev: List<&2, Url.Entry>, +r: Result<&2, &2, Url.Error, List<&2, Url.Entry>>) -> {prepend(e <> rev, r) == prepend(rev, QSpec.cons(Done{e}, r)) : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}:
  match r:
    case Fail{x}: {==}
    case Done{es}: {==}

# A failure stays, whatever pieces follow.
def parts_fail(+ps: List<&2, List<&2, U32>>, +e: Url.Error) -> {Url.parse_parts_go(ps, Fail{e}) == Fail{e} : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}:
  match ps:
    case Nil{}: {==}
    case Nil{} <> t: {==}
    case (b <> bs) <> t: {==}

def parts_step(+k: Result<&2, &2, Url.Error, String>, +v: Result<&2, &2, Url.Error, String>, +t: List<&2, List<&2, U32>>, +rev: List<&2, Url.Entry>, ih: @r:List<&2, Url.Entry> -> {Url.parse_parts_go(t, Done{r}) == prepend(r, QSpec.entries(t)) : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}) -> {Url.parse_parts_go(t, Url.pair_result(k, v, Done{rev})) == prepend(rev, QSpec.cons(QSpec.pair(k, v), QSpec.entries(t))) : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}:
  match k v:
    case Fail{e} Fail{x}: parts_fail(t, e)
    case Fail{e} Done{b}: parts_fail(t, e)
    case Done{a} Fail{e}: parts_fail(t, e)
    case Done{a} Done{b}: Equal.trans(Result<&2, &2, Url.Error, List<&2, Url.Entry>>, Url.parse_parts_go(t, Done{Url.Entry{a, b} <> rev}), prepend(Url.Entry{a, b} <> rev, QSpec.entries(t)), prepend(rev, QSpec.cons(Done{Url.Entry{a, b}}, QSpec.entries(t))), ih(Url.Entry{a, b} <> rev), entry_shift(Url.Entry{a, b}, rev, QSpec.entries(t)))

# The entry loop is the spec with its entries so far, reversed, in front.
def parts(+ps: List<&2, List<&2, U32>>, +rev: List<&2, Url.Entry>) -> {Url.parse_parts_go(ps, Done{rev}) == prepend(rev, QSpec.entries(ps)) : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}:
  match ps:
    case Nil{}: {==}
    case Nil{} <> t: parts(t, rev)
    case (+b <> +bs) <> +t:
      %Equal.sym(List<&2, U32> & List<&2, U32>, Url.field(b <> bs), (QSpec.name(b <> bs), QSpec.value(b <> bs)), Split.field_equiv(b <> bs)) : {Url.parse_parts_go(t, Url.parse_field(_, Done{rev})) == prepend(rev, QSpec.entries((b <> bs) <> t)) : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}
      %Equal.sym(Result<&2, &2, Url.Error, String>, Url.decode_bytes(QSpec.name(b <> bs), True{}), QSpec.text(QSpec.unpercent(QSpec.name(b <> bs))), decode_same(QSpec.name(b <> bs))) : {Url.parse_parts_go(t, Url.pair_result(_, Url.decode_bytes(QSpec.value(b <> bs), True{}), Done{rev})) == prepend(rev, QSpec.entries((b <> bs) <> t)) : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}
      %Equal.sym(Result<&2, &2, Url.Error, String>, Url.decode_bytes(QSpec.value(b <> bs), True{}), QSpec.text(QSpec.unpercent(QSpec.value(b <> bs))), decode_same(QSpec.value(b <> bs))) : {Url.parse_parts_go(t, Url.pair_result(QSpec.text(QSpec.unpercent(QSpec.name(b <> bs))), _, Done{rev})) == prepend(rev, QSpec.entries((b <> bs) <> t)) : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}
      parts_step(QSpec.text(QSpec.unpercent(QSpec.name(b <> bs))), QSpec.text(QSpec.unpercent(QSpec.value(b <> bs))), t, rev, r => parts(t, r))

def bytes_same(+xs: List<&2, U32>) -> {Url.parse_pairs_bytes(xs) == QSpec.entries(QSpec.pieces(xs)) : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}:
  %Equal.sym(List<&2, List<&2, U32>>, Url.split(xs), QSpec.pieces(xs), Split.split_equiv(xs)) : {Url.parse_parts_go(_, Done{[]}) == QSpec.entries(QSpec.pieces(xs)) : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}
  Equal.trans(Result<&2, &2, Url.Error, List<&2, Url.Entry>>, Url.parse_parts_go(QSpec.pieces(xs), Done{[]}), prepend([], QSpec.entries(QSpec.pieces(xs))), QSpec.entries(QSpec.pieces(xs)), parts(QSpec.pieces(xs), []), prepend_nil(QSpec.entries(QSpec.pieces(xs))))

def refuse_same(+r: Result<&2, &2, Url.Error, List<&2, Url.Entry>>, scalars: Bool) -> {Url.scalar_pairs(r, scalars) == QSpec.refuse(r, scalars) : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}:
  match r scalars:
    case Fail{e} _: {==}
    case Done{es} True{}: {==}
    case Done{es} False{}: {==}

def Laws.query_parse_matches_spec(s):
  %Equal.sym(Result<&2, &2, Url.Error, List<&2, Url.Entry>>, Url.parse_pairs_bytes(Utf8.encode(s)), QSpec.entries(QSpec.pieces(Utf8.encode(s))), bytes_same(Utf8.encode(s))) : {Url.scalar_pairs(_, Utf8.valid(s)) == QSpec.parse(s) : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}
  refuse_same(QSpec.entries(QSpec.pieces(Utf8.encode(s))), Utf8.valid(s))

def Laws.query_spec_examples():
  ({==}, ({==}, ({==}, {==})))
