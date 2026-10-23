import { connect } from "node:net";

export type ResponseMessage = { status: number; headers: Map<string, string>; body: Buffer };

/** Independent RFC 9112 buffered-response oracle. No Bend parser or fetch normalization. */
export function responses(wire: Buffer, methods: readonly string[] = []): ResponseMessage[] {
  const result: ResponseMessage[] = [];
  let offset = 0;
  let request = 0;
  while (offset < wire.length) {
    const end = wire.indexOf("\r\n\r\n", offset);
    if (end < 0) throw new Error("truncated response head");
    const lines = wire.subarray(offset, end).toString("latin1").split("\r\n");
    const statusLine = lines.shift() ?? "";
    const match = /^HTTP\/1\.[01] ([1-5][0-9]{2}) [\x20-\x7e]*$/.exec(statusLine);
    if (!match) throw new Error(`invalid status line: ${statusLine}`);
    const status = Number(match[1]);
    const headers = new Map<string, string>();
    for (const line of lines) {
      const field = /^([!#$%&'*+.^_`|~0-9A-Za-z-]+):[ \t]*([\t\x20-\x7e\x80-\xff]*)$/.exec(line);
      if (!field || field[1] === undefined || field[2] === undefined)
        throw new Error(`invalid response field: ${line}`);
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
    const noBody = forbidden || status === 304 || methods[request] === "HEAD";
    if (!noBody && rawLength === undefined) throw new Error("missing Content-Length");
    const length = noBody ? 0 : Number(rawLength);
    if (!Number.isSafeInteger(length) || length < 0) throw new Error("unsafe Content-Length");
    const start = end + 4;
    if (start + length > wire.length) throw new Error("truncated response body");
    result.push({ status, headers, body: wire.subarray(start, start + length) });
    offset = start + length;
    if (status >= 200) request++;
  }
  return result;
}

export function request({ path = "/text", method = "GET", headers = "", close = true } = {}): Buffer {
  return Buffer.from(`${method} ${path} HTTP/1.1\r\nHost: x\r\n${close ? "Connection: close\r\n" : ""}${headers}\r\n`, "latin1");
}

/** Absolute deadline includes connect, paced writes, response and EOF; capped output. */
export function exchange({
  url,
  parts,
  pauseMs = 0,
  halfClose = true,
  deadlineMs = 5000,
}: {
  url: string;
  parts: readonly Uint8Array[];
  pauseMs?: number;
  halfClose?: boolean;
  deadlineMs?: number;
}): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const address = new URL(url);
    const socket = connect(Number(address.port), address.hostname);
    socket.setNoDelay(true);
    const received: Buffer[] = [];
    let bytes = 0;
    const deadline = setTimeout(() => socket.destroy(new Error("absolute socket deadline")), deadlineMs);
    socket.on("error", reject);
    socket.on("close", () => clearTimeout(deadline));
    socket.on("data", (chunk: Buffer) => {
      bytes += chunk.length;
      if (bytes > 1_000_000) socket.destroy(new Error("response output limit"));
      else received.push(chunk);
    });
    socket.on("end", () => {
      resolve(Buffer.concat(received));
      socket.destroy();
    });
    socket.on("connect", () => {
      void (async () => {
        for (const [index, part] of parts.entries()) {
          if (socket.destroyed || socket.readableEnded) return;
          socket.write(part);
          if (pauseMs && index + 1 < parts.length) await Bun.sleep(pauseMs);
        }
        if (halfClose && !socket.destroyed) socket.end();
      })().catch((error: unknown) => socket.destroy(error instanceof Error ? error : new Error(String(error))));
    });
  });
}

export async function closed(url: string, wire: Buffer, methods: readonly string[] = []) {
  const parsed = responses(await exchange({ url, parts: [wire] }), methods);
  const last = parsed.at(-1);
  if (!last || last.headers.get("connection") !== "close")
    throw new Error("final response must advertise Connection: close");
  return parsed;
}
