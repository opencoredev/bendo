# Buffered-response write deadline (BND-106, decision 0009). The shell first
# sends what the socket accepts at once, then sends the rest with
# TCP.try_send_bytes one write_timeout_ms window at a time. Each send that
# ends with octets unsent leaves their count here, and the next window runs
# only if that count shrank. A client that accepts no byte for a whole window
# is dropped; a slow but steady one gets the whole body.
import Base

# Opening is the immediate first send: nothing was measured before it, so it
# always continues. Counting the response up front instead would cost every
# response a pass over its bytes.
type Unsent is Data:
  Opening{}
  Left{octets: Nat}

def progressed(window: Unsent, left: Nat) -> Bool:
  match window:
    case Opening{}: True{}
    case Left{before}: Nat.is_lt(left, before)

# The unsent suffix's length plus acc. A tail loop, so the JavaScript build
# counts a multi-megabyte suffix without growing the stack.
def unsent(xs: List<&2, U32>, acc: Nat) -> Nat:
  match xs:
    case Nil{}: acc
    case c <> t: unsent(t, 1n+acc)
