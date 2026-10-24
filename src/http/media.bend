# Media types in Content-Type values.
import Base
import ./bytes.bend as Bytes

def before_pick(c: Char, rest: String, stop: Bool) -> String:
  match stop:
    case True{}: ""
    case False{}: SCon{c, rest}

def before_params_spec(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{+c, t}: before_pick(c, before_params_spec(t), Char.is_eq(c, ';'))

# c is the character read before t and stop whether it is ';'; rev holds the
# text kept so far, reversed.
def before_params_loop(t: String, rev: String, +c: Char, stop: Bool) -> String:
  match t stop:
    case _ True{}: String.reverse(rev)
    case SNil{} False{}: String.reverse(SCon{c, rev})
    case SCon{+d, u} False{}: before_params_loop(u, SCon{c, rev}, d, Char.is_eq(d, ';'))

def before_params_go(s: String, rev: String) -> String:
  match s:
    case SNil{}: String.reverse(rev)
    case SCon{+c, t}: before_params_loop(t, rev, c, Char.is_eq(c, ';'))

def before_params(s: String) -> String:
  before_params_go(s, "")

# The essence "type/subtype": the text before any parameter, without leading
# and trailing SP and HTAB, in ASCII lowercase. "Text/Plain; charset=utf-8"
# has essence "text/plain". proof/media-spec.bend states it independently.
def essence(value: String) -> String:
  Bytes.fold(Bytes.trim_text(before_params(value)))

# Reads the media type as type "/" subtype, two RFC 9110 tokens. slash records
# whether the '/' was read, some whether the current token has a character,
# and ok whether everything read so far fits. A tail loop: Bool.and is strict
# in the JavaScript target.
def shape_go(s: String, +slash: Bool, some: Bool, ok: Bool) -> Bool:
  match s:
    case SNil{}: ok && slash && some
    case SCon{Chr{+c}, t}: shape_go(t, slash || U32.is_eq(c, 47), Bytes.tchar(c), ok && (Bytes.tchar(c) || (U32.is_eq(c, 47) && some && Bool.not(slash))))

# Whether the essence is a well-formed type "/" subtype. Anything else,
# including a control character the SP and HTAB trim keeps, is malformed.
# proof/media-spec.bend states it independently.
def well_formed(value: String) -> Bool:
  shape_go(Bytes.trim_text(before_params(value)), False{}, False{}, True{})
