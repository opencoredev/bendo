import { afterAll, expect, test } from "bun:test";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawn } from "node:child_process";

const cli = resolve(import.meta.dir, "cli.ts");
const root = mkdtempSync(join(tmpdir(), "bendo-cli-"));
const app = join(root, "app with spaces");
const bun = process.execPath;

function run(args: string[], cwd = app, env = process.env) {
  const child = Bun.spawnSync([bun, cli, ...args], {
    cwd,
    env,
    stdout: "pipe",
    stderr: "pipe",
    timeout: 180_000,
  });
  return { code: child.exitCode, out: child.stdout.toString(), err: child.stderr.toString() };
}

// Compile native fixtures before tests start; watch tests can reuse both successful builds.
const created = run(["new", app], root);
const original = readFileSync(join(app, "main.bend"), "utf8");
const changed = original.replace("Hello from Bendo!", "Updated Bendo!");
const firstBuild = run(["build"]);
writeFileSync(join(app, "main.bend"), changed);
const secondBuild = run(["build"]);
writeFileSync(join(app, "main.bend"), original);

function running(args: string[], port: number, cwd = app, env = process.env) {
  const child = spawn(bun, [cli, ...args], {
    cwd,
    env: { ...env, PORT: String(port) },
    stdio: ["ignore", "pipe", "pipe"],
  });
  let output = "";
  child.stdout.on("data", (data: Buffer) => {
    output += data.toString();
  });
  child.stderr.on("data", (data: Buffer) => {
    output += data.toString();
  });
  const exited = new Promise<number | null>((done) => {
    child.once("exit", done);
  });
  return {
    child,
    exited,
    output: () => output,
    async close(signal: NodeJS.Signals = "SIGTERM") {
      child.kill(signal);
      await Promise.race([
        exited,
        Bun.sleep(3000).then(() => {
          throw new Error("CLI did not stop");
        }),
      ]);
    },
  };
}

async function until(check: () => boolean | Promise<boolean>, timeout = 90_000): Promise<void> {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (await check()) return;
    await Bun.sleep(25);
  }
  throw new Error("Timed out waiting for CLI behavior");
}

function port(): number {
  const listener = Bun.listen({ hostname: "127.0.0.1", port: 0, socket: { data() {} } });
  const value = listener.port;
  listener.stop(true);
  return value;
}
async function body(value: number): Promise<string> {
  try {
    return await (
      await fetch(`http://127.0.0.1:${value}/`, {
        signal: AbortSignal.timeout(300),
        headers: { connection: "close" },
      })
    ).text();
  } catch {
    return "";
  }
}

afterAll(() => {
  rmSync(root, { recursive: true, force: true });
});

for (const command of ["new", "dev", "build", "start", "doctor"]) {
  test(`${command} --help exits successfully`, () => {
    const result = run([command, "--help"]);
    expect(result.code).toBe(0);
    expect(result.out).toContain(`bendo ${command}`);
  });
}

test("new scaffolds an independent public API app and refuses overwrites", () => {
  expect(created.code).toBe(0);
  expect(firstBuild.code).toBe(0);
  expect(secondBuild.code).toBe(0);
  expect(original).toContain("B.RouteError");
  expect(existsSync(join(app, "bendo/main.bend"))).toBe(true);
  expect(run(["new", app]).code).toBe(1);
  expect(readFileSync(join(app, "main.bend"), "utf8")).toBe(original);
});

test("build runs schema stage before compiler, hits cache, and preserves successful output on errors", () => {
  expect(firstBuild.out.indexOf("generate:")).toBeLessThan(firstBuild.out.indexOf("compile:"));
  expect(run(["build"]).out).toContain("compile: cache hit");
  const binary = readFileSync(join(app, "dist/server"));
  writeFileSync(join(app, "main.bend"), `${original}\nnot valid Bend\n`);
  try {
    const result = run(["build"]);
    expect(result.code).toBe(1);
    expect(result.err).toMatch(/main\.bend:\d+: .*Error:/);
    expect(result.err).not.toContain(" at ");
    expect(readFileSync(join(app, "dist/server"))).toEqual(binary);
  } finally {
    writeFileSync(join(app, "main.bend"), original);
  }
});

test("start serves built app, SIGINT frees the port and start needs no compiler", async () => {
  run(["build"]);
  const value = port();
  const server = running(["start"], value, app, {
    ...process.env,
    PATH: "/nonexistent",
    HOME: root,
  });
  try {
    await until(async () => (await body(value)) === "Hello from Bendo!");
  } finally {
    await server.close("SIGINT");
  }
  expect(await body(value)).toBe("");
  const again = running(["start"], value);
  try {
    await until(async () => (await body(value)) === "Hello from Bendo!");
  } finally {
    await again.close();
  }
});

test("start fails clearly without build; invalid args and missing Bend have no stacks", () => {
  const empty = join(root, "empty");
  mkdirSync(empty);
  expect(run(["start"], empty).err).toContain("Run bendo build first");
  expect(run(["build", "--shared"]).code).toBe(1);
  const missing = run(["build"], app, { ...process.env, PATH: "/nonexistent", HOME: root });
  expect(missing.code).toBe(1);
  expect(missing.err).toContain("bend not found");
  expect(missing.err).not.toContain(" at ");
  expect(run(["doctor"]).out).toContain("bend 2.");
});

test("dev debounces atomic saves, keeps serving on syntax errors, recovers and cleans up", async () => {
  const value = port();
  const server = running(["dev"], value);
  try {
    await until(async () => (await body(value)) === "Hello from Bendo!");
    expect(server.output().indexOf("generate:")).toBeLessThan(server.output().indexOf("compile:"));
    mkdirSync(join(app, ".cache/ignored"), { recursive: true });
    mkdirSync(join(app, "dist/ignored"), { recursive: true });
    const before = server.output();
    writeFileSync(join(app, ".cache/ignored/file.bend"), "broken");
    writeFileSync(join(app, "dist/ignored/file.bend"), "broken");
    await Bun.sleep(250);
    expect(server.output()).toBe(before);
    writeFileSync(join(app, "main.bend"), `${original}\nsyntax error\n`);
    await until(() => /main\.bend:\d+: Error:/.test(server.output()));
    expect(await body(value)).toBe("Hello from Bendo!");
    writeFileSync(join(app, "main.bend.tmp"), changed);
    renameSync(join(app, "main.bend.tmp"), join(app, "main.bend"));
    const started = performance.now();
    await until(async () => (await body(value)) === "Updated Bendo!");
    process.stdout.write(
      `fresh JS save -> answering: ${Math.round(performance.now() - started)}ms\n`,
    );
    expect(server.output()).not.toContain(" at ");
  } finally {
    await server.close();
    writeFileSync(join(app, "main.bend"), original);
  }
  expect(await body(value)).toBe("");
}, 120_000);

test("cache tracks transitive imports and diagnostics name the imported source", () => {
  const project = join(root, "imports");
  mkdirSync(project);
  writeFileSync(
    join(project, "main.bend"),
    "import Base\nimport ./lib.bend as Lib\ndef main() -> U32: Lib.value()\n",
  );
  writeFileSync(join(project, "lib.bend"), "import Base\ndef value() -> U32: 1\n");
  expect(run(["build"], project).code).toBe(0);
  expect(run(["build"], project).out).toContain("cache hit");
  writeFileSync(join(project, "lib.bend"), "import Base\ndef value() -> U32: 2\n");
  const changedBuild = run(["build"], project);
  expect(changedBuild.code).toBe(0);
  expect(changedBuild.out).not.toContain("cache hit");
  writeFileSync(join(project, "lib.bend"), "import Base\ndef value() -> U32:\n  absent_name()\n");
  const failed = run(["build"], project);
  expect(failed.code).toBe(1);
  expect(failed.err).toContain("lib.bend:3: Error:");
  expect(failed.err).toContain("a defined name");
});

test("shutdown during compilation kills compiler descendants", async () => {
  const project = join(root, "cancel");
  const bin = join(project, "bin");
  mkdirSync(bin, { recursive: true });
  const real = Bun.which("bend");
  if (real === null) throw new Error("Bend required");
  const marker = join(project, "child-pid");
  // A compiler launcher supplies a deterministic blocked compile with a real child
  // process. Version detection still invokes the actual Bend installation.
  writeFileSync(
    join(bin, "bend"),
    `#!/bin/sh
case "$1" in
  --help|version) exec '${real}' "$@" ;;
esac
sleep 30 &
echo $! > '${marker}'
wait
`,
    { mode: 0o755 },
  );
  writeFileSync(join(project, "main.bend"), "import Base\ndef main() -> U32: 1\n");
  const server = running(["dev"], port(), project, {
    ...process.env,
    PATH: `${bin}:${process.env.PATH}`,
  });
  let descendant: number | undefined;
  try {
    await until(() => existsSync(marker));
    descendant = Number(readFileSync(marker, "utf8").trim());
    expect(Number.isInteger(descendant)).toBe(true);
  } finally {
    await server.close();
  }
  if (descendant === undefined) throw new Error("Compiler child did not start");
  await until(() => {
    try {
      // Linux can retain a dead orphan as a zombie until PID 1 reaps it.
      return readFileSync(`/proc/${descendant}/stat`, "utf8").split(" ")[2] === "Z";
    } catch {
      return true;
    }
  });
});

test("dev queues a save during compilation and notices new and deleted nested files", async () => {
  const project = join(root, "queued");
  const bin = join(project, "bin");
  mkdirSync(bin, { recursive: true });
  const real = Bun.which("bend");
  if (real === null) throw new Error("Bend required");
  const marker = join(project, "compiling");
  writeFileSync(
    join(bin, "bend"),
    `#!/bin/sh
case "$1" in
  --help|version) exec '${real}' "$@" ;;
esac
touch '${marker}'
sleep 0.5
cat > "$3" <<'JS'
Bun.serve({hostname: '127.0.0.1', port: Number(process.env.PORT), fetch: () => new Response('queued')});
JS
`,
    { mode: 0o755 },
  );
  writeFileSync(join(project, "main.bend"), "import Base\ndef main() -> U32: 1\n");
  const server = running(["dev"], port(), project, {
    ...process.env,
    PATH: `${bin}:${process.env.PATH}`,
  });
  try {
    await until(() => existsSync(marker));
    writeFileSync(join(project, "main.bend"), "import Base\ndef main() -> U32: 2\n");
    await until(() => server.output().includes("restart: launched"));
    expect(server.output().match(/generate:/g)?.length).toBeGreaterThanOrEqual(2);
    mkdirSync(join(project, "nested"));
    writeFileSync(join(project, "nested/new.bend"), "import Base\n");
    const before = server.output().match(/generate:/g)?.length ?? 0;
    await until(() => (server.output().match(/generate:/g)?.length ?? 0) > before);
    const beforeDelete = server.output().match(/generate:/g)?.length ?? 0;
    rmSync(join(project, "nested/new.bend"));
    await until(() => (server.output().match(/generate:/g)?.length ?? 0) > beforeDelete);
  } finally {
    await server.close();
  }
});

test("build compiles immutable inputs even when a save is undone before compiler completion", async () => {
  const project = join(root, "snapshot");
  const bin = join(project, "bin");
  mkdirSync(bin, { recursive: true });
  const real = Bun.which("bend");
  if (real === null) throw new Error("Bend required");
  const started = join(project, "started");
  const captured = join(project, "captured");
  const input = join(project, "observed.bend");
  writeFileSync(
    join(bin, "bend"),
    `#!/bin/sh
case "$1" in
  --help|version) exec '${real}' "$@" ;;
esac
touch '${started}'
sleep 0.2
cp "$1" '${input}'
touch '${captured}'
sleep 0.2
exec '${real}' '${input}' -o "$3"
`,
    { mode: 0o755 },
  );
  const source = join(project, "main.bend");
  const original = "import Base\ndef main() -> U32: 1\n";
  writeFileSync(source, original);
  const build = running(["build"], port(), project, {
    ...process.env,
    PATH: `${bin}:${process.env.PATH}`,
  });
  try {
    await until(() => existsSync(started));
    writeFileSync(source, "import Base\ndef main() -> U32: 2\n");
    await until(() => existsSync(captured));
    writeFileSync(source, original);
    await until(() => build.output().includes("build: dist/server"));
    const result = Bun.spawnSync([join(project, "dist/server")], {
      stdout: "pipe",
      stderr: "pipe",
      timeout: 5000,
    });
    expect(result.stdout.toString().trim()).toBe("1");
    expect(
      run(["build"], project, { ...process.env, PATH: `${bin}:${process.env.PATH}` }).out,
    ).toContain("cache hit");
  } finally {
    await build.close();
  }
});

test("start waits for a SIGTERM-resistant server to exit after forced termination", async () => {
  const project = join(root, "resistant");
  mkdirSync(join(project, "dist"), { recursive: true });
  writeFileSync(
    join(project, "dist/server"),
    `#!${bun}
process.on("SIGTERM", () => {});
Bun.serve({hostname: "127.0.0.1", port: Number(process.env.PORT), fetch: () => new Response("resistant")});
`,
    { mode: 0o755 },
  );
  const value = port();
  const server = running(["start"], value, project);
  await until(async () => (await body(value)) === "resistant");
  const began = performance.now();
  await server.close();
  expect(performance.now() - began).toBeGreaterThanOrEqual(450);
  expect(await body(value)).toBe("");
  const replacement = running(["start"], value, project);
  try {
    await until(async () => (await body(value)) === "resistant");
  } finally {
    await replacement.close();
  }
});
