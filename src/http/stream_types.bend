# Affine producer and session ownership, shared without importing the
# transport IO shell.
import Base
import ./websocket.bend as WebSocket

type Config is Data:
  Config{write_timeout_ms: U32, max_chunk_bytes: U32}

type Step<-State: Type> is Type:
  Chunk{bytes: List<&2, U32>, state: State}
  End{state: State}
  Failed{state: State}

type Command is Type:
  Start{socket: Socket}
  Cancel{}

type Outcome is Type:
  Written{socket: Socket, complete: Bool}
  Cancelled{}

type Plan is Type:
  Plan{timeout_ms: U32, action: Command -> IO(Outcome)}

# After a 101, Open hands the socket and every octet already read past the
# handshake to the session, which then owns and closes the socket. Abort
# releases the session's resources without running it.
type Handoff is Type:
  Open{socket: Socket, rest: List<&2, U32>}
  Abort{}

type Session is Type:
  Session{timeout_ms: U32, action: Handoff -> IO(Unit)}

# One registration per request, from B.stream or B.websocket. Upgrade keeps
# the handshake configuration so the transport can re-check the wire request.
type Registration is Type:
  Registration{id: String, plan: Plan}
  Upgrade{id: String, config: WebSocket.Config, session: Session}

# What the connection does with the final response.
type Transport is Type:
  Buffered{}
  Streamed{plan: Plan}
  Upgraded{session: Session}
