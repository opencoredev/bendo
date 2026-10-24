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
// deadline. As in the C effect, at most BENDO_RESOLVERS lookups are
// outstanding at once and one more fails with EAGAIN. A lookup holds its slot
// until the worker has finished with it, not until its request gives up, so
// slow DNS cannot pile up work. Addresses are tried as in the C effect: at
// most BENDO_ADDRS of each family in the resolver's order, alternating
// families from the first answer's, and at most BENDO_ADDRS in all, each
// attempt but the last getting an equal share of the time left.
const BENDO_ADDRS = 8;
const BENDO_RESOLVERS = 32;
const BENDO_NO_ADDRESS = 1001;
const BENDO_EAGAIN = 11;
// The worker stamps its beat word with the time this often; one whose stamp
// is BENDO_RESOLVER_STALE_MS old is taken for dead and replaced. A parked lookup
// wakes every BENDO_RESOLVER_CHECK_MS to look, so it survives a dead worker,
// and so does the janitor that closes write ends left behind.
const BENDO_RESOLVER_BEAT_MS = 200;
const BENDO_RESOLVER_STALE_MS = 2000;
const BENDO_RESOLVER_CHECK_MS = 500;
// A slot word is ticket << 3 | phase, or 0 when free. Every ticket goes to
// exactly one worker, once, so a late or duplicate answer never touches a
// newer lookup and a slot in (ticket, WRITING) names the worker writing it.
const BENDO_ASKED = 1;
const BENDO_WRITING = 2;
const BENDO_ABANDONED = 3;

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

// The resolver worker, recreated when it dies. Exit events never reach this
// thread, and Bun takes postMessage to a dead worker without an error, so
// death shows only as a beat stamp that stops moving. Stamps are
// performance.timeOrigin + performance.now(), which both threads share.
//
// Descriptor ownership. Each lookup is a record in res.lookups, and this
// thread owns both ends of its pipe; only this thread closes them, each once.
// A worker only writes, synchronously on its own thread, and only between
// moving the slot from (ticket, ASKED) to (ticket, WRITING) and moving it on
// to 0. So the write end is closed only when one of these holds:
// - the slot was moved from (ticket, ASKED) to anything by this thread, so no
//   worker can claim that ticket (a request giving up, or recovery handing
//   the lookup to a new worker under a new ticket);
// - the slot has left (ticket, WRITING), so the write returned;
// - the whole answer line has been read and the lookup was never sent again,
//   so its one writer has no bytes left to write;
// - the thread of the worker that took the ticket has ended.
// A stale beat proves nothing on its own: a paused worker may still write.
// Before it claims anything a worker publishes its kernel thread id and start
// time, and a retired worker counts as ended only once /proc/self/task no
// longer lists that thread. Until then its WRITING slots, and their write
// ends, stay as they are. Where /proc cannot say (the id is -1), they stay
// for good: a leak of at most one slot and one descriptor per lookup caught
// mid-write, never a write into a reused descriptor number.
function bendo_upstream_spawn(res) {
  const { Worker } = require("worker_threads");
  const source = `
    const { parentPort, workerData } = require("worker_threads");
    const dns = require("dns");
    const fs = require("fs");
    const slots = new Int32Array(workerData.slots);
    const id = new BigInt64Array(workerData.id);
    let tid = -1n;
    let start = 0n;
    try {
      const stat = fs.readFileSync("/proc/thread-self/stat", "utf8");
      start = BigInt(stat.slice(stat.lastIndexOf(")") + 2).split(" ")[19]);
      tid = BigInt(stat.slice(0, stat.indexOf(" ")));
    } catch {}
    Atomics.store(id, 2, start);
    Atomics.store(id, 1, tid);
    const stamp = () =>
      Atomics.store(id, 0, BigInt(Math.round(performance.timeOrigin + performance.now())));
    stamp();
    setInterval(stamp, ${BENDO_RESOLVER_BEAT_MS});
    let hook;
    parentPort.on("message", ({ slot, ticket, host, fd, test }) => {
      if (test !== undefined) {
        if (test.exit !== undefined) setTimeout(() => process.exit(1), test.exit);
        else hook = test;
        return;
      }
      dns.lookup(host, { all: true, verbatim: true }, (error, list) => {
        const asked = ticket * 8 + ${BENDO_ASKED};
        const writing = ticket * 8 + ${BENDO_WRITING};
        if (Atomics.compareExchange(slots, slot, asked, writing) !== asked) {
          Atomics.compareExchange(slots, slot, ticket * 8 + ${BENDO_ABANDONED}, 0);
          return;
        }
        if (hook !== undefined) {
          const { stall } = hook;
          hook = undefined;
          if (stall === undefined) {
            process.exit(1);
            return;
          }
          Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, stall);
        }
        const answer = error
          ? { error: String(error.code) }
          : { list: list.map((a) => [a.family, a.address]) };
        try {
          fs.writeSync(fd, JSON.stringify(answer) + "\\n");
        } catch {}
        Atomics.compareExchange(slots, slot, writing, 0);
        Atomics.notify(slots, slot);
      });
    });`;
  // Beat stamp, thread id (0 until published) and thread start time.
  const id = new SharedArrayBuffer(24);
  const words = new BigInt64Array(id);
  // Startup gets a full BENDO_RESOLVER_STALE_MS before its first stamp.
  words[0] = BigInt(Math.round(performance.timeOrigin + performance.now()));
  const worker = new Worker(source, { eval: true, workerData: { slots: res.slots.buffer, id } });
  worker.unref();
  res.gen += 1;
  res.worker = worker;
  res.id = words;
}

// True once a retired worker can no longer write: its thread has ended. One
// that never published an id never ran, so it claimed nothing, and recovery
// has already moved every ticket it was sent.
function bendo_upstream_gone(id) {
  const tid = Atomics.load(id, 1);
  if (tid === 0n) return true;
  if (tid < 0n) return false;
  try {
    const stat = require("fs").readFileSync(`/proc/self/task/${tid}/stat`, "utf8");
    return stat.slice(stat.lastIndexOf(")") + 2).split(" ")[19] !== String(Atomics.load(id, 2));
  } catch (e) {
    return e?.code === "ENOENT" || e?.code === "ESRCH";
  }
}

// Moves a lookup's slot from the word `from` to a new ticket, ASKED, and
// sends it to the current worker. False only when the message fails.
function bendo_upstream_send(res, look, from, resent) {
  res.ticket = (res.ticket % 0xfffffff) + 1;
  const ticket = res.ticket;
  if (Atomics.compareExchange(res.slots, look.slot, from, ticket * 8 + BENDO_ASKED) !== from) {
    return true;
  }
  look.ticket = ticket;
  look.gen = res.gen;
  look.resent ||= resent;
  try {
    res.worker.postMessage({ slot: look.slot, ticket, host: look.host, fd: look.w });
  } catch {
    return false;
  }
  return true;
}

// Replaces a worker whose beat has stopped. Its waiting lookups not yet
// claimed move to the new worker under new tickets, and slots abandoned to
// it are freed. Its WRITING slots wait in bendo_upstream_reap for its thread
// to end.
function bendo_upstream_recover(res) {
  try {
    res.worker.terminate();
  } catch {}
  res.retired.push({ gen: res.gen, id: res.id });
  bendo_upstream_spawn(res);
  for (const look of res.lookups) {
    if (look.waiting && look.gen !== res.gen) {
      bendo_upstream_send(res, look, look.ticket * 8 + BENDO_ASKED, false);
    }
  }
  for (let i = 0; i < BENDO_RESOLVERS; i += 1) {
    const word = Atomics.load(res.slots, i);
    if ((word & 7) === BENDO_ABANDONED) Atomics.compareExchange(res.slots, i, word, 0);
  }
}

// Closes the write ends whose writes are over and forgets their lookups.
// Once a retired worker's thread has ended, its WRITING slots are freed, or
// sent to the current worker under a new ticket if their request still
// waits. Keeps the janitor running while a write end waits on a worker that
// can still finish.
function bendo_upstream_reap(sys, res) {
  res.retired = res.retired.filter(({ id }) => !bendo_upstream_gone(id));
  const retired = new Map(res.retired.map(({ gen, id }) => [gen, id]));
  let parked = false;
  for (const look of res.lookups) {
    const writing = look.ticket * 8 + BENDO_WRITING;
    const held = Atomics.load(res.slots, look.slot) === writing;
    if (held && (look.gen === res.gen || retired.has(look.gen))) {
      parked ||=
        !look.waiting && (look.gen === res.gen || Atomics.load(retired.get(look.gen), 1) > 0n);
      continue;
    }
    if (held && look.waiting) {
      bendo_upstream_send(res, look, writing, true);
      continue;
    }
    if (look.waiting) continue;
    if (look.w >= 0) sys.close(look.w);
    if (held) Atomics.compareExchange(res.slots, look.slot, writing, 0);
    res.lookups.delete(look);
  }
  if (parked) bendo_upstream_janitor(sys, res);
}

// Replaces a dead worker, then reaps.
function bendo_upstream_maintain(sys, res) {
  const now = performance.timeOrigin + performance.now();
  if (now - Number(Atomics.load(res.id, 0)) > BENDO_RESOLVER_STALE_MS) {
    bendo_upstream_recover(res);
  }
  bendo_upstream_reap(sys, res);
}

// Parks a wait with no computation behind it, which maintains the resolver
// every BENDO_RESOLVER_CHECK_MS while write ends wait, with no lookups to do
// it. It never resumes anything, so it keeps no run alive. One whose turn is
// long overdue is taken as lost, say with the run that parked it, and
// replaced; the old one, if it fires after all, does not park again.
function bendo_upstream_janitor(sys, res) {
  const now = performance.now();
  if (res.janitor !== undefined && now < res.janitor.at + BENDO_RESOLVER_CHECK_MS) return;
  const mine = { at: now + BENDO_RESOLVER_CHECK_MS };
  res.janitor = mine;
  const more = () => {
    if (res.janitor === mine) res.janitor = undefined;
    try {
      bendo_upstream_maintain(sys, res);
    } catch {}
    return undefined;
  };
  io_park_on(undefined, false, undefined, more, mine.at);
}

// The resolver state, maintained. Shared with every worker: the slot words,
// and with each worker its own beat and id words.
function bendo_upstream_resolver(sys) {
  let res = globalThis.BENDO_RESOLVER;
  if (res === undefined) {
    res = {
      slots: new Int32Array(new SharedArrayBuffer(4 * BENDO_RESOLVERS)),
      lookups: new Set(),
      retired: [],
      gen: 0,
      ticket: 0,
      janitor: undefined,
    };
    bendo_upstream_spawn(res);
    globalThis.BENDO_RESOLVER = res;
  }
  bendo_upstream_maintain(sys, res);
  return res;
}

// Ends a request's use of its lookup: closes the read end, abandons the slot
// if no worker has claimed it, and closes the write end when the ownership
// rule above allows; otherwise the record stays for bendo_upstream_reap. A
// whole answer read from a lookup never sent again means its write is over.
function bendo_upstream_resolved(sys, res, look, r, answered) {
  const asked = look.ticket * 8 + BENDO_ASKED;
  const writing = look.ticket * 8 + BENDO_WRITING;
  sys.close(r);
  look.waiting = false;
  if (
    Atomics.compareExchange(res.slots, look.slot, asked, look.ticket * 8 + BENDO_ABANDONED) ===
    asked
  ) {
    sys.close(look.w);
    res.lookups.delete(look);
    return;
  }
  const over = answered && !look.resent;
  if (!over && Atomics.load(res.slots, look.slot) === writing) {
    Atomics.wait(res.slots, look.slot, writing, 100);
  }
  if (Atomics.load(res.slots, look.slot) === writing) {
    if (over) {
      sys.close(look.w);
      look.w = -1;
    }
    bendo_upstream_janitor(sys, res);
    return;
  }
  sys.close(look.w);
  res.lookups.delete(look);
}

// Test-only probes, enabled by BENDO_RESOLVER_TEST_HOOKS=1: a code, or
// undefined when host is not a probe. pending.resolver.bendo.test counts the
// used slots, fds.resolver.bendo.test the open descriptors,
// terminate.resolver.bendo.test terminates the worker,
// exit.resolver.bendo.test makes it exit after port milliseconds, and
// after its next claim, claimexit.resolver.bendo.test makes it exit and
// claimstall.resolver.bendo.test makes it block for port milliseconds before
// writing.
function bendo_upstream_probe(host, port) {
  if (globalThis.BENDO_RESOLVER_HOOKS === undefined) {
    globalThis.BENDO_RESOLVER_HOOKS = process.env.BENDO_RESOLVER_TEST_HOOKS === "1";
  }
  if (!globalThis.BENDO_RESOLVER_HOOKS || !host.endsWith(".resolver.bendo.test")) {
    return undefined;
  }
  const res = globalThis.BENDO_RESOLVER;
  switch (host) {
    case "pending.resolver.bendo.test":
      return res === undefined ? 0 : res.slots.filter((word) => word !== 0).length;
    case "fds.resolver.bendo.test":
      return require("fs").readdirSync("/proc/self/fd").length;
    case "terminate.resolver.bendo.test":
      res?.worker.terminate();
      return 0;
    case "exit.resolver.bendo.test":
      res?.worker.postMessage({ test: { exit: port } });
      return 0;
    case "claimexit.resolver.bendo.test":
      res?.worker.postMessage({ test: {} });
      return 0;
    case "claimstall.resolver.bendo.test":
      res?.worker.postMessage({ test: { stall: port } });
      return 0;
    default:
      return undefined;
  }
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
  const probe = bendo_upstream_probe(host, Number(port));
  if (probe !== undefined) {
    return bendo_upstream_connect_failure(probe);
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
  let res;
  try {
    res = bendo_upstream_resolver(sys);
  } catch {
    return bendo_upstream_connect_failure(38);
  }
  const slot = res.slots.indexOf(0);
  if (slot < 0) {
    return bendo_upstream_connect_failure(BENDO_EAGAIN);
  }
  const fds = new Int32Array(2);
  try {
    if (bendo_upstream_pipe()(fds) !== 0) {
      return bendo_upstream_connect_failure(sys.errno());
    }
  } catch {
    return bendo_upstream_connect_failure(38);
  }
  const [r, w] = fds;
  sys.fcntl(r, 4, sys.fcntl(r, 3, 0) | (sys.mac ? 4 : 0x800));
  // Only this thread fills a free slot; workers only free them.
  const look = { slot, ticket: 0, host, w, gen: 0, waiting: true, resent: false };
  res.lookups.add(look);
  if (!bendo_upstream_send(res, look, 0, false)) {
    bendo_upstream_resolved(sys, res, look, r, false);
    return bendo_upstream_connect_failure(38);
  }
  let text = "";
  const buf = new Uint8Array(4096);
  const park = () => {
    io_park_on(r, false, k, read, Math.min(deadline, performance.now() + BENDO_RESOLVER_CHECK_MS));
    return undefined;
  };
  const read = () => {
    let n = 1;
    while (n > 0) {
      n = Number(sys.read(r, sys.ptr(buf), buf.length));
      text += n > 0 ? new TextDecoder().decode(buf.subarray(0, n)) : "";
    }
    if (!text.includes("\n")) {
      if (!io_late(deadline)) {
        // Woken to check on the worker: replace it if it died.
        try {
          bendo_upstream_resolver(sys);
        } catch {}
        return park();
      }
      bendo_upstream_resolved(sys, res, look, r, false);
      return bendo_upstream_connect_failure(110);
    }
    bendo_upstream_resolved(sys, res, look, r, true);
    // The first line: a lookup sent again after its worker died mid-write
    // may also get the new worker's.
    let answer;
    try {
      answer = JSON.parse(text.slice(0, text.indexOf("\n")));
    } catch {
      return bendo_upstream_connect_failure(BENDO_NO_ADDRESS);
    }
    const usable = bendo_upstream_order(Array.isArray(answer.list) ? answer.list : []);
    if (usable.length === 0) {
      return bendo_upstream_connect_failure(BENDO_NO_ADDRESS);
    }
    return bendo_upstream_dial(sys, usable, p, deadline, k);
  };
  return park();
}

io_eff(CID(upstream_connect), bendo_upstream_connect);
