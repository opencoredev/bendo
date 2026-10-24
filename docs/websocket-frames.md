# WebSocket frames and messages

Two pure modules implement RFC 6455 framing. `src/ws/frame.bend` encodes and
decodes single frames. `src/ws/message.bend` turns a sequence of decoded frames
into messages. Neither does IO: the [session connection layer](websocket-sessions.md)
reads bytes, calls these functions and writes what they return. The low-level
codec is imported directly from these modules.

Bytes are `List<&2, U32>`, one octet per entry. No extensions are negotiated,
so every frame with an RSV bit set is refused.

## Decode frames

```python
import Base
import ../src/ws/frame.bend as F

# A server reads masked client frames, here with a 1 MiB cap per frame.
def read(bytes: List<&2, U32>) -> F.Decoded:
  F.decode(F.Config{F.Server{}, 1048576}, bytes)
```

`F.decode(cfg, bytes)` reads one frame from the front of a buffer and answers:

| Result | Meaning |
| --- | --- |
| `Got{frame, key, rest}` | A complete frame. `key` is the masking key it carried (`None` for unmasked frames). `rest` is every byte after the frame, untouched. |
| `NeedMore{n}` | The buffer is a prefix of a frame; at least `n` more bytes are needed. |
| `Reject{code}` | The bytes can never form an acceptable frame. Send a close frame with `code`, then close the connection. |

`frame` is `Frame{fin, opcode, payload}` with the payload already unmasked.
Opcodes are `OpContinue`, `OpText`, `OpBinary`, `OpClose`, `OpPing` and
`OpPong`.

The decoder rejects with 1002 (protocol error):

- an RSV bit set, or an opcode other than 0, 1, 2, 8, 9 and 10;
- a fragmented control frame, or a control frame longer than 125 bytes;
- an unmasked frame read by a server, or a masked frame read by a client;
- a length written in a longer form than it needs (16 bits for a length up to
  125, 64 bits for a length up to 65535);
- a 64-bit length with its top bit set;
- any byte above 255 in the header, key or payload.

It rejects with 1009 (message too big) when the length exceeds `Config.max`,
or when any of the top 32 length bits is set. Both are decided as soon as the
length bytes arrive, before any payload is read.

### Read from a socket

`F.decode` re-reads the payload from the start each time it is called. A
connection should use the resumable pair instead:

- `F.start(cfg, buffer)` answers like `decode`, except that a frame whose header
  was accepted but whose payload is incomplete comes back as `Partial{body}`.
  Keep `body` and drop the buffer.
- `F.resume(body, bytes)` continues that payload with the next bytes and
  answers `Got`, `Partial` or `Reject`. Only pass it a `Body` that `start` or
  `resume` returned for the same `Config`.

While `start` answers `NeedMore`, append the next read to the buffer and call
`start` again. A header is at most 14 bytes, so this retry stays cheap, and the
payload costs linear work even when bytes arrive one at a time.

`F.next(cfg, body, bytes)` makes that choice: `start` without a body, `resume`
with one. `F.feed(cfg, body, pending, chunks)` runs the loop that decodes one
frame over a list of reads, and the law `ws_decode_incremental` proves it gives exactly what
`F.next` gives on `pending` followed by every chunk. However reads split the
input, the connection sees the same frame, key and remaining bytes, or the same
rejection, as `F.decode` on the whole buffer. After a frame the connection
resets the decoder and decodes the remaining bytes the same way, so the law
holds again for each frame; it is stated per frame, not for a whole session.

## Encode frames

`F.encode(max, frame, key)` answers `Some{bytes}` for a frame RFC 6455 lets an
endpoint send, and `None` otherwise. A frame is refused when a control frame is
fragmented or longer than 125 bytes, when the payload exceeds `max`, or when
the payload or key holds a value above 255.

A server passes `None` as the key. A client passes `Some{F.MaskKey{a, b, c, d}}`
with fresh random octets for every frame. The encoder always uses the shortest
length form.

## Assemble messages

`M.step(max, state, frame)` from `src/ws/message.bend` takes one decoded frame
and answers `Advance{state, event}`. Start from `Idle{}`. `max` caps a whole
message, summed over its fragments; pass the same value on every call.

| Event | Meaning |
| --- | --- |
| `Absorbed{}` | Nothing to deliver yet: a fragment was kept, or the frame was ignored after the end. |
| `Deliver{message}` | `TextMessage{text}`, `BinaryMessage{data}`, `PingMessage{data}`, `PongMessage{data}` or `CloseMessage{code, reason}`. |
| `Failed{code}` | Close the connection with `code`. |

Control frames may arrive between fragments and never disturb the message being
assembled. These are protocol errors (1002): a continuation with no message
open, a new text or binary frame while one is open, and a hand-built control
frame that is fragmented or too long.

Text is validated as UTF-8 when the final fragment arrives, and a message that
fails is never delivered (1007). This is the non-strict policy of the Autobahn
test suite: a sender of invalid text is closed at the end of its message rather
than at the first bad byte. A fragment is checked against the bytes left in the
message budget before it is kept, so an oversized message fails with 1009
without being stored.

After a close message or a failure the state is `Ended{}`, and every later frame
is ignored.

### Close payloads

A close payload is empty, or a two-byte big-endian code followed by UTF-8 text.
One byte, or a code outside the accepted ranges, is a protocol error (1002);
invalid UTF-8 in the reason is 1007. Accepted codes follow RFC 6455 section 7.4
and the IANA registry:

| Codes | Accepted |
| --- | --- |
| 1000 to 1003 | Yes |
| 1004 to 1006, 1015 | No: reserved, or never sent on the wire |
| 1007 to 1014 | Yes (1012 to 1014 are registered with IANA) |
| 1016 to 2999 | No: unassigned |
| 3000 to 4999 | Yes |
| everything else | No |

`M.close_payload(code, reason)` builds a payload to send. `F.encode` refuses
the frame when the reason makes it longer than 125 bytes.

## Laws

`proof/ws-frame-laws.bend` states what the codec guarantees, and
`bun run prove` checks every one:

- `ws_mask_spec` and `ws_mask_involution`: masking is the RFC's octet-by-octet
  XOR with key octet `i mod 4`, and masking twice restores any payload.
- `ws_encode_valid`, `ws_encode_accepts` and `ws_encode_refuses`: the codec's
  validity check is the independent RFC predicate `S.valid` in
  `proof/ws-frame-spec.bend`, and `F.encode` returns `Some` of the encoding for
  every frame that satisfies it and `None` for every other frame.
- `ws_encode_bytes`: every encoding under a U32 cap is, byte for byte, what
  `S.header` and `S.payload_bytes` write from section 5.2: FIN and opcode,
  MASK and the 7-bit length, the shortest big-endian extended length, the key,
  then the payload, masked when keyed.
- `ws_encode_minimal`, `ws_length_threshold_exact` and `ws_length_exact`: every
  encoding has the minimal size for its payload length.
- `ws_roundtrip_masked` and `ws_roundtrip_plain`: a server decodes every valid
  masked frame, and a client every valid unmasked frame, back to the same frame
  and key, followed by whatever bytes came after it.
- `ws_decode_sound`: whatever the decoder accepts, from any bytes, re-encodes
  to exactly the bytes it consumed, so non-minimal lengths, reserved bits and
  other alternative spellings never pass.
- `ws_decode_valid`: every accepted frame satisfies `S.valid` under the
  receiver's cap, and is masked exactly when the receiver is a server
  (`S.peer_key`).
