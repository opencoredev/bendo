import Base
import ./sha256.bend as SHA256

# Normalize to one 64-byte block; the bounded length check is stack safe.
def long_key(xs: List<&2, U32>, n: Nat) -> Bool:
  match xs n:
    case Nil{} _:
      False{}
    case _ 0n:
      True{}
    case h <> t 1n+p:
      long_key(t, p)

def key(xs: List<&2, U32>, long: Bool) -> List<&2, U32>:
  match long:
    case True{}:
      SHA256.hash(xs)
    case False{}:
      xs

# Only 64 frames, independent of message/key length.
def pad(n: Nat, xs: List<&2, U32>, +mask: U32, tail: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      tail
    case 1n+p:
      match xs:
        case Nil{}:
          mask <> pad(p, [], mask, tail)
        case x <> t:
          U32.xor(x, mask) <> pad(p, t, mask, tail)

# RFC 2104 / RFC 4231, full 32-octet tag. Truncation is caller policy.
def sha256(+secret: List<&2, U32>, message: List<&2, U32>) -> List<&2, U32>:
  +k = key(secret, long_key(secret, 64n))
  SHA256.hash(pad(64n, k, 92, SHA256.hash(pad(64n, k, 54, message))))
