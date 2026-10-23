# Copyable schema metadata and pure native/browser decoder (decision 0003).
import Base
import ./json.bend as J
import ./decimal.bend as D
import ./schema-text.bend as T
import ./schema-pattern.bend as P
import ./schema-pattern-automaton.bend as A

type Format is Data:
  Plain{}
  Email{}
  Url{}

# What an object does with a key its schema does not declare.
type Unknown is Data:
  Strict{}
  Strip{}

# Whether a declared key must be present. JSON has no undefined value, so
# optionality belongs to an object's field rather than to a schema.
type Presence is Data:
  Required{}
  Optional{}

type Schema is Data:
  StringSchema{min_len: Nat, max_len: Maybe<&2, Nat>, pattern: Maybe<&2, P.Pattern>, format: Format}
  NumberSchema{min: Maybe<&2, String>, max: Maybe<&2, String>}
  IntegerSchema{min: Maybe<&2, String>, max: Maybe<&2, String>}
  BooleanSchema{}
  LiteralSchema{value: J.Json}
  EnumSchema{values: List<&2, J.Json>}
  ArraySchema{items: Schema, min_items: Nat, max_items: Maybe<&2, Nat>}
  ObjectSchema{fields: List<&2, Field>, unknown: Unknown}
  NullableSchema{inner: Schema}
  UnionSchema{members: List<&2, Schema>}

type Field is Data:
  Field{key: String, schema: Schema, presence: Presence}

type Value is Data:
  VString{value: String}
  VNumber{value: String}
  VInteger{value: String}
  VBool{value: Bool}
  VLiteral{value: J.Json}
  VNull{}
  VArray{items: List<&2, Value>}
  VObject{fields: List<&2, VField>}
  VUnion{index: Nat, value: Value}

# One declared field in schema order; None when an optional key is absent.
type VField is Data:
  VField{key: String, value: Maybe<&2, Value>}

type PathPart is Data:
  PathKey{value: String}
  PathIndex{value: Nat}

type Code is Data:
  InvalidSchema{}
  TypeMismatch{}
  Constraint{}

type Error is Data:
  Error{code: Code, message: String, path: List<&2, PathPart>}

def Errors() -> Data:
  List<&2, Error>

def max_length(limit: Maybe<&2, Nat>, n: Nat) -> Bool:
  match limit:
    case None{}: True{}
    case Some{k}: Nat.is_le(n, k)

def pattern_check(p: Maybe<&2, P.Pattern>, s: String) -> Bool:
  match p:
    case None{}: True{}
    case Some{x}: A.matches(x, s)

def optional_pattern_valid(p: Maybe<&2, P.Pattern>) -> Bool:
  match p:
    case None{}: True{}
    case Some{x}: P.valid(x)

def format_check(f: Format, s: String) -> Bool:
  match f:
    case Plain{}: True{}
    case Email{}: T.email(s)
    case Url{}: T.url(s)

def format_after(ok: Bool, f: Format, s: String) -> Bool:
  match ok:
    case False{}: False{}
    case True{}: format_check(f, s)

def pattern_after(ok: Bool, p: Maybe<&2, P.Pattern>, f: Format, +s: String) -> Bool:
  match ok:
    case False{}: False{}
    case True{}: format_after(pattern_check(p, s), f, s)

# Cheapest first, each step only after the last passed: a text that fails
# its counts never reaches the matcher, and one that fails the pattern never
# reaches the format grammar.
def string_check(min: Nat, max: Maybe<&2, Nat>, p: Maybe<&2, P.Pattern>, f: Format, +s: String) -> Bool:
  pattern_after(J.scalars(s) && Nat.is_le(min, D.length(s)) && max_length(max, D.length(s)), p, f, s)

def bound_valid(b: Maybe<&2, String>) -> Bool:
  match b:
    case None{}: True{}
    case Some{s}: J.number_valid(s)

def lower(b: Maybe<&2, String>, s: String) -> Bool:
  match b:
    case None{}: True{}
    case Some{v}: Cmp.is_ge(D.order(s, v))

def upper(b: Maybe<&2, String>, s: String) -> Bool:
  match b:
    case None{}: True{}
    case Some{v}: Cmp.is_le(D.order(s, v))

def bounds_order(min: Maybe<&2, String>, max: Maybe<&2, String>) -> Bool:
  match min max:
    case Some{a} Some{b}: Cmp.is_le(D.order(a, b))
    case _ _: True{}

def bounds_valid(+min: Maybe<&2, String>, +max: Maybe<&2, String>) -> Bool:
  bound_valid(min) && bound_valid(max) && bounds_order(min, max)

def number_check(min: Maybe<&2, String>, max: Maybe<&2, String>, +s: String) -> Bool:
  J.number_valid(s) && lower(min, s) && upper(max, s)

def scalar(v: J.Json) -> Bool:
  match v:
    case J.JNull{}: True{}
    case J.JBool{b}: True{}
    case J.JString{s}: J.scalars(s)
    case J.JNumber{s}: J.number_valid(s)
    case _: False{}

def literals_valid(xs: List<&2, J.Json>, ok: Bool) -> Bool:
  match xs:
    case Nil{}: ok
    case h <> t: literals_valid(t, ok && scalar(h))

# JSON const/enum equality: exact numerical equality, lexical text equality.
def same(a: J.Json, b: J.Json) -> Bool:
  match a b:
    case J.JNull{} J.JNull{}: True{}
    case J.JBool{True{}} J.JBool{y}: y
    case J.JBool{False{}} J.JBool{y}: Bool.not(y)
    case J.JString{x} J.JString{y}: String.eq(x, y)
    case J.JNumber{x} J.JNumber{y}: Cmp.is_eq(D.order(x, y))
    case _ _: False{}

def one_of(xs: List<&2, J.Json>, +v: J.Json, found: Bool) -> Bool:
  match xs:
    case Nil{}: found
    case h <> t: one_of(t, v, found || same(h, v))

def declared(fs: List<&2, Field>, +k: String) -> Bool:
  match fs:
    case Nil{}: False{}
    case Field{key, c, p} <> t: String.eq(key, k) || declared(t, k)

# The schema tree is the app's own data, so this walks it without accumulators.
def valid(s: Schema) -> Bool:
  match s:
    case StringSchema{min, max, p, f}: max_length(max, min) && optional_pattern_valid(p)
    case NumberSchema{min, max}: bounds_valid(min, max)
    case IntegerSchema{min, max}: bounds_valid(min, max)
    case BooleanSchema{}: True{}
    case LiteralSchema{v}: scalar(v)
    case EnumSchema{xs}: literals_valid(xs, True{})
    case ArraySchema{i, +min, max}: max_length(max, min) && valid(i)
    case ObjectSchema{Nil{}, u}: True{}
    case ObjectSchema{Field{+k, c, p} <> +t, u}: J.scalars(k) && Bool.not(declared(t, k)) && valid(c) && valid(ObjectSchema{t, u})
    case NullableSchema{i}: valid(i)
    case UnionSchema{Nil{}}: True{}
    case UnionSchema{m <> t}: valid(m) && valid(UnionSchema{t})

def failure(code: Code, message: String) -> Result<&2, &2, Errors(), Value>:
  Fail{[Error{code, message, []}]}

def finish(v: Value, accepted: Bool) -> Result<&2, &2, Errors(), Value>:
  match accepted:
    case True{}: Done{v}
    case False{}: failure(Constraint{}, "value does not satisfy scalar checks")

def decode_scalar(s: Schema, v: J.Json) -> Result<&2, &2, Errors(), Value>:
  match s v:
    case StringSchema{min, max, p, f} J.JString{+x}: finish(VString{x}, string_check(min, max, p, f, x))
    case NumberSchema{min, max} J.JNumber{+x}: finish(VNumber{x}, number_check(min, max, x))
    case IntegerSchema{min, max} J.JNumber{+x}: finish(VInteger{x}, D.is_integer(x) && number_check(min, max, x))
    case BooleanSchema{} J.JBool{x}: Done{VBool{x}}
    case LiteralSchema{x} +y: finish(VLiteral{y}, scalar(y) && same(x, y))
    case EnumSchema{xs} +y: finish(VLiteral{y}, scalar(y) && one_of(xs, y, False{}))
    case _ _: failure(TypeMismatch{}, "expected schema scalar kind")

# Compound decoding. One def walks the schema and the input together; its
# third argument carries the progress through an array, an object or a union.
# Every recursive call either descends into a child schema or continues the
# same schema on a shorter list, so loops over attacker-sized lists are tail
# calls and the call depth is bounded by the schema's own depth.

# Members named by one declared key: none, one, or more (the first is kept).
type Slot is Data:
  Absent{}
  Once{value: J.Json}
  Repeated{first: J.Json}

type Acc is Data:
  AScalar{}
  AItems{index: Nat, state: Result<&2, &2, List<&2, Error>, List<&2, Value>>}
  AFields{state: Result<&2, &2, List<&2, Error>, List<&2, VField>>, slots: List<&2, Slot>}
  AMembers{next: Nat, index: Nat, state: Result<&2, &2, List<&2, Error>, Value>}

def count(xs: List<&2, J.Json>, n: Nat) -> Nat:
  match xs:
    case Nil{}: n
    case h <> t: count(t, 1n+n)

def found(same: Bool, acc: Slot, y: J.Json) -> Slot:
  match same acc:
    case False{} a: a
    case True{} Absent{}: Once{y}
    case True{} Once{x}: Repeated{x}
    case True{} Repeated{x}: Repeated{x}

# One pass over the members, stopping at a second occurrence.
def find(input: List<&2, J.Field>, +k: String, acc: Slot) -> Slot:
  match input acc:
    case _ Repeated{x}: Repeated{x}
    case Nil{} a: a
    case J.Field{key, y} <> t a: find(t, k, found(String.eq(key, k), a, y))

def slots(fs: List<&2, Field>, +input: List<&2, J.Field>) -> List<&2, Slot>:
  match fs:
    case Nil{}: []
    case Field{k, c, p} <> t: find(input, k, Absent{}) <> slots(t, input)

def known_go(input: List<&2, J.Field>, +fs: List<&2, Field>, ok: Bool) -> Bool:
  match input ok:
    case _ False{}: False{}
    case Nil{} True{}: True{}
    case J.Field{k, v} <> t True{}: known_go(t, fs, declared(fs, k))

def known(u: Unknown, fs: List<&2, Field>, input: List<&2, J.Field>) -> Bool:
  match u:
    case Strict{}: known_go(input, fs, True{})
    case Strip{}: True{}

def items_gate(ok: Bool) -> Result<&2, &2, Errors(), List<&2, Value>>:
  match ok:
    case True{}: Done{[]}
    case False{}: Fail{[Error{Constraint{}, "array length out of bounds", []}]}

def fields_gate(ok: Bool) -> Result<&2, &2, Errors(), List<&2, VField>>:
  match ok:
    case True{}: Done{[]}
    case False{}: Fail{[Error{Constraint{}, "object has an undeclared key", []}]}

def item_count(+min: Nat, max: Maybe<&2, Nat>, +n: Nat) -> Bool:
  Nat.is_le(min, n) && max_length(max, n)

def start(s: Schema, v: J.Json) -> Acc:
  match s v:
    case ArraySchema{i, min, max} J.JArray{xs}: AItems{0n, items_gate(item_count(min, max, count(xs, 0n)))}
    case ObjectSchema{+fs, u} J.JObject{+input}: AFields{fields_gate(known(u, fs, input)), slots(fs, input)}
    case UnionSchema{ms} x: AMembers{0n, 0n, Fail{[]}}
    case _ _: AScalar{}

def prefix(+part: PathPart, es: List<&2, Error>) -> List<&2, Error>:
  match es:
    case Nil{}: []
    case Error{c, m, path} <> t: Error{c, m, part <> path} <> prefix(part, t)

def at(part: PathPart, r: Result<&2, &2, Errors(), Value>) -> Result<&2, &2, Errors(), Value>:
  match r:
    case Fail{e}: Fail{prefix(part, e)}
    case Done{x}: Done{x}

def push(rev: List<&2, Value>, r: Result<&2, &2, Errors(), Value>) -> Result<&2, &2, Errors(), List<&2, Value>>:
  match r:
    case Fail{e}: Fail{e}
    case Done{x}: Done{x <> rev}

def push_field(rev: List<&2, VField>, k: String, r: Result<&2, &2, Errors(), Value>) -> Result<&2, &2, Errors(), List<&2, VField>>:
  match r:
    case Fail{e}: Fail{e}
    case Done{x}: Done{VField{k, Some{x}} <> rev}

def absent(rev: List<&2, VField>, +k: String, p: Presence) -> Result<&2, &2, Errors(), List<&2, VField>>:
  match p:
    case Optional{}: Done{VField{k, None{}} <> rev}
    case Required{}: Fail{[Error{Constraint{}, "missing required key", [PathKey{k}]}]}

def decode_go(s: Schema, v: J.Json, acc: Acc) -> Result<&2, &2, Errors(), Value>:
  match s v acc:
    case StringSchema{a, b, c, d} x y: decode_scalar(StringSchema{a, b, c, d}, x)
    case NumberSchema{a, b} x y: decode_scalar(NumberSchema{a, b}, x)
    case IntegerSchema{a, b} x y: decode_scalar(IntegerSchema{a, b}, x)
    case BooleanSchema{} x y: decode_scalar(BooleanSchema{}, x)
    case LiteralSchema{a} x y: decode_scalar(LiteralSchema{a}, x)
    case EnumSchema{a} x y: decode_scalar(EnumSchema{a}, x)
    case ArraySchema{i, m, n} _ AItems{k, Fail{e}}: Fail{e}
    case ArraySchema{i, m, n} J.JArray{Nil{}} AItems{k, Done{rev}}: Done{VArray{List.reverse(&2, Value, rev)}}
    case ArraySchema{+i, +m, +n} J.JArray{+h <> t} AItems{+k, Done{rev}}: decode_go(ArraySchema{i, m, n}, J.JArray{t}, AItems{1n+k, push(rev, at(PathIndex{k}, decode_go(i, h, start(i, h))))})
    case ObjectSchema{fs, u} _ AFields{Fail{e}, ss}: Fail{e}
    case ObjectSchema{Nil{}, u} _ AFields{Done{rev}, ss}: Done{VObject{List.reverse(&2, VField, rev)}}
    case ObjectSchema{Field{+k, +c, p} <> t, u} x AFields{Done{rev}, Once{+y} <> rest}: decode_go(ObjectSchema{t, u}, x, AFields{push_field(rev, k, at(PathKey{k}, decode_go(c, y, start(c, y)))), rest})
    case ObjectSchema{Field{k, c, p} <> t, u} x AFields{Done{rev}, Absent{} <> rest}: decode_go(ObjectSchema{t, u}, x, AFields{absent(rev, k, p), rest})
    case ObjectSchema{Field{k, c, p} <> t, u} x AFields{Done{rev}, Repeated{y} <> rest}: Fail{[Error{Constraint{}, "duplicate key", [PathKey{k}]}]}
    case ObjectSchema{f <> t, u} x AFields{Done{rev}, Nil{}}: failure(InvalidSchema{}, "object fields out of step")
    case NullableSchema{+i} J.JNull{} y: Done{VNull{}}
    case NullableSchema{+i} +x y: decode_go(i, x, start(i, x))
    case UnionSchema{ms} x AMembers{n, i, Done{y}}: Done{VUnion{i, y}}
    case UnionSchema{Nil{}} x AMembers{n, i, Fail{e}}: failure(Constraint{}, "value matches no union member")
    case UnionSchema{+m <> t} +x AMembers{+n, i, Fail{e}}: decode_go(UnionSchema{t}, x, AMembers{1n+n, n, decode_go(m, x, start(m, x))})
    case _ _ _: failure(TypeMismatch{}, "expected schema kind")

def decode_valid(+s: Schema, +v: J.Json, schema_ok: Bool) -> Result<&2, &2, Errors(), Value>:
  match schema_ok:
    case True{}: decode_go(s, v, start(s, v))
    case False{}: failure(InvalidSchema{}, "invalid schema")

def decode(+s: Schema, v: J.Json) -> Result<&2, &2, Errors(), Value>:
  decode_valid(s, v, valid(s))

def accepted(r: Result<&2, &2, Errors(), Value>) -> Bool:
  match r:
    case Fail{e}: False{}
    case Done{x}: True{}

# Rebuilds the JSON a value came from: absent fields are omitted, a union
# value becomes its member's JSON, and stripped unknown keys stay dropped.
def to_json_go(v: Value, rev: List<&2, J.Json>, frev: List<&2, J.Field>) -> J.Json:
  match v:
    case VString{x}: J.JString{x}
    case VNumber{x}: J.JNumber{x}
    case VInteger{x}: J.JNumber{x}
    case VBool{x}: J.JBool{x}
    case VLiteral{x}: x
    case VNull{}: J.JNull{}
    case VUnion{i, x}: to_json_go(x, [], [])
    case VArray{Nil{}}: J.JArray{List.reverse(&2, J.Json, rev)}
    case VArray{h <> t}: to_json_go(VArray{t}, to_json_go(h, [], []) <> rev, frev)
    case VObject{Nil{}}: J.JObject{List.reverse(&2, J.Field, frev)}
    case VObject{VField{k, None{}} <> t}: to_json_go(VObject{t}, rev, frev)
    case VObject{VField{k, Some{x}} <> t}: to_json_go(VObject{t}, rev, J.Field{k, to_json_go(x, [], [])} <> frev)

def to_json(v: Value) -> J.Json:
  to_json_go(v, [], [])

# Independent shape/payload contract used by the preservation law. Scalars
# carry their input. An array carries each item's value in order. An object
# carries each declared field in schema order: the value of the first member
# with that key, or None when there is none. A union carries the position of
# the first member that `decode` accepts and that member's value. Nothing
# here checks a constraint; `decode` must still reach exactly this value.
def first(input: List<&2, J.Field>, +k: String) -> Maybe<&2, J.Json>:
  match input:
    case Nil{}: None{}
    case J.Field{key, y} <> t: Bool.pick(Maybe<&2, J.Json>, String.eq(key, k), Some{y}, first(t, k))

def or_null(m: Maybe<&2, J.Json>) -> J.Json:
  match m:
    case None{}: J.JNull{}
    case Some{y}: y

def field_value(k: String, found: Maybe<&2, J.Json>, value: Maybe<&2, Value>) -> Maybe<&2, VField>:
  match found value:
    case None{} _: Some{VField{k, None{}}}
    case Some{y} Some{x}: Some{VField{k, Some{x}}}
    case Some{y} None{}: None{}

def cons_field(f: Maybe<&2, VField>, rest: Maybe<&2, Value>) -> Maybe<&2, Value>:
  match f rest:
    case Some{x} Some{VObject{xs}}: Some{VObject{x <> xs}}
    case _ _: None{}

def cons_item(x: Maybe<&2, Value>, rest: Maybe<&2, Value>) -> Maybe<&2, Value>:
  match x rest:
    case Some{y} Some{VArray{ys}}: Some{VArray{y <> ys}}
    case _ _: None{}

def first_member(hit: Bool, here: Maybe<&2, Value>, later: Maybe<&2, Value>) -> Maybe<&2, Value>:
  match hit here later:
    case True{} Some{x} _: Some{VUnion{0n, x}}
    case True{} None{} _: None{}
    case False{} _ Some{VUnion{i, x}}: Some{VUnion{1n+i, x}}
    case False{} _ _: None{}

def value_for(s: Schema, v: J.Json) -> Maybe<&2, Value>:
  match s v:
    case StringSchema{a, b, c, d} J.JString{x}: Some{VString{x}}
    case NumberSchema{a, b} J.JNumber{x}: Some{VNumber{x}}
    case IntegerSchema{a, b} J.JNumber{x}: Some{VInteger{x}}
    case BooleanSchema{} J.JBool{x}: Some{VBool{x}}
    case LiteralSchema{x} y: Some{VLiteral{y}}
    case EnumSchema{xs} y: Some{VLiteral{y}}
    case ArraySchema{i, m, n} J.JArray{Nil{}}: Some{VArray{[]}}
    case ArraySchema{+i, +m, +n} J.JArray{h <> t}: cons_item(value_for(i, h), value_for(ArraySchema{i, m, n}, J.JArray{t}))
    case ObjectSchema{Nil{}, u} J.JObject{fs}: Some{VObject{[]}}
    case ObjectSchema{Field{+k, c, p} <> t, u} J.JObject{+input}: cons_field(field_value(k, first(input, k), value_for(c, or_null(first(input, k)))), value_for(ObjectSchema{t, u}, J.JObject{input}))
    case NullableSchema{i} J.JNull{}: Some{VNull{}}
    case NullableSchema{i} +y: value_for(i, y)
    case UnionSchema{Nil{}} y: None{}
    case UnionSchema{+m <> t} +y: first_member(accepted(decode(m, y)), value_for(m, y), value_for(UnionSchema{t}, y))
    case _ _: None{}

def Preserves(expected: Maybe<&2, Value>, r: Result<&2, &2, Errors(), Value>) -> Type:
  match r:
    case Fail{e}: Unit
    case Done{x}: {Some{x} == expected : Maybe<&2, Value>}
