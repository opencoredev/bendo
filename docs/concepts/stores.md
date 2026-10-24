---
title: Stores
description: Shared mutable state in Bendo, held by an actor and reached through the env argument.
---

# Stores

Bend has no global mutable variables, and a Bendo context lives for one
request. A counter, a cache or an in-memory list of todos needs a place that
outlives requests. That place is a **store**: a spawned actor that owns one
value and answers get, set and update messages in order.

## Create it at startup, pass it in `env`

Create the store in `main`, before serving, and put its handle in your app's
`env`. Every handler call receives `env`, and every connection gets a copy of
the handle, all pointing at the same actor.

```python
type Env is Data:
  Env{counter: B.Store(U32)}

def increment(count: U32) -> U32:
  (count + 1 : U32)
```

At startup, `B.store(U32, 0)` returns `IO(B.Store(U32))`. A handler then calls
`B.store_update(U32, counter, increment)` to add one and get the new count.

## Update, don't get then set

An update sends a pure `S -> S` function to the actor, which applies it to the
current state before it reads the next message. That makes it atomic. A get
followed by a set is two messages, and another request can slip between them,
so never build an increment that way.

| Call | Does |
| --- | --- |
| `B.store_get(S, handle)` | Returns a snapshot of the state. |
| `B.store_set(S, handle, value)` | Replaces the state. |
| `B.store_update(S, handle, change)` | Applies `change` atomically and returns the new state. |

Each call returns a `Result`. `Unavailable` means the actor's mailbox is
closed, and `TimedOut` means it did not answer within the handle's budget, 5
seconds by default. Answer both with a 503. A timed-out update may still have
been applied, so do not retry a non-idempotent update blindly.

## Limits

- State lives in memory until the process exits. Nothing is written to disk.
- A store belongs to one process. With [workers](../workers.md), each worker
  has its own copy of every store. Keep state that must be global in an
  external service, or serve with one worker.
- Stores are independent. There is no transaction across two stores.
- Keep update functions small and free of IO. The actor runs them one at a
  time, and nothing can interrupt a long pure computation.

## Read on

- [Shared state](../store.md) is the full reference, with timeouts and the
  complete handler code.
- The [store example](../examples.md#store) serves a counter and a todo list.
- [Rate limiting](../connection.md) is built on a store.
