# BND-100: proofs of the total-encoder and non-scalar refusal laws.
import Base
import ../src/data/utf8.bend as U
import ../src/data/urlencoded.bend as Url
import ../src/http/response.bend as R
import ./utf8.bend as UP
import ./hot-path.bend as HP
import ./utf8-scalar-spec.bend as Spec
import ./utf8-scalar-laws.bend as Laws

# ---- Encoding a non-scalar ----

def char_replaced(+c: U32, refused: {U.scalar(c) == False{} : Bool}) -> {U.encode_char(c) == [239, 191, 189] : List<&2, U32>}:
  %UP.encode_char_equiv(c) : {_ == [239, 191, 189] : List<&2, U32>}
  %Equal.sym(Bool, U.scalar(c), False{}, refused) : {U.encode_scalar(c, _) == [239, 191, 189] : List<&2, U32>}
  {==}

def Laws.utf8_encode_char_non_scalar(c, refused):
  char_replaced(c, refused)

# ---- Every String roundtrips up to replacement ----

def step_any(+c: U32, +rev: String, ok: Bool, e: {U.scalar(c) == ok : Bool}) -> {UP.walk(U.encode_char(c), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{Spec.replace_char(c, ok)}, rev}} : U.State}:
  match ok:
    case True{}:
      UP.step_char(c, rev, e)
    case False{}:
      %Equal.sym(List<&2, U32>, U.encode_char(c), [239, 191, 189], char_replaced(c, e)) : {UP.walk(_, U.UtfReady{rev}) == U.UtfReady{SCon{Chr{65533}, rev}} : U.State}
      {==}

def total_go(+s: String, +rev: String) -> {U.decode_go(U.encode_spec(s), U.UtfReady{rev}) == Some{String.reverse.go(rev, Spec.replaced(s))} : Maybe<&2, String>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+c}, t}:
      +x = Spec.replace_char(c, U.scalar(c))
      +a = UP.decode_append(U.encode_char(c), U.encode_spec(t), U.UtfReady{rev})
      +b = Equal.cong(U.State, Maybe<&2, String>, st => U.decode_go(U.encode_spec(t), st), UP.walk(U.encode_char(c), U.UtfReady{rev}), U.UtfReady{SCon{Chr{x}, rev}}, step_any(c, rev, U.scalar(c), {==}))
      Equal.trans(Maybe<&2, String>, U.decode_go(List.append(&2, U32, U.encode_char(c), U.encode_spec(t)), U.UtfReady{rev}), U.decode_go(U.encode_spec(t), U.UtfReady{SCon{Chr{x}, rev}}), Some{String.reverse.go(rev, SCon{Chr{x}, Spec.replaced(t)})}, Equal.trans(Maybe<&2, String>, U.decode_go(List.append(&2, U32, U.encode_char(c), U.encode_spec(t)), U.UtfReady{rev}), U.decode_go(U.encode_spec(t), UP.walk(U.encode_char(c), U.UtfReady{rev})), U.decode_go(U.encode_spec(t), U.UtfReady{SCon{Chr{x}, rev}}), a, b), total_go(t, SCon{Chr{x}, rev}))

def total(+s: String) -> {U.decode(U.encode(s)) == Some{Spec.replaced(s)} : Maybe<&2, String>}:
  %Equal.sym(List<&2, U32>, U.encode(s), U.encode_spec(s), UP.encode_equiv(s)) : {U.decode(_) == Some{Spec.replaced(s)} : Maybe<&2, String>}
  total_go(s, "")

def Laws.utf8_encode_total(s):
  total(s)

# ---- Utf8.encode is the response encoder ----

def char_pick(+c: U32, ok: Bool, e: {U.scalar(c) == ok : Bool}) -> {U.encode_char(c) == U.encode_char(R.scalar_valid(c, ok)) : List<&2, U32>}:
  match ok:
    case True{}:
      {==}
    case False{}:
      %Equal.sym(List<&2, U32>, U.encode_char(c), [239, 191, 189], char_replaced(c, e)) : {_ == U.encode_char(R.scalar_valid(c, False{})) : List<&2, U32>}
      {==}

def char_response(+c: U32) -> {U.encode_char(c) == U.encode_char(R.scalar(c)) : List<&2, U32>}:
  char_pick(c, U.scalar(c), {==})

def spec_fused(+s: String) -> {U.encode_spec(s) == HP.fused(s) : List<&2, U32>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+c}, t}:
      Equal.trans(List<&2, U32>, List.append(&2, U32, U.encode_char(c), U.encode_spec(t)), List.append(&2, U32, U.encode_char(c), HP.fused(t)), List.append(&2, U32, U.encode_char(R.scalar(c)), HP.fused(t)), Equal.cong(List<&2, U32>, List<&2, U32>, x => List.append(&2, U32, U.encode_char(c), x), U.encode_spec(t), HP.fused(t), spec_fused(t)), Equal.cong(List<&2, U32>, List<&2, U32>, x => List.append(&2, U32, x, HP.fused(t)), U.encode_char(c), U.encode_char(R.scalar(c)), char_response(c)))

def response(+s: String) -> {U.encode(s) == R.utf8(s) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, U.encode(s), U.encode_spec(s), R.utf8(s), UP.encode_equiv(s), Equal.trans(List<&2, U32>, U.encode_spec(s), HP.fused(s), R.utf8(s), spec_fused(s), Equal.sym(List<&2, U32>, R.utf8(s), HP.fused(s), HP.go_equiv(s, []))))

def Laws.utf8_encode_response(s):
  response(s)

# ---- Decoders refuse non-scalar text ----

def refuse_done(+r: Result<&2, &2, Url.Error, List<&2, U32>>) -> &error:Url.Error -> {Url.checked_result(r, False{}) == Fail{error} : Result<&2, &2, Url.Error, String>}:
  match r:
    case Fail{+e}:
      (e, {==})
    case Done{xs}:
      (Url.InvalidUtf8{}, {==})

def refuse(+r: Result<&2, &2, Url.Error, List<&2, U32>>, +v: Bool, refused: {v == False{} : Bool}) -> &error:Url.Error -> {Url.checked_result(r, v) == Fail{error} : Result<&2, &2, Url.Error, String>}:
  %Equal.sym(Bool, v, False{}, refused) : &error:Url.Error -> {Url.checked_result(r, _) == Fail{error} : Result<&2, &2, Url.Error, String>}
  refuse_done(r)

def Laws.url_decode_non_scalar(wire, refused):
  refuse(Url.percent_decode(U.encode(wire), False{}), U.valid(wire), refused)

def Laws.url_decode_form_non_scalar(wire, refused):
  refuse(Url.percent_decode(U.encode(wire), True{}), U.valid(wire), refused)

def refuse_pairs_done(+r: Result<&2, &2, Url.Error, List<&2, Url.Entry>>) -> &error:Url.Error -> {Url.scalar_pairs(r, False{}) == Fail{error} : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}:
  match r:
    case Fail{+e}:
      (e, {==})
    case Done{ps}:
      (Url.InvalidUtf8{}, {==})

def refuse_pairs(+r: Result<&2, &2, Url.Error, List<&2, Url.Entry>>, +v: Bool, refused: {v == False{} : Bool}) -> &error:Url.Error -> {Url.scalar_pairs(r, v) == Fail{error} : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}:
  %Equal.sym(Bool, v, False{}, refused) : &error:Url.Error -> {Url.scalar_pairs(r, _) == Fail{error} : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}
  refuse_pairs_done(r)

def Laws.url_parse_pairs_non_scalar(text, refused):
  refuse_pairs(Url.parse_pairs_bytes(U.encode(text)), U.valid(text), refused)
