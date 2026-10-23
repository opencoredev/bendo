import { expect, test } from "bun:test";
import { spawn } from "node:child_process";
import {
  existsSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { compilerDiagnostic, stop } from "./pipeline.ts";

const cli = resolve(import.meta.dir, "cli.ts");
async function until(check: () => boolean | Promise<boolean>, timeout = 90_000): Promise<void> {
  const deadline = performance.now() + timeout;
  while (performance.now() < deadline) {
    if (await check()) return;
    await Bun.sleep(25);
  }
  throw new Error("Timed out waiting for CLI behavior");
}
function port(): number {
  const listener = Bun.listen({ hostname: "127.0.0.1", port: 0, socket: { data() {} } });
  const result = listener.port;
  listener.stop(true);
  return result;
}
async function body(port: number): Promise<string> {
  try {
    return await (
      await fetch(`http://127.0.0.1:${port}`, {
        signal: AbortSignal.timeout(300),
        headers: { connection: "close" },
      })
    ).text();
  } catch {
    return "";
  }
}

test("ambiguous imported excerpts preserve candidates and never invent an entry location", () => {
  const source = Buffer.from("import Base\ndef value() -> U32: absent()\n");
  const diagnostic = compilerDiagnostic(
    "SOME PROOFS FAIL\nError:\n- expected : a defined name\nLocation: value\n1 |\n2>| def value() -> U32: absent()\n  |                   ^^^^^^",
    "main.bend",
    new Map([
      ["/app/one.bend", source],
      ["/app/two.bend", source],
    ]),
  );
  expect(diagnostic).toContain("location ambiguous");
  expect(diagnostic).toContain("/app/one.bend:2");
  expect(diagnostic).toContain("/app/two.bend:2");
  expect(diagnostic).toContain("2>| def value()");
  expect(diagnostic).not.toContain("main.bend:2:");
});

test("new save promptly kills obsolete compiler descendants and starts latest compile", async () => {
  const root = mkdtempSync(join(tmpdir(), "bendo-cancel-review-"));
  mkdirSync(join(root, "bin"));
  const real = Bun.which("bend");
  if (!real) throw new Error("Bend required");
  const marker = join(root, "first-pid");
  const latest = join(root, "latest");
  writeFileSync(
    join(root, "bin/bend"),
    `#!/bin/sh
case "$1" in --help|version) exec '${real}' "$@" ;; esac
if [ ! -f '${marker}' ]; then
  sleep 30 &
  echo $! > '${marker}'
  wait
else
  touch '${latest}'
  cat > "$3" <<'JS'
Bun.serve({hostname: '127.0.0.1', port: Number(process.env.PORT), fetch: () => new Response('latest')});
JS
fi
`,
    { mode: 0o755 },
  );
  writeFileSync(join(root, "main.bend"), "import Base\ndef main() -> U32: 1\n");
  const value = port();
  const child = spawn(process.execPath, [cli, "dev"], {
    cwd: root,
    env: { ...process.env, PATH: `${root}/bin:${process.env.PATH}`, PORT: String(value) },
    detached: true,
    stdio: "ignore",
  });
  try {
    await until(() => existsSync(marker));
    const started = performance.now();
    writeFileSync(join(root, "main.bend"), "import Base\ndef main() -> U32: 2\n");
    await until(() => existsSync(latest), 2000);
    expect(performance.now() - started).toBeLessThan(2000);
    await until(async () => (await body(value)) === "latest");
    const pid = Number(readFileSync(marker, "utf8").trim());
    await until(() => {
      try {
        return readFileSync(`/proc/${pid}/stat`, "utf8").split(" ")[2] === "Z";
      } catch {
        return true;
      }
    }, 2000);
  } finally {
    child.kill("SIGTERM");
    await new Promise<void>((done) => {
      if (child.exitCode !== null) done();
      else child.once("exit", () => done());
    });
    await stop(child);
    rmSync(root, { recursive: true, force: true });
  }
});

test("dev watches external symlink imports, keeps old HTTP through failures, and recovers", async () => {
  const root = mkdtempSync(join(tmpdir(), "bendo-symlink-review-"));
  const app = join(root, "app");
  const outside = join(root, "outside");
  mkdirSync(outside);
  const created = Bun.spawnSync([process.execPath, cli, "new", app], {
    stdout: "pipe",
    stderr: "pipe",
  });
  expect(created.exitCode).toBe(0);
  symlinkSync(outside, join(app, "linked"));
  const lib = join(outside, "lib.bend");
  writeFileSync(lib, 'import Base\ndef message() -> String: "before"\n');
  const main = readFileSync(join(app, "main.bend"), "utf8")
    .replace("import Base", "import Base\nimport ./linked/lib.bend as Lib")
    .replace('"Hello from Bendo!"', "Lib.message()");
  writeFileSync(join(app, "main.bend"), main);
  const value = port();
  let output = "";
  const child = spawn(process.execPath, [cli, "dev"], {
    cwd: app,
    env: { ...process.env, PORT: String(value) },
    detached: true,
    stdio: ["ignore", "pipe", "pipe"],
  });
  child.stdout?.on("data", (chunk: Buffer) => {
    output += chunk.toString();
  });
  child.stderr?.on("data", (chunk: Buffer) => {
    output += chunk.toString();
  });
  try {
    await until(async () => (await body(value)) === "before");
    writeFileSync(lib, "import Base\ndef message() -> String: absent()\n");
    await until(() => output.includes("lib.bend:2: Error:"));
    expect(await body(value)).toBe("before");
    writeFileSync(lib, 'import Base\ndef message() -> String: "after"\n');
    await until(async () => (await body(value)) === "after");
    expect(output).not.toContain(" at ");
  } finally {
    child.kill("SIGTERM");
    await new Promise<void>((done) => {
      if (child.exitCode !== null) done();
      else child.once("exit", () => done());
    });
    await stop(child);
    rmSync(root, { recursive: true, force: true });
  }
}, 120_000);

test("dev retains old responses until replacement listens and after startup failure", async () => {
  const root = mkdtempSync(join(tmpdir(), "bendo-ready-review-"));
  mkdirSync(join(root, "bin"));
  const real = Bun.which("bend");
  if (!real) throw new Error("Bend required");
  writeFileSync(
    join(root, "bin/bend"),
    `#!/bin/sh
case "$1" in --help|version) exec '${real}' "$@" ;; esac
if grep -q 'doomed' "$1"; then
  echo "process.on('SIGTERM',()=>{}); Bun.serve({hostname:'127.0.0.1',port:Number(process.env.PORT),fetch:()=>new Response('doomed')}); setTimeout(()=>process.exit(7),150);" > "$3"
elif grep -q 'broken' "$1"; then
  echo "console.log('candidate broken'); process.exit(1);" > "$3"
elif grep -q 'delayed' "$1"; then
  cat > "$3" <<'JS'
console.log('candidate delayed');
setTimeout(() => Bun.serve({hostname:'127.0.0.1',port:Number(process.env.PORT),fetch:()=>new Response('delayed')}), 750);
JS
else
  echo "process.on('SIGTERM',()=>{}); Bun.serve({hostname:'127.0.0.1',port:Number(process.env.PORT),fetch:()=>new Response('initial')});" > "$3"
fi
`,
    { mode: 0o755 },
  );
  const source = join(root, "main.bend");
  writeFileSync(source, "initial");
  const value = port();
  let output = "";
  const child = spawn(process.execPath, [cli, "dev"], {
    cwd: root,
    env: { ...process.env, PATH: `${root}/bin:${process.env.PATH}`, PORT: String(value) },
    detached: true,
    stdio: ["ignore", "pipe", "pipe"],
  });
  child.stdout?.on("data", (chunk: Buffer) => {
    output += chunk.toString();
  });
  child.stderr?.on("data", (chunk: Buffer) => {
    output += chunk.toString();
  });
  try {
    await until(async () => (await body(value)) === "initial");
    writeFileSync(source, "delayed");
    await until(() => output.includes("candidate delayed"));
    expect(await body(value)).toBe("initial");
    await Bun.sleep(250);
    expect(await body(value)).toBe("initial");
    await until(async () => (await body(value)) === "delayed");
    writeFileSync(source, "broken");
    await until(() => output.includes("before listening"));
    expect(await body(value)).toBe("delayed");
    writeFileSync(source, "initial");
    await until(async () => (await body(value)) === "initial");
    writeFileSync(source, "doomed");
    await until(() => output.includes("server exited (7)"), 2000);
    expect(output).toContain("server exited (7)");
  } finally {
    child.kill("SIGTERM");
    await new Promise<void>((done) => {
      if (child.exitCode !== null) done();
      else child.once("exit", () => done());
    });
    await stop(child);
    rmSync(root, { recursive: true, force: true });
  }
});
