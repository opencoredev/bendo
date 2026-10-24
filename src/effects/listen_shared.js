// Trusted host effect. Base's tcp_listen twin with SO_REUSEPORT set before
// bind. The socket helpers exist only in executable JS builds; elsewhere
// (an .mjs library) the effect fails with ENOSYS (38).
function bendo_listen_shared(host, port) {
  if (typeof io_sys !== "function" || typeof io_addr !== "function") {
    return {
      $: CID(Fail),
      error: { $: CID(Tuple), fst: 38, snd: "listen_shared needs an executable build" },
    };
  }
  const at = io_addr(host, Number(port));
  if (at === null) {
    return io_fail(22);
  }
  const sys = io_sys();
  const fd = sys.socket(2, 1, 0);
  if (fd < 0) {
    return io_fail(sys.errno());
  }
  const one = new Int32Array([1]);
  const level = sys.mac ? 0xffff : 1;
  sys.setsockopt(fd, level, sys.mac ? 4 : 2, sys.ptr(one), 4);
  // SO_REUSEPORT is 0x200 on macOS and 15 on Linux.
  if (
    sys.setsockopt(fd, level, sys.mac ? 0x200 : 15, sys.ptr(one), 4) < 0 ||
    sys.bind(fd, sys.ptr(at), 16) < 0 ||
    sys.listen(fd, 512) < 0 ||
    sys.fcntl(fd, 4, sys.fcntl(fd, 3, 0) | (sys.mac ? 4 : 0x800)) < 0
  ) {
    const code = sys.errno();
    sys.close(fd);
    return io_fail(code);
  }
  return io_done(fd);
}

io_eff(CID(listen_shared), bendo_listen_shared);
