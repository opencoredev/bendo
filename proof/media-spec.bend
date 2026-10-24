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

# RFC 9110 section 5.6.2: tchar is "!" / "#" / "$" / "%" / "&" / "'" / "*" /
# "+" / "-" / "." / "^" / "_" / "`" / "|" / "~" / DIGIT / ALPHA.
def tchar(+c: U32) -> Bool:
  ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || String.contains("!#$%&'*+-.^_`|~", Char.show(Chr{c}))

def slash(+c: U32) -> Bool:
  U32.is_eq(c, 47)

# The rest of a subtype token; some whether it has a character already.
def subtype(s: String, some: Bool) -> Bool:
  match s:
    case SNil{}: some
    case SCon{Chr{+c}, t}: tchar(c) && subtype(t, True{})

# The rest of a type token, then "/" and a subtype. A "/" may come only after
# at least one type character.
def main_type(s: String, +some: Bool) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+c}, +t}: (tchar(c) && main_type(t, True{})) || (slash(c) && some && subtype(t, False{}))

# RFC 9110 section 8.3.1: whether the media type of a Content-Type value, the
# text before any ';' without leading and trailing SP and HTAB, is
# type "/" subtype. Any other character, a control character included, makes
# it malformed.
def well_formed(value: String) -> Bool:
  main_type(Trim.trim(before(value)), False{})
