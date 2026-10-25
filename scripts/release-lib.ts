// The pure half of `bun run release` (scripts/release.ts): arguments, versions,
// the BendHub package hash and entry file, tarball reading, the publish gate,
// the exact commands and the report text. Nothing here touches the disk, git,
// a child process or the network.
import { createHash } from "node:crypto";

/** npm packages in publish order: each one's dependencies publish before it. */
export const NPM_PACKAGES = ["bendo", "vite-plugin-bendo", "create-bendo"] as const;
export type NpmPackageName = (typeof NPM_PACKAGES)[number];

export const NPM_REGISTRY = "https://registry.npmjs.org/";
export const NPM_TAG = "latest";
export const NPM_ACCESS = "public";
export const HUB_URL = "https://hub.bend-lang.com";
/** Where `bend login` and a named publish's login checks go. */
export const HUB_ORIGIN = "https://bend-lang.com";
export const HUB_PACKAGE = "bendo";
/** The file `bend --publish` starts from. The release script writes it into the staged `src/`. */
export const HUB_ENTRY = "bendhub.bend";
/** Modules a consumer imports by name in the BendHub import check. */
export const HUB_IMPORT_CHECK = ["main.bend", "validated.bend"] as const;

export type Target = "npm" | "bendhub";
export const TARGETS: readonly Target[] = ["npm", "bendhub"];

// ---------------------------------------------------------------- arguments

export type Mode = { kind: "dry-run" } | { kind: "confirm"; version: string };

export type Options = { mode: Mode; json: boolean; targets: readonly Target[] };

export type Parsed =
  | { kind: "run"; options: Options }
  | { kind: "refuse"; message: string }
  | { kind: "usage"; message: string };

export const USAGE = `usage: bun run release --dry-run [--json] [--only=npm|bendhub]
       bun run release --confirm=<version> [--only=npm|bendhub]

--dry-run         pack every package, check the BendHub upload against a local
                  stub hub, and print what would publish. Sends nothing.
--confirm=<v>     publish version <v>. Leo's step: it also needs a clean main
                  that matches origin/main, npm login and bend login.
--only=<target>   npm or bendhub alone. Both by default, npm first.
--json            print the report as JSON (dry run only).`;

export const REFUSAL = `Refusing to run: publishing to npm and BendHub is Leo's step.
Run \`bun run release --dry-run\` to see exactly what would publish.
A real publish is \`bun run release --confirm=<version>\` on a clean, pushed main.`;

/** Parses the release script's arguments. No `--dry-run` and no `--confirm` refuses before any work. */
export function parseArgs(argv: readonly string[]): Parsed {
  let dryRun = false;
  let confirm: string | null = null;
  let json = false;
  let only: Target | null = null;
  for (let index = 0; index < argv.length; index++) {
    const arg = argv[index] ?? "";
    if (arg === "--dry-run") dryRun = true;
    else if (arg === "--json") json = true;
    else if (arg === "--help" || arg === "-h") return { kind: "usage", message: USAGE };
    else if (arg === "--confirm" || arg.startsWith("--confirm=")) {
      const value = arg === "--confirm" ? argv[++index] : arg.slice("--confirm=".length);
      if (value === undefined || value === "" || value.startsWith("--"))
        return { kind: "usage", message: `--confirm needs the version to publish\n\n${USAGE}` };
      confirm = value;
    } else if (arg === "--only" || arg.startsWith("--only=")) {
      const value = arg === "--only" ? argv[++index] : arg.slice("--only=".length);
      if (value !== "npm" && value !== "bendhub")
        return { kind: "usage", message: `--only takes npm or bendhub\n\n${USAGE}` };
      only = value;
    } else return { kind: "usage", message: `unknown argument ${arg}\n\n${USAGE}` };
  }
  if (dryRun && confirm !== null)
    return { kind: "usage", message: `pass --dry-run or --confirm, not both\n\n${USAGE}` };
  if (json && !dryRun) return { kind: "usage", message: `--json is for --dry-run\n\n${USAGE}` };
  const targets = only === null ? TARGETS : [only];
  if (dryRun) return { kind: "run", options: { mode: { kind: "dry-run" }, json, targets } };
  if (confirm !== null)
    return { kind: "run", options: { mode: { kind: "confirm", version: confirm }, json, targets } };
  return { kind: "refuse", message: REFUSAL };
}

// ---------------------------------------------------------------- versions

export type Version = { major: number; minor: number; patch: number };

/** A release version: three numbers, no prerelease or build part, because BendHub has neither. */
export function parseVersion(text: string): Version | null {
  const match = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.exec(text);
  if (match === null) return null;
  return { major: Number(match[1]), minor: Number(match[2]), patch: Number(match[3]) };
}

export function showVersion(version: Version): string {
  return `${version.major}.${version.minor}.${version.patch}`;
}

/**
 * BendHub names need four numbers. The fourth is always 0: the Bend library
 * ships with the npm packages (create-bendo bundles it), so a library fix is a
 * new patch release of everything. See docs/versioning.md.
 */
export function hubVersion(version: Version): string {
  return `${showVersion(version)}.0`;
}

// ---------------------------------------------------------------- where things go

/**
 * Where `bend` sends a package and its login. Bend 2.0.38 has no flag for
 * either: it reads `BEND_HUB` and `BEND_ORIGIN` from the environment, so the
 * release script always sets both itself and never lets them through.
 */
export type HubDestination = { hub: string; origin: string };

export const REAL_HUB: HubDestination = { hub: HUB_URL, origin: HUB_ORIGIN };

/** The variables that carry a destination to `bend`. */
export function hubDestinationEnv(destination: HubDestination): {
  BEND_HUB: string;
  BEND_ORIGIN: string;
} {
  return { BEND_HUB: destination.hub, BEND_ORIGIN: destination.origin };
}

/**
 * Inherited variables that would send a real publish, or its credentials,
 * somewhere other than what the report names, or let anyone in the middle read
 * them. `BEND_LIB` only moves bend's download cache, so it is not one.
 */
export type EnvOverride = { name: string; value: string };

/**
 * npm reads any `npm_config_*` variable (in any case) as a setting, so an
 * inherited `npm_config_dry_run=true` or `npm_config_registry` would change
 * what a publish does. Release commands never inherit them.
 */
export function isNpmConfig(name: string): boolean {
  return /^npm_config_/i.test(name);
}

/** npm settings that change what or where a publish uploads. */
function publishSetting(name: string): boolean {
  const key = name.toLowerCase().slice("npm_config_".length).replace(/-/g, "_");
  return (
    ["dry_run", "registry", "tag", "access", "userconfig", "globalconfig", "provenance"].includes(
      key,
    ) || key.endsWith(":registry")
  );
}

/**
 * The real npm publish: the shared command plus `--dry-run=false`, so neither
 * an `.npmrc` nor the environment can turn it into a dry run.
 */
export function npmRealPublishCommand(tarball: string): string[] {
  return [...npmPublishCommand(tarball), "--dry-run=false"];
}

export function envOverrides(env: Readonly<Record<string, string | undefined>>): EnvOverride[] {
  const pinned: Record<string, string> = hubDestinationEnv(REAL_HUB);
  const found: EnvOverride[] = [];
  for (const name of Object.keys(pinned)) {
    const value = env[name];
    if (value !== undefined && value !== pinned[name]) found.push({ name, value });
  }
  const tls = env.NODE_TLS_REJECT_UNAUTHORIZED;
  if (tls === "0") found.push({ name: "NODE_TLS_REJECT_UNAUTHORIZED", value: tls });
  // Release commands never inherit npm settings, but one that would change a
  // publish is reported anyway, so whoever set it finds out. `bun run` sets
  // others (npm_config_user_agent, npm_config_local_prefix) on every run.
  for (const [name, value] of Object.entries(env))
    if (value !== undefined && isNpmConfig(name) && publishSetting(name))
      found.push({ name, value });
  return found;
}

/**
 * The environment for a `bend` run: the inherited one without any destination
 * or TLS override, then `destination` and `lib` set explicitly.
 */
export function bendEnv(input: {
  inherited: Readonly<Record<string, string | undefined>>;
  destination: HubDestination;
  lib: string;
}): Record<string, string> & ReturnType<typeof hubDestinationEnv> {
  const env: Record<string, string> = {};
  for (const [name, value] of Object.entries(input.inherited))
    if (value !== undefined && !isNpmConfig(name)) env[name] = value;
  delete env.NODE_TLS_REJECT_UNAUTHORIZED;
  return {
    ...env,
    ...hubDestinationEnv(input.destination),
    BEND_LIB: input.lib,
    BEND_NO_TELEMETRY: "1",
  };
}

// ---------------------------------------------------------------- what is already published

/**
 * What a registry holds at the staged name and version: for npm the tarball's
 * `dist.integrity`, for BendHub the hash the name links to.
 */
export type Lookup =
  | { kind: "absent" }
  | { kind: "present"; id: string }
  | { kind: "unknown"; reason: string };

/** What a confirmed run does with one package. A rerun after a partial release skips what landed. */
export type PublishState =
  | { kind: "publish" }
  | { kind: "already-published" }
  | { kind: "conflict"; published: string }
  | { kind: "unknown"; reason: string };

export function publishState(lookup: Lookup, staged: string): PublishState {
  switch (lookup.kind) {
    case "absent":
      return { kind: "publish" };
    case "present":
      return lookup.id === staged
        ? { kind: "already-published" }
        : { kind: "conflict", published: lookup.id };
    case "unknown":
      return { kind: "unknown", reason: lookup.reason };
    default: {
      const exhaustive: never = lookup;
      return exhaustive;
    }
  }
}

/** Waits between registry checks after an upload: about a minute in total. */
export const PUBLISH_VISIBLE_DELAYS_MS = [2_000, 4_000, 8_000, 16_000, 30_000];

/**
 * After an upload exits 0, the registry can still answer E404 or fail for a
 * few seconds. Rechecks an absent or unknown result after each delay. A
 * conflict or the published tarball ends the wait at once.
 */
export async function awaitPublished(
  check: () => PublishState,
  delays: readonly number[],
  sleep: (ms: number) => Promise<void>,
): Promise<PublishState> {
  const state = check();
  const [delay, ...rest] = delays;
  if (delay === undefined || state.kind === "already-published" || state.kind === "conflict") {
    return state;
  }
  await sleep(delay);
  return awaitPublished(check, rest, sleep);
}

/** `npm view <name>@<version> dist.integrity --json`: a JSON string, nothing, or an E404 means absent. */
export function parseNpmView(result: { code: number; stdout: string; stderr: string }): Lookup {
  const out = result.stdout.trim();
  if (result.code === 0) {
    if (out === "") return { kind: "absent" };
    const data: unknown = JSON.parse(out);
    return typeof data === "string" && data.startsWith("sha512-")
      ? { kind: "present", id: data }
      : { kind: "unknown", reason: `npm view printed ${out.slice(0, 80)}` };
  }
  if (/\bE404\b/.test(`${result.stdout}${result.stderr}`)) return { kind: "absent" };
  const last = result.stderr.trim().split("\n").at(-1) ?? "";
  return { kind: "unknown", reason: `npm view exited ${result.code}: ${last}` };
}

/** `GET <hub>/name/<name>@<version>`, read the way `bend` reads it when importing by name. */
export function parseHubName(response: { status: number; body: string }): Lookup {
  const body = response.body.trim();
  if (response.status === 200 && /^0x[0-9a-f]{32}$/.test(body))
    return { kind: "present", id: body };
  if (response.status === 404) return { kind: "absent" };
  if (response.status === 410)
    return { kind: "unknown", reason: "the hub says this name was taken down" };
  return { kind: "unknown", reason: `the hub answered ${response.status}: ${body.slice(0, 80)}` };
}

/**
 * Recorded registry answers for tests, so they never ask npm or BendHub:
 * `{"npm": {"<name>@<version>": "<integrity>"}, "hub": {"<name>@<a.b.c.d>": "<hash>"}}`.
 * A key that is missing is absent. The release script reads it from the file
 * named by {@link REGISTRY_FIXTURE_ENV}, and a confirmed run refuses to start with it set.
 */
export type RegistryFixture = { npm: Record<string, string>; hub: Record<string, string> };

export const REGISTRY_FIXTURE_ENV = "BENDO_RELEASE_REGISTRY_FIXTURE";

function fixtureMap(value: unknown, field: string): Record<string, string> {
  if (value === undefined) return {};
  if (typeof value !== "object" || value === null || Array.isArray(value))
    throw new Error(`${REGISTRY_FIXTURE_ENV}: ${field} is not an object`);
  const out: Record<string, string> = {};
  for (const [key, entry] of Object.entries(value)) {
    if (typeof entry !== "string")
      throw new Error(`${REGISTRY_FIXTURE_ENV}: ${field}.${key} is not a string`);
    out[key] = entry;
  }
  return out;
}

export function parseRegistryFixture(text: string): RegistryFixture {
  const data: unknown = JSON.parse(text);
  if (typeof data !== "object" || data === null || Array.isArray(data))
    throw new Error(`${REGISTRY_FIXTURE_ENV} is not a JSON object`);
  return {
    npm: fixtureMap("npm" in data ? data.npm : undefined, "npm"),
    hub: fixtureMap("hub" in data ? data.hub : undefined, "hub"),
  };
}

export function fixtureLookup(entries: Readonly<Record<string, string>>, key: string): Lookup {
  const id = entries[key];
  return id === undefined ? { kind: "absent" } : { kind: "present", id };
}

// ---------------------------------------------------------------- BendHub

function sha256(text: string): string {
  return createHash("sha256").update(text).digest("hex");
}

/**
 * The manifest BendHub serves for a package: one `<sha256> <path>` line per
 * file, sorted by path. Bend 2.0.38 hashes exactly this text for the package
 * hash, and checks every downloaded file against its line.
 */
export function hubManifest(files: Readonly<Record<string, string>>): string {
  return Object.keys(files)
    .sort()
    .map((path) => `${sha256(files[path] ?? "")} ${path}\n`)
    .join("");
}

/** The `0x` and 32 hex digits that `bend --publish` prints and imports by hash use. */
export function hubHash(files: Readonly<Record<string, string>>): string {
  return `0x${sha256(hubManifest(files)).slice(0, 32)}`;
}

export type HubFile = { path: string; bytes: number; sha256: string };

export function hubFiles(files: Readonly<Record<string, string>>): HubFile[] {
  return Object.keys(files)
    .sort()
    .map((path) => {
      const text = files[path] ?? "";
      return { path, bytes: Buffer.byteLength(text), sha256: sha256(text) };
    });
}

/** Proof modules stay out of the entry. A public module that imports one still brings it along. */
export function isPublicModule(path: string): boolean {
  return (
    path.endsWith(".bend") &&
    path !== HUB_ENTRY &&
    !path.endsWith("-proofs.bend") &&
    !path.endsWith("/proofs.bend")
  );
}

/** A local import alias for a module path. Bend refuses dots in a module name, so map them away. */
function moduleAlias(path: string): string {
  return `M_${path.replace(/\.bend$/, "").replace(/[^A-Za-z0-9]/g, "_")}`;
}

/**
 * The BendHub entry. `bend --publish` takes a file and what it imports, and
 * `main.bend` leaves out opt-in modules (`validated.bend`, `ws/pubsub.bend`,
 * `api-docs.bend`, ...) to keep app compiles fast. This entry imports every
 * public module so the package carries all of them. `modules` are paths
 * relative to `src/`.
 */
export function hubEntrySource(modules: readonly string[]): string {
  const paths = modules.filter(isPublicModule).sort();
  const aliases = new Map<string, string>();
  for (const path of paths) {
    const alias = moduleAlias(path);
    const other = aliases.get(alias);
    if (other !== undefined) throw new Error(`${path} and ${other} share the alias ${alias}`);
    aliases.set(alias, path);
  }
  return [
    "# Generated by scripts/release.ts for BendHub. It only makes the package",
    "# carry every public Bendo module. Apps import main.bend or another module.",
    "import Base",
    ...paths.map((path) => `import ./${path} as ${moduleAlias(path)}`),
    "",
  ].join("\n");
}

/** The consumer the import check compiles: it imports the published package by name. */
export function hubConsumerSource(named: string): string {
  return [
    "import Base",
    ...HUB_IMPORT_CHECK.map((module, index) => `import ${named}/${module} as P${String(index)}`),
    "",
    "def main() -> U32:",
    "  7",
    "",
  ].join("\n");
}

// ---------------------------------------------------------------- tarballs

export type TarEntry = { path: string; bytes: number; content: Uint8Array };

function tarString(block: Uint8Array, start: number, length: number): string {
  const field = block.subarray(start, start + length);
  const end = field.indexOf(0);
  return new TextDecoder().decode(end === -1 ? field : field.subarray(0, end));
}

/**
 * Reads the regular files of an uncompressed ustar archive, as `npm pack` and
 * `bun pm pack` write them. Paths keep their `package/` prefix.
 */
export function readTar(archive: Uint8Array): TarEntry[] {
  const entries: TarEntry[] = [];
  let offset = 0;
  while (offset + 512 <= archive.length) {
    const header = archive.subarray(offset, offset + 512);
    if (header.every((byte) => byte === 0)) break;
    const name = tarString(header, 0, 100);
    const prefix = tarString(header, 345, 155);
    const size = Number.parseInt(tarString(header, 124, 12).trim() || "0", 8);
    const type = tarString(header, 156, 1);
    const start = offset + 512;
    if (type === "" || type === "0")
      entries.push({
        path: prefix === "" ? name : `${prefix}/${name}`,
        bytes: size,
        content: archive.slice(start, start + size),
      });
    offset = start + Math.ceil(size / 512) * 512;
  }
  return entries;
}

// ---------------------------------------------------------------- report

export type GitState = {
  branch: string;
  head: string;
  /** Changed or untracked files, from `git status --porcelain`. */
  changes: number;
  /** `origin/main`, when the clone has that ref. */
  originMain: string | null;
};

/** What `npm publish --dry-run` said about the tarball. */
export type NpmCheck =
  | { kind: "agrees"; id: string; files: number }
  /** Not run: the registry already holds this exact tarball, which npm would refuse to republish. */
  | { kind: "skipped" }
  | { kind: "disagrees"; reason: string }
  | { kind: "failed"; reason: string };

export type PackedFile = { path: string; bytes: number };

export type NpmPackage = {
  name: NpmPackageName;
  version: string;
  tarball: string;
  packedBytes: number;
  unpackedBytes: number;
  shasum: string;
  integrity: string;
  access: string;
  files: PackedFile[];
  bin: Record<string, string>;
  exports: Record<string, string>;
  dependencies: Record<string, string>;
  peerDependencies: Record<string, string>;
  optionalPeers: string[];
  /** The registry's `dist.integrity` for this name and version against {@link NpmPackage.integrity}. */
  registry: PublishState;
  npmCheck: NpmCheck;
  command: string[];
};

export type HubCheck = { kind: "passed"; imports: string[] } | { kind: "failed"; reason: string };

export type HubPackage = {
  name: string;
  version: string;
  /** What a confirmed run passes to `bend` as `BEND_HUB` and `BEND_ORIGIN`. */
  destination: HubDestination;
  entry: string;
  /** The staged directory the real `bend --publish` runs in. */
  directory: string;
  hash: string;
  license: string;
  bytes: number;
  files: HubFile[];
  /** A consumer that imports the package by name from the stub hub, which serves the captured upload. */
  importCheck: HubCheck;
  /** Requests `bend` made to the local stub hub, in order. */
  requests: string[];
  /** The hash the destination hub links this name and version to, against {@link HubPackage.hash}. */
  registry: PublishState;
  command: string[];
};

export type Gate =
  | { kind: "dry-run"; blockers: string[] }
  | { kind: "refuse"; reason: string }
  | { kind: "stop"; blockers: string[] }
  | { kind: "publish" };

export type Report = {
  mode: Mode;
  targets: readonly Target[];
  git: GitState;
  pendingChangesets: string[];
  version: string;
  hubVersion: string;
  npm: NpmPackage[];
  hub: HubPackage | null;
  gate: Gate;
};

export type GateInput = {
  mode: Mode;
  targets: readonly Target[];
  git: GitState;
  pendingChangesets: readonly string[];
  /** Each npm package's version after pending changesets are applied. */
  versions: Readonly<Record<NpmPackageName, string>>;
  npm: readonly NpmPackage[];
  hub: HubPackage | null;
  /** Confirmed runs only: `npm whoami` and `~/.bend/bendai.json`. */
  logins: { npm: boolean; bend: boolean } | null;
  /** From {@link envOverrides}: inherited variables that would redirect a publish. */
  overrides: readonly EnvOverride[];
};

function stateBlocker(state: PublishState, id: string, where: string, what: string): string | null {
  switch (state.kind) {
    case "publish":
    case "already-published":
      return null;
    case "conflict":
      return `${id} is already on ${where} with a different ${what} (${state.published}): the staged package is not what was published, so stop and find out why`;
    case "unknown":
      return `could not ask ${where} whether ${id} exists: ${state.reason}`;
    default: {
      const exhaustive: never = state;
      return exhaustive;
    }
  }
}

/** Everything that keeps a confirmed run from publishing now. */
export function blockers(input: GateInput): string[] {
  const reasons: string[] = [];
  const { git } = input;
  if (git.branch !== "main") reasons.push(`not on main (on ${git.branch})`);
  if (git.changes > 0) reasons.push(`the working tree has ${git.changes} uncommitted change(s)`);
  if (git.originMain === null) reasons.push("there is no origin/main ref to compare with");
  else if (git.originMain !== git.head) reasons.push("HEAD is not origin/main: push or pull first");
  if (input.pendingChangesets.length > 0)
    reasons.push(
      `changesets are not applied (${input.pendingChangesets.join(", ")}): run \`bun run version-packages\` and commit`,
    );
  const versions = new Set(Object.values(input.versions));
  if (versions.size > 1)
    reasons.push(`the packages disagree on the version (${[...versions].join(", ")})`);
  const version = parseVersion(input.versions.bendo);
  if (version === null) reasons.push(`${input.versions.bendo} is not a plain x.y.z version`);
  else if (version.major === 0 && version.minor === 0 && version.patch === 0)
    reasons.push("the version is 0.0.0");
  for (const override of input.overrides)
    reasons.push(
      `${override.name} is set to ${override.value}: unset it, the release pins its own destination`,
    );
  if (input.targets.includes("npm"))
    for (const pkg of input.npm) {
      const reason = stateBlocker(pkg.registry, `${pkg.name}@${pkg.version}`, "npm", "integrity");
      if (reason !== null) reasons.push(reason);
      if (pkg.npmCheck.kind === "disagrees" || pkg.npmCheck.kind === "failed")
        reasons.push(`npm publish --dry-run for ${pkg.name}: ${pkg.npmCheck.reason}`);
    }
  if (input.targets.includes("bendhub")) {
    if (input.hub === null) reasons.push("the BendHub package was not staged");
    else {
      if (input.hub.importCheck.kind === "failed")
        reasons.push(`the BendHub import check failed: ${input.hub.importCheck.reason}`);
      const named = `${input.hub.name}@${input.hub.version}`;
      const reason = stateBlocker(input.hub.registry, named, input.hub.destination.hub, "hash");
      if (reason !== null) reasons.push(reason);
    }
  }
  if (input.logins !== null) {
    if (input.targets.includes("npm") && !input.logins.npm)
      reasons.push("npm is not logged in: run `npm login`");
    if (input.targets.includes("bendhub") && !input.logins.bend)
      reasons.push("bend is not logged in: run `bend login`");
  }
  return reasons;
}

/**
 * Whether `bun run release` may publish. A dry run always runs and lists what
 * would block a real one. A confirmed run needs the confirmed version to be the
 * version being released, then no blockers at all.
 */
export function decide(input: GateInput): Gate {
  const reasons = blockers(input);
  switch (input.mode.kind) {
    case "dry-run":
      return { kind: "dry-run", blockers: reasons };
    case "confirm": {
      const releasing = input.versions.bendo;
      if (input.mode.version !== releasing)
        return {
          kind: "refuse",
          reason: `--confirm=${input.mode.version}, but this release is ${releasing}. Pass --confirm=${releasing} to publish it.`,
        };
      return reasons.length > 0 ? { kind: "stop", blockers: reasons } : { kind: "publish" };
    }
    default: {
      const exhaustive: never = input.mode;
      return exhaustive;
    }
  }
}

// ---------------------------------------------------------------- commands

export function npmPublishCommand(tarball: string): string[] {
  return [
    "npm",
    "publish",
    tarball,
    "--registry",
    NPM_REGISTRY,
    "--access",
    NPM_ACCESS,
    "--tag",
    NPM_TAG,
  ];
}

export function hubPublishCommand(version: Version): string[] {
  return ["bend", HUB_ENTRY, "--publish", `${HUB_PACKAGE}@${hubVersion(version)}`];
}

export function shellWord(word: string): string {
  return /^[A-Za-z0-9_@%+=:,./-]+$/.test(word) ? word : `'${word.replaceAll("'", `'\\''`)}'`;
}

export function shellCommand(command: readonly string[]): string {
  return command.map(shellWord).join(" ");
}

/** The publish command with the destination it is given, as a shell would run it. */
export function hubShellCommand(hub: Pick<HubPackage, "destination" | "command">): string {
  const env = Object.entries(hubDestinationEnv(hub.destination)).map(
    ([name, value]) => `${name}=${shellWord(value)}`,
  );
  return [...env, shellCommand(hub.command)].join(" ");
}

// ---------------------------------------------------------------- text

function kb(bytes: number): string {
  return `${(bytes / 1000).toFixed(1)} kB`;
}

function table(entries: Record<string, string>): string {
  const list = Object.entries(entries);
  return list.length === 0 ? "none" : list.map(([key, value]) => `${key} ${value}`).join(", ");
}

function registryLine(state: PublishState, where: string, what: string): string {
  switch (state.kind) {
    case "publish":
      return `not on ${where} yet`;
    case "already-published":
      return `already on ${where} with the same ${what}: a confirmed run skips it`;
    case "conflict":
      return `ON ${where.toUpperCase()} WITH A DIFFERENT ${what.toUpperCase()}: ${state.published}`;
    case "unknown":
      return `unknown: ${state.reason}`;
    default: {
      const exhaustive: never = state;
      return exhaustive;
    }
  }
}

function npmCheckLine(check: NpmCheck): string {
  switch (check.kind) {
    case "agrees":
      return `agrees (${check.id}, ${check.files} files)`;
    case "skipped":
      return "not run: this exact tarball is already published";
    case "disagrees":
      return `DISAGREES: ${check.reason}`;
    case "failed":
      return `FAILED: ${check.reason}`;
    default: {
      const exhaustive: never = check;
      return exhaustive;
    }
  }
}

function hubCheckLine(check: HubCheck): string {
  switch (check.kind) {
    case "passed":
      return `passed (${check.imports.join(", ")})`;
    case "failed":
      return `FAILED: ${check.reason}`;
    default: {
      const exhaustive: never = check;
      return exhaustive;
    }
  }
}

function npmLines(pkg: NpmPackage): string[] {
  const peers = Object.fromEntries(
    Object.entries(pkg.peerDependencies).map(([name, range]) => [
      name,
      pkg.optionalPeers.includes(name) ? `${range} (optional)` : range,
    ]),
  );
  return [
    "",
    `  ${pkg.name}@${pkg.version}`,
    `    tarball: ${pkg.tarball} (${kb(pkg.packedBytes)} packed, ${kb(pkg.unpackedBytes)} unpacked, ${pkg.files.length} files)`,
    `    shasum: ${pkg.shasum}`,
    `    integrity: ${pkg.integrity}`,
    `    access: ${pkg.access}`,
    `    registry: ${registryLine(pkg.registry, "npm", "integrity")}`,
    `    npm publish --dry-run: ${npmCheckLine(pkg.npmCheck)}`,
    `    bin: ${table(pkg.bin)}`,
    `    exports: ${table(pkg.exports)}`,
    `    dependencies: ${table(pkg.dependencies)}`,
    `    peerDependencies: ${table(peers)}`,
    "    files (bytes, path):",
    ...pkg.files.map((file) => `      ${String(file.bytes).padStart(8)}  ${file.path}`),
    `    command: ${shellCommand(pkg.command)}`,
  ];
}

function hubLines(hub: HubPackage): string[] {
  return [
    "",
    `BendHub: ${hub.destination.hub}, public and permanent (https://bend-lang.com/bendai/terms#s18)`,
    `  ${hub.name}@${hub.version}`,
    `    hash: ${hub.hash}`,
    `    registry: ${registryLine(hub.registry, hub.destination.hub, "hash")}`,
    `    license: ${hub.license}`,
    `    entry: ${hub.entry} (generated; imports every public module)`,
    `    ${hub.files.length} files, ${hub.bytes} bytes`,
    `    import check: ${hubCheckLine(hub.importCheck)}`,
    `    requests to the local stub hub: ${hub.requests.join(", ")}`,
    "    files (sha256, bytes, path):",
    ...hub.files.map(
      (file) => `      ${file.sha256}  ${String(file.bytes).padStart(7)}  ${file.path}`,
    ),
    `    command: (cd ${shellWord(hub.directory)} && ${hubShellCommand(hub)})`,
    "    It sends these files with a proof-of-work nonce in one POST to the hub, then",
    `    links ${hub.name}@${hub.version} to ${hub.hash}. Users import ${hub.name}@${hub.version}/main.bend.`,
  ];
}

function gateLines(gate: Gate): string[] {
  switch (gate.kind) {
    case "dry-run":
      return gate.blockers.length === 0
        ? ["  nothing: a confirmed run would publish now"]
        : gate.blockers.map((reason) => `  - ${reason}`);
    case "refuse":
      return [`  ${gate.reason}`];
    case "stop":
      return gate.blockers.map((reason) => `  - ${reason}`);
    case "publish":
      return ["  clear: publishing now"];
    default: {
      const exhaustive: never = gate;
      return exhaustive;
    }
  }
}

/** The text a run prints. */
export function formatReport(report: Report): string {
  const { mode } = report;
  const dry = mode.kind === "dry-run";
  const out: string[] = [
    mode.kind === "dry-run"
      ? "Bendo release: DRY RUN. Nothing was published, and nothing was sent to npm or BendHub."
      : `Bendo release: --confirm=${mode.version}`,
    "",
    "Repository",
    `  branch: ${report.git.branch}`,
    `  HEAD: ${report.git.head}`,
    `  origin/main: ${report.git.originMain ?? "(no ref)"}`,
    `  working tree: ${report.git.changes === 0 ? "clean" : `${report.git.changes} uncommitted change(s)`}`,
    report.pendingChangesets.length === 0
      ? "  changesets: none pending"
      : `  changesets: ${report.pendingChangesets.join(", ")} pending, applied to the staged copy the way \`bun run version-packages\` will`,
    `  version: ${report.version} on npm, ${report.hubVersion} on BendHub`,
    `  targets: ${report.targets.join(", ")}`,
  ];
  if (report.npm.length > 0) {
    out.push("", `npm: registry ${NPM_REGISTRY}, tag ${NPM_TAG}, access ${NPM_ACCESS}`);
    for (const pkg of report.npm) out.push(...npmLines(pkg));
  }
  if (report.hub !== null) out.push(...hubLines(report.hub));
  out.push("");
  if (dry) {
    out.push(
      "A real publish is Leo's step:",
      `  bun run release --confirm=${report.version}`,
      "It runs the commands above in order, npm first and BendHub last, and only",
      "on a clean main that matches origin/main, with npm and bend logged in. It",
      "skips a package already published with the same integrity or hash, so after",
      "a partial release the same command finishes the rest.",
      "Right now it would stop on:",
    );
  } else out.push("Publish gate:");
  out.push(...gateLines(report.gate));
  return `${out.join("\n")}\n`;
}
