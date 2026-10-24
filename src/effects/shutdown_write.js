// Trusted host effect. shutdown(2) SHUT_WR through bun:ffi on a borrowed
// socket. Bend's own libc table has no shutdown, so this twin opens its own.
// Errors are ignored, as in the C twin: Socket.close still follows.
function bendo_shutdown_libc() {
  if (globalThis.BENDO_SHUTDOWN_LIBC === undefined) {
    const ffi = require("bun:ffi");
    const mac = process.platform === "darwin";
    globalThis.BENDO_SHUTDOWN_LIBC = ffi.dlopen(mac ? "libSystem.dylib" : "libc.so.6", {
      shutdown: { args: ["i32", "i32"], returns: "i32" },
    }).symbols;
  }
  return globalThis.BENDO_SHUTDOWN_LIBC;
}

function bendo_shutdown_write(socket) {
  try {
    // SHUT_WR is 1 on Linux and macOS.
    bendo_shutdown_libc().shutdown(Number(socket), 1);
  } catch {
    // No FFI (for example a browser build): close sends the FIN instead.
  }
  return socket;
}

io_eff(CID(shutdown_write), bendo_shutdown_write);
