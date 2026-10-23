import Base
import ../../src/http/stream_types.bend as StreamTypes
import ../../src/crypto/sha256.bend as Sha
import ../../src/data/hex.bend as Hex
import ../../src/main.bend as B
import ../../src/app/context.bend as C
import ../../src/app/table.bend as Table
import ../../src/app/store.bend as Store
import ../../src/http/request.bend as Request
import ../../src/http/response.bend as R
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Hello{}
  Stream{}
  Echo{}
  Slow{}
  Late{}
  Count{}
  Cpu{steps: U32}
  Work{}
  Rewrite{target: String}
  Builtin{id: B.Builtin}

type Env is Data:
  Env{counter: B.Store(U32), work: B.Store(Nat)}

def increment(n: U32) -> U32: U32.inc(n)

def count(c: B.Ctx, result: Result<&2, &2, Store.Error, U32>) -> B.Res:
  match result:
    case Done{n}: B.text(c, U32.show(n))
    case Fail{e}: R.text(503, "store unavailable")

def work(c: B.Ctx, result: Result<&2, &2, Store.Error, Nat>) -> B.Res:
  match result:
    case Done{n}: B.text(c, Nat.show(n))
    case Fail{e}: R.text(503, "store unavailable")

# Bounded real pure work, never synthetic external load. Runtime seed prevents
# compile-time evaluation; the checksum is forced into an effect before timing.
def burn(n: Nat, value: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n: value
    case 1n+p: burn(p, Sha.hash(value))

def stream_step(state: Nat) -> IO(StreamTypes.Step<Nat>):
  match state:
    case 0n: IO.pure(StreamTypes.Step<Nat>, StreamTypes.End{0n})
    case 1n+n: IO.pure(StreamTypes.Step<Nat>, StreamTypes.Chunk{R.utf8("hello stream\n"), n})

def stream_cleanup(state: Nat) -> IO(Unit):
  IO.pure(Unit, Unit{})

def handle(tag: Tag, +c: B.Ctx, env: Env) -> IO(B.Res):
  match tag env:
    case Stream{} _:
      B.stream(~Unit, ~Nat, ~stream_step, ~stream_cleanup, c, 3n, B.stream_config())
    case Slow{} Env{counter, work}:
      do IO<B.Res>:
        IO.sleep(100)
        return B.text(c, "too late")
    case Late{} Env{counter, work}:
      do IO<B.Res>:
        IO.sleep(100)
        value : Result<&2, &2, Store.Error, U32> <- B.store_update(U32, counter, increment)
        return count(c, value)
    case Count{} Env{counter, work}:
      do IO<B.Res>:
        value : Result<&2, &2, Store.Error, U32> <- B.store_get(U32, counter)
        return count(c, value)
    case Work{} Env{counter, work_store}:
      do IO<B.Res>:
        value : Result<&2, &2, Store.Error, Nat> <- B.store_get(Nat, work_store)
        return work(c, value)
    case Cpu{steps} Env{counter, work_store}:
      do IO<B.Res>:
        +begin : Nat <- IO.now()
        IO.print_err(Hex.encode(burn(U32.to_nat(steps), R.utf8(Nat.show(begin)))))
        end : Nat <- IO.now()
        saved : Result<&2, &2, Store.Error, Unit> <- B.store_set(Nat, work_store, Nat.sub(end, begin))
        IO.sleep(100)
        return B.text(c, "late cpu response")
    case Echo{} _:
      IO.pure(B.Res, B.body(c, B.raw_body(c), Some{"application/octet-stream"}))
    case _ _:
      IO.pure(B.Res, B.text(B.header(B.header(B.header(B.header(B.header(c, "vary", "Accept-Encoding"), "date", "Thu, 01 Jan 1970 00:00:00 GMT"), "content-location", "/representation"), "expires", "Thu, 01 Jan 1970 01:00:00 GMT"), "x-drop", "yes"), "hello é"))

def handler(tag: Tag, c: B.Ctx, env: Env) -> IO(B.Res):
  handle(tag, c, env)

def middleware(tag: Tag, c: B.Ctx, env: Env, next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case Rewrite{target}: next(B.rewrite(c, Request.Post{}, target))
    case _: next(c)

def limit(tag: Tag) -> Maybe<&2, U32>:
  match tag:
    case Builtin{id}: B.builtin_body_limit(id)
    case _: None{}

def limited(path: String, bytes: U32) -> B.Registration(Tag):
  B.route_hooks(Tag, Methods.post(Tag, path, Echo{}), [B.hook(Tag, Table.BeforeHandle{}, Builtin{B.body_limit(bytes)})])

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "invalid routes")
    case Done{table}:
      do IO<Unit>:
        counter : B.Store(U32) <- B.store(U32, 0)
        work : B.Store(Nat) <- B.store(Nat, 0n)
        B.serve_limits_with(~Unit, ~Tag, ~limit, ~Env, ~handler, ~middleware, table, Env{counter, work}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, List.append(&2, B.Registration(Tag), [
    B.use(Tag, Builtin{B.request_id()}),
    B.use(Tag, Builtin{B.server_timing()}),
    B.use_path(Tag, "/slow", Builtin{B.timeout(5)}),
    B.use_path(Tag, "/late", Builtin{B.timeout(5)}),
    B.use_path(Tag, "/cpu/*", Builtin{B.timeout(1)}),
    B.map_response(Tag, Builtin{B.etag()}),
    B.map_response(Tag, Builtin{B.cache_control(B.cache_public(60, True{}))}),
    B.get(Tag, "/", Hello{}),
    B.get(Tag, "/stream", Stream{}),
    B.get(Tag, "/slow", Slow{}),
    B.get(Tag, "/late", Late{}),
    B.get(Tag, "/count", Count{}),
    B.get(Tag, "/work", Work{}),
    B.get(Tag, "/cpu/small", Cpu{1000}),
    B.get(Tag, "/cpu/large", Cpu{20000}),
    limited("/small", 4),
    B.route_hooks(Tag, Methods.get(Tag, "/head-limit", Hello{}), [B.hook(Tag, Table.BeforeHandle{}, Builtin{B.body_limit(4)})]),
    limited("/large", 8),
    B.route_hooks(Tag, Methods.post(Tag, "/to-small", Echo{}), [B.hook(Tag, Table.Request{}, Rewrite{"/small"})]),
    B.route_hooks(Tag, Methods.post(Tag, "/to-large", Echo{}), [B.hook(Tag, Table.Request{}, Rewrite{"/large"}), B.hook(Tag, Table.BeforeHandle{}, Builtin{B.body_limit(4)})])
  ], B.guard(Tag, B.guard_options(Tag, [B.hook(Tag, Table.BeforeHandle{}, Builtin{B.body_limit(2)})]), [B.post(Tag, "/guard", Echo{})]))))
