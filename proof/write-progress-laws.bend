# BND-106: the buffered-response write deadline (src/http/write_progress.bend)
# sends another window exactly when the last one shrank the unsent suffix.
import Base
import ../src/http/write_progress.bend as Progress
import ../src/app/config.bend as Config

# A window that ended with fewer octets unsent than it started with continues.
law write_progress_continues:
  for +left: Nat
  for +k: Nat
  {Progress.progressed(Progress.Left{Nat.add(left, 1n+k)}, left) == True{} : Bool}

# A window in which the client accepted no octet closes the connection. The
# unsent count never grows, but the law covers that case too.
law write_stall_closes:
  for +before: Nat
  for +k: Nat
  {Progress.progressed(Progress.Left{before}, Nat.add(before, k)) == False{} : Bool}

# The immediate first send is never judged: nothing was measured before it.
law write_opening_continues:
  for +left: Nat
  {Progress.progressed(Progress.Opening{}, left) == True{} : Bool}

# The documented default window is 30,000 ms, the same as the body deadline.
law write_timeout_default:
  {Config.write_timeout(Config.defaults()) == 30000 : U32}

# The shell's tail-loop count of the unsent suffix is its length.
law write_unsent_length:
  for +xs: List<&2, U32>
  {Progress.unsent(xs, 0n) == List.length(&2, U32, xs) : Nat}
