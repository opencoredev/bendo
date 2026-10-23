# Network-free entrypoint; only the app dispatcher may perform IO.
import Base
import ./table.bend as Table
import ./context.bend as Context
import ./middleware.bend as Middleware
import ./hooks.bend as Hooks
import ./observability.bend as Obs
import ../data/urlencoded.bend as Query
import ../router/methods.bend as Methods
import ../router/router.bend as Router
import ../router/spec.bend as Spec
import ../router/pattern.bend as Pattern
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/write_response.bend as Write
import ../http/bytes.bend as Bytes
import ../http/date_response.bend as DateResponse

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

# Attach route captures without losing variables or pending response headers.
def with_params(-Vars: Data, ctx: Context.Ctx<Vars>, ps: Pattern.Params) -> Context.Ctx<Vars>:
  Context.Ctx{req, old, body, pairs, code, hs, vars, observation} = ctx
  Context.Ctx{req, ps, body, pairs, code, hs, vars, observation}

def resolved_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), +resolution: Methods.Resolution<Tag>, +layers: List<&2, Table.Middleware<Tag>>, ctx: Context.Ctx<Vars>, +env: Env, +slot: Chan(Context.Ctx<Vars>)) -> IO(Response.Res):
  +routed = with_params(Vars, ctx, params(Tag, resolution))
  ids = Table.lifecycle_pre(Tag, Table.lifecycle(Tag, layers, Context.path(Vars, routed)))
  onion = Hooks.chain(~Vars, ~Tag, ~Env, ~middleware, ids, env, slot)
  do IO<Response.Res>:
    Hooks.remember(Vars, slot, routed)
    onion(routed, changed => terminal(~Vars, ~Tag, ~Env, ~dispatch, resolution, changed, env))

# Route the context on_request produced, through the configured router. Every
# kind returns Methods.resolve's result (law methods_router_resolve).
def route_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), kind: Router.RouterKind, table: Table.Table<Tag>, +ctx: Context.Ctx<Vars>, env: Env, slot: Chan(Context.Ctx<Vars>)) -> IO(Response.Res):
  Table.Table{entries, compiled, layers} = table
  resolved_with(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, Methods.resolve_with(Tag, kind, compiled, Context.path(Vars, ctx), Context.method(Vars, ctx), Methods.defaults()), layers, ctx, env, slot)

def recover(~Vars: Data, ~Tag: Data, ~Env: Data, ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), ids: List<&2, Tag>, ctx: Context.Ctx<Vars>, env: Env, res: Response.Res, failed: Bool) -> IO(Response.Res):
  match failed:
    case False{}: IO.pure(Response.Res, res)
    case True{}: Hooks.post(~Vars, ~Tag, ~Env, ~middleware, ids, ctx, env, res)

def validated(res: Response.Res, valid: Bool) -> Response.Res:
  match valid:
    case True{}: res
    case False{}: Response.body(500, [], [])

def error_response(res: Response.Res) -> Bool:
  Response.Res{code, hs, body, rep} = res
  U32.is_ge(code, 400)

# Transport owns the deferred action. This internal entrypoint never runs it.
def parsed_pending(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), kind: Router.RouterKind, +table: Table.Table<Tag>, +env: Env, +req: Request.Req, body: List<&2, U32>, parsed_query: Result<&2, &2, Query.Error, List<&2, Query.Entry>>) -> IO(Response.Res & IO(Unit)):
  Table.Table{entries, compiled, +layers} = table
  Request.Req{+method, path, query, version, headers} = req
  match parsed_query:
    case Fail{error}: IO.pure(Response.Res & IO(Unit), (finish(method, Response.text(400, "Bad Request")), IO.pure(Unit, Unit{})))
    case Done{pairs}:
      +ctx = Context.variables(Vars, Context.create(req, [], body, pairs))
      +plan = Table.lifecycle(Tag, layers, path)
      do IO<Response.Res & IO(Unit)>:
        +slot : Chan(Context.Ctx<Vars>) <- Chan.new(Context.Ctx<Vars>, 1)
        seeded : Result<&1, &1, Context.Ctx<Vars>, Unit> <- Chan.send(Context.Ctx<Vars>, slot, ctx)
        Hooks.sent(Context.Ctx<Vars>, seeded)
        res : Response.Res <- Hooks.chain(~Vars, ~Tag, ~Env, ~middleware, Table.lifecycle_request(Tag, plan), env, slot, ctx, changed => route_with(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, kind, table, changed, env, slot))
        +latest : Context.Ctx<Vars> <- Hooks.recall(Vars, slot)
        after : Response.Res <- Hooks.post(~Vars, ~Tag, ~Env, ~middleware, Table.lifecycle_after(Tag, plan), latest, env, res)
        +mapped : Response.Res <- Hooks.post(~Vars, ~Tag, ~Env, ~middleware, Table.lifecycle_map(Tag, plan), latest, env, after)
        +checked : Response.Res = validated(mapped, Response.valid(mapped))
        recovered : Response.Res <- recover(~Vars, ~Tag, ~Env, ~middleware, Table.lifecycle_errors(Tag, plan), latest, env, checked, error_response(checked))
        +final : Response.Res <- Obs.finalize(Context.observation(Vars, latest), finish(method, recovered))
        return (final, Hooks.observe(~Vars, ~Tag, ~Env, ~middleware, Table.lifecycle_observers(Tag, plan), latest, env, final))

def pending_routed(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), kind: Router.RouterKind, table: Table.Table<Tag>, env: Env, +req: Request.Req, body: List<&2, U32>) -> IO(Response.Res & IO(Unit)):
  Request.Req{method, path, query, version, headers} = req
  parsed_pending(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, kind, table, env, req, body, Context.query_pairs(query))

def pending_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res & IO(Unit)):
  pending_routed(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, Router.default_kind(), table, env, req, body)

def returned(result: Response.Res & IO(Unit)) -> IO(Response.Res):
  (res, after) = result
  do IO<Response.Res>:
    dated : Response.Res <- DateResponse.ensure(res)
    after
    return dated

# For network-free consumers, returning the normalized response is the boundary.
def handle_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  do IO<Response.Res>:
    result : Response.Res & IO(Unit) <- pending_with(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, table, env, req, body)
    returned(result)

# Existing apps keep their dispatcher signature. Registering middleware requires
# handle_with/serve_with so no identifier can be silently ignored.
def unconfigured(-Tag: Data, -Env: Data, tag: Tag, ctx: Ctx, env: Env, next: Ctx -> IO(Response.Res)) -> IO(Response.Res):
  IO.die(Response.Res, 1, "Bendo middleware requires handle_with or serve_with")

def handle(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  handle_with(~Unit, ~Tag, ~Env, ~dispatch, ~(tag => ctx => env => next => unconfigured(Tag, Env, tag, ctx, env, next)), table, env, req, body)
