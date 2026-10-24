import Base
import ../../src/http/request.bend as Request
import ../../src/main.bend as B
import ../../src/http/stream_types.bend as S
import ../../src/http/response.bend as Response
import ../../src/app/table.bend as Table
import ../../src/app/context.bend as C
import ../../src/router/methods.bend as Methods

type Tag is Data:
  RecoverStream{}
  PolicyError{}
  Hello{}
  Stream{}
  Empty{}
  Broken{}
  Suppress{}
  Invalid{}
  Oversize{}
  Duplicate{}
  Delayed{}
  Late{}
  Timeout{}
  Replace{}
  Map{}
  Observe{}
  SizedStream{}
  Builtin{id: B.Builtin}

type State is Data:
  State{left: Nat, broken: Bool, empty: Bool, chunk: List<&2, U32>}

def cleanup(state: State) -> IO(Unit):
  IO.print("cleanup")

def step(state: State) -> IO(S.Step<State>):
  match state:
    case State{0n, broken, empty, chunk}: IO.pure(S.Step<State>, S.End{State{0n, broken, empty, chunk}})
    case State{1n+n, True{}, empty, chunk}: IO.pure(S.Step<State>, S.Failed{State{n, True{}, empty, chunk}})
    case State{1n+n, False{}, True{}, chunk}: IO.pure(S.Step<State>, S.Chunk{[], State{1n+n, False{}, False{}, chunk}})
    case State{1n+n, False{}, False{}, +chunk}:
      do IO<S.Step<State>>:
        IO.print("pull")
        return S.Chunk{chunk, State{n, False{}, False{}, chunk}}

def broken_step(state: State) -> IO(S.Step<State>):
  match state:
    case State{0n, broken, empty, chunk}: IO.pure(S.Step<State>, S.Failed{state})
    case State{1n+n, broken, empty, +chunk}: IO.pure(S.Step<State>, S.Chunk{chunk, State{n, broken, empty, chunk}})

def delayed_step(state: State) -> IO(S.Step<State>):
  do IO<S.Step<State>>:
    IO.sleep(100)
    step(state)

def count(value: Maybe<&2, String>) -> Nat:
  match value:
    case None{}: 3n
    case Some{s}: U32.to_nat(Maybe.default(&2, U32, U32.read(s), 3))

def copies(n: Nat, +byte: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n: acc
    case 1n+p: copies(p, byte, byte <> acc)

def handler(tag: Tag, c: B.Context(Unit), env: Unit) -> IO(B.Res):
  match tag:
    case PolicyError{}: IO.pure(B.Res, B.text(B.status(c, 500), "recover me"))
    case Hello{}: IO.pure(B.Res, B.text(c, "hello"))
    case Broken{}: B.stream(~Unit, ~State, ~broken_step, ~cleanup, c, State{1n, False{}, False{}, [0, 128, 255]}, S.Config{500, 65536})
    case Suppress{}:
      +ctx = c
      B.stream(~Unit, ~State, ~step, ~cleanup, B.status(ctx, U32.from_nat(count(B.query(ctx, "code")))), State{1n, False{}, False{}, [120]}, S.Config{500, 65536})
    case Invalid{}: B.stream(~Unit, ~State, ~step, ~cleanup, c, State{1n, False{}, False{}, [256]}, S.Config{500, 65536})
    case Oversize{}: B.stream(~Unit, ~State, ~step, ~cleanup, c, State{1n, False{}, False{}, copies(4097n, 120, [])}, S.Config{500, 4096})
    case Duplicate{}:
      +ctx = c
      do IO<B.Res>:
        first : B.Res <- B.stream(~Unit, ~State, ~step, ~cleanup, ctx, State{1n, False{}, False{}, [120]}, S.Config{500, 65536})
        B.stream(~Unit, ~State, ~step, ~cleanup, ctx, State{1n, False{}, False{}, [120]}, S.Config{500, 65536})
    case Late{}:
      do IO<B.Res>:
        IO.sleep(100)
        B.stream(~Unit, ~State, ~step, ~cleanup, c, State{1n, False{}, False{}, [120]}, S.Config{500, 65536})
    case Delayed{}: B.stream(~Unit, ~State, ~delayed_step, ~cleanup, c, State{4n, False{}, False{}, [120]}, S.Config{500, 65536})
    case Empty{}: B.stream(~Unit, ~State, ~step, ~cleanup, c, State{2n, False{}, True{}, [97, 98]}, S.Config{500, 65536})
    # BND-91: an empty chunk, then `chunks` chunks of "ab", declared as `length` octets.
    case SizedStream{}:
      +ctx = c
      B.stream_sized(~Unit, ~State, ~step, ~cleanup, ctx, State{count(B.query(ctx, "chunks")), False{}, True{}, [97, 98]}, S.Config{500, 65536}, count(B.query(ctx, "length")))
    case _:
      +ctx = c
      B.stream(~Unit, ~State, ~step, ~cleanup, ctx, State{count(B.query(ctx, "chunks")), False{}, False{}, copies(4096n, 120, [])}, S.Config{500, 65536})

def mapped(c: B.Context(Unit), res: B.Res) -> B.Res:
  match res:
    case Response.Res{status, hs, body, rep}:
      Response.Res{status, hs, body, rep}

def timed(result: Maybe<&1, B.Res>) -> B.Res:
  match result:
    case None{}: Response.body(504, [], [])
    case Some{res}: res

def middleware(tag: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case RecoverStream{}: B.stream(~Unit, ~State, ~step, ~cleanup, B.header(B.header(B.status(c, 200), "vary", "Accept-Encoding"), "x-powered-by", "replacement"), State{2n, False{}, False{}, [97, 98]}, B.stream_config())
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case Timeout{}:
      do IO<B.Res>:
        result : Maybe<&1, B.Res> <- IO.within(B.Res, 10, next(c))
        return timed(result)
    case Map{}:
      +ctx = c
      do IO<B.Res>:
        res : B.Res <- next(ctx)
        return B.text(ctx, "replacement")
    case Observe{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        IO.print("after")
        return res
    case _: next(c)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "routes")
    case Done{table}: B.serve_with(~Unit, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.on_request(Tag, Builtin{B.request_id()}),
    B.on_request(Tag, Builtin{B.server_timing()}),
    B.on_after_response(Tag, Observe{}),
    B.use_path(Tag, "/policy/*", Builtin{B.cors(B.cors_allow([B.cors_origin_credentials("https://app.example")]))}),
    B.use_path(Tag, "/policy/*", Builtin{B.secure_headers()}),
    B.use_path(Tag, "/replace", Map{}),
    B.use_path(Tag, "/late", Timeout{}),
    B.get(Tag, "/", Hello{}),
    B.get(Tag, "/stream", Stream{}),
    B.get(Tag, "/policy/stream", Stream{}),
    B.route_hooks(Tag, Methods.get(Tag, "/policy/recovered", PolicyError{}), [B.hook(Tag, Table.Error{}, RecoverStream{})]),
    B.get(Tag, "/empty", Empty{}),
    B.get(Tag, "/sized", SizedStream{}),
    B.get(Tag, "/broken", Broken{}),
    B.get(Tag, "/status", Suppress{}),
    B.on(Tag, [Request.Connect{}], "/status", Suppress{}),
    B.get(Tag, "/invalid", Invalid{}),
    B.get(Tag, "/oversize", Oversize{}),
    B.get(Tag, "/duplicate", Duplicate{}),
    B.get(Tag, "/delayed", Delayed{}),
    B.get(Tag, "/late", Late{}),
    B.get(Tag, "/replace", Replace{})
  ]))
