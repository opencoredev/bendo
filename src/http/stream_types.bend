# Affine producer ownership, shared without importing the transport IO shell.
import Base

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

type Registration is Type:
  Registration{id: String, plan: Plan}
