# Request-local framework metadata; separate from application variables.
import Base
import ./store.bend as Store

type Mark is Data:
  Mark{name: String, duration_ms: Nat}

type State is Data:
  State{id: Maybe<&2, String>, timing: Maybe<&2, Store.Store<List<&2, Mark>>>}

def empty() -> State:
  State{None{}, None{}}

def id(state: State) -> Maybe<&2, String>:
  State{id, timing} = state
  id

def timing(state: State) -> Maybe<&2, Store.Store<List<&2, Mark>>>:
  State{id, timing} = state
  timing
