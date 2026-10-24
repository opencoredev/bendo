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
# optionality belongs to an object's field rather than to a schema. A Default
# field may be absent, and then decodes as its value, which the field's schema
# must accept (checked by `valid`).
type Presence is Data:
  Required{}
  Optional{}
  Default{value: J.Json}

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

# The value an absent field decodes from: its default, or null, which only a
# Default field's result uses. Decoding null is a cheap kind check.
def default_of(p: Presence) -> J.Json:
  match p:
    case Default{d}: d
    case Required{}: J.JNull{}
    case Optional{}: J.JNull{}

# An absent field: an error, None, or its decoded default.
def absent(rev: List<&2, VField>, +k: String, p: Presence, r: Result<&2, &2, Errors(), Value>) -> Result<&2, &2, Errors(), List<&2, VField>>:
  match p:
    case Optional{}: Done{VField{k, None{}} <> rev}
    case Required{}: Fail{[Error{Constraint{}, "missing required key", [PathKey{k}]}]}
    case Default{d}: push_field(rev, k, r)

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
    case ObjectSchema{Field{+k, +c, +p} <> t, u} x AFields{Done{rev}, Absent{} <> rest}: decode_go(ObjectSchema{t, u}, x, AFields{absent(rev, k, p, at(PathKey{k}, decode_go(c, default_of(p), start(c, default_of(p))))), rest})
    case ObjectSchema{Field{k, c, p} <> t, u} x AFields{Done{rev}, Repeated{y} <> rest}: Fail{[Error{Constraint{}, "duplicate key", [PathKey{k}]}]}
    case ObjectSchema{f <> t, u} x AFields{Done{rev}, Nil{}}: failure(InvalidSchema{}, "object fields out of step")
    case NullableSchema{+i} J.JNull{} y: Done{VNull{}}
    case NullableSchema{+i} +x y: decode_go(i, x, start(i, x))
    case UnionSchema{ms} x AMembers{n, i, Done{y}}: Done{VUnion{i, y}}
    case UnionSchema{Nil{}} x AMembers{n, i, Fail{e}}: failure(Constraint{}, "value matches no union member")
    case UnionSchema{+m <> t} +x AMembers{+n, i, Fail{e}}: decode_go(UnionSchema{t}, x, AMembers{1n+n, n, decode_go(m, x, start(m, x))})
    case _ _ _: failure(TypeMismatch{}, "expected schema kind")

def accepted(r: Result<&2, &2, Errors(), Value>) -> Bool:
  match r:
    case Fail{e}: False{}
    case Done{x}: True{}

# A default must decode under its own field's schema.
def default_ok(+c: Schema, p: Presence) -> Bool:
  match p:
    case Required{}: True{}
    case Optional{}: True{}
    case Default{+d}: accepted(decode_go(c, d, start(c, d)))

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
    case ObjectSchema{Field{+k, +c, p} <> +t, u}: J.scalars(k) && Bool.not(declared(t, k)) && valid(c) && default_ok(c, p) && valid(ObjectSchema{t, u})
    case NullableSchema{i}: valid(i)
    case UnionSchema{Nil{}}: True{}
    case UnionSchema{m <> t}: valid(m) && valid(UnionSchema{t})

def decode_valid(+s: Schema, +v: J.Json, schema_ok: Bool) -> Result<&2, &2, Errors(), Value>:
  match schema_ok:
    case True{}: decode_go(s, v, start(s, v))
    case False{}: failure(InvalidSchema{}, "invalid schema")

# Decodes and stops at the first failure. `decode` reports every failure.
def decode_first(+s: Schema, v: J.Json) -> Result<&2, &2, Errors(), Value>:
  decode_valid(s, v, valid(s))

# Error collection (BND-35). `decode` reports every failing location, at most
# `error_cap()` of them, each with the path that leads to it. `collect_go`
# walks the schema and the input together like `decode_go`, and returns the
# errors found so far in reverse with the budget left. A child starts with no
# errors and the parent's budget; the parent prefixes the child's errors with
# the key or index of the child. Below a failed array length or kind check
# nothing is examined, and a union reports one error for the whole value.

def error_cap() -> Nat:
  100n

type Out is Data:
  Out{rev: List<&2, Error>, left: Nat}

type Walk is Data:
  WHere{left: Nat}
  WItems{index: Nat, out: Out}
  WFields{slots: List<&2, Slot>, out: Out}
  WDone{out: Out}

# Adds e unless the check passed or the budget is spent.
def emit(ok: Bool, e: Error, out: Out) -> Out:
  match ok out:
    case True{} o: o
    case False{} Out{rev, 0n}: Out{rev, 0n}
    case False{} Out{rev, 1n+n}: Out{e <> rev, n}

def emit_all(es: List<&2, Error>, out: Out) -> Out:
  match es:
    case Nil{}: out
    case e <> t: emit_all(t, emit(False{}, e, out))

def scalar_out(r: Result<&2, &2, Errors(), Value>, left: Nat) -> Out:
  match r:
    case Done{x}: Out{[], left}
    case Fail{es}: emit_all(es, Out{[], left})

# Under Strict, one error per member whose key is undeclared, named by that key.
def strays(input: List<&2, J.Field>, +fs: List<&2, Field>, out: Out) -> Out:
  match input out:
    case _ Out{rev, 0n}: Out{rev, 0n}
    case Nil{} Out{rev, 1n+n}: Out{rev, 1n+n}
    case J.Field{+k, v} <> t Out{rev, 1n+n}: strays(t, fs, emit(declared(fs, k), Error{Constraint{}, "object has an undeclared key", [PathKey{k}]}, Out{rev, 1n+n}))

def unknown_out(u: Unknown, fs: List<&2, Field>, input: List<&2, J.Field>, out: Out) -> Out:
  match u:
    case Strict{}: strays(input, fs, out)
    case Strip{}: out

def items_walk(ok: Bool, left: Nat) -> Walk:
  match ok:
    case True{}: WItems{0n, Out{[], left}}
    case False{}: WDone{emit(False{}, Error{Constraint{}, "array length out of bounds", []}, Out{[], left})}

def cstart(s: Schema, v: J.Json, left: Nat) -> Walk:
  match s v:
    case ArraySchema{i, min, max} J.JArray{xs}: items_walk(item_count(min, max, count(xs, 0n)), left)
    case ObjectSchema{+fs, u} J.JObject{+input}: WFields{slots(fs, input), unknown_out(u, fs, input, Out{[], left})}
    case _ _: WHere{left}

def prefix_onto(+part: PathPart, es: List<&2, Error>, rev: List<&2, Error>) -> List<&2, Error>:
  match es:
    case Nil{}: rev
    case Error{c, m, path} <> t: Error{c, m, part <> path} <> prefix_onto(part, t, rev)

def merge(part: PathPart, child: Out, rev: List<&2, Error>) -> Out:
  match child:
    case Out{es, left}: Out{prefix_onto(part, es, rev), left}

def may_be_absent(p: Presence) -> Bool:
  match p:
    case Required{}: False{}
    case Optional{}: True{}
    case Default{d}: True{}

def kind_out(left: Nat) -> Out:
  emit(False{}, Error{TypeMismatch{}, "expected schema kind", []}, Out{[], left})

# Every state the walk does not advance returns its own errors; a schema
# given a value of the wrong kind reports that.
def walk_out(w: Walk) -> Out:
  match w:
    case WHere{l}: kind_out(l)
    case WItems{k, o}: o
    case WFields{ss, o}: o
    case WDone{o}: o

def collect_go(s: Schema, v: J.Json, w: Walk) -> Out:
  match s v w:
    case StringSchema{a, b, c, d} x WHere{l}: scalar_out(decode_scalar(StringSchema{a, b, c, d}, x), l)
    case NumberSchema{a, b} x WHere{l}: scalar_out(decode_scalar(NumberSchema{a, b}, x), l)
    case IntegerSchema{a, b} x WHere{l}: scalar_out(decode_scalar(IntegerSchema{a, b}, x), l)
    case BooleanSchema{} x WHere{l}: scalar_out(decode_scalar(BooleanSchema{}, x), l)
    case LiteralSchema{a} x WHere{l}: scalar_out(decode_scalar(LiteralSchema{a}, x), l)
    case EnumSchema{a} x WHere{l}: scalar_out(decode_scalar(EnumSchema{a}, x), l)
    case ArraySchema{i, m, n} x WItems{k, Out{rev, 0n}}: Out{rev, 0n}
    case ArraySchema{+i, +m, +n} J.JArray{+h <> t} WItems{+k, Out{rev, 1n+l}}: collect_go(ArraySchema{i, m, n}, J.JArray{t}, WItems{1n+k, merge(PathIndex{k}, collect_go(i, h, cstart(i, h, 1n+l)), rev)})
    case ObjectSchema{fs, u} x WFields{ss, Out{rev, 0n}}: Out{rev, 0n}
    case ObjectSchema{Field{+k, +c, p} <> t, u} x WFields{Once{+y} <> rest, Out{rev, 1n+l}}: collect_go(ObjectSchema{t, u}, x, WFields{rest, merge(PathKey{k}, collect_go(c, y, cstart(c, y, 1n+l)), rev)})
    case ObjectSchema{Field{+k, c, p} <> t, u} x WFields{Absent{} <> rest, Out{rev, 1n+l}}: collect_go(ObjectSchema{t, u}, x, WFields{rest, emit(may_be_absent(p), Error{Constraint{}, "missing required key", [PathKey{k}]}, Out{rev, 1n+l})})
    case ObjectSchema{Field{k, c, p} <> t, u} x WFields{Repeated{y} <> rest, Out{rev, 1n+l}}: collect_go(ObjectSchema{t, u}, x, WFields{rest, Out{Error{Constraint{}, "duplicate key", [PathKey{k}]} <> rev, l}})
    case NullableSchema{i} J.JNull{} WHere{l}: Out{[], l}
    case NullableSchema{+i} +x WHere{l}: collect_go(i, x, cstart(i, x, l))
    case UnionSchema{+ms} +x WHere{l}: emit(accepted(decode_go(UnionSchema{ms}, x, start(UnionSchema{ms}, x))), Error{Constraint{}, "value matches no union member", []}, Out{[], l})
    case _ _ w: walk_out(w)

def listed(o: Out) -> List<&2, Error>:
  match o:
    case Out{rev, l}: List.reverse(&2, Error, rev)

def collect(+s: Schema, +v: J.Json) -> List<&2, Error>:
  listed(collect_go(s, v, cstart(s, v, error_cap())))

def errors(+s: Schema, +v: J.Json, schema_ok: Bool) -> List<&2, Error>:
  match schema_ok:
    case True{}: collect(s, v)
    case False{}: [Error{InvalidSchema{}, "invalid schema", []}]

def report(r: Result<&2, &2, Errors(), Value>, +s: Schema, +v: J.Json) -> Result<&2, &2, Errors(), Value>:
  match r:
    case Done{x}: Done{x}
    case Fail{e}: Fail{errors(s, v, valid(s))}

# Decodes, or lists every failure (at most `error_cap()`) with its path.
def decode(+s: Schema, +v: J.Json) -> Result<&2, &2, Errors(), Value>:
  report(decode_first(s, v), s, v)

# Coercion for text sources (BND-35). Params, query strings, headers and forms
# carry only strings, so before decoding, a string under a number or integer
# schema that is a valid JSON number token becomes that number, "true" and
# "false" under a boolean schema become booleans, and under an object every
# member named by an array field is gathered, in order, into one array at the
# first such member's position. Arrays coerce their items, nullables their
# inner schema, objects their declared members. Unions, literals, enums and
# undeclared members are left as they are. A JSON body is never coerced.
type Pass is Data:
  PValue{}
  PMap{rev: List<&2, J.Json>}
  PEach{key: String, rev: List<&2, J.Field>}
  PGather{key: String, merged: J.Json, first: Bool, rev: List<&2, J.Field>}

def number_text(ok: Bool, x: String) -> J.Json:
  match ok:
    case True{}: J.JNumber{x}
    case False{}: J.JString{x}

def flag_text(yes: Bool, no: Bool, x: String) -> J.Json:
  match yes no:
    case True{} _: J.JBool{True{}}
    case False{} True{}: J.JBool{False{}}
    case False{} False{}: J.JString{x}

def keep_value(same: Bool, y: J.Json, rev: List<&2, J.Json>) -> List<&2, J.Json>:
  match same:
    case True{}: y <> rev
    case False{}: rev

# The values of every member named k, in order.
def named_values(input: List<&2, J.Field>, +k: String, rev: List<&2, J.Json>) -> List<&2, J.Json>:
  match input:
    case Nil{}: List.reverse(&2, J.Json, rev)
    case J.Field{key, y} <> t: named_values(t, k, keep_value(String.eq(key, k), y, rev))

def member_pick(same: Bool, key: String, y: J.Json, coerced: J.Json) -> J.Field:
  match same:
    case True{}: J.Field{key, coerced}
    case False{}: J.Field{key, y}

def gather_step(same: Bool, first: Bool, key: String, y: J.Json, k: String, +merged: J.Json, rev: List<&2, J.Field>) -> Pass:
  match same first:
    case True{} True{}: PGather{k, merged, False{}, J.Field{key, merged} <> rev}
    case True{} False{}: PGather{k, merged, False{}, rev}
    case False{} f: PGather{k, merged, f, J.Field{key, y} <> rev}

def coerce_go(s: Schema, v: J.Json, w: Pass) -> J.Json:
  match s v w:
    case NumberSchema{a, b} J.JString{+x} PValue{}: number_text(J.number_valid(x), x)
    case IntegerSchema{a, b} J.JString{+x} PValue{}: number_text(J.number_valid(x), x)
    case BooleanSchema{} J.JString{+x} PValue{}: flag_text(String.eq(x, "true"), String.eq(x, "false"), x)
    case NullableSchema{i} x PValue{}: coerce_go(i, x, PValue{})
    case ArraySchema{i, m, n} J.JArray{xs} PValue{}: coerce_go(i, J.JArray{xs}, PMap{[]})
    case ObjectSchema{Field{+k, ArraySchema{+i, m, n}, p} <> t, u} J.JObject{+input} PValue{}: coerce_go(ObjectSchema{t, u}, coerce_go(i, J.JObject{input}, PGather{k, coerce_go(i, J.JArray{named_values(input, k, [])}, PMap{[]}), True{}, []}), PValue{})
    case ObjectSchema{Field{+k, +c, p} <> t, u} J.JObject{+input} PValue{}: coerce_go(ObjectSchema{t, u}, coerce_go(c, J.JObject{input}, PEach{k, []}), PValue{})
    case s J.JArray{Nil{}} PMap{rev}: J.JArray{List.reverse(&2, J.Json, rev)}
    case +s J.JArray{h <> t} PMap{rev}: coerce_go(s, J.JArray{t}, PMap{coerce_go(s, h, PValue{}) <> rev})
    case s J.JObject{Nil{}} PEach{k, rev}: J.JObject{List.reverse(&2, J.Field, rev)}
    case +s J.JObject{J.Field{+key, +y} <> t} PEach{+k, rev}: coerce_go(s, J.JObject{t}, PEach{k, member_pick(String.eq(key, k), key, y, coerce_go(s, y, PValue{})) <> rev})
    case s J.JObject{Nil{}} PGather{k, g, f, rev}: J.JObject{List.reverse(&2, J.Field, rev)}
    case s J.JObject{J.Field{+key, y} <> t} PGather{+k, g, f, rev}: coerce_go(s, J.JObject{t}, gather_step(String.eq(key, k), f, key, y, k, g, rev))
    case _ x _: x

def coerce(+s: Schema, v: J.Json) -> J.Json:
  coerce_go(s, v, PValue{})

# Where input comes from: text sources coerce, JSON bodies never do.
type Source is Data:
  JsonBody{}
  TextSource{}

def decode_from(src: Source, +s: Schema, v: J.Json) -> Result<&2, &2, Errors(), Value>:
  match src:
    case JsonBody{}: decode(s, v)
    case TextSource{}: decode(s, coerce(s, v))

# The JSON form of an error list for responses (BND-36): an array of
# {"path": [...], "code": "...", "message": "..."} in report order. Path
# segments are key strings and index numbers; codes are "invalid_schema",
# "type_mismatch" and "constraint".
def code_name(c: Code) -> String:
  match c:
    case InvalidSchema{}: "invalid_schema"
    case TypeMismatch{}: "type_mismatch"
    case Constraint{}: "constraint"

def path_json(ps: List<&2, PathPart>, rev: List<&2, J.Json>) -> J.Json:
  match ps:
    case Nil{}: J.JArray{List.reverse(&2, J.Json, rev)}
    case PathKey{k} <> t: path_json(t, J.JString{k} <> rev)
    case PathIndex{i} <> t: path_json(t, J.JNumber{Nat.show(i)} <> rev)

def error_json(e: Error) -> J.Json:
  match e:
    case Error{c, m, p}: J.JObject{[J.Field{"path", path_json(p, [])}, J.Field{"code", J.JString{code_name(c)}}, J.Field{"message", J.JString{m}}]}

def errors_json_go(es: List<&2, Error>, rev: List<&2, J.Json>) -> J.Json:
  match es:
    case Nil{}: J.JArray{List.reverse(&2, J.Json, rev)}
    case e <> t: errors_json_go(t, error_json(e) <> rev)

def errors_json(es: List<&2, Error>) -> J.Json:
  errors_json_go(es, [])

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
# with that key, its default when it is a Default field, or None when there is
# none. A union carries the position of the first member that `decode` accepts
# and that member's value. Nothing here checks a constraint; `decode` must
# still reach exactly this value.
def first(input: List<&2, J.Field>, +k: String) -> Maybe<&2, J.Json>:
  match input:
    case Nil{}: None{}
    case J.Field{key, y} <> t: Bool.pick(Maybe<&2, J.Json>, String.eq(key, k), Some{y}, first(t, k))

# An absent Default field takes its default.
def fill(p: Presence, m: Maybe<&2, J.Json>) -> Maybe<&2, J.Json>:
  match p m:
    case Default{d} None{}: Some{d}
    case _ x: x

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
    case ObjectSchema{Field{+k, c, +p} <> t, u} J.JObject{+input}: cons_field(field_value(k, fill(p, first(input, k)), value_for(c, or_null(fill(p, first(input, k))))), value_for(ObjectSchema{t, u}, J.JObject{input}))
    case NullableSchema{i} J.JNull{}: Some{VNull{}}
    case NullableSchema{i} +y: value_for(i, y)
    case UnionSchema{Nil{}} y: None{}
    case UnionSchema{+m <> t} +y: first_member(accepted(decode_first(m, y)), value_for(m, y), value_for(UnionSchema{t}, y))
    case _ _: None{}

def Preserves(expected: Maybe<&2, Value>, r: Result<&2, &2, Errors(), Value>) -> Type:
  match r:
    case Fail{e}: Unit
    case Done{x}: {Some{x} == expected : Maybe<&2, Value>}
