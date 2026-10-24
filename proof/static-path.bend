# BND-45: static path confinement. Every lemma is over variables; the final
# check in Path.guard carries the whole argument, so no lemma looks at
# percent decoding. The lemmas reason about the recursive model (P); the
# six at the end carry them to the stack-safe resolver through
# static-path-equiv.bend (BND-84).
import Base
import ./static-path-model.bend as P
import ../src/static/path.bend as Path
import ./static-path-equiv.bend as PE
import ./static-spec.bend as S

def distinguish(b: Bool) -> Type:
  match b:
    case False{}: Unit
    case True{}: Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : distinguish(_)
  Unit{}

def true_false(e: {True{} == False{} : Bool}) -> Empty:
  false_true(Equal.sym(Bool, True{}, False{}, e))

def absurd(-A: Type, e: Empty) -> A:
  match e:

def nat_disc(n: Nat) -> Type:
  match n:
    case 0n: Unit
    case 1n+p: Empty

def zero_succ(n: Nat, e: {0n == 1n+n : Nat}) -> Empty:
  %e : nat_disc(_)
  Unit{}

def and_left(a: Bool, b: Bool, ok: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: ok

def and_right(a: Bool, b: Bool, ok: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}: ok
    case False{}: absurd({b == True{} : Bool}, false_true(ok))

def and_intro(a: Bool, b: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}) -> {a && b == True{} : Bool}:
  match a:
    case True{}: eb
    case False{}: absurd({False{} && b == True{} : Bool}, false_true(ea))

# Characters. The five tests are generalized to Bools so both definitions
# reduce once the Bools are known.

def code_slash(a: Bool, b: Bool, c: Bool, d: Bool, e: Bool, ok: {P.code_ok(a, b, c, d, e) == True{} : Bool}) -> {c == False{} : Bool}:
  match a:
    case True{}: absurd({c == False{} : Bool}, false_true(ok))
    case False{}:
      match b:
        case True{}: absurd({c == False{} : Bool}, false_true(ok))
        case False{}:
          match c:
            case True{}: absurd({True{} == False{} : Bool}, false_true(ok))
            case False{}: {==}

def code_safe(a: Bool, b: Bool, c: Bool, d: Bool, e: Bool, ok: {P.code_ok(a, b, c, d, e) == True{} : Bool}) -> {Bool.not(a) && Bool.not(b) && Bool.not(d) && Bool.not(e) == True{} : Bool}:
  match a:
    case True{}: absurd({Bool.not(True{}) && Bool.not(b) && Bool.not(d) && Bool.not(e) == True{} : Bool}, false_true(ok))
    case False{}:
      match b:
        case True{}: absurd({Bool.not(False{}) && Bool.not(True{}) && Bool.not(d) && Bool.not(e) == True{} : Bool}, false_true(ok))
        case False{}:
          match c:
            case True{}: absurd({Bool.not(False{}) && Bool.not(False{}) && Bool.not(d) && Bool.not(e) == True{} : Bool}, false_true(ok))
            case False{}:
              match d:
                case True{}: absurd({Bool.not(False{}) && Bool.not(False{}) && Bool.not(True{}) && Bool.not(e) == True{} : Bool}, false_true(ok))
                case False{}:
                  match e:
                    case True{}: absurd({Bool.not(False{}) && Bool.not(False{}) && Bool.not(False{}) && Bool.not(True{}) == True{} : Bool}, false_true(ok))
                    case False{}: {==}

def char_no_slash(+code: U32, ok: {P.char_ok(Chr{code}) == True{} : Bool}) -> {Char.is_eq(Chr{code}, '/') == False{} : Bool}:
  code_slash(U32.is_lt(code, 32), U32.is_eq(code, 127), Char.is_eq(Chr{code}, '/'), U32.is_eq(code, 92), U32.is_eq(code, 37), ok)

def char_safe(+code: U32, ok: {P.char_ok(Chr{code}) == True{} : Bool}) -> {S.char_safe(code) == True{} : Bool}:
  code_safe(U32.is_lt(code, 32), U32.is_eq(code, 127), Char.is_eq(Chr{code}, '/'), U32.is_eq(code, 92), U32.is_eq(code, 37), ok)

def chars_safe(s: String, +ok: {P.chars_ok(s) == True{} : Bool}) -> {S.chars_safe(s) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+code}, +t}:
      and_intro(S.char_safe(code), S.chars_safe(t), char_safe(code, and_left(P.char_ok(Chr{code}), P.chars_ok(t), ok)), chars_safe(t, and_right(P.char_ok(Chr{code}), P.chars_ok(t), ok)))

# Segments.

def segment_chars(s: String, +ok: {P.segment_ok(s) == True{} : Bool}) -> {P.chars_ok(s) == True{} : Bool}:
  match s:
    case SNil{}: absurd({P.chars_ok(SNil{}) == True{} : Bool}, false_true(ok))
    case SCon{Chr{+code}, +t}:
      +head = and_left(Bool.not(U32.is_eq(code, 46)) && P.char_ok(Chr{code}), P.chars_ok(t), ok)
      and_intro(P.char_ok(Chr{code}), P.chars_ok(t), and_right(Bool.not(U32.is_eq(code, 46)), P.char_ok(Chr{code}), head), and_right(Bool.not(U32.is_eq(code, 46)) && P.char_ok(Chr{code}), P.chars_ok(t), ok))

def segment_gen(d: Bool, x: Bool, y: Bool, z: Bool, hd: {Bool.not(d) == True{} : Bool}, hz: {z == True{} : Bool}) -> {Bool.not(False{}) && Bool.not(d && x) && Bool.not(d && y) && z == True{} : Bool}:
  match d:
    case True{}: absurd({Bool.not(False{}) && Bool.not(True{} && x) && Bool.not(True{} && y) && z == True{} : Bool}, false_true(hd))
    case False{}: hz

def segment_safe(s: String, +ok: {P.segment_ok(s) == True{} : Bool}) -> {S.segment_safe(s) == True{} : Bool}:
  match s:
    case SNil{}: absurd({S.segment_safe(SNil{}) == True{} : Bool}, false_true(ok))
    case SCon{Chr{+code}, +t}:
      +head = and_left(Bool.not(U32.is_eq(code, 46)) && P.char_ok(Chr{code}), P.chars_ok(t), ok)
      +hd = and_left(Bool.not(U32.is_eq(code, 46)), P.char_ok(Chr{code}), head)
      segment_gen(U32.is_eq(code, 46), S.empty(t), S.dot(t), S.chars_safe(SCon{Chr{code}, t}), hd, chars_safe(SCon{Chr{code}, t}, segment_chars(SCon{Chr{code}, t}, ok)))

def all_safe(xs: List<&2, String>, +ok: {P.segments_ok(xs) == True{} : Bool}) -> {S.all_safe(xs) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +s <> +t:
      and_intro(S.segment_safe(s), S.all_safe(t), segment_safe(s, and_left(P.segment_ok(s), P.segments_ok(t), ok)), all_safe(t, and_right(P.segment_ok(s), P.segments_ok(t), ok)))

# Splitting a joined path gives back its segments.

def fin_push(c: Char, t: String, rest: List<&2, String>, b: Bool, e: {b == False{} : Bool}) -> {String.split.fin(c, t <> rest, b) == SCon{c, t} <> rest : List<&2, String>}:
  match b:
    case False{}: {==}
    case True{}: absurd({String.split.fin(c, t <> rest, True{}) == SCon{c, t} <> rest : List<&2, String>}, true_false(e))

def split_one(s: String, +ok: {P.chars_ok(s) == True{} : Bool}) -> {String.split(s, '/') == [s] : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+code}, +t}:
      +rec = split_one(t, and_right(P.char_ok(Chr{code}), P.chars_ok(t), ok))
      %Equal.sym(List<&2, String>, String.split(t, '/'), [t], rec) : {String.split.fin(Chr{code}, _, Char.is_eq(Chr{code}, '/')) == [SCon{Chr{code}, t}] : List<&2, String>}
      fin_push(Chr{code}, t, [], Char.is_eq(Chr{code}, '/'), char_no_slash(code, and_left(P.char_ok(Chr{code}), P.chars_ok(t), ok)))

def split_cat(s: String, +x: String, +ok: {P.chars_ok(s) == True{} : Bool}) -> {String.split(String.append(s, SCon{'/', x}), '/') == s <> String.split(x, '/') : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+code}, +t}:
      +rec = split_cat(t, x, and_right(P.char_ok(Chr{code}), P.chars_ok(t), ok))
      %Equal.sym(List<&2, String>, String.split(String.append(t, SCon{'/', x}), '/'), t <> String.split(x, '/'), rec) : {String.split.fin(Chr{code}, _, Char.is_eq(Chr{code}, '/')) == SCon{Chr{code}, t} <> String.split(x, '/') : List<&2, String>}
      fin_push(Chr{code}, t, String.split(x, '/'), Char.is_eq(Chr{code}, '/'), char_no_slash(code, and_left(P.char_ok(Chr{code}), P.chars_ok(t), ok)))

def split_join(rest: List<&2, String>, +first: String, +ok_first: {P.chars_ok(first) == True{} : Bool}, +ok_rest: {P.segments_ok(rest) == True{} : Bool}) -> {String.split(P.join(rest, first), '/') == first <> rest : List<&2, String>}:
  match rest:
    case Nil{}: split_one(first, ok_first)
    case +h <> +t:
      +ok_h = and_left(P.segment_ok(h), P.segments_ok(t), ok_rest)
      +rec = split_join(t, h, segment_chars(h, ok_h), and_right(P.segment_ok(h), P.segments_ok(t), ok_rest))
      +cat = split_cat(first, P.join(t, h), ok_first)
      %Equal.sym(List<&2, String>, String.split(String.append(first, SCon{'/', P.join(t, h)}), '/'), first <> String.split(P.join(t, h), '/'), cat) : {_ == first <> h <> t : List<&2, String>}
      %Equal.sym(List<&2, String>, String.split(P.join(t, h), '/'), h <> t, rec) : {first <> _ == first <> h <> t : List<&2, String>}
      {==}

# A raw path splits into one more piece than it has slashes.

def count_gen(c: Char, n: Nat, b: Bool, parts: List<&2, String>, e: {List.length(&2, String, parts) == 1n+n : Nat}) -> {List.length(&2, String, String.split.fin(c, parts, b)) == 1n+P.slash_count(b, n) : Nat}:
  match b:
    case True{}:
      %Equal.sym(Nat, List.length(&2, String, parts), 1n+n, e) : {1n+_ == 1n+1n+n : Nat}
      {==}
    case False{}:
      match parts:
        case Nil{}: absurd({List.length(&2, String, String.split.fin(c, [], False{})) == 1n+n : Nat}, zero_succ(n, e))
        case +h <> +t: e

def pieces_count(s: String) -> {List.length(&2, String, String.split(s, '/')) == 1n+P.slashes(s) : Nat}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+code}, +t}:
      count_gen(Chr{code}, P.slashes(t), Char.is_eq(Chr{code}, '/'), String.split(t, '/'), pieces_count(t))

# The guard.

def accept_ok(+raw: String, +first: String, +rest: List<&2, String>, b: Bool, +e: {P.check(raw, first, rest) == b : Bool}) -> {S.confined(raw, P.accept(first, rest, b)) == True{} : Bool}:
  match b:
    case False{}: {==}
    case True{}:
      +segs = and_left(P.segment_ok(first) && P.segments_ok(rest), Nat.is_eq(1n+List.length(&2, String, rest), P.slashes(raw)), e)
      +count = and_right(P.segment_ok(first) && P.segments_ok(rest), Nat.is_eq(1n+List.length(&2, String, rest), P.slashes(raw)), e)
      +ok_first = and_left(P.segment_ok(first), P.segments_ok(rest), segs)
      +joined = split_join(rest, first, segment_chars(first, ok_first), and_right(P.segment_ok(first), P.segments_ok(rest), segs))
      %Equal.sym(List<&2, String>, String.split(P.join(rest, first), '/'), first <> rest, joined) : {S.all_safe(_) && Nat.is_eq(1n+List.length(&2, String, _), List.length(&2, String, String.split(raw, '/'))) == True{} : Bool}
      %Equal.sym(Nat, List.length(&2, String, String.split(raw, '/')), 1n+P.slashes(raw), pieces_count(raw)) : {S.all_safe(first <> rest) && Nat.is_eq(1n+List.length(&2, String, first <> rest), _) == True{} : Bool}
      and_intro(S.all_safe(first <> rest), Nat.is_eq(1n+List.length(&2, String, rest), P.slashes(raw)), all_safe(first <> rest, segs), count)

def guard_ok(+raw: String, m: Maybe<&2, Path.Segments>) -> {S.confined(raw, P.guard(raw, m)) == True{} : Bool}:
  match m:
    case None{}: {==}
    case Some{Path.Segments{+first, +rest}}:
      accept_ok(raw, first, rest, P.check(raw, first, rest), {==})

def confined_model(+raw: String, +index: String) -> {S.confined(raw, P.resolve(raw, index)) == True{} : Bool}:
  guard_ok(raw, P.segments(raw, index))

def under_opened(root: String, m: Maybe<&2, String>) -> {P.under(root, m) == S.opened(root, m) : Maybe<&2, String>}:
  match m:
    case None{}: {==}
    case Some{rel}: {==}

def target_model(root: String, +raw: String, +index: String) -> {P.target(root, raw, index) == S.opened(root, P.resolve(raw, index)) : Maybe<&2, String>}:
  under_opened(root, P.resolve(raw, index))

# Per-segment decoding (static_path_segments). The resolver's plain test and
# the spec's agree, so each raw segment decodes the same way in both.

def plain_gen(a: Bool, b: Bool, c: Bool, d: Bool, e: Bool, f: Bool, g: Bool) -> {P.plain_code(a, b, c, d, e, f, g) == Bool.not(a) && Bool.not(b) && Bool.not(c) && Bool.not(d) && Bool.not(e) && Bool.not(f) && Bool.not(g) : Bool}:
  match a:
    case True{}: {==}
    case False{}:
      match b:
        case True{}: {==}
        case False{}:
          match c:
            case True{}: {==}
            case False{}:
              match d:
                case True{}: {==}
                case False{}:
                  match e:
                    case True{}: {==}
                    case False{}:
                      match f:
                        case True{}: {==}
                        case False{}:
                          match g:
                            case True{}: {==}
                            case False{}: {==}

def and_both(x: Bool, y: Bool, v: Bool, w: Bool, e1: {x == y : Bool}, e2: {v == w : Bool}) -> {x && v == y && w : Bool}:
  %e1 : {x && v == _ && w : Bool}
  %e2 : {x && v == x && _ : Bool}
  {==}

def plain_eq(s: String) -> {P.plain(s) == S.plain(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+code}, +t}:
      and_both(P.plain_char(Chr{code}), S.plain_char(code), P.plain(t), S.plain(t), plain_gen(U32.is_lt(code, 32), U32.is_eq(code, 32), U32.is_eq(code, 127), U32.is_lt(127, code), Char.is_eq(Chr{code}, '/'), U32.is_eq(code, 92), U32.is_eq(code, 37)), plain_eq(t))

def decoded_gen(+s: String, b: Bool) -> {P.decoded(s, b) == S.decode_plain(s, b) : Maybe<&2, String>}:
  match b:
    case True{}: {==}
    case False{}: {==}

def segment_eq(+s: String) -> {P.decode_segment(s) == S.decode(s) : Maybe<&2, String>}:
  %plain_eq(s) : {P.decoded(s, P.plain(s)) == S.decode_plain(s, _) : Maybe<&2, String>}
  decoded_gen(s, P.plain(s))

def last_eq(raw: String, +index: String) -> {P.decode_last(raw, index) == S.decode_final(raw, index) : Maybe<&2, String>}:
  match raw:
    case SNil{}: {==}
    case SCon{+c, +t}: segment_eq(SCon{c, t})

def single_eq(x: Maybe<&2, String>) -> {P.single(x) == S.final_only(x) : Maybe<&2, List<&2, String>>}:
  match x:
    case None{}: {==}
    case Some{y}: {==}

def prepend_to_eq(y: String, xs: Maybe<&2, List<&2, String>>) -> {P.prepend_to(y, xs) == S.cons(y, xs) : Maybe<&2, List<&2, String>>}:
  match xs:
    case None{}: {==}
    case Some{ys}: {==}

def prepend_eq(x: Maybe<&2, String>, xs: Maybe<&2, List<&2, String>>) -> {P.prepend(x, xs) == S.cons_decoded(x, xs) : Maybe<&2, List<&2, String>>}:
  match x:
    case None{}: {==}
    case Some{y}: prepend_to_eq(y, xs)

def go_eq(rest: List<&2, String>, +raw: String, +index: String) -> {P.decode_go(rest, raw, index) == S.decode_each(rest, raw, index) : Maybe<&2, List<&2, String>>}:
  match rest:
    case Nil{}:
      %last_eq(raw, index) : {P.single(P.decode_last(raw, index)) == S.final_only(_) : Maybe<&2, List<&2, String>>}
      single_eq(P.decode_last(raw, index))
    case +h <> +t:
      %segment_eq(raw) : {P.prepend(P.decode_segment(raw), P.decode_go(t, h, index)) == S.cons_decoded(_, S.decode_each(t, h, index)) : Maybe<&2, List<&2, String>>}
      %go_eq(t, h, index) : {P.prepend(P.decode_segment(raw), P.decode_go(t, h, index)) == S.cons_decoded(P.decode_segment(raw), _) : Maybe<&2, List<&2, String>>}
      prepend_eq(P.decode_segment(raw), P.decode_go(t, h, index))

def split_eq(ps: List<&2, String>, +index: String) -> {P.split_raw(ps, index) == P.segments_of(S.after_root(ps, index)) : Maybe<&2, Path.Segments>}:
  match ps:
    case Nil{}: {==}
    case h <> t:
      match h:
        case SNil{}:
          match t:
            case Nil{}: {==}
            case +r <> +u:
              %go_eq(u, r, index) : {P.segments_of(P.decode_go(u, r, index)) == P.segments_of(_) : Maybe<&2, Path.Segments>}
              {==}
        case SCon{c, s}: {==}

def accept_pieces(+raw: String, +first: String, +rest: List<&2, String>, b: Bool, +e: {P.check(raw, first, rest) == b : Bool}) -> {S.resolved_pieces(P.accept(first, rest, b)) == S.when_resolved(P.accept(first, rest, b), Some{first <> rest}) : Maybe<&2, List<&2, String>>}:
  match b:
    case False{}: {==}
    case True{}:
      +segs = and_left(P.segment_ok(first) && P.segments_ok(rest), Nat.is_eq(1n+List.length(&2, String, rest), P.slashes(raw)), e)
      +ok_first = and_left(P.segment_ok(first), P.segments_ok(rest), segs)
      +joined = split_join(rest, first, segment_chars(first, ok_first), and_right(P.segment_ok(first), P.segments_ok(rest), segs))
      %joined : {Some{String.split(P.join(rest, first), '/')} == Some{_} : Maybe<&2, List<&2, String>>}
      {==}

def guard_pieces(+raw: String, x: Maybe<&2, List<&2, String>>) -> {S.resolved_pieces(P.guard(raw, P.segments_of(x))) == S.when_resolved(P.guard(raw, P.segments_of(x)), x) : Maybe<&2, List<&2, String>>}:
  match x:
    case None{}: {==}
    case Some{xs}:
      match xs:
        case Nil{}: {==}
        case +h <> +t: accept_pieces(raw, h, t, P.check(raw, h, t), {==})

def segments_model(+raw: String, +index: String) -> {S.resolved_pieces(P.resolve(raw, index)) == S.when_resolved(P.resolve(raw, index), S.decoded(raw, index)) : Maybe<&2, List<&2, String>>}:
  +ps = String.split(raw, '/')
  %Equal.sym(Maybe<&2, Path.Segments>, P.split_raw(ps, index), P.segments_of(S.after_root(ps, index)), split_eq(ps, index)) : {S.resolved_pieces(P.guard(raw, _)) == S.when_resolved(P.guard(raw, _), S.after_root(ps, index)) : Maybe<&2, List<&2, String>>}
  guard_pieces(raw, S.after_root(ps, index))

# Dotfiles (static_path_no_dotfiles).

def segment_visible(s: String, +ok: {P.segment_ok(s) == True{} : Bool}) -> {S.visible(s) == True{} : Bool}:
  match s:
    case SNil{}: absurd({S.visible(SNil{}) == True{} : Bool}, false_true(ok))
    case SCon{Chr{+code}, +t}:
      +head = and_left(Bool.not(U32.is_eq(code, 46)) && P.char_ok(Chr{code}), P.chars_ok(t), ok)
      and_left(Bool.not(U32.is_eq(code, 46)), P.char_ok(Chr{code}), head)

def all_visible(xs: List<&2, String>, +ok: {P.segments_ok(xs) == True{} : Bool}) -> {S.all_visible(xs) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +s <> +t:
      and_intro(S.visible(s), S.all_visible(t), segment_visible(s, and_left(P.segment_ok(s), P.segments_ok(t), ok)), all_visible(t, and_right(P.segment_ok(s), P.segments_ok(t), ok)))

def accept_visible(+raw: String, +first: String, +rest: List<&2, String>, b: Bool, +e: {P.check(raw, first, rest) == b : Bool}) -> {S.no_dotfiles(P.accept(first, rest, b)) == True{} : Bool}:
  match b:
    case False{}: {==}
    case True{}:
      +segs = and_left(P.segment_ok(first) && P.segments_ok(rest), Nat.is_eq(1n+List.length(&2, String, rest), P.slashes(raw)), e)
      +ok_first = and_left(P.segment_ok(first), P.segments_ok(rest), segs)
      +joined = split_join(rest, first, segment_chars(first, ok_first), and_right(P.segment_ok(first), P.segments_ok(rest), segs))
      %Equal.sym(List<&2, String>, String.split(P.join(rest, first), '/'), first <> rest, joined) : {S.all_visible(_) == True{} : Bool}
      all_visible(first <> rest, segs)

def guard_visible(+raw: String, m: Maybe<&2, Path.Segments>) -> {S.no_dotfiles(P.guard(raw, m)) == True{} : Bool}:
  match m:
    case None{}: {==}
    case Some{Path.Segments{+first, +rest}}:
      accept_visible(raw, first, rest, P.check(raw, first, rest), {==})

def no_dotfiles_model(+raw: String, +index: String) -> {S.no_dotfiles(P.resolve(raw, index)) == True{} : Bool}:
  guard_visible(raw, P.segments(raw, index))

# Completeness (static_path_complete, static_path_index).

def plain_ok_gen(a: Bool, b: Bool, c: Bool, d: Bool, e: Bool, f: Bool, g: Bool, h: {Bool.not(a) && Bool.not(b) && Bool.not(c) && Bool.not(d) && Bool.not(e) && Bool.not(f) && Bool.not(g) == True{} : Bool}) -> {P.code_ok(a, c, e, f, g) == True{} : Bool}:
  match a:
    case True{}: absurd({P.code_ok(True{}, c, e, f, g) == True{} : Bool}, false_true(h))
    case False{}:
      match b:
        case True{}: absurd({P.code_ok(False{}, c, e, f, g) == True{} : Bool}, false_true(h))
        case False{}:
          match c:
            case True{}: absurd({P.code_ok(False{}, True{}, e, f, g) == True{} : Bool}, false_true(h))
            case False{}:
              match d:
                case True{}: absurd({P.code_ok(False{}, False{}, e, f, g) == True{} : Bool}, false_true(h))
                case False{}:
                  match e:
                    case True{}: absurd({P.code_ok(False{}, False{}, True{}, f, g) == True{} : Bool}, false_true(h))
                    case False{}:
                      match f:
                        case True{}: absurd({P.code_ok(False{}, False{}, False{}, True{}, g) == True{} : Bool}, false_true(h))
                        case False{}:
                          match g:
                            case True{}: absurd({P.code_ok(False{}, False{}, False{}, False{}, True{}) == True{} : Bool}, false_true(h))
                            case False{}: {==}

def plain_chars(s: String, +ok: {S.plain(s) == True{} : Bool}) -> {P.chars_ok(s) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+code}, +t}:
      +hc = and_left(S.plain_char(code), S.plain(t), ok)
      +ht = and_right(S.plain_char(code), S.plain(t), ok)
      and_intro(P.char_ok(Chr{code}), P.chars_ok(t), plain_ok_gen(U32.is_lt(code, 32), U32.is_eq(code, 32), U32.is_eq(code, 127), U32.is_lt(127, code), Char.is_eq(Chr{code}, '/'), U32.is_eq(code, 92), U32.is_eq(code, 37), hc), plain_chars(t, ht))

def servable_plain(s: String, +ok: {S.servable_segment(s) == True{} : Bool}) -> {S.plain(s) == True{} : Bool}:
  match s:
    case SNil{}: absurd({S.plain(SNil{}) == True{} : Bool}, false_true(ok))
    case SCon{Chr{+code}, +t}: and_right(Bool.not(U32.is_eq(code, 46)), S.plain(SCon{Chr{code}, t}), ok)

def servable_chars(+s: String, +ok: {S.servable_segment(s) == True{} : Bool}) -> {P.chars_ok(s) == True{} : Bool}:
  plain_chars(s, servable_plain(s, ok))

def servable_ok(s: String, +ok: {S.servable_segment(s) == True{} : Bool}) -> {P.segment_ok(s) == True{} : Bool}:
  match s:
    case SNil{}: absurd({P.segment_ok(SNil{}) == True{} : Bool}, false_true(ok))
    case SCon{Chr{+code}, +t}:
      +hd = and_left(Bool.not(U32.is_eq(code, 46)), S.plain(SCon{Chr{code}, t}), ok)
      +chars = plain_chars(SCon{Chr{code}, t}, and_right(Bool.not(U32.is_eq(code, 46)), S.plain(SCon{Chr{code}, t}), ok))
      and_intro(Bool.not(U32.is_eq(code, 46)) && P.char_ok(Chr{code}), P.chars_ok(t), and_intro(Bool.not(U32.is_eq(code, 46)), P.char_ok(Chr{code}), hd, and_left(P.char_ok(Chr{code}), P.chars_ok(t), chars)), and_right(P.char_ok(Chr{code}), P.chars_ok(t), chars))

def servables_ok(xs: List<&2, String>, +ok: {S.servable(xs) == True{} : Bool}) -> {P.segments_ok(xs) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +s <> +t:
      and_intro(P.segment_ok(s), P.segments_ok(t), servable_ok(s, and_left(S.servable_segment(s), S.servable(t), ok)), servables_ok(t, and_right(S.servable_segment(s), S.servable(t), ok)))

# A plain segment skips the decoder.
def plain_segment(+s: String, +ok: {S.servable_segment(s) == True{} : Bool}) -> {P.decode_segment(s) == Some{s} : Maybe<&2, String>}:
  +p = Equal.trans(Bool, P.plain(s), S.plain(s), True{}, plain_eq(s), servable_plain(s, ok))
  %Equal.sym(Bool, P.plain(s), True{}, p) : {P.decoded(s, _) == Some{s} : Maybe<&2, String>}
  {==}

def split_end(s: String, +ok: {P.chars_ok(s) == True{} : Bool}) -> {String.split(String.append(s, SNil{}), '/') == [s] : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+code}, +t}:
      +rec = split_end(t, and_right(P.char_ok(Chr{code}), P.chars_ok(t), ok))
      %Equal.sym(List<&2, String>, String.split(String.append(t, SNil{}), '/'), [t], rec) : {String.split.fin(Chr{code}, _, Char.is_eq(Chr{code}, '/')) == [SCon{Chr{code}, t}] : List<&2, String>}
      fin_push(Chr{code}, t, [], Char.is_eq(Chr{code}, '/'), char_no_slash(code, and_left(P.char_ok(Chr{code}), P.chars_ok(t), ok)))

def slash_none(b: Bool, n: Nat, e: {b == False{} : Bool}) -> {P.slash_count(b, n) == n : Nat}:
  match b:
    case False{}: {==}
    case True{}: absurd({P.slash_count(True{}, n) == n : Nat}, true_false(e))

def slashes_app(s: String, +x: String, +ok: {P.chars_ok(s) == True{} : Bool}) -> {P.slashes(String.append(s, x)) == P.slashes(x) : Nat}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+code}, +t}:
      +rec = slashes_app(t, x, and_right(P.char_ok(Chr{code}), P.chars_ok(t), ok))
      +none = slash_none(Char.is_eq(Chr{code}, '/'), P.slashes(String.append(t, x)), char_no_slash(code, and_left(P.char_ok(Chr{code}), P.chars_ok(t), ok)))
      Equal.trans(Nat, P.slash_count(Char.is_eq(Chr{code}, '/'), P.slashes(String.append(t, x))), P.slashes(String.append(t, x)), P.slashes(x), none, rec)

def nat_refl(n: Nat) -> {Nat.is_eq(n, n) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+p: nat_refl(p)

def join_eq(rest: List<&2, String>, +first: String) -> {P.join(rest, first) == S.joined(rest, first) : String}:
  match rest:
    case Nil{}: {==}
    case +h <> +t:
      %join_eq(t, h) : {String.append(first, SCon{'/', P.join(t, h)}) == String.append(first, SCon{'/', _}) : String}
      {==}

# Request paths without a trailing slash.

def request_split(rest: List<&2, String>, +first: String, +ok: {S.servable(first <> rest) == True{} : Bool}) -> {String.split(String.append(first, S.request(rest)), '/') == first <> rest : List<&2, String>}:
  match rest:
    case Nil{}: split_end(first, servable_chars(first, and_left(S.servable_segment(first), S.servable([]), ok)))
    case +h <> +t:
      +ok_first = servable_chars(first, and_left(S.servable_segment(first), S.servable(h <> t), ok))
      +rec = request_split(t, h, and_right(S.servable_segment(first), S.servable(h <> t), ok))
      +cat = split_cat(first, String.append(h, S.request(t)), ok_first)
      %Equal.sym(List<&2, String>, String.split(String.append(first, SCon{'/', String.append(h, S.request(t))}), '/'), first <> String.split(String.append(h, S.request(t)), '/'), cat) : {_ == first <> h <> t : List<&2, String>}
      %Equal.sym(List<&2, String>, String.split(String.append(h, S.request(t)), '/'), h <> t, rec) : {first <> _ == first <> h <> t : List<&2, String>}
      {==}

def request_slashes(rest: List<&2, String>, +first: String, +ok: {S.servable(first <> rest) == True{} : Bool}) -> {P.slashes(String.append(first, S.request(rest))) == List.length(&2, String, rest) : Nat}:
  match rest:
    case Nil{}: slashes_app(first, SNil{}, servable_chars(first, and_left(S.servable_segment(first), S.servable([]), ok)))
    case +h <> +t:
      +ok_first = servable_chars(first, and_left(S.servable_segment(first), S.servable(h <> t), ok))
      +rec = request_slashes(t, h, and_right(S.servable_segment(first), S.servable(h <> t), ok))
      +app = slashes_app(first, SCon{'/', String.append(h, S.request(t))}, ok_first)
      %rec : {P.slashes(String.append(first, SCon{'/', String.append(h, S.request(t))})) == 1n+_ : Nat}
      app

def request_go(rest: List<&2, String>, +first: String, +index: String, +ok: {S.servable(first <> rest) == True{} : Bool}) -> {P.decode_go(rest, first, index) == Some{first <> rest} : Maybe<&2, List<&2, String>>}:
  match rest:
    case Nil{}:
      match first:
        case SNil{}: absurd({P.decode_go([], SNil{}, index) == Some{[SNil{}]} : Maybe<&2, List<&2, String>>}, false_true(ok))
        case SCon{+c, +t}:
          %Equal.sym(Maybe<&2, String>, P.decode_segment(SCon{c, t}), Some{SCon{c, t}}, plain_segment(SCon{c, t}, and_left(S.servable_segment(SCon{c, t}), S.servable([]), ok))) : {P.single(_) == Some{[SCon{c, t}]} : Maybe<&2, List<&2, String>>}
          {==}
    case +h <> +t:
      +head = plain_segment(first, and_left(S.servable_segment(first), S.servable(h <> t), ok))
      +rec = request_go(t, h, index, and_right(S.servable_segment(first), S.servable(h <> t), ok))
      %Equal.sym(Maybe<&2, String>, P.decode_segment(first), Some{first}, head) : {P.prepend(_, P.decode_go(t, h, index)) == Some{first <> h <> t} : Maybe<&2, List<&2, String>>}
      %Equal.sym(Maybe<&2, List<&2, String>>, P.decode_go(t, h, index), Some{h <> t}, rec) : {P.prepend(Some{first}, _) == Some{first <> h <> t} : Maybe<&2, List<&2, String>>}
      {==}

def request_check(+first: String, +rest: List<&2, String>, +ok: {S.servable(first <> rest) == True{} : Bool}) -> {P.check(S.request(first <> rest), first, rest) == True{} : Bool}:
  +segs = servables_ok(first <> rest, ok)
  +count = request_slashes(rest, first, ok)
  %Equal.sym(Nat, P.slashes(String.append(first, S.request(rest))), List.length(&2, String, rest), count) : {P.segment_ok(first) && P.segments_ok(rest) && Nat.is_eq(1n+List.length(&2, String, rest), 1n+_) == True{} : Bool}
  and_intro(P.segment_ok(first) && P.segments_ok(rest), Nat.is_eq(1n+List.length(&2, String, rest), 1n+List.length(&2, String, rest)), segs, nat_refl(1n+List.length(&2, String, rest)))

def complete_model(+first: String, +rest: List<&2, String>, +index: String, +ok: {S.servable(first <> rest) == True{} : Bool}) -> {P.resolve(S.request(first <> rest), index) == Some{S.joined(rest, first)} : Maybe<&2, String>}:
  +raw = S.request(first <> rest)
  +split = request_split(rest, first, ok)
  %Equal.sym(List<&2, String>, String.split(String.append(first, S.request(rest)), '/'), first <> rest, split) : {P.guard(raw, P.split_raw(SNil{} <> _, index)) == Some{S.joined(rest, first)} : Maybe<&2, String>}
  %Equal.sym(Maybe<&2, List<&2, String>>, P.decode_go(rest, first, index), Some{first <> rest}, request_go(rest, first, index, ok)) : {P.guard(raw, P.segments_of(_)) == Some{S.joined(rest, first)} : Maybe<&2, String>}
  %Equal.sym(Bool, P.check(raw, first, rest), True{}, request_check(first, rest, ok)) : {P.accept(first, rest, _) == Some{S.joined(rest, first)} : Maybe<&2, String>}
  %join_eq(rest, first) : {Some{P.join(rest, first)} == Some{_} : Maybe<&2, String>}
  {==}

# Request paths with a trailing slash. `pieces_dir` is how such a path splits
# after its leading '/'; `with_index` is what it decodes to.

def pieces_dir(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: [SNil{}]
    case h <> t: h <> pieces_dir(t)

def with_index(xs: List<&2, String>, index: String) -> List<&2, String>:
  match xs:
    case Nil{}: [index]
    case h <> t: h <> with_index(t, index)

def directory_split(rest: List<&2, String>, +first: String, +ok: {S.servable(first <> rest) == True{} : Bool}) -> {String.split(String.append(first, S.directory(rest)), '/') == first <> pieces_dir(rest) : List<&2, String>}:
  match rest:
    case Nil{}: split_cat(first, SNil{}, servable_chars(first, and_left(S.servable_segment(first), S.servable([]), ok)))
    case +h <> +t:
      +ok_first = servable_chars(first, and_left(S.servable_segment(first), S.servable(h <> t), ok))
      +rec = directory_split(t, h, and_right(S.servable_segment(first), S.servable(h <> t), ok))
      +cat = split_cat(first, String.append(h, S.directory(t)), ok_first)
      %Equal.sym(List<&2, String>, String.split(String.append(first, SCon{'/', String.append(h, S.directory(t))}), '/'), first <> String.split(String.append(h, S.directory(t)), '/'), cat) : {_ == first <> h <> pieces_dir(t) : List<&2, String>}
      %Equal.sym(List<&2, String>, String.split(String.append(h, S.directory(t)), '/'), h <> pieces_dir(t), rec) : {first <> _ == first <> h <> pieces_dir(t) : List<&2, String>}
      {==}

def directory_slashes(rest: List<&2, String>, +first: String, +ok: {S.servable(first <> rest) == True{} : Bool}) -> {P.slashes(String.append(first, S.directory(rest))) == 1n+List.length(&2, String, rest) : Nat}:
  match rest:
    case Nil{}: slashes_app(first, "/", servable_chars(first, and_left(S.servable_segment(first), S.servable([]), ok)))
    case +h <> +t:
      +ok_first = servable_chars(first, and_left(S.servable_segment(first), S.servable(h <> t), ok))
      +rec = directory_slashes(t, h, and_right(S.servable_segment(first), S.servable(h <> t), ok))
      +app = slashes_app(first, SCon{'/', String.append(h, S.directory(t))}, ok_first)
      %rec : {P.slashes(String.append(first, SCon{'/', String.append(h, S.directory(t))})) == 1n+_ : Nat}
      app

def directory_go(rest: List<&2, String>, +first: String, +index: String, +ok: {S.servable(first <> rest) == True{} : Bool}) -> {P.decode_go(pieces_dir(rest), first, index) == Some{first <> with_index(rest, index)} : Maybe<&2, List<&2, String>>}:
  match rest:
    case Nil{}:
      +head = plain_segment(first, and_left(S.servable_segment(first), S.servable([]), ok))
      %Equal.sym(Maybe<&2, String>, P.decode_segment(first), Some{first}, head) : {P.prepend(_, P.decode_go([], SNil{}, index)) == Some{[first, index]} : Maybe<&2, List<&2, String>>}
      {==}
    case +h <> +t:
      +head = plain_segment(first, and_left(S.servable_segment(first), S.servable(h <> t), ok))
      +rec = directory_go(t, h, index, and_right(S.servable_segment(first), S.servable(h <> t), ok))
      %Equal.sym(Maybe<&2, String>, P.decode_segment(first), Some{first}, head) : {P.prepend(_, P.decode_go(pieces_dir(t), h, index)) == Some{first <> h <> with_index(t, index)} : Maybe<&2, List<&2, String>>}
      %Equal.sym(Maybe<&2, List<&2, String>>, P.decode_go(pieces_dir(t), h, index), Some{h <> with_index(t, index)}, rec) : {P.prepend(Some{first}, _) == Some{first <> h <> with_index(t, index)} : Maybe<&2, List<&2, String>>}
      {==}

def with_index_ok(xs: List<&2, String>, +index: String, +ok: {S.servable(xs) == True{} : Bool}, +named: {S.servable_segment(index) == True{} : Bool}) -> {P.segments_ok(with_index(xs, index)) == True{} : Bool}:
  match xs:
    case Nil{}: and_intro(P.segment_ok(index), True{}, servable_ok(index, named), {==})
    case +h <> +t:
      and_intro(P.segment_ok(h), P.segments_ok(with_index(t, index)), servable_ok(h, and_left(S.servable_segment(h), S.servable(t), ok)), with_index_ok(t, index, and_right(S.servable_segment(h), S.servable(t), ok), named))

def with_index_length(xs: List<&2, String>, +index: String) -> {List.length(&2, String, with_index(xs, index)) == 1n+List.length(&2, String, xs) : Nat}:
  match xs:
    case Nil{}: {==}
    case +h <> +t:
      %with_index_length(t, index) : {1n+List.length(&2, String, with_index(t, index)) == 1n+_ : Nat}
      {==}

def join_index(rest: List<&2, String>, +first: String, +index: String) -> {P.join(with_index(rest, index), first) == S.joined_index(first <> rest, index) : String}:
  match rest:
    case Nil{}: {==}
    case +h <> +t:
      %join_index(t, h, index) : {String.append(first, SCon{'/', P.join(with_index(t, index), h)}) == String.append(first, SCon{'/', _}) : String}
      {==}

def directory_check(+first: String, +rest: List<&2, String>, +index: String, +ok: {S.servable(first <> rest) == True{} : Bool}, +named: {S.servable_segment(index) == True{} : Bool}) -> {P.check(S.directory(first <> rest), first, with_index(rest, index)) == True{} : Bool}:
  +segs = and_intro(P.segment_ok(first), P.segments_ok(with_index(rest, index)), servable_ok(first, and_left(S.servable_segment(first), S.servable(rest), ok)), with_index_ok(rest, index, and_right(S.servable_segment(first), S.servable(rest), ok), named))
  %Equal.sym(Nat, P.slashes(String.append(first, S.directory(rest))), 1n+List.length(&2, String, rest), directory_slashes(rest, first, ok)) : {P.segment_ok(first) && P.segments_ok(with_index(rest, index)) && Nat.is_eq(1n+List.length(&2, String, with_index(rest, index)), 1n+_) == True{} : Bool}
  %Equal.sym(Nat, List.length(&2, String, with_index(rest, index)), 1n+List.length(&2, String, rest), with_index_length(rest, index)) : {P.segment_ok(first) && P.segments_ok(with_index(rest, index)) && Nat.is_eq(1n+_, 1n+1n+List.length(&2, String, rest)) == True{} : Bool}
  and_intro(P.segment_ok(first) && P.segments_ok(with_index(rest, index)), Nat.is_eq(1n+1n+List.length(&2, String, rest), 1n+1n+List.length(&2, String, rest)), segs, nat_refl(1n+1n+List.length(&2, String, rest)))

def index_root(+index: String, +named: {S.servable_segment(index) == True{} : Bool}) -> {P.resolve("/", index) == Some{index} : Maybe<&2, String>}:
  %Equal.sym(Bool, P.segment_ok(index), True{}, servable_ok(index, named)) : {P.accept(index, [], _ && True{} && Nat.is_eq(1n, 1n)) == Some{index} : Maybe<&2, String>}
  {==}

def index_under(+first: String, +rest: List<&2, String>, +index: String, +ok: {S.servable(first <> rest) == True{} : Bool}, +named: {S.servable_segment(index) == True{} : Bool}) -> {P.resolve(S.directory(first <> rest), index) == Some{S.joined_index(first <> rest, index)} : Maybe<&2, String>}:
  +raw = S.directory(first <> rest)
  %Equal.sym(List<&2, String>, String.split(String.append(first, S.directory(rest)), '/'), first <> pieces_dir(rest), directory_split(rest, first, ok)) : {P.guard(raw, P.split_raw(SNil{} <> _, index)) == Some{S.joined_index(first <> rest, index)} : Maybe<&2, String>}
  %Equal.sym(Maybe<&2, List<&2, String>>, P.decode_go(pieces_dir(rest), first, index), Some{first <> with_index(rest, index)}, directory_go(rest, first, index, ok)) : {P.guard(raw, P.segments_of(_)) == Some{S.joined_index(first <> rest, index)} : Maybe<&2, String>}
  %Equal.sym(Bool, P.check(raw, first, with_index(rest, index)), True{}, directory_check(first, rest, index, ok, named)) : {P.accept(first, with_index(rest, index), _) == Some{S.joined_index(first <> rest, index)} : Maybe<&2, String>}
  %join_index(rest, first, index) : {Some{P.join(with_index(rest, index), first)} == Some{_} : Maybe<&2, String>}
  {==}

def index_law_model(xs: List<&2, String>, +index: String, +ok: {S.servable(xs) == True{} : Bool}, +named: {S.servable_segment(index) == True{} : Bool}) -> {P.resolve(S.directory(xs), index) == Some{S.joined_index(xs, index)} : Maybe<&2, String>}:
  match xs:
    case Nil{}: index_root(index, named)
    case +h <> +t: index_under(h, t, index, ok, named)

# The laws, over the production resolver.
def confined(+raw: String, +index: String) -> {S.confined(raw, Path.resolve(raw, index)) == True{} : Bool}:
  %PE.resolve_equiv(raw, index) : {S.confined(raw, _) == True{} : Bool}
  confined_model(raw, index)

def path_under_opened(root: String, m: Maybe<&2, String>) -> {Path.under(root, m) == S.opened(root, m) : Maybe<&2, String>}:
  match m:
    case None{}: {==}
    case Some{rel}: {==}

def target(root: String, +raw: String, +index: String) -> {Path.target(root, raw, index) == S.opened(root, Path.resolve(raw, index)) : Maybe<&2, String>}:
  %PE.resolve_equiv(raw, index) : {Path.under(root, _) == S.opened(root, _) : Maybe<&2, String>}
  path_under_opened(root, P.resolve(raw, index))

def segments(+raw: String, +index: String) -> {S.resolved_pieces(Path.resolve(raw, index)) == S.when_resolved(Path.resolve(raw, index), S.decoded(raw, index)) : Maybe<&2, List<&2, String>>}:
  %PE.resolve_equiv(raw, index) : {S.resolved_pieces(_) == S.when_resolved(_, S.decoded(raw, index)) : Maybe<&2, List<&2, String>>}
  segments_model(raw, index)

def no_dotfiles(+raw: String, +index: String) -> {S.no_dotfiles(Path.resolve(raw, index)) == True{} : Bool}:
  %PE.resolve_equiv(raw, index) : {S.no_dotfiles(_) == True{} : Bool}
  no_dotfiles_model(raw, index)

def complete(+first: String, +rest: List<&2, String>, +index: String, +ok: {S.servable(first <> rest) == True{} : Bool}) -> {Path.resolve(S.request(first <> rest), index) == Some{S.joined(rest, first)} : Maybe<&2, String>}:
  %PE.resolve_equiv(S.request(first <> rest), index) : {_ == Some{S.joined(rest, first)} : Maybe<&2, String>}
  complete_model(first, rest, index, ok)

def index_law(+xs: List<&2, String>, +index: String, +ok: {S.servable(xs) == True{} : Bool}, +named: {S.servable_segment(index) == True{} : Bool}) -> {Path.resolve(S.directory(xs), index) == Some{S.joined_index(xs, index)} : Maybe<&2, String>}:
  %PE.resolve_equiv(S.directory(xs), index) : {_ == Some{S.joined_index(xs, index)} : Maybe<&2, String>}
  index_law_model(xs, index, ok, named)
