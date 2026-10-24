# Request-local framework metadata; separate from application variables.
import Base
import ../net/conn_info.bend as Conn
import ../http/stream_types.bend as StreamTypes
import ../mw/response_policy.bend as Policy
import ./store.bend as Store
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes
import ../http/request_id.bend as RequestId
import ../data/utf8.bend as Utf8
import ./validate.bend as V

type Mark is Data:
  Mark{name: String, duration_ms: Nat}

type Access is Data:
  Access{index: Nat, prefix: String, started: Nat, elapsed: Maybe<&2, Nat>, fallback: Maybe<&2, String>}

type State is Data:
  State{id: Maybe<&2, String>, timing: Maybe<&2, Store.Store<List<&2, Mark>>>, finalized: Maybe<&2, Chan(Maybe<&2, String>)>, policies: Maybe<&2, Chan(List<&2, Policy.Policy>)>, stream: Maybe<&2, Chan(StreamTypes.Registration)>, peer: Maybe<&2, Conn.ConnInfo>, access: Maybe<&2, Chan(List<&2, Access>)>, valid: Maybe<&2, V.Values>}

def empty() -> State:
  State{None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}}

def id(state: State) -> Maybe<&2, String>:
  State{id, timing, finalized, policies, stream, peer, access, valid} = state
  id

def timing(state: State) -> Maybe<&2, Store.Store<List<&2, Mark>>>:
  State{id, timing, finalized, policies, stream, peer, access, valid} = state
  timing

def with_id(state: State, id: String) -> State:
  State{old, timing, finalized, policies, stream, peer, access, valid} = state
  State{Some{id}, timing, finalized, policies, stream, peer, access, valid}

# Final response fields win, including mixed-case names. Only fill missing fields.
def has_header(hs: List<&2, Request.Header>, +name: String) -> Bool:
  match hs:
    case Nil{}: False{}
    case Request.Header{k, v} <> tail: String.eq(Bytes.fold(k), name) || has_header(tail, name)

def missing(exists: Bool, res: Response.Res, name: String, value: String) -> Response.Res:
  match exists:
    case True{}: res
    case False{}:
      Response.Res{code, hs, body, rep} = res
      Response.Res{code, Request.Header{name, Response.utf8(value)} <> hs, body, rep}

def present(+res: Response.Res, +name: String, value: String) -> Response.Res:
  Response.Res{code, hs, body, rep} = res
  missing(has_header(hs, name), res, name, value)

def header(+res: Response.Res, +name: String, value: Maybe<&2, String>) -> Response.Res:
  match value:
    case None{}: res
    case Some{text}:
      present(res, name, text)

# Select the first valid explicit ID and remove all other copies. Invalid IDs
# fall back to retained metadata, including None when no middleware assigned one.
def valid_id(value: String, fallback: Maybe<&2, String>, valid: Bool) -> Maybe<&2, String>:
  match valid:
    case True{}: Some{value}
    case False{}: fallback

def decoded_id(value: Maybe<&2, String>, fallback: Maybe<&2, String>) -> Maybe<&2, String>:
  match value:
    case None{}: fallback
    case Some{+text}: valid_id(text, fallback, RequestId.valid_go(text, 200n, False{}))

def explicit_field(value: List<&2, U32>, fallback: Maybe<&2, String>, same: Bool) -> Maybe<&2, String>:
  match same:
    case True{}: decoded_id(Utf8.decode(value), fallback)
    case False{}: fallback

def explicit_id(hs: List<&2, Request.Header>, fallback: Maybe<&2, String>) -> Maybe<&2, String>:
  match hs:
    case Nil{}: fallback
    case Request.Header{k, v} <> tail:
      explicit_field(v, explicit_id(tail, fallback), String.eq(Bytes.fold(k), "x-request-id"))

def keep_field(h: Request.Header, tail: List<&2, Request.Header>, same: Bool) -> List<&2, Request.Header>:
  match same:
    case True{}: tail
    case False{}: h <> tail

def without_ids(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+k, v} <> tail:
      keep_field(Request.Header{k, v}, without_ids(tail), String.eq(Bytes.fold(k), "x-request-id"))

def request_id(res: Response.Res, fallback: Maybe<&2, String>) -> Response.Res:
  Response.Res{code, +hs, body, rep} = res
  header(Response.Res{code, without_ids(hs), body, rep}, "x-request-id", explicit_id(hs, fallback))

# The fields finalization adds after response validation: request ID, then
# Server-Timing. Neither touches the body, the status or other fields
# (law finalizers_only_stamp).
def stamped(res: Response.Res, id: Maybe<&2, String>, timing: Maybe<&2, String>) -> Response.Res:
  header(request_id(res, id), "server-timing", timing)

def polled(got: Poll<&1, &1, Maybe<&1, Maybe<&2, String>>, Unit>) -> Maybe<&2, String>:
  match got:
    case Ready{Some{value}}: value
    case _: None{}

# The timing owner publishes once after next returns. Consume and close its
# request-local mailbox after hooks and validation, before observers or transport.
def finalized_timing(state: State, res: Response.Res) -> IO(Response.Res):
  State{id, timing, finalized, policies, stream, peer, access, valid} = state
  match finalized:
    case None{}: IO.pure(Response.Res, stamped(res, id, None{}))
    case Some{+channel}:
      do IO<Response.Res>:
        got : Poll<&1, &1, Maybe<&1, Maybe<&2, String>>, Unit> <- Chan.try_recv(Maybe<&2, String>, channel, 0)
        Chan.close(Maybe<&2, String>, channel)
        return stamped(res, id, polled(got))

# One request owns this mailbox. Immutable context copies share its policies,
# so short-circuits and response hooks need not forward a new context.
def with_policies(state: State, channel: Chan(List<&2, Policy.Policy>)) -> State:
  State{id, timing, finalized, old, stream, peer, access, valid} = state
  State{id, timing, finalized, Some{channel}, stream, peer, access, valid}

def recorded(+channel: Chan(List<&2, Policy.Policy>), policy: Policy.Policy, got: Maybe<&1, List<&2, Policy.Policy>>) -> IO(Unit):
  match got:
    case None{}: IO.pure(Unit, Unit{})
    case Some{policies}:
      do IO<Unit>:
        sent : Result<&1, &1, List<&2, Policy.Policy>, Unit> <- Chan.send(List<&2, Policy.Policy>, channel, List.append(&2, Policy.Policy, policies, [policy]))
        return Unit{}

def retain(state: State, policy: Policy.Policy) -> IO(Unit):
  State{id, timing, finalized, policies, stream, peer, access, valid} = state
  match policies:
    case None{}: IO.pure(Unit, Unit{})
    case Some{+channel}:
      do IO<Unit>:
        got : Maybe<&1, List<&2, Policy.Policy>> <- Chan.recv(List<&2, Policy.Policy>, channel)
        recorded(channel, policy, got)

def taken(got: Maybe<&1, List<&2, Policy.Policy>>) -> List<&2, Policy.Policy>:
  match got:
    case None{}: []
    case Some{policies}: policies

# Take the retained policies once and close their mailbox. Finalization
# applies them before response validation, and again to a replacement.
def take_policies(state: State) -> IO(List<&2, Policy.Policy>):
  State{id, timing, finalized, policies, stream, peer, access, valid} = state
  match policies:
    case None{}: IO.pure(List<&2, Policy.Policy>, [])
    case Some{+channel}:
      do IO<List<&2, Policy.Policy>>:
        got : Maybe<&1, List<&2, Policy.Policy>> <- Chan.recv(List<&2, Policy.Policy>, channel)
        Chan.close(List<&2, Policy.Policy>, channel)
        return taken(got)

# Transport metadata survives policy and timing updates.
def stream(state: State) -> Maybe<&2, Chan(StreamTypes.Registration)>:
  State{id, timing, finalized, policies, stream, peer, access, valid} = state
  stream

def with_stream(state: State, stream: Chan(StreamTypes.Registration)) -> State:
  State{id, timing, finalized, policies, old, peer, access, valid} = state
  State{id, timing, finalized, policies, Some{stream}, peer, access, valid}

# The logger records its onion duration, but prints only after transport has
# selected the status the client receives.
def with_access(state: State, channel: Chan(List<&2, Access>)) -> State:
  State{id, timing, finalized, policies, stream, peer, old, valid} = state
  State{id, timing, finalized, policies, stream, peer, Some{channel}, valid}

def access(state: State) -> Maybe<&2, Chan(List<&2, Access>)>:
  State{id, timing, finalized, policies, stream, peer, channel, valid} = state
  channel

# Observers run after transport selection and can log their response directly.
def without_access(state: State) -> State:
  State{id, timing, finalized, policies, stream, peer, access, valid} = state
  State{id, timing, finalized, policies, stream, peer, None{}, valid}

# The peer is immutable connection metadata and survives all request updates.
def peer(state: State) -> Maybe<&2, Conn.ConnInfo>:
  State{id, timing, finalized, policies, stream, peer, access, valid} = state
  peer

def with_peer(state: State, peer: Maybe<&2, Conn.ConnInfo>) -> State:
  State{id, timing, finalized, policies, stream, old, access, valid} = state
  State{id, timing, finalized, policies, stream, peer, access, valid}

# Values the route's schemas decoded (BND-36); None before validation runs.
def valid(state: State) -> Maybe<&2, V.Values>:
  State{id, timing, finalized, policies, stream, peer, access, valid} = state
  valid

def with_valid(state: State, values: V.Values) -> State:
  State{id, timing, finalized, policies, stream, peer, access, old} = state
  State{id, timing, finalized, policies, stream, peer, access, Some{values}}
