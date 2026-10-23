# Route manifest

Run a compiled app with `--bendo-routes` to print its route registrations as JSON.
The app exits with status 0 before reading `PORT` or opening a listening socket.
For example:

```sh
bend examples/hello/main.bend -o /tmp/bendo-hello
/tmp/bendo-hello --bendo-routes | jq .
```

The version 1 envelope is:

```json
{
  "bendo": 1,
  "routes": [{ "method": "GET", "path": "/*" }]
}
```

`bendo` is the manifest format version, independent of the package version.
`routes` is an array in registration order. Each explicitly registered method
produces an entry with its canonical case-sensitive HTTP token and the original path
pattern, including constraints such as `/todos/:id{int}`. Multiple methods on
one registration produce adjacent entries in the method list's order. Duplicate
registrations remain visible. Implicit HEAD fallback is not an extra registration.
`B.all` expands to the nine standard methods. An empty app exports `routes: []`.

Consumers must check `bendo`, accept unknown object fields and preserve route
order. BND-19 extends this envelope for composition, BND-37 adds route schemas,
and BND-56 consumes it for TypeScript generation. Additive fields keep version 1;
a change to existing field meanings requires a new version. Schemas are absent
until BND-37.

BND-28's JSON module is not in this branch's base. The exporter uses a local
writer that escapes quotation marks, backslashes and every JSON control character.
Its source has a TODO to adopt BND-28's shared writer.

## Public entrypoints

Import `src/main.bend as B`. The closed dispatcher has the signature
`dispatch(tag: Tag, ctx: B.Ctx, env: Env) -> IO(B.Res)`, where `Tag` and `Env`
are app-owned `Data` types. Startup state travels in `env`.

- `B.routes(Tag, registrations)` returns
  `Result<&2, &2, Methods.BuildError, B.Routes(Tag)>`. It validates registrations
  atomically and retains their source strings beside a proof-carrying
  `Methods.Valid<Tag>`. `B.Routes(Tag)` wraps those registrations and the validated
  table; `B.handle` and `B.serve` accept that same value. The manifest reads methods
  through `Methods.raw(Tag, valid)`, so canonical method names match dispatch.
- `B.handle(~Tag, ~Env, ~dispatch, table, env, req, body)` returns `IO(B.Res)`
  without opening a socket. Matching and response framing are pure; dispatcher IO
  still runs. `req` is `B.Req`; `body` is a list of octets. The returned response
  includes normalized framing headers and an empty body for HEAD, while preserving
  the GET representation's content length. Invalid dispatcher responses become 500.
- `B.serve(~Tag, ~Env, ~dispatch, table, env, config)` returns `IO(Unit)`, checks
  the manifest flag, then serves the same handler over TCP.
- `B.config()` returns the documented defaults in
  [`src/app/config.bend`](../src/app/config.bend). To customize fields, import that
  module and construct its `Config` record. `host` is an IPv4 literal. A valid
  decimal `PORT` between 1 and 65535 overrides `config.port`; missing, malformed,
  zero or out-of-range values use the configured port.

`B.Ctx` aliases `src/app/context.bend`'s `Ctx<Unit>`. Use the
[context accessors and helpers](context.md) to read requests, build responses,
and derive typed per-request variables.

`B` also exposes `Req`, `Res`, `ServerConfig`, `RouterKind`, `spec`, `trie`,
`text`, `body`, `not_modified`, `get`, `head`, `post`, `put`, `patch`, `delete`,
`options`, `all` and `on`. `spec()` and `trie()` construct router-kind values;
method-aware dispatch currently uses the reference router. BND-17 integrates trie
selection. Header limits, timeout fields, max requests and keep-alive are reserved
for BND-11. Connections currently serve one request and close.

The legacy byte-handler `Serve.serve` and two-field `Serve.Config` remain available
for existing low-level consumers. New applications use `B.serve` and `B.config`.
