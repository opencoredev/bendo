import Base
import ../src/data/cookie.bend as Cookie
import ../src/data/base64.bend as Base64
import ../src/crypto/octets.bend as Octets
import ./crypto-base64.bend as Base64Proof
import ./crypto-support.bend as Support
import ./signed-cookie-laws.bend as Laws
import ./signed-cookie-spec.bend as Spec
import ./signed-cookie-compare.bend as CompareProof
import ../src/data/signed-cookie.bend as S
import ../src/data/utf8.bend as Utf8
import ../src/crypto/compare.bend as Compare
import ./percent.bend as Percent
import ./utf8.bend as Utf8Proof
import ../src/data/urlencoded.bend as Url

def distinguish(b: Bool) -> Type:
  match b:
    case False{}: Unit
    case True{}: Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : distinguish(_)
  Unit{}

def absurd(-A: Type, e: Empty) -> A:
  match e:

def and_left(+a: Bool, +b: Bool, ok: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case False{}: ok
    case True{}: {==}

def and_right(+a: Bool, +b: Bool, ok: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}: absurd({b == True{} : Bool}, false_true(ok))
    case True{}: ok

def bit_refl(+a: Bool) -> {Spec.bit_equal(a, a) == True{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def word_refl(+n: Nat, +a: Word(n)) -> {Spec.word_equal(n, a, a) == True{} : Bool}:
  match n a:
    case 0n WNil{}: {==}
    case 1n+p WCon{+h, +t}:
      %Equal.sym(Bool, Spec.bit_equal(h, h), True{}, bit_refl(h)) : {_ && Spec.word_equal(p, t, t) == True{} : Bool}
      word_refl(p, t)

def bytes_refl(+xs: List<&2, U32>) -> {Spec.bytes_equal(xs, xs) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case U32{+w} <> +t:
      %Equal.sym(Bool, Spec.word_equal(32n, w, w), True{}, word_refl(32n, w)) : {_ && Spec.bytes_equal(t, t) == True{} : Bool}
      bytes_refl(t)

def or_assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a || b) || c == a || (b || c) : Bool}:
  match a:
    case False{}: {==}
    case True{}: {==}

def matches_acc(+keys: List<&2, String>, +value: String, +signature: List<&2, U32>, +found: Bool) -> {S.matches_go(keys, value, signature, found) == found || Spec.authentic(keys, value, signature) : Bool}:
  match keys:
    case Nil{}:
      match found:
        case False{}: {==}
        case True{}: {==}
    case +key <> +rest:
      %Equal.sym(Bool, Compare.ct_equal(S.digest(key, value), signature), Spec.bytes_equal(S.digest(key, value), signature), CompareProof.equal(S.digest(key, value), signature)) : {S.matches_go(rest, value, signature, found || _) == found || (Spec.bytes_equal(S.digest(key, value), signature) || Spec.authentic(rest, value, signature)) : Bool}
      Equal.trans(Bool, S.matches_go(rest, value, signature, found || Spec.bytes_equal(S.digest(key, value), signature)), (found || Spec.bytes_equal(S.digest(key, value), signature)) || Spec.authentic(rest, value, signature), found || (Spec.bytes_equal(S.digest(key, value), signature) || Spec.authentic(rest, value, signature)), matches_acc(rest, value, signature, found || Spec.bytes_equal(S.digest(key, value), signature)), or_assoc(found, Spec.bytes_equal(S.digest(key, value), signature), Spec.authentic(rest, value, signature)))

def digest_spec(+first: String, +rest: List<&2, String>, +value: String, +signature: List<&2, U32>) -> {S.verify_digest(S.Keys{first, rest}, value, signature) == S.verified(value, Spec.authentic(first <> rest, value, signature)) : Maybe<&2, String>}:
  Equal.cong(Bool, Maybe<&2, String>, b => S.verified(value, b), S.matches_go(first <> rest, value, signature, False{}), Spec.authentic(first <> rest, value, signature), matches_acc(first <> rest, value, signature, False{}))

def or_true(+b: Bool) -> {b || True{} == True{} : Bool}:
  match b:
    case False{}: {==}
    case True{}: {==}

def authentic_member(+keys: List<&2, String>, +key: String, +value: String, member: Spec.contains(key, keys)) -> {Spec.authentic(keys, value, S.digest(key, value)) == True{} : Bool}:
  match keys:
    case Nil{}: absurd({Spec.authentic([], value, S.digest(key, value)) == True{} : Bool}, member)
    case +first <> +rest:
      match member:
        case Inl{same}:
          %Equal.sym(String, key, first, same) : {Spec.authentic(first <> rest, value, S.digest(_, value)) == True{} : Bool}
          %Equal.sym(Bool, Spec.bytes_equal(S.digest(first, value), S.digest(first, value)), True{}, bytes_refl(S.digest(first, value))) : {_ || Spec.authentic(rest, value, S.digest(first, value)) == True{} : Bool}
          {==}
        case Inr{later}:
          %Equal.sym(Bool, Spec.authentic(rest, value, S.digest(key, value)), True{}, authentic_member(rest, key, value, later)) : {Spec.bytes_equal(S.digest(first, value), S.digest(key, value)) || _ == True{} : Bool}
          or_true(Spec.bytes_equal(S.digest(first, value), S.digest(key, value)))

def bit_sound(+a: Bool, +b: Bool, ok: {Spec.bit_equal(a, b) == True{} : Bool}) -> {a == b : Bool}:
  match a b:
    case False{} False{}: {==}
    case True{} True{}: {==}
    case False{} True{}: absurd({False{} == True{} : Bool}, false_true(ok))
    case True{} False{}: absurd({True{} == False{} : Bool}, false_true(ok))

def word_sound(+n: Nat, +a: Word(n), +b: Word(n), +ok: {Spec.word_equal(n, a, b) == True{} : Bool}) -> {a == b : Word(n)}:
  match n a b:
    case 0n WNil{} WNil{}: {==}
    case 1n+p WCon{+ah, +at} WCon{+bh, +bt}:
      %bit_sound(ah, bh, and_left(Spec.bit_equal(ah, bh), Spec.word_equal(p, at, bt), ok)) : {WCon{ah, at} == WCon{_, bt} : Word(1n+p)}
      Equal.cong(Word(p), Word(1n+p), t => WCon{ah, t}, at, bt, word_sound(p, at, bt, and_right(Spec.bit_equal(ah, bh), Spec.word_equal(p, at, bt), ok)))

def bytes_sound(+xs: List<&2, U32>, +ys: List<&2, U32>, +ok: {Spec.bytes_equal(xs, ys) == True{} : Bool}) -> {xs == ys : List<&2, U32>}:
  match xs ys:
    case Nil{} Nil{}: {==}
    case Nil{} y <> yt: absurd({[] == y <> yt : List<&2, U32>}, false_true(ok))
    case x <> xt Nil{}: absurd({x <> xt == [] : List<&2, U32>}, false_true(ok))
    case U32{+a} <> +at U32{+b} <> +bt:
      %word_sound(32n, a, b, and_left(Spec.word_equal(32n, a, b), Spec.bytes_equal(at, bt), ok)) : {U32{a} <> at == U32{_} <> bt : List<&2, U32>}
      Equal.cong(List<&2, U32>, List<&2, U32>, t => U32{a} <> t, at, bt, bytes_sound(at, bt, and_right(Spec.word_equal(32n, a, b), Spec.bytes_equal(at, bt), ok)))

def unequal_decide(+xs: List<&2, U32>, +ys: List<&2, U32>, b: Bool, e: {Spec.bytes_equal(xs, ys) == b : Bool}, ne: {xs != ys : List<&2, U32>}) -> {Spec.bytes_equal(xs, ys) == False{} : Bool}:
  match b:
    case False{}: e
    case True{}: absurd({Spec.bytes_equal(xs, ys) == False{} : Bool}, ne(bytes_sound(xs, ys, e)))

def reject_all(+keys: List<&2, String>, +value: String, +signature: List<&2, U32>, ne: Spec.different(keys, value, signature)) -> {Spec.authentic(keys, value, signature) == False{} : Bool}:
  match keys:
    case Nil{}: {==}
    case +key <> +rest:
      (head, tail) = ne
      %Equal.sym(Bool, Spec.bytes_equal(S.digest(key, value), signature), False{}, unequal_decide(S.digest(key, value), signature, Spec.bytes_equal(S.digest(key, value), signature), {==}, head)) : {_ || Spec.authentic(rest, value, signature) == False{} : Bool}
      reject_all(rest, value, signature, tail)

def member(+first: String, +rest: List<&2, String>, +key: String, +value: String, contained: Spec.contains(key, first <> rest)) -> {S.verify_digest(S.Keys{first, rest}, value, S.digest(key, value)) == Some{value} : Maybe<&2, String>}:
  Equal.trans(Maybe<&2, String>, S.verify_digest(S.Keys{first, rest}, value, S.digest(key, value)), S.verified(value, Spec.authentic(first <> rest, value, S.digest(key, value))), Some{value}, digest_spec(first, rest, value, S.digest(key, value)), Equal.cong(Bool, Maybe<&2, String>, b => S.verified(value, b), Spec.authentic(first <> rest, value, S.digest(key, value)), True{}, authentic_member(first <> rest, key, value, contained)))

def reject(+first: String, +rest: List<&2, String>, +value: String, +signature: List<&2, U32>, ne: Spec.different(first <> rest, value, signature)) -> {S.verify_digest(S.Keys{first, rest}, value, signature) == None{} : Maybe<&2, String>}:
  Equal.trans(Maybe<&2, String>, S.verify_digest(S.Keys{first, rest}, value, signature), S.verified(value, Spec.authentic(first <> rest, value, signature)), None{}, digest_spec(first, rest, value, signature), Equal.cong(Bool, Maybe<&2, String>, b => S.verified(value, b), Spec.authentic(first <> rest, value, signature), False{}, reject_all(first <> rest, value, signature, ne)))

def percent_roundtrip(+value: String, valid: {Utf8.valid(value) == True{} : Bool}) -> {Url.decode(Url.encode(value)) == Done{value} : Result<&2, &2, Url.Error, String>}:
  Percent.component_roundtrip(value, False{}, Utf8Proof.roundtrip(value, valid))


def Laws.signed_cookie_compare_structural(xs, ys):
  CompareProof.equal(xs, ys)

def Laws.signed_cookie_digest_first(first, rest, value):
  member(first, rest, first, value, Inl{{==}})

def Laws.signed_cookie_digest_member(first, rest, key, value, contained):
  member(first, rest, key, value, contained)

def Laws.signed_cookie_digest_reject(first, rest, value, signature, ne):
  reject(first, rest, value, signature, ne)

def Laws.signed_cookie_empty_configuration():
  {==}

def Laws.signed_cookie_percent_roundtrip(value, valid):
  percent_roundtrip(value, valid)

# Composition is proved; the remaining public-wire work is discharging these
# independent frame/octet premises for every signed value, not assuming verify.
def reverse_twice(+s: String) -> {String.reverse(String.reverse(s)) == s : String}:
  Equal.trans(String, String.reverse(String.reverse(s)), s ++ "", s, Support.reverse_twice(s, "", ""), Support.string_nil(s))

def wire_digest(+keys: S.Keys, +value: String, +signature: List<&2, U32>, scalar: {Utf8.valid(value ++ "." ++ Base64.encode(signature, False{}, True{})) == True{} : Bool}, frame: {Cookie.split(String.reverse(value ++ "." ++ Base64.encode(signature, False{}, True{})), '.') == (String.reverse(Base64.encode(signature, False{}, True{})), Some{String.reverse(value)}) : String & Maybe<&2, String>}, octets: {Octets.valid(signature) == True{} : Bool}) -> {S.verify(keys, Url.encode(value ++ "." ++ Base64.encode(signature, False{}, True{}))) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}:
  %Equal.sym(Result<&2, &2, Url.Error, String>, Url.decode(Url.encode(value ++ "." ++ Base64.encode(signature, False{}, True{}))), Done{value ++ "." ++ Base64.encode(signature, False{}, True{})}, percent_roundtrip(value ++ "." ++ Base64.encode(signature, False{}, True{}), scalar)) : {S.verify_decoded(keys, _) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  %Equal.sym(String & Maybe<&2, String>, Cookie.split(String.reverse(value ++ "." ++ Base64.encode(signature, False{}, True{})), '.'), (String.reverse(Base64.encode(signature, False{}, True{})), Some{String.reverse(value)}), frame) : {S.verify_parts(keys, _) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  %Equal.sym(String, String.reverse(String.reverse(value)), value, reverse_twice(value)) : {S.verify_base64(keys, _, Base64.decode(String.reverse(String.reverse(Base64.encode(signature, False{}, True{}))), False{}, True{})) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  %Equal.sym(String, String.reverse(String.reverse(Base64.encode(signature, False{}, True{}))), Base64.encode(signature, False{}, True{}), reverse_twice(Base64.encode(signature, False{}, True{}))) : {S.verify_base64(keys, value, Base64.decode(_, False{}, True{})) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  %Equal.sym(Maybe<&2, List<&2, U32>>, Base64.decode(Base64.encode(signature, False{}, True{}), False{}, True{}), Some{signature}, Base64Proof.roundtrip(signature, False{}, True{}, octets)) : {S.verify_base64(keys, value, _) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  {==}
