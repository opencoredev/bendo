# Request-local framework metadata; separate from application variables.
import Base
import ./store.bend as Store
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes

type Mark is Data:
  Mark{name: String, duration_ms: Nat}

type State is Data:
  State{id: Maybe<&2, String>, timing: Maybe<&2, Store.Store<List<&2, Mark>>>, finalized: Maybe<&2, Chan(Maybe<&2, String>)>}

def empty() -> State:
  State{None{}, None{}, None{}}

def id(state: State) -> Maybe<&2, String>:
  State{id, timing, finalized} = state
  id

def timing(state: State) -> Maybe<&2, Store.Store<List<&2, Mark>>>:
  State{id, timing, finalized} = state
  timing

def with_id(state: State, id: String) -> State:
  State{old, timing, finalized} = state
  State{Some{id}, timing, finalized}

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

def timed(res: Response.Res, got: Poll<&1, &1, Maybe<&1, Maybe<&2, String>>, Unit>) -> Response.Res:
  match got:
    case Ready{Some{value}}: header(res, "server-timing", value)
    case _: res

# The timing owner publishes once after next returns. Consume and close its
# request-local mailbox after hooks and validation, before observers or transport.
def finalize(state: State, res: Response.Res) -> IO(Response.Res):
  State{id, timing, finalized} = state
  match finalized:
    case None{}: IO.pure(Response.Res, header(res, "x-request-id", id))
    case Some{+channel}:
      do IO<Response.Res>:
        got : Poll<&1, &1, Maybe<&1, Maybe<&2, String>>, Unit> <- Chan.try_recv(Maybe<&2, String>, channel, 0)
        Chan.close(Maybe<&2, String>, channel)
        return timed(header(res, "x-request-id", id), got)
