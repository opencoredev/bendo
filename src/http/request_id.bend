# Shared request-ID character and length policy.
import Base

def safe_char(+c: U32) -> Bool:
  ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || String.contains("._-", Char.show(Chr{c}))

def valid_go(s: String, fuel: Nat, nonempty: Bool) -> Bool:
  match s fuel:
    case SNil{} _: nonempty
    case SCon{Chr{c}, t} 0n: False{}
    case SCon{Chr{c}, t} 1n+p: safe_char(c) && valid_go(t, p, True{})

