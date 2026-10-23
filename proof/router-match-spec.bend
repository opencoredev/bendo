# BND-78: what a route pattern matches, written over raw request paths.
# This reads pattern data but calls none of Pattern's compiling, matching or
# filling helpers. Decoding is the shared strict percent/UTF-8 codec, and
# constraints are the shared constraint semantics.
import Base
import ../src/router/pattern.bend as P
import ../src/router/encoding.bend as E
import ../src/router/constraint.bend as C

# A present capture value: nonempty, Unicode scalars, and the constraint holds.
def accepted(c: C.Constraint, +value: String) -> Bool:
  Bool.not(String.is_empty(value)) && E.scalars(value) && C.accepts(c, value)

def or_else(first: Maybe<&2, P.Params>, second: Unit -> Maybe<&2, P.Params>) -> Maybe<&2, P.Params>:
  match first:
    case Some{ps}:
      Some{ps}
    case None{}:
      second(Unit{})

def with_param(+name: String, +value: String, rest: Maybe<&2, P.Params>) -> Maybe<&2, P.Params>:
  match rest:
    case None{}:
      None{}
    case Some{ps}:
      Some{P.Param{name, value} <> ps}

def keep(ok: Bool, +name: String, +value: String, rest: Maybe<&2, P.Params>) -> Maybe<&2, P.Params>:
  match ok:
    case True{}:
      with_param(name, value, rest)
    case False{}:
      None{}

# One raw segment, decoded exactly once.
def capture(+name: String, +c: C.Constraint, decoded: Maybe<&2, String>, rest: Maybe<&2, P.Params>) -> Maybe<&2, P.Params>:
  match decoded:
    case None{}:
      None{}
    case Some{+value}:
      keep(accepted(c, value), name, value, rest)

def same_text(equal: Bool, rest: Maybe<&2, P.Params>) -> Maybe<&2, P.Params>:
  match equal:
    case True{}:
      rest
    case False{}:
      None{}

# A wildcard decodes every remaining raw segment and joins the values with `/`.
def decoded_all(ps: List<&2, String>) -> Maybe<&2, List<&2, String>>:
  match ps:
    case Nil{}:
      Some{Nil{}}
    case p <> t:
      do Maybe<&2, List<&2, String>>:
        v : String <- E.decode(p)
        vs : List<&2, String> <- decoded_all(t)
        return v <> vs

def wildcard(+name: String, values: Maybe<&2, List<&2, String>>) -> Maybe<&2, P.Params>:
  match values:
    case None{}:
      None{}
    case Some{vs}:
      Some{[P.Param{name, String.join(vs, "/")}]}

def prefix_hit(hit: Bool) -> Maybe<&2, P.Params>:
  match hit:
    case True{}:
      Some{Nil{}}
    case False{}:
      None{}

# `taken` holds a span's raw segments, most recent first. The span value is
# their decoded join, and the remainder must match the rest of the pattern.
def span_here(+name: String, +taken: List<&2, String>, rest: Maybe<&2, P.Params>) -> Maybe<&2, P.Params>:
  match rest:
    case None{}:
      None{}
    case Some{ps}:
      capture(name, C.Any{}, E.decode(String.join(List.reverse(&2, String, taken), "/")), Some{ps})

# Precedence: an optional capture takes a present segment; an interior
# wildcard takes as few whole segments as possible; a span takes as many as
# possible. Results list captures in pattern order.
def matches(segs: List<&2, P.Segment>, paths: List<&2, String>, +taken: List<&2, String>) -> Maybe<&2, P.Params>:
  match segs paths:
    case Nil{} Nil{}:
      Some{Nil{}}
    case Nil{} h <> t:
      None{}
    case P.Static{raw} <> rest Nil{}:
      None{}
    case P.Static{+raw} <> rest +h <> t:
      same_text(String.eq(raw, h), matches(rest, t, Nil{}))
    case P.Capture{name, c, True{}} <> rest Nil{}:
      matches(rest, Nil{}, Nil{})
    case P.Capture{name, c, False{}} <> rest Nil{}:
      None{}
    case P.Capture{+name, +c, optional} <> rest raw <> t:
      capture(name, c, E.decode(raw), matches(rest, t, Nil{}))
    case P.Wildcard{+name} <> Nil{} ps:
      wildcard(name, decoded_all(ps))
    case P.Wildcard{name} <> h <> t ps:
      None{}
    case P.InteriorWildcard{} <> rest Nil{}:
      matches(rest, Nil{}, Nil{})
    case P.InteriorWildcard{} <> +rest +h <> +t:
      or_else(matches(rest, h <> t, Nil{}), u => matches(P.InteriorWildcard{} <> rest, t, Nil{}))
    case P.PrefixWildcard{+prefix} <> Nil{} h <> t:
      prefix_hit(String.starts_with(h, prefix))
    case P.PrefixWildcard{prefix} <> Nil{} Nil{}:
      None{}
    case P.PrefixWildcard{prefix} <> h <> t ps:
      None{}
    case P.Span{name} <> rest Nil{}:
      None{}
    case P.Span{+name} <> +rest +h <> +t:
      or_else(matches(P.Span{name} <> rest, t, h <> taken), u => span_here(name, h <> taken, matches(rest, t, Nil{})))

def only_optional(segs: List<&2, P.Segment>) -> Bool:
  match segs:
    case Nil{}:
      True{}
    case P.Capture{name, c, True{}} <> rest:
      only_optional(rest)
    case _:
      False{}

# The root path "/" is one empty segment, which no capture accepts. It also
# matches a pattern made only of optional captures, with no params.
def root_rule(segs: List<&2, P.Segment>, t: String) -> Maybe<&2, P.Params>:
  match segs t:
    case P.Capture{name, c, True{}} <> rest SNil{}:
      prefix_hit(only_optional(rest))
    case _ _:
      None{}

def match_rest(pattern: P.Pattern, +t: String) -> Maybe<&2, P.Params>:
  match pattern:
    case P.Pattern{+segs}:
      or_else(matches(segs, String.split(t, '/'), Nil{}), u => root_rule(segs, t))

def match_path(pattern: P.Pattern, path: String) -> Maybe<&2, P.Params>:
  match path:
    case SCon{'/', t}:
      match_rest(pattern, t)
    case _:
      None{}
