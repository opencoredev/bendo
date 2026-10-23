# Constructive lemmas for the independently admissible pattern assignment law.
import Base
import ./pattern.bend as P
import ./encoding.bend as E
import ./constraint.bend as C
import ./octet-proofs.bend as OctetProof
import ./codec-bits.bend as CodecBits

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
law split_prefix:
  for +s: String
  for +tail: String
  for clean: {no_slash(s) == True{} : Bool}
  {P.path_segments(s ++ ("/" ++ tail)) == s <> P.path_segments(tail) : List<&2, String>}

def split_prefix(s, tail, clean):
  match s:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      +e = clean
      cut = not_true(Char.is_eq(h, '/'), and_left(Bool.not(Char.is_eq(h, '/')), no_slash(t), e))
      rest = and_right(Bool.not(Char.is_eq(h, '/')), no_slash(t), e)
      %Equal.sym(Bool, Char.is_eq(h, '/'), False{}, cut) : {String.split.fin(h, P.path_segments(t ++ ("/" ++ tail)), _) == SCon{h, t} <> P.path_segments(tail) : List<&2, String>}
      %Equal.sym(List<&2, String>, P.path_segments(t ++ ("/" ++ tail)), t <> P.path_segments(tail), split_prefix(t, tail, rest)) : {String.split.push(h, _) == SCon{h, t} <> P.path_segments(tail) : List<&2, String>}
      {==}

# A single slash-free segment, including the empty segment, is preserved.
law split_single:
  for +s: String
  for clean: {no_slash(s) == True{} : Bool}
  {P.path_segments(s) == [s] : List<&2, String>}

def split_single(s, clean):
  match s:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      +e = clean
      cut = not_true(Char.is_eq(h, '/'), and_left(Bool.not(Char.is_eq(h, '/')), no_slash(t), e))
      rest = and_right(Bool.not(Char.is_eq(h, '/')), no_slash(t), e)
      %Equal.sym(Bool, Char.is_eq(h, '/'), False{}, cut) : {String.split.fin(h, P.path_segments(t), _) == [SCon{h, t}] : List<&2, String>}
      %Equal.sym(List<&2, String>, P.path_segments(t), [t], split_single(t, rest)) : {String.split.push(h, _) == [SCon{h, t}] : List<&2, String>}
      {==}

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
law clean_split:
  for +s: String
  {clean_segments(P.path_segments(s)) == True{} : Bool}

def clean_split(s):
  match s:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      clean_split_fin(h, P.path_segments(t), Char.is_eq(h, '/'), {==}, clean_split(t))

# Splitting the joined nonempty list recovers empty and nonempty segments alike.
law split_join:
  for +tail: List<&2, String>
  for +head: String
  for clean: {clean_segments(head <> tail) == True{} : Bool}
  {P.path_segments(String.join(head <> tail, "/")) == head <> tail : List<&2, String>}

def split_join(tail, head, clean):
  match tail:
    case Nil{}:
      split_single(head, and_left(no_slash(head), True{}, clean))
    case +h <> +t:
      +e = clean
      first = and_left(no_slash(head), clean_segments(h <> t), e)
      rest = and_right(no_slash(head), clean_segments(h <> t), e)
      %Equal.sym(List<&2, String>, P.path_segments(head ++ ("/" ++ String.join(h <> t, "/"))), head <> P.path_segments(String.join(h <> t, "/")), split_prefix(head, String.join(h <> t, "/"), first)) : {_ == head <> h <> t : List<&2, String>}
      %Equal.sym(List<&2, String>, P.path_segments(String.join(h <> t, "/")), h <> t, split_join(t, h, rest)) : {head <> _ == head <> h <> t : List<&2, String>}
      {==}

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

def fill_segments_success(segs, ps, admitted):
  match segs ps:
    case Nil{} Nil{}:
      (Nil{}, {==})
    case P.Static{+raw} <> +rest +values:
      fill_static(raw, rest, values, fill_segments_success(rest, values, admitted))
    case P.Capture{name, c, True{}} <> Nil{} Nil{}:
      (Nil{}, {==})
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
    case P.Capture{name, c, True{}} <> h <> t Nil{}:
      absurd(&xs: List<&2, String> -> {P.fill_segments(P.Capture{name, c, True{}} <> h <> t, Nil{}) == Some{xs} : Maybe<&2, List<&2, String>>}, false_true(admitted))
    case P.Wildcard{name} <> Nil{} Nil{}:
      absurd(&xs: List<&2, String> -> {P.fill_segments([P.Wildcard{name}], Nil{}) == Some{xs} : Maybe<&2, List<&2, String>>}, false_true(admitted))
    case P.Wildcard{name} <> Nil{} h <> j <> t:
      absurd(&xs: List<&2, String> -> {P.fill_segments([P.Wildcard{name}], h <> j <> t) == Some{xs} : Maybe<&2, List<&2, String>>}, false_true(admitted))
    case P.Wildcard{name} <> h <> t values:
      absurd(&xs: List<&2, String> -> {P.fill_segments(P.Wildcard{name} <> h <> t, values) == Some{xs} : Maybe<&2, List<&2, String>>}, false_true(admitted))

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
