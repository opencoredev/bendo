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

# The encoder sends exactly the valid frames, as encode_raw writes them, and
# refuses every other frame.
law ws_encode_accepts:
  for +max: U32
  for +f: F.Frame
  for +k: Maybe<&2, F.Key>
  for +ok: {S.valid(max, f, k) == True{} : Bool}
  {F.encode(max, f, k) == Some{F.encode_raw(f, k)} : Maybe<&2, List<&2, U32>>}

law ws_encode_refuses:
  for +max: U32
  for +f: F.Frame
  for +k: Maybe<&2, F.Key>
  for +bad: {S.valid(max, f, k) == False{} : Bool}
  {F.encode(max, f, k) == None{} : Maybe<&2, List<&2, U32>>}

# The bytes of every encoding under a U32 cap, written out from RFC 6455
# section 5.2: FIN and opcode, MASK and the 7-bit length, the shortest
# big-endian extended length, the key, then the payload, masked when keyed.
law ws_encode_bytes:
  for +max: U32
  for +fin: Bool
  for +op: F.Opcode
  for +payload: List<&2, U32>
  for +k: Maybe<&2, F.Key>
  for +fits: {Nat.is_le(List.length(&2, U32, payload), U32.to_nat(max)) == True{} : Bool}
  {F.encode_raw(F.Frame{fin, op, payload}, k) == List.append(&2, U32, S.header(fin, op, List.length(&2, U32, payload), k), S.payload_bytes(payload, k)) : List<&2, U32>}

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

# Whatever the decoder accepts, from any bytes, re-encodes to exactly the bytes
# it consumed: no byte is reinterpreted, so non-minimal lengths, reserved bits
# and the like cannot pass.
law ws_decode_sound:
  for +cfg: F.Config
  for +xs: List<&2, U32>
  for +f: F.Frame
  for +k: Maybe<&2, F.Key>
  for +rest: List<&2, U32>
  for +e: {F.decode(cfg, xs) == F.Got{f, k, rest} : F.Decoded}
  {List.append(&2, U32, F.encode_raw(f, k), rest) == xs : List<&2, U32>}

# Every accepted frame is one the RFC lets the peer send under the receiver's
# cap, masked exactly when the peer is a client (section 5.1).
law ws_decode_valid:
  for +role: F.Role
  for +max: U32
  for +xs: List<&2, U32>
  for +f: F.Frame
  for +k: Maybe<&2, F.Key>
  for +rest: List<&2, U32>
  for +e: {F.decode(F.Config{role, max}, xs) == F.Got{f, k, rest} : F.Decoded}
  {S.valid(max, f, k) && S.peer_key(role, k) == True{} : Bool}

# BND-95: decoding as bytes arrive gives the same result as decoding them all
# at once. From any decoder state (no frame yet, or any frame in progress) and
# for every way the input is split into chunks, the connection's read loop
# ends with exactly the result of one decode of the buffered bytes followed by
# every chunk: the same frame, key and remaining bytes, the same rejection
# code, or the same progress (including the mask position) or shortfall.
law ws_decode_incremental:
  for +cfg: F.Config
  for +body: Maybe<&2, F.Body>
  for +pending: List<&2, U32>
  for +chunks: List<&2, List<&2, U32>>
  {F.feed(cfg, body, pending, chunks) == F.next(cfg, body, List.append(&2, U32, pending, List.concat(&2, U32, chunks))) : F.Decoded}

# So a fresh connection reading any split of a buffer reaches exactly what
# F.decode gives for the whole buffer, the decoder that ws_decode_sound and
# ws_decode_valid describe.
law ws_decode_chunks:
  for +cfg: F.Config
  for +chunks: List<&2, List<&2, U32>>
  {F.settle(F.feed(cfg, None{}, [], chunks)) == F.decode(cfg, List.concat(&2, U32, chunks)) : F.Decoded}
