# Network-free entrypoint; only the app dispatcher may perform IO.
import Base
import ./table.bend as Table
import ../router/methods.bend as Methods
import ../router/router.bend as Router
import ../router/spec.bend as Spec
import ../router/pattern.bend as Pattern
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/write_response.bend as Write
import ../http/bytes.bend as Bytes

# Minimal context until BND-21 adds the full request/response API.
type Ctx is Data:
  Ctx{req: Request.Req, params: Pattern.Params, body: List<&2, U32>}

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

def resolved(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Ctx -> Env -> IO(Response.Res), resolution: Methods.Resolution<Tag>, +req: Request.Req, body: List<&2, U32>, env: Env) -> IO(Response.Res):
  match resolution req:
    case Methods.NotFound{} Request.Req{method, path, query, version, headers}:
      IO.pure(Response.Res, finish(method, Response.text(404, "Not Found")))
    case Methods.MethodNotAllowed{allow} Request.Req{method, path, query, version, headers}:
      IO.pure(Response.Res, finish(method, Response.body(405, [Request.Header{"allow", Bytes.encode(Methods.allow_text(allow))}], [])))
    case Methods.Found{Spec.Match{index, tag, params}, head_from_get} Request.Req{+method, path, query, version, headers}:
      do IO<Response.Res>:
        res : Response.Res <- dispatch(tag, Ctx{req, params, body}, env)
        return finish(method, res)

# Resolve through the configured router; every kind returns Methods.resolve's
# result (law methods_router_resolve).
def handle_with(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Ctx -> Env -> IO(Response.Res), kind: Router.RouterKind, table: Table.Table<Tag>, env: Env, +req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  Table.Table{entries, compiled} = table
  Request.Req{+method, +path, query, version, headers} = req
  resolved(~Tag, ~Env, ~dispatch, Methods.resolve_with(Tag, kind, compiled, path, method, Methods.defaults()), req, body, env)

def handle(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  handle_with(~Tag, ~Env, ~dispatch, Router.default_kind(), table, env, req, body)
