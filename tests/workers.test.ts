import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { get } from "node:http";
import { connect } from "node:net";
import { build, start, type RunningServer } from "./harness.ts";

// Workers (BND-69, decision 0016): tests/servers/workers.bend serves with
// B.workers(config, 3) and answers each request with the serving PID.
const binary = build("tests/servers/workers.bend");

/** One request on its own connection, so the kernel picks a worker each time. */
function servingPid(url: string): Promise<number> {
  return new Promise((resolve, reject) => {
    const req = get(url, { agent: false, timeout: 5000 }, (res) => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", (chunk: string) => (body += chunk));
      res.on("error", reject);
      res.on("end", () => {
        if (res.statusCode !== 200 || !/^[0-9]+$/.test(body)) {
          reject(new Error(`unexpected reply: ${res.statusCode} ${body}`));
          return;
        }
        resolve(Number(body));
      });
    });
    req.on("timeout", () => req.destroy(new Error("request timeout")));
    req.on("error", reject);
  });
}

/** Distinct serving PIDs, polling until `want` appear or attempts run out. */
async function servingPids(url: string, want: number): Promise<Set<number>> {
  const seen = new Set<number>();
  for (let i = 0; i < 300 && seen.size < want; i++) seen.add(await servingPid(url));
  return seen;
}

function children(pid: number): number[] {
  const path = `/proc/${pid}/task/${pid}/children`;
  if (!existsSync(path)) return [];
  return readFileSync(path, "utf8").split(" ").filter(Boolean).map(Number);
}

/** Running means present and not a zombie. */
function running(pid: number): boolean {
  try {
    const stat = readFileSync(`/proc/${pid}/stat`, "utf8");
    return stat.slice(stat.lastIndexOf(")") + 2)[0] !== "Z";
  } catch {
    return false;
  }
}

async function until(check: () => boolean, ms: number): Promise<boolean> {
  const deadline = Date.now() + ms;
  while (Date.now() < deadline) {
    if (check()) return true;
    await Bun.sleep(25);
  }
  return check();
}

function refused(url: string): Promise<boolean> {
  const { hostname, port } = new URL(url);
  return new Promise((resolve) => {
    const socket = connect({ host: hostname, port: Number(port) });
    socket.on("connect", () => {
      socket.destroy();
      resolve(false);
    });
    socket.on("error", () => resolve(true));
  });
}

async function workerTree(server: RunningServer, count: number): Promise<number[]> {
  expect(await until(() => children(server.pid).length === count - 1, 5000)).toBe(true);
  return [server.pid, ...children(server.pid)];
}

describe.skipIf(process.platform !== "linux")("multi-worker serving", () => {
  test("three worker processes all serve one port", async () => {
    await using server = await start(binary);
    const tree = await workerTree(server, 3);
    const seen = await servingPids(server.url, 3);
    expect([...seen].sort()).toEqual([...tree].sort());
    // Every worker is a copy of the same binary.
    const exe = readFileSync(`/proc/${server.pid}/cmdline`, "utf8");
    for (const pid of tree) expect(readFileSync(`/proc/${pid}/cmdline`, "utf8")).toBe(exe);
  });

  test("stopping the first process stops every worker and frees the port", async () => {
    const server = await start(binary);
    const tree = await workerTree(server, 3);
    await servingPids(server.url, 3);
    await server[Symbol.asyncDispose]();
    expect(await until(() => tree.every((pid) => !running(pid)), 3000)).toBe(true);
    expect(await refused(server.url)).toBe(true);
  });

  test("a worker that dies stops the whole server", async () => {
    await using server = await start(binary);
    const tree = await workerTree(server, 3);
    const [first, victim, other] = tree;
    if (first === undefined || victim === undefined || other === undefined)
      throw new Error("missing workers");
    process.kill(victim, "SIGKILL");
    expect(await until(() => !running(first) && !running(other), 3000)).toBe(true);
    expect(server.stderr()).toContain(
      `bendo: worker ${victim} stopped by signal 9; stopping the server`,
    );
    expect(await refused(server.url)).toBe(true);
  });

  test("BENDO_WORKERS overrides the config, and an invalid value keeps it", async () => {
    {
      await using server = await start(binary, "127.0.0.1", { BENDO_WORKERS: "1" });
      expect([...(await servingPids(server.url, 2))]).toEqual([server.pid]);
      expect(children(server.pid)).toEqual([]);
    }
    {
      await using server = await start(binary, "127.0.0.1", { BENDO_WORKERS: "2" });
      expect((await workerTree(server, 2)).length).toBe(2);
    }
    {
      await using server = await start(binary, "127.0.0.1", { BENDO_WORKERS: "many" });
      expect((await workerTree(server, 3)).length).toBe(3);
    }
  });
});
