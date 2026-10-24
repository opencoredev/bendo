# Independent statements of RFC 6455 framing facts, for the BND-51 laws. Each
# def restates the RFC directly and does not call the codec's helpers.
import Base
import ../src/ws/frame.bend as F

# Section 5.3: octet i of the payload is XORed with key octet i mod 4. Rotating
# the key by one position per octet is the same rule.
def mask(xs: List<&2, U32>, k: F.Key) -> List<&2, U32>:
  match xs:
    case Nil{}:
      []
    case x <> t:
      match k:
        case F.MaskKey{+a, b, c, d}:
          U32.xor(x, a) <> mask(t, F.MaskKey{b, c, d, a})

def octets(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case +x <> t:
      (x <= 255 : U32) && octets(t)

def key_valid(k: Maybe<&2, F.Key>) -> Bool:
  match k:
    case None{}:
      True{}
    case Some{F.MaskKey{+a, +b, +c, +d}}:
      (a <= 255 : U32) && (b <= 255 : U32) && (c <= 255 : U32) && (d <= 255 : U32)

# Section 5.5: control frames are opcodes 8, 9 and 10, are never fragmented
# and carry at most 125 payload bytes.
def control_valid(op: F.Opcode, fin: Bool, +n: Nat) -> Bool:
  match op:
    case F.OpContinue{}:
      True{}
    case F.OpText{}:
      True{}
    case F.OpBinary{}:
      True{}
    case F.OpClose{}:
      fin && Nat.is_le(n, 125n)
    case F.OpPing{}:
      fin && Nat.is_le(n, 125n)
    case F.OpPong{}:
      fin && Nat.is_le(n, 125n)

# A frame this endpoint may send, given its payload cap `max`: octet payload
# and key, RFC control-frame rules, and a payload that fits `max`.
def valid(max: U32, f: F.Frame, k: Maybe<&2, F.Key>) -> Bool:
  match f:
    case F.Frame{fin, op, +payload}:
      +n = List.length(&2, U32, payload)
      control_valid(op, fin, n) && Nat.is_le(n, U32.to_nat(max)) && key_valid(k) && octets(payload)

# Section 5.2: the payload length uses the minimal number of bytes. Lengths up
# to 125 fit the 7-bit field, up to 65535 need 2 more bytes, otherwise 8.
def extra_of(short: Bool, medium: Bool) -> Nat:
  match short:
    case True{}:
      0n
    case False{}:
      match medium:
        case True{}:
          2n
        case False{}:
          8n

# The 125 threshold is compared on Nat. The 65535 threshold is compared on the
# length converted to U32, because Bend 2.0.38's checker overflows expanding a
# Nat that large. Under a U32 cap the conversion is exact, and the law
# ws_length_threshold_exact proves this comparison equals
# Nat.is_le(n, U32.to_nat(65535)).
def extra(+n: Nat) -> Nat:
  extra_of(Nat.is_le(n, 125n), U32.is_le(U32.from_nat(n), 65535))

def key_size(masked: Bool) -> Nat:
  match masked:
    case False{}:
      0n
    case True{}:
      4n

# Two fixed header bytes, the extended length, the key and the payload.
def wire_size(+n: Nat, masked: Bool) -> Nat:
  Nat.add(2n, Nat.add(extra(n), Nat.add(key_size(masked), n)))
