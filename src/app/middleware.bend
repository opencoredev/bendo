# Pure onion algebra. R may be an ordinary result or IO(Res).
import Base

# Function values are affine: a middleware can consume next at most once.
def Value(-C: Data, -R: Type) -> Type:
  C -> (C -> R) -> R

def identity(-C: Data, -R: Type, ctx: C, next: C -> R) -> R:
  next(ctx)

def compose(-C: Data, -R: Type, outer: Value(C, R), inner: Value(C, R)) -> Value(C, R):
  ctx => next => outer(ctx, changed => inner(changed, next))

# Build request-local function values; only identifiers live in reusable data.
def chain(~C: Data, ~R: Type, ~Id: Data, ~Env: Data, ~dispatch: Id -> C -> Env -> (C -> R) -> R, ids: List<&2, Id>, +env: Env) -> Value(C, R):
  match ids:
    case Nil{}: identity(C, R)
    case id <> tail:
      compose(C, R, ctx => next => dispatch(id, ctx, env, next), chain(~C, ~R, ~Id, ~Env, ~dispatch, tail, env))
