# Media types in Content-Type values.
import Base
import ./bytes.bend as Bytes

def before_params_spec(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{';', t}: ""
    case SCon{c, t}: SCon{c, before_params_spec(t)}

# rev holds the text read so far, reversed. Same patterns as the spec.
def before_params_go(s: String, rev: String) -> String:
  match s:
    case SNil{}: String.reverse(rev)
    case SCon{';', t}: String.reverse(rev)
    case SCon{c, t}: before_params_go(t, SCon{c, rev})

def before_params(s: String) -> String:
  before_params_go(s, "")

# The essence "type/subtype": the text before any parameter, trimmed and in
# lowercase. "Text/Plain; charset=utf-8" has essence "text/plain".
def essence(value: String) -> String:
  Bytes.fold(String.trim(before_params(value)))
