# Trusted socket boundary, outside the proofs: getpeername(2) on an accepted
# socket. Answers the peer's numeric host text and port, and hands the socket
# back open on every path. Callers canonicalize the text with net/ip.bend.
import Base

def peer_address(sock: Socket) -> IO(Socket & Result<&1, &1, U32 & String, String & U32>):
  import "./peer.c"
  import "./peer.js"
