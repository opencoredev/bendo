import {
  copyFileSync,
  existsSync,
  linkSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  realpathSync,
  renameSync,
  rmdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { basename, join, resolve } from "node:path";

export const TEMPLATES = ["api", "fullstack"] as const;
export type Template = (typeof TEMPLATES)[number];

export function isTemplate(value: string): value is Template {
  return TEMPLATES.some((template) => template === value);
}

export const TEMPLATE_SUMMARIES: Readonly<Record<Template, string>> = {
  api: "a Bend API with typed, validated routes",
  fullstack: "the API plus a React app (Vite, TanStack Router and Query, typed client)",
};

/**
 * Where the toolkit comes from. Run from a Bendo checkout, generated apps link
 * the checkout's packages, because nothing is on npm yet. A published
 * create-bendo carries the Bend library in `bend/` (written by `prepack`) and
 * pins the toolkit packages to its own version.
 */
export type Toolkit =
  | { kind: "checkout"; root: string }
  | { kind: "published"; directory: string; version: string };

const PACKAGE_DIR = resolve(import.meta.dir, "..");

function parseVersion(path: string): string {
  const data: unknown = JSON.parse(readFileSync(path, "utf8"));
  if (typeof data !== "object" || data === null || !("version" in data))
    throw new Error(`${path} has no version`);
  const { version } = data;
  if (typeof version !== "string") throw new Error(`${path} has no version`);
  return version;
}

export function locateToolkit(packageDir = PACKAGE_DIR): Toolkit {
  const root = resolve(packageDir, "../..");
  const inCheckout =
    existsSync(join(root, ".bend-version")) &&
    existsSync(join(root, "packages/bendo/package.json")) &&
    existsSync(join(root, "packages/create-bendo")) &&
    realpathSync(join(root, "packages/create-bendo")) === realpathSync(packageDir);
  if (inCheckout) return { kind: "checkout", root };
  if (!existsSync(join(packageDir, "bend/src/main.bend")))
    throw new Error(`create-bendo is missing its Bend library (${join(packageDir, "bend")})`);
  return {
    kind: "published",
    directory: packageDir,
    version: parseVersion(join(packageDir, "package.json")),
  };
}

/** The Bend library and the directory holding its toolchain pins. */
function library(toolkit: Toolkit): { source: string; pins: string } {
  switch (toolkit.kind) {
    case "checkout":
      return { source: join(toolkit.root, "src"), pins: toolkit.root };
    case "published":
      return { source: join(toolkit.directory, "bend/src"), pins: join(toolkit.directory, "bend") };
  }
}

/** Bend's version, and the Lean toolchain its proof checker needs (`bendo doctor` reads both). */
export const PINS = [".bend-version", "lean-toolchain"] as const;

type ToolkitPackage = "bendo" | "vite-plugin-bendo";

function dependency(toolkit: Toolkit, name: ToolkitPackage): string {
  switch (toolkit.kind) {
    case "checkout":
      return `file:${join(toolkit.root, "packages", name)}`;
    case "published":
      return `^${toolkit.version}`;
  }
}

/** A valid npm package name derived from the directory name. */
export function packageName(directory: string): string {
  const name = basename(resolve(directory))
    .toLowerCase()
    .replace(/[^a-z0-9._~-]+/g, "-")
    .replace(/^[._-]+/, "")
    .replace(/-+$/, "");
  return name === "" ? "bendo-app" : name.slice(0, 214);
}

const FRONTEND_DEPENDENCIES = {
  "@tanstack/react-query": "5.104.5",
  "@tanstack/react-router": "1.170.46",
  react: "19.3.1",
  "react-dom": "19.3.1",
};

const FRONTEND_DEV_DEPENDENCIES = {
  "@types/react": "19.3.0",
  "@types/react-dom": "19.3.0",
  "@vitejs/plugin-react": "6.1.2",
  typescript: "5.9.3",
  vite: "8.3.5",
};

export function manifest(template: Template, toolkit: Toolkit, name: string): object {
  const bendo = dependency(toolkit, "bendo");
  // vite-plugin-bendo depends on bendo. A checkout's copy names it with a
  // workspace range, so point that dependency at the same local package.
  const overrides = toolkit.kind === "checkout" ? { overrides: { bendo } } : {};
  switch (template) {
    case "api":
      return {
        name,
        private: true,
        type: "module",
        scripts: {
          dev: "bendo dev",
          build: "bendo build",
          start: "bendo start",
          gen: "bendo gen",
          routes: "bendo routes",
          doctor: "bendo doctor",
        },
        devDependencies: { bendo },
        ...overrides,
      };
    case "fullstack":
      return {
        name,
        private: true,
        type: "module",
        scripts: {
          dev: "bun dev.ts",
          build: "bendo build && bendo gen && bun --bun vite build && tsc",
          start: "bendo start",
          gen: "bendo gen",
          typecheck: "tsc",
          doctor: "bendo doctor",
        },
        dependencies: { ...FRONTEND_DEPENDENCIES, bendo },
        devDependencies: {
          ...FRONTEND_DEV_DEPENDENCIES,
          "vite-plugin-bendo": dependency(toolkit, "vite-plugin-bendo"),
        },
        ...overrides,
      };
  }
}

export class TargetNotEmpty extends Error {
  override name = "TargetNotEmpty";
}

/** Refuses a target that is a file or a nonempty directory. */
export function checkTarget(target: string): void {
  if (!existsSync(target)) return;
  if (!statSync(target).isDirectory())
    throw new TargetNotEmpty(`${target} already exists and is not a directory.`);
  if (readdirSync(target).length > 0)
    throw new TargetNotEmpty(`${target} is not empty. Choose a new or empty directory.`);
}

export type Created = { target: string; template: Template; bendVersion: string };

/**
 * Copies a directory tree. Directories are made with plain mkdir rather than
 * cpSync's copy of the source mode, so they inherit the destination's setgid
 * bit and group the way directories the user makes do.
 */
function copyTree(from: string, to: string): void {
  mkdirSync(to, { recursive: true });
  for (const entry of readdirSync(from, { withFileTypes: true })) {
    const source = join(from, entry.name);
    const destination = join(to, entry.name);
    if (entry.isDirectory()) copyTree(source, destination);
    else copyFileSync(source, destination);
  }
}

/**
 * Moves a staged tree into place without replacing anything: each directory is
 * made with an exclusive mkdir and each file is hard-linked, and both fail if
 * the name already exists. Every path made is recorded in `made`, deepest
 * last, so a failure can remove exactly what this call created.
 */
export function promote(from: string, to: string, made: string[]): void {
  for (const entry of readdirSync(from, { withFileTypes: true })) {
    const source = join(from, entry.name);
    const destination = join(to, entry.name);
    if (entry.isDirectory()) {
      mkdirSync(destination);
      made.push(destination);
      promote(source, destination, made);
    } else {
      linkSync(source, destination);
      made.push(destination);
    }
  }
}

/** Removes what promote made, deepest first. */
export function demote(made: readonly string[]): void {
  for (const path of [...made].reverse()) rmSync(path, { recursive: true, force: true });
}

/**
 * Writes the app into a temporary directory inside the target, then moves
 * each entry up into the target. The target is never replaced, so it keeps
 * its owner, group, mode and setgid bit, and every file inherits them as if
 * the user had made it there. Nothing in the target is overwritten, and on any
 * failure the target is left as it was (a target this call made is removed).
 */
export function create(directory: string, template: Template, toolkit = locateToolkit()): Created {
  const target = resolve(directory);
  checkTarget(target);
  const made = !existsSync(target);
  mkdirSync(target, { recursive: true });
  const staging = mkdtempSync(join(target, ".create-"));
  const promoted: string[] = [];
  try {
    copyTree(join(PACKAGE_DIR, "templates", template), staging);
    renameSync(join(staging, "gitignore"), join(staging, ".gitignore"));
    const { source, pins } = library(toolkit);
    copyTree(source, join(staging, "bendo"));
    for (const pin of PINS) copyFileSync(join(pins, pin), join(staging, pin));
    const bendVersion = readFileSync(join(staging, ".bend-version"), "utf8");
    writeFileSync(
      join(staging, "package.json"),
      `${JSON.stringify(manifest(template, toolkit, packageName(target)), null, 2)}\n`,
    );
    // Recheck: something else may have written into the target meanwhile.
    const others = readdirSync(target).filter((name) => name !== basename(staging));
    if (others.length > 0)
      throw new TargetNotEmpty(`${target} is not empty. Choose a new or empty directory.`);
    try {
      promote(staging, target, promoted);
    } catch (error) {
      if (error instanceof Error && "code" in error && error.code === "EEXIST")
        throw new TargetNotEmpty(`${target} is not empty. Choose a new or empty directory.`);
      throw error;
    }
    rmSync(staging, { recursive: true, force: true });
    return { target, template, bendVersion: bendVersion.trim() };
  } catch (error) {
    demote(promoted);
    rmSync(staging, { recursive: true, force: true });
    if (made && existsSync(target) && readdirSync(target).length === 0) rmdirSync(target);
    throw error;
  }
}
