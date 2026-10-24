# Trusted socket boundary, outside the proofs: TCP.listen with SO_REUSEPORT
# (BND-69). Every worker process binds its own listener to the same address
# and the kernel spreads new connections across them. Only used when a server
# runs more than one worker; a single worker keeps TCP.listen, so a second
# copy on a taken port still fails with EADDRINUSE.
import Base

def listen_shared(host: String, port: U32) -> IO(Result<&1, &1, U32 & String, Listener>):
  import "./listen_shared.c"
  import "./listen_shared.js"
