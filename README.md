# Bendo

A Hono-style web framework for [Bend](https://bend-lang.com), with a TypeScript toolkit for calling it from React with full types.

- One native binary for the server.
- Routing, parsing, JSON and validation with machine-checked proofs in `LAWS.bend`.
- The same Bend validation code runs on the server and in the browser.
- Handlers can spread heavy work across every CPU core, or the GPU.

Bendo is pre-alpha and being built in the open. See [docs/PLAN.md](docs/PLAN.md) for the full plan. The [route pattern reference](docs/router-patterns.md) describes the current compiler and matcher. [Compose route lists](docs/router-compose.md) covers base paths, mounting and nested groups. See the [public entrypoints and route manifest](docs/manifest.md) for network-free handling, server configuration and `--bendo-routes`. [Static files](docs/static.md) covers `serve_static`, and [the proxy guide](docs/proxy.md) covers `B.proxy`.

## Try the hello example

```sh
curl -fsSL https://bend-lang.com/install.sh | sh
bend examples/hello/main.bend -o hello && ./hello
curl http://127.0.0.1:8787/todos/42
```

## Develop

```sh
bun install
bun run check   # proofs, typecheck, integration tests
```

## License

MIT

## Benchmarks

[Five-scenario benchmark chart](bench/results/2026-10-24-full-suite.svg) comparing Bendo’s native server with Hono and Elysia on Bun. See the [method and results](bench/README.md).
