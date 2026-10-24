# Todo example

A todo list with a Bend API and a React app. The API keeps its todos in a
`B.Store` and serves create, read, update and delete routes with CORS. The app
runs on Vite with TanStack Router and TanStack Query. It calls the API through
Bendo's [typed client](../../docs/client.md) and [query helpers](../../docs/query.md),
and checks each form with the same Bend validator the server uses.

## Run it

You need Bun and Bend (see the repository's `CLAUDE.md` for the pinned
versions). From the repository root:

```sh
bun install
cd examples/todo
bun run api    # the Bend API on http://127.0.0.1:8787
bun run web    # in a second terminal: the app on http://127.0.0.1:5173
```

Open http://127.0.0.1:5173. `bun run api` runs `bendo dev`, which rebuilds the
server when a `.bend` file changes. For the native binary, run
`bunx bendo build` and then `./dist/server`.

The API allows the browser origins `http://127.0.0.1:5173` and
`http://localhost:5173`. To open the app from another address, set both sides:

```sh
TODO_WEB_ORIGIN=http://192.168.1.20:5173 bun run api
VITE_BENDO_API=http://192.168.1.20:8787 bun run web -- --host 0.0.0.0
```

The API listens on 127.0.0.1 only, as every Bendo app does by default, so the
second machine also needs the API port forwarded or proxied to it.

## How it fits together

| File | What it does |
| --- | --- |
| `shared/todo.bend` | The schemas for every route, the blank-title rule, and `check_create` and `check_update`, which the browser calls |
| `todos.bend` | The todo list as pure state: create, update, remove, filter |
| `main.bend` | The routes, their schemas, the store, and the CORS middleware |
| `.bendo/` | Route types and response schemas from `bunx bendo gen` |
| `src/` | The React app |

Each form runs `shared/todo.bend` in the browser through
[vite-plugin-bendo](../../docs/vite-plugin.md) before it sends anything. The
server declares the same schemas on its routes, so
[route validation](../../docs/validation.md) rejects a bad body with a 422
before the handler runs. A title of only spaces passes a length check, so both
sides also apply the shared `blank` rule.

Turn off **Check in the browser** at the top of the page to send bad input
anyway. The form then shows the server's 422 instead of the browser's message.

## Change a route

After you change a route or a schema, regenerate the client types and commit
them:

```sh
bunx bendo gen
```

`tests/todo-example.test.ts` fails when `.bendo/` is stale. It also drives the
API over HTTP, checks that the browser and server accept the same bodies, checks
that every route exports its full schemas, and builds and typechecks the app.
Run it from the repository root:

```sh
bun test --timeout 30000 tests/todo-example.test.ts
```
