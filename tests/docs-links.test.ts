import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";

// Every relative link in a tracked Markdown file must name a file or directory
// that exists, and a `#fragment` on a Markdown target must name one of its
// headings. External links (with a scheme) are not fetched.

const root = resolve(import.meta.dir, "..");

function trackedMarkdown(): string[] {
  const git = Bun.spawnSync(["git", "ls-files", "-z", "--", "*.md"], { cwd: root });
  if (git.exitCode !== 0) throw new Error(`git ls-files failed: ${git.stderr.toString()}`);
  return git.stdout
    .toString()
    .split("\0")
    .filter((path) => path.length > 0 && existsSync(join(root, path)));
}

/** Markdown without fenced code blocks, which may be indented up to three spaces. */
function withoutFences(text: string): string {
  return text.replace(/^ {0,3}(```|~~~)[^\n]*\n[\s\S]*?^ {0,3}\1[^\n]*$/gm, "");
}

/** Markdown with fenced code blocks and inline code spans blanked out. */
function prose(text: string): string {
  return withoutFences(text).replace(/`[^`\n]*`/g, "``");
}

const inlineLink = /!?\[(?:[^\]\n]|\][^(\n])*\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)/g;
const referenceLink = /^\s*\[[^\]\n]+\]:\s*<?(\S+?)>?(?:\s+"[^"]*")?\s*$/gm;

function linksIn(text: string): string[] {
  const body = prose(text);
  return [
    ...Array.from(body.matchAll(inlineLink), (match) => match[1] ?? ""),
    ...Array.from(body.matchAll(referenceLink), (match) => match[1] ?? ""),
  ].filter((target) => target.length > 0);
}

/** GitHub's heading anchors: lowercase, punctuation dropped, spaces to hyphens. */
function anchors(text: string): Set<string> {
  const seen = new Map<string, number>();
  const result = new Set<string>();
  // Inline code keeps its text in an anchor: "Boat `large` sandbox" is
  // #boat-large-sandbox.
  for (const match of withoutFences(text).matchAll(/^#{1,6}\s+(.+?)\s*#*\s*$/gm)) {
    const heading = (match[1] ?? "")
      .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
      .replace(/`([^`\n]*)`/g, "$1");
    const base = heading
      .toLowerCase()
      .replace(/[^\p{L}\p{N}\s_-]/gu, "")
      .replace(/\s/g, "-");
    const count = seen.get(base) ?? 0;
    seen.set(base, count + 1);
    result.add(count === 0 ? base : `${base}-${count}`);
  }
  return result;
}

function brokenLinks(file: string): string[] {
  const text = readFileSync(join(root, file), "utf8");
  return linksIn(text).flatMap((target) => {
    if (/^[a-z][a-z0-9+.-]*:/i.test(target)) return [];
    const hash = target.indexOf("#");
    const path = decodeURIComponent(hash === -1 ? target : target.slice(0, hash));
    const fragment = hash === -1 ? "" : decodeURIComponent(target.slice(hash + 1));
    const resolved = path === "" ? join(root, file) : resolve(root, dirname(file), path);
    if (!resolved.startsWith(root)) return [`${target} (outside the repository)`];
    if (!existsSync(resolved)) return [`${target} (no such file)`];
    if (fragment === "" || !resolved.endsWith(".md") || statSync(resolved).isDirectory()) return [];
    const ids = anchors(readFileSync(resolved, "utf8"));
    return ids.has(fragment)
      ? []
      : [`${target} (no heading #${fragment} in ${relative(root, resolved)})`];
  });
}

describe("Markdown links", () => {
  const files = trackedMarkdown();

  test("finds the top-level docs", () => {
    for (const file of ["README.md", "CONTRIBUTING.md", "AGENTS.md", "docs/laws/README.md"]) {
      expect(files).toContain(file);
    }
  });

  test("anchors keep inline code text, and indented fences hide their links", () => {
    expect(anchors("### Boat `large` sandbox (primary numbers)\n")).toContain(
      "boat-large-sandbox-primary-numbers",
    );
    expect(linksIn("1. Step\n\n   ```md\n   [not prose](missing.md)\n   ```\n")).toEqual([]);
    expect(linksIn("[real](here.md)\n")).toEqual(["here.md"]);
  });

  test("every relative link resolves", () => {
    const broken = files.flatMap((file) => brokenLinks(file).map((link) => `${file}: ${link}`));
    expect(broken).toEqual([]);
  });
});
