# `.mjs` consumer for tests/json-schema.test.ts: the exporter, the decoder and
# the text formats, called with schemas and JSON trees built in TypeScript.
import Base
import ../../../src/data/json.bend as J
import ../../../src/data/schema.bend as S
import ../../../src/data/schema-text.bend as T
import ../../../src/data/schema-pattern.bend as P
import ../../../src/data/json-schema.bend as JS

def yes(b: Bool) -> String:
  match b:
    case True{}: "yes"
    case False{}: "no"

def written(r: Result<&2, &2, J.Error, String>) -> String:
  match r:
    case Done{text}: text
    case Fail{e}: "!unwritable"

def accepted(r: Result<&2, &2, S.Errors(), S.Value>) -> String:
  match r:
    case Done{v}: "yes"
    case Fail{e}: "no"

def jbool(b: String) -> J.Json: J.JBool{String.eq(b, "true")}
def document(s: S.Schema) -> String: written(J.stringify(JS.document(s)))
def exported(s: S.Schema) -> String: written(J.stringify(JS.export(s)))
def invalid() -> String: written(J.stringify(JS.invalid()))
def never() -> String: written(J.stringify(JS.never()))
def accepts(s: S.Schema, v: J.Json) -> String: accepted(S.decode(s, v))
def valid(s: S.Schema) -> String: yes(S.valid(s))
def email(s: String) -> String: yes(T.email(s))
def url(s: String) -> String: yes(T.url(s))
def scalars(s: String) -> String: yes(J.scalars(s))
def email_source() -> String: JS.email()
def url_source() -> String: JS.url()
def lone_source() -> String: JS.lone()
def pattern_source(p: P.Pattern) -> String: P.source(p)
def parsed(s: String) -> Result<&2, &2, J.Error, J.Json>: J.parse_string(s)
