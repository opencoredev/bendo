# BND-37: serve an app with route schemas. Import this module beside
# main.bend only when an app has schemas; apps without them never compile the
# schema exporter. `--bendo-routes` prints the manifest with route schemas, or
# names the problem on stderr and exits 1. Serving is otherwise exactly
# B.serve: this list is not validated at request time. Route validation
# (BND-36) reads the table's own schemas and serves through src/validated.bend.
# See docs/manifest.md#route-schemas.
import Base
import ./serve.bend as Serve
import ./app/config.bend as Config
import ./app/table.bend as Table
import ./app/handle.bend as Handle
import ./app/context.bend as Context
import ./app/manifest.bend as Manifest
import ./app/manifest-schemas.bend as ManifestSchemas
import ./app/route-schemas.bend as RS
import ./app/validate.bend as Validate
import ./http/response.bend as Response
import ./data/json.bend as Json
import ./data/schema.bend as Schema
import ./data/json-schema.bend as JsonSchema

def RouteSchemas() -> Data: RS.RouteSchemas
def no_schemas() -> RS.RouteSchemas: RS.none()
def route_schemas(params: Maybe<&2, Schema.Schema>, query: Maybe<&2, Schema.Schema>, headers: Maybe<&2, Schema.Schema>, body: Maybe<&2, Schema.Schema>, response: Maybe<&2, Schema.Schema>) -> RS.RouteSchemas:
  RS.RouteSchemas{params, query, headers, body, response}
def json_schema(s: Schema.Schema) -> Json.Json: JsonSchema.document(s)
def routes_json(-Tag: Data, table: Table.Table<Tag>, schemas: List<&2, RS.RouteSchemas>) -> Result<&2, &2, ManifestSchemas.AttachError, String>: ManifestSchemas.json_schemas(Tag, table, schemas)

def print_manifest(r: Result<&2, &2, ManifestSchemas.AttachError, String>) -> IO(Unit):
  match r:
    case Done{text}:
      do IO<Unit>:
        IO.print(text)
        IO.exit(0)
    case Fail{e}:
      do IO<Unit>:
        IO.print_err("bendo: " ++ ManifestSchemas.error_text(e))
        IO.exit(1)

def startup_schemas_with(~Vars: Data, ~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, schemas: List<&2, RS.RouteSchemas>, env: Env, config: Config.Config, manifest: Bool) -> IO(Unit):
  match manifest:
    case True{}: print_manifest(ManifestSchemas.json_schemas(Tag, table, schemas))
    case False{}: Serve.startup_limits_with(~Validate.skip, ~Vars, ~Tag, ~select, ~Env, ~dispatch, ~middleware, table, env, config, False{})

def run_schemas_limits_with(~Vars: Data, ~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, schemas: List<&2, RS.RouteSchemas>, env: Env, config: Config.Config) -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    startup_schemas_with(~Vars, ~Tag, ~select, ~Env, ~dispatch, ~middleware, table, schemas, env, config, Manifest.argv(args))

def run_schemas_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, schemas: List<&2, RS.RouteSchemas>, env: Env, config: Config.Config) -> IO(Unit):
  run_schemas_limits_with(~Vars, ~Tag, ~(tag => None{}), ~Env, ~dispatch, ~middleware, table, schemas, env, config)

def run_schemas(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, schemas: List<&2, RS.RouteSchemas>, env: Env, config: Config.Config) -> IO(Unit):
  run_schemas_with(~Unit, ~Tag, ~Env, ~dispatch, ~(tag => ctx => env => next => Handle.unconfigured(Tag, Env, tag, ctx, env, next)), table, schemas, env, config)

def serve_schemas(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, schemas: List<&2, RS.RouteSchemas>, env: Env, config: Config.Config) -> IO(Unit):
  run_schemas(~Tag, ~Env, ~dispatch, table, schemas, env, config)

def serve_schemas_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, schemas: List<&2, RS.RouteSchemas>, env: Env, config: Config.Config) -> IO(Unit):
  run_schemas_with(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, table, schemas, env, config)

def serve_schemas_limits_with(~Vars: Data, ~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, schemas: List<&2, RS.RouteSchemas>, env: Env, config: Config.Config) -> IO(Unit):
  run_schemas_limits_with(~Vars, ~Tag, ~select, ~Env, ~dispatch, ~middleware, table, schemas, env, config)
