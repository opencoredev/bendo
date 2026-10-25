# bendo

The TypeScript toolkit for [Bendo](https://github.com/opencoredev/bendo), a
Hono-style web framework written in Bend. It runs on Bun.

- `bendo` CLI: `dev`, `build`, `start`, `routes`, `gen`, `openapi`, `prove`
  and `doctor` for a Bend server app.
- `bendo/client`: a typed client for the routes `bendo gen` writes.
- `bendo/query`: TanStack Query helpers on top of the client.
- `bendo/shared`: call Bend code from TypeScript through its `.mjs` build.

Start a new app with `bun create bendo my-app`, which installs this package.
The guides are [the CLI](../../docs/cli.md), [the typed client](../../docs/client.md),
[the query helpers](../../docs/query.md) and [shared Bend code](../../docs/shared.md).
