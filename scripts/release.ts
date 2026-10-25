// `bun run release`: stage, pack and check the npm packages and the BendHub
// package, then print exactly what would publish. Publishing is Leo's step:
// without --dry-run or --confirm=<version> this refuses before doing anything,
// and a confirmed run still stops unless it is on a clean main that matches
// origin/main. docs/releasing.md walks through it.
//
// A dry run never writes to npm or BendHub. It packs tarballs into the staging
// directory, asks `npm publish --dry-run` and `npm view` about them, runs the
// real `bend --publish` against a stub hub on 127.0.0.1 that keeps the upload
// in memory and serves it back for an import check, and looks up whether the
// hub already links the name. A confirmed run skips whatever is already
// published with the same tarball or hash, so rerunning it resumes a release.
import {
  chmodSync,
  cpSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { join, relative, resolve } from "node:path";
import {
  HUB_ENTRY,
  HUB_IMPORT_CHECK,
  HUB_PACKAGE,
  NPM_PACKAGES,
  NPM_REGISTRY,
  PUBLISH_VISIBLE_DELAYS_MS,
  REAL_HUB,
  REGISTRY_FIXTURE_ENV,
  awaitPublished,
  bendEnv,
  isNpmConfig,
  npmRealPublishCommand,
  decide,
  envOverrides,
  fixtureLookup,
  formatReport,
  hubConsumerSource,
  hubEntrySource,
  hubFiles,
  hubHash,
  hubManifest,
  hubPublishCommand,
  hubShellCommand,
  hubVersion,
  npmPublishCommand,
  parseArgs,
  parseHubName,
  parseNpmView,
  parseRegistryFixture,
  parseVersion,
  publishState,
  readTar,
  shellCommand,
  type GitState,
  type HubCheck,
  type HubPackage,
  type Lookup,
  type NpmCheck,
  type PublishState,
  type NpmPackage,
  type NpmPackageName,
  type Options,
  type Report,
} from "./release-lib.ts";

const ROOT = resolve(import.meta.dir, "..");
const STAGE = resolve(process.env.BENDO_RELEASE_DIR ?? join(ROOT, ".cache/release"));
/** bend's download cache for every run here, so a stub's packages never reach ~/.bend/lib. */
const BEND_LIB = join(STAGE, "bend-lib");
/** Marks a directory this script made, so a rerun only ever wipes its own staging. */
const MARKER = ".bendo-release-stage";
const BEND_TIMEOUT_MS = 300_000;
const NPM_TIMEOUT_MS = 60_000;
const PACK_TIMEOUT_MS = 120_000;

type Ran = { code: number; stdout: string; stderr: string };

function run(
  command: readonly string[],
  cwd: string,
  timeout: number,
  env: Record<string, string> = {},
): Ran {
  const inherited: Record<string, string> = {};
  for (const [name, value] of Object.entries(process.env))
    if (value !== undefined && !isNpmConfig(name)) inherited[name] = value;
  const result = Bun.spawnSync([...command], {
    cwd,
    env: { ...inherited, BEND_NO_TELEMETRY: "1", npm_config_update_notifier: "false", ...env },
    stdin: "ignore",
    stdout: "pipe",
    stderr: "pipe",
    timeout,
  });
  return {
    code: result.exitCode ?? -1,
    stdout: result.stdout.toString(),
    stderr: result.stderr.toString(),
  };
}

function must(command: readonly string[], cwd: string, timeout: number): string {
  const result = run(command, cwd, timeout);
  if (result.code !== 0)
    throw new Error(
      `${shellCommand(command)} failed (${result.code}) in ${cwd}:\n${result.stdout}${result.stderr}`,
    );
  return result.stdout;
}

/**
 * Async spawn, so the in-process stub hub keeps answering while `bend` runs.
 * `env` is the whole environment, from `bendEnv`.
 */
async function runAsync(
  command: readonly string[],
  cwd: string,
  timeout: number,
  env: Record<string, string>,
): Promise<Ran> {
  const child = Bun.spawn([...command], {
    cwd,
    env,
    stdin: "ignore",
    stdout: "pipe",
    stderr: "pipe",
    timeout,
  });
  const [stdout, stderr, code] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ]);
  return { code, stdout, stderr };
}

// ---------------------------------------------------------------- JSON at the boundary

type Manifest = {
  name: string;
  version: string;
  bin: Record<string, string>;
  exports: Record<string, string>;
  dependencies: Record<string, string>;
  peerDependencies: Record<string, string>;
  optionalPeers: string[];
  access: string;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringMap(value: unknown, field: string): Record<string, string> {
  if (value === undefined) return {};
  if (!isRecord(value)) throw new Error(`${field} is not an object`);
  const out: Record<string, string> = {};
  for (const [key, entry] of Object.entries(value)) {
    if (typeof entry !== "string") throw new Error(`${field}.${key} is not a string`);
    out[key] = entry;
  }
  return out;
}

function parseManifest(text: string, where: string): Manifest {
  const data: unknown = JSON.parse(text);
  if (!isRecord(data)) throw new Error(`${where} is not a JSON object`);
  const { name, version } = data;
  if (typeof name !== "string" || typeof version !== "string")
    throw new Error(`${where} has no name or version`);
  const meta = isRecord(data.peerDependenciesMeta) ? data.peerDependenciesMeta : {};
  const publishConfig = isRecord(data.publishConfig) ? data.publishConfig : {};
  return {
    name,
    version,
    bin: stringMap(data.bin, `${where} bin`),
    exports: stringMap(data.exports, `${where} exports`),
    dependencies: stringMap(data.dependencies, `${where} dependencies`),
    peerDependencies: stringMap(data.peerDependencies, `${where} peerDependencies`),
    optionalPeers: Object.entries(meta).flatMap(([peer, value]) =>
      isRecord(value) && value.optional === true ? [peer] : [],
    ),
    access: typeof publishConfig.access === "string" ? publishConfig.access : "(unset)",
  };
}

// ---------------------------------------------------------------- git

function git(args: readonly string[]): string {
  return must(["git", ...args], ROOT, 30_000).trim();
}

function gitState(fetch: boolean): GitState {
  if (fetch) must(["git", "fetch", "--quiet", "origin", "main"], ROOT, 60_000);
  const origin = run(
    ["git", "rev-parse", "--verify", "--quiet", "refs/remotes/origin/main"],
    ROOT,
    30_000,
  );
  return {
    branch: git(["rev-parse", "--abbrev-ref", "HEAD"]),
    head: git(["rev-parse", "HEAD"]),
    changes: git(["status", "--porcelain"])
      .split("\n")
      .filter((line) => line !== "").length,
    originMain: origin.code === 0 ? origin.stdout.trim() : null,
  };
}

function pendingChangesets(): string[] {
  return readdirSync(join(ROOT, ".changeset"))
    .filter((file) => file.endsWith(".md") && file !== "README.md")
    .sort();
}

// ---------------------------------------------------------------- staging

function freshStage(): void {
  if (existsSync(STAGE)) {
    if (!existsSync(join(STAGE, MARKER)))
      throw new Error(`${STAGE} exists and was not made by the release script; move it away first`);
    rmSync(STAGE, { recursive: true, force: true });
  }
  mkdirSync(STAGE, { recursive: true });
  writeFileSync(join(STAGE, MARKER), "staging for scripts/release.ts; safe to delete\n");
}

/**
 * Sets every file in `dir` to 0644, or 0755 if any execute bit was set, and
 * every directory to 0755. Tarballs record modes, so without this the same
 * contents packed from checkouts with different umasks would get different
 * integrities, and resuming a partial release would see a conflict.
 */
function normalizeModes(dir: string): void {
  chmodSync(dir, 0o755);
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isSymbolicLink()) continue;
    if (entry.isDirectory()) normalizeModes(path);
    else chmodSync(path, (statSync(path).mode & 0o111) === 0 ? 0o644 : 0o755);
  }
}

/**
 * A copy of the workspace with just the three packages, the Bend library and
 * the pins (create-bendo's prepack reads them), with pending changesets applied.
 * The repository itself is never modified.
 */
function stageWorkspace(pending: readonly string[]): string {
  const workspace = join(STAGE, "workspace");
  mkdirSync(join(workspace, "packages"), { recursive: true });
  for (const name of NPM_PACKAGES) {
    const from = join(ROOT, "packages", name);
    const to = join(workspace, "packages", name);
    cpSync(from, to, {
      recursive: true,
      filter: (path) => {
        const inside = relative(from, path).split("/");
        return (
          !inside.includes("node_modules") && !(name === "create-bendo" && inside[0] === "bend")
        );
      },
    });
    // npm puts LICENSE in every tarball; keep one copy in the repository.
    cpSync(join(ROOT, "LICENSE"), join(to, "LICENSE"));
  }
  for (const path of [
    "src",
    ".bend-version",
    "lean-toolchain",
    "LICENSE",
    ".changeset",
    "bun.lock",
  ])
    cpSync(join(ROOT, path), join(workspace, path), { recursive: true });
  writeFileSync(
    join(workspace, "package.json"),
    `${JSON.stringify({ name: "bendo-release-stage", private: true, workspaces: ["packages/*"] }, null, 2)}\n`,
  );
  // Changesets loads its changelog generator and oxfmt from here.
  symlinkSync(join(ROOT, "node_modules"), join(workspace, "node_modules"));
  if (pending.length > 0)
    must([join(ROOT, "node_modules/.bin/changeset"), "version"], workspace, 120_000);
  // create-bendo's prepack copies the staged src/ and pins into its tarball.
  normalizeModes(workspace);
  return workspace;
}

function stagedVersions(workspace: string): Record<NpmPackageName, string> {
  const read = (name: NpmPackageName) =>
    parseManifest(readFileSync(join(workspace, "packages", name, "package.json"), "utf8"), name)
      .version;
  return {
    bendo: read("bendo"),
    "vite-plugin-bendo": read("vite-plugin-bendo"),
    "create-bendo": read("create-bendo"),
  };
}

// ---------------------------------------------------------------- registries (read only)

/** What npm and BendHub already hold. Tests swap in recorded answers so they stay off the network. */
type Registries = {
  npm: (name: string, version: string) => Lookup;
  hub: (named: string) => Promise<Lookup>;
};

const liveRegistries: Registries = {
  npm: (name, version) =>
    parseNpmView(
      run(
        [
          "npm",
          "view",
          `${name}@${version}`,
          "dist.integrity",
          "--json",
          "--prefer-online",
          "--registry",
          NPM_REGISTRY,
        ],
        ROOT,
        NPM_TIMEOUT_MS,
      ),
    ),
  hub: async (named) => {
    const response = await fetch(`${REAL_HUB.hub}/name/${named}`, {
      signal: AbortSignal.timeout(30_000),
    }).catch((error: unknown) => (error instanceof Error ? error : new Error(String(error))));
    if (response instanceof Error)
      return {
        kind: "unknown",
        reason: `${REAL_HUB.hub} could not be reached: ${response.message}`,
      };
    return parseHubName({ status: response.status, body: await response.text() });
  },
};

function fixtureRegistries(path: string): Registries {
  const fixture = parseRegistryFixture(readFileSync(path, "utf8"));
  return {
    npm: (name, version) => fixtureLookup(fixture.npm, `${name}@${version}`),
    hub: (named) => Promise.resolve(fixtureLookup(fixture.hub, named)),
  };
}

// ---------------------------------------------------------------- npm

function npmCheck(input: {
  tarball: string;
  name: string;
  version: string;
  files: number;
  integrity: string;
}): NpmCheck {
  const { tarball, name, version, files } = input;
  // --offline: the check needs nothing from the registry, so it asks for nothing.
  const result = run(
    ["npm", "publish", "--dry-run", "--offline", "--json", ...npmPublishCommand(tarball).slice(2)],
    STAGE,
    NPM_TIMEOUT_MS,
  );
  if (result.code !== 0)
    return {
      kind: "failed",
      reason: `exit ${result.code}: ${result.stderr.trim().split("\n").at(-1) ?? ""}`,
    };
  const data: unknown = JSON.parse(result.stdout);
  const entry = isRecord(data) ? data[name] : undefined;
  if (
    !isRecord(entry) ||
    typeof entry.id !== "string" ||
    typeof entry.entryCount !== "number" ||
    typeof entry.integrity !== "string"
  )
    return { kind: "failed", reason: "unexpected --json output" };
  if (entry.id !== `${name}@${version}`)
    return { kind: "disagrees", reason: `npm reads ${entry.id}` };
  if (entry.entryCount !== files)
    return {
      kind: "disagrees",
      reason: `npm counts ${entry.entryCount} files, the tarball has ${files}`,
    };
  // The registry lookup compares against this integrity, so npm must upload exactly it.
  if (entry.integrity !== input.integrity)
    return { kind: "disagrees", reason: `npm computes integrity ${entry.integrity}` };
  return { kind: "agrees", id: entry.id, files: entry.entryCount };
}

function packNpm(workspace: string, name: NpmPackageName, registries: Registries): NpmPackage {
  const out = join(STAGE, "tarballs");
  mkdirSync(out, { recursive: true });
  // create-bendo's prepack prints its command before the tarball path.
  const printed = must(
    ["bun", "pm", "pack", "--destination", out, "--quiet"],
    join(workspace, "packages", name),
    PACK_TIMEOUT_MS,
  );
  const tarball = printed.trim().split("\n").at(-1) ?? "";
  const bytes = new Uint8Array(readFileSync(tarball));
  const entries = readTar(Bun.gunzipSync(bytes));
  const packageJson = entries.find((entry) => entry.path === "package/package.json");
  if (packageJson === undefined) throw new Error(`${tarball} has no package/package.json`);
  const manifest = parseManifest(
    new TextDecoder().decode(packageJson.content),
    `${tarball} package.json`,
  );
  const files = entries
    .map((entry) => ({ path: entry.path.replace(/^package\//, ""), bytes: entry.bytes }))
    .sort((a, b) => a.path.localeCompare(b.path));
  const integrity = `sha512-${new Bun.CryptoHasher("sha512").update(bytes).digest("base64")}`;
  const registry = publishState(registries.npm(manifest.name, manifest.version), integrity);
  return {
    name,
    version: manifest.version,
    tarball,
    packedBytes: bytes.length,
    unpackedBytes: files.reduce((sum, file) => sum + file.bytes, 0),
    shasum: new Bun.CryptoHasher("sha1").update(bytes).digest("hex"),
    integrity,
    access: manifest.access,
    files,
    bin: manifest.bin,
    exports: manifest.exports,
    dependencies: manifest.dependencies,
    peerDependencies: manifest.peerDependencies,
    optionalPeers: manifest.optionalPeers,
    registry,
    npmCheck:
      registry.kind === "already-published"
        ? { kind: "skipped" }
        : npmCheck({
            tarball,
            name: manifest.name,
            version: manifest.version,
            files: files.length,
            integrity,
          }),
    command: npmPublishCommand(tarball),
  };
}

// ---------------------------------------------------------------- BendHub

function listModules(directory: string, prefix = ""): string[] {
  return readdirSync(join(directory, prefix), { withFileTypes: true }).flatMap((entry) => {
    const path = prefix === "" ? entry.name : `${prefix}/${entry.name}`;
    return entry.isDirectory() ? listModules(directory, path) : [path];
  });
}

/**
 * A stand-in for hub.bend-lang.com on 127.0.0.1. It accepts one anonymous
 * upload (checking the hash the way the hub does), names it, and serves it back
 * so a consumer can import it. Everything stays in memory.
 */
function stubHub() {
  const requests: string[] = [];
  let upload: Record<string, string> | null = null;
  const server = Bun.serve({
    hostname: "127.0.0.1",
    port: 0,
    async fetch(request) {
      const url = new URL(request.url);
      const path = decodeURIComponent(url.pathname);
      requests.push(`${request.method} ${path}`);
      // The lowest difficulty, so the proof of work takes one or two hashes.
      if (path === "/pow.json") return Response.json({ pow: 1 });
      if (request.method === "POST" && path === "/") {
        const body: unknown = await request.json();
        if (!isRecord(body) || !isRecord(body.files))
          return new Response("bad upload", { status: 400 });
        upload = stringMap(body.files, "upload files");
        return new Response(hubHash(upload));
      }
      if (upload === null) return new Response("nothing uploaded", { status: 404 });
      const hash = hubHash(upload);
      if (path.startsWith(`/name/${HUB_PACKAGE}@`)) return new Response(`${hash}\n`);
      if (path === `/${hash}/manifest`) return new Response(hubManifest(upload));
      const file = path.startsWith(`/${hash}/`) ? upload[path.slice(hash.length + 2)] : undefined;
      return file === undefined
        ? new Response("no such file", { status: 404 })
        : new Response(file);
    },
  });
  return {
    url: `http://127.0.0.1:${server.port}`,
    requests,
    upload: () => upload,
    stop: () => server.stop(true),
  };
}

function licenseOf(files: Readonly<Record<string, string>>): string {
  const text = files.LICENSE;
  if (text === undefined) return "MIT-0 (no LICENSE file)";
  const spdx = /^\s*SPDX-License-Identifier:\s*(\S+)/m.exec(text)?.[1];
  return spdx === undefined ? "see LICENSE" : `${spdx} (LICENSE)`;
}

async function stageHub(version: string, registries: Registries): Promise<HubPackage> {
  const parsed = parseVersion(version);
  if (parsed === null) throw new Error(`${version} is not a plain x.y.z version`);
  const directory = join(STAGE, "bendhub", "src");
  cpSync(join(ROOT, "src"), directory, { recursive: true });
  // `bend --publish` takes the LICENSE beside the entry file.
  cpSync(join(ROOT, "LICENSE"), join(directory, "LICENSE"));
  writeFileSync(join(directory, HUB_ENTRY), hubEntrySource(listModules(directory)));
  normalizeModes(directory);

  const hub = stubHub();
  // Set here, never inherited: a leftover BEND_HUB must not move the dry run either.
  const env = bendEnv({
    inherited: process.env,
    destination: { hub: hub.url, origin: hub.url },
    lib: BEND_LIB,
  });
  try {
    const publish = await runAsync(
      ["bend", HUB_ENTRY, "--publish"],
      directory,
      BEND_TIMEOUT_MS,
      env,
    );
    const files = hub.upload();
    if (publish.code !== 0 || files === null)
      throw new Error(
        `bend --publish to the stub hub failed (${publish.code}):\n${publish.stdout}${publish.stderr}`,
      );
    const hash = hubHash(files);
    if (!publish.stdout.includes(hash))
      throw new Error(
        `bend printed a different hash than the stub computed (${hash}):\n${publish.stdout}`,
      );

    const named = `${HUB_PACKAGE}@${hubVersion(parsed)}`;
    const consumer = join(STAGE, "bendhub-consumer");
    mkdirSync(consumer, { recursive: true });
    writeFileSync(join(consumer, "consumer.bend"), hubConsumerSource(named));
    const imported = await runAsync(["bend", "consumer.bend"], consumer, BEND_TIMEOUT_MS, env);
    const importCheck: HubCheck =
      imported.code === 0 && imported.stdout.trim() === "7"
        ? { kind: "passed", imports: HUB_IMPORT_CHECK.map((module) => `${named}/${module}`) }
        : {
            kind: "failed",
            reason: `bend consumer.bend exited ${imported.code}: ${`${imported.stdout}${imported.stderr}`.trim().slice(0, 400)}`,
          };
    const listed = hubFiles(files);
    return {
      name: HUB_PACKAGE,
      version: hubVersion(parsed),
      destination: REAL_HUB,
      entry: HUB_ENTRY,
      directory,
      hash,
      license: licenseOf(files),
      bytes: listed.reduce((sum, file) => sum + file.bytes, 0),
      files: listed,
      importCheck,
      requests: [
        ...new Set(
          hub.requests.map((line) => line.replace(/^(GET \/0x[0-9a-f]+\/).+$/, "$1<file>")),
        ),
      ],
      registry: publishState(await registries.hub(named), hash),
      command: hubPublishCommand(parsed),
    };
  } finally {
    hub.stop();
  }
}

// ---------------------------------------------------------------- logins (confirmed runs only)

function logins(): { npm: boolean; bend: boolean } {
  return {
    npm:
      run(["npm", "whoami", "--registry", "https://registry.npmjs.org/"], ROOT, NPM_TIMEOUT_MS)
        .code === 0,
    bend: existsSync(join(homedir(), ".bend", "bendai.json")),
  };
}

// ---------------------------------------------------------------- main

async function release(options: Options, registries: Registries): Promise<number> {
  const confirmed = options.mode.kind === "confirm";
  const git = gitState(confirmed);
  const pending = pendingChangesets();
  freshStage();
  const workspace = stageWorkspace(pending);
  const versions = stagedVersions(workspace);
  const version = versions.bendo;
  const parsed = parseVersion(version);

  const npm = options.targets.includes("npm")
    ? NPM_PACKAGES.map((name) => packNpm(workspace, name, registries))
    : [];
  const hub = options.targets.includes("bendhub") ? await stageHub(version, registries) : null;
  const gate = decide({
    mode: options.mode,
    targets: options.targets,
    git,
    pendingChangesets: pending,
    versions,
    npm,
    hub,
    logins: confirmed ? logins() : null,
    overrides: envOverrides(process.env),
  });
  const report: Report = {
    mode: options.mode,
    targets: options.targets,
    git,
    pendingChangesets: pending,
    version,
    hubVersion: parsed === null ? "(none)" : hubVersion(parsed),
    npm,
    hub,
    gate,
  };
  process.stdout.write(
    options.json ? `${JSON.stringify(report, null, 2)}\n` : formatReport(report),
  );

  switch (gate.kind) {
    case "dry-run":
      return 0;
    case "refuse":
      return 2;
    case "stop":
      return 3;
    case "publish":
      break;
    default: {
      const exhaustive: never = gate;
      return exhaustive;
    }
  }

  // Leo's confirmed run on a clean, pushed main. npm first: an npm version can
  // be deprecated or, within 72 hours, unpublished. A BendHub publish cannot be
  // undone. Anything already published with the same tarball or hash was an
  // earlier run's, so it is skipped and the rerun finishes the release.
  // Every step gets the pinned destination, whatever the shell had.
  const env = bendEnv({ inherited: process.env, destination: REAL_HUB, lib: BEND_LIB });
  const steps: {
    id: string;
    skip: boolean;
    cwd: string;
    command: string[];
    shown: string;
    verify?: () => PublishState;
  }[] = [
    ...npm.map((pkg) => ({
      id: `${pkg.name}@${pkg.version} on npm`,
      skip: pkg.registry.kind === "already-published",
      cwd: STAGE,
      command: npmRealPublishCommand(pkg.tarball),
      shown: shellCommand(npmRealPublishCommand(pkg.tarball)),
      // npm can exit 0 without uploading (a dry-run setting it still found):
      // the registry must hold this exact tarball before anything else runs.
      verify: () => publishState(registries.npm(pkg.name, pkg.version), pkg.integrity),
    })),
    ...(hub === null
      ? []
      : [
          {
            id: `${hub.name}@${hub.version} on ${hub.destination.hub}`,
            skip: hub.registry.kind === "already-published",
            cwd: hub.directory,
            command: hub.command,
            shown: hubShellCommand({
              destination: { hub: env.BEND_HUB, origin: env.BEND_ORIGIN },
              command: hub.command,
            }),
          },
        ]),
  ];
  for (const step of steps) {
    if (step.skip) {
      process.stdout.write(`\nSkipping ${step.id}: already published with the same contents.\n`);
      continue;
    }
    process.stdout.write(`\n$ (cd ${step.cwd} && ${step.shown})\n`);
    const child = Bun.spawn(step.command, {
      cwd: step.cwd,
      env,
      stdio: ["inherit", "inherit", "inherit"],
    });
    const code = await child.exited;
    if (code !== 0) {
      process.stderr.write(
        `\nStopped: ${shellCommand(step.command)} exited ${code}. Earlier steps did publish.\n` +
          `Rerun bun run release --confirm=${version} to finish: it skips what is already published.\n`,
      );
      return code;
    }
    if (step.verify === undefined) continue;
    const state = await awaitPublished(step.verify, PUBLISH_VISIBLE_DELAYS_MS, (ms) =>
      Bun.sleep(ms),
    );
    if (state.kind !== "already-published") {
      process.stderr.write(
        `\nStopped: ${step.id} exited 0, but after a minute the registry still does not hold this tarball (${state.kind}).\n` +
          "Nothing after it ran. If npm printed a dry-run notice, check your npm config. Otherwise the registry may be slow:\n" +
          `rerun bun run release --confirm=${version} later; it skips what is already published.\n`,
      );
      return 1;
    }
  }
  process.stdout.write(
    steps.every((step) => step.skip)
      ? `\nNothing left to publish: ${version} is already everywhere. Tag and push the release if that is not done: bunx changeset tag && git push --follow-tags\n`
      : `\nPublished ${version}. Tag and push the release: bunx changeset tag && git push --follow-tags\n`,
  );
  return 0;
}

const parsed = parseArgs(Bun.argv.slice(2));
switch (parsed.kind) {
  case "usage":
    process.stderr.write(`${parsed.message}\n`);
    process.exit(parsed.message.startsWith("usage:") ? 0 : 64);
    break;
  case "refuse":
    process.stderr.write(`${parsed.message}\n`);
    process.exit(2);
    break;
  case "run": {
    const fixture = process.env[REGISTRY_FIXTURE_ENV];
    if (fixture !== undefined && parsed.options.mode.kind === "confirm") {
      process.stderr.write(
        `Refusing to run: ${REGISTRY_FIXTURE_ENV} replaces the real registries and is for tests.\n`,
      );
      process.exit(2);
    }
    process.exit(
      await release(
        parsed.options,
        fixture === undefined ? liveRegistries : fixtureRegistries(fixture),
      ),
    );
    break;
  }
  default: {
    const exhaustive: never = parsed;
    throw new Error(`unhandled ${String(exhaustive)}`);
  }
}
