import Base
import ../../src/main.bend as B
import ../../src/app/table.bend as T
import ../../src/router/methods.bend as M

type Tag is Data:
  Handler{}
  Failure{}
  Mark{name: String}
  Recover{}
  Missing{}

def value(v: Maybe<&2, String>) -> String:
  match v:
    case None{}: "-"
    case Some{s}: s

def handler_impl(tag: Tag, +c: B.Ctx, env: Unit) -> IO(B.Res):
  match tag:
    case Failure{}: IO.pure(B.Res, B.error(c, B.http_error(418, "teapot")))
    case _: IO.pure(B.Res, B.text(c, value(B.param(c, "tenant")) ++ ":" ++ value(B.param(c, "id")) ++ ":" ++ value(B.param(c, "tail"))))

def handler(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  handler_impl(tag, c, env)

def middleware(tag: Tag, c: B.Ctx, env: Unit, next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Mark{name}: next(B.header(c, name, "yes"))
    case Recover{}: IO.pure(B.Res, B.text(B.status(c, 202), "child recovered"))
    case Missing{}: IO.pure(B.Res, B.text(B.status(c, 404), "parent missing"))
    case _: next(c)

def child() -> List<&2, B.Registration(Tag)>:
  List.concat(&2, B.Registration(Tag), [
    [B.use(Tag, Mark{"x-child"}), B.use_path(Tag, "/items/:id{int}", Mark{"x-item"}),
     B.before_handle(Tag, Mark{"x-before"}), B.on_error(Tag, Recover{}), B.on_not_found(Tag, Recover{}),
     B.get(Tag, "/items/:id{int}", Handler{}), B.get(Tag, "/fail", Failure{}), B.get(Tag, "/", Handler{})],
    B.guard(Tag, B.guard_options(Tag, [B.hook(Tag, T.BeforeHandle{}, Mark{"x-guard"})]), [B.post(Tag, "/guarded", Handler{})])])

def entries() -> List<&2, B.Registration(Tag)>:
  List.concat(&2, B.Registration(Tag), [
    [B.on_not_found(Tag, Missing{}), B.get(Tag, "/outside", Handler{}), B.get(Tag, "/api/v1/sibling", Handler{})],
    B.route(Tag, "/api/v1/", child()),
    B.base_path(Tag, "/:tenant", [B.get(Tag, "/users/:id", Handler{})]),
    B.group(Tag, "/one", [], B.group(Tag, "/two/", [], B.group(Tag, "/three", [], [B.get(Tag, "/deep", Handler{})]))),
    B.group(Tag, "/outer", [], B.route(Tag, "/inner", child())),
    B.route(Tag, "/wild", [B.get(Tag, "*", Handler{})]),
    B.route(Tag, "/named", [B.get(Tag, "/*tail", Handler{})]),
    B.group(Tag, "/groupwild", [], [B.get(Tag, "*", Handler{})]),
    B.base_path(Tag, "/", [B.get(Tag, "/identity", Handler{})])])

def serve(table: B.Routes(Tag), show: Bool) -> IO(Unit):
  match show:
    case True{}: B.show_routes(Tag, table)
    case False{}: B.serve_with(~Unit, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def ready(result: Result<&2, &2, M.BuildError, B.Routes(Tag)>, show: Bool) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "invalid composed routes")
    case Done{table}: serve(table, show)

def show_requested(args: List<String>) -> Bool:
  match args:
    case Nil{}: False{}
    case h <> tail: String.eq(h, "--show-routes") || show_requested(tail)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args
    ready(B.routes(Tag, entries()), show_requested(args))
