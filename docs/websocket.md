# Accept a WebSocket upgrade

`B.websocket` answers an RFC 6455 opening handshake from an ordinary route
handler. When the handshake is valid, the server sends `101 Switching
Protocols`, stops parsing HTTP on that connection, and hands the socket to a
session template. Bendo does not decode frames yet; the frame codec (BND-51)
and the open/message/close handler API (BND-52) build on this session seam.
The complete native example is [the WebSocket fixture](../tests/servers/websocket.bend).

## Register a session

`B.websocket(~Vars, ~State, ~session, ~cleanup, context, state, config)` returns
`IO(B.Res)`. Return that response from a route handler served by `B.serve` or
`B.serve_with`. The templates have these types:

- `session: State -> Socket -> List<&2, U32> -> IO(Unit)` runs after the 101 has
  been sent. It receives the state, the socket, and every octet the server had
  already read past the handshake (a client may send its first frame in the same
  packet). The session owns the socket from then on and must close it.
- `cleanup: State -> IO(Unit)` runs instead of the session when the handshake is
  refused, middleware replaces the response, the 101 cannot be sent, or the
  registration is rejected. It must release whatever the state owns.

Exactly one of the two receives the state. For example, a session that sends
back whatever arrived with the handshake, then closes:

```python
import Base
import ../src/main.bend as B

def closed(sent: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>) -> IO(Unit):
  (s, result) = sent
  Socket.close(s)

def session(state: Unit, s: Socket, rest: List<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    sent : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send_bytes(s, rest)
    closed(sent)

def cleanup(state: Unit) -> IO(Unit):
  IO.pure(Unit, Unit{})

def handler(c: B.Context(Unit)) -> IO(B.Res):
  B.websocket(~Unit, ~Unit, ~session, ~cleanup, c, Unit{}, B.websocket_config())
```

The session runs inside the connection's own computation, so a slow session
does not block other clients. Bound its reads with `TCP.try_recv_bytes` and a
timeout; the fixture's echo loop shows one way.

## Configure origins and subprotocols

`B.websocket_config()` accepts every Origin, offers no subprotocol, and gives the
101 head a 30-second write budget. Adjust it with:

- `B.websocket_origins(config, ["https://app.example"])` requires exactly one
  `Origin` field whose serialized origin is listed. Entries are serialized with
  the same rules as CORS and CSRF (`src/http/origin.bend`): any path is ignored,
  and entries that are not http or https URLs, or whose host is not written the
  way browsers send it, are dropped. A missing, repeated
  or unlisted Origin gets 403. Browsers always send Origin, so list your origins
  whenever a session trusts cookies; otherwise any site can open a socket with
  the user's credentials.
- `B.websocket_protocols(config, ["chat.v2", "chat"])` lists the subprotocols the
  server speaks, most preferred first. Bendo answers with the first listed
  protocol that the client offered in any `Sec-WebSocket-Protocol` field. Offers
  match exactly, including case. With no match, the 101 has no
  `Sec-WebSocket-Protocol` field and the client decides whether to continue.
  Entries that are not HTTP tokens are dropped.
- `B.websocket_timeout(config, milliseconds)` sets the write budget for the 101.

Cookie-authenticated sockets need an explicit origin allowlist. CORS does not
protect WebSockets; configure `B.websocket_origins` even when CORS is enabled.

Extensions are never negotiated. A `Sec-WebSocket-Extensions` offer such as
`permessage-deflate` is ignored, and the 101 never carries that field, so the
connection uses uncompressed frames.

## Handshake rules

Register the route with `B.all` (or list the methods with `B.on`) when every
method should reach `B.websocket` and get its 400. A `B.get` route answers other
methods with the router's 405 before the handler runs.

`B.websocket` checks the request in this order. The first failure decides the
status:

| Check | Failure |
|---|---|
| Method is GET | 400 |
| Version is HTTP/1.1 | 400 |
| No `Transfer-Encoding` (even an empty chunked body), and no `Content-Length` other than one zero value (`0`, `00`, …) | 400 |
| An `Upgrade` list element `websocket`, any ASCII case, in any `Upgrade` field | 400 |
| A `Connection` list element `upgrade`, any ASCII case, in any `Connection` field | 400 |
| Exactly one `Sec-WebSocket-Key`: padded standard base64 of exactly 16 octets, in its one canonical spelling | 400 |
| Exactly one `Sec-WebSocket-Version` | 400 |
| That version is `13` | 426 with `Sec-WebSocket-Version: 13` |
| Origin policy (above) | 403 |

A refusal is an ordinary Bendo error response: plain text, or
`{"error": ..., "status": ...}` for clients that accept JSON, passing through
your middleware like any other handler result. The 426 follows RFC 6455
section 4.4 by naming the one version Bendo speaks.

An accepted handshake answers:

```
HTTP/1.1 101 Switching Protocols
upgrade: websocket
connection: Upgrade
sec-websocket-accept: <base64(SHA-1(key ++ "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))>
sec-websocket-protocol: <chosen subprotocol, when there is one>
```

followed by any fields middleware and finalizers added. For the RFC's sample
key `dGhlIHNhbXBsZSBub25jZQ==` the accept value is
`s3pPLMBiTxaQ9kYGzzhZRbK+xOo=`. A 101 never has a body, `Content-Length` or
`Transfer-Encoding`. Bendo does not generate `Date` for a 101 (RFC 9110 requires
it only for 2xx to 5xx), but keeps one that middleware set.

## Middleware and lifecycle

Response hooks, CORS, secure headers, request IDs and server timing run on the
101 as on any response. After they finish, Bendo checks the response a private
marker ties to the registration:

- If the marker is gone (middleware returned a different response), Bendo sends
  that response and runs `cleanup`.
- If the marker survives but the status is no longer 101 (a hook turned it into
  a 403 or 500), Bendo keeps that status, removes the handshake fields, and runs
  `cleanup`. It never forces a 101 over an explicit refusal.
- If the response is still the 101, Bendo checks the handshake again against the
  request exactly as it arrived on the wire, then rebuilds the handshake fields
  and drops any body, framing or handshake fields middleware added. A rewrite
  that changed the method (for example a POST rewritten to GET) is refused here
  with 400, keeping the fields middleware and finalizers added. Method override
  never produces GET, so it cannot turn a POST into an upgrade.

A second `B.websocket` or `B.stream` call in one request, or one made after
handling finished (for example after timeout middleware gave up), answers an
empty 500 and runs that registration's cleanup. The first registration is
cleaned up too, because the 500 no longer carries its marker.

The access logger records the status after transport selection, including a
400 refusal caused by a method rewrite. Cache middleware skips all 1xx
responses.

`on_after_response` observers run once, after the 101 has been sent and before
the session starts. A 101 does not take the connection's keep-alive or
`Connection: close` policy: the connection belongs to the session. Network-free
`B.handle` cannot hand off a socket, so it runs `cleanup` and returns an empty
500.

## Verify

Run `bun test tests/websocket.test.ts --timeout 30000`. It opens a real Bun
`WebSocket` client with a negotiated subprotocol, then drives raw sockets
through the validation table, pipelined suffixes, middleware finalization,
replacement, duplicate and late registrations, and the wire-method check.

Six laws in `LAWS.bend` cover the pure handshake, against an independent
statement in [`proof/websocket-spec.bend`](../proof/websocket-spec.bend):

- `websocket_accept_spec`: for every key, the accept value is the base64 of the
  SHA-1 of the key octets and the GUID, which the spec writes as literal octets.
- `websocket_accept_rfc`: the RFC 6455 sample key gives the RFC's accept value.
- `websocket_decision_spec`: for every configuration and request, the decision
  (accept with the computed key and subprotocol, or the refusal status) equals
  the spec's rules above.

- `websocket_response_version`: a pure 426 response names exactly version 13.
- `websocket_response_success`: a pure 101 response carries the required fields
  and the selected protocol exactly when one was selected.
- `websocket_rebuilt_framing`: rebuilding any middleware response as a 101
  leaves an empty body and no Content-Length or Transfer-Encoding fields.
