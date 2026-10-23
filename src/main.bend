# Public Bendo entrypoint. Route tags and startup environments are app-owned Data.
import Base
import ./app/config.bend as Config
import ./app/table.bend as Table
import ./app/handle.bend as Handle
import ./app/context.bend as Context
import ./app/store.bend as Store
import ./data/json.bend as Json
import ./serve.bend as Serve
import ./http/request.bend as Request
import ./http/response.bend as Response
import ./router/methods.bend as Methods
import ./router/router.bend as Router

def Req() -> Data: Request.Req
def Res() -> Data: Response.Res
def Ctx() -> Data: Handle.Ctx
def Context(-Vars: Data) -> Data: Context.Ctx<Vars>
def ServerConfig() -> Data: Config.Config
def RouterKind() -> Data: Router.RouterKind
def Routes(-Tag: Data) -> Data: Table.Table<Tag>

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

def get(-Tag: Data, path: String, tag: Tag) -> Methods.Registration(Tag): Methods.get(Tag, path, tag)
def head(-Tag: Data, path: String, tag: Tag) -> Methods.Registration(Tag): Methods.head(Tag, path, tag)
def post(-Tag: Data, path: String, tag: Tag) -> Methods.Registration(Tag): Methods.post(Tag, path, tag)
def put(-Tag: Data, path: String, tag: Tag) -> Methods.Registration(Tag): Methods.put(Tag, path, tag)
def patch(-Tag: Data, path: String, tag: Tag) -> Methods.Registration(Tag): Methods.patch(Tag, path, tag)
def delete(-Tag: Data, path: String, tag: Tag) -> Methods.Registration(Tag): Methods.delete(Tag, path, tag)
def options(-Tag: Data, path: String, tag: Tag) -> Methods.Registration(Tag): Methods.options(Tag, path, tag)
def all(-Tag: Data, path: String, tag: Tag) -> Methods.Registration(Tag): Methods.all(Tag, path, tag)
def on(-Tag: Data, methods: List<&2, Request.Method>, path: String, tag: Tag) -> Methods.Registration(Tag): Methods.on(Tag, methods, path, tag)
def routes(-Tag: Data, entries: List<&2, Methods.Registration(Tag)>) -> Result<&2, &2, Methods.BuildError, Table.Table<Tag>>: Table.build(Tag, entries)

def handle(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  Handle.handle(~Tag, ~Env, ~dispatch, table, env, req, body)

def serve(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  Serve.run(~Tag, ~Env, ~dispatch, table, env, config)

# Store operations use a prefix because B.get registers routes.
def Store(-S: Data) -> Data: Store.Store<S>
def StoreError() -> Data: Store.Error

def store(-S: Data, initial: S) -> IO(Store.Store<S>):
  Store.store(S, initial)

def store_with_timeout(-S: Data, initial: S, timeout_ms: U32) -> IO(Store.Store<S>):
  Store.store_with_timeout(S, initial, timeout_ms)

def store_get(-S: Data, handle: Store.Store<S>) -> IO(Result<&2, &2, Store.Error, S>):
  Store.get(S, handle)

def store_set(-S: Data, handle: Store.Store<S>, value: S) -> IO(Result<&2, &2, Store.Error, Unit>):
  Store.set(S, handle, value)

def store_update(-S: Data, handle: Store.Store<S>, change: S -> S) -> IO(Result<&2, &2, Store.Error, S>):
  Store.update(S, handle, change)
