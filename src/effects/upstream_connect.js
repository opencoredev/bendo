// Trusted host effect, the JS twin of upstream_connect.c. It needs the
// executable JS runtime's socket helpers; an .mjs library has none and fails
// with ENOSYS. Every failure path closes its descriptors. A timeout is always
// reported as 110 (Linux ETIMEDOUT), as in the C effect on Linux, and a name
// that does not resolve as 1001.
//
// The runtime's IO loop blocks in select(2) through bun:ffi, so dns.lookup
// callbacks never run on this thread. Names are looked up by one shared
// worker thread instead, which writes each answer as a line of JSON to a pipe
// made for that lookup; the computation parks on the pipe's read end with the
// deadline. The worker owns the write end and closes it after answering, so a
// lookup abandoned at the deadline only leaves the worker a write that fails.
// Addresses are tried as in the C effect: in the resolver's order, alternating
// families, each attempt but the last getting an equal share of the time left.
const BENDO_ADDRS = 8;
const BENDO_NO_ADDRESS = 1001;

function bendo_upstream_connect_failure(code) {
  return { $: CID(Fail), error: { $: CID(Tuple), fst: code >>> 0, snd: "connect failed" } };
}

function bendo_upstream_pipe() {
  if (globalThis.BENDO_PIPE === undefined) {
    const ffi = require("bun:ffi");
    const lib = ffi.dlopen(process.platform === "darwin" ? "libSystem.dylib" : "libc.so.6", {
      pipe: { args: ["ptr"], returns: "i32" },
    });
    globalThis.BENDO_PIPE = (fds) => lib.symbols.pipe(ffi.ptr(fds));
  }
  return globalThis.BENDO_PIPE;
}

function bendo_upstream_resolver() {
  if (globalThis.BENDO_RESOLVER === undefined) {
    const { Worker } = require("worker_threads");
    const source = `
      const { parentPort } = require("worker_threads");
      const dns = require("dns");
      const fs = require("fs");
      parentPort.on("message", ({ host, fd }) => {
        dns.lookup(host, { all: true, verbatim: true }, (error, list) => {
          const answer = error
            ? { error: String(error.code) }
            : { list: list.slice(0, ${BENDO_ADDRS * 2}).map((a) => [a.family, a.address]) };
          try {
            fs.writeSync(fd, JSON.stringify(answer) + "\\n");
          } catch {}
          try {
            fs.closeSync(fd);
          } catch {}
        });
      });`;
    const worker = new Worker(source, { eval: true });
    worker.unref();
    globalThis.BENDO_RESOLVER = worker;
  }
  return globalThis.BENDO_RESOLVER;
}

// The 16 octets of IPv6 text, or null.
function bendo_upstream_v6(text) {
  if (!require("net").isIPv6(text)) {
    return null;
  }
  let head = text;
  const tail = [];
  const dotted = /^(.*:)(\d+\.\d+\.\d+\.\d+)$/.exec(text);
  if (dotted !== null) {
    head = dotted[1].endsWith("::") ? dotted[1] : dotted[1].slice(0, -1);
    const o = dotted[2].split(".").map(Number);
    tail.push((o[0] << 8) | o[1], (o[2] << 8) | o[3]);
  }
  const halves = head.split("::");
  const groups = (s) => (s === "" ? [] : s.split(":").map((g) => parseInt(g, 16)));
  const left = groups(halves[0]);
  const right = halves.length > 1 ? groups(halves[1]) : [];
  const fill = 8 - tail.length - left.length - right.length;
  const all = [
    ...left,
    ...(halves.length > 1 ? Array.from({ length: fill }, () => 0) : []),
    ...right,
    ...tail,
  ];
  const b = new Uint8Array(16);
  all.forEach((g, i) => b.set([g >> 8, g & 255], i * 2));
  return b;
}

function bendo_upstream_sockaddr(sys, family, address, port) {
  if (family === 4) {
    return io_addr(address, port);
  }
  const octets = bendo_upstream_v6(address);
  if (octets === null) {
    return null;
  }
  const b = new Uint8Array(28);
  b.set([...(sys.mac ? [28, 30] : [10, 0]), port >> 8, port & 255]);
  b.set(octets, 8);
  return b;
}

// Alternates families starting with the first address's family.
function bendo_upstream_order(list) {
  const first = list[0]?.[0];
  const same = list.filter((a) => a[0] === first);
  const other = list.filter((a) => a[0] !== first);
  const out = [];
  for (let i = 0; out.length < BENDO_ADDRS && i < Math.max(same.length, other.length); i += 1) {
    if (i < same.length) out.push(same[i]);
    if (i < other.length && out.length < BENDO_ADDRS) out.push(other[i]);
  }
  return out;
}

function bendo_upstream_writable(sys, fd) {
  const len = ((fd >> 6) << 3) + 8;
  const set = new Uint8Array(len);
  set[fd >> 3] |= 1 << (fd & 7);
  const tv = new BigInt64Array([0n, 0n]);
  const n = sys.select(fd + 1, null, sys.ptr(set), null, sys.ptr(tv));
  return n > 0 && (set[fd >> 3] & (1 << (fd & 7))) !== 0;
}

function bendo_upstream_dial(sys, addrs, port, deadline, k) {
  let last = BENDO_NO_ADDRESS;
  const error = (fd) => {
    const v = new Int32Array([0]);
    const l = new Uint32Array([4]);
    return sys.getsockopt(fd, sys.mac ? 0xffff : 1, sys.mac ? 0x1007 : 4, sys.ptr(v), sys.ptr(l)) <
      0
      ? sys.errno()
      : v[0];
  };
  const attempt = (i) => {
    for (; i < addrs.length; i += 1) {
      const now = performance.now();
      if (now >= deadline) {
        return bendo_upstream_connect_failure(110);
      }
      const left = addrs.length - i;
      const until = left === 1 ? deadline : now + (deadline - now) / left;
      const [family, address] = addrs[i];
      const at = bendo_upstream_sockaddr(sys, family, address, port);
      if (at === null) {
        last = 22;
        continue;
      }
      const fd = sys.socket(family === 4 ? 2 : sys.mac ? 30 : 10, 1, 0);
      if (fd < 0) {
        last = sys.errno();
        continue;
      }
      const set = sys.fcntl(fd, 4, sys.fcntl(fd, 3, 0) | (sys.mac ? 4 : 0x800));
      const ok = set >= 0 && sys.connect(fd, sys.ptr(at), at.length) >= 0;
      const code = ok ? 0 : sys.errno();
      if (code === 0) {
        return { $: CID(Done), value: fd };
      }
      if (code !== (sys.mac ? 36 : 115)) {
        last = code;
        sys.close(fd);
        continue;
      }
      const next = i + 1;
      // Writable means the attempt finished; past its share it is late.
      const check = () => {
        if (bendo_upstream_writable(sys, fd)) {
          const err = error(fd);
          if (err === 0) {
            return { $: CID(Done), value: fd };
          }
          last = err;
        } else if (!io_late(until)) {
          io_park_on(fd, true, k, check, until);
          return undefined;
        } else {
          last = 110;
        }
        sys.close(fd);
        return io_late(deadline) ? bendo_upstream_connect_failure(110) : attempt(next);
      };
      io_park_on(fd, true, k, check, until);
      return undefined;
    }
    return bendo_upstream_connect_failure(last);
  };
  return attempt(0);
}

function bendo_upstream_connect(host, port, ms, k) {
  if (typeof io_sys !== "function" || typeof io_park_on !== "function") {
    return bendo_upstream_connect_failure(38);
  }
  const p = Number(port);
  if (host === "" || host.includes("\0") || p === 0 || p > 65535) {
    return bendo_upstream_connect_failure(22);
  }
  const deadline = io_until(ms);
  const sys = io_sys();
  if (io_addr(host, p) !== null) {
    return bendo_upstream_dial(sys, [[4, host]], p, deadline, k);
  }
  if (bendo_upstream_v6(host) !== null) {
    return bendo_upstream_dial(sys, [[6, host]], p, deadline, k);
  }
  const fds = new Int32Array(2);
  let resolver;
  try {
    resolver = bendo_upstream_resolver();
    if (bendo_upstream_pipe()(fds) !== 0) {
      return bendo_upstream_connect_failure(sys.errno());
    }
  } catch {
    return bendo_upstream_connect_failure(38);
  }
  const [r, w] = fds;
  sys.fcntl(r, 4, sys.fcntl(r, 3, 0) | (sys.mac ? 4 : 0x800));
  resolver.postMessage({ host, fd: w });
  let text = "";
  const buf = new Uint8Array(4096);
  const read = () => {
    let n = 1;
    while (n > 0) {
      n = Number(sys.read(r, sys.ptr(buf), buf.length));
      text += n > 0 ? new TextDecoder().decode(buf.subarray(0, n)) : "";
    }
    if (!text.includes("\n")) {
      if (n === 0) {
        sys.close(r);
        return bendo_upstream_connect_failure(BENDO_NO_ADDRESS);
      }
      if (!io_late(deadline)) {
        io_park_on(r, false, k, read, deadline);
        return undefined;
      }
      sys.close(r);
      return bendo_upstream_connect_failure(110);
    }
    sys.close(r);
    let answer;
    try {
      answer = JSON.parse(text);
    } catch {
      return bendo_upstream_connect_failure(BENDO_NO_ADDRESS);
    }
    const list = Array.isArray(answer.list) ? answer.list : [];
    const usable = list.filter((a) => (a[0] === 4 || a[0] === 6) && typeof a[1] === "string");
    if (usable.length === 0) {
      return bendo_upstream_connect_failure(BENDO_NO_ADDRESS);
    }
    return bendo_upstream_dial(sys, bendo_upstream_order(usable), p, deadline, k);
  };
  io_park_on(r, false, k, read, deadline);
  return undefined;
}

io_eff(CID(upstream_connect), bendo_upstream_connect);
