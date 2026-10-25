# BND-35 fixtures shared by the native driver and the .mjs consumer: defaults,
# coercion for text sources, and error lists.
import Base
import ../../../src/data/schema.bend as S
import ../../../src/data/schema-spec.bend as Spec
import ../../../src/data/json.bend as J
import ../schema-compound/consumer.bend as C

def text(min: Nat, max: Maybe<&2, Nat>) -> S.Schema:
  S.StringSchema{min, max, None{}, S.Plain{}}

def int() -> S.Schema:
  S.IntegerSchema{None{}, None{}}

def req(k: String, s: S.Schema) -> S.Field:
  S.Field{k, s, S.Required{}}

def opt(k: String, s: S.Schema) -> S.Field:
  S.Field{k, s, S.Optional{}}

def dflt(k: String, s: S.Schema, d: J.Json) -> S.Field:
  S.Field{k, s, S.Default{d}}

def query_fields() -> List<&2, S.Field>:
  [dflt("limit", S.IntegerSchema{Some{"1"}, Some{"100"}}, J.JNumber{"10"}), opt("page", int()), opt("tag", S.ArraySchema{text(1n, None{}), 0n, Some{5n}}), dflt("flag", S.BooleanSchema{}, J.JBool{False{}}), opt("ratio", S.NumberSchema{None{}, None{}}), opt("mode", S.EnumSchema{[J.JString{"a"}, J.JString{"b"}]}), opt("maybe", S.NullableSchema{int()}), opt("pick", S.UnionSchema{[int(), text(0n, None{})]}), opt("ids", S.ArraySchema{int(), 0n, None{}})]

def person() -> S.Schema:
  S.ObjectSchema{[req("name", text(1n, Some{10n})), opt("age", S.IntegerSchema{Some{"0"}, Some{"150"}}), dflt("role", S.EnumSchema{[J.JString{"user"}, J.JString{"admin"}]}, J.JString{"user"})], S.Strict{}}

def letters(n: Nat, +c: U32) -> List<&2, S.Field>:
  match n:
    case 0n: []
    case 1n+p: opt(SCon{Chr{c}, ""}, int()) <> letters(p, (c + 1 : U32))

def schema_b(+name: String) -> S.Schema:
  Bool.pick(S.Schema, String.eq(name, "ints"), S.ArraySchema{int(), 0n, None{}}, Bool.pick(S.Schema, String.eq(name, "wide"), S.ObjectSchema{letters(26n, 97), S.Strict{}}, Bool.pick(S.Schema, String.eq(name, "bad-default"), S.ObjectSchema{[dflt("n", S.IntegerSchema{Some{"0"}, Some{"5"}}, J.JNumber{"9"})], S.Strip{}}, Bool.pick(S.Schema, String.eq(name, "nested-default"), S.ObjectSchema{[dflt("p", person(), J.JObject{[J.Field{"name", J.JString{"anon"}}]})], S.Strict{}}, Bool.pick(S.Schema, String.eq(name, "union"), S.UnionSchema{[int(), text(0n, Some{2n})]}, S.BooleanSchema{})))))

def schema(+name: String) -> S.Schema:
  Bool.pick(S.Schema, String.eq(name, "query"), S.ObjectSchema{query_fields(), S.Strip{}}, Bool.pick(S.Schema, String.eq(name, "strict-query"), S.ObjectSchema{query_fields(), S.Strict{}}, Bool.pick(S.Schema, String.eq(name, "people"), S.ObjectSchema{[req("id", int()), req("people", S.ArraySchema{person(), 0n, Some{50n}})], S.Strict{}}, Bool.pick(S.Schema, String.eq(name, "person"), person(), schema_b(name)))))

def written(r: Result<&2, &2, J.Error, String>) -> String:
  match r:
    case Done{s}: s
    case Fail{e}: "?"

def stringify(v: J.Json) -> String:
  written(J.stringify(v))

def error_count(es: List<&2, S.Error>, n: Nat) -> Nat:
  match es:
    case Nil{}: n
    case e <> t: error_count(t, 1n+n)

def report(r: Result<&2, &2, S.Errors(), S.Value>) -> String:
  match r:
    case Done{v}: "ok:" ++ C.show(v, C.Whole{})
    case Fail{es}: "errors:" ++ stringify(S.errors_json(es))

# Large inputs: the value's size or the number of errors.
def count(r: Result<&2, &2, S.Errors(), S.Value>) -> String:
  match r:
    case Fail{es}: "errors:" ++ Nat.show(error_count(es, 0n))
    case Done{v}: C.count(Done{v})

def source(text: Bool) -> S.Source:
  match text:
    case True{}: S.TextSource{}
    case False{}: S.JsonBody{}

def decode_parsed(text: Bool, name: String, r: Result<&2, &2, J.Error, J.Json>) -> Result<&2, &2, S.Errors(), S.Value>:
  match r:
    case Done{v}: S.decode_from(source(text), schema(name), v)
    case Fail{e}: Fail{[]}

def coerce_parsed(spec: Bool, name: String, r: Result<&2, &2, J.Error, J.Json>) -> String:
  match spec r:
    case True{} Done{v}: stringify(Spec.coerce_text(schema(name), v))
    case False{} Done{v}: stringify(S.coerce(schema(name), v))
    case _ Fail{e}: "parse-error"

def run(name: String, s: String) -> String:
  report(decode_parsed(False{}, name, J.parse_string(s)))

def run_text(name: String, s: String) -> String:
  report(decode_parsed(True{}, name, J.parse_string(s)))

def run_coerce(name: String, s: String) -> String:
  coerce_parsed(False{}, name, J.parse_string(s))

def run_spec_coerce(name: String, s: String) -> String:
  coerce_parsed(True{}, name, J.parse_string(s))

def run_count(text: Bool, name: String, s: String) -> String:
  count(decode_parsed(text, name, J.parse_string(s)))

def run_count_json(name: String, s: String) -> String:
  run_count(False{}, name, s)

def run_count_text(name: String, s: String) -> String:
  run_count(True{}, name, s)

# Direct access for seeded tests that build schemas in TypeScript.
def parse(s: String) -> Result<&2, &2, J.Error, J.Json>: J.parse_string(s)
def decode(s: S.Schema, v: J.Json) -> Result<&2, &2, S.Errors(), S.Value>: S.decode(s, v)
def decode_text(s: S.Schema, v: J.Json) -> Result<&2, &2, S.Errors(), S.Value>: S.decode_from(S.TextSource{}, s, v)
def coerce(s: S.Schema, v: J.Json) -> J.Json: S.coerce(s, v)
def spec_coerce(s: S.Schema, v: J.Json) -> J.Json: Spec.coerce_text(s, v)
def satisfies(s: S.Schema, v: J.Json) -> Bool: Spec.satisfies(s, v)
def located(s: S.Schema, v: J.Json, r: Result<&2, &2, S.Errors(), S.Value>) -> Bool: Spec.located_errors(s, v, r)
def error_at(s: S.Schema, v: J.Json, p: List<&2, S.PathPart>) -> Bool: Spec.error_at(s, v, p)
def reported(r: Result<&2, &2, S.Errors(), S.Value>, p: List<&2, S.PathPart>) -> Bool: Spec.reported(r, p)

def same_paths(a: List<&2, List<&2, S.PathPart>>, b: List<&2, List<&2, S.PathPart>>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case p <> t q <> u: Spec.same_path(p, q) && same_paths(t, u)
    case _ _: False{}

# BND-89: the listed paths are exactly the specification's.
def exact(s: S.Schema, v: J.Json, r: Result<&2, &2, S.Errors(), S.Value>) -> Bool: same_paths(Spec.listed_paths(r), Spec.error_paths(s, v))
def json(v: J.Json) -> String: stringify(v)
def errors_json(r: Result<&2, &2, S.Errors(), S.Value>) -> String: report(r)
