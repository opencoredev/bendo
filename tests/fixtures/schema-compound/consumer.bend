# Compound schema fixtures shared by the native driver and the .mjs consumer.
import Base
import ../../../src/data/schema.bend as S
import ../../../src/data/schema-spec.bend as Spec
import ../../../src/data/schema-pattern.bend as P
import ../../../src/data/json.bend as J

def text(min: Nat, max: Maybe<&2, Nat>) -> S.Schema:
  S.StringSchema{min, max, None{}, S.Plain{}}

def int() -> S.Schema:
  S.IntegerSchema{None{}, None{}}

def num() -> S.Schema:
  S.NumberSchema{None{}, None{}}

def req(k: String, s: S.Schema) -> S.Field:
  S.Field{k, s, S.Required{}}

def opt(k: String, s: S.Schema) -> S.Field:
  S.Field{k, s, S.Optional{}}

def digits() -> S.Schema:
  S.StringSchema{0n, Some{5n}, Some{P.Repeat{P.Class{[P.Range{48, 57}]}, 5n, Some{5n}}}, S.Plain{}}

def geo() -> S.Schema:
  S.ObjectSchema{[req("lat", num()), req("lng", num())], S.Strict{}}

def address() -> S.Schema:
  S.ObjectSchema{[req("city", text(1n, None{})), req("geo", geo()), opt("zip", digits())], S.Strict{}}

def user_fields() -> List<&2, S.Field>:
  [req("name", text(1n, Some{40n})), opt("age", S.IntegerSchema{Some{"0"}, Some{"150"}}), req("address", address()), opt("tags", S.ArraySchema{text(0n, None{}), 0n, Some{3n}}), opt("nick", S.NullableSchema{text(0n, None{})})]

def letters(n: Nat, +c: U32) -> List<&2, S.Field>:
  match n:
    case 0n: []
    case 1n+p: opt(SCon{Chr{c}, ""}, int()) <> letters(p, (c + 1 : U32))

def lone() -> String:
  SCon{Chr{55296}, ""}

def schema_e(+name: String) -> S.Schema:
  Bool.pick(S.Schema, String.eq(name, "deep"), S.ArraySchema{S.ArraySchema{S.ArraySchema{int(), 0n, None{}}, 0n, None{}}, 0n, None{}}, Bool.pick(S.Schema, String.eq(name, "wide"), S.ObjectSchema{letters(26n, 97), S.Strict{}}, Bool.pick(S.Schema, String.eq(name, "wide-strip"), S.ObjectSchema{letters(26n, 97), S.Strip{}}, Bool.pick(S.Schema, String.eq(name, "empty-object"), S.ObjectSchema{[], S.Strict{}}, S.BooleanSchema{}))))

def schema_d(+name: String) -> S.Schema:
  Bool.pick(S.Schema, String.eq(name, "invalid-duplicate"), S.ObjectSchema{[req("a", int()), opt("a", int())], S.Strict{}}, Bool.pick(S.Schema, String.eq(name, "invalid-nested"), S.ArraySchema{S.ObjectSchema{[req("a", text(3n, Some{1n}))], S.Strip{}}, 0n, None{}}, Bool.pick(S.Schema, String.eq(name, "invalid-items"), S.ArraySchema{int(), 3n, Some{1n}}, Bool.pick(S.Schema, String.eq(name, "invalid-key"), S.ObjectSchema{[opt(lone(), int())], S.Strip{}}, Bool.pick(S.Schema, String.eq(name, "invalid-member"), S.UnionSchema{[int(), S.IntegerSchema{Some{"2"}, Some{"1"}}]}, schema_e(name))))))

def schema_c(+name: String) -> S.Schema:
  Bool.pick(S.Schema, String.eq(name, "union"), S.UnionSchema{[int(), text(0n, Some{2n}), S.LiteralSchema{J.JNull{}}, S.ObjectSchema{[req("kind", S.LiteralSchema{J.JString{"x"}})], S.Strict{}}]}, Bool.pick(S.Schema, String.eq(name, "union-objects"), S.UnionSchema{[S.ObjectSchema{[req("a", int())], S.Strict{}}, S.ObjectSchema{[req("a", text(0n, None{}))], S.Strip{}}]}, Bool.pick(S.Schema, String.eq(name, "empty-union"), S.UnionSchema{[]}, Bool.pick(S.Schema, String.eq(name, "nullable-union"), S.NullableSchema{S.UnionSchema{[S.NullableSchema{int()}, text(0n, None{})]}}, schema_d(name)))))

def schema_b(+name: String) -> S.Schema:
  Bool.pick(S.Schema, String.eq(name, "strip"), S.ObjectSchema{user_fields(), S.Strip{}}, Bool.pick(S.Schema, String.eq(name, "items"), S.ArraySchema{int(), 1n, Some{3n}}, Bool.pick(S.Schema, String.eq(name, "ints"), S.ArraySchema{int(), 0n, None{}}, Bool.pick(S.Schema, String.eq(name, "matrix"), S.ArraySchema{S.ArraySchema{S.BooleanSchema{}, 0n, None{}}, 0n, None{}}, Bool.pick(S.Schema, String.eq(name, "nullable"), S.NullableSchema{int()}, schema_c(name))))))

def schema(+name: String) -> S.Schema:
  Bool.pick(S.Schema, String.eq(name, "user"), S.ObjectSchema{user_fields(), S.Strict{}}, schema_b(name))

# Rendering. `show` is a test oracle format: strings and literals as compact
# JSON, numbers with their spelling, unions as #index:value, absent fields as -.
type Mode is Data:
  Whole{}
  Rest{}

def written(r: Result<&2, &2, J.Error, String>) -> String:
  match r:
    case Done{s}: s
    case Fail{e}: "?"

def quoted(j: J.Json) -> String:
  written(J.stringify(j))

def show(v: S.Value, mode: Mode) -> String:
  match v mode:
    case S.VString{x} _: quoted(J.JString{x})
    case S.VNumber{x} _: "n" ++ x
    case S.VInteger{x} _: "i" ++ x
    case S.VBool{x} _: Bool.show(x)
    case S.VLiteral{x} _: "lit:" ++ quoted(x)
    case S.VNull{} _: "null"
    case S.VUnion{i, x} _: "#" ++ Nat.show(i) ++ ":" ++ show(x, Whole{})
    case S.VArray{Nil{}} Whole{}: "[]"
    case S.VArray{Nil{}} Rest{}: "]"
    case S.VArray{h <> t} Whole{}: "[" ++ show(h, Whole{}) ++ show(S.VArray{t}, Rest{})
    case S.VArray{h <> t} Rest{}: "," ++ show(h, Whole{}) ++ show(S.VArray{t}, Rest{})
    case S.VObject{Nil{}} Whole{}: "{}"
    case S.VObject{Nil{}} Rest{}: "}"
    case S.VObject{S.VField{k, None{}} <> t} Whole{}: "{" ++ k ++ "=-" ++ show(S.VObject{t}, Rest{})
    case S.VObject{S.VField{k, None{}} <> t} Rest{}: "," ++ k ++ "=-" ++ show(S.VObject{t}, Rest{})
    case S.VObject{S.VField{k, Some{x}} <> t} Whole{}: "{" ++ k ++ "=" ++ show(x, Whole{}) ++ show(S.VObject{t}, Rest{})
    case S.VObject{S.VField{k, Some{x}} <> t} Rest{}: "," ++ k ++ "=" ++ show(x, Whole{}) ++ show(S.VObject{t}, Rest{})

def code(c: S.Code) -> String:
  match c:
    case S.InvalidSchema{}: "InvalidSchema"
    case S.TypeMismatch{}: "TypeMismatch"
    case S.Constraint{}: "Constraint"

def path(ps: List<&2, S.PathPart>) -> String:
  match ps:
    case Nil{}: ""
    case S.PathKey{k} <> t: "/" ++ k ++ path(t)
    case S.PathIndex{i} <> t: "/" ++ Nat.show(i) ++ path(t)

def report(r: Result<&2, &2, S.Errors(), S.Value>) -> String:
  match r:
    case Done{v}: "ok:" ++ show(v, Whole{})
    case Fail{S.Error{c, m, p} <> t}: "error:" ++ code(c) ++ ":" ++ path(p) ++ ":" ++ m
    case Fail{Nil{}}: "error:none"

def parse(s: String) -> Result<&2, &2, J.Error, J.Json>: J.parse_string(s)
def decode(s: S.Schema, v: J.Json) -> Result<&2, &2, S.Errors(), S.Value>: S.decode(s, v)
def satisfies(s: S.Schema, v: J.Json) -> Bool: Spec.satisfies(s, v)
def to_json(v: S.Value) -> J.Json: S.to_json(v)
def stringify(v: J.Json) -> String: quoted(v)

def decode_parsed(name: String, r: Result<&2, &2, J.Error, J.Json>) -> Result<&2, &2, S.Errors(), S.Value>:
  match r:
    case Done{v}: S.decode(schema(name), v)
    case Fail{e}: Fail{[]}

def decode_text(name: String, s: String) -> Result<&2, &2, S.Errors(), S.Value>:
  decode_parsed(name, J.parse_string(s))

def run(name: String, s: String) -> String:
  report(decode_text(name, s))

# Large inputs: report the item or field count rather than the whole value.
def items(xs: List<&2, S.Value>, n: Nat) -> Nat:
  match xs:
    case Nil{}: n
    case h <> t: items(t, 1n+n)

def fields(xs: List<&2, S.VField>, n: Nat) -> Nat:
  match xs:
    case Nil{}: n
    case h <> t: fields(t, 1n+n)

def count(r: Result<&2, &2, S.Errors(), S.Value>) -> String:
  match r:
    case Done{S.VArray{xs}}: "ok:" ++ Nat.show(items(xs, 0n))
    case Done{S.VObject{xs}}: "ok:" ++ Nat.show(fields(xs, 0n))
    case Done{v}: "ok"
    case Fail{e}: report(Fail{e})

def run_count(name: String, s: String) -> String:
  count(decode_text(name, s))

# A record written the way decision 0003's generator will write one: it reads
# the decoded fields by position, which the preservation law fixes as schema
# order, and never consults a key.
type Geo is Data:
  Geo{lat: String, lng: String}

type Address is Data:
  Address{city: String, geo: Geo, zip: Maybe<&2, String>}

type User is Data:
  User{name: String, address: Address, nick: Maybe<&2, Maybe<&2, String>>}

def geo_of(v: S.Value) -> Maybe<&2, Geo>:
  match v:
    case S.VObject{S.VField{a, Some{S.VNumber{lat}}} <> S.VField{b, Some{S.VNumber{lng}}} <> Nil{}}: Some{Geo{lat, lng}}
    case _: None{}

def zip_of(f: Maybe<&2, S.Value>) -> Maybe<&2, Maybe<&2, String>>:
  match f:
    case None{}: Some{None{}}
    case Some{S.VString{z}}: Some{Some{z}}
    case Some{x}: None{}

def address_go(city: String, g: Maybe<&2, Geo>, z: Maybe<&2, Maybe<&2, String>>) -> Maybe<&2, Address>:
  match g z:
    case Some{x} Some{y}: Some{Address{city, x, y}}
    case _ _: None{}

def address_of(v: S.Value) -> Maybe<&2, Address>:
  match v:
    case S.VObject{S.VField{a, Some{S.VString{city}}} <> S.VField{b, Some{g}} <> S.VField{c, z} <> Nil{}}: address_go(city, geo_of(g), zip_of(z))
    case _: None{}

def nick_of(f: Maybe<&2, S.Value>) -> Maybe<&2, Maybe<&2, Maybe<&2, String>>>:
  match f:
    case None{}: Some{None{}}
    case Some{S.VNull{}}: Some{Some{None{}}}
    case Some{S.VString{x}}: Some{Some{Some{x}}}
    case Some{x}: None{}

def user_go(name: String, a: Maybe<&2, Address>, n: Maybe<&2, Maybe<&2, Maybe<&2, String>>>) -> Maybe<&2, User>:
  match a n:
    case Some{x} Some{y}: Some{User{name, x, y}}
    case _ _: None{}

def user_of(v: S.Value) -> Maybe<&2, User>:
  match v:
    case S.VObject{S.VField{n0, Some{S.VString{name}}} <> S.VField{n1, age} <> S.VField{n2, Some{a}} <> S.VField{n3, tags} <> S.VField{n4, nick} <> Nil{}}: user_go(name, address_of(a), nick_of(nick))
    case _: None{}

def typed(r: Result<&2, &2, S.Errors(), S.Value>) -> Maybe<&2, User>:
  match r:
    case Done{v}: user_of(v)
    case Fail{e}: None{}

def maybe_text(m: Maybe<&2, String>) -> String:
  match m:
    case None{}: "none"
    case Some{x}: quoted(J.JString{x})

def nick_text(m: Maybe<&2, Maybe<&2, String>>) -> String:
  match m:
    case None{}: "absent"
    case Some{x}: maybe_text(x)

def describe(u: Maybe<&2, User>) -> String:
  match u:
    case None{}: "untyped"
    case Some{User{name, Address{city, Geo{lat, lng}, zip}, nick}}: "User{" ++ quoted(J.JString{name}) ++ " in " ++ quoted(J.JString{city}) ++ " at " ++ lat ++ "," ++ lng ++ " zip " ++ maybe_text(zip) ++ " nick " ++ nick_text(nick) ++ "}"

def run_typed(s: String) -> String:
  describe(typed(decode_text("user", s)))
