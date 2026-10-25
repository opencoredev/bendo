# BND-86: what a mounted route answers, read from docs/router-compose.md,
# docs/router-patterns.md and docs/router-methods.md.
#
# This calls no composition, compilation, splitting or matching helper of
# the router. It reads Pattern's data types, Base strings, the shared
# percent/UTF-8 codec, and two independent specifications already proven
# equal to the router: the source grammar of proof/router-compile-spec.bend
# (BND-83) and the raw-path matcher of proof/router-match-spec.bend (BND-78).
# ASCII folding is the letter table of proof/fold-spec.bend. Method
# resolution shares the method-set helpers of src/router/methods.bend
# (normalization, membership, canonical Allow order), which the BND-18 laws
# pin down; it shares none of their path matching.
import Base
import ../src/router/pattern.bend as P
import ../src/router/encoding.bend as E
import ../src/router/methods.bend as M
import ../src/router/spec.bend as R
import ../src/http/request.bend as H
import ../src/app/table.bend as T
import ./router-compile-spec.bend as CS
import ./router-match-spec.bend as MS
import ./fold-spec.bend as F

# ---- Slash and case options, for any pattern ----

# Case-insensitive mode folds ASCII letters in static text and in a prefix
# wildcard's literal prefix, never in captured values.
def folded_text(+raw: String, +h: String) -> Bool:
  String.eq(F.fold(raw), F.fold(h))

def folded_start(+h: String, +prefix: String) -> Bool:
  String.starts_with(F.fold(h), F.fold(prefix))

# The BND-78 matcher with folded static comparisons; captures, wildcards and
# spans keep the request's bytes and the same precedence.
def folded(segs: List<&2, P.Segment>, paths: List<&2, String>, +taken: List<&2, String>) -> Maybe<&2, P.Params>:
  match segs paths:
    case Nil{} Nil{}:
      Some{Nil{}}
    case Nil{} h <> t:
      None{}
    case P.Static{raw} <> rest Nil{}:
      None{}
    case P.Static{+raw} <> rest +h <> t:
      MS.same_text(folded_text(raw, h), folded(rest, t, Nil{}))
    case P.Capture{name, c, True{}} <> rest Nil{}:
      folded(rest, Nil{}, Nil{})
    case P.Capture{name, c, False{}} <> rest Nil{}:
      None{}
    case P.Capture{+name, +c, optional} <> rest raw <> t:
      MS.capture(name, c, E.decode(raw), folded(rest, t, Nil{}))
    case P.Wildcard{+name} <> Nil{} ps:
      MS.wildcard(name, MS.decoded_all(ps))
    case P.Wildcard{name} <> h <> t ps:
      None{}
    case P.InteriorWildcard{} <> rest Nil{}:
      folded(rest, Nil{}, Nil{})
    case P.InteriorWildcard{} <> +rest +h <> +t:
      MS.or_else(folded(rest, h <> t, Nil{}), u => folded(P.InteriorWildcard{} <> rest, t, Nil{}))
    case P.PrefixWildcard{+prefix} <> Nil{} h <> t:
      MS.prefix_hit(folded_start(h, prefix))
    case P.PrefixWildcard{prefix} <> Nil{} Nil{}:
      None{}
    case P.PrefixWildcard{prefix} <> h <> t ps:
      None{}
    case P.Span{name} <> rest Nil{}:
      None{}
    case P.Span{+name} <> +rest +h <> +t:
      MS.or_else(folded(P.Span{name} <> rest, t, h <> taken), u => MS.span_here(name, h <> taken, folded(rest, t, Nil{})))

# Segment matching under the case option.
def segments_with(sensitive: Bool, segs: List<&2, P.Segment>, paths: List<&2, String>) -> Maybe<&2, P.Params>:
  match sensitive:
    case True{}:
      MS.matches(segs, paths, Nil{})
    case False{}:
      folded(segs, paths, Nil{})

# The same, resuming with a span's raw segments already taken.
def segments_at(sensitive: Bool, segs: List<&2, P.Segment>, paths: List<&2, String>, +taken: List<&2, String>) -> Maybe<&2, P.Params>:
  match sensitive:
    case True{}:
      MS.matches(segs, paths, taken)
    case False{}:
      folded(segs, paths, taken)

# Lenient mode drops every terminal empty segment of the request path and
# every terminal empty static of the pattern, then keeps one for root.
def keep_text(rest: List<&2, String>, +h: String) -> List<&2, String>:
  match rest:
    case Nil{}:
      match h:
        case SNil{}:
          Nil{}
        case SCon{x, y}:
          [SCon{x, y}]
    case r <> t:
      h <> r <> t

def drop_empty(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      keep_text(drop_empty(t), h)

def root_text(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      [""]
    case h <> t:
      h <> t

def keep_segment(rest: List<&2, P.Segment>, +s: P.Segment) -> List<&2, P.Segment>:
  match rest:
    case Nil{}:
      match s:
        case P.Static{SNil{}}:
          Nil{}
        case _:
          [s]
    case r <> t:
      s <> r <> t

def drop_static(segs: List<&2, P.Segment>) -> List<&2, P.Segment>:
  match segs:
    case Nil{}:
      Nil{}
    case s <> t:
      keep_segment(drop_static(t), s)

def root_segment(segs: List<&2, P.Segment>) -> List<&2, P.Segment>:
  match segs:
    case Nil{}:
      [P.Static{""}]
    case s <> t:
      s <> t

def normal_path(strict: Bool, xs: List<&2, String>) -> List<&2, String>:
  match strict:
    case True{}:
      xs
    case False{}:
      root_text(drop_empty(xs))

def normal_pattern(strict: Bool, segs: List<&2, P.Segment>) -> List<&2, P.Segment>:
  match strict:
    case True{}:
      segs
    case False{}:
      root_segment(drop_static(segs))

# The root path is the single empty segment. No capture accepts it, but a
# pattern made only of optional captures matches it with no params.
def root_hit(paths: List<&2, String>, segs: List<&2, P.Segment>) -> Maybe<&2, P.Params>:
  match paths segs:
    case SNil{} <> Nil{} P.Capture{name, c, True{}} <> rest:
      MS.prefix_hit(MS.only_optional(rest))
    case _ _:
      None{}

def matched(sensitive: Bool, +segs: List<&2, P.Segment>, +paths: List<&2, String>) -> Maybe<&2, P.Params>:
  MS.or_else(segments_with(sensitive, segs, paths), u => root_hit(paths, segs))

# The text after a request path's leading slash.
def slash_tail(path: String) -> Maybe<&2, String>:
  match path:
    case SCon{'/', t}:
      Some{t}
    case _:
      None{}

def options_at(tail: Maybe<&2, String>, pattern: P.Pattern, opts: M.Options) -> Maybe<&2, P.Params>:
  match tail:
    case None{}:
      None{}
    case Some{t}:
      match pattern opts:
        case P.Pattern{segs} M.Options{+strict, sensitive}:
          matched(sensitive, normal_pattern(strict, segs), normal_path(strict, String.split(t, '/')))

# Matching one pattern under the slash and case options.
def match_options(pattern: P.Pattern, path: String, opts: M.Options) -> Maybe<&2, P.Params>:
  options_at(slash_tail(path), pattern, opts)

# ---- Joining a prefix and a member source ----

type Place is Data:
  AtRoot{}
  Under{raws: List<&2, String>}
  Unplaced{}

def strip_pick(+h: Char, last: Bool, rest: String) -> String:
  match last:
    case True{}:
      SNil{}
    case False{}:
      SCon{h, rest}

# The text without one terminal slash.
def strip_one(q: String) -> String:
  match q:
    case SNil{}:
      SNil{}
    case SCon{+h, +t}:
      strip_pick(h, Char.is_eq(h, '/') && String.is_empty(t), strip_one(t))

# Empty and `/` prefixes are identities. Any other prefix starts with `/`;
# without one terminal slash, its text splits into raw prefix segments.
def place(prefix: String) -> Place:
  match prefix:
    case "":
      AtRoot{}
    case "/":
      AtRoot{}
    case SCon{'/', q}:
      Under{String.split(strip_one(q), '/')}
    case _:
      Unplaced{}

# A member source is `*` (an alias for `/*`) or starts with `/`.
def member_text(member: String) -> Maybe<&2, String>:
  match member:
    case "*":
      Some{"*"}
    case SCon{'/', t}:
      Some{t}
    case _:
      None{}

# A member follows every prefix segment, so none of them is the last one.
def prefix_pieces(raws: List<&2, String>) -> Maybe<&2, List<&2, P.Segment>>:
  match raws:
    case Nil{}:
      Some{Nil{}}
    case raw <> rest:
      CS.both(CS.piece(raw, False{}), prefix_pieces(rest))

def member_pieces(text: Maybe<&2, String>) -> Maybe<&2, List<&2, P.Segment>>:
  match text:
    case None{}:
      None{}
    case Some{t}:
      CS.pieces(String.split(t, '/'))

# The joined pattern obeys the whole-pattern rules: names, placement, spans.
def joined(ps: Maybe<&2, List<&2, P.Segment>>, ms: Maybe<&2, List<&2, P.Segment>>) -> Maybe<&2, P.Pattern>:
  match ps ms:
    case Some{a} Some{b}:
      CS.checked(Some{List.append(&2, P.Segment, a, b)})
    case _ _:
      None{}

# The assembled pattern: prefix segments, then member segments.
def assembled_at(at: Place, member: String) -> Maybe<&2, P.Pattern>:
  match at:
    case AtRoot{}:
      CS.compile(member)
    case Under{raws}:
      joined(prefix_pieces(raws), member_pieces(member_text(member)))
    case Unplaced{}:
      None{}

def assembled(prefix: String, member: String) -> Maybe<&2, P.Pattern>:
  assembled_at(place(prefix), member)

# Where the laws apply: the prefix is empty, `/`, or segments of any pattern
# syntax (static text, captures with or without constraints, optional
# captures, wildcards and spans) whose last segment is not empty, and the
# assembled pattern compiles, so the whole-pattern rules (one trailing
# optional chain across prefix and member, wildcard and span placement,
# distinct names) hold. A last empty prefix segment comes from repeated
# trailing slashes (`/a//`); lenient mode could then drop a prefix segment
# along with the member's, which is the documented flattening counterexample.
def solid(s: P.Segment) -> Bool:
  match s:
    case P.Static{SNil{}}:
      False{}
    case _:
      True{}

# Whether the last segment is solid (`ok` for an empty list).
def ends_solid(segs: List<&2, P.Segment>, ok: Bool) -> Bool:
  match segs:
    case Nil{}:
      ok
    case s <> t:
      ends_solid(t, solid(s))

def compiles(m: Maybe<&2, P.Pattern>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{p}:
      True{}

def kept_and(ps: Maybe<&2, List<&2, P.Segment>>, ok: Bool) -> Bool:
  match ps:
    case None{}:
      False{}
    case Some{segs}:
      ends_solid(segs, False{}) && ok

def admissible_at(at: Place, +member: String) -> Bool:
  match at:
    case AtRoot{}:
      compiles(CS.compile(member))
    case Under{+raws}:
      kept_and(prefix_pieces(raws), compiles(joined(prefix_pieces(raws), member_pieces(member_text(member)))))
    case Unplaced{}:
      False{}

def admissible(prefix: String, +member: String) -> Bool:
  admissible_at(place(prefix), member)

# ---- What a mounted route answers ----

def text_same(sensitive: Bool, +raw: String, +h: String) -> Bool:
  match sensitive:
    case True{}:
      String.eq(raw, h)
    case False{}:
      folded_text(raw, h)

# The member keeps its own segments; lenient mode drops its terminal empty
# statics, since the prefix already supplies a segment.
def member_segments(strict: Bool, segs: List<&2, P.Segment>) -> List<&2, P.Segment>:
  match strict:
    case True{}:
      segs
    case False{}:
      drop_static(segs)

# A terminal wildcard takes every remaining segment, only when no pattern
# segment follows it.
def wildcard_end(+name: String, after: List<&2, P.Segment>, ps: List<&2, String>) -> Maybe<&2, P.Params>:
  match after:
    case Nil{}:
      MS.wildcard(name, MS.decoded_all(ps))
    case h <> t:
      None{}

def start_same(sensitive: Bool, +h: String, +prefix: String) -> Bool:
  match sensitive:
    case True{}:
      String.starts_with(h, prefix)
    case False{}:
      folded_start(h, prefix)

# A prefix wildcard matches one last segment that starts with its text, only
# when no pattern segment follows it.
def prefix_end(+sensitive: Bool, +prefix: String, after: List<&2, P.Segment>, ps: List<&2, String>) -> Maybe<&2, P.Params>:
  match after ps:
    case Nil{} h <> t:
      MS.prefix_hit(start_same(sensitive, h, prefix))
    case _ _:
      None{}

# The prefix walks the request's segments first, each segment by its own
# rule: static text compares under the case option; a capture decodes and
# checks its constraint, and an optional one may stand at the end of the
# path; an interior wildcard skips as few whole segments as possible; a span
# takes as many as it can and still lets the rest match. When the prefix is
# used up, the member matches the remaining segments. Captures come out in
# that order, so prefix captures precede member captures.
def walk(prefix: List<&2, P.Segment>, paths: List<&2, String>, +sensitive: Bool, +member: List<&2, P.Segment>, +taken: List<&2, String>) -> Maybe<&2, P.Params>:
  match prefix paths:
    case Nil{} ps:
      segments_at(sensitive, member, ps, taken)
    case P.Static{raw} <> rest Nil{}:
      None{}
    case P.Static{+raw} <> rest +h <> t:
      MS.same_text(text_same(sensitive, raw, h), walk(rest, t, sensitive, member, Nil{}))
    case P.Capture{name, c, True{}} <> rest Nil{}:
      walk(rest, Nil{}, sensitive, member, Nil{})
    case P.Capture{name, c, False{}} <> rest Nil{}:
      None{}
    case P.Capture{+name, +c, optional} <> rest raw <> t:
      MS.capture(name, c, E.decode(raw), walk(rest, t, sensitive, member, Nil{}))
    case P.Wildcard{+name} <> rest ps:
      wildcard_end(name, List.append(&2, P.Segment, rest, member), ps)
    case P.InteriorWildcard{} <> rest Nil{}:
      walk(rest, Nil{}, sensitive, member, Nil{})
    case P.InteriorWildcard{} <> +rest +h <> +t:
      MS.or_else(walk(rest, h <> t, sensitive, member, Nil{}), u => walk(P.InteriorWildcard{} <> rest, t, sensitive, member, Nil{}))
    case P.PrefixWildcard{+p} <> rest ps:
      prefix_end(sensitive, p, List.append(&2, P.Segment, rest, member), ps)
    case P.Span{name} <> rest Nil{}:
      None{}
    case P.Span{+name} <> +rest +h <> +t:
      MS.or_else(walk(P.Span{name} <> rest, t, sensitive, member, h <> taken), u => MS.span_here(name, h <> taken, walk(rest, t, sensitive, member, Nil{})))

# The member has no root rule of its own under a nonroot prefix. The root
# rule belongs to the assembled pattern: when the prefix and member are both
# optional captures, the bare root path matches with no params.
def rooted(+sensitive: Bool, +prefix: List<&2, P.Segment>, +xs: List<&2, String>, +member: List<&2, P.Segment>) -> Maybe<&2, P.Params>:
  MS.or_else(walk(prefix, xs, sensitive, member, Nil{}), u => root_hit(xs, List.append(&2, P.Segment, prefix, member)))

def walk_at(tail: Maybe<&2, String>, prefix: List<&2, P.Segment>, member: List<&2, P.Segment>, opts: M.Options) -> Maybe<&2, P.Params>:
  match tail:
    case None{}:
      None{}
    case Some{t}:
      match opts:
        case M.Options{+strict, sensitive}:
          rooted(sensitive, prefix, normal_path(strict, String.split(t, '/')), member_segments(strict, member))

def walk_pieces(ps: Maybe<&2, List<&2, P.Segment>>, ms: Maybe<&2, List<&2, P.Segment>>, path: String, opts: M.Options) -> Maybe<&2, P.Params>:
  match ps ms:
    case Some{a} Some{b}:
      walk_at(slash_tail(path), a, b, opts)
    case _ _:
      None{}

def member_alone(m: Maybe<&2, P.Pattern>, path: String, opts: M.Options) -> Maybe<&2, P.Params>:
  match m:
    case None{}:
      None{}
    case Some{p}:
      match_options(p, path, opts)

# Under a root mount the member answers alone, root rule included.
def mounted_at(at: Place, member: String, path: String, opts: M.Options) -> Maybe<&2, P.Params>:
  match at:
    case AtRoot{}:
      member_alone(CS.compile(member), path, opts)
    case Under{raws}:
      walk_pieces(prefix_pieces(raws), member_pieces(member_text(member)), path, opts)
    case Unplaced{}:
      None{}

def mounted(prefix: String, member: String, path: String, opts: M.Options) -> Maybe<&2, P.Params>:
  mounted_at(place(prefix), member, path, opts)

# ---- Ordered method resolution for a mounted registration list ----

def entries(-Tag: Data, routes: List<&2, M.Registration(Tag)>) -> List<&2, T.Entry<Tag>>:
  match routes:
    case Nil{}:
      Nil{}
    case r <> t:
      T.Route{r} <> entries(Tag, t)

type Row<-Tag: Data> is Data:
  Row{hit: Maybe<&2, P.Params>, methods: M.MethodSelector, tag: Tag}

# Each registration's mounted answer for the request, in order.
def rows(-Tag: Data, +prefix: String, routes: List<&2, M.Registration(Tag)>, +path: String, +opts: M.Options) -> List<&2, Row<Tag>>:
  match routes:
    case Nil{}:
      Nil{}
    case R.Registration{source, M.Binding{methods, tag}} <> t:
      Row{mounted(prefix, source, path, opts), M.normalize_selector(methods), tag} <> rows(Tag, prefix, t, path, opts)

def allowed_hit(ok: Bool, hit: Maybe<&2, P.Params>) -> Maybe<&2, P.Params>:
  match ok:
    case True{}:
      hit
    case False{}:
      None{}

def later(-Tag: Data, m: Maybe<&2, R.Match<Tag>>) -> Maybe<&2, R.Match<Tag>>:
  match m:
    case None{}:
      None{}
    case Some{R.Match{i, tag, ps}}:
      Some{R.Match{1n+i, tag, ps}}

def pick(-Tag: Data, tag: Tag, hit: Maybe<&2, P.Params>, rest: Maybe<&2, R.Match<Tag>>) -> Maybe<&2, R.Match<Tag>>:
  match hit:
    case None{}:
      later(Tag, rest)
    case Some{ps}:
      Some{R.Match{0n, tag, ps}}

# The first row that answers the path and allows the method, with its index.
def first(-Tag: Data, xs: List<&2, Row<Tag>>, +method: H.Method) -> Maybe<&2, R.Match<Tag>>:
  match xs:
    case Nil{}:
      None{}
    case Row{hit, methods, tag} <> t:
      pick(Tag, tag, allowed_hit(M.accepts(methods, method), hit), first(Tag, t, method))

def hit_some(hit: Maybe<&2, P.Params>) -> Bool:
  match hit:
    case None{}:
      False{}
    case Some{ps}:
      True{}

def answered(-Tag: Data, xs: List<&2, Row<Tag>>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Row{hit, methods, tag} <> t:
      hit_some(hit) || answered(Tag, t)

def listed_pick(ok: Bool, ms: List<&2, H.Method>, rest: List<&2, H.Method>) -> List<&2, H.Method>:
  match ok:
    case True{}:
      List.append(&2, H.Method, ms, rest)
    case False{}:
      rest

def listed(-Tag: Data, xs: List<&2, Row<Tag>>) -> List<&2, H.Method>:
  match xs:
    case Nil{}:
      Nil{}
    case Row{hit, methods, tag} <> t:
      listed_pick(hit_some(hit), M.finite(methods), listed(Tag, t))

def missed_pick(-Tag: Data, ok: Bool, allow: List<&2, H.Method>) -> M.Resolution<Tag>:
  match ok:
    case True{}:
      M.MethodNotAllowed{M.canonical(allow)}
    case False{}:
      M.NotFound{}

def missed(-Tag: Data, +xs: List<&2, Row<Tag>>) -> M.Resolution<Tag>:
  missed_pick(Tag, answered(Tag, xs), listed(Tag, xs))

def head_get(-Tag: Data, hit: Maybe<&2, R.Match<Tag>>, +xs: List<&2, Row<Tag>>) -> M.Resolution<Tag>:
  match hit:
    case Some{m}:
      M.Found{m, True{}}
    case None{}:
      missed(Tag, xs)

# A direct hit wins; HEAD then falls back to the first GET; otherwise a path
# that some row answers is 405 with every answering row's methods, and any
# other path is 404.
def decided(-Tag: Data, hit: Maybe<&2, R.Match<Tag>>, +xs: List<&2, Row<Tag>>, method: H.Method) -> M.Resolution<Tag>:
  match hit:
    case Some{m}:
      M.Found{m, False{}}
    case None{}:
      match method:
        case H.Head{}:
          head_get(Tag, first(Tag, xs, H.Get{}), xs)
        case _:
          missed(Tag, xs)

def resolve(-Tag: Data, +prefix: String, routes: List<&2, M.Registration(Tag)>, +path: String, +method: H.Method, +opts: M.Options) -> M.Resolution<Tag>:
  +xs = rows(Tag, prefix, routes, path, opts)
  decided(Tag, first(Tag, xs, method), xs, method)

def all_admissible(-Tag: Data, +prefix: String, routes: List<&2, M.Registration(Tag)>) -> Bool:
  match routes:
    case Nil{}:
      True{}
    case R.Registration{source, b} <> t:
      admissible(prefix, source) && all_admissible(Tag, prefix, t)

def methods_valid(-Tag: Data, routes: List<&2, M.Registration(Tag)>) -> Bool:
  match routes:
    case Nil{}:
      True{}
    case R.Registration{source, M.Binding{methods, tag}} <> t:
      M.list_valid(M.finite(M.normalize_selector(methods))) && methods_valid(Tag, t)

# ---- Literal prefixes ----

# Plain static text: nonempty, not a capture (`:` first), not a wildcard
# (`*` first or last), and valid static text.
def plain_text(raw: String) -> Bool:
  match raw:
    case SNil{}:
      False{}
    case SCon{+h, +t}:
      Bool.not(Char.is_eq(h, ':')) && Bool.not(Char.is_eq(h, '*')) && Bool.not(String.ends_with(SCon{h, t}, "*")) && CS.static_text(SCon{h, t})

def all_plain(raws: List<&2, String>) -> Bool:
  match raws:
    case Nil{}:
      True{}
    case raw <> t:
      plain_text(raw) && all_plain(t)

def literal_at(at: Place) -> Bool:
  match at:
    case Under{raws}:
      all_plain(raws)
    case _:
      False{}

# Every prefix segment is plain static text.
def literal(prefix: String) -> Bool:
  literal_at(place(prefix))

def lead_at(at: Place) -> String:
  match at:
    case Under{raws}:
      "/" ++ String.join(raws, "/")
    case _:
      ""

# The request path a prefix stands for: `/api/` and `/api` both lead `/api`.
def lead(prefix: String) -> String:
  lead_at(place(prefix))

def chain_at(m: Maybe<&2, P.Pattern>) -> Bool:
  match m:
    case Some{P.Pattern{P.Capture{name, c, True{}} <> rest}}:
      MS.only_optional(rest)
    case _:
      False{}

# The member is a chain of optional captures, which alone answers `/`.
def root_optional(member: String) -> Bool:
  chain_at(CS.compile(member))

# The documented root convention: such a member answers the bare prefix,
# not the prefix plus `/`.
def root_exception(member: String, +rest: String) -> Bool:
  String.eq(rest, "/") && root_optional(member)

# A suffix after the prefix is empty or starts a new segment.
def boundary(rest: String) -> Bool:
  match rest:
    case SNil{}:
      True{}
    case SCon{h, t}:
      Char.is_eq(h, '/')

# Each request segment equals its prefix segment under the case option:
# exactly, or after ASCII folding when matching is case-insensitive.
def same_segments(+sensitive: Bool, raws: List<&2, String>, segs: List<&2, String>) -> Bool:
  match raws segs:
    case Nil{} Nil{}:
      True{}
    case raw <> rt x <> xt:
      text_same(sensitive, raw, x) && same_segments(sensitive, rt, xt)
    case _ _:
      False{}

def prefix_same_at(at: Place, +sensitive: Bool, segs: List<&2, String>) -> Bool:
  match at:
    case Under{raws}:
      same_segments(sensitive, raws, segs)
    case _:
      False{}

# The request's leading segments spell the prefix under the case option.
def prefix_same(prefix: String, +sensitive: Bool, segs: List<&2, String>) -> Bool:
  prefix_same_at(place(prefix), sensitive, segs)

# A request path cut after its leading segments.
type Cut is Data:
  Cut{segs: List<&2, String>, rest: String}

def cut_path(c: Cut) -> String:
  match c:
    case Cut{segs, rest}:
      ("/" ++ String.join(segs, "/")) ++ rest

def cut_segs(c: Cut) -> List<&2, String>:
  match c:
    case Cut{segs, rest}:
      segs

def cut_rest(c: Cut) -> String:
  match c:
    case Cut{segs, rest}:
      rest

def compiles_text(m: Maybe<&2, String>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{t}:
      True{}

# The prefix is empty or starts with `/`, and a member under a nonroot prefix
# starts with `/` or is `*`.
def placed_at(at: Place, member: String) -> Bool:
  match at:
    case AtRoot{}:
      True{}
    case Under{raws}:
      compiles_text(member_text(member))
    case Unplaced{}:
      False{}

def placed(prefix: String, member: String) -> Bool:
  placed_at(place(prefix), member)
