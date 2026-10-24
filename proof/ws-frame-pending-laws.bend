# BND-51 claims that are stated but NOT PROVEN yet. LAWS.bend does not import
# this file, so `bun run prove` does not count them. The runtime fuzz tests in
# tests/ws-frame.test.ts check both on random and mutated input.
import Base
import ../src/ws/frame.bend as F
import ./ws-frame-spec.bend as S

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
# cap.
law ws_decode_valid:
  for +role: F.Role
  for +max: U32
  for +xs: List<&2, U32>
  for +f: F.Frame
  for +k: Maybe<&2, F.Key>
  for +rest: List<&2, U32>
  for +e: {F.decode(F.Config{role, max}, xs) == F.Got{f, k, rest} : F.Decoded}
  {S.valid(max, f, k) == True{} : Bool}
