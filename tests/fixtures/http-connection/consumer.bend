import Base
import ../../../src/http/connection.bend as C
import ../../../src/app/config.bend as Config

def initial() -> C.State:
  C.initial(0n, Config.defaults())

def state(pair: C.State & Bool) -> C.State:
  (s, interim) = pair
  s

def feed(xs: List<&2, U32>, s: C.State, now: Nat) -> C.State:
  state(C.feed(xs, s, now, Config.defaults()))

def next(s: C.State, rest: List<&2, U32>, now: Nat) -> C.State:
  state(C.next(s, rest, now, Config.defaults()))

def action(s: C.State, now: Nat) -> C.Action:
  C.action(s, now)
