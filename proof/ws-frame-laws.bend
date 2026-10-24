import Base
import ../src/ws/frame.bend as F
import ./ws-frame-spec.bend as S

# BND-51: masking is the RFC 6455 section 5.3 rule, for every key and payload.
law ws_mask_spec:
  for +k: F.Key
  for +xs: List<&2, U32>
  {F.mask(k, xs) == S.mask(xs, k) : List<&2, U32>}

# Masking twice with the same key restores any payload.
law ws_mask_involution:
  for +k: F.Key
  for +xs: List<&2, U32>
  {F.mask(k, F.mask(k, xs)) == xs : List<&2, U32>}

# The encoder accepts exactly the frames that are well formed at the transport
# layer (RFC 6455 sections 5.2 to 5.5). Close payload contents are checked
# when a close frame is received, by M.step in src/ws/message.bend.
law ws_encode_valid:
  for +max: U32
  for +f: F.Frame
  for +k: Maybe<&2, F.Key>
  {F.valid(max, f, k) == S.valid(max, f, k) : Bool}

# Every encoding of a payload that fits a U32 cap uses the minimal length
# form: its size is the two fixed bytes, the shortest extended length for the
# payload, the key and the payload.
law ws_encode_minimal:
  for +max: U32
  for +fin: Bool
  for +op: F.Opcode
  for +payload: List<&2, U32>
  for +k: Maybe<&2, F.Key>
  for +fits: {Nat.is_le(List.length(&2, U32, payload), U32.to_nat(max)) == True{} : Bool}
  {List.length(&2, U32, F.encode_raw(F.Frame{fin, op, payload}, k)) == S.wire_size(List.length(&2, U32, payload), F.is_masked(k)) : Nat}

# Below any U32 cap, the spec's 16-bit threshold is the numeric one, and the
# conversion to U32 loses nothing.
law ws_length_threshold_exact:
  for +n: Nat
  for +max: U32
  for +fits: {Nat.is_le(n, U32.to_nat(max)) == True{} : Bool}
  {U32.is_le(U32.from_nat(n), 65535) == Nat.is_le(n, U32.to_nat(65535)) : Bool}

law ws_length_exact:
  for +n: Nat
  for +max: U32
  for +fits: {Nat.is_le(n, U32.to_nat(max)) == True{} : Bool}
  {U32.to_nat(U32.from_nat(n)) == n : Nat}

# A server decodes every valid masked client frame back to the frame
# and key, and hands back the bytes after it untouched.
law ws_roundtrip_masked:
  for +max: U32
  for +fin: Bool
  for +op: F.Opcode
  for +payload: List<&2, U32>
  for +key: F.Key
  for +rest: List<&2, U32>
  for +ok: {S.valid(max, F.Frame{fin, op, payload}, Some{key}) == True{} : Bool}
  {F.decode(F.Config{F.Server{}, max}, List.append(&2, U32, F.encode_raw(F.Frame{fin, op, payload}, Some{key}), rest)) == F.Got{F.Frame{fin, op, payload}, Some{key}, rest} : F.Decoded}

# A client does the same for every valid unmasked server frame.
law ws_roundtrip_plain:
  for +max: U32
  for +fin: Bool
  for +op: F.Opcode
  for +payload: List<&2, U32>
  for +rest: List<&2, U32>
  for +ok: {S.valid(max, F.Frame{fin, op, payload}, None{}) == True{} : Bool}
  {F.decode(F.Config{F.Client{}, max}, List.append(&2, U32, F.encode_raw(F.Frame{fin, op, payload}, None{}), rest)) == F.Got{F.Frame{fin, op, payload}, None{}, rest} : F.Decoded}
