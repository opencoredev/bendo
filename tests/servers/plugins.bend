import Base
import ../../src/main.bend as B
import ../../src/app/table.bend as T
import ../../src/app/context.bend as C
import ../../src/router/methods.bend as M
import ../../src/http/response.bend as R

type Tag is Data:
  Handler{}
  Say{word: String}
  Trace{label: String}
  PostTrace{label: String}

type Vars is Data:
  Vars{trace: String}

def trace(value: Maybe<&2, Vars>) -> String:
  match value:
    case None{}: ""
    case Some{Vars{text}}: text

def add(+c: B.Context(Vars), label: String) -> B.Context(Vars):
  C.set(Vars, c, Vars{trace(C.get(Vars, c)) ++ label ++ ","})

def append(res: B.Res, label: String) -> B.Res:
  R.Res{code, hs, body, rep} = res
  R.Res{code, hs, List.append(&2, U32, body, R.utf8("," ++ label)), rep}

def handler_impl(tag: Tag, +c: B.Context(Vars)) -> IO(B.Res):
  match tag:
    case Say{word}: IO.pure(B.Res, C.text(Vars, c, trace(C.get(Vars, c)) ++ word))
    case _: IO.pure(B.Res, C.text(Vars, c, trace(C.get(Vars, c)) ++ "handler"))

def middleware_impl(tag: Tag, +c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Trace{label}: next(add(c, label))
    case PostTrace{label}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return append(res, label)
    case _: next(c)

def handler(tag: Tag, c: B.Context(Vars), env: Unit) -> IO(B.Res):
  handler_impl(tag, c)

def middleware(tag: Tag, c: B.Context(Vars), env: Unit, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  middleware_impl(tag, c, next)

# B adds a route and a global before-handle hook.
def plugin_b(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("b"), app, a => B.register(Tag, a, [B.get(Tag, "/b", Handler{}), B.before_handle(Tag, Trace{"b"})]))

# A uses B first, then adds its own route, middleware and response hook.
def plugin_a(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("a"), app, a => B.register(Tag, plugin_b(a), [B.get(Tag, "/a", Handler{}), B.use(Tag, Trace{"a-mw"}), B.after_handle(Tag, PostTrace{"a-after"})]))

# Anonymous: applies on every use.
def plugin_anon(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.register(Tag, app, [B.get(Tag, "/anon", Handler{}), B.before_handle(Tag, Trace{"anon"})])

# Uses itself inside its own body; the inner use must be skipped.
def plugin_self(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("self"), app, a => B.register(Tag, a, [B.get(Tag, "/self", Handler{})]))

def plugin_self_outer(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("self"), app, a => plugin_self(B.register(Tag, a, [B.get(Tag, "/self", Say{"outer"})])))

# Identity is the name only: the first configuration wins.
def plugin_config(word: String, app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("config"), app, a => B.register(Tag, a, [B.get(Tag, "/config", Say{word})]))

# The seed makes each configuration a separate identity.
def plugin_seeded(+word: String, app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_seed("seeded", word), app, a => B.register(Tag, a, [B.get(Tag, "/seeded/" ++ word, Say{word})]))

# A plugin whose hook is scoped to whatever scope first uses it.
def plugin_scoped(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("scoped"), app, a => B.register(Tag, a, [B.get(Tag, "/thing", Say{"scoped"}), B.before_handle(Tag, Trace{"scoped-hook"})]))

def plugin_mounted(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("mounted"), app, a => B.register(Tag, a, [B.use(Tag, Trace{"mount-mw"}), B.get(Tag, "/x", Handler{})]))

def plugin_guarded(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("guarded"), app, a => B.register(Tag, a, [B.get(Tag, "/guarded", Handler{})]))

def scopes(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.use_guard(Tag, B.use_route(Tag, B.use_group(Tag, B.use_group(Tag, app,
    "/a", [], a => plugin_scoped(B.register(Tag, a, [B.get(Tag, "/other", Handler{})]))),
    "/b", [], b => plugin_scoped(B.register(Tag, b, [B.get(Tag, "/sibling", Handler{})]))),
    "/m", plugin_mounted),
    B.guard_options(Tag, [B.hook(Tag, T.BeforeHandle{}, Trace{"guard"})]), plugin_guarded)

def configured(app: B.Builder(Tag)) -> B.Builder(Tag):
  plugin_seeded("two", plugin_seeded("one", plugin_seeded("one", plugin_config("second", plugin_config("first", app)))))

def assembled() -> B.Builder(Tag):
  scopes(configured(plugin_self_outer(plugin_anon(plugin_anon(B.use_plugin(Tag, plugin_a(B.app_from(Tag, [B.get(Tag, "/root", Handler{})])), plugin_b))))))

def ready(result: Result<&2, &2, M.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "bad plugin table")
    case Done{table}:
      B.serve_with(~Vars, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.app_routes(Tag, assembled()))
