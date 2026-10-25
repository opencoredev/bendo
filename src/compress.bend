# Response compression middleware (BND-46); docs/compression.md. Opt in by
# importing this module beside src/main.bend and calling Z.compress from a
# middleware case: apps that never import it compile without zlib. The
# decision is pure (src/mw/compress_policy.bend, laws in LAWS.bend); this
# shell only runs the zlib effect on a body the policy chose to encode. A
# failed or unhelpful compression sends the identity body instead.
import Base
import ./app/context.bend as C
import ./http/response.bend as Response
import ./mw/compress_policy.bend as P
import ./effects/zlib.bend as Zlib

def Config() -> Data: P.Config

# Threshold 1024 octets, limit 8 MiB, level 6.
def defaults() -> P.Config: P.defaults()

# Bodies shorter than n octets are sent uncompressed.
def threshold(config: P.Config, n: U32) -> P.Config: P.with_threshold(config, n)

# Bodies longer than n octets are sent uncompressed, which bounds the memory
# one compression takes.
def limit(config: P.Config, n: U32) -> P.Config: P.with_limit(config, n)

# The zlib level, clamped to 1 (fastest) through 9 (smallest).
def level(config: P.Config, n: U32) -> P.Config: P.with_level(config, n)

def body(res: Response.Res) -> List<&2, U32>:
  Response.Res{s, hs, b, rep} = res
  b

def outcome(r: Result<&1, &1, U32 & String, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match r:
    case Fail{e}: None{}
    case Done{z}: Some{z}

def compressed(+config: P.Config, +res: Response.Res, +c: P.Coding) -> IO(Response.Res):
  do IO<Response.Res>:
    r : Result<&1, &1, U32 & String, List<&2, U32>> <- Zlib.zlib_compress(P.format(c), P.level(config), P.limit(config), body(res))
    return P.coded(res, c, outcome(r))

# Each case is P.respond(res, plan, out); only Encode and Measure run zlib.
def run(+config: P.Config, +res: Response.Res, plan: P.Plan) -> IO(Response.Res):
  match plan:
    case P.Keep{}: IO.pure(Response.Res, res)
    case P.Vary{}: IO.pure(Response.Res, P.varied(res))
    case P.Revalidated{c}: IO.pure(Response.Res, P.revalidated_res(res))
    case P.Encode{+c}: compressed(config, res, c)
    case P.Measure{+c}: compressed(config, res, c)

def received(-Vars: Data, +config: P.Config, +c: C.Ctx<Vars>, +res: Response.Res) -> IO(Response.Res):
  run(config, res, P.decide(config, C.method(Vars, c), P.accept(C.header_bytes(Vars, c, "accept-encoding")), res))

# Compresses the response next produces with gzip or deflate, as the
# request's Accept-Encoding allows. Call it from a middleware case.
def compress(-Vars: Data, +config: P.Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  do IO<Response.Res>:
    res : Response.Res <- next(c)
    received(Vars, config, c, res)
