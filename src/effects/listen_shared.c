// Trusted host effect. Base's tcp_listen with SO_REUSEPORT set before bind, so
// several processes can listen on one address. Same host rules as TCP.listen
// (numeric IPv4), same backlog, and the listener is non-blocking.
#include <sys/socket.h>

static Term bendo_listen_shared_run(Env e, Term* f, IoWork* w) {
  struct sockaddr_in at;
  u64 len;
  char* host = io_cstr(e, f[0], &len);
  int valid = !io_nul(host, len) && io_sys_addr(host, (u32)f[1], &at) == 0;
  free(host);
  if (!valid) {
    return io_fail(e, EINVAL, NULL);
  }
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return io_fail(e, (u32)errno, NULL);
  }
  int one = 1;
  setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
  if (setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &one, sizeof(one)) < 0
    || bind(fd, (struct sockaddr*)&at, sizeof(at)) < 0 || listen(fd, 512) < 0
    || fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) < 0) {
    u32 code = (u32)errno;
    close(fd);
    return io_fail(e, code, NULL);
  }
  return io_done(e, io_hand(fd));
}

static void __attribute__((constructor)) bendo_listen_shared_use(void) {
  io_eff(CID(listen_shared), bendo_listen_shared_run);
}
