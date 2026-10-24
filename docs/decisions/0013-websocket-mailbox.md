# 0013: One socket owner and a bounded WebSocket mailbox

BND-52 runs each upgraded connection in one computation. The same computation
decodes frames, assembles messages, calls the application's templates, and
writes frames. The HTTP transport still owns the opening handshake and its
access log. After 101, no HTTP parser runs on that socket.

An application receives a copyable `WebSocketHandle` in `open` and `message`.
It holds a per-connection `Chan(Command)` and an outbound message limit. The
application can retain it in `B.Store`, allowing an HTTP route or a different
WebSocket connection to send a message. BND-53 can store topic memberships as
these handles and enqueue a publication separately for each recipient.

## Poll instead of racing socket ownership

Bend 2.0.38 has `Chan.try_recv` and `TCP.try_recv_bytes`, but no operation that
selects between a channel and a socket. `IO.within` leaves its losing computation
alive, so racing a receive against a mailbox would leave an affine socket with
an outstanding reader. A separate unbounded reader/writer task would also hide
backpressure and complicate close ordering. We use neither.

Each cycle checks deadlines, polls one mailbox item without waiting, and
processes one buffered frame or performs a socket read. After a mailbox command,
that read does not wait: it only collects bytes that have already arrived, so a
queued burst drains at write speed while inbound frames and deadlines still get
a turn between commands. When the mailbox is empty the read waits, shortened to
the nearest idle, keepalive, or close deadline. After an automatic keepalive
write the loop processes input before checking keepalive again. Buffered input
and a busy mailbox cannot starve each other.

The wait starts at `poll_ms` (default 10 ms) and doubles after each empty read
up to `poll_max_ms` (default 100 ms). Received bytes reset it to `poll_ms`, and
a mailbox command makes it zero. The trade-off is latency for idle CPU. A
command sent to a connection that has been quiet for a while reaches the wire
within `poll_max_ms`, plus scheduling and any current handler or write. A busy
connection sees `poll_ms` or better. Measured on ms-a2 with the
`tests/servers/ws-session.bend` fixture, 1,000 idle connections used 9.7% of a
core with the defaults and 83% with a fixed 5 ms poll; 50 idle connections used
0.4% and 2.1%. BND-53 chat rooms inherit this: a message to a quiet room member
can take up to `poll_max_ms` to leave. Set `poll_max_ms` to `poll_ms` to turn
backoff off and pay the CPU instead.

Handlers run in that same computation. They must finish and bound their own IO;
no session deadline cancels arbitrary handler IO or uninterrupted pure work.
An `open` or `message` handler may enqueue sends, but must not wait for their
delivery before returning. Admission is immediate and does not await delivery.

## Memory and slow recipients

The channel has `mailbox_capacity` slots (default 16, minimum 1). Send helpers
validate a command before `Chan.try_send(..., 0)`. They return `False` for an
invalid command, a full mailbox, or a closed channel. No framework sender waits
outside that bounded queue. A publisher must choose its slow-recipient policy:
drop the message, retry from bounded application state, or remove the recipient.
It must never spawn one waiting computation per publication.

One send finishes before another begins. The existing streaming writer retries
only the unsent suffix under a single absolute `write_ms` deadline. A stalled
write closes the socket with a local 1006 notification. It cannot keep adding
frames to a transport output buffer.

Through the supplied helpers, queued wire payload is bounded by
`mailbox_capacity * max(max_message, 125)` bytes. In addition, the connection
holds one current outgoing frame and its encoding, up to one `max_message`
assembled message, one partial frame up to `max(max_message, 125)`, a 16 KiB
socket-read chunk, an incomplete header of at most 14 bytes, and bounded runtime
and kernel buffers. Temporary codec/list copies add constant factors. Octet
lists consume substantially more memory than their wire length. User state and
allocations made before a helper is called remain the application's responsibility.
Directly constructing handles or sending to their underlying channels bypasses
admission validation; applications should use the helpers.

## Close ordering

A successful local close write moves the pure policy to closing. Later queued
data and ping commands are ignored. Incoming pings still get a pong until the
peer's close arrives; those pong writes use the remaining close budget. The
socket continues reading for a peer close until `close_ms` expires. A peer close in an open session gets exactly one
echo, including an empty close payload; a peer acknowledgment of our close gets
no second close. Both end with one `close` callback. The callback reports the
peer's code and reason, or 1005 for an empty peer close. EOF, transport failure,
or an unacknowledged local close reports 1006 without sending that code.

Protocol errors send 1002, invalid UTF-8 sends 1007, and exceeded limits send
1009, then end the session. They do not wait for an acknowledgment.

When the session ends it closes the mailbox, closes the socket, then removes and
drops every command still queued before calling `close`. Closing prevents
retained handles from accepting further sends, but `Chan.close` keeps queued
items, so without the drain a handle saved in a store or topic registry would
hold up to `mailbox_capacity * max(max_message, 125)` bytes after disconnect.

Every transition goes through the pure reducer `S.step` in
`src/ws/session.bend`, over four events: an inbound frame, an outbound command,
a decoder rejection, and `Dropped` (EOF, transport or write failure, or an
expired close wait). A failed write feeds `Dropped` to the session the action
started in, so the trace laws in `proof/ws-session-laws.bend` describe every
connection run. The existing
handshake and codec laws are unchanged.
