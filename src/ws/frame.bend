# RFC 6455 frame codec. Pure: no IO, no extensions (every RSV bit must be 0).
# Bytes are List<&2, U32> entries; every byte the decoder consumes must be an
# octet. Lengths travel as U32 words split into bits, so the codec's inverse
# rests on word structure rather than on shift and mask arithmetic.
import Base
import ../data/utf8.bend as Utf8

type Opcode is Data:
  OpContinue{}
  OpText{}
  OpBinary{}
  OpClose{}
  OpPing{}
  OpPong{}

# The four masking key octets, in wire order.
type Key is Data:
  MaskKey{a: U32, b: U32, c: U32, d: U32}

type Frame is Data:
  Frame{fin: Bool, opcode: Opcode, payload: List<&2, U32>}

# The decoding endpoint. A server reads masked client frames; a client reads
# unmasked server frames.
type Role is Data:
  Server{}
  Client{}

# `max` caps one frame's payload in bytes. It is a U32, so no accepted frame
# exceeds 4294967295 bytes.
type Config is Data:
  Config{role: Role, max: U32}

# Partial payload progress, kept by `resume` so a slow peer costs linear work.
# `rot` is the key rotated to the next byte's position; `ok` is False once a
# non-octet byte was read.
type Body is Data:
  Body{fin: Bool, opcode: Opcode, key: Maybe<&2, Key>, rot: Key, left: Nat, acc: List<&2, U32>, ok: Bool}

# `NeedMore{n}`: at least n more bytes are needed. `Partial` holds a frame whose
# header was read and accepted. `Reject{code}` carries the close code to send.
type Decoded is Data:
  NeedMore{need: Nat}
  Partial{body: Body}
  Got{frame: Frame, key: Maybe<&2, Key>, rest: List<&2, U32>}
  Reject{code: U32}

def protocol_error() -> U32:
  1002

def too_big() -> U32:
  1009

def is_control(op: Opcode) -> Bool:
  match op:
    case OpContinue{}:
      False{}
    case OpText{}:
      False{}
    case OpBinary{}:
      False{}
    case OpClose{}:
      True{}
    case OpPing{}:
      True{}
    case OpPong{}:
      True{}

def is_octet(+x: U32) -> Bool:
  (x <= 255 : U32)

def octets(xs: List<&2, U32>, ok: Bool) -> Bool:
  match xs:
    case Nil{}:
      ok
    case +x <> t:
      octets(t, ok && is_octet(x))

def key_octets(k: Key) -> Bool:
  match k:
    case MaskKey{+a, +b, +c, +d}:
      is_octet(a) && is_octet(b) && is_octet(c) && is_octet(d)

def count(xs: List<&2, U32>, n: Nat) -> Nat:
  match xs:
    case Nil{}:
      n
    case _ <> t:
      count(t, 1n+n)

def length(xs: List<&2, U32>) -> Nat:
  count(xs, 0n)

# Masking. Byte i is XORed with key octet i mod 4. The loop rotates the key
# instead of indexing it, and accumulates in reverse so JavaScript loops.

def mask_go(xs: List<&2, U32>, a: U32, b: U32, c: U32, +d: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      +a = a
      mask_go(t, b, c, d, a, U32.xor(x, a) <> acc)

def mask(k: Key, xs: List<&2, U32>) -> List<&2, U32>:
  match k:
    case MaskKey{a, b, c, d}:
      List.reverse(&2, U32, mask_go(xs, a, b, c, d, []))

# Octets as little-endian bit words.

def octet(w: Word(8n)) -> U32:
  U32{Utf8.join(8n, 24n, w, Word.zero(24n))}

def c125() -> Word(7n):
  WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}

def c126() -> Word(7n):
  WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}

def c127() -> Word(7n):
  WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}

# A 7-bit length field below 126 is the length itself.
def short7(x: Word(7n)) -> Bool:
  Cmp.is_le(Word.cmp(7n, x, c125()))

def opcode_bits(op: Opcode) -> Word(4n):
  match op:
    case OpContinue{}:
      WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}
    case OpText{}:
      WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}
    case OpBinary{}:
      WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}
    case OpClose{}:
      WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}
    case OpPing{}:
      WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}
    case OpPong{}:
      WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}

def first_byte(fin: Bool, op: Opcode) -> U32:
  octet(Utf8.join(4n, 4n, opcode_bits(op), WCon{False{}, WCon{False{}, WCon{False{}, WCon{fin, WNil{}}}}}))

def second_byte(len7: Word(7n), masked: Bool) -> U32:
  octet(Utf8.join(7n, 1n, len7, WCon{masked, WNil{}}))

def byte0(+w: Word(32n)) -> U32:
  octet(Utf8.low(8n, 24n, w))

def byte1(+w: Word(32n)) -> U32:
  octet(Utf8.low(8n, 16n, Utf8.high(8n, 24n, w)))

def byte2(+w: Word(32n)) -> U32:
  octet(Utf8.low(8n, 8n, Utf8.high(8n, 16n, Utf8.high(8n, 24n, w))))

def byte3(+w: Word(32n)) -> U32:
  octet(Utf8.high(8n, 8n, Utf8.high(8n, 16n, Utf8.high(8n, 24n, w))))

# The length header with the shortest form that holds the length: 7 bits up
# to 125, then 16 bits up to 65535, then 64 bits with the top 32 zero.
def length_bytes(masked: Bool, +w: Word(32n), short: Bool, medium: Bool) -> List<&2, U32>:
  match short:
    case True{}:
      [second_byte(Utf8.low(7n, 25n, w), masked)]
    case False{}:
      match medium:
        case True{}:
          [second_byte(c126(), masked), byte1(w), byte0(w)]
        case False{}:
          [second_byte(c127(), masked), 0, 0, 0, 0, byte3(w), byte2(w), byte1(w), byte0(w)]

def is_masked(k: Maybe<&2, Key>) -> Bool:
  match k:
    case None{}:
      False{}
    case Some{_}:
      True{}

def body_bytes(k: Maybe<&2, Key>, payload: List<&2, U32>) -> List<&2, U32>:
  match k:
    case None{}:
      payload
    case Some{MaskKey{+a, +b, +c, +d}}:
      a <> b <> c <> d <> mask(MaskKey{a, b, c, d}, payload)

def header_with(+k: Maybe<&2, Key>, n: U32) -> List<&2, U32>:
  match n:
    case U32{+w}:
      length_bytes(is_masked(k), w, U32.is_le(U32{w}, 125), U32.is_le(U32{w}, 65535))

# The raw encoder. It is total; `encode` below only runs it on valid input.
# A payload longer than 4294967295 bytes would wrap its length.
def encode_raw(f: Frame, +k: Maybe<&2, Key>) -> List<&2, U32>:
  match f:
    case Frame{fin, +op, +payload}:
      first_byte(fin, op) <> List.append(&2, U32, header_with(k, U32.from_nat(length(payload))), body_bytes(k, payload))

def key_ok(k: Maybe<&2, Key>) -> Bool:
  match k:
    case None{}:
      True{}
    case Some{key}:
      key_octets(key)

def control_ok(control: Bool, fin: Bool, n: Nat) -> Bool:
  match control:
    case False{}:
      True{}
    case True{}:
      fin && Nat.is_le(n, 125n)

# RFC 6455 validity for a frame this codec may send: octet payload and key, a
# control frame is final with at most 125 bytes, and the payload fits `max`.
def valid(max: U32, f: Frame, k: Maybe<&2, Key>) -> Bool:
  match f:
    case Frame{fin, +op, +payload}:
      +n = length(payload)
      control_ok(is_control(op), fin, n) && Nat.is_le(n, U32.to_nat(max)) && key_ok(k) && octets(payload, True{})

def encode_if(ok: Bool, f: Frame, k: Maybe<&2, Key>) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}:
      Some{encode_raw(f, k)}
    case False{}:
      None{}

# A server passes None (servers never mask); a client passes Some{key} with a
# fresh random key per frame.
def encode(max: U32, +f: Frame, +k: Maybe<&2, Key>) -> Maybe<&2, List<&2, U32>>:
  encode_if(valid(max, f, k), f, k)

# Decoding.

type Taken is Data:
  Took{ok: Bool, acc: List<&2, U32>, rest: List<&2, U32>}
  Short{ok: Bool, rot: Key, left: Nat, acc: List<&2, U32>}

# Unmask n bytes into a reversed accumulator.
def take_mask(n: Nat, xs: List<&2, U32>, a: U32, b: U32, c: U32, +d: U32, acc: List<&2, U32>, ok: Bool) -> Taken:
  match n:
    case 0n:
      Took{ok, acc, xs}
    case 1n+p:
      match xs:
        case Nil{}:
          Short{ok, MaskKey{a, b, c, d}, 1n+p, acc}
        case +x <> t:
          +a = a
          take_mask(p, t, b, c, d, a, U32.xor(x, a) <> acc, ok && is_octet(x))

def take_plain(n: Nat, xs: List<&2, U32>, acc: List<&2, U32>, ok: Bool) -> Taken:
  match n:
    case 0n:
      Took{ok, acc, xs}
    case 1n+p:
      match xs:
        case Nil{}:
          Short{ok, MaskKey{0, 0, 0, 0}, 1n+p, acc}
        case +x <> t:
          take_plain(p, t, x <> acc, ok && is_octet(x))

def finish_ok(ok: Bool, fin: Bool, op: Opcode, key: Maybe<&2, Key>, acc: List<&2, U32>, rest: List<&2, U32>) -> Decoded:
  match ok:
    case True{}:
      Got{Frame{fin, op, List.reverse(&2, U32, acc)}, key, rest}
    case False{}:
      Reject{protocol_error()}

def finish(+fin: Bool, +op: Opcode, +key: Maybe<&2, Key>, t: Taken) -> Decoded:
  match t:
    case Took{ok, acc, rest}:
      finish_ok(ok, fin, op, key, acc, rest)
    case Short{ok, rot, left, acc}:
      Partial{Body{fin, op, key, rot, left, acc, ok}}

def take_with(+key: Maybe<&2, Key>, n: Nat, xs: List<&2, U32>, acc: List<&2, U32>, ok: Bool) -> Taken:
  match key:
    case None{}:
      take_plain(n, xs, acc, ok)
    case Some{MaskKey{a, b, c, d}}:
      take_mask(n, xs, a, b, c, d, acc, ok)

def take_rot(+key: Maybe<&2, Key>, rot: Key, n: Nat, xs: List<&2, U32>, acc: List<&2, U32>, ok: Bool) -> Taken:
  match key:
    case None{}:
      take_plain(n, xs, acc, ok)
    case Some{_}:
      match rot:
        case MaskKey{a, b, c, d}:
          take_mask(n, xs, a, b, c, d, acc, ok)

def body(fin: Bool, op: Opcode, +key: Maybe<&2, Key>, n: U32, xs: List<&2, U32>) -> Decoded:
  finish(fin, op, key, take_with(key, U32.to_nat(n), xs, [], True{}))

def key_octet(+x: U32, ok: Bool) -> Bool:
  ok && is_octet(x)

def with_key(+a: U32, +b: U32, +c: U32, +d: U32, fin: Bool, op: Opcode, n: U32, xs: List<&2, U32>, ok: Bool) -> Decoded:
  match ok:
    case True{}:
      body(fin, op, Some{MaskKey{a, b, c, d}}, n, xs)
    case False{}:
      Reject{protocol_error()}

def read_key(masked: Bool, fin: Bool, op: Opcode, n: U32, xs: List<&2, U32>) -> Decoded:
  match masked:
    case False{}:
      body(fin, op, None{}, n, xs)
    case True{}:
      match xs:
        case Nil{}:
          NeedMore{4n}
        case +a <> Nil{}:
          NeedMore{3n}
        case +a <> +b <> Nil{}:
          NeedMore{2n}
        case +a <> +b <> +c <> Nil{}:
          NeedMore{1n}
        case +a <> +b <> +c <> +d <> t:
          with_key(a, b, c, d, fin, op, n, t, key_octet(d, key_octet(c, key_octet(b, key_octet(a, True{})))))

def sized(fits: Bool, masked: Bool, fin: Bool, op: Opcode, n: U32, xs: List<&2, U32>) -> Decoded:
  match fits:
    case True{}:
      read_key(masked, fin, op, n, xs)
    case False{}:
      Reject{too_big()}

def length_known(+max: U32, masked: Bool, fin: Bool, op: Opcode, +n: U32, xs: List<&2, U32>) -> Decoded:
  sized(U32.is_le(n, max), masked, fin, op, n, xs)

# Reject a length written in a longer form than it needs.
def minimal(ok: Bool, max: U32, masked: Bool, fin: Bool, op: Opcode, n: U32, xs: List<&2, U32>) -> Decoded:
  match ok:
    case True{}:
      length_known(max, masked, fin, op, n, xs)
    case False{}:
      Reject{protocol_error()}

def bits(b: U32) -> Word(8n):
  match b:
    case U32{w}:
      Utf8.low(8n, 24n, w)

def byte_ok(b: U32, ok: Bool) -> Bool:
  match b:
    case U32{+w}:
      ok && Utf8.zero(24n, Utf8.high(8n, 24n, w))

def is_zero_byte(+b: U32, ok: Bool) -> Bool:
  ok && U32.is_eq(b, 0)

def join16(+hi: U32, +lo: U32) -> U32:
  U32{Utf8.join(8n, 24n, bits(lo), Utf8.join(8n, 16n, bits(hi), Word.zero(16n)))}

def join32(+b3: U32, +b2: U32, +b1: U32, +b0: U32) -> U32:
  U32{Utf8.join(8n, 24n, bits(b0), Utf8.join(8n, 16n, bits(b1), Utf8.join(8n, 8n, bits(b2), bits(b3))))}

def octets_then(octs: Bool, ok: Bool, max: U32, masked: Bool, fin: Bool, op: Opcode, n: U32, xs: List<&2, U32>) -> Decoded:
  match octs:
    case True{}:
      minimal(ok, max, masked, fin, op, n, xs)
    case False{}:
      Reject{protocol_error()}

def ext16(+max: U32, masked: Bool, fin: Bool, op: Opcode, xs: List<&2, U32>) -> Decoded:
  match xs:
    case Nil{}:
      NeedMore{2n}
    case +hi <> Nil{}:
      NeedMore{1n}
    case +hi <> +lo <> t:
      +n = join16(hi, lo)
      octets_then(byte_ok(lo, byte_ok(hi, True{})), Bool.not(U32.is_le(n, 125)), max, masked, fin, op, n, t)

# The 64-bit form: bit 63 set is a protocol error; any other bit in the top 32
# exceeds every U32 maximum.
def upper(top: Bool, zeros: Bool, max: U32, masked: Bool, fin: Bool, op: Opcode, +b3: U32, +b2: U32, +b1: U32, +b0: U32, xs: List<&2, U32>) -> Decoded:
  match top:
    case True{}:
      Reject{protocol_error()}
    case False{}:
      match zeros:
        case False{}:
          Reject{too_big()}
        case True{}:
          +n = join32(b3, b2, b1, b0)
          octets_then(byte_ok(b0, byte_ok(b1, byte_ok(b2, byte_ok(b3, True{})))), Bool.not(U32.is_le(n, 65535)), max, masked, fin, op, n, xs)

def ext64(+max: U32, masked: Bool, fin: Bool, op: Opcode, xs: List<&2, U32>) -> Decoded:
  match xs:
    case +u3 <> +u2 <> +u1 <> +u0 <> +b3 <> +b2 <> +b1 <> +b0 <> t:
      # Bytes above 255 count as too large here and are refused either way.
      upper((u3 >= 128 : U32), is_zero_byte(u0, is_zero_byte(u1, is_zero_byte(u2, is_zero_byte(u3, True{})))), max, masked, fin, op, b3, b2, b1, b0, t)
    case Nil{}:
      NeedMore{8n}
    case _ <> Nil{}:
      NeedMore{7n}
    case _ <> _ <> Nil{}:
      NeedMore{6n}
    case _ <> _ <> _ <> Nil{}:
      NeedMore{5n}
    case _ <> _ <> _ <> _ <> Nil{}:
      NeedMore{4n}
    case _ <> _ <> _ <> _ <> _ <> Nil{}:
      NeedMore{3n}
    case _ <> _ <> _ <> _ <> _ <> _ <> Nil{}:
      NeedMore{2n}
    case _ <> _ <> _ <> _ <> _ <> _ <> _ <> Nil{}:
      NeedMore{1n}

# Lengths 126 and 127 announce the 16- and 64-bit forms; a control frame may
# not use either.
def extended(control: Bool, wide: Bool, max: U32, masked: Bool, fin: Bool, op: Opcode, xs: List<&2, U32>) -> Decoded:
  match control:
    case True{}:
      Reject{protocol_error()}
    case False{}:
      match wide:
        case False{}:
          ext16(max, masked, fin, op, xs)
        case True{}:
          ext64(max, masked, fin, op, xs)

def length7(short: Bool, +len7: Word(7n), max: U32, masked: Bool, fin: Bool, +op: Opcode, xs: List<&2, U32>) -> Decoded:
  match short:
    case True{}:
      length_known(max, masked, fin, op, U32{Utf8.join(7n, 25n, len7, Word.zero(25n))}, xs)
    case False{}:
      match len7:
        case WCon{wide, _}:
          extended(is_control(op), wide, max, masked, fin, op, xs)

def role_mask(role: Role, masked: Bool) -> Bool:
  match role:
    case Server{}:
      masked
    case Client{}:
      Bool.not(masked)

def masked_ok(ok: Bool, short: Bool, len7: Word(7n), max: U32, masked: Bool, fin: Bool, op: Opcode, xs: List<&2, U32>) -> Decoded:
  match ok:
    case False{}:
      Reject{protocol_error()}
    case True{}:
      length7(short, len7, max, masked, fin, op, xs)

def second(ok: Bool, w: Word(8n), +role: Role, max: U32, fin: Bool, op: Opcode, xs: List<&2, U32>) -> Decoded:
  match ok:
    case False{}:
      Reject{protocol_error()}
    case True{}:
      match w:
        case WCon{+l0, WCon{+l1, WCon{+l2, WCon{+l3, WCon{+l4, WCon{+l5, WCon{+l6, WCon{+m, WNil{}}}}}}}}}:
          +len7 = {WCon{l0, WCon{l1, WCon{l2, WCon{l3, WCon{l4, WCon{l5, WCon{l6, WNil{}}}}}}}} : Word(7n)}
          masked_ok(role_mask(role, m), short7(len7), len7, max, m, fin, op, xs)

def read_second(+role: Role, +max: U32, +fin: Bool, +op: Opcode, xs: List<&2, U32>) -> Decoded:
  match xs:
    case Nil{}:
      NeedMore{1n}
    case +b <> t:
      second(byte_ok(b, True{}), bits(b), role, max, fin, op, t)

def fragmented_control(control: Bool, fin: Bool) -> Bool:
  match control:
    case False{}:
      False{}
    case True{}:
      Bool.not(fin)

def control_fin(bad: Bool, op: Opcode, fin: Bool, role: Role, max: U32, xs: List<&2, U32>) -> Decoded:
  match bad:
    case True{}:
      Reject{protocol_error()}
    case False{}:
      read_second(role, max, fin, op, xs)

def with_opcode(op: Maybe<&2, Opcode>, +fin: Bool, role: Role, max: U32, xs: List<&2, U32>) -> Decoded:
  match op:
    case None{}:
      Reject{protocol_error()}
    case Some{+o}:
      control_fin(fragmented_control(is_control(o), fin), o, fin, role, max, xs)

# Opcode bits, least significant first.
def opcode_of(o0: Bool, o1: Bool, o2: Bool, o3: Bool) -> Maybe<&2, Opcode>:
  match o0 o1 o2 o3:
    case False{} False{} False{} False{}:
      Some{OpContinue{}}
    case True{} False{} False{} False{}:
      Some{OpText{}}
    case False{} True{} False{} False{}:
      Some{OpBinary{}}
    case False{} False{} False{} True{}:
      Some{OpClose{}}
    case True{} False{} False{} True{}:
      Some{OpPing{}}
    case False{} True{} False{} True{}:
      Some{OpPong{}}
    case _ _ _ _:
      None{}

def rsv_clear(r1: Bool, r2: Bool, r3: Bool) -> Bool:
  Bool.not(r1) && Bool.not(r2) && Bool.not(r3)

def reserved(clear: Bool, op: Maybe<&2, Opcode>, fin: Bool, role: Role, max: U32, xs: List<&2, U32>) -> Decoded:
  match clear:
    case False{}:
      Reject{protocol_error()}
    case True{}:
      with_opcode(op, fin, role, max, xs)

def first(ok: Bool, w: Word(8n), role: Role, max: U32, xs: List<&2, U32>) -> Decoded:
  match ok:
    case False{}:
      Reject{protocol_error()}
    case True{}:
      match w:
        case WCon{o0, WCon{o1, WCon{o2, WCon{o3, WCon{r1, WCon{r2, WCon{r3, WCon{fin, WNil{}}}}}}}}}:
          reserved(rsv_clear(r1, r2, r3), opcode_of(o0, o1, o2, o3), fin, role, max, xs)

# Decode one frame from the front of a buffer. Bytes after the frame come back
# as `rest`. Payload progress is returned as `Partial`, which `resume` continues
# with the next bytes; the header itself is at most 14 bytes, so retrying an
# incomplete header from the buffer stays cheap.
def start(cfg: Config, xs: List<&2, U32>) -> Decoded:
  match cfg:
    case Config{role, max}:
      match xs:
        case Nil{}:
          NeedMore{2n}
        case +b <> t:
          first(byte_ok(b, True{}), bits(b), role, max, t)

# Precondition: `b` came from `start` or `resume` with the same Config.
def resume(b: Body, xs: List<&2, U32>) -> Decoded:
  match b:
    case Body{+fin, +op, +key, rot, left, acc, ok}:
      finish(fin, op, key, take_rot(key, rot, left, xs, acc, ok))

def settle(d: Decoded) -> Decoded:
  match d:
    case NeedMore{n}:
      NeedMore{n}
    case Partial{Body{_, _, _, _, left, _, _}}:
      NeedMore{left}
    case Got{f, k, rest}:
      Got{f, k, rest}
    case Reject{c}:
      Reject{c}

# The whole-buffer view used by the laws: a frame still waiting for payload
# bytes needs at least `left` more.
def decode(cfg: Config, xs: List<&2, U32>) -> Decoded:
  settle(start(cfg, xs))
