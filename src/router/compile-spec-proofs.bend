# BND-83: compiling a route source succeeds exactly when the independent
# source grammar in proof/router-compile-spec.bend accepts it, with the same
# pattern.
import Base
import ./pattern.bend as P
import ./constraint.bend as C
import ./encoding.bend as E
import ./codec-bits.bend as Bits
import ./equality-proofs.bend as Eq
import ../http/text.bend as T
import ../http/text-proofs.bend as TP
import ./compile-spec-chars.bend as CS
import ../../proof/router-compile-spec.bend as S

def name_tail_eq(s: String) -> {P.name_tail(s) == S.name_rest(s) : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+n}, +t}:
      Equal.cong(Bool, Bool, x => S.name_char(n) && x, P.name_tail(t), S.name_rest(t), name_tail_eq(t))

def name_ok_eq(s: String) -> {P.name_ok(s) == S.valid_name(s) : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+n}, +t}:
      Equal.cong(Bool, Bool, x => (S.letter(n) || U32.is_eq(n, 95)) && x, P.name_tail(t), S.name_rest(t), name_tail_eq(t))

def static_ok_eq(s: String) -> {P.static_ok(s) == S.static_text(s) : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+n}, +t}:
      Equal.cong(Bool, Bool, x => S.static_char(n) && x, P.static_ok(t), S.static_text(t), static_ok_eq(t))

def no_percent_eq(s: String) -> {P.no_percent(s) == S.no_percent(s) : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+n}, +t}:
      Equal.cong(Bool, Bool, x => Bool.not(U32.is_eq(n, 37)) && x, P.no_percent(t), S.no_percent(t), no_percent_eq(t))

def seen_eq(names: List<&2, String>, +n: String) -> {P.seen(names, n) == S.used(names, n) : Bool}:
  match names:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.cong(Bool, Bool, x => String.eq(h, n) || x, P.seen(t, n), S.used(t, n), seen_eq(t, n))

def all_optional_eq(segs: List<&2, P.Segment>) -> {P.all_optional(segs) == S.all_optional(segs) : Bool}:
  match segs:
    case Nil{}:
      {==}
    case P.Capture{name, c, True{}} <> +t:
      all_optional_eq(t)
    case P.Capture{name, c, False{}} <> t:
      {==}
    case P.Static{raw} <> t:
      {==}
    case P.Wildcard{name} <> t:
      {==}
    case P.InteriorWildcard{} <> t:
      {==}
    case P.PrefixWildcard{p} <> t:
      {==}
    case P.Span{name} <> t:
      {==}

# Small Boolean facts.
def and_true(b: Bool) -> {b && True{} == b : Bool}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def and_false(b: Bool) -> {b && False{} == False{} : Bool}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def falsy_and(+x: Bool, +y: Bool, e: {x == False{} : Bool}) -> {x && y == False{} : Bool}:
  Equal.cong(Bool, Bool, z => z && y, x, False{}, e)

# ---------------------------------------------------------------------------
# One segment: the compiler's segment, located, is the spec's piece.

def seg_view(r: Result<&2, &2, P.PatternError, P.Segment>, +rest: List<&2, String>) -> Maybe<&2, P.Segment>:
  match r:
    case Done{p}:
      Some{P.located(p, rest)}
    case Fail{e}:
      None{}

def fails_view(b: Bool, +x: P.PatternError, +y: P.PatternError, +rest: List<&2, String>) ->
    {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, b, u => Fail{x}, u => Fail{y}), rest) == None{} : Maybe<&2, P.Segment>}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def known_view(r: Maybe<&2, C.Constraint>, +body: String, +name: String, +optional: Bool, +rest: List<&2, String>) ->
    {seg_view(P.constraint_result(r, body, name, optional), rest) == S.known(r, name, optional) : Maybe<&2, P.Segment>}:
  match r:
    case Some{c}:
      {==}
    case None{}:
      fails_view(String.starts_with(body, "["), P.PatternError{P.InvalidClass{}, body}, P.PatternError{P.UnknownConstraint{}, body}, rest)

# `{.+}?` is no constraint: the constraint module rejects `.+`.
def braced_view(+body: String, +name: String, +rest: List<&2, String>, sp: Bool, optional: Bool, e: {String.eq(body, ".+") == sp : Bool}) ->
    {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, sp && Bool.not(optional), u => Done{P.Span{name}}, u => P.constraint_result(C.compile(body), body, name, optional)), rest) == S.braced(sp, body, name, optional) : Maybe<&2, P.Segment>}:
  match sp:
    case False{}:
      known_view(C.compile(body), body, name, optional, rest)
    case True{}:
      match optional:
        case False{}:
          {==}
        case True{}:
          Equal.cong(String, Maybe<&2, P.Segment>, b => seg_view(P.constraint_result(C.compile(b), b, name, True{}), rest), body, ".+", Eq.string_eq_sound(body, ".+", e))

def closed_view(+s: String, +name: String, +optional: Bool, +rest: List<&2, String>, ok: Bool) ->
    {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, ok, u => (
      +body = String.take(String.drop(s, 1n), Nat.sub(String.length(s), 2n))
      E.choose(Result<&2, &2, P.PatternError, P.Segment>, String.eq(body, ".+") && Bool.not(optional), u => Done{P.Span{name}}, u => P.constraint_result(C.compile(body), body, name, optional))
    ), u => Fail{P.PatternError{P.UnbalancedBraces{}, s}}), rest) == S.closed(ok, s, name, optional) : Maybe<&2, P.Segment>}:
  match ok:
    case False{}:
      {==}
    case True{}:
      braced_view(S.inside(s), name, rest, String.eq(S.inside(s), ".+"), optional, {==})

def constrained_view(+s: String, +name: String, +optional: Bool, +rest: List<&2, String>) ->
    {seg_view(P.constrained(s, name, optional), rest) == S.constraint(s, name, optional) : Maybe<&2, P.Segment>}:
  closed_view(s, name, optional, rest, String.starts_with(s, "{") && String.ends_with(s, "}"))

def marked_view(+s: String, +name: String, +rest: List<&2, String>, question: Bool, optional: Bool) ->
    {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, question, u => Done{P.Capture{name, C.Any{}, True{}}}, u => (
      E.choose(Result<&2, &2, P.PatternError, P.Segment>, optional, u => P.constrained(String.take(s, Nat.sub(String.length(s), 1n)), name, True{}), u => P.constrained(s, name, False{}))
    )), rest) == S.marked(question, optional, s, name) : Maybe<&2, P.Segment>}:
  match question:
    case True{}:
      {==}
    case False{}:
      match optional:
        case True{}:
          constrained_view(String.take(s, Nat.sub(String.length(s), 1n)), name, True{}, rest)
        case False{}:
          constrained_view(s, name, False{}, rest)

def suffix_view(s: String, +name: String, +rest: List<&2, String>) ->
    {seg_view(P.capture_suffix(s, name), rest) == S.suffix(s, name) : Maybe<&2, P.Segment>}:
  match s:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      marked_view(SCon{h, t}, name, rest, String.eq(SCon{h, t}, "?"), String.ends_with(SCon{h, t}, "?"))

def named_view(+name: String, +s: String, +rest: List<&2, String>, ok: Bool) ->
    {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, ok, u => P.capture_suffix(s, name), u => Fail{P.PatternError{P.InvalidName{}, name}}), rest) == S.named(ok, name, s) : Maybe<&2, P.Segment>}:
  match ok:
    case True{}:
      suffix_view(s, name, rest)
    case False{}:
      {==}

def capture_cut(c: S.Cut, +rest: List<&2, String>) ->
    {seg_view(P.capture(CS.as_split(c)), rest) == S.capture(c) : Maybe<&2, P.Segment>}:
  match c:
    case S.Cut{SNil{}, s}:
      {==}
    case S.Cut{SCon{+a, +b}, +s}:
      %name_ok_eq(SCon{a, b}) : {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.name_ok(SCon{a, b}), u => P.capture_suffix(s, SCon{a, b}), u => Fail{P.PatternError{P.InvalidName{}, SCon{a, b}}}), rest) == S.named(_, SCon{a, b}, s) : Maybe<&2, P.Segment>}
      named_view(SCon{a, b}, s, rest, P.name_ok(SCon{a, b}))

def capture_view(+t: String, +rest: List<&2, String>) ->
    {seg_view(P.capture(P.split_name(t)), rest) == S.capture(S.cut(t)) : Maybe<&2, P.Segment>}:
  %Equal.sym(C.Split, P.split_name(t), CS.as_split(S.cut(t)), CS.split_cut(t)) : {seg_view(P.capture(_), rest) == S.capture(S.cut(t)) : Maybe<&2, P.Segment>}
  capture_cut(S.cut(t), rest)

def wild_view(+t: String, +rest: List<&2, String>, ok: Bool, e: {P.name_ok(t) == ok : Bool}) ->
    {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, ok, u => Done{P.Wildcard{t}}, u => Fail{P.PatternError{P.InvalidName{}, t}}), rest) == S.wild(ok, t) : Maybe<&2, P.Segment>}:
  match ok:
    case True{}:
      Equal.cong(P.Segment, Maybe<&2, P.Segment>, x => Some{x}, P.located(P.Wildcard{t}, rest), P.Wildcard{t}, CS.located_named(t, rest, e))
    case False{}:
      {==}

def star_view(t: String, +rest: List<&2, String>) ->
    {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, String.is_empty(t), u => Done{P.Wildcard{"*"}}, u => (
      E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.name_ok(t), u => Done{P.Wildcard{t}}, u => Fail{P.PatternError{P.InvalidName{}, t}})
    )), rest) == S.star(t, List.is_empty(&2, String, rest)) : Maybe<&2, P.Segment>}:
  match t rest:
    case SNil{} Nil{}:
      {==}
    case SNil{} h <> r:
      {==}
    case SCon{+a, +b} +r:
      %name_ok_eq(SCon{a, b}) : {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.name_ok(SCon{a, b}), u => Done{P.Wildcard{SCon{a, b}}}, u => Fail{P.PatternError{P.InvalidName{}, SCon{a, b}}}), r) == S.wild(_, SCon{a, b}) : Maybe<&2, P.Segment>}
      wild_view(SCon{a, b}, r, P.name_ok(SCon{a, b}), {==})

def prefix_view(+p: String, +raw: String, +rest: List<&2, String>, ok: Bool) ->
    {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, ok, u => Done{P.PrefixWildcard{p}}, u => Fail{P.PatternError{P.InvalidStatic{}, raw}}), rest) == S.prefix(ok, p) : Maybe<&2, P.Segment>}:
  match ok:
    case True{}:
      {==}
    case False{}:
      {==}

def text_view(+raw: String, +rest: List<&2, String>, ok: Bool) ->
    {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, ok, u => Done{P.Static{raw}}, u => Fail{P.PatternError{P.InvalidStatic{}, raw}}), rest) == S.text(ok, raw) : Maybe<&2, P.Segment>}:
  match ok:
    case True{}:
      {==}
    case False{}:
      {==}

def plain_view(+raw: String, +rest: List<&2, String>, starred: Bool) ->
    {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, starred, u => (
      +prefix = String.take(raw, Nat.sub(String.length(raw), 1n))
      E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.static_ok(prefix), u => Done{P.PrefixWildcard{prefix}}, u => Fail{P.PatternError{P.InvalidStatic{}, raw}})
    ), u => (
      E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.static_ok(raw), u => Done{P.Static{raw}}, u => Fail{P.PatternError{P.InvalidStatic{}, raw}})
    )), rest) == S.plain(starred, raw) : Maybe<&2, P.Segment>}:
  match starred:
    case True{}:
      %static_ok_eq(String.take(raw, Nat.sub(String.length(raw), 1n))) : {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.static_ok(String.take(raw, Nat.sub(String.length(raw), 1n))), u => Done{P.PrefixWildcard{String.take(raw, Nat.sub(String.length(raw), 1n))}}, u => Fail{P.PatternError{P.InvalidStatic{}, raw}}), rest) == S.prefix(_, String.take(raw, Nat.sub(String.length(raw), 1n))) : Maybe<&2, P.Segment>}
      prefix_view(String.take(raw, Nat.sub(String.length(raw), 1n)), raw, rest, P.static_ok(String.take(raw, Nat.sub(String.length(raw), 1n))))
    case False{}:
      %static_ok_eq(raw) : {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.static_ok(raw), u => Done{P.Static{raw}}, u => Fail{P.PatternError{P.InvalidStatic{}, raw}}), rest) == S.text(_, raw) : Maybe<&2, P.Segment>}
      text_view(raw, rest, P.static_ok(raw))

def static_view(+raw: String, +rest: List<&2, String>) ->
    {seg_view(P.compile_static(raw), rest) == S.static(raw) : Maybe<&2, P.Segment>}:
  plain_view(raw, rest, String.ends_with(raw, "*"))

def head_view(+h: Char, +t: String, +rest: List<&2, String>, colon: Bool, starred: Bool) ->
    {seg_view(E.choose(Result<&2, &2, P.PatternError, P.Segment>, colon, u => P.capture(P.split_name(t)), u => (
      E.choose(Result<&2, &2, P.PatternError, P.Segment>, starred, u => (
        E.choose(Result<&2, &2, P.PatternError, P.Segment>, String.is_empty(t), u => Done{P.Wildcard{"*"}}, u => (
          E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.name_ok(t), u => Done{P.Wildcard{t}}, u => Fail{P.PatternError{P.InvalidName{}, t}})
        ))
      ), u => P.compile_static(SCon{h, t}))
    )), rest) == S.lead(colon, starred, h, t, List.is_empty(&2, String, rest)) : Maybe<&2, P.Segment>}:
  match colon:
    case True{}:
      capture_view(t, rest)
    case False{}:
      match starred:
        case True{}:
          star_view(t, rest)
        case False{}:
          static_view(SCon{h, t}, rest)

def segment_view(raw: String, +rest: List<&2, String>) ->
    {seg_view(P.compile_segment(raw), rest) == S.piece(raw, List.is_empty(&2, String, rest)) : Maybe<&2, P.Segment>}:
  match raw:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      head_view(h, t, rest, Char.is_eq(h, ':'), Char.is_eq(h, '*'))

# ---------------------------------------------------------------------------
# Optional chains. The compiler checks that every source after an optional
# capture has the form `:…?`; the spec checks that each parses to an optional
# capture. A source that parses to an optional capture has that form.

def head_same(b: Bool, +a1: String, +a2: String) ->
    {String.starts_with.go.if(SNil{}, a1, b) == String.starts_with.go.if(SNil{}, a2, b) : Bool}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

# Whether a reversed string starts with `?` depends only on its last character.
def last_same(u: String, +c: Char, +a1: String, +a2: String) ->
    {String.starts_with.go("?", String.reverse.go(u, SCon{c, a1})) == String.starts_with.go("?", String.reverse.go(u, SCon{c, a2})) : Bool}:
  match u:
    case SNil{}:
      head_same(Char.is_eq(c, '?'), a1, a2)
    case SCon{+d, +v}:
      last_same(v, d, SCon{c, a1}, SCon{c, a2})

def reverse_append(a: String, +b: String, +acc: String) ->
    {String.reverse.go(a ++ b, acc) == String.reverse.go(b, String.reverse.go(a, acc)) : String}:
  match a:
    case SNil{}:
      {==}
    case SCon{+x, +y}:
      reverse_append(y, b, SCon{x, acc})

def ends_after(+h: Char, +n: String, +a: Char, +b: String) ->
    {String.ends_with(SCon{h, n ++ SCon{a, b}}, "?") == String.ends_with(SCon{a, b}, "?") : Bool}:
  Equal.trans(Bool, String.starts_with.go("?", String.reverse.go(n ++ SCon{a, b}, SCon{h, SNil{}})), String.starts_with.go("?", String.reverse.go(b, SCon{a, String.reverse.go(n, SCon{h, SNil{}})})), String.starts_with.go("?", String.reverse.go(b, SCon{a, SNil{}})),
    Equal.cong(String, Bool, x => String.starts_with.go("?", x), String.reverse.go(n ++ SCon{a, b}, SCon{h, SNil{}}), String.reverse.go(SCon{a, b}, String.reverse.go(n, SCon{h, SNil{}})), reverse_append(n, SCon{a, b}, SCon{h, SNil{}})),
    last_same(b, a, String.reverse.go(n, SCon{h, SNil{}}), SNil{}))

def opt1(m: Maybe<&2, P.Segment>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{s}:
      S.optional(s)

def opt_m(m: Maybe<&2, List<&2, P.Segment>>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{ss}:
      S.all_optional(ss)

def empty_m(m: Maybe<&2, List<&2, P.Segment>>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{ss}:
      List.is_empty(&2, P.Segment, ss)

def no_known(c: Maybe<&2, C.Constraint>, +name: String) -> {opt1(S.known(c, name, False{})) == False{} : Bool}:
  match c:
    case None{}:
      {==}
    case Some{k}:
      {==}

def no_braced(sp: Bool, +body: String, +name: String) -> {opt1(S.braced(sp, body, name, False{})) == False{} : Bool}:
  match sp:
    case True{}:
      {==}
    case False{}:
      no_known(C.compile(body), name)

def no_closed(ok: Bool, +s: String, +name: String) -> {opt1(S.closed(ok, s, name, False{})) == False{} : Bool}:
  match ok:
    case False{}:
      {==}
    case True{}:
      no_braced(String.eq(S.inside(s), ".+"), S.inside(s), name)

def no_constraint(+s: String, +name: String) -> {opt1(S.constraint(s, name, False{})) == False{} : Bool}:
  no_closed(String.starts_with(s, "{") && String.ends_with(s, "}"), s, name)

def no_wild(ok: Bool, +name: String) -> {opt1(S.wild(ok, name)) == False{} : Bool}:
  match ok:
    case True{}:
      {==}
    case False{}:
      {==}

def no_bare(last: Bool) -> {opt1(Some{S.bare(last)}) == False{} : Bool}:
  match last:
    case True{}:
      {==}
    case False{}:
      {==}

def no_star(t: String, +last: Bool) -> {opt1(S.star(t, last)) == False{} : Bool}:
  match t:
    case SNil{}:
      no_bare(last)
    case SCon{+a, +b}:
      no_wild(S.valid_name(SCon{a, b}), SCon{a, b})

def no_prefix(ok: Bool, +p: String) -> {opt1(S.prefix(ok, p)) == False{} : Bool}:
  match ok:
    case True{}:
      {==}
    case False{}:
      {==}

def no_text(ok: Bool, +raw: String) -> {opt1(S.text(ok, raw)) == False{} : Bool}:
  match ok:
    case True{}:
      {==}
    case False{}:
      {==}

def no_plain(starred: Bool, +raw: String) -> {opt1(S.plain(starred, raw)) == False{} : Bool}:
  match starred:
    case True{}:
      no_prefix(S.static_text(String.take(raw, Nat.sub(String.length(raw), 1n))), String.take(raw, Nat.sub(String.length(raw), 1n)))
    case False{}:
      no_text(S.static_text(raw), raw)

def no_static(+raw: String) -> {opt1(S.static(raw)) == False{} : Bool}:
  no_plain(String.ends_with(raw, "*"), raw)

def no_named_plain(ok: Bool, +name: String) -> {opt1(S.named(ok, name, SNil{})) == False{} : Bool}:
  match ok:
    case True{}:
      {==}
    case False{}:
      {==}

def marked_opt(+s: String, +name: String, question: Bool, optional: Bool,
    qe: {String.eq(s, "?") == question : Bool}, oe: {String.ends_with(s, "?") == optional : Bool}) ->
    {opt1(S.marked(question, optional, s, name)) && Bool.not(optional) == False{} : Bool}:
  match question optional:
    case True{} True{}:
      {==}
    case True{} False{}:
      Bits.absurd({opt1(S.marked(True{}, False{}, s, name)) && Bool.not(False{}) == False{} : Bool}, Bits.false_true(Equal.sym(Bool, True{}, False{}, Equal.trans(Bool, True{}, String.ends_with(s, "?"), False{}, Equal.cong(String, Bool, z => String.ends_with(z, "?"), "?", s, Equal.sym(String, s, "?", Eq.string_eq_sound(s, "?", qe))), oe))))
    case False{} True{}:
      and_false(opt1(S.marked(False{}, True{}, s, name)))
    case False{} False{}:
      falsy_and(opt1(S.constraint(s, name, False{})), True{}, no_constraint(s, name))

def named_opt(+name: String, +a: Char, +b: String, ok: Bool) ->
    {opt1(S.named(ok, name, SCon{a, b})) && Bool.not(String.ends_with(SCon{a, b}, "?")) == False{} : Bool}:
  match ok:
    case False{}:
      {==}
    case True{}:
      marked_opt(SCon{a, b}, name, String.eq(SCon{a, b}, "?"), String.ends_with(SCon{a, b}, "?"), {==}, {==})

def capture_opt(+h: Char, c: S.Cut) ->
    {opt1(S.capture(c)) && Bool.not(String.ends_with(SCon{h, CS.whole(c)}, "?")) == False{} : Bool}:
  match c:
    case S.Cut{+n, SNil{}}:
      falsy_and(opt1(S.named(S.valid_name(n), n, SNil{})), Bool.not(String.ends_with(SCon{h, n ++ SNil{}}, "?")), no_named_plain(S.valid_name(n), n))
    case S.Cut{+n, SCon{+a, +b}}:
      %Equal.sym(Bool, String.ends_with(SCon{h, n ++ SCon{a, b}}, "?"), String.ends_with(SCon{a, b}, "?"), ends_after(h, n, a, b)) : {opt1(S.named(S.valid_name(n), n, SCon{a, b})) && Bool.not(_) == False{} : Bool}
      named_opt(n, a, b, S.valid_name(n))

def lead_opt(+h: Char, +t: String, +last: Bool, colon: Bool, starred: Bool) ->
    {opt1(S.lead(colon, starred, h, t, last)) && Bool.not(String.starts_with.go.if(SNil{}, t, colon) && String.ends_with(SCon{h, t}, "?")) == False{} : Bool}:
  match colon:
    case False{}:
      match starred:
        case True{}:
          falsy_and(opt1(S.star(t, last)), True{}, no_star(t, last))
        case False{}:
          falsy_and(opt1(S.static(SCon{h, t})), True{}, no_static(SCon{h, t}))
    case True{}:
      %CS.cut_whole(t) : {opt1(S.capture(S.cut(t))) && Bool.not(String.ends_with(SCon{h, _}, "?")) == False{} : Bool}
      capture_opt(h, S.cut(t))

def piece_opt(raw: String, +last: Bool) ->
    {opt1(S.piece(raw, last)) && Bool.not(String.starts_with(raw, ":") && String.ends_with(raw, "?")) == False{} : Bool}:
  match raw:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      lead_opt(h, t, last, Char.is_eq(h, ':'), Char.is_eq(h, '*'))

def opt_both(m: Maybe<&2, P.Segment>, q: Maybe<&2, List<&2, P.Segment>>) ->
    {opt_m(S.both(m, q)) == opt1(m) && opt_m(q) : Bool}:
  match m q:
    case None{} q2:
      {==}
    case Some{+s} None{}:
      Equal.sym(Bool, S.optional(s) && False{}, False{}, and_false(S.optional(s)))
    case Some{s} Some{ss}:
      {==}

def empty_both(m: Maybe<&2, P.Segment>, q: Maybe<&2, List<&2, P.Segment>>) ->
    {empty_m(S.both(m, q)) == False{} : Bool}:
  match m q:
    case None{} q2:
      {==}
    case Some{s} None{}:
      {==}
    case Some{s} Some{ss}:
      {==}

def comb(a: Bool, b: Bool, x: Bool, y: Bool, h1: {a && Bool.not(x) == False{} : Bool}, h2: {b && Bool.not(y) == False{} : Bool}) ->
    {(a && b) && Bool.not(x && y) == False{} : Bool}:
  match a b x y:
    case False{} b2 x2 y2:
      {==}
    case True{} False{} x2 y2:
      {==}
    case True{} True{} False{} y2:
      Bits.absurd({(True{} && True{}) && Bool.not(False{} && y2) == False{} : Bool}, Bits.false_true(Equal.sym(Bool, True{}, False{}, h1)))
    case True{} True{} True{} False{}:
      Bits.absurd({(True{} && True{}) && Bool.not(True{} && False{}) == False{} : Bool}, Bits.false_true(Equal.sym(Bool, True{}, False{}, h2)))
    case True{} True{} True{} True{}:
      {==}

def chain(rest: List<&2, String>) -> {opt_m(S.pieces(rest)) && Bool.not(P.optional_sources(rest)) == False{} : Bool}:
  match rest:
    case Nil{}:
      {==}
    case +r <> +t:
      %Equal.sym(Bool, opt_m(S.both(S.piece(r, List.is_empty(&2, String, t)), S.pieces(t))), opt1(S.piece(r, List.is_empty(&2, String, t))) && opt_m(S.pieces(t)), opt_both(S.piece(r, List.is_empty(&2, String, t)), S.pieces(t))) : {_ && Bool.not(P.optional_sources(r <> t)) == False{} : Bool}
      comb(opt1(S.piece(r, List.is_empty(&2, String, t))), opt_m(S.pieces(t)), String.starts_with(r, ":") && String.ends_with(r, "?"), P.optional_sources(t), piece_opt(r, List.is_empty(&2, String, t)), chain(t))

def chain_at(+rest: List<&2, String>, +ys: List<&2, P.Segment>, e: {S.pieces(rest) == Some{ys} : Maybe<&2, List<&2, P.Segment>>}) ->
    {S.all_optional(ys) && Bool.not(P.optional_sources(rest)) == False{} : Bool}:
  %e : {opt_m(_) && Bool.not(P.optional_sources(rest)) == False{} : Bool}
  chain(rest)

def implied(x: Bool, y: Bool, h: {x && Bool.not(y) == False{} : Bool}) -> {x == Bool.not(Bool.not(y)) && x : Bool}:
  match x y:
    case True{} True{}:
      {==}
    case True{} False{}:
      Bits.absurd({True{} == Bool.not(Bool.not(False{})) && True{} : Bool}, Bits.false_true(Equal.sym(Bool, True{}, False{}, h)))
    case False{} True{}:
      {==}
    case False{} False{}:
      {==}

def opt_chain(+rest: List<&2, String>, +ys: List<&2, P.Segment>, e: {S.pieces(rest) == Some{ys} : Maybe<&2, List<&2, P.Segment>>}) ->
    {S.all_optional(ys) == Bool.not(Bool.not(P.optional_sources(rest))) && P.all_optional(ys) : Bool}:
  %Equal.sym(Bool, P.all_optional(ys), S.all_optional(ys), all_optional_eq(ys)) : {S.all_optional(ys) == Bool.not(Bool.not(P.optional_sources(rest))) && _ : Bool}
  implied(S.all_optional(ys), P.optional_sources(rest), chain_at(rest, ys, e))

def length_at(rest: List<&2, String>, +ys: List<&2, P.Segment>, e: {S.pieces(rest) == Some{ys} : Maybe<&2, List<&2, P.Segment>>}) ->
    {List.is_empty(&2, P.Segment, ys) == Bool.not(Bool.not(List.is_empty(&2, String, rest))) && True{} : Bool}:
  match rest:
    case Nil{}:
      Equal.sym(Bool, True{}, List.is_empty(&2, P.Segment, ys), Equal.cong(Maybe<&2, List<&2, P.Segment>>, Bool, m => empty_m(m), Some{Nil{}}, Some{ys}, e))
    case +r <> +t:
      Equal.trans(Bool, List.is_empty(&2, P.Segment, ys), empty_m(S.both(S.piece(r, List.is_empty(&2, String, t)), S.pieces(t))), False{},
        Equal.sym(Bool, empty_m(S.both(S.piece(r, List.is_empty(&2, String, t)), S.pieces(t))), List.is_empty(&2, P.Segment, ys), Equal.cong(Maybe<&2, List<&2, P.Segment>>, Bool, m => empty_m(m), S.both(S.piece(r, List.is_empty(&2, String, t)), S.pieces(t)), Some{ys}, e)),
        empty_both(S.piece(r, List.is_empty(&2, String, t)), S.pieces(t)))

# ---------------------------------------------------------------------------
# Placement and names, per segment.

def placed_at(s: P.Segment, +rest: List<&2, String>, +ys: List<&2, P.Segment>, e: {S.pieces(rest) == Some{ys} : Maybe<&2, List<&2, P.Segment>>}) ->
    {S.placed(s, ys) == Bool.not(CS.misplaced(s, rest)) && P.optional_tail_ok(s, ys) : Bool}:
  match s:
    case P.Static{raw}:
      {==}
    case P.Capture{name, c, True{}}:
      opt_chain(rest, ys, e)
    case P.Capture{name, c, False{}}:
      {==}
    case P.Wildcard{name}:
      length_at(rest, ys, e)
    case P.InteriorWildcard{}:
      {==}
    case P.PrefixWildcard{p}:
      length_at(rest, ys, e)
    case P.Span{name}:
      {==}

def pl_at(+s: P.Segment, +rest: List<&2, String>, +inv: {P.invalid_tail(s, rest) == CS.misplaced(s, rest) : Bool}, +ys: List<&2, P.Segment>, e: {S.pieces(rest) == Some{ys} : Maybe<&2, List<&2, P.Segment>>}) ->
    {S.placed(s, ys) == Bool.not(P.invalid_tail(s, rest)) && P.optional_tail_ok(s, ys) : Bool}:
  %Equal.sym(Bool, P.invalid_tail(s, rest), CS.misplaced(s, rest), inv) : {S.placed(s, ys) == Bool.not(_) && P.optional_tail_ok(s, ys) : Bool}
  placed_at(s, rest, ys, e)

def rules_at(s: P.Segment, +names: List<&2, String>, +ys: List<&2, P.Segment>) ->
    {S.rules(s <> ys, names) == (Bool.not(P.duplicate(P.segment_name(s), names)) && S.placed(s, ys)) && S.rules(ys, P.add_name(P.segment_name(s), names)) : Bool}:
  match s:
    case P.Static{raw}:
      {==}
    case P.Capture{+name, +c, +o}:
      Equal.cong(Bool, Bool, x => (Bool.not(x) && S.placed(P.Capture{name, c, o}, ys)) && S.rules(ys, name <> names), S.used(names, name), P.seen(names, name), Equal.sym(Bool, P.seen(names, name), S.used(names, name), seen_eq(names, name)))
    case P.Wildcard{+name}:
      Equal.cong(Bool, Bool, x => (Bool.not(x) && S.placed(P.Wildcard{name}, ys)) && S.rules(ys, name <> names), S.used(names, name), P.seen(names, name), Equal.sym(Bool, P.seen(names, name), S.used(names, name), seen_eq(names, name)))
    case P.InteriorWildcard{}:
      {==}
    case P.PrefixWildcard{p}:
      {==}
    case P.Span{+name}:
      Equal.cong(Bool, Bool, x => (Bool.not(x) && S.placed(P.Span{name}, ys)) && S.rules(ys, name <> names), S.used(names, name), P.seen(names, name), Equal.sym(Bool, P.seen(names, name), S.used(names, name), seen_eq(names, name)))

# ---------------------------------------------------------------------------
# The segment list: the compiler's interleaved checks are the spec's rules.

def Segs() -> Data:
  List<&2, P.Segment>

def ok_list(r: Result<&2, &2, P.PatternError, Segs>) -> Maybe<&2, Segs>:
  match r:
    case Done{xs}:
      Some{xs}
    case Fail{e}:
      None{}

def keep_list(ok: Bool, +segs: Segs) -> Maybe<&2, Segs>:
  match ok:
    case True{}:
      Some{segs}
    case False{}:
      None{}

def after(q: Maybe<&2, Segs>, +names: List<&2, String>) -> Maybe<&2, Segs>:
  match q:
    case None{}:
      None{}
    case Some{+segs}:
      keep_list(S.rules(segs, names), segs)

# What compile_segments does once the head segment is parsed and located.
def tail(+seg: P.Segment, +raw: String, +rest: List<&2, String>, +names: List<&2, String>) -> Result<&2, &2, P.PatternError, Segs>:
  E.choose(Result<&2, &2, P.PatternError, Segs>, P.duplicate(P.segment_name(seg), names), u => (
    Fail{P.PatternError{P.DuplicateName{}, raw}}
  ), u => (
    E.choose(Result<&2, &2, P.PatternError, Segs>, P.invalid_tail(seg, rest), u => (
      Fail{P.PatternError{P.terminal_error(seg), raw}}
    ), u => (
      Result.bind(&2, &2, P.PatternError, Segs, Segs, P.compile_segments(rest, P.add_name(P.segment_name(seg), names)), +ys => E.choose(Result<&2, &2, P.PatternError, Segs>, P.optional_tail_ok(seg, ys), u => Done{seg <> ys}, u => Fail{P.PatternError{P.OptionalNotLast{}, raw}}))
    ))
  ))

def bound(+s: P.Segment, +raw: String, r: Result<&2, &2, P.PatternError, Segs>) -> Maybe<&2, Segs>:
  ok_list(Result.bind(&2, &2, P.PatternError, Segs, Segs, r, +ys => E.choose(Result<&2, &2, P.PatternError, Segs>, P.optional_tail_ok(s, ys), u => Done{s <> ys}, u => Fail{P.PatternError{P.OptionalNotLast{}, raw}})))

def kept(+s: P.Segment, m: Maybe<&2, Segs>) -> Maybe<&2, Segs>:
  Maybe.bind(&2, Segs, Segs, m, +y => keep_list(P.optional_tail_ok(s, y), s <> y))

def keep_tail(b: Bool, +ys: Segs, +s: P.Segment, +raw: String) ->
    {ok_list(E.choose(Result<&2, &2, P.PatternError, Segs>, b, u => Done{s <> ys}, u => Fail{P.PatternError{P.OptionalNotLast{}, raw}})) == keep_list(b, s <> ys) : Maybe<&2, Segs>}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def bind_tail(+s: P.Segment, +raw: String, r: Result<&2, &2, P.PatternError, Segs>) ->
    {bound(s, raw, r) == kept(s, ok_list(r)) : Maybe<&2, Segs>}:
  match r:
    case Fail{e}:
      {==}
    case Done{+ys}:
      keep_tail(P.optional_tail_ok(s, ys), ys, s, raw)

def finish(a: Bool, +s: P.Segment, +ys: Segs) ->
    {kept(s, keep_list(a, ys)) == keep_list(P.optional_tail_ok(s, ys) && a, s <> ys) : Maybe<&2, Segs>}:
  match a:
    case True{}:
      Equal.cong(Bool, Maybe<&2, Segs>, x => keep_list(x, s <> ys), P.optional_tail_ok(s, ys), P.optional_tail_ok(s, ys) && True{}, Equal.sym(Bool, P.optional_tail_ok(s, ys) && True{}, P.optional_tail_ok(s, ys), and_true(P.optional_tail_ok(s, ys))))
    case False{}:
      Equal.cong(Bool, Maybe<&2, Segs>, x => keep_list(x, s <> ys), False{}, P.optional_tail_ok(s, ys) && False{}, Equal.sym(Bool, P.optional_tail_ok(s, ys) && False{}, False{}, and_false(P.optional_tail_ok(s, ys))))

def finq(+s: P.Segment, +names: List<&2, String>, +ns: List<&2, String>, q: Maybe<&2, Segs>,
    rules_eq: @ys: Segs -> {S.rules(s <> ys, names) == (Bool.not(False{}) && S.placed(s, ys)) && S.rules(ys, ns) : Bool},
    pl: @ys: Segs -> {q == Some{ys} : Maybe<&2, Segs>} -> {S.placed(s, ys) == Bool.not(False{}) && P.optional_tail_ok(s, ys) : Bool}) ->
    {kept(s, after(q, ns)) == after(S.both(Some{s}, q), names) : Maybe<&2, Segs>}:
  match q:
    case None{}:
      {==}
    case Some{+ys}:
      %Equal.sym(Bool, S.rules(s <> ys, names), (Bool.not(False{}) && S.placed(s, ys)) && S.rules(ys, ns), rules_eq(ys)) : {kept(s, keep_list(S.rules(ys, ns), ys)) == keep_list(_, s <> ys) : Maybe<&2, Segs>}
      %Equal.sym(Bool, S.placed(s, ys), Bool.not(False{}) && P.optional_tail_ok(s, ys), pl(ys, {==})) : {kept(s, keep_list(S.rules(ys, ns), ys)) == keep_list((Bool.not(False{}) && _) && S.rules(ys, ns), s <> ys) : Maybe<&2, Segs>}
      finish(S.rules(ys, ns), s, ys)

def dupq(+s: P.Segment, +names: List<&2, String>, +ns: List<&2, String>, q: Maybe<&2, Segs>,
    rules_eq: @ys: Segs -> {S.rules(s <> ys, names) == (Bool.not(True{}) && S.placed(s, ys)) && S.rules(ys, ns) : Bool}) ->
    {None{} == after(S.both(Some{s}, q), names) : Maybe<&2, Segs>}:
  match q:
    case None{}:
      {==}
    case Some{+ys}:
      %Equal.sym(Bool, S.rules(s <> ys, names), (Bool.not(True{}) && S.placed(s, ys)) && S.rules(ys, ns), rules_eq(ys)) : {None{} == keep_list(_, s <> ys) : Maybe<&2, Segs>}
      {==}

def badq(+s: P.Segment, +names: List<&2, String>, +ns: List<&2, String>, q: Maybe<&2, Segs>,
    rules_eq: @ys: Segs -> {S.rules(s <> ys, names) == (Bool.not(False{}) && S.placed(s, ys)) && S.rules(ys, ns) : Bool},
    pl: @ys: Segs -> {q == Some{ys} : Maybe<&2, Segs>} -> {S.placed(s, ys) == Bool.not(True{}) && P.optional_tail_ok(s, ys) : Bool}) ->
    {None{} == after(S.both(Some{s}, q), names) : Maybe<&2, Segs>}:
  match q:
    case None{}:
      {==}
    case Some{+ys}:
      %Equal.sym(Bool, S.rules(s <> ys, names), (Bool.not(False{}) && S.placed(s, ys)) && S.rules(ys, ns), rules_eq(ys)) : {None{} == keep_list(_, s <> ys) : Maybe<&2, Segs>}
      %Equal.sym(Bool, S.placed(s, ys), Bool.not(True{}) && P.optional_tail_ok(s, ys), pl(ys, {==})) : {None{} == keep_list((Bool.not(False{}) && _) && S.rules(ys, ns), s <> ys) : Maybe<&2, Segs>}
      {==}

def checks(+s: P.Segment, +raw: String, +names: List<&2, String>, d: Bool, iv: Bool, r: Result<&2, &2, P.PatternError, Segs>, q: Maybe<&2, Segs>, +ns: List<&2, String>,
    ihq: {ok_list(r) == after(q, ns) : Maybe<&2, Segs>},
    rules_eq: @ys: Segs -> {S.rules(s <> ys, names) == (Bool.not(d) && S.placed(s, ys)) && S.rules(ys, ns) : Bool},
    pl: @ys: Segs -> {q == Some{ys} : Maybe<&2, Segs>} -> {S.placed(s, ys) == Bool.not(iv) && P.optional_tail_ok(s, ys) : Bool}) ->
    {ok_list(E.choose(Result<&2, &2, P.PatternError, Segs>, d, u => Fail{P.PatternError{P.DuplicateName{}, raw}}, u => (
      E.choose(Result<&2, &2, P.PatternError, Segs>, iv, u => Fail{P.PatternError{P.terminal_error(s), raw}}, u => (
        Result.bind(&2, &2, P.PatternError, Segs, Segs, r, +ys => E.choose(Result<&2, &2, P.PatternError, Segs>, P.optional_tail_ok(s, ys), u => Done{s <> ys}, u => Fail{P.PatternError{P.OptionalNotLast{}, raw}}))
      ))
    ))) == after(S.both(Some{s}, q), names) : Maybe<&2, Segs>}:
  match d iv:
    case True{} iv2:
      dupq(s, names, ns, q, rules_eq)
    case False{} True{}:
      badq(s, names, ns, q, rules_eq, pl)
    case False{} False{}:
      Equal.trans(Maybe<&2, Segs>, bound(s, raw, r), kept(s, ok_list(r)), after(S.both(Some{s}, q), names), bind_tail(s, raw, r),
        Equal.trans(Maybe<&2, Segs>, kept(s, ok_list(r)), kept(s, after(q, ns)), after(S.both(Some{s}, q), names),
          Equal.cong(Maybe<&2, Segs>, Maybe<&2, Segs>, m => kept(s, m), ok_list(r), after(q, ns), ihq),
          finq(s, names, ns, q, rules_eq, pl)))

def located_step(+s: P.Segment, +raw: String, +rest: List<&2, String>, +names: List<&2, String>,
    +inv: {P.invalid_tail(s, rest) == CS.misplaced(s, rest) : Bool},
    ih: @ns: List<&2, String> -> {ok_list(P.compile_segments(rest, ns)) == after(S.pieces(rest), ns) : Maybe<&2, Segs>}) ->
    {ok_list(tail(s, raw, rest, names)) == after(S.both(Some{s}, S.pieces(rest)), names) : Maybe<&2, Segs>}:
  checks(s, raw, names, P.duplicate(P.segment_name(s), names), P.invalid_tail(s, rest), P.compile_segments(rest, P.add_name(P.segment_name(s), names)), S.pieces(rest), P.add_name(P.segment_name(s), names),
    ih(P.add_name(P.segment_name(s), names)), ys => rules_at(s, names, ys), ys => e => pl_at(s, rest, inv, ys, e))

def step(+raw: String, +rest: List<&2, String>, +names: List<&2, String>, r: Result<&2, &2, P.PatternError, P.Segment>,
    e: {seg_view(r, rest) == S.piece(raw, List.is_empty(&2, String, rest)) : Maybe<&2, P.Segment>},
    ih: @ns: List<&2, String> -> {ok_list(P.compile_segments(rest, ns)) == after(S.pieces(rest), ns) : Maybe<&2, Segs>}) ->
    {ok_list(Result.bind(&2, &2, P.PatternError, P.Segment, Segs, r, seg => tail(P.located(seg, rest), raw, rest, names))) == after(S.both(S.piece(raw, List.is_empty(&2, String, rest)), S.pieces(rest)), names) : Maybe<&2, Segs>}:
  match r:
    case Fail{err}:
      %e : {None{} == after(S.both(_, S.pieces(rest)), names) : Maybe<&2, Segs>}
      {==}
    case Done{+p}:
      %e : {ok_list(tail(P.located(p, rest), raw, rest, names)) == after(S.both(_, S.pieces(rest)), names) : Maybe<&2, Segs>}
      located_step(P.located(p, rest), raw, rest, names, CS.tail_inv(p, rest), ih)

def segments_spec(xs: List<&2, String>, +names: List<&2, String>) ->
    {ok_list(P.compile_segments(xs, names)) == after(S.pieces(xs), names) : Maybe<&2, Segs>}:
  match xs:
    case Nil{}:
      {==}
    case +raw <> +rest:
      step(raw, rest, names, P.compile_segment(raw), segment_view(raw, rest), ns => segments_spec(rest, ns))

# ---------------------------------------------------------------------------
# Spans: the compiler's left-to-right check is the spec's declarative rule.

def no_span_eq(segs: List<&2, P.Segment>) -> {P.no_span(segs) == Bool.not(S.has_span(segs)) || False{} : Bool}:
  match segs:
    case Nil{}:
      {==}
    case P.Span{name} <> t:
      {==}
    case P.Static{raw} <> +t:
      no_span_eq(t)
    case P.Capture{name, c, o} <> +t:
      no_span_eq(t)
    case P.Wildcard{name} <> +t:
      no_span_eq(t)
    case P.InteriorWildcard{} <> +t:
      no_span_eq(t)
    case P.PrefixWildcard{p} <> +t:
      no_span_eq(t)

def fixed_eq(segs: List<&2, P.Segment>) -> {P.fixed_tail(segs) == S.fixed(segs) : Bool}:
  match segs:
    case Nil{}:
      {==}
    case P.Static{+raw} <> +t:
      %Equal.sym(Bool, P.no_percent(raw), S.no_percent(raw), no_percent_eq(raw)) : {_ && P.fixed_tail(t) == S.no_percent(raw) && S.fixed(t) : Bool}
      Equal.cong(Bool, Bool, x => S.no_percent(raw) && x, P.fixed_tail(t), S.fixed(t), fixed_eq(t))
    case P.Capture{name, c, o} <> +t:
      fixed_eq(t)
    case P.Wildcard{name} <> t:
      {==}
    case P.InteriorWildcard{} <> t:
      {==}
    case P.PrefixWildcard{p} <> t:
      {==}
    case P.Span{name} <> t:
      {==}

def fw_static(np: Bool, +t: List<&2, P.Segment>, ih: {S.no_wildcard(t) && S.fixed(t) == S.fixed(t) : Bool}) ->
    {S.no_wildcard(t) && (np && S.fixed(t)) == np && S.fixed(t) : Bool}:
  match np:
    case True{}:
      ih
    case False{}:
      and_false(S.no_wildcard(t))

# Fixed segments hold no wildcard.
def fixed_tame(segs: List<&2, P.Segment>) -> {S.no_wildcard(segs) && S.fixed(segs) == S.fixed(segs) : Bool}:
  match segs:
    case Nil{}:
      {==}
    case P.Static{+raw} <> +t:
      fw_static(S.no_percent(raw), t, fixed_tame(t))
    case P.Capture{name, c, o} <> +t:
      fixed_tame(t)
    case P.Wildcard{name} <> t:
      {==}
    case P.InteriorWildcard{} <> t:
      {==}
    case P.PrefixWildcard{p} <> t:
      {==}
    case P.Span{name} <> +t:
      and_false(S.no_wildcard(t))

def anchored_eq(segs: List<&2, P.Segment>) -> {P.span_tail(segs) == S.no_wildcard(segs) && S.anchored(segs) : Bool}:
  match segs:
    case Nil{}:
      {==}
    case P.Static{+raw} <> +t:
      Equal.trans(Bool, P.no_percent(raw) && P.fixed_tail(t), S.no_percent(raw) && S.fixed(t), S.no_wildcard(t) && (S.no_percent(raw) && S.fixed(t)),
        fixed_eq(P.Static{raw} <> t),
        Equal.sym(Bool, S.no_wildcard(t) && (S.no_percent(raw) && S.fixed(t)), S.no_percent(raw) && S.fixed(t), fw_static(S.no_percent(raw), t, fixed_tame(t))))
    case P.Capture{name, c, o} <> +t:
      Equal.sym(Bool, S.no_wildcard(t) && False{}, False{}, and_false(S.no_wildcard(t)))
    case P.Span{name} <> +t:
      Equal.sym(Bool, S.no_wildcard(t) && False{}, False{}, and_false(S.no_wildcard(t)))
    case P.Wildcard{name} <> t:
      {==}
    case P.InteriorWildcard{} <> t:
      {==}
    case P.PrefixWildcard{p} <> t:
      {==}

def spans_eq(segs: List<&2, P.Segment>) -> {P.spans_ok(segs) == S.spans(segs) : Bool}:
  match segs:
    case Nil{}:
      {==}
    case P.Static{raw} <> +t:
      spans_eq(t)
    case P.Capture{name, c, o} <> +t:
      spans_eq(t)
    case P.Span{name} <> +t:
      anchored_eq(t)
    case P.Wildcard{name} <> +t:
      no_span_eq(t)
    case P.InteriorWildcard{} <> +t:
      no_span_eq(t)
    case P.PrefixWildcard{p} <> +t:
      no_span_eq(t)

# ---------------------------------------------------------------------------
# The body after the leading slash, and the whole source.

def accept_view(+segs: Segs, +t: String, ok: Bool) ->
    {S.accepted(E.choose(Result<&2, &2, P.PatternError, P.Pattern>, ok, u => Done{P.Pattern{segs}}, u => Fail{P.PatternError{P.InvalidSpan{}, t}})) == S.accept(ok, segs) : Maybe<&2, P.Pattern>}:
  match ok:
    case True{}:
      {==}
    case False{}:
      {==}

def checked_view(+segs: Segs, +t: String) -> {S.accepted(P.checked(segs, t)) == S.accept(S.spans(segs), segs) : Maybe<&2, P.Pattern>}:
  %spans_eq(segs) : {S.accepted(P.checked(segs, t)) == S.accept(_, segs) : Maybe<&2, P.Pattern>}
  accept_view(segs, t, P.spans_ok(segs))

def gated(+t: String, m: Maybe<&2, Segs>) -> Maybe<&2, P.Pattern>:
  Maybe.bind(&2, Segs, P.Pattern, m, +xs => S.accepted(P.checked(xs, t)))

def rules_gate(a: Bool, +segs: Segs, +t: String) -> {gated(t, keep_list(a, segs)) == S.accept(a && S.spans(segs), segs) : Maybe<&2, P.Pattern>}:
  match a:
    case True{}:
      checked_view(segs, t)
    case False{}:
      {==}

def checked_q(q: Maybe<&2, Segs>, +t: String) -> {gated(t, after(q, Nil{})) == S.checked(q) : Maybe<&2, P.Pattern>}:
  match q:
    case None{}:
      {==}
    case Some{+segs}:
      rules_gate(S.rules(segs, Nil{}), segs, t)

def bind_body(r: Result<&2, &2, P.PatternError, Segs>, +t: String) ->
    {S.accepted(Result.bind(&2, &2, P.PatternError, Segs, P.Pattern, r, +xs => P.checked(xs, t))) == gated(t, ok_list(r)) : Maybe<&2, P.Pattern>}:
  match r:
    case Fail{e}:
      {==}
    case Done{xs}:
      {==}

def body_split(+xs: List<&2, String>, +t: String) ->
    {S.accepted(Result.bind(&2, &2, P.PatternError, Segs, P.Pattern, P.compile_segments(xs, Nil{}), +ys => P.checked(ys, t))) == S.checked(S.pieces(xs)) : Maybe<&2, P.Pattern>}:
  Equal.trans(Maybe<&2, P.Pattern>, S.accepted(Result.bind(&2, &2, P.PatternError, Segs, P.Pattern, P.compile_segments(xs, Nil{}), +ys => P.checked(ys, t))), gated(t, ok_list(P.compile_segments(xs, Nil{}))), S.checked(S.pieces(xs)),
    bind_body(P.compile_segments(xs, Nil{}), t),
    Equal.trans(Maybe<&2, P.Pattern>, gated(t, ok_list(P.compile_segments(xs, Nil{}))), gated(t, after(S.pieces(xs), Nil{})), S.checked(S.pieces(xs)),
      Equal.cong(Maybe<&2, Segs>, Maybe<&2, P.Pattern>, m => gated(t, m), ok_list(P.compile_segments(xs, Nil{})), after(S.pieces(xs), Nil{}), segments_spec(xs, Nil{})),
      checked_q(S.pieces(xs), t)))

def body_eq(+t: String) -> {S.accepted(P.compile_body(t)) == S.body(t) : Maybe<&2, P.Pattern>}:
  %Equal.sym(List<&2, String>, T.split(t, '/'), String.split(t, '/'), TP.split_equiv(t, '/')) : {S.accepted(Result.bind(&2, &2, P.PatternError, Segs, P.Pattern, P.compile_segments(_, Nil{}), +ys => P.checked(ys, t))) == S.body(t) : Maybe<&2, P.Pattern>}
  body_split(String.split(t, '/'), t)

# BND-83: compiling succeeds with a pattern exactly when the spec gives it,
# and fails exactly when the spec gives nothing.
def compile_spec(+source: String) -> {S.accepted(P.compile(source)) == S.compile(source) : Maybe<&2, P.Pattern>}:
  CS.top(source, u => body_eq(u))
