# Entity tags and their comparisons (RFC 9110 section 8.8.3). Pure, so the
# cache middleware (BND-41) can reuse it.
import Base

# A strong tag from a settled file's change stamp (src/effects/static_file.bend):
# device, inode, size, mtime and ctime in nanoseconds. ctime moves on every
# write and cannot be set back, so the tag changes whenever the content does,
# barring a wall clock stepped backwards onto the same nanosecond.
def strong(+stamp: String) -> String:
  "\"" ++ stamp ++ "\""

def opaque_of(weak_prefix: Bool, +tag: String) -> String:
  match weak_prefix:
    case True{}: String.drop(tag, 2n)
    case False{}: tag

# The quoted opaque part, without a W/ prefix.
def opaque(+tag: String) -> String:
  opaque_of(String.starts_with(tag, "W/"), tag)

# Weak comparison: the opaque parts match, whether either tag is weak.
def weak_eq(+a: String, +b: String) -> Bool:
  String.eq(opaque(a), opaque(b))

# Strong comparison: both tags are strong and identical.
def strong_eq(+a: String, +b: String) -> Bool:
  Bool.not(String.starts_with(a, "W/")) && Bool.not(String.starts_with(b, "W/")) && String.eq(a, b)

def any_listed(items: List<&2, String>, +tag: String) -> Bool:
  match items:
    case Nil{}: False{}
    case +h <> t:
      +item = String.trim(h)
      String.eq(item, "*") || weak_eq(item, tag) || any_listed(t, tag)

def any_field(values: List<&2, String>, +tag: String) -> Bool:
  match values:
    case Nil{}: False{}
    case h <> t: any_listed(String.split(h, ','), tag) || any_field(t, tag)

# If-None-Match: True when any field lists the current tag or "*", so the
# answer is 304 for GET and HEAD. Repeated fields are read as one list.
# Splitting on ',' cannot invent a match for a tag without a comma, which
# every tag from `strong` is. This is the one place static files compare
# If-None-Match; when BND-41's Conditional.matches (the canonical RFC 9110
# weak comparison) reaches main, this becomes `any field matches` over it.
def none_match(values: List<&2, String>, +tag: String) -> Bool:
  any_field(values, tag)
