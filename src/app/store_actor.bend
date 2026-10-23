# The store's state owner. Its unbounded loop is @unsafe, so it lives apart
# from the pure Store types that request context and laws import.
import Base
import ./store.bend as Store

@unsafe
def actor(-S: Data, +requests: Chan(Store.Message<S>), +state: S, event: Store.ActorEvent<S>) -> IO(Unit):
  match event:
    case Store.Receive{}:
      do IO<Unit>:
        got : Maybe<&1, Store.Message<S>> <- Chan.recv(Store.Message<S>, requests)
        actor(S, requests, state, Store.Received{got})
    case Store.Received{None{}}:
      IO.pure(Unit, Unit{})
    case Store.Received{Some{Store.Get{channel}}}:
      do IO<Unit>:
        Store.reply(S, channel, state)
        actor(S, requests, state, Store.Receive{})
    case Store.Received{Some{Store.Set{value, channel}}}:
      do IO<Unit>:
        Store.reply(Unit, channel, Unit{})
        actor(S, requests, value, Store.Receive{})
    case Store.Received{Some{Store.Update{change, channel}}}:
      actor(S, requests, Store.transition(S, state, change), Store.Publish{channel})
    case Store.Publish{channel}:
      do IO<Unit>:
        Store.reply(S, channel, state)
        actor(S, requests, state, Store.Receive{})

def store_with_timeout(-S: Data, initial: S, timeout_ms: U32) -> IO(Store.Store<S>):
  do IO<Store.Store<S>>:
    +requests : Chan(Store.Message<S>) <- Chan.new(Store.Message<S>, 128)
    IO.spawn(Unit, actor(S, requests, initial, Store.Receive{}))
    return Store.Store{requests, timeout_ms}

def store(-S: Data, initial: S) -> IO(Store.Store<S>):
  store_with_timeout(S, initial, 5000)
