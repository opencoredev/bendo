# Docs site

The docs site is [VitePress](https://vitepress.dev) 1.6.4, rendering the
Markdown files in `docs/` as they are. This file and the other contributor
documents (`PLAN.md`, `RUNBOOK.md`, `test-runners.md`) stay in the repo and are
not published; links to them become GitHub links.

## Commands

Run these from the repository root:

```sh
bun install --cwd docs --frozen-lockfile   # once, and after docs/bun.lock changes
bun run docs:dev       # live preview on http://localhost:5173
bun run docs:build     # static site in docs/.vitepress/dist
bun run docs:preview   # serve the built site on http://localhost:4173
bun run check:docs     # install, typecheck the config, build: what CI runs
```

The docs have their own `package.json` and `bun.lock`, so the test jobs never
install VitePress.

## Where things live

| Path | What it holds |
| --- | --- |
| `docs/*.md`, `docs/*/*.md` | Every page. Relative links between pages work on GitHub and on the site. |
| `docs/index.md` | The home page. |
| `docs/concepts/` | Concept pages. They explain and link to the reference pages instead of repeating them. |
| `docs/.vitepress/sidebar.ts` | The sidebar. Every published page must be listed. |
| `docs/.vitepress/config.ts` | Site config and the build checks. |
| `docs/.vitepress/links.ts` | Rewrites links into `src/`, `tests/`, `examples/` and unpublished docs to GitHub. |
| `docs/.vitepress/theme/` | Colors and fonts on top of the default theme. |
| `docs/public/` | Files copied to the site root, such as `logo.svg`. |
| `docs/wrangler.toml` | Static hosting config. |

To show part of one page inside another, mark it in the source with
`<!-- #region name -->` and `<!-- #endregion name -->` and include it with
`<!--@include: ../path.md#name-->`. Keep included parts free of relative links,
because they resolve against the including page.

## What fails the build

- A link to a page or file that does not exist (VitePress's dead-link check,
  extended to repo files by `links.ts`).
- A published page missing from `sidebar.ts`.
- An `@include` whose file or region does not exist.

## Deploy

Nothing deploys automatically, and no domain is set up. The build output in
`docs/.vitepress/dist` is plain static files with clean URLs (`/concepts/routing`
serves `concepts/routing.html`), so any static host works.

`docs/wrangler.toml` configures Cloudflare Workers static assets. When Leo
approves a deploy:

```sh
bun run docs:build
cd docs && bunx wrangler@4 deploy
```

That publishes the site at `bendo-docs.<account>.workers.dev`. A custom domain
needs a DNS change and is Leo's call.

Planned addition: the API reference (BND-71). Add its pages to `sidebar.ts`
where its comment says. The task and migration guides live in `docs/guides`,
and `tests/guides.test.ts` checks every code block in them.
