# Trusted socket boundary, outside the proofs: shutdown(2) with SHUT_WR on a
# socket the server is about to close (BND-90). The peer sees EOF after the
# bytes already sent, while the read side stays open for the bounded drain.
# Hands the socket back open on every path; a failure only means the later
# close sends the FIN instead.
import Base

def shutdown_write(sock: Socket) -> IO(Socket):
  import "./shutdown_write.c"
  import "./shutdown_write.js"
