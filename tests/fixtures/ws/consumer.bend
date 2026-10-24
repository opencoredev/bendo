import Base
import ../../../src/ws/frame.bend as F
import ../../../src/ws/message.bend as M

def encode(max: U32, f: F.Frame, k: Maybe<&2, F.Key>) -> Maybe<&2, List<&2, U32>>:
  F.encode(max, f, k)

def encode_raw(f: F.Frame, k: Maybe<&2, F.Key>) -> List<&2, U32>:
  F.encode_raw(f, k)

def decode(cfg: F.Config, xs: List<&2, U32>) -> F.Decoded:
  F.decode(cfg, xs)

def start(cfg: F.Config, xs: List<&2, U32>) -> F.Decoded:
  F.start(cfg, xs)

def resume(b: F.Body, xs: List<&2, U32>) -> F.Decoded:
  F.resume(b, xs)

def mask(k: F.Key, xs: List<&2, U32>) -> List<&2, U32>:
  F.mask(k, xs)

def step(max: U32, s: M.State, f: F.Frame) -> M.Advance:
  M.step(max, s, f)

def close_payload(code: U32, reason: String) -> List<&2, U32>:
  M.close_payload(code, reason)

def code_ok(code: U32) -> Bool:
  M.code_ok(code)
