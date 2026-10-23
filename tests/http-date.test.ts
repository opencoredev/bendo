import { describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { connect } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { compile, start } from "./harness.ts";

const module: unknown = await import(
  pathToFileURL(compile("tests/fixtures/http-date/consumer.bend", "mjs")).href
);
if (typeof module !== "object" || module === null || !("default" in module))
  throw new Error("Missing Bend exports");
const api: unknown = module.default;
function exported(name: string): (...args: unknown[]) => unknown {
  if (typeof api !== "object" || api === null || !(name in api)) throw new Error(`Missing ${name}`);
  const fn: unknown = Reflect.get(api, name);
  if (typeof fn !== "function") throw new Error(`Not callable: ${name}`);
  return (...args) => fn(...args);
}
const format = exported("format_imf");
const parse = exported("parse_imf");
const serverBinary = compile("tests/servers/http-date.bend", "native");
const handleBinary = compile("tests/fixtures/http-date/handle.bend", "native");
const legacyBinary = compile("tests/fixtures/http-connection/legacy.bend", "native");
const vectors: readonly (readonly [number, string])[] = [
  [0, "Thu, 01 Jan 1970 00:00:00 GMT"],
  [784111777, "Sun, 06 Nov 1994 08:49:37 GMT"],
  [951782400, "Tue, 29 Feb 2000 00:00:00 GMT"],
  [4107542400, "Mon, 01 Mar 2100 00:00:00 GMT"],
  [253402300799, "Fri, 31 Dec 9999 23:59:59 GMT"],
];
function run(command: string[]): string {
  const proc = Bun.spawnSync(command, { stdout: "pipe", stderr: "pipe", timeout: 30_000 });
  if (proc.exitCode !== 0) throw new Error(`${proc.stdout}${proc.stderr}`);
  return proc.stdout.toString().trim();
}

function raw(url: string, request: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const target = new URL(url);
    const socket = connect({ host: target.hostname, port: Number(target.port) });
    const chunks: Buffer[] = [];
    socket.setTimeout(5000, () => socket.destroy(new Error("HTTP date socket timed out")));
    socket.on("connect", () => socket.end(request));
    socket.on("data", (chunk: Buffer) => chunks.push(chunk));
    socket.on("error", reject);
    socket.on("end", () => resolve(Buffer.concat(chunks).toString("latin1")));
  });
}

describe("HTTP dates", () => {
  test("native and .mjs formatting match independent fixed vectors", () => {
    for (const [second, expected] of vectors) {
      expect(format(second)).toBe(expected);
      expect(parse(expected)).toEqual({ $: "Some", value: second });
    }
    expect(run([compile("tests/fixtures/http-date/vectors.bend", "native")])).toBe(
      vectors.map(([, text]) => text).join("\n"),
    );
  });

  test("strict parser rejects wrong weekdays, invalid dates, obsolete forms and extra bytes", () => {
    for (const invalid of [
      "Mon, 06 Nov 1994 08:49:37 GMT",
      "Sun, 6 Nov 1994 08:49:37 GMT",
      "Sun, 06 nov 1994 08:49:37 GMT",
      "Sun, 06 Nov 1994 08:49:37 UTC",
      "Sun, 06 Nov 1994 08:49:60 GMT",
      "Sun, 06 Nov 1994 24:49:37 GMT",
      "Sun, 06 Nov 1994 08:60:37 GMT",
      "Tue, 29 Feb 2100 00:00:00 GMT",
      "Thu, 31 Apr 2000 00:00:00 GMT",
      "Wed, 31 Dec 1969 23:59:59 GMT",
      "Sun, 06 Nov 1994 08:49:37 GMT\r\n",
      "Sunday, 06-Nov-94 08:49:37 GMT",
      "Sun Nov  6 08:49:37 1994",
      "Sun, 0: Nov 1994 08:49:37 GMT",
      "Sun, 06 Nov 0000 08:49:37 GMT",
      "",
    ])
      expect(parse(invalid)).toEqual({ $: "None" });
    expect(format(253402300800)).toBe("");
  });

  test("calendar boundaries and sampled seconds match the host UTC calendar", () => {
    // Deterministic samples cover every year, including century leap rules.
    for (let year = 1970; year <= 9999; year++) {
      for (const month of [0, 1, 2, 11]) {
        const second = Date.UTC(year, month, 1, 23, 59, 59) / 1000;
        const expected = new Date(second * 1000).toUTCString();
        expect(format(second)).toBe(expected);
        expect(parse(expected)).toEqual({ $: "Some", value: second });
      }
    }
  });

  test("native and JavaScript executable targets call their realtime twin", () => {
    const native = compile("tests/fixtures/http-date/clock.bend", "native");
    const js = compile("tests/fixtures/http-date/clock.bend", "js");
    expect(readFileSync(js, "utf8")).toContain("Date.now()");
    for (const command of [[native], [process.execPath, js]]) {
      const before = Date.now();
      const [millis, seconds] = run(command).split("\n").map(Number);
      const after = Date.now();
      expect(millis).toBeGreaterThanOrEqual(before);
      expect(millis).toBeLessThanOrEqual(after);
      expect(seconds).toBeGreaterThanOrEqual(Math.floor(before / 1000));
      expect(seconds).toBeLessThanOrEqual(Math.floor(after / 1000));
    }
  });

  test(".mjs library dispatches its registered JS twin and rejects out-of-range host time", async () => {
    const root = mkdtempSync(join(tmpdir(), "bendo-clock-mjs-"));
    const originalNow = Date.now;
    try {
      const artifact = compile("tests/fixtures/http-date/clock.bend", "mjs");
      // Bend's .mjs library returns IO descriptions rather than running an event
      // loop. Supply a synchronous test driver for this immediate clock effect.
      const bridged = join(root, "clock.mjs");
      writeFileSync(
        bridged,
        readFileSync(artifact, "utf8") +
          `
export function test_sample() {
  const action = $sample({ $: "Unit" })(value => value);
  return action.kont($0eff[action.$](...action.args));
}
`,
      );
      const library: unknown = await import(pathToFileURL(bridged).href);
      if (
        typeof library !== "object" ||
        library === null ||
        !("test_sample" in library) ||
        typeof library.test_sample !== "function"
      )
        throw new Error("Missing .mjs clock driver");
      for (const millis of [0, 784111777000, 253402300799999]) {
        Date.now = () => millis;
        expect(library.test_sample()).toEqual({ $: "Done", value: millis });
      }
      for (const millis of [-1, NaN, Infinity, 1.5, 253402300800000]) {
        Date.now = () => millis;
        const result: unknown = library.test_sample();
        if (typeof result !== "object" || result === null || !("$" in result))
          throw new Error("Missing clock failure");
        expect(result.$).toBe("Fail");
      }
    } finally {
      Date.now = originalNow;
      rmSync(root, { recursive: true, force: true });
    }
  });

  test("informational and explicit legacy dates survive without a clock; unavailable clocks use 500", () => {
    const js = compile("tests/fixtures/http-date/wire.bend", "js");
    const result = run([
      process.execPath,
      "-e",
      `Date.now = () => -1; await import(${JSON.stringify(pathToFileURL(js).href)});`,
    ]);
    expect(result).toBe(
      "HTTP/1.1 103 Early Hints\r\n\r\n\n" +
        "HTTP/1.1 200 OK\r\nDaTe: Sun, 06 Nov 1994 08:49:37 GMT\r\ncontent-length: 4\r\n\r\nbody\n" +
        "HTTP/1.1 500 Internal Server Error\r\ncontent-length: 0\r\n\r\n\n" +
        "HTTP/1.1 500 Internal Server Error\r\ncontent-length: 0\r\nconnection: close\r\n\r\n\n500",
    );
    const native = run([compile("tests/fixtures/http-date/wire.bend", "native")]);
    expect(native).toContain("\r\ndate: ");
    expect(native).toEndWith("200");
  });

  test("C effect edits invalidate the real fixture compilation cache", () => {
    const root = mkdtempSync(join(tmpdir(), "bendo-date-cache-"));
    try {
      const clockRoot = join(import.meta.dir, "../src/effects");
      writeFileSync(join(root, "clock.c"), readFileSync(join(clockRoot, "clock.c")));
      writeFileSync(join(root, "clock.js"), readFileSync(join(clockRoot, "clock.js")));
      writeFileSync(join(root, "clock.bend"), readFileSync(join(clockRoot, "clock.bend")));
      writeFileSync(
        join(root, "main.bend"),
        'import Base\nimport ./clock.bend as Clock\ndef main() -> IO(Unit):\n  do IO<Unit>:\n    result : Result<&1, &1, U32 & String, Nat> <- Clock.wall_seconds()\n    IO.print("clock sampled")\n',
      );
      const first = compile(join(root, "main.bend"), "native");
      writeFileSync(
        join(root, "clock.c"),
        readFileSync(join(root, "clock.c"), "utf8") + "\n// cache probe\n",
      );
      const second = compile(join(root, "main.bend"), "native");
      expect(second).not.toBe(first);
      expect(run([second])).toBe("clock sampled");
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  test("network-free responses and malformed queries receive Date", () => {
    const lines = run([handleBinary]).split("\n");
    expect(lines).toHaveLength(3);
    for (const [index, status] of [200, 404, 400].entries()) {
      const line = lines[index] ?? "";
      expect(line.slice(0, 4)).toBe(`${status} `);
      expect(Math.abs(Date.parse(line.slice(4)) - Date.now())).toBeLessThanOrEqual(2000);
    }
  });

  test("transport rejections and legacy byte handlers receive Date without changing binary bodies", async () => {
    await using server = await start(serverBinary);
    const rejected = await raw(
      server.url,
      "POST / HTTP/1.1\r\nHost: test\r\nContent-Length: 1048577\r\n\r\n",
    );
    expect(rejected).toStartWith("HTTP/1.1 413 ");
    const date = /\r\ndate: ([^\r]+)\r\n/i.exec(rejected)?.[1] ?? "";
    expect(Math.abs(Date.parse(date) - Date.now())).toBeLessThanOrEqual(2000);
    await using legacy = await start(legacyBinary);
    const bytes = await raw(legacy.url, "GET / HTTP/1.1\r\nHost: test\r\n\r\n");
    const legacyDate = /\r\ndate: ([^\r]+)\r\n/i.exec(bytes)?.[1] ?? "";
    expect(Math.abs(Date.parse(legacyDate) - Date.now())).toBeLessThanOrEqual(2000);
    expect(Buffer.from(bytes.slice(bytes.indexOf("\r\n\r\n") + 4), "latin1")).toEqual(
      Buffer.from([0, 255, 13, 10, 13, 10, 42]),
    );
  });

  test("Date insertion preserves valid heads larger than 64 KiB and their bodies", async () => {
    await using server = await start(serverBinary);
    const response = await raw(
      server.url,
      "GET /large HTTP/1.1\r\nHost: test\r\nConnection: close\r\n\r\n",
    );
    expect(response).toStartWith("HTTP/1.1 200 OK\r\n");
    expect(response.split("\r\nx: a")).toHaveLength(11001);
    expect(response).toContain("\r\ndate: ");
    expect(response.slice(response.indexOf("\r\n\r\n") + 4)).toBe("hello");
  });

  test("real 200, 404, HEAD and 304 responses have a current Date", async () => {
    await using server = await start(serverBinary);
    for (const [path, method, status] of [
      ["/", "GET", 200],
      ["/missing", "GET", 404],
      ["/", "HEAD", 200],
      ["/cached", "GET", 304],
    ] satisfies [string, string, number][]) {
      const res = await fetch(server.url + path, { method });
      expect(res.status).toBe(status);
      const date = res.headers.get("date");
      expect(date).not.toBeNull();
      expect(Math.abs(Date.parse(date ?? "") - Date.now())).toBeLessThanOrEqual(2000);
      if (method === "HEAD" || status === 304) expect(await res.text()).toBe("");
    }
    const explicit = await fetch(server.url + "/explicit");
    expect(explicit.headers.get("date")).toBe("Sun, 06 Nov 1994 08:49:37 GMT");
  });
});
