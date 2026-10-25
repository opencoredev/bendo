# Bendo's laws in plain words

Bendo states what its pure code must do as laws in [`LAWS.bend`](../../LAWS.bend)
and the law modules it imports from `proof/`. [`PROOF.bend`](../../PROOF.bend)
proves every one of them, and `bun run prove` checks those proofs with Bend's
Lean-backed kernel. This section explains each law in a sentence: what it
says and what it guarantees for an app built on Bendo.

| Page | Covers |
| --- | --- |
| [HTTP](http.md) | request parsing, response framing, HTTP dates, conditional requests and body limits, the response write deadline, media types, error responses |
| [Routing](routing.md) | patterns, the reference router, the trie, method resolution, route composition, the route manifest |
| [Middleware](middleware.md) | composition, lifecycle hooks and scopes, plugins, CORS, secure headers, origins, CSRF, method override, trailing slash, IP restriction and client addresses, rate limiting, proxy, compression |
| [Data](data.md) | JSON, forms and queries, cookies, signed cookies, schemas, route validation, JSON Schema export, SQLite parameters and rows |
| [Crypto and JWT](crypto.md) | hex, base64, constant-time comparison, JSON Web Tokens |
| [Streaming, WebSocket and static files](streaming.md) | chunked bodies and streams, Server-Sent Events, the WebSocket handshake, frames, sessions and publish/subscribe, static file paths |
| [Equivalences](equivalences.md) | hot-path and stack-safe rewrites, and general proof building blocks |

`tests/laws-docs.test.ts` reads the law names from `LAWS.bend` and the law
modules it imports, and fails if a law has no entry here or an entry names a
law that no longer exists. Adding a law means adding its entry.

## Reading an entry

Each entry starts with the law's exact name, so you can search for it in
`LAWS.bend` or `proof/`, then says what it states. A few conventions:

- Most laws hold "for every" input of their type, often under a condition
  such as "valid", "well-formed" or "admissible". The entry says what that
  condition means when it matters. A law about well-formed requests says
  nothing about malformed ones.
- Many laws compare Bendo's code with a specification: a second definition,
  written separately, usually in a `proof/*-spec.bend` file, that states the
  intended behavior directly (often from the RFC). Such a law is as strong as
  the specification is independent. Where a specification shares code with the
  implementation, the entry or the section says so.
- Some laws are fixed examples: one input and its exact output. They pin
  documented syntax or a case from a review, next to a universal law that
  covers the general case.
- About a quarter are equivalence laws: a faster or stack-safe rewrite equals
  the definition the other laws were proven against, for every input. They
  are explained once per family on the [equivalences page](equivalences.md)
  and listed compactly.

## What the laws do not cover

The laws are about pure functions. Bendo keeps IO (the accept loop, sockets,
timers, file opens, rate-limit stores) in thin shells that integration tests
exercise instead, so a law about a policy says what the policy decides, not
that every byte reached the socket. Other limits worth knowing:

- The request-parser laws describe canonical input. Rejection of malformed
  and non-canonical requests is covered by the conformance suite and the
  fuzzer, not by laws. See [HTTP conformance](../http-conformance.md).
- The route-validation laws trust the JSON parser, which the implementation
  and its specification share. `Bytes.fold` and the raw query parser, the
  other two shared parsers, have their own laws against independent
  specifications. The JSON parser is checked by seeded differential tests
  against an independent parser instead; see [Data](data.md#json).
- The CSRF and WebSocket handshake specifications reuse the shared origin
  parser, which has its own laws against an independent origin specification.
- SHA-1, SHA-256 and HMAC are checked against published test vectors, not
  proven.
