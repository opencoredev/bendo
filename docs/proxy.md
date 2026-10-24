# Proxy requests to an upstream

`B.proxy` forwards the current request to an HTTP/1.1 upstream and streams the
upstream's answer back through [`B.stream`](streaming.md). It sends the method,
path, query, end-to-end headers and body. Hop-by-hop headers are removed in
both directions, framing is recomputed, and the client gets 502 or 504 when the
upstream fails before its response head is complete. The complete native
example is [the proxy fixture](../tests/servers/proxy.bend).

```python
import Base
import ../src/main.bend as B
import ../src/router/methods.bend as Methods

type Tag is Data:
  Api{}

def handler(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  B.proxy(c, B.proxy_rewrite(B.proxy_options("http://127.0.0.1:3000"), "/api", ""))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve(~Tag, ~Unit, ~handler, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.all(Tag, "/api/*", Api{})]))
```

A request for `/api/users?page=2` reaches `http://127.0.0.1:3000/users?page=2`.
Use `B.proxy_with(Vars, c, options)` from a handler with typed context variables.

## Options

`B.proxy_options(url)` returns `B.ProxyOptions` with these defaults. Each setter
returns a new value.

| Setter | Default | Effect |
|---|---|---|
| `B.proxy_preserve_host(o, on)` | off | Send the client's `Host` instead of the upstream's authority. |
| `B.proxy_trust_forwarded(o, on)` | off | Append to incoming forwarding fields instead of replacing them. |
| `B.proxy_forwarded(o, on)` | off | Also send an RFC 7239 `Forwarded` field. |
| `B.proxy_rewrite(o, from, to)` | none | Replace a leading `from` in the path with `to`. |
| `B.proxy_timeouts(o, connect, send, head, read)` | 5000, 30000, 30000, 30000 ms | See [timeouts](#timeouts). |
| `B.proxy_stream_config(o, config)` | `B.stream_config()` | Write budget and maximum chunk size of the client stream. |

The upstream URL is `http://host[:port][/base]`. The scheme and host may be
in any case; Bendo lowercases them. `host` is one of:

- a DNS name, such as `api.internal` or `localhost`. Labels are 1 to 63
  characters of `a-z`, `0-9`, `-` and `_`, may not start or end with `-`, and
  the name has at most 253 characters. Empty labels, and so a trailing root
  dot, are refused. A name that ends in a number, such as `127.1` or
  `0x7f.1`, is read as IPv4 and refused, because a resolver would rewrite it.
- a dotted-quad IPv4 address without leading zeros, such as `10.0.0.5`.
- an IPv6 address in brackets, in RFC 5952 form: lowercase (Bendo lowercases
  it for you), compressed, with no zone ID and no dotted IPv4 tail, such as
  `[::1]` or `[2001:db8::1]`. `[0::1]` and `[::ffff:1.2.3.4]` are refused.
  Addresses that carry an IPv4 address are refused too, because a dual-stack
  socket would reach the IPv4 host: IPv4-mapped addresses (`::ffff:0:0/96`,
  such as `[::ffff:c000:201]`) and IPv4-compatible ones (`::/96` other than
  `[::]` and `[::1]`, such as `[::c000:201]`). Other prefixes are ordinary
  IPv6, including NAT64 (`64:ff9b::/96`) and `::ffff:0:0:0/96`.

The port has one to five digits with a value from 1 to 65535 and defaults to
80. Leading zeros are allowed and kept: `http://api:080` dials port 80 and
sends `Host: api:080`. `base` is prefixed to every forwarded path. Bendo refuses any other URL,
including `https`, userinfo, an empty port, a query or a fragment, and answers
`500` `Proxy upstream misconfigured`. The host grammar is the origin host
grammar of `src/http/origin.bend` plus the label rules, and two laws check the
parser (see [Verify](#verify)).

A rewritten path must still be an origin-form path (it starts with `/` and has
only path characters). Otherwise the request gets `500`
`Proxy rewrite produced an invalid target` and nothing is sent upstream.
`OPTIONS *` is forwarded as `*`.

The upstream host and port come only from the configured URL; a request can't
change where Bendo connects. The `base` path and rewrites are not an access
boundary, though: Bendo forwards dot segments as sent, so `/api/../admin`
reaches whatever the upstream resolves it to. If the upstream must only see
paths under `base`, enforce that upstream or reject such paths before calling
`B.proxy`.

## What is sent upstream

The upstream request line is `METHOD target HTTP/1.1`. Bendo builds the header
list in this order:

1. `host`: the upstream URL's host, in lowercase and with IPv6 in brackets,
   followed by `:` and the port exactly when the URL has one, digits as
   written (`127.0.0.1:3000`, `api.internal`, `[::1]:8080`). With
   `preserve_host` it is the client's `Host` when it has one.
2. The client's end-to-end fields, unchanged and in arrival order. Bendo first
   removes the hop-by-hop fields described below. It then drops `Host`,
   `Content-Length`, `Transfer-Encoding`, `Expect` (the server already answered
   it), `Proxy-Authorization` (a credential for this hop) and the incoming
   forwarding fields.
3. `x-forwarded-for` (the socket peer), `x-forwarded-proto` (`http`) and
   `x-forwarded-host` (the client's `Host`). With `trust_forwarded`, each one
   instead holds the incoming values of that field, joined with `, `, followed
   by Bendo's own value.
4. `forwarded`, when enabled: `for=<peer>;host="<client host>";proto=http`.
   IPv6 peers are written as `for="[2001:db8::1]"`, and quotes and backslashes
   in the host are escaped. With `trust_forwarded` it is appended to the
   incoming `Forwarded` values. An unknown peer is written as `for=unknown`.
5. `content-length`: the body length, when the body is not empty or the client
   request had `Content-Length` or `Transfer-Encoding`.
6. `connection: close`.

Hop-by-hop fields are removed from the client's list before step 3, so a
client that names `Host`, `Content-Length` or `X-Forwarded-For` in its
`Connection` field cannot remove a field Bendo adds. Any generated field whose
name is not a token or whose value is not valid field content is dropped.

Only enable `trust_forwarded` when every client reaches Bendo through a proxy
you control that sets these fields itself. Otherwise clients can forge the
chain.

### Request bodies are buffered, not streamed

The body sent upstream is the one the server already read under its
`body_limit` (1 MiB by default). Bendo reads the whole request before any
handler runs, so an upload larger than the limit gets `413` before the proxy
starts. Memory for an upload is proportional to its admitted size. Streaming
uploads would need changes to the connection layer and are not implemented.
To proxy larger uploads, start the server with a larger `body_limit` in its
`Config.Config` record (`src/app/config.bend`), as the proxy fixture does.

## Hop-by-hop headers

In both directions Bendo removes `Connection`, `Keep-Alive`,
`Proxy-Connection`, `TE`, `Trailer`, `Transfer-Encoding` and `Upgrade`. It also
removes every field named by an option in any `Connection` field of the same
message. Names compare case-insensitively, options are comma-separated with
spaces and tabs trimmed, and empty options name nothing. Every other field
keeps its value and position, so repeated fields such as `Set-Cookie` stay
separate and ordered.

Two laws in [`proof/proxy-laws.bend`](../proof/proxy-laws.bend) check this
filter (`src/http/proxy_headers.bend`) against an independent specification in
[`proof/proxy-headers-spec.bend`](../proof/proxy-headers-spec.bend), for every
header list:

- `proxy_forward_spec`: the result is exactly the clean fields of the input,
  unchanged and in order.
- `proxy_forward_clean`: no field in the result is hop-by-hop or named in a
  `Connection` field.

The response also loses `Content-Length`, because the stream writer recomputes
framing, and `Proxy-Authenticate`.

## What the client receives

Bendo reads the upstream status line and headers strictly. The status line is
`HTTP/1.1` or `HTTP/1.0`, a space, three digits from 100 to 599 and a space
(the reason may be empty). It requires CRLF line endings and refuses obs-fold.
The whole head, interim responses included, may use at most 65536 octets.
Interim `1xx` responses other than 101 are discarded, up to 8 of them. A `101`
is refused, since no `Upgrade` is ever forwarded.

The body framing comes from the raw upstream head:

| Upstream | Body |
|---|---|
| HEAD request, 204 or 304 | none |
| `Transfer-Encoding: chunked` (exactly), no `Content-Length` | chunked, decoded; trailers are dropped |
| `Content-Length`, every value and list element identical | that many octets; extra octets are ignored |
| neither | until the upstream closes |
| anything else | `502` |

Anything else covers `Transfer-Encoding` together with `Content-Length`, any
other transfer coding, `Transfer-Encoding` in an HTTP/1.0 response, and
disagreeing or invalid lengths. A single `Content-Length` above 4294967295 is
also refused.

The client always gets the upstream status and the filtered headers, with the
body re-framed as chunked by `B.stream`. HEAD responses therefore have no
`Content-Length`, and 205 gets `content-length: 0`, as described in
[the streaming guide](streaming.md#http-and-lifecycle-behavior). Middleware,
response hooks, request IDs and `Date` apply as for any stream.

## Failures

| Situation | Response |
|---|---|
| Upstream URL not supported | `500` `Proxy upstream misconfigured` |
| Rewrite leaves an invalid path | `500` `Proxy rewrite produced an invalid target` |
| `CONNECT` request | `501` `Not Implemented: CONNECT is not proxied` |
| The upstream host name does not resolve | `502` `Bad Gateway: upstream host did not resolve` |
| Connection refused or unreachable, or the request send fails | `502` `Bad Gateway: upstream connection failed` |
| Malformed status line, headers or framing, `101`, or EOF before the head ends | `502` `Bad Gateway: invalid upstream response` |
| Connect, request-send or head timeout | `504` `Gateway Timeout: upstream did not answer in time` |

The bodies are `text/plain; charset=utf-8`. Once the head has been sent, the
status cannot change. After that point a malformed chunk, a fixed-length body
that ends early, a receive error or a read timeout aborts the client
connection without the terminating chunk. A client can tell a truncated body
from a complete one by the missing last chunk. Decoded octets from earlier
receives may already have been delivered.

## Timeouts

- **connect** (5000 ms): one absolute budget for resolving the host and
  connecting to it, described [below](#name-resolution-and-connecting). On
  timeout the connect effect closes its own descriptors, so a slow upstream
  leaves no socket behind.
- **send** (30000 ms): one absolute budget for writing the request head and
  body.
- **head** (30000 ms): one absolute budget for the complete response head,
  interim responses included. Progress does not extend it.
- **read** (30000 ms): the budget for each body receive. An upstream that keeps
  sending within this budget can stream indefinitely, for example
  Server-Sent Events.

Writes to the client use the stream's write budget, as for any `B.stream`.

## Name resolution and connecting

Base's `TCP.connect` has no resolver and opens only IPv4 sockets, so the proxy
uses its own effect, `src/effects/upstream_connect.c`, with a JS twin in
`upstream_connect.js`.

A numeric IPv4 or IPv6 host is used as it is, with no lookup. A DNS name is
resolved with `getaddrinfo` on a detached thread started for that lookup, so
the event loop keeps serving other requests. The thread signals completion
through a pipe, and the request waits on that pipe until the answer or the
connect deadline arrives. At most 32 lookups run at once; another request
fails with `502` (`EAGAIN` from the effect) until one finishes. A lookup
counts until `getaddrinfo` returns, even after its request has given up, so
slow DNS can't pile up threads or descriptors. The runtime's own helper threads can't be
abandoned at a deadline, and `getaddrinfo_a` exists only in glibc, which is
why each lookup gets its own thread.

A lookup still running at the deadline is abandoned and the request gets
`504`. The thread frees its result and closes the pipe when `getaddrinfo`
returns, so a late answer opens no socket. The C library's resolver settings
(`/etc/hosts`, `/etc/resolv.conf`, `nsswitch.conf`) apply, and nothing is
cached between requests.

The resolved addresses are tried one at a time, at most 8 of them. Bendo
keeps the first 8 addresses of each family in the resolver's order (RFC 6724)
and alternates families starting with the first result's family, as RFC 8305
suggests, so a long list of one family can't hide the other. Each attempt except the last gets an
equal share of the time left, and the last gets all of it. A refused or
unreachable address moves on to the next one at once, and a slow attempt's
socket is closed before the next one opens. Attempts never run in parallel,
so this is a simplified Happy Eyeballs: a black-holed first address costs its
share of the budget before the next address is tried.

`localhost` goes through the resolver like any name. If it resolves to both
`::1` and `127.0.0.1` and the upstream listens only on IPv4, the `::1`
attempt is refused at once and the IPv4 one connects.

In the JS build, the IO loop blocks in `select`, so `dns.lookup` callbacks
can't run on the main thread. One shared worker thread does the lookups and
writes each answer to a pipe made for that request. The same 32-lookup cap
applies, counted in memory shared with the worker until it has answered and
closed the pipe. Address order and the connect logic match the C effect.

## Connections and cleanup

Each proxied request opens one upstream connection, sends `connection: close`
and closes the socket when it finishes. There is no connection pool or reuse.
Every path closes the upstream socket exactly once:

- each error path above;
- the stream's cleanup after the body ends or aborts;
- a client disconnect, because the stream write fails and runs cleanup;
- a HEAD request or bodyless status, where the stream is suppressed and runs
  cleanup without pulling;
- middleware that replaces the response, which cancels the stream;
- a timeout middleware that answers first. The proxy keeps running, as
  [plan decision 9](PLAN.md#design-decisions) describes, and its late stream
  registration is cancelled and cleaned up.

The response body streams with bounded memory. Each pull receives at most
`min(max_chunk_bytes, 65536)` octets, and the chunked decoder hands back what
it decoded on every receive instead of accumulating the body.

## Verify

Run `bun test tests/proxy.test.ts --timeout 30000`. The test compiles the
proxy fixture and runs it against a Bun upstream and a scripted `node:net`
upstream. It covers:

- forwarding: 200, 404 and 500 statuses, repeated `Set-Cookie`, method, path,
  query, headers, `preserve_host`, rewrites and the forwarding chains;
- request headers: hop-by-hop and `Connection`-listed fields, proxy
  credentials, framing and `Expect` are not forwarded;
- bodies: 1 MiB and 3 MiB uploads, a 413 above the limit, and 1 MiB and 16 MiB
  downloads, with the server's peak RSS compared across sizes;
- upstream framing: every malformed case returns 502 and closes the upstream
  socket, chunked and close-delimited bodies complete, and post-commit
  failures abort;
- timeouts: connect, head and per-read timeouts;
- names and IPv6: `localhost` through the resolver, a `.invalid` name that
  gets `502`, a bracketed `[::1]` upstream with its `Host`, and the connect
  effect alone in both the native and JS builds (a name, NXDOMAIN, a refused
  port, an unroutable address timing out at its deadline, and an IPv6
  literal). The IPv6 tests are skipped with a message when the machine has no
  IPv6 loopback. On Linux, `tests/fixtures/proxy/fake_dns.c` replaces
  `getaddrinfo` through `LD_PRELOAD` to check, in both builds, that the 33rd
  concurrent lookup fails with `EAGAIN` (and gets `502` from the native
  server) while 32 slow lookups are held, and that 16 IPv6 answers before an
  IPv4 one still reach the IPv4 address;
- cleanup: the upstream socket closes on client disconnect, HEAD and
  middleware replacement.

`bend PROOF.bend --verdict` checks the two header laws and the upstream host
laws in [`proof/proxy-laws.bend`](../proof/proxy-laws.bend):

- `proxy_upstream_authority_spec`: the authority parser
  (`Upstream.read_authority`) accepts exactly the authorities that the grammar
  in [`proof/upstream-host-spec.bend`](../proof/upstream-host-spec.bend)
  accepts, and reads the same host and port.
- `proxy_upstream_host_round_trip`: the `Host` value sent upstream parses back
  to exactly the endpoint it came from.

The specification splits the authority at every `]` or `:` and states labels,
ports and embedded IPv4 in its own terms, while the parser cuts at the first
separator, so the two are independent formulations. Closed examples cover an
IPv6 URL, a name URL, IPv4 shorthand, non-canonical IPv6, IPv4-mapped and
IPv4-compatible IPv6, an empty label, a trailing dot, a leading and a trailing
hyphen, port 0 and a port with a leading zero.
