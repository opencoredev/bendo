# The signup form's schema and messages. The Bend server (../main.bend)
# imports this file directly; the React form imports its `.mjs` from
# `bendo build --shared`. Both sides run this exact decoder.
import Base
import ../../../../../../src/data/schema.bend as S
import ../../../../../../src/data/json.bend as J
import ../../../../../../src/data/schema-pattern.bend as P

type Issue is Data:
  Issue{field: String, message: String}

type Checked is Data:
  Accepted{user: J.Json}
  Rejected{issues: List<&2, Issue>}

# Lowercase letters, digits and underscores, 3 to 20 of them.
def handle() -> P.Pattern:
  P.Repeat{P.Class{[P.Range{97, 122}, P.Range{48, 57}, P.Range{95, 95}]}, 3n, Some{20n}}

def schema() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"name", S.StringSchema{1n, Some{60n}, None{}, S.Plain{}}, S.Required{}},
    S.Field{"email", S.StringSchema{3n, Some{254n}, None{}, S.Email{}}, S.Required{}},
    S.Field{"username", S.StringSchema{0n, None{}, Some{handle()}, S.Plain{}}, S.Required{}},
    S.Field{"age", S.IntegerSchema{Some{"13"}, Some{"120"}}, S.Optional{}},
    S.Field{"plan", S.EnumSchema{[J.JString{"free"}, J.JString{"pro"}]}, S.Default{J.JString{"free"}}}
  ], S.Strict{}}

def label(field: String) -> String:
  match field:
    case "name": "Name"
    case "email": "Email"
    case "username": "Username"
    case "age": "Age"
    case "plan": "Plan"
    case _: "This field"

# What a field needs, for a value that has the wrong type or fails a check.
def hint(field: String) -> String:
  match field:
    case "name": "Use 1 to 60 characters."
    case "email": "Enter an email address, like ada@example.com."
    case "username": "Use 3 to 20 lowercase letters, digits or underscores."
    case "age": "Enter a whole number from 13 to 120, or leave it empty."
    case "plan": "Choose Free or Pro."
    case _: "Send the signup form as a JSON object."

def explain(+field: String, raw: String) -> String:
  match raw:
    case "missing required key": label(field) ++ " is required."
    case "duplicate key": label(field) ++ " appears more than once."
    case "object has an undeclared key": "The form has no field named " ++ field ++ "."
    case _: hint(field)

# The first key on an error's path names the form field; the root is "".
def field_of(path: List<&2, S.PathPart>) -> String:
  match path:
    case S.PathKey{k} <> t: k
    case _: ""

def issue(e: S.Error) -> Issue:
  match e:
    case S.Error{code, message, +path}: Issue{field_of(path), explain(field_of(path), message)}

def issues_go(es: List<&2, S.Error>, rev: List<&2, Issue>) -> List<&2, Issue>:
  match es:
    case Nil{}: List.reverse(&2, Issue, rev)
    case e <> t: issues_go(t, issue(e) <> rev)

def decoded(r: Result<&2, &2, S.Errors(), S.Value>) -> Checked:
  match r:
    case Done{v}: Accepted{S.to_json(v)}
    case Fail{es}: Rejected{issues_go(es, [])}

def parsed(r: Result<&2, &2, J.Error, J.Json>) -> Checked:
  match r:
    case Done{v}: decoded(S.decode(schema(), v))
    case Fail{e}: Rejected{[Issue{"", "Send the signup form as JSON."}]}

# The browser checks the text it is about to send.
def check(text: String) -> Checked:
  parsed(J.parse_string(text))

# The server checks the request body octets.
def check_body(body: List<&2, U32>) -> Checked:
  parsed(J.parse(body))

def status(c: Checked) -> U32:
  match c:
    case Accepted{u}: 201
    case Rejected{xs}: 422

def issues_json(xs: List<&2, Issue>, rev: List<&2, J.Json>) -> J.Json:
  match xs:
    case Nil{}: J.JArray{List.reverse(&2, J.Json, rev)}
    case Issue{f, m} <> t: issues_json(t, J.JObject{[J.Field{"field", J.JString{f}}, J.Field{"message", J.JString{m}}]} <> rev)

# The response body: {"ok": true, "user": ...} or {"ok": false, "issues": [...]}.
def reply(c: Checked) -> J.Json:
  match c:
    case Accepted{u}: J.JObject{[J.Field{"ok", J.JBool{True{}}}, J.Field{"user", u}]}
    case Rejected{xs}: J.JObject{[J.Field{"ok", J.JBool{False{}}}, J.Field{"issues", issues_json(xs, [])}]}

def written(r: Result<&2, &2, J.Error, String>) -> String:
  match r:
    case Done{s}: s
    case Fail{e}: "null"

# The exact response text, for comparing both sides byte for byte.
def reply_text(c: Checked) -> String:
  written(J.stringify(reply(c)))
