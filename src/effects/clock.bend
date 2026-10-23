# Trusted wall-clock boundary, outside the proofs: CLOCK_REALTIME / Date.now().
# Nat is exact on both targets for 0..253402300799999 milliseconds (year 9999).
# Fail covers unavailable clocks, pre-epoch time and values beyond this range.
# IO.now remains the monotonic clock for durations and timeouts.
import Base

def wall_millis() -> IO(Result<&1, &1, U32 & String, Nat>):
  import "./clock.c"
  import "./clock.js"

def seconds(result: Result<&1, &1, U32 & String, Nat>) -> Result<&1, &1, U32 & String, Nat>:
  match result:
    case Fail{error}: Fail{error}
    case Done{ms}: Done{Nat.div(ms, 1000n)}

def wall_seconds() -> IO(Result<&1, &1, U32 & String, Nat>):
  do IO<Result<&1, &1, U32 & String, Nat>>:
    result : Result<&1, &1, U32 & String, Nat> <- wall_millis()
    return seconds(result)
