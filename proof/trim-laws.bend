# BND-85: Bytes.trim and Bytes.trim_text remove exactly the leading and
# trailing SP and HTAB, for every input (proof/trim-spec.bend).
import Base
import ../src/http/bytes.bend as Bytes
import ./trim-spec.bend as Trim

law bytes_trim_spec:
  for +xs: List<&2, U32>
  {Bytes.trim(xs) == Trim.strip(xs) : List<&2, U32>}

law bytes_trim_text_spec:
  for +s: String
  {Bytes.trim_text(s) == Trim.trim(s) : String}
