# Shared state

Create a store at startup and put its handle in your app's `env`. One spawned
actor owns the state and processes get, set, and update messages in order. Every
handler and keep-alive connection receives a copy of the handle pointing to that
same actor. State lasts until the server process exits; it is not persisted to disk.

A store lives in one process. A server with more than one worker
([workers](workers.md)) runs one copy of `main` per worker, so each worker
creates and holds its own store, and a request sees only the state of the
worker that serves it. Keep state that must be global (counters, sessions,
caches that must agree) in an external service, or serve with one worker.

## Atomic updates

An update sends a pure `S -> S` function to the actor, which consumes it once
against the current state and replies with the new state. Pass a top-level def
or a closure that captures runtime values:

```python
import Base
import ../../src/main.bend as B

def increment(count: U32) -> U32:
  (count + 1 : U32)
```

At startup, create this counter with `B.store(U32, 0)`. The result is
`IO(B.Store(U32))`. In a handler, call `B.store_update(U32, counter, increment)`.
Bend functions are affine, so the update message is `Type` rather than `Data`.
`Chan` accepts affine elements while its handle remains copyable `Data`; the
function moves to the actor without being copied. No closed template or command
interpreter is needed. The native HTTP example also sends a closure capturing a
todo title, so this is checked across spawned computations.

Do not implement increments as a get followed by a set. Those are separate
messages and other requests can interleave. One update reads and replaces the
state before the actor processes the next message. The module's pure `transition`
def applies the function independently of the IO shell, so laws can refer to it
later.

## Reach stores from handlers

The [complete runnable example](../examples/store/main.bend) serves a counter
and a todo map represented as a list of records keyed by ID. Its environment has
two independent store types:

```python
type Env is Data:
  Env{counter: B.Store(U32), todos: B.Store(List<&2, Todo>)}
```

The example's dispatcher receives `tag`, `c: B.Ctx`, and `env: Env`, as usual.
It matches the tag and environment together with `match tag env`, then uses
the startup handle directly:

```python
    case AddCounter{} Env{counter, todos}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, U32> <- B.store_update(U32, counter, increment)
        return number(c, r)
```

`number` turns `Done{n}` into `B.text(c, U32.show(n))` and store failures into
503 responses. The example imports `src/app/store.bend as Store` for error
constructors. [Request context](context.md) variables remain immutable and local
to each request; shared resources stay in `env` beside the context.

Build and run from the repository root:

```sh
bend examples/store/main.bend -o /tmp/bendo-store
PORT=8787 /tmp/bendo-store
```

GET `/counter` initially returns `0`. POST `/counter` returns `1`, then `2`.
POST `/todos?title=buy+milk` returns `1`; GET `/todos` returns `1:buy milk`.
Posting another title replaces todo ID 1 without touching the counter. The
example is a local server; it uses the normal Bendo configuration.

## API

The public entrypoint exports these operations. `S` must be `Data`; pass it as
an explicit erased argument.

```text
B.Store(S) -> Data
B.StoreError -> Data
B.store(S, initial: S) -> IO(B.Store(S))
B.store_with_timeout(S, initial: S, timeout_ms: U32) -> IO(B.Store(S))
B.store_get(S, handle) -> IO(Result<&2, &2, B.StoreError, S>)
B.store_set(S, handle, value: S) -> IO(Result<&2, &2, B.StoreError, Unit>)
B.store_update(S, handle, change: S -> S) -> IO(Result<&2, &2, B.StoreError, S>)
```

Get returns a snapshot. Set replaces the whole state and acknowledges after its
message reaches the actor. Update applies the function atomically and returns
the new state. A successful set or update precedes later reads sent after its
acknowledgment. Multiple stores are independent; there is no transaction across
stores.

The direct module `src/app/store.bend` exports `Store<S>`, `Error`, `get`, `set`,
and `update`. `src/app/store_actor.bend` exports `store` and
`store_with_timeout`; it holds the `@unsafe` actor loop apart from the pure
types, so laws can import the request context. Public operation names have a
`store_` prefix because `B.get` already registers routes.

## Failure and timeout behavior

The default operation budget is 5,000 milliseconds. `store_with_timeout` chooses
a different budget for that handle. A single monotonic deadline covers sending
to the mailbox and receiving the reply, including mailbox backpressure. A zero
budget polls without waiting. The mailbox holds at most 128 pending messages;
additional callers wait only for their remaining budget.

Every call creates a buffered reply channel and closes it on success, closed
mailbox, closed reply channel, or timeout. Channel-native timed operations remove
parked waits when their deadline expires, without spawning a losing waiter with
`IO.within`. A late or undeliverable reply is discarded; it cannot block or kill
the actor.

- `Fail{Store.Unavailable{}}` means the mailbox or reply channel is closed.
- `Fail{Store.TimedOut{}}` means the mailbox send or reply wait exceeded its budget.

Handle both failures with a 503 (or your app's 500 policy), as the example does.
There is no implicit exception or HTTP conversion in this IO-level API. If an
actor stops answering without closing its mailbox, calls time out. A handler's
failed response does not affect the independent actor.

A timed-out write may still commit if its message was accepted. Do not blindly
retry non-idempotent updates; use app-owned operation IDs if retries are needed.
Timeouts do not cancel accepted work. Bend's IO scheduler is cooperative, so a
pure update must terminate and yield promptly: no timer can preempt pure
code that blocks the event loop, and a fatal runtime/process error is outside
the store's recovery boundary. Keep update functions small and free of IO. Run
expensive work before submitting an update, with any required state check inside
the update function.

Verify with `bun test --timeout 30000 tests/store.test.ts`. The HTTP suite checks
1,000 increments across 50 unchanged connections, distinct store types,
get/set/update, connection and handler-error survival, unavailable mailboxes,
send/reply timeouts, and a late write followed by a successful read and update.
