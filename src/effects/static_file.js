// Trusted host effect for static files, the twin of static_file.c. Node has
// no openat, so each segment is checked with lstat before the file opens with
// O_NOFOLLOW, and the opened file must match the inspected one. A directory
// swapped for a symlink between those checks and the open can still redirect
// the walk: this twin has a time-of-check to time-of-use window the native
// one does not. Serve untrusted, writable trees with the native build.
// The change stamp, as static_file.c writes it: empty until both mtime and
// ctime are at least two seconds old.
function bendo_static_stamp(st) {
  const now = BigInt(Date.now()) * 1000000n;
  const limit = now - 2000000000n;
  if (st.mtimeNs > limit || st.ctimeNs > limit) {
    return "";
  }
  const time = (ns) => (ns / 1000000000n).toString(16) + "." + (ns % 1000000000n).toString(16);
  return (
    [st.dev, st.ino, st.size].map((n) => n.toString(16)).join("-") +
    "-" +
    time(st.mtimeNs) +
    "-" +
    time(st.ctimeNs)
  );
}

function bendo_static_open(root, path) {
  const fs = require("fs");
  const errno = require("os").constants.errno;
  if (root.length === 0 || !path.startsWith(root + "/")) {
    return io_fail(errno.EINVAL);
  }
  if (root.includes("\0") || path.includes("\0")) {
    return io_fail(errno.EILSEQ);
  }
  const parts = path.slice(root.length + 1).split("/");
  if (parts.some((p) => p === "" || p === "." || p === "..")) {
    return io_fail(errno.ENOENT);
  }
  try {
    if (!fs.statSync(root).isDirectory()) {
      return io_fail(errno.ENOTDIR);
    }
    let at = root;
    for (const part of parts.slice(0, -1)) {
      at += "/" + part;
      const st = fs.lstatSync(at);
      // openat(O_DIRECTORY | O_NOFOLLOW) answers ENOTDIR for a symlink too.
      if (!st.isDirectory()) {
        return io_fail(errno.ENOTDIR);
      }
    }
    at += "/" + parts[parts.length - 1];
    const before = fs.lstatSync(at, { bigint: true });
    if (before.isDirectory()) {
      return io_fail(errno.EISDIR);
    }
    if (!before.isFile()) {
      return io_fail(errno.ENOENT);
    }
    const c = fs.constants;
    const fd = fs.openSync(at, c.O_RDONLY | c.O_NOFOLLOW | c.O_NONBLOCK);
    const st = fs.fstatSync(fd, { bigint: true });
    if (!st.isFile() || st.dev !== before.dev || st.ino !== before.ino) {
      fs.closeSync(fd);
      return io_fail(errno.ENOENT);
    }
    if (st.size > 4294967295n) {
      fs.closeSync(fd);
      return io_fail(errno.EFBIG);
    }
    const clamp = (ns) => {
      const secs = ns < 0n ? 0n : ns / 1000000000n;
      return Number(secs > 253402300799n ? 253402300799n : secs);
    };
    const mtime = clamp(st.mtimeNs);
    const ctime = clamp(st.ctimeNs);
    return io_done(
      io_tup(
        fd,
        io_tup(
          Number(st.size),
          io_tup(mtime, io_tup(Math.max(mtime, ctime), bendo_static_stamp(st))),
        ),
      ),
    );
  } catch (e) {
    return io_fail(Math.abs(e.errno ?? errno.EIO));
  }
}

io_eff(CID(open_beneath), bendo_static_open);
