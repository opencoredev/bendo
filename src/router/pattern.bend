# Pure, copyable route patterns. See docs/router-patterns.md for the grammar.
import Base
import ./encoding.bend as E
import ./constraint.bend as C

type Param is Data:
  Param{name: String, value: String}

def Params() -> Data:
  List<&2, Param>

type Segment is Data:
  Static{raw: String}
  Capture{name: String, constraint: C.Constraint, optional: Bool}
  Wildcard{name: String}
  InteriorWildcard{}
  PrefixWildcard{prefix: String}
  Span{name: String}

type Pattern is Data:
  Pattern{segments: List<&2, Segment>}

type ErrorKind is Data:
  MissingSlash{}
  EmptyName{}
  InvalidName{}
  DuplicateName{}
  UnbalancedBraces{}
  UnknownConstraint{}
  InvalidClass{}
  WildcardNotLast{}
  OptionalNotLast{}
  InvalidStatic{}

type PatternError is Data:
  PatternError{kind: ErrorKind, segment: String}

def error_kind(kind: ErrorKind) -> String:
  match kind:
    case MissingSlash{}:
      "MissingSlash"
    case EmptyName{}:
      "EmptyName"
    case InvalidName{}:
      "InvalidName"
    case DuplicateName{}:
      "DuplicateName"
    case UnbalancedBraces{}:
      "UnbalancedBraces"
    case UnknownConstraint{}:
      "UnknownConstraint"
    case InvalidClass{}:
      "InvalidClass"
    case WildcardNotLast{}:
      "WildcardNotLast"
    case OptionalNotLast{}:
      "OptionalNotLast"
    case InvalidStatic{}:
      "InvalidStatic"

def error_message(e: PatternError) -> String:
  PatternError{kind, segment} = e
  error_kind(kind) ++ ": " ++ segment

def name_tail(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+n}, t}:
      (C.alpha(n) || C.digit(n) || U32.is_eq(n, 95)) && name_tail(t)

def name_ok(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+n}, t}:
      (C.alpha(n) || U32.is_eq(n, 95)) && name_tail(t)

# Split the name from its optional/constraint suffix without losing delimiters.
def split_name(s: String) -> C.Split:
  match s:
    case SNil{}:
      C.Split{"", ""}
    case SCon{'{', t}:
      C.Split{"", SCon{'{', t}}
    case SCon{'?', t}:
      C.Split{"", SCon{'?', t}}
    case SCon{h, t}:
      C.split_cons(h, split_name(t))

def constraint_result(r: Maybe<&2, C.Constraint>, +body: String, name: String, optional: Bool) -> Result<&2, &2, PatternError, Segment>:
  match r:
    case Some{c}:
      Done{Capture{name, c, optional}}
    case None{}:
      E.choose(Result<&2, &2, PatternError, Segment>, String.starts_with(body, "["), u => (
        Fail{PatternError{InvalidClass{}, body}}
      ), u => (
        Fail{PatternError{UnknownConstraint{}, body}}
      ))

def constrained(+suffix: String, +name: String, +optional: Bool) -> Result<&2, &2, PatternError, Segment>:
  E.choose(Result<&2, &2, PatternError, Segment>, String.starts_with(suffix, "{") && String.ends_with(suffix, "}"), u => (
    +body = String.take(String.drop(suffix, 1n), Nat.sub(String.length(suffix), 2n))
    E.choose(Result<&2, &2, PatternError, Segment>, String.eq(body, ".+") && Bool.not(optional), u => Done{Span{name}}, u => constraint_result(C.compile(body), body, name, optional))
  ), u => (Fail{PatternError{UnbalancedBraces{}, suffix}}))

def capture_suffix(+suffix: String, +name: String) -> Result<&2, &2, PatternError, Segment>:
  E.choose(Result<&2, &2, PatternError, Segment>, String.is_empty(suffix), u => (
    Done{Capture{name, C.Any{}, False{}}}
  ), u => (
    E.choose(Result<&2, &2, PatternError, Segment>, String.eq(suffix, "?"), u => (
      Done{Capture{name, C.Any{}, True{}}}
    ), u => (
      E.choose(Result<&2, &2, PatternError, Segment>, String.ends_with(suffix, "?"), u => (
        constrained(String.take(suffix, Nat.sub(String.length(suffix), 1n)), name, True{})
      ), u => (constrained(suffix, name, False{})))
    ))
  ))

def capture(pair: C.Split) -> Result<&2, &2, PatternError, Segment>:
  C.Split{+name, suffix} = pair
  E.choose(Result<&2, &2, PatternError, Segment>, String.is_empty(name), u => (
    Fail{PatternError{EmptyName{}, name}}
  ), u => (
    E.choose(Result<&2, &2, PatternError, Segment>, name_ok(name), u => (
      capture_suffix(suffix, name)
    ), u => (Fail{PatternError{InvalidName{}, name}}))
  ))

def static_ok(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+n}, t}:
      E.scalar(n) && Bool.not(U32.is_eq(n, 42) || U32.is_eq(n, 123) || U32.is_eq(n, 125) || U32.is_eq(n, 63) || U32.is_eq(n, 35)) && static_ok(t)

def compile_static(+raw: String) -> Result<&2, &2, PatternError, Segment>:
  E.choose(Result<&2, &2, PatternError, Segment>, String.ends_with(raw, "*"), u => (
    +prefix = String.take(raw, Nat.sub(String.length(raw), 1n))
    E.choose(Result<&2, &2, PatternError, Segment>, static_ok(prefix), u => Done{PrefixWildcard{prefix}}, u => Fail{PatternError{InvalidStatic{}, raw}})
  ), u => (
    E.choose(Result<&2, &2, PatternError, Segment>, static_ok(raw), u => Done{Static{raw}}, u => Fail{PatternError{InvalidStatic{}, raw}})
  ))

def compile_head(+h: Char, +t: String) -> Result<&2, &2, PatternError, Segment>:
  E.choose(Result<&2, &2, PatternError, Segment>, Char.is_eq(h, ':'), u => (
    capture(split_name(t))
  ), u => (
    E.choose(Result<&2, &2, PatternError, Segment>, Char.is_eq(h, '*'), u => (
      E.choose(Result<&2, &2, PatternError, Segment>, String.is_empty(t), u => Done{Wildcard{"*"}}, u => (
        E.choose(Result<&2, &2, PatternError, Segment>, name_ok(t), u => Done{Wildcard{t}}, u => Fail{PatternError{InvalidName{}, t}})
      ))
    ), u => (
      compile_static(SCon{h, t})
    ))
  ))

def compile_segment(s: String) -> Result<&2, &2, PatternError, Segment>:
  match s:
    case SNil{}:
      Done{Static{SNil{}}}
    case SCon{h, t}:
      compile_head(h, t)

def seen(names: List<&2, String>, +name: String) -> Bool:
  match names:
    case Nil{}:
      False{}
    case h <> t:
      String.eq(h, name) || seen(t, name)

def segment_name(s: Segment) -> Maybe<&2, String>:
  match s:
    case Static{raw}:
      None{}
    case Capture{name, c, optional}:
      Some{name}
    case Wildcard{name}:
      Some{name}
    case Span{name}:
      Some{name}
    case _:
      None{}

def terminal(s: Segment) -> Bool:
  match s:
    case Static{raw}:
      False{}
    case Capture{name, c, optional}:
      optional
    case Wildcard{name}:
      True{}
    case PrefixWildcard{prefix}:
      True{}
    case _:
      False{}

def terminal_error(s: Segment) -> ErrorKind:
  match s:
    case Wildcard{name}:
      WildcardNotLast{}
    case PrefixWildcard{prefix}:
      WildcardNotLast{}
    case _:
      OptionalNotLast{}

def add_name(name: Maybe<&2, String>, names: List<&2, String>) -> List<&2, String>:
  match name:
    case None{}:
      names
    case Some{n}:
      n <> names

def duplicate(name: Maybe<&2, String>, names: List<&2, String>) -> Bool:
  match name:
    case None{}:
      False{}
    case Some{n}:
      seen(names, n)

def optional_sources(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case +h <> t:
      String.starts_with(h, ":") && String.ends_with(h, "?") && optional_sources(t)

def invalid_tail(seg: Segment, +rest: List<&2, String>) -> Bool:
  match seg:
    case Capture{name, c, True{}}:
      Bool.not(optional_sources(rest))
    case Wildcard{"*"}:
      False{}
    case _:
      terminal(seg) && Bool.not(List.is_empty(&2, String, rest))

def located(seg: Segment, rest: List<&2, String>) -> Segment:
  match seg rest:
    case Wildcard{"*"} h <> t:
      InteriorWildcard{}
    case s _:
      s

# One shrinking segment-list traversal; constraints themselves are pure data.
def compile_segments(xs: List<&2, String>, +names: List<&2, String>) -> Result<&2, &2, PatternError, List<&2, Segment>>:
  match xs:
    case Nil{}:
      Done{Nil{}}
    case +raw <> +rest:
      do Result<&2, &2, PatternError, List<&2, Segment>>:
        parsed : Segment <- compile_segment(raw)
        +seg : Segment = located(parsed, rest)
        E.choose(Result<&2, &2, PatternError, List<&2, Segment>>, duplicate(segment_name(seg), names), u => (
          Fail{PatternError{DuplicateName{}, raw}}
        ), u => (
          E.choose(Result<&2, &2, PatternError, List<&2, Segment>>, invalid_tail(seg, rest), u => (
            Fail{PatternError{terminal_error(seg), raw}}
          ), u => (
            do Result<&2, &2, PatternError, List<&2, Segment>>:
              tail : List<&2, Segment> <- compile_segments(rest, add_name(segment_name(seg), names))
              return seg <> tail
          ))
        ))

def path_segments(s: String) -> List<&2, String>:
  String.split(s, '/')

def compile_body(t: String) -> Result<&2, &2, PatternError, Pattern>:
  do Result<&2, &2, PatternError, Pattern>:
    xs : List<&2, Segment> <- compile_segments(path_segments(t), Nil{})
    return Pattern{xs}

def compile(source: String) -> Result<&2, &2, PatternError, Pattern>:
  match source:
    case SNil{}:
      Fail{PatternError{MissingSlash{}, SNil{}}}
    case "*":
      compile_body("*")
    case SCon{+h, +t}:
      E.choose(Result<&2, &2, PatternError, Pattern>, Char.is_eq(h, '/'), u => compile_body(t), u => Fail{PatternError{MissingSlash{}, SCon{h, t}}})

def put_capture(name: String, value: String, tail: Maybe<&2, Params>) -> Maybe<&2, Params>:
  do Maybe<&2, Params>:
    ps : Params <- tail
    return Param{name, value} <> ps

def value_ok(c: C.Constraint, +value: String) -> Bool:
  Bool.not(String.is_empty(value)) && E.scalars(value) && C.accepts(c, value)

def prefer(hit: Maybe<&2, Params>, next: Unit -> Maybe<&2, Params>) -> Maybe<&2, Params>:
  match hit:
    case Some{ps}:
      Some{ps}
    case None{}:
      next(Unit{})

def span_result(name: String, raw: String, tail: Maybe<&2, Params>) -> Maybe<&2, Params>:
  do Maybe<&2, Params>:
    +value : String <- E.decode(raw)
    E.choose(Maybe<&2, Params>, value_ok(C.Any{}, value), u => put_capture(name, value, tail), u => None{})

# One result for each suffix of the request path, including the empty suffix.
# Each pattern segment computes its row from the next segment's row. Glob
# choices reuse these results instead of recursively rematching a suffix.
def first_result(hits: List<&2, Maybe<&2, Params>>) -> Maybe<&2, Params>:
  match hits:
    case Nil{}:
      None{}
    case Some{ps} <> rest:
      Some{ps}
    case None{} <> rest:
      first_result(rest)

def row_head(hits: List<&2, Maybe<&2, Params>>) -> Maybe<&2, Params>:
  match hits:
    case Nil{}:
      None{}
    case h <> t:
      h

def empty_rows(paths: List<&2, String>) -> List<&2, Maybe<&2, Params>>:
  match paths:
    case Nil{}:
      [Some{Nil{}}]
    case h <> t:
      None{} <> empty_rows(t)

# The next-row cells are already computed. Try increasing nonempty prefixes;
# each alternative only decodes its prefix and reads one cell.
def span_options(paths: List<&2, String>, hits: List<&2, Maybe<&2, Params>>, +name: String, +taken: List<&2, String>) -> Maybe<&2, Params>:
  match paths hits:
    case raw <> tail old <> +next:
      +consumed = List.append(&2, String, taken, [raw])
      prefer(span_result(name, String.join(consumed, "/"), row_head(next)), u => span_options(tail, next, name, consumed))
    case _ _:
      None{}

def row_one(seg: Segment, +last: Bool, +paths: List<&2, String>, +hits: List<&2, Maybe<&2, Params>>) -> Maybe<&2, Params>:
  match seg paths hits:
    case Static{raw} h <> tail old <> next:
      E.choose(Maybe<&2, Params>, String.eq(raw, h), u => row_head(next), u => None{})
    case Capture{name, c, True{}} Nil{} cells:
      row_head(cells)
    case Capture{name, +c, optional} raw <> tail old <> next:
      do Maybe<&2, Params>:
        +value : String <- E.decode(raw)
        E.choose(Maybe<&2, Params>, value_ok(c, value), u => put_capture(name, value, row_head(next)), u => None{})
    case Wildcard{name} ps cells:
      E.choose(Maybe<&2, Params>, last, u => (
        do Maybe<&2, Params>:
          value : String <- E.decode(String.join(ps, "/"))
          return [Param{name, value}]
      ), u => None{})
    case InteriorWildcard{} ps cells:
      first_result(cells)
    case PrefixWildcard{prefix} raw <> tail cells:
      E.choose(Maybe<&2, Params>, last && String.starts_with(raw, prefix), u => Some{Nil{}}, u => None{})
    case Span{name} ps cells:
      span_options(ps, cells, name, Nil{})
    case _ _ _:
      None{}

def rows_for(+seg: Segment, +last: Bool, +paths: List<&2, String>, +hits: List<&2, Maybe<&2, Params>>) -> List<&2, Maybe<&2, Params>>:
  match paths hits:
    case Nil{} cells:
      [row_one(seg, last, Nil{}, cells)]
    case h <> +tail old <> +next:
      row_one(seg, last, paths, hits) <> rows_for(seg, last, tail, next)
    case h <> tail Nil{}:
      Nil{}

def match_rows(segs: List<&2, Segment>, +paths: List<&2, String>) -> List<&2, Maybe<&2, Params>>:
  match segs:
    case Nil{}:
      empty_rows(paths)
    case seg <> +rest:
      rows_for(seg, List.is_empty(&2, Segment, rest), paths, match_rows(rest, paths))

def search_segments(segs: List<&2, Segment>, paths: List<&2, String>) -> Maybe<&2, Params>:
  row_head(match_rows(segs, paths))

def match_segments(segs: List<&2, Segment>, paths: List<&2, String>) -> Maybe<&2, Params>:
  match segs paths:
    case Nil{} Nil{}:
      Some{Nil{}}
    case Nil{} h <> t:
      None{}
    case Wildcard{name} <> Nil{} ps:
      do Maybe<&2, Params>:
        value : String <- E.decode(String.join(ps, "/"))
        return [Param{name, value}]
    case Capture{name, c, True{}} <> rest Nil{}:
      match_segments(rest, Nil{})
    case Capture{name, +c, optional} <> rest raw <> tail:
      do Maybe<&2, Params>:
        +value : String <- E.decode(raw)
        E.choose(Maybe<&2, Params>, value_ok(c, value), u => (
          put_capture(name, value, match_segments(rest, tail))
        ), u => (None{}))
    case Static{raw} <> rest h <> tail:
      E.choose(Maybe<&2, Params>, String.eq(raw, h), u => (
        match_segments(rest, tail)
      ), u => (None{}))
    case InteriorWildcard{} <> rest ps:
      search_segments(InteriorWildcard{} <> rest, ps)
    case PrefixWildcard{prefix} <> rest ps:
      search_segments(PrefixWildcard{prefix} <> rest, ps)
    case Span{name} <> rest ps:
      search_segments(Span{name} <> rest, ps)
    case _ _:
      None{}

def all_optional(segs: List<&2, Segment>) -> Bool:
  match segs:
    case Nil{}:
      True{}
    case Capture{name, c, True{}} <> rest:
      all_optional(rest)
    case _:
      False{}

def match_path(pattern: Pattern, path: String) -> Maybe<&2, Params>:
  match pattern path:
    case Pattern{Capture{name, c, True{}} <> +rest} "/":
      E.choose(Maybe<&2, Params>, all_optional(rest), u => Some{Nil{}}, u => match_segments(Capture{name, c, True{}} <> rest, [""]))
    case Pattern{segs} SCon{'/', t}:
      match_segments(segs, path_segments(t))
    case _ _:
      None{}

# Filling checks ordered names and value validity, independently of matching.
def fill_segments(segs: List<&2, Segment>, ps: Params) -> Maybe<&2, List<&2, String>>:
  match segs ps:
    case Nil{} Nil{}:
      Some{Nil{}}
    case Static{raw} <> rest values:
      do Maybe<&2, List<&2, String>>:
        tail : List<&2, String> <- fill_segments(rest, values)
        return raw <> tail
    case Capture{name, c, True{}} <> rest Nil{}:
      fill_segments(rest, Nil{})
    case Capture{name, c, optional} <> rest Param{key, +value} <> tail:
      E.choose(Maybe<&2, List<&2, String>>, String.eq(name, key) && value_ok(c, value), u => (
        do Maybe<&2, List<&2, String>>:
          xs : List<&2, String> <- fill_segments(rest, tail)
          return E.encode(value) <> xs
      ), u => (None{}))
    case InteriorWildcard{} <> rest values:
      fill_segments(rest, values)
    case PrefixWildcard{prefix} <> Nil{} Nil{}:
      Some{[prefix]}
    case Span{name} <> rest Param{key, +value} <> tail:
      E.choose(Maybe<&2, List<&2, String>>, String.eq(name, key) && value_ok(C.Any{}, value), u => (
        do Maybe<&2, List<&2, String>>:
          xs : List<&2, String> <- fill_segments(rest, tail)
          return E.encode(value) <> xs
      ), u => None{})
    case Wildcard{name} <> Nil{} Param{key, +value} <> Nil{}:
      E.choose(Maybe<&2, List<&2, String>>, String.eq(name, key) && E.scalars(value), u => (
        Some{[E.encode(value)]}
      ), u => (None{}))
    case _ _:
      None{}

def fill(pattern: Pattern, ps: Params) -> Maybe<&2, String>:
  Pattern{segs} = pattern
  do Maybe<&2, String>:
    xs : List<&2, String> <- fill_segments(segs, ps)
    return "/" ++ String.join(xs, "/")

# This predicate never calls fill or match_path.
def admissible_segments(segs: List<&2, Segment>, ps: Params) -> Bool:
  match segs ps:
    case Nil{} Nil{}:
      True{}
    case Static{raw} <> rest values:
      admissible_segments(rest, values)
    case Capture{name, c, True{}} <> rest Nil{}:
      admissible_segments(rest, Nil{})
    case Capture{name, c, optional} <> rest Param{key, +value} <> tail:
      String.eq(name, key) && value_ok(c, value) && admissible_segments(rest, tail)
    case InteriorWildcard{} <> rest values:
      admissible_segments(rest, values)
    case PrefixWildcard{prefix} <> Nil{} Nil{}:
      True{}
    case Span{name} <> rest Param{key, +value} <> tail:
      String.eq(name, key) && value_ok(C.Any{}, value) && admissible_segments(rest, tail)
    case Wildcard{name} <> Nil{} Param{key, +value} <> Nil{}:
      String.eq(name, key) && E.scalars(value)
    case _ _:
      False{}

def admissible(pattern: Pattern, ps: Params) -> Bool:
  Pattern{segs} = pattern
  admissible_segments(segs, ps)
