import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { createRequire } from "node:module";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const require = createRequire(import.meta.url);

// The package directory of a bundled module id, or undefined for app code.
// CommonJS helper ids start with NUL and may carry a query.
function packageDir(raw) {
  const id = raw.replace(/^\0/, "").split("?")[0];
  const at = id.lastIndexOf("/node_modules/");
  if (at < 0) return undefined;
  const rest = id.slice(at + "/node_modules/".length).split("/");
  const name = rest[0].startsWith("@") ? `${rest[0]}/${rest[1]}` : rest[0];
  return id.slice(0, at) + "/node_modules/" + name;
}

function notice(dir) {
  const pkg = JSON.parse(readFileSync(join(dir, "package.json"), "utf8"));
  const file = ["LICENSE", "LICENSE.md", "LICENSE.txt"].map((f) => join(dir, f)).find(existsSync);
  if (file === undefined) throw new Error(`no license file in ${dir}`);
  // Vite's file also lists the licenses of its own Node dependencies, none
  // of which reach a browser bundle; keep only its core license.
  const text = readFileSync(file, "utf8").split("\n# Licenses of bundled dependencies")[0].trim();
  return { name: pkg.name, line: `${pkg.name}@${pkg.version} (${pkg.license})`, text };
}

// Every package with code in the bundle keeps its license: a banner in each
// chunk names them, and THIRD_PARTY_LICENSES.txt holds the full texts. Vite's
// module preload polyfill is Vite's own code, so Vite is listed too.
function thirdPartyLicenses() {
  return {
    name: "third-party-licenses",
    // generateBundle runs after minification, which would drop the banner.
    generateBundle(options, bundle) {
      const dirs = new Set();
      for (const chunk of Object.values(bundle)) {
        if (chunk.type !== "chunk") continue;
        for (const id of Object.keys(chunk.modules)) {
          const dir = packageDir(id);
          if (dir !== undefined) dirs.add(dir);
          if (id.includes("vite/modulepreload-polyfill"))
            dirs.add(dirname(require.resolve("vite/package.json")));
        }
      }
      const notices = [...dirs].map(notice).sort((a, b) => a.name.localeCompare(b.name));
      if (notices.length === 0) return;
      this.emitFile({
        type: "asset",
        fileName: "THIRD_PARTY_LICENSES.txt",
        source: notices.map((n) => `${n.line}\n\n${n.text}\n`).join("\n" + "-".repeat(72) + "\n\n"),
      });
      const banner = `/*! Bundles ${notices.map((n) => n.line).join(", ")}. License texts: /THIRD_PARTY_LICENSES.txt */\n`;
      for (const chunk of Object.values(bundle)) {
        if (chunk.type === "chunk") chunk.code = banner + chunk.code;
      }
    },
  };
}

// build/ rather than dist/: the repository ignores dist/ directories.
export default defineConfig({
  plugins: [react(), thirdPartyLicenses()],
  build: { outDir: "build", emptyOutDir: true },
});
