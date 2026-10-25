# Stores and the clock

Shared state lives in a store: one spawned actor owns a value of type `S` and
answers get, set and update messages in order. [Shared state](../../store.md)
explains the model; this page lists the calls.

Examples on this page are one Bend program and share this setup:

```bend
import Base
import ./bendo/main.bend as B
import ./bendo/app/store.bend as Store
import ./bendo/effects/clock.bend as Clock

def increment(count: U32) -> U32:
  (count + 1 : U32)
```

## Types

### `B.Store`

```bend signature
def Store(-S: Data) -> Data
```

The handle to a store holding an `S`. It is copyable `Data`, so keep it in
your app's `env` and every connection gets a copy pointing at the same actor.
It is the same type as `Store.Store<S>`.

```bend
type Env is Data:
  Env{visits: B.Store(U32)}
```

### `Store.Store`

```bend signature
type Store<-S: Data> is Data:
  Store{requests: Chan(Message<S>), timeout_ms: U32}
```

The type behind `B.Store(S)`, for code that imports `app/store.bend` directly.
Its fields are internal; create one with `B.store`.

```bend
def ex_same_type(handle: B.Store(U32)) -> Store.Store<U32>:
  handle
```

### `B.StoreError`, `Store.Error`

```bend signature
def StoreError() -> Data

type Error is Data:
  Unavailable{}
  TimedOut{}
```

Why a store operation failed. `Unavailable{}` means the actor's mailbox or the
reply channel is closed. `TimedOut{}` means sending the request or waiting for
the reply took longer than the store's timeout. Match the constructors through
`Store`, since `main.bend` names only the type.

```bend
def ex_store_failure(e: B.StoreError) -> String:
  match e:
    case Store.Unavailable{}: "store unavailable"
    case Store.TimedOut{}: "store timed out"

def ex_same_error(e: Store.Error) -> B.StoreError:
  e
```

## Create a store

### `B.store`

```bend signature
def store(-S: Data, initial: S) -> IO(B.Store(S))
```

Spawns the actor with `initial` as its state and returns its handle. Each
operation waits at most 5,000 milliseconds. Call it once at startup, in
`main`, and pass the handle to `B.serve` inside `env`. With
[workers](../../workers.md), each worker process creates its own store.

```bend
def ex_startup() -> IO(Env):
  do IO<Env>:
    visits : B.Store(U32) <- B.store(U32, 0)
    return Env{visits}
```

### `B.store_with_timeout`

```bend signature
def store_with_timeout(-S: Data, initial: S, timeout_ms: U32) -> IO(B.Store(S))
```

`B.store` with a different operation budget in milliseconds. One budget covers
each whole operation: sending to the actor's mailbox (128 queued requests) and
then waiting for the reply, which gets only the time the send left.

```bend
def ex_patient() -> IO(B.Store(U32)):
  B.store_with_timeout(U32, 0, 250)
```

## Read and change state

### `B.store_get`, `Store.get`

```bend signature
def store_get(-S: Data, handle: B.Store(S)) -> IO(Result<&2, &2, B.StoreError, S>)
```

Reads the current state. `Store.get` is the same function.

```bend
def ex_show(+c: B.Ctx, result: Result<&2, &2, B.StoreError, U32>) -> B.Res:
  match result:
    case Done{n}: B.text(c, U32.show(n))
    case Fail{e}: B.text(B.status(c, 503), "unavailable")

def ex_read(c: B.Ctx, visits: B.Store(U32)) -> IO(B.Res):
  do IO<B.Res>:
    got : Result<&2, &2, B.StoreError, U32> <- B.store_get(U32, visits)
    return ex_show(c, got)

def ex_read_direct(visits: B.Store(U32)) -> IO(Result<&2, &2, Store.Error, U32>):
  Store.get(U32, visits)
```

### `B.store_set`

```bend signature
def store_set(-S: Data, handle: B.Store(S), value: S) -> IO(Result<&2, &2, B.StoreError, Unit>)
```

Replaces the state with `value`. To change the state based on its current
value, use `B.store_update`: a get followed by a set lets other requests run in
between.

```bend
def ex_reset(visits: B.Store(U32)) -> IO(Result<&2, &2, B.StoreError, Unit>):
  B.store_set(U32, visits, 0)
```

### `B.store_update`, `Store.update`

```bend signature
def store_update(-S: Data, handle: B.Store(S), change: S -> S) -> IO(Result<&2, &2, B.StoreError, S>)
```

Sends `change` to the actor, which applies it to the current state before it
handles the next message, and returns the new state. `change` can be a
top-level def or a closure over runtime values. `Store.update` is the same
function.

```bend
def ex_count(c: B.Ctx, visits: B.Store(U32)) -> IO(B.Res):
  do IO<B.Res>:
    got : Result<&2, &2, B.StoreError, U32> <- B.store_update(U32, visits, increment)
    return ex_show(c, got)

def ex_add(visits: B.Store(U32), +n: U32) -> IO(Result<&2, &2, Store.Error, U32>):
  Store.update(U32, visits, count => (count + n : U32))
```

## Wall clock

### `Clock.wall_millis`, `Clock.wall_seconds`

```bend signature
def wall_millis() -> IO(Result<&1, &1, U32 & String, Nat>)
def wall_seconds() -> IO(Result<&1, &1, U32 & String, Nat>)
```

Milliseconds since the Unix epoch, read from `CLOCK_REALTIME` natively and
`Date.now()` in JavaScript. It fails with an error code and message when the
clock is unavailable, before the epoch, or past the year 9999. Use it for
timestamps people read; for durations and timeouts use `IO.now`, which is
monotonic. `Clock.wall_seconds` is the same reading in whole seconds, rounded
down, as JWT `iat` and `exp` claims use.

```bend
def ex_stamp(r: Result<&1, &1, U32 & String, Nat>) -> String:
  match r:
    case Done{ms}: Nat.show(ms)
    case Fail{e}: "clock unavailable"

def ex_now() -> IO(String):
  do IO<String>:
    got : Result<&1, &1, U32 & String, Nat> <- Clock.wall_millis()
    return ex_stamp(got)

def ex_now_seconds() -> IO(String):
  do IO<String>:
    got : Result<&1, &1, U32 & String, Nat> <- Clock.wall_seconds()
    return ex_stamp(got)
```
