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
import ./signed-cookie-config.bend as Config
import ./signed-cookie-wire.bend as Wire
import ./signed-cookie-format.bend as Format
import ./cookie-serialization-spec.bend as CSpec
import ./cookie-serialization.bend as CSerProof
import ./cookie-ows-spec.bend as OwsSpec
import ./cookie-ows.bend as OwsProof
import ./cookies.bend as CookieProof
import ../src/app/context.bend as Context

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

# Wire composition. Its frame, scalar and octet premises are discharged for
# every value and signature in signed-cookie-wire.bend.
def reverse_twice(+s: String) -> {String.reverse(String.reverse(s)) == s : String}:
  Equal.trans(String, String.reverse(String.reverse(s)), s ++ "", s, Support.reverse_twice(s, "", ""), Support.string_nil(s))

def wire_digest(+keys: S.Keys, +value: String, +signature: List<&2, U32>, scalar: {Utf8.valid(value ++ "." ++ Base64.encode(signature, False{}, True{})) == True{} : Bool}, frame: {Cookie.split(String.reverse(value ++ "." ++ Base64.encode(signature, False{}, True{})), '.') == (String.reverse(Base64.encode(signature, False{}, True{})), Some{String.reverse(value)}) : String & Maybe<&2, String>}, octets: {Octets.valid(signature) == True{} : Bool}) -> {S.verify(keys, Url.encode(value ++ "." ++ Base64.encode(signature, False{}, True{}))) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}:
  %Equal.sym(Result<&2, &2, Url.Error, String>, Url.decode(Url.encode(value ++ "." ++ Base64.encode(signature, False{}, True{}))), Done{value ++ "." ++ Base64.encode(signature, False{}, True{})}, percent_roundtrip(value ++ "." ++ Base64.encode(signature, False{}, True{}), scalar)) : {S.verify_decoded(keys, _) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  %Equal.sym(String & Maybe<&2, String>, Cookie.split(String.reverse(value ++ "." ++ Base64.encode(signature, False{}, True{})), '.'), (String.reverse(Base64.encode(signature, False{}, True{})), Some{String.reverse(value)}), frame) : {S.verify_parts(keys, _) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  %Equal.sym(String, String.reverse(String.reverse(value)), value, reverse_twice(value)) : {S.verify_base64(keys, _, Base64.decode(String.reverse(String.reverse(Base64.encode(signature, False{}, True{}))), False{}, True{})) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  %Equal.sym(String, String.reverse(String.reverse(Base64.encode(signature, False{}, True{}))), Base64.encode(signature, False{}, True{}), reverse_twice(Base64.encode(signature, False{}, True{}))) : {S.verify_base64(keys, value, Base64.decode(_, False{}, True{})) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  %Equal.sym(Maybe<&2, List<&2, U32>>, Base64.decode(Base64.encode(signature, False{}, True{}), False{}, True{}), Some{signature}, Base64Proof.roundtrip(signature, False{}, True{}, octets)) : {S.verify_base64(keys, value, _) == S.verify_digest(keys, value, signature) : Maybe<&2, String>}
  {==}

def wire(+first: String, +rest: List<&2, String>, +key: String, +value: String, contained: Spec.contains(key, first <> rest), valid: {Utf8.valid(value) == True{} : Bool}) -> {S.verify(S.Keys{first, rest}, S.sign(key, value)) == Some{value} : Maybe<&2, String>}:
  Equal.trans(Maybe<&2, String>, S.verify(S.Keys{first, rest}, S.sign(key, value)), S.verify_digest(S.Keys{first, rest}, value, S.digest(key, value)), Some{value}, wire_digest(S.Keys{first, rest}, value, S.digest(key, value), Wire.payload_valid(value, S.digest(key, value), valid), Wire.payload_split(value, S.digest(key, value)), Wire.hmac_octets(Utf8.encode(key), Utf8.encode(value))), member(first, rest, key, value, contained))

def Laws.signed_cookie_configure_spec(xs):
  Config.configure(xs)

def Laws.signed_cookie_configure_nonempty(xs, keys, configured):
  Config.nonempty(xs, keys, configured)

def Laws.signed_cookie_wire_first(first, rest, value, valid):
  wire(first, rest, first, value, Inl{{==}}, valid)

def Laws.signed_cookie_wire_member(first, rest, key, value, contained, valid):
  wire(first, rest, key, value, contained, valid)

def scalar_true(+value: String, +valid: {Utf8.valid(value) == True{} : Bool}) -> {S.scalar_valid(value) == True{} : Bool}:
  Equal.trans(Bool, S.scalar_valid(value), Utf8.valid(value), True{}, Config.scalar(value), valid)

def serialize_first(+name: String, +value: String, +first: String, +rest: List<&2, String>, +options: Cookie.Options, +valid: {Utf8.valid(value) == True{} : Bool}) -> {S.serialize(name, value, S.Keys{first, rest}, options) == Cookie.serialize(name, Spec.signed_wire(first, value), options) : Result<&2, &2, Cookie.Error, String>}:
  %Equal.sym(Bool, S.scalar_valid(value), True{}, scalar_true(value, valid)) : {S.serialize_valid(name, value, S.Keys{first, rest}, options, _) == Cookie.serialize(name, Spec.signed_wire(first, value), options) : Result<&2, &2, Cookie.Error, String>}
  Equal.cong(String, Result<&2, &2, Cookie.Error, String>, w => Cookie.serialize(name, w, options), S.sign(first, value), Spec.signed_wire(first, value), Format.sign_eq(first, value))

def serialize_invalid(+name: String, +value: String, +first: String, +rest: List<&2, String>, +options: Cookie.Options, +invalid: {Utf8.valid(value) == False{} : Bool}) -> {S.serialize(name, value, S.Keys{first, rest}, options) == Fail{Cookie.InvalidValue{}} : Result<&2, &2, Cookie.Error, String>}:
  %Equal.sym(Bool, S.scalar_valid(value), False{}, Equal.trans(Bool, S.scalar_valid(value), Utf8.valid(value), False{}, Config.scalar(value), invalid)) : {S.serialize_valid(name, value, S.Keys{first, rest}, options, _) == Fail{Cookie.InvalidValue{}} : Result<&2, &2, Cookie.Error, String>}
  {==}

def admissible_swap(+nv: Bool, +rest: Bool, +vv: Bool, ok: {nv && rest == True{} : Bool}, okv: {vv == True{} : Bool}) -> {nv && (vv && rest) == True{} : Bool}:
  match nv:
    case False{}: absurd({False{} == True{} : Bool}, false_true(ok))
    case True{}: Wire.both(vv, rest, okv, ok)

# Admissibility depends on the value only through the cookie-octet rule.
def admissible_value(+name: String, +value: String, +options: Cookie.Options, ok: {CSpec.admissible(name, "", options) == True{} : Bool}, okv: {CSpec.value_valid(value) == True{} : Bool}) -> {CSpec.admissible(name, value, options) == True{} : Bool}:
  match options:
    case Cookie.Options{+p, +d, +a, +e, +secure, +h, +site, +part}:
      admissible_swap(CSpec.name_valid(name), CSpec.optional_valid(~CSpec.path_valid, p) && (CSpec.optional_valid(~CSpec.domain_valid, d) && (CSpec.optional_valid(~CSpec.expires_valid, e) && ((Bool.not(CSpec.unrestricted(site)) || secure) && (Bool.not(part) || secure)))), CSpec.value_valid(value), ok, okv)

def set_cookie_field(+name: String, +value: String, +first: String, +rest: List<&2, String>, +options: Cookie.Options, +valid: {Utf8.valid(value) == True{} : Bool}, ok: {CSpec.admissible(name, "", options) == True{} : Bool}) -> {S.serialize(name, value, S.Keys{first, rest}, options) == Done{CSpec.wire(name, Spec.signed_wire(first, value), options)} : Result<&2, &2, Cookie.Error, String>}:
  +wire = Spec.signed_wire(first, value)
  Equal.trans(Result<&2, &2, Cookie.Error, String>, S.serialize(name, value, S.Keys{first, rest}, options), Cookie.serialize(name, wire, options), Done{CSpec.wire(name, wire, options)}, serialize_first(name, value, first, rest, options, valid), CSerProof.successful(name, wire, options, Cookie.validate(name, wire, options), Equal.trans(Bool, CSerProof.status(Cookie.validate(name, wire, options)), CSpec.admissible(name, wire, options), True{}, CSerProof.validation_status(name, wire, options), admissible_value(name, wire, options, ok, Format.wire_valid(first, value)))))

def word_cmp_refl(+n: Nat, +w: Word(n)) -> {Word.cmp(n, w, w) == EQ{} : Cmp}:
  match n w:
    case 0n WNil{}: {==}
    case 1n+p WCon{+b, +t}:
      match b:
        case False{}:
          %Equal.sym(Cmp, Word.cmp(p, t, t), EQ{}, word_cmp_refl(p, t)) : {Word.cmp.fin(False{}, False{}, _) == EQ{} : Cmp}
          {==}
        case True{}:
          %Equal.sym(Cmp, Word.cmp(p, t, t), EQ{}, word_cmp_refl(p, t)) : {Word.cmp.fin(True{}, True{}, _) == EQ{} : Cmp}
          {==}

def order_refl(+s: String) -> {String.order.go(s, s, EQ{}) == EQ{} : Cmp}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{U32{+w}}, +t}:
      %Equal.sym(Cmp, Word.cmp(32n, w, w), EQ{}, word_cmp_refl(32n, w)) : {String.order.go(t, t, _) == EQ{} : Cmp}
      order_refl(t)

def name_refl(+s: String) -> {String.eq(s, s) == True{} : Bool}:
  Equal.cong(Cmp, Bool, c => Cmp.is_eq(c), String.order.go(s, s, EQ{}), EQ{}, order_refl(s))

def found_rest(+after: List<&2, Cookie.Entry>, +wire: String, +name: String) -> {Cookie.first_go(after, Some{wire}, name) == Some{wire} : Maybe<&2, String>}:
  match after:
    case Nil{}: {==}
    case Cookie.Entry{+k, +v} <> +t: {==}

# BND-31 first-wins: earlier pairs with other names are passed over.
def first_found(+before: List<&2, Cookie.Entry>, +name: String, +wire: String, +after: List<&2, Cookie.Entry>, +distinct: {Spec.unnamed(before, name) == True{} : Bool}) -> {Cookie.first_go(List.append(&2, Cookie.Entry, before, Cookie.Entry{name, wire} <> after), None{}, name) == Some{wire} : Maybe<&2, String>}:
  match before:
    case Nil{}:
      %Equal.sym(Bool, String.eq(name, name), True{}, name_refl(name)) : {Cookie.first_go(after, Cookie.accepted_value(wire, _), name) == Some{wire} : Maybe<&2, String>}
      found_rest(after, wire, name)
    case Cookie.Entry{+k, +v} <> +t:
      +other = Wire.not_true(String.eq(k, name), Wire.and_left(Bool.not(String.eq(k, name)), Spec.unnamed(t, name), distinct))
      %Equal.sym(Bool, String.eq(k, name), False{}, other) : {Cookie.first_go(List.append(&2, Cookie.Entry, t, Cookie.Entry{name, wire} <> after), Cookie.accepted_value(v, _), name) == Some{wire} : Maybe<&2, String>}
      first_found(t, name, wire, after, Wire.and_right(Bool.not(String.eq(k, name)), Spec.unnamed(t, name), distinct))

def entries_and(+a: Bool, +b: Bool, +c: Bool, +d: Bool, ok: {a && b && c == True{} : Bool}, okd: {d == True{} : Bool}) -> {a && b && d == True{} : Bool}:
  match a b:
    case False{} _: absurd({False{} && b && d == True{} : Bool}, false_true(ok))
    case True{} False{}: absurd({True{} && False{} && d == True{} : Bool}, false_true(ok))
    case True{} True{}: okd

def entries_append(+xs: List<&2, Cookie.Entry>, +ys: List<&2, Cookie.Entry>, +okx: {OwsSpec.entries_valid(xs) == True{} : Bool}, +oky: {OwsSpec.entries_valid(ys) == True{} : Bool}) -> {OwsSpec.entries_valid(List.append(&2, Cookie.Entry, xs, ys)) == True{} : Bool}:
  match xs:
    case Nil{}: oky
    case Cookie.Entry{+k, +v} <> +t:
      entries_and(CSpec.name_valid(k), CSpec.value_valid(v), OwsSpec.entries_valid(t), OwsSpec.entries_valid(List.append(&2, Cookie.Entry, t, ys)), okx, entries_append(t, ys, Wire.and_right(CSpec.name_valid(k) && CSpec.value_valid(v), OwsSpec.entries_valid(t), okx), oky))

# The Cookie header joined with "; " parses back to its entries (BND-31).
def semispace(+entries: List<&2, Cookie.Entry>, valid: {OwsSpec.entries_valid(entries) == True{} : Bool}) -> {Cookie.parse(String.join(OwsSpec.pairs(entries), "; ")) == entries : List<&2, Cookie.Entry>}:
  match entries:
    case Nil{}: {==}
    case Cookie.Entry{+name, +value} <> +t:
      +ok = CookieProof.head_valid(name, value, OwsSpec.entries_valid(t), valid)
      OwsProof.joined_semispace(t, OwsSpec.Empty{}, name, value, OwsProof.left(Cookie.name_valid(name), Cookie.value_valid(value), OwsProof.left(Cookie.name_valid(name) && Cookie.value_valid(value), OwsSpec.entries_valid(t), ok)), OwsProof.right(Cookie.name_valid(name), Cookie.value_valid(value), OwsProof.left(Cookie.name_valid(name) && Cookie.value_valid(value), OwsSpec.entries_valid(t), ok)), OwsProof.right(Cookie.name_valid(name) && Cookie.value_valid(value), OwsSpec.entries_valid(t), ok))

def request_roundtrip(+name: String, +value: String, +first: String, +rest: List<&2, String>, +key: String, +before: List<&2, Cookie.Entry>, +after: List<&2, Cookie.Entry>, contained: Spec.contains(key, first <> rest), +valid: {Utf8.valid(value) == True{} : Bool}, +named: {CSpec.name_valid(name) == True{} : Bool}, +earlier: {OwsSpec.entries_valid(before) == True{} : Bool}, +later: {OwsSpec.entries_valid(after) == True{} : Bool}, +distinct: {Spec.unnamed(before, name) == True{} : Bool}) -> {S.read(S.Keys{first, rest}, Cookie.first(Cookie.parse(String.join(OwsSpec.pairs(List.append(&2, Cookie.Entry, before, Cookie.Entry{name, Spec.signed_wire(key, value)} <> after)), "; ")), name)) == Some{value} : Maybe<&2, String>}:
  +signed = Spec.signed_wire(key, value)
  +entries = List.append(&2, Cookie.Entry, before, Cookie.Entry{name, signed} <> after)
  +cons_ok = Wire.both(CSpec.name_valid(name) && CSpec.value_valid(signed), OwsSpec.entries_valid(after), Wire.both(CSpec.name_valid(name), CSpec.value_valid(signed), named, Format.wire_valid(key, value)), later)
  %Equal.sym(List<&2, Cookie.Entry>, Cookie.parse(String.join(OwsSpec.pairs(entries), "; ")), entries, semispace(entries, entries_append(before, Cookie.Entry{name, signed} <> after, earlier, cons_ok))) : {S.read(S.Keys{first, rest}, Cookie.first(_, name)) == Some{value} : Maybe<&2, String>}
  %Equal.sym(Maybe<&2, String>, Cookie.first(entries, name), Some{signed}, first_found(before, name, signed, after, distinct)) : {S.read(S.Keys{first, rest}, _) == Some{value} : Maybe<&2, String>}
  %Format.sign_eq(key, value) : {S.verify(S.Keys{first, rest}, _) == Some{value} : Maybe<&2, String>}
  wire(first, rest, key, value, contained, valid)

def Laws.signed_cookie_sign_spec(key, value):
  Format.sign_eq(key, value)

def Laws.signed_cookie_serialize_first(name, value, first, rest, options, valid):
  serialize_first(name, value, first, rest, options, valid)

def Laws.signed_cookie_serialize_invalid(name, value, first, rest, options, invalid):
  serialize_invalid(name, value, first, rest, options, invalid)

def Laws.signed_cookie_setter_first(Vars, c, name, value, first, rest, options, valid):
  Equal.cong(Result<&2, &2, Cookie.Error, String>, Result<&2, &2, Cookie.Error, Context.Ctx<Vars>>, r => Context.cookie_result(Vars, c, r), S.serialize(name, value, S.Keys{first, rest}, options), Cookie.serialize(name, Spec.signed_wire(first, value), options), serialize_first(name, value, first, rest, options, valid))

def Laws.signed_cookie_set_cookie_field(name, value, first, rest, options, valid, admissible):
  set_cookie_field(name, value, first, rest, options, valid, admissible)

def Laws.signed_cookie_context_read(Vars, c, name, keys):
  {==}

def Laws.signed_cookie_request_roundtrip(name, value, first, rest, key, before, after, contained, valid, named, earlier, later, distinct):
  request_roundtrip(name, value, first, rest, key, before, after, contained, valid, named, earlier, later, distinct)

def accept_eq(+value: String, +b: Bool) -> {S.verified(value, b) == Spec.accept(value, b) : Maybe<&2, String>}:
  match b:
    case False{}: {==}
    case True{}: {==}

def by_keys(+keys: S.Keys, +value: String, +bytes: List<&2, U32>) -> {S.verify_digest(keys, value, bytes) == Spec.authenticated_by(keys, value, bytes) : Maybe<&2, String>}:
  match keys:
    case S.Keys{+first, +rest}:
      Equal.trans(Maybe<&2, String>, S.verify_digest(S.Keys{first, rest}, value, bytes), S.verified(value, Spec.authentic(first <> rest, value, bytes)), Spec.accept(value, Spec.authentic(first <> rest, value, bytes)), digest_spec(first, rest, value, bytes), accept_eq(value, Spec.authentic(first <> rest, value, bytes)))

def signature_eq(+keys: S.Keys, +value: String, +signature: Maybe<&2, List<&2, U32>>) -> {S.verify_base64(keys, value, signature) == Spec.authenticated(keys, value, signature) : Maybe<&2, String>}:
  match signature:
    case None{}: {==}
    case Some{+bytes}: by_keys(keys, value, bytes)

def parts_eq(+keys: S.Keys, +m: Maybe<&2, Spec.Parts>, +p: String) -> {S.verify_parts(keys, Wire.expected(m, p)) == Spec.verify_split(keys, m) : Maybe<&2, String>}:
  match m:
    case None{}: {==}
    case Some{Spec.Parts{+v, +s}}:
      %Equal.sym(String, String.reverse(String.reverse(v)), v, Wire.reverse_twice(v)) : {S.verify_base64(keys, _, Base64.decode(String.reverse(String.reverse(s)), False{}, True{})) == Spec.authenticated(keys, v, Base64.decode(s, False{}, True{})) : Maybe<&2, String>}
      %Equal.sym(String, String.reverse(String.reverse(s)), s, Wire.reverse_twice(s)) : {S.verify_base64(keys, v, Base64.decode(_, False{}, True{})) == Spec.authenticated(keys, v, Base64.decode(s, False{}, True{})) : Maybe<&2, String>}
      signature_eq(keys, v, Base64.decode(s, False{}, True{}))

def payload_eq(+keys: S.Keys, +decoded: Result<&2, &2, Url.Error, String>) -> {S.verify_decoded(keys, decoded) == Spec.verify_payload(keys, decoded) : Maybe<&2, String>}:
  match decoded:
    case Fail{e}: {==}
    case Done{+p}:
      %Equal.sym(String & Maybe<&2, String>, Cookie.split(String.reverse(p), '.'), Wire.expected(Spec.last_dot(p), p), Wire.split_last(p)) : {S.verify_parts(keys, _) == Spec.verify_split(keys, Spec.last_dot(p)) : Maybe<&2, String>}
      parts_eq(keys, Spec.last_dot(p), p)

def Laws.signed_cookie_wire_spec(keys, wire):
  payload_eq(keys, Url.decode(wire))
