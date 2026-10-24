# Trusted socket boundary, outside the proofs: a TCP connect with an absolute
# deadline (BND-47). Base's TCP.connect has none. The host must be a numeric
# IPv4 address, as for TCP.connect. On timeout the effect closes its own
# descriptor and fails with ETIMEDOUT (110), so no socket outlives the call.
import Base

def upstream_connect(host: String, port: U32, ms: U32) -> IO(Result<&1, &1, U32 & String, Socket>):
  import "./upstream_connect.c"
  import "./upstream_connect.js"
