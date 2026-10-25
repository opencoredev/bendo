# Trusted host effect, outside the proofs: compress octets with zlib
# (BND-46). format 1 writes a gzip member (RFC 1952) and format 2 a zlib
# stream (RFC 1950), which is what HTTP calls "deflate" (RFC 9110 8.4.1.2).
# level is the zlib level, 1 to 9. An input longer than limit octets fails
# with EFBIG (27) before any work, an octet above 255 fails with EINVAL (22),
# and a missing system zlib fails with ENOSYS (38). See zlib.c and zlib.js.
import Base

def zlib_compress(format: U32, level: U32, limit: U32, data: List<&2, U32>) -> IO(Result<&1, &1, U32 & String, List<&2, U32>>):
  import "./zlib.c"
  import "./zlib.js"
