# The stack-safe static path resolver equals the recursive model that
# carries the BND-45 proofs (BND-84). Each `_equiv` lemma is stated model
# first, so `%X_equiv(..)` rewrites a production term into the model.
import Base
import ../src/static/path.bend as Path
import ../src/http/text.bend as Text
import ./static-path-model.bend as M
import ./text.bend as TP
import ../src/router/reverse-proofs.bend as Rev

def chars_go_equiv(s: String, ok: Bool) -> {Path.chars_go(s, ok) == ok && M.chars_ok(s) : Bool}:
  match s ok:
    case SNil{} True{}: {==}
    case SNil{} False{}: {==}
    case SCon{+c, t} True{}: chars_go_equiv(t, Path.char_ok(c))
    case SCon{+c, t} False{}: chars_go_equiv(t, False{})

def chars_equiv(+s: String) -> {M.chars_ok(s) == Path.chars_ok(s) : Bool}:
  Equal.sym(Bool, Path.chars_ok(s), M.chars_ok(s), chars_go_equiv(s, True{}))

def segment_equiv(+s: String) -> {M.segment_ok(s) == Path.segment_ok(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}:
      %chars_equiv(t) : {Bool.not(U32.is_eq(Char.to_u32(c), 46)) && M.char_ok(c) && M.chars_ok(t) == Bool.not(U32.is_eq(Char.to_u32(c), 46)) && Path.char_ok(c) && _ : Bool}
      {==}

def segments_go_equiv(xs: List<&2, String>, ok: Bool) -> {Path.segments_go(xs, ok) == ok && M.segments_ok(xs) : Bool}:
  match xs ok:
    case Nil{} True{}: {==}
    case Nil{} False{}: {==}
    case +s <> t True{}:
      %segment_equiv(s) : {Path.segments_go(t, _) == M.segment_ok(s) && M.segments_ok(t) : Bool}
      segments_go_equiv(t, M.segment_ok(s))
    case s <> t False{}: segments_go_equiv(t, False{})

def segments_equiv(+xs: List<&2, String>) -> {M.segments_ok(xs) == Path.segments_ok(xs) : Bool}:
  Equal.sym(Bool, Path.segments_ok(xs), M.segments_ok(xs), segments_go_equiv(xs, True{}))

def add_succ(x: Nat, +n: Nat) -> {Nat.add(x, 1n+n) == 1n+Nat.add(x, n) : Nat}:
  match x:
    case 0n: {==}
    case 1n+p: Equal.cong(Nat, Nat, k => 1n+k, Nat.add(p, 1n+n), 1n+Nat.add(p, n), add_succ(p, n))

def add_zero(x: Nat) -> {Nat.add(x, 0n) == x : Nat}:
  match x:
    case 0n: {==}
    case 1n+p: Equal.cong(Nat, Nat, k => 1n+k, Nat.add(p, 0n), p, add_zero(p))

def slash_step(b: Bool, +x: Nat, +n: Nat) -> {Nat.add(x, Path.slash_count(b, n)) == Nat.add(M.slash_count(b, x), n) : Nat}:
  match b:
    case True{}: add_succ(x, n)
    case False{}: {==}

def slashes_go_equiv(s: String, +n: Nat) -> {Path.slashes_go(s, n) == Nat.add(M.slashes(s), n) : Nat}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}:
      Equal.trans(Nat, Path.slashes_go(t, Path.slash_count(Char.is_eq(c, '/'), n)), Nat.add(M.slashes(t), Path.slash_count(Char.is_eq(c, '/'), n)), Nat.add(M.slash_count(Char.is_eq(c, '/'), M.slashes(t)), n), slashes_go_equiv(t, Path.slash_count(Char.is_eq(c, '/'), n)), slash_step(Char.is_eq(c, '/'), M.slashes(t), n))

def slashes_equiv(+s: String) -> {M.slashes(s) == Path.slashes(s) : Nat}:
  Equal.sym(Nat, Path.slashes(s), M.slashes(s), Equal.trans(Nat, Path.slashes(s), Nat.add(M.slashes(s), 0n), M.slashes(s), slashes_go_equiv(s, 0n), add_zero(M.slashes(s))))

def count_go_equiv(xs: List<&2, String>, +n: Nat) -> {Path.count_go(xs, n) == Nat.add(List.length(&2, String, xs), n) : Nat}:
  match xs:
    case Nil{}: {==}
    case h <> +t:
      Equal.trans(Nat, Path.count_go(t, 1n+n), Nat.add(List.length(&2, String, t), 1n+n), 1n+Nat.add(List.length(&2, String, t), n), count_go_equiv(t, 1n+n), add_succ(List.length(&2, String, t), n))

def count_equiv(+xs: List<&2, String>) -> {List.length(&2, String, xs) == Path.count(xs) : Nat}:
  Equal.sym(Nat, Path.count(xs), List.length(&2, String, xs), Equal.trans(Nat, Path.count(xs), Nat.add(List.length(&2, String, xs), 0n), List.length(&2, String, xs), count_go_equiv(xs, 0n), add_zero(List.length(&2, String, xs))))

def check_equiv(+raw: String, +first: String, +rest: List<&2, String>) -> {M.check(raw, first, rest) == Path.check(raw, first, rest) : Bool}:
  %segment_equiv(first) : {M.check(raw, first, rest) == _ && Path.segments_ok(rest) && Nat.is_eq(1n+Path.count(rest), Path.slashes(raw)) : Bool}
  %segments_equiv(rest) : {M.check(raw, first, rest) == M.segment_ok(first) && _ && Nat.is_eq(1n+Path.count(rest), Path.slashes(raw)) : Bool}
  %count_equiv(rest) : {M.check(raw, first, rest) == M.segment_ok(first) && M.segments_ok(rest) && Nat.is_eq(1n+_, Path.slashes(raw)) : Bool}
  %slashes_equiv(raw) : {M.check(raw, first, rest) == M.segment_ok(first) && M.segments_ok(rest) && Nat.is_eq(1n+List.length(&2, String, rest), _) : Bool}
  {==}

def join_go_claim(rest: List<&2, String>, +first: String, +r: String) -> {Path.join_go(rest, String.reverse.go(first, r)) == String.reverse.go(M.join(rest, first), r) : String}:
  match rest:
    case Nil{}: {==}
    case +h <> +t:
      Equal.trans(String, Path.join_go(t, String.reverse.go(h, SCon{'/', String.reverse.go(first, r)})), String.reverse.go(M.join(t, h), SCon{'/', String.reverse.go(first, r)}), String.reverse.go(String.append(first, SCon{'/', M.join(t, h)}), r), join_go_claim(t, h, SCon{'/', String.reverse.go(first, r)}), Equal.sym(String, String.reverse.go(String.append(first, SCon{'/', M.join(t, h)}), r), String.reverse.go(M.join(t, h), SCon{'/', String.reverse.go(first, r)}), Rev.string_append_onto(first, SCon{'/', M.join(t, h)}, r)))

def join_equiv(+rest: List<&2, String>, +first: String) -> {M.join(rest, first) == Path.join(rest, first) : String}:
  %Equal.sym(String, Path.join_go(rest, String.reverse.go(first, "")), String.reverse.go(M.join(rest, first), ""), join_go_claim(rest, first, "")) : {M.join(rest, first) == String.reverse(_) : String}
  Equal.sym(String, String.reverse(String.reverse(M.join(rest, first))), M.join(rest, first), Rev.string_twice(M.join(rest, first)))

def accept_equiv(+first: String, +rest: List<&2, String>, ok: Bool) -> {M.accept(first, rest, ok) == Path.accept(first, rest, ok) : Maybe<&2, String>}:
  match ok:
    case True{}:
      %join_equiv(rest, first) : {Some{M.join(rest, first)} == Some{_} : Maybe<&2, String>}
      {==}
    case False{}: {==}

def guard_equiv(+raw: String, m: Maybe<&2, Path.Segments>) -> {M.guard(raw, m) == Path.guard(raw, m) : Maybe<&2, String>}:
  match m:
    case None{}: {==}
    case Some{Path.Segments{+first, +rest}}:
      %check_equiv(raw, first, rest) : {M.accept(first, rest, M.check(raw, first, rest)) == Path.accept(first, rest, _) : Maybe<&2, String>}
      accept_equiv(first, rest, M.check(raw, first, rest))

def plain_go_equiv(s: String, ok: Bool) -> {Path.plain_go(s, ok) == ok && M.plain(s) : Bool}:
  match s ok:
    case SNil{} True{}: {==}
    case SNil{} False{}: {==}
    case SCon{+c, t} True{}: plain_go_equiv(t, Path.plain_char(c))
    case SCon{+c, t} False{}: plain_go_equiv(t, False{})

def plain_equiv(+s: String) -> {M.plain(s) == Path.plain(s) : Bool}:
  Equal.sym(Bool, Path.plain(s), M.plain(s), plain_go_equiv(s, True{}))

def decoded_equiv(+s: String, b: Bool) -> {M.decoded(s, b) == Path.decoded(s, b) : Maybe<&2, String>}:
  match b:
    case True{}: {==}
    case False{}: {==}

def segment_decode_equiv(+s: String) -> {M.decode_segment(s) == Path.decode_segment(s) : Maybe<&2, String>}:
  %plain_equiv(s) : {M.decode_segment(s) == Path.decoded(s, _) : Maybe<&2, String>}
  decoded_equiv(s, M.plain(s))

def last_equiv(raw: String, +index: String) -> {M.decode_last(raw, index) == Path.decode_last(raw, index) : Maybe<&2, String>}:
  match raw:
    case SNil{}: {==}
    case SCon{+c, +t}: segment_decode_equiv(SCon{c, t})

def onto(acc: List<&2, String>, m: Maybe<&2, List<&2, String>>) -> Maybe<&2, List<&2, String>>:
  match m:
    case None{}: None{}
    case Some{ys}: Some{List.reverse.go(&2, String, acc, ys)}

def decode_failed(rest: List<&2, String>, raw: String, +index: String) -> {Path.decode_go_loop(rest, raw, index, None{}) == None{} : Maybe<&2, List<&2, String>>}:
  match rest:
    case Nil{}: {==}
    case h <> t: decode_failed(t, h, index)

def finish_equiv(+acc: List<&2, String>, x: Maybe<&2, String>) -> {Path.finish(Some{acc}, x) == onto(acc, M.single(x)) : Maybe<&2, List<&2, String>>}:
  match x:
    case None{}: {==}
    case Some{y}: {==}

def onto_piece(+y: String, +acc: List<&2, String>, xs: Maybe<&2, List<&2, String>>) -> {onto(y <> acc, xs) == onto(acc, M.prepend_to(y, xs)) : Maybe<&2, List<&2, String>>}:
  match xs:
    case None{}: {==}
    case Some{ys}: {==}

def piece_step(x: Maybe<&2, String>, +acc: List<&2, String>, +t: List<&2, String>, +h: String, +index: String,
    ih: @c: List<&2, String> -> {Path.decode_go_loop(t, h, index, Some{c}) == onto(c, M.decode_go(t, h, index)) : Maybe<&2, List<&2, String>>}) ->
    {Path.decode_go_loop(t, h, index, Path.push_piece(Some{acc}, x)) == onto(acc, M.prepend(x, M.decode_go(t, h, index))) : Maybe<&2, List<&2, String>>}:
  match x:
    case None{}: decode_failed(t, h, index)
    case Some{+y}:
      Equal.trans(Maybe<&2, List<&2, String>>, Path.decode_go_loop(t, h, index, Some{y <> acc}), onto(y <> acc, M.decode_go(t, h, index)), onto(acc, M.prepend_to(y, M.decode_go(t, h, index))), ih(y <> acc), onto_piece(y, acc, M.decode_go(t, h, index)))

def decode_go_claim(rest: List<&2, String>, +raw: String, +index: String, +acc: List<&2, String>) -> {Path.decode_go_loop(rest, raw, index, Some{acc}) == onto(acc, M.decode_go(rest, raw, index)) : Maybe<&2, List<&2, String>>}:
  match rest:
    case Nil{}:
      %last_equiv(raw, index) : {Path.finish(Some{acc}, _) == onto(acc, M.single(M.decode_last(raw, index))) : Maybe<&2, List<&2, String>>}
      finish_equiv(acc, M.decode_last(raw, index))
    case +h <> +t:
      %segment_decode_equiv(raw) : {Path.decode_go_loop(t, h, index, Path.push_piece(Some{acc}, _)) == onto(acc, M.prepend(M.decode_segment(raw), M.decode_go(t, h, index))) : Maybe<&2, List<&2, String>>}
      piece_step(M.decode_segment(raw), acc, t, h, index, c => decode_go_claim(t, h, index, c))

def onto_nil(m: Maybe<&2, List<&2, String>>) -> {onto([], m) == m : Maybe<&2, List<&2, String>>}:
  match m:
    case None{}: {==}
    case Some{ys}: {==}

def decode_go_equiv(+rest: List<&2, String>, +raw: String, +index: String) -> {M.decode_go(rest, raw, index) == Path.decode_go_loop(rest, raw, index, Some{[]}) : Maybe<&2, List<&2, String>>}:
  Equal.sym(Maybe<&2, List<&2, String>>, Path.decode_go_loop(rest, raw, index, Some{[]}), M.decode_go(rest, raw, index), Equal.trans(Maybe<&2, List<&2, String>>, Path.decode_go_loop(rest, raw, index, Some{[]}), onto([], M.decode_go(rest, raw, index)), M.decode_go(rest, raw, index), decode_go_claim(rest, raw, index, []), onto_nil(M.decode_go(rest, raw, index))))

def segments_of_equiv(xs: Maybe<&2, List<&2, String>>) -> {M.segments_of(xs) == Path.segments_of(xs) : Maybe<&2, Path.Segments>}:
  match xs:
    case None{}: {==}
    case Some{Nil{}}: {==}
    case Some{h <> t}: {==}

def split_raw_equiv(ps: List<&2, String>, +index: String) -> {M.split_raw(ps, index) == Path.split_raw(ps, index) : Maybe<&2, Path.Segments>}:
  match ps:
    case Nil{}: {==}
    case SNil{} <> Nil{}: {==}
    case SNil{} <> +h <> +t:
      %decode_go_equiv(t, h, index) : {M.segments_of(M.decode_go(t, h, index)) == Path.segments_of(_) : Maybe<&2, Path.Segments>}
      segments_of_equiv(M.decode_go(t, h, index))
    case SCon{c, s} <> t: {==}

def resolve_equiv(+raw: String, +index: String) -> {M.resolve(raw, index) == Path.resolve(raw, index) : Maybe<&2, String>}:
  %Equal.sym(List<&2, String>, Text.split(raw, '/'), String.split(raw, '/'), TP.split_equiv(raw, '/')) : {M.resolve(raw, index) == Path.guard(raw, Path.split_raw(_, index)) : Maybe<&2, String>}
  %split_raw_equiv(String.split(raw, '/'), index) : {M.resolve(raw, index) == Path.guard(raw, _) : Maybe<&2, String>}
  guard_equiv(raw, M.split_raw(String.split(raw, '/'), index))

def under_equiv(root: String, m: Maybe<&2, String>) -> {M.under(root, m) == Path.under(root, m) : Maybe<&2, String>}:
  match m:
    case None{}: {==}
    case Some{rel}: {==}

def target_equiv(root: String, +raw: String, +index: String) -> {M.target(root, raw, index) == Path.target(root, raw, index) : Maybe<&2, String>}:
  %resolve_equiv(raw, index) : {M.target(root, raw, index) == Path.under(root, _) : Maybe<&2, String>}
  under_equiv(root, M.resolve(raw, index))
