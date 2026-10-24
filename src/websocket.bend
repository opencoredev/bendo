# B.websocket: answer a WebSocket opening handshake and register the session
# that takes over the socket after the 101. Frames are not decoded here.
import Base
import ./stream.bend as Stream
import ./http/stream_types.bend as T
import ./http/websocket.bend as Handshake
import ./http/response.bend as Response
import ./app/context.bend as Context
import ./app/transport_response.bend as Transport
import ./app/observability.bend as Observation

# Open runs the session with the socket and the octets read past the
# handshake; Abort releases its state without running it.
def handoff(~State: Type, ~session: State -> Socket -> List<&2, U32> -> IO(Unit), ~cleanup: State -> IO(Unit), state: State, command: T.Handoff) -> IO(Unit):
  match command:
    case T.Open{s, rest}: session(state, s, rest)
    case T.Abort{}: cleanup(state)

def protocol_header(-Vars: Data, c: Context.Ctx<Vars>, protocol: Maybe<&2, String>) -> Context.Ctx<Vars>:
  match protocol:
    case None{}: c
    case Some{p}: Context.header(Vars, c, "sec-websocket-protocol", p)

def switching(-Vars: Data, c: Context.Ctx<Vars>, accept: String, protocol: Maybe<&2, String>) -> Response.Res:
  Context.body(Vars, Transport.opening_context(Vars, c, Handshake.response(Handshake.Accept{accept, protocol})), [], None{})

def answer(~Vars: Data, ~State: Type, ~session: State -> Socket -> List<&2, U32> -> IO(Unit), ~cleanup: State -> IO(Unit), +c: Context.Ctx<Vars>, state: State, +config: Handshake.Config, decision: Handshake.Decision) -> IO(Response.Res):
  match decision:
    case Handshake.Refuse{status}:
      do IO<Response.Res>:
        cleanup(state)
        return Transport.refusal(Vars, c, status)
    case Handshake.Accept{accept, protocol}:
      Stream.register_claim(Observation.stream(Context.observation(Vars, c)), switching(Vars, c, accept, protocol), Stream.Handshake{config, T.Session{Handshake.timeout(config), command => handoff(~State, ~session, ~cleanup, state, command)}})

def respond(~Vars: Data, ~State: Type, ~session: State -> Socket -> List<&2, U32> -> IO(Unit), ~cleanup: State -> IO(Unit), +c: Context.Ctx<Vars>, state: State, +config: Handshake.Config) -> IO(Response.Res):
  answer(~Vars, ~State, ~session, ~cleanup, c, state, config, Handshake.decide(config, Context.request(Vars, c)))
