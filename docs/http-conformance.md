# HTTP conformance and fuzzing

BND-13 checks the HTTP/1.1 server from the outside. Two tools talk to one
compiled Bendo app over raw TCP: a deterministic conformance suite and a seeded
fuzzer. Neither uses Bendo's own parser to judge responses. The fuzzer adds to
the per-row framing tests in `tests/http-body.test.ts` and
`tests/http-connection.test.ts` (decisions [0005](decisions/0005-framing.md) and
[0009](decisions/0009-connections.md)); it does not replace them.

## The server under test

`tests/fixtures/http-conformance/server.bend` is a `B.serve` app with these
routes:

| Route | Answer |
| --- | --- |
| `GET /`, `GET /text` (and HEAD) | `conformance` as text |
| `POST /echo`, `POST /chunked` | the request body, byte for byte |
| `POST /summary` | the body, plus `x-header-count` with the number of request header fields |

It runs with small limits so rejection paths are quick to reach: 16 KiB body,
8 KiB head, 500 ms idle timeout, 700 ms head and body deadlines.

## The response oracle

`tests/conformance/wire.ts` parses every response with its own RFC 9112 rules.
It rejects a bad status line, an invalid or duplicated field, any
`Transfer-Encoding`, a missing or malformed `Content-Length`, a length on 1xx or
204, a truncated body, trailing bytes, any of 400, 408, 413, 417 or 431 without
`Connection: close`, and any bytes after a closing response.

`responses(wire, methods)` takes the request methods so HEAD responses are read
without a body. `framedResponses(wire)` is for the fuzzer, which cannot know
which mutated request was a HEAD. Each response with a nonzero length may then
carry its body or not, and the whole buffer must parse under some choice.

## Conformance suite

Run it with:

```sh
bun test --timeout 30000 tests/conformance
```

It covers:

- **Split reads.** Six representative requests (GET, HEAD, `Content-Length`
  body, chunked body, repeated and obs-text headers, leading CRLF), each sent
  split in two at every byte offset and once as one write per byte. 4 KiB
  bodies of all 256 octet values at sampled splits. A four-request pipeline
  split at every offset.
- **Pipelining.** 3 to 10 requests in one write, mixing `Content-Length`,
  chunked, HEAD and GET; responses stay in order and HEAD carries GET's length.
  An error in the middle answers earlier requests, then closes without running
  later ones. A 105-request pipeline gets exactly 100 answers, the last one
  closing. Body octets sent with the next head do not count toward that head's
  budget.
- **Slow clients.** Two clients sending one byte per 100 ms get 408 at the
  deadline while five fast requests complete first.
- **Oversized heads.** Exactly 8192 octets passes and 8193 gets 431, whether
  the excess is padding, 1400 short fields, 4097 leading CRLFs, a long target or
  one long field.
- **Bad request lines and fields.** 29 malformed heads, including bad versions,
  invalid method tokens, NUL, DEL, bare LF, lone CR, obs-fold and whitespace
  before a colon, each get 400 and a close.
- **Ambiguous framing.** 33 smuggling shapes from decision 0005 (TE with CL,
  repeated or malformed CL, oversized numbers, unknown or repeated codings, bad
  chunk sizes, extensions and trailers), plus TE on HTTP/1.0. Each is followed
  by a valid request in the same write. The server must answer one 400 with
  `Connection: close` and never answer the queued request.
- **Binary bodies.** Every octet value, CR, LF and an embedded request head echo
  exactly under both framings; 16385 octets get 413.

Measured wall time for `bun test tests/conformance` (86 tests):

| Machine | Time |
| --- | --- |
| Boat `default` sandbox, idle (4 vCPU) | 3.3 to 3.8 s over three runs |
| ms-a2, load average 2.5 to 26 (shared) | 3.3 to 3.4 s |

## Fuzzer

`scripts/fuzz-http.ts` starts the fixture and sends generated cases. Case `n`
of seed `s` is built from its own PRNG stream (mulberry32), so any case replays
alone.

Each case is one of:

- **generated** (30%): one request from the HTTP grammar. Just over half are
  valid, most of those aimed at a real route. The rest break exactly one part:
  the method, target, version, a field, the framing headers, the chunked body,
  or a size limit.
- **pipeline** (15%): 2 to 10 generated or mutated requests in one write.
- **mutated** (50%): a generated request with 1 to 8 byte-level mutations: bit
  flips, interesting octets (NUL, CR, LF, SP, colon, DEL, 0xFF), inserts,
  deletes, duplicated ranges, splices from another request, CRLF replaced by
  `\n`, `\r`, `\r\r\n` and similar, digit runs replaced by very large numbers,
  and truncation.
- **random** (5%): up to 600 random octets.

Each case goes out in up to six writes with 0 to 2 ms pauses. 97% half-close
after writing; the rest leave the socket open so the server's own deadlines
must close it. A case passes when the connection reaches EOF within 10 seconds
and everything received parses with `framedResponses`. An empty reply is a
valid close. A reset counts as a close and is tallied separately, but the
bytes received before it must still parse as whole responses. The run fails on
a hang, an ill-framed response, a server exit, or a failed health check
(`GET /text` on a fresh connection every 100 cases). The report also records
peak server RSS. Startup has a 20 second budget that also bounds each readiness
probe, so a server that accepts connections but never answers fails instead of
stalling the run.

`bun run check` runs a fixed-seed short mode in `tests/fuzz/http.test.ts`:
seed 20261023, 1500 cases, about 7 seconds. It also requires 200, 400, 404,
413, 417 and 431 to each appear, so the generator keeps reaching handlers and
every rejection path.

### Self-test

`tests/fuzz/self-test.test.ts` runs the fuzzer against
`tests/fuzz/broken-server.ts`, a small Bun server with one mode per failure. It
answers the readiness probe correctly, then misbehaves on fuzz cases. The
fuzzer must report each mode with the matching reason:

| Mode | Expected failure |
| --- | --- |
| `hang` | no EOF within the case deadline |
| `missing-length` | ill-framed: missing `Content-Length` |
| `extra-bytes` | ill-framed: bytes after the body |
| `bad-status` | ill-framed: invalid status line |
| `junk-then-reset` | ill-framed before reset: truncated head |
| `crash` | server exit (or a refused connection right after it) |
| `silent` | startup fails within its deadline |

Two control modes, `valid` and `valid-then-reset`, send a well-framed 400 and
must pass. The self-test runs in `bun run check` and takes about 3 seconds.

### Long runs

Run long fuzzing on a Boat sandbox, never on ms-a2:

```sh
bun scripts/fuzz-http.ts --minutes 10 --seed <n>
```

`--cases <n>` stops after a count instead, `--case <n>` replays one case, and
`--concurrency <n>` sets parallel connections (default 8). A failure exits 1
and saves the case, its writes in base64, and the bytes received to
`.cache/fuzz/failure-<seed>-<case>.json`.

### Recorded runs

| Date | Where | Command | Cases | Result |
| --- | --- | --- | --- | --- |
| 2026-10-23 | Boat `default` sandbox (4 vCPU, 8 GB), Bend 2.0.38, Bun 1.4.4 | `bun scripts/fuzz-http.ts --minutes 10 --seed 1013` | 142,818 in 601 s | PASS |

That run sent 43,264 generated, 21,172 pipelined, 71,209 mutated and 7,173
random cases. Every connection reached EOF with well-framed output, none reset,
all 1,429 health checks passed, and server RSS peaked at 6.2 MiB. Responses
seen: 100 (100), 200 (32,588), 400 (90,637), 404 (6,938), 405 (5,250),
408 (213), 413 (2,749), 417 (9,989), 431 (6,692). It found no bugs.
