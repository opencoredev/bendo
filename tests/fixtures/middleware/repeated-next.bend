# Negative fixture: both sequential calls consume the same affine continuation.
import Base
import ../../../src/main.bend as B

def invalid(+ctx: B.Ctx, next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  do IO<B.Res>:
    first : B.Res <- next(ctx)
    next(ctx)
