# One actor owns S. Update functions are affine messages consumed exactly once.
import Base

type Error is Data:
  Unavailable{}
  TimedOut{}

type Message<-S: Data> is Type:
  Get{reply: Chan(S)}
  Set{value: S, reply: Chan(Unit)}
  Update{change: S -> S, reply: Chan(S)}

type Store<-S: Data> is Data:
  Store{requests: Chan(Message<S>), timeout_ms: U32}

type ActorEvent<-S: Data> is Type:
  Receive{}
  Received{message: Maybe<&1, Message<S>>}
  Publish{channel: Chan(S)}

# Reply channels have room for one value. A caller may already have timed out;
# dropping a failed reply must never terminate or block the state owner.
def reply(-A: Data, chan: Chan(A), value: A) -> IO(Unit):
  do IO<Unit>:
    sent : Poll<&1, &1, Result<&1, &1, A, Unit>, A> <- Chan.try_send(A, chan, value, 0)
    return Unit{}

def transition(-S: Data, state: S, change: S -> S) -> S:
  change(state)

def received(-A: Data, got: Poll<&1, &1, Maybe<&1, A>, Unit>) -> Result<&2, &2, Error, A>:
  match got:
    case Ready{Some{value}}: Done{value}
    case Ready{None{}}: Fail{Unavailable{}}
    case Wait{u}: Fail{TimedOut{}}

def sent(-S: Data, -A: Data, +channel: Chan(A), deadline: Nat, result: Poll<&1, &1, Result<&1, &1, Message<S>, Unit>, Message<S>>) -> IO(Result<&2, &2, Error, A>):
  match result:
    case Ready{Done{u}}:
      do IO<Result<&2, &2, Error, A>>:
        now : Nat <- IO.now()
        got : Poll<&1, &1, Maybe<&1, A>, Unit> <- Chan.try_recv(A, channel, U32.from_nat(Nat.sub(deadline, now)))
        Chan.close(A, channel)
        return received(A, got)
    case Ready{Fail{message}}:
      do IO<Result<&2, &2, Error, A>>:
        Chan.close(A, channel)
        return Fail{Unavailable{}}
    case Wait{message}:
      do IO<Result<&2, &2, Error, A>>:
        Chan.close(A, channel)
        return Fail{TimedOut{}}

def ask(-S: Data, -A: Data, handle: Store<S>, make: Chan(A) -> Message<S>) -> IO(Result<&2, &2, Error, A>):
  Store{requests, +ms} = handle
  do IO<Result<&2, &2, Error, A>>:
    +channel : Chan(A) <- Chan.new(A, 1)
    now : Nat <- IO.now()
    result : Poll<&1, &1, Result<&1, &1, Message<S>, Unit>, Message<S>> <- Chan.try_send(Message<S>, requests, make(channel), ms)
    sent(S, A, channel, Nat.add(now, U32.to_nat(ms)), result)

def get(-S: Data, handle: Store<S>) -> IO(Result<&2, &2, Error, S>):
  ask(S, S, handle, channel => Get{channel})

def set(-S: Data, handle: Store<S>, value: S) -> IO(Result<&2, &2, Error, Unit>):
  ask(S, Unit, handle, channel => Set{value, channel})

def update(-S: Data, handle: Store<S>, change: S -> S) -> IO(Result<&2, &2, Error, S>):
  ask(S, S, handle, channel => Update{change, channel})
