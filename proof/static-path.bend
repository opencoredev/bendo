# BND-45: static path confinement. Every lemma is over variables; the final
# check in Path.guard carries the whole argument, so no lemma looks at
# percent decoding.
import Base
import ../src/static/path.bend as P
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

def guard_ok(+raw: String, m: Maybe<&2, P.Segments>) -> {S.confined(raw, P.guard(raw, m)) == True{} : Bool}:
  match m:
    case None{}: {==}
    case Some{P.Segments{+first, +rest}}:
      accept_ok(raw, first, rest, P.check(raw, first, rest), {==})

def confined(+raw: String, +index: String) -> {S.confined(raw, P.resolve(raw, index)) == True{} : Bool}:
  guard_ok(raw, P.segments(raw, index))

def under_opened(root: String, m: Maybe<&2, String>) -> {P.under(root, m) == S.opened(root, m) : Maybe<&2, String>}:
  match m:
    case None{}: {==}
    case Some{rel}: {==}

def target(root: String, +raw: String, +index: String) -> {P.target(root, raw, index) == S.opened(root, P.resolve(raw, index)) : Maybe<&2, String>}:
  under_opened(root, P.resolve(raw, index))
