import { afterAll, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { compile, COMPILE_TEST_TIMEOUT_MS } from "./harness.ts";

const directory = mkdtempSync(join(tmpdir(), "bendo-cache-test-"));
afterAll(() => rmSync(directory, { recursive: true, force: true }));

for (const target of ["native", "mjs"] satisfies ("native" | "mjs")[]) {
  test(
    `${target}: cache hits skip compilation and entry/transitive edits invalidate`,
    async () => {
      const root = join(directory, target);
      mkdirSync(join(root, "nested"), { recursive: true });
      const entry = join(root, "main.bend");
      const leaf = join(root, "leaf.bend");
      writeFileSync(join(root, "effect.c"), "// native effect\n");
      writeFileSync(join(root, "effect.js"), "// JavaScript effect\n");
      writeFileSync(
        entry,
        'import Base\nimport ./nested/dep.bend as D\n\ndef value() -> String:\n  D.value()\n\ndef main() -> IO(Unit):\n  do IO<Unit>:\n    IO.print(value())\n\ndef foreign() -> IO(Unit):\n  import "./effect.c"\n  import "./effect.js"\n',
      );
      writeFileSync(
        join(root, "nested/dep.bend"),
        "import Base\nimport ../leaf.bend as L\n\ndef value() -> String:\n  L.value()\n",
      );
      writeFileSync(leaf, 'import Base\n\ndef value() -> String:\n  "before"\n');
      async function output(path: string): Promise<unknown> {
        if (target === "native") {
          const run = Bun.spawnSync([path, "+RTS", "--threads", "1"], { timeout: 5000 });
          expect(run.exitCode).toBe(0);
          return run.stdout.toString().trim();
        }
        const module: unknown = await import(pathToFileURL(path).href);
        if (typeof module !== "object" || module === null || !("default" in module))
          throw new Error("Missing module");
        const api: unknown = module.default;
        if (
          typeof api !== "object" ||
          api === null ||
          !("value" in api) ||
          typeof api.value !== "function"
        )
          throw new Error("Missing value");
        return api.value();
      }
      const first = compile(entry, target);
      expect(await output(first)).toBe("before");
      const stat = statSync(first);
      expect(compile(entry, target)).toBe(first);
      expect(statSync(first).ino).toBe(stat.ino);
      expect(statSync(first).mtimeMs).toBe(stat.mtimeMs);
      // No memoized graph: edits in the same process must be visible immediately.
      writeFileSync(leaf, readFileSync(leaf, "utf8").replace('"before"', '"after"'));
      const changed = compile(entry, target);
      expect(changed).not.toBe(first);
      expect(await output(changed)).toBe("after");
      writeFileSync(entry, readFileSync(entry, "utf8") + "\n# entry changed\n");
      expect(compile(entry, target)).not.toBe(changed);
      let previous = compile(entry, target);
      for (const effect of ["effect.c", "effect.js"]) {
        writeFileSync(
          join(root, effect),
          readFileSync(join(root, effect), "utf8") + "// changed\n",
        );
        const next = compile(entry, target);
        expect(next).not.toBe(previous);
        previous = next;
      }
      // Same graph in a new temp directory still hits the cache.
      const copy = join(directory, `${target}-copy`);
      mkdirSync(join(copy, "nested"), { recursive: true });
      for (const file of ["main.bend", "leaf.bend", "nested/dep.bend", "effect.c", "effect.js"])
        writeFileSync(join(copy, file), readFileSync(join(root, file)));
      expect(compile(join(copy, "main.bend"), target)).toBe(compile(entry, target));
    },
    COMPILE_TEST_TIMEOUT_MS,
  );
}
