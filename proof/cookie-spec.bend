import Base
import ../src/data/cookie.bend as C

# Canonical Cookie header specification. Validity is only the conjunction of
# each entry's independent name/value checks; duplicate names are permitted.
def entries_valid(xs: List<&2, C.Entry>) -> Bool:
  match xs:
    case Nil{}: True{}
    case C.Entry{+name, +value} <> t:
      C.name_valid(name) && C.value_valid(value) && entries_valid(t)

def pairs(xs: List<&2, C.Entry>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case C.Entry{name, value} <> t: C.serialize_pair(name, value) <> pairs(t)
