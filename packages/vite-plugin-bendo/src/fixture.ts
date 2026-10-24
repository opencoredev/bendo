import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

/** The package directory: copies live under it so `vite/client` types resolve. */
export const PACKAGE_DIR = resolve(import.meta.dir, "..");
export const FIXTURE = join(PACKAGE_DIR, "fixtures/app");

export type FixtureCopy = {
  root: string;
  path: (relative: string) => string;
  read: (relative: string) => string;
  write: (relative: string, text: string) => void;
  edit: (relative: string, from: string, to: string) => void;
  [Symbol.dispose]: () => void;
};

/** Copies the fixture app into a scratch directory the test may edit. */
export function copyFixture(label: string): FixtureCopy {
  const scratch = join(PACKAGE_DIR, ".cache");
  mkdirSync(scratch, { recursive: true });
  const root = mkdtempSync(join(scratch, `${label}-`));
  cpSync(FIXTURE, root, {
    recursive: true,
    filter: (source) => !source.endsWith(".d.bend.ts"),
  });
  const path = (relative: string) => join(root, relative);
  const read = (relative: string) => readFileSync(path(relative), "utf8");
  const write = (relative: string, text: string) => writeFileSync(path(relative), text);
  return {
    root,
    path,
    read,
    write,
    edit(relative, from, to) {
      const text = read(relative);
      if (!text.includes(from)) throw new Error(`${relative} has no ${JSON.stringify(from)}`);
      write(relative, text.replace(from, to));
    },
    [Symbol.dispose]: () => rmSync(root, { recursive: true, force: true }),
  };
}
