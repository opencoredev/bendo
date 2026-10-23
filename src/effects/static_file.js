// Trusted host effect for static files, the twin of static_file.c. Node has
// no openat, so each segment is checked with lstat before the file opens with
// O_NOFOLLOW, and the opened file must match the inspected one. A directory
// swapped for a symlink between those checks and the open can still redirect
// the walk: this twin has a time-of-check to time-of-use window the native
// one does not. Serve untrusted, writable trees with the native build.
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
    const before = fs.lstatSync(at);
    if (before.isDirectory()) {
      return io_fail(errno.EISDIR);
    }
    if (!before.isFile()) {
      return io_fail(errno.ENOENT);
    }
    const c = fs.constants;
    const fd = fs.openSync(at, c.O_RDONLY | c.O_NOFOLLOW | c.O_NONBLOCK);
    const st = fs.fstatSync(fd);
    if (!st.isFile() || st.dev !== before.dev || st.ino !== before.ino) {
      fs.closeSync(fd);
      return io_fail(errno.ENOENT);
    }
    if (st.size > 4294967295) {
      fs.closeSync(fd);
      return io_fail(errno.EFBIG);
    }
    const secs = Math.min(Math.max(0, Math.floor(st.mtimeMs / 1000)), 253402300799);
    return io_done(io_tup(fd, st.size, secs));
  } catch (e) {
    return io_fail(Math.abs(e.errno ?? errno.EIO));
  }
}

io_eff(CID(open_beneath), bendo_static_open);
