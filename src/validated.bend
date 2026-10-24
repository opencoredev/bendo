# Entrypoints that validate route schemas (BND-36); see docs/validation.md.
# They are B.handle, B.serve and friends with the schema decoder linked in.
# The plain entrypoints in main.bend link none, so an app that declares no
# schemas compiles without it, and they refuse to start a table that does.
# `--bendo-routes` prints the manifest with every route's effective schemas
# (BND-37's format), taken from the table itself.
import Base
import ./app/handle.bend as Handle
import ./serve.bend as Serve
import ./app/validate.bend as Validate
import ./app/table.bend as Table
import ./app/context.bend as Context
import ./app/config.bend as Config
import ./http/request.bend as Request
import ./http/response.bend as Response
import ./app/manifest.bend as Manifest
import ./app/manifest-schemas.bend as ManifestSchemas
import ./app/table-schemas.bend as TableSchemas
import ./serve-schemas.bend as ServeSchemas

def handle(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  Handle.handle_checked(~Validate.run, ~Unit, ~Tag, ~Env, ~dispatch, ~(tag => ctx => env => next => Handle.unconfigured(Tag, Env, tag, ctx, env, next)), table, env, req, body)

def handle_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  Handle.handle_checked(~Validate.run, ~Vars, ~Tag, ~Env, ~dispatch, ~middleware, table, env, req, body)

def startup(~Vars: Data, ~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), +table: Table.Table<Tag>, env: Env, config: Config.Config, manifest: Bool) -> IO(Unit):
  match manifest:
    case True{}: ServeSchemas.print_manifest(ManifestSchemas.json_schemas(Tag, table, TableSchemas.effective(Tag, table)))
    case False{}: Serve.startup_limits_with(~Validate.run, ~Vars, ~Tag, ~select, ~Env, ~dispatch, ~middleware, table, env, config, False{})

def run_validated(~Vars: Data, ~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    startup(~Vars, ~Tag, ~select, ~Env, ~dispatch, ~middleware, table, env, config, Manifest.argv(args))

def serve(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  run_validated(~Unit, ~Tag, ~(tag => None{}), ~Env, ~dispatch, ~(tag => ctx => env => next => Handle.unconfigured(Tag, Env, tag, ctx, env, next)), table, env, config)

def serve_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  run_validated(~Vars, ~Tag, ~(tag => None{}), ~Env, ~dispatch, ~middleware, table, env, config)

def serve_limits_with(~Vars: Data, ~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  run_validated(~Vars, ~Tag, ~select, ~Env, ~dispatch, ~middleware, table, env, config)
