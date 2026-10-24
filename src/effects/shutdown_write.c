// Trusted host effect. shutdown(2) SHUT_WR on a borrowed socket: queues a FIN
// after the unsent bytes and hands the descriptor back open. Errors (ENOTCONN
// after a peer reset, for example) are ignored; Socket.close still follows.
#include <sys/socket.h>

static Term bendo_shutdown_write_run(Env e, Term* f, IoWork* w) {
  intptr_t fd = (intptr_t)io_hand_v(f[0]);
  shutdown((int)fd, SHUT_WR);
  return io_hand(fd);
}

static void __attribute__((constructor)) bendo_shutdown_write_use(void) {
  io_eff(CID(shutdown_write), bendo_shutdown_write_run);
}
