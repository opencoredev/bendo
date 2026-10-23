// Robustness fuzzer for the HTTP/1.1 server (BND-13). It sends generated and
// mutated requests to the conformance fixture and fails on a crash, a hang, or
// a response the independent oracle in tests/conformance/wire.ts rejects.
// Usage and recorded runs: docs/http-conformance.md.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { parseArgs } from "node:util";
import { build } from "../tests/harness.ts";
import { exchangeOutcome, framedResponses } from "../tests/conformance/wire.ts";

export const FIXTURE = "tests/fixtures/http-conformance/server.bend";

/** The fixture's slowest close is a 700 ms deadline plus the 1 s drain; leave room for load. */
const CASE_DEADLINE_MS = 10_000;

type Rng = { next: () => number };

/** mulberry32: small, fast and identical on every platform. */
function rng(seed: number): Rng {
  let state = seed >>> 0;
  return {
    next() {
      state = (state + 0x6d2b79f5) >>> 0;
      let t = state;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    },
  };
}

/** Each case has its own stream, so `--case N` replays case N alone. */
function caseRng(seed: number, index: number): Rng {
  return rng(Math.imul(seed ^ 0x9e3779b9, 0x85ebca6b) ^ Math.imul(index + 1, 0xc2b2ae35));
}

const int = (r: Rng, below: number) => Math.floor(r.next() * below);
const chance = (r: Rng, p: number) => r.next() < p;
function pick<T>(r: Rng, items: readonly [T, ...T[]]): T {
  return items[int(r, items.length)] ?? items[0];
}

const TCHAR = "!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
const PCHAR = "abcxyz0123456789-._~!$&'()*+,;=:@/";
const INTERESTING = [0, 9, 10, 11, 13, 32, 34, 44, 58, 59, 127, 128, 255] as const;

function chars(r: Rng, alphabet: string, length: number): string {
  let out = "";
  for (let i = 0; i < length; i++) out += alphabet[int(r, alphabet.length)] ?? "";
  return out;
}

function bytes(r: Rng, length: number): Buffer {
  return Buffer.from(Array.from({ length }, () => int(r, 256)));
}

function hugeNumber(r: Rng): string {
  return pick(r, [
    "4294967295",
    "4294967296",
    "18446744073709551616",
    "9".repeat(1 + int(r, 60)),
    `0${"0".repeat(int(r, 30))}1`,
  ]);
}

/** Picks one generator and runs only that one, so unused alternatives cost nothing. */
function oneOf<T>(r: Rng, makers: readonly [() => T, ...(() => T)[]]): T {
  return pick(r, makers)();
}

// Each generated request is valid, or breaks exactly one part of the grammar.
// Mutation and pipelines add the compound damage.
type Fault = "none" | "method" | "target" | "version" | "field" | "framing" | "body" | "size";

function method(r: Rng, bad: boolean): string {
  if (!bad)
    return pick(r, [
      "GET",
      "GET",
      "GET",
      "HEAD",
      "POST",
      "POST",
      "POST",
      "PUT",
      "DELETE",
      "OPTIONS",
      "PATCH",
      "get",
      "BREW",
    ]);
  return oneOf(r, [
    () => "",
    () => "G(ET",
    () => bytes(r, 1 + int(r, 6)).toString("latin1"),
    () => `${chars(r, TCHAR, 1 + int(r, 6))} ${chars(r, TCHAR, 1 + int(r, 6))}`,
  ]);
}

function target(r: Rng, bad: boolean): string {
  if (!bad)
    return oneOf(r, [
      () => pick(r, ["/", "/text", "/text", "/echo", "/echo", "/chunked", "/summary", "/summary"]),
      () => pick(r, ["/summary?x=1&y", "/missing", "*", "/%41%2f", "/echo?"]),
      () => `/${chars(r, PCHAR, int(r, 40))}`,
    ]);
  return oneOf(r, [
    () => pick(r, ["/%zz", "/a#b", "/a\\b", "http://x/text", "x:80", "", "/a b"]),
    () => `/${chars(r, PCHAR, 8200 + int(r, 2000))}`,
    () => `/${bytes(r, 1 + int(r, 10)).toString("latin1")}`,
  ]);
}

function version(r: Rng, bad: boolean): string {
  if (!bad) return chance(r, 0.9) ? "HTTP/1.1" : "HTTP/1.0";
  return pick(r, ["HTTP/2.0", "HTTP/1.10", "http/1.1", "HTTP/1", "HTTP/1.1 ", "", "HTTP/1.1\0"]);
}

function fieldValue(r: Rng, bad: boolean): string {
  if (!bad) return chars(r, `${TCHAR} ,;="/\t\x80\xff`, int(r, 30)).trim();
  return bytes(r, 1 + int(r, 20)).toString("latin1");
}

function field(r: Rng, bad: boolean): string {
  if (!bad)
    return oneOf(r, [
      () => `X-${chars(r, TCHAR, 1 + int(r, 10))}: ${fieldValue(r, false)}`,
      () => `${chars(r, TCHAR, 1 + int(r, 10))}:${fieldValue(r, false)}`,
      () => `Connection: ${pick(r, ["close", "keep-alive", "Close, x", "x"])}`,
      () => "Expect: 100-continue",
    ]);
  return oneOf(r, [
    () => `X-${chars(r, TCHAR, 1 + int(r, 10))}: ${fieldValue(r, true)}`,
    () => pick(r, ["X : a", ": a", "X", " folded", "X Y: a", "Expect: kittens"]),
    () => `X-Big: ${"b".repeat(8200 + int(r, 2000))}`,
  ]);
}

type Framing =
  | { kind: "none" }
  | { kind: "length"; fields: string[]; actual: number }
  | { kind: "chunked"; fields: string[] };

function framing(r: Rng, bad: boolean, size: boolean): Framing {
  const roll = r.next();
  if (!bad && roll < 0.35) return { kind: "none" };
  if (roll < 0.65) {
    const actual = size ? 16_385 + int(r, 2000) : int(r, 300);
    if (!bad) return { kind: "length", fields: [`Content-Length: ${actual}`], actual };
    const declared = oneOf(r, [
      () => pick(r, [`+${actual}`, `${actual}, ${actual}`, "", `${actual} 1`, "-1", `0x${actual}`]),
      () => hugeNumber(r),
      () => String(actual + 1 + int(r, 5)),
    ]);
    return oneOf(r, [
      () => ({ kind: "length", fields: [`Content-Length: ${declared}`], actual }),
      () => ({
        kind: "length",
        fields: [
          `Content-Length: ${actual}`,
          `Content-Length: ${pick(r, [String(actual), declared])}`,
        ],
        actual,
      }),
      () => ({
        kind: "length",
        fields: [`Content-Length: ${actual}`, "Transfer-Encoding: chunked"],
        actual,
      }),
    ]);
  }
  if (!bad)
    return {
      kind: "chunked",
      fields: [`Transfer-Encoding: ${pick(r, ["chunked", "Chunked", "CHUNKED"])}`],
    };
  return oneOf(r, [
    () => ({
      kind: "chunked",
      fields: [
        `Transfer-Encoding: ${pick(r, ["gzip, chunked", "chunked, chunked", "chunked, gzip", "identity", "", "xchunked", "\x0bchunked"])}`,
      ],
    }),
    () => ({
      kind: "chunked",
      fields: ["Transfer-Encoding: chunked", `Content-Length: ${int(r, 20)}`],
    }),
    () => ({
      kind: "chunked",
      fields: ["Transfer-Encoding: chunked", "Transfer-Encoding: chunked"],
    }),
  ]);
}

function chunkedBody(r: Rng, bad: boolean, size: boolean): Buffer {
  const parts: Buffer[] = [];
  const chunks = size ? 2 : int(r, 5);
  const broken = bad ? int(r, chunks + 1) : -1;
  for (let i = 0; i < chunks; i++) {
    const data = bytes(r, size ? 9000 : int(r, 100));
    let size_ = data.length.toString(16);
    let extension = chance(r, 0.2) ? pick(r, [";a=b", ';a="q\\"x"', `;${chars(r, TCHAR, 8)}`]) : "";
    let end = "\r\n";
    if (i === broken)
      oneOf(r, [
        () =>
          (size_ = pick(r, [
            hugeNumber(r),
            "ffffffffffffffff",
            `0x${size_}`,
            "",
            ` ${size_}`,
            "g",
          ])),
        () => (extension = pick(r, [";", ";=", ';a="x', "; a"])),
        () => (end = pick(r, ["\n", "", "x\r\n"])),
      ]);
    parts.push(Buffer.from(`${size_}${extension}\r\n`, "latin1"), data, Buffer.from(end));
  }
  parts.push(Buffer.from("0\r\n"));
  if (chance(r, 0.2)) parts.push(Buffer.from(`X-Trailer: ${fieldValue(r, false)}\r\n`, "latin1"));
  if (broken === chunks)
    parts.push(
      Buffer.from(
        pick(r, ["Content-Length: 1\r\n", " folded\r\n", `X-Big: ${"t".repeat(9000)}\r\n`]),
      ),
    );
  parts.push(Buffer.from("\r\n"));
  return Buffer.concat(parts);
}

type Route = readonly [method: string, path: string];
const ROUTES: readonly [Route, ...Route[]] = [
  ["GET", "/text"],
  ["HEAD", "/text"],
  ["GET", "/"],
  ["POST", "/echo"],
  ["POST", "/chunked"],
  ["POST", "/summary"],
];

/** One request from the HTTP grammar: valid, or with exactly one fault. */
function generated(r: Rng): Buffer {
  const fault: Fault = chance(r, 0.55)
    ? "none"
    : pick(r, ["method", "target", "version", "field", "framing", "body", "size"]);
  // Most valid requests hit a route, so handlers and responses get exercised too.
  const routed = fault === "none" || fault === "body" || fault === "size" || fault === "framing";
  const [verb, path] =
    routed && chance(r, 0.7)
      ? pick(r, ROUTES)
      : [method(r, fault === "method"), target(r, fault === "target")];
  const lines = [`${verb} ${path} ${version(r, fault === "version")}`];
  const frame = framing(r, fault === "framing", fault === "size");
  const fields = ["Host: x", ...(frame.kind === "none" ? [] : frame.fields)];
  const count = fault === "size" && chance(r, 0.3) ? 1500 : int(r, 6);
  for (let i = 0; i < count; i++) fields.push(field(r, false));
  if (fault === "field") fields.push(field(r, true));
  for (const line of fields) lines.splice(1 + int(r, lines.length), 0, line);
  const head = Buffer.from(`${lines.join("\r\n")}\r\n\r\n`, "latin1");
  switch (frame.kind) {
    case "none":
      return head;
    case "length":
      return Buffer.concat([head, bytes(r, frame.actual)]);
    case "chunked":
      return Buffer.concat([head, chunkedBody(r, fault === "body", fault === "size")]);
    default: {
      const exhaustive: never = frame;
      return exhaustive;
    }
  }
}

function replaceRandom(r: Rng, wire: Buffer, needle: string, replacement: string): Buffer {
  const hits: number[] = [];
  for (let at = wire.indexOf(needle); at >= 0; at = wire.indexOf(needle, at + 1)) hits.push(at);
  if (hits.length === 0) return wire;
  const at = hits[int(r, hits.length)] ?? 0;
  return Buffer.concat([
    wire.subarray(0, at),
    Buffer.from(replacement, "latin1"),
    wire.subarray(at + needle.length),
  ]);
}

/** Byte-level mutation of a generated request. */
function mutate(r: Rng, wire: Buffer): Buffer {
  let out: Buffer = Buffer.from(wire);
  const rounds = 1 + int(r, chance(r, 0.7) ? 2 : 8);
  for (let i = 0; i < rounds; i++) {
    const at = int(r, out.length + 1);
    switch (int(r, 9)) {
      case 0: {
        if (out.length === 0) break;
        const index = Math.min(at, out.length - 1);
        out[index] = (out[index] ?? 0) ^ (1 << int(r, 8));
        break;
      }
      case 1: {
        if (out.length === 0) break;
        out[Math.min(at, out.length - 1)] = pick(r, INTERESTING);
        break;
      }
      case 2:
        out = Buffer.concat([out.subarray(0, at), bytes(r, 1 + int(r, 8)), out.subarray(at)]);
        break;
      case 3:
        out = Buffer.concat([
          out.subarray(0, at),
          out.subarray(Math.min(out.length, at + 1 + int(r, 16))),
        ]);
        break;
      case 4: {
        const length = 1 + int(r, 64);
        out = Buffer.concat([out.subarray(0, at + length), out.subarray(at)]);
        break;
      }
      case 5: {
        const donor = generated(r);
        const from = int(r, donor.length + 1);
        out = Buffer.concat([
          out.subarray(0, at),
          donor.subarray(from, from + 1 + int(r, 200)),
          out.subarray(at),
        ]);
        break;
      }
      case 6:
        out = replaceRandom(
          r,
          out,
          "\r\n",
          pick(r, ["\n", "\r", "\r\r\n", "\n\r", "\r\n\r\n", " \r\n", "\r\n "]),
        );
        break;
      case 7: {
        const digits = /[0-9a-fA-F]+/g;
        const runs = [...out.toString("latin1").matchAll(digits)];
        const run = runs[int(r, runs.length)];
        if (!run || run.index === undefined) break;
        out = Buffer.concat([
          out.subarray(0, run.index),
          Buffer.from(hugeNumber(r)),
          out.subarray(run.index + run[0].length),
        ]);
        break;
      }
      default:
        out = out.subarray(0, at);
    }
  }
  return out;
}

export type Case = {
  index: number;
  kind: "generated" | "pipeline" | "mutated" | "random";
  parts: Buffer[];
  pauseMs: number;
  halfClose: boolean;
};

/** Builds case `index` deterministically from `seed`. */
export function makeCase(seed: number, index: number): Case {
  const r = caseRng(seed, index);
  const roll = r.next();
  let kind: Case["kind"];
  let wire: Buffer;
  if (roll < 0.3) {
    kind = "generated";
    wire = generated(r);
  } else if (roll < 0.45) {
    kind = "pipeline";
    wire = Buffer.concat(
      Array.from({ length: 2 + int(r, 9) }, () =>
        chance(r, 0.8) ? generated(r) : mutate(r, generated(r)),
      ),
    );
  } else if (roll < 0.95) {
    kind = "mutated";
    wire = mutate(r, generated(r));
  } else {
    kind = "random";
    wire = bytes(r, int(r, 600));
  }
  const splits = chance(r, 0.05) && wire.length < 200 ? wire.length : int(r, 6);
  const cuts = new Set<number>();
  for (let i = 0; i < splits; i++) cuts.add(int(r, wire.length + 1));
  const sorted = [0, ...[...cuts].sort((a, b) => a - b), wire.length];
  const parts = sorted.slice(1).map((end, i) => wire.subarray(sorted[i] ?? 0, end));
  return { index, kind, parts, pauseMs: int(r, 3), halfClose: !chance(r, 0.03) };
}

export type Failure = { reason: string; case?: Case; output?: Buffer };

export type Report = {
  seed: number;
  cases: number;
  elapsedMs: number;
  kinds: Record<Case["kind"], number>;
  outcomes: { eof: number; reset: number };
  statuses: Record<string, number>;
  healthChecks: number;
  maxRssKiB: number;
  failure?: Failure;
};

type Server = {
  url: string;
  pid: number;
  exited: () => string | undefined;
  stop: () => Promise<void>;
};

/** One readiness probe waits at most this long, so later probes still fit the budget. */
const PROBE_MS = 2000;

/** `startupMs` bounds the whole start, including retries on a busy port. */
async function launch(command: readonly string[], startupMs: number): Promise<Server> {
  const deadline = Date.now() + startupMs;
  for (let attempt = 0; attempt < 3 && Date.now() < deadline; attempt++) {
    const port = 20000 + Math.floor(Math.random() * 20000);
    const proc = Bun.spawn([...command], {
      env: { ...process.env, PORT: String(port) },
      stdout: "pipe",
      stderr: "pipe",
    });
    let exit: string | undefined;
    void proc.exited.then(async (code) => {
      exit = `exit ${code} signal ${proc.signalCode}: ${(await new Response(proc.stderr).text()).trim()}`;
    });
    const url = `http://127.0.0.1:${port}`;
    while (Date.now() < deadline && exit === undefined) {
      // A server that accepts TCP but never answers must not outlive the deadline.
      const signal = AbortSignal.timeout(Math.max(1, Math.min(PROBE_MS, deadline - Date.now())));
      if (
        await fetch(`${url}/text`, { signal })
          .then((response) => response.arrayBuffer())
          .then(
            () => true,
            () => false,
          )
      )
        return {
          url,
          pid: proc.pid,
          exited: () => exit,
          stop: async () => {
            proc.kill();
            await proc.exited;
          },
        };
      await Bun.sleep(50);
    }
    proc.kill();
    await proc.exited;
  }
  throw new Error(`fuzz server did not answer within ${startupMs} ms`);
}

function rssKiB(pid: number): number {
  try {
    const match = /VmRSS:\s+(\d+) kB/.exec(readFileSync(`/proc/${pid}/status`, "utf8"));
    return match ? Number(match[1]) : 0;
  } catch {
    return 0;
  }
}

async function healthy(url: string, deadlineMs: number): Promise<string | undefined> {
  const outcome = await exchangeOutcome({
    url,
    parts: [Buffer.from("GET /text HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n")],
    deadlineMs,
  });
  if (outcome.kind !== "eof") return `health check ${outcome.kind}`;
  try {
    const [response] = framedResponses(outcome.bytes);
    if (response?.status === 200 && response.body.toString() === "conformance") return undefined;
    return `health check answered ${response?.status}`;
  } catch (error) {
    return `health check: ${error instanceof Error ? error.message : String(error)}`;
  }
}

type CaseResult =
  | { kind: "ok"; reset: boolean; statuses: number[] }
  | { kind: "fail"; reason: string; output: Buffer };

/** Everything received, even before a reset, must be whole, well-framed responses. */
function framed(bytes: Buffer, reset: boolean): CaseResult {
  try {
    return { kind: "ok", reset, statuses: framedResponses(bytes).map((r) => r.status) };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      kind: "fail",
      reason: `ill-framed response${reset ? " before reset" : ""}: ${message}`,
      output: bytes,
    };
  }
}

/** Runs one case; returns a failure reason or the statuses it saw. */
async function runCase(url: string, item: Case, deadlineMs: number): Promise<CaseResult> {
  const outcome = await exchangeOutcome({
    url,
    parts: item.parts,
    pauseMs: item.pauseMs,
    halfClose: item.halfClose,
    deadlineMs,
  });
  switch (outcome.kind) {
    case "timeout":
      return {
        kind: "fail",
        reason: `hang: no EOF within ${deadlineMs} ms`,
        output: outcome.bytes,
      };
    case "error":
      // A reset after the server closes still counts as closing the connection.
      if (!/ECONNRESET|EPIPE/.test(outcome.message))
        return { kind: "fail", reason: outcome.message, output: outcome.bytes };
      return framed(outcome.bytes, true);
    case "eof":
      return framed(outcome.bytes, false);
    default: {
      const exhaustive: never = outcome;
      return exhaustive;
    }
  }
}

export async function fuzz({
  seed,
  cases = Number.POSITIVE_INFINITY,
  minutes = Number.POSITIVE_INFINITY,
  concurrency = 8,
  healthEvery = 100,
  only,
  binary,
  command = [binary ?? build(FIXTURE)],
  caseDeadlineMs = CASE_DEADLINE_MS,
  startupMs = 20_000,
  progress,
}: {
  seed: number;
  cases?: number;
  minutes?: number;
  concurrency?: number;
  healthEvery?: number;
  only?: number;
  binary?: string;
  /** Overrides `binary`: the command that starts the server, which listens on $PORT. */
  command?: readonly string[];
  caseDeadlineMs?: number;
  startupMs?: number;
  progress?: (report: Report) => void;
}): Promise<Report> {
  const server = await launch(command, startupMs);
  const started = Date.now();
  const stopAt = started + minutes * 60_000;
  const report: Report = {
    seed,
    cases: 0,
    elapsedMs: 0,
    kinds: { generated: 0, pipeline: 0, mutated: 0, random: 0 },
    outcomes: { eof: 0, reset: 0 },
    statuses: {},
    healthChecks: 0,
    maxRssKiB: rssKiB(server.pid),
  };
  let next = only ?? 0;
  const last = only === undefined ? cases : only + 1;
  let health = Promise.resolve();
  const fail = (failure: Failure) => {
    report.failure ??= failure;
  };
  async function worker() {
    while (!report.failure && next < last && Date.now() < stopAt) {
      const item = makeCase(seed, next++);
      const result = await runCase(server.url, item, caseDeadlineMs);
      const exit = server.exited();
      if (exit !== undefined) return fail({ reason: `server crashed: ${exit}`, case: item });
      if (result.kind === "fail")
        return fail({ reason: result.reason, case: item, output: result.output });
      report.cases++;
      report.kinds[item.kind]++;
      report.outcomes[result.reset ? "reset" : "eof"]++;
      for (const status of result.statuses)
        report.statuses[status] = (report.statuses[status] ?? 0) + 1;
      if (report.cases % healthEvery === 0) {
        health = health.then(async () => {
          const problem = await healthy(server.url, caseDeadlineMs);
          report.healthChecks++;
          report.maxRssKiB = Math.max(report.maxRssKiB, rssKiB(server.pid));
          if (problem) fail({ reason: problem });
          progress?.({ ...report, elapsedMs: Date.now() - started });
        });
        await health;
      }
    }
  }
  try {
    await Promise.all(Array.from({ length: concurrency }, worker));
    await health;
    if (!report.failure) {
      const problem = await healthy(server.url, caseDeadlineMs);
      report.healthChecks++;
      if (problem) fail({ reason: problem });
    }
    const exit = server.exited();
    if (exit !== undefined) fail({ reason: `server crashed: ${exit}` });
    report.maxRssKiB = Math.max(report.maxRssKiB, rssKiB(server.pid));
  } finally {
    report.elapsedMs = Date.now() - started;
    await server.stop();
  }
  return report;
}

function summary(report: Report): string {
  const { failure, ...rest } = report;
  return JSON.stringify({
    ...rest,
    result: failure ? "FAIL" : "PASS",
    ...(failure && {
      failure: {
        reason: failure.reason,
        case: failure.case && {
          index: failure.case.index,
          kind: failure.case.kind,
          pauseMs: failure.case.pauseMs,
          halfClose: failure.case.halfClose,
          parts: failure.case.parts.map((p) => p.toString("base64")),
        },
        output: failure.output?.toString("latin1").slice(0, 2000),
      },
    }),
  });
}

if (import.meta.main) {
  const { values } = parseArgs({
    options: {
      seed: { type: "string" },
      minutes: { type: "string" },
      cases: { type: "string" },
      case: { type: "string" },
      concurrency: { type: "string", default: "8" },
    },
  });
  const number = (name: string, raw: string | undefined): number | undefined => {
    if (raw === undefined) return undefined;
    if (!/^[0-9]+(\.[0-9]+)?$/.test(raw)) throw new Error(`--${name} must be a number`);
    return Number(raw);
  };
  const seed = number("seed", values.seed) ?? Math.floor(Math.random() * 2 ** 31);
  const minutes = number("minutes", values.minutes);
  const cases = number("cases", values.cases);
  const only = number("case", values.case);
  if (minutes === undefined && cases === undefined && only === undefined)
    throw new Error("pass --minutes, --cases or --case");
  console.info(`fuzz-http seed ${seed}`);
  const report = await fuzz({
    seed,
    concurrency: number("concurrency", values.concurrency) ?? 8,
    ...(minutes !== undefined && { minutes }),
    ...(cases !== undefined && { cases }),
    ...(only !== undefined && { only }),
    progress: (r) => {
      if (r.healthChecks % 20 === 0) console.info(summary(r));
    },
  });
  console.info(summary(report));
  if (report.failure) {
    mkdirSync(".cache/fuzz", { recursive: true });
    const path = `.cache/fuzz/failure-${seed}-${report.failure.case?.index ?? "health"}.json`;
    writeFileSync(path, summary(report));
    console.error(`failure saved to ${path}`);
    process.exit(1);
  }
}
