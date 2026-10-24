# Request-local framework metadata; separate from application variables.
import Base
import ../http/stream_types.bend as StreamTypes
import ../mw/response_policy.bend as Policy
import ./store.bend as Store
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes
import ../http/request_id.bend as RequestId
import ../data/utf8.bend as Utf8
import ../net/conn_info.bend as Conn

type Mark is Data:
  Mark{name: String, duration_ms: Nat}

type State is Data:
  State{id: Maybe<&2, String>, timing: Maybe<&2, Store.Store<List<&2, Mark>>>, finalized: Maybe<&2, Chan(Maybe<&2, String>)>, policies: Maybe<&2, Chan(List<&2, Policy.Policy>)>, stream: Maybe<&2, Chan(StreamTypes.Registration)>, peer: Maybe<&2, Conn.ConnInfo>}

def empty() -> State:
  State{None{}, None{}, None{}, None{}, None{}, None{}}

def id(state: State) -> Maybe<&2, String>:
  State{id, timing, finalized, policies, stream, p} = state
  id

def timing(state: State) -> Maybe<&2, Store.Store<List<&2, Mark>>>:
  State{id, timing, finalized, policies, stream, p} = state
  timing

def with_id(state: State, id: String) -> State:
  State{old, timing, finalized, policies, stream, p} = state
  State{Some{id}, timing, finalized, policies, stream, p}

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

def timed(res: Response.Res, got: Poll<&1, &1, Maybe<&1, Maybe<&2, String>>, Unit>) -> Response.Res:
  match got:
    case Ready{Some{value}}: header(res, "server-timing", value)
    case _: res

# The timing owner publishes once after next returns. Consume and close its
# request-local mailbox after hooks and validation, before observers or transport.
def finalized_timing(state: State, res: Response.Res) -> IO(Response.Res):
  State{id, timing, finalized, policies, stream, p} = state
  match finalized:
    case None{}: IO.pure(Response.Res, request_id(res, id))
    case Some{+channel}:
      do IO<Response.Res>:
        got : Poll<&1, &1, Maybe<&1, Maybe<&2, String>>, Unit> <- Chan.try_recv(Maybe<&2, String>, channel, 0)
        Chan.close(Maybe<&2, String>, channel)
        return timed(request_id(res, id), got)

# One request owns this mailbox. Immutable context copies share its policies,
# so short-circuits and response hooks need not forward a new context.
def with_policies(state: State, channel: Chan(List<&2, Policy.Policy>)) -> State:
  State{id, timing, finalized, old, stream, p} = state
  State{id, timing, finalized, Some{channel}, stream, p}

def recorded(+channel: Chan(List<&2, Policy.Policy>), policy: Policy.Policy, got: Maybe<&1, List<&2, Policy.Policy>>) -> IO(Unit):
  match got:
    case None{}: IO.pure(Unit, Unit{})
    case Some{policies}:
      do IO<Unit>:
        sent : Result<&1, &1, List<&2, Policy.Policy>, Unit> <- Chan.send(List<&2, Policy.Policy>, channel, List.append(&2, Policy.Policy, policies, [policy]))
        return Unit{}

def retain(state: State, policy: Policy.Policy) -> IO(Unit):
  State{id, timing, finalized, policies, stream, p} = state
  match policies:
    case None{}: IO.pure(Unit, Unit{})
    case Some{+channel}:
      do IO<Unit>:
        got : Maybe<&1, List<&2, Policy.Policy>> <- Chan.recv(List<&2, Policy.Policy>, channel)
        recorded(channel, policy, got)

def applied(got: Maybe<&1, List<&2, Policy.Policy>>, res: Response.Res) -> Response.Res:
  match got:
    case None{}: res
    case Some{policies}: Policy.finalized(policies, res)

def finalized_policies(policies: Maybe<&2, Chan(List<&2, Policy.Policy>)>, res: Response.Res) -> IO(Response.Res):
  match policies:
    case None{}: IO.pure(Response.Res, res)
    case Some{+channel}:
      do IO<Response.Res>:
        got : Maybe<&1, List<&2, Policy.Policy>> <- Chan.recv(List<&2, Policy.Policy>, channel)
        Chan.close(List<&2, Policy.Policy>, channel)
        return applied(got, res)

def finalize(+state: State, res: Response.Res) -> IO(Response.Res):
  State{id, timing, finalized, policies, stream, p} = state
  do IO<Response.Res>:
    decorated : Response.Res <- finalized_policies(policies, res)
    finalized_timing(state, decorated)

# Transport metadata survives policy and timing updates.
def stream(state: State) -> Maybe<&2, Chan(StreamTypes.Registration)>:
  State{id, timing, finalized, policies, stream, p} = state
  stream

def with_stream(state: State, stream: Chan(StreamTypes.Registration)) -> State:
  State{id, timing, finalized, policies, old, p} = state
  State{id, timing, finalized, policies, Some{stream}, p}

# The socket peer, set once per connection by the server. None for
# network-free handling and when getpeername fails.
def peer(state: State) -> Maybe<&2, Conn.ConnInfo>:
  State{id, timing, finalized, policies, stream, peer} = state
  peer

def with_peer(state: State, peer: Maybe<&2, Conn.ConnInfo>) -> State:
  State{id, timing, finalized, policies, stream, old} = state
  State{id, timing, finalized, policies, stream, peer}
