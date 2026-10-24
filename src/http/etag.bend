# Static-file entity tags and the strong comparison If-Range needs (RFC 9110
# section 8.8.3). If-None-Match uses BND-41's Conditional.matches instead.
import Base

# A strong tag from a settled file's change stamp (src/effects/static_file.bend):
# device, inode, size, mtime and ctime in nanoseconds. ctime moves on every
# write and cannot be set back, so the tag changes whenever the content does,
# barring a wall clock stepped backwards onto the same nanosecond.
def strong(+stamp: String) -> String:
  "\"" ++ stamp ++ "\""

# Strong comparison: both tags are strong and identical.
def strong_eq(+a: String, +b: String) -> Bool:
  Bool.not(String.starts_with(a, "W/")) && Bool.not(String.starts_with(b, "W/")) && String.eq(a, b)
