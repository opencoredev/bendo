# Public Bendo entrypoint. Route tags and startup environments are app-owned Data.
import Base
import ./app/config.bend as Config
import ./app/table.bend as Table
import ./app/handle.bend as Handle
import ./serve.bend as Serve
import ./http/request.bend as Request
import ./http/response.bend as Response
import ./router/methods.bend as Methods
import ./router/router.bend as Router

def Req() -> Data: Request.Req
def Res() -> Data: Response.Res
def Ctx() -> Data: Handle.Ctx
def ServerConfig() -> Data: Config.Config
def RouterKind() -> Data: Router.RouterKind
def Routes(-Tag: Data) -> Data: Table.Table<Tag>

def config() -> Config.Config: Config.defaults()
def spec() -> Router.RouterKind: Router.Spec{}
def trie() -> Router.RouterKind: Router.Trie{}
def text(status: U32, value: String) -> Response.Res: Response.text(status, value)
def body(status: U32, headers: List<&2, Request.Header>, bytes: List<&2, U32>) -> Response.Res: Response.body(status, headers, bytes)
def not_modified(headers: List<&2, Request.Header>, representation: Maybe<&2, List<&2, U32>>) -> Response.Res: Response.not_modified(headers, representation)

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
