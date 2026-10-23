# Trusted file-open boundary for static files (BND-45), outside the proofs.
# `path` must be root ++ "/" ++ rel, as StaticPath.target builds it. The
# effect opens `root` as a directory, then walks each '/'-separated segment
# of rel beneath it with openat and O_NOFOLLOW, so a symlink anywhere below
# the root is refused, even one that points back inside. Only a regular file
# opens: a directory fails with EISDIR (21), anything else with ENOENT.
# Done holds the open file, its size in bytes (below 4 GiB, else EFBIG), its
# modification time, the later of its modification and status-change times
# (both Unix seconds, clamped to 0..253402300799), and its change stamp.
# The stamp is device, inode, size, mtime and ctime with nanoseconds, in hex.
# Every write sets ctime to the current time and nothing can set it back, so
# once both times are two seconds old the stamp changes whenever the content
# does. While either time is younger the stamp is "".
import Base

def open_beneath(root: String, path: String) -> IO(Result<&1, &1, U32 & String, File & (Nat & (Nat & (Nat & String)))>):
  import "./static_file.c"
  import "./static_file.js"
