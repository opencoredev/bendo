// Trusted host effect, the JS twin of upstream_connect.c. It needs the
// executable JS runtime's socket helpers; an .mjs library has none and fails
// with ENOSYS. Every failure path closes the descriptor. A timeout is always
// reported as 110 (Linux ETIMEDOUT), as in the C effect on Linux.
function bendo_upstream_connect_failure(code) {
  return { $: CID(Fail), error: { $: CID(Tuple), fst: code >>> 0, snd: "connect failed" } };
}

function bendo_upstream_connect(host, port, ms, k) {
  if (typeof io_sys !== "function" || typeof io_park_on !== "function") {
    return bendo_upstream_connect_failure(38);
  }
  const at = io_addr(host, Number(port));
  if (at === null) {
    return bendo_upstream_connect_failure(22);
  }
  const deadline = io_until(ms);
  const sys = io_sys();
  const fd = sys.socket(2, 1, 0);
  if (fd < 0) {
    return bendo_upstream_connect_failure(sys.errno());
  }
  const end = (code) => {
    if (code !== 0) {
      sys.close(fd);
      return bendo_upstream_connect_failure(code);
    }
    return { $: CID(Done), value: fd };
  };
  const error = () => {
    const v = new Int32Array([0]);
    const l = new Uint32Array([4]);
    return sys.getsockopt(fd, sys.mac ? 0xffff : 1, sys.mac ? 0x1007 : 4, sys.ptr(v), sys.ptr(l)) <
      0
      ? sys.errno()
      : v[0];
  };
  const set = sys.fcntl(fd, 4, sys.fcntl(fd, 3, 0) | (sys.mac ? 4 : 0x800));
  const ok = set >= 0 && sys.connect(fd, sys.ptr(at), 16) >= 0;
  const code = ok ? 0 : sys.errno();
  if (code !== (sys.mac ? 36 : 115)) {
    return end(code);
  }
  // Writable means the connect finished; past the deadline it timed out.
  const check = () => {
    const err = error();
    if (err === 0 && io_late(deadline)) {
      return end(110);
    }
    return end(err);
  };
  io_park_on(fd, true, k, check, deadline);
  return undefined;
}

io_eff(CID(upstream_connect), bendo_upstream_connect);
