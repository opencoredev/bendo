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

# ---- Distinct names ----

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

# ---- Member names ----

def is_some(m: Maybe<&2, J.Error>) -> Type:
  match m:
    case None{}:
      Empty
    case Some{e}:
      Unit

def some_none(+x: J.Error, e: {Some{x} == None{} : Maybe<&2, J.Error>}) -> Empty:
  %e : is_some(_)
  Unit{}

def repeated_none(+fields: List<&2, Json.Field>, +d: Bool, ed: {J.unique(fields) == d : Bool}, e: {J.repeated(d) == None{} : Maybe<&2, J.Error>}) -> {J.unique(fields) == True{} : Bool}:
  match d:
    case True{}:
      ed
    case False{}:
      JwtProof.absurd({J.unique(fields) == True{} : Bool}, some_none(J.DuplicateMember{}, e))

def bounded_none(+fields: List<&2, Json.Field>, +small: Bool, e: {J.bounded(fields, small) == None{} : Maybe<&2, J.Error>}) -> {J.unique(fields) == True{} : Bool}:
  match small:
    case True{}:
      repeated_none(fields, J.unique(fields), {==}, e)
    case False{}:
      JwtProof.absurd({J.unique(fields) == True{} : Bool}, some_none(J.TooManyMembers{}, e))

# The member check passes only when unique holds: the size limit adds
# failures, never successes.
def members_unique(+fields: List<&2, Json.Field>, e: {J.members(fields) == None{} : Maybe<&2, J.Error>}) -> {J.unique(fields) == True{} : Bool}:
  bounded_none(fields, J.at_most(fields, 256n), e)

def members_distinct(+fields: List<&2, Json.Field>, e: {J.members(fields) == None{} : Maybe<&2, J.Error>}) -> {Spec.distinct(fields) == True{} : Bool}:
  Equal.trans(Bool, Spec.distinct(fields), J.unique(fields), True{}, distinct_unique(fields), members_unique(fields, e))

def repeated_absurd(+fields: List<&2, Json.Field>, dup: {Spec.distinct(fields) == False{} : Bool}, e: {J.members(fields) == None{} : Maybe<&2, J.Error>}) -> Empty:
  JwtProof.false_true(Equal.trans(Bool, False{}, Spec.distinct(fields), True{}, Equal.sym(Bool, Spec.distinct(fields), False{}, dup), members_distinct(fields, e)))

def alg_absurd(+fields: List<&2, Json.Field>, bad: {Spec.alg_accepted(fields) == False{} : Bool}, e: {J.members(fields) == None{} : Maybe<&2, J.Error>}, ok: {J.alg_ok(Json.lookup(fields, "alg")) == True{} : Bool}) -> Empty:
  JwtProof.false_true(Equal.trans(Bool, False{}, Spec.alg_accepted(fields), True{}, Equal.sym(Bool, Spec.alg_accepted(fields), False{}, bad), alg_accepted(fields, members_unique(fields, e), ok)))

# ---- The header path ----

def members_fails(+fields: List<&2, Json.Field>, +p: List<&2, U32>, +now: Nat, +leeway: Nat, +m: Maybe<&2, J.Error>, em: {J.members(fields) == m : Maybe<&2, J.Error>}, rest: {J.members(fields) == None{} : Maybe<&2, J.Error>} -> {Spec.failed(J.payload_claims(Json.parse(p), now, leeway)) == True{} : Bool}) -> {Spec.failed(J.header_members(p, now, leeway, m)) == True{} : Bool}:
  match m:
    case None{}:
      rest(em)
    case Some{x}:
      {==}

def checked_fails(+fields: List<&2, Json.Field>, +p: List<&2, U32>, +now: Nat, +leeway: Nat, +al: Bool, ea: {J.alg_ok(Json.lookup(fields, "alg")) == al : Bool}, +cr: Bool, rest: {J.members(fields) == None{} : Maybe<&2, J.Error>} -> {J.alg_ok(Json.lookup(fields, "alg")) == True{} : Bool} -> {Spec.failed(J.payload_claims(Json.parse(p), now, leeway)) == True{} : Bool}) -> {Spec.failed(J.header_checked(fields, p, now, leeway, al, cr)) == True{} : Bool}:
  match al:
    case False{}:
      {==}
    case True{}:
      match cr:
        case False{}:
          {==}
        case True{}:
          members_fails(fields, p, now, leeway, J.members(fields), {==}, m => rest(m, ea))

# An object header fails unless its alg reads HS256, it has no crit, its
# member check passes and the payload then verifies.
def fields_fails(+fields: List<&2, Json.Field>, +p: List<&2, U32>, +now: Nat, +leeway: Nat, rest: {J.members(fields) == None{} : Maybe<&2, J.Error>} -> {J.alg_ok(Json.lookup(fields, "alg")) == True{} : Bool} -> {Spec.failed(J.payload_claims(Json.parse(p), now, leeway)) == True{} : Bool}) -> {Spec.failed(J.header_fields(fields, p, now, leeway)) == True{} : Bool}:
  checked_fails(fields, p, now, leeway, J.alg_ok(Json.lookup(fields, "alg")), {==}, J.absent(Json.lookup(fields, "crit")), rest)

def object_header(+h: List<&2, U32>, +p: List<&2, U32>, +now: Nat, +leeway: Nat, +fields: List<&2, Json.Field>, ph: {Json.parse(h) == Done{Json.JObject{fields}} : Result<&2, &2, Json.Error, Json.Json>}, rest: {J.members(fields) == None{} : Maybe<&2, J.Error>} -> {J.alg_ok(Json.lookup(fields, "alg")) == True{} : Bool} -> {Spec.failed(J.payload_claims(Json.parse(p), now, leeway)) == True{} : Bool}) -> {Spec.failed(J.header_parsed(Json.parse(h), p, now, leeway)) == True{} : Bool}:
  %Equal.sym(Result<&2, &2, Json.Error, Json.Json>, Json.parse(h), Done{Json.JObject{fields}}, ph) : {Spec.failed(J.header_parsed(_, p, now, leeway)) == True{} : Bool}
  fields_fails(fields, p, now, leeway, rest)

def header_json(+r: Result<&2, &2, Json.Error, Json.Json>, +p: List<&2, U32>, +now: Nat, +leeway: Nat, bad: {Spec.json_object(r) == False{} : Bool}) -> {Spec.failed(J.header_parsed(r, p, now, leeway)) == True{} : Bool}:
  match r:
    case Done{Json.JObject{fields}}:
      JwtProof.absurd({Spec.failed(J.header_parsed(Done{Json.JObject{fields}}, p, now, leeway)) == True{} : Bool}, JwtProof.false_true(Equal.sym(Bool, True{}, False{}, bad)))
    case Done{Json.JNull{}}:
      {==}
    case Done{Json.JBool{x}}:
      {==}
    case Done{Json.JNumber{x}}:
      {==}
    case Done{Json.JString{x}}:
      {==}
    case Done{Json.JArray{x}}:
      {==}
    case Fail{e}:
      {==}

def claims_json(+r: Result<&2, &2, Json.Error, Json.Json>, +now: Nat, +leeway: Nat, bad: {Spec.json_object(r) == False{} : Bool}) -> {Spec.failed(J.payload_claims(r, now, leeway)) == True{} : Bool}:
  match r:
    case Done{Json.JObject{fields}}:
      JwtProof.absurd({Spec.failed(J.payload_claims(Done{Json.JObject{fields}}, now, leeway)) == True{} : Bool}, JwtProof.false_true(Equal.sym(Bool, True{}, False{}, bad)))
    case Done{Json.JNull{}}:
      {==}
    case Done{Json.JBool{x}}:
      {==}
    case Done{Json.JNumber{x}}:
      {==}
    case Done{Json.JString{x}}:
      {==}
    case Done{Json.JArray{x}}:
      {==}
    case Fail{e}:
      {==}

def claim_members(+fields: List<&2, Json.Field>, +now: Nat, +leeway: Nat, +m: Maybe<&2, J.Error>, em: {J.members(fields) == m : Maybe<&2, J.Error>}, no: {J.members(fields) == None{} : Maybe<&2, J.Error>} -> Empty) -> {Spec.failed(J.claim_fields(fields, now, leeway, m)) == True{} : Bool}:
  match m:
    case None{}:
      JwtProof.absurd({Spec.failed(J.claim_fields(fields, now, leeway, None{})) == True{} : Bool}, no(em))
    case Some{x}:
      {==}

def claims_distinct(+p: List<&2, U32>, +now: Nat, +leeway: Nat, +fields: List<&2, Json.Field>, pp: {Json.parse(p) == Done{Json.JObject{fields}} : Result<&2, &2, Json.Error, Json.Json>}, dup: {Spec.distinct(fields) == False{} : Bool}) -> {Spec.failed(J.payload_claims(Json.parse(p), now, leeway)) == True{} : Bool}:
  %Equal.sym(Result<&2, &2, Json.Error, Json.Json>, Json.parse(p), Done{Json.JObject{fields}}, pp) : {Spec.failed(J.payload_claims(_, now, leeway)) == True{} : Bool}
  claim_members(fields, now, leeway, J.members(fields), {==}, m => repeated_absurd(fields, dup, m))

# Whatever the header, a payload that fails rest makes verify fail.
def payload_parsed(+r: Result<&2, &2, Json.Error, Json.Json>, +p: List<&2, U32>, +now: Nat, +leeway: Nat, rest: {Spec.failed(J.payload_claims(Json.parse(p), now, leeway)) == True{} : Bool}) -> {Spec.failed(J.header_parsed(r, p, now, leeway)) == True{} : Bool}:
  match r:
    case Done{Json.JObject{+fields}}:
      fields_fails(fields, p, now, leeway, m => o => rest)
    case Done{Json.JNull{}}:
      {==}
    case Done{Json.JBool{x}}:
      {==}
    case Done{Json.JNumber{x}}:
      {==}
    case Done{Json.JString{x}}:
      {==}
    case Done{Json.JArray{x}}:
      {==}
    case Fail{e}:
      {==}

def payload_side(+ma: Maybe<&2, List<&2, U32>>, +p: List<&2, U32>, +now: Nat, +leeway: Nat, rest: {Spec.failed(J.payload_claims(Json.parse(p), now, leeway)) == True{} : Bool}) -> {Spec.failed(J.opened(J.decoded(ma, Some{p}), now, leeway)) == True{} : Bool}:
  match ma:
    case None{}:
      {==}
    case Some{+h}:
      payload_parsed(Json.parse(h), p, now, leeway, rest)

def payload_fails(+a: String, +b: String, +now: Nat, +leeway: Nat, +p: List<&2, U32>, dp: {J.decode(b) == Some{p} : Maybe<&2, List<&2, U32>>}, rest: {Spec.failed(J.payload_claims(Json.parse(p), now, leeway)) == True{} : Bool}) -> {Spec.failed(J.opened(J.decoded(J.decode(a), J.decode(b)), now, leeway)) == True{} : Bool}:
  %Equal.sym(Maybe<&2, List<&2, U32>>, J.decode(b), Some{p}, dp) : {Spec.failed(J.opened(J.decoded(J.decode(a), _), now, leeway)) == True{} : Bool}
  payload_side(J.decode(a), p, now, leeway, rest)

def header_side(+h: List<&2, U32>, +now: Nat, +leeway: Nat, +mb: Maybe<&2, List<&2, U32>>, hr: @p:List<&2, U32> -> {Spec.failed(J.header_parsed(Json.parse(h), p, now, leeway)) == True{} : Bool}) -> {Spec.failed(J.opened(J.decoded(Some{h}, mb), now, leeway)) == True{} : Bool}:
  match mb:
    case None{}:
      {==}
    case Some{+p}:
      hr(p)

# Whatever the payload, a header that fails hr makes verify fail.
def header_fails(+a: String, +b: String, +now: Nat, +leeway: Nat, +h: List<&2, U32>, dh: {J.decode(a) == Some{h} : Maybe<&2, List<&2, U32>>}, hr: @p:List<&2, U32> -> {Spec.failed(J.header_parsed(Json.parse(h), p, now, leeway)) == True{} : Bool}) -> {Spec.failed(J.opened(J.decoded(J.decode(a), J.decode(b)), now, leeway)) == True{} : Bool}:
  %Equal.sym(Maybe<&2, List<&2, U32>>, J.decode(a), Some{h}, dh) : {Spec.failed(J.opened(J.decoded(_, J.decode(b)), now, leeway)) == True{} : Bool}
  header_side(h, now, leeway, J.decode(b), hr)

def signature_fails(+a: String, +b: String, +now: Nat, +leeway: Nat, +x: Bool, ok: {Spec.failed(J.opened(J.decoded(J.decode(a), J.decode(b)), now, leeway)) == True{} : Bool}) -> {Spec.failed(J.opened(J.signed(a, b, x), now, leeway)) == True{} : Bool}:
  match x:
    case False{}:
      {==}
    case True{}:
      ok

# For any signature segment: a wrong one fails with BadSignature, and a right
# one reaches the decoded header and payload, where ok applies.
def token_fails(+secret: List<&2, U32>, +a: String, +b: String, +c: String, +now: Nat, +leeway: Nat, za: {Spec.dots(a) == 0n : Nat}, zb: {Spec.dots(b) == 0n : Nat}, zc: {Spec.dots(c) == 0n : Nat}, ok: {Spec.failed(J.opened(J.decoded(J.decode(a), J.decode(b)), now, leeway)) == True{} : Bool}) -> {Spec.failed(J.verify(secret, J.token(a, b, c), now, leeway)) == True{} : Bool}:
  +s = J.signature(secret, J.signing_input(a, b))
  +rest = b ++ ("." ++ c)
  %Equal.sym(Maybe<&2, J.Cut>, J.split(a ++ ("." ++ rest)), Some{J.Cut{a, rest}}, JwtProof.split_free(a, rest, dotfree_of(a, za))) : {Spec.failed(J.opened(J.first(secret, _), now, leeway)) == True{} : Bool}
  %Equal.sym(Maybe<&2, J.Cut>, J.split(rest), Some{J.Cut{b, c}}, JwtProof.split_free(b, c, dotfree_of(b, zb))) : {Spec.failed(J.opened(J.second(secret, a, _), now, leeway)) == True{} : Bool}
  %Equal.sym(Bool, J.dotfree(c), True{}, dotfree_of(c, zc)) : {Spec.failed(J.opened(J.third(secret, a, b, c, _), now, leeway)) == True{} : Bool}
  signature_fails(a, b, now, leeway, Compare.ct_equal(J.codes(c), J.codes(s)), ok)

# ---- Laws: verify fails ----

# Whatever the signature and payload, a token whose header decodes to an
# object that does not name HS256 exactly once fails to verify.
def bad_alg(+secret: List<&2, U32>, +a: String, +b: String, +c: String, +now: Nat, +leeway: Nat, +h: List<&2, U32>, +fields: List<&2, Json.Field>, za: {Spec.dots(a) == 0n : Nat}, zb: {Spec.dots(b) == 0n : Nat}, zc: {Spec.dots(c) == 0n : Nat}, dh: {J.decode(a) == Some{h} : Maybe<&2, List<&2, U32>>}, ph: {Json.parse(h) == Done{Json.JObject{fields}} : Result<&2, &2, Json.Error, Json.Json>}, bad: {Spec.alg_accepted(fields) == False{} : Bool}) -> {Spec.failed(J.verify(secret, J.token(a, b, c), now, leeway)) == True{} : Bool}:
  token_fails(secret, a, b, c, now, leeway, za, zb, zc, header_fails(a, b, now, leeway, h, dh, p => object_header(h, p, now, leeway, fields, ph, m => o => JwtProof.absurd({Spec.failed(J.payload_claims(Json.parse(p), now, leeway)) == True{} : Bool}, alg_absurd(fields, bad, m, o)))))

# A header that decodes but is not a JSON object fails to verify.
def header_not_object(+secret: List<&2, U32>, +a: String, +b: String, +c: String, +now: Nat, +leeway: Nat, +h: List<&2, U32>, za: {Spec.dots(a) == 0n : Nat}, zb: {Spec.dots(b) == 0n : Nat}, zc: {Spec.dots(c) == 0n : Nat}, dh: {J.decode(a) == Some{h} : Maybe<&2, List<&2, U32>>}, bad: {Spec.json_object(Json.parse(h)) == False{} : Bool}) -> {Spec.failed(J.verify(secret, J.token(a, b, c), now, leeway)) == True{} : Bool}:
  token_fails(secret, a, b, c, now, leeway, za, zb, zc, header_fails(a, b, now, leeway, h, dh, p => header_json(Json.parse(h), p, now, leeway, bad)))

# An object header with a repeated member name fails to verify.
def header_repeated(+secret: List<&2, U32>, +a: String, +b: String, +c: String, +now: Nat, +leeway: Nat, +h: List<&2, U32>, +fields: List<&2, Json.Field>, za: {Spec.dots(a) == 0n : Nat}, zb: {Spec.dots(b) == 0n : Nat}, zc: {Spec.dots(c) == 0n : Nat}, dh: {J.decode(a) == Some{h} : Maybe<&2, List<&2, U32>>}, ph: {Json.parse(h) == Done{Json.JObject{fields}} : Result<&2, &2, Json.Error, Json.Json>}, dup: {Spec.distinct(fields) == False{} : Bool}) -> {Spec.failed(J.verify(secret, J.token(a, b, c), now, leeway)) == True{} : Bool}:
  token_fails(secret, a, b, c, now, leeway, za, zb, zc, header_fails(a, b, now, leeway, h, dh, p => object_header(h, p, now, leeway, fields, ph, m => o => JwtProof.absurd({Spec.failed(J.payload_claims(Json.parse(p), now, leeway)) == True{} : Bool}, repeated_absurd(fields, dup, m)))))

# A payload that decodes but is not a JSON object fails to verify.
def payload_not_object(+secret: List<&2, U32>, +a: String, +b: String, +c: String, +now: Nat, +leeway: Nat, +p: List<&2, U32>, za: {Spec.dots(a) == 0n : Nat}, zb: {Spec.dots(b) == 0n : Nat}, zc: {Spec.dots(c) == 0n : Nat}, dp: {J.decode(b) == Some{p} : Maybe<&2, List<&2, U32>>}, bad: {Spec.json_object(Json.parse(p)) == False{} : Bool}) -> {Spec.failed(J.verify(secret, J.token(a, b, c), now, leeway)) == True{} : Bool}:
  token_fails(secret, a, b, c, now, leeway, za, zb, zc, payload_fails(a, b, now, leeway, p, dp, claims_json(Json.parse(p), now, leeway, bad)))

# An object payload with a repeated member name fails to verify.
def payload_repeated(+secret: List<&2, U32>, +a: String, +b: String, +c: String, +now: Nat, +leeway: Nat, +p: List<&2, U32>, +fields: List<&2, Json.Field>, za: {Spec.dots(a) == 0n : Nat}, zb: {Spec.dots(b) == 0n : Nat}, zc: {Spec.dots(c) == 0n : Nat}, dp: {J.decode(b) == Some{p} : Maybe<&2, List<&2, U32>>}, pp: {Json.parse(p) == Done{Json.JObject{fields}} : Result<&2, &2, Json.Error, Json.Json>}, dup: {Spec.distinct(fields) == False{} : Bool}) -> {Spec.failed(J.verify(secret, J.token(a, b, c), now, leeway)) == True{} : Bool}:
  token_fails(secret, a, b, c, now, leeway, za, zb, zc, payload_fails(a, b, now, leeway, p, dp, claims_distinct(p, now, leeway, fields, pp, dup)))

# verify only adds checks after open: every open failure is verify's result.
def open_failure(+secret: List<&2, U32>, +token: String, +now: Nat, +leeway: Nat, +e: J.Error, failed: {J.open(secret, token) == Fail{e} : Result<&2, &2, J.Error, J.Parts>}) -> {J.verify(secret, token, now, leeway) == Fail{e} : Result<&2, &2, J.Error, Json.Json>}:
  %Equal.sym(Result<&2, &2, J.Error, J.Parts>, J.open(secret, token), Fail{e}, failed) : {J.opened(_, now, leeway) == Fail{e} : Result<&2, &2, J.Error, Json.Json>}
  {==}

# ---- Exactly BadAlgorithm ----

def alg_exact(+fields: List<&2, Json.Field>, +p: List<&2, U32>, +now: Nat, +leeway: Nat, bad: {Spec.alg_accepted(fields) == False{} : Bool}, u: {J.unique(fields) == True{} : Bool}, +al: Bool, ea: {J.alg_ok(Json.lookup(fields, "alg")) == al : Bool}) -> {J.header_checked(fields, p, now, leeway, al, J.absent(Json.lookup(fields, "crit"))) == Fail{J.BadAlgorithm{}} : Result<&2, &2, J.Error, Json.Json>}:
  match al:
    case False{}:
      {==}
    case True{}:
      JwtProof.absurd({J.header_checked(fields, p, now, leeway, True{}, J.absent(Json.lookup(fields, "crit"))) == Fail{J.BadAlgorithm{}} : Result<&2, &2, J.Error, Json.Json>}, JwtProof.false_true(Equal.trans(Bool, False{}, Spec.alg_accepted(fields), True{}, Equal.sym(Bool, Spec.alg_accepted(fields), False{}, bad), alg_accepted(fields, u, ea))))

# With canonical segments, a correct signature and distinct member names, a
# header that does not name HS256 exactly once fails with BadAlgorithm. The
# alg is checked before the member limit, so this holds at any size.
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
  alg_exact(fields, p, now, leeway, bad, u, J.alg_ok(Json.lookup(fields, "alg")), {==})
