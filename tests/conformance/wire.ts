import { connect } from "node:net";

export type ResponseMessage = { status: number; headers: Map<string, string>; body: Buffer };

/** Statuses that decision 0009 says always close the connection. */
const CLOSING = new Set([400, 408, 413, 417, 431]);

type Head = {
  status: number;
  headers: Map<string, string>;
  start: number;
  /** Octets the body would carry for a non-HEAD request; 0 when the status forbids a body. */
  length: number;
  /** True when a HEAD request would also see `length` octets: only when the length is 0. */
  bodyless: boolean;
};

/** Parses one RFC 9112 response head at `offset`. Throws on any framing fault. */
function head(wire: Buffer, offset: number): Head {
  const end = wire.indexOf("\r\n\r\n", offset);
  if (end < 0) throw new Error("truncated response head");
  const lines = wire.subarray(offset, end).toString("latin1").split("\r\n");
  const statusLine = lines.shift() ?? "";
  const match = /^HTTP\/1\.[01] ([1-5][0-9]{2}) [\x20-\x7e]*$/.exec(statusLine);
  if (!match) throw new Error(`invalid status line: ${JSON.stringify(statusLine)}`);
  const status = Number(match[1]);
  const headers = new Map<string, string>();
  for (const line of lines) {
    const field = /^([!#$%&'*+.^_`|~0-9A-Za-z-]+):[ \t]*([\t\x20-\x7e\x80-\xff]*)$/.exec(line);
    if (!field || field[1] === undefined || field[2] === undefined)
      throw new Error(`invalid response field: ${JSON.stringify(line)}`);
    const name = field[1].toLowerCase();
    if (headers.has(name)) throw new Error(`duplicate response field: ${name}`);
    headers.set(name, field[2].trim());
  }
  if (headers.has("transfer-encoding")) throw new Error("unexpected transfer coding");
  const rawLength = headers.get("content-length");
  const forbidden = status < 200 || status === 204;
  if (forbidden && rawLength !== undefined) throw new Error("forbidden Content-Length");
  if (rawLength !== undefined && !/^(0|[1-9][0-9]*)$/.test(rawLength))
    throw new Error("invalid Content-Length");
  if (!forbidden && status !== 304 && rawLength === undefined)
    throw new Error("missing Content-Length");
  const length = forbidden || status === 304 ? 0 : Number(rawLength);
  if (!Number.isSafeInteger(length)) throw new Error("unsafe Content-Length");
  if (CLOSING.has(status) && headers.get("connection") !== "close")
    throw new Error(`${status} must close the connection`);
  return { status, headers, start: end + 4, length, bodyless: length === 0 };
}

function message(wire: Buffer, parsed: Head, length: number): ResponseMessage {
  if (parsed.start + length > wire.length) throw new Error("truncated response body");
  const body = wire.subarray(parsed.start, parsed.start + length);
  return { status: parsed.status, headers: parsed.headers, body };
}

function closes(response: ResponseMessage): boolean {
  return response.headers.get("connection") === "close";
}

/**
 * Independent RFC 9112 buffered-response oracle. No Bend parser or fetch
 * normalization. `methods` lists the request method for each final response.
 */
export function responses(wire: Buffer, methods: readonly string[] = []): ResponseMessage[] {
  const result: ResponseMessage[] = [];
  let offset = 0;
  let request = 0;
  while (offset < wire.length) {
    const last = result.at(-1);
    if (last && closes(last)) throw new Error("bytes after a closing response");
    const parsed = head(wire, offset);
    const length = methods[request] === "HEAD" ? 0 : parsed.length;
    const response = message(wire, parsed, length);
    result.push(response);
    offset = parsed.start + length;
    if (parsed.status >= 200) request++;
  }
  return result;
}

/**
 * The same oracle for unknown request methods, as in fuzzing. Each response
 * with a nonzero length may answer GET (body follows) or HEAD (no body); the
 * whole buffer must parse under some choice, so neither split can hide junk.
 */
export function framedResponses(wire: Buffer): ResponseMessage[] {
  const failed = new Set<number>();
  let fault = "";
  function from(offset: number, closed: boolean): ResponseMessage[] | undefined {
    if (offset === wire.length) return [];
    if (closed) {
      fault = "bytes after a closing response";
      return undefined;
    }
    if (failed.has(offset)) return undefined;
    let parsed: Head;
    try {
      parsed = head(wire, offset);
    } catch (error) {
      fault = error instanceof Error ? error.message : String(error);
      failed.add(offset);
      return undefined;
    }
    for (const length of parsed.bodyless ? [0] : [parsed.length, 0]) {
      if (parsed.start + length > wire.length) continue;
      const response = message(wire, parsed, length);
      const rest = from(parsed.start + length, closes(response));
      if (rest) return [response, ...rest];
    }
    if (!fault) fault = "truncated response body";
    failed.add(offset);
    return undefined;
  }
  const result = from(0, false);
  if (!result) throw new Error(fault);
  return result;
}

export function request({
  path = "/text",
  method = "GET",
  headers = "",
  close = true,
}: { path?: string; method?: string; headers?: string; close?: boolean } = {}): Buffer {
  return Buffer.from(
    `${method} ${path} HTTP/1.1\r\nHost: x\r\n${close ? "Connection: close\r\n" : ""}${headers}\r\n`,
    "latin1",
  );
}

export type Outcome =
  | { kind: "eof"; bytes: Buffer }
  | { kind: "timeout"; bytes: Buffer }
  | { kind: "error"; message: string; bytes: Buffer };

/**
 * Writes `parts` with `pauseMs` between them, then reads to EOF. The absolute
 * deadline covers connect, paced writes, the response and EOF; output is capped.
 */
export function exchangeOutcome({
  url,
  parts,
  pauseMs = 0,
  halfClose = true,
  deadlineMs = 5000,
  limit = 4_000_000,
}: {
  url: string;
  parts: readonly Uint8Array[];
  pauseMs?: number;
  halfClose?: boolean;
  deadlineMs?: number;
  limit?: number;
}): Promise<Outcome> {
  return new Promise((resolve) => {
    const address = new URL(url);
    const socket = connect(Number(address.port), address.hostname);
    socket.setNoDelay(true);
    const received: Buffer[] = [];
    let bytes = 0;
    const finish = (outcome: Outcome) => {
      clearTimeout(deadline);
      resolve(outcome);
      socket.destroy();
    };
    const deadline = setTimeout(
      () => finish({ kind: "timeout", bytes: Buffer.concat(received) }),
      deadlineMs,
    );
    socket.on("error", (error) =>
      finish({ kind: "error", message: error.message, bytes: Buffer.concat(received) }),
    );
    socket.on("data", (chunk: Buffer) => {
      bytes += chunk.length;
      received.push(chunk);
      if (bytes > limit)
        finish({ kind: "error", message: "response output limit", bytes: Buffer.concat(received) });
    });
    socket.on("end", () => finish({ kind: "eof", bytes: Buffer.concat(received) }));
    socket.on("connect", () => {
      void (async () => {
        for (const [index, part] of parts.entries()) {
          if (socket.destroyed || socket.writableEnded) return;
          socket.write(part);
          if (pauseMs && index + 1 < parts.length) await Bun.sleep(pauseMs);
        }
        if (halfClose && !socket.destroyed) socket.end();
      })();
    });
  });
}

/** Like `exchangeOutcome`, but anything other than EOF before the deadline is an error. */
export async function exchange(options: Parameters<typeof exchangeOutcome>[0]): Promise<Buffer> {
  const outcome = await exchangeOutcome(options);
  switch (outcome.kind) {
    case "eof":
      return outcome.bytes;
    case "timeout":
      throw new Error(`absolute socket deadline after ${outcome.bytes.length} octets`);
    case "error":
      throw new Error(`${outcome.message} after ${outcome.bytes.length} octets`);
    default: {
      const exhaustive: never = outcome;
      return exhaustive;
    }
  }
}

export async function closed(url: string, wire: Buffer, methods: readonly string[] = []) {
  const parsed = responses(await exchange({ url, parts: [wire] }), methods);
  const last = parsed.at(-1);
  if (!last || !closes(last)) throw new Error("final response must advertise Connection: close");
  return parsed;
}
