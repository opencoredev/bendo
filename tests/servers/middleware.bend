import Base
import ../../src/main.bend as B
import ../../src/app/context.bend as C
import ../../src/http/response.bend as Response
import ../../src/http/request.bend as Request
import ../../src/router/methods.bend as Methods

# The same Data sum supplies identifiers to both closed dispatchers.
type Tag is Data:
  Handler{}
  A{}
  BTag{}
  CTag{}
  Auth{}
  User{}
  Identity{}
  Transform{}
  Invalid{}

type Vars is Data:
  Vars{trace: String, user: String}

def values(c: B.Context(Vars)) -> Vars:
  Maybe.default(&2, Vars, C.get(Vars, c), Vars{"", "unset"})

def before_vars(c: B.Context(Vars), label: String, vars: Vars) -> B.Context(Vars):
  Vars{trace, user} = vars
  C.set(Vars, c, Vars{trace ++ label ++ "-before,", user})

def before(+c: B.Context(Vars), label: String) -> B.Context(Vars):
  before_vars(c, label, values(c))

def after(res: B.Res, label: String) -> B.Res:
  Response.Res{code, hs, body, rep} = res
  +out = List.append(&2, U32, body, Response.utf8("," ++ label ++ "-after"))
  Response.Res{code, Request.Header{"x-order", out} <> C.without(hs, "x-order"), out, rep}

def handler_text(trace: String, user: String) -> String:
  match trace:
    case "": "handler:" ++ user
    case _: trace ++ "handler"

def handler_vars(c: B.Context(Vars), vars: Vars) -> IO(B.Res):
  Vars{trace, user} = vars
  IO.pure(B.Res, C.text(Vars, C.header(Vars, c, "x-handler", "ran"), handler_text(trace, user)))

def handler(tag: Tag, c: B.Context(Vars), env: Unit) -> IO(B.Res):
  +ctx = c
  handler_vars(ctx, values(ctx))

def set_user_vars(c: B.Context(Vars), vars: Vars) -> B.Context(Vars):
  Vars{trace, old} = vars
  C.set(Vars, c, Vars{trace, "Ada"})

def set_user(+c: B.Context(Vars)) -> B.Context(Vars):
  set_user_vars(c, values(c))

def auth(c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res), allowed: Maybe<&2, String>) -> IO(B.Res):
  match allowed:
    case Some{"yes"}: next(c)
    case _: IO.pure(B.Res, C.text(Vars, C.status(Vars, c, 401), "denied"))

def transform(res: B.Res) -> B.Res:
  Response.Res{code, hs, body, rep} = res
  Response.Res{202, Request.Header{"x-transformed", Response.utf8("yes")} <> hs, List.append(&2, U32, body, Response.utf8("!")), rep}

def invalid(res: B.Res) -> B.Res:
  Response.Res{code, hs, body, rep} = res
  Response.Res{code, Request.Header{"bad name", []} <> hs, body, rep}

def middleware(tag: Tag, +c: B.Context(Vars), env: Unit, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case A{}:
      do IO<B.Res>:
        res : B.Res <- next(before(c, "a"))
        return after(res, "a")
    case BTag{}:
      do IO<B.Res>:
        res : B.Res <- next(before(c, "b"))
        return after(res, "b")
    case CTag{}:
      do IO<B.Res>:
        res : B.Res <- next(before(c, "c"))
        return after(res, "c")
    case Auth{}: auth(c, next, C.request_header(Vars, c, "x-auth"))
    case User{}: next(set_user(c))
    case Identity{}: next(c)
    case Transform{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return transform(res)
    case Invalid{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        return invalid(res)
    case Handler{}: next(c)

# Global middleware is observable on misses, too.
def global_middleware(tag: Tag, c: B.Context(Vars), env: Unit, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  middleware(tag, C.header(Vars, c, "x-middleware", "yes"), env, next)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid middleware routes")
    case Done{table}: B.serve_with(~Vars, ~Tag, ~Unit, ~handler, ~global_middleware, table, Unit{}, B.config())

def entries() -> List<&2, B.Registration(Tag)>:
  [
    B.use(Tag, Identity{}),
    B.use_path(Tag, "/order", A{}),
    B.use_path(Tag, "/order", Identity{}),
    B.get(Tag, "/order", Handler{}),
    B.use_path(Tag, "/order", BTag{}),
    B.use_path(Tag, "/order", CTag{}),
    B.use_path(Tag, "/private/*", Auth{}),
    B.use_path(Tag, "/private/*", User{}),
    B.get(Tag, "/private/hello", Handler{}),
    B.use_path(Tag, "/transform", Transform{}),
    B.get(Tag, "/transform", Handler{}),
    B.use_path(Tag, "/bad", Invalid{}),
    B.get(Tag, "/bad", Handler{}),
    B.use_path(Tag, "/users/:id{int}", User{}),
    B.get(Tag, "/users/:id", Handler{}),
    B.use_path(Tag, "/optional/:name?", User{}),
    B.get(Tag, "/optional/*", Handler{}),
    B.route(Tag, Methods.get(Tag, "/plain", Handler{}))
  ]

def main() -> IO(Unit):
  ready(B.routes(Tag, entries()))
