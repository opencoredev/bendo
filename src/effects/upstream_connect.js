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
// As in the C effect, at most BENDO_RESOLVERS lookups are outstanding at once
// and one more fails with EAGAIN. A lookup counts until the worker has
// answered it and closed its pipe, not until its request gives up, so slow
// DNS cannot pile up descriptors. Addresses are tried as in the C effect: at
// most BENDO_ADDRS of each family in the resolver's order, alternating
// families from the first answer's, and at most BENDO_ADDRS in all, each
// attempt but the last getting an equal share of the time left.
const BENDO_ADDRS = 8;
const BENDO_RESOLVERS = 32;
const BENDO_NO_ADDRESS = 1001;
const BENDO_EAGAIN = 11;

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

// The resolver worker and the count of lookups it has not finished, shared
// with the worker so it can drop a lookup the moment its pipe is closed.
function bendo_upstream_resolver() {
  if (globalThis.BENDO_RESOLVER === undefined) {
    const { Worker } = require("worker_threads");
    const source = `
      const { parentPort, workerData } = require("worker_threads");
      const dns = require("dns");
      const fs = require("fs");
      const pending = new Int32Array(workerData);
      parentPort.on("message", ({ host, fd }) => {
        dns.lookup(host, { all: true, verbatim: true }, (error, list) => {
          const answer = error
            ? { error: String(error.code) }
            : { list: list.map((a) => [a.family, a.address]) };
          try {
            fs.writeSync(fd, JSON.stringify(answer) + "\\n");
          } catch {}
          try {
            fs.closeSync(fd);
          } catch {}
          Atomics.sub(pending, 0, 1);
        });
      });`;
    const pending = new SharedArrayBuffer(4);
    const worker = new Worker(source, { eval: true, workerData: pending });
    worker.unref();
    globalThis.BENDO_RESOLVER = { worker, pending: new Int32Array(pending) };
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

// The addresses to try, as bendo_dial_order picks them in the C effect: the
// first BENDO_ADDRS of each family in the resolver's order, then alternating
// families from the first answer's, BENDO_ADDRS in all. Entries that are not
// [4 or 6, address text] are skipped. A family's later addresses never push
// out the other family.
function bendo_upstream_order(list) {
  const fam = { 4: [], 6: [] };
  let first;
  for (const a of list) {
    if (!Array.isArray(a) || (a[0] !== 4 && a[0] !== 6) || typeof a[1] !== "string") continue;
    if (fam[a[0]].length === BENDO_ADDRS) continue;
    first ??= a[0];
    fam[a[0]].push([a[0], a[1]]);
  }
  if (first === undefined) return [];
  const same = fam[first];
  const other = fam[first === 4 ? 6 : 4];
  const out = [];
  for (let j = 0; j < BENDO_ADDRS; j += 1) {
    if (j < same.length && out.length < BENDO_ADDRS) out.push(same[j]);
    if (j < other.length && out.length < BENDO_ADDRS) out.push(other[j]);
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
  } catch {
    return bendo_upstream_connect_failure(38);
  }
  if (Atomics.add(resolver.pending, 0, 1) >= BENDO_RESOLVERS) {
    Atomics.sub(resolver.pending, 0, 1);
    return bendo_upstream_connect_failure(BENDO_EAGAIN);
  }
  try {
    if (bendo_upstream_pipe()(fds) !== 0) {
      Atomics.sub(resolver.pending, 0, 1);
      return bendo_upstream_connect_failure(sys.errno());
    }
  } catch {
    Atomics.sub(resolver.pending, 0, 1);
    return bendo_upstream_connect_failure(38);
  }
  const [r, w] = fds;
  sys.fcntl(r, 4, sys.fcntl(r, 3, 0) | (sys.mac ? 4 : 0x800));
  try {
    resolver.worker.postMessage({ host, fd: w });
  } catch {
    Atomics.sub(resolver.pending, 0, 1);
    sys.close(r);
    sys.close(w);
    return bendo_upstream_connect_failure(38);
  }
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
    const usable = bendo_upstream_order(Array.isArray(answer.list) ? answer.list : []);
    if (usable.length === 0) {
      return bendo_upstream_connect_failure(BENDO_NO_ADDRESS);
    }
    return bendo_upstream_dial(sys, usable, p, deadline, k);
  };
  io_park_on(r, false, k, read, deadline);
  return undefined;
}

io_eff(CID(upstream_connect), bendo_upstream_connect);
