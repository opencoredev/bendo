# Lifecycle placements use the same app-owned ids and affine middleware values.
import Base
import ./context.bend as C
import ./middleware.bend as M
import ./table.bend as T
import ../http/response.bend as R

type State<-Vars: Data, -Env: Data> is Data:
  State{env: Env, slot: Chan(C.Ctx<Vars>)}

# Latest context forwarded to next, scoped to one sequential request. It is
# never shared between requests and never contains a function or continuation.
def sent(-A: Type, result: Result<&1, &1, A, Unit>) -> IO(Unit):
  match result:
    case Done{u}: IO.pure(Unit, Unit{})
    case Fail{e}: IO.die(Unit, 1, "lifecycle context slot closed")

def remember(-Vars: Data, +slot: Chan(C.Ctx<Vars>), ctx: C.Ctx<Vars>) -> IO(Unit):
  do IO<Unit>:
    old : Maybe<&1, C.Ctx<Vars>> <- Chan.recv(C.Ctx<Vars>, slot)
    result : Result<&1, &1, C.Ctx<Vars>, Unit> <- Chan.send(C.Ctx<Vars>, slot, ctx)
    # A timeout may have already returned the response and closed this slot.
    # IO.within does not cancel its loser: let late user work finish normally,
    # while discarding its context update instead of terminating the server.
    return Unit{}

def recalled(-Vars: Data, value: Maybe<&1, C.Ctx<Vars>>) -> IO(C.Ctx<Vars>):
  match value:
    case Some{ctx}: IO.pure(C.Ctx<Vars>, ctx)
    case None{}: IO.die(C.Ctx<Vars>, 1, "lifecycle context slot empty")

def recall(-Vars: Data, +slot: Chan(C.Ctx<Vars>)) -> IO(C.Ctx<Vars>):
  do IO<C.Ctx<Vars>>:
    value : Maybe<&1, C.Ctx<Vars>> <- Chan.recv(C.Ctx<Vars>, slot)
    Chan.close(C.Ctx<Vars>, slot)
    recalled(Vars, value)

def forward(-Vars: Data, slot: Chan(C.Ctx<Vars>), +ctx: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(R.Res)) -> IO(R.Res):
  do IO<R.Res>:
    remember(Vars, slot, ctx)
    next(ctx)

def tracked(~Vars: Data, ~Tag: Data, ~Env: Data, ~middleware: Tag -> C.Ctx<Vars> -> Env -> (C.Ctx<Vars> -> IO(R.Res)) -> IO(R.Res), tag: Tag, ctx: C.Ctx<Vars>, state: State<Vars, Env>, next: C.Ctx<Vars> -> IO(R.Res)) -> IO(R.Res):
  State{env, slot} = state
  middleware(tag, ctx, env, changed => forward(Vars, slot, changed, next))

def chain(~Vars: Data, ~Tag: Data, ~Env: Data, ~middleware: Tag -> C.Ctx<Vars> -> Env -> (C.Ctx<Vars> -> IO(R.Res)) -> IO(R.Res), ids: List<&2, Tag>, env: Env, slot: Chan(C.Ctx<Vars>)) -> M.Value(C.Ctx<Vars>, IO(R.Res)):
  M.chain(~C.Ctx<Vars>, ~IO(R.Res), ~Tag, ~State<Vars, Env>, ~(tag => ctx => state => next => tracked(~Vars, ~Tag, ~Env, ~middleware, tag, ctx, state, next)), ids, State{env, slot})

# Each post hook is a one-layer onion around the previous result. Sequential
# one-layer applications preserve registration order for all effects, not just
# response edits. next supplies the response being transformed.
def post(~Vars: Data, ~Tag: Data, ~Env: Data, ~middleware: Tag -> C.Ctx<Vars> -> Env -> (C.Ctx<Vars> -> IO(R.Res)) -> IO(R.Res), ids: List<&2, Tag>, +ctx: C.Ctx<Vars>, +env: Env, res: R.Res) -> IO(R.Res):
  match ids:
    case Nil{}: IO.pure(R.Res, res)
    case id <> tail:
      do IO<R.Res>:
        changed : R.Res <- M.chain(~C.Ctx<Vars>, ~IO(R.Res), ~Tag, ~Env, ~middleware, [id], env, ctx, ignored => IO.pure(R.Res, res))
        post(~Vars, ~Tag, ~Env, ~middleware, tail, ctx, env, changed)

# Every observer sees the same final response; its returned Res is discarded.
def observe(~Vars: Data, ~Tag: Data, ~Env: Data, ~middleware: Tag -> C.Ctx<Vars> -> Env -> (C.Ctx<Vars> -> IO(R.Res)) -> IO(R.Res), ids: List<&2, Tag>, +ctx: C.Ctx<Vars>, +env: Env, +res: R.Res) -> IO(Unit):
  match ids:
    case Nil{}: IO.pure(Unit, Unit{})
    case id <> tail:
      do IO<Unit>:
        ignored : R.Res <- M.chain(~C.Ctx<Vars>, ~IO(R.Res), ~Tag, ~Env, ~middleware, [id], env, ctx, ignored => IO.pure(R.Res, res))
        observe(~Vars, ~Tag, ~Env, ~middleware, tail, ctx, env, res)
