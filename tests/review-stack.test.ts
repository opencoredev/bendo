import { expect, test } from "bun:test";
import { createHmac } from "node:crypto";
import { pathToFileURL } from "node:url";
import { compile, SLOW_TEST_TIMEOUT_MS } from "./harness.ts";

const entry = "tests/fixtures/review-stack/consumer.bend";
const native = compile(entry, "native");
const mjs = compile(entry, "mjs");
const module: unknown = await import(pathToFileURL(mjs).href);
if (typeof module !== "object" || module === null || !("default" in module)) {
  throw new Error("Missing compiled Bend exports");
}
const api: unknown = module.default;
if (
  typeof api !== "object" ||
  api === null ||
  !("probe" in api) ||
  typeof api.probe !== "function"
) {
  throw new Error("Missing compiled Bend probe");
}
const probe = api.probe;
const size = 65536;
function signed(claim: string, whole: string, fraction: string): string {
  const head = Buffer.from('{"alg":"HS256","typ":"JWT"}').toString("base64url");
  const body = Buffer.from(`{"${claim}":${whole}.${fraction}}`).toString("base64url");
  const message = `${head}.${body}`;
  return `${message}.${createHmac("sha256", "review-secret").update(message).digest("base64url")}`;
}
const vectors = [
  ...["exp", "nbf", "iat"].flatMap((claim) => [
    {
      name: `signed JWT ${claim} nonzero fraction`,
      mode: "jwt",
      input: signed(claim, claim === "exp" ? "100" : "99", `${"0".repeat(48000)}1`),
      expected: "ok",
    },
    {
      name: `signed JWT ${claim} zero fraction`,
      mode: "jwt",
      input: signed(claim, claim === "exp" ? "101" : "100", "0".repeat(48000)),
      expected: "ok",
    },
  ]),
  {
    name: "signed JWT long whole with negative exponent",
    mode: "jwt",
    input: signed("exp", "1".repeat(48000), "0e-1"),
    expected: "ok",
  },
  {
    name: "signed JWT clamped positive exponent",
    mode: "jwt",
    input: signed("exp", "1", "0e99999"),
    expected: "ok",
  },
  {
    name: "proxy long Connection option",
    mode: "proxy-connection",
    input: "A".repeat(size),
    expected: "2",
  },
  {
    name: "proxy blank Connection options",
    mode: "proxy-connection",
    input: " ".repeat(size),
    expected: "2",
  },
  {
    name: "proxy many Connection options and membership",
    mode: "proxy-connection",
    input: `${"a,".repeat(32760)}x-drop`,
    expected: "1",
  },
  {
    name: "proxy many empty Connection options",
    mode: "proxy-connection",
    input: `${",".repeat(65530)}x-drop`,
    expected: "1",
  },
  {
    name: "proxy quoted request Host",
    mode: "proxy-host",
    input: 'a"\\Z'.repeat(size / 4),
    expected: `for=unknown;host="${'a\\"\\\\Z'.repeat(size / 4)}";proto=http`,
  },
  {
    name: "proxy many request fields",
    mode: "proxy-fields",
    input: `GET / HTTP/1.1\r\n${"a:\r\n".repeat(16000)}\r\n`,
    expected: String(
      Buffer.byteLength(
        `GET / HTTP/1.1\r\nhost: 127.0.0.1\r\n${"a: \r\n".repeat(16000)}x-forwarded-proto: http\r\nconnection: close\r\n\r\n`,
      ),
    ),
  },
  {
    name: "proxy trusted forwarding chain",
    mode: "proxy-trusted",
    input: `GET / HTTP/1.1\r\n${"x-forwarded-proto:\r\n".repeat(3200)}\r\n`,
    expected: `${", ".repeat(3200)}http`,
  },
  {
    name: "upstream equal framing lengths",
    mode: "proxy-lengths",
    input: `${"0,".repeat(32767)}0`,
    expected: "fixed:0",
  },
  {
    name: "upstream unequal framing lengths",
    mode: "proxy-lengths",
    input: `${"0,".repeat(32767)}1`,
    expected: "invalid",
  },
  {
    name: "upstream dense transfer codings",
    mode: "proxy-codings",
    input: `${",".repeat(65529)}chunked`,
    expected: "chunks",
  },
  {
    name: "WebSocket real handshake dense offers",
    mode: "websocket",
    input: `${",".repeat(65523)}upgrade,chat`,
    expected: "accept",
  },
];
for (const vector of vectors) {
  test(
    `.mjs default stack ${vector.name}`,
    () => {
      expect(probe(vector.mode, vector.input)).toBe(vector.expected);
    },
    SLOW_TEST_TIMEOUT_MS,
  );
  test(
    `Node .mjs default stack ${vector.name}`,
    () => {
      const run = Bun.spawnSync(
        [
          "node",
          "tests/fixtures/review-stack/run.mjs",
          pathToFileURL(mjs).href,
          vector.mode,
          vector.input,
        ],
        { stdout: "pipe", stderr: "pipe", timeout: 30000 },
      );
      expect(run.exitCode, run.stderr.toString()).toBe(0);
      expect(run.stdout.toString()).toBe(`${vector.expected}\n`);
    },
    SLOW_TEST_TIMEOUT_MS,
  );
  test(
    `native ${vector.name}`,
    () => {
      const run = Bun.spawnSync([native, vector.mode, vector.input], {
        stdout: "pipe",
        stderr: "pipe",
        timeout: 30000,
      });
      expect(run.exitCode, run.stderr.toString()).toBe(0);
      expect(run.stdout.toString()).toBe(`${vector.expected}\n`);
    },
    SLOW_TEST_TIMEOUT_MS,
  );
}
if (!("middleware_probe" in api) || typeof api.middleware_probe !== "function") {
  throw new Error("Missing compiled middleware probe");
}
const middlewareProbe = api.middleware_probe;
for (const target of ["mjs", "node", "native"]) {
  for (const vector of [
    {
      name: "unrelated form fields",
      mode: "override-form",
      input: `${"x=0&".repeat(16380)}_method=PUT`,
      expected: "200:PUT",
    },
    {
      name: "repeated override form values",
      mode: "override-form",
      input: "_method=PUT&".repeat(5400),
      expected: "400:Bad Request",
    },
    {
      name: "repeated override headers",
      mode: "override-headers",
      input: `POST / HTTP/1.1\r\n${"x:\r\n".repeat(16000)}\r\n`,
      expected: "400:Bad Request",
    },
  ]) {
    test(
      `${target} real middleware ${vector.name}`,
      () => {
        if (target === "mjs") {
          const io: unknown = middlewareProbe(vector.mode, vector.input);
          if (typeof io !== "function") throw new Error("Expected IO continuation");
          const result: unknown = io((value: unknown) => value);
          expect(result).toBe(vector.expected);
          return;
        }
        const run = Bun.spawnSync(
          target === "node"
            ? [
                "node",
                "tests/fixtures/review-stack/run.mjs",
                pathToFileURL(mjs).href,
                vector.mode,
                vector.input,
              ]
            : [native, vector.mode, vector.input],
          {
            stdout: "pipe",
            stderr: "pipe",
            timeout: 30000,
          },
        );
        expect(run.exitCode, run.stderr.toString()).toBe(0);
        expect(run.stdout.toString()).toBe(`${vector.expected}\n`);
      },
      SLOW_TEST_TIMEOUT_MS,
    );
  }
}
