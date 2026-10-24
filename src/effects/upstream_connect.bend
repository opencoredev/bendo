# Trusted socket boundary, outside the proofs: resolve a host and connect to
# it with an absolute deadline (BND-47, BND-93). Base's TCP.connect has neither
# a resolver nor a timeout. The host is a numeric IPv4 address, IPv6 text
# without brackets, or a DNS name. On timeout the effect closes its own
# descriptors and fails with ETIMEDOUT (110), so no socket outlives the call;
# a name that does not resolve fails with 1001. See upstream_connect.c.
import Base

def upstream_connect(host: String, port: U32, ms: U32) -> IO(Result<&1, &1, U32 & String, Socket>):
  import "./upstream_connect.c"
  import "./upstream_connect.js"
