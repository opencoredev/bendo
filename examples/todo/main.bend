# The todo API behind examples/todo's React app. Every route declares its
# schemas, all taken from shared/todo.bend, so route validation rejects a bad
# request before a handler runs, `--bendo-routes` exports each route's full
# contract for `bendo gen`, and the browser checks forms with the same decoder.
# The list lives in one B.Store. CORS lets the Vite dev server call the API
# from its own origin.
import Base
import ../../src/main.bend as B
import ../../src/validated.bend as V
import ../../src/data/schema.bend as S
import ../../src/data/json.bend as J
import ../../src/mw/cors.bend as Cors
import ../../src/mw/cors_policy.bend as CorsPolicy
import ../../src/app/store.bend as Store
import ../../src/router/methods.bend as Methods
import ./shared/todo.bend as Rules
import ./todos.bend as T

type Env is Data:
  Env{todos: B.Store(T.State), cors: B.CorsConfig}

type Tag is Data:
  ListTodos{}
  CreateTodo{}
  GetTodo{}
  UpdateTodo{}
  DeleteTodo{}
  AllowBrowser{}

def text_of(v: Maybe<&2, S.Value>) -> Maybe<&2, String>:
  match v:
    case Some{S.VString{s}}: Some{s}
    case _: None{}

def bool_of(v: Maybe<&2, S.Value>) -> Maybe<&2, Bool>:
  match v:
    case Some{S.VBool{b}}: Some{b}
    case _: None{}

def id_text(v: Maybe<&2, S.Value>) -> String:
  match v:
    case Some{S.VInteger{text}}: text
    case _: "0"

# Validation admitted the capture as an integer from 1 to 999999999.
def id_of(c: B.Ctx) -> U32:
  Maybe.default(&2, U32, U32.read(id_text(B.field(B.valid_params(c), "id"))), 0)

# The show query is an enum, so it decodes to a literal.
def show_text(v: Maybe<&2, S.Value>) -> String:
  match v:
    case Some{S.VLiteral{J.JString{s}}}: s
    case _: "all"

def unavailable(c: B.Ctx) -> B.Res:
  B.json(B.status(c, 503), J.JObject{[J.Field{"error", J.JString{"Service Unavailable"}}, J.Field{"status", J.JNumber{"503"}}]})

# The 422 for a blank title, in the shape of route validation's own rejections.
def blank_title(c: B.Ctx) -> B.Res:
  B.json(B.status(c, 422), J.JObject{[
    J.Field{"error", J.JString{"Unprocessable Content"}},
    J.Field{"status", J.JNumber{"422"}},
    J.Field{"errors", J.JArray{[J.JObject{[
      J.Field{"path", J.JArray{[J.JString{"body"}, J.JString{"title"}]}},
      J.Field{"code", J.JString{"constraint"}},
      J.Field{"message", J.JString{"title is blank"}}
    ]}]}}
  ]})

# The todo a store step touched, or 404 when it found none.
def touched(+c: B.Ctx, code: U32, result: Result<&2, &2, Store.Error, T.State>) -> B.Res:
  match result:
    case Done{T.State{next, items, Some{todo}}}: B.json(B.status(c, code), T.todo_json(todo))
    case Done{T.State{next, items, None{}}}: B.not_found(c)
    case Fail{e}: unavailable(c)

def listed(+c: B.Ctx, show: T.Show, result: Result<&2, &2, Store.Error, T.State>) -> B.Res:
  match result:
    case Done{T.State{next, items, last}}: B.json(c, T.list_json(items, show))
    case Fail{e}: unavailable(c)

def found(+c: B.Ctx, +id: U32, result: Result<&2, &2, Store.Error, T.State>) -> B.Res:
  match result:
    case Done{T.State{next, +items, last}}: touched(c, 200, Done{T.State{next, items, T.find(items, id)}})
    case Fail{e}: unavailable(c)

def list_todos(+c: B.Ctx, todos: B.Store(T.State)) -> IO(B.Res):
  do IO<B.Res>:
    r : Result<&2, &2, Store.Error, T.State> <- B.store_get(T.State, todos)
    return listed(c, T.show_of(show_text(B.field(B.valid_query(c), "show"))), r)

def get_todo(+c: B.Ctx, todos: B.Store(T.State)) -> IO(B.Res):
  do IO<B.Res>:
    r : Result<&2, &2, Store.Error, T.State> <- B.store_get(T.State, todos)
    return found(c, id_of(c), r)

def create_with(+c: B.Ctx, todos: B.Store(T.State), title: String, done: Bool) -> IO(B.Res):
  do IO<B.Res>:
    r : Result<&2, &2, Store.Error, T.State> <- B.store_update(T.State, todos, state => T.create(title, done, state))
    return touched(c, 201, r)

def create_checked(+c: B.Ctx, todos: B.Store(T.State), +title: String, is_blank: Bool) -> IO(B.Res):
  match is_blank:
    case True{}: IO.pure(B.Res, blank_title(c))
    case False{}: create_with(c, todos, title, Maybe.default(&2, Bool, bool_of(B.field(B.valid_body(c), "done")), False{}))

def create_todo(+c: B.Ctx, todos: B.Store(T.State), +title: String) -> IO(B.Res):
  create_checked(c, todos, title, Rules.blank(title))

def update_with(+c: B.Ctx, todos: B.Store(T.State), change: T.Change) -> IO(B.Res):
  +id = id_of(c)
  do IO<B.Res>:
    r : Result<&2, &2, Store.Error, T.State> <- B.store_update(T.State, todos, state => T.update(id, change, state))
    return touched(c, 200, r)

def update_checked(+c: B.Ctx, todos: B.Store(T.State), change: T.Change, is_blank: Bool) -> IO(B.Res):
  match is_blank:
    case True{}: IO.pure(B.Res, blank_title(c))
    case False{}: update_with(c, todos, change)

def blank_change(title: Maybe<&2, String>) -> Bool:
  match title:
    case Some{s}: Rules.blank(s)
    case None{}: False{}

def update_todo(+c: B.Ctx, todos: B.Store(T.State)) -> IO(B.Res):
  +title = text_of(B.field(B.valid_body(c), "title"))
  update_checked(c, todos, T.Change{title, bool_of(B.field(B.valid_body(c), "done"))}, blank_change(title))

def delete_todo(+c: B.Ctx, todos: B.Store(T.State)) -> IO(B.Res):
  +id = id_of(c)
  do IO<B.Res>:
    r : Result<&2, &2, Store.Error, T.State> <- B.store_update(T.State, todos, state => T.remove(id, state))
    return touched(c, 200, r)

def respond(tag: Tag, +c: B.Ctx, env: Env) -> IO(B.Res):
  match tag env:
    case ListTodos{} Env{todos, cors}: list_todos(c, todos)
    case GetTodo{} Env{todos, cors}: get_todo(c, todos)
    case CreateTodo{} Env{todos, cors}: create_todo(c, todos, Maybe.default(&2, String, text_of(B.field(B.valid_body(c), "title")), ""))
    case UpdateTodo{} Env{todos, cors}: update_todo(c, todos)
    case DeleteTodo{} Env{todos, cors}: delete_todo(c, todos)
    case AllowBrowser{} Env{todos, cors}: IO.pure(B.Res, B.not_found(c))

def dispatch(tag: Tag, c: B.Ctx, env: Env) -> IO(B.Res):
  respond(tag, c, env)

def middleware(tag: Tag, c: B.Ctx, env: Env, next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  match tag env:
    case AllowBrowser{} Env{todos, cors}: Cors.middleware(Unit, cors, c, next)
    case _ Env{todos, cors}: next(c)

def routes() -> List<&2, B.Registration(Tag)>:
  [
    B.use(Tag, AllowBrowser{}),
    B.with_schemas(Tag, B.get(Tag, "/api/todos", ListTodos{}), B.schemas([B.query_schema(Rules.list_query()), B.response_schema(Rules.todo_list())])),
    B.with_schemas(Tag, B.post(Tag, "/api/todos", CreateTodo{}), B.schemas([B.body_schema(Rules.create_schema()), B.response_schema(Rules.todo())])),
    B.with_schemas(Tag, B.get(Tag, "/api/todos/:id{int}", GetTodo{}), B.schemas([B.params_schema(Rules.id_params()), B.response_schema(Rules.todo())])),
    B.with_schemas(Tag, B.patch(Tag, "/api/todos/:id{int}", UpdateTodo{}), B.schemas([B.params_schema(Rules.id_params()), B.body_schema(Rules.update_schema()), B.response_schema(Rules.todo())])),
    B.with_schemas(Tag, B.delete(Tag, "/api/todos/:id{int}", DeleteTodo{}), B.schemas([B.params_schema(Rules.id_params()), B.response_schema(Rules.todo())]))
  ]

def ready(env: Env, result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}: V.serve_with(~Unit, ~Tag, ~Env, ~dispatch, ~middleware, table, env, B.config())
    case Fail{e}: IO.die(Unit, 1, "invalid todo routes")

def origin_or(r: Result<&1, &1, U32 & String, String>) -> List<&2, CorsPolicy.Entry>:
  match r:
    case Done{origin}: [B.cors_origin(origin)]
    case Fail{e}: []

# The Vite dev server's origins. TODO_WEB_ORIGIN adds one more, such as the
# address another device opens the app on.
def origins(extra: List<&2, CorsPolicy.Entry>) -> List<&2, CorsPolicy.Entry>:
  B.cors_origin("http://127.0.0.1:5173") <> B.cors_origin("http://localhost:5173") <> extra

def main() -> IO(Unit):
  do IO<Unit>:
    extra : Result<&1, &1, U32 & String, String> <- IO.get_env("TODO_WEB_ORIGIN")
    cors : B.CorsConfig <- B.cors_allow_checked(origins(origin_or(extra)))
    todos : B.Store(T.State) <- B.store(T.State, T.seed())
    ready(Env{todos, cors}, B.routes(Tag, routes()))
