import { connect, createServer, type Socket } from "node:net";
import type { ChildProcess } from "node:child_process";

/** Keep the public port open while candidate servers start on private ports. */
export async function devProxy() {
  const rawPort = process.env.PORT ?? "8787";
  if (!/^[0-9]+$/.test(rawPort) || Number(rawPort) < 1 || Number(rawPort) > 65535)
    throw new Error("PORT must be an integer from 1 to 65535");
  let active: number | undefined;
  const sockets = new Set<Socket>();
  const proxy = createServer((client) => {
    if (active === undefined) return client.destroy();
    const backend = connect(active, "127.0.0.1");
    for (const socket of [client, backend]) {
      sockets.add(socket);
      socket.on("close", () => sockets.delete(socket));
      socket.on("error", () => {
        client.destroy();
        backend.destroy();
      });
    }
    client.on("close", () => backend.destroy());
    backend.on("close", () => client.destroy());
    client.pipe(backend).pipe(client);
  });
  await new Promise<void>((done, reject) => {
    proxy.once("error", reject);
    proxy.listen(Number(rawPort), "127.0.0.1", done);
  });
  return {
    activate(port: number): void {
      active = port;
    },
    close(): void {
      for (const socket of sockets) socket.destroy();
      proxy.close();
    },
  };
}

export async function privatePort(): Promise<number> {
  const listener = createServer();
  await new Promise<void>((done, reject) => {
    listener.once("error", reject);
    listener.listen(0, "127.0.0.1", done);
  });
  const address = listener.address();
  await new Promise<void>((done) => listener.close(() => done()));
  if (address === null || typeof address === "string") throw new Error("Cannot allocate dev port");
  return address.port;
}

export async function waitForServer(
  child: ChildProcess,
  port: number,
  signal: AbortSignal,
): Promise<void> {
  const deadline = performance.now() + 10_000;
  while (performance.now() < deadline) {
    signal.throwIfAborted();
    if (child.exitCode !== null || child.signalCode !== null)
      throw new Error(`server exited (${child.exitCode ?? child.signalCode}) before listening`);
    const ready = await new Promise<boolean>((done) => {
      const socket = connect(port, "127.0.0.1");
      const finish = (result: boolean): void => {
        socket.destroy();
        done(result);
      };
      socket.setTimeout(100, () => finish(false));
      socket.once("connect", () => finish(true));
      socket.once("error", () => finish(false));
    });
    if (ready) return;
    await Bun.sleep(20);
  }
  throw new Error("server did not listen within 10s; waiting for a .bend change");
}
