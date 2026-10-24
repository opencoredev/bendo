# The API for the web app in src/. Routes carry schemas, so `bendo gen`
# writes the client's types to .bendo/ and the server checks every request.
# `bun run build` also builds the web app into dist/web. This server sends its
# hashed files from /assets and index.html for every other GET path, so the
# router's pages work on reload.
import Base
import ./bendo/main.bend as B
import ./bendo/validated.bend as V
import ./bendo/data/schema.bend as S
import ./bendo/data/json.bend as J
import ./shared/notes.bend as Rules

type Note is Data:
  Note{id: U32, text: String}

type Notes is Data:
  Notes{next: U32, items: List<&2, Note>}

type Env is Data:
  Env{notes: B.Store(Notes)}

type Tag is Data:
  Hello{}
  ListNotes{}
  AddNote{}
  MissingApi{}
  Assets{}
  Page{}

# Keep the newest notes only, so the in-memory list stays small.
def recent(n: Nat, notes: List<&2, Note>) -> List<&2, Note>:
  match n:
    case 0n: []
    case 1n+p:
      match notes:
        case Nil{}: []
        case h <> t: h <> recent(p, t)

def add(state: Notes, text: String) -> Notes:
  match state:
    case Notes{+next, items}: Notes{(next + 1 : U32), recent(50n, Note{next, text} <> items)}

def note_json(note: Note) -> J.Json:
  match note:
    case Note{id, text}: J.JObject{[J.Field{"id", J.JNumber{U32.show(id)}}, J.Field{"text", J.JString{text}}]}

def notes_json(notes: List<&2, Note>) -> List<&2, J.Json>:
  match notes:
    case Nil{}: []
    case h <> t: note_json(h) <> notes_json(t)

def unavailable(c: B.Ctx) -> B.Res:
  B.json(B.status(c, 503), J.JObject{[J.Field{"error", J.JString{"notes are unavailable"}}]})

def listed(+c: B.Ctx, result: Result<&2, &2, B.StoreError, Notes>) -> B.Res:
  match result:
    case Done{Notes{next, items}}: B.json(c, J.JObject{[J.Field{"notes", J.JArray{notes_json(items)}}]})
    case Fail{e}: unavailable(c)

def added(+c: B.Ctx, result: Result<&2, &2, B.StoreError, Notes>) -> B.Res:
  match result:
    case Done{Notes{next, items}}:
      match items:
        case h <> t: B.json(B.status(c, 201), note_json(h))
        case Nil{}: unavailable(c)
    case Fail{e}: unavailable(c)

def text_of(value: Maybe<&2, S.Value>) -> String:
  match value:
    case Some{S.VString{s}}: s
    case _: ""

def hello(+c: B.Ctx) -> B.Res:
  B.json(c, J.JObject{[J.Field{"message", J.JString{"Hello, " ++ text_of(B.field(B.valid_query(c), "name")) ++ "!"}}]})

def assets() -> B.StaticOptions:
  B.static_cache_control(B.static_options("dist/web"), "public, max-age=31536000, immutable")

def missing(c: B.Ctx) -> B.Res:
  B.json(B.status(c, 404), J.JObject{[J.Field{"error", J.JString{"no such API route"}}]})

def respond(tag: Tag, +ctx: B.Ctx, env: Env) -> IO(B.Res):
  match tag env:
    case Hello{} Env{notes}:
      IO.pure(B.Res, hello(ctx))
    case ListNotes{} Env{notes}:
      do IO<B.Res>:
        r : Result<&2, &2, B.StoreError, Notes> <- B.store_get(Notes, notes)
        return listed(ctx, r)
    case AddNote{} Env{notes}:
      do IO<B.Res>:
        text : String = text_of(B.field(B.valid_body(ctx), "text"))
        r : Result<&2, &2, B.StoreError, Notes> <- B.store_update(Notes, notes, state => add(state, text))
        return added(ctx, r)
    case MissingApi{} Env{notes}:
      IO.pure(B.Res, missing(ctx))
    case Assets{} Env{notes}:
      B.serve_static(ctx, assets())
    case Page{} Env{notes}:
      B.serve_static(B.rewrite(ctx, B.method(ctx), "/"), B.static_options("dist/web"))

def dispatch(tag: Tag, c: B.Ctx, env: Env) -> IO(B.Res):
  respond(tag, c, env)

def text(min: Nat, max: Nat) -> S.Schema:
  S.StringSchema{min, Some{max}, None{}, S.Plain{}}

def note() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"id", S.IntegerSchema{Some{"1"}, None{}}, S.Required{}},
    S.Field{"text", text(1n, Rules.max_length()), S.Required{}},
  ], S.Strict{}}

def hello_query() -> S.Schema:
  S.ObjectSchema{[S.Field{"name", text(1n, 40n), S.Default{J.JString{"world"}}}], S.Strip{}}

def hello_response() -> S.Schema:
  S.ObjectSchema{[S.Field{"message", text(1n, 60n), S.Required{}}], S.Strict{}}

def notes_response() -> S.Schema:
  S.ObjectSchema{[S.Field{"notes", S.ArraySchema{note(), 0n, Some{50n}}, S.Required{}}], S.Strict{}}

def note_input() -> S.Schema:
  S.ObjectSchema{[S.Field{"text", text(1n, Rules.max_length()), S.Required{}}], S.Strict{}}

def routes() -> List<&2, B.Registration(Tag)>:
  [
    B.with_schemas(Tag, B.get(Tag, "/api/hello", Hello{}), B.schemas([B.query_schema(hello_query()), B.response_schema(hello_response())])),
    B.with_schemas(Tag, B.get(Tag, "/api/notes", ListNotes{}), B.schemas([B.response_schema(notes_response())])),
    B.with_schemas(Tag, B.post(Tag, "/api/notes", AddNote{}), B.schemas([B.body_schema(note_input()), B.response_schema(note())])),
    B.get(Tag, "/api/*", MissingApi{}),
    B.get(Tag, "/assets/*", Assets{}),
    B.get(Tag, "/*", Page{}),
  ]

def ready(env: Env, result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}: V.serve(~Tag, ~Env, ~dispatch, table, env, B.config())
    case Fail{error}: IO.die(Unit, 1, "invalid routes")

def main() -> IO(Unit):
  do IO<Unit>:
    notes : B.Store(Notes) <- B.store(Notes, Notes{1, []})
    ready(Env{notes}, B.routes(Tag, routes()))
