# Bendo app

A [Bendo](https://github.com/opencoredev/bendo) API with a React app on Vite,
TanStack Router and TanStack Query.

- `main.bend`: the API. Its routes carry schemas, and the server checks every
  request against them.
- `.bendo/`: route types and response schemas written by `bun run gen`. The
  typed client in `src/api.ts` uses them. Rerun it after changing a route.
- `shared/notes.bend`: Bend code both sides run. The server builds its schema
  from it, and `src/` imports it through `vite-plugin-bendo`.
- `bendo/`: the framework source `main.bend` imports. Keep it with the app.

You need Bun, Bend (the version in `.bend-version`) and clang. `bun run doctor`
checks them, and Lean (`lean-toolchain`) for writing proofs.

```sh
bun install
bun run dev      # app on http://127.0.0.1:5173, API on 127.0.0.1:8787
bun run build    # dist/server and dist/web, after regenerating .bendo/
bun run start    # dist/server serves the API and the app on :8787
```

`API_PORT` moves the development API; `PORT` moves `bun run start`.
