import Base
import ../../src/main.bend as B
import ../../src/serve.bend as Serve
import ../../src/app/handle.bend as Handle
import ../../src/app/validate.bend as Validate
import ../../src/app/context.bend as C
import ../../src/app/table.bend as Table
import ../../src/net/conn_info.bend as Conn
import ../../src/http/request.bend as Request
import ../../src/http/response.bend as Response
import ../../src/http/stream_types.bend as S
import ../../src/router/methods.bend as Methods
import ../../src/data/schema.bend as Schema

# BND-96 differential fixture: one app without route schemas, served through
# the plain pipeline or forced through the validating one, chosen by
# BENDO_TEST_PIPELINE at startup. The `-schemas` pipelines add a route with only
# a response schema and serve it through the validating pipeline as it is, or
# with the request step forced as before BND-96. Every trace goes to stderr.

type Tag is Data:
  Hello{}
  Json{}
  Failing{}
  Thrown{}
  Target{}
  Stream{}
  Socket{}
  Missing{}
  Rewrite{}
  Before{}
  After{}
  Map{}
  Recover{}
  Observe{}
  Seed{}
  Seeded{}
  Builtin{id: B.Builtin}

type Chunks is Data:
  Chunks{left: Nat}

def step(state: Chunks) -> IO(S.Step<Chunks>):
  match state:
    case Chunks{0n}: IO.pure(S.Step<Chunks>, S.End{Chunks{0n}})
    case Chunks{1n+(+n)}:
      do IO<S.Step<Chunks>>:
        IO.print_err("pull:" ++ Nat.show(n))
        return S.Chunk{[120, 121], Chunks{n}}

def cleanup(state: Chunks) -> IO(Unit):
  IO.print_err("stream-cleanup")

def session(label: String, s: Socket, rest: List<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    IO.print_err("ws-open:" ++ label ++ ":" ++ Nat.show(List.length(&2, U32, rest)))
    Socket.close(s)

def ws_cleanup(label: String) -> IO(Unit):
  IO.print_err("ws-cleanup:" ++ label)

# Whether the context still carries the decoded body an early hook stored.
def seeded_mark(found: Maybe<&2, Schema.Value>) -> String:
  match found:
    case Some{v}: "kept"
    case None{}: "cleared"

def seeded(c: B.Context(Unit)) -> String:
  seeded_mark(C.valid_body(Unit, c))

def handle(tag: Tag, +c: B.Context(Unit), env: Unit) -> IO(B.Res):
  match tag:
    case Seeded{}: IO.pure(B.Res, C.body(Unit, C.header(Unit, c, "x-seeded", seeded(c)), Response.utf8("{\"count\":0}"), Some{"application/json"}))
    case Json{}:
      do IO<B.Res>:
        db : Bool <- B.timing_mark(Unit, c, "db", 4n)
        return C.body(Unit, C.header(Unit, c, "etag", "\"v1\""), Response.utf8("{\"a\":[1,true]}"), Some{"application/json"})
    case Failing{}: IO.pure(B.Res, Response.text(500, "handler failed"))
    case Thrown{}: IO.pure(B.Res, C.error(Unit, c, B.http_error(418, "teapot")))
    case Target{}: IO.pure(B.Res, C.text(Unit, c, "target:" ++ Maybe.default(&2, String, C.param(Unit, c, "id"), "none")))
    case Stream{}: B.stream(~Unit, ~Chunks, ~step, ~cleanup, c, Chunks{3n}, B.stream_config())
    case Socket{}: B.websocket(~Unit, ~String, ~session, ~ws_cleanup, c, "ws", B.websocket_config())
    case _: IO.pure(B.Res, C.text(Unit, c, "hello"))

def handler(tag: Tag, c: B.Context(Unit), env: Unit) -> IO(B.Res):
  handle(tag, c, env)

def rewritten(+c: B.Context(Unit), next: B.Context(Unit) -> IO(B.Res), path: String) -> IO(B.Res):
  match path:
    case "/rewrite": next(C.rewrite(Unit, c, Request.Get{}, "/target/7"))
    case _: next(c)

def mapped(+c: B.Context(Unit), res: B.Res, path: String) -> B.Res:
  match path:
    case "/mapped": B.text(C.status(Unit, c, 201), "mapped")
    case "/policy/mapped": Response.text(201, "mapped")
    case _: res

def recovered(res: B.Res, path: String) -> B.Res:
  match path:
    case "/recover": Response.text(503, "recovered")
    case "/policy/recover": Response.text(503, "recovered")
    case _: res

def middleware_go(tag: Tag, +c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case Rewrite{}: rewritten(c, next, C.path(Unit, c))
    case Before{}:
      do IO<B.Res>:
        IO.print_err("before:" ++ C.path(Unit, c))
        next(c)
    case After{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        IO.print_err("after:" ++ C.path(Unit, c) ++ ":" ++ seeded(c))
        return res
    case Map{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        IO.print_err("map:" ++ C.path(Unit, c))
        return mapped(c, res, C.path(Unit, c))
    case Recover{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        IO.print_err("error:" ++ C.path(Unit, c))
        return recovered(res, C.path(Unit, c))
    case Missing{}:
      do IO<B.Res>:
        IO.print_err("not-found:" ++ C.path(Unit, c))
        next(c)
    # Middleware can store decoded values through the public Context API.
    case Seed{}: next(C.with_values(Unit, c, Validate.Values{None{}, None{}, None{}, Some{Schema.VString{"seeded"}}}))
    case Observe{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        IO.print_err("observed:" ++ C.path(Unit, c))
        return res
    case _: next(c)

def middleware(tag: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  middleware_go(tag, c, env, next)

# The validating pipeline, forced: transport_routed with `validates` set, so
# a table without schemas still runs parsed_checked.
def respond_checked(req: Request.Req, body: List<&2, U32>, state: Serve.State<Tag, Unit>, close: Bool, peer: Maybe<&2, Conn.ConnInfo>) -> IO(Serve.Reply):
  Serve.State{table, hooks, env, router, limit, mode, validates} = state
  do IO<Serve.Reply>:
    result : Response.Res & (S.Transport & IO(Unit)) <- Handle.transport_routed(~Validate.run, ~Unit, ~Tag, ~Unit, ~handler, ~middleware, router, mode, table, hooks, env, req, body, peer, True{})
    return Serve.prepare_transport(result, close)

# The decoder, with a probe that says it decodes nothing, so every route that
# declares a schema runs the request step, as every one did before BND-96.
def stepping(job: Validate.Job) -> Validate.Answer:
  match job:
    case Validate.Probe{}: Validate.Enabled{False{}}
    case _: Validate.run(job)

def respond_stepped(req: Request.Req, body: List<&2, U32>, state: Serve.State<Tag, Unit>, close: Bool, peer: Maybe<&2, Conn.ConnInfo>) -> IO(Serve.Reply):
  Serve.State{table, hooks, env, router, limit, mode, validates} = state
  do IO<Serve.Reply>:
    result : Response.Res & (S.Transport & IO(Unit)) <- Handle.transport_routed(~stepping, ~Unit, ~Tag, ~Unit, ~handler, ~middleware, router, mode, table, hooks, env, req, body, peer, True{})
    return Serve.prepare_transport(result, close)

def serving(table: Table.Table<Tag>, pipeline: String) -> IO(Unit):
  match pipeline:
    case "checked": Serve.startup_serving(~Validate.run, ~Tag, ~(tag => None{}), ~Unit, ~(req => body => state => close => peer => respond_checked(req, body, state, close, peer)), table, Unit{}, B.config(), False{})
    case "checked-schemas": Serve.startup_serving(~Validate.run, ~Tag, ~(tag => None{}), ~Unit, ~(req => body => state => close => peer => respond_checked(req, body, state, close, peer)), table, Unit{}, B.config(), False{})
    case "stepped-schemas": Serve.startup_serving(~Validate.run, ~Tag, ~(tag => None{}), ~Unit, ~(req => body => state => close => peer => respond_stepped(req, body, state, close, peer)), table, Unit{}, B.config(), False{})
    case _: Serve.startup_plain(~Unit, ~Tag, ~(tag => None{}), ~Unit, ~handler, ~middleware, table, Unit{}, B.config(), False{})

def pipeline_of(found: Result<&1, &1, U32 & String, String>) -> String:
  match found:
    case Done{value}: value
    case Fail{e}: "plain"

def ready(+pipeline: String, result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: serving(table, pipeline)

def report_schema() -> Schema.Schema:
  Schema.ObjectSchema{[Schema.Field{"count", Schema.IntegerSchema{Some{"0"}, None{}}, Schema.Required{}}], Schema.Strict{}}

# The route with only a response schema, in the `-schemas` pipelines only.
def schema_routes(pipeline: String) -> List<&2, Table.Entry<Tag>>:
  match pipeline:
    case "checked-schemas": [B.with_schemas(Tag, B.get(Tag, "/seeded/report", Seeded{}), B.schemas([B.response_schema(report_schema())]))]
    case "stepped-schemas": [B.with_schemas(Tag, B.get(Tag, "/seeded/report", Seeded{}), B.schemas([B.response_schema(report_schema())]))]
    case _: []

def entries(+pipeline: String) -> List<&2, Table.Entry<Tag>>:
  List.append(&2, Table.Entry<Tag>, schema_routes(pipeline), [
    B.on_request(Tag, Builtin{B.request_id()}),
    B.on_request(Tag, Builtin{B.server_timing()}),
    B.on_request(Tag, Builtin{B.logger()}),
    B.on_request(Tag, Rewrite{}),
    B.before_handle(Tag, Before{}),
    B.after_handle(Tag, After{}),
    B.map_response(Tag, Map{}),
    B.on_error(Tag, Recover{}),
    B.on_not_found(Tag, Missing{}),
    B.on_after_response(Tag, Observe{}),
    B.use_path(Tag, "/policy/*", Builtin{B.cors(B.cors_allow([B.cors_origin_credentials("https://app.example")]))}),
    B.use_path(Tag, "/policy/*", Builtin{B.secure_headers()}),
    B.use(Tag, Builtin{B.pretty_json()}),
    B.use_path(Tag, "/seeded/*", Seed{}),
    B.get(Tag, "/seeded/free", Seeded{}),
    B.get(Tag, "/", Hello{}),
    B.get(Tag, "/json", Json{}),
    B.get(Tag, "/failing", Failing{}),
    B.get(Tag, "/recover", Failing{}),
    B.get(Tag, "/thrown", Thrown{}),
    B.get(Tag, "/mapped", Hello{}),
    B.get(Tag, "/target/:id", Target{}),
    B.post(Tag, "/only-post", Hello{}),
    B.get(Tag, "/stream", Stream{}),
    B.get(Tag, "/policy/stream", Stream{}),
    B.get(Tag, "/policy/hello", Hello{}),
    B.get(Tag, "/policy/mapped", Hello{}),
    B.get(Tag, "/policy/recover", Failing{}),
    B.get(Tag, "/ws", Socket{}),
    B.get(Tag, "/policy/ws", Socket{})
  ])

def main() -> IO(Unit):
  do IO<Unit>:
    found : Result<&1, &1, U32 & String, String> <- IO.get_env("BENDO_TEST_PIPELINE")
    +pipeline : String = pipeline_of(found)
    ready(pipeline, B.routes(Tag, entries(pipeline)))
