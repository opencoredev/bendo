# Captures the actual routed identity; later context rewrites cannot change it.
import Base
import ../router/methods.bend as M
import ../router/spec.bend as S

def identity(-Tag: Data, count: Nat, resolution: M.Resolution<Tag>) -> Maybe<&2, Nat>:
  match resolution:
    case M.Found{S.Match{index, tag, params}, head}: Some{Nat.sub(Nat.sub(count, 1n), index)}
    case _: None{}

def remember(+slot: Chan(Maybe<&2, Nat>), route: Maybe<&2, Nat>) -> IO(Unit):
  do IO<Unit>:
    old : Maybe<&1, Maybe<&2, Nat>> <- Chan.recv(Maybe<&2, Nat>, slot)
    sent : Result<&1, &1, Maybe<&2, Nat>, Unit> <- Chan.send(Maybe<&2, Nat>, slot, route)
    return Unit{}

def recalled(value: Maybe<&1, Maybe<&2, Nat>>) -> Maybe<&2, Nat>:
  match value:
    case Some{route}: route
    case None{}: None{}

def recall(+slot: Chan(Maybe<&2, Nat>)) -> IO(Maybe<&2, Nat>):
  do IO<Maybe<&2, Nat>>:
    value : Maybe<&1, Maybe<&2, Nat>> <- Chan.recv(Maybe<&2, Nat>, slot)
    Chan.close(Maybe<&2, Nat>, slot)
    return recalled(value)
