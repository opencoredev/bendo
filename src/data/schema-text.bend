# Bounded scalar text checks. Every text-width traversal is tail recursive.
import Base
import ./decimal.bend as D

def between(+c: U32, lo: U32, hi: U32) -> Bool:
  (c >= lo : U32) && (c <= hi : U32)

def digit(c: U32) -> Bool:
  between(c, 48, 57)

def alpha(+c: U32) -> Bool:
  between(c, 65, 90) || between(c, 97, 122)

def alnum(+c: U32) -> Bool:
  alpha(c) || digit(c)

def hex(+c: U32) -> Bool:
  digit(c) || between(c, 65, 70) || between(c, 97, 102)

def contains(s: String, +c: U32, found: Bool) -> Bool:
  match s:
    case SNil{}: found
    case SCon{Chr{h}, t}: contains(t, c, found || U32.is_eq(h, c))

def atom(+c: U32) -> Bool:
  alnum(c) || contains("!#$%&'*+-/=?^_`{|}~", c, False{})

# DNS labels: 1..63 ASCII alphanumeric/hyphen, alphanumeric endpoints.
def host_go(s: String, +n: Nat, last: Bool, ok: Bool) -> Bool:
  match s:
    case SNil{}: ok && last && Nat.is_gt(n, 0n) && Nat.is_le(n, 63n)
    case SCon{'.', t}: host_go(t, 0n, False{}, ok && last && Nat.is_gt(n, 0n) && Nat.is_le(n, 63n))
    case SCon{Chr{+c}, t}:
      host_go(t, 1n+n, alnum(c), ok && (alnum(c) || (U32.is_eq(c, 45) && Nat.is_gt(n, 0n))))

def host(+s: String) -> Bool:
  Nat.is_le(D.length(s), 253n) && host_go(s, 0n, False{}, True{})

# Dot-atom local part, no leading/trailing/consecutive dots; 64 scalar limit.
def email_go(s: String, +n: Nat, last: Bool, ok: Bool) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{'@', +t}: ok && last && Nat.is_gt(n, 0n) && Nat.is_le(n, 64n) && host(t)
    case SCon{'.', t}: email_go(t, 1n+n, False{}, ok && last)
    case SCon{Chr{c}, t}: email_go(t, 1n+n, True{}, ok && atom(c))

def email(+s: String) -> Bool:
  Nat.is_le(D.length(s), 254n) && email_go(s, 0n, False{}, True{})

def uri_char(+c: U32) -> Bool:
  alnum(c) || contains("-._~:/?#[]@!$&'()*+,;=", c, False{})

def suffix(s: String, ok: Bool) -> Bool:
  match s:
    case SNil{}: ok
    case SCon{'%', SCon{Chr{a}, SCon{Chr{b}, t}}}: suffix(t, ok && hex(a) && hex(b))
    case SCon{Chr{c}, t}: suffix(t, ok && uri_char(c))

def port(s: String, +n: Nat, +value: U32, ok: Bool) -> Bool:
  match s:
    case SNil{}: ok && Nat.is_gt(n, 0n) && (value <= 65535 : U32)
    case SCon{'/', t}: ok && Nat.is_gt(n, 0n) && (value <= 65535 : U32) && suffix(t, True{})
    case SCon{'?', t}: ok && Nat.is_gt(n, 0n) && (value <= 65535 : U32) && suffix(t, True{})
    case SCon{'#', t}: ok && Nat.is_gt(n, 0n) && (value <= 65535 : U32) && suffix(t, True{})
    case SCon{Chr{+c}, t}:
      port(t, 1n+n, ((value % 100000) * 10 + c - 48 : U32), ok && digit(c) && Nat.is_lt(n, 5n))

def authority(s: String, rev: String) -> Bool:
  match s:
    case SNil{}: host(String.reverse(rev))
    case SCon{':', t}: host(String.reverse(rev)) && port(t, 0n, 0, True{})
    case SCon{'/', t}: host(String.reverse(rev)) && suffix(t, True{})
    case SCon{'?', t}: host(String.reverse(rev)) && suffix(t, True{})
    case SCon{'#', t}: host(String.reverse(rev)) && suffix(t, True{})
    case SCon{c, t}: authority(t, SCon{c, rev})

def url(s: String) -> Bool:
  match s:
    case SCon{'h', SCon{'t', SCon{'t', SCon{'p', SCon{':', SCon{'/', SCon{'/', t}}}}}}}: authority(t, "")
    case SCon{'h', SCon{'t', SCon{'t', SCon{'p', SCon{'s', SCon{':', SCon{'/', SCon{'/', t}}}}}}}}: authority(t, "")
    case _: False{}
