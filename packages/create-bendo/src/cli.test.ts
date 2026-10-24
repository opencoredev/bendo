import { afterEach, describe, expect, test } from "bun:test";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { main, parseArgs, UsageError, type Io } from "./cli.ts";
import { locateToolkit, manifest, packageName, TargetNotEmpty, type Toolkit } from "./create.ts";

const ROOT = resolve(import.meta.dir, "../../..");
const CLI = join(import.meta.dir, "index.ts");
const scratch: string[] = [];

function directory(): string {
  const path = mkdtempSync(join(tmpdir(), "create-bendo-"));
  scratch.push(path);
  return path;
}

afterEach(() => {
  for (const path of scratch.splice(0)) rmSync(path, { recursive: true, force: true });
});

function fakeIo(
  interactive: boolean,
  answers: string[] = [],
): Io & { text: () => string; asked: string[] } {
  let text = "";
  const asked: string[] = [];
  return {
    interactive,
    asked,
    ask: async (question) => {
      asked.push(question);
      const answer = answers.shift();
      if (answer === undefined) throw new Error(`unexpected prompt: ${question}`);
      return answer;
    },
    out: (chunk) => {
      text += chunk;
    },
    text: () => text,
  };
}

function packageJson(path: string): unknown {
  return JSON.parse(readFileSync(join(path, "package.json"), "utf8"));
}

describe("parseArgs", () => {
  test("reads a directory and a template in either flag form", () => {
    expect(parseArgs(["my-app", "--template", "fullstack"])).toEqual({
      kind: "create",
      directory: "my-app",
      template: "fullstack",
    });
    expect(parseArgs(["-t", "api", "x"])).toEqual({
      kind: "create",
      directory: "x",
      template: "api",
    });
    expect(parseArgs(["--template=api"])).toEqual({
      kind: "create",
      directory: undefined,
      template: "api",
    });
    expect(parseArgs(["x", "--help"])).toEqual({ kind: "help" });
  });

  test("rejects unknown templates, options and extra arguments", () => {
    expect(() => parseArgs(["x", "--template", "vue"])).toThrow(UsageError);
    expect(() => parseArgs(["x", "--template"])).toThrow(UsageError);
    expect(() => parseArgs(["x", "--force"])).toThrow(UsageError);
    expect(() => parseArgs(["x", "y"])).toThrow(UsageError);
  });
});

describe("main", () => {
  test("never prompts without a terminal and defaults to the api template", async () => {
    const cwd = directory();
    const io = fakeIo(false);
    expect(await main([join(cwd, "app")], io, cwd)).toBe(0);
    expect(io.asked).toEqual([]);
    expect(io.text()).toContain("Created app from the api template.");
    expect(io.text()).toContain("  cd app\n  bun install\n  bun run dev");
    expect(existsSync(join(cwd, "app/main.bend"))).toBe(true);
    expect(existsSync(join(cwd, "app/bendo/main.bend"))).toBe(true);
    for (const pin of [".bend-version", "lean-toolchain"])
      expect(readFileSync(join(cwd, "app", pin), "utf8")).toBe(
        readFileSync(join(ROOT, pin), "utf8"),
      );
    expect(readFileSync(join(cwd, "app/.gitignore"), "utf8")).toContain(".cache/");
    expect(existsSync(join(cwd, "app/gitignore"))).toBe(false);
  });

  test("requires a directory without a terminal", async () => {
    await expect(main([], fakeIo(false))).rejects.toThrow("Name a directory.");
  });

  test("asks for the directory and template on a terminal", async () => {
    const cwd = directory();
    const io = fakeIo(true, [join(cwd, "picked"), "2"]);
    expect(await main([], io, cwd)).toBe(0);
    expect(io.asked).toEqual(["Project directory (bendo-app): ", "Template (1): "]);
    expect(existsSync(join(cwd, "picked/src/main.tsx"))).toBe(true);
    expect(existsSync(join(cwd, "picked/.bendo/routes.ts"))).toBe(true);
  });

  test("does not ask for a template given on the command line", async () => {
    const cwd = directory();
    const io = fakeIo(true);
    expect(await main([join(cwd, "a"), "-t", "fullstack"], io, cwd)).toBe(0);
    expect(io.asked).toEqual([]);
  });

  test("refuses a nonempty directory before asking anything, and leaves it untouched", async () => {
    const cwd = directory();
    mkdirSync(join(cwd, "taken"));
    writeFileSync(join(cwd, "taken/keep.txt"), "mine");
    const io = fakeIo(true);
    await expect(main([join(cwd, "taken")], io, cwd)).rejects.toThrow(TargetNotEmpty);
    expect(io.asked).toEqual([]);
    expect(readFileSync(join(cwd, "taken/keep.txt"), "utf8")).toBe("mine");
  });

  test("fills an existing empty directory", async () => {
    const cwd = directory();
    mkdirSync(join(cwd, "empty"));
    expect(await main([join(cwd, "empty"), "-t", "api"], fakeIo(false), cwd)).toBe(0);
    expect(existsSync(join(cwd, "empty/main.bend"))).toBe(true);
  });

  test("keeps the mode of an existing empty directory, and gives a new one mkdir's", async () => {
    const cwd = directory();
    mkdirSync(join(cwd, "shared"));
    chmodSync(join(cwd, "shared"), 0o2770);
    expect(await main([join(cwd, "shared"), "-t", "api"], fakeIo(false), cwd)).toBe(0);
    expect(statSync(join(cwd, "shared")).mode & 0o7777).toBe(0o2770);
    mkdirSync(join(cwd, "probe"));
    expect(await main([join(cwd, "fresh"), "-t", "api"], fakeIo(false), cwd)).toBe(0);
    expect(statSync(join(cwd, "fresh")).mode & 0o7777).toBe(
      statSync(join(cwd, "probe")).mode & 0o7777,
    );
  });

  test("refuses a file", async () => {
    const cwd = directory();
    writeFileSync(join(cwd, "file"), "");
    await expect(main([join(cwd, "file")], fakeIo(false), cwd)).rejects.toThrow(TargetNotEmpty);
  });
});

describe("generated package.json", () => {
  test("links the checkout's packages when run from a checkout", () => {
    const toolkit = locateToolkit();
    expect(toolkit).toEqual({ kind: "checkout", root: ROOT });
    const bendo = `file:${join(ROOT, "packages/bendo")}`;
    expect(manifest("fullstack", toolkit, "x")).toMatchObject({
      dependencies: { bendo },
      devDependencies: { "vite-plugin-bendo": `file:${join(ROOT, "packages/vite-plugin-bendo")}` },
      overrides: { bendo },
    });
  });

  test("pins published packages to create-bendo's own version", () => {
    const toolkit: Toolkit = { kind: "published", directory: "/unused", version: "0.1.0" };
    const api = manifest("api", toolkit, "x");
    expect(api).toMatchObject({ devDependencies: { bendo: "^0.1.0" } });
    expect(api).not.toHaveProperty("overrides");
    expect(manifest("fullstack", toolkit, "x")).toMatchObject({
      dependencies: { bendo: "^0.1.0" },
      devDependencies: { "vite-plugin-bendo": "^0.1.0" },
    });
  });

  test("derives a valid package name from the directory", () => {
    expect(packageName("/tmp/My App!")).toBe("my-app");
    expect(packageName("./.hidden")).toBe("hidden");
    expect(packageName("/tmp/___")).toBe("bendo-app");
  });

  test("names the app after its directory", async () => {
    const cwd = directory();
    await main([join(cwd, "Shop Front"), "-t", "api"], fakeIo(false), cwd);
    expect(packageJson(join(cwd, "Shop Front"))).toMatchObject({
      name: "shop-front",
      private: true,
    });
  });
});

describe("the bin", () => {
  test("exits 1 with a message for a nonempty directory", () => {
    const cwd = directory();
    writeFileSync(join(cwd, "x"), "");
    const result = Bun.spawnSync([process.execPath, CLI, cwd], {
      stdin: "ignore",
      stdout: "pipe",
      stderr: "pipe",
    });
    expect(result.exitCode).toBe(1);
    expect(result.stderr.toString()).toBe(
      `create-bendo: ${cwd} is not empty. Choose a new or empty directory.\n`,
    );
  });

  test("prints usage for --help", () => {
    const result = Bun.spawnSync([process.execPath, CLI, "--help"], {
      stdin: "ignore",
      stdout: "pipe",
    });
    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString()).toStartWith(
      "Usage: bun create bendo <dir> [--template api|fullstack]",
    );
  });
});
