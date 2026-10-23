# Constructive lemmas for the independently admissible pattern assignment law.
import Base
import ./pattern.bend as P
import ./encoding.bend as E
import ./constraint.bend as C

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
