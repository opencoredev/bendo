// A deliberately broken HTTP server for the fuzzer self-test. It answers the
// fuzzer's readiness probe and health check correctly, then misbehaves on every
// other request in the way its mode names. Usage: bun broken-server.ts <mode>.
import { createServer, type Socket } from "node:net";

export const MODES = [
  "valid",
  "valid-then-reset",
  "hang",
  "missing-length",
  "extra-bytes",
  "bad-status",
  "junk-then-reset",
  "crash",
  "silent",
] as const;
export type Mode = (typeof MODES)[number];

const HEALTHY = "HTTP/1.1 200 OK\r\nContent-Length: 11\r\nConnection: close\r\n\r\nconformance";
const REJECT = "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";

function parseMode(raw: string | undefined): Mode {
  const mode = MODES.find((m) => m === raw);
  if (!mode) throw new Error(`mode must be one of ${MODES.join(", ")}`);
  return mode;
}

function misbehave(mode: Mode, socket: Socket): void {
  switch (mode) {
    case "valid":
      return void socket.end(REJECT);
    case "valid-then-reset":
      return void socket.write(REJECT, () => socket.resetAndDestroy());
    case "hang":
    case "silent":
      return;
    case "missing-length":
      return void socket.end("HTTP/1.1 200 OK\r\nConnection: close\r\n\r\nhi");
    case "extra-bytes":
      return void socket.end(
        "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nhijunk",
      );
    case "bad-status":
      return void socket.end("HTTP/1.1 2OO OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
    case "junk-then-reset":
      return void socket.write("HTTP/1.1 200 OK\r\nContent-Le", () => socket.resetAndDestroy());
    case "crash":
      return process.exit(3);
    default: {
      const exhaustive: never = mode;
      return exhaustive;
    }
  }
}

if (import.meta.main) {
  const mode = parseMode(process.argv[2]);
  createServer({ allowHalfOpen: true }, (socket) => {
    let received = Buffer.alloc(0);
    let answered = false;
    const answer = () => {
      if (answered || received.length === 0) return;
      answered = true;
      const probe = received.toString("latin1").startsWith("GET /text HTTP/1.1\r\n");
      if (probe && mode !== "silent") socket.end(HEALTHY);
      else misbehave(mode, socket);
    };
    socket.on("error", () => socket.destroy());
    socket.on("data", (chunk: Buffer) => {
      received = Buffer.concat([received, chunk]);
      if (received.includes("\r\n\r\n") || received.length > 64) answer();
    });
    socket.on("end", answer);
  }).listen(Number(process.env.PORT), "127.0.0.1");
}
