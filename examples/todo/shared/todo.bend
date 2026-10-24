# The todo rules. The Bend server (../main.bend) declares these schemas on its
# routes, and the React app imports this file through vite-plugin-bendo, so
# the browser and the server run this exact decoder on the same JSON text.
import Base
import ../../../src/data/schema.bend as S
import ../../../src/data/json.bend as J

# The longest title, in Unicode scalar values. The form shows it as a counter.
def title_limit() -> Nat: 120n

def title() -> S.Schema:
  S.StringSchema{1n, Some{title_limit()}, None{}, S.Plain{}}

# POST /api/todos
def create_schema() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"title", title(), S.Required{}},
    S.Field{"done", S.BooleanSchema{}, S.Default{J.JBool{False{}}}}
  ], S.Strict{}}

# PATCH /api/todos/:id
def update_schema() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"title", title(), S.Optional{}},
    S.Field{"done", S.BooleanSchema{}, S.Optional{}}
  ], S.Strict{}}

# The :id capture of every single-todo route.
def id_params() -> S.Schema:
  S.ObjectSchema{[S.Field{"id", S.IntegerSchema{Some{"1"}, Some{"999999999"}}, S.Required{}}], S.Strict{}}

# GET /api/todos?show=all|active|done
def list_query() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"show", S.EnumSchema{[J.JString{"all"}, J.JString{"active"}, J.JString{"done"}]}, S.Default{J.JString{"all"}}}
  ], S.Strip{}}

def todo() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"id", S.IntegerSchema{Some{"1"}, None{}}, S.Required{}},
    S.Field{"title", title(), S.Required{}},
    S.Field{"done", S.BooleanSchema{}, S.Required{}}
  ], S.Strict{}}

def count() -> S.Schema:
  S.IntegerSchema{Some{"0"}, None{}}

# The list answer: the todos the filter kept, and the counts behind every tab.
def todo_list() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"todos", S.ArraySchema{todo(), 0n, None{}}, S.Required{}},
    S.Field{"counts", S.ObjectSchema{[
      S.Field{"all", count(), S.Required{}},
      S.Field{"active", count(), S.Required{}},
      S.Field{"done", count(), S.Required{}}
    ], S.Strict{}}, S.Required{}}
  ], S.Strict{}}

# A title of only spaces passes the schema's length check, so both sides add
# this rule after decoding. A tail call, so a huge paste cannot overflow the
# browser's stack.
def blank_go(s: String, acc: Bool) -> Bool:
  match s:
    case SNil{}: acc
    case SCon{h, t}: blank_go(t, Bool.and(acc, Char.is_space(h)))

def blank(s: String) -> Bool:
  blank_go(s, True{})

type Issue is Data:
  Issue{field: String, message: String}

type Checked is Data:
  Accepted{}
  Rejected{issues: List<&2, Issue>}

def text_of(v: J.Json) -> Maybe<&2, String>:
  match v:
    case J.JString{s}: Some{s}
    case _: None{}

# The title of a JSON object, when it is a string.
def title_go(fs: List<&2, J.Field>) -> Maybe<&2, String>:
  match fs:
    case Nil{}: None{}
    case J.Field{k, v} <> t: Bool.pick(Maybe<&2, String>, String.eq(k, "title"), text_of(v), title_go(t))

def title_of(j: J.Json) -> Maybe<&2, String>:
  match j:
    case J.JObject{fs}: title_go(fs)
    case _: None{}

def length_message(blank_title: Bool) -> String:
  match blank_title:
    case True{}: "Give the todo a title."
    case False{}: "Keep the title to 120 characters or fewer."

# A title that fails the schema is either empty or too long.
def title_message(title: Maybe<&2, String>) -> String:
  match title:
    case Some{s}: length_message(blank(s))
    case None{}: "The title must be text."

def wrong_kind(field: String) -> String:
  match field:
    case "title": "The title must be text."
    case "done": "Done must be true or false."
    case _: "That value has the wrong type."

def explain(+field: String, raw: String, title: Maybe<&2, String>) -> String:
  match raw:
    case "missing required key": "Give the todo a title."
    case "object has an undeclared key": "A todo has no field named " ++ field ++ "."
    case "duplicate key": "The " ++ field ++ " field appears more than once."
    case "expected schema scalar kind": wrong_kind(field)
    case "expected schema kind": "Send the todo as a JSON object."
    case _: title_message(title)


# The first key on an error's path names the form field; the root is "".
def field_of(path: List<&2, S.PathPart>) -> String:
  match path:
    case S.PathKey{k} <> t: k
    case _: ""

def issue(+title: Maybe<&2, String>, e: S.Error) -> Issue:
  match e:
    case S.Error{code, message, +path}: Issue{field_of(path), explain(field_of(path), message, title)}

def issues_go(es: List<&2, S.Error>, +title: Maybe<&2, String>, rev: List<&2, Issue>) -> List<&2, Issue>:
  match es:
    case Nil{}: List.reverse(&2, Issue, rev)
    case e <> t: issues_go(t, title, issue(title, e) <> rev)

def blank_verdict(is_blank: Bool) -> Checked:
  match is_blank:
    case True{}: Rejected{[Issue{"title", "Give the todo a title."}]}
    case False{}: Accepted{}

# The schema passed; the title, when the body has one, must not be blank.
def accepted(title: Maybe<&2, String>) -> Checked:
  match title:
    case Some{s}: blank_verdict(blank(s))
    case None{}: Accepted{}

def decoded(r: Result<&2, &2, S.Errors(), S.Value>, +title: Maybe<&2, String>) -> Checked:
  match r:
    case Done{v}: accepted(title)
    case Fail{es}: Rejected{issues_go(es, title, [])}

def parsed(r: Result<&2, &2, J.Error, J.Json>, schema: S.Schema) -> Checked:
  match r:
    case Done{+j}: decoded(S.decode(schema, j), title_of(j))
    case Fail{e}: Rejected{[Issue{"", "Send the todo as JSON."}]}

# The browser checks the JSON text it is about to send to POST /api/todos.
def check_create(text: String) -> Checked:
  parsed(J.parse_string(text), create_schema())

# The same for PATCH /api/todos/:id.
def check_update(text: String) -> Checked:
  parsed(J.parse_string(text), update_schema())
