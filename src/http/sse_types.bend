# Server-Sent Events producer steps and configuration.
import Base
import ./sse.bend as Sse
import ./stream_types.bend as Stream

# heartbeat_ms: write a comment after this long without output; 0 disables.
# idle_ms: how long Bendo waits after an Idle step before pulling again.
# comment: heartbeat comment text, sent as ":" text LF. It must not contain
# CR or LF; an unsafe comment aborts the stream when the first heartbeat is due.
type Config is Data:
  Config{stream: Stream.Config, heartbeat_ms: U32, idle_ms: U32, comment: List<&2, U32>}

# Send writes one frame. Idle means nothing is ready yet: Bendo may write a
# heartbeat, waits idle_ms, then pulls again with the returned state.
type Step<-State: Type> is Type:
  Send{frame: Sse.Frame, state: State}
  Idle{state: State}
  End{state: State}
  Failed{state: State}

# The B.stream producer state wrapping an SSE producer.
type Pump<-State: Type> is Type:
  Pump{inner: State, config: Config, last_write_ms: Nat}
