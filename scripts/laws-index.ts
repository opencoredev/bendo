import { existsSync, readFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";

// The laws Bendo states are the `law` declarations in LAWS.bend and in the law
// modules it imports. Follow the imports rather than globbing, so this list is
// exactly what `bend PROOF.bend --verdict` checks against LAWS.bend. Lemma
// libraries that a law module happens to import are not followed.

export type Law = { readonly name: string; readonly file: string; readonly line: number };

const root = join(import.meta.dir, "..");
const lawLine = /^law ([A-Za-z_][A-Za-z0-9_]*)\s*[:<(]/;
const importLine = /^import (\.{1,2}\/\S+\.bend) as \w+/;

function lawsIn(file: string): Law[] {
  const lines = readFileSync(join(root, file), "utf8").split("\n");
  return lines.flatMap((text, index) => {
    const match = lawLine.exec(text);
    const name = match?.[1];
    return name === undefined ? [] : [{ name, file, line: index + 1 }];
  });
}

function importsOf(file: string): string[] {
  const lines = readFileSync(join(root, file), "utf8").split("\n");
  return lines.flatMap((text) => {
    const target = importLine.exec(text)?.[1];
    if (target === undefined) return [];
    const path = relative(root, join(root, dirname(file), target));
    if (!existsSync(join(root, path))) throw new Error(`${file} imports missing ${target}`);
    return [path];
  });
}

/** Files whose laws are part of Bendo's stated laws, in import order. */
export function lawFiles(): string[] {
  const files = ["LAWS.bend"];
  const seen = new Set(files);
  // LAWS.bend's direct imports count when they state laws. Below that, only
  // `*-laws.bend` modules are followed.
  const visit = (file: string, top: boolean) => {
    for (const path of importsOf(file)) {
      if (seen.has(path)) continue;
      const lawModule = path.endsWith("-laws.bend");
      if (!lawModule && !top) continue;
      seen.add(path);
      if (lawsIn(path).length > 0) files.push(path);
      // A law module that only imports other law modules still passes them on.
      if (lawModule) visit(path, false);
    }
  };
  visit("LAWS.bend", true);
  return files;
}

export function allLaws(): Law[] {
  return lawFiles().flatMap(lawsIn);
}

if (import.meta.main) {
  const laws = allLaws();
  for (const file of lawFiles())
    console.log(`${laws.filter((law) => law.file === file).length}\t${file}`);
  console.log(`${laws.length} laws, ${new Set(laws.map((law) => law.name)).size} distinct names`);
}
