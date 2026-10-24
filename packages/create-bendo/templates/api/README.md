# Bendo API

A [Bendo](https://github.com/opencoredev/bendo) server. `main.bend` holds the
routes, their schemas and the handlers. `bendo/` is the framework source it
imports; keep it with the app.

You need Bun, Bend (the version in `.bend-version`) and clang. `bun run doctor`
checks them, and Lean (`lean-toolchain`) for writing proofs.

```sh
bun install
bun run dev      # http://127.0.0.1:8787, rebuilt on every .bend save
bun run build    # native binary at dist/server
bun run start    # run dist/server
```

Set `PORT` to listen elsewhere.

```sh
curl http://127.0.0.1:8787/hello/Ada
curl -X POST http://127.0.0.1:8787/echo -H 'content-type: application/json' -d '{"message":"hi"}'
```

A body that breaks its schema gets a 422 with the list of errors. Run
`bun run gen` to write TypeScript route types to `.bendo/` for `bendo/client`.
