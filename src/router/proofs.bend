# Constructive lemmas for the independently admissible pattern assignment law.
import Base
import ./pattern.bend as P
import ./encoding.bend as E
import ./constraint.bend as C
import ./octet-proofs.bend as OctetProof
import ./codec-bits.bend as CodecBits
import ./utf8-proofs.bend as Utf8Proof
import ./utf8-code.bend as Code
import ./encoding-proofs.bend as EP
import ./pattern-stack-proofs.bend as PS

# A Boolean equality is usable evidence, including in impossible branches.
def true_type(b: Bool) -> Type:
  match b:
    case False{}:
      Empty
    case True{}:
      Unit

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %Equal.sym(Bool, False{}, True{}, e) : true_type(_)
  Unit{}

def absurd(-A: Type, impossible: Empty) -> A:
  match impossible:

def and_left(+a: Bool, +b: Bool, e: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      absurd({False{} == True{} : Bool}, false_true(e))

def and_right(+a: Bool, +b: Bool, e: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}:
      e
    case False{}:
      absurd({b == True{} : Bool}, false_true(e))

# BND-14 lemmas (proof support)

def no_slash(s: String) -> Bool:
  OctetProof.no_slash(s)

# Concatenation preserves the absence of path separators.
law append_no_slash:
  for +a: String
  for +b: String
  for left: {no_slash(a) == True{} : Bool}
  for right: {no_slash(b) == True{} : Bool}
  {no_slash(a ++ b) == True{} : Bool}

def append_no_slash(a, b, left, right):
  match a:
    case SNil{}:
      right
    case SCon{+h, +t}:
      +e = left
      first = and_left(Bool.not(Char.is_eq(h, '/')), no_slash(t), e)
      rest = and_right(Bool.not(Char.is_eq(h, '/')), no_slash(t), e)
      %Equal.sym(Bool, Bool.not(Char.is_eq(h, '/')), True{}, first) : {_ && no_slash(t ++ b) == True{} : Bool}
      append_no_slash(t, b, rest, right)

law take_no_slash:
  for n: Nat
  for +s: String
  for clean: {no_slash(s) == True{} : Bool}
  {no_slash(String.take(s, n)) == True{} : Bool}

def take_no_slash(n, s, clean):
  match n s:
    case 0n SNil{}:
      {==}
    case 0n SCon{h, t}:
      {==}
    case 1n+p SNil{}:
      {==}
    case 1n+p SCon{+h, +t}:
      +yes = clean
      %Equal.sym(Bool, Bool.not(Char.is_eq(h, '/')), True{}, and_left(Bool.not(Char.is_eq(h, '/')), no_slash(t), yes)) : {_ && no_slash(String.take(t, p)) == True{} : Bool}
      take_no_slash(p, t, and_right(Bool.not(Char.is_eq(h, '/')), no_slash(t), yes))

# Percent-encoding a finite octet list cannot introduce path separators.
law octets_no_slash:
  for +xs: List<&2, Word(8n)>
  {no_slash(OctetProof.escape_octets(xs)) == True{} : Bool}

def octets_no_slash(xs):
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      append_no_slash(E.byte(OctetProof.octet(h)), OctetProof.escape_octets(t), OctetProof.byte_no_slash(h), octets_no_slash(t))

def not_true(+b: Bool, e: {Bool.not(b) == True{} : Bool}) -> {b == False{} : Bool}:
  match b:
    case False{}:
      {==}
    case True{}:
      absurd({True{} == False{} : Bool}, false_true(e))

# A slash-free prefix followed by a separator is exactly the first split part.
def split_prefix_base(+s: String, +tail: String, clean: {no_slash(s) == True{} : Bool}) ->
    {String.split(s ++ ("/" ++ tail), '/') == s <> String.split(tail, '/') : List<&2, String>}:
  match s:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      +e = clean
      cut = not_true(Char.is_eq(h, '/'), and_left(Bool.not(Char.is_eq(h, '/')), no_slash(t), e))
      rest = and_right(Bool.not(Char.is_eq(h, '/')), no_slash(t), e)
      %Equal.sym(Bool, Char.is_eq(h, '/'), False{}, cut) : {String.split.fin(h, String.split(t ++ ("/" ++ tail), '/'), _) == SCon{h, t} <> String.split(tail, '/') : List<&2, String>}
      %Equal.sym(List<&2, String>, String.split(t ++ ("/" ++ tail), '/'), t <> String.split(tail, '/'), split_prefix_base(t, tail, rest)) : {String.split.push(h, _) == SCon{h, t} <> String.split(tail, '/') : List<&2, String>}
      {==}

law split_prefix:
  for +s: String
  for +tail: String
  for clean: {no_slash(s) == True{} : Bool}
  {P.path_segments(s ++ ("/" ++ tail)) == s <> P.path_segments(tail) : List<&2, String>}

def split_prefix(s, tail, clean):
  %PS.segments_equiv(s ++ ("/" ++ tail)) : {_ == s <> P.path_segments(tail) : List<&2, String>}
  %PS.segments_equiv(tail) : {String.split(s ++ ("/" ++ tail), '/') == s <> _ : List<&2, String>}
  split_prefix_base(s, tail, clean)

# A single slash-free segment, including the empty segment, is preserved.
def split_single_base(+s: String, clean: {no_slash(s) == True{} : Bool}) ->
    {String.split(s, '/') == [s] : List<&2, String>}:
  match s:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      +e = clean
      cut = not_true(Char.is_eq(h, '/'), and_left(Bool.not(Char.is_eq(h, '/')), no_slash(t), e))
      rest = and_right(Bool.not(Char.is_eq(h, '/')), no_slash(t), e)
      %Equal.sym(Bool, Char.is_eq(h, '/'), False{}, cut) : {String.split.fin(h, String.split(t, '/'), _) == [SCon{h, t}] : List<&2, String>}
      %Equal.sym(List<&2, String>, String.split(t, '/'), [t], split_single_base(t, rest)) : {String.split.push(h, _) == [SCon{h, t}] : List<&2, String>}
      {==}

law split_single:
  for +s: String
  for clean: {no_slash(s) == True{} : Bool}
  {P.path_segments(s) == [s] : List<&2, String>}

def split_single(s, clean):
  %PS.segments_equiv(s) : {_ == [s] : List<&2, String>}
  split_single_base(s, clean)

def clean_segments(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      no_slash(h) && clean_segments(t)

def clean_split_push(+h: Char, parts: List<&2, String>,
    cut: {Char.is_eq(h, '/') == False{} : Bool},
    clean: {clean_segments(parts) == True{} : Bool}) ->
    {clean_segments(String.split.push(h, parts)) == True{} : Bool}:
  match parts:
    case Nil{}:
      %Equal.sym(Bool, Char.is_eq(h, '/'), False{}, cut) : {Bool.not(_) && True{} && True{} == True{} : Bool}
      {==}
    case +s <> +ss:
      %Equal.sym(Bool, Char.is_eq(h, '/'), False{}, cut) : {(Bool.not(_) && no_slash(s)) && clean_segments(ss) == True{} : Bool}
      %Equal.sym(Bool, clean_segments(s <> ss), True{}, clean) : {_ == True{} : Bool}
      {==}

def clean_split_fin(+h: Char, +parts: List<&2, String>, +cut: Bool,
    decision: {Char.is_eq(h, '/') == cut : Bool},
    clean: {clean_segments(parts) == True{} : Bool}) ->
    {clean_segments(String.split.fin(h, parts, cut)) == True{} : Bool}:
  match cut:
    case True{}:
      clean
    case False{}:
      clean_split_push(h, parts, decision, clean)

# Splitting any source establishes the separator invariant needed by split_join.
def clean_split_base(+s: String) ->
    {clean_segments(String.split(s, '/')) == True{} : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      clean_split_fin(h, String.split(t, '/'), Char.is_eq(h, '/'), {==}, clean_split_base(t))

law clean_split:
  for +s: String
  {clean_segments(P.path_segments(s)) == True{} : Bool}

def clean_split(s):
  %PS.segments_equiv(s) : {clean_segments(_) == True{} : Bool}
  clean_split_base(s)

# Splitting the joined nonempty list recovers empty and nonempty segments alike.
def split_join_base(+tail: List<&2, String>, +head: String, clean: {clean_segments(head <> tail) == True{} : Bool}) ->
    {String.split(String.join(head <> tail, "/"), '/') == head <> tail : List<&2, String>}:
  match tail:
    case Nil{}:
      split_single_base(head, and_left(no_slash(head), True{}, clean))
    case +h <> +t:
      +e = clean
      first = and_left(no_slash(head), clean_segments(h <> t), e)
      rest = and_right(no_slash(head), clean_segments(h <> t), e)
      %Equal.sym(List<&2, String>, String.split(head ++ ("/" ++ String.join(h <> t, "/")), '/'), head <> String.split(String.join(h <> t, "/"), '/'), split_prefix_base(head, String.join(h <> t, "/"), first)) : {_ == head <> h <> t : List<&2, String>}
      %Equal.sym(List<&2, String>, String.split(String.join(h <> t, "/"), '/'), h <> t, split_join_base(t, h, rest)) : {head <> _ == head <> h <> t : List<&2, String>}
      {==}

law split_join:
  for +tail: List<&2, String>
  for +head: String
  for clean: {clean_segments(head <> tail) == True{} : Bool}
  {P.path_segments(String.join(head <> tail, "/")) == head <> tail : List<&2, String>}

def split_join(tail, head, clean):
  %PS.segments_equiv(String.join(head <> tail, "/")) : {_ == head <> tail : List<&2, String>}
  split_join_base(tail, head, clean)

# The filler cannot fail on an admissible ordered assignment. No compilation
# premise or decoder/roundtrip premise is needed for this direction.
law fill_segments_success:
  for +segs: List<&2, P.Segment>
  for +ps: P.Params
  for +admitted: {P.admissible_segments(segs, ps) == True{} : Bool}
  exs xs: List<&2, String>
  {P.fill_segments(segs, ps) == Some{xs} : Maybe<&2, List<&2, String>>}

def fill_static(+raw: String, +rest: List<&2, P.Segment>, +ps: P.Params,
    success: &xs: List<&2, String> -> {P.fill_segments(rest, ps) == Some{xs} : Maybe<&2, List<&2, String>>}) ->
    &xs: List<&2, String> -> {P.fill_segments(P.Static{raw} <> rest, ps) == Some{xs} : Maybe<&2, List<&2, String>>}:
  (+xs, filled) = success
  (raw <> xs, (
    %Equal.sym(Maybe<&2, List<&2, String>>, P.fill_segments(rest, ps), Some{xs}, filled) : {Maybe.bind(&2, List<&2, String>, List<&2, String>, _, ys => Some{raw <> ys}) == Some{raw <> xs} : Maybe<&2, List<&2, String>>}
    {==}
  ))

def fill_capture(+name: String, +c: C.Constraint, +optional: Bool, +rest: List<&2, P.Segment>, +key: String, +value: String, +tail: P.Params,
    ok_true: {String.eq(name, key) && P.value_ok(c, value) == True{} : Bool},
    success: &xs: List<&2, String> -> {P.fill_segments(rest, tail) == Some{xs} : Maybe<&2, List<&2, String>>}) ->
    &xs: List<&2, String> -> {P.fill_segments(P.Capture{name, c, optional} <> rest, P.Param{key, value} <> tail) == Some{xs} : Maybe<&2, List<&2, String>>}:
  match optional rest:
    case False{} +remaining:
      (+xs, filled) = success
      (E.encode(value) <> xs, (
        %Equal.sym(Bool, String.eq(name, key) && P.value_ok(c, value), True{}, ok_true) : {E.choose(Maybe<&2, List<&2, String>>, _, u => (
          do Maybe<&2, List<&2, String>>:
            ys : List<&2, String> <- P.fill_segments(remaining, tail)
            return E.encode(value) <> ys
        ), u => (None{})) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}
        %Equal.sym(Maybe<&2, List<&2, String>>, P.fill_segments(remaining, tail), Some{xs}, filled) : {Maybe.bind(&2, List<&2, String>, List<&2, String>, _, ys => Some{E.encode(value) <> ys}) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}
        {==}
      ))
    case True{} Nil{}:
      (+xs, filled) = success
      (E.encode(value) <> xs, (
        %Equal.sym(Bool, String.eq(name, key) && P.value_ok(c, value), True{}, ok_true) : {E.choose(Maybe<&2, List<&2, String>>, _, u => (
          do Maybe<&2, List<&2, String>>:
            ys : List<&2, String> <- P.fill_segments(Nil{}, tail)
            return E.encode(value) <> ys
        ), u => (None{})) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}
        %Equal.sym(Maybe<&2, List<&2, String>>, P.fill_segments(Nil{}, tail), Some{xs}, filled) : {Maybe.bind(&2, List<&2, String>, List<&2, String>, _, ys => Some{E.encode(value) <> ys}) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}
        {==}
      ))
    case True{} +head <> +remaining:
      (+xs, filled) = success
      (E.encode(value) <> xs, (
        %Equal.sym(Bool, String.eq(name, key) && P.value_ok(c, value), True{}, ok_true) : {E.choose(Maybe<&2, List<&2, String>>, _, u => (
          do Maybe<&2, List<&2, String>>:
            ys : List<&2, String> <- P.fill_segments(head <> remaining, tail)
            return E.encode(value) <> ys
        ), u => (None{})) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}
        %Equal.sym(Maybe<&2, List<&2, String>>, P.fill_segments(head <> remaining, tail), Some{xs}, filled) : {Maybe.bind(&2, List<&2, String>, List<&2, String>, _, ys => Some{E.encode(value) <> ys}) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}
        {==}
      ))

def fill_interior(+rest: List<&2, P.Segment>, +ps: P.Params,
    success: &xs: List<&2, String> -> {P.fill_segments(rest, ps) == Some{xs} : Maybe<&2, List<&2, String>>}) ->
    &xs: List<&2, String> -> {P.fill_segments(P.InteriorWildcard{} <> rest, ps) == Some{xs} : Maybe<&2, List<&2, String>>}:
  (+xs, filled) = success
  (xs, filled)

def fill_span(+name: String, +rest: List<&2, P.Segment>, +key: String, +value: String, +tail: P.Params,
    ok_true: {(String.eq(name, key) && P.value_ok(C.Any{}, value)) && P.span_tail(rest) == True{} : Bool},
    success: &xs: List<&2, String> -> {P.fill_segments(rest, tail) == Some{xs} : Maybe<&2, List<&2, String>>}) ->
    &xs: List<&2, String> -> {P.fill_segments(P.Span{name} <> rest, P.Param{key, value} <> tail) == Some{xs} : Maybe<&2, List<&2, String>>}:
  (+xs, filled) = success
  (E.encode(value) <> xs, (
    %Equal.sym(Bool, (String.eq(name, key) && P.value_ok(C.Any{}, value)) && P.span_tail(rest), True{}, ok_true) : {E.choose(Maybe<&2, List<&2, String>>, _, u => Maybe.bind(&2, List<&2, String>, List<&2, String>, P.fill_segments(rest, tail), ys => Some{E.encode(value) <> ys}), u => None{}) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}
    %Equal.sym(Maybe<&2, List<&2, String>>, P.fill_segments(rest, tail), Some{xs}, filled) : {Maybe.bind(&2, List<&2, String>, List<&2, String>, _, ys => Some{E.encode(value) <> ys}) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}
    {==}
  ))

def fill_segments_success(segs, ps, admitted):
  match segs ps:
    case Nil{} Nil{}:
      (Nil{}, {==})
    case P.Static{+raw} <> +rest +values:
      fill_static(raw, rest, values, fill_segments_success(rest, values, admitted))
    case P.Capture{name, c, True{}} <> +rest Nil{}:
      (Nil{}, (
        %Equal.sym(Bool, P.all_optional(rest), True{}, admitted) : {E.choose(Maybe<&2, List<&2, String>>, _, u => Some{Nil{}}, u => None{}) == Some{Nil{}} : Maybe<&2, List<&2, String>>}
        {==}
      ))
    case P.InteriorWildcard{} <> +rest +values:
      fill_interior(rest, values, fill_segments_success(rest, values, admitted))
    case P.PrefixWildcard{+prefix} <> Nil{} Nil{}:
      ([prefix], {==})
    case P.Span{+name} <> +rest P.Param{+key, +value} <> +tail:
      +ok = (String.eq(name, key) && P.value_ok(C.Any{}, value)) && P.span_tail(rest)
      fill_span(name, rest, key, value, tail, and_left(ok, P.admissible_segments(rest, tail), admitted), fill_segments_success(rest, tail, and_right(ok, P.admissible_segments(rest, tail), admitted)))
    case P.Capture{+name, +c, +optional} <> +rest P.Param{+key, +value} <> +tail:
      +ok = String.eq(name, key) && P.value_ok(c, value)
      ok_true = and_left(ok, P.admissible_segments(rest, tail), admitted)
      tail_true = and_right(ok, P.admissible_segments(rest, tail), admitted)
      fill_capture(name, c, optional, rest, key, value, tail, ok_true, fill_segments_success(rest, tail, tail_true))
    case P.Wildcard{+name} <> Nil{} P.Param{+key, +value} <> Nil{}:
      ([E.encode(value)], (
        %Equal.sym(Bool, String.eq(name, key) && E.scalars(value), True{}, admitted) : {E.choose(Maybe<&2, List<&2, String>>, _, u => Some{[E.encode(value)]}, u => None{}) == Some{[E.encode(value)]} : Maybe<&2, List<&2, String>>}
        {==}
      ))
    case Nil{} h <> t:
      absurd(&xs: List<&2, String> -> {P.fill_segments(Nil{}, h <> t) == Some{xs} : Maybe<&2, List<&2, String>>}, false_true(admitted))
    case P.Capture{name, c, False{}} <> rest Nil{}:
      absurd(&xs: List<&2, String> -> {P.fill_segments(P.Capture{name, c, False{}} <> rest, Nil{}) == Some{xs} : Maybe<&2, List<&2, String>>}, false_true(admitted))
    case P.Wildcard{name} <> Nil{} Nil{}:
      absurd(&xs: List<&2, String> -> {P.fill_segments([P.Wildcard{name}], Nil{}) == Some{xs} : Maybe<&2, List<&2, String>>}, false_true(admitted))
    case P.Wildcard{name} <> Nil{} h <> j <> t:
      absurd(&xs: List<&2, String> -> {P.fill_segments([P.Wildcard{name}], h <> j <> t) == Some{xs} : Maybe<&2, List<&2, String>>}, false_true(admitted))
    case P.Wildcard{name} <> h <> t values:
      absurd(&xs: List<&2, String> -> {P.fill_segments(P.Wildcard{name} <> h <> t, values) == Some{xs} : Maybe<&2, List<&2, String>>}, false_true(admitted))
    case P.PrefixWildcard{prefix} <> Nil{} h <> t:
      absurd(&xs: List<&2, String> -> {P.fill_segments([P.PrefixWildcard{prefix}], h <> t) == Some{xs} : Maybe<&2, List<&2, String>>}, false_true(admitted))
    case P.PrefixWildcard{prefix} <> h <> t values:
      absurd(&xs: List<&2, String> -> {P.fill_segments(P.PrefixWildcard{prefix} <> h <> t, values) == Some{xs} : Maybe<&2, List<&2, String>>}, false_true(admitted))
    case P.Span{name} <> rest Nil{}:
      absurd(&xs: List<&2, String> -> {P.fill_segments(P.Span{name} <> rest, Nil{}) == Some{xs} : Maybe<&2, List<&2, String>>}, false_true(admitted))

law fill_success:
  for +pattern: P.Pattern
  for +ps: P.Params
  for +admitted: {P.admissible(pattern, ps) == True{} : Bool}
  exs path: String
  {P.fill(pattern, ps) == Some{path} : Maybe<&2, String>}

def fill_path(+segs: List<&2, P.Segment>, +ps: P.Params,
    success: &xs: List<&2, String> -> {P.fill_segments(segs, ps) == Some{xs} : Maybe<&2, List<&2, String>>}) ->
    &path: String -> {P.fill(P.Pattern{segs}, ps) == Some{path} : Maybe<&2, String>}:
  (+xs, filled) = success
  ("/" ++ String.join(xs, "/"), (
    %Equal.sym(Maybe<&2, List<&2, String>>, P.fill_segments(segs, ps), Some{xs}, filled) : {Maybe.bind(&2, List<&2, String>, String, _, ys => Some{"/" ++ String.join(ys, "/")}) == Some{"/" ++ String.join(xs, "/")} : Maybe<&2, String>}
    {==}
  ))

def fill_success(pattern, ps, admitted):
  match pattern:
    case P.Pattern{+segs}:
      fill_path(segs, ps, fill_segments_success(segs, ps, admitted))

def clean_encoded_rep(+r: Code.Representation,
    packed: {Code.is_packed(r) == True{} : Bool}) ->
    {no_slash(E.encode_rep(r)) == True{} : Bool}:
  match r:
    case Code.Packed{+code}:
      %Equal.sym(String, E.encode_octets(Code.octets(code)), OctetProof.escape_octets(OctetProof.reverse_octets(Code.octets(code))), OctetProof.structural_escape(Code.octets(code))) : {no_slash(_) == True{} : Bool}
      octets_no_slash(OctetProof.reverse_octets(Code.octets(code)))
    case Code.Outside{raw}:
      absurd({no_slash(E.encode_rep(Code.Outside{raw})) == True{} : Bool}, false_true(packed))

law encode_no_slash:
  for +s: String
  for valid: {E.scalars(s) == True{} : Bool}
  {no_slash(E.encode(s)) == True{} : Bool}

def encode_no_slash(s, valid):
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+n}, +t}:
      +yes = Equal.trans(Bool, E.scalar(n) && E.scalars(t), E.scalars(SCon{Chr{n}, t}), True{}, EP.scalars_cons(n, t), valid)
      first = and_left(E.scalar(n), E.scalars(t), yes)
      rest = and_right(E.scalar(n), E.scalars(t), yes)
      %EP.encode_cons(n, t) : {no_slash(_) == True{} : Bool}
      append_no_slash(E.encode_char(n), E.encode(t), clean_encoded_rep(Code.represent(n), Utf8Proof.scalar_is_packed(n, first)), encode_no_slash(t, rest))

# Dynamic-programming rows contain one cell for every path suffix. These
# structural equations expose that layout without a fuel or termination premise.
def Rows() -> Data:
  List<&2, Maybe<&2, P.Params>>

def rows_cons(+segs: List<&2, P.Segment>, +h: String, +t: List<&2, String>) ->
    {P.match_rows(~String.eq, ~String.starts_with, segs, h <> t) == P.search_segments(segs, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, segs, t) : Rows}:
  match segs:
    case Nil{}:
      %PS.empty_rows_equiv(h <> t) : {_ == P.row_head(_) <> P.empty_rows(t) : Rows}
      %PS.empty_rows_equiv(t) : {P.empty_rows_spec(h <> t) == P.row_head(P.empty_rows_spec(h <> t)) <> _ : Rows}
      {==}
    case +seg <> +rest:
      +same = rows_cons(rest, h, t)
      %Equal.sym(Rows, P.match_rows(~String.eq, ~String.starts_with, rest, h <> t), P.search_segments(rest, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, rest, t), same) : {P.rows_for(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), h <> t, _) == P.row_head(P.rows_for(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), h <> t, _)) <> P.rows_for(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), t, P.match_rows(~String.eq, ~String.starts_with, rest, t)) : Rows}
      %PS.rows_for_equiv(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.search_segments(rest, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, rest, t)) : {_ == P.row_head(_) <> P.rows_for(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), t, P.match_rows(~String.eq, ~String.starts_with, rest, t)) : Rows}
      %PS.rows_for_equiv(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), t, P.match_rows(~String.eq, ~String.starts_with, rest, t)) : {P.rows_for_spec(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.search_segments(rest, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, rest, t)) == P.row_head(P.rows_for_spec(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.search_segments(rest, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, rest, t))) <> _ : Rows}
      {==}

# The row computed for the next shorter suffix, which interior and wildcard
# cells extend.
def below(+seg: P.Segment, +rest: List<&2, P.Segment>, +paths: List<&2, String>) -> Rows:
  match paths:
    case Nil{}:
      Nil{}
    case h <> +t:
      P.match_rows(~String.eq, ~String.starts_with, seg <> rest, t)

def rows_head(+seg: P.Segment, +rest: List<&2, P.Segment>, +paths: List<&2, String>) ->
    {P.search_segments(seg <> rest, paths) == P.row_one(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), paths, P.match_rows(~String.eq, ~String.starts_with, rest, paths), below(seg, rest, paths)) : Maybe<&2, P.Params>}:
  match paths:
    case Nil{}:
      {==}
    case +h <> +t:
      %Equal.sym(Rows, P.match_rows(~String.eq, ~String.starts_with, rest, h <> t), P.search_segments(rest, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, rest, t), rows_cons(rest, h, t)) : {P.row_head(P.rows_for(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), h <> t, _)) == P.row_one(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), h <> t, _, P.match_rows(~String.eq, ~String.starts_with, seg <> rest, t)) : Maybe<&2, P.Params>}
      %PS.rows_for_equiv(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.search_segments(rest, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, rest, t)) : {P.row_head(_) == P.row_one(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.search_segments(rest, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, rest, t), P.rows_for(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), t, P.match_rows(~String.eq, ~String.starts_with, rest, t))) : Maybe<&2, P.Params>}
      %PS.rows_for_equiv(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), t, P.match_rows(~String.eq, ~String.starts_with, rest, t)) : {P.row_head(P.rows_for_spec(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.search_segments(rest, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, rest, t))) == P.row_one(~String.eq, ~String.starts_with, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.search_segments(rest, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, rest, t), _) : Maybe<&2, P.Params>}
      {==}

def wildcard_value_param(+name: String, d: Maybe<&2, String>) ->
    {P.wildcard_value(P.wildcard_param(name, d)) == d : Maybe<&2, String>}:
  match d:
    case None{}:
      {==}
    case Some{v}:
      {==}

# The cached wildcard row extends the next suffix's decoded value.
def wildcard_search(+name: String, +ps: List<&2, String>) ->
    {P.search_segments([P.Wildcard{name}], ps) == P.match_segments([P.Wildcard{name}], ps) : Maybe<&2, P.Params>}:
  match ps:
    case Nil{}:
      {==}
    case +raw <> +tail:
      %Equal.sym(Maybe<&2, P.Params>, P.search_segments([P.Wildcard{name}], raw <> tail), P.row_one(~String.eq, ~String.starts_with, P.Wildcard{name}, True{}, raw <> tail, P.match_rows(~String.eq, ~String.starts_with, Nil{}, raw <> tail), below(P.Wildcard{name}, Nil{}, raw <> tail)), rows_head(P.Wildcard{name}, Nil{}, raw <> tail)) : {_ == P.match_segments([P.Wildcard{name}], raw <> tail) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, P.search_segments([P.Wildcard{name}], tail), P.match_segments([P.Wildcard{name}], tail), wildcard_search(name, tail)) : {P.wildcard_param(name, P.join_value(E.decode(raw), tail, P.wildcard_value(_))) == P.match_segments([P.Wildcard{name}], raw <> tail) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, String>, P.wildcard_value(P.wildcard_param(name, P.decode_segments(tail))), P.decode_segments(tail), wildcard_value_param(name, P.decode_segments(tail))) : {P.wildcard_param(name, P.join_value(E.decode(raw), tail, _)) == P.match_segments([P.Wildcard{name}], raw <> tail) : Maybe<&2, P.Params>}
      %PS.decode_segments_equiv(tail) : {P.wildcard_param(name, P.join_value(E.decode(raw), tail, _)) == P.wildcard_param(name, P.decode_segments(raw <> tail)) : Maybe<&2, P.Params>}
      %PS.decode_segments_equiv(raw <> tail) : {P.wildcard_param(name, P.join_value(E.decode(raw), tail, P.decode_segments_spec(tail))) == P.wildcard_param(name, _) : Maybe<&2, P.Params>}
      {==}

# The cached-row engine agrees with the original structurally recursive
# matcher, including on arbitrary hand-built patterns.
def search_equal(+segs: List<&2, P.Segment>, +paths: List<&2, String>) ->
    {P.search_segments(segs, paths) == P.match_segments(segs, paths) : Maybe<&2, P.Params>}:
  match segs paths:
    case Nil{} Nil{}:
      {==}
    case Nil{} +h <> +t:
      %PS.empty_rows_equiv(h <> t) : {P.row_head(_) == None{} : Maybe<&2, P.Params>}
      {==}
    case P.Static{+raw} <> +rest +h <> +t:
      %Equal.sym(Maybe<&2, P.Params>, P.search_segments(P.Static{raw} <> rest, h <> t), P.row_one(~String.eq, ~String.starts_with, P.Static{raw}, List.is_empty(&2, P.Segment, rest), h <> t, P.match_rows(~String.eq, ~String.starts_with, rest, h <> t), below(P.Static{raw}, rest, h <> t)), rows_head(P.Static{raw}, rest, h <> t)) : {_ == P.match_segments(P.Static{raw} <> rest, h <> t) : Maybe<&2, P.Params>}
      %Equal.sym(Rows, P.match_rows(~String.eq, ~String.starts_with, rest, h <> t), P.search_segments(rest, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, rest, t), rows_cons(rest, h, t)) : {P.row_one(~String.eq, ~String.starts_with, P.Static{raw}, List.is_empty(&2, P.Segment, rest), h <> t, _, below(P.Static{raw}, rest, h <> t)) == P.match_segments(P.Static{raw} <> rest, h <> t) : Maybe<&2, P.Params>}
      Equal.cong(Maybe<&2, P.Params>, Maybe<&2, P.Params>, r => E.choose(Maybe<&2, P.Params>, String.eq(raw, h), u => r, u => None{}), P.search_segments(rest, t), P.match_segments(rest, t), search_equal(rest, t))
    case P.Static{raw} <> rest Nil{}:
      {==}
    case P.Capture{+name, +c, True{}} <> +rest Nil{}:
      search_equal(rest, Nil{})
    case P.Capture{name, c, False{}} <> rest Nil{}:
      {==}
    case P.Capture{+name, +c, +optional} <> +rest +h <> +t:
      %Equal.sym(Maybe<&2, P.Params>, P.search_segments(P.Capture{name, c, optional} <> rest, h <> t), P.row_one(~String.eq, ~String.starts_with, P.Capture{name, c, optional}, List.is_empty(&2, P.Segment, rest), h <> t, P.match_rows(~String.eq, ~String.starts_with, rest, h <> t), below(P.Capture{name, c, optional}, rest, h <> t)), rows_head(P.Capture{name, c, optional}, rest, h <> t)) : {_ == P.match_segments(P.Capture{name, c, optional} <> rest, h <> t) : Maybe<&2, P.Params>}
      %Equal.sym(Rows, P.match_rows(~String.eq, ~String.starts_with, rest, h <> t), P.search_segments(rest, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, rest, t), rows_cons(rest, h, t)) : {P.row_one(~String.eq, ~String.starts_with, P.Capture{name, c, optional}, List.is_empty(&2, P.Segment, rest), h <> t, _, below(P.Capture{name, c, optional}, rest, h <> t)) == P.match_segments(P.Capture{name, c, optional} <> rest, h <> t) : Maybe<&2, P.Params>}
      Equal.cong(Maybe<&2, P.Params>, Maybe<&2, P.Params>, r => Maybe.bind(&2, String, P.Params, E.decode(h), +value => E.choose(Maybe<&2, P.Params>, P.value_ok(c, value), u => P.put_capture(name, value, r), u => None{})), P.search_segments(rest, t), P.match_segments(rest, t), search_equal(rest, t))
    case P.Wildcard{+name} <> Nil{} +p:
      wildcard_search(name, p)
    case P.Wildcard{name} <> h <> t Nil{}:
      {==}
    case P.Wildcard{+name} <> +h <> +t +x <> +y:
      rows_head(P.Wildcard{name}, h <> t, x <> y)
    case P.InteriorWildcard{} <> rest p:
      {==}
    case P.PrefixWildcard{prefix} <> rest p:
      {==}
    case P.Span{+name} <> +rest +p:
      rows_head(P.Span{name}, rest, p)

def some_bool(-A: Data, value: Maybe<&2, A>) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{x}:
      True{}

def none_some(-A: Data, +value: A, e: {None{} == Some{value} : Maybe<&2, A>}) -> Empty:
  false_true(Equal.cong(Maybe<&2, A>, Bool, x => some_bool(A, x), None{}, Some{value}, e))

def first_head(+hits: Rows, +ps: P.Params,
    found: {P.row_head(hits) == Some{ps} : Maybe<&2, P.Params>}) ->
    {P.first_result(hits) == Some{ps} : Maybe<&2, P.Params>}:
  match hits:
    case Nil{}:
      absurd({P.first_result(Nil{}) == Some{ps} : Maybe<&2, P.Params>}, none_some(P.Params, ps, found))
    case Some{qs} <> tail:
      found
    case None{} <> tail:
      absurd({P.first_result(None{} <> tail) == Some{ps} : Maybe<&2, P.Params>}, none_some(P.Params, ps, found))

def interior_match(+rest: List<&2, P.Segment>, +paths: List<&2, String>, +ps: P.Params,
    matched: {P.match_segments(rest, paths) == Some{ps} : Maybe<&2, P.Params>}) ->
    {P.match_segments(P.InteriorWildcard{} <> rest, paths) == Some{ps} : Maybe<&2, P.Params>}:
  %Equal.sym(Maybe<&2, P.Params>, P.search_segments(P.InteriorWildcard{} <> rest, paths), P.row_one(~String.eq, ~String.starts_with, P.InteriorWildcard{}, List.is_empty(&2, P.Segment, rest), paths, P.match_rows(~String.eq, ~String.starts_with, rest, paths), below(P.InteriorWildcard{}, rest, paths)), rows_head(P.InteriorWildcard{}, rest, paths)) : {_ == Some{ps} : Maybe<&2, P.Params>}
  %Equal.sym(Maybe<&2, P.Params>, P.search_segments(rest, paths), Some{ps}, Equal.trans(Maybe<&2, P.Params>, P.search_segments(rest, paths), P.match_segments(rest, paths), Some{ps}, search_equal(rest, paths), matched)) : {P.prefer(_, u => P.row_head(below(P.InteriorWildcard{}, rest, paths))) == Some{ps} : Maybe<&2, P.Params>}
  {==}

def rows_nil(+segs: List<&2, P.Segment>) ->
    {P.match_rows(~String.eq, ~String.starts_with, segs, Nil{}) == [P.search_segments(segs, Nil{})] : Rows}:
  match segs:
    case Nil{}:
      {==}
    case seg <> rest:
      {==}
