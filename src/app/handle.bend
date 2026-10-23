# Network-free entrypoint; only the app dispatcher may perform IO.
import Base
import ./table.bend as Table
import ./context.bend as Context
import ./middleware.bend as Middleware
import ../data/urlencoded.bend as Query
import ../router/methods.bend as Methods
import ../router/spec.bend as Spec
import ../router/pattern.bend as Pattern
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/write_response.bend as Write
import ../http/bytes.bend as Bytes

def Ctx() -> Data: Context.Ctx<Unit>

# Normalize the returned response just as the wire writer would, retaining the
# HEAD representation length in headers while returning an empty body.
def normalized(+method: Request.Method, +res: Response.Res) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{status, Write.response_headers(method, res), Write.payload(method, res), rep}

def finish_valid(method: Request.Method, res: Response.Res, valid: Bool) -> Response.Res:
  match valid:
    case True{}: normalized(method, res)
    case False{}: normalized(method, Response.body(500, [], []))

def finish(method: Request.Method, +res: Response.Res) -> Response.Res:
  finish_valid(method, res, Response.valid(res))

# Routing failures are terminals inside the onion, just like user handlers.
def terminal(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), resolution: Methods.Resolution<Tag>, ctx: Context.Ctx<Vars>, env: Env) -> IO(Response.Res):
  match resolution:
    case Methods.NotFound{}:
      IO.pure(Response.Res, Context.not_found(Vars, ctx))
    case Methods.MethodNotAllowed{allow}:
      IO.pure(Response.Res, Context.body(Vars, Context.header(Vars, Context.status(Vars, ctx, 405), "allow", Methods.allow_text(allow)), [], None{}))
    case Methods.Found{Spec.Match{index, tag, params}, head_from_get}:
      dispatch(tag, ctx, env)

def params(-Tag: Data, resolution: Methods.Resolution<Tag>) -> Pattern.Params:
  match resolution:
    case Methods.Found{Spec.Match{index, tag, ps}, head_from_get}: ps
    case _: []

def resolved_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), +resolution: Methods.Resolution<Tag>, ids: List<&2, Tag>, +req: Request.Req, body: List<&2, U32>, pairs: List<&2, Query.Entry>, +env: Env) -> IO(Response.Res):
  Request.Req{method, path, query, version, headers} = req
  ctx = Context.variables(Vars, Context.create(req, params(Tag, resolution), body, pairs))
  onion = Middleware.chain(~Context.Ctx<Vars>, ~IO(Response.Res), ~Tag, ~Env, ~middleware, ids, env)
  do IO<Response.Res>:
    res : Response.Res <- onion(ctx, changed => terminal(~Vars, ~Tag, ~Env, ~dispatch, resolution, changed, env))
    return finish(method, res)

def parsed_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, +req: Request.Req, body: List<&2, U32>, parsed_query: Result<&2, &2, Query.Error, List<&2, Query.Entry>>) -> IO(Response.Res):
  Table.Table{entries, compiled, middleware_entries} = table
  Request.Req{+method, +path, query, version, headers} = req
  match parsed_query:
    case Fail{error}: IO.pure(Response.Res, finish(method, Response.text(400, "Bad Request")))
    case Done{pairs}:
      resolved_with(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, Methods.resolve(Tag, compiled, path, method, Methods.defaults()), Table.selected(Tag, middleware_entries, path), req, body, pairs, env)

def handle_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, +req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  Request.Req{method, path, query, version, headers} = req
  parsed_with(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, table, env, req, body, Context.query_pairs(query))

# Existing apps keep their dispatcher signature. Registering middleware requires
# handle_with/serve_with so no identifier can be silently ignored.
def unconfigured(-Tag: Data, -Env: Data, tag: Tag, ctx: Ctx, env: Env, next: Ctx -> IO(Response.Res)) -> IO(Response.Res):
  IO.die(Response.Res, 1, "Bendo middleware requires handle_with or serve_with")

def handle(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  handle_with(~Unit, ~Tag, ~Env, ~dispatch, ~(tag => ctx => env => next => unconfigured(Tag, Env, tag, ctx, env, next)), table, env, req, body)
