# BND-87: proofs of the signed-cookie decoder laws.
import Base
import ../src/data/signed-cookie.bend as S
import ../src/data/base64.bend as B
import ../src/data/urlencoded.bend as Url
import ../src/data/utf8.bend as Utf8
import ../src/data/cookie.bend as Cookie
import ../src/crypto/octets.bend as Octets
import ../src/crypto/hmac.bend as Hmac
import ./signed-cookie-spec.bend as Spec
import ./url-decode-spec.bend as DSpec
import ./signed-cookie-decoder-laws.bend as Laws
import ./base64-sound.bend as B64
import ./url-percent.bend as Percent
import ./utf8-sound.bend as Utf8Sound
import ./utf8.bend as UP
import ./json-credit.bend as Credit
import ./crypto-base64.bend as Base64Proof
import ./signed-cookie.bend as SCP
import ./signed-cookie-wire.bend as Wire
import ./signed-cookie-format.bend as Format

# ---- Small logic ----

def done_tag(r: Result<&2, &2, Url.Error, String>) -> Type:
  match r:
    case Fail{e}: Unit
    case Done{v}: Empty

def fail_done(+e: Url.Error, +v: String, h: {Fail{e} == Done{v} : Result<&2, &2, Url.Error, String>}) -> Empty:
  %h : done_tag(_)
  Unit{}

def fail_tag(r: Result<&2, &2, Url.Error, String>) -> Type:
  match r:
    case Fail{e}: Empty
    case Done{v}: Unit

def done_fail(+v: String, +e: Url.Error, h: {Done{v} == Fail{e} : Result<&2, &2, Url.Error, String>}) -> Empty:
  %h : fail_tag(_)
  Unit{}

def done_get(r: Result<&2, &2, Url.Error, String>, d: String) -> String:
  match r:
    case Fail{e}: d
    case Done{v}: v

def done_inj(+a: String, +b: String, h: {Done{a} == Done{b} : Result<&2, &2, Url.Error, String>}) -> {a == b : String}:
  Equal.cong(Result<&2, &2, Url.Error, String>, String, r => done_get(r, a), Done{a}, Done{b}, h)

def fail_get(r: Result<&2, &2, Url.Error, String>, d: Url.Error) -> Url.Error:
  match r:
    case Fail{e}: e
    case Done{v}: d

def fail_inj(+a: Url.Error, +b: Url.Error, h: {Fail{a} == Fail{b} : Result<&2, &2, Url.Error, String>}) -> {a == b : Url.Error}:
  Equal.cong(Result<&2, &2, Url.Error, String>, Url.Error, r => fail_get(r, a), Fail{a}, Fail{b}, h)

def none_value(-A: Type, +value: String, h: {None{} == Some{value} : Maybe<&2, String>}) -> A:
  UP.absurd(A, Utf8Sound.none_some(value, h))

def and_left(+a: Bool, +b: Bool, e: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  Utf8Sound.and_left(a, b, e)

def and_right(+a: Bool, +b: Bool, e: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  Utf8Sound.and_right(a, b, e)

def char_is(+c: Char, +k: U32, e: {Char.is_eq(c, Chr{k}) == True{} : Bool}) -> {c == Chr{k} : Char}:
  match c:
    case Chr{+x}:
      Equal.cong(U32, Char, y => Chr{y}, x, k, Credit.u32_eq_sound(x, k, e))

# ---- Base64 ----

def Laws.signed_cookie_base64_canonical(s, bytes, decoded):
  B64.canonical(s, bytes, decoded)

# ---- Percent decoding and URL decoding ----

def Laws.signed_cookie_percent_spec(xs):
  Percent.percent(xs)

def Laws.signed_cookie_utf8_sound(xs, s, decoded):
  Utf8Sound.decoded(xs, s, decoded)

def lift(+xs: List<&2, U32>, +value: String, p: {Utf8.valid(value) == True{} : Bool} & {Utf8.encode(value) == xs : List<&2, U32>}) -> {Utf8.valid(value) == True{} : Bool} & {Done{xs} == Done{Utf8.encode(value)} : Result<&2, &2, Url.Error, List<&2, U32>>}:
  match p:
    case (ok, +e):
      (ok, Equal.cong(List<&2, U32>, Result<&2, &2, Url.Error, List<&2, U32>>, x => Done{x}, xs, Utf8.encode(value), Equal.sym(List<&2, U32>, Utf8.encode(value), xs, e)))

def sound_m(+xs: List<&2, U32>, +value: String, +m: Maybe<&2, String>, em: {Utf8.decode(xs) == m : Maybe<&2, String>}, h: {Url.utf8_result(m) == Done{value} : Result<&2, &2, Url.Error, String>}) -> {Utf8.valid(value) == True{} : Bool} & {Done{xs} == Done{Utf8.encode(value)} : Result<&2, &2, Url.Error, List<&2, U32>>}:
  match m:
    case None{}:
      UP.absurd({Utf8.valid(value) == True{} : Bool} & {Done{xs} == Done{Utf8.encode(value)} : Result<&2, &2, Url.Error, List<&2, U32>>}, fail_done(Url.InvalidUtf8{}, value, h))
    case Some{+v}:
      %done_inj(v, value, h) : {Utf8.valid(_) == True{} : Bool} & {Done{xs} == Done{Utf8.encode(_)} : Result<&2, &2, Url.Error, List<&2, U32>>}
      lift(xs, v, Utf8Sound.decoded(xs, v, em))

def sound_r(+value: String, +r: Result<&2, &2, Url.Error, List<&2, U32>>, h: {Url.decode_result(r) == Done{value} : Result<&2, &2, Url.Error, String>}) -> {Utf8.valid(value) == True{} : Bool} & {r == Done{Utf8.encode(value)} : Result<&2, &2, Url.Error, List<&2, U32>>}:
  match r:
    case Fail{+e}:
      UP.absurd({Utf8.valid(value) == True{} : Bool} & {Fail{e} == Done{Utf8.encode(value)} : Result<&2, &2, Url.Error, List<&2, U32>>}, fail_done(e, value, h))
    case Done{+xs}:
      sound_m(xs, value, Utf8.decode(xs), {==}, h)

def url_sound(+wire: String, +value: String, h: {Url.decode(wire) == Done{value} : Result<&2, &2, Url.Error, String>}) -> {Utf8.valid(value) == True{} : Bool} & {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(value)} : Result<&2, &2, Url.Error, List<&2, U32>>}:
  %Percent.percent(Utf8.encode(wire)) : {Utf8.valid(value) == True{} : Bool} & {_ == Done{Utf8.encode(value)} : Result<&2, &2, Url.Error, List<&2, U32>>}
  sound_r(value, Url.percent_decode(Utf8.encode(wire), False{}), h)

def Laws.signed_cookie_url_decode_sound(wire, value, decoded):
  url_sound(wire, value, decoded)

# Url.decode is the result stage applied to the independent percent decoding.
def staged(+wire: String) -> {Url.decode(wire) == Url.decode_result(DSpec.unpercent(Utf8.encode(wire))) : Result<&2, &2, Url.Error, String>}:
  Equal.cong(Result<&2, &2, Url.Error, List<&2, U32>>, Result<&2, &2, Url.Error, String>, r => Url.decode_result(r), Url.percent_decode(Utf8.encode(wire), False{}), DSpec.unpercent(Utf8.encode(wire)), Percent.percent(Utf8.encode(wire)))

def url_complete(+wire: String, +value: String, valid: {Utf8.valid(value) == True{} : Bool}, escaped: {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(value)} : Result<&2, &2, Url.Error, List<&2, U32>>}) -> {Url.decode(wire) == Done{value} : Result<&2, &2, Url.Error, String>}:
  +step = Equal.cong(Result<&2, &2, Url.Error, List<&2, U32>>, Result<&2, &2, Url.Error, String>, r => Url.decode_result(r), DSpec.unpercent(Utf8.encode(wire)), Done{Utf8.encode(value)}, escaped)
  +back = Equal.cong(Maybe<&2, String>, Result<&2, &2, Url.Error, String>, m => Url.utf8_result(m), Utf8.decode(Utf8.encode(value)), Some{value}, UP.roundtrip(value, valid))
  Equal.trans(Result<&2, &2, Url.Error, String>, Url.decode(wire), Url.decode_result(DSpec.unpercent(Utf8.encode(wire))), Done{value}, staged(wire), Equal.trans(Result<&2, &2, Url.Error, String>, Url.decode_result(DSpec.unpercent(Utf8.encode(wire))), Url.decode_result(Done{Utf8.encode(value)}), Done{value}, step, back))

def Laws.signed_cookie_url_decode_complete(wire, value, valid, escaped):
  url_complete(wire, value, valid, escaped)

def Laws.signed_cookie_url_decode_percent_error(wire, error, rejected):
  Equal.trans(Result<&2, &2, Url.Error, String>, Url.decode(wire), Url.decode_result(DSpec.unpercent(Utf8.encode(wire))), Fail{error}, staged(wire), Equal.cong(Result<&2, &2, Url.Error, List<&2, U32>>, Result<&2, &2, Url.Error, String>, r => Url.decode_result(r), DSpec.unpercent(Utf8.encode(wire)), Fail{error}, rejected))

def utf8_error_m(+error: Url.Error, +m: Maybe<&2, String>, h: {Url.utf8_result(m) == Fail{error} : Result<&2, &2, Url.Error, String>}) -> {error == Url.InvalidUtf8{} : Url.Error}:
  match m:
    case None{}:
      Equal.sym(Url.Error, Url.InvalidUtf8{}, error, fail_inj(Url.InvalidUtf8{}, error, h))
    case Some{+v}:
      UP.absurd({error == Url.InvalidUtf8{} : Url.Error}, done_fail(v, error, h))

def Laws.signed_cookie_url_decode_utf8_error(wire, octets, error, escaped, failed):
  +chain = Equal.trans(Result<&2, &2, Url.Error, String>, Url.decode(wire), Url.decode_result(DSpec.unpercent(Utf8.encode(wire))), Url.decode_result(Done{octets}), staged(wire), Equal.cong(Result<&2, &2, Url.Error, List<&2, U32>>, Result<&2, &2, Url.Error, String>, r => Url.decode_result(r), DSpec.unpercent(Utf8.encode(wire)), Done{octets}, escaped))
  utf8_error_m(error, Utf8.decode(octets), Equal.trans(Result<&2, &2, Url.Error, String>, Url.decode_result(Done{octets}), Url.decode(wire), Fail{error}, Equal.sym(Result<&2, &2, Url.Error, String>, Url.decode(wire), Url.decode_result(Done{octets}), chain), failed))

# ---- Structural facts behind the verification spec ----

def bit_sound(+x: Bool, +y: Bool, e: {Spec.bit_equal(x, y) == True{} : Bool}) -> {x == y : Bool}:
  match x y:
    case False{} False{}: {==}
    case False{} True{}: UP.absurd({False{} == True{} : Bool}, UP.false_true(e))
    case True{} False{}: UP.absurd({True{} == False{} : Bool}, UP.false_true(e))
    case True{} True{}: {==}

def word_sound(+n: Nat, +a: Word(n), +b: Word(n), +e: {Spec.word_equal(n, a, b) == True{} : Bool}) -> {a == b : Word(n)}:
  match n a b:
    case 0n WNil{} WNil{}: {==}
    case 1n+p WCon{+x, +at} WCon{+y, +bt}:
      +eh = bit_sound(x, y, and_left(Spec.bit_equal(x, y), Spec.word_equal(p, at, bt), e))
      +et = word_sound(p, at, bt, and_right(Spec.bit_equal(x, y), Spec.word_equal(p, at, bt), e))
      %eh : {WCon{x, at} == WCon{_, bt} : Word(1n+p)}
      %et : {WCon{x, at} == WCon{x, _} : Word(1n+p)}
      {==}

def bytes_sound(+xs: List<&2, U32>, +ys: List<&2, U32>, +e: {Spec.bytes_equal(xs, ys) == True{} : Bool}) -> {xs == ys : List<&2, U32>}:
  match xs ys:
    case Nil{} Nil{}: {==}
    case Nil{} +y <> +yt: UP.absurd({[] == y <> yt : List<&2, U32>}, UP.false_true(e))
    case +x <> +xt Nil{}: UP.absurd({x <> xt == [] : List<&2, U32>}, UP.false_true(e))
    case U32{+a} <> +at U32{+b} <> +bt:
      +eh = Equal.cong(Word(32n), U32, w => U32{w}, a, b, word_sound(32n, a, b, and_left(Spec.word_equal(32n, a, b), Spec.bytes_equal(at, bt), e)))
      +et = bytes_sound(at, bt, and_right(Spec.word_equal(32n, a, b), Spec.bytes_equal(at, bt), e))
      %eh : {U32{a} <> at == _ <> bt : List<&2, U32>}
      %et : {U32{a} <> at == U32{a} <> _ : List<&2, U32>}
      {==}

# Some listed key whose HMAC over v is exactly the given bytes.
def Signer(keys: List<&2, String>, v: String, bytes: List<&2, U32>) -> Type:
  &k:String -> (Spec.contains(k, keys) & {Hmac.sha256(Utf8.encode(k), Utf8.encode(v)) == bytes : List<&2, U32>})

def widen(+key: String, +rest: List<&2, String>, +v: String, +bytes: List<&2, U32>, s: Signer(rest, v, bytes)) -> Signer(key <> rest, v, bytes):
  match s:
    case (+k, (c, e)): (k, (Inr{c}, e))

def auth_step(+key: String, +rest: List<&2, String>, +v: String, +bytes: List<&2, U32>, x: Bool, ex: {Spec.bytes_equal(Hmac.sha256(Utf8.encode(key), Utf8.encode(v)), bytes) == x : Bool}, h: {x || Spec.authentic(rest, v, bytes) == True{} : Bool}, ih: {Spec.authentic(rest, v, bytes) == True{} : Bool} -> Signer(rest, v, bytes)) -> Signer(key <> rest, v, bytes):
  match x:
    case True{}:
      (key, (Inl{{==}}, bytes_sound(Hmac.sha256(Utf8.encode(key), Utf8.encode(v)), bytes, ex)))
    case False{}:
      widen(key, rest, v, bytes, ih(h))

def authentic_sound(+keys: List<&2, String>, +v: String, +bytes: List<&2, U32>, h: {Spec.authentic(keys, v, bytes) == True{} : Bool}) -> Signer(keys, v, bytes):
  match keys:
    case Nil{}:
      UP.absurd(Signer([], v, bytes), UP.false_true(h))
    case +key <> +rest:
      auth_step(key, rest, v, bytes, Spec.bytes_equal(Hmac.sha256(Utf8.encode(key), Utf8.encode(v)), bytes), {==}, h, e => authentic_sound(rest, v, bytes, e))

# The independent last-dot split recovers its input.
def LD(s: String, m: Maybe<&2, Spec.Parts>) -> Type:
  match m:
    case None{}: Unit
    case Some{Spec.Parts{a, b}}: {s == a ++ SCon{'.', b} : String}

def ld_at(+c: Char, +t: String, +m: Maybe<&2, Spec.Parts>, +d: Bool, ed: {Char.is_eq(c, '.') == d : Bool}, ih: LD(t, m)) -> LD(SCon{c, t}, Spec.last_dot_at(c, t, m, d)):
  match m d:
    case Some{Spec.Parts{+a, +b}} d:
      Equal.cong(String, String, x => SCon{c, x}, t, a ++ SCon{'.', b}, ih)
    case None{} True{}:
      Equal.cong(Char, String, x => SCon{x, t}, c, '.', char_is(c, 46, ed))
    case None{} False{}:
      Unit{}

def last_dot_sound(+s: String) -> LD(s, Spec.last_dot(s)):
  match s:
    case SNil{}: Unit{}
    case SCon{+c, +t}: ld_at(c, t, Spec.last_dot(t), Char.is_eq(c, '.'), {==}, last_dot_sound(t))

def prefix_spec(+a: String, +b: String, +h: {Utf8.valid_spec(a ++ b) == True{} : Bool}) -> {Utf8.valid_spec(a) == True{} : Bool}:
  match a:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      Utf8Sound.both(Utf8.scalar(c), Utf8.valid_spec(t), and_left(Utf8.scalar(c), Utf8.valid_spec(t ++ b), h), prefix_spec(t, b, and_right(Utf8.scalar(c), Utf8.valid_spec(t ++ b), h)))

def prefix_valid(+a: String, +b: String, h: {Utf8.valid(a ++ b) == True{} : Bool}) -> {Utf8.valid(a) == True{} : Bool}:
  Equal.trans(Bool, Utf8.valid(a), Utf8.valid_spec(a), True{}, UP.valid_equiv(a), prefix_spec(a, b, Equal.trans(Bool, Utf8.valid_spec(a ++ b), Utf8.valid(a ++ b), True{}, Equal.sym(Bool, Utf8.valid(a ++ b), Utf8.valid_spec(a ++ b), UP.valid_equiv(a ++ b)), h)))

# ---- Verification soundness ----

def Signed(first: String, rest: List<&2, String>, wire: String, value: String) -> Type:
  &key:String -> (Spec.contains(key, first <> rest) & ({Spec.secrets(first <> rest) == True{} : Bool} & ({Utf8.valid(value) == True{} : Bool} & {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(value ++ "." ++ Spec.base64(Hmac.sha256(Utf8.encode(key), Utf8.encode(value))))} : Result<&2, &2, Url.Error, List<&2, U32>>})))

def assemble(+first: String, +rest: List<&2, String>, +wire: String, +value: String, +p: String, +v: String, +sg: String, +bytes: List<&2, U32>, +sec: {Spec.secrets(first <> rest) == True{} : Bool}, +ok: {Utf8.valid(p) == True{} : Bool}, +escaped: {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(p)} : Result<&2, &2, Url.Error, List<&2, U32>>}, +split: {p == v ++ SCon{'.', sg} : String}, +canon: {sg == Spec.base64(bytes) : String}, +same: {v == value : String}, signer: Signer(first <> rest, v, bytes)) -> Signed(first, rest, wire, value):
  match signer:
    case (+key, (member, +hk)):
      +e1 = Equal.cong(String, Result<&2, &2, Url.Error, List<&2, U32>>, x => Done{Utf8.encode(x)}, p, v ++ SCon{'.', sg}, split)
      +e2 = Equal.cong(String, Result<&2, &2, Url.Error, List<&2, U32>>, x => Done{Utf8.encode(v ++ SCon{'.', x})}, sg, Spec.base64(bytes), canon)
      +e3 = Equal.cong(List<&2, U32>, Result<&2, &2, Url.Error, List<&2, U32>>, x => Done{Utf8.encode(v ++ SCon{'.', Spec.base64(x)})}, bytes, Hmac.sha256(Utf8.encode(key), Utf8.encode(v)), Equal.sym(List<&2, U32>, Hmac.sha256(Utf8.encode(key), Utf8.encode(v)), bytes, hk))
      +e4 = Equal.cong(String, Result<&2, &2, Url.Error, List<&2, U32>>, y => Done{Utf8.encode(y ++ SCon{'.', Spec.base64(Hmac.sha256(Utf8.encode(key), Utf8.encode(y)))})}, v, value, same)
      +wire_eq = Equal.trans(Result<&2, &2, Url.Error, List<&2, U32>>, DSpec.unpercent(Utf8.encode(wire)), Done{Utf8.encode(p)}, Done{Utf8.encode(value ++ SCon{'.', Spec.base64(Hmac.sha256(Utf8.encode(key), Utf8.encode(value)))})}, escaped, Equal.trans(Result<&2, &2, Url.Error, List<&2, U32>>, Done{Utf8.encode(p)}, Done{Utf8.encode(v ++ SCon{'.', sg})}, Done{Utf8.encode(value ++ SCon{'.', Spec.base64(Hmac.sha256(Utf8.encode(key), Utf8.encode(value)))})}, e1, Equal.trans(Result<&2, &2, Url.Error, List<&2, U32>>, Done{Utf8.encode(v ++ SCon{'.', sg})}, Done{Utf8.encode(v ++ SCon{'.', Spec.base64(bytes)})}, Done{Utf8.encode(value ++ SCon{'.', Spec.base64(Hmac.sha256(Utf8.encode(key), Utf8.encode(value)))})}, e2, Equal.trans(Result<&2, &2, Url.Error, List<&2, U32>>, Done{Utf8.encode(v ++ SCon{'.', Spec.base64(bytes)})}, Done{Utf8.encode(v ++ SCon{'.', Spec.base64(Hmac.sha256(Utf8.encode(key), Utf8.encode(v)))})}, Done{Utf8.encode(value ++ SCon{'.', Spec.base64(Hmac.sha256(Utf8.encode(key), Utf8.encode(value)))})}, e3, e4))))
      +ok_v = prefix_valid(v, SCon{'.', sg}, Equal.trans(Bool, Utf8.valid(v ++ SCon{'.', sg}), Utf8.valid(p), True{}, Equal.cong(String, Bool, x => Utf8.valid(x), v ++ SCon{'.', sg}, p, Equal.sym(String, p, v ++ SCon{'.', sg}, split)), ok))
      +ok_value = Equal.trans(Bool, Utf8.valid(value), Utf8.valid(v), True{}, Equal.cong(String, Bool, x => Utf8.valid(x), value, v, Equal.sym(String, v, value, same)), ok_v)
      (key, (member, (sec, (ok_value, wire_eq))))

def vs_accept(+first: String, +rest: List<&2, String>, +wire: String, +value: String, +p: String, +v: String, +sg: String, +bytes: List<&2, U32>, +ok: {Utf8.valid(p) == True{} : Bool}, +escaped: {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(p)} : Result<&2, &2, Url.Error, List<&2, U32>>}, +split: {p == v ++ SCon{'.', sg} : String}, +canon: {sg == Spec.base64(bytes) : String}, x: Bool, +ex: {Spec.secrets(first <> rest) && Spec.authentic(first <> rest, v, bytes) == x : Bool}, h: {Spec.accept(v, x) == Some{value} : Maybe<&2, String>}) -> Signed(first, rest, wire, value):
  match x:
    case False{}:
      none_value(Signed(first, rest, wire, value), value, h)
    case True{}:
      +sec = and_left(Spec.secrets(first <> rest), Spec.authentic(first <> rest, v, bytes), ex)
      +au = and_right(Spec.secrets(first <> rest), Spec.authentic(first <> rest, v, bytes), ex)
      assemble(first, rest, wire, value, p, v, sg, bytes, sec, ok, escaped, split, canon, Utf8Sound.some_inj(v, value, h), authentic_sound(first <> rest, v, bytes, au))

def vs_canon(+first: String, +rest: List<&2, String>, +wire: String, +value: String, +p: String, +v: String, +sg: String, +bytes: List<&2, U32>, +ok: {Utf8.valid(p) == True{} : Bool}, +escaped: {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(p)} : Result<&2, &2, Url.Error, List<&2, U32>>}, +split: {p == v ++ SCon{'.', sg} : String}, can: {sg == Spec.base64(bytes) : String} & {Octets.valid(bytes) == True{} : Bool}, h: {Spec.authenticated_by(S.Keys{first, rest}, v, bytes) == Some{value} : Maybe<&2, String>}) -> Signed(first, rest, wire, value):
  match can:
    case (+canon, octets):
      vs_accept(first, rest, wire, value, p, v, sg, bytes, ok, escaped, split, canon, Spec.secrets(first <> rest) && Spec.authentic(first <> rest, v, bytes), {==}, h)

def vs_sig(+first: String, +rest: List<&2, String>, +wire: String, +value: String, +p: String, +v: String, +sg: String, +ok: {Utf8.valid(p) == True{} : Bool}, +escaped: {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(p)} : Result<&2, &2, Url.Error, List<&2, U32>>}, +split: {p == v ++ SCon{'.', sg} : String}, +mb: Maybe<&2, List<&2, U32>>, emb: {B.decode(sg, False{}, True{}) == mb : Maybe<&2, List<&2, U32>>}, h: {Spec.authenticated(S.Keys{first, rest}, v, mb) == Some{value} : Maybe<&2, String>}) -> Signed(first, rest, wire, value):
  match mb:
    case None{}:
      none_value(Signed(first, rest, wire, value), value, h)
    case Some{+bytes}:
      vs_canon(first, rest, wire, value, p, v, sg, bytes, ok, escaped, split, B64.canonical(sg, bytes, emb), h)

def vs_split(+first: String, +rest: List<&2, String>, +wire: String, +value: String, +p: String, +ok: {Utf8.valid(p) == True{} : Bool}, +escaped: {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(p)} : Result<&2, &2, Url.Error, List<&2, U32>>}, +m: Maybe<&2, Spec.Parts>, split: LD(p, m), h: {Spec.verify_split(S.Keys{first, rest}, m) == Some{value} : Maybe<&2, String>}) -> Signed(first, rest, wire, value):
  match m:
    case None{}:
      none_value(Signed(first, rest, wire, value), value, h)
    case Some{Spec.Parts{+v, +sg}}:
      vs_sig(first, rest, wire, value, p, v, sg, ok, escaped, split, B.decode(sg, False{}, True{}), {==}, h)

def vs_url(+first: String, +rest: List<&2, String>, +wire: String, +value: String, +p: String, us: {Utf8.valid(p) == True{} : Bool} & {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(p)} : Result<&2, &2, Url.Error, List<&2, U32>>}, h: {Spec.verify_split(S.Keys{first, rest}, Spec.last_dot(p)) == Some{value} : Maybe<&2, String>}) -> Signed(first, rest, wire, value):
  match us:
    case (+ok, +escaped):
      vs_split(first, rest, wire, value, p, ok, escaped, Spec.last_dot(p), last_dot_sound(p), h)

def vs_payload(+first: String, +rest: List<&2, String>, +wire: String, +value: String, +d: Result<&2, &2, Url.Error, String>, ed: {Url.decode(wire) == d : Result<&2, &2, Url.Error, String>}, h: {Spec.verify_payload(S.Keys{first, rest}, d) == Some{value} : Maybe<&2, String>}) -> Signed(first, rest, wire, value):
  match d:
    case Fail{e}:
      none_value(Signed(first, rest, wire, value), value, h)
    case Done{+p}:
      vs_url(first, rest, wire, value, p, url_sound(wire, p, ed), h)

def verify_sound(+first: String, +rest: List<&2, String>, +wire: String, +value: String, h: {S.verify(S.Keys{first, rest}, wire) == Some{value} : Maybe<&2, String>}) -> Signed(first, rest, wire, value):
  +spec = Equal.trans(Maybe<&2, String>, Spec.verify_payload(S.Keys{first, rest}, Url.decode(wire)), S.verify(S.Keys{first, rest}, wire), Some{value}, Equal.sym(Maybe<&2, String>, S.verify_decoded(S.Keys{first, rest}, Url.decode(wire)), Spec.verify_payload(S.Keys{first, rest}, Url.decode(wire)), SCP.payload_eq(S.Keys{first, rest}, Url.decode(wire))), h)
  vs_payload(first, rest, wire, value, Url.decode(wire), {==}, spec)

def Laws.signed_cookie_verify_sound(first, rest, wire, value, verified):
  verify_sound(first, rest, wire, value, verified)

# ---- Verification completeness ----

# The implementation's split, signature decode and digest check on an
# already URL-decoded payload, as in BND-32's wire_digest.
def decoded_digest(+keys: S.Keys, +value: String, +signature: List<&2, U32>, frame: {Cookie.split(String.reverse(value ++ "." ++ B.encode(signature, False{}, True{})), '.') == (String.reverse(B.encode(signature, False{}, True{})), Some{String.reverse(value)}) : String & Maybe<&2, String>}, octets: {Octets.valid(signature) == True{} : Bool}) -> {S.verify_decoded(keys, Done{value ++ "." ++ B.encode(signature, False{}, True{})}) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}:
  %Equal.sym(String & Maybe<&2, String>, Cookie.split(String.reverse(value ++ "." ++ B.encode(signature, False{}, True{})), '.'), (String.reverse(B.encode(signature, False{}, True{})), Some{String.reverse(value)}), frame) : {S.verify_parts(keys, _) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  %Equal.sym(String, String.reverse(String.reverse(value)), value, SCP.reverse_twice(value)) : {S.verify_base64(keys, _, B.decode(String.reverse(String.reverse(B.encode(signature, False{}, True{}))), False{}, True{})) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  %Equal.sym(String, String.reverse(String.reverse(B.encode(signature, False{}, True{}))), B.encode(signature, False{}, True{}), SCP.reverse_twice(B.encode(signature, False{}, True{}))) : {S.verify_base64(keys, value, B.decode(_, False{}, True{})) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  %Equal.sym(Maybe<&2, List<&2, U32>>, B.decode(B.encode(signature, False{}, True{}), False{}, True{}), Some{signature}, Base64Proof.roundtrip(signature, False{}, True{}, octets)) : {S.verify_base64(keys, value, _) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  {==}

def verify_complete(+first: String, +rest: List<&2, String>, +key: String, +wire: String, +value: String, member: Spec.contains(key, first <> rest), usable: {Spec.secrets(first <> rest) == True{} : Bool}, valid: {Utf8.valid(value) == True{} : Bool}, escaped: {DSpec.unpercent(Utf8.encode(wire)) == Done{Utf8.encode(value ++ "." ++ Spec.base64(Hmac.sha256(Utf8.encode(key), Utf8.encode(value))))} : Result<&2, &2, Url.Error, List<&2, U32>>}) -> {S.verify(S.Keys{first, rest}, wire) == Some{value} : Maybe<&2, String>}:
  +sig = S.digest(key, value)
  +payload = value ++ "." ++ B.encode(sig, False{}, True{})
  +escaped2 = Equal.trans(Result<&2, &2, Url.Error, List<&2, U32>>, DSpec.unpercent(Utf8.encode(wire)), Done{Utf8.encode(value ++ "." ++ Spec.base64(sig))}, Done{Utf8.encode(payload)}, escaped, Equal.cong(String, Result<&2, &2, Url.Error, List<&2, U32>>, x => Done{Utf8.encode(value ++ "." ++ x)}, Spec.base64(sig), B.encode(sig, False{}, True{}), Equal.sym(String, B.encode(sig, False{}, True{}), Spec.base64(sig), Format.encode_eq(sig))))
  +dec = url_complete(wire, payload, Wire.payload_valid(value, sig, valid), escaped2)
  %Equal.sym(Result<&2, &2, Url.Error, String>, Url.decode(wire), Done{payload}, dec) : {S.verify_decoded(S.Keys{first, rest}, _) == Some{value} : Maybe<&2, String>}
  Equal.trans(Maybe<&2, String>, S.verify_decoded(S.Keys{first, rest}, Done{payload}), S.verify_digest(S.Keys{first, rest}, value, sig), Some{value}, decoded_digest(S.Keys{first, rest}, value, sig, Wire.payload_split(value, sig), Wire.hmac_octets(Utf8.encode(key), Utf8.encode(value))), SCP.member(first, rest, key, value, member, usable))

def Laws.signed_cookie_verify_complete(first, rest, key, wire, value, member, usable, valid, escaped):
  verify_complete(first, rest, key, wire, value, member, usable, valid, escaped)
