# Media types in Content-Type values.
import Base
import ./bytes.bend as Bytes

def before_params(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{';', t}: ""
    case SCon{c, t}: SCon{c, before_params(t)}

# The essence "type/subtype": the text before any parameter, trimmed and in
# lowercase. "Text/Plain; charset=utf-8" has essence "text/plain".
def essence(value: String) -> String:
  Bytes.fold(String.trim(before_params(value)))
