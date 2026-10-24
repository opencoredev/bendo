import { describe, expect, test } from "bun:test";
import { SLOW_TEST_TIMEOUT_MS } from "./harness.ts";
import {
  type Body,
  type Decoded,
  type Frame,
  type Key,
  type Opcode,
  type Role,
  loadCodec,
} from "./ws-codec.ts";

const ws = await loadCodec();
const MAX = 0xffff_ffff;
const KEY: Key = [0x37, 0xfa, 0x21, 0x3d];
const HELLO = [0x48, 0x65, 0x6c, 0x6c, 0x6f];
const utf8 = (s: string): number[] => [...new TextEncoder().encode(s)];

/** Mulberry32: a seeded PRNG so fuzz failures replay. */
function rng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function bytes(n: number, seed = 1): number[] {
  const r = rng(seed);
  return Array.from({ length: n }, () => Math.floor(r() * 256));
}

function got(d: Decoded): Extract<Decoded, { kind: "got" }> {
  if (d.kind !== "got") throw new Error(`expected a frame, got ${JSON.stringify(d)}`);
  return d;
}

/** The RFC's server role reads masked frames; the client reads unmasked ones. */
const reader = (k: Key | null): Role => (k === null ? "Client" : "Server");

/** Feeds chunks the way a connection would: retry the header from a buffer, resume payloads. */
function feed(role: Role, max: number, chunks: readonly number[][]): Decoded {
  let buffer: number[] = [];
  let body: Body | null = null;
  let last: Decoded = { kind: "need", need: 2 };
  for (const chunk of chunks) {
    if (body === null) {
      buffer = buffer.concat(chunk);
      last = ws.start(role, max, buffer);
    } else {
      last = ws.resume(body, chunk);
    }
    switch (last.kind) {
      case "partial":
        body = last.body;
        buffer = [];
        break;
      case "need":
        break;
      case "got":
      case "reject":
        return last;
      default: {
        const _exhaustive: never = last;
        return _exhaustive;
      }
    }
  }
  return last;
}

describe("BND-51 RFC 6455 section 5.7 vectors", () => {
  test("single-frame unmasked text", () => {
    const wire = [0x81, 0x05, ...HELLO];
    expect(ws.encode(MAX, { fin: true, opcode: "OpText", payload: HELLO }, null)).toEqual(wire);
    expect(got(ws.decode("Client", MAX, wire))).toEqual({
      kind: "got",
      frame: { fin: true, opcode: "OpText", payload: HELLO },
      key: null,
      rest: [],
    });
  });

  test("single-frame masked text", () => {
    const wire = [0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58];
    expect(ws.encode(MAX, { fin: true, opcode: "OpText", payload: HELLO }, KEY)).toEqual(wire);
    expect(got(ws.decode("Server", MAX, wire)).frame.payload).toEqual(HELLO);
  });

  test("fragmented unmasked text", () => {
    const a = [0x01, 0x03, 0x48, 0x65, 0x6c];
    const b = [0x80, 0x02, 0x6c, 0x6f];
    const first = got(ws.decode("Client", MAX, [...a, ...b]));
    expect(first.frame).toEqual({ fin: false, opcode: "OpText", payload: [0x48, 0x65, 0x6c] });
    expect(first.rest).toEqual(b);
    const second = got(ws.decode("Client", MAX, first.rest));
    expect(second.frame).toEqual({ fin: true, opcode: "OpContinue", payload: [0x6c, 0x6f] });
    const m1 = ws.step(MAX, ws.idle, first.frame);
    expect(m1.outcome).toEqual({ kind: "absorbed" });
    expect(ws.step(MAX, m1.state, second.frame).outcome).toEqual({
      kind: "deliver",
      message: { kind: "text", text: "Hello" },
    });
  });

  test("unmasked ping and masked pong", () => {
    const ping = [0x89, 0x05, ...HELLO];
    const pong = [0x8a, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58];
    expect(ws.encode(MAX, { fin: true, opcode: "OpPing", payload: HELLO }, null)).toEqual(ping);
    expect(ws.encode(MAX, { fin: true, opcode: "OpPong", payload: HELLO }, KEY)).toEqual(pong);
    expect(got(ws.decode("Client", MAX, ping)).frame.opcode).toBe("OpPing");
    expect(got(ws.decode("Server", MAX, pong)).frame).toEqual({
      fin: true,
      opcode: "OpPong",
      payload: HELLO,
    });
  });

  test("256 bytes use the 16-bit length", () => {
    const payload = bytes(256);
    const wire = ws.encode(MAX, { fin: true, opcode: "OpBinary", payload }, null);
    expect(wire?.slice(0, 4)).toEqual([0x82, 0x7e, 0x01, 0x00]);
    expect(wire?.length).toBe(260);
  });

  test("64 KiB uses the 64-bit length", () => {
    const payload = bytes(65536);
    const wire = ws.encode(MAX, { fin: true, opcode: "OpBinary", payload }, null);
    expect(wire?.slice(0, 10)).toEqual([0x82, 0x7f, 0, 0, 0, 0, 0, 1, 0, 0]);
    expect(got(ws.decode("Client", MAX, wire ?? [])).frame.payload).toEqual(payload);
  });
});

describe("BND-51 roundtrip and length forms", () => {
  const edges = [0, 1, 125, 126, 127, 65535, 65536, 65537];
  for (const n of edges)
    for (const k of [null, KEY])
      test(`${n} bytes, ${k === null ? "unmasked" : "masked"}, with trailing bytes`, () => {
        const frame: Frame = { fin: true, opcode: "OpBinary", payload: bytes(n, n + 7) };
        const wire = ws.encode(MAX, frame, k);
        if (wire === null) throw new Error("valid frame refused");
        const header = 2 + (n <= 125 ? 0 : n <= 65535 ? 2 : 8) + (k === null ? 0 : 4);
        expect(wire.length).toBe(header + n);
        const rest = [0x81, 0x00, 0xff];
        const d = got(ws.decode(reader(k), MAX, [...wire, ...rest]));
        expect(d.frame.payload).toEqual([...frame.payload]);
        expect(d.key).toEqual(k);
        expect(d.rest).toEqual(rest);
      });

  test(
    "1 MiB masked roundtrip",
    () => {
      const payload = bytes(1 << 20, 3);
      const wire = ws.encode(MAX, { fin: true, opcode: "OpBinary", payload }, KEY);
      const d = got(ws.decode("Server", MAX, wire ?? []));
      expect(d.frame.payload).toEqual(payload);
    },
    SLOW_TEST_TIMEOUT_MS,
  );

  test("masking twice restores the payload", () => {
    const payload = bytes(1000, 9);
    expect(ws.mask(KEY, ws.mask(KEY, payload))).toEqual(payload);
    expect(ws.mask(KEY, [0, 0, 0, 0, 0])).toEqual([...KEY, KEY[0]]);
  });
});

describe("BND-51 decoder rejections", () => {
  const reject = (role: Role, wire: number[]) => ws.decode(role, MAX, wire);
  const protocol: Decoded = { kind: "reject", code: 1002 };
  test("reserved bits", () => {
    for (const rsv of [0x40, 0x20, 0x10])
      expect(reject("Client", [0x81 | rsv, 0])).toEqual(protocol);
  });
  test("unknown opcodes", () => {
    for (const op of [3, 4, 5, 6, 7, 11, 12, 13, 14, 15])
      expect(reject("Client", [0x80 | op, 0])).toEqual(protocol);
  });
  test("fragmented or long control frames", () => {
    for (const op of [8, 9, 10]) {
      expect(reject("Client", [op, 0])).toEqual(protocol);
      expect(reject("Client", [0x80 | op, 126, 0, 126])).toEqual(protocol);
      expect(reject("Client", [0x80 | op, 127, 0, 0, 0, 0, 0, 0, 0, 200])).toEqual(protocol);
    }
  });
  test("masking direction", () => {
    expect(reject("Server", [0x81, 0x00])).toEqual(protocol);
    expect(reject("Client", [0x81, 0x80, 1, 2, 3, 4])).toEqual(protocol);
  });
  test("non-minimal lengths", () => {
    expect(reject("Client", [0x82, 126, 0, 125])).toEqual(protocol);
    expect(reject("Client", [0x82, 126, 0, 0])).toEqual(protocol);
    expect(reject("Client", [0x82, 127, 0, 0, 0, 0, 0, 0, 0xff, 0xff])).toEqual(protocol);
    expect(reject("Client", [0x82, 127, 0, 0, 0, 0, 0, 0, 0, 5])).toEqual(protocol);
  });
  test("64-bit lengths: bit 63 is a protocol error, other upper bits are too big", () => {
    const big: Decoded = { kind: "reject", code: 1009 };
    expect(reject("Client", [0x82, 127, 0x80, 0, 0, 0, 0, 0, 0, 1])).toEqual(protocol);
    expect(reject("Client", [0x82, 127, 0, 0, 0, 1, 0, 0, 0, 0])).toEqual(big);
    expect(reject("Client", [0x82, 127, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff])).toEqual(
      big,
    );
  });
  test("configured maximum, decided before any payload arrives", () => {
    expect(ws.decode("Client", 1000, [0x82, 126, 0x03, 0xe9])).toEqual({
      kind: "reject",
      code: 1009,
    });
    expect(ws.decode("Client", 1000, [0x82, 126, 0x03, 0xe8])).toEqual({
      kind: "need",
      need: 1000,
    });
    expect(ws.decode("Client", 0, [0x82, 1, 7])).toEqual({ kind: "reject", code: 1009 });
  });
  test("a small cap holds at the boundary when bytes arrive one at a time", () => {
    for (const k of [null, KEY]) {
      const at = ws.encodeRaw({ fin: true, opcode: "OpBinary", payload: bytes(1000) }, k);
      expect(
        got(
          feed(
            reader(k),
            1000,
            at.map((b) => [b]),
          ),
        ).frame.payload,
      ).toEqual(bytes(1000));
      const over = ws.encodeRaw({ fin: true, opcode: "OpBinary", payload: bytes(1001) }, k);
      // Refused once the 16-bit length is read, before the key or any payload.
      expect(
        feed(
          reader(k),
          1000,
          over.slice(0, 4).map((b) => [b]),
        ),
      ).toEqual({ kind: "reject", code: 1009 });
    }
  });
  test("bytes above 255 in header, key or payload", () => {
    expect(reject("Client", [0x181, 0])).toEqual(protocol);
    expect(reject("Client", [0x81, 0x100])).toEqual(protocol);
    expect(reject("Client", [0x82, 126, 0x100, 0])).toEqual(protocol);
    expect(reject("Server", [0x81, 0x81, 1, 2, 3, 0x100, 9])).toEqual(protocol);
    expect(reject("Client", [0x81, 0x02, 0x41, 0x141])).toEqual(protocol);
  });
  test("every strict prefix of an encoding needs more bytes", () => {
    for (const n of [0, 3, 125, 126, 300, 65536])
      for (const k of [null, KEY]) {
        const wire = ws.encode(MAX, { fin: true, opcode: "OpBinary", payload: bytes(n) }, k) ?? [];
        const cuts =
          n > 400 ? [0, 1, 2, 5, 9, 10, 13, 14, 1000, wire.length - 1] : wire.map((_, i) => i);
        for (const cut of cuts) {
          const d = ws.decode(reader(k), MAX, wire.slice(0, cut));
          expect(d.kind).toBe("need");
          if (d.kind === "need") expect(cut + d.need).toBeLessThanOrEqual(wire.length);
        }
      }
  });
});

describe("BND-51 encoder gate", () => {
  test("refuses frames the RFC forbids sending", () => {
    expect(ws.encode(MAX, { fin: true, opcode: "OpPing", payload: bytes(126) }, null)).toBeNull();
    expect(ws.encode(MAX, { fin: false, opcode: "OpClose", payload: [] }, null)).toBeNull();
    expect(ws.encode(10, { fin: true, opcode: "OpBinary", payload: bytes(11) }, null)).toBeNull();
    expect(ws.encode(MAX, { fin: true, opcode: "OpBinary", payload: [256] }, null)).toBeNull();
    expect(
      ws.encode(MAX, { fin: true, opcode: "OpBinary", payload: [1] }, [1, 2, 3, 256]),
    ).toBeNull();
    expect(
      ws.encode(MAX, { fin: true, opcode: "OpPing", payload: bytes(125) }, null),
    ).not.toBeNull();
  });
});

describe("BND-51 bounded fuzz", () => {
  const OPS: readonly Opcode[] = [
    "OpContinue",
    "OpText",
    "OpBinary",
    "OpClose",
    "OpPing",
    "OpPong",
  ];
  const pick = (r: () => number) => Math.floor(r() * 256);
  test(
    "random valid frames roundtrip whole and fed in random chunks",
    () => {
      const r = rng(51);
      for (let i = 0; i < 400; i++) {
        const opcode = OPS[Math.floor(r() * OPS.length)] ?? "OpBinary";
        const control = opcode === "OpClose" || opcode === "OpPing" || opcode === "OpPong";
        const n = control
          ? Math.floor(r() * 126)
          : i % 2 === 0
            ? Math.floor(r() * 130)
            : Math.floor(r() * 70000);
        const fin = control || r() < 0.5;
        const k: Key | null = r() < 0.5 ? null : [pick(r), pick(r), pick(r), pick(r)];
        const payload = bytes(n, i);
        const wire = ws.encode(MAX, { fin, opcode, payload }, k);
        if (wire === null) throw new Error(`valid frame refused at ${i}`);
        const rest = bytes(Math.floor(r() * 4), i + 1);
        expect(ws.decode(reader(k), MAX, [...wire, ...rest])).toEqual({
          kind: "got",
          frame: { fin, opcode, payload },
          key: k,
          rest,
        });
        const chunks: number[][] = [];
        for (let at = 0; at < wire.length;) {
          const size = 1 + Math.floor(r() * (r() < 0.3 ? 4 : 5000));
          chunks.push(wire.slice(at, at + size));
          at += size;
        }
        expect(got(feed(reader(k), MAX, chunks)).frame.payload).toEqual(payload);
      }
    },
    SLOW_TEST_TIMEOUT_MS,
  );

  test(
    "random and mutated bytes: every accepted frame re-encodes to exactly what it consumed",
    () => {
      const r = rng(6455);
      let accepted = 0;
      for (let i = 0; i < 6000; i++) {
        const role: Role = r() < 0.5 ? "Server" : "Client";
        let input: number[];
        if (i % 2 === 0) {
          input = bytes(Math.floor(r() * 40), i);
        } else {
          const k: Key | null = role === "Server" ? [1, 2, 3, 4] : null;
          input = ws.encodeRaw(
            { fin: r() < 0.5, opcode: "OpText", payload: bytes(Math.floor(r() * 300), i) },
            k,
          );
          const flips = 1 + Math.floor(r() * 3);
          for (let f = 0; f < flips; f++) {
            const at = Math.floor(r() * Math.min(input.length, 16));
            input[at] = Math.floor(r() * (r() < 0.05 ? 512 : 256));
          }
        }
        const d = ws.decode(role, 0xffff, input);
        if (d.kind !== "got") continue;
        accepted++;
        expect([...ws.encodeRaw(d.frame, d.key), ...d.rest]).toEqual(input);
        expect(ws.encode(0xffff, d.frame, d.key)).not.toBeNull();
      }
      expect(accepted).toBeGreaterThan(100);
    },
    SLOW_TEST_TIMEOUT_MS,
  );
});

/** Best of three, to keep scheduling noise out of a cost ratio. */
function timed(run: () => void): number {
  let best = Infinity;
  for (let i = 0; i < 3; i++) {
    const t0 = performance.now();
    run();
    best = Math.min(best, performance.now() - t0);
  }
  return best;
}

describe("BND-51 cost growth", () => {
  test(
    "one-byte deliveries cost linear work in the payload",
    () => {
      const run = (n: number) => {
        const wire =
          ws.encode(MAX, { fin: true, opcode: "OpBinary", payload: bytes(n) }, KEY) ?? [];
        const chunks = wire.map((b) => [b]);
        return () => {
          if (got(feed("Server", MAX, chunks)).frame.payload.length !== n)
            throw new Error("short frame");
        };
      };
      const small = timed(run(2048));
      const large = timed(run(131072));
      // 64x the bytes. Retrying from the buffer would cost about 4096x.
      expect(large / small).toBeLessThan(64 * 8);
    },
    SLOW_TEST_TIMEOUT_MS,
  );

  test(
    "assembling many fragments costs linear work",
    () => {
      const chunk = bytes(32);
      const run = (count: number) => () => {
        let state = ws.idle;
        for (let i = 0; i < count; i++) {
          const opcode = i === 0 ? "OpBinary" : "OpContinue";
          state = ws.step(MAX, state, { fin: i === count - 1, opcode, payload: chunk }).state;
        }
      };
      const small = timed(run(128));
      const large = timed(run(8192));
      expect(large / small).toBeLessThan(64 * 8);
    },
    SLOW_TEST_TIMEOUT_MS,
  );
});

describe("BND-51 message assembly", () => {
  const frame = (fin: boolean, opcode: Opcode, payload: number[]): Frame => ({
    fin,
    opcode,
    payload,
  });
  const run = (max: number, frames: Frame[]) => {
    let state = ws.idle;
    return frames.map((f) => {
      const a = ws.step(max, state, f);
      state = a.state;
      return a.outcome;
    });
  };

  test("control frames interleave with fragments", () => {
    const frames = [
      frame(false, "OpText", utf8("He")),
      frame(true, "OpPing", [1]),
      frame(false, "OpContinue", utf8("l")),
      frame(true, "OpPong", []),
      frame(true, "OpContinue", utf8("lo")),
    ];
    expect(run(MAX, frames)).toEqual([
      { kind: "absorbed" },
      { kind: "deliver", message: { kind: "ping", data: [1] } },
      { kind: "absorbed" },
      { kind: "deliver", message: { kind: "pong", data: [] } },
      { kind: "deliver", message: { kind: "text", text: "Hello" } },
    ]);
  });

  test("stray continuation and new data mid-message are protocol errors", () => {
    expect(run(MAX, [frame(true, "OpContinue", [1])])).toEqual([{ kind: "failed", code: 1002 }]);
    expect(run(MAX, [frame(false, "OpBinary", [1]), frame(true, "OpText", [2])])).toEqual([
      { kind: "absorbed" },
      { kind: "failed", code: 1002 },
    ]);
  });

  test("UTF-8 is checked when the message completes, across fragment boundaries", () => {
    const euro = utf8("€");
    expect(
      run(MAX, [
        frame(false, "OpText", euro.slice(0, 1)),
        frame(true, "OpContinue", euro.slice(1)),
      ]).at(-1),
    ).toEqual({
      kind: "deliver",
      message: { kind: "text", text: "€" },
    });
    expect(
      run(MAX, [frame(false, "OpText", [0xce, 0xba]), frame(true, "OpContinue", [0xff])]).at(-1),
    ).toEqual({
      kind: "failed",
      code: 1007,
    });
    expect(run(MAX, [frame(true, "OpText", [0xed, 0xa0, 0x80])])).toEqual([
      { kind: "failed", code: 1007 },
    ]);
    expect(run(MAX, [frame(true, "OpBinary", [0xff])])).toEqual([
      { kind: "deliver", message: { kind: "binary", data: [0xff] } },
    ]);
  });

  test("the message cap is checked before a fragment is kept", () => {
    expect(
      run(10, [frame(false, "OpBinary", bytes(6)), frame(true, "OpContinue", bytes(4))]).at(-1),
    ).toEqual({
      kind: "deliver",
      message: { kind: "binary", data: [...bytes(6), ...bytes(4)] },
    });
    expect(
      run(10, [frame(false, "OpBinary", bytes(6)), frame(true, "OpContinue", bytes(5))]).at(-1),
    ).toEqual({
      kind: "failed",
      code: 1009,
    });
    expect(run(10, [frame(true, "OpText", bytes(11))])).toEqual([{ kind: "failed", code: 1009 }]);
  });

  test("after close or failure every later frame is ignored", () => {
    expect(
      run(MAX, [
        frame(true, "OpClose", []),
        frame(true, "OpText", utf8("x")),
        frame(true, "OpPing", []),
      ]),
    ).toEqual([
      { kind: "deliver", message: { kind: "close", code: null, reason: "" } },
      { kind: "absorbed" },
      { kind: "absorbed" },
    ]);
    const frames = [
      frame(false, "OpText", utf8("a")),
      frame(true, "OpBinary", []),
      frame(true, "OpContinue", utf8("b")),
    ];
    expect(run(MAX, frames).slice(1)).toEqual([
      { kind: "failed", code: 1002 },
      { kind: "absorbed" },
    ]);
  });

  test("a hand-built control frame is re-checked", () => {
    expect(run(MAX, [frame(true, "OpPing", bytes(126))])).toEqual([{ kind: "failed", code: 1002 }]);
    expect(run(MAX, [frame(false, "OpPong", [])])).toEqual([{ kind: "failed", code: 1002 }]);
  });

  test("close payloads and the close code table", () => {
    const close = (payload: number[]) => run(MAX, [frame(true, "OpClose", payload)])[0];
    expect(close([0x03])).toEqual({ kind: "failed", code: 1002 });
    expect(close([0x03, 0xe8, ...utf8("bye")])).toEqual({
      kind: "deliver",
      message: { kind: "close", code: 1000, reason: "bye" },
    });
    expect(close([0x03, 0xe8, 0xff])).toEqual({ kind: "failed", code: 1007 });
    expect(close(ws.closePayload(4001, "é"))).toEqual({
      kind: "deliver",
      message: { kind: "close", code: 4001, reason: "é" },
    });
    const valid = [
      1000, 1001, 1002, 1003, 1007, 1008, 1009, 1010, 1011, 1012, 1013, 1014, 3000, 3999, 4000,
      4999,
    ];
    const invalid = [0, 999, 1004, 1005, 1006, 1015, 1016, 1100, 2000, 2999, 5000, 65535];
    for (const code of valid)
      expect(close([code >> 8, code & 255])).toEqual({
        kind: "deliver",
        message: { kind: "close", code, reason: "" },
      });
    for (const code of invalid)
      expect(close([code >> 8, code & 255])).toEqual({ kind: "failed", code: 1002 });
    for (let code = 0; code < 65536; code++) {
      const ok =
        (code >= 1000 && code <= 1003) ||
        (code >= 1007 && code <= 1014) ||
        (code >= 3000 && code <= 4999);
      if (ws.codeOk(code) !== ok) throw new Error(`close code ${code}`);
    }
  });

  test(
    "a 1 MiB message in 16 fragments",
    () => {
      const data = bytes(1 << 20, 4);
      let last = ws.step(MAX, ws.idle, frame(false, "OpBinary", data.slice(0, 65536)));
      for (let i = 1; i < 16; i++)
        last = ws.step(
          MAX,
          last.state,
          frame(i === 15, "OpContinue", data.slice(i * 65536, (i + 1) * 65536)),
        );
      expect(last.outcome).toEqual({ kind: "deliver", message: { kind: "binary", data } });
    },
    SLOW_TEST_TIMEOUT_MS,
  );
});
