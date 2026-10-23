# Public Bendo entrypoint. Route tags and startup environments are app-owned Data.
import Base
import ./mw/builtin.bend as Builtin
import ./mw/server_timing.bend as Timing
import ./app/config.bend as Config
import ./app/table.bend as Table
import ./app/scopes.bend as Scopes
import ./app/handle.bend as Handle
import ./app/context.bend as Context
import ./app/errors.bend as Errors
import ./app/store.bend as Store
import ./app/store_actor.bend as StoreActor
import ./data/json.bend as Json
import ./data/cookie.bend as Cookie
import ./serve.bend as Serve
import ./http/request.bend as Request
import ./http/response.bend as Response
import ./router/methods.bend as Methods
import ./router/router.bend as Router

def HttpError() -> Data: Errors.HttpError
def http_error(status: U32, message: String) -> Errors.HttpError: Errors.http_error(status, message)
def error(c: Handle.Ctx, failure: Errors.HttpError) -> Response.Res: Context.error(Unit, c, failure)
def result(c: Handle.Ctx, value: Result<&2, &2, Errors.HttpError, Response.Res>) -> Response.Res: Context.result(Unit, c, value)

def Req() -> Data: Request.Req
def Res() -> Data: Response.Res
def Ctx() -> Data: Handle.Ctx
def Context(-Vars: Data) -> Data: Context.Ctx<Vars>
def ServerConfig() -> Data: Config.Config
def RouterKind() -> Data: Router.RouterKind
def Registration(-Tag: Data) -> Data: Table.Entry<Tag>
def Routes(-Tag: Data) -> Data: Table.Table<Tag>
def RouteError() -> Data: Methods.BuildError

def config() -> Config.Config: Config.defaults()
def spec() -> Router.RouterKind: Router.Spec{}
def trie() -> Router.RouterKind: Router.Trie{}
def not_modified(headers: List<&2, Request.Header>, representation: Maybe<&2, List<&2, U32>>) -> Response.Res: Response.not_modified(headers, representation)

def param(c: Handle.Ctx, name: String) -> Maybe<&2, String>: Context.param(Unit, c, name)
def query(c: Handle.Ctx, name: String) -> Maybe<&2, String>: Context.query(Unit, c, name)
def queries(c: Handle.Ctx, name: String) -> List<&2, String>: Context.queries(Unit, c, name)
def request_header(c: Handle.Ctx, name: String) -> Maybe<&2, String>: Context.request_header(Unit, c, name)
def header_bytes(c: Handle.Ctx, name: String) -> List<&2, List<&2, U32>>: Context.header_bytes(Unit, c, name)
def method(c: Handle.Ctx) -> Request.Method: Context.method(Unit, c)
def path(c: Handle.Ctx) -> String: Context.path(Unit, c)
def url(c: Handle.Ctx) -> String: Context.url(Unit, c)
def rewrite(c: Handle.Ctx, method: Request.Method, path: String) -> Handle.Ctx: Context.rewrite(Unit, c, method, path)
def raw_body(c: Handle.Ctx) -> List<&2, U32>: Context.raw_body(Unit, c)
def text(c: Handle.Ctx, value: String) -> Response.Res: Context.text(Unit, c, value)
def html(c: Handle.Ctx, value: String) -> Response.Res: Context.html(Unit, c, value)
def json(c: Handle.Ctx, value: Json.Json) -> Response.Res: Context.json(Unit, c, value)
def body(c: Handle.Ctx, bytes: List<&2, U32>, content_type: Maybe<&2, String>) -> Response.Res: Context.body(Unit, c, bytes, content_type)
def status(c: Handle.Ctx, code: U32) -> Handle.Ctx: Context.status(Unit, c, code)
def header(c: Handle.Ctx, name: String, value: String) -> Handle.Ctx: Context.header(Unit, c, name, value)
def redirect(c: Handle.Ctx, location: String) -> Response.Res: Context.redirect(Unit, c, location)
def redirect_status(c: Handle.Ctx, location: String, code: U32) -> Response.Res: Context.redirect_status(Unit, c, location, code)
def not_found(c: Handle.Ctx) -> Response.Res: Context.not_found(Unit, c)

def get(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.get(Tag, path, tag)}
def head(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.head(Tag, path, tag)}
def post(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.post(Tag, path, tag)}
def put(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.put(Tag, path, tag)}
def patch(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.patch(Tag, path, tag)}
def delete(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.delete(Tag, path, tag)}
def options(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.options(Tag, path, tag)}
def all(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.all(Tag, path, tag)}
def on(-Tag: Data, methods: List<&2, Request.Method>, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.on(Tag, methods, path, tag)}
# Adapt a low-level method registration into the public app registration list.
def route(-Tag: Data, entry: Methods.Registration(Tag)) -> Table.Entry<Tag>: Table.Route{entry}
def use(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Use{None{}, id}
def use_path(-Tag: Data, pattern: String, id: Tag) -> Table.Entry<Tag>: Table.Use{Some{pattern}, id}
def on_request(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.Request{}, id}
def on_parse(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.Parse{}, id}
def on_transform(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.Transform{}, id}
def before_handle(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.BeforeHandle{}, id}
def after_handle(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.AfterHandle{}, id}
def map_response(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.MapResponse{}, id}
def on_not_found(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.NotFound{}, id}
def on_error(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.Error{}, id}
def on_after_response(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.AfterResponse{}, id}
def routes(-Tag: Data, entries: List<&2, Table.Entry<Tag>>) -> Result<&2, &2, Methods.BuildError, Table.Table<Tag>>: Table.build(Tag, entries)

# Typed hook data for group/guard/route options; on_* entries are global until assembled into a scope.
def Hook(-Tag: Data) -> Data: Table.HookSpec<Tag>
def GuardOptions(-Tag: Data) -> Data: Table.GuardOptions<Tag>
def hook(-Tag: Data, stage: Table.Stage, id: Tag) -> Table.HookSpec<Tag>: Table.HookSpec{stage, id}
def guard_options(-Tag: Data, hooks: List<&2, Table.HookSpec<Tag>>) -> Table.GuardOptions<Tag>: Table.GuardOptions{hooks, Table.NoSchemas{}}
def guard(-Tag: Data, options: Table.GuardOptions<Tag>, entries: List<&2, Table.Entry<Tag>>) -> List<&2, Table.Entry<Tag>>: Scopes.guard(Tag, options, entries)
def group(-Tag: Data, prefix: String, hooks: List<&2, Table.HookSpec<Tag>>, entries: List<&2, Table.Entry<Tag>>) -> List<&2, Table.Entry<Tag>>: Scopes.group(Tag, prefix, hooks, entries)
def route_hooks(-Tag: Data, registration: Methods.Registration(Tag), hooks: List<&2, Table.HookSpec<Tag>>) -> Table.Entry<Tag>:
  Scopes.local(Tag, registration, hooks)

def handle(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  Handle.handle(~Tag, ~Env, ~dispatch, table, env, req, body)

def serve(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  Serve.run(~Tag, ~Env, ~dispatch, table, env, config)

# Vars is uniform across every middleware and handler in an app.
def handle_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  Handle.handle_with(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, table, env, req, body)

def serve_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  Serve.run_with(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, table, env, config)

# Store operations use a prefix because B.get registers routes.
def Store(-S: Data) -> Data: Store.Store<S>
def StoreError() -> Data: Store.Error

def store(-S: Data, initial: S) -> IO(Store.Store<S>):
  StoreActor.store(S, initial)

def store_with_timeout(-S: Data, initial: S, timeout_ms: U32) -> IO(Store.Store<S>):
  StoreActor.store_with_timeout(S, initial, timeout_ms)

def store_get(-S: Data, handle: Store.Store<S>) -> IO(Result<&2, &2, Store.Error, S>):
  Store.get(S, handle)

def store_set(-S: Data, handle: Store.Store<S>, value: S) -> IO(Result<&2, &2, Store.Error, Unit>):
  Store.set(S, handle, value)

def store_update(-S: Data, handle: Store.Store<S>, change: S -> S) -> IO(Result<&2, &2, Store.Error, S>):
  Store.update(S, handle, change)

# Built-in identifiers are wrapped in the application's own middleware Tag.
def Builtin() -> Data: Builtin.Builtin
def logger() -> Builtin.Builtin: Builtin.Logger{}
def request_id() -> Builtin.Builtin: Builtin.RequestId{}
def server_timing() -> Builtin.Builtin: Builtin.ServerTiming{}
def powered_by(name: String) -> Builtin.Builtin: Builtin.PoweredBy{name}
def pretty_json() -> Builtin.Builtin: Builtin.PrettyJson{}
def builtin(-Vars: Data, id: Builtin.Builtin, c: Context.Ctx<Vars>, next: Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  Builtin.dispatch(Vars, id, c, next)
def timing_mark(-Vars: Data, c: Context.Ctx<Vars>, name: String, duration_ms: Nat) -> IO(Bool):
  Timing.mark(Vars, c, name, duration_ms)

# Cookie setters append fields and return validation failures explicitly.
def cookies(c: Handle.Ctx) -> List<&2, Cookie.Entry>: Context.cookies(Unit, c)
def cookie(c: Handle.Ctx, name: String) -> Maybe<&2, String>: Context.cookie(Unit, c, name)
def set_cookie(c: Handle.Ctx, name: String, value: String, options: Cookie.Options) -> Result<&2, &2, Cookie.Error, Handle.Ctx>: Context.set_cookie(Unit, c, name, value, options)
def delete_cookie(c: Handle.Ctx, name: String, options: Cookie.Options) -> Result<&2, &2, Cookie.Error, Handle.Ctx>: Context.delete_cookie(Unit, c, name, options)
