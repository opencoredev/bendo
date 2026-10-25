# BND-83: which route sources compile, and to which pattern, read from the
# syntax in docs/router-patterns.md. This calls none of Pattern's helpers. It
# uses Pattern's data types, Base strings, the shared Unicode scalar test, and
# the constraint module's grammar for the text inside `{...}`.
import Base
import ../src/router/pattern.bend as P
import ../src/router/constraint.bend as C
import ../src/router/encoding.bend as E

# Names are ASCII `[A-Za-z_][A-Za-z0-9_]*`.
def letter(+n: U32) -> Bool:
  ((n >= 97 : U32) && (n <= 122 : U32)) || ((n >= 65 : U32) && (n <= 90 : U32))

def name_char(+n: U32) -> Bool:
  letter(n) || ((n >= 48 : U32) && (n <= 57 : U32)) || U32.is_eq(n, 95)

def name_rest(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+n}, t}:
      name_char(n) && name_rest(t)

def valid_name(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+n}, t}:
      (letter(n) || U32.is_eq(n, 95)) && name_rest(t)

# Static text holds Unicode scalars other than `*`, `{`, `}`, `?` and `#`.
def static_char(+n: U32) -> Bool:
  E.scalar(n) && Bool.not(U32.is_eq(n, 42) || U32.is_eq(n, 123) || U32.is_eq(n, 125) || U32.is_eq(n, 63) || U32.is_eq(n, 35))

def static_text(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+n}, t}:
      static_char(n) && static_text(t)

# A capture source after its `:`. The name runs up to the first `{` or `?`,
# and the suffix starts there.
type Cut is Data:
  Cut{name: String, suffix: String}

def cut_cons(h: Char, c: Cut) -> Cut:
  match c:
    case Cut{name, suffix}:
      Cut{SCon{h, name}, suffix}

def cut(s: String) -> Cut:
  match s:
    case SNil{}:
      Cut{"", ""}
    case SCon{'{', t}:
      Cut{"", SCon{'{', t}}
    case SCon{'?', t}:
      Cut{"", SCon{'?', t}}
    case SCon{h, t}:
      cut_cons(h, cut(t))

# The text inside a suffix's outer braces.
def inside(+s: String) -> String:
  String.take(String.drop(s, 1n), Nat.sub(String.length(s), 2n))

def known(c: Maybe<&2, C.Constraint>, +name: String, +optional: Bool) -> Maybe<&2, P.Segment>:
  match c:
    case None{}:
      None{}
    case Some{k}:
      Some{P.Capture{name, k, optional}}

# `{.+}` is a span, which cannot be optional. Other text is a constraint.
def braced(span: Bool, +body: String, +name: String, +optional: Bool) -> Maybe<&2, P.Segment>:
  match span:
    case True{}:
      match optional:
        case True{}:
          None{}
        case False{}:
          Some{P.Span{name}}
    case False{}:
      known(C.compile(body), name, optional)

def closed(ok: Bool, +s: String, +name: String, +optional: Bool) -> Maybe<&2, P.Segment>:
  match ok:
    case False{}:
      None{}
    case True{}:
      braced(String.eq(inside(s), ".+"), inside(s), name, optional)

# `{c}`: the suffix opens with `{` and closes with `}`.
def constraint(+s: String, +name: String, +optional: Bool) -> Maybe<&2, P.Segment>:
  closed(String.starts_with(s, "{") && String.ends_with(s, "}"), s, name, optional)

def marked(question: Bool, optional: Bool, +s: String, +name: String) -> Maybe<&2, P.Segment>:
  match question:
    case True{}:
      Some{P.Capture{name, C.Any{}, True{}}}
    case False{}:
      match optional:
        case True{}:
          constraint(String.take(s, Nat.sub(String.length(s), 1n)), name, True{})
        case False{}:
          constraint(s, name, False{})

# After the name comes nothing, `?`, `{c}` or `{c}?`.
def suffix(s: String, +name: String) -> Maybe<&2, P.Segment>:
  match s:
    case SNil{}:
      Some{P.Capture{name, C.Any{}, False{}}}
    case SCon{+h, +t}:
      marked(String.eq(SCon{h, t}, "?"), String.ends_with(SCon{h, t}, "?"), SCon{h, t}, name)

def named(ok: Bool, +name: String, +s: String) -> Maybe<&2, P.Segment>:
  match ok:
    case False{}:
      None{}
    case True{}:
      suffix(s, name)

def capture(c: Cut) -> Maybe<&2, P.Segment>:
  match c:
    case Cut{+name, +s}:
      named(valid_name(name), name, s)

# `*` alone is the final wildcard, or an interior one when segments follow.
def bare(last: Bool) -> P.Segment:
  match last:
    case True{}:
      P.Wildcard{"*"}
    case False{}:
      P.InteriorWildcard{}

def wild(ok: Bool, +name: String) -> Maybe<&2, P.Segment>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{P.Wildcard{name}}

# `*name` is a named wildcard.
def star(t: String, +last: Bool) -> Maybe<&2, P.Segment>:
  match t:
    case SNil{}:
      Some{bare(last)}
    case SCon{+h, +u}:
      wild(valid_name(SCon{h, u}), SCon{h, u})

def text(ok: Bool, +raw: String) -> Maybe<&2, P.Segment>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{P.Static{raw}}

def prefix(ok: Bool, +p: String) -> Maybe<&2, P.Segment>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{P.PrefixWildcard{p}}

def plain(starred: Bool, +raw: String) -> Maybe<&2, P.Segment>:
  match starred:
    case True{}:
      prefix(static_text(String.take(raw, Nat.sub(String.length(raw), 1n))), String.take(raw, Nat.sub(String.length(raw), 1n)))
    case False{}:
      text(static_text(raw), raw)

# `text*` is a prefix wildcard. Other text is a static segment, kept raw.
def static(+raw: String) -> Maybe<&2, P.Segment>:
  plain(String.ends_with(raw, "*"), raw)

def lead(colon: Bool, starred: Bool, +h: Char, +t: String, +last: Bool) -> Maybe<&2, P.Segment>:
  match colon:
    case True{}:
      capture(cut(t))
    case False{}:
      match starred:
        case True{}:
          star(t, last)
        case False{}:
          static(SCon{h, t})

# One source segment. `last` says whether it ends the pattern. An empty
# segment is empty static text, which keeps repeated and trailing slashes.
def piece(raw: String, +last: Bool) -> Maybe<&2, P.Segment>:
  match raw:
    case SNil{}:
      Some{P.Static{""}}
    case SCon{+h, +t}:
      lead(Char.is_eq(h, ':'), Char.is_eq(h, '*'), h, t, last)

def both(m: Maybe<&2, P.Segment>, rest: Maybe<&2, List<&2, P.Segment>>) -> Maybe<&2, List<&2, P.Segment>>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      match rest:
        case None{}:
          None{}
        case Some{ss}:
          Some{s <> ss}

def pieces(raws: List<&2, String>) -> Maybe<&2, List<&2, P.Segment>>:
  match raws:
    case Nil{}:
      Some{Nil{}}
    case raw <> +rest:
      both(piece(raw, List.is_empty(&2, String, rest)), pieces(rest))

# Captures, wildcards and spans carry names.
def label(s: P.Segment) -> Maybe<&2, String>:
  match s:
    case P.Static{raw}:
      None{}
    case P.Capture{name, c, optional}:
      Some{name}
    case P.Wildcard{name}:
      Some{name}
    case P.InteriorWildcard{}:
      None{}
    case P.PrefixWildcard{p}:
      None{}
    case P.Span{name}:
      Some{name}

def used(names: List<&2, String>, +n: String) -> Bool:
  match names:
    case Nil{}:
      False{}
    case h <> t:
      String.eq(h, n) || used(t, n)

def fresh(n: Maybe<&2, String>, names: List<&2, String>) -> Bool:
  match n:
    case None{}:
      True{}
    case Some{x}:
      Bool.not(used(names, x))

def remember(n: Maybe<&2, String>, names: List<&2, String>) -> List<&2, String>:
  match n:
    case None{}:
      names
    case Some{x}:
      x <> names

def optional(s: P.Segment) -> Bool:
  match s:
    case P.Static{raw}:
      False{}
    case P.Capture{name, c, o}:
      o
    case P.Wildcard{name}:
      False{}
    case P.InteriorWildcard{}:
      False{}
    case P.PrefixWildcard{p}:
      False{}
    case P.Span{name}:
      False{}

def all_optional(segs: List<&2, P.Segment>) -> Bool:
  match segs:
    case Nil{}:
      True{}
    case s <> t:
      optional(s) && all_optional(t)

# Named and prefix wildcards end the pattern. Only optional captures follow
# an optional capture.
def placed(s: P.Segment, after: List<&2, P.Segment>) -> Bool:
  match s:
    case P.Static{raw}:
      True{}
    case P.Capture{name, c, o}:
      match o:
        case True{}:
          all_optional(after)
        case False{}:
          True{}
    case P.Wildcard{name}:
      List.is_empty(&2, P.Segment, after)
    case P.InteriorWildcard{}:
      True{}
    case P.PrefixWildcard{p}:
      List.is_empty(&2, P.Segment, after)
    case P.Span{name}:
      True{}

# Every segment is placed and no name repeats an earlier one.
def rules(segs: List<&2, P.Segment>, +names: List<&2, String>) -> Bool:
  match segs:
    case Nil{}:
      True{}
    case +s <> +rest:
      fresh(label(s), names) && placed(s, rest) && rules(rest, remember(label(s), names))

def no_percent(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+n}, t}:
      Bool.not(U32.is_eq(n, 37)) && no_percent(t)

def has_span(segs: List<&2, P.Segment>) -> Bool:
  match segs:
    case Nil{}:
      False{}
    case P.Span{name} <> t:
      True{}
    case s <> t:
      has_span(t)

def wildcard(s: P.Segment) -> Bool:
  match s:
    case P.Static{raw}:
      False{}
    case P.Capture{name, c, o}:
      False{}
    case P.Wildcard{name}:
      True{}
    case P.InteriorWildcard{}:
      True{}
    case P.PrefixWildcard{p}:
      True{}
    case P.Span{name}:
      False{}

def no_wildcard(segs: List<&2, P.Segment>) -> Bool:
  match segs:
    case Nil{}:
      True{}
    case s <> t:
      Bool.not(wildcard(s)) && no_wildcard(t)

# Statics without `%` and captures.
def fixed(segs: List<&2, P.Segment>) -> Bool:
  match segs:
    case Nil{}:
      True{}
    case P.Static{raw} <> t:
      no_percent(raw) && fixed(t)
    case P.Capture{name, c, o} <> t:
      fixed(t)
    case s <> t:
      False{}

# A static anchor without `%`, then fixed segments.
def anchored(segs: List<&2, P.Segment>) -> Bool:
  match segs:
    case P.Static{raw} <> t:
      no_percent(raw) && fixed(t)
    case _:
      False{}

def after_span(segs: List<&2, P.Segment>) -> Bool:
  match segs:
    case Nil{}:
      True{}
    case P.Span{name} <> t:
      anchored(t)
    case s <> t:
      after_span(t)

# A pattern with a span has no wildcard, and its span is followed by an
# anchor, so there is no second span.
def spans(+segs: List<&2, P.Segment>) -> Bool:
  Bool.not(has_span(segs)) || (no_wildcard(segs) && after_span(segs))

def accept(ok: Bool, +segs: List<&2, P.Segment>) -> Maybe<&2, P.Pattern>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{P.Pattern{segs}}

def checked(m: Maybe<&2, List<&2, P.Segment>>) -> Maybe<&2, P.Pattern>:
  match m:
    case None{}:
      None{}
    case Some{+segs}:
      accept(rules(segs, Nil{}) && spans(segs), segs)

# The text after the leading slash, split at every `/`.
def body(t: String) -> Maybe<&2, P.Pattern>:
  checked(pieces(String.split(t, '/')))

def slash(ok: Bool, +t: String) -> Maybe<&2, P.Pattern>:
  match ok:
    case False{}:
      None{}
    case True{}:
      body(t)

# A route source starts with `/`. Bare `*` is an alias for `/*`.
def compile(source: String) -> Maybe<&2, P.Pattern>:
  match source:
    case SNil{}:
      None{}
    case "*":
      body("*")
    case SCon{+h, +t}:
      slash(Char.is_eq(h, '/'), t)

# What a compile result promises, without its error.
def accepted(r: Result<&2, &2, P.PatternError, P.Pattern>) -> Maybe<&2, P.Pattern>:
  match r:
    case Done{p}:
      Some{p}
    case Fail{e}:
      None{}
