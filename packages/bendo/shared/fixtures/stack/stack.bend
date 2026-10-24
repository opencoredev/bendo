# Every pure helper on the shared schema/validator path, behind one probe so
# stack.test.ts runs identical Bend on Bun's and Node's default JS stacks.
import Base
import ../../../../../src/data/schema.bend as S
import ../../../../../src/data/json.bend as J
import ../../../../../src/data/utf8.bend as U
import ../../../../../src/data/schema-pattern.bend as P
import ../../../../../src/data/schema-pattern-automaton.bend as A

def lower() -> P.Pattern:
  P.Repeat{P.Class{[P.Range{97, 122}]}, 0n, None{}}

def text(p: Maybe<&2, P.Pattern>, f: S.Format) -> S.Schema:
  S.StringSchema{0n, None{}, p, f}

def number() -> S.Schema:
  S.NumberSchema{None{}, None{}}

def numbers() -> S.Schema:
  S.ArraySchema{number(), 0n, None{}}

def schema(name: String) -> S.Schema:
  match name:
    case "string": text(None{}, S.Plain{})
    case "pattern": text(Some{lower()}, S.Plain{})
    case "email": text(None{}, S.Email{})
    case "url": text(None{}, S.Url{})
    case "bounded": S.StringSchema{0n, Some{10n}, None{}, S.Plain{}}
    case "integer": S.IntegerSchema{Some{"0"}, None{}}
    case "numbers": numbers()
    case "strings": S.ArraySchema{text(None{}, S.Plain{}), 0n, None{}}
    case "strict": S.ObjectSchema{[S.Field{"a", number(), S.Required{}}], S.Strict{}}
    case "strip": S.ObjectSchema{[S.Field{"a", number(), S.Required{}}], S.Strip{}}
    case "records": S.ArraySchema{S.ObjectSchema{[S.Field{"a", text(None{}, S.Plain{}), S.Required{}}], S.Strict{}}, 0n, None{}}
    case "union": S.UnionSchema{[text(None{}, S.Plain{}), numbers()]}
    case "nullable": S.NullableSchema{numbers()}
    case "ids": S.ObjectSchema{[S.Field{"ids", numbers(), S.Required{}}], S.Strict{}}
    case "any-key": S.ObjectSchema{[S.Field{"k", number(), S.Optional{}}], S.Strip{}}
    case _: S.BooleanSchema{}

def count_errors(es: List<&2, S.Error>, n: Nat) -> Nat:
  match es:
    case Nil{}: n
    case e <> t: count_errors(t, 1n+n)

def summary(r: Result<&2, &2, S.Errors(), S.Value>) -> String:
  match r:
    case Done{v}: "ok"
    case Fail{es}: "fail:" ++ Nat.show(count_errors(es, 0n))

def written(r: Result<&2, &2, J.Error, String>) -> String:
  match r:
    case Done{s}: s
    case Fail{e}: "unwritable"

def size(r: Result<&2, &2, J.Error, String>) -> String:
  match r:
    case Done{s}: Nat.show(String.length(s))
    case Fail{e}: "unwritable"

def report(r: Result<&2, &2, S.Errors(), S.Value>) -> String:
  match r:
    case Done{v}: written(J.stringify(S.to_json(v)))
    case Fail{es}: size(J.stringify(S.errors_json(es)))

def flag(b: Bool) -> String:
  match b:
    case True{}: "true"
    case False{}: "false"

def utf8(r: Maybe<&2, String>) -> String:
  match r:
    case Some{s}: s
    case None{}: "invalid"

def escaped(r: Result<&2, &2, J.Error, J.Json>) -> String:
  match r:
    case Done{v}: written(J.write(v, False{}, True{}))
    case Fail{e}: "unreadable"

def on_json(kind: String, +s: S.Schema, +v: J.Json) -> String:
  match kind:
    case "decode": summary(S.decode(s, v))
    case "text": summary(S.decode_from(S.TextSource{}, s, v))
    case "report": report(S.decode(s, v))
    case "roundtrip": written(J.stringify(v))
    case "pretty": size(J.write(v, True{}, True{}))
    case _: "unknown kind"

def parsed(kind: String, +s: S.Schema, r: Result<&2, &2, J.Error, J.Json>) -> String:
  match r:
    case Fail{e}: "unreadable"
    case Done{v}: on_json(kind, s, v)

def probe(kind: String, name: String, +input: String) -> String:
  match kind:
    case "bytes": escaped(J.parse(U.encode(input)))
    case "utf8": utf8(U.decode(U.encode(input)))
    case "valid": flag(U.valid(input))
    case "matches": flag(A.matches(lower(), input))
    case "derivative": flag(P.matches(lower(), input))
    case "source": Nat.show(String.length(P.source(P.Literal{input})))
    case _: parsed(kind, schema(name), J.parse_string(input))
