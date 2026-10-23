import Base
import ../src/data/cookie.bend as C
import ./cookie-serialization-spec.bend as Independent

# Canonical Cookie header specification. Validity is only the conjunction of
# each entry's independent name/value checks; duplicate names are permitted.
def entries_valid(xs: List<&2, C.Entry>) -> Bool:
  match xs:
    case Nil{}: True{}
    case C.Entry{+name, +value} <> t:
      Independent.name_valid(name) && Independent.value_valid(value) && entries_valid(t)

def pairs(xs: List<&2, C.Entry>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case C.Entry{name, value} <> t: (name ++ "=" ++ value) <> pairs(t)
