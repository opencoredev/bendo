// Trusted host effect. getpeername(2) through bun:ffi on a borrowed socket.
// Bend's own libc table has no getpeername, so this twin opens its own.
// IPv6 is written uncompressed; Bendo re-parses and canonicalizes the text.
// Construct values directly: .mjs libraries do not include executable IO helpers.
function bendo_peer_pair(fst, snd) {
  return { $: CID(Tuple), fst, snd };
}

function bendo_peer_failure(socket, code, message) {
  return bendo_peer_pair(socket, {
    $: CID(Fail),
    error: bendo_peer_pair(code >>> 0, message),
  });
}

function bendo_peer_libc() {
  if (globalThis.BENDO_PEER_LIBC === undefined) {
    const ffi = require("bun:ffi");
    const mac = process.platform === "darwin";
    const errno = mac ? "__error" : "__errno_location";
    const lib = ffi.dlopen(mac ? "libSystem.dylib" : "libc.so.6", {
      getpeername: { args: ["i32", "ptr", "ptr"], returns: "i32" },
      [errno]: { args: [], returns: "ptr" },
    }).symbols;
    globalThis.BENDO_PEER_LIBC = {
      mac,
      ptr: ffi.ptr,
      getpeername: lib.getpeername,
      errno: () => ffi.read.i32(lib[errno](), 0),
    };
  }
  return globalThis.BENDO_PEER_LIBC;
}

function bendo_peer_address(socket) {
  let sys;
  try {
    sys = bendo_peer_libc();
  } catch {
    return bendo_peer_failure(socket, 38, "getpeername unavailable");
  }
  const at = new Uint8Array(128);
  const len = new Uint32Array([128]);
  if (sys.getpeername(Number(socket), sys.ptr(at), sys.ptr(len)) !== 0) {
    const code = sys.errno();
    return bendo_peer_failure(socket, code, "getpeername failed (errno " + code + ")");
  }
  // Linux: 16-bit family first. macOS: one length byte, then an 8-bit family.
  const family = sys.mac ? at[1] : at[0] | (at[1] << 8);
  const port = (at[2] << 8) | at[3];
  if (family === 2) {
    const host = at[4] + "." + at[5] + "." + at[6] + "." + at[7];
    return bendo_peer_pair(socket, { $: CID(Done), value: bendo_peer_pair(host, port) });
  }
  if (family === (sys.mac ? 30 : 10)) {
    const groups = [];
    for (let i = 8; i < 24; i += 2) groups.push(((at[i] << 8) | at[i + 1]).toString(16));
    return bendo_peer_pair(socket, {
      $: CID(Done),
      value: bendo_peer_pair(groups.join(":"), port),
    });
  }
  return bendo_peer_failure(socket, 97, "unsupported address family");
}

io_eff(CID(peer_address), bendo_peer_address);
