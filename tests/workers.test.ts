import { describe, expect, test } from "bun:test";
import { existsSync, mkdtempSync, readdirSync, readFileSync, readlinkSync, rmSync } from "node:fs";
import { get } from "node:http";
import { connect } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { build, COMPILE_TEST_TIMEOUT_MS, start, type RunningServer } from "./harness.ts";

// Workers (BND-69, decision 0017): tests/servers/workers.bend serves with
// B.workers(config, 3) and answers each request with the serving PID.
const binary = build("tests/servers/workers.bend");

/** A port below Linux's ephemeral range, as the harness picks. */
function randomPort(): number {
  return 20000 + Math.floor(Math.random() * 10000);
}

/** One request on its own connection, so the kernel picks a worker each time. */
function reply(url: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const req = get(url, { agent: false, timeout: 5000 }, (res) => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", (chunk: string) => (body += chunk));
      res.on("error", reject);
      res.on("end", () => {
        if (res.statusCode !== 200) {
          reject(new Error(`unexpected reply: ${res.statusCode} ${body}`));
          return;
        }
        resolve(body);
      });
    });
    req.on("timeout", () => req.destroy(new Error("request timeout")));
    req.on("error", reject);
  });
}

async function servingPid(url: string): Promise<number> {
  const text = await reply(url);
  if (!/^[0-9]+$/.test(text)) throw new Error(`unexpected reply: ${text}`);
  return Number(text);
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

function kill(pid: number): void {
  try {
    process.kill(pid, "SIGKILL");
  } catch {
    // Already gone.
  }
}

/** Resolves when `promise` settles or after `ms`, whichever comes first. */
async function bounded(promise: Promise<unknown>, ms: number): Promise<void> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  await Promise.race([
    promise.then(
      () => undefined,
      () => undefined,
    ),
    new Promise<void>((resolve) => (timer = setTimeout(resolve, ms))),
  ]);
  clearTimeout(timer);
}

/**
 * Records every process under some roots while a test runs: once a parent
 * stops, its children are no longer listed under it. `stop` SIGKILLs them all
 * before anything waits on a process or its output.
 */
function processTracker(): {
  root: (pid: number) => void;
  stop: () => Promise<void>;
} {
  const roots = new Set<number>();
  const seen = new Set<number>();
  const scan = (): void => {
    for (const root of roots) for (const pid of children(root)) seen.add(pid);
  };
  const watch = setInterval(scan, 25);
  return {
    root: (pid) => {
      roots.add(pid);
      scan();
    },
    stop: async () => {
      clearInterval(watch);
      scan();
      const all = [...roots, ...seen];
      for (const pid of all) kill(pid);
      await until(() => all.every((pid) => !running(pid)), 3000);
    },
  };
}

/**
 * Runs `body` against a fresh server. Every process the server started, and
 * every root the body adds with `track`, is killed afterwards, whether the
 * body passes or throws. The server's own exit and stderr are awaited only
 * after that, and only for a bounded time.
 */
async function withServer(
  env: Readonly<Record<string, string>>,
  body: (server: RunningServer, track: (pid: number) => void) => Promise<void>,
): Promise<void> {
  const server = await start(binary, "127.0.0.1", env);
  const tracker = processTracker();
  tracker.root(server.pid);
  try {
    await body(server, tracker.root);
  } finally {
    await tracker.stop();
    await bounded(server[Symbol.asyncDispose](), 3000);
  }
}

type Exit = {
  code: number | null;
  stderr: string;
  ms: number;
  workers: number;
  workersGone: boolean;
};

/** Runs the server to its exit, bounded by `ms`, and kills whatever is left. */
async function runToExit(env: Readonly<Record<string, string>>, ms: number): Promise<Exit> {
  const began = Date.now();
  const proc = Bun.spawn([binary], {
    env: { ...process.env, ...env, PORT: String(randomPort()) },
    stdout: "ignore",
    stderr: "pipe",
  });
  const tracker = processTracker();
  tracker.root(proc.pid);
  const workers = new Set<number>();
  const watch = setInterval(() => {
    for (const pid of children(proc.pid)) workers.add(pid);
  }, 10);
  try {
    await bounded(proc.exited, ms);
    clearInterval(watch);
    const elapsed = Date.now() - began;
    const code = proc.exitCode;
    const started = [...workers];
    const workersGone = await until(() => started.every((pid) => !running(pid)), 3000);
    await tracker.stop();
    let stderr = "";
    await bounded(
      (async () => {
        const decoder = new TextDecoder();
        for await (const chunk of proc.stderr) stderr += decoder.decode(chunk, { stream: true });
      })(),
      3000,
    );
    return { code, stderr, ms: elapsed, workers: started.length, workersGone };
  } finally {
    clearInterval(watch);
    await tracker.stop();
  }
}

/** A fresh stall marker, so only workers run the stall test effect. */
function stallFile(): { path: string; [Symbol.dispose]: () => void } {
  const directory = mkdtempSync(join(tmpdir(), "bendo-stall-"));
  return {
    path: join(directory, "first"),
    [Symbol.dispose]: () => rmSync(directory, { recursive: true, force: true }),
  };
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
      // Bounded: a worker left alive by a regression would hold stderr open
      // and keep disposal from settling, and withServer's cleanup must still run.
      await bounded(server[Symbol.asyncDispose](), 5000);
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
      // The harness reads stderr asynchronously, so the last line can arrive
      // just after the processes exit.
      const notice = `bendo: worker ${victim} stopped by signal 9; stopping the server`;
      await until(() => server.stderr().includes(notice), 3000);
      expect(server.stderr()).toContain(notice);
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

  test("a server a worker starts is a fresh first process with its own workers", async () => {
    const port = randomPort();
    await withServer({ BENDO_TEST_CHILD_PORT: String(port) }, async (server, track) => {
      await workerTree(server, 3);
      // /spawn starts a copy only in a worker; retry until a worker answers.
      let copy = 0;
      for (let i = 0; i < 300 && copy === 0; i++) {
        const [worker, started] = (await reply(`${server.url}/spawn`)).split(" ").map(Number);
        if (started !== undefined && started !== 0) {
          expect(worker).not.toBe(server.pid);
          copy = started;
          track(copy);
        }
      }
      expect(copy).not.toBe(0);
      // A copy that inherited the worker's identity would serve alone.
      expect(await until(() => children(copy).length === 2, 10_000)).toBe(true);
      const url = `http://127.0.0.1:${port}`;
      const seen = await servingPids(url, 3);
      expect([...seen].sort()).toEqual([copy, ...children(copy)].sort());
    });
  });

  test("a worker that reports late, within the startup limit, still starts", async () => {
    using stall = stallFile();
    const began = Date.now();
    const env = {
      BENDO_WORKERS_STARTUP_MS: "15000",
      BENDO_TEST_STALL_FILE: stall.path,
      BENDO_TEST_STALL_MS: "1500",
    };
    await withServer(env, async (server) => {
      // The first process answers only after every worker reported.
      expect(Date.now() - began).toBeGreaterThanOrEqual(1500);
      const tree = await workerTree(server, 3);
      expect([...(await servingPids(server.url, 3))].sort()).toEqual([...tree].sort());
    });
  });

  test("a worker that exits before it reports stops startup at once", async () => {
    using stall = stallFile();
    const exit = await runToExit(
      { BENDO_TEST_STALL_FILE: stall.path, BENDO_TEST_STALL_MS: "200", BENDO_TEST_STALL_EXIT: "7" },
      20_000,
    );
    expect(exit.code).toBe(7);
    // Well inside the default 30-second startup limit.
    expect(exit.ms).toBeLessThan(10_000);
    expect(exit.stderr).toMatch(/bendo: worker [0-9]+ exited with status 7; stopping the server/);
  });

  test("a worker stuck past the startup limit stops the whole group", async () => {
    using stall = stallFile();
    const exit = await runToExit(
      {
        BENDO_WORKERS_STARTUP_MS: "500",
        BENDO_TEST_STALL_FILE: stall.path,
        BENDO_TEST_STALL_MS: "60000",
      },
      20_000,
    );
    // ETIMEDOUT.
    expect(exit.code).toBe(110);
    expect(exit.ms).toBeLessThan(10_000);
    expect(exit.stderr).toContain(
      "bendo: a worker did not report its listener within 500 ms; stopping the server",
    );
    expect(exit.stderr).not.toContain("stopped by signal");
    expect(exit.workers).toBe(2);
    expect(exit.workersGone).toBe(true);
  });

  test(
    "several workers refuse config port 0",
    async () => {
      const port0 = build("tests/servers/workers-port0.bend");
      // PORT=0 is not a valid override, so the config's port 0 stays.
      const proc = Bun.spawn([port0], {
        env: { ...process.env, PORT: "0" },
        stdout: "ignore",
        stderr: "pipe",
      });
      const tracker = processTracker();
      tracker.root(proc.pid);
      try {
        await bounded(proc.exited, 20_000);
        // EINVAL.
        expect(proc.exitCode).toBe(22);
        expect(children(proc.pid)).toEqual([]);
        expect(await new Response(proc.stderr).text()).toContain(
          "bendo: several workers cannot share port 0",
        );
      } finally {
        await tracker.stop();
      }
    },
    COMPILE_TEST_TIMEOUT_MS,
  );
});
