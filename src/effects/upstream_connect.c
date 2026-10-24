// Trusted host effect. A non-blocking connect(2) parked until the socket is
// writable or the deadline passes. Every failure path closes the descriptor;
// success hands it over as a Socket. Timeouts report 110 on every platform
// (Linux ETIMEDOUT); Bendo classifies only that code as a timeout.
#include <poll.h>

static Term bendo_upstream_connect_more(Env e, IoWork* w) {
  int fd = (int)w->made;
  struct pollfd p = { fd, POLLOUT, 0 };
  int ready = poll(&p, 1, 0);
  int err = 0;
  socklen_t len = sizeof(err);
  if (ready == 0 && io_tick() < w->time) {
    return io_wait_on(w, fd, POLLOUT, w->time, bendo_upstream_connect_more);
  }
  if (ready == 0) {
    err = 110;
  } else if (ready < 0) {
    err = errno;
  } else if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &len) != 0) {
    err = errno;
  }
  free(w->data);
  if (err != 0) {
    close(fd);
    return io_fail(e, (u32)err, NULL);
  }
  return io_done(e, io_hand(fd));
}

static Term bendo_upstream_connect_run(Env e, Term* f, IoWork* w) {
  struct sockaddr_in at;
  w->data = io_cstr(e, f[0], &w->size);
  w->time = io_until(f[2]);
  int fd = -1;
  errno = EINVAL;
  if (!io_nul(w->data, w->size) && io_sys_addr(w->data, (u32)f[1], &at) == 0) {
    fd = socket(AF_INET, SOCK_STREAM, 0);
  }
  if (fd >= 0 && fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) < 0) {
    close(fd);
    fd = -1;
  }
  if (fd < 0) {
    u32 code = (u32)errno;
    free(w->data);
    return io_fail(e, code, NULL);
  }
  w->made = fd;
  if (connect(fd, (struct sockaddr*)&at, sizeof(at)) == 0) {
    free(w->data);
    return io_done(e, io_hand(fd));
  }
  if (errno != EINPROGRESS) {
    u32 code = (u32)errno;
    close(fd);
    free(w->data);
    return io_fail(e, code, NULL);
  }
  return io_wait_on(w, fd, POLLOUT, w->time, bendo_upstream_connect_more);
}

static void __attribute__((constructor)) bendo_upstream_connect_use(void) {
  io_eff(CID(upstream_connect), bendo_upstream_connect_run);
}
