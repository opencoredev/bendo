# Octet helpers shared by the pure hashes. Callers supply values <= 255.
import Base

def rotr(+x: U32, +n: Nat) -> U32:
  U32.or(U32.shrn(x, n), U32.shln(x, Nat.sub(32n, n)))

def rotl(+x: U32, +n: Nat) -> U32:
  U32.or(U32.shln(x, n), U32.shrn(x, Nat.sub(32n, n)))

def word(a: U32, b: U32, c: U32, d: U32) -> U32:
  U32.or(U32.shln(a, 24n), U32.or(U32.shln(b, 16n), U32.or(U32.shln(c, 8n), d)))

def bytes(+x: U32) -> List<&2, U32>:
  [U32.shrn(x, 24n), U32.and(U32.shrn(x, 16n), 255), U32.and(U32.shrn(x, 8n), 255), U32.and(x, 255)]

def zeros(n: Nat, acc: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      acc
    case 1n+p:
      zeros(p, 0 <> acc)

# hi/lo count bits modulo 2^64, as required by FIPS 180-4 padding.
def pad_go(xs: List<&2, U32>, rev: List<&2, U32>, +hi: U32, +lo: U32, +rem: U32) -> List<&2, U32>:
  match xs:
    case Nil{}:
      suffix = List.append(&2, U32, bytes(hi), bytes(lo))
      tail = {128 <> zeros(U32.to_nat(U32.and(U32.sub(119, rem), 63)), suffix) : List<&2, U32>}
      List.reverse.go(&2, U32, rev, tail)
    case x <> t:
      pad_go(t, x <> rev, U32.add(hi, Bool.to_u32(U32.is_gt(lo, 4294967287))), U32.add(lo, 8), U32.and(U32.inc(rem), 63))

def pad(xs: List<&2, U32>) -> List<&2, U32>:
  pad_go(xs, [], 0, 0, 0)
