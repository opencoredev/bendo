# BND-43: token structure and the header's algorithm. A token without exactly
# two '.' separators is malformed, and a header that does not name HS256
# exactly once never verifies.
import Base
import ../src/crypto/jwt.bend as J
import ../src/crypto/compare.bend as Compare
import ../src/crypto/hmac.bend as HMAC
import ../src/data/utf8.bend as U
import ../src/data/json.bend as Json
import ./jwt.bend as JwtProof
import ./jwt-spec.bend as Spec

def nonzero(n: Nat) -> Type:
  match n:
    case 0n:
      Empty
    case 1n+p:
      Unit

def succ_zero(+n: Nat, e: {1n+n == 0n : Nat}) -> Empty:
  %e : nonzero(_)
  Unit{}

# ---- Separators ----

def free_step(+c: Char, +t: String, +x: Bool, ex: {Char.is_eq(c, '.') == x : Bool}, z: {Spec.count_dot(x, Spec.dots(t)) == 0n : Nat}, ih: {Spec.dots(t) == 0n : Nat} -> {J.dotfree(t) == True{} : Bool}) -> {J.dotfree(SCon{c, t}) == True{} : Bool}:
  match x:
    case True{}:
      JwtProof.absurd({J.dotfree(SCon{c, t}) == True{} : Bool}, succ_zero(Spec.dots(t), z))
    case False{}:
      %Equal.sym(Bool, Char.is_eq(c, '.'), False{}, ex) : {Bool.not(_) && J.dotfree(t) == True{} : Bool}
      ih(z)

# A string without '.' is dot-free in the verifier's sense.
def dotfree_of(+s: String, z: {Spec.dots(s) == 0n : Nat}) -> {J.dotfree(s) == True{} : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{+c, +t}:
      free_step(c, t, Char.is_eq(c, '.'), {==}, z, w => dotfree_of(t, w))

def dots_step(+c: Char, +t: String, +x: Bool, ex: {Char.is_eq(c, '.') == x : Bool}, f: {Bool.not(x) && J.dotfree(t) == True{} : Bool}, ih: {J.dotfree(t) == True{} : Bool} -> {Spec.dots(t) == 0n : Nat}) -> {Spec.count_dot(x, Spec.dots(t)) == 0n : Nat}:
  match x:
    case True{}:
      JwtProof.absurd({Spec.count_dot(True{}, Spec.dots(t)) == 0n : Nat}, JwtProof.false_true(f))
    case False{}:
      ih(f)

# A dot-free string has no '.'.
def dots_of(+s: String, f: {J.dotfree(s) == True{} : Bool}) -> {Spec.dots(s) == 0n : Nat}:
  match s:
    case SNil{}:
      {==}
    case SCon{+c, +t}:
      dots_step(c, t, Char.is_eq(c, '.'), {==}, f, g => dots_of(t, g))

# The separators that remain after a split.
def after(m: Maybe<&2, J.Cut>) -> Nat:
  match m:
    case None{}:
      0n
    case Some{J.Cut{a, r}}:
      1n+Spec.dots(r)

def after_prepend(+c: Char, +m: Maybe<&2, J.Cut>) -> {after(J.prepend(c, m)) == after(m) : Nat}:
  match m:
    case None{}:
      {==}
    case Some{J.Cut{a, r}}:
      {==}

def split_step(+c: Char, +t: String, +x: Bool, ih: {Spec.dots(t) == after(J.split(t)) : Nat}) -> {Spec.count_dot(x, Spec.dots(t)) == after(J.split_pick(c, t, J.split(t), x)) : Nat}:
  match x:
    case True{}:
      {==}
    case False{}:
      Equal.trans(Nat, Spec.dots(t), after(J.split(t)), after(J.prepend(c, J.split(t))), ih, Equal.sym(Nat, after(J.prepend(c, J.split(t))), after(J.split(t)), after_prepend(c, J.split(t))))

# Splitting at the first '.' leaves one separator fewer.
def dots_split(+s: String) -> {Spec.dots(s) == after(J.split(s)) : Nat}:
  match s:
    case SNil{}:
      {==}
    case SCon{+c, +t}:
      split_step(c, t, Char.is_eq(c, '.'), dots_split(t))

def two(+token: String, +rest: String, +c: String, d: {Spec.dots(token) == 1n+Spec.dots(rest) : Nat}, d2: {Spec.dots(rest) == 1n+Spec.dots(c) : Nat}, z: {Spec.dots(c) == 0n : Nat}) -> {Spec.dots(token) == 2n : Nat}:
  %z : {Spec.dots(token) == 1n+(1n+_) : Nat}
  %d2 : {Spec.dots(token) == 1n+_ : Nat}
  d

def third_malformed(+secret: List<&2, U32>, +token: String, +a: String, +b: String, +rest: String, +c: String, +y: Bool, ey: {J.dotfree(c) == y : Bool}, d: {Spec.dots(token) == 1n+Spec.dots(rest) : Nat}, d2: {Spec.dots(rest) == 1n+Spec.dots(c) : Nat}, wrong: {Spec.dots(token) != 2n : Nat}) -> {J.third(secret, a, b, c, y) == Fail{J.Malformed{}} : Result<&2, &2, J.Error, J.Parts>}:
  match y:
    case False{}:
      {==}
    case True{}:
      JwtProof.absurd({J.third(secret, a, b, c, True{}) == Fail{J.Malformed{}} : Result<&2, &2, J.Error, J.Parts>}, wrong(two(token, rest, c, d, d2, dots_of(c, ey))))

def second_malformed(+secret: List<&2, U32>, +token: String, +a: String, +rest: String, +m: Maybe<&2, J.Cut>, d: {Spec.dots(token) == 1n+Spec.dots(rest) : Nat}, d2: {Spec.dots(rest) == after(m) : Nat}, wrong: {Spec.dots(token) != 2n : Nat}) -> {J.second(secret, a, m) == Fail{J.Malformed{}} : Result<&2, &2, J.Error, J.Parts>}:
  match m:
    case None{}:
      {==}
    case Some{J.Cut{+b, +c}}:
      third_malformed(secret, token, a, b, rest, c, J.dotfree(c), {==}, d, d2, wrong)

def first_malformed(+secret: List<&2, U32>, +token: String, +m: Maybe<&2, J.Cut>, d: {Spec.dots(token) == after(m) : Nat}, wrong: {Spec.dots(token) != 2n : Nat}) -> {J.first(secret, m) == Fail{J.Malformed{}} : Result<&2, &2, J.Error, J.Parts>}:
  match m:
    case None{}:
      {==}
    case Some{J.Cut{+a, +rest}}:
      second_malformed(secret, token, a, rest, J.split(rest), d, dots_split(rest), wrong)

# Every token whose '.' count is not two is Malformed.
def malformed(+secret: List<&2, U32>, +token: String, wrong: {Spec.dots(token) != 2n : Nat}) -> {J.open(secret, token) == Fail{J.Malformed{}} : Result<&2, &2, J.Error, J.Parts>}:
  first_malformed(secret, token, J.split(token), dots_split(token), wrong)

# ---- String equality ----

def string_order_eq(+o: Cmp, +a: String, +b: String) -> {Cmp.is_eq(String.order.go(a, b, o)) == (Cmp.is_eq(o) && String.eq(a, b)) : Bool}:
  match o:
    case LT{}:
      match a b:
        case SNil{} SNil{}: {==}
        case SNil{} SCon{Chr{c}, t}: {==}
        case SCon{Chr{c}, t} SNil{}: {==}
        case SCon{Chr{c}, t} SCon{Chr{d}, u}: {==}
    case EQ{}: {==}
    case GT{}:
      match a b:
        case SNil{} SNil{}: {==}
        case SNil{} SCon{Chr{c}, t}: {==}
        case SCon{Chr{c}, t} SNil{}: {==}
        case SCon{Chr{c}, t} SCon{Chr{d}, u}: {==}

def string_sound(+a: String, +b: String, e: {String.eq(a, b) == True{} : Bool}) -> {a == b : String}:
  match a b:
    case SNil{} SNil{}:
      {==}
    case SCon{Chr{+x}, +at} SCon{Chr{+y}, +bt}:
      +both = Equal.trans(Bool, U32.is_eq(x, y) && String.eq(at, bt), String.eq(SCon{Chr{x}, at}, SCon{Chr{y}, bt}), True{}, Equal.sym(Bool, String.eq(SCon{Chr{x}, at}, SCon{Chr{y}, bt}), U32.is_eq(x, y) && String.eq(at, bt), string_order_eq(U32.cmp(x, y), at, bt)), e)
      %JwtProof.u32_sound(x, y, JwtProof.and_left(U32.is_eq(x, y), String.eq(at, bt), both)) : {SCon{Chr{x}, at} == SCon{Chr{_}, bt} : String}
      %string_sound(at, bt, JwtProof.and_right(U32.is_eq(x, y), String.eq(at, bt), both)) : {SCon{Chr{x}, at} == SCon{Chr{x}, _} : String}
      {==}
    case SCon{Chr{+x}, +at} SNil{}:
      JwtProof.absurd({SCon{Chr{x}, at} == SNil{} : String}, JwtProof.false_true(e))
    case SNil{} SCon{Chr{+y}, +bt}:
      JwtProof.absurd({SNil{} == SCon{Chr{y}, bt} : String}, JwtProof.false_true(e))

# ---- The header's alg ----

def lookup_found(+fields: List<&2, Json.Field>, +key: String, +v: Json.Json) -> {Json.lookup_go(fields, key, Some{v}) == Some{v} : Maybe<&2, Json.Json>}:
  match fields:
    case Nil{}:
      {==}
    case Json.Field{k, w} <> t:
      {==}

def alg_value(+v: Json.Json) -> {J.alg_ok(Some{v}) == Spec.hs256(v) : Bool}:
  match v:
    case Json.JNull{}: {==}
    case Json.JBool{b}: {==}
    case Json.JNumber{n}: {==}
    case Json.JString{s}: {==}
    case Json.JArray{xs}: {==}
    case Json.JObject{fs}: {==}

def none_step(+k: String, +v: Json.Json, +t: List<&2, Json.Field>, +x: Bool, ex: {String.eq(k, "alg") == x : Bool}, n: {x || J.key_in("alg", t) == False{} : Bool}, ih: {J.key_in("alg", t) == False{} : Bool} -> {Spec.alg_members(t) == 0n : Nat} & {Spec.hs256_members(t) == 0n : Nat}) -> {Spec.alg_members(Json.Field{k, v} <> t) == 0n : Nat} & {Spec.hs256_members(Json.Field{k, v} <> t) == 0n : Nat}:
  match x:
    case True{}:
      JwtProof.absurd({Spec.alg_members(Json.Field{k, v} <> t) == 0n : Nat} & {Spec.hs256_members(Json.Field{k, v} <> t) == 0n : Nat}, JwtProof.false_true(Equal.sym(Bool, True{}, False{}, n)))
    case False{}:
      %Equal.sym(Bool, String.eq(k, "alg"), False{}, ex) : {Spec.count_if(_, Spec.alg_members(t)) == 0n : Nat} & {Spec.count_if(_ && Spec.hs256(v), Spec.hs256_members(t)) == 0n : Nat}
      ih(n)

# Without an "alg" member, both counts are zero.
def none_named(+t: List<&2, Json.Field>, n: {J.key_in("alg", t) == False{} : Bool}) -> {Spec.alg_members(t) == 0n : Nat} & {Spec.hs256_members(t) == 0n : Nat}:
  match t:
    case Nil{}:
      ({==}, {==})
    case Json.Field{+k, +v} <> +u:
      none_step(k, v, u, String.eq(k, "alg"), {==}, n, w => none_named(u, w))

def not_true(+b: Bool, e: {Bool.not(b) == True{} : Bool}) -> {b == False{} : Bool}:
  match b:
    case False{}:
      {==}
    case True{}:
      JwtProof.absurd({True{} == False{} : Bool}, JwtProof.false_true(e))

def alg_absent(+k: String, +t: List<&2, Json.Field>, same: {k == "alg" : String}, nk: {J.key_in(k, t) == False{} : Bool}) -> {J.key_in("alg", t) == False{} : Bool}:
  %same : {J.key_in(_, t) == False{} : Bool}
  nk

def alg_counts(+v: Json.Json, +t: List<&2, Json.Field>, okv: {Spec.hs256(v) == True{} : Bool}, zs: {Spec.alg_members(t) == 0n : Nat} & {Spec.hs256_members(t) == 0n : Nat}) -> {Nat.is_eq(Spec.count_if(True{}, Spec.alg_members(t)), 1n) && Nat.is_eq(Spec.count_if(True{} && Spec.hs256(v), Spec.hs256_members(t)), 1n) == True{} : Bool}:
  match zs:
    case (z1, z2):
      %Equal.sym(Nat, Spec.alg_members(t), 0n, z1) : {Nat.is_eq(Spec.count_if(True{}, _), 1n) && Nat.is_eq(Spec.count_if(True{} && Spec.hs256(v), Spec.hs256_members(t)), 1n) == True{} : Bool}
      %Equal.sym(Nat, Spec.hs256_members(t), 0n, z2) : {Nat.is_eq(Spec.count_if(True{}, 0n), 1n) && Nat.is_eq(Spec.count_if(True{} && Spec.hs256(v), _), 1n) == True{} : Bool}
      %Equal.sym(Bool, Spec.hs256(v), True{}, okv) : {Nat.is_eq(Spec.count_if(True{}, 0n), 1n) && Nat.is_eq(Spec.count_if(True{} && _, 0n), 1n) == True{} : Bool}
      {==}

def alg_found(+k: String, +v: Json.Json, +t: List<&2, Json.Field>, ex: {String.eq(k, "alg") == True{} : Bool}, u: {Bool.not(J.key_in(k, t)) && J.unique(t) == True{} : Bool}, ok: {J.alg_ok(Json.lookup_go(t, "alg", Some{v})) == True{} : Bool}) -> {Nat.is_eq(Spec.count_if(True{}, Spec.alg_members(t)), 1n) && Nat.is_eq(Spec.count_if(True{} && Spec.hs256(v), Spec.hs256_members(t)), 1n) == True{} : Bool}:
  +same = string_sound(k, "alg", ex)
  +okv = Equal.trans(Bool, Spec.hs256(v), J.alg_ok(Some{v}), True{}, Equal.sym(Bool, J.alg_ok(Some{v}), Spec.hs256(v), alg_value(v)), Equal.trans(Bool, J.alg_ok(Some{v}), J.alg_ok(Json.lookup_go(t, "alg", Some{v})), True{}, Equal.cong(Maybe<&2, Json.Json>, Bool, m => J.alg_ok(m), Some{v}, Json.lookup_go(t, "alg", Some{v}), Equal.sym(Maybe<&2, Json.Json>, Json.lookup_go(t, "alg", Some{v}), Some{v}, lookup_found(t, "alg", v))), ok))
  +nk = not_true(J.key_in(k, t), JwtProof.and_left(Bool.not(J.key_in(k, t)), J.unique(t), u))
  +na = alg_absent(k, t, same, nk)
  alg_counts(v, t, okv, none_named(t, na))

def alg_step(+k: String, +v: Json.Json, +t: List<&2, Json.Field>, +x: Bool, ex: {String.eq(k, "alg") == x : Bool}, u: {Bool.not(J.key_in(k, t)) && J.unique(t) == True{} : Bool}, ok: {J.alg_ok(Json.lookup_go(t, "alg", Json.select(v, None{}, x))) == True{} : Bool}, ih: {J.unique(t) == True{} : Bool} -> {J.alg_ok(Json.lookup(t, "alg")) == True{} : Bool} -> {Spec.alg_accepted(t) == True{} : Bool}) -> {Nat.is_eq(Spec.count_if(x, Spec.alg_members(t)), 1n) && Nat.is_eq(Spec.count_if(x && Spec.hs256(v), Spec.hs256_members(t)), 1n) == True{} : Bool}:
  match x:
    case True{}:
      alg_found(k, v, t, ex, u, ok)
    case False{}:
      ih(JwtProof.and_right(Bool.not(J.key_in(k, t)), J.unique(t), u), ok)

# A header without repeated names whose "alg" lookup is "HS256" has exactly
# one "alg" member, and it is "HS256".
def alg_accepted(+fields: List<&2, Json.Field>, u: {J.unique(fields) == True{} : Bool}, ok: {J.alg_ok(Json.lookup(fields, "alg")) == True{} : Bool}) -> {Spec.alg_accepted(fields) == True{} : Bool}:
  match fields:
    case Nil{}:
      JwtProof.absurd({Spec.alg_accepted([]) == True{} : Bool}, JwtProof.false_true(ok))
    case Json.Field{+k, +v} <> +t:
      alg_step(k, v, t, String.eq(k, "alg"), {==}, u, ok, w => o => alg_accepted(t, w, o))

def alg_checked(+p: List<&2, U32>, +now: Nat, +leeway: Nat, +fields: List<&2, Json.Field>, bad: {Spec.alg_accepted(fields) == False{} : Bool}, u: {J.unique(fields) == True{} : Bool}, +al: Bool, ea: {J.alg_ok(Json.lookup(fields, "alg")) == al : Bool}) -> {Spec.failed(J.header_checked(p, now, leeway, al, J.absent(Json.lookup(fields, "crit")))) == True{} : Bool}:
  match al:
    case False{}:
      {==}
    case True{}:
      JwtProof.absurd({Spec.failed(J.header_checked(p, now, leeway, True{}, J.absent(Json.lookup(fields, "crit")))) == True{} : Bool}, JwtProof.false_true(Equal.trans(Bool, False{}, Spec.alg_accepted(fields), True{}, Equal.sym(Bool, Spec.alg_accepted(fields), False{}, bad), alg_accepted(fields, u, ea))))

def fields_checked(+p: List<&2, U32>, +now: Nat, +leeway: Nat, +fields: List<&2, Json.Field>, bad: {Spec.alg_accepted(fields) == False{} : Bool}, +d: Bool, ed: {J.unique(fields) == d : Bool}) -> {Spec.failed(J.header_fields(fields, p, now, leeway, d)) == True{} : Bool}:
  match d:
    case False{}:
      {==}
    case True{}:
      alg_checked(p, now, leeway, fields, bad, ed, J.alg_ok(Json.lookup(fields, "alg")), {==})

def payload_checked(+h: List<&2, U32>, +now: Nat, +leeway: Nat, +fields: List<&2, Json.Field>, ph: {Json.parse(h) == Done{Json.JObject{fields}} : Result<&2, &2, Json.Error, Json.Json>}, bad: {Spec.alg_accepted(fields) == False{} : Bool}, +m: Maybe<&2, List<&2, U32>>) -> {Spec.failed(J.opened(J.decoded(Some{h}, m), now, leeway)) == True{} : Bool}:
  match m:
    case None{}:
      {==}
    case Some{+p}:
      %Equal.sym(Result<&2, &2, Json.Error, Json.Json>, Json.parse(h), Done{Json.JObject{fields}}, ph) : {Spec.failed(J.header_parsed(_, p, now, leeway)) == True{} : Bool}
      fields_checked(p, now, leeway, fields, bad, J.unique(fields), {==})

def signature_checked(+a: String, +b: String, +now: Nat, +leeway: Nat, +h: List<&2, U32>, +fields: List<&2, Json.Field>, dh: {J.decode(a) == Some{h} : Maybe<&2, List<&2, U32>>}, ph: {Json.parse(h) == Done{Json.JObject{fields}} : Result<&2, &2, Json.Error, Json.Json>}, bad: {Spec.alg_accepted(fields) == False{} : Bool}, +x: Bool) -> {Spec.failed(J.opened(J.signed(a, b, x), now, leeway)) == True{} : Bool}:
  match x:
    case False{}:
      {==}
    case True{}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, J.decode(a), Some{h}, dh) : {Spec.failed(J.opened(J.decoded(_, J.decode(b)), now, leeway)) == True{} : Bool}
      payload_checked(h, now, leeway, fields, ph, bad, J.decode(b))

# Whatever the signature and payload, a token whose header decodes to an
# object that does not name HS256 exactly once fails to verify.
def bad_alg(+secret: List<&2, U32>, +a: String, +b: String, +c: String, +now: Nat, +leeway: Nat, +h: List<&2, U32>, +fields: List<&2, Json.Field>, za: {Spec.dots(a) == 0n : Nat}, zb: {Spec.dots(b) == 0n : Nat}, zc: {Spec.dots(c) == 0n : Nat}, dh: {J.decode(a) == Some{h} : Maybe<&2, List<&2, U32>>}, ph: {Json.parse(h) == Done{Json.JObject{fields}} : Result<&2, &2, Json.Error, Json.Json>}, bad: {Spec.alg_accepted(fields) == False{} : Bool}) -> {Spec.failed(J.verify(secret, J.token(a, b, c), now, leeway)) == True{} : Bool}:
  +s = J.signature(secret, J.signing_input(a, b))
  +rest = b ++ ("." ++ c)
  %Equal.sym(Maybe<&2, J.Cut>, J.split(a ++ ("." ++ rest)), Some{J.Cut{a, rest}}, JwtProof.split_free(a, rest, dotfree_of(a, za))) : {Spec.failed(J.opened(J.first(secret, _), now, leeway)) == True{} : Bool}
  %Equal.sym(Maybe<&2, J.Cut>, J.split(rest), Some{J.Cut{b, c}}, JwtProof.split_free(b, c, dotfree_of(b, zb))) : {Spec.failed(J.opened(J.second(secret, a, _), now, leeway)) == True{} : Bool}
  %Equal.sym(Bool, J.dotfree(c), True{}, dotfree_of(c, zc)) : {Spec.failed(J.opened(J.third(secret, a, b, c, _), now, leeway)) == True{} : Bool}
  signature_checked(a, b, now, leeway, h, fields, dh, ph, bad, Compare.ct_equal(J.codes(c), J.codes(s)))

# ---- Exactly BadAlgorithm ----

def named_key_in(+key: String, +fields: List<&2, Json.Field>) -> {Spec.named(key, fields) == J.key_in(key, fields) : Bool}:
  match fields:
    case Nil{}:
      {==}
    case Json.Field{+k, v} <> +t:
      %Equal.sym(Bool, Spec.named(key, t), J.key_in(key, t), named_key_in(key, t)) : {String.eq(k, key) || _ == String.eq(k, key) || J.key_in(key, t) : Bool}
      {==}

def distinct_unique(+fields: List<&2, Json.Field>) -> {Spec.distinct(fields) == J.unique(fields) : Bool}:
  match fields:
    case Nil{}:
      {==}
    case Json.Field{+k, v} <> +t:
      %Equal.sym(Bool, Spec.named(k, t), J.key_in(k, t), named_key_in(k, t)) : {Bool.not(_) && Spec.distinct(t) == Bool.not(J.key_in(k, t)) && J.unique(t) : Bool}
      %Equal.sym(Bool, Spec.distinct(t), J.unique(t), distinct_unique(t)) : {Bool.not(J.key_in(k, t)) && _ == Bool.not(J.key_in(k, t)) && J.unique(t) : Bool}
      {==}

def alg_exact(+p: List<&2, U32>, +now: Nat, +leeway: Nat, +fields: List<&2, Json.Field>, bad: {Spec.alg_accepted(fields) == False{} : Bool}, u: {J.unique(fields) == True{} : Bool}, +al: Bool, ea: {J.alg_ok(Json.lookup(fields, "alg")) == al : Bool}) -> {J.header_checked(p, now, leeway, al, J.absent(Json.lookup(fields, "crit"))) == Fail{J.BadAlgorithm{}} : Result<&2, &2, J.Error, Json.Json>}:
  match al:
    case False{}:
      {==}
    case True{}:
      JwtProof.absurd({J.header_checked(p, now, leeway, True{}, J.absent(Json.lookup(fields, "crit"))) == Fail{J.BadAlgorithm{}} : Result<&2, &2, J.Error, Json.Json>}, JwtProof.false_true(Equal.trans(Bool, False{}, Spec.alg_accepted(fields), True{}, Equal.sym(Bool, Spec.alg_accepted(fields), False{}, bad), alg_accepted(fields, u, ea))))

# With canonical segments, a correct signature and distinct member names, a
# header that does not name HS256 exactly once fails with BadAlgorithm.
def exactly_bad_alg(+secret: List<&2, U32>, +a: String, +b: String, +now: Nat, +leeway: Nat, +h: List<&2, U32>, +p: List<&2, U32>, +fields: List<&2, Json.Field>, za: {Spec.dots(a) == 0n : Nat}, zb: {Spec.dots(b) == 0n : Nat}, dh: {J.decode(a) == Some{h} : Maybe<&2, List<&2, U32>>}, dp: {J.decode(b) == Some{p} : Maybe<&2, List<&2, U32>>}, ph: {Json.parse(h) == Done{Json.JObject{fields}} : Result<&2, &2, Json.Error, Json.Json>}, dist: {Spec.distinct(fields) == True{} : Bool}, bad: {Spec.alg_accepted(fields) == False{} : Bool}) -> {J.verify(secret, J.token(a, b, J.signature(secret, J.signing_input(a, b))), now, leeway) == Fail{J.BadAlgorithm{}} : Result<&2, &2, J.Error, Json.Json>}:
  +s = J.signature(secret, J.signing_input(a, b))
  +rest = b ++ ("." ++ s)
  +u = Equal.trans(Bool, J.unique(fields), Spec.distinct(fields), True{}, Equal.sym(Bool, Spec.distinct(fields), J.unique(fields), distinct_unique(fields)), dist)
  %Equal.sym(Maybe<&2, J.Cut>, J.split(a ++ ("." ++ rest)), Some{J.Cut{a, rest}}, JwtProof.split_free(a, rest, dotfree_of(a, za))) : {J.opened(J.first(secret, _), now, leeway) == Fail{J.BadAlgorithm{}} : Result<&2, &2, J.Error, Json.Json>}
  %Equal.sym(Maybe<&2, J.Cut>, J.split(rest), Some{J.Cut{b, s}}, JwtProof.split_free(b, s, dotfree_of(b, zb))) : {J.opened(J.second(secret, a, _), now, leeway) == Fail{J.BadAlgorithm{}} : Result<&2, &2, J.Error, Json.Json>}
  %Equal.sym(Bool, J.dotfree(s), True{}, JwtProof.encode_free(HMAC.sha256(secret, U.encode(J.signing_input(a, b))))) : {J.opened(J.third(secret, a, b, s, _), now, leeway) == Fail{J.BadAlgorithm{}} : Result<&2, &2, J.Error, Json.Json>}
  %Equal.sym(Bool, Compare.ct_equal(J.codes(s), J.codes(s)), True{}, JwtProof.codes_self(s)) : {J.opened(J.signed(a, b, _), now, leeway) == Fail{J.BadAlgorithm{}} : Result<&2, &2, J.Error, Json.Json>}
  %Equal.sym(Maybe<&2, List<&2, U32>>, J.decode(a), Some{h}, dh) : {J.opened(J.decoded(_, J.decode(b)), now, leeway) == Fail{J.BadAlgorithm{}} : Result<&2, &2, J.Error, Json.Json>}
  %Equal.sym(Maybe<&2, List<&2, U32>>, J.decode(b), Some{p}, dp) : {J.opened(J.decoded(Some{h}, _), now, leeway) == Fail{J.BadAlgorithm{}} : Result<&2, &2, J.Error, Json.Json>}
  %Equal.sym(Result<&2, &2, Json.Error, Json.Json>, Json.parse(h), Done{Json.JObject{fields}}, ph) : {J.header_parsed(_, p, now, leeway) == Fail{J.BadAlgorithm{}} : Result<&2, &2, J.Error, Json.Json>}
  %Equal.sym(Bool, J.unique(fields), True{}, u) : {J.header_fields(fields, p, now, leeway, _) == Fail{J.BadAlgorithm{}} : Result<&2, &2, J.Error, Json.Json>}
  alg_exact(p, now, leeway, fields, bad, u, J.alg_ok(Json.lookup(fields, "alg")), {==})
