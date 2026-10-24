import { existsSync, readFileSync, realpathSync } from "node:fs";
import { dirname, extname, resolve } from "node:path";

const IMPORT = /(^\s*import\s+)(?:"([^"\n]+)"|(\.{1,2}\/[^\s]+))/gm;

export function mapImports(content: string, map: (file: string) => string): string {
  return content.replace(
    IMPORT,
    (_match, prefix: string, quoted: string | undefined, relative: string | undefined) => {
      const imported = quoted ?? relative;
      if (imported === undefined) return _match;
      const mapped = map(imported);
      return `${prefix}${quoted === undefined ? mapped : `"${mapped}"`}`;
    },
  );
}

/** Canonical paths prevent symlink cycles and keep snapshots independent of aliases. */
export function sourceGraph(
  entry: string,
  onFile: (file: string) => void = () => {},
): Map<string, Buffer> {
  const graph = new Map<string, Buffer>();
  const visit = (path: string): void => {
    const file = existsSync(path) ? realpathSync(path) : resolve(path);
    onFile(file);
    if (graph.has(file)) return;
    const content = readFileSync(file);
    graph.set(file, content);
    if (extname(file) !== ".bend") return;
    mapImports(content.toString(), (imported) => {
      const dependency = resolve(dirname(file), imported);
      visit(dependency);
      if (/\.(c|js)$/.test(dependency)) {
        const twin = dependency.replace(/\.(c|js)$/, dependency.endsWith(".c") ? ".js" : ".c");
        if (existsSync(twin)) visit(twin);
      }
      return imported;
    });
  };
  visit(resolve(entry));
  return graph;
}
