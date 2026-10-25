// `bun run release`: the argument and publish gates, resuming a partial
// release, and the shape of a real dry run. The dry run packs the three npm
// packages and runs `bend --publish` against the script's local stub hub, so it
// never writes to npm or BendHub. The registry lookups read a recorded fixture,
// so these tests make no network requests and keep passing after a release.
// BENDO_RELEASE_LIVE=1 adds one dry run against the real npm and BendHub.
import { describe, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import {
  NPM_PACKAGES,
  REAL_HUB,
  REGISTRY_FIXTURE_ENV,
  bendEnv,
  decide,
  envOverrides,
  formatReport,
  hubEntrySource,
  hubHash,
  hubShellCommand,
  hubVersion,
  isNpmConfig,
  npmPublishCommand,
  npmRealPublishCommand,
  parseArgs,
  parseHubName,
  parseNpmView,
  parseVersion,
  publishState,
  readTar,
  type GateInput,
  type HubPackage,
  type NpmPackage,
  type RegistryFixture,
  type Report,
} from "../scripts/release-lib.ts";

const ROOT = resolve(import.meta.dir, "..");
const SCRIPT = join(ROOT, "scripts/release.ts");
/** Staging, three packs (one runs create-bendo's prepack), npm checks and two `bend` runs. */
const DRY_RUN_TIMEOUT_MS = 240_000;

/**
 * Runs the script with `fixture` as every registry answer, or against the real
 * registries when it is "live". `env` adds or overrides inherited variables.
 */
function release(
  args: string[],
  stage: string,
  fixture: RegistryFixture | "live" = { npm: {}, hub: {} },
  env: Record<string, string> = {},
) {
  const inherited: Record<string, string | undefined> = { ...process.env };
  delete inherited[REGISTRY_FIXTURE_ENV];
  if (fixture !== "live") {
    const path = join(resolve(stage, ".."), "registry.json");
    writeFileSync(path, JSON.stringify(fixture));
    inherited[REGISTRY_FIXTURE_ENV] = path;
  }
  const result = Bun.spawnSync([process.execPath, SCRIPT, ...args], {
    cwd: ROOT,
    env: { ...inherited, BENDO_RELEASE_DIR: stage, ...env },
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

function withStage<T>(body: (stage: string) => T): T {
  const stage = join(mkdtempSync(join(tmpdir(), "bendo-release-")), "stage");
  try {
    return body(stage);
  } finally {
    rmSync(resolve(stage, ".."), { recursive: true, force: true });
  }
}

/** Parses the script's `--json` output. It is the script's own Report, so the test reads it as one. */
function readReport(result: { code: number | null; stdout: string; stderr: string }): Report {
  if (result.code !== 0) throw new Error(`dry run failed (${result.code}):\n${result.stderr}`);
  return JSON.parse(result.stdout);
}

const stagedHub: HubPackage = {
  name: "bendo",
  version: "0.1.0.0",
  destination: REAL_HUB,
  entry: "bendhub.bend",
  directory: "/stage/bendhub/src",
  hash: "0x00000000000000000000000000000000",
  license: "MIT (LICENSE)",
  bytes: 0,
  files: [],
  importCheck: { kind: "passed", imports: ["bendo@0.1.0.0/main.bend"] },
  requests: [],
  registry: { kind: "publish" },
  command: ["bend", "bendhub.bend", "--publish", "bendo@0.1.0.0"],
};

const stagedNpm: NpmPackage = {
  name: "bendo",
  version: "0.1.0",
  tarball: "/stage/tarballs/bendo-0.1.0.tgz",
  packedBytes: 0,
  unpackedBytes: 0,
  shasum: "0",
  integrity: "sha512-staged",
  access: "public",
  files: [],
  bin: {},
  exports: {},
  dependencies: {},
  peerDependencies: {},
  optionalPeers: [],
  registry: { kind: "publish" },
  npmCheck: { kind: "agrees", id: "bendo@0.1.0", files: 0 },
  command: ["npm", "publish", "/stage/tarballs/bendo-0.1.0.tgz"],
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
  overrides: [],
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
    withStage((stage) => {
      const result = release([], stage);
      expect(result.code).toBe(2);
      expect(result.stderr).toContain("Refusing to run");
      expect(result.stderr).toContain("bun run release --dry-run");
      expect(result.stdout).toBe("");
      expect(existsSync(stage)).toBe(false);
    });
  });

  test("a confirmed run refuses recorded registry answers before staging anything", () => {
    withStage((stage) => {
      const result = release(["--confirm=0.1.0"], stage);
      expect(result.code).toBe(2);
      expect(result.stderr).toContain(`${REGISTRY_FIXTURE_ENV} replaces the real registries`);
      expect(existsSync(stage)).toBe(false);
    });
  });
});

describe("release destination", () => {
  test("bend gets the destination it is given, whatever the shell had", () => {
    const env = bendEnv({
      inherited: {
        PATH: "/bin",
        BEND_HUB: "http://127.0.0.1:9",
        BEND_ORIGIN: "http://127.0.0.1:9",
        BEND_LIB: "/elsewhere",
        NODE_TLS_REJECT_UNAUTHORIZED: "0",
      },
      destination: REAL_HUB,
      lib: "/stage/bend-lib",
    });
    expect(env).toEqual({
      PATH: "/bin",
      BEND_HUB: "https://hub.bend-lang.com",
      BEND_ORIGIN: "https://bend-lang.com",
      BEND_LIB: "/stage/bend-lib",
      BEND_NO_TELEMETRY: "1",
    });
  });

  test("inherited destination and TLS overrides block a publish", () => {
    expect(envOverrides({ PATH: "/bin", BEND_LIB: "/x" })).toEqual([]);
    expect(envOverrides({ BEND_HUB: "https://hub.bend-lang.com" })).toEqual([]);
    const overrides = envOverrides({
      BEND_HUB: "http://127.0.0.1:9",
      BEND_ORIGIN: "http://127.0.0.1:9",
      NODE_TLS_REJECT_UNAUTHORIZED: "0",
    });
    expect(overrides.map((override) => override.name)).toEqual([
      "BEND_HUB",
      "BEND_ORIGIN",
      "NODE_TLS_REJECT_UNAUTHORIZED",
    ]);
    const gate = decide({ ...cleanMain, overrides });
    if (gate.kind !== "stop") throw new Error(`expected stop, got ${gate.kind}`);
    expect(gate.blockers[0]).toBe(
      "BEND_HUB is set to http://127.0.0.1:9: unset it, the release pins its own destination",
    );
  });

  test("inherited npm settings never reach a release command, and block a publish", () => {
    const env = bendEnv({
      inherited: { PATH: "/bin", npm_config_dry_run: "true", NPM_CONFIG_REGISTRY: "http://x" },
      destination: REAL_HUB,
      lib: "/stage/bend-lib",
    });
    expect(Object.keys(env).filter(isNpmConfig)).toEqual([]);
    const overrides = envOverrides({
      npm_config_dry_run: "true",
      npm_config_update_notifier: "false",
    });
    expect(overrides.map((override) => override.name)).toEqual(["npm_config_dry_run"]);
    expect(decide({ ...cleanMain, overrides }).kind).toBe("stop");
  });

  test("the real npm publish forces --dry-run=false after the shared flags", () => {
    const real = npmRealPublishCommand("/t/bendo-0.1.0.tgz");
    expect(real.at(-1)).toBe("--dry-run=false");
    expect(real.slice(0, -1)).toEqual(npmPublishCommand("/t/bendo-0.1.0.tgz"));
  });

  test("the printed publish command names the destination it passes", () => {
    expect(hubShellCommand(stagedHub)).toBe(
      "BEND_HUB=https://hub.bend-lang.com BEND_ORIGIN=https://bend-lang.com bend bendhub.bend --publish bendo@0.1.0.0",
    );
  });
});

describe("resuming a partial release", () => {
  test("a package published with the same contents is skipped, different contents stop", () => {
    expect(publishState({ kind: "absent" }, "sha512-a")).toEqual({ kind: "publish" });
    expect(publishState({ kind: "present", id: "sha512-a" }, "sha512-a")).toEqual({
      kind: "already-published",
    });
    expect(publishState({ kind: "present", id: "sha512-b" }, "sha512-a")).toEqual({
      kind: "conflict",
      published: "sha512-b",
    });
    expect(publishState({ kind: "unknown", reason: "offline" }, "sha512-a")).toEqual({
      kind: "unknown",
      reason: "offline",
    });
  });

  test("npm view answers", () => {
    expect(parseNpmView({ code: 0, stdout: '"sha512-abc"\n', stderr: "" })).toEqual({
      kind: "present",
      id: "sha512-abc",
    });
    expect(parseNpmView({ code: 0, stdout: "", stderr: "" })).toEqual({ kind: "absent" });
    expect(
      parseNpmView({ code: 1, stdout: "", stderr: "npm error code E404\nnpm error 404 Not Found" }),
    ).toEqual({ kind: "absent" });
    expect(
      parseNpmView({ code: 1, stdout: "", stderr: "npm error code ECONNREFUSED\nnpm error x" }),
    ).toEqual({ kind: "unknown", reason: "npm view exited 1: npm error x" });
  });

  test("hub name answers", () => {
    const hash = "0x0123456789abcdef0123456789abcdef";
    expect(parseHubName({ status: 200, body: `${hash}\n` })).toEqual({ kind: "present", id: hash });
    expect(parseHubName({ status: 404, body: "no version bendo@0.1.0.0" })).toEqual({
      kind: "absent",
    });
    expect(parseHubName({ status: 410, body: "" }).kind).toBe("unknown");
    expect(parseHubName({ status: 200, body: "<html>" }).kind).toBe("unknown");
  });

  test("the gate lets already-published packages through and stops on a mismatch", () => {
    const done = {
      ...cleanMain,
      npm: [{ ...stagedNpm, registry: { kind: "already-published" } }],
      hub: { ...stagedHub, registry: { kind: "already-published" } },
    } satisfies GateInput;
    expect(decide(done)).toEqual({ kind: "publish" });
    const gate = decide({
      ...cleanMain,
      npm: [{ ...stagedNpm, registry: { kind: "conflict", published: "sha512-other" } }],
      hub: { ...stagedHub, registry: { kind: "unknown", reason: "the hub answered 503: " } },
    });
    if (gate.kind !== "stop") throw new Error(`expected stop, got ${gate.kind}`);
    expect(gate.blockers).toEqual([
      "bendo@0.1.0 is already on npm with a different integrity (sha512-other): the staged package is not what was published, so stop and find out why",
      "could not ask https://hub.bend-lang.com whether bendo@0.1.0.0 exists: the hub answered 503: ",
    ]);
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
    "reports every npm tarball and the BendHub upload, publishes nothing, and resumes",
    () => {
      withStage((stage) => {
        // A leftover local hub in the shell must not move the dry run's stub.
        const report = readReport(
          release(["--dry-run", "--json"], stage, undefined, { BEND_HUB: "http://127.0.0.1:9" }),
        );
        expect(report.mode).toEqual({ kind: "dry-run" });
        if (report.gate.kind !== "dry-run") throw new Error(`gate is ${report.gate.kind}`);
        expect(report.gate.blockers).toContain(
          "BEND_HUB is set to http://127.0.0.1:9: unset it, the release pins its own destination",
        );
        expect(parseVersion(report.version)).not.toBeNull();

        expect(report.npm.map((pkg) => pkg.name)).toEqual([...NPM_PACKAGES]);
        for (const pkg of report.npm) {
          expect(pkg.version).toBe(report.version);
          expect(pkg.access).toBe("public");
          expect(pkg.npmCheck.kind).toBe("agrees");
          expect(pkg.registry).toEqual({ kind: "publish" });
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
        const [bendo, plugin, create] = report.npm;
        if (bendo === undefined || plugin === undefined || create === undefined)
          throw new Error("missing npm packages");
        expect(plugin.dependencies.bendo).toBe(`^${report.version}`);
        expect(create.files.map((file) => file.path)).toContain("bend/src/main.bend");

        const hub = report.hub;
        if (hub === null) throw new Error("no BendHub package in the report");
        expect(hub.name).toBe("bendo");
        expect(hub.version).toBe(`${report.version}.0`);
        expect(hub.destination).toEqual(REAL_HUB);
        expect(hub.registry).toEqual({ kind: "publish" });
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
        expect(text).toContain(
          `&& BEND_HUB=https://hub.bend-lang.com BEND_ORIGIN=https://bend-lang.com bend bendhub.bend`,
        );
        expect(text).toContain(`bun run release --confirm=${report.version}`);

        // After a partial release: bendo and the BendHub package landed, and
        // vite-plugin-bendo is on npm with other contents. A second staging
        // packs byte-identical tarballs, so the landed ones are skipped.
        const resumed = readReport(
          release(["--dry-run", "--json"], stage, {
            npm: {
              [`bendo@${report.version}`]: bendo.integrity,
              [`vite-plugin-bendo@${report.version}`]: "sha512-other",
            },
            hub: { [`bendo@${hub.version}`]: hub.hash },
          }),
        );
        expect(resumed.npm.map((pkg) => [pkg.name, pkg.integrity, pkg.registry])).toEqual([
          ["bendo", bendo.integrity, { kind: "already-published" }],
          ["vite-plugin-bendo", plugin.integrity, { kind: "conflict", published: "sha512-other" }],
          ["create-bendo", create.integrity, { kind: "publish" }],
        ]);
        expect(resumed.hub?.hash).toBe(hub.hash);
        expect(resumed.hub?.registry).toEqual({ kind: "already-published" });
        // The git blockers depend on where the test runs; the registry ones do not.
        if (resumed.gate.kind !== "dry-run") throw new Error(`gate is ${resumed.gate.kind}`);
        expect(resumed.gate.blockers.filter((reason) => / on (npm|https:)/.test(reason))).toEqual([
          `vite-plugin-bendo@${report.version} is already on npm with a different integrity (sha512-other): the staged package is not what was published, so stop and find out why`,
        ]);
        expect(formatReport(resumed)).toContain(
          "registry: already on npm with the same integrity: a confirmed run skips it",
        );
      });
    },
    2 * DRY_RUN_TIMEOUT_MS,
  );

  test.skipIf(process.env.BENDO_RELEASE_LIVE !== "1")(
    "BENDO_RELEASE_LIVE=1: the real npm and BendHub answer the lookups",
    () => {
      withStage((stage) => {
        const report = readReport(release(["--dry-run", "--json"], stage, "live"));
        for (const pkg of report.npm) expect(pkg.registry.kind).not.toBe("unknown");
        expect(report.hub?.registry.kind).not.toBe("unknown");
      });
    },
    DRY_RUN_TIMEOUT_MS,
  );
});
