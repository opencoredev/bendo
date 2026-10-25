// `bun run release`: the argument and publish gates, and the shape of a real
// dry run. The dry run packs the three npm packages and runs `bend --publish`
// against the script's local stub hub, so it never writes to npm or BendHub.
import { describe, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import {
  NPM_PACKAGES,
  decide,
  formatReport,
  hubEntrySource,
  hubHash,
  hubVersion,
  parseArgs,
  parseVersion,
  readTar,
  type GateInput,
  type HubPackage,
  type Report,
} from "../scripts/release-lib.ts";

const ROOT = resolve(import.meta.dir, "..");
const SCRIPT = join(ROOT, "scripts/release.ts");
/** Staging, three packs (one runs create-bendo's prepack), npm checks and two `bend` runs. */
const DRY_RUN_TIMEOUT_MS = 240_000;

function release(args: string[], stage: string) {
  const result = Bun.spawnSync([process.execPath, SCRIPT, ...args], {
    cwd: ROOT,
    env: { ...process.env, BENDO_RELEASE_DIR: stage },
    stdin: "ignore",
    stdout: "pipe",
    stderr: "pipe",
    timeout: DRY_RUN_TIMEOUT_MS - 10_000,
  });
  return {
    code: result.exitCode,
    stdout: result.stdout.toString(),
    stderr: result.stderr.toString(),
  };
}

const stagedHub: HubPackage = {
  name: "bendo",
  version: "0.1.0.0",
  url: "https://hub.bend-lang.com",
  entry: "bendhub.bend",
  directory: "/stage/bendhub/src",
  hash: "0x00000000000000000000000000000000",
  license: "MIT (LICENSE)",
  bytes: 0,
  files: [],
  importCheck: { kind: "passed", imports: ["bendo@0.1.0.0/main.bend"] },
  requests: [],
  command: ["bend", "bendhub.bend", "--publish", "bendo@0.1.0.0"],
};

const cleanMain: GateInput = {
  mode: { kind: "confirm", version: "0.1.0" },
  targets: ["npm", "bendhub"],
  git: { branch: "main", head: "a", changes: 0, originMain: "a" },
  pendingChangesets: [],
  versions: { bendo: "0.1.0", "vite-plugin-bendo": "0.1.0", "create-bendo": "0.1.0" },
  npm: [],
  hub: stagedHub,
  logins: { npm: true, bend: true },
};

describe("release arguments", () => {
  test("no --dry-run and no --confirm refuses", () => {
    const parsed = parseArgs([]);
    expect(parsed.kind).toBe("refuse");
    expect(parseArgs(["--only=npm"]).kind).toBe("refuse");
  });

  test("dry run, confirm and their conflicts", () => {
    expect(parseArgs(["--dry-run"])).toEqual({
      kind: "run",
      options: { mode: { kind: "dry-run" }, json: false, targets: ["npm", "bendhub"] },
    });
    expect(parseArgs(["--confirm", "0.1.0", "--only", "bendhub"])).toEqual({
      kind: "run",
      options: { mode: { kind: "confirm", version: "0.1.0" }, json: false, targets: ["bendhub"] },
    });
    expect(parseArgs(["--dry-run", "--confirm=0.1.0"]).kind).toBe("usage");
    expect(parseArgs(["--confirm"]).kind).toBe("usage");
    expect(parseArgs(["--confirm=0.1.0", "--json"]).kind).toBe("usage");
    expect(parseArgs(["--only=pypi", "--dry-run"]).kind).toBe("usage");
    expect(parseArgs(["--publish"]).kind).toBe("usage");
  });

  test("the script refuses before staging anything", () => {
    const stage = join(mkdtempSync(join(tmpdir(), "bendo-release-")), "stage");
    try {
      const result = release([], stage);
      expect(result.code).toBe(2);
      expect(result.stderr).toContain("Refusing to run");
      expect(result.stderr).toContain("bun run release --dry-run");
      expect(result.stdout).toBe("");
      expect(existsSync(stage)).toBe(false);
    } finally {
      rmSync(resolve(stage, ".."), { recursive: true, force: true });
    }
  });
});

describe("release gate", () => {
  test("a confirmed run on a clean, pushed main publishes", () => {
    expect(decide(cleanMain)).toEqual({ kind: "publish" });
  });

  test("the confirmed version must be the one being released", () => {
    const gate = decide({ ...cleanMain, mode: { kind: "confirm", version: "0.2.0" } });
    expect(gate.kind).toBe("refuse");
  });

  test("anything off main, dirty, unpushed or unversioned stops", () => {
    const gate = decide({
      ...cleanMain,
      mode: { kind: "confirm", version: "0.0.0" },
      hub: null,
      git: { branch: "topic", head: "b", changes: 2, originMain: "a" },
      pendingChangesets: ["initial-release.md"],
      versions: { bendo: "0.0.0", "vite-plugin-bendo": "0.0.0", "create-bendo": "0.1.0" },
      logins: { npm: false, bend: false },
    });
    if (gate.kind !== "stop") throw new Error(`expected stop, got ${gate.kind}`);
    expect(gate.blockers).toEqual([
      "not on main (on topic)",
      "the working tree has 2 uncommitted change(s)",
      "HEAD is not origin/main: push or pull first",
      "changesets are not applied (initial-release.md): run `bun run version-packages` and commit",
      "the packages disagree on the version (0.0.0, 0.1.0)",
      "the version is 0.0.0",
      "the BendHub package was not staged",
      "npm is not logged in: run `npm login`",
      "bend is not logged in: run `bend login`",
    ]);
  });

  test("a dry run always runs and lists the blockers", () => {
    const gate = decide({ ...cleanMain, mode: { kind: "dry-run" }, logins: null, hub: null });
    expect(gate).toEqual({ kind: "dry-run", blockers: ["the BendHub package was not staged"] });
    expect(decide({ ...cleanMain, mode: { kind: "dry-run" }, logins: null })).toEqual({
      kind: "dry-run",
      blockers: [],
    });
  });
});

describe("BendHub package", () => {
  test("versions take a fourth number of 0", () => {
    const version = parseVersion("0.1.0");
    if (version === null) throw new Error("0.1.0 did not parse");
    expect(hubVersion(version)).toBe("0.1.0.0");
    expect(parseVersion("0.1.0-next.1")).toBeNull();
    expect(parseVersion("01.0.0")).toBeNull();
  });

  test("the hash is the first 32 hex digits of the sorted manifest's SHA-256", () => {
    const sha = (text: string) => createHash("sha256").update(text).digest("hex");
    const manifest = `${sha("b")} a.bend\n${sha("a")} z/b.bend\n`;
    expect(hubHash({ "z/b.bend": "a", "a.bend": "b" })).toBe(`0x${sha(manifest).slice(0, 32)}`);
  });

  test("the entry imports public modules and leaves proofs out", () => {
    const entry = hubEntrySource([
      "main.bend",
      "ws/pubsub.bend",
      "router/trie-proofs.bend",
      "router/proofs.bend",
      "effects/clock.c",
      "bendhub.bend",
    ]);
    expect(entry.split("\n").filter((line) => line.startsWith("import"))).toEqual([
      "import Base",
      "import ./main.bend as M_main",
      "import ./ws/pubsub.bend as M_ws_pubsub",
    ]);
    expect(() => hubEntrySource(["a-b.bend", "a_b.bend"])).toThrow("share the alias");
  });
});

describe("bun run release --dry-run", () => {
  test(
    "reports every npm tarball and the BendHub upload, and publishes nothing",
    () => {
      const stage = join(mkdtempSync(join(tmpdir(), "bendo-release-")), "stage");
      try {
        const result = release(["--dry-run", "--json"], stage);
        if (result.code !== 0)
          throw new Error(`dry run failed (${result.code}):\n${result.stderr}`);
        // The JSON is the script's own Report, so the test reads it as one.
        const report: Report = JSON.parse(result.stdout);
        expect(report.mode).toEqual({ kind: "dry-run" });
        expect(report.gate.kind).toBe("dry-run");
        expect(parseVersion(report.version)).not.toBeNull();

        expect(report.npm.map((pkg) => pkg.name)).toEqual([...NPM_PACKAGES]);
        for (const pkg of report.npm) {
          expect(pkg.version).toBe(report.version);
          expect(pkg.access).toBe("public");
          expect(pkg.npmCheck.kind).toBe("agrees");
          expect(pkg.registry).not.toBe("published");
          expect(pkg.command.slice(0, 3)).toEqual(["npm", "publish", pkg.tarball]);
          expect(pkg.command).toContain("--access");
          const paths = pkg.files.map((file) => file.path);
          expect(paths).toContain("package.json");
          expect(paths).toContain("LICENSE");
          expect(paths.filter((path) => /\.test\.ts$|fixture/.test(path))).toEqual([]);
          // The listing is the tarball: same paths, same sizes.
          const tar = readTar(Bun.gunzipSync(new Uint8Array(readFileSync(pkg.tarball))));
          expect(tar.map((entry) => entry.path.replace(/^package\//, "")).sort()).toEqual(
            [...paths].sort(),
          );
          expect(pkg.unpackedBytes).toBe(tar.reduce((sum, entry) => sum + entry.bytes, 0));
          expect(
            Object.values(pkg.dependencies).some((range) => range.startsWith("workspace:")),
          ).toBe(false);
        }
        const [, plugin, create] = report.npm;
        expect(plugin?.dependencies.bendo).toBe(`^${report.version}`);
        expect(create?.files.map((file) => file.path)).toContain("bend/src/main.bend");

        const hub = report.hub;
        if (hub === null) throw new Error("no BendHub package in the report");
        expect(hub.name).toBe("bendo");
        expect(hub.version).toBe(`${report.version}.0`);
        expect(hub.hash).toMatch(/^0x[0-9a-f]{32}$/);
        expect(hub.license).toBe("MIT (LICENSE)");
        expect(hub.importCheck.kind).toBe("passed");
        expect(hub.requests).toContain("POST /");
        expect(hub.command).toEqual(["bend", "bendhub.bend", "--publish", `bendo@${hub.version}`]);
        const paths = hub.files.map((file) => file.path);
        for (const path of [
          "main.bend",
          "validated.bend",
          "ws/pubsub.bend",
          "effects/clock.c",
          "LICENSE",
        ])
          expect(paths).toContain(path);
        const files = Object.fromEntries(
          hub.files.map((file) => [
            file.path,
            readFileSync(join(hub.directory, file.path), "utf8"),
          ]),
        );
        expect(hubHash(files)).toBe(hub.hash);

        const text = formatReport(report);
        expect(text).toStartWith("Bendo release: DRY RUN. Nothing was published");
        for (const pkg of report.npm) expect(text).toContain(`  ${pkg.name}@${pkg.version}\n`);
        expect(text).toContain(`  bendo@${hub.version}\n    hash: ${hub.hash}`);
        expect(text).toContain(`bun run release --confirm=${report.version}`);
      } finally {
        rmSync(resolve(stage, ".."), { recursive: true, force: true });
      }
    },
    DRY_RUN_TIMEOUT_MS,
  );
});
