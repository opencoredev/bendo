import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { connect } from "node:net";
import { pathToFileURL } from "node:url";
import { build, compile, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/mw-ip.bend");
const modulePath = compile("tests/fixtures/ip/consumer.bend", "mjs");

const loaded: unknown = await import(pathToFileURL(modulePath).href);
if (typeof loaded !== "object" || loaded === null || !("default" in loaded)) {
  throw new Error("Missing Bend module");
}
const exports: unknown = loaded.default;
function exported(name: string): (...args: string[]) => string {
  if (typeof exports !== "object" || exports === null || !(name in exports)) {
    throw new Error(`Missing export ${name}`);
  }
  const fn: unknown = Reflect.get(exports, name);
  if (typeof fn !== "function") throw new Error(`Not callable: ${name}`);
  return (...args) => {
    const result: unknown = fn(...args);
    if (typeof result !== "string") throw new Error(`${name} did not return a string`);
    return result;
  };
}
const parse = exported("parse");
const bendBits = exported("bits");
const cidr = exported("cidr");
const member = exported("member");
const permitted = exported("permitted");
const client = exported("client");

// An independent model: expand an address to its bits with Node's parser
// as the validity oracle and our own group expansion.
function groupsOf(address: string): number[] {
  const [head = "", tail] = address.split("::");
  const side = (s: string): number[] => {
    if (s === "") return [];
    const out: number[] = [];
    for (const part of s.split(":")) {
      if (part.includes(".")) {
        const o = part.split(".").map(Number);
        out.push(((o[0] ?? 0) << 8) | (o[1] ?? 0), ((o[2] ?? 0) << 8) | (o[3] ?? 0));
      } else out.push(parseInt(part, 16));
    }
    return out;
  };
  const left = side(head);
  const right = tail === undefined ? [] : side(tail);
  const fill = tail === undefined ? [] : Array<number>(8 - left.length - right.length).fill(0);
  return [...left, ...fill, ...right];
}
function modelBits(address: string): string {
  if (!address.includes(":")) {
    return address
      .split(".")
      .map((o) => Number(o).toString(2).padStart(8, "0"))
      .join("");
  }
  const bits = groupsOf(address)
    .map((g) => g.toString(2).padStart(16, "0"))
    .join("");
  // IPv4-mapped addresses are the IPv4 address they carry.
  return bits.startsWith("0".repeat(80) + "1".repeat(16)) ? bits.slice(96) : bits;
}
function modelMember(address: string, network: string, len: number): boolean {
  const a = modelBits(address);
  const n = modelBits(network);
  return a.length === n.length && a.slice(0, len) === n.slice(0, len);
}

describe("address parsing (pure core through .mjs)", () => {
  test("accepts canonical and compressed forms and formats them per RFC 5952", () => {
    const cases: [string, string][] = [
      ["127.0.0.1", "IPv4 127.0.0.1"],
      ["0.0.0.0", "IPv4 0.0.0.0"],
      ["255.255.255.255", "IPv4 255.255.255.255"],
      ["::1", "IPv6 ::1"],
      ["::", "IPv6 ::"],
      ["1::", "IPv6 1::"],
      ["2001:DB8:0:0:0:0:2:1", "IPv6 2001:db8::2:1"],
      ["2001:0db8:0000:0001:0000:0000:0000:0001", "IPv6 2001:db8:0:1::1"],
      ["1:0:0:1:0:0:0:1", "IPv6 1:0:0:1::1"],
      ["1:0:0:2:0:0:3:4", "IPv6 1::2:0:0:3:4"],
      ["1:2:3:4:5:6:7:0", "IPv6 1:2:3:4:5:6:7:0"],
      ["::ffff:10.0.0.1", "IPv4 10.0.0.1"],
      ["::FFFF:a00:1", "IPv4 10.0.0.1"],
      ["0:0:0:0:0:ffff:7f00:1", "IPv4 127.0.0.1"],
      ["::1.2.3.4", "IPv6 ::102:304"],
      ["1:2:3:4:5:6:1.2.3.4", "IPv6 1:2:3:4:5:6:102:304"],
    ];
    for (const [input, expected] of cases) expect([input, parse(input)]).toEqual([input, expected]);
  });

  test("IPv6 formatting matches the WHATWG URL serializer (an independent RFC 5952 writer)", () => {
    const next = random(44);
    for (let i = 0; i < 300; i++) {
      // Bias toward zero groups so compression cases are common.
      const groups = Array.from({ length: 8 }, () =>
        next() < 0.5 ? 0 : Math.floor(next() * 0x10000),
      );
      if (groups[5] === 0xffff && groups.slice(0, 5).every((g) => g === 0)) continue;
      const text = groups.map((g) => g.toString(16)).join(":");
      const expected = new URL(`http://[${text}]/`).hostname.slice(1, -1);
      expect([text, parse(text)]).toEqual([text, `IPv6 ${expected}`]);
      expect(bendBits(text)).toBe(modelBits(text));
    }
  });

  test("rejects ambiguous, shorthand, out-of-range and zoned text", () => {
    for (const input of [
      "",
      " 1.2.3.4",
      "1.2.3.4 ",
      "01.2.3.4",
      "1.2.3.04",
      "00.0.0.0",
      "256.1.1.1",
      "1.2.3",
      "1.2.3.4.5",
      "127.1",
      "0x7f.0.0.1",
      "1..2.3",
      "1:2:3:4:5:6:7:8:9",
      "1:2:3:4:5:6:7",
      "1::2::3",
      ":::",
      ":1::",
      "1:::2",
      "12345::",
      "g::1",
      "fe80::1%eth0",
      "fe80::1%25eth0",
      "1.2.3.4::",
      "::1.2.3",
      "::256.0.0.1",
      "1:2:3:4:5:6:7:1.2.3.4",
      "[::1]",
      "::1:",
      "1.2.3.4:80",
    ]) {
      expect([input, parse(input)]).toEqual([input, "invalid"]);
    }
  });
});

describe("CIDR matching edge prefixes (pure core)", () => {
  test("parses strict ranges and refuses host bits, bad lengths and leading zeros", () => {
    expect(cidr("10.0.0.0/8")).toBe(`IPv4 ${modelBits("10.0.0.0")}/8`);
    expect(cidr("1.2.3.4")).toBe(`IPv4 ${modelBits("1.2.3.4")}/32`);
    expect(cidr("::1")).toBe(`IPv6 ${modelBits("::1")}/128`);
    expect(cidr("::ffff:10.0.0.0/104")).toBe(`IPv4 ${modelBits("10.0.0.0")}/8`);
    expect(cidr("::ffff:0:0/96")).toBe(`IPv4 ${"0".repeat(32)}/0`);
    for (const input of [
      "10.0.0.1/8",
      "1.2.3.4/33",
      "::/129",
      "1.2.3.4/032",
      "1.2.3.4/",
      "/8",
      "1.2.3.4/8/8",
      "1.2.3.4/-1",
      "::ffff:0:0/80",
      "fe80::%eth0/64",
    ]) {
      expect([input, cidr(input)]).toEqual([input, "invalid"]);
    }
  });

  test("membership agrees with the bit model at /0, /31, /32, /127, /128 and around boundaries", () => {
    const v4: [string, number][] = [
      ["0.0.0.0", 0],
      ["10.0.0.0", 8],
      ["192.168.1.0", 31],
      ["192.168.1.2", 31],
      ["192.168.1.1", 32],
      ["255.255.255.255", 32],
      ["128.0.0.0", 1],
    ];
    const v4probes = [
      "0.0.0.0",
      "255.255.255.255",
      "9.255.255.255",
      "10.0.0.0",
      "10.255.255.255",
      "11.0.0.0",
      "192.168.1.0",
      "192.168.1.1",
      "192.168.1.2",
      "192.168.1.3",
      "127.255.255.255",
      "128.0.0.0",
      "::ffff:10.1.2.3",
      "::1",
    ];
    const v6: [string, number][] = [
      ["::", 0],
      ["2001:db8::", 32],
      ["2001:db8::", 127],
      ["2001:db8::2", 127],
      ["2001:db8::1", 128],
      ["::1", 128],
      ["ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff", 128],
    ];
    const v6probes = [
      "::",
      "::1",
      "2001:db8::",
      "2001:db8::1",
      "2001:db8::2",
      "2001:db8::3",
      "2001:db7:ffff:ffff:ffff:ffff:ffff:ffff",
      "2001:db9::",
      "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
      "1.2.3.4",
      "::ffff:1.2.3.4",
    ];
    for (const [network, len] of [...v4, ...v6]) {
      for (const probe of [...v4probes, ...v6probes]) {
        const expected = modelMember(probe, network, len);
        expect([probe, network, len, member(probe, `${network}/${len}`)]).toEqual([
          probe,
          network,
          len,
          expected ? "True" : "False",
        ]);
      }
    }
  });

  test("IPv4-mapped addresses follow IPv4 rules; ::/0 covers only IPv6", () => {
    expect(member("::ffff:10.0.0.1", "10.0.0.0/8")).toBe("True");
    expect(member("10.0.0.1", "::ffff:10.0.0.0/104")).toBe("True");
    expect(member("1.2.3.4", "::/0")).toBe("False");
    expect(member("::ffff:1.2.3.4", "::/0")).toBe("False");
    expect(member("::1", "0.0.0.0/0")).toBe("False");
    expect(member("2001:db8::1", "::/0")).toBe("True");
  });

  test("random addresses agree with the model at every prefix length", () => {
    const next = random(7);
    for (let i = 0; i < 120; i++) {
      const v6 = next() < 0.5;
      const address = v6
        ? Array.from({ length: 8 }, () => Math.floor(next() * 0x10000).toString(16)).join(":")
        : Array.from({ length: 4 }, () => Math.floor(next() * 256)).join(".");
      const width = v6 ? 128 : 32;
      const len = Math.floor(next() * (width + 1));
      // Zero the host bits of a near neighbour to build a valid network.
      const bits = modelBits(address);
      const flipped = bits.slice(0, len) + "0".repeat(width - len);
      const network = v6
        ? Array.from({ length: 8 }, (_, g) =>
            parseInt(flipped.slice(g * 16, g * 16 + 16), 2).toString(16),
          ).join(":")
        : Array.from({ length: 4 }, (_, o) => parseInt(flipped.slice(o * 8, o * 8 + 8), 2)).join(
            ".",
          );
      if (modelBits(network).length !== width) continue;
      expect(member(address, `${network}/${len}`)).toBe("True");
      if (len > 0) {
        const outside = bits.slice(0, len - 1) + (bits[len - 1] === "1" ? "0" : "1");
        const net2 = outside + "0".repeat(width - len);
        const text = v6
          ? Array.from({ length: 8 }, (_, g) =>
              parseInt(net2.slice(g * 16, g * 16 + 16), 2).toString(16),
            ).join(":")
          : Array.from({ length: 4 }, (_, o) => parseInt(net2.slice(o * 8, o * 8 + 8), 2)).join(
              ".",
            );
        if (modelBits(text).length === width)
          expect(member(address, `${text}/${len}`)).toBe("False");
      }
    }
  });

  test("deny overrides allow; an unknown address is refused unless both lists are empty", () => {
    expect(permitted("10.0.0.0/8", "10.0.0.0/8", "10.0.0.1")).toBe("False");
    expect(permitted("10.0.0.0/8", "", "11.0.0.1")).toBe("True");
    expect(permitted("", "10.0.0.0/8", "11.0.0.1")).toBe("False");
    expect(permitted("", "10.0.0.0/8,::1", "::1")).toBe("True");
    expect(permitted("", "", "1.2.3.4")).toBe("True");
    expect(permitted("", "", "not-an-address")).toBe("True");
    expect(permitted("10.0.0.0/8", "", "not-an-address")).toBe("False");
    expect(permitted("", "10.0.0.0/8", "not-an-address")).toBe("False");
    expect(permitted("10.0.0.1/8", "", "1.2.3.4")).toBe("invalid");
  });

  test("X-Forwarded-For counts only behind a trusted proxy, nearest hop first", () => {
    expect(client("", "127.0.0.1", "203.0.113.9")).toBe("IPv4 127.0.0.1");
    expect(client("10.0.0.0/8", "127.0.0.1", "203.0.113.9")).toBe("IPv4 127.0.0.1");
    expect(client("127.0.0.1", "127.0.0.1", "203.0.113.9")).toBe("IPv4 203.0.113.9");
    // A client-written leftmost entry never wins over the hop a proxy added.
    expect(client("127.0.0.1", "127.0.0.1", "1.1.1.1, 203.0.113.9")).toBe("IPv4 203.0.113.9");
    expect(client("127.0.0.1,10.0.0.0/8", "127.0.0.1", "1.1.1.1, 203.0.113.9, 10.0.0.7")).toBe(
      "IPv4 203.0.113.9",
    );
    // Several fields are one list, in order.
    expect(client("127.0.0.1", "127.0.0.1", "5.5.5.5|6.6.6.6")).toBe("IPv4 6.6.6.6");
    // Malformed or exhausted: stop at the last trusted hop.
    expect(client("127.0.0.1", "127.0.0.1", "garbage")).toBe("IPv4 127.0.0.1");
    expect(client("127.0.0.1,10.0.0.0/8", "127.0.0.1", "1.1.1.1, bad, 10.0.0.7")).toBe(
      "IPv4 10.0.0.7",
    );
    expect(client("127.0.0.1,10.0.0.0/8", "127.0.0.1", "10.0.0.8")).toBe("IPv4 10.0.0.8");
    expect(client("127.0.0.1", "127.0.0.1", "203.0.113.9:443")).toBe("IPv4 127.0.0.1");
    expect(client("127.0.0.1", "127.0.0.1", "::ffff:203.0.113.9")).toBe("IPv4 203.0.113.9");
  });
});

let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => {
  await server[Symbol.asyncDispose]();
});

async function get(path: string, headers: Record<string, string> = {}): Promise<Response> {
  return fetch(server.url + path, { headers, signal: AbortSignal.timeout(10_000) });
}
async function status(path: string, headers: Record<string, string> = {}): Promise<number> {
  const response = await get(path, headers);
  await response.arrayBuffer();
  return response.status;
}
async function setClock(ms: number): Promise<void> {
  const response = await fetch(`${server.url}/clock?ms=${ms}`, {
    method: "POST",
    signal: AbortSignal.timeout(10_000),
  });
  expect(await response.text()).toBe("ok");
}

/** Send one raw request and return the reply text with the client's local port. */
function raw(path: string): Promise<{ text: string; port: number }> {
  const url = new URL(server.url);
  return new Promise((resolve, reject) => {
    const socket = connect(Number(url.port), url.hostname);
    let text = "";
    let port = -1;
    socket.setTimeout(10_000, () => socket.destroy(new Error("raw request timed out")));
    socket.on("connect", () => {
      port = socket.localPort ?? -1;
      socket.write(`GET ${path} HTTP/1.1\r\nhost: x\r\nconnection: close\r\n\r\n`);
    });
    socket.on("data", (chunk: Buffer) => {
      text += chunk.toString("latin1");
    });
    socket.on("error", reject);
    socket.on("close", () => resolve({ text, port }));
  });
}

describe("connection info (compiled server)", () => {
  test("conn_info reports 127.0.0.1 and the client's own port for a local request", async () => {
    const { text, port } = await raw("/info");
    expect(text.startsWith("HTTP/1.1 200")).toBe(true);
    expect(text.split("\r\n\r\n")[1]).toBe(`IPv4 127.0.0.1 ${port}`);
  });

  test("a spoofed X-Forwarded-For never changes the peer or the default client address", async () => {
    const response = await get("/client", { "x-forwarded-for": "203.0.113.9" });
    expect(await response.text()).toBe("127.0.0.1");
    const behind = await get("/proxied/client", { "x-forwarded-for": "1.1.1.1, 198.51.100.9" });
    expect(await behind.text()).toBe("198.51.100.9");
  });
});

describe("IP restriction (compiled server)", () => {
  test("allow and deny lists against the 127.0.0.1 peer", async () => {
    expect(await status("/deny/x")).toBe(403);
    expect(await status("/allow-other/x")).toBe(403);
    expect(await status("/allow-local/x")).toBe(200);
    expect(await status("/deny-wins/x")).toBe(403);
    expect(await status("/mapped/x")).toBe(403);
    expect(await status("/v6-only/x")).toBe(200);
    expect(await status("/elsewhere")).toBe(200);
  });

  test("a 403 is a negotiated error body", async () => {
    const text = await get("/deny/x");
    expect(text.status).toBe(403);
    expect(await text.text()).toBe("Forbidden");
    const json = await get("/deny/x", { accept: "application/json" });
    expect(await json.json()).toEqual({ error: "Forbidden", status: 403 });
  });

  test("forwarded addresses count only behind a trusted proxy", async () => {
    expect(await status("/proxied/x", { "x-forwarded-for": "203.0.113.5" })).toBe(403);
    expect(await status("/proxied/x", { "x-forwarded-for": "198.51.100.1" })).toBe(200);
    expect(await status("/spoof/x", { "x-forwarded-for": "203.0.113.5" })).toBe(200);
    expect(await status("/spoof-allow/x", { "x-forwarded-for": "10.0.0.1" })).toBe(403);
  });
});

function header(response: Response, name: string): string | null {
  return response.headers.get(name);
}

describe("rate limiting (compiled server, injected clock)", () => {
  test("the 101st request in a 100-per-minute window gets 429 with Retry-After and RateLimit", async () => {
    await setClock(1_000_000);
    const key = { "x-test-key": "fixed-101" };
    for (let i = 1; i <= 100; i++) {
      const response = await get("/fixed", key);
      await response.arrayBuffer();
      expect([i, response.status]).toEqual([i, 200]);
      expect(header(response, "ratelimit")).toBe(`"default";r=${100 - i};t=20`);
      expect(header(response, "ratelimit-policy")).toBe(`"default";q=100;w=60`);
    }
    const denied = await get("/fixed", key);
    expect(denied.status).toBe(429);
    expect(await denied.text()).toBe("Too Many Requests");
    // 1,000,000 ms is 40 s into its 60 s window: 20 s remain.
    expect(header(denied, "retry-after")).toBe("20");
    expect(header(denied, "ratelimit")).toBe(`"default";r=0;t=20`);
    expect(header(denied, "ratelimit-policy")).toBe(`"default";q=100;w=60`);
    // Other keys keep their own counts.
    expect(await status("/fixed", { "x-test-key": "fixed-other" })).toBe(200);
    // Still denied one millisecond before the window ends; allowed at its end.
    await setClock(1_019_999);
    const late = await get("/fixed", key);
    expect(late.status).toBe(429);
    expect(header(late, "retry-after")).toBe("1");
    await setClock(1_020_000);
    const next = await get("/fixed", key);
    expect(next.status).toBe(200);
    expect(header(next, "ratelimit")).toBe(`"default";r=99;t=60`);
  });

  test("a request read from an earlier clock never resets a newer window", async () => {
    await setClock(5_000_000);
    const key = { "x-test-key": "fixed-order" };
    for (let i = 0; i < 100; i++) expect(await status("/fixed", key)).toBe(200);
    await setClock(4_970_000);
    expect(await status("/fixed", key)).toBe(429);
    await setClock(5_000_000);
    expect(await status("/fixed", key)).toBe(429);
  });

  test("token bucket: capacity bursts, integer refill, never above capacity", async () => {
    await setClock(10_000_000);
    const key = { "x-test-key": "bucket" };
    for (let i = 1; i <= 5; i++) {
      const response = await get("/bucket", key);
      await response.arrayBuffer();
      expect(response.status).toBe(200);
      expect(header(response, "ratelimit")).toBe(`"burst";r=${5 - i};t=${i}`);
      expect(header(response, "ratelimit-policy")).toBe(`"burst";q=5;w=5`);
    }
    const denied = await get("/bucket", key);
    expect(denied.status).toBe(429);
    expect(header(denied, "retry-after")).toBe("1");
    // 999 ms refills less than one token.
    await setClock(10_000_999);
    expect(await status("/bucket", key)).toBe(429);
    await setClock(10_001_000);
    expect(await status("/bucket", key)).toBe(200);
    expect(await status("/bucket", key)).toBe(429);
    // A long idle period refills to capacity, not beyond it.
    await setClock(20_000_000);
    for (let i = 0; i < 5; i++) expect(await status("/bucket", key)).toBe(200);
    expect(await status("/bucket", key)).toBe(429);
  });

  const as = (k: string) => ({ "x-test-key": k });
  async function stats(path: string): Promise<string> {
    const response = await get(`/stats${path}`);
    expect(response.status).toBe(200);
    return response.text();
  }

  // The three "tiny" limiters allow 2 requests per minute and track at most 2 keys.
  test("default saturation: key spraying never denies a new client; tracked keys keep their quotas", async () => {
    await setClock(30_000_000);
    // The review's reproduction: attacker-a and attacker-b fill the table.
    for (const k of ["attacker-a", "attacker-b", "attacker-c", "attacker-d"]) {
      expect([k, await status("/tiny", as(k))]).toEqual([k, 200]);
    }
    for (let i = 0; i < 5; i++) {
      const fresh = await get("/tiny", as("legitimate-new"));
      await fresh.arrayBuffer();
      expect(fresh.status).toBe(200);
      // No quota applied to it, so no RateLimit fields.
      expect(header(fresh, "ratelimit")).toBeNull();
      expect(header(fresh, "ratelimit-policy")).toBeNull();
    }
    // Spraying keys did not reset or share the tracked quotas.
    const tracked = await get("/tiny", as("attacker-a"));
    await tracked.arrayBuffer();
    expect(tracked.status).toBe(200);
    expect(header(tracked, "ratelimit")).toBe(`"tiny";r=0;t=60`);
    expect(await status("/tiny", as("attacker-a"))).toBe(429);
    expect(await status("/tiny", as("attacker-b"))).toBe(200);
    expect(await status("/tiny", as("attacker-b"))).toBe(429);
    // Two tracked keys; seven requests met the full table; still saturated.
    expect(await stats("/tiny")).toBe("2 7 true");
    // In the next window the idle entries are swept and the new client is tracked.
    await setClock(30_060_000);
    expect(await status("/tiny", as("legitimate-new"))).toBe(200);
    expect(await stats("/tiny")).toBe("1 7 false");
    expect(await status("/tiny", as("legitimate-new"))).toBe(200);
    expect(await status("/tiny", as("legitimate-new"))).toBe(429);
  });

  test("shared saturation (opt-in): new keys share one overflow quota and fail closed", async () => {
    await setClock(31_000_000);
    expect(await status("/tiny-shared", as("a"))).toBe(200);
    expect(await status("/tiny-shared", as("b"))).toBe(200);
    // The table is full: c and d share the overflow entry's quota of 2.
    expect(await status("/tiny-shared", as("c"))).toBe(200);
    expect(await status("/tiny-shared", as("d"))).toBe(200);
    expect(await status("/tiny-shared", as("c"))).toBe(429);
    // The documented trade-off: a client never seen before is denied too.
    expect(await status("/tiny-shared", as("legitimate-new"))).toBe(429);
    // Spraying keys did not reset a or b.
    expect(await status("/tiny-shared", as("a"))).toBe(200);
    expect(await status("/tiny-shared", as("a"))).toBe(429);
    expect(await status("/tiny-shared", as("b"))).toBe(200);
    expect(await stats("/tiny-shared")).toBe("2 4 true");
    // In the next window the idle entries are swept and d gets its own entry.
    await setClock(31_060_000);
    expect(await status("/tiny-shared", as("d"))).toBe(200);
    expect(await status("/tiny-shared", as("d"))).toBe(200);
    expect(await status("/tiny-shared", as("d"))).toBe(429);
    expect(await status("/tiny-shared", as("e"))).toBe(200);
  });

  test("evict saturation (opt-in): the least recently used key makes room; its quota restarts", async () => {
    await setClock(32_400_000);
    expect(await status("/tiny-evict", as("a"))).toBe(200);
    expect(await status("/tiny-evict", as("b"))).toBe(200);
    expect(await status("/tiny-evict", as("a"))).toBe(200);
    // Full: c evicts b, the least recently used, and is counted.
    const c = await get("/tiny-evict", as("c"));
    await c.arrayBuffer();
    expect(c.status).toBe(200);
    expect(header(c, "ratelimit")).toBe(`"tiny";r=1;t=60`);
    expect(await status("/tiny-evict", as("legitimate-new"))).toBe(200);
    // legitimate-new evicted a (touched before c). c keeps its count.
    expect(await status("/tiny-evict", as("c"))).toBe(200);
    expect(await status("/tiny-evict", as("c"))).toBe(429);
    expect(await status("/tiny-evict", as("legitimate-new"))).toBe(200);
    expect(await status("/tiny-evict", as("legitimate-new"))).toBe(429);
    expect(await stats("/tiny-evict")).toBe("2 2 true");
    // The documented trade-off: an evicted key starts over (a had used 2).
    expect(await status("/tiny-evict", as("a"))).toBe(200);
    expect(await stats("/tiny-evict")).toBe("2 3 true");
  });

  test("evict saturation stays correct over many evictions and queue compactions", async () => {
    await setClock(33_000_000);
    // A steady tracked client between bursts of new keys keeps its own count.
    expect(await status("/tiny-evict", as("steady"))).toBe(200);
    for (let i = 0; i < 30; i++) {
      expect(await status("/tiny-evict", as(`churn-${i}`))).toBe(200);
    }
    expect(await stats("/tiny-evict")).toMatch(/^2 \d+ true$/);
    // steady was evicted long ago, so it starts over: 2 allowed, then 429.
    expect(await status("/tiny-evict", as("steady"))).toBe(200);
    expect(await status("/tiny-evict", as("steady"))).toBe(200);
    expect(await status("/tiny-evict", as("steady"))).toBe(429);
  });

  test("concurrent requests are serialized: exactly the limit succeeds", async () => {
    await setClock(40_000_000);
    const key = { "x-test-key": "conc" };
    // 60 requests at once against a limit of 40 (not a load test).
    const statuses = await Promise.all(Array.from({ length: 60 }, () => status("/conc", key)));
    expect(statuses.filter((s) => s === 200).length).toBe(40);
    expect(statuses.filter((s) => s === 429).length).toBe(20);
  });

  test("B.rate_limit keys by the peer address on the real monotonic clock", async () => {
    for (let i = 0; i < 3; i++) expect(await status("/live")).toBe(200);
    // A spoofed header does not give the same peer a fresh key.
    expect(await status("/live", { "x-forwarded-for": "198.51.100.77" })).toBe(429);
  });
});

// Deterministic generator, so a failing case can be reproduced.
function random(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 2 ** 32;
  };
}
