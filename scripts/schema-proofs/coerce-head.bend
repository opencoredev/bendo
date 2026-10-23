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
