// Trusted host effect. The JS twin of zlib.c, through node:zlib (Bun ships
// it): format 1 is gzipSync (RFC 1952), format 2 deflateSync, whose output is
// a zlib stream (RFC 1950), HTTP's "deflate". The octets differ from the C
// twin's in the gzip header, but both decode to the same input. The call is
// synchronous: the JS event loop waits while it runs. Without node:zlib (a
// browser build) it fails with ENOSYS and the caller sends identity.
function bendo_zlib_module() {
  if (globalThis.BENDO_ZLIB === undefined) {
    try {
      globalThis.BENDO_ZLIB = require("node:zlib");
    } catch {
      globalThis.BENDO_ZLIB = null;
    }
  }
  return globalThis.BENDO_ZLIB;
}

function bendo_zlib_fail(code, text) {
  return { $: CID(Fail), error: io_tup(code >>> 0, text) };
}

function bendo_zlib_compress(format, level, limit, data) {
  const input = io_unlist(data);
  if (input === null) {
    return bendo_zlib_fail(22, "an octet is above 255");
  }
  if ((format !== 1 && format !== 2) || level < 1 || level > 9) {
    return bendo_zlib_fail(22, "unknown zlib format or level");
  }
  if (input.length > limit) {
    return bendo_zlib_fail(27, "File too large");
  }
  const zlib = bendo_zlib_module();
  if (zlib === null) {
    return bendo_zlib_fail(38, "zlib is not available");
  }
  let out;
  try {
    out = format === 1 ? zlib.gzipSync(input, { level }) : zlib.deflateSync(input, { level });
  } catch {
    return bendo_zlib_fail(5, "zlib compression failed");
  }
  return io_done(io_list(out, out.length));
}

io_eff(CID(zlib_compress), bendo_zlib_compress);
