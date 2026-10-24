# Proofs of the BND-37 JSON Schema export laws. Objects and unions are walked
# with an accumulator, so each walk gets an induction over its list.
import Base
import ../src/data/json.bend as J
import ../src/data/schema.bend as S
import ../src/data/schema-pattern.bend as P
import ../src/data/json-schema.bend as X
import ./json-schema-spec.bend as Spec

def invalid_export(+s: S.Schema, bad: {S.valid(s) == False{} : Bool}) -> {X.export(s) == X.invalid() : J.Json}:
  %Equal.sym(Bool, S.valid(s), False{}, bad) : {X.gated(s, _) == X.invalid() : J.Json}
  {==}

def invalid_rejects_all(+s: S.Schema, bad: {S.valid(s) == False{} : Bool}) -> {Spec.keyword(X.export(s), "not") == Some{J.JObject{[]}} : Maybe<&2, J.Json>}:
  %Equal.sym(J.Json, X.export(s), X.invalid(), invalid_export(s, bad)) : {Spec.keyword(_, "not") == Some{J.JObject{[]}} : Maybe<&2, J.Json>}
  {==}

def valid_export(+s: S.Schema, ok: {S.valid(s) == True{} : Bool}) -> {X.export(s) == X.go(s, X.start(s)) : J.Json}:
  %Equal.sym(Bool, S.valid(s), True{}, ok) : {X.gated(s, _) == X.go(s, X.start(s)) : J.Json}
  {==}

# The object walk ends in object_json whatever the accumulated properties.
def object_type(+fs: List<&2, S.Field>, +u: S.Unknown, +rev: List<&2, J.Field>, +req: List<&2, J.Json>) -> {Spec.keyword(X.go(S.ObjectSchema{fs, u}, X.AProps{rev, req}), "type") == Some{J.JString{"object"}} : Maybe<&2, J.Json>}:
  match fs:
    case Nil{}: {==}
    case S.Field{k, c, p} <> t: object_type(t, u, J.Field{k, X.with_default(X.go(c, X.start(c)), p)} <> rev, req)

def object_required(+fs: List<&2, S.Field>, +u: S.Unknown, +rev: List<&2, J.Field>, +req: List<&2, J.Json>) -> {Spec.keyword(X.go(S.ObjectSchema{fs, u}, X.AProps{rev, req}), "required") == Some{J.JArray{req}} : Maybe<&2, J.Json>}:
  match fs:
    case Nil{}: {==}
    case S.Field{k, c, p} <> t: object_required(t, u, J.Field{k, X.with_default(X.go(c, X.start(c)), p)} <> rev, req)

def object_unknown(+fs: List<&2, S.Field>, +u: S.Unknown, +rev: List<&2, J.Field>, +req: List<&2, J.Json>) -> {Spec.keyword(X.go(S.ObjectSchema{fs, u}, X.AProps{rev, req}), "additionalProperties") == Some{J.JBool{X.open(u)}} : Maybe<&2, J.Json>}:
  match fs:
    case Nil{}: {==}
    case S.Field{k, c, p} <> t: object_unknown(t, u, J.Field{k, X.with_default(X.go(c, X.start(c)), p)} <> rev, req)

def union_json_type(+xs: List<&2, J.Json>) -> {Spec.keyword(X.union_json(xs), "type") == None{} : Maybe<&2, J.Json>}:
  match xs:
    case Nil{}: {==}
    case h <> t: {==}

def union_type(+ms: List<&2, S.Schema>, +rev: List<&2, J.Json>) -> {Spec.keyword(X.go(S.UnionSchema{ms}, X.AMembers{rev}), "type") == None{} : Maybe<&2, J.Json>}:
  match ms:
    case Nil{}: union_json_type(List.reverse(&2, J.Json, rev))
    case m <> t: union_type(t, X.go(m, X.start(m)) <> rev)

def enum_type(+xs: List<&2, J.Json>) -> {Spec.keyword(X.enum_json(xs), "type") == None{} : Maybe<&2, J.Json>}:
  match xs:
    case Nil{}: {==}
    case h <> t: {==}

def type_keyword(+s: S.Schema) -> {Spec.keyword(X.go(s, X.start(s)), "type") == Spec.type_of(s) : Maybe<&2, J.Json>}:
  match s:
    case S.StringSchema{a, b, c, d}: {==}
    case S.NumberSchema{a, b}: {==}
    case S.IntegerSchema{a, b}: {==}
    case S.BooleanSchema{}: {==}
    case S.LiteralSchema{v}: {==}
    case S.EnumSchema{xs}: enum_type(X.distinct(xs))
    case S.ArraySchema{i, a, b}: {==}
    case S.ObjectSchema{fs, u}: object_type(fs, u, [], X.required(fs))
    case S.NullableSchema{i}: {==}
    case S.UnionSchema{ms}: union_type(ms, [])

def required_one(+k: String, +p: S.Presence, +rest: List<&2, J.Json>) -> {X.required_one(k, p, rest) == Spec.keep(Spec.is_required(p), J.JString{k}, rest) : List<&2, J.Json>}:
  match p:
    case S.Required{}: {==}
    case S.Optional{}: {==}
    case S.Default{d}: {==}

def required(+fs: List<&2, S.Field>) -> {X.required(fs) == Spec.required(fs) : List<&2, J.Json>}:
  match fs:
    case Nil{}: {==}
    case S.Field{k, c, p} <> t:
      %required(t) : {X.required_one(k, p, X.required(t)) == Spec.keep(Spec.is_required(p), J.JString{k}, _) : List<&2, J.Json>}
      required_one(k, p, X.required(t))

def required_keys(+fs: List<&2, S.Field>, +u: S.Unknown) -> {Spec.keyword(X.go(S.ObjectSchema{fs, u}, X.start(S.ObjectSchema{fs, u})), "required") == Some{J.JArray{Spec.required(fs)}} : Maybe<&2, J.Json>}:
  %required(fs) : {Spec.keyword(X.go(S.ObjectSchema{fs, u}, X.AProps{[], X.required(fs)}), "required") == Some{J.JArray{_}} : Maybe<&2, J.Json>}
  object_required(fs, u, [], X.required(fs))

def open(+u: S.Unknown) -> {X.open(u) == Spec.allows_unknown(u) : Bool}:
  match u:
    case S.Strict{}: {==}
    case S.Strip{}: {==}

def unknown_keys(+fs: List<&2, S.Field>, +u: S.Unknown) -> {Spec.keyword(X.go(S.ObjectSchema{fs, u}, X.start(S.ObjectSchema{fs, u})), "additionalProperties") == Some{J.JBool{Spec.allows_unknown(u)}} : Maybe<&2, J.Json>}:
  %open(u) : {Spec.keyword(X.go(S.ObjectSchema{fs, u}, X.AProps{[], X.required(fs)}), "additionalProperties") == Some{J.JBool{_}} : Maybe<&2, J.Json>}
  object_unknown(fs, u, [], X.required(fs))

def string_pattern(+min: Nat, +max: Maybe<&2, Nat>, +p: Maybe<&2, P.Pattern>, +f: S.Format) -> {Spec.keyword(X.go(S.StringSchema{min, max, p, f}, X.start(S.StringSchema{min, max, p, f})), "pattern") == Spec.pattern_of(p) : Maybe<&2, J.Json>}:
  match max p f:
    case None{} None{} S.Plain{}: {==}
    case None{} None{} S.Email{}: {==}
    case None{} None{} S.Url{}: {==}
    case None{} Some{x} S.Plain{}: {==}
    case None{} Some{x} S.Email{}: {==}
    case None{} Some{x} S.Url{}: {==}
    case Some{n} None{} S.Plain{}: {==}
    case Some{n} None{} S.Email{}: {==}
    case Some{n} None{} S.Url{}: {==}
    case Some{n} Some{x} S.Plain{}: {==}
    case Some{n} Some{x} S.Email{}: {==}
    case Some{n} Some{x} S.Url{}: {==}

def string_lengths(+min: Nat, +max: Maybe<&2, Nat>, +p: Maybe<&2, P.Pattern>, +f: S.Format) -> {Spec.keyword(X.go(S.StringSchema{min, max, p, f}, X.start(S.StringSchema{min, max, p, f})), "maxLength") == Spec.upper_of(max) : Maybe<&2, J.Json>}:
  match max p f:
    case None{} None{} S.Plain{}: {==}
    case None{} None{} S.Email{}: {==}
    case None{} None{} S.Url{}: {==}
    case None{} Some{x} S.Plain{}: {==}
    case None{} Some{x} S.Email{}: {==}
    case None{} Some{x} S.Url{}: {==}
    case Some{n} p f: {==}

def string_wellformed(+min: Nat, +max: Maybe<&2, Nat>, +p: Maybe<&2, P.Pattern>, +f: S.Format) -> {Spec.keyword(X.go(S.StringSchema{min, max, p, f}, X.start(S.StringSchema{min, max, p, f})), "not") == Some{J.JObject{[J.Field{"pattern", J.JString{X.lone()}}]}} : Maybe<&2, J.Json>}:
  match max p f:
    case None{} None{} S.Plain{}: {==}
    case None{} None{} S.Email{}: {==}
    case None{} None{} S.Url{}: {==}
    case None{} Some{x} S.Plain{}: {==}
    case None{} Some{x} S.Email{}: {==}
    case None{} Some{x} S.Url{}: {==}
    case Some{n} None{} S.Plain{}: {==}
    case Some{n} None{} S.Email{}: {==}
    case Some{n} None{} S.Url{}: {==}
    case Some{n} Some{x} S.Plain{}: {==}
    case Some{n} Some{x} S.Email{}: {==}
    case Some{n} Some{x} S.Url{}: {==}
