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

def string_wellformed(+min: Nat, +max: Maybe<&2, Nat>, +p: Maybe<&2, P.Pattern>, +f: S.Format) -> {Spec.keyword(X.go(S.StringSchema{min, max, p, f}, X.start(S.StringSchema{min, max, p, f})), "not") == Some{J.JObject{[J.Field{"pattern", J.JString{Spec.lone()}}]}} : Maybe<&2, J.Json>}:
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

# General accumulator statements end in a forward list of child nodes.
def annotation(+j: J.Json, +p: S.Presence) -> {X.with_default(j, p) == Spec.annotate(j, p) : J.Json}:
  match j p:
    case J.JNull{} p: {==}
    case J.JBool{v} p: {==}
    case J.JNumber{v} p: {==}
    case J.JString{v} p: {==}
    case J.JArray{v} p: {==}
    case J.JObject{v} S.Required{}: {==}
    case J.JObject{v} S.Optional{}: {==}
    case J.JObject{v} S.Default{d}: {==}

def properties_walk(+fs: List<&2, S.Field>, +u: S.Unknown, +rev: List<&2, J.Field>, +req: List<&2, J.Json>) -> {Spec.keyword(X.go(S.ObjectSchema{fs, u}, X.AProps{rev, req}), "properties") == Some{J.JObject{List.reverse.go(&2, J.Field, rev, Spec.properties(~(+c => X.go(c, X.start(c))), fs))}} : Maybe<&2, J.Json>}:
  match fs:
    case Nil{}: {==}
    case S.Field{k, c, p} <> t:
      %annotation(X.go(c, X.start(c)), p) : {Spec.keyword(X.go(S.ObjectSchema{fs, u}, X.AProps{rev, req}), "properties") == Some{J.JObject{List.reverse.go(&2, J.Field, rev, J.Field{k, _} <> Spec.properties(~(+c => X.go(c, X.start(c))), t))}} : Maybe<&2, J.Json>}
      properties_walk(t, u, J.Field{k, X.with_default(X.go(c, X.start(c)), p)} <> rev, req)

def union_node(+xs: List<&2, J.Json>) -> {X.union_json(xs) == Spec.union(xs) : J.Json}:
  match xs:
    case Nil{}: {==}
    case h <> t: {==}

def union_walk(+ms: List<&2, S.Schema>, +rev: List<&2, J.Json>) -> {X.go(S.UnionSchema{ms}, X.AMembers{rev}) == Spec.union(List.reverse.go(&2, J.Json, rev, Spec.nodes(~(+c => X.go(c, X.start(c))), ms))) : J.Json}:
  match ms:
    case Nil{}: union_node(List.reverse(&2, J.Json, rev))
    case m <> t: union_walk(t, X.go(m, X.start(m)) <> rev)

def same(+a: J.Json, +b: J.Json) -> {S.same(a, b) == Spec.same(a, b) : Bool}:
  match a b:
    case J.JNull{} J.JNull{}: {==}
    case J.JNull{} J.JBool{True{}}: {==}
    case J.JNull{} J.JBool{False{}}: {==}
    case J.JNull{} J.JNumber{y}: {==}
    case J.JNull{} J.JString{y}: {==}
    case J.JNull{} J.JArray{y}: {==}
    case J.JNull{} J.JObject{y}: {==}
    case J.JBool{True{}} J.JNull{}: {==}
    case J.JBool{True{}} J.JBool{True{}}: {==}
    case J.JBool{True{}} J.JBool{False{}}: {==}
    case J.JBool{True{}} J.JNumber{y}: {==}
    case J.JBool{True{}} J.JString{y}: {==}
    case J.JBool{True{}} J.JArray{y}: {==}
    case J.JBool{True{}} J.JObject{y}: {==}
    case J.JBool{False{}} J.JNull{}: {==}
    case J.JBool{False{}} J.JBool{True{}}: {==}
    case J.JBool{False{}} J.JBool{False{}}: {==}
    case J.JBool{False{}} J.JNumber{y}: {==}
    case J.JBool{False{}} J.JString{y}: {==}
    case J.JBool{False{}} J.JArray{y}: {==}
    case J.JBool{False{}} J.JObject{y}: {==}
    case J.JNumber{x} J.JNull{}: {==}
    case J.JNumber{x} J.JBool{True{}}: {==}
    case J.JNumber{x} J.JBool{False{}}: {==}
    case J.JNumber{x} J.JNumber{y}: {==}
    case J.JNumber{x} J.JString{y}: {==}
    case J.JNumber{x} J.JArray{y}: {==}
    case J.JNumber{x} J.JObject{y}: {==}
    case J.JString{x} J.JNull{}: {==}
    case J.JString{x} J.JBool{True{}}: {==}
    case J.JString{x} J.JBool{False{}}: {==}
    case J.JString{x} J.JNumber{y}: {==}
    case J.JString{x} J.JString{y}: {==}
    case J.JString{x} J.JArray{y}: {==}
    case J.JString{x} J.JObject{y}: {==}
    case J.JArray{x} J.JNull{}: {==}
    case J.JArray{x} J.JBool{True{}}: {==}
    case J.JArray{x} J.JBool{False{}}: {==}
    case J.JArray{x} J.JNumber{y}: {==}
    case J.JArray{x} J.JString{y}: {==}
    case J.JArray{x} J.JArray{y}: {==}
    case J.JArray{x} J.JObject{y}: {==}
    case J.JObject{x} J.JNull{}: {==}
    case J.JObject{x} J.JBool{True{}}: {==}
    case J.JObject{x} J.JBool{False{}}: {==}
    case J.JObject{x} J.JNumber{y}: {==}
    case J.JObject{x} J.JString{y}: {==}
    case J.JObject{x} J.JArray{y}: {==}
    case J.JObject{x} J.JObject{y}: {==}

def contains(+xs: List<&2, J.Json>, +v: J.Json, +found: Bool) -> {S.one_of(xs, v, found) == Spec.contains(xs, v, found) : Bool}:
  match xs:
    case Nil{}: {==}
    case h <> t:
      %same(h, v) : {S.one_of(xs, v, found) == Spec.contains(t, v, found || _) : Bool}
      contains(t, v, found || S.same(h, v))

def unseen(+b: Bool, +v: J.Json, +rev: List<&2, J.Json>) -> {X.keep(b, v, rev) == Spec.unseen(b, v, rev) : List<&2, J.Json>}:
  match b:
    case True{}: {==}
    case False{}: {==}

def unique(+xs: List<&2, J.Json>, +rev: List<&2, J.Json>) -> {X.distinct_go(xs, rev) == Spec.unique(xs, rev) : List<&2, J.Json>}:
  match xs:
    case Nil{}: {==}
    case h <> t:
      %contains(rev, h, False{}) : {X.distinct_go(xs, rev) == Spec.unique(t, Spec.unseen(_, h, rev)) : List<&2, J.Json>}
      %unseen(S.one_of(rev, h, False{}), h, rev) : {X.distinct_go(xs, rev) == Spec.unique(t, _) : List<&2, J.Json>}
      unique(t, X.keep(S.one_of(rev, h, False{}), h, rev))

def enum_node(+xs: List<&2, J.Json>) -> {X.enum_json(xs) == Spec.enum(xs) : J.Json}:
  match xs:
    case Nil{}: {==}
    case h <> t: {==}

def object_properties(+fields: List<&2, S.Field>, +unknown: S.Unknown) -> {Spec.keyword(X.go(S.ObjectSchema{fields, unknown}, X.start(S.ObjectSchema{fields, unknown})), "properties") == Some{J.JObject{Spec.properties(~(+c => X.go(c, X.start(c))), fields)}} : Maybe<&2, J.Json>}:
  properties_walk(fields, unknown, [], X.required(fields))

def literal_const(+value: J.Json) -> {X.go(S.LiteralSchema{value}, X.start(S.LiteralSchema{value})) == J.JObject{[J.Field{"const", value}]} : J.Json}:
  {==}

def enum_values(+values: List<&2, J.Json>) -> {X.go(S.EnumSchema{values}, X.start(S.EnumSchema{values})) == Spec.enum(Spec.unique(values, [])) : J.Json}:
  %unique(values, []) : {X.enum_json(X.distinct(values)) == Spec.enum(_) : J.Json}
  enum_node(X.distinct(values))

def array_items_bounds(+child: S.Schema, +min: Nat, +max: Maybe<&2, Nat>) -> {X.go(S.ArraySchema{child, min, max}, X.start(S.ArraySchema{child, min, max})) == Spec.array(X.go(child, X.start(child)), min, max) : J.Json}:
  match max:
    case None{}: {==}
    case Some{n}: {==}

def nullable_child(+child: S.Schema) -> {X.go(S.NullableSchema{child}, X.start(S.NullableSchema{child})) == Spec.nullable(X.go(child, X.start(child))) : J.Json}:
  {==}

def union_members(+members: List<&2, S.Schema>) -> {X.go(S.UnionSchema{members}, X.start(S.UnionSchema{members})) == Spec.union(Spec.nodes(~(+c => X.go(c, X.start(c))), members)) : J.Json}:
  union_walk(members, [])

def number_bounds(+min: Maybe<&2, String>, +max: Maybe<&2, String>) -> {X.go(S.NumberSchema{min, max}, X.start(S.NumberSchema{min, max})) == Spec.number("number", min, max, []) : J.Json}:
  match min max:
    case None{} None{}: {==}
    case None{} Some{b}: {==}
    case Some{a} None{}: {==}
    case Some{a} Some{b}: {==}

def integer_bounds(+min: Maybe<&2, String>, +max: Maybe<&2, String>) -> {X.go(S.IntegerSchema{min, max}, X.start(S.IntegerSchema{min, max})) == Spec.number("integer", min, max, [J.Field{"$comment", J.JString{"Bendo accepts only integer tokens -?(0|[1-9][0-9]*); 1.0 and 1e0 are rejected"}}]) : J.Json}:
  match min max:
    case None{} None{}: {==}
    case None{} Some{b}: {==}
    case Some{a} None{}: {==}
    case Some{a} Some{b}: {==}

def string_min_length(+min: Nat, +max: Maybe<&2, Nat>, +pattern: Maybe<&2, P.Pattern>, +format: S.Format) -> {Spec.keyword(X.go(S.StringSchema{min, max, pattern, format}, X.start(S.StringSchema{min, max, pattern, format})), "minLength") == Some{J.JNumber{Nat.show(min)}} : Maybe<&2, J.Json>}:
  match max pattern format:
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

def string_format(+min: Nat, +max: Maybe<&2, Nat>, +pattern: Maybe<&2, P.Pattern>, +format: S.Format) -> {Spec.keyword(X.go(S.StringSchema{min, max, pattern, format}, X.start(S.StringSchema{min, max, pattern, format})), "allOf") == Spec.format(format) : Maybe<&2, J.Json>}:
  match max pattern format:
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

def default_annotation(+fields: List<&2, J.Field>, +presence: S.Presence) -> {X.with_default(J.JObject{fields}, presence) == Spec.annotate(J.JObject{fields}, presence) : J.Json}:
  match presence:
    case S.Required{}: {==}
    case S.Optional{}: {==}
    case S.Default{d}: {==}

def object_no_default(+fs: List<&2, S.Field>, +u: S.Unknown, +rev: List<&2, J.Field>, +req: List<&2, J.Json>) -> {Spec.keyword(X.go(S.ObjectSchema{fs, u}, X.AProps{rev, req}), "default") == None{} : Maybe<&2, J.Json>}:
  match fs:
    case Nil{}: {==}
    case S.Field{k, c, p} <> t: object_no_default(t, u, J.Field{k, X.with_default(X.go(c, X.start(c)), p)} <> rev, req)


def number_no_default(+a: Maybe<&2, String>, +b: Maybe<&2, String>) -> {Spec.keyword(X.go(S.NumberSchema{a, b}, X.AHere{}), "default") == None{} : Maybe<&2, J.Json>}:
  match a b:
    case None{} None{}: {==}
    case None{} Some{y}: {==}
    case Some{x} None{}: {==}
    case Some{x} Some{y}: {==}

def integer_no_default(+a: Maybe<&2, String>, +b: Maybe<&2, String>) -> {Spec.keyword(X.go(S.IntegerSchema{a, b}, X.AHere{}), "default") == None{} : Maybe<&2, J.Json>}:
  match a b:
    case None{} None{}: {==}
    case None{} Some{y}: {==}
    case Some{x} None{}: {==}
    case Some{x} Some{y}: {==}

def array_no_default(+i: S.Schema, +a: Nat, +b: Maybe<&2, Nat>) -> {Spec.keyword(X.go(S.ArraySchema{i, a, b}, X.AHere{}), "default") == None{} : Maybe<&2, J.Json>}:
  match b:
    case None{}: {==}
    case Some{n}: {==}

def string_no_default(+a: Nat, +b: Maybe<&2, Nat>, +c: Maybe<&2, P.Pattern>, +d: S.Format) -> {Spec.keyword(X.go(S.StringSchema{a, b, c, d}, X.AHere{}), "default") == None{} : Maybe<&2, J.Json>}:
  match b c d:
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

def union_json_no_default(+xs: List<&2, J.Json>) -> {Spec.keyword(X.union_json(xs), "default") == None{} : Maybe<&2, J.Json>}:
  match xs:
    case Nil{}: {==}
    case h <> t: {==}

def union_no_default(+ms: List<&2, S.Schema>, +rev: List<&2, J.Json>) -> {Spec.keyword(X.go(S.UnionSchema{ms}, X.AMembers{rev}), "default") == None{} : Maybe<&2, J.Json>}:
  match ms:
    case Nil{}: union_json_no_default(List.reverse(&2, J.Json, rev))
    case m <> t: union_no_default(t, X.go(m, X.start(m)) <> rev)

def enum_no_default(+xs: List<&2, J.Json>) -> {Spec.keyword(X.enum_json(xs), "default") == None{} : Maybe<&2, J.Json>}:
  match xs:
    case Nil{}: {==}
    case h <> t: {==}

def no_default(+s: S.Schema) -> {Spec.keyword(X.go(s, X.start(s)), "default") == None{} : Maybe<&2, J.Json>}:
  match s:
    case S.StringSchema{a, b, c, d}: string_no_default(a, b, c, d)
    case S.NumberSchema{a, b}: number_no_default(a, b)
    case S.IntegerSchema{a, b}: integer_no_default(a, b)
    case S.BooleanSchema{}: {==}
    case S.LiteralSchema{v}: {==}
    case S.EnumSchema{xs}: enum_no_default(X.distinct(xs))
    case S.ArraySchema{i, a, b}: array_no_default(i, a, b)
    case S.ObjectSchema{fs, u}: object_no_default(fs, u, [], X.required(fs))
    case S.NullableSchema{i}: {==}
    case S.UnionSchema{ms}: union_no_default(ms, [])

def dialect_document(+j: J.Json) -> {X.with_dialect(j) == Spec.document(j) : J.Json}:
  match j:
    case J.JNull{}: {==}
    case J.JBool{v}: {==}
    case J.JNumber{v}: {==}
    case J.JString{v}: {==}
    case J.JArray{v}: {==}
    case J.JObject{fs}: {==}

def document_dialect(+s: S.Schema) -> {X.document(s) == Spec.document(X.export(s)) : J.Json}:
  dialect_document(X.export(s))

def object_node(+props: List<&2, J.Field>, +req: List<&2, J.Json>, +u: S.Unknown) -> {X.object_json(props, req, u) == Spec.object(props, req, u) : J.Json}:
  match u:
    case S.Strict{}: {==}
    case S.Strip{}: {==}

def whole_object_walk(+fs: List<&2, S.Field>, +u: S.Unknown, +rev: List<&2, J.Field>, +req: List<&2, J.Json>) -> {X.go(S.ObjectSchema{fs, u}, X.AProps{rev, req}) == Spec.object(List.reverse.go(&2, J.Field, rev, Spec.properties(~(+c => X.go(c, X.start(c))), fs)), req, u) : J.Json}:
  match fs:
    case Nil{}: object_node(List.reverse(&2, J.Field, rev), req, u)
    case S.Field{k, c, p} <> t:
      %annotation(X.go(c, X.start(c)), p) : {X.go(S.ObjectSchema{fs, u}, X.AProps{rev, req}) == Spec.object(List.reverse.go(&2, J.Field, rev, J.Field{k, _} <> Spec.properties(~(+c => X.go(c, X.start(c))), t)), req, u) : J.Json}
      whole_object_walk(t, u, J.Field{k, X.with_default(X.go(c, X.start(c)), p)} <> rev, req)

def object_node_exact(+fields: List<&2, S.Field>, +unknown: S.Unknown) -> {X.go(S.ObjectSchema{fields, unknown}, X.start(S.ObjectSchema{fields, unknown})) == Spec.object(Spec.properties(~(+c => X.go(c, X.start(c))), fields), Spec.required(fields), unknown) : J.Json}:
  %required(fields) : {X.go(S.ObjectSchema{fields, unknown}, X.start(S.ObjectSchema{fields, unknown})) == Spec.object(Spec.properties(~(+c => X.go(c, X.start(c))), fields), _, unknown) : J.Json}
  whole_object_walk(fields, unknown, [], X.required(fields))

def string_node_exact(+min: Nat, +max: Maybe<&2, Nat>, +pattern: Maybe<&2, P.Pattern>, +format: S.Format) -> {X.go(S.StringSchema{min, max, pattern, format}, X.start(S.StringSchema{min, max, pattern, format})) == Spec.string(min, max, pattern, format) : J.Json}:
  match max pattern format:
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
