import { describe, expect, test } from "bun:test";
import { existsSync, readdirSync, readFileSync, readlinkSync } from "node:fs";
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

/** Sockets a process holds, by inode. */
function socketInodes(pid: number): Set<string> {
  const inodes = new Set<string>();
  for (const fd of readdirSync(`/proc/${pid}/fd`)) {
    try {
      const match = /^socket:\[(\d+)\]$/.exec(readlinkSync(`/proc/${pid}/fd/${fd}`));
      if (match?.[1] !== undefined) inodes.add(match[1]);
    } catch {
      // The descriptor closed while we listed it.
    }
  }
  return inodes;
}

/** Inodes of the IPv4 sockets listening on `port`. */
function listeners(port: number): Set<string> {
  const hex = port.toString(16).toUpperCase().padStart(4, "0");
  const inodes = new Set<string>();
  for (const line of readFileSync("/proc/net/tcp", "utf8").split("\n").slice(1)) {
    const fields = line.trim().split(/\s+/);
    if (fields[1]?.endsWith(`:${hex}`) && fields[3] === "0A" && fields[9] !== undefined)
      inodes.add(fields[9]);
  }
  return inodes;
}

/**
 * Runs `body` against a fresh server. Every process the server started is
 * killed afterwards, whether the body passes or throws.
 */
async function withServer(
  env: Readonly<Record<string, string>>,
  body: (server: RunningServer) => Promise<void>,
): Promise<void> {
  const server = await start(binary, "127.0.0.1", env);
  const spawned = new Set<number>(children(server.pid));
  // Keep listing children while the body runs: once the first process stops,
  // its children are no longer listed under it.
  const watch = setInterval(() => {
    for (const pid of children(server.pid)) spawned.add(pid);
  }, 25);
  try {
    await body(server);
  } finally {
    clearInterval(watch);
    for (const pid of children(server.pid)) spawned.add(pid);
    await server[Symbol.asyncDispose]();
    for (const pid of spawned) {
      try {
        process.kill(pid, "SIGKILL");
      } catch {
        // Already gone.
      }
    }
  }
}

async function workerTree(server: RunningServer, count: number): Promise<number[]> {
  expect(await until(() => children(server.pid).length === count - 1, 5000)).toBe(true);
  return [server.pid, ...children(server.pid)];
}

describe.skipIf(process.platform !== "linux")("multi-worker serving", () => {
  test("three worker processes all serve one port", async () => {
    await withServer({}, async (server) => {
      const tree = await workerTree(server, 3);
      const seen = await servingPids(server.url, 3);
      expect([...seen].sort()).toEqual([...tree].sort());
      // Every worker is a copy of the same binary, under the same process name.
      const exe = readFileSync(`/proc/${server.pid}/cmdline`, "utf8");
      const name = readFileSync(`/proc/${server.pid}/comm`, "utf8");
      for (const pid of tree) {
        expect(readFileSync(`/proc/${pid}/cmdline`, "utf8")).toBe(exe);
        expect(readFileSync(`/proc/${pid}/comm`, "utf8")).toBe(name);
      }
    });
  });

  test("the first process accepts only once every worker listens", async () => {
    await withServer({}, async (server) => {
      // The harness returned after the first answer; wait until the first
      // process itself has answered once.
      let first = false;
      for (let i = 0; i < 300 && !first; i++) first = (await servingPid(server.url)) === server.pid;
      expect(first).toBe(true);
      const tree = [server.pid, ...children(server.pid)];
      expect(tree.length).toBe(3);
      const listening = listeners(Number(new URL(server.url).port));
      for (const pid of tree) {
        const held = [...socketInodes(pid)].filter((inode) => listening.has(inode));
        // Each worker holds exactly its own listener and none of the others.
        expect(held.length).toBe(1);
      }
      expect(listening.size).toBe(3);
    });
  });

  test("stopping the first process stops every worker and frees the port", async () => {
    await withServer({}, async (server) => {
      const tree = await workerTree(server, 3);
      await servingPids(server.url, 3);
      await server[Symbol.asyncDispose]();
      expect(await until(() => tree.every((pid) => !running(pid)), 3000)).toBe(true);
      expect(await refused(server.url)).toBe(true);
    });
  });

  test("a worker that dies stops the whole server", async () => {
    await withServer({}, async (server) => {
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
  });

  test("BENDO_WORKERS overrides the config, and an invalid value keeps it", async () => {
    await withServer({ BENDO_WORKERS: "1" }, async (server) => {
      expect([...(await servingPids(server.url, 2))]).toEqual([server.pid]);
      expect(children(server.pid)).toEqual([]);
    });
    await withServer({ BENDO_WORKERS: "2" }, async (server) => {
      expect((await workerTree(server, 2)).length).toBe(2);
    });
    await withServer({ BENDO_WORKERS: "many" }, async (server) => {
      expect((await workerTree(server, 3)).length).toBe(3);
    });
  });
});
