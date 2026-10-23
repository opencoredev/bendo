// Trusted host effect. getpeername(2) on a borrowed socket: the descriptor is
// handed back open on every path. Answers the numeric host (inet_ntop) and port.
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>

static Term bendo_peer_address_run(Env e, Term* f, IoWork* w) {
  intptr_t fd = (intptr_t)io_hand_v(f[0]);
  struct sockaddr_storage at;
  socklen_t len = sizeof(at);
  memset(&at, 0, sizeof(at));
  if (getpeername((int)fd, (struct sockaddr*)&at, &len) != 0) {
    return io_tup(e, io_hand(fd), io_fail(e, (uint32_t)errno, NULL));
  }
  char host[INET6_ADDRSTRLEN];
  uint32_t port;
  if (at.ss_family == AF_INET) {
    struct sockaddr_in* v4 = (struct sockaddr_in*)&at;
    if (inet_ntop(AF_INET, &v4->sin_addr, host, sizeof(host)) == NULL) {
      return io_tup(e, io_hand(fd), io_fail(e, (uint32_t)errno, NULL));
    }
    port = ntohs(v4->sin_port);
  } else if (at.ss_family == AF_INET6) {
    struct sockaddr_in6* v6 = (struct sockaddr_in6*)&at;
    if (inet_ntop(AF_INET6, &v6->sin6_addr, host, sizeof(host)) == NULL) {
      return io_tup(e, io_hand(fd), io_fail(e, (uint32_t)errno, NULL));
    }
    port = ntohs(v6->sin6_port);
  } else {
    return io_tup(e, io_hand(fd), io_fail(e, EAFNOSUPPORT, NULL));
  }
  return io_tup(e, io_hand(fd), io_done(e, io_tup(e, io_str(e, host, strlen(host)), (Term)port)));
}

static void __attribute__((constructor)) bendo_peer_address_use(void) {
  io_eff(CID(peer_address), bendo_peer_address_run);
}
