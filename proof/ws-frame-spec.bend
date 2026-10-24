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

# Section 5.1: a client masks every frame it sends and a server masks none, so
# a server accepts only masked frames and a client only unmasked ones.
def peer_key(role: F.Role, k: Maybe<&2, F.Key>) -> Bool:
  match role:
    case F.Server{}:
      match k:
        case None{}:
          False{}
        case Some{_}:
          True{}
    case F.Client{}:
      match k:
        case None{}:
          True{}
        case Some{_}:
          False{}

# Section 5.2 header bytes. The opcode values are those of section 11.8.
def opcode_value(op: F.Opcode) -> U32:
  match op:
    case F.OpContinue{}:
      0
    case F.OpText{}:
      1
    case F.OpBinary{}:
      2
    case F.OpClose{}:
      8
    case F.OpPing{}:
      9
    case F.OpPong{}:
      10

def has_key(k: Maybe<&2, F.Key>) -> Bool:
  match k:
    case None{}:
      False{}
    case Some{_}:
      True{}

def key_bytes(k: Maybe<&2, F.Key>) -> List<&2, U32>:
  match k:
    case None{}:
      []
    case Some{F.MaskKey{a, b, c, d}}:
      [a, b, c, d]

# Byte 1 is MASK << 7 | len7. A length up to 125 is len7 itself; up to 65535,
# len7 is 126 and two big-endian bytes follow; otherwise len7 is 127 and eight
# big-endian bytes follow. `u` is the length; under a U32 cap it is exact
# (ws_length_exact), so the top four of the eight bytes are zero.
def length_field(+mask: U32, +u: U32, short: Bool, medium: Bool) -> List<&2, U32>:
  match short:
    case True{}:
      [U32.or(mask, u)]
    case False{}:
      match medium:
        case True{}:
          [U32.or(mask, 126), U32.and(255, U32.shrn(u, 8n)), U32.and(255, u)]
        case False{}:
          [U32.or(mask, 127), 0, 0, 0, 0, U32.and(255, U32.shrn(u, 24n)), U32.and(255, U32.shrn(u, 16n)), U32.and(255, U32.shrn(u, 8n)), U32.and(255, u)]

# Byte 0 is FIN << 7 | opcode with the RSV bits clear; then byte 1 and the
# extended length; then the masking key, if any. The 65535 threshold is
# compared on U32 for the reason given at `extra`.
def header(fin: Bool, op: F.Opcode, +n: Nat, +k: Maybe<&2, F.Key>) -> List<&2, U32>:
  U32.or(U32.shln(Bool.to_u32(fin), 7n), opcode_value(op)) <> List.append(&2, U32, length_field(U32.shln(Bool.to_u32(has_key(k)), 7n), U32.from_nat(n), Nat.is_le(n, 125n), U32.is_le(U32.from_nat(n), 65535)), key_bytes(k))

# Section 5.3: the payload follows the header, masked when there is a key.
def payload_bytes(payload: List<&2, U32>, k: Maybe<&2, F.Key>) -> List<&2, U32>:
  match k:
    case None{}:
      payload
    case Some{key}:
      mask(payload, key)
