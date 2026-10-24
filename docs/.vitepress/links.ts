import { existsSync, statSync } from "node:fs";
import { posix, relative, resolve } from "node:path";

// The site renders the Markdown in `docs/` as it is, so pages keep the
// relative links that work on GitHub. A link that leaves the published pages
// (into `src/`, `tests/`, `examples/`, or an unpublished doc) is rewritten to
// the file on GitHub. Every other link is left as written, so VitePress's
// dead-link check fails the build on a missing page or file.

export const repoUrl = "https://github.com/opencoredev/bendo";
const branch = "main";

export type LinkTarget =
  | { kind: "keep" }
  | { kind: "page"; href: string }
  | { kind: "repo"; href: string };

export type LinkScope = {
  docsDir: string;
  repoDir: string;
  // Whether a docs-relative Markdown path is a page on the site.
  isPage: (pagePath: string) => boolean;
};

const absoluteOrAnchor = /^([a-z][a-z0-9+.-]*:|\/|#)/i;

export function classifyLink(scope: LinkScope, fromPage: string, href: string): LinkTarget {
  if (absoluteOrAnchor.test(href)) return { kind: "keep" };
  const cut = href.search(/[?#]/);
  const path = cut === -1 ? href : href.slice(0, cut);
  const suffix = cut === -1 ? "" : href.slice(cut);
  if (path === "") return { kind: "keep" };
  const target = posix.normalize(posix.join(posix.dirname(fromPage), decodeURI(path)));
  if (!target.startsWith("../") && target.endsWith(".md") && scope.isPage(target)) {
    // A folder's README is published as its index page.
    return { kind: "page", href: href.replace(/(^|\/)README\.md(?=$|[?#])/, "$1index.md") };
  }
  const absolute = resolve(scope.docsDir, target);
  const repoPath = relative(scope.repoDir, absolute).split("\\").join("/");
  if (repoPath.startsWith("..") || !existsSync(absolute)) return { kind: "keep" };
  const view = statSync(absolute).isDirectory() ? "tree" : "blob";
  return { kind: "repo", href: `${repoUrl}/${view}/${branch}/${encodeURI(repoPath)}${suffix}` };
}
