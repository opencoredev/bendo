# BND-85: the media-type essence of a Content-Type value, stated without
# src/http/media.bend. RFC 9110 section 8.3.1: a media type is type "/"
# subtype, then parameters after ';', and type and subtype compare without
# case. The essence is the text before the first ';', without leading and
# trailing SP and HTAB, in ASCII lowercase (Base's Char.to_lower maps A-Z
# only).
import Base
import ./trim-spec.bend as Trim

def stop_pick(c: Char, rest: String, semicolon: Bool) -> String:
  match semicolon:
    case True{}: ""
    case False{}: SCon{c, rest}

# The text before the first ';', or all of it.
def before(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{+c, t}: stop_pick(c, before(t), Char.is_eq(c, ';'))

def essence(value: String) -> String:
  String.to_lower(Trim.trim(before(value)))
