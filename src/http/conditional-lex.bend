import Base

# RFC 9110 entity-tag character class, shared with the reference grammar.
def etagc(+c: U32) -> Bool:
  U32.is_eq(c, 33) || ((c >= 35 : U32) && (c <= 126 : U32)) || ((c >= 128 : U32) && (c <= 255 : U32))
