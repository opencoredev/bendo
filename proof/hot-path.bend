# BND-68: proofs that the hot-path rewrites equal their retained specs.
import Base
import ./hot-path-laws.bend as Laws
import ../src/data/utf8.bend as Utf8
import ./utf8.bend as UP
import ../src/http/bytes.bend as B
import ../src/http/response.bend as R
import ../src/app/context.bend as C
import ../src/data/utf8.bend as U

def Laws.hot_utf8_encode_char(c):
  Equal.sym(List<&2, U32>, Utf8.encode_char_spec(c), Utf8.encode_char(c), UP.encode_char_equiv(c))

# ---- BND-68: the branching token classifier equals the string search ----

def punct_step_14(+c: U32, hit: Bool) -> {B.tchar_punct_14(c, hit) == String.contains.if("", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      {==}

def punct_step_13(+c: U32, hit: Bool) -> {B.tchar_punct_13(c, hit) == String.contains.if("~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_14(c, U32.is_eq(126, c))

def punct_step_12(+c: U32, hit: Bool) -> {B.tchar_punct_12(c, hit) == String.contains.if("|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_13(c, U32.is_eq(124, c))

def punct_step_11(+c: U32, hit: Bool) -> {B.tchar_punct_11(c, hit) == String.contains.if("`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_12(c, U32.is_eq(96, c))

def punct_step_10(+c: U32, hit: Bool) -> {B.tchar_punct_10(c, hit) == String.contains.if("_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_11(c, U32.is_eq(95, c))

def punct_step_9(+c: U32, hit: Bool) -> {B.tchar_punct_9(c, hit) == String.contains.if("^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_10(c, U32.is_eq(94, c))

def punct_step_8(+c: U32, hit: Bool) -> {B.tchar_punct_8(c, hit) == String.contains.if(".^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, ".^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_9(c, U32.is_eq(46, c))

def punct_step_7(+c: U32, hit: Bool) -> {B.tchar_punct_7(c, hit) == String.contains.if("-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_8(c, U32.is_eq(45, c))

def punct_step_6(+c: U32, hit: Bool) -> {B.tchar_punct_6(c, hit) == String.contains.if("+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_7(c, U32.is_eq(43, c))

def punct_step_5(+c: U32, hit: Bool) -> {B.tchar_punct_5(c, hit) == String.contains.if("*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_6(c, U32.is_eq(42, c))

def punct_step_4(+c: U32, hit: Bool) -> {B.tchar_punct_4(c, hit) == String.contains.if("'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_5(c, U32.is_eq(39, c))

def punct_step_3(+c: U32, hit: Bool) -> {B.tchar_punct_3(c, hit) == String.contains.if("&'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "&'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_4(c, U32.is_eq(38, c))

def punct_step_2(+c: U32, hit: Bool) -> {B.tchar_punct_2(c, hit) == String.contains.if("%&'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "%&'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_3(c, U32.is_eq(37, c))

def punct_step_1(+c: U32, hit: Bool) -> {B.tchar_punct_1(c, hit) == String.contains.if("$%&'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "$%&'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_2(c, U32.is_eq(36, c))

def punct_step_0(+c: U32, hit: Bool) -> {B.tchar_punct_0(c, hit) == String.contains.if("#$%&'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "#$%&'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_1(c, U32.is_eq(35, c))

def tchar_pick_spec(+c: U32, alnum: Bool) -> {B.tchar_pick(c, alnum) == alnum || String.contains("!#$%&'*+-.^_`|~", Char.show(Chr{c})) : Bool}:
  match alnum:
    case True{}:
      {==}
    case False{}:
      punct_step_0(c, U32.is_eq(33, c))

def tchar_equiv(+c: U32) -> {B.tchar(c) == B.tchar_spec(c) : Bool}:
  tchar_pick_spec(c, ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)))

def Laws.hot_bytes_tchar(c): tchar_equiv(c)

# ---- BND-68: the fused response encoder equals scalars then encode ----

def map_scalars(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{c}, t}:
      SCon{Chr{R.scalar(c)}, map_scalars(t)}

def fused(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      []
    case SCon{Chr{c}, t}:
      List.append(&2, U32, Utf8.encode_char(R.scalar(c)), fused(t))

def rev_onto(+xs: List<&2, U32>, +acc: List<&2, U32>, +f: List<&2, U32>) -> {List.reverse.go(&2, U32, List.reverse.go(&2, U32, xs, acc), f) == List.reverse.go(&2, U32, acc, List.append(&2, U32, xs, f)) : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      rev_onto(t, h <> acc, f)

def octets_ascii(+a: Word(7n), +acc: List<&2, U32>) -> {R.utf8_octets(U32{U.join(7n, 25n, a, Word.zero(25n))}, acc, True{}) == List.reverse.go(&2, U32, Utf8.encode_char(R.scalar(U32{U.join(7n, 25n, a, Word.zero(25n))})), acc) : List<&2, U32>}:
  match a:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}:
      {==}

def octets_pick(+w: Word(32n), +acc: List<&2, U32>, z: Bool, e: {U.zero(25n, U.high(7n, 25n, w)) == z : Bool}) -> {R.utf8_octets(U32{w}, acc, z) == List.reverse.go(&2, U32, Utf8.encode_char(R.scalar(U32{w})), acc) : List<&2, U32>}:
  match z:
    case False{}:
      {==}
    case True{}:
      %UP.pad_reconstruct(7n, 25n, w, UP.zero_sound(25n, U.high(7n, 25n, w), e)) : {R.utf8_octets(U32{_}, acc, True{}) == List.reverse.go(&2, U32, Utf8.encode_char(R.scalar(U32{_})), acc) : List<&2, U32>}
      octets_ascii(U.low(7n, 25n, w), acc)

def octets_equiv(+c: U32, +acc: List<&2, U32>) -> {R.utf8_octets(c, acc, (c < 128 : U32)) == List.reverse.go(&2, U32, Utf8.encode_char(R.scalar(c)), acc) : List<&2, U32>}:
  match c:
    case U32{+w}:
      Equal.trans(List<&2, U32>, R.utf8_octets(U32{w}, acc, (U32{w} < 128 : U32)), R.utf8_octets(U32{w}, acc, U.zero(25n, U.high(7n, 25n, w))), List.reverse.go(&2, U32, Utf8.encode_char(R.scalar(U32{w})), acc), Equal.cong(Bool, List<&2, U32>, z => R.utf8_octets(U32{w}, acc, z), (U32{w} < 128 : U32), U.zero(25n, U.high(7n, 25n, w)), UP.ascii_lt(w)), octets_pick(w, acc, U.zero(25n, U.high(7n, 25n, w)), {==}))

def go_equiv(+s: String, +acc: List<&2, U32>) -> {R.utf8_go(s, acc) == List.reverse.go(&2, U32, acc, fused(s)) : List<&2, U32>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+c}, t}:
      +ec = Utf8.encode_char(R.scalar(c))
      Equal.trans(List<&2, U32>, R.utf8_go(t, R.utf8_octets(c, acc, (c < 128 : U32))), R.utf8_go(t, List.reverse.go(&2, U32, ec, acc)), List.reverse.go(&2, U32, acc, List.append(&2, U32, ec, fused(t))), Equal.cong(List<&2, U32>, List<&2, U32>, x => R.utf8_go(t, x), R.utf8_octets(c, acc, (c < 128 : U32)), List.reverse.go(&2, U32, ec, acc), octets_equiv(c, acc)), Equal.trans(List<&2, U32>, R.utf8_go(t, List.reverse.go(&2, U32, ec, acc)), List.reverse.go(&2, U32, List.reverse.go(&2, U32, ec, acc), fused(t)), List.reverse.go(&2, U32, acc, List.append(&2, U32, ec, fused(t))), go_equiv(t, List.reverse.go(&2, U32, ec, acc)), rev_onto(ec, acc, fused(t))))

def fused_spec(+s: String) -> {fused(s) == Utf8.encode_spec(map_scalars(s)) : List<&2, U32>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+c}, t}:
      Equal.cong(List<&2, U32>, List<&2, U32>, x => List.append(&2, U32, Utf8.encode_char(R.scalar(c)), x), fused(t), Utf8.encode_spec(map_scalars(t)), fused_spec(t))

def scalars_go_map(+s: String, +acc: String) -> {R.scalars_go(s, acc) == String.reverse.go(acc, map_scalars(s)) : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+c}, t}:
      scalars_go_map(t, SCon{Chr{R.scalar(c)}, acc})

def utf8_equiv(+s: String) -> {R.utf8(s) == R.utf8_spec(s) : List<&2, U32>}:
  e1 = go_equiv(s, [])
  e2 = fused_spec(s)
  e3 = Equal.sym(List<&2, U32>, Utf8.encode(map_scalars(s)), Utf8.encode_spec(map_scalars(s)), UP.encode_equiv(map_scalars(s)))
  e4 = Equal.cong(String, List<&2, U32>, x => Utf8.encode(x), map_scalars(s), R.scalars(s), Equal.sym(String, R.scalars(s), map_scalars(s), scalars_go_map(s, "")))
  Equal.trans(List<&2, U32>, R.utf8(s), fused(s), R.utf8_spec(s), e1, Equal.trans(List<&2, U32>, fused(s), Utf8.encode_spec(map_scalars(s)), R.utf8_spec(s), e2, Equal.trans(List<&2, U32>, Utf8.encode_spec(map_scalars(s)), Utf8.encode(map_scalars(s)), R.utf8_spec(s), e3, e4)))

# Spec first, so `%` rewrites the fused encoder into scalars then encode.
def utf8_spec_equiv(+s: String) -> {R.utf8_spec(s) == R.utf8(s) : List<&2, U32>}:
  Equal.sym(List<&2, U32>, R.utf8(s), R.utf8_spec(s), utf8_equiv(s))

def Laws.hot_response_utf8(s): utf8_equiv(s)

# ---- BND-68: fixed Content-Type bytes equal encoding the literal ----

def Laws.hot_context_text(Vars, c, value):
  match c:
    case C.Ctx{r, p, b, q, s, hs, v, o}:
      {==}

def Laws.hot_context_html(Vars, c, value):
  match c:
    case C.Ctx{r, p, b, q, s, hs, v, o}:
      {==}

def Laws.hot_context_json_result(Vars, c, result):
  match c result:
    case _ Fail{e}:
      {==}
    case C.Ctx{r, p, b, q, s, hs, v, o} Done{x}:
      {==}

# ---- BND-68: CORS derives its policy once per request ----

def Laws.hot_cors_actual(config, g, requested, res): {==}

def Laws.hot_cors_policy(config, req): {==}

def Laws.hot_secure_prepared(Vars, config, c, next): {==}
