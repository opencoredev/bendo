# BND-45 fixture: roots come from the environment at startup.
import Base
import ../../src/main.bend as B
import ../../src/router/methods.bend as Methods

type Tag is Data:
  TStatic{}
  TSmall{}
  TNoIndex{}
  TAnyMethod{}
  TApp{}

type Env is Data:
  Env{root: String, app: String}

def static_opts(env: Env) -> B.StaticOptions:
  Env{root, app} = env
  B.static_cache_control(B.static_mounted(B.static_options(root), "/static"), "public, max-age=60")

def small_opts(env: Env) -> B.StaticOptions:
  Env{root, app} = env
  B.static_buffer_bytes(B.static_mounted(B.static_options(root), "/small"), 1000n)

def noindex_opts(env: Env) -> B.StaticOptions:
  Env{root, app} = env
  B.static_index(B.static_mounted(B.static_options(root), "/noindex"), "")

def any_opts(env: Env) -> B.StaticOptions:
  Env{root, app} = env
  B.static_mounted(B.static_options(root), "/any")

def app_opts(env: Env) -> B.StaticOptions:
  Env{root, app} = env
  B.static_options(app)

def dispatch(tag: Tag, c: B.Ctx, env: Env) -> IO(B.Res):
  match tag:
    case TStatic{}: B.serve_static(c, static_opts(env))
    case TSmall{}: B.serve_static(c, small_opts(env))
    case TNoIndex{}: B.serve_static(c, noindex_opts(env))
    case TAnyMethod{}: B.serve_static(c, any_opts(env))
    case TApp{}: B.serve_static(c, app_opts(env))

def ready(env: Env, result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid static routes")
    case Done{table}: B.serve(~Tag, ~Env, ~dispatch, table, env, B.config())

def main() -> IO(Unit):
  do IO<Unit>:
    root : String <- IO.try(String, IO.get_env("BENDO_STATIC_ROOT"))
    app : String <- IO.try(String, IO.get_env("BENDO_STATIC_APP"))
    ready(Env{root, app}, B.routes(Tag, [
      B.get(Tag, "/static/*", TStatic{}),
      B.get(Tag, "/small/*", TSmall{}),
      B.get(Tag, "/noindex/*", TNoIndex{}),
      B.all(Tag, "/any/*", TAnyMethod{}),
      B.get(Tag, "*", TApp{})
    ]))
