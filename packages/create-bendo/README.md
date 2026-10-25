# create-bendo

Creates a Bendo app in a new directory.

```sh
bun create bendo my-app --template fullstack
```

| Template | What you get |
| --- | --- |
| `api` | `main.bend`: a Bend API whose routes carry schemas. The server checks each request, and `bun run gen` writes TypeScript route types to `.bendo/`. |
| `fullstack` | The API plus a React app on Vite, TanStack Router and TanStack Query. `src/api.ts` sets up the typed client from `bendo/client`, pages use `bendo/query`, and `shared/notes.bend` runs in both the server and the browser through `vite-plugin-bendo`. |

`bun create bendo <dir> [--template api|fullstack]` refuses a directory that
exists and is not empty, and leaves it untouched. An empty directory is filled.
On a terminal it asks for anything you left out. Without one (CI, pipes) it
never prompts: the directory is required and the template defaults to `api`.
It prints the next steps when it finishes. It does not run `bun install`.

Every app gets a copy of the Bend framework in `bendo/`, which `main.bend`
imports, and the toolchain pins `.bend-version` and `lean-toolchain`. Building
needs Bun, Bend at the pinned version, and clang. `bun run doctor` checks those
and the Lean toolchain that Bend's proof checker uses.

## Fullstack scripts

- `bun run dev` starts `bendo dev` on `API_PORT` (default 8787) and Vite on
  5173. Vite proxies `/api` to the Bendo server. The API's first compile
  takes several seconds; until it finishes, API calls fail and Vite logs
  proxy errors.
- `bun run build` compiles `dist/server`, regenerates `.bendo/`, builds the
  page into `dist/web` and runs `tsc`.
- `bun run start` runs `dist/server`, which serves `/api`, the files in
  `dist/web/assets`, and `index.html` for every other GET path, so router
  pages survive a reload.

## Before the first npm release

Nothing is published yet, so run the CLI from a Bendo checkout:

```sh
bun /path/to/bendo/packages/create-bendo/src/index.ts my-app --template fullstack
cd my-app && bun install
```

Run from a checkout, the CLI writes `file:` dependencies on the checkout's
`packages/bendo` and `packages/vite-plugin-bendo`. Bun copies them into
`node_modules` at install time, so reinstall after changing the toolkit. The
generated `package.json` also has an `overrides` entry for `bendo`, because the
checkout's `vite-plugin-bendo` names `bendo` as `workspace:^`, which only
resolves inside the monorepo.

The CLI decides this by where it runs. When `packages/create-bendo` sits inside
a checkout (one with `.bend-version` and `packages/bendo`), it links. Anywhere
else it acts as the published package: it copies the Bend library from its own
`bend/` directory, which the `prepack` script fills from the checkout's `src/`,
and it writes `^<version>` ranges on `bendo` and `vite-plugin-bendo` using
create-bendo's own version, with no overrides. Once the three packages are
published at the same version, `bun create bendo` works with no other change.
Packing alone does not make that work: a packed create-bendo at `0.0.0` asks npm
for `bendo@^0.0.0`, which does not exist.

## Tests

`packages/create-bendo/src/cli.test.ts` covers arguments, prompts and the
refusal rules. `tests/create-bendo-api.test.ts` and
`tests/create-bendo-fullstack.test.ts` scaffold each template into the system
temp directory, run `bun install` and `bun run build`, start `dist/server` and
call it. The fullstack test also checks that the template's shipped `.bendo/`
files match what `bendo gen` writes. Rerun `bun run gen` in a generated app and
copy `.bendo/` back into `templates/fullstack` after changing its `main.bend`.
