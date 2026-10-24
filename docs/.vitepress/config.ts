import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { defineConfig } from "vitepress";
import { classifyLink, repoUrl, type LinkScope } from "./links.ts";
import { sidebar } from "./sidebar.ts";

const docsDir = resolve(import.meta.dirname, "..");
const repoDir = resolve(docsDir, "..");

// Contributor documents stay in the repo; links to them go to GitHub.
const unpublished = ["PLAN.md", "RUNBOOK.md", "SITE.md", "test-runners.md"];
const srcExclude = [...unpublished, "**/node_modules/**"];

const scope: LinkScope = {
  docsDir,
  repoDir,
  isPage: (page) => !unpublished.includes(page) && existsSync(resolve(docsDir, page)),
};

function sidebarLinks(items: typeof sidebar): string[] {
  return items.flatMap((item) => [
    ...(item.link === undefined ? [] : [item.link]),
    ...sidebarLinks(item.items ?? []),
  ]);
}

// VitePress leaves a broken `<!--@include: file#region-->` in place, or
// includes the whole file when the region is missing, without failing.
function brokenIncludes(page: string): string[] {
  const source = readFileSync(resolve(docsDir, page), "utf8");
  return [...source.matchAll(/<!--\s*@include:\s*([^#\s]+)(?:#([\w-]+))?\s*-->/g)].flatMap(
    ([directive, file, region]) => {
      const target = resolve(docsDir, dirname(page), file ?? "");
      if (!existsSync(target)) return [`${page}: ${directive} (no such file)`];
      const marker = `<!-- #region ${region} -->`;
      if (region !== undefined && !readFileSync(target, "utf8").includes(marker)) {
        return [`${page}: ${directive} (no ${marker})`];
      }
      return [];
    },
  );
}

function pageRoute(page: string): string {
  return `/${page.replace(/(^|\/)index\.md$/, "$1").replace(/\.md$/, "")}`;
}

export default defineConfig({
  title: "Bendo",
  description: "A Hono-style web framework for Bend, with proofs and a typed TypeScript client.",
  lang: "en-US",
  cleanUrls: true,
  lastUpdated: false,
  srcExclude,
  rewrites: { "laws/README.md": "laws/index.md" },
  head: [["link", { rel: "icon", type: "image/svg+xml", href: "/logo.svg" }]],
  markdown: {
    // Bend has no Shiki grammar yet. Its syntax is close enough to Python
    // that the existing docs already fence it as `python`.
    languageAlias: { bend: "python" },
    // The high-contrast light theme keeps every token at 4.5:1 or more on the
    // code background; github-light's red and orange fall below it.
    theme: { light: "github-light-high-contrast", dark: "github-dark" },
    config(md) {
      const render = md.renderer.rules.link_open;
      md.renderer.rules.link_open = (tokens, index, options, env, self) => {
        const token = tokens[index];
        const href = token?.attrGet("href");
        const page: unknown = env?.relativePath;
        if (
          token !== undefined &&
          href !== null &&
          href !== undefined &&
          typeof page === "string"
        ) {
          const target = classifyLink(scope, page, href);
          switch (target.kind) {
            case "keep":
              break;
            case "page":
            case "repo":
              token.attrSet("href", target.href);
              break;
            default: {
              const exhaustive: never = target;
              return exhaustive;
            }
          }
        }
        return render === undefined
          ? self.renderToken(tokens, index, options)
          : render(tokens, index, options, env, self);
      };
    },
  },
  buildEnd(site) {
    const listed = new Set(sidebarLinks(sidebar));
    listed.add("/");
    const unlisted = site.pages
      .map((page) => pageRoute(site.rewrites.map[page] ?? page))
      .filter((route) => !listed.has(route));
    const problems = [
      ...unlisted.map((route) => `page missing from .vitepress/sidebar.ts: ${route}`),
      ...site.pages.flatMap(brokenIncludes),
    ];
    if (problems.length > 0) throw new Error(`docs check failed:\n  ${problems.join("\n  ")}`);
  },
  themeConfig: {
    logo: { src: "/logo.svg", alt: "" },
    nav: [
      { text: "Quick start", link: "/getting-started" },
      { text: "Concepts", link: "/concepts/" },
      { text: "Laws", link: "/laws/" },
      { text: "Examples", link: "/examples" },
    ],
    sidebar,
    search: { provider: "local" },
    socialLinks: [{ icon: "github", link: repoUrl }],
    editLink: { pattern: `${repoUrl}/edit/main/docs/:path`, text: "Edit this page on GitHub" },
    outline: { level: [2, 3] },
    footer: { message: "Bendo is pre-alpha. MIT licensed." },
  },
});
