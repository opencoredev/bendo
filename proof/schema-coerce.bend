# BND-35: coercion for text sources agrees with its specification.
#
# `Schema.coerce` walks members and items with reversed accumulators; the
# specification `SchemaSpec.coerced` builds the same JSON by plain recursion.
# One induction follows the decoder's states and says what each must return.
import Base
import ../src/data/schema.bend as S
import ../src/data/json.bend as J
import ../src/data/schema-spec.bend as Spec
import ./schema-number.bend as NP
import ./schema-compound.bend as SC
import ./schema-errors.bend as SE

def onto_items(rev: List<&2, J.Json>, j: J.Json) -> J.Json:
  match j:
    case J.JArray{ys}: J.JArray{List.reverse.go(&2, J.Json, rev, ys)}
    case other: other

def onto_members(rev: List<&2, J.Field>, j: J.Json) -> J.Json:
  match j:
    case J.JObject{fs}: J.JObject{List.reverse.go(&2, J.Field, rev, fs)}
    case other: other

def onto_nil_items(+j: J.Json) -> {onto_items([], j) == j : J.Json}:
  match j:
    case J.JNull{}: {==}
    case J.JBool{b}: {==}
    case J.JNumber{b}: {==}
    case J.JString{b}: {==}
    case J.JArray{ys}: {==}
    case J.JObject{fs}: {==}

def onto_nil_members(+j: J.Json) -> {onto_members([], j) == j : J.Json}:
  match j:
    case J.JNull{}: {==}
    case J.JBool{b}: {==}
    case J.JNumber{b}: {==}
    case J.JString{b}: {==}
    case J.JArray{ys}: {==}
    case J.JObject{fs}: {==}

def onto_cons_items(+x: J.Json, +rev: List<&2, J.Json>, +r: J.Json) -> {onto_items(rev, Spec.cons_item(x, r)) == onto_items(x <> rev, r) : J.Json}:
  match r:
    case J.JNull{}: {==}
    case J.JBool{b}: {==}
    case J.JNumber{b}: {==}
    case J.JString{b}: {==}
    case J.JArray{ys}: {==}
    case J.JObject{fs}: {==}

def onto_cons_members(+f: J.Field, +rev: List<&2, J.Field>, +r: J.Json) -> {onto_members(rev, Spec.cons_member(f, r)) == onto_members(f <> rev, r) : J.Json}:
  match r:
    case J.JNull{}: {==}
    case J.JBool{b}: {==}
    case J.JNumber{b}: {==}
    case J.JString{b}: {==}
    case J.JArray{ys}: {==}
    case J.JObject{fs}: {==}

def number_same(+b: Bool, +x: String) -> {S.number_text(b, x) == Spec.number_or_text(b, x) : J.Json}:
  match b:
    case True{}: {==}
    case False{}: {==}

def number_eq(+x: String) -> {S.number_text(J.number_valid(x), x) == Spec.number_or_text(Spec.number(x), x) : J.Json}:
  %NP.number_equiv(x) : {S.number_text(J.number_valid(x), x) == Spec.number_or_text(_, x) : J.Json}
  number_same(J.number_valid(x), x)

def flag_eq(+a: Bool, +b: Bool, +x: String) -> {S.flag_text(a, b, x) == Spec.bool_or_text(a, b, x) : J.Json}:
  match a b:
    case True{} c: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def pick_eq(+b: Bool, +key: String, +y: J.Json, +c: J.Json) -> {Bool.pick(J.Field, b, J.Field{key, c}, J.Field{key, y}) == S.member_pick(b, key, y, c) : J.Field}:
  match b:
    case True{}: {==}
    case False{}: {==}

def values_step(+b: Bool, +y: J.Json, +t: List<&2, J.Field>, +k: String, +rev: List<&2, J.Json>, ih_t: {S.named_values(t, k, y <> rev) == List.reverse.go(&2, J.Json, y <> rev, Spec.values_named(t, k)) : List<&2, J.Json>}, ih_f: {S.named_values(t, k, rev) == List.reverse.go(&2, J.Json, rev, Spec.values_named(t, k)) : List<&2, J.Json>}) -> {S.named_values(t, k, S.keep_value(b, y, rev)) == List.reverse.go(&2, J.Json, rev, Spec.with_value(b, y, Spec.values_named(t, k))) : List<&2, J.Json>}:
  match b:
    case True{}: ih_t
    case False{}: ih_f

def values_go(+input: List<&2, J.Field>, +k: String, +rev: List<&2, J.Json>) -> {S.named_values(input, k, rev) == List.reverse.go(&2, J.Json, rev, Spec.values_named(input, k)) : List<&2, J.Json>}:
  match input:
    case Nil{}: {==}
    case J.Field{key, +y} <> +t: values_step(String.eq(key, k), y, t, k, rev, values_go(t, k, y <> rev), values_go(t, k, rev))

def values_eq(+input: List<&2, J.Field>, +k: String) -> {S.named_values(input, k, []) == Spec.values_named(input, k) : List<&2, J.Json>}:
  values_go(input, k, [])

# What each state of `coerce_go` returns, in terms of the specification.
def want(s: S.Schema, v: J.Json, w: S.Pass) -> J.Json:
  match w:
    case S.PValue{}: Spec.coerced(s, v, Spec.Whole{})
    case S.PMap{rev}: onto_items(rev, Spec.coerced(s, v, Spec.Each{}))
    case S.PEach{k, rev}: onto_members(rev, Spec.coerced(s, v, Spec.Members{k}))
    case S.PGather{k, g, f, rev}: onto_members(rev, Spec.coerced(s, v, Spec.Merged{k, g, f}))

def gather_eq(+s: S.Schema, +t: List<&2, J.Field>, +key: String, +y: J.Json, +k: String, +g: J.Json, +rev: List<&2, J.Field>, b: Bool, f: Bool) -> {S.coerce_go(s, J.JObject{t}, S.gather_step(b, f, key, y, k, g, rev)) == want(s, J.JObject{t}, S.gather_step(b, f, key, y, k, g, rev)) : J.Json} -> {S.coerce_go(s, J.JObject{t}, S.gather_step(b, f, key, y, k, g, rev)) == onto_members(rev, Spec.merged_member(b, f, key, y, g, Spec.coerced(s, J.JObject{t}, Spec.Merged{k, g, f && Bool.not(b)}))) : J.Json}:
  match b f:
    case True{} True{}: ih =>
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(J.Field{key, g}, Spec.coerced(s, J.JObject{t}, Spec.Merged{k, g, False{}}))), onto_members(J.Field{key, g} <> rev, Spec.coerced(s, J.JObject{t}, Spec.Merged{k, g, False{}})), onto_cons_members(J.Field{key, g}, rev, Spec.coerced(s, J.JObject{t}, Spec.Merged{k, g, False{}}))) : {S.coerce_go(s, J.JObject{t}, S.PGather{k, g, False{}, J.Field{key, g} <> rev}) == _ : J.Json}
      ih
    case True{} False{}: ih => ih
    case False{} True{}: ih =>
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(J.Field{key, y}, Spec.coerced(s, J.JObject{t}, Spec.Merged{k, g, True{}}))), onto_members(J.Field{key, y} <> rev, Spec.coerced(s, J.JObject{t}, Spec.Merged{k, g, True{}})), onto_cons_members(J.Field{key, y}, rev, Spec.coerced(s, J.JObject{t}, Spec.Merged{k, g, True{}}))) : {S.coerce_go(s, J.JObject{t}, S.PGather{k, g, True{}, J.Field{key, y} <> rev}) == _ : J.Json}
      ih
    case False{} False{}: ih =>
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(J.Field{key, y}, Spec.coerced(s, J.JObject{t}, Spec.Merged{k, g, False{}}))), onto_members(J.Field{key, y} <> rev, Spec.coerced(s, J.JObject{t}, Spec.Merged{k, g, False{}})), onto_cons_members(J.Field{key, y}, rev, Spec.coerced(s, J.JObject{t}, Spec.Merged{k, g, False{}}))) : {S.coerce_go(s, J.JObject{t}, S.PGather{k, g, False{}, J.Field{key, y} <> rev}) == _ : J.Json}
      ih


# Each state of `coerce_go` returns what `want` says.
def ceq(+s: S.Schema, +v: J.Json, +w: S.Pass) -> {S.coerce_go(s, v, w) == want(s, v, w) : J.Json}:
  match s v w:
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JNull{} S.PValue{}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JNull{} S.PMap{+rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JBool{+b0} S.PValue{}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JNumber{+b0} S.PValue{}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JString{+x} S.PValue{}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JString{+x} S.PMap{+rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JArray{Nil{}} S.PValue{}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.StringSchema{a1, a2, a3, a4}, h, Spec.Whole{}), Spec.coerced(S.StringSchema{a1, a2, a3, a4}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.StringSchema{a1, a2, a3, a4}, h, Spec.Whole{}) <> rev, Spec.coerced(S.StringSchema{a1, a2, a3, a4}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.StringSchema{a1, a2, a3, a4}, h, Spec.Whole{}), rev, Spec.coerced(S.StringSchema{a1, a2, a3, a4}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.StringSchema{a1, a2, a3, a4}, J.JArray{hs}, S.PMap{S.coerce_go(S.StringSchema{a1, a2, a3, a4}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.StringSchema{a1, a2, a3, a4}, h, S.PValue{}) : {S.coerce_go(S.StringSchema{a1, a2, a3, a4}, J.JArray{hs}, S.PMap{S.coerce_go(S.StringSchema{a1, a2, a3, a4}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.StringSchema{a1, a2, a3, a4}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.StringSchema{a1, a2, a3, a4}, J.JArray{hs}, S.PMap{S.coerce_go(S.StringSchema{a1, a2, a3, a4}, h, S.PValue{}) <> rev})
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JObject{Nil{}} S.PValue{}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.StringSchema{a1, a2, a3, a4}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.StringSchema{a1, a2, a3, a4}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.StringSchema{a1, a2, a3, a4}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.StringSchema{a1, a2, a3, a4}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.StringSchema{a1, a2, a3, a4}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.StringSchema{a1, a2, a3, a4}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.StringSchema{a1, a2, a3, a4}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.StringSchema{a1, a2, a3, a4}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.StringSchema{a1, a2, a3, a4}, y, S.PValue{}) : {S.coerce_go(S.StringSchema{a1, a2, a3, a4}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.StringSchema{a1, a2, a3, a4}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.StringSchema{a1, a2, a3, a4}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.StringSchema{a1, a2, a3, a4}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.StringSchema{a1, a2, a3, a4}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.StringSchema{a1, a2, a3, a4}, y, S.PValue{}))) : {S.coerce_go(S.StringSchema{a1, a2, a3, a4}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.StringSchema{a1, a2, a3, a4}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.StringSchema{a1, a2, a3, a4}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.StringSchema{a1, a2, a3, a4}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.StringSchema{a1, a2, a3, a4}, y, S.PValue{})) <> rev})
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.StringSchema{a1, a2, a3, a4}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.StringSchema{a1, a2, a3, a4}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.NumberSchema{+a1, +a2} J.JNull{} S.PValue{}: {==}
    case S.NumberSchema{+a1, +a2} J.JNull{} S.PMap{+rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JBool{+b0} S.PValue{}: {==}
    case S.NumberSchema{+a1, +a2} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JNumber{+b0} S.PValue{}: {==}
    case S.NumberSchema{+a1, +a2} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JString{+x} S.PValue{}: number_eq(x)
    case S.NumberSchema{+a1, +a2} J.JString{+x} S.PMap{+rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JArray{Nil{}} S.PValue{}: {==}
    case S.NumberSchema{+a1, +a2} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.NumberSchema{+a1, +a2} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.NumberSchema{a1, a2}, h, Spec.Whole{}), Spec.coerced(S.NumberSchema{a1, a2}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.NumberSchema{a1, a2}, h, Spec.Whole{}) <> rev, Spec.coerced(S.NumberSchema{a1, a2}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.NumberSchema{a1, a2}, h, Spec.Whole{}), rev, Spec.coerced(S.NumberSchema{a1, a2}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.NumberSchema{a1, a2}, J.JArray{hs}, S.PMap{S.coerce_go(S.NumberSchema{a1, a2}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.NumberSchema{a1, a2}, h, S.PValue{}) : {S.coerce_go(S.NumberSchema{a1, a2}, J.JArray{hs}, S.PMap{S.coerce_go(S.NumberSchema{a1, a2}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.NumberSchema{a1, a2}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.NumberSchema{a1, a2}, J.JArray{hs}, S.PMap{S.coerce_go(S.NumberSchema{a1, a2}, h, S.PValue{}) <> rev})
    case S.NumberSchema{+a1, +a2} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JObject{Nil{}} S.PValue{}: {==}
    case S.NumberSchema{+a1, +a2} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}: {==}
    case S.NumberSchema{+a1, +a2} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.NumberSchema{+a1, +a2} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.NumberSchema{a1, a2}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.NumberSchema{a1, a2}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.NumberSchema{a1, a2}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.NumberSchema{a1, a2}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.NumberSchema{a1, a2}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.NumberSchema{a1, a2}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.NumberSchema{a1, a2}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.NumberSchema{a1, a2}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.NumberSchema{a1, a2}, y, S.PValue{}) : {S.coerce_go(S.NumberSchema{a1, a2}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.NumberSchema{a1, a2}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.NumberSchema{a1, a2}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.NumberSchema{a1, a2}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.NumberSchema{a1, a2}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.NumberSchema{a1, a2}, y, S.PValue{}))) : {S.coerce_go(S.NumberSchema{a1, a2}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.NumberSchema{a1, a2}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.NumberSchema{a1, a2}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.NumberSchema{a1, a2}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.NumberSchema{a1, a2}, y, S.PValue{})) <> rev})
    case S.NumberSchema{+a1, +a2} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.NumberSchema{a1, a2}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.NumberSchema{a1, a2}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.IntegerSchema{+a1, +a2} J.JNull{} S.PValue{}: {==}
    case S.IntegerSchema{+a1, +a2} J.JNull{} S.PMap{+rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JBool{+b0} S.PValue{}: {==}
    case S.IntegerSchema{+a1, +a2} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JNumber{+b0} S.PValue{}: {==}
    case S.IntegerSchema{+a1, +a2} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JString{+x} S.PValue{}: number_eq(x)
    case S.IntegerSchema{+a1, +a2} J.JString{+x} S.PMap{+rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JArray{Nil{}} S.PValue{}: {==}
    case S.IntegerSchema{+a1, +a2} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.IntegerSchema{+a1, +a2} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.IntegerSchema{a1, a2}, h, Spec.Whole{}), Spec.coerced(S.IntegerSchema{a1, a2}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.IntegerSchema{a1, a2}, h, Spec.Whole{}) <> rev, Spec.coerced(S.IntegerSchema{a1, a2}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.IntegerSchema{a1, a2}, h, Spec.Whole{}), rev, Spec.coerced(S.IntegerSchema{a1, a2}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.IntegerSchema{a1, a2}, J.JArray{hs}, S.PMap{S.coerce_go(S.IntegerSchema{a1, a2}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.IntegerSchema{a1, a2}, h, S.PValue{}) : {S.coerce_go(S.IntegerSchema{a1, a2}, J.JArray{hs}, S.PMap{S.coerce_go(S.IntegerSchema{a1, a2}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.IntegerSchema{a1, a2}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.IntegerSchema{a1, a2}, J.JArray{hs}, S.PMap{S.coerce_go(S.IntegerSchema{a1, a2}, h, S.PValue{}) <> rev})
    case S.IntegerSchema{+a1, +a2} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JObject{Nil{}} S.PValue{}: {==}
    case S.IntegerSchema{+a1, +a2} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}: {==}
    case S.IntegerSchema{+a1, +a2} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.IntegerSchema{+a1, +a2} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.IntegerSchema{a1, a2}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.IntegerSchema{a1, a2}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.IntegerSchema{a1, a2}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.IntegerSchema{a1, a2}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.IntegerSchema{a1, a2}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.IntegerSchema{a1, a2}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.IntegerSchema{a1, a2}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.IntegerSchema{a1, a2}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.IntegerSchema{a1, a2}, y, S.PValue{}) : {S.coerce_go(S.IntegerSchema{a1, a2}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.IntegerSchema{a1, a2}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.IntegerSchema{a1, a2}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.IntegerSchema{a1, a2}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.IntegerSchema{a1, a2}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.IntegerSchema{a1, a2}, y, S.PValue{}))) : {S.coerce_go(S.IntegerSchema{a1, a2}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.IntegerSchema{a1, a2}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.IntegerSchema{a1, a2}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.IntegerSchema{a1, a2}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.IntegerSchema{a1, a2}, y, S.PValue{})) <> rev})
    case S.IntegerSchema{+a1, +a2} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.IntegerSchema{a1, a2}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.IntegerSchema{a1, a2}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.BooleanSchema{} J.JNull{} S.PValue{}: {==}
    case S.BooleanSchema{} J.JNull{} S.PMap{+rev}: {==}
    case S.BooleanSchema{} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.BooleanSchema{} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.BooleanSchema{} J.JBool{+b0} S.PValue{}: {==}
    case S.BooleanSchema{} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.BooleanSchema{} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.BooleanSchema{} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.BooleanSchema{} J.JNumber{+b0} S.PValue{}: {==}
    case S.BooleanSchema{} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.BooleanSchema{} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.BooleanSchema{} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.BooleanSchema{} J.JString{+x} S.PValue{}: flag_eq(String.eq(x, "true"), String.eq(x, "false"), x)
    case S.BooleanSchema{} J.JString{+x} S.PMap{+rev}: {==}
    case S.BooleanSchema{} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.BooleanSchema{} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.BooleanSchema{} J.JArray{Nil{}} S.PValue{}: {==}
    case S.BooleanSchema{} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.BooleanSchema{} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.BooleanSchema{} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.BooleanSchema{} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.BooleanSchema{} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.BooleanSchema{}, h, Spec.Whole{}), Spec.coerced(S.BooleanSchema{}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.BooleanSchema{}, h, Spec.Whole{}) <> rev, Spec.coerced(S.BooleanSchema{}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.BooleanSchema{}, h, Spec.Whole{}), rev, Spec.coerced(S.BooleanSchema{}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.BooleanSchema{}, J.JArray{hs}, S.PMap{S.coerce_go(S.BooleanSchema{}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.BooleanSchema{}, h, S.PValue{}) : {S.coerce_go(S.BooleanSchema{}, J.JArray{hs}, S.PMap{S.coerce_go(S.BooleanSchema{}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.BooleanSchema{}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.BooleanSchema{}, J.JArray{hs}, S.PMap{S.coerce_go(S.BooleanSchema{}, h, S.PValue{}) <> rev})
    case S.BooleanSchema{} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.BooleanSchema{} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.BooleanSchema{} J.JObject{Nil{}} S.PValue{}: {==}
    case S.BooleanSchema{} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.BooleanSchema{} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.BooleanSchema{} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.BooleanSchema{} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}: {==}
    case S.BooleanSchema{} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.BooleanSchema{} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.BooleanSchema{}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.BooleanSchema{}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.BooleanSchema{}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.BooleanSchema{}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.BooleanSchema{}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.BooleanSchema{}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.BooleanSchema{}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.BooleanSchema{}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.BooleanSchema{}, y, S.PValue{}) : {S.coerce_go(S.BooleanSchema{}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.BooleanSchema{}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.BooleanSchema{}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.BooleanSchema{}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.BooleanSchema{}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.BooleanSchema{}, y, S.PValue{}))) : {S.coerce_go(S.BooleanSchema{}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.BooleanSchema{}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.BooleanSchema{}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.BooleanSchema{}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.BooleanSchema{}, y, S.PValue{})) <> rev})
    case S.BooleanSchema{} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.BooleanSchema{}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.BooleanSchema{}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.LiteralSchema{+a1} J.JNull{} S.PValue{}: {==}
    case S.LiteralSchema{+a1} J.JNull{} S.PMap{+rev}: {==}
    case S.LiteralSchema{+a1} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.LiteralSchema{+a1} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.LiteralSchema{+a1} J.JBool{+b0} S.PValue{}: {==}
    case S.LiteralSchema{+a1} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.LiteralSchema{+a1} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.LiteralSchema{+a1} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.LiteralSchema{+a1} J.JNumber{+b0} S.PValue{}: {==}
    case S.LiteralSchema{+a1} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.LiteralSchema{+a1} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.LiteralSchema{+a1} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.LiteralSchema{+a1} J.JString{+x} S.PValue{}: {==}
    case S.LiteralSchema{+a1} J.JString{+x} S.PMap{+rev}: {==}
    case S.LiteralSchema{+a1} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.LiteralSchema{+a1} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.LiteralSchema{+a1} J.JArray{Nil{}} S.PValue{}: {==}
    case S.LiteralSchema{+a1} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.LiteralSchema{+a1} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.LiteralSchema{+a1} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.LiteralSchema{+a1} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.LiteralSchema{+a1} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.LiteralSchema{a1}, h, Spec.Whole{}), Spec.coerced(S.LiteralSchema{a1}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.LiteralSchema{a1}, h, Spec.Whole{}) <> rev, Spec.coerced(S.LiteralSchema{a1}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.LiteralSchema{a1}, h, Spec.Whole{}), rev, Spec.coerced(S.LiteralSchema{a1}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.LiteralSchema{a1}, J.JArray{hs}, S.PMap{S.coerce_go(S.LiteralSchema{a1}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.LiteralSchema{a1}, h, S.PValue{}) : {S.coerce_go(S.LiteralSchema{a1}, J.JArray{hs}, S.PMap{S.coerce_go(S.LiteralSchema{a1}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.LiteralSchema{a1}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.LiteralSchema{a1}, J.JArray{hs}, S.PMap{S.coerce_go(S.LiteralSchema{a1}, h, S.PValue{}) <> rev})
    case S.LiteralSchema{+a1} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.LiteralSchema{+a1} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.LiteralSchema{+a1} J.JObject{Nil{}} S.PValue{}: {==}
    case S.LiteralSchema{+a1} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.LiteralSchema{+a1} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.LiteralSchema{+a1} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.LiteralSchema{+a1} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}: {==}
    case S.LiteralSchema{+a1} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.LiteralSchema{+a1} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.LiteralSchema{a1}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.LiteralSchema{a1}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.LiteralSchema{a1}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.LiteralSchema{a1}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.LiteralSchema{a1}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.LiteralSchema{a1}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.LiteralSchema{a1}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.LiteralSchema{a1}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.LiteralSchema{a1}, y, S.PValue{}) : {S.coerce_go(S.LiteralSchema{a1}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.LiteralSchema{a1}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.LiteralSchema{a1}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.LiteralSchema{a1}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.LiteralSchema{a1}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.LiteralSchema{a1}, y, S.PValue{}))) : {S.coerce_go(S.LiteralSchema{a1}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.LiteralSchema{a1}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.LiteralSchema{a1}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.LiteralSchema{a1}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.LiteralSchema{a1}, y, S.PValue{})) <> rev})
    case S.LiteralSchema{+a1} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.LiteralSchema{a1}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.LiteralSchema{a1}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.EnumSchema{+a1} J.JNull{} S.PValue{}: {==}
    case S.EnumSchema{+a1} J.JNull{} S.PMap{+rev}: {==}
    case S.EnumSchema{+a1} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.EnumSchema{+a1} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.EnumSchema{+a1} J.JBool{+b0} S.PValue{}: {==}
    case S.EnumSchema{+a1} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.EnumSchema{+a1} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.EnumSchema{+a1} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.EnumSchema{+a1} J.JNumber{+b0} S.PValue{}: {==}
    case S.EnumSchema{+a1} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.EnumSchema{+a1} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.EnumSchema{+a1} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.EnumSchema{+a1} J.JString{+x} S.PValue{}: {==}
    case S.EnumSchema{+a1} J.JString{+x} S.PMap{+rev}: {==}
    case S.EnumSchema{+a1} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.EnumSchema{+a1} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.EnumSchema{+a1} J.JArray{Nil{}} S.PValue{}: {==}
    case S.EnumSchema{+a1} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.EnumSchema{+a1} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.EnumSchema{+a1} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.EnumSchema{+a1} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.EnumSchema{+a1} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.EnumSchema{a1}, h, Spec.Whole{}), Spec.coerced(S.EnumSchema{a1}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.EnumSchema{a1}, h, Spec.Whole{}) <> rev, Spec.coerced(S.EnumSchema{a1}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.EnumSchema{a1}, h, Spec.Whole{}), rev, Spec.coerced(S.EnumSchema{a1}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.EnumSchema{a1}, J.JArray{hs}, S.PMap{S.coerce_go(S.EnumSchema{a1}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.EnumSchema{a1}, h, S.PValue{}) : {S.coerce_go(S.EnumSchema{a1}, J.JArray{hs}, S.PMap{S.coerce_go(S.EnumSchema{a1}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.EnumSchema{a1}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.EnumSchema{a1}, J.JArray{hs}, S.PMap{S.coerce_go(S.EnumSchema{a1}, h, S.PValue{}) <> rev})
    case S.EnumSchema{+a1} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.EnumSchema{+a1} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.EnumSchema{+a1} J.JObject{Nil{}} S.PValue{}: {==}
    case S.EnumSchema{+a1} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.EnumSchema{+a1} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.EnumSchema{+a1} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.EnumSchema{+a1} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}: {==}
    case S.EnumSchema{+a1} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.EnumSchema{+a1} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.EnumSchema{a1}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.EnumSchema{a1}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.EnumSchema{a1}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.EnumSchema{a1}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.EnumSchema{a1}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.EnumSchema{a1}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.EnumSchema{a1}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.EnumSchema{a1}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.EnumSchema{a1}, y, S.PValue{}) : {S.coerce_go(S.EnumSchema{a1}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.EnumSchema{a1}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.EnumSchema{a1}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.EnumSchema{a1}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.EnumSchema{a1}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.EnumSchema{a1}, y, S.PValue{}))) : {S.coerce_go(S.EnumSchema{a1}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.EnumSchema{a1}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.EnumSchema{a1}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.EnumSchema{a1}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.EnumSchema{a1}, y, S.PValue{})) <> rev})
    case S.EnumSchema{+a1} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.EnumSchema{a1}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.EnumSchema{a1}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.ArraySchema{+i, +m, +n} J.JNull{} S.PValue{}: {==}
    case S.ArraySchema{+i, +m, +n} J.JNull{} S.PMap{+rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JBool{+b0} S.PValue{}: {==}
    case S.ArraySchema{+i, +m, +n} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JNumber{+b0} S.PValue{}: {==}
    case S.ArraySchema{+i, +m, +n} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JString{+x} S.PValue{}: {==}
    case S.ArraySchema{+i, +m, +n} J.JString{+x} S.PMap{+rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JArray{Nil{}} S.PValue{}: Equal.trans(J.Json, S.coerce_go(i, J.JArray{Nil{}}, S.PMap{[]}), onto_items([], Spec.coerced(i, J.JArray{Nil{}}, Spec.Each{})), Spec.coerced(i, J.JArray{Nil{}}, Spec.Each{}), ceq(i, J.JArray{Nil{}}, S.PMap{[]}), onto_nil_items(Spec.coerced(i, J.JArray{Nil{}}, Spec.Each{})))
    case S.ArraySchema{+i, +m, +n} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JArray{+h <> +hs} S.PValue{}: Equal.trans(J.Json, S.coerce_go(i, J.JArray{h <> hs}, S.PMap{[]}), onto_items([], Spec.coerced(i, J.JArray{h <> hs}, Spec.Each{})), Spec.coerced(i, J.JArray{h <> hs}, Spec.Each{}), ceq(i, J.JArray{h <> hs}, S.PMap{[]}), onto_nil_items(Spec.coerced(i, J.JArray{h <> hs}, Spec.Each{})))
    case S.ArraySchema{+i, +m, +n} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.ArraySchema{i, m, n}, h, Spec.Whole{}), Spec.coerced(S.ArraySchema{i, m, n}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.ArraySchema{i, m, n}, h, Spec.Whole{}) <> rev, Spec.coerced(S.ArraySchema{i, m, n}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.ArraySchema{i, m, n}, h, Spec.Whole{}), rev, Spec.coerced(S.ArraySchema{i, m, n}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.ArraySchema{i, m, n}, J.JArray{hs}, S.PMap{S.coerce_go(S.ArraySchema{i, m, n}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.ArraySchema{i, m, n}, h, S.PValue{}) : {S.coerce_go(S.ArraySchema{i, m, n}, J.JArray{hs}, S.PMap{S.coerce_go(S.ArraySchema{i, m, n}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.ArraySchema{i, m, n}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.ArraySchema{i, m, n}, J.JArray{hs}, S.PMap{S.coerce_go(S.ArraySchema{i, m, n}, h, S.PValue{}) <> rev})
    case S.ArraySchema{+i, +m, +n} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JObject{Nil{}} S.PValue{}: {==}
    case S.ArraySchema{+i, +m, +n} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}: {==}
    case S.ArraySchema{+i, +m, +n} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.ArraySchema{+i, +m, +n} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ArraySchema{i, m, n}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.ArraySchema{i, m, n}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ArraySchema{i, m, n}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.ArraySchema{i, m, n}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ArraySchema{i, m, n}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.ArraySchema{i, m, n}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.ArraySchema{i, m, n}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ArraySchema{i, m, n}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.ArraySchema{i, m, n}, y, S.PValue{}) : {S.coerce_go(S.ArraySchema{i, m, n}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ArraySchema{i, m, n}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.ArraySchema{i, m, n}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.ArraySchema{i, m, n}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ArraySchema{i, m, n}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.ArraySchema{i, m, n}, y, S.PValue{}))) : {S.coerce_go(S.ArraySchema{i, m, n}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ArraySchema{i, m, n}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.ArraySchema{i, m, n}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.ArraySchema{i, m, n}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ArraySchema{i, m, n}, y, S.PValue{})) <> rev})
    case S.ArraySchema{+i, +m, +n} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.ArraySchema{i, m, n}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.ArraySchema{i, m, n}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.ObjectSchema{Nil{}, +u} J.JNull{} S.PValue{}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JNull{} S.PMap{+rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JBool{+b0} S.PValue{}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JNumber{+b0} S.PValue{}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JString{+x} S.PValue{}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JString{+x} S.PMap{+rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JArray{Nil{}} S.PValue{}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.ObjectSchema{Nil{}, u}, h, Spec.Whole{}), Spec.coerced(S.ObjectSchema{Nil{}, u}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.ObjectSchema{Nil{}, u}, h, Spec.Whole{}) <> rev, Spec.coerced(S.ObjectSchema{Nil{}, u}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.ObjectSchema{Nil{}, u}, h, Spec.Whole{}), rev, Spec.coerced(S.ObjectSchema{Nil{}, u}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.ObjectSchema{Nil{}, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{Nil{}, u}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{Nil{}, u}, h, S.PValue{}) : {S.coerce_go(S.ObjectSchema{Nil{}, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{Nil{}, u}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.ObjectSchema{Nil{}, u}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.ObjectSchema{Nil{}, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{Nil{}, u}, h, S.PValue{}) <> rev})
    case S.ObjectSchema{Nil{}, +u} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JObject{Nil{}} S.PValue{}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{Nil{}, u}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.ObjectSchema{Nil{}, u}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{Nil{}, u}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{Nil{}, u}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{Nil{}, u}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.ObjectSchema{Nil{}, u}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.ObjectSchema{Nil{}, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{Nil{}, u}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{Nil{}, u}, y, S.PValue{}) : {S.coerce_go(S.ObjectSchema{Nil{}, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{Nil{}, u}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{Nil{}, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.ObjectSchema{Nil{}, u}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{Nil{}, u}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{Nil{}, u}, y, S.PValue{}))) : {S.coerce_go(S.ObjectSchema{Nil{}, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{Nil{}, u}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.ObjectSchema{Nil{}, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.ObjectSchema{Nil{}, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{Nil{}, u}, y, S.PValue{})) <> rev})
    case S.ObjectSchema{Nil{}, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.ObjectSchema{Nil{}, u}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.ObjectSchema{Nil{}, u}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JNull{} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JNull{} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JBool{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JNumber{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JString{+x} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JString{+x} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JArray{Nil{}} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, h, Spec.Whole{}), Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, h, Spec.Whole{}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, h, Spec.Whole{}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, h, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, h, S.PValue{}) <> rev})
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JObject{Nil{}} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.StringSchema{c1, c2, c3, c4}, J.JObject{[]}, S.PEach{k, []}), Spec.coerced(S.StringSchema{c1, c2, c3, c4}, J.JObject{[]}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.StringSchema{c1, c2, c3, c4}, J.JObject{[]}, S.PEach{k, []}), onto_members([], Spec.coerced(S.StringSchema{c1, c2, c3, c4}, J.JObject{[]}, Spec.Members{k})), Spec.coerced(S.StringSchema{c1, c2, c3, c4}, J.JObject{[]}, Spec.Members{k}), ceq(S.StringSchema{c1, c2, c3, c4}, J.JObject{[]}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.StringSchema{c1, c2, c3, c4}, J.JObject{[]}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.StringSchema{c1, c2, c3, c4}, J.JObject{[]}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.StringSchema{c1, c2, c3, c4}, J.JObject{[]}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.StringSchema{c1, c2, c3, c4}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), Spec.coerced(S.StringSchema{c1, c2, c3, c4}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.StringSchema{c1, c2, c3, c4}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_members([], Spec.coerced(S.StringSchema{c1, c2, c3, c4}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})), Spec.coerced(S.StringSchema{c1, c2, c3, c4}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), ceq(S.StringSchema{c1, c2, c3, c4}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.StringSchema{c1, c2, c3, c4}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.StringSchema{c1, c2, c3, c4}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.StringSchema{c1, c2, c3, c4}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, y, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, y, S.PValue{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, y, S.PValue{})) <> rev})
    case S.ObjectSchema{S.Field{+k, S.StringSchema{+c1, +c2, +c3, +c4}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.ObjectSchema{S.Field{k, S.StringSchema{c1, c2, c3, c4}, p} <> t, u}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JNull{} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JNull{} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JBool{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JNumber{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JString{+x} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JString{+x} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{Nil{}} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, h, Spec.Whole{}), Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, h, Spec.Whole{}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, h, Spec.Whole{}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, h, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, h, S.PValue{}) <> rev})
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{Nil{}} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.NumberSchema{c1, c2}, J.JObject{[]}, S.PEach{k, []}), Spec.coerced(S.NumberSchema{c1, c2}, J.JObject{[]}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.NumberSchema{c1, c2}, J.JObject{[]}, S.PEach{k, []}), onto_members([], Spec.coerced(S.NumberSchema{c1, c2}, J.JObject{[]}, Spec.Members{k})), Spec.coerced(S.NumberSchema{c1, c2}, J.JObject{[]}, Spec.Members{k}), ceq(S.NumberSchema{c1, c2}, J.JObject{[]}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.NumberSchema{c1, c2}, J.JObject{[]}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.NumberSchema{c1, c2}, J.JObject{[]}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.NumberSchema{c1, c2}, J.JObject{[]}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.NumberSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), Spec.coerced(S.NumberSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.NumberSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_members([], Spec.coerced(S.NumberSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})), Spec.coerced(S.NumberSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), ceq(S.NumberSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.NumberSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.NumberSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.NumberSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, y, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, y, S.PValue{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, y, S.PValue{})) <> rev})
    case S.ObjectSchema{S.Field{+k, S.NumberSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.ObjectSchema{S.Field{k, S.NumberSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JNull{} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JNull{} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JBool{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JNumber{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JString{+x} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JString{+x} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{Nil{}} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, h, Spec.Whole{}), Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, h, Spec.Whole{}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, h, Spec.Whole{}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, h, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, h, S.PValue{}) <> rev})
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{Nil{}} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.IntegerSchema{c1, c2}, J.JObject{[]}, S.PEach{k, []}), Spec.coerced(S.IntegerSchema{c1, c2}, J.JObject{[]}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.IntegerSchema{c1, c2}, J.JObject{[]}, S.PEach{k, []}), onto_members([], Spec.coerced(S.IntegerSchema{c1, c2}, J.JObject{[]}, Spec.Members{k})), Spec.coerced(S.IntegerSchema{c1, c2}, J.JObject{[]}, Spec.Members{k}), ceq(S.IntegerSchema{c1, c2}, J.JObject{[]}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.IntegerSchema{c1, c2}, J.JObject{[]}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.IntegerSchema{c1, c2}, J.JObject{[]}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.IntegerSchema{c1, c2}, J.JObject{[]}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.IntegerSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), Spec.coerced(S.IntegerSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.IntegerSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_members([], Spec.coerced(S.IntegerSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})), Spec.coerced(S.IntegerSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), ceq(S.IntegerSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.IntegerSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.IntegerSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.IntegerSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, y, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, y, S.PValue{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, y, S.PValue{})) <> rev})
    case S.ObjectSchema{S.Field{+k, S.IntegerSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.ObjectSchema{S.Field{k, S.IntegerSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JNull{} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JNull{} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JBool{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JNumber{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JString{+x} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JString{+x} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JArray{Nil{}} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, h, Spec.Whole{}), Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, h, Spec.Whole{}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, h, Spec.Whole{}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, h, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, h, S.PValue{}) <> rev})
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JObject{Nil{}} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.BooleanSchema{}, J.JObject{[]}, S.PEach{k, []}), Spec.coerced(S.BooleanSchema{}, J.JObject{[]}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.BooleanSchema{}, J.JObject{[]}, S.PEach{k, []}), onto_members([], Spec.coerced(S.BooleanSchema{}, J.JObject{[]}, Spec.Members{k})), Spec.coerced(S.BooleanSchema{}, J.JObject{[]}, Spec.Members{k}), ceq(S.BooleanSchema{}, J.JObject{[]}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.BooleanSchema{}, J.JObject{[]}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.BooleanSchema{}, J.JObject{[]}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.BooleanSchema{}, J.JObject{[]}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.BooleanSchema{}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), Spec.coerced(S.BooleanSchema{}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.BooleanSchema{}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_members([], Spec.coerced(S.BooleanSchema{}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})), Spec.coerced(S.BooleanSchema{}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), ceq(S.BooleanSchema{}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.BooleanSchema{}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.BooleanSchema{}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.BooleanSchema{}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, y, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, y, S.PValue{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, y, S.PValue{})) <> rev})
    case S.ObjectSchema{S.Field{+k, S.BooleanSchema{}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.ObjectSchema{S.Field{k, S.BooleanSchema{}, p} <> t, u}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, h, Spec.Whole{}), Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, h, Spec.Whole{}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, h, Spec.Whole{}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, h, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, h, S.PValue{}) <> rev})
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.LiteralSchema{c1}, J.JObject{[]}, S.PEach{k, []}), Spec.coerced(S.LiteralSchema{c1}, J.JObject{[]}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.LiteralSchema{c1}, J.JObject{[]}, S.PEach{k, []}), onto_members([], Spec.coerced(S.LiteralSchema{c1}, J.JObject{[]}, Spec.Members{k})), Spec.coerced(S.LiteralSchema{c1}, J.JObject{[]}, Spec.Members{k}), ceq(S.LiteralSchema{c1}, J.JObject{[]}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.LiteralSchema{c1}, J.JObject{[]}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.LiteralSchema{c1}, J.JObject{[]}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.LiteralSchema{c1}, J.JObject{[]}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.LiteralSchema{c1}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), Spec.coerced(S.LiteralSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.LiteralSchema{c1}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_members([], Spec.coerced(S.LiteralSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})), Spec.coerced(S.LiteralSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), ceq(S.LiteralSchema{c1}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.LiteralSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.LiteralSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.LiteralSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, y, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, y, S.PValue{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev})
    case S.ObjectSchema{S.Field{+k, S.LiteralSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.ObjectSchema{S.Field{k, S.LiteralSchema{c1}, p} <> t, u}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, h, Spec.Whole{}), Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, h, Spec.Whole{}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, h, Spec.Whole{}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, h, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, h, S.PValue{}) <> rev})
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.EnumSchema{c1}, J.JObject{[]}, S.PEach{k, []}), Spec.coerced(S.EnumSchema{c1}, J.JObject{[]}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.EnumSchema{c1}, J.JObject{[]}, S.PEach{k, []}), onto_members([], Spec.coerced(S.EnumSchema{c1}, J.JObject{[]}, Spec.Members{k})), Spec.coerced(S.EnumSchema{c1}, J.JObject{[]}, Spec.Members{k}), ceq(S.EnumSchema{c1}, J.JObject{[]}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.EnumSchema{c1}, J.JObject{[]}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.EnumSchema{c1}, J.JObject{[]}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.EnumSchema{c1}, J.JObject{[]}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.EnumSchema{c1}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), Spec.coerced(S.EnumSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.EnumSchema{c1}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_members([], Spec.coerced(S.EnumSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})), Spec.coerced(S.EnumSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), ceq(S.EnumSchema{c1}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.EnumSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.EnumSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.EnumSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, y, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, y, S.PValue{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev})
    case S.ObjectSchema{S.Field{+k, S.EnumSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.ObjectSchema{S.Field{k, S.EnumSchema{c1}, p} <> t, u}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JNull{} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JNull{} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JBool{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JNumber{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JString{+x} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JString{+x} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JArray{Nil{}} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, h, Spec.Whole{}), Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, h, Spec.Whole{}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, h, Spec.Whole{}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, h, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, h, S.PValue{}) <> rev})
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JObject{Nil{}} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(i, J.JObject{[]}, S.PGather{k, S.coerce_go(i, J.JArray{S.named_values([], k, [])}, S.PMap{[]}), True{}, []}), Spec.coerced(i, J.JObject{[]}, Spec.Merged{k, Spec.coerced(i, J.JArray{Spec.values_named([], k)}, Spec.Each{}), True{}}), Equal.trans(J.Json, S.coerce_go(i, J.JObject{[]}, S.PGather{k, S.coerce_go(i, J.JArray{S.named_values([], k, [])}, S.PMap{[]}), True{}, []}), onto_members([], Spec.coerced(i, J.JObject{[]}, Spec.Merged{k, S.coerce_go(i, J.JArray{S.named_values([], k, [])}, S.PMap{[]}), True{}})), Spec.coerced(i, J.JObject{[]}, Spec.Merged{k, Spec.coerced(i, J.JArray{Spec.values_named([], k)}, Spec.Each{}), True{}}), ceq(i, J.JObject{[]}, S.PGather{k, S.coerce_go(i, J.JArray{S.named_values([], k, [])}, S.PMap{[]}), True{}, []}), Equal.trans(J.Json, onto_members([], Spec.coerced(i, J.JObject{[]}, Spec.Merged{k, S.coerce_go(i, J.JArray{S.named_values([], k, [])}, S.PMap{[]}), True{}})), Spec.coerced(i, J.JObject{[]}, Spec.Merged{k, S.coerce_go(i, J.JArray{S.named_values([], k, [])}, S.PMap{[]}), True{}}), Spec.coerced(i, J.JObject{[]}, Spec.Merged{k, Spec.coerced(i, J.JArray{Spec.values_named([], k)}, Spec.Each{}), True{}}), onto_nil_members(Spec.coerced(i, J.JObject{[]}, Spec.Merged{k, S.coerce_go(i, J.JArray{S.named_values([], k, [])}, S.PMap{[]}), True{}})), Equal.cong(J.Json, J.Json, z => Spec.coerced(i, J.JObject{[]}, Spec.Merged{k, z, True{}}), S.coerce_go(i, J.JArray{S.named_values([], k, [])}, S.PMap{[]}), Spec.coerced(i, J.JArray{Spec.values_named([], k)}, Spec.Each{}), Equal.trans(J.Json, S.coerce_go(i, J.JArray{S.named_values([], k, [])}, S.PMap{[]}), onto_items([], Spec.coerced(i, J.JArray{S.named_values([], k, [])}, Spec.Each{})), Spec.coerced(i, J.JArray{Spec.values_named([], k)}, Spec.Each{}), ceq(i, J.JArray{S.named_values([], k, [])}, S.PMap{[]}), Equal.trans(J.Json, onto_items([], Spec.coerced(i, J.JArray{S.named_values([], k, [])}, Spec.Each{})), Spec.coerced(i, J.JArray{S.named_values([], k, [])}, Spec.Each{}), Spec.coerced(i, J.JArray{Spec.values_named([], k)}, Spec.Each{}), onto_nil_items(Spec.coerced(i, J.JArray{S.named_values([], k, [])}, Spec.Each{})), Equal.cong(List<&2, J.Json>, J.Json, z => Spec.coerced(i, J.JArray{z}, Spec.Each{}), S.named_values([], k, []), Spec.values_named([], k), values_eq([], k)))))))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(i, J.JObject{[]}, Spec.Merged{k, Spec.coerced(i, J.JArray{Spec.values_named([], k)}, Spec.Each{}), True{}}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(i, J.JObject{[]}, Spec.Merged{k, Spec.coerced(i, J.JArray{Spec.values_named([], k)}, Spec.Each{}), True{}}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(i, J.JObject{J.Field{key, y} <> ft}, S.PGather{k, S.coerce_go(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, S.PMap{[]}), True{}, []}), Spec.coerced(i, J.JObject{J.Field{key, y} <> ft}, Spec.Merged{k, Spec.coerced(i, J.JArray{Spec.values_named(J.Field{key, y} <> ft, k)}, Spec.Each{}), True{}}), Equal.trans(J.Json, S.coerce_go(i, J.JObject{J.Field{key, y} <> ft}, S.PGather{k, S.coerce_go(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, S.PMap{[]}), True{}, []}), onto_members([], Spec.coerced(i, J.JObject{J.Field{key, y} <> ft}, Spec.Merged{k, S.coerce_go(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, S.PMap{[]}), True{}})), Spec.coerced(i, J.JObject{J.Field{key, y} <> ft}, Spec.Merged{k, Spec.coerced(i, J.JArray{Spec.values_named(J.Field{key, y} <> ft, k)}, Spec.Each{}), True{}}), ceq(i, J.JObject{J.Field{key, y} <> ft}, S.PGather{k, S.coerce_go(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, S.PMap{[]}), True{}, []}), Equal.trans(J.Json, onto_members([], Spec.coerced(i, J.JObject{J.Field{key, y} <> ft}, Spec.Merged{k, S.coerce_go(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, S.PMap{[]}), True{}})), Spec.coerced(i, J.JObject{J.Field{key, y} <> ft}, Spec.Merged{k, S.coerce_go(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, S.PMap{[]}), True{}}), Spec.coerced(i, J.JObject{J.Field{key, y} <> ft}, Spec.Merged{k, Spec.coerced(i, J.JArray{Spec.values_named(J.Field{key, y} <> ft, k)}, Spec.Each{}), True{}}), onto_nil_members(Spec.coerced(i, J.JObject{J.Field{key, y} <> ft}, Spec.Merged{k, S.coerce_go(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, S.PMap{[]}), True{}})), Equal.cong(J.Json, J.Json, z => Spec.coerced(i, J.JObject{J.Field{key, y} <> ft}, Spec.Merged{k, z, True{}}), S.coerce_go(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, S.PMap{[]}), Spec.coerced(i, J.JArray{Spec.values_named(J.Field{key, y} <> ft, k)}, Spec.Each{}), Equal.trans(J.Json, S.coerce_go(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, S.PMap{[]}), onto_items([], Spec.coerced(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, Spec.Each{})), Spec.coerced(i, J.JArray{Spec.values_named(J.Field{key, y} <> ft, k)}, Spec.Each{}), ceq(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, S.PMap{[]}), Equal.trans(J.Json, onto_items([], Spec.coerced(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, Spec.Each{})), Spec.coerced(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, Spec.Each{}), Spec.coerced(i, J.JArray{Spec.values_named(J.Field{key, y} <> ft, k)}, Spec.Each{}), onto_nil_items(Spec.coerced(i, J.JArray{S.named_values(J.Field{key, y} <> ft, k, [])}, Spec.Each{})), Equal.cong(List<&2, J.Json>, J.Json, z => Spec.coerced(i, J.JArray{z}, Spec.Each{}), S.named_values(J.Field{key, y} <> ft, k, []), Spec.values_named(J.Field{key, y} <> ft, k), values_eq(J.Field{key, y} <> ft, k)))))))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(i, J.JObject{J.Field{key, y} <> ft}, Spec.Merged{k, Spec.coerced(i, J.JArray{Spec.values_named(J.Field{key, y} <> ft, k)}, Spec.Each{}), True{}}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(i, J.JObject{J.Field{key, y} <> ft}, Spec.Merged{k, Spec.coerced(i, J.JArray{Spec.values_named(J.Field{key, y} <> ft, k)}, Spec.Each{}), True{}}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, y, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, y, S.PValue{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, y, S.PValue{})) <> rev})
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, +m, +n}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.ObjectSchema{S.Field{k, S.ArraySchema{i, m, n}, p} <> t, u}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JNull{} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JNull{} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JBool{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JNumber{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JString{+x} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JString{+x} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{Nil{}} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, h, Spec.Whole{}), Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, h, Spec.Whole{}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, h, Spec.Whole{}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, h, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, h, S.PValue{}) <> rev})
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{Nil{}} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.ObjectSchema{c1, c2}, J.JObject{[]}, S.PEach{k, []}), Spec.coerced(S.ObjectSchema{c1, c2}, J.JObject{[]}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.ObjectSchema{c1, c2}, J.JObject{[]}, S.PEach{k, []}), onto_members([], Spec.coerced(S.ObjectSchema{c1, c2}, J.JObject{[]}, Spec.Members{k})), Spec.coerced(S.ObjectSchema{c1, c2}, J.JObject{[]}, Spec.Members{k}), ceq(S.ObjectSchema{c1, c2}, J.JObject{[]}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.ObjectSchema{c1, c2}, J.JObject{[]}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.ObjectSchema{c1, c2}, J.JObject{[]}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.ObjectSchema{c1, c2}, J.JObject{[]}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.ObjectSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), Spec.coerced(S.ObjectSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.ObjectSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_members([], Spec.coerced(S.ObjectSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})), Spec.coerced(S.ObjectSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), ceq(S.ObjectSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.ObjectSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.ObjectSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.ObjectSchema{c1, c2}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, y, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, y, S.PValue{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, y, S.PValue{})) <> rev})
    case S.ObjectSchema{S.Field{+k, S.ObjectSchema{+c1, +c2}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.ObjectSchema{S.Field{k, S.ObjectSchema{c1, c2}, p} <> t, u}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, h, Spec.Whole{}), Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, h, Spec.Whole{}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, h, Spec.Whole{}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, h, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, h, S.PValue{}) <> rev})
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.NullableSchema{c1}, J.JObject{[]}, S.PEach{k, []}), Spec.coerced(S.NullableSchema{c1}, J.JObject{[]}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.NullableSchema{c1}, J.JObject{[]}, S.PEach{k, []}), onto_members([], Spec.coerced(S.NullableSchema{c1}, J.JObject{[]}, Spec.Members{k})), Spec.coerced(S.NullableSchema{c1}, J.JObject{[]}, Spec.Members{k}), ceq(S.NullableSchema{c1}, J.JObject{[]}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.NullableSchema{c1}, J.JObject{[]}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.NullableSchema{c1}, J.JObject{[]}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.NullableSchema{c1}, J.JObject{[]}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.NullableSchema{c1}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), Spec.coerced(S.NullableSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.NullableSchema{c1}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_members([], Spec.coerced(S.NullableSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})), Spec.coerced(S.NullableSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), ceq(S.NullableSchema{c1}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.NullableSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.NullableSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.NullableSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, y, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, y, S.PValue{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev})
    case S.ObjectSchema{S.Field{+k, S.NullableSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.ObjectSchema{S.Field{k, S.NullableSchema{c1}, p} <> t, u}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, h, Spec.Whole{}), Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, h, Spec.Whole{}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, h, Spec.Whole{}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, h, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JArray{hs}, S.PMap{S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, h, S.PValue{}) <> rev})
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.UnionSchema{c1}, J.JObject{[]}, S.PEach{k, []}), Spec.coerced(S.UnionSchema{c1}, J.JObject{[]}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.UnionSchema{c1}, J.JObject{[]}, S.PEach{k, []}), onto_members([], Spec.coerced(S.UnionSchema{c1}, J.JObject{[]}, Spec.Members{k})), Spec.coerced(S.UnionSchema{c1}, J.JObject{[]}, Spec.Members{k}), ceq(S.UnionSchema{c1}, J.JObject{[]}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.UnionSchema{c1}, J.JObject{[]}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.UnionSchema{c1}, J.JObject{[]}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.UnionSchema{c1}, J.JObject{[]}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}:
      %Equal.sym(J.Json, S.coerce_go(S.UnionSchema{c1}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), Spec.coerced(S.UnionSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Equal.trans(J.Json, S.coerce_go(S.UnionSchema{c1}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_members([], Spec.coerced(S.UnionSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})), Spec.coerced(S.UnionSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), ceq(S.UnionSchema{c1}, J.JObject{J.Field{key, y} <> ft}, S.PEach{k, []}), onto_nil_members(Spec.coerced(S.UnionSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k})))) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, Spec.coerced(S.UnionSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), Spec.Whole{}) : J.Json}
      ceq(S.ObjectSchema{t, u}, Spec.coerced(S.UnionSchema{c1}, J.JObject{J.Field{key, y} <> ft}, Spec.Members{k}), S.PValue{})
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, y, S.PValue{}) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, y, S.PValue{}))) : {S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, y, S.PValue{})) <> rev})
    case S.ObjectSchema{S.Field{+k, S.UnionSchema{+c1}, +p} <> +t, +u} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.ObjectSchema{S.Field{k, S.UnionSchema{c1}, p} <> t, u}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.NullableSchema{+i} J.JNull{} S.PValue{}: ceq(i, J.JNull{}, S.PValue{})
    case S.NullableSchema{+i} J.JNull{} S.PMap{+rev}: {==}
    case S.NullableSchema{+i} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.NullableSchema{+i} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NullableSchema{+i} J.JBool{+b0} S.PValue{}: ceq(i, J.JBool{b0}, S.PValue{})
    case S.NullableSchema{+i} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.NullableSchema{+i} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.NullableSchema{+i} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NullableSchema{+i} J.JNumber{+b0} S.PValue{}: ceq(i, J.JNumber{b0}, S.PValue{})
    case S.NullableSchema{+i} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.NullableSchema{+i} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.NullableSchema{+i} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NullableSchema{+i} J.JString{+x} S.PValue{}: ceq(i, J.JString{x}, S.PValue{})
    case S.NullableSchema{+i} J.JString{+x} S.PMap{+rev}: {==}
    case S.NullableSchema{+i} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.NullableSchema{+i} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NullableSchema{+i} J.JArray{Nil{}} S.PValue{}: ceq(i, J.JArray{Nil{}}, S.PValue{})
    case S.NullableSchema{+i} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.NullableSchema{+i} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.NullableSchema{+i} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NullableSchema{+i} J.JArray{+h <> +hs} S.PValue{}: ceq(i, J.JArray{h <> hs}, S.PValue{})
    case S.NullableSchema{+i} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.NullableSchema{i}, h, Spec.Whole{}), Spec.coerced(S.NullableSchema{i}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.NullableSchema{i}, h, Spec.Whole{}) <> rev, Spec.coerced(S.NullableSchema{i}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.NullableSchema{i}, h, Spec.Whole{}), rev, Spec.coerced(S.NullableSchema{i}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.NullableSchema{i}, J.JArray{hs}, S.PMap{S.coerce_go(S.NullableSchema{i}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.NullableSchema{i}, h, S.PValue{}) : {S.coerce_go(S.NullableSchema{i}, J.JArray{hs}, S.PMap{S.coerce_go(S.NullableSchema{i}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.NullableSchema{i}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.NullableSchema{i}, J.JArray{hs}, S.PMap{S.coerce_go(S.NullableSchema{i}, h, S.PValue{}) <> rev})
    case S.NullableSchema{+i} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.NullableSchema{+i} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NullableSchema{+i} J.JObject{Nil{}} S.PValue{}: ceq(i, J.JObject{Nil{}}, S.PValue{})
    case S.NullableSchema{+i} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.NullableSchema{+i} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.NullableSchema{+i} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.NullableSchema{+i} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}: ceq(i, J.JObject{J.Field{key, y} <> ft}, S.PValue{})
    case S.NullableSchema{+i} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.NullableSchema{+i} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.NullableSchema{i}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.NullableSchema{i}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.NullableSchema{i}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.NullableSchema{i}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.NullableSchema{i}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.NullableSchema{i}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.NullableSchema{i}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.NullableSchema{i}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.NullableSchema{i}, y, S.PValue{}) : {S.coerce_go(S.NullableSchema{i}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.NullableSchema{i}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.NullableSchema{i}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.NullableSchema{i}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.NullableSchema{i}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.NullableSchema{i}, y, S.PValue{}))) : {S.coerce_go(S.NullableSchema{i}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.NullableSchema{i}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.NullableSchema{i}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.NullableSchema{i}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.NullableSchema{i}, y, S.PValue{})) <> rev})
    case S.NullableSchema{+i} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.NullableSchema{i}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.NullableSchema{i}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))
    case S.UnionSchema{+ms} J.JNull{} S.PValue{}: {==}
    case S.UnionSchema{+ms} J.JNull{} S.PMap{+rev}: {==}
    case S.UnionSchema{+ms} J.JNull{} S.PEach{+kk, +rev}: {==}
    case S.UnionSchema{+ms} J.JNull{} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.UnionSchema{+ms} J.JBool{+b0} S.PValue{}: {==}
    case S.UnionSchema{+ms} J.JBool{+b0} S.PMap{+rev}: {==}
    case S.UnionSchema{+ms} J.JBool{+b0} S.PEach{+kk, +rev}: {==}
    case S.UnionSchema{+ms} J.JBool{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.UnionSchema{+ms} J.JNumber{+b0} S.PValue{}: {==}
    case S.UnionSchema{+ms} J.JNumber{+b0} S.PMap{+rev}: {==}
    case S.UnionSchema{+ms} J.JNumber{+b0} S.PEach{+kk, +rev}: {==}
    case S.UnionSchema{+ms} J.JNumber{+b0} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.UnionSchema{+ms} J.JString{+x} S.PValue{}: {==}
    case S.UnionSchema{+ms} J.JString{+x} S.PMap{+rev}: {==}
    case S.UnionSchema{+ms} J.JString{+x} S.PEach{+kk, +rev}: {==}
    case S.UnionSchema{+ms} J.JString{+x} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.UnionSchema{+ms} J.JArray{Nil{}} S.PValue{}: {==}
    case S.UnionSchema{+ms} J.JArray{Nil{}} S.PMap{+rev}: {==}
    case S.UnionSchema{+ms} J.JArray{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.UnionSchema{+ms} J.JArray{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.UnionSchema{+ms} J.JArray{+h <> +hs} S.PValue{}: {==}
    case S.UnionSchema{+ms} J.JArray{+h <> +hs} S.PMap{+rev}:
      %Equal.sym(J.Json, onto_items(rev, Spec.cons_item(Spec.coerced(S.UnionSchema{ms}, h, Spec.Whole{}), Spec.coerced(S.UnionSchema{ms}, J.JArray{hs}, Spec.Each{}))), onto_items(Spec.coerced(S.UnionSchema{ms}, h, Spec.Whole{}) <> rev, Spec.coerced(S.UnionSchema{ms}, J.JArray{hs}, Spec.Each{})), onto_cons_items(Spec.coerced(S.UnionSchema{ms}, h, Spec.Whole{}), rev, Spec.coerced(S.UnionSchema{ms}, J.JArray{hs}, Spec.Each{}))) : {S.coerce_go(S.UnionSchema{ms}, J.JArray{hs}, S.PMap{S.coerce_go(S.UnionSchema{ms}, h, S.PValue{}) <> rev}) == _ : J.Json}
      %ceq(S.UnionSchema{ms}, h, S.PValue{}) : {S.coerce_go(S.UnionSchema{ms}, J.JArray{hs}, S.PMap{S.coerce_go(S.UnionSchema{ms}, h, S.PValue{}) <> rev}) == onto_items(_ <> rev, Spec.coerced(S.UnionSchema{ms}, J.JArray{hs}, Spec.Each{})) : J.Json}
      ceq(S.UnionSchema{ms}, J.JArray{hs}, S.PMap{S.coerce_go(S.UnionSchema{ms}, h, S.PValue{}) <> rev})
    case S.UnionSchema{+ms} J.JArray{+h <> +hs} S.PEach{+kk, +rev}: {==}
    case S.UnionSchema{+ms} J.JArray{+h <> +hs} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.UnionSchema{+ms} J.JObject{Nil{}} S.PValue{}: {==}
    case S.UnionSchema{+ms} J.JObject{Nil{}} S.PMap{+rev}: {==}
    case S.UnionSchema{+ms} J.JObject{Nil{}} S.PEach{+kk, +rev}: {==}
    case S.UnionSchema{+ms} J.JObject{Nil{}} S.PGather{+kk, +g, +f, +rev}: {==}
    case S.UnionSchema{+ms} J.JObject{J.Field{+key, +y} <> +ft} S.PValue{}: {==}
    case S.UnionSchema{+ms} J.JObject{J.Field{+key, +y} <> +ft} S.PMap{+rev}: {==}
    case S.UnionSchema{+ms} J.JObject{J.Field{+key, +y} <> +ft} S.PEach{+kk, +rev}:
      %Equal.sym(J.Json, onto_members(rev, Spec.cons_member(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.UnionSchema{ms}, y, Spec.Whole{})}, J.Field{key, y}), Spec.coerced(S.UnionSchema{ms}, J.JObject{ft}, Spec.Members{kk}))), onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.UnionSchema{ms}, y, Spec.Whole{})}, J.Field{key, y}) <> rev, Spec.coerced(S.UnionSchema{ms}, J.JObject{ft}, Spec.Members{kk})), onto_cons_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, Spec.coerced(S.UnionSchema{ms}, y, Spec.Whole{})}, J.Field{key, y}), rev, Spec.coerced(S.UnionSchema{ms}, J.JObject{ft}, Spec.Members{kk}))) : {S.coerce_go(S.UnionSchema{ms}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.UnionSchema{ms}, y, S.PValue{})) <> rev}) == _ : J.Json}
      %ceq(S.UnionSchema{ms}, y, S.PValue{}) : {S.coerce_go(S.UnionSchema{ms}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.UnionSchema{ms}, y, S.PValue{})) <> rev}) == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, Spec.coerced(S.UnionSchema{ms}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      %Equal.sym(J.Field, Bool.pick(J.Field, String.eq(key, kk), J.Field{key, S.coerce_go(S.UnionSchema{ms}, y, S.PValue{})}, J.Field{key, y}), S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.UnionSchema{ms}, y, S.PValue{})), pick_eq(String.eq(key, kk), key, y, S.coerce_go(S.UnionSchema{ms}, y, S.PValue{}))) : {S.coerce_go(S.UnionSchema{ms}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.UnionSchema{ms}, y, S.PValue{})) <> rev}) == onto_members(_ <> rev, Spec.coerced(S.UnionSchema{ms}, J.JObject{ft}, Spec.Members{kk})) : J.Json}
      ceq(S.UnionSchema{ms}, J.JObject{ft}, S.PEach{kk, S.member_pick(String.eq(key, kk), key, y, S.coerce_go(S.UnionSchema{ms}, y, S.PValue{})) <> rev})
    case S.UnionSchema{+ms} J.JObject{J.Field{+key, +y} <> +ft} S.PGather{+kk, +g, +f, +rev}: gather_eq(S.UnionSchema{ms}, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(S.UnionSchema{ms}, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))

# BND-35 law: text coercion is the specification's coercion.
def coerce_spec(+s: S.Schema, +v: J.Json) -> {S.coerce(s, v) == Spec.coerce_text(s, v) : J.Json}:
  ceq(s, v, S.PValue{})

# Decoding a text source is decoding its specified coercion.
def text_spec(+s: S.Schema, +v: J.Json) -> {S.decode_from(S.TextSource{}, s, v) == S.decode(s, Spec.coerce_text(s, v)) : Result<&2, &2, S.Errors(), S.Value>}:
  %Equal.sym(J.Json, S.coerce(s, v), Spec.coerce_text(s, v), coerce_spec(s, v)) : {S.decode(s, _) == S.decode(s, Spec.coerce_text(s, v)) : Result<&2, &2, S.Errors(), S.Value>}
  {==}

def text_acceptance(+s: S.Schema, +v: J.Json) -> {S.accepted(S.decode_from(S.TextSource{}, s, v)) == Spec.satisfies(s, Spec.coerce_text(s, v)) : Bool}:
  %Equal.sym(Result<&2, &2, S.Errors(), S.Value>, S.decode_from(S.TextSource{}, s, v), S.decode(s, Spec.coerce_text(s, v)), text_spec(s, v)) : {S.accepted(_) == Spec.satisfies(s, Spec.coerce_text(s, v)) : Bool}
  SC.acceptance_spec(s, Spec.coerce_text(s, v))

def text_preservation(+s: S.Schema, +v: J.Json) -> S.Preserves(S.value_for(s, Spec.coerce_text(s, v)), S.decode_from(S.TextSource{}, s, v)):
  %Equal.sym(Result<&2, &2, S.Errors(), S.Value>, S.decode_from(S.TextSource{}, s, v), S.decode(s, Spec.coerce_text(s, v)), text_spec(s, v)) : S.Preserves(S.value_for(s, Spec.coerce_text(s, v)), _)
  SC.preservation(s, Spec.coerce_text(s, v))

def text_located(+s: S.Schema, +v: J.Json) -> {Spec.located_errors(s, Spec.coerce_text(s, v), S.decode_from(S.TextSource{}, s, v)) == True{} : Bool}:
  %Equal.sym(Result<&2, &2, S.Errors(), S.Value>, S.decode_from(S.TextSource{}, s, v), S.decode(s, Spec.coerce_text(s, v)), text_spec(s, v)) : {Spec.located_errors(s, Spec.coerce_text(s, v), _) == True{} : Bool}
  SE.errors_located(s, Spec.coerce_text(s, v))

def text_complete(+s: S.Schema, +v: J.Json, +path: List<&2, S.PathPart>, he: {Spec.error_at(s, Spec.coerce_text(s, v), path) == True{} : Bool}) -> {Spec.reported(S.decode_from(S.TextSource{}, s, v), path) == True{} : Bool}:
  %Equal.sym(Result<&2, &2, S.Errors(), S.Value>, S.decode_from(S.TextSource{}, s, v), S.decode(s, Spec.coerce_text(s, v)), text_spec(s, v)) : {Spec.reported(_, path) == True{} : Bool}
  SE.errors_complete(s, Spec.coerce_text(s, v), path, he)
